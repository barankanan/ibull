import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/print_evidence.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_sync_service.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const seller = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const waiterId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const branchA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const ocak = '11111111-1111-1111-1111-111111111111';
const firin = '22222222-2222-2222-2222-222222222222';
const kasap = '33333333-3333-3333-3333-333333333333';
final jwtSecret = base64Url.encode(
  List<int>.generate(32, (_) => Random.secure().nextInt(256)),
); // test-only random per run, never a real secret

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late Directory temp;
  late LanTlsMaterial material;
  late FakePrintBridge bridge;
  late RestaurantLocalOrderQueueService orders;
  late RestaurantLocalPrintQueueService prints;
  late RestaurantLanHost host;
  late RestaurantLanClient waiter;

  setUpAll(() async {
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    temp = await Directory.systemTemp.createTemp('ibul-bridge-');
    material = await LanTlsMaterial.open(Directory('${temp.path}/host'));
    bridge = FakePrintBridge();
    await bridge.start();
    expect(bridge.port, isNot(3001));
    orders = RestaurantLocalOrderQueueService();
    prints = RestaurantLocalPrintQueueService();
    host = _host(material, orders: orders, prints: prints, bridge: bridge.base);
    await host.start(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    waiter = await _pair(host, material, Directory('${temp.path}/waiter'));
  });

  tearDownAll(() async {
    await host.stop();
    await bridge.stop();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('queue reaches the fake bridge and survives the failure cases', () async {
    final health = await _get(bridge.base.replace(path: '/health'));
    expect(health['service'], 'ibul-local-print-bridge');
    expect(health['ok'], isTrue);

    Future<Map<String, dynamic>> place(
      String id,
      List<Map<String, Object?>> items, {
      String? station,
      String? branch,
    }) {
      return waiter.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': id,
        'table_number': 1,
        'station_id': station ?? items.first['station_id'],
        'branch_id': branch ?? branchA,
        'items': items,
      });
    }

    final one = await place('one', <Map<String, Object?>>[_item('Çorba', ocak)]);
    expect(one['saved'], isTrue);
    expect(one['printed'], isFalse);
    expect(one['print_status'], 'forwarded');
    expect(bridge.accepted, 1);
    expect(bridge.jobs.single['physical_confirmation_sent'], isFalse);
    final stored = await prints.list(seller);
    expect(stored.single.status, RestaurantLocalPrintJobStatus.forwarded);
    expect(stored.single.printedAt, isNull);

    bridge.forcePhysical = true;
    final physical = await place('physical', <Map<String, Object?>>[
      _item('Çorba', ocak),
    ]);
    bridge.forcePhysical = false;
    expect(physical['printed'], isFalse);
    expect(physical['print_status'], 'forwarded');
    final physicalJob = (await prints.list(seller))
        .where((row) => row.localOrderId == 'physical')
        .single;
    expect(physicalJob.printedAt, isNull);
    expect(physicalJob.lastError, 'bridge_accepted_not_device_ack');

    final before = bridge.accepted;
    await prints.deliverToBridge(job: stored.single, bridgeBase: bridge.base);
    expect(bridge.accepted, before);

    final ten = await place('ten', <Map<String, Object?>>[
      for (var index = 0; index < 10; index++) _item('Ürün $index', ocak),
    ]);
    expect(ten['print_status'], 'forwarded');
    expect((bridge.jobs.last['items'] as List).length, 10);
    final thirty = await place('thirty', <Map<String, Object?>>[
      for (var index = 0; index < 30; index++) _item('Satır $index', ocak),
    ]);
    expect(thirty['print_status'], 'forwarded');
    expect((bridge.jobs.last['items'] as List).length, 30);
    final sixty = await place('sixty', <Map<String, Object?>>[
      for (var index = 0; index < 60; index++) _item('Kalem $index', ocak),
    ]);
    expect(sixty['print_status'], 'forwarded');
    expect((bridge.jobs.last['items'] as List).length, 60);

    final split = await place('split', <Map<String, Object?>>[
      _item('Çorba', ocak),
      _item('Pide', firin),
    ]);
    expect(split['print_status'], 'forwarded');
    final splitStations = bridge.jobs
        .where((job) => job['local_order_id'] == 'split')
        .map((job) => job['station_id'])
        .toSet();
    expect(splitStations, <String>{ocak, firin});
    final butcher = await place('butcher', <Map<String, Object?>>[
      _item('Köfte', kasap),
    ], station: kasap);
    expect(butcher['print_status'], 'forwarded');
    expect(bridge.jobs.last['station_id'], kasap);

    final raceQueue = RestaurantLocalPrintQueueService();
    final raceJob = _queued('race', ocak);
    await raceQueue.enqueue(job: raceJob);
    await Future.wait(<Future<RestaurantLocalPrintJobRecord>>[
      raceQueue.deliverToBridge(job: raceJob, bridgeBase: bridge.base),
      raceQueue.deliverToBridge(job: raceJob, bridgeBase: bridge.base),
    ]);
    expect(bridge.jobs.where((job) => job['print_job_id'] == raceJob.localJobId).length, 1);
    expect((await raceQueue.list('queue-test')).single.status, RestaurantLocalPrintJobStatus.forwarded);

    final silent = RestaurantLocalPrintQueueService();
    final silentJob = _queued('silent', ocak);
    await silent.enqueue(job: silentJob);
    bridge.mode = 'hang';
    final hung = await silent.deliverToBridge(
      job: silentJob,
      bridgeBase: bridge.base,
      timeout: const Duration(milliseconds: 250),
    );
    expect(hung.status, RestaurantLocalPrintJobStatus.uncertain);
    final silentPosts = bridge.jobs.where((job) => job['print_job_id'] == silentJob.localJobId).length;
    bridge.mode = 'ok';
    await silent.deliverToBridge(job: hung, bridgeBase: bridge.base);
    expect(bridge.jobs.where((job) => job['print_job_id'] == silentJob.localJobId).length, silentPosts);

    final dropped = RestaurantLocalPrintQueueService();
    final droppedJob = _queued('dropped', ocak);
    await dropped.enqueue(job: droppedJob);
    bridge.mode = 'drop';
    final lost = await dropped.deliverToBridge(job: droppedJob, bridgeBase: bridge.base);
    expect(lost.status, RestaurantLocalPrintJobStatus.uncertain);
    bridge.mode = 'ok';
    await dropped.deliverToBridge(job: lost, bridgeBase: bridge.base);
    expect(bridge.jobs.where((job) => job['print_job_id'] == droppedJob.localJobId).length, 1);
    final reprint = await dropped.operatorReprint(job: lost, reprintToken: 'audit-1');
    final reprinted = await dropped.deliverToBridge(job: reprint, bridgeBase: bridge.base);
    expect(reprinted.localJobId, '${lost.localJobId}|reprint|audit-1');
    expect(reprinted.status, RestaurantLocalPrintJobStatus.forwarded);
    expect(reprinted.printedAt, isNull);
    expect(
      (await dropped.list('queue-test')).firstWhere((row) => row.localJobId == lost.localJobId).status,
      RestaurantLocalPrintJobStatus.uncertain,
    );
    expect(bridge.jobs.last['manual_reprint_token'], 'audit-1');

    final refusedUri = Uri.parse('http://127.0.0.1:1');
    final down = RestaurantLocalPrintQueueService();
    final downJob = _queued('down', ocak);
    await down.enqueue(job: downJob);
    final refused = await down.deliverToBridge(job: downJob, bridgeBase: refusedUri);
    expect(refused.status, RestaurantLocalPrintJobStatus.failed);
    await bridge.stop();
    final closedJob = _queued('closed', ocak);
    await down.enqueue(job: closedJob);
    final closed = await down.deliverToBridge(
      job: closedJob,
      bridgeBase: bridge.base,
    );
    expect(closed.status, RestaurantLocalPrintJobStatus.failed);
    await bridge.start();
    final recovered = await down.operatorReprint(job: refused, reprintToken: 'after-restart');
    final again = await down.deliverToBridge(job: recovered, bridgeBase: bridge.base);
    expect(again.status, RestaurantLocalPrintJobStatus.forwarded);

    final disk = RestaurantLocalPrintQueueService(
      writeHook: () async => throw StateError('disk'),
    );
    await expectLater(
      disk.enqueue(job: _queued('disk', ocak, restaurantId: 'disk-test')),
      throwsA(isA<StateError>()),
    );
    expect(await disk.list('disk-test'), isEmpty);

    final remoteQueue = RestaurantLocalPrintQueueService();
    final remoteJob = _queued('remote', ocak, restaurantId: 'remote-test');
    await remoteQueue.enqueue(job: remoteJob);
    final remote = await remoteQueue.deliverToBridge(
      job: remoteJob,
      bridgeBase: Uri.parse('http://192.0.2.1:9'),
    );
    expect(remote.status, RestaurantLocalPrintJobStatus.failed);
    expect(remote.lastError, contains('yalnız'));

    RestaurantLocalPrintQueueService.clearAllMemoryForTests();
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    await host.stop();
    final restartedPrints = RestaurantLocalPrintQueueService();
    final restartedOrders = RestaurantLocalOrderQueueService();
    final afterRestart = await restartedPrints.list(seller);
    expect(afterRestart.any((row) => row.localOrderId == 'one'), isTrue);
    expect(
      afterRestart.firstWhere((row) => row.localOrderId == 'one').status,
      RestaurantLocalPrintJobStatus.forwarded,
    );
    host = _host(
      material,
      orders: restartedOrders,
      prints: restartedPrints,
      bridge: bridge.base,
    );
    await host.start(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    waiter = await _pair(host, material, Directory('${temp.path}/waiter-2'));
    final afterHost = await place('after-host', <Map<String, Object?>>[
      _item('Çorba', ocak),
    ]);
    expect(afterHost['saved'], isTrue);
    expect(afterHost['printed'], isFalse);

    final wrongBranch = await place(
      'wrong-branch',
      <Map<String, Object?>>[_item('Çorba', ocak)],
      branch: 'branch-2',
    );
    expect(wrongBranch['status'], 403);
    expect(wrongBranch['saved'], isFalse);
    final payment = await waiter.postAuthorized('/lan/payments', <String, Object?>{});
    expect(payment['status'], 403);
    expect(deviceMayRunLocalPrintBridge(TargetPlatform.iOS), isFalse);
    expect(deviceMayRunLocalPrintBridge(TargetPlatform.android), isFalse);
    expect(deviceMayRunLocalPrintBridge(TargetPlatform.macOS), isTrue);
    final second = await _pair(
      host,
      material,
      Directory('${temp.path}/waiter-b'),
    );
    final beforeAccepted = bridge.accepted;
    final secondOrder = await second.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'waiter-b',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(secondOrder['saved'], isTrue);
    expect(secondOrder['printed'], isFalse);
    expect(bridge.accepted, beforeAccepted + 1);
    final scratch = await Directory.systemTemp.createTemp('ibul-evidence-');
    final firstMaterial = await LanTlsMaterial.open(scratch);
    final firstKey = await LanTlsMaterial.evidenceIdentity(scratch);
    expect(firstKey.path, endsWith('evidence.key'));
    expect(firstKey.modulusHex == await _modulus('${scratch.path}/server.key'), isFalse);
    await File('${scratch.path}/server.pem').delete();
    await File('${scratch.path}/operator.pem').delete();
    final renewed = await LanTlsMaterial.open(scratch);
    expect((await LanTlsMaterial.evidenceIdentity(scratch)).id, firstKey.id);
    expect(renewed.serverFingerprint, isNot(firstMaterial.serverFingerprint));
    await LanTlsMaterial.rotateEvidenceKey(scratch);
    expect((await LanTlsMaterial.evidenceIdentity(scratch)).id, isNot(firstKey.id));
    expect(File('${scratch.path}/evidence.retired-${firstKey.id}.key').existsSync(), isTrue);
    expect(File('${scratch.path}/server.key').existsSync(), isTrue);
    scratch.deleteSync(recursive: true);
    final strangerDir = Directory('${temp.path}/stranger');
    final stranger = await LanClientCertificate.generate(
      directory: strangerDir,
      commonName: 'stranger',
    );
    final foreign = RestaurantLanClient(
      Uri.parse('https://127.0.0.1:${host.port}'),
      securityContext: stranger.context,
      pinnedServerFingerprint: material.serverFingerprint,
      staffId: 'staff-a',
    );
    try {
      final foreignOrder = await foreign.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'foreign',
        'table_number': 1,
        'station_id': ocak,
        'items': <Map<String, Object?>>[_item('Çorba', ocak)],
      });
      expect(foreignOrder['saved'], isNot(true));
    } on Exception {
      // The host closes a certificate it did not sign.
    }
  });

  test('signed local evidence syncs once through isolated PostgREST', () async {
    final postgrest = Platform.environment['IBUL_POSTGREST'] ?? '';
    final psql = Platform.environment['IBUL_PSQL'] ?? '';
    expect(postgrest, isNotEmpty, reason: 'IBUL_POSTGREST is required');
    expect(psql, isNotEmpty, reason: 'IBUL_PSQL is required');
    await _registerServerKey(psql, material);
    final verifier = await _startVerifier(postgrest);
    addTearDown(() {
      verifier.edge.kill();
      verifier.gateway.kill();
      verifier.rpcProxy.kill();
    });

    final sync = RestaurantOfflineSyncService(
      orderQueue: orders,
      isolatedPostgrestUri: Uri.parse(postgrest),
      isolatedAccessToken: _jwt(seller),
      isolatedEvidenceVerifierUri: verifier.uri,
    );
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await sync.syncPendingOrders(restaurantId: seller, limit: 20) == 0) {
        break;
      }
    }
    final localSave = <int>[];
    final printQueue = <int>[];
    final bridgeRequest = <int>[];
    final bridgeResponse = <int>[];
    final syncTimes = <int>[];
    for (var index = 0; index < 30; index++) {
      final saved = await waiter.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'sample-$index',
        'table_number': 1,
        'station_id': ocak,
        'branch_id': branchA,
        'items': <Map<String, Object?>>[_item('Çorba', ocak)],
      });
      expect(saved['printed'], isFalse);
      expect(saved['print_status'], 'forwarded');
      localSave.add(host.lastStageMicros['local_save'] ?? 0);
      printQueue.add(host.lastStageMicros['print_queue'] ?? 0);
      bridgeRequest.add(host.lastStageMicros['bridge_request'] ?? 0);
      bridgeResponse.add(host.lastStageMicros['bridge_response'] ?? 0);
      final watch = Stopwatch()..start();
      final count = await sync.syncPendingOrders(restaurantId: seller, limit: 1);
      syncTimes.add(watch.elapsedMicroseconds);
      expect(count, 1);
    }
    _report('local_save', localSave);
    _report('print_queue', printQueue);
    _report('bridge_request', bridgeRequest);
    _report('bridge_response', bridgeResponse);
    _report('sync', syncTimes);

    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'sample-0'"), '1');
    expect(
      await _sql(
        psql,
        "select status || ':' || coalesce(last_error, '') from public.print_jobs "
        "where order_id = (select id from public.orders where local_order_id = 'sample-0')",
      ),
      'paused_by_operator:local_forwarded',
    );
    expect(
      await _sql(
        psql,
        "select count(*) from public.print_jobs where status = 'pending' "
        "and order_id = (select id from public.orders where local_order_id = 'sample-0')",
      ),
      '0',
    );

    final sample = (await orders.list(seller)).firstWhere((row) => row.localOrderId == 'sample-0');
    await orders.update(
      restaurantId: seller,
      order: sample.copyWith(
        syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
        updatedAt: DateTime.now(),
      ),
    );
    expect(await sync.syncPendingOrders(restaurantId: seller, limit: 1), 1);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'sample-0'"), '1');

    final conflict = await _rpc(postgrest, <String, dynamic>{
      'p_restaurant_id': seller,
      'p_table_number': 1,
      'p_items': <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'Çorba',
          'name': 'Çorba',
          'quantity': 2,
          'price': 40,
          'station_id': ocak,
        },
      ],
      'p_waiter_name': 'Garson',
      'p_job_type': 'new_order',
      'p_order_type': 'table',
      'p_local_order_id': 'sample-0',
    });
    expect(conflict['status'], isNot(200));
    expect(conflict['text'], contains('farklı içerik'));
    expect(
      await _sql(
        psql,
        "select quantity from public.order_items where order_id = "
        "(select id from public.orders where local_order_id = 'sample-0')",
      ),
      '1',
    );

    final legacy = await _rpc(
      postgrest,
      createTableOrderRpcParams(
        restaurantId: seller,
        tableNumber: 1,
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 'Çorba',
            'name': 'Çorba',
            'quantity': 1,
            'price': 40,
            'station_id': ocak,
          },
        ],
        waiterName: 'Garson',
        jobType: 'new_order',
      ),
    );
    expect(legacy['status'], 200);
    expect(legacy['text'], contains('"print_disposition": "online"'));

    bridge.mode = 'drop';
    final uncertain = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'uncertain-e2e',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    bridge.mode = 'ok';
    expect(uncertain['print_status'], 'uncertain');
    expect(uncertain['printed'], isFalse);
    expect(await sync.syncPendingOrders(restaurantId: seller, limit: 5), greaterThan(0));
    expect(
      await _sql(
        psql,
        "select status || ':' || coalesce(last_error, '') from public.print_jobs "
        "where order_id = (select id from public.orders where local_order_id = 'uncertain-e2e')",
      ),
      'failed:locally_uncertain',
    );

    await bridge.stop();
    final failed = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'failed-e2e',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    await bridge.start();
    expect(failed['print_status'], 'failed');
    expect(await sync.syncPendingOrders(restaurantId: seller, limit: 5), greaterThan(0));
    expect(
      await _sql(
        psql,
        "select status from public.print_jobs where order_id = "
        "(select id from public.orders where local_order_id = 'failed-e2e')",
      ),
      'pending',
    );

    final drop = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    drop.listen((socket) => socket.destroy());
    final broken = RestaurantOfflineSyncService(
      orderQueue: orders,
      isolatedPostgrestUri: Uri.parse('http://127.0.0.1:${drop.port}'),
      isolatedAccessToken: _jwt(seller),
    );
    final held = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'drop-e2e',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(held['print_status'], 'forwarded');
    expect(await broken.syncPendingOrders(restaurantId: seller, limit: 20), 0);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'drop-e2e'"), '0');
    expect(await sync.syncPendingOrders(restaurantId: seller, limit: 5), greaterThan(0));
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'drop-e2e'"), '1');
    await drop.close();

    final forged = await host.evidenceForOrder(
      localOrderId: 'forged-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'forged-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    expect(forged, isNotNull);
    final signed = forged!;
    final ownerToken = await host.evidenceForOrder(
      localOrderId: 'direct-owner-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'direct-owner-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final direct = await _rpc(postgrest, _evidenceBody('direct-owner-e2e', ownerToken!));
    expect(direct['text'], contains('"print_disposition": "unverified"'));
    final signatureAt = signed.lastIndexOf('.') + 1;
    final flippedChars = signed.split('');
    flippedChars[signatureAt] = flippedChars[signatureAt] == 'a' ? 'b' : 'a';
    final flipped = flippedChars.join();
    final tampered = await _verify(verifier.uri, _evidenceBody('forged-e2e', flipped));
    expect(tampered['text'], contains('"print_disposition": "unverified"'));
    final reused = await _verify(verifier.uri, _evidenceBody('stolen-e2e', signed));
    expect(reused['text'], contains('"print_disposition": "unverified"'));
    final changedQuantity = Map<String, dynamic>.from(_evidenceBody('qty-e2e', signed));
    changedQuantity['p_items'] = <Map<String, dynamic>>[
      <String, dynamic>{..._soup(), 'quantity': 2},
    ];
    changedQuantity['p_local_order_id'] = 'qty-e2e';
    final quantityProof = await _verify(verifier.uri, changedQuantity);
    expect(quantityProof['text'], contains('"print_disposition": "unverified"'));
    final branchToken = await host.evidenceForOrder(
      localOrderId: 'branch-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'branch-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final otherBranch = Map<String, dynamic>.from(_evidenceBody('branch-e2e', branchToken!))
      ..['p_table_number'] = 2;
    expect((await _verify(verifier.uri, otherBranch))['text'], contains('"print_disposition": "unverified"'));
    final staffBranch = await _verify(
      verifier.uri,
      Map<String, dynamic>.from(_evidenceBody('staff-branch', branchToken))
        ..['p_local_order_id'] = 'staff-branch'
        ..['p_table_number'] = 2
        ..['p_waiter_id'] = waiterId,
      token: _jwt(waiterId),
    );
    expect(staffBranch['status'], isNot(200));
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'staff-branch'"), '0');
    final otherStore = Map<String, dynamic>.from(_evidenceBody('store-e2e', signed))
      ..['p_restaurant_id'] = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
    final otherStoreCall = await _verify(verifier.uri, otherStore);
    expect(otherStoreCall['status'], isNot(200));
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'store-e2e'"), '0');
    expect((await _verify(verifier.uri, _evidenceBody('expired-e2e', signed), token: _jwt(seller, exp: 1)))['status'], 401);
    expect((await _verify(verifier.uri, _evidenceBody('session-e2e', signed), token: _jwt(seller, sessionId: 'unknown-session')))['status'], 401);
    expect((await _verify(verifier.uri, _evidenceBody('missing-auth', signed), token: ''))['status'], 401);
    final serviceCaller = await _verify(
      verifier.uri,
      _evidenceBody('service-caller-e2e', signed),
      token: _jwt(seller, role: 'service_role'),
    );
    expect(serviceCaller['status'], 401);
    final tamperedJwt = _jwt(seller).split('.');
    final signature = tamperedJwt[2].split('');
    signature[0] = signature[0] == 'a' ? 'b' : 'a';
    tamperedJwt[2] = signature.join();
    expect(
      (await _verify(
        verifier.uri,
        _evidenceBody('tampered-jwt', signed),
        token: tamperedJwt.join('.'),
      ))['status'],
      401,
    );
    final revokedSession = _jwt(seller, sessionId: 'revoke-session');
    final logout = HttpClient();
    try {
      final request = await logout.postUrl(
        verifier.gatewayUri.replace(path: '/auth/v1/logout'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $revokedSession');
      request.headers.set('apikey', 'isolated-anon-key');
      final response = await request.close();
      expect(response.statusCode, 204);
    } finally {
      logout.close(force: true);
    }
    expect(
      (await _verify(
        verifier.uri,
        _evidenceBody('revoked-session', signed),
        token: revokedSession,
      ))['status'],
      401,
    );
    final hookToken = await host.evidenceForOrder(
      localOrderId: 'hook-ignored-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'hook-ignored-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final hookWatch = Stopwatch()..start();
    final ignoredHook = await _verify(
      verifier.uri.replace(queryParameters: <String, String>{'hold': '1', 'drop': '1'}),
      _evidenceBody('hook-ignored-e2e', hookToken!),
    );
    expect(hookWatch.elapsedMilliseconds, lessThan(700));
    expect(ignoredHook['status'], isNot(599));
    expect(ignoredHook['text'], contains('"print_disposition": "forwarded"'));

    final registered = await LanTlsMaterial.evidenceIdentity(material.directory);
    final clientSignature = await _sign(
      '${temp.path}/waiter/client.key',
      lanPrintEvidenceCanonical(
        restaurantId: seller,
        localOrderId: 'client-e2e',
        jobType: 'new_order',
        outcome: 'forwarded',
        revision: '1',
        eventId: 'client-e2e|1|forwarded',
        keyId: registered.id,
        branchId: branchA,
        serverFingerprint: material.serverFingerprint,
        items: <Map<String, dynamic>>[_soup()],
      ),
    );
    final clientProof = await _verify(
      verifier.uri,
      _evidenceBody(
        'client-e2e',
        'v2.forwarded.1.client-e2e|1|forwarded.${registered.id}.$clientSignature',
      ),
    );
    expect(clientProof['text'], contains('"print_disposition": "unverified"'));

    final tlsSignature = await _sign(
      '${material.directory.path}/server.key',
      lanPrintEvidenceCanonical(
        restaurantId: seller,
        localOrderId: 'tls-key-e2e',
        jobType: 'new_order',
        outcome: 'forwarded',
        revision: '1',
        eventId: 'tls-key-e2e|1|forwarded',
        keyId: registered.id,
        branchId: branchA,
        serverFingerprint: material.serverFingerprint,
        items: <Map<String, dynamic>>[_soup()],
      ),
    );
    final tlsProof = await _verify(
      verifier.uri,
      _evidenceBody(
        'tls-key-e2e',
        'v2.forwarded.1.tls-key-e2e|1|forwarded.${registered.id}.$tlsSignature',
      ),
    );
    expect(tlsProof['text'], contains('"print_disposition": "unverified"'));

    final oldKey = await LanTlsMaterial.evidenceIdentity(material.directory);
    final retiredPayload = lanPrintEvidenceCanonical(
      restaurantId: seller,
      localOrderId: 'retired-e2e',
      jobType: 'new_order',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'retired-e2e|1|forwarded',
      keyId: oldKey.id,
      branchId: branchA,
      serverFingerprint: material.serverFingerprint,
      items: <Map<String, dynamic>>[_soup()],
    );
    await LanTlsMaterial.rotateEvidenceKey(material.directory);
    final retiredSignature = await _sign(
      '${material.directory.path}/evidence.retired-${oldKey.id}.key',
      retiredPayload,
    );
    final retiredToken =
        'v2.forwarded.1.retired-e2e|1|forwarded.${oldKey.id}.$retiredSignature';
    final retiredOk = await _verify(verifier.uri, _evidenceBody('retired-e2e', retiredToken));
    expect(retiredOk['text'], contains('"print_disposition": "forwarded"'));
    await _sql(
      psql,
      "update public.restaurant_lan_print_evidence_keys set revoked = true "
      "where key_id = '${oldKey.id}'",
    );
    final revokedSignature = await _sign(
      '${material.directory.path}/evidence.retired-${oldKey.id}.key',
      lanPrintEvidenceCanonical(
        restaurantId: seller,
        localOrderId: 'revoked-e2e',
        jobType: 'new_order',
        outcome: 'forwarded',
        revision: '1',
        eventId: 'revoked-e2e|1|forwarded',
        keyId: oldKey.id,
        branchId: branchA,
        serverFingerprint: material.serverFingerprint,
        items: <Map<String, dynamic>>[_soup()],
      ),
    );
    final retiredAgain = await _verify(
      verifier.uri,
      _evidenceBody(
        'revoked-e2e',
        'v2.forwarded.1.revoked-e2e|1|forwarded.${oldKey.id}.$revokedSignature',
      ),
    );
    expect(retiredAgain['text'], contains('"print_disposition": "unverified"'));
    final rotated = await host.evidenceForOrder(
      localOrderId: 'rotated-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'rotated-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final unregistered = await _verify(verifier.uri, _evidenceBody('rotated-e2e', rotated!));
    expect(unregistered['text'], contains('"print_disposition": "unverified"'));
    await _registerServerKey(psql, material);
    final rotatedAgain = await host.evidenceForOrder(
      localOrderId: 'rotated-live-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'rotated-live-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final rotatedCall = await _verify(
      verifier.uri,
      _evidenceBody('rotated-live-e2e', rotatedAgain!),
    );
    expect(rotatedCall['text'], contains('"print_disposition": "forwarded"'));
    final actorToken = await host.evidenceForOrder(
      localOrderId: 'actor-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'actor-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final actorBody = Map<String, dynamic>.from(_evidenceBody('actor-e2e', actorToken!))
      ..['p_verified_actor'] = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
      ..['p_waiter_id'] = waiterId;
    expect((await _verify(verifier.uri, actorBody))['text'], contains('"print_disposition": "forwarded"'));
    expect(await _sql(psql, "select user_id::text from public.orders where local_order_id = 'actor-e2e'"), seller);
    expect(await _sql(psql, "select waiter_id::text from public.orders where local_order_id = 'actor-e2e'"), waiterId);

    final holdToken = await host.evidenceForOrder(
      localOrderId: 'hold-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'hold-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    final raceHarness = await _startRaceHarness(verifier.gatewayUri);
    addTearDown(raceHarness.process.kill);
    final holdCall = _verify(
      raceHarness.uri,
      _evidenceBody('hold-e2e', holdToken!),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final heldKey = (await LanTlsMaterial.evidenceIdentity(material.directory)).id;
    await _sql(
      psql,
      "update public.restaurant_lan_print_evidence_keys set revoked = true "
      "where key_id = '$heldKey'",
    );
    expect((await holdCall)['text'], contains('"print_disposition": "unverified"'));
    await _sql(
      psql,
      "update public.restaurant_lan_print_evidence_keys set revoked = false "
      "where key_id = '$heldKey'",
    );

    final stallToken = await host.evidenceForOrder(
      localOrderId: 'stall-e2e',
      outcome: 'forwarded',
      revision: '1',
      eventId: 'stall-e2e|1|forwarded',
      items: <Map<String, dynamic>>[_soup()],
    );
    await _proxyMode(verifier.rpcControl, 'blackhole');
    expect(
      (await _verify(
        verifier.uri,
        _evidenceBody('stall-e2e', stallToken!),
      ))['status'],
      504,
    );
    await _proxyMode(verifier.rpcControl, 'forward');
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'stall-e2e'"), '0');

    final revisionChars = rotatedAgain.split('.');
    revisionChars[2] = '9';
    final revisionProof = await _verify(
      verifier.uri,
      _evidenceBody('revision-e2e', revisionChars.join('.')),
    );
    expect(revisionProof['text'], contains('"print_disposition": "unverified"'));
    final outcomeChars = rotatedAgain.split('.');
    outcomeChars[1] = 'uncertain';
    final outcomeProof = await _verify(
      verifier.uri,
      _evidenceBody('outcome-e2e', outcomeChars.join('.')),
    );
    expect(outcomeProof['text'], contains('"print_disposition": "unverified"'));
    final stationBody = Map<String, dynamic>.from(_evidenceBody('station-e2e', rotatedAgain));
    stationBody['p_items'] = <Map<String, dynamic>>[_soup(station: firin)];
    stationBody['p_local_order_id'] = 'station-e2e';
    expect(
      (await _verify(verifier.uri, stationBody))['text'],
      contains('"print_disposition": "unverified"'),
    );

    final claimed = await _sql(
      psql,
      "with claimed as ("
      "update public.print_jobs set status = 'claimed' "
      "where status = 'pending' and order_id = "
      "(select id from public.orders where local_order_id = 'sample-0') "
      "returning 1) select count(*) from claimed",
    );
    expect(claimed, '0');
    expect(
      await _sql(
        psql,
        "select status || ':' || coalesce(last_error, '') from public.print_jobs "
        "where order_id = (select id from public.orders where local_order_id = 'sample-0')",
      ),
      'paused_by_operator:local_forwarded',
    );

    final edgeProxy = await _startTcpProxy(verifier.uri);
    addTearDown(edgeProxy.process.kill);
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = closed.port;
    await closed.close();
    final absent = RestaurantOfflineSyncService(
      orderQueue: orders,
      isolatedPostgrestUri: Uri.parse(postgrest),
      isolatedAccessToken: _jwt(seller),
      isolatedEvidenceVerifierUri: Uri.parse('http://127.0.0.1:$closedPort/'),
    );
    final absentOrder = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'tcp-absent',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(absentOrder['print_status'], 'forwarded');
    expect(await absent.syncPendingOrders(restaurantId: seller, limit: 5), 0);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-absent'"), '0');
    expect(
      (await orders.list(seller)).any((row) => row.localOrderId == 'tcp-absent' && row.syncStatus != RestaurantLocalOrderSyncStatus.synced),
      isTrue,
    );

    await _proxyMode(edgeProxy.control, 'cut-request');
    final cutSync = RestaurantOfflineSyncService(
      orderQueue: orders,
      isolatedPostgrestUri: Uri.parse(postgrest),
      isolatedAccessToken: _jwt(seller),
      isolatedEvidenceVerifierUri: edgeProxy.proxy,
    );
    final bodyCut = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'tcp-body',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(bodyCut['print_status'], 'forwarded');
    expect(await cutSync.syncPendingOrders(restaurantId: seller, limit: 5), 0);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-body'"), '0');
    expect(
      (await orders.list(seller)).any((row) => row.localOrderId == 'tcp-body'),
      isTrue,
    );

    await _proxyMode(edgeProxy.control, 'cut-upstream');
    final verifyCut = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'tcp-verify',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(verifyCut['print_status'], 'forwarded');
    expect(await cutSync.syncPendingOrders(restaurantId: seller, limit: 5), 0);
    final verifyLocal = (await orders.list(seller)).firstWhere((row) => row.localOrderId == 'tcp-verify');
    expect(verifyLocal.syncStatus, isNot(RestaurantLocalOrderSyncStatus.synced));
    final verifyCount = await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-verify'");
    expect(verifyCount == '0' || verifyCount == '1', isTrue);

    await _proxyMode(edgeProxy.control, 'drop-response');
    final lost = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'tcp-lost',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(lost['print_status'], 'forwarded');
    expect(await cutSync.syncPendingOrders(restaurantId: seller, limit: 5), 0);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-lost'"), '1');
    expect(
      (await orders.list(seller)).firstWhere((row) => row.localOrderId == 'tcp-lost').syncStatus,
      isNot(RestaurantLocalOrderSyncStatus.synced),
    );
    await _proxyMode(edgeProxy.control, 'forward');
    final retryA = RestaurantOfflineSyncService(
      orderQueue: orders,
      isolatedPostgrestUri: Uri.parse(postgrest),
      isolatedAccessToken: _jwt(seller),
      isolatedEvidenceVerifierUri: edgeProxy.proxy,
    );
    final retryB = RestaurantOfflineSyncService(
      orderQueue: orders,
      isolatedPostgrestUri: Uri.parse(postgrest),
      isolatedAccessToken: _jwt(seller),
      isolatedEvidenceVerifierUri: edgeProxy.proxy,
    );
    await Future.wait(<Future<int>>[
      retryA.syncPendingOrders(restaurantId: seller, limit: 5),
      retryB.syncPendingOrders(restaurantId: seller, limit: 5),
    ]);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-lost'"), '1');
    expect(
      await _sql(
        psql,
        "select count(*) from public.print_jobs where order_id = "
        "(select id from public.orders where local_order_id = 'tcp-lost')",
      ),
      '1',
    );
    expect(
      await _sql(
        psql,
        "select count(*) from public.print_jobs where status = 'pending' and order_id = "
        "(select id from public.orders where local_order_id = 'tcp-lost')",
      ),
      '0',
    );

    await _proxyMode(verifier.rpcControl, 'drop-response');
    final rpcLost = await waiter.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'tcp-rpc',
      'table_number': 1,
      'station_id': ocak,
      'branch_id': branchA,
      'items': <Map<String, Object?>>[_item('Çorba', ocak)],
    });
    expect(rpcLost['print_status'], 'forwarded');
    expect(await sync.syncPendingOrders(restaurantId: seller, limit: 5), 0);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-rpc'"), '1');
    expect(
      (await orders.list(seller)).any((row) => row.localOrderId == 'tcp-rpc' && row.syncStatus != RestaurantLocalOrderSyncStatus.synced),
      isTrue,
    );
    await _proxyMode(verifier.rpcControl, 'forward');
    expect(await sync.syncPendingOrders(restaurantId: seller, limit: 5), greaterThan(0));
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-rpc'"), '1');
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-absent'"), '1');
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-body'"), '1');
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'tcp-verify'"), '1');
    expect(
      await _sql(
        psql,
        "select count(*) from public.print_jobs where status = 'pending' and order_id = "
        "(select id from public.orders where local_order_id = 'tcp-verify')",
      ),
      '0',
    );

    final race = (await orders.list(seller)).firstWhere((row) => row.localOrderId == 'sample-1');
    await orders.update(
      restaurantId: seller,
      order: race.copyWith(
        syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
        updatedAt: DateTime.now(),
      ),
    );
    await Future.wait(<Future<int>>[
      sync.syncPendingOrders(restaurantId: seller, limit: 1),
      sync.syncPendingOrders(restaurantId: seller, limit: 1),
    ]);
    expect(await _sql(psql, "select count(*) from public.orders where local_order_id = 'sample-1'"), '1');
    expect(
      await _sql(
        psql,
        "select count(*) from public.print_jobs where order_id = "
        "(select id from public.orders where local_order_id = 'sample-1')",
      ),
      '1',
    );
  });
}

Map<String, Object?> _item(String name, String station) {
  return <String, Object?>{
    'product_id': name,
    'name': name,
    'quantity': 1,
    'price': 40,
    'station_id': station,
  };
}

Map<String, dynamic> _evidenceBody(String localOrderId, String evidence) {
  return createTableOrderRpcParams(
    restaurantId: seller,
    tableNumber: 1,
    items: <Map<String, dynamic>>[
      <String, dynamic>{
        'product_id': 'Çorba',
        'name': 'Çorba',
        'quantity': 1,
        'price': 40,
        'station_id': ocak,
      },
    ],
    waiterName: 'Garson',
    jobType: 'new_order',
    localOrderId: localOrderId,
    localPrintEvidence: evidence,
  );
}

Map<String, dynamic> _soup({String station = ocak}) {
  return <String, dynamic>{
    'product_id': 'Çorba',
    'name': 'Çorba',
    'quantity': 1,
    'price': 40,
    'station_id': station,
  };
}

Future<({Process gateway, Process edge, Process rpcProxy, Uri uri, Uri gatewayUri, Uri rpcControl})> _startVerifier(String postgrest) async {
  final rpcProxy = await _startTcpProxy(Uri.parse(postgrest));
  final gateway = await Process.start(
    'node',
    <String>['supabase/functions/verify-lan-print-evidence/isolated_gateway.mjs'],
    environment: <String, String>{
      ...Platform.environment,
      'POSTGREST_URL': rpcProxy.proxy.toString(),
      'IBUL_EVIDENCE_JWT_SECRET': jwtSecret,
      'SUPABASE_ANON_KEY': 'isolated-anon-key',
      'IBUL_AUTH_SESSIONS': 'test-session:$seller,waiter-session:$waiterId,revoke-session:$seller',
    },
  );
  final gatewayLine = await gateway.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .firstWhere((row) => row.startsWith('GATEWAY_PORT '))
      .timeout(const Duration(seconds: 8));
  final gatewayUri = 'http://127.0.0.1:${gatewayLine.split(' ').last}';
  final edge = await Process.start(
    '/tmp/ibul-deno/bin/deno',
    <String>[
      'run',
      '--allow-net',
      '--allow-env',
      'supabase/functions/verify-lan-print-evidence/index.ts',
    ],
    environment: <String, String>{
      ...Platform.environment,
      'SUPABASE_URL': gatewayUri,
      'SUPABASE_ANON_KEY': 'isolated-anon-key',
      'SUPABASE_SERVICE_ROLE_KEY': _jwt(seller, role: 'service_role'),
      'IBUL_EVIDENCE_TEST_HOOKS': '1',
      'IBUL_EVIDENCE_RPC_TIMEOUT_MS': '1000',
    },
  );
  final log = File('${Directory.systemTemp.path}/ibul-verifier-63a2.log');
  edge.stderr.listen((chunk) {
    log.writeAsBytesSync(chunk, mode: FileMode.append);
  });
  gateway.stderr.listen((chunk) {
    log.writeAsBytesSync(chunk, mode: FileMode.append);
  });
  final line = await edge.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .firstWhere((row) => row.startsWith('EVIDENCE_VERIFIER_PORT '))
      .timeout(const Duration(seconds: 8));
  final port = int.parse(line.split(' ').last);
  return (
    gateway: gateway,
    edge: edge,
    rpcProxy: rpcProxy.process,
    uri: Uri.parse('http://127.0.0.1:$port/'),
    gatewayUri: Uri.parse(gatewayUri),
    rpcControl: rpcProxy.control,
  );
}

Future<({Process process, Uri proxy, Uri control})> _startTcpProxy(Uri upstream) async {
  final process = await Process.start(
    'node',
    <String>['supabase/tests/tcp_cut_proxy.mjs'],
    environment: <String, String>{
      ...Platform.environment,
      'UPSTREAM': upstream.toString(),
    },
  );
  final proxyLine = Completer<String>();
  final controlLine = Completer<String>();
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((row) {
    if (row.startsWith('PROXY_PORT ') && !proxyLine.isCompleted) proxyLine.complete(row);
    if (row.startsWith('CONTROL_PORT ') && !controlLine.isCompleted) controlLine.complete(row);
  });
  final proxyText = await proxyLine.future.timeout(const Duration(seconds: 8));
  final controlText = await controlLine.future.timeout(const Duration(seconds: 8));
  return (
    process: process,
    proxy: Uri.parse('http://127.0.0.1:${proxyText.split(' ').last}'),
    control: Uri.parse('http://127.0.0.1:${controlText.split(' ').last}/'),
  );
}

Future<({Process process, Uri uri})> _startRaceHarness(Uri gateway) async {
  final process = await Process.start(
    '/tmp/ibul-deno/bin/deno',
    <String>[
      'run',
      '--allow-net',
      '--allow-env',
      'supabase/tests/evidence_race_harness.ts',
    ],
    environment: <String, String>{
      ...Platform.environment,
      'SUPABASE_URL': gateway.toString(),
      'SUPABASE_ANON_KEY': 'isolated-anon-key',
      'SUPABASE_SERVICE_ROLE_KEY': _jwt(seller, role: 'service_role'),
      'IBUL_EVIDENCE_RPC_TIMEOUT_MS': '1000',
      'IBUL_EVIDENCE_TEST_HOOKS': '1',
    },
  );
  final line = await process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .firstWhere((row) => row.startsWith('RACE_HARNESS_PORT '))
      .timeout(const Duration(seconds: 8));
  return (process: process, uri: Uri.parse('http://127.0.0.1:${line.split(' ').last}/'));
}

Future<void> _proxyMode(Uri control, String mode) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(control.replace(path: '/mode'));
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(<String, String>{'mode': mode})));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) throw StateError(text);
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _verify(
  Uri uri,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    final bearer = token ?? _jwt(seller);
    if (bearer.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
    }
    final payload = Map<String, dynamic>.from(body);
    payload.putIfAbsent('branch_id', () => branchA);
    request.add(utf8.encode(jsonEncode(payload)));
    final response = await request.close().timeout(const Duration(seconds: 8));
    final text = await utf8.decoder.bind(response).join();
    return <String, dynamic>{'status': response.statusCode, 'text': text};
  } finally {
    client.close(force: true);
  }
}

RestaurantLocalPrintJobRecord _queued(
  String id,
  String station, {
  String restaurantId = 'queue-test',
}) {
  return RestaurantLocalPrintJobRecord(
    localJobId: '$id|1|$station|new_order',
    restaurantId: restaurantId,
    localOrderId: id,
    tableId: '1',
    tableName: 'Masa 1',
    documentType: 'kitchen',
    role: 'mutfak',
    station: station,
    printerSnapshot: const <String, dynamic>{},
    payloadSnapshot: <String, dynamic>{
      'revision': '1',
      'station_id': station,
      'job_type': 'new_order',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'station_id': station},
      ],
    },
    status: RestaurantLocalPrintJobStatus.queued,
    attempts: 0,
    createdAt: DateTime.utc(2026, 11, 3),
  );
}

