import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a second process reads the order after the writer exits', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final directory = await Directory.systemTemp.createTemp('ibul-queue-journal');
    addTearDown(() => directory.delete(recursive: true));
    final writer = RestaurantLocalOrderQueueService(journalDirectory: directory);
    final now = DateTime.utc(2026, 11, 13, 18);
    await writer.enqueue(
      order: RestaurantLocalOrderRecord(
        localOrderId: 'local-keep',
        restaurantId: 'rest-kill',
        tableId: '3',
        tableName: 'Bahçe 3',
        tableNumber: 3,
        waiterId: '',
        waiterName: '',
        items: const <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'price': 40},
        ],
        notes: '',
        total: 40,
        stationGroups: const <Map<String, dynamic>>[],
        printStatus: 'queued',
        syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final journal = File('${directory.path}/orders_rest-kill.json');
    expect(journal.existsSync(), isTrue);
    final script = File('${directory.path}/check.dart');
    await script.writeAsString('''
import 'dart:convert';
import 'dart:io';

void main() {
  final raw = jsonDecode(File(${jsonEncode(journal.path)}).readAsStringSync());
  final orders = raw['orders'] as List;
  if (orders.length != 1) exit(2);
  if (orders.first['local_order_id'] != 'local-keep') exit(3);
}
''');
    final result = await Process.run('dart', <String>[script.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final reopened = RestaurantLocalOrderQueueService(journalDirectory: directory);
    final rows = await reopened.list('rest-kill');
    expect(rows, hasLength(1));
    await reopened.enqueue(
      order: rows.single.copyWith(updatedAt: now.add(const Duration(seconds: 1))),
    );
    expect(await reopened.list('rest-kill'), hasLength(1));
  });

  test('a partial journal is not treated as an empty queue', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final directory = await Directory.systemTemp.createTemp('ibul-queue-partial');
    addTearDown(() => directory.delete(recursive: true));
    final broken = File('${directory.path}/orders_rest-broken.json');
    await broken.writeAsString('{');
    final queue = RestaurantLocalOrderQueueService(journalDirectory: directory);
    await expectLater(
      queue.list('rest-broken'),
      throwsA(isA<FormatException>()),
    );
    expect(await broken.readAsString(), '{');
  });
}
