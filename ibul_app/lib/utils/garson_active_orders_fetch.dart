import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Active statuses used on live Garson / kitchen flows.
const Set<String> garsonActiveOrderStatuses = <String>{
  'new',
  'open',
  'pending',
  'kitchen_sent',
  'preparing',
  'in_progress',
  'waiting',
  'served',
  'active',
  'mutfaga_iletildi',
  'mutfakta',
  'hazirlaniyor',
  // RPC / table_orders production aliases
  'sent',
  'done',
  'confirmed',
};

/// Terminal statuses excluded from the Garson active-order board.
const Set<String> garsonTerminalOrderStatuses = <String>{
  'closed',
  'paid',
  'cancelled',
  'canceled',
  'completed',
  'complete',
  'completed_payment',
  'payment_completed',
  'archived',
};

bool isGarsonTerminalOrderStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return garsonTerminalOrderStatuses.contains(normalized);
}

bool isGarsonActiveOrderStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (garsonTerminalOrderStatuses.contains(normalized)) return false;
  if (garsonActiveOrderStatuses.contains(normalized)) return true;
  // Unknown non-terminal status: keep visible so raw_statuses log can surface it.
  return true;
}

/// Resolves the canonical Garson status for an order row.
///
/// BUG-FIX (Reopen Bug): the customer-facing `orders` table writes the live
/// state into BOTH `status` and `order_status` but legacy migrations may
/// leave one stale.  The previous implementation returned `order_status`
/// first and dropped the `status` check entirely — which meant a row with
/// `status='closed'` + `order_status='pending'` looked **active** on the
/// garson board even though the customer had been paid.
///
/// New contract: if EITHER field carries a terminal status, the row is
/// considered closed.  This makes the helper resistant to dual-source drift.
String resolveGarsonOrderStatusField(Map<String, dynamic> order) {
  final orderStatus = order['order_status']?.toString().trim() ?? '';
  final status = order['status']?.toString().trim() ?? '';
  // Terminal in either field wins — never let a non-terminal `order_status`
  // hide a terminal `status` (or vice versa).
  if (garsonTerminalOrderStatuses.contains(status.toLowerCase())) {
    return status;
  }
  if (garsonTerminalOrderStatuses.contains(orderStatus.toLowerCase())) {
    return orderStatus;
  }
  if (orderStatus.isNotEmpty) return orderStatus;
  return status.isEmpty ? 'sent' : status;
}

String garsonTableOrdersSnapshotQueryDescription({
  required String restaurantId,
  int? tableNumber,
}) {
  final tableFilter = tableNumber != null && tableNumber > 0
      ? " and table_number = $tableNumber"
      : '';
  return "from('table_orders').select().eq('seller_id', '$restaurantId')"
      "$tableFilter.order('created_at', ascending: false)";
}

String garsonRestaurantOrdersSnapshotQueryDescription({
  required String restaurantId,
}) {
  return "from('orders').select('id,restaurant_id,table_id,order_status,status,"
      "order_type,delivery_type,total_amount,created_at,updated_at,"
      "order_items(id,product_id,product_name,quantity,unit_price,line_total,item_note)') "
      ".eq('restaurant_id', '$restaurantId').or('order_type.eq.table,delivery_type.eq.table')"
      ".order('created_at', ascending: false).limit(50)";
}

String garsonActiveOrdersStatusFilterDescription() {
  return 'include ${garsonActiveOrderStatuses.join(', ')}; '
      'exclude ${garsonTerminalOrderStatuses.join(', ')}';
}

void logGarsonOrdersDebugSql({required String restaurantId}) {
  debugPrint(
    '[GARSON_ORDERS_DEBUG_SQL] '
    'restaurant_id=$restaurantId '
    'all_orders_query='
    "select id, restaurant_id, store_id, table_id, store_table_id, "
    "table_number, status, created_at, updated_at, "
    "jsonb_array_length(coalesce(items, '[]'::jsonb)) as item_count, "
    "total_amount, total from public.orders "
    "where restaurant_id = '$restaurantId' "
    "order by created_at desc limit 20",
  );
  debugPrint(
    '[GARSON_ORDERS_DEBUG_SQL] '
    'restaurant_id=$restaurantId '
    'active_orders_query='
    "select id, table_id, store_table_id, table_number, status, created_at, updated_at "
    "from public.orders "
    "where restaurant_id = '$restaurantId' "
    "and status not in ('closed','paid','cancelled','completed_payment','archived') "
    "order by created_at desc limit 20",
  );
  debugPrint(
    '[GARSON_ORDERS_DEBUG_SQL] '
    'restaurant_id=$restaurantId '
    'table_orders_query='
    "select id, seller_id, table_number, status, created_at, updated_at, "
    "jsonb_array_length(coalesce(items, '[]'::jsonb)) as item_count "
    "from public.table_orders "
    "where seller_id = '$restaurantId' "
    "order by created_at desc limit 20",
  );
}

