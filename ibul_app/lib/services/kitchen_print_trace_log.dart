import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'kitchen_routing_service.dart';

/// Mutfak fişi payload zinciri — gerçek baskı debug (kDebugMode'dan bağımsız).
void kitchenTraceJsonLog(
  String tag,
  String stage,
  Map<String, Object?> data,
) {
  try {
    debugPrint('[$tag][$stage] ${jsonEncode(data)}');
  } catch (_) {
    debugPrint('[$tag][$stage] $data');
  }
}

void logProductStationMappingCacheWrite({
  required String productId,
  required String productName,
  required String normalizedName,
  required String stationId,
  required String stationName,
  required String stationCode,
  required String source,
}) {
  kitchenTraceJsonLog('ProductStationMapping', 'CacheWrite', <String, Object?>{
    'productId': productId,
    'productName': productName,
    'normalizedName': normalizedName,
    'stationId': stationId,
    'stationName': stationName,
    'stationCode': stationCode,
    'source': source,
  });
}

void logProductStationMappingCacheHydrate({
  required String restaurantId,
  required int mappingCount,
  required List<String> productNameKeys,
  required List<String> productIdKeys,
  required bool fromDisk,
  String? error,
}) {
  kitchenTraceJsonLog('ProductStationMapping', 'CacheHydrate', <String, Object?>{
    'restaurantId': restaurantId,
    'mappingCount': mappingCount,
    'productNameKeys': productNameKeys,
    'productIdKeys': productIdKeys,
    'fromDisk': fromDisk,
    if (error != null) 'error': error,
  });
}

void logKitchenOrderNumberFields({
  required Map<String, dynamic> payload,
  String? printedOrderNo,
}) {
  kitchenTraceJsonLog('KitchenPrintPayload', 'OrderNumberFields', <String, Object?>{
    'daily_order_no': payload['daily_order_no'] ?? '',
    'kitchen_order_no': payload['kitchen_order_no'] ?? '',
    'order_number': payload['order_number'] ?? '',
    'order_no': payload['order_no'] ?? '',
    'waiter_name': payload['waiter_name'] ?? '',
    'printed_order_no':
        printedOrderNo ?? payload['printed_order_no'] ?? payload['order_no'] ?? '',
  });
}

void logHubStationResolveAttempt({
  required String rawName,
  required String normalizedName,
  required bool hasProductId,
  required bool foundByProductId,
  required bool foundByProductName,
  required List<String> cacheProductNameKeys,
}) {
  kitchenTraceJsonLog('KitchenPrintPayload', 'HubStationResolveAttempt', <String, Object?>{
    'rawName': rawName,
    'normalizedName': normalizedName,
    'hasProductId': hasProductId,
    'foundByProductId': foundByProductId,
    'foundByProductName': foundByProductName,
    'cacheProductNameKeys': cacheProductNameKeys,
  });
}

void logProductStationMappingLoaded({
  required String productId,
  required String productName,
  required String stationId,
  required String stationName,
  required String stationCode,
  required String source,
}) {
  kitchenTraceJsonLog('ProductStationMapping', 'Loaded', <String, Object?>{
    'productId': productId,
    'productName': productName,
    'stationId': stationId,
    'stationName': stationName,
    'stationCode': stationCode,
    'source': source,
  });
}

void logGarsonProductStationFields({
  required String productId,
  required String productName,
  required String stationId,
  required String stationName,
  required String stationCode,
}) {
  kitchenTraceJsonLog('GarsonProduct', 'StationFields', <String, Object?>{
    'productId': productId,
    'productName': productName,
    'stationId': stationId,
    'stationName': stationName,
    'stationCode': stationCode,
  });
}

void logGarsonOrderItemStationAttached(Map<String, dynamic> item) {
  kitchenTraceJsonLog('GarsonOrderItem', 'StationAttached', <String, Object?>{
    'productId': item['product_id'] ?? '',
    'name': item['name'] ?? item['item_name'] ?? '',
    'station_id': item['station_id'] ?? '',
    'station_name': item['station_name'] ?? '',
    'station_code': item['station_code'] ?? '',
    'kitchen_station_name': item['kitchen_station_name'] ?? '',
    'table_area_name': item['table_area_name'] ?? '',
  });
}

void logKitchenDispatchPath({
  required String path,
  required bool physicallyDispatched,
  required String reason,
  required int itemCount,
  String? traceId,
}) {
  kitchenTraceJsonLog('KitchenDispatch', 'Path', <String, Object?>{
    'path': path,
    'physicallyDispatched': physicallyDispatched,
    'reason': reason,
    'itemCount': itemCount,
    if (traceId != null && traceId.isNotEmpty) 'traceId': traceId,
  });
}

