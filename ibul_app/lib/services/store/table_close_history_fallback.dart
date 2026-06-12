import 'table_order_history_utils.dart';

class TableCloseHistoryFallbackPlan {
  const TableCloseHistoryFallbackPlan({
    required this.ordersToArchive,
    required this.grandTotal,
    required this.hasRecentAggregateMatch,
  });

  final List<Map<String, dynamic>> ordersToArchive;
  final double grandTotal;
  final bool hasRecentAggregateMatch;

  bool get shouldInsert =>
      ordersToArchive.isNotEmpty && grandTotal > 0 && !hasRecentAggregateMatch;
}

TableCloseHistoryFallbackPlan planTableCloseHistoryFallback({
  required List<Map<String, dynamic>> closedOrders,
  required List<Map<String, dynamic>> recentHistoryRows,
}) {
  final archivedOrderIds = _collectArchivedOrderIds(recentHistoryRows);
  final closedOrderIds = closedOrders
      .map((order) => order['id']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  final ordersToArchive = <Map<String, dynamic>>[];
  for (final order in closedOrders) {
    final orderId = order['id']?.toString().trim() ?? '';
    final alreadyArchivedOrder =
        orderId.isNotEmpty && archivedOrderIds.contains(orderId);
    if (alreadyArchivedOrder) continue;
    ordersToArchive.add(Map<String, dynamic>.from(order));
  }

  final grandTotal = ordersToArchive.fold<double>(
    0,
    (sum, order) => sum + TableOrderHistoryUtils.revenue(order),
  );

  final hasRecentAggregateMatch =
      !_hasReliableOrderIdComparison(closedOrderIds, archivedOrderIds) &&
      grandTotal > 0 &&
      recentHistoryRows.any((row) {
        final revenue = TableOrderHistoryUtils.revenue(row);
        return (revenue - grandTotal).abs() <= 0.01;
      });

  return TableCloseHistoryFallbackPlan(
    ordersToArchive: ordersToArchive,
    grandTotal: grandTotal,
    hasRecentAggregateMatch: hasRecentAggregateMatch,
  );
}

Set<String> _collectArchivedOrderIds(List<Map<String, dynamic>> historyRows) {
  final ids = <String>{};
  for (final row in historyRows) {
    final originalOrderId = row['original_order_id']?.toString().trim() ?? '';
    if (originalOrderId.isNotEmpty) {
      ids.add(originalOrderId);
    }
    final archivedOrders = row['archived_orders'];
    if (archivedOrders is! List) continue;
    for (final entry in archivedOrders) {
      if (entry is! Map) continue;
      for (final key in const ['id', 'original_order_id', 'order_id']) {
        final value = entry[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          ids.add(value);
        }
      }
    }
  }
  return ids;
}

bool _hasReliableOrderIdComparison(
  Set<String> closedOrderIds,
  Set<String> archivedOrderIds,
) {
  return closedOrderIds.isNotEmpty && archivedOrderIds.isNotEmpty;
}
