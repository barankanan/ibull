class GarsonActiveTableMetrics {
  const GarsonActiveTableMetrics({
    required this.openTableCount,
    required this.sentToKitchenCount,
    required this.cancelledCount,
    required this.todayActiveOrderCount,
  });

  final int openTableCount;
  final int sentToKitchenCount;
  final int cancelledCount;
  final int todayActiveOrderCount;
}

GarsonActiveTableMetrics computeGarsonActiveTableMetrics({
  required List<Map<String, dynamic>> orders,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

  final openTables = <String>{};
  final sentToKitchenTables = <String>{};
  var cancelledCount = 0;
  var todayActiveOrderCount = 0;

  for (final order in orders) {
    final status = (order['status'] ?? '').toString().trim().toLowerCase();
    final tableKey = _tableKey(order);
    final createdAt = DateTime.tryParse(
      order['created_at']?.toString() ?? '',
    )?.toLocal();

    if (status == 'cancelled' || status == 'canceled') {
      cancelledCount++;
      continue;
    }

    final isTerminal =
        status == 'closed' ||
        status == 'paid' ||
        status == 'completed' ||
        status == 'completed_payment' ||
        status == 'archived';
    if (!isTerminal) {
      openTables.add(tableKey);
    }

    final sentToKitchen =
        status == 'done' ||
        status == 'sent' ||
        status == 'kitchen_sent' ||
        status == 'preparing' ||
        status == 'ready';
    if (sentToKitchen) {
      sentToKitchenTables.add(tableKey);
    }

    final isToday =
        createdAt != null &&
        !createdAt.isBefore(todayStart) &&
        !createdAt.isAfter(todayEnd);
    if (isToday && !isTerminal) {
      todayActiveOrderCount++;
    }
  }

  return GarsonActiveTableMetrics(
    openTableCount: openTables.length,
    sentToKitchenCount: sentToKitchenTables.length,
    cancelledCount: cancelledCount,
    todayActiveOrderCount: todayActiveOrderCount,
  );
}

String _tableKey(Map<String, dynamic> order) {
  final tableNumber = order['table_number']?.toString().trim() ?? '';
  if (tableNumber.isNotEmpty && tableNumber != '0') return tableNumber;

  for (final key in const <String>[
    'table_id',
    'store_table_id',
    'display_table_label',
    'table_display_name',
    'table_name',
    'id',
  ]) {
    final value = order[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }

  return 'unknown';
}
