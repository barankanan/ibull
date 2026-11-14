import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'lan_cert_material.dart';
import 'lan_client_key.dart';
import 'lan_pairing_guard.dart';

/// `IBUL_OPENSSL` points at a helper inside the app bundle when App Sandbox
/// cannot execute `/usr/bin/openssl`. The helper is signed with the app.
String lanOpenSslExecutable() {
  final override = Platform.environment['IBUL_OPENSSL']?.trim() ?? '';
  if (override.isNotEmpty) return override;
  return 'openssl';
}

/// TLS material for the local restaurant host.
///
/// Certificates come from the platform `openssl` so the transport is ordinary
/// TLS. The pairing code is not a key. Private keys stay in the directory
/// that created them and are not written to logs.
class LanTlsMaterial {
  LanTlsMaterial._({
    required this.directory,
    required this.serverContext,
    required this.operatorContext,
    required this.serverFingerprint,
    required this.operatorFingerprint,
  });

  final Directory directory;
  final SecurityContext serverContext;
  final SecurityContext operatorContext;
  final String serverFingerprint;
  final String operatorFingerprint;

  static Future<LanTlsMaterial> openForRestaurant(String restaurantId) async {
    final root = Directory(
      lanMaterialDirectory(
        operatingSystem: Platform.operatingSystem,
        environment: Platform.environment,
        restaurantId: restaurantId,
      ),
    );
    return open(root);
  }

  static Future<LanTlsMaterial> open(Directory directory) async {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    await _restrict(directory.path, '700');
    final serverPem = File('${directory.path}/server.pem');
    final serverKey = File('${directory.path}/server.key');
    final operatorPem = File('${directory.path}/operator.pem');
    final operatorKey = File('${directory.path}/operator.key');
    if (!serverPem.existsSync() || !operatorPem.existsSync()) {
      await _generate(directory);
    }
    await ensureEvidenceKey(directory);
    final caPem = File('${directory.path}/ca.pem');
    final server = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(serverPem.path)
      ..usePrivateKey(serverKey.path)
      ..setTrustedCertificates(caPem.path)
      ..setClientAuthorities(caPem.path);
    final operator = _clientContext(
      certificatePath: operatorPem.path,
      keyPath: operatorKey.path,
      serverCertificatePath: caPem.path,
    );
    return LanTlsMaterial._(
      directory: directory,
      serverContext: server,
      operatorContext: operator,
      serverFingerprint: await certificateFingerprint(serverPem.path),
      operatorFingerprint: await certificateFingerprint(operatorPem.path),
    );
  }

  static SecurityContext clientContext({
    required String certificatePath,
    required String keyPath,
    required String serverCertificatePath,
  }) {
    return _clientContext(
      certificatePath: certificatePath,
      keyPath: keyPath,
      serverCertificatePath: serverCertificatePath,
    );
  }

  static SecurityContext _clientContext({
    required String certificatePath,
    required String keyPath,
    required String serverCertificatePath,
  }) {
    return SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(certificatePath)
      ..usePrivateKey(keyPath)
      ..setTrustedCertificates(serverCertificatePath);
  }

  static Future<String> certificateFingerprint(String pemPath) async {
    try {
      final result = await Process.run(lanOpenSslExecutable(), <String>[
        'x509',
        '-in',
        pemPath,
        '-noout',
        '-fingerprint',
        '-sha256',
      ]);
      if (result.exitCode == 0) {
        final text = '${result.stdout}';
        final separator = text.lastIndexOf('=');
        if (separator >= 0) {
          return normalizeFingerprint(text.substring(separator + 1));
        }
      }
    } catch (_) {}
    return certificateSha256Hex(await File(pemPath).readAsString());
  }

  static String fingerprintOf(X509Certificate? certificate) {
    final der = certificate?.der;
    if (der == null || der.isEmpty) return '';
    return sha256.convert(der).toString();
  }

  static String normalizeFingerprint(String value) {
    return value.replaceAll(':', '').trim().toLowerCase();
  }

  /// Reissues only the server certificate so its name matches [ip].
  /// The private CA and operator key stay. Returns true when a new
  /// certificate was written. Clients that pinned the old fingerprint
  /// must pair again.
  static Future<bool> ensureServerAddress(Directory directory, String ip) async {
    final serverPem = File('${directory.path}/server.pem');
    final serverKey = File('${directory.path}/server.key');
    final caPem = File('${directory.path}/ca.pem');
    final caKey = File('${directory.path}/ca.key');
    if (!serverPem.existsSync() || !serverKey.existsSync() || !caPem.existsSync()) {
      return false;
    }
    final current = await Process.run(lanOpenSslExecutable(), <String>[
      'x509', '-in', serverPem.path, '-noout', '-ext', 'subjectAltName',
    ]);
    final text = '${current.stdout}';
    if (text.contains('127.0.0.1') && text.contains(ip)) return false;
    final ext = File('${directory.path}/server.ext');
    final csr = '${directory.path}/server.csr';
    await ext.writeAsString(
      'subjectAltName=IP:127.0.0.1,DNS:localhost,IP:$ip\n',
    );
    await _openssl(<String>[
      'req', '-new', '-key', serverKey.path, '-out', csr, '-subj', '/CN=ibul-lan',
    ]);
    await _openssl(<String>[
      'x509', '-req', '-in', csr,
      '-CA', caPem.path, '-CAkey', caKey.path, '-CAcreateserial',
      '-out', serverPem.path, '-days', '825', '-extfile', ext.path,
    ]);
    return true;
  }