RestaurantLanHost _host(
  LanTlsMaterial material, {
  required RestaurantLocalOrderQueueService orders,
  required RestaurantLocalPrintQueueService prints,
  required Uri bridge,
}) {
  return RestaurantLanHost(
    restaurantId: seller,
    branchId: branchA,
    orders: orders,
    printQueue: prints,
    printBridgeUri: bridge,
    deviceStore: MemoryLanEnrollmentStore(),
    operatorFingerprint: material.operatorFingerprint,
    certificateDirectory: material.directory.path,
    staffStillAuthorized: (_) async => const StaffProbe(StaffProbeKind.active),
    stationsOverride: const <Map<String, dynamic>>[
      <String, dynamic>{'id': ocak},
      <String, dynamic>{'id': firin},
      <String, dynamic>{'id': kasap},
    ],
    tablesOverride: const <Map<String, dynamic>>[],
    productsOverride: <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Çorba', 'station_id': ocak, 'price': 40},
      <String, dynamic>{'name': 'Pide', 'station_id': firin, 'price': 40},
      <String, dynamic>{'name': 'Köfte', 'station_id': kasap, 'price': 40},
      for (var index = 0; index < 60; index++) ...<Map<String, dynamic>>[
        <String, dynamic>{'name': 'Ürün $index', 'station_id': ocak, 'price': 40},
        <String, dynamic>{'name': 'Satır $index', 'station_id': ocak, 'price': 40},
        <String, dynamic>{'name': 'Kalem $index', 'station_id': ocak, 'price': 40},
      ],
    ],
  );
}

