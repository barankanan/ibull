import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_cert_material.dart';
import 'package:ibul_app/services/restaurant_offline/lan_client_key.dart';

void main() {
  HttpOverrides.global = _RealHttp();
  test('dart certificates complete a TLS handshake and sign a request', () async {
    final root = await Directory.systemTemp.createTemp('ibul-dart-cert');
    addTearDown(() => root.delete(recursive: true));
    await writeDartTlsMaterial(root, sanIps: const <String>['192.168.1.20']);
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain('${root.path}/server.pem')
      ..usePrivateKey('${root.path}/server.key')
      ..setTrustedCertificates('${root.path}/ca.pem')
      ..setClientAuthorities('${root.path}/ca.pem');
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
    );
    addTearDown(server.close);
    server.listen((request) => request.response.close());
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates('${root.path}/ca.pem'),
    );
    client.badCertificateCallback = (certificate, host, port) => true;
    final request = await client.getUrl(
      Uri.parse('https://127.0.0.1:${server.port}/lan/discover'),
    );
    final response = await request.close();
    expect(response.statusCode, 200);
    final waiter = await Directory.systemTemp.createTemp('ibul-dart-waiter');
    addTearDown(() => waiter.delete(recursive: true));
    final csr = createLanDeviceKey(commonName: 'waiter-a');
    final signed = await signCsrWithDartCa(directory: root, csrPem: csr.csrPem);
    expect(signed, contains('BEGIN CERTIFICATE'));
    expect(certificateSha256Hex(signed!), hasLength(64));
  });
}

class _RealHttp extends HttpOverrides {}