  static Future<void> _generate(Directory directory) async {
    final caPem = '${directory.path}/ca.pem';
    final caKey = '${directory.path}/ca.key';
    final serverPem = '${directory.path}/server.pem';
    final serverKey = '${directory.path}/server.key';
    final serverCsr = '${directory.path}/server.csr';
    final operatorPem = '${directory.path}/operator.pem';
    final operatorKey = '${directory.path}/operator.key';
    final operatorCsr = '${directory.path}/operator.csr';
    final ext = File('${directory.path}/server.ext');
    await ext.writeAsString(
      'subjectAltName=IP:127.0.0.1,DNS:localhost\n',
    );
    await _openssl(<String>[
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
      '-keyout', caKey, '-out', caPem, '-days', '825',
      '-subj', '/CN=ibul-lan-ca',
    ]);
    await _openssl(<String>[
      'req', '-newkey', 'rsa:2048', '-nodes',
      '-keyout', serverKey, '-out', serverCsr,
      '-subj', '/CN=ibul-lan',
    ]);
    await _openssl(<String>[
      'x509', '-req', '-in', serverCsr,
      '-CA', caPem, '-CAkey', caKey, '-CAcreateserial',
      '-out', serverPem, '-days', '825',
      '-extfile', ext.path,
    ]);
    await _openssl(<String>[
      'req', '-newkey', 'rsa:2048', '-nodes',
      '-keyout', operatorKey, '-out', operatorCsr,
      '-subj', '/CN=ibul-operator',
    ]);
    await _openssl(<String>[
      'x509', '-req', '-in', operatorCsr,
      '-CA', caPem, '-CAkey', caKey, '-CAcreateserial',
      '-out', operatorPem, '-days', '825',
    ]);
    for (final name in <String>[caKey, serverKey, operatorKey]) {
      await _restrict(name, '600');
    }
  }

  /// Print evidence key. Certificate renewal does not replace this file.
  static Future<void> ensureEvidenceKey(Directory directory) async {
    final path = '${directory.path}/evidence.key';
    if (File(path).existsSync()) return;
    try {
      await _openssl(<String>[
        'genpkey',
        '-algorithm',
        'RSA',
        '-pkeyopt',
        'rsa_keygen_bits:2048',
        '-out',
        path,
      ]);
    } catch (_) {
      if (!File(path).existsSync()) {
        await writeDartTlsMaterial(directory, sanIps: const <String>['127.0.0.1']);
      }
    }
    if (File(path).existsSync()) await _restrict(path, '600');
  }

  static Future<({String id, String modulusHex, String path})> evidenceIdentity(
    Directory directory,
  ) async {
    await ensureEvidenceKey(directory);
    final path = '${directory.path}/evidence.key';
    final modulus = await Process.run(lanOpenSslExecutable(), <String>[
      'rsa',
      '-in',
      path,
      '-noout',
      '-modulus',
    ]);
    if (modulus.exitCode != 0) {
      throw StateError('Baskı kanıtı anahtarı okunamadı.');
    }
    final text = '${modulus.stdout}'.trim();
    final separator = text.indexOf('=');
    if (separator < 0) throw StateError('Baskı kanıtı anahtarı okunamadı.');
    final hex = text.substring(separator + 1).trim().toLowerCase();
    if (hex.length < 512 || hex.length.isOdd) {
      throw StateError('Baskı kanıtı anahtarı yetersiz.');
    }
    return (id: await _evidenceKeyId(hex), modulusHex: hex, path: path);
  }

  /// Retires the current evidence key and creates the next one.
  /// The TLS key is left in place. The retired private key stays on disk
  /// only so an already issued signature can be recognized until its
  /// public row is revoked.
  static Future<void> rotateEvidenceKey(Directory directory) async {
    final current = await evidenceIdentity(directory);
    final retired = File('${directory.path}/evidence.retired-${current.id}.key');
    await File(current.path).rename(retired.path);
    await _restrict(retired.path, '600');
    await ensureEvidenceKey(directory);
  }