Future<RestaurantLanClient> _pair(
  RestaurantLanHost host,
  LanTlsMaterial material,
  Directory directory,
) async {
  final owner = RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: material.operatorContext,
    pinnedServerFingerprint: material.serverFingerprint,
  );
  final issued = await owner.post('/lan/pair/issue', <String, Object?>{});
  expect(issued['status'], 200, reason: issued['error']?.toString());
  final request = await LanClientRequest.generate(directory: directory, commonName: 'staff-a');
  final anonymous = RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('${material.directory.path}/ca.pem'),
    pinnedServerFingerprint: material.serverFingerprint,
  );
  final redeemed = await anonymous.post('/lan/pair/redeem', <String, Object?>{
    'code': issued['code'],
    'staff_id': 'staff-a',
    'csr': request.csr,
  });
  expect(redeemed['ok'], isTrue, reason: redeemed['error']?.toString());
  await request.installSignedCertificate(
    certificate: redeemed['certificate'].toString(),
    caPath: '${material.directory.path}/ca.pem',
  );
  return RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: SecurityContext(withTrustedRoots: false)
      ..useCertificateChain('${directory.path}/client.pem')
      ..usePrivateKey('${directory.path}/client.key')
      ..setTrustedCertificates('${material.directory.path}/ca.pem'),
    pinnedServerFingerprint: material.serverFingerprint,
    staffId: 'staff-a',
  );
}

