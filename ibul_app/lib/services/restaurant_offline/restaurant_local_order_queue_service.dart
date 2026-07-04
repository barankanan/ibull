import '../../core/secure_local_store.dart';
import 'restaurant_offline_models.dart';

class RestaurantLocalOrderQueueService {
  RestaurantLocalOrderQueueService({SecureLocalStore? store})
    : _store = store ?? SecureLocalStore.instance;

  final SecureLocalStore _store;
  static final Map<String, List<RestaurantLocalOrderRecord>> _memory =
      <String, List<RestaurantLocalOrderRecord>>{};

  static String storageKey(String restaurantId) =>
      'restaurant_offline_order_queue_v1_${restaurantId.trim()}';

  Future<List<RestaurantLocalOrderRecord>> list(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return const <RestaurantLocalOrderRecord>[];
    if (_memory.containsKey(id)) {
      return List<RestaurantLocalOrderRecord>.from(_memory[id]!);
    }
    final raw = await _store.readJson(storageKey(id));
    final rows = raw is Map ? raw['orders'] : null;
    final parsed = _readMapList(rows)
        .map(RestaurantLocalOrderRecord.fromJson)
        .toList(growable: false);
    _memory[id] = parsed;
    return parsed;
  }

  Future<RestaurantLocalOrderRecord?> getByLocalId({
    required String restaurantId,
    required String localOrderId,
  }) async {
    final orders = await list(restaurantId);
    for (final order in orders) {
      if (order.localOrderId == localOrderId) return order;
    }
    return null;
  }

  Future<RestaurantLocalOrderRecord> enqueue({
    required RestaurantLocalOrderRecord order,
  }) async {
    final id = order.restaurantId.trim();
    if (id.isEmpty || order.localOrderId.trim().isEmpty) {
      throw StateError('Offline sipariş kaydedilemedi: geçersiz restoran veya sipariş kimliği.');
    }
    final existing = await list(id);
    if (existing.any((row) => row.localOrderId == order.localOrderId)) {
      return order;
    }
    final next = <RestaurantLocalOrderRecord>[...existing, order];
    await _persist(id, next);
    return order;
  }

  Future<void> update({
    required String restaurantId,
    required RestaurantLocalOrderRecord order,
  }) async {
    final id = restaurantId.trim();
    final orders = await list(id);
    final next = orders
        .map(
          (row) => row.localOrderId == order.localOrderId ? order : row,
        )
        .toList(growable: false);
    await _persist(id, next);
  }

  Future<int> pendingSyncCount(String restaurantId) async {
    final orders = await list(restaurantId);
    return orders
        .where(
          (order) =>
              order.syncStatus == RestaurantLocalOrderSyncStatus.pendingSync ||
              order.syncStatus == RestaurantLocalOrderSyncStatus.syncFailed ||
              order.syncStatus == RestaurantLocalOrderSyncStatus.localOnly,
        )
        .length;
  }

  Future<List<RestaurantLocalOrderRecord>> pendingSyncOrders(
    String restaurantId,
  ) async {
    final orders = await list(restaurantId);
    return orders
        .where(
          (order) =>
              order.syncStatus == RestaurantLocalOrderSyncStatus.pendingSync ||
              order.syncStatus == RestaurantLocalOrderSyncStatus.syncFailed ||
              order.syncStatus == RestaurantLocalOrderSyncStatus.localOnly,
        )
        .toList(growable: false);
  }

  Future<bool> markSynced({
    required String restaurantId,
    required String localOrderId,
    required String remoteOrderId,
  }) async {
    final order = await getByLocalId(
      restaurantId: restaurantId,
      localOrderId: localOrderId,
    );
    if (order == null) return false;
    await update(
      restaurantId: restaurantId,
      order: order.copyWith(
        syncStatus: RestaurantLocalOrderSyncStatus.synced,
        remoteOrderId: remoteOrderId,
        updatedAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<void> _persist(
    String restaurantId,
    List<RestaurantLocalOrderRecord> orders,
  ) async {
    _memory[restaurantId] = orders;
    await _store.writeJson(storageKey(restaurantId), <String, dynamic>{
      'version': restaurantOfflineOrderQueueVersion,
      'restaurant_id': restaurantId,
      'orders': orders.map((order) => order.toJson()).toList(),
    });
  }

  void clearMemoryForTests() {
    _memory.clear();
  }

  static void clearAllMemoryForTests() {
    _memory.clear();
  }
}

List<Map<String, dynamic>> _readMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
