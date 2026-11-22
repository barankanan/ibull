import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

RestaurantLocalOrderRecord _order(String id, DateTime at) =>
    RestaurantLocalOrderRecord(
      localOrderId: id,
      restaurantId: 'rest-1',
      tableId: '4',
      tableName: 'Masa 4',
      tableNumber: 4,
      waiterId: 'w',
      waiterName: 'Ali',
      items: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çay', 'quantity': 1},
      ],
      notes: '',
      total: 25,
      stationGroups: const <Map<String, dynamic>>[],
      printStatus: 'forwarded',
      syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
      createdAt: at,
      updatedAt: at,
    );

List<dynamic> _journalRows(Directory directory) {
  final text = File('${directory.path}/orders_rest-1.json').readAsStringSync();
  return (jsonDecode(text) as Map<String, dynamic>)['orders'] as List<dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    directory = await Directory.systemTemp.createTemp('ibul-queue-marks');
  });
  tearDown(() => directory.delete(recursive: true));

  test('a "sent to the cloud" mark made by the sync side reaches the journal',
      () async {
    final center = RestaurantLocalOrderQueueService(journalDirectory: directory);
    await center.enqueue(order: _order('a', DateTime.utc(2026, 11, 20, 10)));
    // The sync service builds its own queue object without a folder.
    final sync = RestaurantLocalOrderQueueService();
    expect(
      await sync.markSynced(
        restaurantId: 'rest-1',
        localOrderId: 'a',
        remoteOrderId: 'cloud-a',
      ),
      isTrue,
    );
    final row = _journalRows(directory).single as Map<String, dynamic>;
    expect(row['sync_status'], 'synced');
    expect(row['remote_order_id'], 'cloud-a');

    // Next launch: nothing is waiting, so nothing is sent twice.
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final next = RestaurantLocalOrderQueueService(journalDirectory: directory);
    expect(await next.pendingSyncCount('rest-1'), 0);
  });

  test('a mark written before the folder was known wins over an older journal',
      () async {
    final center = RestaurantLocalOrderQueueService(journalDirectory: directory);
    await center.enqueue(order: _order('a', DateTime.utc(2026, 11, 20, 10)));
    // New launch: the sync side runs before the center is started.
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final sync = RestaurantLocalOrderQueueService();
    await sync.markSynced(
      restaurantId: 'rest-1',
      localOrderId: 'a',
      remoteOrderId: 'cloud-a',
    );
    expect(
      (_journalRows(directory).single as Map<String, dynamic>)['sync_status'],
      'pendingSync',
    );
    // Another launch, the center reads first: the journal alone is stale.
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final later = RestaurantLocalOrderQueueService(journalDirectory: directory);
    expect(await later.pendingSyncCount('rest-1'), 0);
    expect((await later.list('rest-1')).single.remoteOrderId, 'cloud-a');
  });

  test('the center starting after the sync side loaded brings the journal up to date',
      () async {
    final first = RestaurantLocalOrderQueueService(journalDirectory: directory);
    await first.enqueue(order: _order('a', DateTime.utc(2026, 11, 20, 10)));
    await first.enqueue(order: _order('b', DateTime.utc(2026, 11, 20, 11)));
    // New launch: the sync side loads and marks before "Başlat".
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final sync = RestaurantLocalOrderQueueService();
    await sync.markSynced(
      restaurantId: 'rest-1',
      localOrderId: 'a',
      remoteOrderId: 'cloud-a',
    );
    // "Başlat": the center takes the journal over.
    final center = RestaurantLocalOrderQueueService(journalDirectory: directory);
    await center.adoptJournal('rest-1');
    var rows = _journalRows(directory).cast<Map<String, dynamic>>();
    expect(rows.firstWhere((r) => r['local_order_id'] == 'a')['sync_status'], 'synced');
    // A later mark from the sync side now reaches the journal too.
    await sync.markSynced(
      restaurantId: 'rest-1',
      localOrderId: 'b',
      remoteOrderId: 'cloud-b',
    );
    rows = _journalRows(directory).cast<Map<String, dynamic>>();
    expect(rows.every((r) => r['sync_status'] == 'synced'), isTrue);
  });

  test('a journal with more orders than the store copy is kept', () async {
    final center = RestaurantLocalOrderQueueService(journalDirectory: directory);
    await center.enqueue(order: _order('a', DateTime.utc(2026, 11, 20, 10)));
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    // The store copy is newer but lost an order: it must not replace the
    // journal.
    final payload = <String, dynamic>{
      'version': restaurantOfflineOrderQueueVersion,
      'restaurant_id': 'rest-1',
      'orders': <dynamic>[],
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      RestaurantLocalOrderQueueService.storageKey('rest-1'): jsonEncode(payload),
    });
    final later = RestaurantLocalOrderQueueService(journalDirectory: directory);
    expect((await later.list('rest-1')).single.localOrderId, 'a');
  });
}