Future<Map<String, dynamic>> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _rpc(String base, Map<String, dynamic> body) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse(base).replace(path: '/rpc/create_table_order_with_print_jobs'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${_jwt(seller)}');
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return <String, dynamic>{'status': response.statusCode, 'text': text};
  } finally {
    client.close(force: true);
  }
}

Future<String> _sql(String psql, String query) async {
  final result = await Process.run(psql, <String>[
    '-h',
    '127.0.0.1',
    '-p',
    Platform.environment['IBUL_PGPORT'] ?? '',
    '-U',
    Platform.environment['IBUL_PGUSER'] ?? 'ibul',
    '-d',
    Platform.environment['IBUL_PGDB'] ?? '',
    '-tA',
    '-c',
    query,
  ]);
  if (result.exitCode != 0) {
    final detail = (result.stderr as String).split('\n').first;
    throw StateError('isolated query failed: $detail');
  }
  return (result.stdout as String).trim();
}

Future<String> _modulus(String keyPath) async {
  final modulus = await Process.run('openssl', <String>[
    'rsa',
    '-in',
    keyPath,
    '-noout',
    '-modulus',
  ]);
  if (modulus.exitCode != 0) throw StateError('modulus unavailable');
  final text = (modulus.stdout as String).trim();
  return text.substring(text.indexOf('=') + 1).trim().toLowerCase();
}

