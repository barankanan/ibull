import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_cert_material.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pairing_guard.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';

bool get _hasOpenSsl => Process.runSync('which', <String>['openssl']).exitCode == 0;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ibul-tls-'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('first-run material is created in process and works as TLS context', () async {
    final material = await LanTlsMaterial.open(dir);
    for (final name in ['ca.pem', 'ca.key', 'server.pem', 'server.key', 'operator.pem', 'operator.key', 'evidence.key']) {
      expect(File('${dir.path}/$name').existsSync(), isTrue, reason: name);
    }
    expect(material.serverFingerprint, hasLength(64));
    expect(material.serverFingerprint, certificateSha256Hex(File('${dir.path}/server.pem').readAsStringSync()));
    expect(material.operatorFingerprint, isNot(material.serverFingerprint));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('private keys are not readable by others', () async {
    if (Platform.isWindows) return;
    await LanTlsMaterial.open(dir);
    for (final name in ['ca.key', 'server.key', 'operator.key', 'evidence.key']) {
      final mode = File('${dir.path}/$name').statSync().mode & 0x1ff;
      expect(mode & 0x3f, 0, reason: '$name mode ${mode.toRadixString(8)}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('server address reissue adds the IP once and keeps CA and operator', () async {
    await LanTlsMaterial.open(dir);
    final ca = File('${dir.path}/ca.pem').readAsStringSync();
    final operator = File('${dir.path}/operator.pem').readAsStringSync();
    final before = File('${dir.path}/server.pem').readAsStringSync();
    expect(serverCertificateNamesIps(before, ['192.168.10.158']), isFalse);
    expect(await LanTlsMaterial.ensureServerAddress(dir, '192.168.10.158'), isTrue);
    final after = File('${dir.path}/server.pem').readAsStringSync();
    expect(serverCertificateNamesIps(after, ['127.0.0.1', '192.168.10.158']), isTrue);
    expect(await LanTlsMaterial.ensureServerAddress(dir, '192.168.10.158'), isFalse);
    expect(File('${dir.path}/ca.pem').readAsStringSync(), ca);
    expect(File('${dir.path}/operator.pem').readAsStringSync(), operator);
    if (_hasOpenSsl) {
      final verify = Process.runSync('openssl', ['verify', '-CAfile', '${dir.path}/ca.pem', '${dir.path}/server.pem']);
      expect(verify.exitCode, 0, reason: '${verify.stdout}${verify.stderr}');
      final san = Process.runSync('openssl', ['x509', '-in', '${dir.path}/server.pem', '-noout', '-ext', 'subjectAltName']);
      expect('${san.stdout}', contains('192.168.10.158'));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('evidence identity matches openssl for the same key (PKCS#1 and PKCS#8)', () async {
    if (!_hasOpenSsl) return;
    final pkcs8 = '${dir.path}/p8.key';
    final gen = Process.runSync('openssl', ['genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', pkcs8]);
    expect(gen.exitCode, 0);
    File('${dir.path}/evidence.key').writeAsStringSync(File(pkcs8).readAsStringSync());
    final id = await LanTlsMaterial.evidenceIdentity(dir);
    final mod = Process.runSync('openssl', ['rsa', '-in', pkcs8, '-noout', '-modulus']);
    final expected = '${mod.stdout}'.trim().split('=').last.toLowerCase();
    expect(id.modulusHex, expected);
    final digest = Process.runSync('sh', ['-c', "printf '%s' '$expected' | xxd -r -p | openssl dgst -sha256"]);
    expect(id.id, '${digest.stdout}'.trim().split('= ').last.substring(0, 16));
    // PKCS#1 form (what the in-process generator writes) gives the same shape.
    File('${dir.path}/evidence.key').deleteSync();
    final own = await LanTlsMaterial.evidenceIdentity(dir);
    expect(own.modulusHex.length, greaterThanOrEqualTo(512));
    expect(own.id, hasLength(16));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('device CSRs are signed in process and verify against the CA', () async {
    await LanTlsMaterial.open(dir);
    final client = Directory('${dir.path}/client')..createSync();
    final request = await LanClientRequest.generate(directory: client, commonName: 'staff-x');
    final cert = await signCsrWithDartCa(directory: dir, csrPem: request.csr);
    expect(cert, isNotNull);
    if (_hasOpenSsl) {
      File('${dir.path}/dev.pem').writeAsStringSync(cert!);
      final verify = Process.runSync('openssl', ['verify', '-CAfile', '${dir.path}/ca.pem', '${dir.path}/dev.pem']);
      expect(verify.exitCode, 0, reason: '${verify.stdout}${verify.stderr}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('evidence signatures made in process verify with openssl and against the modulus', () async {
    await LanTlsMaterial.open(dir);
    final pem = File('${dir.path}/evidence.key').readAsStringSync();
    final message = List<int>.generate(300, (i) => (i * 7) % 251);
    final signature = signSha256Rsa(pem, message)!;
    expect(signature.length, 256);
    if (!_hasOpenSsl) return;
    File('${dir.path}/msg.bin').writeAsBytesSync(message);
    File('${dir.path}/sig.bin').writeAsBytesSync(signature);
    final pub = Process.runSync('openssl', ['rsa', '-in', '${dir.path}/evidence.key', '-pubout', '-out', '${dir.path}/pub.pem']);
    expect(pub.exitCode, 0, reason: '${pub.stderr}');
    final verify = Process.runSync('openssl', ['dgst', '-sha256', '-verify', '${dir.path}/pub.pem', '-signature', '${dir.path}/sig.bin', '${dir.path}/msg.bin']);
    expect('${verify.stdout}', contains('Verified OK'));
    File('${dir.path}/msg.bin').writeAsBytesSync([...message, 1]);
    final bad = Process.runSync('openssl', ['dgst', '-sha256', '-verify', '${dir.path}/pub.pem', '-signature', '${dir.path}/sig.bin', '${dir.path}/msg.bin']);
    expect(bad.exitCode, isNot(0));
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('authority lock', () {
    test('a second claim fails until release, and a stale file never blocks', () async {
      final file = File('${dir.path}/authority.lock')..writeAsStringSync('999999');
      final a = LanAuthorityLock(file);
      expect(await a.acquire(), isTrue);
      expect(await LanAuthorityLock(file).acquire(), isFalse);
      await a.release();
      expect(await LanAuthorityLock(file).acquire(), isTrue);
    });
  });
}
