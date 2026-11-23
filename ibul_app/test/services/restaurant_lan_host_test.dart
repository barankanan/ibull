import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_authority_seal.dart';
import 'package:ibul_app/services/restaurant_offline/lan_channel.dart';
import 'package:ibul_app/services/restaurant_offline/lan_staff_probe.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_order_router.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_sync_service.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late Directory temp;
  late LanTlsMaterial material;
  late LanClientCertificate waiterA;
  late LanClientCertificate waiterB;
  late LanClientCertificate stranger;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('ibul-lan-tls');
    material = await LanTlsMaterial.open(Directory('${temp.path}/host'));
    waiterA = await LanClientCertificate.generate(
      directory: Directory('${temp.path}/waiter-a'),
      commonName: 'waiter-a',
    );
    waiterB = await LanClientCertificate.generate(
      directory: Directory('${temp.path}/waiter-b'),
      commonName: 'waiter-b',
    );
    stranger = await LanClientCertificate.generate(
      directory: Directory('${temp.path}/stranger'),
      commonName: 'stranger',
    );
  });

  tearDownAll(() async {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  setUp(() {
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
  });

  test('tls waiters save once and a closed host reports failure', () async {
    const restaurantId = 'lan-host-rest';
    var prints = 0;
    final host = _host(
      material,
      restaurantId: restaurantId,
      branchId: 'branch-1',
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      tablesOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'Masa 1', 'printer_ip': '10.0.0.8'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'corba',
          'name': 'Çorba',
          'station_id': 'ocak',
          'price': 40,
        },
        <String, dynamic>{
          'id': 'izgara',
          'name': 'Izgara',
          'station_id': 'ocak',
          'price': 90,
        },
      ],
      enablePhysicalPrint: true,
      onPhysicalPrint: (_) async {
        prints += 1;
      },
    );
    await _listen(host, material);
    addTearDown(host.stop);

    final discovered = await _anonymous(host, material).get('/lan/discover');
    expect(discovered['service'], 'ibul-lan');
    expect(discovered.containsKey('printer_ip'), isFalse);

    final session = await _pair(host, material, waiterA.directory, 'staff-a');
    final tables = await session.postAuthorized('/lan/tables', <String, Object?>{});
    expect(tables['status'], 200);
    expect((tables['tables'] as List).single.containsKey('printer_ip'), isFalse);

    final saved = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'lan-order-1',
      'table_number': 1,
      'station_id': 'ocak',
      'branch_id': 'branch-1',
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'name': 'Çorba',
          'quantity': 1,
          'service_children': <Map<String, Object?>>[
            <String, Object?>{'name': 'Ekmek'},
          ],
        },
      ],
    });
    expect(saved['saved'], isTrue);
    expect(saved['printed'], isFalse);
    expect(saved['print_status'], 'forwarded');
    expect(prints, 1);

    final again = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'lan-order-1',
      'table_number': 1,
      'station_id': 'ocak',
      'revision': '1',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(again['duplicate'], isTrue);
    expect(prints, 1);

    final conflict = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'lan-order-1',
      'table_number': 1,
      'station_id': 'ocak',
      'revision': '1',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Izgara', 'quantity': 1, 'price': 90},
      ],
    });
    expect(conflict['status'], 409);
    expect(conflict['saved'], isFalse);

    final otherBranch = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'lan-order-branch',
      'table_number': 1,
      'station_id': 'ocak',
      'branch_id': 'branch-2',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(otherBranch['status'], 403);

    final otherStore = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'lan-order-store',
      'restaurant_id': 'other-store',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(otherStore['status'], 403);

    await host.stop();
    await expectLater(
      _anonymous(host, material).postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'lan-order-6',
      }),
      throwsA(isA<SocketException>()),
    );
  });

  test('plain http and a stolen bearer do not authorize a device', () async {
    final host = _host(material, restaurantId: 'lan-plain');
    await _listen(host, material);
    addTearDown(host.stop);
    final issued = await _owner(host, material).post('/lan/pair/issue', <String, Object?>{});
    final code = issued['code']?.toString() ?? '';
    expect(code, hasLength(32));

    final socket = await Socket.connect('127.0.0.1', host.port);
    socket.add(utf8.encode(
      'POST /lan/orders HTTP/1.1\r\nHost: 127.0.0.1\r\n'
      'Authorization: Bearer $code\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}',
    ));
    final raw = await socket.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    await socket.close();
    final text = utf8.decode(raw, allowMalformed: true);
    expect(text.contains(code), isFalse);
    expect(text.contains('saved'), isFalse);

    final bare = HttpClient();
    bare.badCertificateCallback = (certificate, _, _) {
      return LanTlsMaterial.fingerprintOf(certificate) ==
          material.serverFingerprint;
    };
    addTearDown(bare.close);
    final request = await bare.postUrl(Uri.parse('https://127.0.0.1:${host.port}/lan/orders'));
    request.headers.set('authorization', 'Bearer stolen-token');
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode('{"seq":1,"body":{"staff_id":"staff-a"}}'));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    expect(response.statusCode, 401);
    expect(body.contains('saved'), isFalse);
    expect(await RestaurantLocalOrderQueueService().list('lan-plain'), isEmpty);
  });

  test('revoked, expired, replayed and foreign certificates stay closed', () async {
    var now = DateTime.utc(2026, 11, 3, 12);
    var probe = () async => const StaffProbe(StaffProbeKind.active);
    final store = MemoryLanEnrollmentStore();
    final orders = RestaurantLocalOrderQueueService();
    final host = _host(
      material,
      restaurantId: 'lan-auth',
      orders: orders,
      deviceStore: store,
      deviceGrantTtl: const Duration(minutes: 15),
      clock: () => now,
      staffStillAuthorized: (_) => probe(),
      tablesOverride: const <Map<String, dynamic>>[],
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
      ],
    );
    await _listen(host, material);
    addTearDown(host.stop);
    final session = await _pair(host, material, waiterA.directory, 'staff-a');

    final strangerClient = _client(host, material, stranger, staffId: 'staff-a');
    await _expectClosed(strangerClient.post('/lan/pair/redeem', <String, Object?>{
      'code': '000000',
      'staff_id': 'staff-a',
    }));
    await _expectClosed(strangerClient.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'foreign',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    }));

    final once = await session.post('/lan/tables', <String, Object?>{
      'seq': session.seq + 1,
      'body': <String, Object?>{'staff_id': 'staff-a'},
    });
    session.seq += 1;
    expect(once['status'], 200);
    final replay = await session.post('/lan/tables', <String, Object?>{
      'seq': session.seq,
      'body': <String, Object?>{'staff_id': 'staff-a'},
    });
    expect(replay['status'], 401);

    probe = () async => const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Personel kaydı bulunamadı.',
    );
    final revokedByStaff = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'revoked-staff',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(revokedByStaff['status'], 401);
    expect(revokedByStaff['error'], 'Personel kaydı bulunamadı.');
    expect(revokedByStaff['error'], isNot('Personel sunucusuna ulaşılamadı.'));
    expect(await orders.list('lan-auth'), isEmpty);

    await host.stop();
    final restarted = _host(
      material,
      restaurantId: 'lan-auth',
      orders: orders,
      deviceStore: store,
      deviceGrantTtl: const Duration(minutes: 15),
      clock: () => now,
      staffStillAuthorized: (_) => probe(),
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
      ],
    );
    await _listen(restarted, material);
    addTearDown(restarted.stop);
    final afterRestart = await _signed(
      restarted,
      material,
      waiterA.directory,
      'staff-a',
    ).postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'after-revoke',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(afterRestart['status'], 401);

    probe = () async => const StaffProbe(StaffProbeKind.active);
    final freshHost = _host(
      material,
      restaurantId: 'lan-expiry',
      orders: orders,
      deviceGrantTtl: const Duration(minutes: 15),
      clock: () => now,
      staffStillAuthorized: (_) => probe(),
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
      ],
    );
    await _listen(freshHost, material);
    addTearDown(freshHost.stop);
    final fresh = await _pair(freshHost, material, waiterB.directory, 'staff-b');
    final whileOffline = await fresh.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'offline-ok',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(whileOffline['saved'], isTrue);
    probe = () async => throw const SocketException('Connection refused');
    final stillInside = await fresh.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'offline-window',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(stillInside['saved'], isTrue);
    final verifiedUntil = now.add(const Duration(minutes: 15));
    now = now.subtract(const Duration(minutes: 1));
    final clockBack = await fresh.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'clock-back',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(clockBack['status'], 401);
    expect(clockBack['error'], contains('geri alındı'));
    now = verifiedUntil;
    final expired = await fresh.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'offline-late',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(expired['status'], 401);
    final payment = await fresh.postAuthorized('/lan/payments', <String, Object?>{
      'amount': 10,
    });
    expect(payment['status'], isNot(200));
  });

  test('two waiters keep both orders and device revoke is immediate', () async {
    final host = _host(
      material,
      restaurantId: 'lan-race',
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
        <String, dynamic>{'id': 'firin'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
        <String, dynamic>{'name': 'Pide', 'station_id': 'firin', 'price': 70},
      ],
    );
    await _listen(host, material);
    addTearDown(host.stop);
    final a = await _pair(host, material, waiterA.directory, 'staff-1');
    final b = await _pair(host, material, waiterB.directory, 'staff-2');
    final results = await Future.wait(<Future<Map<String, dynamic>>>[
      a.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'race-a',
        'table_number': 1,
        'station_id': 'ocak',
        'items': <Map<String, Object?>>[
          <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
        ],
      }),
      b.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'race-b',
        'table_number': 1,
        'station_id': 'firin',
        'items': <Map<String, Object?>>[
          <String, Object?>{'name': 'Pide', 'quantity': 1, 'price': 70},
        ],
      }),
    ]);
    expect(results.every((row) => row['saved'] == true), isTrue);
    await _owner(host, material).post('/lan/revoke', <String, Object?>{
      'device_id': host.devices
          .firstWhere((device) => device.staffId == 'staff-1')
          .deviceId,
    });
    final after = await a.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'race-c',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(after['status'], 401);
    expect(host.deviceCount, 1);
  });

  test('center status is read-only, authorised and honest about the bridge', () async {
    final bridge = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => bridge.close(force: true));
    bridge.listen((request) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'service': 'ibul-local-print-bridge'}),
      );
      request.response.close();
    });
    final bridgeUri = Uri.parse('http://127.0.0.1:${bridge.port}');
    final host = _host(
      material,
      restaurantId: 'lan-status',
      printBridgeUri: bridgeUri,
      tablesOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'table_number': 1},
        <String, dynamic>{'table_number': 2},
      ],
    );
    await _listen(host, material);
    addTearDown(host.stop);
    final a = await _pair(host, material, waiterA.directory, 'staff-a');
    final b = await _pair(host, material, waiterB.directory, 'staff-b');

    final open = await a.postAuthorized('/lan/center/status', <String, Object?>{});
    expect(open['status'], 200);
    expect(open['ok'], isTrue);
    expect((open['print_center'] as Map)['reachable'], isTrue);
    expect((open['overview'] as Map)['tables_total'], 2);
    expect(open.containsKey('generated_at'), isTrue);
    expect(open.containsKey('machine_id'), isTrue);
    expect(open.toString().toLowerCase(), isNot(contains('revenue')));

    // The bridge goes away: the answer says so instead of guessing.
    await bridge.close(force: true);
    final down = await b.postAuthorized('/lan/center/status', <String, Object?>{});
    expect(down['status'], 200);
    expect((down['print_center'] as Map)['reachable'], isFalse);

    // A revoked device gets nothing.
    await _owner(host, material).post('/lan/revoke', <String, Object?>{
      'device_id': host.devices
          .firstWhere((device) => device.staffId == 'staff-a')
          .deviceId,
    });
    final revoked = await a.postAuthorized('/lan/center/status', <String, Object?>{});
    expect(revoked['status'], 401);
    expect(revoked.containsKey('print_center'), isFalse);
    // The operator certificate is not a paired device.
    final unpaired = await _owner(host, material).post('/lan/center/status', <String, Object?>{});
    expect(unpaired['status'], 401);
    expect(unpaired.containsKey('print_center'), isFalse);
  });

  test('an unreachable probe does not admit staff who were never verified', () async {
    final host = _host(
      material,
      restaurantId: 'lan-never',
      staffStillAuthorized: (_) async =>
          throw const SocketException('Connection refused'),
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
      ],
    );
    await _listen(host, material);
    addTearDown(host.stop);
    final session = await _pair(host, material, waiterB.directory, 'staff-new');
    final denied = await session.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'never-verified',
      'table_number': 1,
      'station_id': 'ocak',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(denied['status'], 401);
    expect(denied['error'], 'Personel daha önce doğrulanmadı.');
    expect(denied['error'], isNot('Personel sunucusuna ulaşılamadı.'));
  });

  test('a listening host is the offline route only while it is up', () async {
    final connectivity = RestaurantConnectivityService();
    connectivity.debugSkipNetworkProbes = true;
    connectivity.debugSetConnectivity(
      hasNetwork: false,
      supabaseReachable: false,
      bridgeReachable: false,
    );
    var now = DateTime.utc(2026, 11, 3, 12);
    final router = RestaurantOfflineOrderRouter(
      connectivityService: connectivity,
      clock: () => now,
    );
    final host = _host(material, restaurantId: 'lan-route');
    await _listen(host, material);
    addTearDown(host.stop);
    expect(
      await router.shouldRouteOffline(
        restaurantId: 'lan-route',
        storeCategory: 'Restoran',
      ),
      isTrue,
    );
    connectivity.debugSetConnectivity(
      hasNetwork: true,
      supabaseReachable: true,
      bridgeReachable: true,
    );
    expect(
      await router.shouldRouteOfflineFast(
        restaurantId: 'lan-route',
        storeCategory: 'Restoran',
      ),
      isTrue,
    );
    now = now.add(const Duration(seconds: 3));
    expect(
      await router.shouldRouteOffline(
        restaurantId: 'lan-route',
        storeCategory: 'Restoran',
      ),
      isFalse,
    );
    connectivity.debugSetConnectivity(
      hasNetwork: false,
      supabaseReachable: false,
      bridgeReachable: false,
    );
    now = now.add(const Duration(seconds: 3));
    await host.stop();
    expect(
      await router.shouldRouteOffline(
        restaurantId: 'lan-route',
        storeCategory: 'Restoran',
      ),
      isFalse,
    );
  });

  test('sync evidence is host-only and conflicts stay conflicts', () {
    expect(
      planLanOrderSync(listeningHost: false, printStatus: 'forwarded').action,
      'hold',
    );
    expect(
      planLanOrderSync(listeningHost: true, printStatus: 'printed').evidence,
      'forwarded',
    );
    expect(
      planLanOrderSync(listeningHost: true, printStatus: 'uncertain').evidence,
      'uncertain',
    );
    expect(
      planLanOrderSync(listeningHost: true, printStatus: 'failed').evidence,
      'failed',
    );
    expect(
      lanSyncErrorIsConflict('Aynı sipariş kimliği farklı içerikle geldi.'),
      isTrue,
    );
    expect(lanSyncErrorIsConflict('timeout'), isFalse);
  });

  test('pairing attempts lock and a second authority is refused', () async {
    const restaurantId = 'lan-guard';
    final host = _host(material, restaurantId: restaurantId);
    await _listen(host, material);
    addTearDown(host.stop);
    final issued = await _owner(host, material).post('/lan/pair/issue', <String, Object?>{});
    final code = issued['code'].toString();
    expect(code, hasLength(32));
    for (var attempt = 0; attempt < 5; attempt++) {
      final failed = await _anonymous(host, material).post('/lan/pair/redeem', <String, Object?>{
        'code': '0' * 32,
        'staff_id': 'staff-a',
        'csr': '-----BEGIN CERTIFICATE REQUEST-----\n${'A' * 40}\n-----END CERTIFICATE REQUEST-----',
      });
      expect(failed['status'], 401);
    }
    final locked = await _anonymous(host, material).post('/lan/pair/redeem', <String, Object?>{
      'code': code,
      'staff_id': 'staff-a',
      'csr': '-----BEGIN CERTIFICATE REQUEST-----\n${'A' * 40}\n-----END CERTIFICATE REQUEST-----',
    });
    expect(locked['status'], 429);
    expect(locked['error'].toString().contains(code), isFalse);

    final other = _host(material, restaurantId: restaurantId);
    expect(
      () => _listen(other, material),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('başka bir sipariş otoritesi'),
        ),
      ),
    );
  });

  test('sha1 enrollment is revoked and unspecified listen is refused', () async {
    final store = MemoryLanEnrollmentStore();
    await store.writeJson('lan_device_enrollment_v1_lan-sha', <String, dynamic>{
      'devices': <Map<String, dynamic>>[
        <String, dynamic>{
          'device_id': 'ab' * 20,
          'paired_at': DateTime.utc(2026).toIso8601String(),
          'staff_id': 'old',
          'revoked': false,
        },
      ],
    });
    final host = _host(material, restaurantId: 'lan-sha', deviceStore: store);
    await _listen(host, material);
    addTearDown(host.stop);
    expect(host.devices.single.revoked, isTrue);
    expect(material.serverFingerprint, hasLength(64));
    expect(
      () => host.start(
        address: InternetAddress.anyIPv4,
        securityContext: material.serverContext,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('paired tablet prefers the main computer while the host keeps cloud', () async {
    final connectivity = RestaurantConnectivityService()
      ..debugSkipNetworkProbes = true
      ..debugSetConnectivity(
        hasNetwork: true,
        supabaseReachable: true,
        bridgeReachable: true,
      );
    addTearDown(connectivity.dispose);
    final router = RestaurantOfflineOrderRouter(
      connectivityService: connectivity,
    );
    RestaurantLanPairing.transport = _RememberTransport();
    addTearDown(() => RestaurantLanPairing.transport = null);
    expect(
      await router.shouldRouteOfflineFast(
        restaurantId: 'tablet-floor',
        storeCategory: 'Restoran',
      ),
      isTrue,
    );
    expect(
      restaurantOrderRoute(
        supabaseReachable: true,
        lanReachable: true,
        lanIdentityVerified: true,
        pairedTablet: false,
      ),
      'cloud',
    );
  });

  test('tablet order stays on the host, survives reopen, and syncs once', () async {
    const restaurantId = 'lan-floor';
    final orders = RestaurantLocalOrderQueueService();
    final prints = RestaurantLocalPrintQueueService();
    final seen = <String>[];
    final floor = RestaurantLanHostRegistry.ordersAccepted.stream.listen((order) {
      if (order.restaurantId == restaurantId) seen.add(order.localOrderId);
    });
    addTearDown(floor.cancel);
    final host = _host(
      material,
      restaurantId: restaurantId,
      orders: orders,
      printQueue: prints,
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
        <String, dynamic>{'id': 'firin'},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'corba',
          'name': 'Çorba',
          'station_id': 'ocak',
          'price': 40,
        },
        <String, dynamic>{
          'id': 'pide',
          'name': 'Pide',
          'station_id': 'firin',
          'price': 70,
        },
      ],
    );
    await _listen(host, material);
    final sessionA = await _pair(host, material, waiterA.directory, 'staff-a');
    final sessionB = await _pair(host, material, waiterB.directory, 'staff-b');
    final samples = <int>[];
    for (var index = 0; index < 10; index++) {
      final watch = Stopwatch()..start();
      final saved = await sessionA.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'floor-$index',
        'table_number': 3,
        'station_id': index.isEven ? 'ocak' : 'firin',
        'items': <Map<String, Object?>>[
          <String, Object?>{
            'name': index.isEven ? 'Çorba' : 'Pide',
            'quantity': 1,
          },
        ],
      });
      samples.add(watch.elapsedMicroseconds);
      expect(saved['saved'], isTrue);
      expect(saved['duplicate'], isFalse);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    final p95 = samples[(samples.length * 0.95).floor()];
    debugPrint('LAN_ACCEPT_US median=$median p95=$p95');
    expect(await orders.list(restaurantId), hasLength(10));
    expect(await prints.list(restaurantId), hasLength(10));
    expect(seen, hasLength(10));
    final repeat = await sessionA.postAuthorized('/lan/orders', <String, Object?>{
      'local_order_id': 'floor-0',
      'table_number': 3,
      'station_id': 'ocak',
      'revision': '1',
      'items': <Map<String, Object?>>[
        <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
    });
    expect(repeat['duplicate'], isTrue);
    expect(await orders.list(restaurantId), hasLength(10));
    expect(await prints.list(restaurantId), hasLength(10));
    final floorView = await sessionB.postAuthorized('/lan/floor', <String, Object?>{});
    expect(floorView['status'], 200);
    expect((floorView['orders'] as List), hasLength(10));
    await host.stop();
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    RestaurantLocalPrintQueueService.clearAllMemoryForTests();
    final reopenedOrders = RestaurantLocalOrderQueueService();
    final reopenedPrints = RestaurantLocalPrintQueueService();
    expect(await reopenedOrders.list(restaurantId), hasLength(10));
    expect(await reopenedPrints.list(restaurantId), hasLength(10));
    expect(
      (await reopenedOrders.list('other-restaurant')),
      isEmpty,
    );

    final cloudIds = <String>{};
    final evidenceSeen = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      final body = jsonDecode(text) as Map<String, dynamic>;
      final id = body['p_local_order_id']?.toString() ?? '';
      cloudIds.add(id);
      evidenceSeen.add(body['p_local_print_evidence']?.toString());
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{
        'order_id': 'remote-$id',
        'order_number': '1',
      }));
      await request.response.close();
    });
    // A center registered with the cloud (has a branch) can sign the
    // "uncertain" evidence that every unfinished local print state goes up as.
    final restarted = _host(
      material,
      restaurantId: restaurantId,
      branchId: 'branch-1',
      orders: reopenedOrders,
      printQueue: reopenedPrints,
    );
    await _listen(restarted, material);
    addTearDown(restarted.stop);
    final connectivity = RestaurantConnectivityService()
      ..debugSkipNetworkProbes = true
      ..debugSetConnectivity(hasNetwork: true, supabaseReachable: true);
    addTearDown(connectivity.dispose);
    final sync = RestaurantOfflineSyncService(
      orderQueue: reopenedOrders,
      connectivityService: connectivity,
      isolatedPostgrestUri: Uri.parse('http://127.0.0.1:${server.port}'),
      isolatedAccessToken: 'isolated-test',
    );
    final syncSamples = <int>[];
    var synced = 0;
    for (var attempt = 0; attempt < 10; attempt++) {
      final watch = Stopwatch()..start();
      synced += await sync.syncPendingOrders(restaurantId: restaurantId, limit: 20);
      syncSamples.add(watch.elapsedMicroseconds);
    }
    syncSamples.sort();
    debugPrint(
      'LAN_SYNC_US median=${syncSamples[syncSamples.length ~/ 2]} '
      'p95=${syncSamples[(syncSamples.length * 0.95).floor()]} '
      'synced=$synced cloud=${cloudIds.length}',
    );
    expect(synced, 10);
    expect(cloudIds, hasLength(10));
    // Nothing reached a printer here (not_sent): signed "failed" evidence,
    // so the cloud may print. Never a bare, evidence-less order.
    expect(evidenceSeen, hasLength(10));
    expect(
      evidenceSeen.every((e) => e != null && e.startsWith('v2.failed.')),
      isTrue,
    );
    expect(
      await sync.syncPendingOrders(restaurantId: restaurantId, limit: 20),
      0,
    );
    expect(cloudIds, hasLength(10));
  });

  test('one offline order syncs once and a dropped reply can be retried', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    final orders = RestaurantLocalOrderQueueService();
    final host = _host(
      material,
      restaurantId: 'rest-sync',
      branchId: 'branch-1',
      orders: orders,
    );
    await _listen(host, material);
    addTearDown(host.stop);

    var calls = 0;
    final sentEvidence = <String?>[];
    var failFirst = true;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      calls += 1;
      final raw = await utf8.decoder.bind(request).join();
      sentEvidence.add(
        (jsonDecode(raw) as Map<String, dynamic>)['p_local_print_evidence']?.toString(),
      );
      if (failFirst) {
        failFirst = false;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'order_id': 'remote-one',
          'order_number': '1',
        }),
      );
      await request.response.close();
    });

    // Güncel bir kayıt: iki günden eski kayıtlar otomatik eşitlemeye girmez.
    final now = DateTime.now().toUtc();
    await orders.enqueue(
      order: RestaurantLocalOrderRecord(
        localOrderId: 'local-one',
        restaurantId: 'rest-sync',
        tableId: '4',
        tableName: 'Masa 4',
        tableNumber: 4,
        waiterId: '',
        waiterName: 'Ali',
        items: const <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'price': 40},
        ],
        notes: '',
        total: 40,
        stationGroups: const <Map<String, dynamic>>[],
        printStatus: 'pending',
        syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final connectivity = RestaurantConnectivityService()
      ..debugSkipNetworkProbes = true
      ..debugSetConnectivity(
        hasNetwork: true,
        supabaseReachable: true,
        lanHostReachable: true,
      );
    addTearDown(connectivity.dispose);
    final sync = RestaurantOfflineSyncService(
      orderQueue: orders,
      connectivityService: connectivity,
      isolatedPostgrestUri: Uri.parse('http://127.0.0.1:${server.port}'),
      isolatedAccessToken: 'isolated-test',
    );
    final samples = <int>[];
    var synced = 0;
    for (var attempt = 0; attempt < 10; attempt++) {
      final watch = Stopwatch()..start();
      synced += await sync.syncPendingOrders(restaurantId: 'rest-sync');
      samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    final p95 = samples[(samples.length * 0.95).floor().clamp(0, samples.length - 1)];
    debugPrint('OFFLINE_SYNC_US median=$median p95=$p95 calls=$calls synced=$synced');
    expect(synced, 1);
    expect(calls, 2);
    // A "pending" record (center may have stopped mid-print) is sent twice
    // with the same signed uncertain evidence, never as a bare order.
    expect(sentEvidence, hasLength(2));
    expect(sentEvidence.every((e) => e != null && e.startsWith('v2.uncertain.')), isTrue);
    expect(sentEvidence[0], sentEvidence[1]);
    final stored = await orders.getByLocalId(
      restaurantId: 'rest-sync',
      localOrderId: 'local-one',
    );
    expect(stored?.syncStatus, RestaurantLocalOrderSyncStatus.synced);
    expect(stored?.remoteOrderId, 'remote-one');
    expect(await orders.list('rest-sync'), hasLength(1));
  });

  group('Sync auth hold (expired / refused session never fails an order)', () {
    Future<
      ({
        RestaurantOfflineSyncService sync,
        RestaurantLocalOrderQueueService orders,
        List<String?> auth,
        HttpServer server,
      })
    >
    setUpSync({
      required List<int> statuses,
      required Future<String> Function({required bool forceRefresh}) tokens,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      RestaurantLocalOrderQueueService.clearAllMemoryForTests();
      final orders = RestaurantLocalOrderQueueService();
      final host = _host(
        material,
        restaurantId: 'rest-auth',
        branchId: 'branch-1',
        orders: orders,
      );
      await _listen(host, material);
      addTearDown(host.stop);
      final auth = <String?>[];
      var call = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        auth.add(request.headers.value(HttpHeaders.authorizationHeader));
        final status = statuses[call < statuses.length ? call : statuses.length - 1];
        call++;
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          status == 200
              ? jsonEncode(<String, Object?>{'order_id': 'remote-auth', 'order_number': '1'})
              : '{"error":"unauthorized"}',
        );
        await request.response.close();
      });
      final now = DateTime.now().toUtc();
      await orders.enqueue(
        order: RestaurantLocalOrderRecord(
          localOrderId: 'local-auth',
          restaurantId: 'rest-auth',
          tableId: '4',
          tableName: 'Masa 4',
          tableNumber: 4,
          waiterId: '',
          waiterName: 'Ali',
          items: const <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'price': 40},
          ],
          notes: '',
          total: 40,
          stationGroups: const <Map<String, dynamic>>[],
          printStatus: 'pending',
          syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final connectivity = RestaurantConnectivityService()
        ..debugSkipNetworkProbes = true
        ..debugSetConnectivity(
          hasNetwork: true,
          supabaseReachable: true,
          lanHostReachable: true,
        );
      addTearDown(connectivity.dispose);
      final sync = RestaurantOfflineSyncService(
        orderQueue: orders,
        connectivityService: connectivity,
        isolatedEvidenceVerifierUri: Uri.parse('http://127.0.0.1:${server.port}/'),
        isolatedAccessToken: 'x',
      )..accessTokenProvider = tokens;
      return (sync: sync, orders: orders, auth: auth, server: server);
    }

    test('no usable session: nothing is sent and the order is NOT marked failed', () async {
      final ctx = await setUpSync(
        statuses: const [200],
        tokens: ({required bool forceRefresh}) async =>
            throw const SyncAuthUnavailable('oturum yenilenemedi'),
      );
      final synced = await ctx.sync.syncPendingOrders(restaurantId: 'rest-auth');
      expect(synced, 0);
      expect(ctx.auth, isEmpty, reason: 'sunucuya hiçbir istek gitmemeli');
      final stored = await ctx.orders.getByLocalId(
        restaurantId: 'rest-auth',
        localOrderId: 'local-auth',
      );
      expect(stored?.syncStatus, RestaurantLocalOrderSyncStatus.pendingSync);
      expect(stored?.syncError ?? '', isEmpty);
      expect(RestaurantOfflineSyncService.authNotice.value, contains('Oturum doğrulanamadı'));
    });

    test('server 401 once: session is refreshed, same order sent once, notice cleared', () async {
      final refreshes = <bool>[];
      final ctx = await setUpSync(
        statuses: const [401, 200],
        tokens: ({required bool forceRefresh}) async {
          refreshes.add(forceRefresh);
          return forceRefresh ? 'a.b.fresh' : 'a.b.stale';
        },
      );
      final synced = await ctx.sync.syncPendingOrders(restaurantId: 'rest-auth');
      expect(synced, 1);
      expect(refreshes, [false, true]);
      expect(ctx.auth, ['Bearer a.b.stale', 'Bearer a.b.fresh']);
      expect(RestaurantOfflineSyncService.authNotice.value, isNull);
      expect(await ctx.orders.list('rest-auth'), hasLength(1));
    });

    test('server keeps refusing: held as pending (not failed), then goes once session is back', () async {
      var good = false;
      final ctx = await setUpSync(
        statuses: const [401, 401, 200],
        tokens: ({required bool forceRefresh}) async => good ? 'a.b.good' : 'a.b.bad',
      );
      expect(await ctx.sync.syncPendingOrders(restaurantId: 'rest-auth'), 0);
      var stored = await ctx.orders.getByLocalId(
        restaurantId: 'rest-auth',
        localOrderId: 'local-auth',
      );
      expect(stored?.syncStatus, RestaurantLocalOrderSyncStatus.pendingSync);
      expect(RestaurantOfflineSyncService.authNotice.value, isNotNull);
      good = true;
      expect(await ctx.sync.syncPendingOrders(restaurantId: 'rest-auth'), 1);
      stored = await ctx.orders.getByLocalId(
        restaurantId: 'rest-auth',
        localOrderId: 'local-auth',
      );
      expect(stored?.syncStatus, RestaurantLocalOrderSyncStatus.synced);
      expect(RestaurantOfflineSyncService.authNotice.value, isNull);
      expect(await ctx.orders.list('rest-auth'), hasLength(1));
    });

    test('a token that is not a three-part JWT is never sent', () {
      expect(RestaurantOfflineSyncService.looksLikeJwt(''), isFalse);
      expect(RestaurantOfflineSyncService.looksLikeJwt('sb_publishable_abc'), isFalse);
      expect(RestaurantOfflineSyncService.looksLikeJwt('a.b'), isFalse);
      expect(RestaurantOfflineSyncService.looksLikeJwt('a..c'), isFalse);
      expect(RestaurantOfflineSyncService.looksLikeJwt('a.b.c'), isTrue);
    });
  });

  test('legacy pairing box is not the transport and does not leak text', () {
    final box = sealLanBox(
      lanCodeKey('123456'),
      '{"name":"Çorba"}',
      direction: 'pair',
      nonce: 1,
    );
    expect(box.contains('Çorba'), isFalse);
    final raw = base64Decode(box);
    raw[raw.length - 1] ^= 1;
    expect(
      openLanBox(lanCodeKey('123456'), base64Encode(raw), direction: 'pair'),
      isNull,
    );
  });

  group('Offline staff authority (sealed, time-limited)', () {
    const rid = 'lan-offline-auth';
    const products = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
    ];
    const stations = <Map<String, dynamic>>[<String, dynamic>{'id': 'ocak'}];
    const tables = <Map<String, dynamic>>[
      <String, dynamic>{'id': 't1', 'table_number': 1, 'branch_id': 'b1', 'is_active': true},
      <String, dynamic>{'id': 't2', 'table_number': 2, 'branch_id': 'b2', 'is_active': true},
    ];
    late DateTime now;
    late String cloud; // active | down | revoked | otherBranch | noPermission
    late int epoch; // server credential_epoch
    var sendEpoch = true;
    late MemoryLanEnrollmentStore store;
    late RestaurantLocalOrderQueueService queue;

    setUp(() {
      now = DateTime.utc(2026, 11, 20, 9);
      cloud = 'active';
      epoch = 1;
      sendEpoch = true;
      store = MemoryLanEnrollmentStore();
      queue = RestaurantLocalOrderQueueService();
    });

    Future<Map<String, dynamic>?> membership(String staffId) async {
      if (cloud == 'down') throw const SocketException('Connection refused');
      if (cloud == 'revoked') return null;
      return <String, dynamic>{
        'store_id': rid,
        'status': 'active',
        'staff_role': 'waiter',
        'permissions': cloud == 'noPermission'
            ? const <String>['viewOrders']
            : const <String>['manageOrders'],
        'branch_id': cloud == 'otherBranch' ? 'b2' : 'b1',
        'must_change_password': cloud == 'tempPassword',
        if (sendEpoch) 'credential_epoch': epoch,
      };
    }

    RestaurantLanHost hostFor({
      LanAuthoritySealer? sealer,
      Duration ttl = const Duration(hours: 12),
      String? center = 'b1',
    }) {
      return _host(
        material,
        restaurantId: rid,
        branchId: center,
        orders: queue,
        deviceStore: store,
        deviceGrantTtl: ttl,
        authoritySealer: sealer,
        clock: () => now,
        stationsOverride: stations,
        tablesOverride: tables,
        productsOverride: products,
        staffStillAuthorized: lanStaffProbe(
          membership,
          restaurantId: rid,
          centerBranchId: () => center,
        ),
      );
    }

    Future<Map<String, dynamic>> order(RestaurantLanClient c, String id, {int table = 1}) {
      return c.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': id,
        'table_number': table,
        'station_id': 'ocak',
        'items': <Map<String, Object?>>[
          <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
        ],
      });
    }

    Future<RestaurantLanClient> pairedAndWarm(RestaurantLanHost host) async {
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      expect((await order(session, 'warm'))['status'], 200);
      return session;
    }

    test('a waiter verified online still orders with the cloud down', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      cloud = 'down';
      now = now.add(const Duration(hours: 5));
      final result = await order(session, 'during-outage');
      expect(result['status'], 200, reason: result['error']?.toString());
      expect((await queue.list(rid)).map((o) => o.localOrderId), contains('during-outage'));
    });

    test('the offline authority expires and is never extended offline', () async {
      final host = hostFor(ttl: const Duration(hours: 12));
      final session = await pairedAndWarm(host);
      cloud = 'down';
      now = now.add(const Duration(hours: 11, minutes: 59));
      expect((await order(session, 'inside'))['status'], 200);
      now = now.add(const Duration(minutes: 2));
      final late = await order(session, 'outside');
      expect(late['status'], 401);
      expect(late['error'], 'Kayıtlı personel yetkisinin süresi doldu.');
    });

    test('a device paired while offline has no authority', () async {
      cloud = 'down';
      final host = hostFor();
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      final result = await order(session, 'never-verified');
      expect(result['status'], 401);
      expect(result['error'], 'Personel daha önce doğrulanmadı.');
    });

    test('an edited expiry or branch in the stored record is refused', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      await host.stop();
      final raw = Map<String, dynamic>.from(
        await store.readJson('lan_device_enrollment_v1_$rid') as Map,
      );
      final rows = (raw['devices'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      rows.first['expires_at'] =
          now.add(const Duration(days: 30)).toUtc().toIso8601String();
      await store.writeJson('lan_device_enrollment_v1_$rid', <String, dynamic>{'devices': rows});
      cloud = 'down';
      final restarted = hostFor();
      await _listen(restarted, material);
      addTearDown(restarted.stop);
      final again = _signed(restarted, material, waiterA.directory, 'staff-a');
      final result = await order(again, 'forged');
      expect(session.staffId, 'staff-a');
      expect(result['status'], 401);
      expect(result['error'], contains('doğrulanamadı'));
      expect(await queue.list(rid), hasLength(1)); // only the warm-up order
    });

    test('a stored record sealed by another device key is refused', () async {
      final host = hostFor();
      await pairedAndWarm(host);
      await host.stop();
      cloud = 'down';
      final restarted = hostFor(sealer: MemoryLanAuthoritySealer());
      await _listen(restarted, material);
      addTearDown(restarted.stop);
      final again = _signed(restarted, material, waiterA.directory, 'staff-a');
      final result = await order(again, 'copied-record');
      expect(result['status'], 401);
    });

    test('without a keystore seal nothing is trusted offline, online still works', () async {
      final host = hostFor(sealer: MemoryLanAuthoritySealer(available: false));
      final session = await pairedAndWarm(host);
      cloud = 'down';
      final result = await order(session, 'no-seal');
      expect(result['status'], 401);
    });

    test('a clock set back does not revive the authority', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      cloud = 'down';
      now = now.subtract(const Duration(hours: 2));
      final result = await order(session, 'rolled-back');
      expect(result['status'], 401);
      expect(result['error'], 'Cihaz saati geri alındı. Yetki uzatılmadı.');
    });

    test('the cloud returning closes a membership revoked during the outage', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      cloud = 'down';
      expect((await order(session, 'offline-ok'))['status'], 200);
      cloud = 'revoked';
      expect(await host.reverifyDevices(), 1);
      cloud = 'down';
      final result = await order(session, 'after-revoke');
      expect(result['status'], 401);
    });

    test('a temporary password is refused online and gives no offline authority', () async {
      final host = hostFor();
      await _listen(host, material);
      addTearDown(host.stop);
      cloud = 'tempPassword';
      await _expectPairingRefused(host, material, waiterA.directory, 'staff-a');
      expect(host.deviceCount, 0);
      cloud = 'down';
      // Nothing was ever sealed for this account, so the outage grants nothing.
      expect(host.devices, isEmpty);
    });

    test('a password reset after pairing closes the device and stays closed offline', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      cloud = 'tempPassword';
      final online = await order(session, 'reset-online');
      expect(online['status'], 401);
      expect(online['error'], contains('geçici şifresini'));
      cloud = 'down';
      expect((await order(session, 'reset-offline'))['status'], 401);
    });

    Future<void> rewriteStoredDevice(void Function(Map<String, dynamic> d) edit) async {
      final raw = Map<String, dynamic>.from(
        await store.readJson('lan_device_enrollment_v1_$rid') as Map,
      );
      final rows = (raw['devices'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      edit(rows.first);
      await store.writeJson('lan_device_enrollment_v1_$rid', <String, dynamic>{'devices': rows});
    }

    test('a changed credential epoch revokes the device for good', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      expect(host.devices.first.staffEpoch, 1);
      epoch = 2; // staff was deactivated and re-activated meanwhile
      final changed = await order(session, 'after-epoch');
      expect(changed['status'], 401);
      expect(host.devices.first.revoked, isTrue);
      epoch = 1; // even the old value does not bring the device back
      expect((await order(session, 'epoch-back'))['status'], 401);
      cloud = 'down';
      expect((await order(session, 'epoch-offline'))['status'], 401);
    });

    test('an unchanged credential epoch keeps the device working', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      expect(await host.reverifyDevices(), 0);
      expect((await order(session, 'same-epoch'))['status'], 200);
      expect(host.devices.first.revoked, isFalse);
      expect(host.devices.first.staffEpoch, 1);
    });

    test('an answer without a credential epoch is refused at pairing', () async {
      final host = hostFor();
      await _listen(host, material);
      addTearDown(host.stop);
      sendEpoch = false;
      await _expectPairingRefused(host, material, waiterA.directory, 'staff-a');
      expect(host.deviceCount, 0);
    });

    test('an old record without an epoch learns it online and is not revoked', () async {
      final host = hostFor();
      await pairedAndWarm(host);
      await host.stop();
      // last_seq reset: the restarted test client counts from 1 again.
      await rewriteStoredDevice((d) {
        d.remove('staff_epoch');
        d['last_seq'] = 0;
      });
      epoch = 7;
      final restarted = hostFor();
      await _listen(restarted, material);
      addTearDown(restarted.stop);
      final again = _signed(restarted, material, waiterA.directory, 'staff-a');
      final legacy = await order(again, 'legacy-online');
      expect(legacy['status'], 200, reason: '${legacy['error']}');
      expect(restarted.devices.first.revoked, isFalse);
      expect(restarted.devices.first.staffEpoch, 7);
    });

    test('with the cloud away a seal from before the epoch or with another epoch is refused', () async {
      for (final edit in <String, void Function(Map<String, dynamic>)>{
        'no epoch in record': (d) => d.remove('staff_epoch'),
        'other epoch in record': (d) => d['staff_epoch'] = 2,
      }.entries) {
        store = MemoryLanEnrollmentStore();
        queue = RestaurantLocalOrderQueueService();
        cloud = 'active';
        final host = hostFor();
        await pairedAndWarm(host);
        await host.stop();
        await rewriteStoredDevice(edit.value);
        cloud = 'down';
        final restarted = hostFor();
        await _listen(restarted, material);
        final again = _signed(restarted, material, waiterA.directory, 'staff-a');
        final result = await order(again, 'old-seal');
        expect(result['status'], 401, reason: edit.key);
        expect(result['error'], contains('doğrulanamadı'), reason: edit.key);
        await restarted.stop();
      }
    });

    test('a branch mismatch and a lost permission are rejected, not treated as offline', () async {
      for (final mode in <String>['otherBranch', 'noPermission']) {
        store = MemoryLanEnrollmentStore();
        queue = RestaurantLocalOrderQueueService();
        cloud = 'active';
        final host = hostFor();
        await _listen(host, material);
        final session = await _pair(host, material, waiterA.directory, 'staff-a');
        cloud = mode;
        final result = await order(session, 'mode-$mode');
        expect(result['status'], 401, reason: mode);
        cloud = 'down';
        expect((await order(session, 'mode-$mode-2'))['status'], 401, reason: mode);
        await host.stop();
      }
    });

    test('offline authority keeps the table scope of the sealed branch', () async {
      final host = hostFor();
      final session = await pairedAndWarm(host);
      cloud = 'down';
      final foreign = await order(session, 'other-branch-table', table: 2);
      expect(foreign['status'], isNot(200));
    });
  });

  group('LAN staff authorization (negative)', () {
    const rid = 'lan-auth-rest';
    const tables = <Map<String, dynamic>>[
      <String, dynamic>{'id': 't1', 'table_number': 1, 'branch_id': 'b1', 'is_active': true},
      <String, dynamic>{'id': 't2', 'table_number': 2, 'branch_id': 'b2', 'is_active': true},
      <String, dynamic>{'id': 't3', 'table_number': 3, 'branch_id': 'b1', 'is_active': false},
    ];
    const products = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
    ];
    const stations = <Map<String, dynamic>>[<String, dynamic>{'id': 'ocak'}];

    Map<String, dynamic> row({
      String store = rid,
      String status = 'active',
      String role = 'waiter',
      List<String> permissions = const <String>['manageOrders'],
      String? branch,
      Object? mustChange = false,
    }) =>
        <String, dynamic>{
          'store_id': store,
          'status': status,
          'staff_role': role,
          'permissions': permissions,
          'branch_id': branch,
          'must_change_password': mustChange,
          'credential_epoch': 1,
        };

    late RestaurantLocalOrderQueueService queue;
    setUp(() => queue = RestaurantLocalOrderQueueService());

    RestaurantLanHost hostFor(
      Map<String, dynamic>? Function() membership, {
      String? center = 'b1',
    }) {
      return _host(
        material,
        restaurantId: rid,
        branchId: center,
        orders: queue,
        stationsOverride: stations,
        tablesOverride: tables,
        productsOverride: products,
        staffStillAuthorized: lanStaffProbe(
          (_) async => membership(),
          restaurantId: rid,
          centerBranchId: () => center,
        ),
      );
    }

    Future<Map<String, dynamic>> order(
      RestaurantLanClient session,
      String id, {
      int table = 1,
      String staff = 'staff-a',
    }) {
      return session.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': id,
        'table_number': table,
        'station_id': 'ocak',
        'items': <Map<String, Object?>>[
          <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
        ],
      });
    }

    Future<void> expectRefused(
      RestaurantLanHost host,
      Map<String, dynamic> result,
      String id,
    ) async {
      expect(result['saved'], isNot(true));
      expect(result['status'], isNot(200));
      final stored = await queue.list(rid);
      expect(stored, isEmpty, reason: 'no local order may exist for $id');
    }

    for (final entry in <String, Map<String, dynamic>?>{
      'a waiter role without manageOrders': row(permissions: const <String>[]),
      'a viewOrders-only sub-admin': row(role: 'sub_admin', permissions: const <String>['viewOrders']),
      'an inactive member': row(status: 'inactive'),
      'a member of another restaurant': row(store: 'someone-else'),
      'a member limited to another branch': row(branch: 'b2'),
      'no membership at all': null,
      'a staff account with a temporary password': row(mustChange: true),
      'an answer without the password flag': (row()..remove('must_change_password')),
      'a non-boolean password flag': row(mustChange: 'false'),
    }.entries) {
      test('${entry.key} cannot send an order', () async {
        final host = hostFor(() => entry.value);
        await _listen(host, material);
        addTearDown(host.stop);
        await _expectPairingRefused(host, material, waiterA.directory, 'staff-a');
        expect(host.deviceCount, 0);
        expect(await queue.list(rid), isEmpty);
      });
    }

    test('a branch-limited member without a known center branch is refused', () async {
      final host = hostFor(() => row(branch: 'b1'), center: null);
      await _listen(host, material);
      addTearDown(host.stop);
      await _expectPairingRefused(host, material, waiterA.directory, 'staff-a');
      expect(host.deviceCount, 0);
      expect(await queue.list(rid), isEmpty);
    });

    test('staff deactivated after pairing stops at the next request', () async {
      Map<String, dynamic>? current = row();
      final host = hostFor(() => current);
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      expect((await order(session, 'ok-1'))['saved'], isTrue);
      current = row(status: 'inactive');
      final after = await order(session, 'late-1');
      expect(after['saved'], isNot(true));
      expect(after['status'], 401);
      // The revocation sticks even if the membership comes back.
      current = row();
      expect((await order(session, 'late-2'))['saved'], isNot(true));
    });

    test('a permission removed after pairing stops the next order', () async {
      Map<String, dynamic>? current = row();
      final host = hostFor(() => current);
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      expect((await order(session, 'p-1'))['saved'], isTrue);
      current = row(permissions: const <String>[]);
      expect((await order(session, 'p-2'))['saved'], isNot(true));
    });

    test('a branch-limited member only reaches active tables of that branch', () async {
      final host = hostFor(() => row(branch: 'b1'));
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      final list = await session.postAuthorized('/lan/tables', <String, Object?>{});
      final numbers = (list['tables'] as List).map((t) => t['table_number']).toList();
      expect(numbers, containsAll(<int>[1, 3]));
      expect(numbers, isNot(contains(2)));
      final other = await order(session, 'tb-2', table: 2);
      expect(other['status'], 403);
      expect(other['saved'], isNot(true));
      final missing = await order(session, 'tb-9', table: 9);
      expect(missing['status'], 403);
      final inactive = await order(session, 'tb-3', table: 3);
      expect(inactive['status'], 403);
      expect((await order(session, 'tb-1', table: 1))['saved'], isTrue);
    });

    test('a member limited to nothing still cannot use an inactive table', () async {
      final host = hostFor(() => row());
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      expect((await order(session, 'tc-3', table: 3))['status'], 403);
      expect((await order(session, 'tc-2', table: 2))['saved'], isTrue);
    });

    test('a device cannot send as a different staff id', () async {
      final host = hostFor(() => row());
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      session.seq += 1;
      final spoof = await session.post('/lan/orders', <String, Object?>{
        'seq': session.seq,
        'body': <String, Object?>{
          'staff_id': 'staff-boss',
          'local_order_id': 'spoof-1',
          'table_number': 1,
          'station_id': 'ocak',
          'items': <Map<String, Object?>>[
            <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
          ],
        },
      });
      expect(spoof['saved'], isNot(true));
      expect(spoof['status'], 401);
    });
  });

  group('LAN print state is a recorded fact (fake printer)', () {
    const rid = 'lan-print-rest';
    const tables = <Map<String, dynamic>>[
      <String, dynamic>{'id': 't1', 'table_number': 1, 'is_active': true},
    ];
    const products = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Çorba', 'station_id': 'ocak', 'price': 40},
    ];
    const stations = <Map<String, dynamic>>[<String, dynamic>{'id': 'ocak'}];

    Future<(RestaurantLocalOrderRecord, int)> run({
      bool physical = false,
      Future<void> Function(RestaurantLocalOrderRecord)? print,
    }) async {
      final queue = RestaurantLocalOrderQueueService();
      var calls = 0;
      final host = _host(
        material,
        restaurantId: rid,
        orders: queue,
        stationsOverride: stations,
        tablesOverride: tables,
        productsOverride: products,
        enablePhysicalPrint: physical,
        onPhysicalPrint: print == null
            ? null
            : (order) async {
                calls += 1;
                await print(order);
              },
      );
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      final saved = await session.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': 'pr-1',
        'table_number': 1,
        'station_id': 'ocak',
        'items': <Map<String, Object?>>[
          <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
        ],
      });
      expect(saved['saved'], isTrue);
      final rows = await queue.list(rid);
      return (rows.single, calls);
    }

    test('nothing handed to a printer is recorded as not_sent, one record', () async {
      final (order, calls) = await run();
      expect(order.printStatus, 'not_sent');
      expect(calls, 0);
      expect(planLanOrderSync(listeningHost: true, printStatus: order.printStatus).evidence, 'failed');
    });

    test('a printer error after the write started is uncertain, never failed', () async {
      final (order, calls) = await run(
        physical: true,
        print: (_) async => throw const SocketException('reset after write'),
      );
      expect(calls, 1);
      expect(order.printStatus, 'uncertain');
      expect(planLanOrderSync(listeningHost: true, printStatus: order.printStatus).evidence, 'uncertain');
    });

    test('a printed order is forwarded evidence and printed exactly once', () async {
      final (order, calls) = await run(physical: true, print: (_) async {});
      expect(calls, 1);
      expect(order.printStatus, 'forwarded');
      expect(planLanOrderSync(listeningHost: true, printStatus: order.printStatus).evidence, 'forwarded');
    });

    test('resending the same order id prints nothing more', () async {
      final queue = RestaurantLocalOrderQueueService();
      var calls = 0;
      final host = _host(
        material,
        restaurantId: rid,
        orders: queue,
        stationsOverride: stations,
        tablesOverride: tables,
        productsOverride: products,
        enablePhysicalPrint: true,
        onPhysicalPrint: (_) async => calls += 1,
      );
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      Future<Map<String, dynamic>> send() => session.postAuthorized('/lan/orders', <String, Object?>{
            'local_order_id': 'dup-1',
            'table_number': 1,
            'station_id': 'ocak',
            'items': <Map<String, Object?>>[
              <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
            ],
          });
      expect((await send())['saved'], isTrue);
      final again = await send();
      expect(again['duplicate'], isTrue);
      expect(calls, 1);
      expect((await queue.list(rid)).length, 1);
    });

    test('closing the app lets the order in progress finish and refuses new ones', () async {
      final queue = RestaurantLocalOrderQueueService();
      final printing = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final host = _host(
        material,
        restaurantId: rid,
        orders: queue,
        stationsOverride: stations,
        tablesOverride: tables,
        productsOverride: products,
        enablePhysicalPrint: true,
        onPhysicalPrint: (_) async {
          calls += 1;
          printing.complete();
          await release.future;
        },
      );
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-a');
      Map<String, Object?> order(String id) => <String, Object?>{
            'local_order_id': id,
            'table_number': 1,
            'station_id': 'ocak',
            'items': <Map<String, Object?>>[
              <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
            ],
          };
      final first = session.postAuthorized('/lan/orders', order('stop-1'));
      await printing.future;
      final stopped = host.stop(grace: const Duration(seconds: 5));
      expect(host.stopping, isTrue);
      final late = await session.postAuthorized('/lan/orders', order('stop-2'));
      expect(late['saved'], isFalse);
      release.complete();
      expect((await first)['saved'], isTrue);
      await stopped;
      expect(host.listening, isFalse);
      final rows = await queue.list(rid);
      expect(rows.map((row) => row.localOrderId), <String>['stop-1']);
      expect(rows.single.printStatus, 'forwarded');
      expect(calls, 1);
    });
  });

  group('Paired device list', () {
    test('old records without name, platform or last seen still load', () async {
      final json = <String, dynamic>{
        'device_id': 'cd' * 32,
        'paired_at': DateTime.utc(2026).toIso8601String(),
        'staff_id': 'old',
      };
      final old = RestaurantLanDevice.fromJson(json);
      expect(old.deviceName, isNull);
      expect(old.platform, isNull);
      expect(old.lastSeenAt, isNull);
      expect(old.toJson().containsKey('last_seen_at'), isFalse);
      final round = RestaurantLanDevice.fromJson(
        old.copy(lastSeenAt: DateTime.utc(2026, 2)).toJson(),
      );
      expect(round.lastSeenAt, DateTime.utc(2026, 2));
      final store = MemoryLanEnrollmentStore();
      await store.writeJson('lan_device_enrollment_v1_lan-old', <String, dynamic>{
        'devices': <Map<String, dynamic>>[json],
      });
      final host = _host(material, restaurantId: 'lan-old', deviceStore: store);
      await _listen(host, material);
      addTearDown(host.stop);
      expect(host.deviceInfos.single.staffId, 'old');
      expect(host.deviceInfos.single.deviceName, isNull);
    });

    test('last seen moves once a minute and revoke closes the device', () async {
      var now = DateTime.utc(2026, 3, 1, 10);
      final store = MemoryLanEnrollmentStore();
      final host = _host(
        material,
        restaurantId: 'lan-seen',
        deviceStore: store,
        clock: () => now,
      );
      await _listen(host, material);
      addTearDown(host.stop);
      final session = await _pair(host, material, waiterA.directory, 'staff-seen');
      expect(host.deviceInfos.single.lastSeenAt, isNull);
      await session.postAuthorized('/lan/center/status', <String, Object?>{});
      final first = host.deviceInfos.single.lastSeenAt;
      expect(first, now);
      now = now.add(const Duration(seconds: 30));
      await session.postAuthorized('/lan/center/status', <String, Object?>{});
      expect(host.deviceInfos.single.lastSeenAt, first);
      now = now.add(const Duration(seconds: 40));
      await session.postAuthorized('/lan/center/status', <String, Object?>{});
      expect(host.deviceInfos.single.lastSeenAt, now);

      final id = host.deviceInfos.single.deviceId;
      expect(await host.revokeDevice('unknown-device'), isFalse);
      expect(await host.revokeDevice(id), isTrue);
      expect(host.deviceCount, 0);
      expect(host.deviceInfos.single.revoked, isTrue);
      final after = await session.postAuthorized('/lan/center/status', <String, Object?>{});
      expect(after['status'], 401);
      final stored = jsonEncode(
        await store.readJson('lan_device_enrollment_v1_lan-seen'),
      );
      expect(stored, contains('"revoked":true'));
    });
  });
}