Future<void> _registerServerKey(String psql, LanTlsMaterial material) async {
  final identity = await LanTlsMaterial.evidenceIdentity(material.directory);
  await _sql(
    psql,
    "insert into public.restaurant_lan_print_evidence_keys "
    "(restaurant_id, branch_id, key_id, server_fingerprint, modulus, exponent, revoked) values "
    "('$seller', '$branchA', '${identity.id}', '${material.serverFingerprint}', "
    "decode('${identity.modulusHex}', 'hex'), 65537, false) "
    "on conflict (restaurant_id, key_id) do update set "
    "server_fingerprint = excluded.server_fingerprint, "
    "modulus = excluded.modulus, exponent = excluded.exponent, revoked = false",
  );
}

Future<String> _sign(String keyPath, String payload) async {
  final process = await Process.start('openssl', <String>[
    'dgst',
    '-sha256',
    '-sign',
    keyPath,
  ]);
  process.stdin.add(utf8.encode(payload));
  await process.stdin.close();
  final bytes = await process.stdout.fold<List<int>>(
    <int>[],
    (previous, chunk) => previous..addAll(chunk),
  );
  if (await process.exitCode != 0 || bytes.isEmpty) {
    throw StateError('signature unavailable');
  }
  const alphabet = '0123456789abcdef';
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer
      ..write(alphabet[(byte >> 4) & 0xf])
      ..write(alphabet[byte & 0xf]);
  }
  return buffer.toString();
}