void logGarsonActiveOrdersFetchStart({
  required String restaurantId,
  required String source,
  required String query,
  String statusFilter = '',
  String tableFilter = '',
}) {
  debugPrint(
    '[GARSON_ACTIVE_ORDERS_FETCH_START] '
    'restaurant_id=$restaurantId '
    'source=$source '
    'query=$query '
    'status_filter=${statusFilter.isEmpty ? garsonActiveOrdersStatusFilterDescription() : statusFilter} '
    'table_filter=${tableFilter.isEmpty ? '-' : tableFilter}',
  );
}

void logGarsonActiveOrdersFetchResult({
  required String restaurantId,
  required String source,
  required List<Map<String, dynamic>> orders,
}) {
  final first = orders.isNotEmpty ? orders.first : null;
  final rawStatuses = orders
      .map((order) => resolveGarsonOrderStatusField(order))
      .toSet()
      .toList(growable: false)
    ..sort();
  final firstTotal = first == null
      ? '-'
      : _parseMoney(first['total'] ?? first['grand_total'] ?? first['total_amount']);
  debugPrint(
    '[GARSON_ACTIVE_ORDERS_FETCH_RESULT] '
    'restaurant_id=$restaurantId '
    'source=$source '
    'orders_count=${orders.length} '
    'raw_statuses=$rawStatuses '
    'first_order_id=${first?['id'] ?? '-'} '
    'first_status=${first == null ? '-' : resolveGarsonOrderStatusField(first)} '
    'first_table_id=${first?['table_id'] ?? '-'} '
    'first_store_table_id=${first?['store_table_id'] ?? first?['table_id'] ?? '-'} '
    'first_table_number=${first?['table_number'] ?? '-'} '
    'first_items_count=${garsonExtractActiveOrderItems(first).length} '
    'first_total=$firstTotal',
  );
}

void logGarsonActiveOrdersFetchError({
  required String restaurantId,
  required String source,
  required Object error,
  StackTrace? stack,
}) {
  final code = _extractErrorCode(error);
  debugPrint(
    '[GARSON_ACTIVE_ORDERS_FETCH_ERROR] '
    'restaurant_id=$restaurantId '
    'source=$source '
    'error_type=${error.runtimeType} '
    'error_code=${code.isEmpty ? '-' : code} '
    'error_message=$error '
    'stack=${stack ?? StackTrace.current}',
  );
}

void logGarsonOrdersStreamError({
  required String restaurantId,
  required Object error,
  StackTrace? stack,
  String source = 'table_orders_stream',
}) {
  final code = _extractErrorCode(error);
  debugPrint(
    '[GARSON_ORDERS_STREAM_ERROR] '
    'restaurant_id=$restaurantId '
    'source=$source '
    'query=${garsonTableOrdersSnapshotQueryDescription(restaurantId: restaurantId)} '
    'error_type=${error.runtimeType} '
    'error_code=${code.isEmpty ? '-' : code} '
    'error_message=$error '
    'stack=${stack ?? StackTrace.current}',
  );
}

String _extractErrorCode(Object error) {
  try {
    final dynamicCode = (error as dynamic).code;
    if (dynamicCode != null) return dynamicCode.toString();
  } catch (_) {}
  return '';
}

