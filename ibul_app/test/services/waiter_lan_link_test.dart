import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_authority_seal.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_browser.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_discovery.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pairing_guard.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/waiter_lan_link.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Host-approved pairing against a real TLS center on loopback: the phone
/// finds the center, the operator approves, the device reconnects after a
/// restart, and the people and devices that must be refused are refused.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  const restaurantId = 'rest-approve';
  late Directory temp;
  late LanTlsMaterial material;
  late RestaurantLanHost host;
  late _MemoryStore store;
  late _FixedBrowser browser;
  final links = <WaiterLanLink>[];

  setUp(() async {
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    temp = await Directory.systemTemp.createTemp('ibul-waiter-link');
    material = await LanTlsMaterial.open(Directory('${temp.path}/host'));
    host = RestaurantLanHost(
      restaurantId: restaurantId,
      deviceStore: MemoryLanEnrollmentStore(),
      operatorFingerprint: material.operatorFingerprint,
      certificateDirectory: material.directory.path,
      machineId: 'machine-1',
      authoritySealer: MemoryLanAuthoritySealer(),
      staffStillAuthorized: (staffId) async => staffId == 'staff-ok'
          ? const StaffProbe(StaffProbeKind.active)
          : const StaffProbe(
              StaffProbeKind.rejected,
              reason: 'Bu kişi bu işletmenin personeli değil.',
            ),
      tablesOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'Bahçe 1', 'table_number': 1},
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cay', 'name': 'Çay', 'price': 20},
      ],
    );
    await host.start(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    store = _MemoryStore();
    browser = _FixedBrowser(<LanCenterRecord>[
      LanCenterRecord(
        host: '127.0.0.1',
        port: host.port,
        restaurantId: restaurantId,
        machineId: 'machine-1',
        fingerprint: material.serverFingerprint,
      ),
    ]);
  });

  tearDown(() async {
    for (final link in links) {
      link.stop();
    }
    links.clear();
    await host.stop(grace: Duration.zero);
    RestaurantLanPairing.transport = null;
    RestaurantLanPairing.centerReachable = true;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  WaiterLanLink newLink({String device = 'phone-a'}) {
    final link = WaiterLanLink(
      browser: browser,
      store: store,
      certificateDirectory: (_) async => Directory('${temp.path}/$device'),
      pollEvery: const Duration(milliseconds: 40),
      watchEvery: const Duration(hours: 1),
      centerPort: host.port,
    );
    links.add(link);
    return link;
  }

  Future<void> until(bool Function() done, {String what = 'state'}) async {
    for (var i = 0; i < 400; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('timed out waiting for $what');
  }

  RestaurantLocalOrderRecord order(String id) {
    final now = DateTime.now();
    return RestaurantLocalOrderRecord(
      localOrderId: id,
      restaurantId: restaurantId,
      tableId: '1',
      tableName: 'Bahçe 1',
      tableNumber: 1,
      waiterId: 'staff-ok',
      waiterName: 'Ali',
      items: const <Map<String, dynamic>>[
        <String, dynamic>{'product_id': 'cay', 'name': 'Çay', 'quantity': 1},
      ],
      notes: '',
      total: 20,
      stationGroups: const <Map<String, dynamic>>[],
      printStatus: 'pending',
      syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('signed-in waiter is found, approved once and sends an order', () async {
    final link = newLink();
    await link.start(
      restaurantId: restaurantId,
      staffId: 'staff-ok',
      staffName: 'Ali',
    );
    expect(link.phase, WaiterLanLinkPhase.centerFound);
    expect(RestaurantLanPairing.transport, isNull);

    final pairing = link.requestPairing();
    await until(
      () => host.pendingPairingRequests.isNotEmpty && link.matchCode.isNotEmpty,
      what: 'request on the operator screen',
    );
    final pending = host.pendingPairingRequests.single;
    // Both screens show the same six digits; the operator sees who asks.
    expect(pending.matchCode, link.matchCode);
    expect(pending.matchCode, matches(RegExp(r'^\d{6}$')));
    expect(pending.staffId, 'staff-ok');
    expect(pending.staffName, 'Ali');
    expect(host.deviceCount, 0, reason: 'nothing is granted before approval');

    expect(await host.approvePairingRequest(pending.id), isNull);
    await pairing;
    expect(link.phase, WaiterLanLinkPhase.paired);
    expect(link.centerReachable, isTrue);
    expect(host.deviceCount, 1);

    final transport = RestaurantLanPairing.transport!;
    expect(await transport.submit(order('order-1')), isTrue);
    // The same order again: the center answers from its journal, one record.
    expect(await transport.submit(order('order-1')), isTrue);
    final saved = await RestaurantLocalOrderQueueService().list(restaurantId);
    expect(saved.where((row) => row.localOrderId == 'order-1'), hasLength(1));

    // The private key went to the keystore, not into the session record.
    expect(store.secrets.values.single, contains('PRIVATE KEY'));
    expect(store.json.values.join(), isNot(contains('PRIVATE KEY')));
  });

  test('after a restart the device reconnects without a new approval', () async {
    final first = newLink();
    await first.start(restaurantId: restaurantId, staffId: 'staff-ok');
    final pairing = first.requestPairing();
    await until(() => host.pendingPairingRequests.isNotEmpty);
    await host.approvePairingRequest(host.pendingPairingRequests.single.id);
    await pairing;
    expect(await RestaurantLanPairing.transport!.submit(order('before')), isTrue);
    first.stop();
    expect(RestaurantLanPairing.transport, isNull);

    // "App closed and opened": a new object, the same keystore and files.
    final again = newLink();
    await again.start(restaurantId: restaurantId, staffId: 'staff-ok');
    expect(again.phase, WaiterLanLinkPhase.paired);
    expect(again.centerReachable, isTrue);
    expect(host.pendingPairingRequests, isEmpty);
    expect(await RestaurantLanPairing.transport!.submit(order('after')), isTrue);
  });

  test('another person on the same phone is not attached silently', () async {
    final first = newLink();
    await first.start(restaurantId: restaurantId, staffId: 'staff-ok');
    final pairing = first.requestPairing();
    await until(() => host.pendingPairingRequests.isNotEmpty);
    await host.approvePairingRequest(host.pendingPairingRequests.single.id);
    await pairing;
    first.stop();

    final other = newLink();
    await other.start(restaurantId: restaurantId, staffId: 'staff-other');
    expect(other.phase, WaiterLanLinkPhase.centerFound);
    expect(RestaurantLanPairing.transport, isNull);
  });

  test('a person the cloud refuses is not paired even if approved', () async {
    final link = newLink();
    await link.start(restaurantId: restaurantId, staffId: 'staff-bad');
    final pairing = link.requestPairing();
    await until(() => host.pendingPairingRequests.isNotEmpty);
    final error = await host.approvePairingRequest(
      host.pendingPairingRequests.single.id,
    );
    expect(error, contains('personeli değil'));
    await pairing;
    expect(link.phase, WaiterLanLinkPhase.failed);
    expect(link.message, contains('personeli değil'));
    expect(host.deviceCount, 0);
    expect(RestaurantLanPairing.transport, isNull);
  });

  test('operator refusal and a center that is off', () async {
    final link = newLink();
    await link.start(restaurantId: restaurantId, staffId: 'staff-ok');
    final pairing = link.requestPairing();
    await until(() => host.pendingPairingRequests.isNotEmpty);
    host.denyPairingRequest(host.pendingPairingRequests.single.id);
    await pairing;
    expect(link.phase, WaiterLanLinkPhase.failed);
    expect(host.deviceCount, 0);

    link.cancelPairing();
    await host.stop(grace: Duration.zero);
    await link.requestPairing();
    expect(link.phase, WaiterLanLinkPhase.failed);
    expect(link.message, contains('ulaşılamadı'));
  });

  test('a paired device notices the center going away and coming back', () async {
    final link = newLink();
    await link.start(restaurantId: restaurantId, staffId: 'staff-ok');
    final pairing = link.requestPairing();
    await until(() => host.pendingPairingRequests.isNotEmpty);
    await host.approvePairingRequest(host.pendingPairingRequests.single.id);
    await pairing;
    final port = host.port;

    await host.stop(grace: Duration.zero);
    await expectLater(
      RestaurantLanPairing.transport!.submit(order('lost')),
      throwsA(isA<SocketException>()),
    );
    // The cloud route is used while this is false.
    expect(RestaurantLanPairing.centerReachable, isFalse);
    expect(link.phase, WaiterLanLinkPhase.paired);

    await host.start(
      address: InternetAddress.loopbackIPv4,
      port: port,
      securityContext: material.serverContext,
    );
    for (var i = 0; i < 20 && !RestaurantLanPairing.centerReachable; i++) {
      await RestaurantLanPairing.recheck!.call();
    }
    expect(RestaurantLanPairing.centerReachable, isTrue);
    expect(await RestaurantLanPairing.transport!.submit(order('back')), isTrue);
  });

  test('the center moves to another network: same key reconnects, an impostor does not', () async {
    final link = newLink();
    await link.start(restaurantId: restaurantId, staffId: 'staff-ok');
    final pairing = link.requestPairing();
    await until(() => host.pendingPairingRequests.isNotEmpty);
    await host.approvePairingRequest(host.pendingPairingRequests.single.id);
    await pairing;
    final port = host.port;
    final oldFingerprint = material.serverFingerprint;
    await host.stop(grace: Duration.zero);

    // An impostor announces the saved machine id with its own certificate.
    final fakeMaterial = await LanTlsMaterial.open(Directory('${temp.path}/fake'));
    final fake = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      port,
      fakeMaterial.serverContext,
    );
    fake.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"service":"ibul-lan","restaurant_id":"$restaurantId","machine_id":"machine-1"}',
      );
      await request.response.close();
    });
    browser.records = <LanCenterRecord>[
      LanCenterRecord(
        host: '127.0.0.1',
        port: port,
        restaurantId: restaurantId,
        machineId: 'machine-1',
        fingerprint: fakeMaterial.serverFingerprint,
      ),
    ];
    for (var i = 0; i < 3; i++) {
      await RestaurantLanPairing.recheck!.call();
    }
    expect(RestaurantLanPairing.centerReachable, isFalse);
    await fake.close(force: true);

    // The real center comes up on a new address: new certificate, same key.
    expect(
      await LanTlsMaterial.ensureServerAddress(material.directory, '192.168.10.158'),
      isTrue,
    );
    final moved = await LanTlsMaterial.open(material.directory);
    expect(moved.serverFingerprint, isNot(oldFingerprint));
    await host.start(
      address: InternetAddress.loopbackIPv4,
      port: port,
      securityContext: moved.serverContext,
    );
    browser.records = <LanCenterRecord>[
      LanCenterRecord(
        host: '127.0.0.1',
        port: port,
        restaurantId: restaurantId,
        machineId: 'machine-1',
        fingerprint: moved.serverFingerprint,
      ),
    ];
    for (var i = 0; i < 20 && !RestaurantLanPairing.centerReachable; i++) {
      await RestaurantLanPairing.recheck!.call();
    }
    expect(RestaurantLanPairing.centerReachable, isTrue);
    expect(host.pendingPairingRequests, isEmpty);
    expect(await RestaurantLanPairing.transport!.submit(order('moved')), isTrue);

    // The new certificate survives an app restart without a new approval.
    link.stop();
    final again = newLink();
    await again.start(restaurantId: restaurantId, staffId: 'staff-ok');
    expect(again.centerReachable, isTrue);
    expect(await RestaurantLanPairing.transport!.submit(order('moved-2')), isTrue);
  });

  test('announcements of another restaurant or a second center are not used', () async {
    browser.records = <LanCenterRecord>[
      LanCenterRecord(
        host: '127.0.0.1',
        port: host.port,
        restaurantId: 'another-restaurant',
        machineId: 'machine-1',
        fingerprint: material.serverFingerprint,
      ),
    ];
    final link = newLink();
    await link.start(restaurantId: restaurantId, staffId: 'staff-ok');
    expect(link.phase, WaiterLanLinkPhase.noCenter);

    browser.records = <LanCenterRecord>[
      for (final machine in <String>['machine-1', 'machine-2'])
        LanCenterRecord(
          host: '127.0.0.1',
          port: host.port,
          restaurantId: restaurantId,
          machineId: machine,
          fingerprint: material.serverFingerprint,
        ),
    ];
    await link.refresh();
    expect(link.phase, WaiterLanLinkPhase.noCenter);
    expect(link.message, contains('birden fazla'));
  });

  test('center refuses wrong restaurant, bad reveal and a changed request', () async {
    final anonymous = RestaurantLanClient(
      Uri.parse('https://127.0.0.1:${host.port}'),
      securityContext: SecurityContext(withTrustedRoots: false),
      pinnedServerFingerprint: material.serverFingerprint,
    );
    final request = await LanClientRequest.generate(
      directory: Directory('${temp.path}/raw'),
      commonName: 'ibul-waiter',
    );
    final nonce = newPairingSecret(Random.secure());

    final wrong = await anonymous.post('/lan/pair/request', <String, Object?>{
      'restaurant_id': 'another-restaurant',
      'staff_id': 'staff-ok',
      'csr': request.csr,
      'commit': lanPairingCommit(nonce),
    });
    expect(wrong['status'], 403);

    final asked = await anonymous.post('/lan/pair/request', <String, Object?>{
      'restaurant_id': restaurantId,
      'staff_id': 'staff-ok',
      'csr': request.csr,
      'commit': lanPairingCommit(nonce),
    });
    expect(asked['ok'], isTrue);
    expect(host.pendingPairingRequests, isEmpty, reason: 'not shown before the reveal');
    expect(
      await host.approvePairingRequest(asked['request_id'].toString()),
      isNotNull,
      reason: 'an unrevealed request cannot be approved',
    );

    final again = await anonymous.post('/lan/pair/request', <String, Object?>{
      'restaurant_id': restaurantId,
      'staff_id': 'staff-ok',
      'csr': request.csr,
      'commit': lanPairingCommit(nonce),
    });
    final badReveal = await anonymous.post('/lan/pair/status', <String, Object?>{
      'request_id': again['request_id'],
      'nonce': 'not-the-committed-nonce',
    });
    expect(badReveal['state'], 'denied');
    expect(host.pendingPairingRequests, isEmpty);

    // A relay that swaps the certificate request, the server certificate or
    // a nonce ends up with other digits than the phone shows.
    final code = lanPairingMatchCode(
      serverFingerprint: material.serverFingerprint,
      csr: request.csr,
      deviceNonce: nonce,
      hostNonce: 'host-nonce',
    );
    expect(
      lanPairingMatchCode(
        serverFingerprint: material.serverFingerprint,
        csr: '${request.csr}x',
        deviceNonce: nonce,
        hostNonce: 'host-nonce',
      ),
      isNot(code),
    );
    expect(
      lanPairingMatchCode(
        serverFingerprint: 'aa${material.serverFingerprint}',
        csr: request.csr,
        deviceNonce: nonce,
        hostNonce: 'host-nonce',
      ),
      isNot(code),
    );

    final unknown = await anonymous.post('/lan/pair/status', <String, Object?>{
      'request_id': 'no-such-request',
      'nonce': nonce,
    });
    expect(unknown['status'], 404);
    expect(host.deviceCount, 0);
  });
}

class _FixedBrowser extends LanCenterBrowser {
  _FixedBrowser(this.records);

  List<LanCenterRecord> records;

  @override
  Future<List<LanCenterRecord>> browse() async => records;
}

class _MemoryStore implements WaiterLinkStore {
  final Map<String, Object?> json = <String, Object?>{};
  final Map<String, String> secrets = <String, String>{};

  @override
  Future<Object?> readJson(String key) async => json[key];

  @override
  Future<void> writeJson(String key, Object? value) async => json[key] = value;

  @override
  Future<String?> readSecret(String key) async => secrets[key];

  @override
  Future<bool> writeSecret(String key, String value) async {
    secrets[key] = value;
    return true;
  }
}

class _RealHttpOverrides extends HttpOverrides {}
