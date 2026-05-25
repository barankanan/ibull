import 'kitchen_order_number_fields.dart';
import 'kitchen_print_trace_log.dart';
import 'kitchen_product_mapping_cache_store.dart';
import 'kitchen_routing_service.dart';

/// Hub mutfak job mu? (SQL print_jobs: item.name / product_name yeterli.)
bool isHubKitchenPrintJob(
  Map<String, dynamic> payload,
  Map<String, dynamic> jobRecord,
) {
  final documentType = payload['document_type']?.toString().trim() ?? '';
  if (documentType == 'receipt') return false;

  final jobType =
      payload['job_type']?.toString().trim() ??
      jobRecord['job_type']?.toString().trim() ??
      '';
  if (jobType == 'receipt' || jobType == 'adisyon') return false;

  final printerRole = payload['printer_role']?.toString().trim() ?? '';
  if (printerRole == 'adisyon') return false;

  final items = payload['items'];
  if (items is List && items.isNotEmpty) {
    return true;
  }

  if (documentType == 'kitchen') return true;
  return jobType == 'new_order' ||
      jobType == 'add_item' ||
      jobType == 'remove_item' ||
      jobType == 'reprint' ||
      jobType == 'kitchen_order';
}

/// Üretim alanına göre ayrı bridge istekleri (OCAK / FIRIN / …).
List<Map<String, dynamic>> buildHubKitchenPrintRequests({
  required String restaurantId,
  required Map<String, dynamic> payload,
  String? jobStationId,
}) {
  final stamped = stampHubKitchenPrintPayload(
    restaurantId: restaurantId,
    payload: payload,
    jobStationId: jobStationId,
  );
  final items = KitchenTicketHeaderResolver.kitchenItemsFromPayload(stamped);
  if (items.length <= 1) {
    return <Map<String, dynamic>>[stamped];
  }

  final groups = <String, List<Map<String, dynamic>>>{};
  for (final raw in items) {
    final item = Map<String, dynamic>.from(raw);
    final header = KitchenTicketHeaderResolver.productionHeaderLabel(
      stationName: item['station_name']?.toString() ?? '',
      stationCode: item['station_code']?.toString() ?? '',
    );
    final key = header.isEmpty ? kKitchenGeneralStationLabel : header;
    groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
  }

  if (groups.length <= 1) {
    return <Map<String, dynamic>>[stamped];
  }

  kitchenTraceJsonLog('KitchenPrintPayload', 'HubSplitByStation', <String, Object?>{
    'groupCount': groups.length,
    'groups': groups.keys.toList(),
  });

  return groups.entries.map((entry) {
    final header = entry.key;
    final split = Map<String, dynamic>.from(stamped);
    split['items'] = entry.value;
    split['area_name'] = header;
    split['station_name'] = header;
    split['kitchen_ticket_header'] = header;
    final code = entry.value.first['station_code']?.toString().trim() ?? '';
    split['station_code'] = code.isNotEmpty ? code.toUpperCase() : header;
    if (entry.value.first['station_id'] != null) {
      split['station_id'] = entry.value.first['station_id'];
    }
    return split;
  }).toList(growable: false);
}

