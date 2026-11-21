import '../../../../services/restaurant_offline/restaurant_offline_models.dart';

/// Genel Bakış'ın çevrimdışı verisi. Her rakamın KAYNAĞI ayrıdır; gelir uydurulmaz.
class OfflineOverviewData {
  const OfflineOverviewData({
    required this.totalTables,
    required this.occupiedTables,
    required this.freeTables,
    required this.cloudOpenOrders,
    required this.localOrders,
    required this.localKitchenSent,
    required this.localPrintWaiting,
    required this.localPrintUnverified,
    required this.pendingSync,
    required this.syncFailed,
    required this.localProvisionalTotal,
    required this.cloudOpenBillTotal,
    required this.lastCloudSnapshotAt,
    required this.tablesKnown,
  });

  /// Son bulut eşitlemesindeki masa sayısı; hiç eşitlenmediyse 0 ve [tablesKnown] false.
  final int totalTables;
  final int occupiedTables;
  final int freeTables;
  final bool tablesKnown;

  /// Son bulut anlık görüntüsündeki açık sipariş sayısı (güncel olmayabilir).
  final int cloudOpenOrders;

  /// Bu cihazın yerel günlüğündeki siparişler.
  final int localOrders;
  final int localKitchenSent;
  final int localPrintWaiting;
  final int localPrintUnverified;
  final int pendingSync;
  final int syncFailed;

  /// Senkronize OLMAMIŞ yerel siparişlerin tutarı. Tahsilat DEĞİLDİR.
  final double localProvisionalTotal;

  /// Son bulut anlık görüntüsündeki açık adisyon kalem toplamı. Tahsilat DEĞİLDİR.
  final double cloudOpenBillTotal;
  final DateTime? lastCloudSnapshotAt;
}

bool _closedStatus(String status) => const <String>{
      'closed',
      'paid',
      'cancelled',
      'canceled',
      'completed',
      'complete',
      'archived',
      'payment_completed',
      'completed_payment',
    }.contains(status.trim().toLowerCase());

double _itemsTotal(Object? items) {
  if (items is! List) return 0;
  var total = 0.0;
  for (final raw in items) {
    if (raw is! Map) continue;
    final line = raw['line_total'] ?? raw['total'];
    if (line is num) {
      total += line.toDouble();
      continue;
    }
    final price = raw['price'];
    final qty = raw['quantity'];
    if (price is num) total += price.toDouble() * (qty is num ? qty.toDouble() : 1);
  }
  return total;
}

int _tableNumber(Map<String, dynamic> row) {
  final v = row['table_number'];
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

OfflineOverviewData buildOfflineOverview({
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> cloudTableOrders,
  required List<RestaurantLocalOrderRecord> localOrders,
  required DateTime? cachedAt,
}) {
  final occupied = <int>{};
  var cloudOpen = 0;
  var cloudBill = 0.0;
  for (final order in cloudTableOrders) {
    if (_closedStatus(order['status']?.toString() ?? '')) continue;
    cloudOpen++;
    cloudBill += _itemsTotal(order['items']);
    final n = _tableNumber(order);
    if (n > 0) occupied.add(n);
  }
  var kitchenSent = 0, printWaiting = 0, printUnverified = 0;
  var pending = 0, failed = 0;
  var provisional = 0.0;
  var localCount = 0;
  for (final order in localOrders) {
    final synced = order.syncStatus == RestaurantLocalOrderSyncStatus.synced;
    if (!synced) {
      localCount++;
      provisional += order.total;
      if (order.tableNumber > 0) occupied.add(order.tableNumber);
      switch (order.syncStatus) {
        case RestaurantLocalOrderSyncStatus.syncFailed:
        case RestaurantLocalOrderSyncStatus.conflict:
          failed++;
        default:
          pending++;
      }
    }
    switch (order.printStatus) {
      case 'printed':
        kitchenSent++;
      case 'pending':
        printWaiting++;
      default:
        // failed, uncertain, dispatching: sonuç doğrulanamadı ya da başarısız.
        printUnverified++;
    }
  }
  final tableNumbers = <int>{
    for (final t in tables)
      if (_tableNumber(t) > 0) _tableNumber(t),
  };
  final known = tableNumbers.isNotEmpty;
  final occupiedKnown = occupied.where(tableNumbers.contains).length;
  return OfflineOverviewData(
    totalTables: tableNumbers.length,
    occupiedTables: known ? occupiedKnown : occupied.length,
    freeTables: known ? tableNumbers.length - occupiedKnown : 0,
    cloudOpenOrders: cloudOpen,
    localOrders: localCount,
    localKitchenSent: kitchenSent,
    localPrintWaiting: printWaiting,
    localPrintUnverified: printUnverified,
    pendingSync: pending,
    syncFailed: failed,
    localProvisionalTotal: provisional,
    cloudOpenBillTotal: cloudBill,
    lastCloudSnapshotAt: cachedAt,
    tablesKnown: known,
  );
}