class _RememberTransport implements RestaurantLanOrderTransport {
  @override
  Future<bool> submit(RestaurantLocalOrderRecord order) async => true;
}

final LanAuthoritySealer _testSealer = MemoryLanAuthoritySealer();

RestaurantLanHost _host(
  LanTlsMaterial material, {
  required String restaurantId,
  String? branchId,
  RestaurantLocalOrderQueueService? orders,
  LanEnrollmentStore? deviceStore,
  Duration deviceGrantTtl = const Duration(minutes: 15),
  LanAuthoritySealer? authoritySealer,
  DateTime Function()? clock,
  Future<StaffProbe> Function(String staffId)? staffStillAuthorized,
  List<Map<String, dynamic>>? stationsOverride,
  List<Map<String, dynamic>>? tablesOverride,
  List<Map<String, dynamic>>? productsOverride,
  bool enablePhysicalPrint = false,
  LanPhysicalPrint? onPhysicalPrint,
  RestaurantLocalPrintQueueService? printQueue,
  Uri? printBridgeUri,
}) {
  return RestaurantLanHost(
    restaurantId: restaurantId,
    printBridgeUri: printBridgeUri,
    branchId: branchId,
    orders: orders,
    printQueue: printQueue,
    deviceStore: deviceStore ?? MemoryLanEnrollmentStore(),
    operatorFingerprint: material.operatorFingerprint,
    certificateDirectory: material.directory.path,
    deviceGrantTtl: deviceGrantTtl,
    authoritySealer: authoritySealer ?? _testSealer,
    clock: clock,
    staffStillAuthorized: staffStillAuthorized ??
        (_) async => const StaffProbe(StaffProbeKind.active),
    stationsOverride: stationsOverride,
    tablesOverride: tablesOverride,
    productsOverride: productsOverride,
    enablePhysicalPrint: enablePhysicalPrint,
    onPhysicalPrint: onPhysicalPrint,
  );
}

