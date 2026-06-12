import 'table_order_history_utils.dart';

class TableCloseHistoryFallbackPlan {
  const TableCloseHistoryFallbackPlan({
    required this.shouldInsert,
    required this.ordersToArchive,
    required this.grandTotal,
  });

  final bool shouldInsert;
  final List<Map<String, dynamic>> ordersToArchive;
  final double grandTotal;
}

TableCloseHistoryFallbackPlan planTableCloseHistoryFallback({
  required List<Map<String, dynamic>> closedOrders,
  required List<Map<String, dynamic>> recentHistoryRows,
}) {
  final ordersToArchive = closedOrders
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
  if (ordersToArchive.isEmpty) {
    return const TableCloseHistoryFallbackPlan(
      shouldInsert: false,
      ordersToArchive: <Map<String, dynamic>>[],
      grandTotal: 0,
    );
  }

  final orderIds = ordersToArchive
      .map((order) => order['id']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
  final sessionKeys = ordersToArchive
      .map((order) => order['session_key']?.toString().trim() ?? '')
      .where((key) => key.isNotEmpty)
      .toSet();

  final duplicateExists = recentHistoryRows.any((row) {
    final originalOrderId = row['original_order_id']?.toString().trim() ?? '';
    if (originalOrderId.isNotEmpty && orderIds.contains(originalOrderId)) {
      return true;
    }

    final sessionKey = row['session_key']?.toString().trim() ?? '';
    if (sessionKey.isNotEmpty && sessionKeys.contains(sessionKey)) {
      return true;
    }

    final archivedOrders = TableOrderHistoryUtils.parseJsonList(
      row['archived_orders'],
    );
    for (final archivedOrder in archivedOrders) {
      final archivedId = archivedOrder['id']?.toString().trim() ?? '';
      if (archivedId.isNotEmpty && orderIds.contains(archivedId)) {
        return true;
      }
    }
    return false;
  });

  final grandTotal = ordersToArchive.fold<double>(0, (sum, order) {
    return sum + TableOrderHistoryUtils.revenue(order);
  });

  return TableCloseHistoryFallbackPlan(
    shouldInsert: !duplicateExists,
    ordersToArchive: ordersToArchive,
    grandTotal: grandTotal,
  );
}
