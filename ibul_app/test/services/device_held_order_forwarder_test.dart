// A phone that could not reach the order center keeps the order and hands
// it over by itself when the center answers again: same key, one order.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/device_held_order_forwarder.dart';
import 'package:ibul_app/services/restaurant_offline/paired_lan_transport.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _staff = '2e2f1914-0d12-4459-846e-b17d5b1eb014';
var _n = 0;

RestaurantLocalOrderRecord _order(
  String rid,
  String id, {
  bool held = true,
  String waiterId = _staff,
  DateTime? createdAt,
}) {
  final at = createdAt ?? DateTime.now();
  return RestaurantLocalOrderRecord(
    localOrderId: id,
    restaurantId: rid,
    tableId: '4',
    tableName: 'Bahçe 4',
    tableNumber: 4,
    waiterId: waiterId,
    waiterName: 'efe',
    items: const <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'price': 40},
    ],
    notes: '',
    total: 40,
    stationGroups: const <Map<String, dynamic>>[],
    printStatus: 'pending',
    syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
    createdAt: at,
    updatedAt: at,
    heldForCenter: held,
  );
}

/// A center that remembers what it saved, keyed by the send key.
class _Center {
  final Map<String, String> saved = <String, String>{};
  final List<String> requests = <String>[];
  Object? failWith;
  int? refuseStatus;
  Completer<void>? gate;

  Future<Map<String, dynamic>> send(String path, Map<String, Object?> body) async {
    final id = body['local_order_id'].toString();
    requests.add(id);
    await gate?.future;
    if (failWith != null) throw failWith!;
    if (refuseStatus != null) {
      return <String, dynamic>{'status': refuseStatus, 'saved': false};
    }
    final content = body['items'].toString();
    final before = saved[id];
    if (before != null && before != content) {
      return <String, dynamic>{'status': 409, 'saved': false, 'conflict': true};
    }
    if (before != null) {
      return <String, dynamic>{'status': 200, 'saved': true, 'duplicate': true};
    }
    saved[id] = content;
    return <String, dynamic>{
      'status': 200,
      'saved': true,
      'print_status': 'forwarded',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String rid;
  late RestaurantLocalOrderQueueService queue;
  late _Center center;
  late PairedLanTransport transport;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    rid = 'fwd-${_n++}';
    queue = RestaurantLocalOrderQueueService();
    center = _Center();
    transport = PairedLanTransport(center.send);
  });

  Future<DeviceHeldForwardResult> forward({DateTime Function()? clock}) =>
      DeviceHeldOrderForwarder.forward(
        restaurantId: rid,
        staffId: _staff,
        queue: queue,
        transport: transport,
        clock: clock,
      );

  test('held order goes to the center once; a later round sends nothing', () async {
    await queue.enqueue(order: _order(rid, 'waiter-1'));
    final first = await forward();
    expect(first.delivered, 1);
    expect(center.saved.keys, <String>['waiter-1']);
    final row = await queue.getByLocalId(restaurantId: rid, localOrderId: 'waiter-1');
    expect(row!.heldForCenter, isFalse);
    expect(row.printStatus, 'forwarded');
    final second = await forward();
    expect(second.delivered, 0);
    expect(center.requests, <String>['waiter-1']);
    expect(await queue.list(rid), hasLength(1), reason: 'the order is kept');
  });

  test('center had saved it but the reply was lost: repeat is answered as '
      'already saved, no second order', () async {
    final order = _order(rid, 'waiter-lost');
    await queue.enqueue(order: order);
    center.saved['waiter-lost'] = order.items.toString();
    final result = await forward();
    expect(result.delivered, 1);
    expect(center.saved, hasLength(1));
    expect(
      (await queue.getByLocalId(restaurantId: rid, localOrderId: 'waiter-lost'))!
          .heldForCenter,
      isFalse,
    );
  });