Future<void> _listen(RestaurantLanHost host, LanTlsMaterial material) {
  return host.start(
    address: InternetAddress.loopbackIPv4,
    securityContext: material.serverContext,
  );
}

RestaurantLanClient _owner(RestaurantLanHost host, LanTlsMaterial material) {
  return RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: material.operatorContext,
    pinnedServerFingerprint: material.serverFingerprint,
  );
}

RestaurantLanClient _client(
  RestaurantLanHost host,
  LanTlsMaterial material,
  LanClientCertificate certificate, {
  String? staffId,
}) {
  return RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: certificate.context,
    pinnedServerFingerprint: material.serverFingerprint,
    staffId: staffId,
  );
}

RestaurantLanClient _anonymous(RestaurantLanHost host, LanTlsMaterial material) {
  return RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('${material.directory.path}/ca.pem'),
    pinnedServerFingerprint: material.serverFingerprint,
  );
}

RestaurantLanClient _signed(
  RestaurantLanHost host,
  LanTlsMaterial material,
  Directory directory,
  String staffId,
) {
  return RestaurantLanClient(
    Uri.parse('https://127.0.0.1:${host.port}'),
    securityContext: SecurityContext(withTrustedRoots: false)
      ..useCertificateChain('${directory.path}/client.pem')
      ..usePrivateKey('${directory.path}/client.key')
      ..setTrustedCertificates('${material.directory.path}/ca.pem'),
    pinnedServerFingerprint: material.serverFingerprint,
    staffId: staffId,
  );
}

