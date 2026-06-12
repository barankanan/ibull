import 'garson_active_orders_fetch.dart';

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
  required Iterable<Map<String, dynamic>> orders,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final todayStart = DateTime(
    resolvedNow.year,
    resolvedNow.month,
    resolvedNow.day,
  );
  final todayEnd = DateTime(
    resolvedNow.year,
    resolvedNow.month,
    resolvedNow.day,
    23,
    59,
    59,
  );
  final openTableNumbers = <int>{};
  var sentToKitchen = 0;
  var cancelled = 0;
  var todayActiveOrders = 0;

  for (final order in orders) {
    final rawStatus = resolveGarsonOrderStatusField(order).toLowerCase().trim();
    if (isGarsonTerminalOrderStatus(rawStatus)) continue;

    final mappedStatus = _mapGarsonMetricStatus(rawStatus);
    if (mappedStatus == 'cancelled') {
      cancelled++;
      continue;
    }

    final tableNumber =
        int.tryParse(order['table_number']?.toString() ?? '') ?? 0;
    if (tableNumber > 0) openTableNumbers.add(tableNumber);

    if (mappedStatus == 'preparing') {
      sentToKitchen++;
    }

    final createdAt = DateTime.tryParse(
      order['created_at']?.toString() ?? '',
    )?.toLocal();
    if (createdAt != null &&
        !createdAt.isBefore(todayStart) &&
        !createdAt.isAfter(todayEnd)) {
      todayActiveOrders++;
    }
  }

  return GarsonActiveTableMetrics(
    openTableCount: openTableNumbers.length,
    sentToKitchenCount: sentToKitchen,
    cancelledCount: cancelled,
    todayActiveOrderCount: todayActiveOrders,
  );
}

String _mapGarsonMetricStatus(String rawStatus) {
  switch (rawStatus) {
    case 'cancelled':
    case 'canceled':
    case 'void':
    case 'refunded':
    case 'deleted':
      return 'cancelled';
    case 'done':
    case 'sent':
    case 'kitchen_sent':
    case 'preparing':
    case 'ready':
      return 'preparing';
    default:
      return 'new';
  }
}