int _parsePositiveInt(dynamic value) {
  if (value is int) return value > 0 ? value : 0;
  if (value is num) {
    final parsed = value.toInt();
    return parsed > 0 ? parsed : 0;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> garsonExtractActiveOrderItems(
  Map<String, dynamic>? order,
) {
  if (order == null) return const <Map<String, dynamic>>[];
  final raw = order['items'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<Map<String, dynamic>> normalizeRestaurantOrderItems(
  List<dynamic> rawItems,
) {
  return rawItems
      .whereType<Map>()
      .map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final quantity = _parsePositiveInt(item['quantity']);
        final safeQty = quantity > 0 ? quantity : 1;
        final unitPrice = _parseMoney(item['unit_price'] ?? item['price']);
        final lineTotal = _parseMoney(
          item['line_total'] ?? item['total_price'] ?? (unitPrice * safeQty),
        );
        return <String, dynamic>{
          'id': item['id'],
          'product_id': item['product_id'],
          'name': item['product_name'] ?? item['name'] ?? 'Ürün',
          'quantity': safeQty,
          'price': unitPrice,
          'line_total': lineTotal,
          if (item['item_note'] case final note?)
            if (note.toString().trim().isNotEmpty) 'notes': note,
        };
      })
      .toList(growable: false);
}

double _parseMoney(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> buildGarsonBoardOrderModel({
  required String orderId,
  required String restaurantId,
  required String tableId,
  required int tableNumber,
  required String displayLabel,
  required String areaName,
  required int areaTableNumber,
  required String status,
  required List<Map<String, dynamic>> items,
  required double total,
  required dynamic createdAt,
  required dynamic updatedAt,
  required String sourceTable,
  String? placementSource,
}) {
  final normalizedLabel = displayLabel.trim();
  final normalizedArea = areaName.trim();
  return <String, dynamic>{
    'id': orderId,
    'order_id': orderId,
    'restaurant_id': restaurantId,
    'seller_id': restaurantId,
    if (tableId.isNotEmpty) 'table_id': tableId,
    if (tableId.isNotEmpty) 'store_table_id': tableId,
    if (tableNumber > 0) 'table_number': tableNumber,
    if (normalizedLabel.isNotEmpty) ...<String, dynamic>{
      'display_table_label': normalizedLabel,
      'table_display_name': normalizedLabel,
      'table_name': normalizedLabel,
    },
    if (normalizedArea.isNotEmpty) ...<String, dynamic>{
      'area_name': normalizedArea,
      'table_area_name': normalizedArea,
    },
    if (areaTableNumber > 0) 'area_table_number': areaTableNumber,
    'status': status,
    'items': items,
    'total': total,
    'grand_total': total,
    'created_at': createdAt,
    'updated_at': updatedAt,
    if (placementSource != null && placementSource.isNotEmpty)
      'placement_source': placementSource,
    '_garson_source_table': sourceTable,
  };
}

List<Map<String, dynamic>> _extractTableOrderItems(Map<String, dynamic> order) {
  dynamic raw = order['items'];
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic>? normalizeTableOrderToGarsonBoardOrder({
  required Map<String, dynamic> order,
  Map<String, dynamic>? storeTable,
}) {
  final orderId = order['id']?.toString().trim() ?? '';
  if (orderId.isEmpty) return null;

  final status = resolveGarsonOrderStatusField(order);
  if (!isGarsonActiveOrderStatus(status)) return null;

  final restaurantId =
      order['restaurant_id']?.toString().trim() ??
      order['seller_id']?.toString().trim() ??
      '';
  final tableId =
      order['table_id']?.toString().trim() ??
      order['store_table_id']?.toString().trim() ??
      storeTable?['id']?.toString().trim() ??
      '';
  final tableNumber = _parsePositiveInt(
    storeTable?['table_number'] ?? order['table_number'],
  );
  if (tableId.isEmpty && tableNumber <= 0) return null;

  final displayLabel =
      order['display_table_label'] ??
      order['table_display_name'] ??
      order['table_name'] ??
      storeTable?['display_label'] ??
      storeTable?['table_name'] ??
      (tableNumber > 0 ? 'Masa $tableNumber' : '');
  final areaName =
      order['area_name'] ??
      order['table_area_name'] ??
      storeTable?['area_name'] ??
      '';
  final areaTableNumber = _parsePositiveInt(
    order['area_table_number'] ?? storeTable?['area_table_number'],
  );
  final items = _extractTableOrderItems(order);
  final total = _parseMoney(
    order['total'] ?? order['grand_total'] ?? order['total_amount'],
  );

  return buildGarsonBoardOrderModel(
    orderId: orderId,
    restaurantId: restaurantId,
    tableId: tableId,
    tableNumber: tableNumber,
    displayLabel: displayLabel?.toString() ?? '',
    areaName: areaName?.toString() ?? '',
    areaTableNumber: areaTableNumber,
    status: status,
    items: items,
    total: total,
    createdAt: order['created_at'],
    updatedAt: order['updated_at'] ?? order['created_at'],
    sourceTable: 'table_orders',
    placementSource: order['placement_source']?.toString(),
  );
}

Map<String, dynamic>? normalizeRestaurantOrderToGarsonTableOrder({
  required Map<String, dynamic> order,
  required List<Map<String, dynamic>> items,
  Map<String, dynamic>? storeTable,
}) {
  final status = resolveGarsonOrderStatusField(order);
  if (!isGarsonActiveOrderStatus(status)) return null;

  final orderId = order['id']?.toString().trim() ?? '';
  if (orderId.isEmpty) return null;

  final tableId =
      order['table_id']?.toString().trim() ??
      storeTable?['id']?.toString().trim() ??
      '';
  final tableNumber = _parsePositiveInt(
    storeTable?['table_number'] ?? order['table_number'],
  );
  if (tableId.isEmpty && tableNumber <= 0) return null;

  final restaurantId = order['restaurant_id']?.toString().trim() ?? '';
  final displayLabel =
      storeTable?['display_label'] ?? storeTable?['table_name'] ?? '';
  final areaName = storeTable?['area_name'] ?? storeTable?['table_area_name'] ?? '';
  final areaTableNumber = _parsePositiveInt(
    storeTable?['area_table_number'] ?? order['area_table_number'],
  );
  final total = _parseMoney(order['total_amount'] ?? order['total']);

  return buildGarsonBoardOrderModel(
    orderId: orderId,
    restaurantId: restaurantId,
    tableId: tableId,
    tableNumber: tableNumber,
    displayLabel: displayLabel?.toString() ?? '',
    areaName: areaName?.toString() ?? '',
    areaTableNumber: areaTableNumber,
    status: status,
    items: items,
    total: total,
    createdAt: order['created_at'],
    updatedAt: order['updated_at'] ?? order['created_at'],
    sourceTable: 'orders',
    placementSource: 'orders_table',
  );
}

bool isGarsonRestaurantTableOrderRow(Map<String, dynamic> order) {
  final orderType = order['order_type']?.toString().trim().toLowerCase() ?? '';
  final deliveryType =
      order['delivery_type']?.toString().trim().toLowerCase() ?? '';
  return orderType == 'table' || deliveryType == 'table';
}

List<Map<String, dynamic>> mergeGarsonActiveOrderSources({
  required List<Map<String, dynamic>> tableOrders,
  required List<Map<String, dynamic>> restaurantOrders,
}) {
  final merged = <Map<String, dynamic>>[];

  final occupiedTableIds = <String>{};
  final occupiedTableNumbers = <int>{};
  for (final order in tableOrders) {
    final tableId =
        order['table_id']?.toString().trim() ??
        order['store_table_id']?.toString().trim() ??
        '';
    final tableNumber = _parsePositiveInt(order['table_number']);
    if (tableId.isNotEmpty) occupiedTableIds.add(tableId);
    if (tableNumber > 0) occupiedTableNumbers.add(tableNumber);
    merged.add(Map<String, dynamic>.from(order));
  }

  for (final order in restaurantOrders) {
    final tableId =
        order['table_id']?.toString().trim() ??
        order['store_table_id']?.toString().trim() ??
        '';
    final tableNumber = _parsePositiveInt(order['table_number']);
    if (tableId.isNotEmpty && occupiedTableIds.contains(tableId)) continue;
    if (tableNumber > 0 && occupiedTableNumbers.contains(tableNumber)) {
      continue;
    }
    merged.add(Map<String, dynamic>.from(order));
    if (tableId.isNotEmpty) occupiedTableIds.add(tableId);
    if (tableNumber > 0) occupiedTableNumbers.add(tableNumber);
  }

  return merged;
}

List<Map<String, dynamic>> filterGarsonActiveOrdersByTableNumber({
  required List<Map<String, dynamic>> orders,
  required int tableNumber,
}) {
  if (tableNumber <= 0) return orders;
  return orders
      .where((order) => _parsePositiveInt(order['table_number']) == tableNumber)
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
}
