import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/kitchen_print_dedup.dart';
import 'kitchen_routing_service.dart';
import 'kitchen_station_print_grouping.dart';

class CargoKitchenPrintJobsResult {
  const CargoKitchenPrintJobsResult({
    required this.ok,
    required this.printJobCount,
    required this.printJobIds,
    this.skippedDuplicate = false,
    this.groupCount = 0,
    this.errorMessage,
  });

  final bool ok;
  final int printJobCount;
  final List<String> printJobIds;
  final bool skippedDuplicate;
  final int groupCount;
  final String? errorMessage;
}

class CargoKitchenPrintPlan {
  const CargoKitchenPrintPlan({
    required this.groupsToCreate,
    required this.skippedExisting,
    required this.skippedRoutingDisabled,
  });

  final List<KitchenStationPrintGroup> groupsToCreate;
  final List<KitchenStationPrintGroup> skippedExisting;
  final List<Map<String, dynamic>> skippedRoutingDisabled;

  int get printableGroupCount => groupsToCreate.length;
}

List<Map<String, dynamic>> mergeCargoItemsForPrint({
  required List<Map<String, dynamic>> storedItems,
  List<Map<String, dynamic>>? productLines,
}) {
  final linesByProductId = <String, Map<String, dynamic>>{};
  for (final raw in productLines ?? const <Map<String, dynamic>>[]) {
    final productId = (raw['product_id'] ?? raw['productId'] ?? '')
        .toString()
        .trim();
    if (productId.isEmpty) continue;
    linesByProductId[productId] = raw;
  }

  final merged = <Map<String, dynamic>>[];
  for (final stored in storedItems) {
    final item = Map<String, dynamic>.from(stored);
    final productId = (item['product_id'] ?? '').toString().trim();
    final line = productId.isEmpty ? null : linesByProductId[productId];
    final storedStation = (item['station_id'] ?? '').toString().trim();
    if (storedStation.isEmpty && line != null) {
      final lineStation = (line['station_id'] ?? line['stationId'] ?? '')
          .toString()
          .trim();
      if (lineStation.isNotEmpty) item['station_id'] = lineStation;
    }
    if (!item.containsKey('printer_routing_enabled') && line != null) {
      item['printer_routing_enabled'] = line['printer_routing_enabled'];
    }
    final name = KitchenTicketHeaderResolver.extractKitchenItemProductName(
      item,
    );
    if (name.isNotEmpty) {
      item['name'] = name;
      item['product_name'] ??= name;
    }
    merged.add(item);
  }
  return merged;
}

CargoKitchenPrintPlan planCargoKitchenPrintJobs({
  required List<Map<String, dynamic>> orderItems,
  Map<String, String>? stationNamesById,
  Map<String, String>? stationCodesById,
  Map<String, ProductStationMapping>? productStationByProductId,
  Set<String> existingActiveStationKeys = const <String>{},
}) {
  final skippedRoutingDisabled = orderItems
      .where((item) => !isKitchenPrinterRoutingEnabled(item))
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  final routable = filterKitchenRoutableItems(orderItems);
  if (routable.isEmpty) {
    return CargoKitchenPrintPlan(
      groupsToCreate: const <KitchenStationPrintGroup>[],
      skippedExisting: const <KitchenStationPrintGroup>[],
      skippedRoutingDisabled: skippedRoutingDisabled,
    );
  }

  final grouped = groupItemsByProductionStation(
    routable,
    stationNamesById: stationNamesById ?? const <String, String>{},
    stationCodesById: stationCodesById,
    productStationByProductId: productStationByProductId,
  );
  final toCreate = <KitchenStationPrintGroup>[];
  final skippedExisting = <KitchenStationPrintGroup>[];
  for (final group in grouped) {
    if (existingActiveStationKeys.contains(group.groupKey)) {
      skippedExisting.add(group);
      continue;
    }
    toCreate.add(group);
  }
  return CargoKitchenPrintPlan(
    groupsToCreate: toCreate,
    skippedExisting: skippedExisting,
    skippedRoutingDisabled: skippedRoutingDisabled,
  );
}

