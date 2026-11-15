import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_client_key.dart';

void main() {
  test('phone key request is accepted by openssl and hides the private key', () async {
    final material = createLanDeviceKey();
    expect(material.csrPem, contains('BEGIN CERTIFICATE REQUEST'));
    expect(material.privateKeyPem, contains('BEGIN RSA PRIVATE KEY'));
    expect(material.csrPem.contains('PRIVATE KEY'), isFalse);

    final directory = await Directory.systemTemp.createTemp('ibul-csr');
    final csr = File('${directory.path}/client.csr');
    await csr.writeAsString(material.csrPem);
    final verified = await Process.run('openssl', <String>[
      'req', '-in', csr.path, '-noout', '-verify',
    ]);
    expect(verified.exitCode, 0, reason: '${verified.stderr}');
    expect('${verified.stdout}${verified.stderr}', contains('verify OK'));
  });
}