  test('center still unreachable: nothing is lost, nothing marked failed', () async {
    await queue.enqueue(order: _order(rid, 'waiter-a'));
    await queue.enqueue(order: _order(rid, 'waiter-b'));
    center.failWith = const SocketException('Ana bilgisayar kapalı');
    final result = await forward();
    expect(result.delivered, 0);
    expect(result.stoppedBy, isNotNull);
    expect(center.requests, <String>['waiter-a'], reason: 'round stops');
    for (final row in await queue.list(rid)) {
      expect(row.heldForCenter, isTrue);
      expect(row.syncStatus, RestaurantLocalOrderSyncStatus.pendingSync);
    }
    center.failWith = null;
    expect((await forward()).delivered, 2);
    expect(center.saved.keys.toSet(), <String>{'waiter-a', 'waiter-b'});
  });

  test('pairing refused (401): held, round stops, no retry storm', () async {
    await queue.enqueue(order: _order(rid, 'waiter-a'));
    await queue.enqueue(order: _order(rid, 'waiter-b'));
    center.refuseStatus = 401;
    final result = await forward();
    expect(result.delivered, 0);
    expect(result.stoppedBy, isNotNull);
    expect(center.requests, hasLength(1));
    expect((await queue.list(rid)).every((o) => o.heldForCenter), isTrue);
  });

  test('center busy (not saved, no conflict): tried again later', () async {
    await queue.enqueue(order: _order(rid, 'waiter-a'));
    center.refuseStatus = 503;
    expect((await forward()).stoppedBy, 'center_not_saved');
    center.refuseStatus = null;
    expect((await forward()).delivered, 1);
  });

  test('same key with different content at the center: conflict, never '
      'sent again on its own', () async {
    await queue.enqueue(order: _order(rid, 'waiter-x'));
    center.saved['waiter-x'] = 'something else';
    final result = await forward();
    expect(result.conflicts, 1);
    final row = await queue.getByLocalId(restaurantId: rid, localOrderId: 'waiter-x');
    expect(row!.syncStatus, RestaurantLocalOrderSyncStatus.conflict);
    expect(row.heldForCenter, isFalse);
    await forward();
    expect(center.requests, hasLength(1));
    expect(center.saved['waiter-x'], 'something else', reason: 'not overwritten');
  });

  test('another staff member\'s held order is not sent under this sign-in', () async {
    await queue.enqueue(order: _order(rid, 'waiter-other', waiterId: 'someone-else'));
    final result = await forward();
    expect(result.otherStaff, 1);
    expect(center.requests, isEmpty);
    expect((await queue.list(rid)).single.heldForCenter, isTrue);
  });

  test('an old held order is not printed in the kitchen unasked', () async {
    final made = DateTime(2026, 11, 23, 20);
    await queue.enqueue(order: _order(rid, 'waiter-old', createdAt: made));
    final result = await forward(
      clock: () => made.add(const Duration(minutes: 31)),
    );
    expect(result.stale, 1);
    expect(center.requests, isEmpty);
    expect((await queue.list(rid)).single.heldForCenter, isTrue);
    final fresh = await forward(
      clock: () => made.add(const Duration(minutes: 29)),
    );
    expect(fresh.delivered, 1);
  });

  test('device copies from before this rule (no mark) are never sent', () async {
    await queue.enqueue(order: _order(rid, 'waiter-legacy', held: false));
    await forward();
    expect(center.requests, isEmpty);
  });

  test('two triggers at once: one round, one request', () async {
    await queue.enqueue(order: _order(rid, 'waiter-1'));
    center.gate = Completer<void>();
    final a = forward();
    final b = forward();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    center.gate!.complete();
    final results = await Future.wait(<Future<DeviceHeldForwardResult>>[a, b]);
    expect(results.map((r) => r.delivered).reduce((x, y) => x + y), 1);
    expect(center.requests, <String>['waiter-1']);
  });

  test('the held mark survives a restart of the phone app (stored record)', () {
    final json = _order(rid, 'waiter-1').toJson();
    expect(json['held_for_center'], isTrue);
    expect(RestaurantLocalOrderRecord.fromJson(json).heldForCenter, isTrue);
    final plain = _order(rid, 'waiter-2', held: false).toJson();
    expect(plain.containsKey('held_for_center'), isFalse);
    expect(RestaurantLocalOrderRecord.fromJson(plain).heldForCenter, isFalse);
  });
}
