import 'package:flutter/foundation.dart';

import '../order_print_job_service.dart';
import 'restaurant_connectivity_service.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_offline_models.dart';

/// V1 sync skeleton: marks pending orders and attempts Supabase replay when online.
class RestaurantOfflineSyncService {
  RestaurantOfflineSyncService({
    RestaurantLocalOrderQueueService? orderQueue,
    OrderPrintJobService? orderPrintJobService,
    RestaurantConnectivityService? connectivityService,
  }) : _orderQueue = orderQueue ?? RestaurantLocalOrderQueueService(),
       _orderPrintJobService = orderPrintJobService ?? OrderPrintJobService(),
       _connectivity =
           connectivityService ?? RestaurantConnectivityService.instance;

  final RestaurantLocalOrderQueueService _orderQueue;
  final OrderPrintJobService _orderPrintJobService;
  final RestaurantConnectivityService _connectivity;
  final Set<String> _syncInFlight = <String>{};

  Future<int> pendingCount(String restaurantId) =>
      _orderQueue.pendingSyncCount(restaurantId);

  Future<List<RestaurantLocalOrderRecord>> pendingOrders(String restaurantId) =>
      _orderQueue.pendingSyncOrders(restaurantId);

  Future<int> syncPendingOrders({
    required String restaurantId,
    int limit = 10,
  }) async {
    await _connectivity.refresh();
    if (!_connectivity.hasNetwork || !_connectivity.supabaseReachable) {
      return 0;
    }

    final pending = await _orderQueue.pendingSyncOrders(restaurantId);
    if (pending.isEmpty) return 0;

    _connectivity.setSyncing(true);
    var syncedCount = 0;
    try {
      for (final order in pending.take(limit)) {
        if (_syncInFlight.contains(order.localOrderId)) continue;
        _syncInFlight.add(order.localOrderId);
        try {
          final result = await _orderPrintJobService.dispatchNewOrder(
            restaurantId: order.restaurantId,
            tableNumber: order.tableNumber,
            items: order.items,
            waiterId: order.waiterId.isEmpty ? null : order.waiterId,
            waiterName: order.waiterName.isEmpty ? null : order.waiterName,
            notes: order.notes.isEmpty ? null : order.notes,
            jobType: 'new_order',
            garsonDesktopFastKitchen: true,
            skipOfflineFallback: true,
            localOrderId: order.localOrderId,
          );
          final remoteOrderId = result.orderId ?? '';
          if (remoteOrderId.isEmpty) {
            await _orderQueue.update(
              restaurantId: restaurantId,
              order: order.copyWith(
                syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
                syncError: 'Supabase sipariş kimliği alınamadı.',
                updatedAt: DateTime.now(),
              ),
            );
            continue;
          }
          await _orderQueue.markSynced(
            restaurantId: restaurantId,
            localOrderId: order.localOrderId,
            remoteOrderId: remoteOrderId,
          );
          syncedCount++;
        } catch (error, stackTrace) {
          debugPrint(
            '[RestaurantOfflineSync] failed localOrder=${order.localOrderId} error=$error',
          );
          debugPrintStack(stackTrace: stackTrace);
          await _orderQueue.update(
            restaurantId: restaurantId,
            order: order.copyWith(
              syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
              syncError: error.toString(),
              updatedAt: DateTime.now(),
            ),
          );
        } finally {
          _syncInFlight.remove(order.localOrderId);
        }
      }
    } finally {
      _connectivity.setSyncing(false);
    }
    return syncedCount;
  }

  void clearSyncInFlightForTests() {
    _syncInFlight.clear();
  }
}