Map<String, dynamic> buildCargoKitchenJobPayload({
  required String restaurantId,
  required String orderId,
  required String orderNumber,
  required KitchenStationPrintGroup group,
  Map<String, String>? stationCodesById,
  String? storeName,
  String? createdAt,
}) {
  final stationCode = group.stationId.isEmpty
      ? ''
      : (stationCodesById?[group.stationId] ?? '').trim();
  final items = group.items
      .map((item) {
        final name = KitchenTicketHeaderResolver.extractKitchenItemProductName(
          item,
        );
        return <String, dynamic>{
          'order_item_id': item['id'] ?? item['order_item_id'],
          'product_id': item['product_id'],
          'product_name': name,
          'name': name,
          'quantity': item['quantity'] ?? 1,
          'unit_price': item['unit_price'],
          'item_note': item['item_note'] ?? item['note'],
          if ((item['station_id'] ?? '').toString().trim().isNotEmpty)
            'station_id': item['station_id'],
        };
      })
      .toList(growable: false);
  final idempotencyKey = buildKitchenPrintIdempotencyKey(
    restaurantId: restaurantId,
    orderId: orderId,
    stationId: group.stationId,
    stationName: group.stationName,
    revision: 1,
    items: items,
  );
  return <String, dynamic>{
    'restaurant_id': restaurantId,
    if ((storeName ?? '').trim().isNotEmpty) 'restaurant_name': storeName!.trim(),
    'order_id': orderId,
    'order_no': orderNumber,
    'order_number': orderNumber,
    'table_name': 'Kargo',
    'display_table_label': 'Kargo',
    'job_type': 'new_order',
    'document_type': 'kitchen',
    'station_id': group.stationId.isEmpty ? null : group.stationId,
    'station_name': group.stationName,
    if (stationCode.isNotEmpty) 'station_code': stationCode,
    'kitchen_ticket_header': group.stationName,
    'area_name': group.stationName,
    'revision': 1,
    'idempotency_key': idempotencyKey,
    'content_idempotency_key': idempotencyKey,
    if ((createdAt ?? '').trim().isNotEmpty) 'created_at': createdAt,
    'items': items,
  };
}