Future<RestaurantLanClient> _pair(
  RestaurantLanHost host,
  LanTlsMaterial material,
  Directory directory,
  String staffId,
) async {
  final issued = await _owner(host, material).post('/lan/pair/issue', <String, Object?>{});
  expect(issued['status'], 200, reason: issued['error']?.toString());
  final code = issued['code'].toString();
  final request = await LanClientRequest.generate(
    directory: directory,
    commonName: staffId,
  );
  final redeemed = await _anonymous(host, material).post('/lan/pair/redeem', <String, Object?>{
    'code': code,
    'staff_id': staffId,
    'csr': request.csr,
  });
  expect(redeemed['ok'], isTrue, reason: redeemed['error']?.toString());
  expect(redeemed.containsKey('sealed_token'), isFalse);
  final certificate = redeemed['certificate']?.toString() ?? '';
  expect(certificate.contains('BEGIN CERTIFICATE'), isTrue);
  await request.installSignedCertificate(
    certificate: certificate,
    caPath: '${material.directory.path}/ca.pem',
  );
  final replay = await _anonymous(host, material).post('/lan/pair/redeem', <String, Object?>{
    'code': code,
    'staff_id': staffId,
    'csr': request.csr,
  });
  expect(replay['status'], 401);
  return _signed(host, material, directory, staffId);
}

/// An unauthorised member is refused at pairing itself: no device, no
/// certificate, nothing to send an order with.
Future<void> _expectPairingRefused(
  RestaurantLanHost host,
  LanTlsMaterial material,
  Directory directory,
  String staffId,
) async {
  final issued = await _owner(host, material).post('/lan/pair/issue', <String, Object?>{});
  final request = await LanClientRequest.generate(
    directory: directory,
    commonName: staffId,
  );
  final redeemed = await _anonymous(host, material).post('/lan/pair/redeem', <String, Object?>{
    'code': issued['code'].toString(),
    'staff_id': staffId,
    'csr': request.csr,
  });
  expect(redeemed['ok'], isNot(true));
  expect(redeemed['status'], 403);
  expect(redeemed.containsKey('certificate'), isFalse);
}

Future<void> _expectClosed(Future<Map<String, dynamic>> attempt) async {
  try {
    final result = await attempt;
    expect(result['status'], isNot(200));
    expect(result['saved'], isNot(true));
  } on HttpException {
    // An untrusted client certificate is closed during the handshake.
  } on SocketException {
    // The host is closed or the certificate was rejected.
  }
}

class _RealHttpOverrides extends HttpOverrides {}