void logKitchenRoutingGroupInput(Map<String, dynamic> item) {
  kitchenTraceJsonLog('KitchenRouting', 'GroupInput', <String, Object?>{
    'productId': item['product_id'] ?? '',
    'name': item['name'] ?? item['item_name'] ?? item['product_name'] ?? '',
    'station_id': item['station_id'] ?? '',
    'station_name': item['station_name'] ?? '',
    'station_code': item['station_code'] ?? '',
    'table_area_name': item['table_area_name'] ?? '',
  });
}

void logKitchenRoutingGroupCreated({
  required String groupKey,
  required String stationId,
  required String stationName,
  required String stationCode,
  required int itemCount,
}) {
  kitchenTraceJsonLog('KitchenRouting', 'GroupCreated', <String, Object?>{
    'groupKey': groupKey,
    'stationId': stationId,
    'stationName': stationName,
    'stationCode': stationCode,
    'itemCount': itemCount,
  });
}

void logReceiptFinalBeforeBridge({
  required String path,
  required Map<String, dynamic> payload,
}) {
  final rawItems = payload['items'];
  final itemSnapshots = <Map<String, Object?>>[];
  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      itemSnapshots.add(<String, Object?>{
        'name': map['name'] ?? '',
        'display_label': map['display_label'] ?? '',
        'amount_label': map['amount_label'] ?? '',
      });
    }
  }
  kitchenTraceJsonLog('ReceiptPrintPayload', 'FinalBeforeBridge', <String, Object?>{
    'path': path,
    'items': itemSnapshots,
  });
}

void logKitchenFinalBeforeBridge({
  required String path,
  required Map<String, dynamic> payload,
}) {
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
  kitchenTraceJsonLog('KitchenPrintPayload', 'FinalBeforeBridge', <String, Object?>{
    'path': path,
    'title': payload['title'] ?? '',
    'area_name': payload['area_name'] ?? '',
    'station_name': payload['station_name'] ?? '',
    'station_code': payload['station_code'] ?? '',
    'kitchen_ticket_header': payload['kitchen_ticket_header'] ?? '',
    'table_area_name': payload['table_area_name'] ?? '',
    'items': itemSnapshots,
  });
  detectTableAreaUsedAsHeader(payload, where: 'logKitchenFinalBeforeBridge');
}

/// Masa alanı fiş başlığı olarak kullanıldıysa uyarı basar.
void detectTableAreaUsedAsHeader(
  Map<String, dynamic> payload, {
  required String where,
}) {
  final tableArea =
      payload['table_area_name']?.toString().trim() ?? '';
  if (tableArea.isEmpty) return;

  final headerCandidates = <String, String>{
    'area_name': payload['area_name']?.toString().trim() ?? '',
    'station_name': payload['station_name']?.toString().trim() ?? '',
    'kitchen_ticket_header':
        payload['kitchen_ticket_header']?.toString().trim() ?? '',
    'title': payload['title']?.toString().trim() ?? '',
  };

  for (final entry in headerCandidates.entries) {
    final value = entry.value;
    if (value.isEmpty) continue;
    if (value.toLowerCase() == tableArea.toLowerCase()) {
      kitchenTraceJsonLog(
        'KitchenPrintPayload',
        'BUG_TABLE_AREA_USED_AS_HEADER',
        <String, Object?>{
          'tableAreaName': tableArea,
          'where': '$where.${entry.key}',
          'field': entry.key,
          'value': value,
        },
      );
    }
  }

  final items = payload['items'];
  if (items is! List) return;
  for (final raw in items) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final itemArea = map['area_name']?.toString().trim() ?? '';
    if (itemArea.isNotEmpty &&
        itemArea.toLowerCase() == tableArea.toLowerCase()) {
      kitchenTraceJsonLog(
        'KitchenPrintPayload',
        'BUG_TABLE_AREA_USED_AS_HEADER',
        <String, Object?>{
          'tableAreaName': tableArea,
          'where': '$where.items.area_name',
          'itemName': map['name'] ?? map['item_name'] ?? '',
        },
      );
    }
  }
}

String productionHeaderFromItem(
  Map<String, dynamic> item, {
  Map<String, String>? stationCodesById,
}) {
  return KitchenTicketHeaderResolver.productionHeaderLabel(
    stationName: item['station_name']?.toString() ?? '',
    stationCode: item['station_code']?.toString() ??
        (stationCodesById?[item['station_id']?.toString() ?? ''] ?? ''),
  );
}