/// Creates pending kitchen [print_jobs] for an already-saved cargo order.
/// Does not call Garson table RPC and does not physically print.
class SellerCargoPrintJobService {
  SellerCargoPrintJobService({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  static final Set<String> _inFlightOrderIds = <String>{};

  Future<CargoKitchenPrintJobsResult> createPrintJobsForExistingOrder({
    required String restaurantId,
    required String orderId,
    required String orderNumber,
    required List<Map<String, dynamic>> orderItems,
    List<Map<String, dynamic>>? productLines,
    Map<String, String>? stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
    String? storeName,
    String? createdAt,
    Future<void> Function(List<String> printJobIds)? onJobsInserted,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedOrderId = orderId.trim();
    if (normalizedRestaurantId.isEmpty || normalizedOrderId.isEmpty) {
      return const CargoKitchenPrintJobsResult(
        ok: false,
        printJobCount: 0,
        printJobIds: <String>[],
        errorMessage: 'missing_order_or_restaurant',
      );
    }
    if (!_inFlightOrderIds.add(normalizedOrderId)) {
      debugPrint(
        '[CargoPrintJobs] skip in-flight orderId=$normalizedOrderId',
      );
      return const CargoKitchenPrintJobsResult(
        ok: true,
        printJobCount: 0,
        printJobIds: <String>[],
        skippedDuplicate: true,
      );
    }

    try {
      final mergedItems = mergeCargoItemsForPrint(
        storedItems: orderItems,
        productLines: productLines,
      );
      await _stampPrinterRoutingFromProducts(mergedItems);
      final resolvedStations = await _resolveStationMaps(
        restaurantId: normalizedRestaurantId,
        cachedNames: stationNamesById,
        cachedCodes: stationCodesById,
      );
      final existingJobs = await _loadExistingJobs(normalizedOrderId);
      final existingKeys = activeKitchenPrintStationKeys(existingJobs);
      final plan = planCargoKitchenPrintJobs(
        orderItems: mergedItems,
        stationNamesById: resolvedStations.names,
        stationCodesById: resolvedStations.codes,
        productStationByProductId: productStationByProductId,
        existingActiveStationKeys: existingKeys,
      );

      debugPrint(
        '[CargoPrintJobs] orderId=$normalizedOrderId '
        'itemCount=${mergedItems.length} '
        'groupCount=${plan.groupsToCreate.length + plan.skippedExisting.length} '
        'createCount=${plan.groupsToCreate.length} '
        'skippedExisting=${plan.skippedExisting.length} '
        'skippedRouting=${plan.skippedRoutingDisabled.length}',
      );

      if (plan.groupsToCreate.isEmpty) {
        final existingIds = existingJobs
            .map((job) => (job['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        return CargoKitchenPrintJobsResult(
          ok: true,
          printJobCount: existingIds.length,
          printJobIds: existingIds,
          skippedDuplicate: plan.skippedExisting.isNotEmpty,
          groupCount: plan.skippedExisting.length,
        );
      }

      final insertedIds = <String>[];
      for (final group in plan.groupsToCreate) {
        final payload = buildCargoKitchenJobPayload(
          restaurantId: normalizedRestaurantId,
          orderId: normalizedOrderId,
          orderNumber: orderNumber,
          group: group,
          stationCodesById: resolvedStations.codes,
          storeName: storeName,
          createdAt: createdAt,
        );
        debugPrint(
          '[CargoPrintJobs] insert station=${group.stationId.isEmpty ? "GENEL" : group.stationId} '
          'header=${group.stationName} itemCount=${group.items.length}',
        );
        final inserted = await _client
            .from('print_jobs')
            .insert(<String, dynamic>{
              'restaurant_id': normalizedRestaurantId,
              'order_id': normalizedOrderId,
              'station_id': group.stationId.isEmpty ? null : group.stationId,
              'job_type': 'new_order',
              'status': 'pending',
              'document_type': 'kitchen',
              'printer_role': 'mutfak',
              'payload': payload,
            })
            .select('id')
            .single();
        final printJobId = (inserted['id'] ?? '').toString().trim();
        if (printJobId.isEmpty) continue;
        insertedIds.add(printJobId);
        await _insertPrintJobItems(
          printJobId: printJobId,
          items: group.items,
        );
      }

      if (insertedIds.isNotEmpty && onJobsInserted != null) {
        try {
          await onJobsInserted(insertedIds);
        } catch (error) {
          debugPrint('[CargoPrintJobs] hub notify warn: $error');
        }
      }

      return CargoKitchenPrintJobsResult(
        ok: true,
        printJobCount: insertedIds.length,
        printJobIds: insertedIds,
        skippedDuplicate: plan.skippedExisting.isNotEmpty,
        groupCount: plan.groupsToCreate.length + plan.skippedExisting.length,
      );
    } catch (error) {
      debugPrint('[CargoPrintJobs] create failed orderId=$normalizedOrderId error=$error');
      return CargoKitchenPrintJobsResult(
        ok: false,
        printJobCount: 0,
        printJobIds: const <String>[],
        errorMessage: error.toString(),
      );
    } finally {
      _inFlightOrderIds.remove(normalizedOrderId);
    }
  }

  Future<List<Map<String, dynamic>>> _loadExistingJobs(String orderId) async {
    try {
      final rows = await _client
          .from('print_jobs')
          .select('id, station_id, status, job_type')
          .eq('order_id', orderId)
          .eq('job_type', 'new_order');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      debugPrint('[CargoPrintJobs] existing jobs lookup warn: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<({Map<String, String> names, Map<String, String> codes})>
  _resolveStationMaps({
    required String restaurantId,
    Map<String, String>? cachedNames,
    Map<String, String>? cachedCodes,
  }) async {
    final names = <String, String>{...?cachedNames};
    final codes = <String, String>{...?cachedCodes};
    try {
      final rows = await _client
          .from('stations')
          .select('id, name, code')
          .eq('restaurant_id', restaurantId);
      for (final raw in List<Map<String, dynamic>>.from(rows as List)) {
        final id = (raw['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final name = (raw['name'] ?? '').toString().trim();
        final code = (raw['code'] ?? '').toString().trim();
        if (name.isNotEmpty) names[id] = name;
        if (code.isNotEmpty) codes[id] = code;
      }
    } catch (error) {
      debugPrint('[CargoPrintJobs] stations lookup warn: $error');
    }
    return (names: names, codes: codes);
  }

  Future<void> _stampPrinterRoutingFromProducts(
    List<Map<String, dynamic>> items,
  ) async {
    final missingIds = items
        .where((item) => !item.containsKey('printer_routing_enabled'))
        .map((item) => (item['product_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (missingIds.isEmpty) return;
    try {
      final rows = await _client
          .from('products')
          .select('id, printer_routing_enabled')
          .inFilter('id', missingIds.toList(growable: false));
      final enabledById = <String, bool>{};
      for (final raw in List<Map<String, dynamic>>.from(rows as List)) {
        final id = (raw['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        enabledById[id] = raw['printer_routing_enabled'] != false;
      }
      for (final item in items) {
        if (item.containsKey('printer_routing_enabled')) continue;
        final id = (item['product_id'] ?? '').toString().trim();
        final enabled = enabledById[id];
        if (enabled != null) item['printer_routing_enabled'] = enabled;
      }
    } catch (error) {
      debugPrint('[CargoPrintJobs] product routing lookup warn: $error');
    }
  }

  Future<void> _insertPrintJobItems({
    required String printJobId,
    required List<Map<String, dynamic>> items,
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final orderItemId = (item['id'] ?? item['order_item_id'] ?? '')
          .toString()
          .trim();
      if (orderItemId.isEmpty) continue;
      rows.add(<String, dynamic>{
        'print_job_id': printJobId,
        'order_item_id': orderItemId,
      });
    }
    if (rows.isEmpty) return;
    try {
      await _client.from('print_job_items').insert(rows);
    } catch (error) {
      debugPrint('[CargoPrintJobs] print_job_items warn: $error');
    }
  }
}
