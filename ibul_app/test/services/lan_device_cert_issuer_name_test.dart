import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_cert_material.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';

/// A center whose CA was created by `openssl` (older installs) names itself
/// with a UTF8String. A device certificate signed in process must repeat that
/// name byte for byte, otherwise the center's own TLS refuses the device right
/// after a successful pairing.
void main() {
  final hasOpenSsl = File('/usr/bin/openssl').existsSync();

  test('a device certificate signed in process is accepted under an openssl-made CA', () async {
    final temp = await Directory.systemTemp.createTemp('ibul-lan-issuer');
    addTearDown(() => temp.delete(recursive: true));
    final d = temp.path;
    Future<void> openssl(List<String> args) async {
      final result = await Process.run('/usr/bin/openssl', args);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }

    await openssl(['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '30',
      '-subj', '/CN=ibul-lan-ca', '-keyout', '$d/ca.key', '-out', '$d/ca.pem']);
    await openssl(['req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=ibul-lan',
      '-keyout', '$d/server.key', '-out', '$d/server.csr']);
    await openssl(['x509', '-req', '-in', '$d/server.csr', '-CA', '$d/ca.pem',
      '-CAkey', '$d/ca.key', '-CAcreateserial', '-days', '30', '-out', '$d/server.pem']);

    final device = Directory('$d/device')..createSync();
    final request = await LanClientRequest.generate(directory: device, commonName: 'staff-1');
    final signed = await signCsrWithDartCa(directory: temp, csrPem: request.csr);
    expect(signed, isNotNull);
    await request.installSignedCertificate(certificate: signed!, caPath: '$d/ca.pem');

    final serverContext = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain('$d/server.pem')
      ..usePrivateKey('$d/server.key')
      ..setTrustedCertificates('$d/ca.pem')
      ..setClientAuthorities('$d/ca.pem');
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
      requestClientCertificate: true,
    );
    addTearDown(server.close);
    final accepted = <String>[];
    final errors = <Object>[];
    server.listen(
      (socket) {
        accepted.add(socket.peerCertificate?.subject ?? '');
        socket.destroy();
      },
      onError: errors.add,
    );
    final client = await SecureSocket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
      context: SecurityContext(withTrustedRoots: false)
        ..useCertificateChain('${device.path}/client.pem')
        ..usePrivateKey('${device.path}/client.key')
        ..setTrustedCertificates('$d/ca.pem'),
      onBadCertificate: (_) => true,
    );
    await client.drain<void>().timeout(const Duration(seconds: 2), onTimeout: () {});
    client.destroy();
    expect(errors, isEmpty);
    expect(accepted.single, contains('staff-1'));
  }, skip: hasOpenSsl ? false : 'openssl not available');
}
