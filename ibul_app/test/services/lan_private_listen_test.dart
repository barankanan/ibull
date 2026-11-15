import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  HttpOverrides.global = _OpenHttp();

  test('this Mac listens only on its private address and checks the certificate', () async {
    final chosen = await _privateEn0();
    expect(chosen, isNotNull, reason: 'en0 üzerinde özel IPv4 yok.');
    final directory = await Directory.systemTemp.createTemp('ibul-lan-listen');
    await LanTlsMaterial.open(directory);
    final reissued = await LanTlsMaterial.ensureServerAddress(directory, chosen!.address);
    expect(reissued, isTrue);
    final material = await LanTlsMaterial.open(directory);
    final san = await Process.run('openssl', <String>[
      'x509', '-in', '${directory.path}/server.pem', '-noout', '-ext', 'subjectAltName',
    ]);
    expect('${san.stdout}', contains(chosen.address));

    final host = RestaurantLanHost(
      restaurantId: 'listen-check',
      operatorFingerprint: material.operatorFingerprint,
      certificateDirectory: directory.path,
      machineId: 'mac-listen-check',
      deviceStore: MemoryLanEnrollmentStore(),
      staffStillAuthorized: (_) async => const StaffProbe(StaffProbeKind.active),
    );
    await host.start(
      address: chosen,
      port: 0,
      securityContext: material.serverContext,
    );
    addTearDown(host.stop);

    expect(host.boundAddress, chosen.address);
    final listeners = await Process.run('lsof', <String>[
      '-nP', '-iTCP:${host.port}', '-sTCP:LISTEN',
    ]);
    expect('${listeners.stdout}', contains('${chosen.address}:${host.port}'));
    expect('${listeners.stdout}', isNot(contains('0.0.0.0:${host.port}')));
    expect('${listeners.stdout}', isNot(contains('*:${host.port}')));

    final uri = Uri.parse('https://${chosen.address}:${host.port}');
    final seen = await RestaurantLanClient(
      uri,
      securityContext: material.operatorContext,
      pinnedServerFingerprint: material.serverFingerprint,
    ).get('/lan/discover');
    expect(seen['ok'], isTrue);
    expect(seen['restaurant_id'], 'listen-check');
    expect(seen['listen_address'], chosen.address);

    await expectLater(
      RestaurantLanClient(
        uri,
        securityContext: SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates('${directory.path}/ca.pem'),
        pinnedServerFingerprint: 'ab' * 32,
      ).get('/lan/discover'),
      throwsA(isA<Exception>()),
    );

    final rejected = await RestaurantLanClient(
      uri,
      securityContext: SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates('${directory.path}/ca.pem'),
      pinnedServerFingerprint: material.serverFingerprint,
    ).post('/lan/orders', <String, Object?>{
      'local_order_id': 'unpaired',
      'restaurant_id': 'other-restaurant',
    });
    expect(rejected['status'], 401);
  });
}

Future<InternetAddress?> _privateEn0() async {
  for (final interface in await NetworkInterface.list()) {
    if (interface.name != 'en0') continue;
    for (final address in interface.addresses) {
      if (address.type != InternetAddressType.IPv4 || address.isLoopback) continue;
      final bytes = address.rawAddress;
      final private = bytes[0] == 10 ||
          bytes[0] == 192 && bytes[1] == 168 ||
          bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31;
      if (private) return address;
    }
  }
  return null;
}

class _OpenHttp extends HttpOverrides {}
