import 'dart:convert';
import 'dart:io';

import '../../core/secure_local_store.dart';
import 'restaurant_offline_models.dart';

class RestaurantLocalOrderQueueService {
  RestaurantLocalOrderQueueService({
    SecureLocalStore? store,
    this.writeHook,
    this.journalDirectory,
  }) : _store = store ?? SecureLocalStore.instance;

  final SecureLocalStore _store;
  final Future<void> Function(String key, Map<String, dynamic> value)? writeHook;
  final Directory? journalDirectory;
  Future<void> _writeChain = Future<void>.value();
  static final Map<String, List<RestaurantLocalOrderRecord>> _memory =
      <String, List<RestaurantLocalOrderRecord>>{};

  /// The journal folder of each restaurant, once any instance knows it. The
  /// sync service has no folder of its own; without this its "sent to the
  /// cloud" marks never reached the journal, and the next launch read every
  /// one of those orders as still waiting.
  static final Map<String, Directory> _journalDirectories =
      <String, Directory>{};

  Directory? _journalFor(String restaurantId) {
    final own = journalDirectory;
    if (own != null) {
      _journalDirectories[restaurantId] = own;
      return own;
    }
    return _journalDirectories[restaurantId];
  }

  /// The center calls this when it starts. From then on every instance
  /// writes this restaurant's journal, and what is already loaded (it may be
  /// newer than the file) is written to it once.
  Future<void> adoptJournal(String restaurantId) async {
    final id = restaurantId.trim();
    final own = journalDirectory;
    if (id.isEmpty || own == null) return;
    _journalDirectories[id] = own;
    final orders = await list(id);
    if (orders.isNotEmpty) await _persist(id, orders);
  }

  static DateTime _newest(List<RestaurantLocalOrderRecord> orders) {
    var newest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final order in orders) {
      if (order.updatedAt.isAfter(newest)) newest = order.updatedAt;
    }
    return newest;
  }

  static String storageKey(String restaurantId) =>
      'restaurant_offline_order_queue_v1_${restaurantId.trim()}';

  Future<T> transaction<T>(Future<T> Function() body) => _locked(body);

  Future<List<RestaurantLocalOrderRecord>> list(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return const <RestaurantLocalOrderRecord>[];
    if (_memory.containsKey(id)) {
      return List<RestaurantLocalOrderRecord>.from(_memory[id]!);
    }
    final journal = _readJournal(id);
    if (journal != null) {
      var parsed = _ordersFromPayload(journal);
      // A mark written while the journal folder was not known is only in
      // the device store. The newer complete record wins, so an order
      // already sent to the cloud is not sent again.
      try {
        final stored = await _readStored(id);
        if (stored != null &&
            stored.length >= parsed.length &&
            _newest(stored).isAfter(_newest(parsed))) {
          parsed = stored;
        }
      } catch (_) {
        // The journal is readable; an unreadable store copy changes nothing.
      }
      _memory[id] = parsed;
      return parsed;
    }
    final stored = await _readStored(id);
    _memory[id] = stored ?? const <RestaurantLocalOrderRecord>[];
    return _memory[id]!;
  }

  Future<List<RestaurantLocalOrderRecord>?> _readStored(String id) async {
    final rawText = await _store.readString(storageKey(id));
    if (rawText == null || rawText.trim().isEmpty) return null;
    Object? raw;
    try {
      raw = jsonDecode(rawText);
    } catch (_) {
      raw = null;
    }
    final rows = raw is Map ? raw['orders'] : null;
    if (raw is! Map || rows is! List) {
      throw StateError(
        'Yerel sipariş kaydı bozuk. Üzerine yazılmadı.',
      );
    }
    return _readMapList(rows)
        .map(RestaurantLocalOrderRecord.fromJson)
        .toList(growable: false);
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
      throw StateError(
        'Offline sipariş kaydedilemedi: geçersiz restoran veya sipariş kimliği.',
      );
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

  Future<bool> remove({
    required String restaurantId,
    required String localOrderId,
  }) async {
    final id = restaurantId.trim();
    final target = localOrderId.trim();
    final orders = await list(id);
    final next = orders
        .where((row) => row.localOrderId != target)
        .toList(growable: false);
    if (next.length == orders.length) return false;
    await _persist(id, next);
    return true;
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

  Future<T> _locked<T>(Future<T> Function() body) {
    final run = _writeChain.then((_) => body());
    _writeChain = run.then((_) {}, onError: (_, _) {});
    return run;
  }

  Future<void> _persist(
    String restaurantId,
    List<RestaurantLocalOrderRecord> orders,
  ) async {
    final payload = <String, dynamic>{
      'version': restaurantOfflineOrderQueueVersion,
      'restaurant_id': restaurantId,
      'orders': orders.map((order) => order.toJson()).toList(),
    };
    final key = storageKey(restaurantId);
    final directory = _journalFor(restaurantId);
    if (directory != null) {
      await writeAtomicQueueJournal(
        directory: directory,
        fileName: 'orders_$restaurantId.json',
        payload: payload,
      );
    }
    if (writeHook != null) {
      await writeHook!(key, payload);
    } else {
      await _store.writeJson(key, payload);
    }
    _memory[restaurantId] = orders;
  }

  void clearMemoryForTests() {
    _memory.clear();
    _journalDirectories.clear();
  }

  static void clearAllMemoryForTests() {
    _memory.clear();
    _journalDirectories.clear();
  }

  Map<String, dynamic>? _readJournal(String restaurantId) {
    final directory = _journalFor(restaurantId);
    if (directory == null) return null;
    final file = File('${directory.path}/orders_$restaurantId.json');
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync();
    if (text.trim().isEmpty) {
      throw StateError('Yerel sipariş kaydı bozuk. Üzerine yazılmadı.');
    }
    final raw = jsonDecode(text);
    if (raw is! Map || raw['orders'] is! List) {
      throw StateError('Yerel sipariş kaydı bozuk. Üzerine yazılmadı.');
    }
    return Map<String, dynamic>.from(raw);
  }

  List<RestaurantLocalOrderRecord> _ordersFromPayload(Map<String, dynamic> raw) {
    final rows = raw['orders'];
    if (rows is! List) {
      throw StateError('Yerel sipariş kaydı bozuk. Üzerine yazılmadı.');
    }
    return _readMapList(rows)
        .map(RestaurantLocalOrderRecord.fromJson)
        .toList(growable: false);
  }
}

Future<void> writeAtomicQueueJournal({
  required Directory directory,
  required String fileName,
  required Map<String, dynamic> payload,
}) async {
  await directory.create(recursive: true);
  final target = File('${directory.path}/$fileName');
  final temp = File(
    '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  await temp.writeAsString(jsonEncode(payload), flush: true);
  await temp.rename(target.path);
}

List<Map<String, dynamic>> _readMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