  static Future<String> _evidenceKeyId(String modulusHex) async {
    final bytes = <int>[];
    for (var index = 0; index < modulusHex.length; index += 2) {
      bytes.add(int.parse(modulusHex.substring(index, index + 2), radix: 16));
    }
    final process = await Process.start(lanOpenSslExecutable(), <String>['dgst', '-sha256']);
    process.stdin.add(bytes);
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    if (await process.exitCode != 0) {
      throw StateError('Baskı kanıtı anahtar kimliği okunamadı.');
    }
    final digest = out.substring(out.lastIndexOf('=') + 1).trim().toLowerCase();
    if (digest.length < 16) {
      throw StateError('Baskı kanıtı anahtar kimliği okunamadı.');
    }
    return digest.substring(0, 16);
  }

  static Future<void> _restrict(String path, String mode) async {
    if (Platform.isWindows) return;
    await Process.run('chmod', <String>[mode, path]);
  }

  static Future<void> _openssl(List<String> args) async {
    final result = await Process.run(lanOpenSslExecutable(), args);
    if (result.exitCode != 0) {
      throw StateError('Yerel TLS sertifikası oluşturulamadı.');
    }
  }
}

/// A waiter device key. It is self-signed until the owner enrolls its
/// fingerprint with the one-time pairing code.
class LanClientRequest {
  LanClientRequest({required this.directory, required this.csr});

  final Directory directory;
  final String csr;

  static Future<LanClientRequest> generate({
    required Directory directory,
    required String commonName,
  }) async {
    if (Platform.isIOS || Platform.isAndroid) {
      return generateNative(directory: directory, commonName: commonName);
    }
    try {
      return await _generateWithOpenSsl(
        directory: directory,
        commonName: commonName,
      );
    } catch (_) {
      return generateNative(directory: directory, commonName: commonName);
    }
  }

  /// Phone and tablet builds have no openssl binary. The private key is
  /// written only into the caller-supplied directory.
  static Future<LanClientRequest> generateNative({
    required Directory directory,
    required String commonName,
  }) async {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final material = createLanDeviceKey(commonName: commonName);
    final key = File('${directory.path}/client.key');
    await key.writeAsString(material.privateKeyPem);
    await LanTlsMaterial._restrict(key.path, '600');
    return LanClientRequest(directory: directory, csr: material.csrPem);
  }

  static Future<LanClientRequest> _generateWithOpenSsl({
    required Directory directory,
    required String commonName,
  }) async {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final key = '${directory.path}/client.key';
    final csr = '${directory.path}/client.csr';
    final result = await Process.run(lanOpenSslExecutable(), <String>[
      'req', '-newkey', 'rsa:2048', '-nodes',
      '-keyout', key, '-out', csr,
      '-subj', '/CN=$commonName',
    ]);
    if (result.exitCode != 0) {
      throw StateError('Cihaz sertifika isteği oluşturulamadı.');
    }
    await LanTlsMaterial._restrict(key, '600');
    return LanClientRequest(
      directory: directory,
      csr: await File(csr).readAsString(),
    );
  }

  Future<SecurityContext> installSignedCertificate({
    required String certificate,
    required String caPath,
  }) async {
    final pem = File('${directory.path}/client.pem');
    await pem.writeAsString(certificate);
    return SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(pem.path)
      ..usePrivateKey('${directory.path}/client.key')
      ..setTrustedCertificates(caPath);
  }
}

/// A waiter certificate after the owner host has signed the local key.
class LanClientCertificate {
  LanClientCertificate({
    required this.directory,
    required this.context,
    required this.fingerprint,
  });

  final Directory directory;
  final SecurityContext context;
  final String fingerprint;

  static Future<LanClientCertificate?> load({
    required Directory directory,
  }) async {
    final pem = File('${directory.path}/client.pem');
    final key = File('${directory.path}/client.key');
    if (!pem.existsSync() || !key.existsSync()) return null;
    return LanClientCertificate(
      directory: directory,
      context: _identity(pem.path, key.path),
      fingerprint: await LanTlsMaterial.certificateFingerprint(pem.path),
    );
  }

  static Future<LanClientCertificate> generate({
    required Directory directory,
    required String commonName,
  }) async {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final pem = '${directory.path}/client.pem';
    final key = '${directory.path}/client.key';
    final result = await Process.run(lanOpenSslExecutable(), <String>[
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
      '-keyout', key, '-out', pem, '-days', '825',
      '-subj', '/CN=$commonName',
    ]);
    if (result.exitCode != 0) {
      throw StateError('Cihaz sertifikası oluşturulamadı.');
    }
    await LanTlsMaterial._restrict(key, '600');
    return LanClientCertificate(
      directory: directory,
      context: _identity(pem, key),
      fingerprint: await LanTlsMaterial.certificateFingerprint(pem),
    );
  }

  static SecurityContext _identity(String certificatePath, String keyPath) {
    return SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(certificatePath)
      ..usePrivateKey(keyPath);
  }
}