String _jwt(
  String subject, {
  String role = 'authenticated',
  String? sessionId,
  int? exp,
}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = part(<String, String>{'alg': 'HS256', 'typ': 'JWT'});
  final payload = part(<String, Object>{
    'role': role,
    'sub': subject,
    'session_id': sessionId ?? (subject == waiterId ? 'waiter-session' : 'test-session'),
    'exp': exp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  });
  final mac = Hmac(sha256, utf8.encode(jwtSecret)).convert(utf8.encode('$header.$payload'));
  return '$header.$payload.${base64Url.encode(mac.bytes).replaceAll('=', '')}';
}

void _report(String stage, List<int> micros) {
  final sorted = <int>[...micros]..sort();
  int at(double p) => sorted[((sorted.length - 1) * p).ceil()];
  stdout.writeln(
    'FAKE_BRIDGE_STAGE $stage n=${sorted.length} '
    'p50=${(at(0.50) / 1000).toStringAsFixed(3)}ms '
    'p95=${(at(0.95) / 1000).toStringAsFixed(3)}ms',
  );
}

class FakePrintBridge {
  HttpServer? _server;
  int port = 0;
  String mode = 'ok';
  bool forcePhysical = false;
  int accepted = 0;
  final List<Map<String, dynamic>> jobs = <Map<String, dynamic>>[];
  final Set<String> _seen = <String>{};

