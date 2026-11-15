import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_channel.dart';
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
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      final body = jsonDecode(text) as Map<String, dynamic>;
      final id = body['p_local_order_id']?.toString() ?? '';
      cloudIds.add(id);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{
        'order_id': 'remote-$id',
        'order_number': '1',
      }));
      await request.response.close();
    });
    final restarted = _host(
      material,
      restaurantId: restaurantId,
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
    final host = _host(material, restaurantId: 'rest-sync', orders: orders);
    await _listen(host, material);
    addTearDown(host.stop);

    var calls = 0;
    var failFirst = true;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      calls += 1;
      await utf8.decoder.bind(request).join();
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

    final now = DateTime.utc(2026, 11, 13, 18);
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
    final stored = await orders.getByLocalId(
      restaurantId: 'rest-sync',
      localOrderId: 'local-one',
    );
    expect(stored?.syncStatus, RestaurantLocalOrderSyncStatus.synced);
    expect(stored?.remoteOrderId, 'remote-one');
    expect(await orders.list('rest-sync'), hasLength(1));
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
}

class _RememberTransport implements RestaurantLanOrderTransport {
  @override
  Future<bool> submit(RestaurantLocalOrderRecord order) async => true;
}

RestaurantLanHost _host(
  LanTlsMaterial material, {
  required String restaurantId,
  String? branchId,
  RestaurantLocalOrderQueueService? orders,
  LanEnrollmentStore? deviceStore,
  Duration deviceGrantTtl = const Duration(minutes: 15),
  DateTime Function()? clock,
  Future<StaffProbe> Function(String staffId)? staffStillAuthorized,
  List<Map<String, dynamic>>? stationsOverride,
  List<Map<String, dynamic>>? tablesOverride,
  List<Map<String, dynamic>>? productsOverride,
  bool enablePhysicalPrint = false,
  LanPhysicalPrint? onPhysicalPrint,
  RestaurantLocalPrintQueueService? printQueue,
}) {
  return RestaurantLanHost(
    restaurantId: restaurantId,
    branchId: branchId,
    orders: orders,
    printQueue: printQueue,
    deviceStore: deviceStore ?? MemoryLanEnrollmentStore(),
    operatorFingerprint: material.operatorFingerprint,
    certificateDirectory: material.directory.path,
    deviceGrantTtl: deviceGrantTtl,
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