/// PrintHub / print_jobs yolunda bridge öncesi mutfak payload düzeltmesi (cache-only).
Map<String, dynamic> stampHubKitchenPrintPayload({
  required String restaurantId,
  required Map<String, dynamic> payload,
  String? jobStationId,
}) {
  final restaurantKey = restaurantId.trim();
  final out = Map<String, dynamic>.from(payload);

  logHubKitchenPayloadSnapshot('HubStampBefore', out);

  var tableAreaName = out['table_area_name']?.toString().trim() ?? '';
  final legacyArea = out['area_name']?.toString().trim() ?? '';
  if (tableAreaName.isEmpty &&
      KitchenTicketHeaderResolver.isDiningAreaStationLabel(legacyArea)) {
    tableAreaName = legacyArea;
  }
  if (tableAreaName.isNotEmpty) {
    out['table_area_name'] = tableAreaName;
  }

  for (final key in <String>[
    'area_name',
    'station_name',
    'kitchen_ticket_header',
    'station_code',
  ]) {
    final value = out[key]?.toString().trim() ?? '';
    if (KitchenTicketHeaderResolver.isDiningAreaStationLabel(value) ||
        (value.toUpperCase() == 'GENEL' && key != 'station_code')) {
      if (key == 'area_name' || key == 'station_name' || key == 'kitchen_ticket_header') {
        out.remove(key);
      }
    }
  }

  final stationNamesById =
      KitchenTicketHeaderResolver.stationNamesForRestaurant(restaurantKey) ??
      const <String, String>{};
  final stationCodesById =
      KitchenTicketHeaderResolver.stationCodesForRestaurant(restaurantKey) ??
      const <String, String>{};
  KitchenProductMappingCacheStore.applyMemoryToResolver(restaurantKey);
  final cacheDiag = KitchenProductMappingCacheStore.diagnostics(restaurantKey);
  kitchenTraceJsonLog('KitchenPrintPayload', 'HubStampCache', cacheDiag);

  final productMappings =
      KitchenTicketHeaderResolver.productMappingsForRestaurant(restaurantKey) ??
      const <String, ProductStationMapping>{};
  final cacheNameKeys = KitchenProductMappingCacheStore.productNameKeys(
    restaurantKey,
  );

  final rawItems = KitchenTicketHeaderResolver.kitchenItemsFromPayload(out);
  final resolvedItems = <Map<String, dynamic>>[];

  for (final raw in rawItems) {
    final item = Map<String, dynamic>.from(raw);
    final productId = item['product_id']?.toString().trim() ?? '';
    final productName =
        KitchenTicketHeaderResolver.extractKitchenItemProductName(item);
    final normalizedName =
        KitchenTicketHeaderResolver.normalizeProductNameKey(productName);

    final foundByProductId = productId.isNotEmpty &&
        KitchenTicketHeaderResolver.productMappingForHubItem(
              restaurantId: restaurantKey,
              productId: productId,
            ) !=
            null;
    final foundByProductName = productName.isNotEmpty &&
        KitchenTicketHeaderResolver.productMappingForHubItem(
              restaurantId: restaurantKey,
              productName: productName,
            ) !=
            null;

    logHubStationResolveAttempt(
      rawName: productName,
      normalizedName: normalizedName,
      hasProductId: productId.isNotEmpty,
      foundByProductId: foundByProductId,
      foundByProductName: foundByProductName,
      cacheProductNameKeys: cacheNameKeys,
    );

    final resolution = KitchenTicketHeaderResolver.resolveHubItemProductionStation(
      restaurantId: restaurantKey,
      productId: productId,
      productName: productName,
      item: item,
      jobStationId: jobStationId,
      stationNamesById: stationNamesById,
      stationCodesById: stationCodesById,
      productMappings: productMappings,
    );

    kitchenTraceJsonLog('KitchenPrintPayload', 'HubStationResolved', <String, Object?>{
      'productId': productId,
      'productName': productName,
      'normalizedName': normalizedName,
      'stationId': resolution.stationId,
      'stationName': resolution.headerLabel,
      'stationCode': resolution.stationCode,
      'source': resolution.source,
    });

    if (resolution.stationId.isNotEmpty) {
      item['station_id'] = resolution.stationId;
    }
    item['station_name'] = resolution.headerLabel;
    item['station_code'] = resolution.stationCode;
    item['kitchen_station_name'] = resolution.headerLabel;
    item['area_name'] = resolution.headerLabel;
    if (productName.isNotEmpty &&
        (item['name'] == null || item['name'].toString().trim().isEmpty)) {
      item['name'] = productName;
    }
    resolvedItems.add(item);
  }

  final enrichedItems =
      KitchenTicketHeaderResolver.enrichItemsWithProductionStations(
        items: resolvedItems,
        stationNamesById: stationNamesById,
        stationCodesById: stationCodesById,
        productStationByProductId: productMappings,
        tableAreaName: tableAreaName,
        restaurantId: restaurantKey,
      );

  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final item in enrichedItems) {
    logKitchenRoutingGroupInput(item);
    final sid = item['station_id']?.toString().trim() ?? '';
    final key = sid.isEmpty ? '__general__' : sid;
    grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    final header = KitchenTicketHeaderResolver.resolveProductionHeaderForItem(
      item: item,
      stationNamesById: stationNamesById,
      stationCodesById: stationCodesById,
      productStationByProductId: productMappings,
    );
    logKitchenRoutingGroupCreated(
      groupKey: key,
      stationId: sid,
      stationName: header,
      stationCode: item['station_code']?.toString() ?? '',
      itemCount: grouped[key]!.length,
    );
  }

  out['items'] = enrichedItems;

  final normalizedJobStationId =
      jobStationId?.trim().isNotEmpty == true
          ? jobStationId!.trim()
          : out['station_id']?.toString().trim() ?? '';
  String? headerOverride;
  if (normalizedJobStationId.isNotEmpty) {
    headerOverride = KitchenTicketHeaderResolver.productionHeaderLabel(
      stationName: stationNamesById[normalizedJobStationId] ?? '',
      stationCode: stationCodesById[normalizedJobStationId] ?? '',
    );
  }

  final header = KitchenTicketHeaderResolver.finalizeKitchenTicketHeader(
    overrideHeader: headerOverride,
    rawItems: enrichedItems,
    payload: out,
    stationId: normalizedJobStationId.isEmpty ? null : normalizedJobStationId,
    stationNamesById: stationNamesById,
    stationCodesById: stationCodesById,
    productStationByProductId: productMappings,
    tableAreaName: tableAreaName,
    restaurantId: restaurantKey,
  );

  out['kitchen_ticket_header'] = header;
  out['station_name'] = header;
  out['area_name'] = header;
  final jobCode = normalizedJobStationId.isNotEmpty
      ? (stationCodesById[normalizedJobStationId] ?? '')
      : '';
  if (jobCode.isNotEmpty) {
    out['station_code'] = jobCode.toUpperCase();
  } else if (enrichedItems.isNotEmpty) {
    final firstCode = enrichedItems.first['station_code']?.toString().trim() ?? '';
    if (firstCode.isNotEmpty) {
      out['station_code'] = firstCode.toUpperCase();
    } else {
      out['station_code'] = header.toUpperCase();
    }
  } else {
    out['station_code'] = header.toUpperCase();
  }
  if (normalizedJobStationId.isNotEmpty) {
    out['station_id'] = normalizedJobStationId;
  }

  final stamped = KitchenTicketHeaderResolver.stampProductionHeaderOnKitchenPayload(
    out,
    stationNamesById: stationNamesById,
    stationCodesById: stationCodesById,
    productStationByProductId: productMappings,
  );

  var result = stamped;
  final headerArea = result['area_name']?.toString().trim() ?? '';
  if (KitchenTicketHeaderResolver.isDiningAreaStationLabel(headerArea)) {
    result = Map<String, dynamic>.from(result)
      ..['area_name'] = kKitchenGeneralStationLabel
      ..['station_name'] = kKitchenGeneralStationLabel
      ..['kitchen_ticket_header'] = kKitchenGeneralStationLabel
      ..['station_code'] = kKitchenGeneralStationLabel;
    kitchenTraceJsonLog(
      'KitchenPrintPayload',
      'HubStampForcedGeneral',
      <String, Object?>{'rejectedHeader': headerArea},
    );
  }

  stampKitchenOrderNumberFields(result);
  logHubKitchenPayloadSnapshot('HubStampAfter', result);
  detectTableAreaUsedAsHeader(result, where: 'stampHubKitchenPrintPayload');
  return result;
}

void logHubKitchenPayloadSnapshot(
  String stage,
  Map<String, dynamic> payload,
) {
  final rawItems = payload['items'];
  final itemSnapshots = <Map<String, Object?>>[];
  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      itemSnapshots.add(<String, Object?>{
        'name': map['name'] ?? map['item_name'] ?? map['product_name'] ?? '',
        'display_label': map['display_label'] ?? '',
        'amount_label': map['amount_label'] ?? map['gramaj'] ?? '',
        'pricing_mode': map['pricing_mode'] ?? '',
        'selected_grams': map['selected_grams'] ?? '',
        'station_id': map['station_id'] ?? '',
        'station_name': map['station_name'] ?? '',
        'station_code': map['station_code'] ?? '',
        'area_name': map['area_name'] ?? '',
      });
    }
  }
  kitchenTraceJsonLog('KitchenPrintPayload', stage, <String, Object?>{
    'area_name': payload['area_name'] ?? '',
    'station_name': payload['station_name'] ?? '',
    'station_code': payload['station_code'] ?? '',
    'kitchen_ticket_header': payload['kitchen_ticket_header'] ?? '',
    'table_area_name': payload['table_area_name'] ?? '',
    'items': itemSnapshots,
  });
}