  Uri get base => Uri.parse('http://127.0.0.1:$port');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    port = _server!.port;
    if (port == 3001) {
      throw StateError('fake bridge must not use the real bridge port');
    }
    _server!.listen((request) => _handle(request));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/health') {
      await _json(request, 200, <String, Object?>{
        'ok': true,
        'service': 'ibul-local-print-bridge',
        'bridge_version': 'isolated-test',
      });
      return;
    }
    if (request.uri.path == '/printers') {
      await _json(request, 200, <String, Object?>{
        'ok': true,
        'count': 0,
        'printers': <Object?>[],
        'queue': 'none',
      });
      return;
    }
    if (request.uri.path != '/print/kitchen' || request.method != 'POST') {
      await _json(request, 404, <String, Object?>{'ok': false});
      return;
    }
    final text = await utf8.decoder.bind(request).join();
    final body = jsonDecode(text);
    final job = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final key = '${job['print_job_id']}|${job['manual_reprint_token'] ?? ''}';
    if (mode == 'drop') {
      jobs.add(job);
      final socket = await request.response.detachSocket(writeHeaders: false);
      await socket.close();
      return;
    }
    if (mode == 'hang') {
      jobs.add(job);
      mode = 'ok';
      await Future<void>.delayed(const Duration(seconds: 2));
      return;
    }
    if (mode == 'reject') {
      await _json(request, 503, <String, Object?>{
        'ok': false,
        'errorCode': 'print_system_disabled',
      });
      return;
    }
    if (_seen.contains(key)) {
      await _json(request, 200, <String, Object?>{
        'ok': true,
        'duplicate': true,
        'errorCode': 'already_processed',
        'print_job_id': job['print_job_id'],
        'message': 'Job already processed by this bridge.',
      });
      return;
    }
    _seen.add(key);
    accepted += 1;
    jobs.add(<String, dynamic>{
      ...job,
      'physical_confirmation_sent': forcePhysical,
    });
    await _json(request, 200, <String, Object?>{
      'ok': true,
      'duplicate': false,
      'print_job_id': job['print_job_id'],
      'job_id': 'fake-${jobs.length}',
      'bytes_sent': 0,
      'physical_confirmation': forcePhysical,
      'confirmation_status': 'not_a_device_ack',
      'document_type': 'kitchen',
      'actual_backend': 'none',
      'queue_status': 'accepted',
      'message': 'Accepted by the isolated bridge. No printer was contacted.',
    });
  }

  Future<void> _json(HttpRequest request, int status, Map<String, Object?> body) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}

class _RealHttpOverrides extends HttpOverrides {}
