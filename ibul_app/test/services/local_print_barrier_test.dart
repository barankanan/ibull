import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/local_print_barrier.dart';
import 'package:ibul_app/services/print_job_identity.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PrintJobLedger.clearForTest();
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
  });
  tearDown(PrintJobLedger.clearForTest);

  test('order revision station and restaurant stay distinct', () {
    final first = buildPrintJobIdentity(
      restaurantId: 'rest-a',
      orderKey: 'order-1',
      revision: '1',
      stationId: 'ocak',
      jobType: 'new_order',
    );
    final secondRevision = buildPrintJobIdentity(
      restaurantId: 'rest-a',
      orderKey: 'order-1',
      revision: '2',
      stationId: 'ocak',
    );
    final otherStation = buildPrintJobIdentity(
      restaurantId: 'rest-a',
      orderKey: 'order-1',
      stationId: 'bar',
    );
    final otherRestaurant = buildPrintJobIdentity(
      restaurantId: 'rest-b',
      orderKey: 'order-1',
      stationId: 'ocak',
    );
    expect(first, 'rest-a|order-1|1|ocak|new_order');
    expect(secondRevision, isNot(first));
    expect(otherStation, isNot(first));
    expect(otherRestaurant, isNot(first));
  });

  test('printed, uncertain and inconsistent jobs do not print', () {
    PrintJobLedger.remember(
      identity: buildPrintJobIdentity(
        restaurantId: 'rest-a',
        orderKey: 'order-1',
        stationId: 'ocak',
      ),
      orderKey: 'order-1',
      printStatus: 'printed',
    );
    expect(
      PrintJobLedger.reconcile(
        identity: buildPrintJobIdentity(
          restaurantId: 'rest-a',
          orderKey: 'order-1',
          stationId: 'ocak',
        ),
        orderKey: 'order-1',
      ),
      PrintReconcile.skipPrinted,
    );
    expect(
      PrintJobLedger.reconcile(
        identity: buildPrintJobIdentity(
          restaurantId: 'rest-a',
          orderKey: 'order-1',
          revision: '2',
          stationId: 'ocak',
        ),
        orderKey: 'order-1',
      ),
      PrintReconcile.allowPrint,
    );
    expect(
      PrintJobLedger.reconcile(
        identity: buildPrintJobIdentity(
          restaurantId: 'rest-a',
          orderKey: 'order-1',
          stationId: 'bar',
        ),
        orderKey: 'order-1',
      ),
      PrintReconcile.allowPrint,
    );
    expect(
      PrintJobLedger.reconcile(
        identity: buildPrintJobIdentity(
          restaurantId: 'rest-a',
          orderKey: 'order-1',
          stationId: '',
        ),
        orderKey: 'order-1',
      ),
      PrintReconcile.holdInconsistent,
    );
    PrintJobLedger.clearForTest();
    PrintJobLedger.remember(
      identity: buildPrintJobIdentity(
        restaurantId: 'rest-a',
        orderKey: 'order-2',
        stationId: 'ocak',
      ),
      orderKey: 'order-2',
      printStatus: 'uncertain',
    );
    expect(
      PrintJobLedger.reconcile(
        identity: buildPrintJobIdentity(
          restaurantId: 'rest-a',
          orderKey: 'order-2',
          stationId: 'ocak',
        ),
        orderKey: 'order-2',
      ),
      PrintReconcile.holdUncertain,
    );
    expect(
      localPrintStatusFromDispatch(physicallyDispatched: false, error: 'TCP timeout'),
      'uncertain',
    );
  });

  test('two paths for one order print only the first', () {
    final identity = buildPrintJobIdentity(
      restaurantId: 'rest-a',
      orderKey: 'order-race',
      stationId: 'ocak',
    );
    expect(
      PrintJobLedger.reconcile(identity: identity, orderKey: 'order-race'),
      PrintReconcile.allowPrint,
    );
    PrintJobLedger.remember(
      identity: identity,
      orderKey: 'order-race',
      printStatus: 'printed',
    );
    expect(
      PrintJobLedger.reconcile(identity: identity, orderKey: 'order-race'),
      PrintReconcile.skipPrinted,
    );
  });

  test('a restarted process reloads the printed order and does not reprint it', () async {
    const restaurantId = 'rest-barrier-hydrate';
    await RestaurantLocalOrderQueueService().enqueue(
      order: _order(restaurantId, 'local-hydrate-1', 'printed'),
    );
    PrintJobLedger.clearForTest();
    await hydrateLocalPrintBarrier(restaurantId);
    expect(
      PrintJobLedger.reconcile(
        identity: buildPrintJobIdentity(
          restaurantId: restaurantId,
          orderKey: 'local-hydrate-1',
          stationId: 'ocak',
        ),
        orderKey: 'local-hydrate-1',
      ),
      PrintReconcile.skipPrinted,
    );
  });

  test('ten and fifty local orders keep separate identities', () async {
    const restaurantId = 'rest-volume';
    for (final count in <int>[10, 50]) {
      RestaurantLocalOrderQueueService.clearAllMemoryForTests();
      PrintJobLedger.clearForTest();
      for (var i = 0; i < count; i++) {
        await RestaurantLocalOrderQueueService().enqueue(
          order: _order(restaurantId, 'order-$i', 'printed'),
        );
      }
      await hydrateLocalPrintBarrier(restaurantId);
      final stored = await RestaurantLocalOrderQueueService().list(restaurantId);
      expect(stored.length, count);
      for (var i = 0; i < count; i++) {
        expect(
          PrintJobLedger.reconcile(
            identity: buildPrintJobIdentity(
              restaurantId: restaurantId,
              orderKey: 'order-$i',
              stationId: 'ocak',
            ),
            orderKey: 'order-$i',
          ),
          PrintReconcile.skipPrinted,
        );
      }
    }
  });

  test('connectivity can move online, offline, then online again', () {
    final connectivity = RestaurantConnectivityService.instance;
    connectivity.debugSetConnectivity(
      hasNetwork: true,
      supabaseReachable: true,
      bridgeReachable: true,
      syncing: false,
    );
    expect(connectivity.mode, RestaurantConnectivityMode.online);
    connectivity.debugSetConnectivity(
      hasNetwork: false,
      supabaseReachable: false,
      bridgeReachable: false,
      lanHostReachable: false,
    );
    expect(connectivity.mode, RestaurantConnectivityMode.lanUnavailable);
    connectivity.debugSetConnectivity(lanHostReachable: true);
    expect(connectivity.mode, RestaurantConnectivityMode.offlineLocalMode);
    connectivity.debugSetConnectivity(
      hasNetwork: true,
      supabaseReachable: true,
      bridgeReachable: true,
    );
    expect(connectivity.mode, RestaurantConnectivityMode.online);
  });

  test('sql identity uses the same field order and password gate', () {
    final sql = File(
      'supabase/migrations/2026110101_print_identity_and_staff_password_gate.sql',
    ).readAsStringSync();
    expect(
      sql.contains(
        "concat_ws('|', new.restaurant_id::text, v_order_key, v_revision, v_station, v_job)",
      ),
      isTrue,
    );
    expect(sql.contains('not public.staff_must_change_password()'), isTrue);
    expect(sql.contains('get_my_staff_access'), isFalse);
  });
}

RestaurantLocalOrderRecord _order(
  String restaurantId,
  String localOrderId,
  String printStatus,
) {
  return RestaurantLocalOrderRecord(
    localOrderId: localOrderId,
    restaurantId: restaurantId,
    tableId: '4',
    tableName: 'Masa 4',
    tableNumber: 4,
    waiterId: 'w',
    waiterName: 'Ali',
    items: const <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'station_id': 'ocak'},
    ],
    notes: '',
    total: 50,
    stationGroups: const <Map<String, dynamic>>[],
    printStatus: printStatus,
    syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
  );
}
