import '../utils/kitchen_print_dedup.dart';
import 'print_job_identity.dart';
import 'restaurant_offline/restaurant_local_order_queue_service.dart';

/// Remembers a locally finished ticket before the cloud job exists.
/// The key is the order and revision, not an item fingerprint.
void rememberLocalTicketBarrier({
  required String restaurantId,
  required int tableNumber,
  required List<Map<String, dynamic>> items,
  required String printStatus,
  String orderKey = '',
  String revision = '1',
  String jobType = 'new_order',
}) {
  final status = printStatus.trim();
  if (status != 'printed' && status != 'uncertain' && status != 'forwarded') {
    return;
  }
  final resolvedOrder = orderKey.trim().isEmpty
      ? '$restaurantId:$tableNumber'
      : orderKey.trim();
  final stations = <String>{};
  for (final item in items) {
    stations.add(item['station_id']?.toString().trim() ?? '');
  }
  if (stations.isEmpty) stations.add('');
  for (final stationId in stations) {
    PrintJobLedger.remember(
      identity: buildPrintJobIdentity(
        restaurantId: restaurantId,
        orderKey: resolvedOrder,
        revision: revision,
        stationId: stationId,
        jobType: jobType,
      ),
      orderKey: resolvedOrder,
      printStatus: status,
    );
  }
  // The short in-process barrier still collapses a same-process double send.
  KitchenLanPrintBarrier.rememberDurable(resolvedOrder);
}

Future<void> hydrateLocalPrintBarrier(String restaurantId) async {
  final orders = await RestaurantLocalOrderQueueService().list(restaurantId);
  for (final order in orders) {
    rememberLocalTicketBarrier(
      restaurantId: order.restaurantId,
      tableNumber: order.tableNumber,
      items: order.items,
      printStatus: order.printStatus,
      orderKey: order.localOrderId,
    );
  }
}
