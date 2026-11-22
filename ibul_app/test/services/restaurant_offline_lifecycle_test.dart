import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/platform_capabilities.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_lifecycle.dart';

const _wifi = <ConnectivityResult>[ConnectivityResult.wifi];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RestaurantConnectivityService net;
  late bool cloud;
  late int resumes, syncs, pending;
  late bool owned, listening;
  late List<String> order; // call order of reconnect check and sync

  RestaurantOfflineLifecycle build() => RestaurantOfflineLifecycle(
        connectivity: net,
        centerWait: const Duration(milliseconds: 1),
        centerWaitAttempts: 5,
        resumeCenter: (id) async {
          resumes++;
          if (owned) listening = true;
          return owned;
        },
        isCenterListening: (id) => listening,
        onReconnected: (id) async => order.add('reverify'),
        pendingCount: (id) async => pending,
        syncPending: (id) async {
          syncs++;
          order.add('sync');
          pending = 0;
          return 1;
        },
      );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>['wifi'],
    );
    PlatformCapabilities.debugIsWebOverride = false;
    PlatformCapabilities.debugPlatformOverride = TargetPlatform.macOS;
    cloud = false;
    resumes = syncs = 0;
    order = <String>[];
    pending = 2;
    owned = true;
    listening = false;
    net = RestaurantConnectivityService(
      supabaseReachabilityProbe: () async => cloud,
      bridgeReachabilityProbe: () async => true,
      lanHostProbe: () => true,
    );
  });

  tearDown(() async {
    // Let a start-up sync from this test finish before the next one resets.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    net.dispose();
    PlatformCapabilities.resetOverridesForTests();
    RestaurantConnectivityService.resetInstanceForTests();
  });

  test('cloud returning re-checks staff before waiting orders are sent', () async {
    final l = build();
    await l.ensureStarted('r1');
    await net.refresh(networkResults: _wifi);
    await net.refresh(networkResults: _wifi); // offline
    await Future<void>.delayed(const Duration(milliseconds: 20));
    order.clear();
    pending = 2;
    cloud = true;
    await net.refresh(networkResults: _wifi);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(order, <String>['reverify', 'sync']);
  });

  test('starting the lifecycle keeps the cloud monitor running without any screen', () async {
    expect(net.isMonitoring, isFalse);
    final l = build();
    await l.ensureStarted('r1');
    expect(net.isMonitoring, isTrue);
    net.stopMonitoring();
  });

  test('second start for the same restaurant does nothing', () async {
    final l = build();
    await l.ensureStarted('r1');
    await l.ensureStarted('r1');
    expect(resumes, 1);
    expect(l.starts, 1);
  });

  test('device that owns no center never opens one (resume reports false)',
      () async {
    owned = false;
    final l = build();
    await l.ensureStarted('r1');
    expect(listening, isFalse);
  });

  test('blank restaurant id starts nothing', () async {
    final l = build();
    await l.ensureStarted('  ');
    expect(resumes, 0);
  });

  test('stop detaches: no sync after sign-out', () async {
    final l = build();
    await net.refresh(networkResults: _wifi);
    await net.refresh(networkResults: _wifi); // offline: no start-up sync
    await l.ensureStarted('r1');
    l.stop();
    expect(l.activeRestaurantId, isNull);
    cloud = true;
    await net.refresh(networkResults: _wifi);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(syncs, 0);
  });

  test('pending orders sync once when the internet returns, after the center is up',
      () async {
    final l = build();
    await net.refresh(networkResults: _wifi);
    await net.refresh(networkResults: _wifi); // cloud down twice -> offline
    await l.ensureStarted('r1');
    expect(syncs, 0);
    cloud = true;
    await net.refresh(networkResults: _wifi);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(syncs, 1);
    await net.refresh(networkResults: _wifi); // still online: no second run
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(syncs, 1);
  });

  test('an order accepted while online is sent without waiting for a reconnect',
      () async {
    pending = 0;
    cloud = true;
    final l = build();
    await net.refresh(networkResults: _wifi);
    await l.ensureStarted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(syncs, 0);
    pending = 1;
    l.localOrderAccepted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(syncs, 1);
    // Another restaurant's order, or one taken offline, starts nothing.
    pending = 1;
    l.localOrderAccepted('other');
    cloud = false;
    await net.refresh(networkResults: _wifi);
    await net.refresh(networkResults: _wifi);
    l.localOrderAccepted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(syncs, 1);
  });

  test('a backlog larger than one batch is sent in the same reconnect',
      () async {
    var waiting = 18;
    var runs = 0;
    cloud = true;
    listening = true;
    final l = RestaurantOfflineLifecycle(
      connectivity: net,
      centerWait: const Duration(milliseconds: 1),
      centerWaitAttempts: 1,
      resumeCenter: (id) async => false,
      isCenterListening: (id) => true,
      pendingCount: (id) async => waiting,
      syncPending: (id) async {
        runs++;
        final sent = waiting < 10 ? waiting : 10;
        waiting -= sent;
        return sent;
      },
    );
    await net.refresh(networkResults: _wifi);
    await l.ensureStarted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(waiting, 0);
    expect(runs, 2);
  });

  test('orders the cloud keeps refusing do not make the sync spin', () async {
    var runs = 0;
    cloud = true;
    final l = RestaurantOfflineLifecycle(
      connectivity: net,
      centerWait: const Duration(milliseconds: 1),
      centerWaitAttempts: 1,
      resumeCenter: (id) async => false,
      isCenterListening: (id) => true,
      pendingCount: (id) async => 3,
      syncPending: (id) async {
        runs++;
        return 0;
      },
    );
    await net.refresh(networkResults: _wifi);
    await l.ensureStarted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(runs, 1);
  });

  test('starting the center sends the orders that were waiting for it',
      () async {
    cloud = true;
    owned = false; // nothing reopens the center at launch
    final l = build();
    await net.refresh(networkResults: _wifi);
    await l.ensureStarted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final before = syncs;
    pending = 2;
    listening = true;
    expect(l.restaurantId, 'r1');
    l.centerStarted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(syncs, before + 1);
    expect(pending, 0);
  });

  test('nothing pending: no sync call', () async {
    pending = 0;
    cloud = true;
    final l = build();
    await net.refresh(networkResults: _wifi);
    await l.ensureStarted('r1');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(syncs, 0);
  });
}
