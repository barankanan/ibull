import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// In-process CA and server certificates.
///
/// App Sandbox cannot execute `/usr/bin/openssl`. These certificates are the
/// same PEM files the existing host already reads. Private keys stay in those
/// files and are not copied into preferences.
Future<void> writeDartTlsMaterial(
  Directory directory, {
  required List<String> sanIps,
}) async {
  if (!directory.existsSync()) directory.createSync(recursive: true);
  final ca = _keyPair();
  final server = _keyPair();
  final operator = _keyPair();
  final ips = <String>{'127.0.0.1', ...sanIps.where((ip) => ip.trim().isNotEmpty)};
  await _writePair(
    directory: directory,
    name: 'ca',
    pair: ca,
    issuer: ca,
    commonName: 'ibul-lan-ca',
    isCa: true,
    sanIps: const <String>[],
  );
  await _writePair(
    directory: directory,
    name: 'server',
    pair: server,
    issuer: ca,
    commonName: 'ibul-lan',
    isCa: false,
    sanIps: ips.toList(),
    dnsNames: const <String>['localhost'],
  );
  await _writePair(
    directory: directory,
    name: 'operator',
    pair: operator,
    issuer: ca,
    commonName: 'ibul-operator',
    isCa: false,
    sanIps: const <String>[],
  );
  final evidence = _keyPair();
  await File('${directory.path}/evidence.key').writeAsString(
    _pem('RSA PRIVATE KEY', _pkcs1(evidence.privateKey, evidence.publicKey.exponent!)),
  );
}

Future<String?> signCsrWithDartCa({
  required Directory directory,
  required String csrPem,
}) async {
  final caKey = _privateKeyFromPem(await File('${directory.path}/ca.key').readAsString());
  final caCert = await File('${directory.path}/ca.pem').readAsString();
  final issuer = _commonNameFromCertificate(caCert) ?? 'ibul-lan-ca';
  final csr = _csrParts(csrPem);
  if (csr == null || caKey == null) return null;
  final der = _certificate(
    serial: DateTime.now().millisecondsSinceEpoch,
    issuerCn: issuer,
    subjectCn: csr.commonName,
    subjectPublic: csr.publicKey,
    signer: caKey,
    isCa: false,
    sanIps: const <String>[],
    dnsNames: const <String>[],
  );
  return _pem('CERTIFICATE', der);
}

String certificateSha256Hex(String pem) {
  final der = _derFromPem(pem);
  return sha256.convert(der).toString();
}

String? rsaModulusHexFromPkcs1Pem(String pem) {
  final key = _privateKeyFromPem(pem);
  final modulus = key?.modulus;
  if (modulus == null) return null;
  var hex = modulus.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  return hex.toLowerCase();
}

Future<void> _writePair({
  required Directory directory,
  required String name,
  required _KeyPair pair,
  required _KeyPair issuer,
  required String commonName,
  required bool isCa,
  required List<String> sanIps,
  List<String> dnsNames = const <String>[],
}) async {
  final cert = _certificate(
    serial: name.hashCode.abs() + 1,
    issuerCn: isCa ? commonName : 'ibul-lan-ca',
    subjectCn: commonName,
    subjectPublic: pair.publicKey,
    signer: issuer.privateKey,
    isCa: isCa,
    sanIps: sanIps,
    dnsNames: dnsNames,
  );
  await File('${directory.path}/$name.pem').writeAsString(_pem('CERTIFICATE', cert));
  await File('${directory.path}/$name.key').writeAsString(
    _pem('RSA PRIVATE KEY', _pkcs1(pair.privateKey, pair.publicKey.exponent!)),
  );
}

class _KeyPair {
  const _KeyPair(this.publicKey, this.privateKey);
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;
}

_KeyPair _keyPair() {
  final seed = Uint8List(32);
  final random = Random.secure();
  for (var index = 0; index < seed.length; index++) {
    seed[index] = random.nextInt(256);
  }
  final fortuna = FortunaRandom()..seed(KeyParameter(seed));
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        fortuna,
      ),
    );
  final pair = generator.generateKeyPair();
  return _KeyPair(pair.publicKey as RSAPublicKey, pair.privateKey as RSAPrivateKey);
}

Uint8List _certificate({
  required int serial,
  required String issuerCn,
  required String subjectCn,
  required RSAPublicKey subjectPublic,
  required RSAPrivateKey signer,
  required bool isCa,
  required List<String> sanIps,
  required List<String> dnsNames,
}) {
  final algorithm = _sequence(<Uint8List>[
    _oid(const <int>[1, 2, 840, 113549, 1, 1, 11]),
    _tag(0x05, Uint8List(0)),
  ]);
  final spki = _sequence(<Uint8List>[
    _sequence(<Uint8List>[
      _oid(const <int>[1, 2, 840, 113549, 1, 1, 1]),
      _tag(0x05, Uint8List(0)),
    ]),
    _bitString(_sequence(<Uint8List>[
      _integer(subjectPublic.modulus!),
      _integer(subjectPublic.exponent!),
    ])),
  ]);
  final extensions = <Uint8List>[
    if (isCa)
      _extension(
        oid: const <int>[2, 5, 29, 19],
        critical: true,
        value: _sequence(<Uint8List>[_tag(0x01, Uint8List.fromList(<int>[0xff]))]),
      ),
    if (sanIps.isNotEmpty || dnsNames.isNotEmpty)
      _extension(
        oid: const <int>[2, 5, 29, 17],
        critical: false,
        value: _sequence(<Uint8List>[
          for (final name in dnsNames) _context(2, utf8.encode(name)),
          for (final ip in sanIps) _context(7, _ipv4(ip)),
        ]),
      ),
  ];
  final tbsChildren = <Uint8List>[
    _explicit(0, _integer(BigInt.from(2))),
    _integer(BigInt.from(serial)),
    algorithm,
    _name(issuerCn),
    _sequence(<Uint8List>[_utc(DateTime.utc(2026, 1, 1)), _utc(DateTime.utc(2028, 1, 1))]),
    _name(subjectCn),
    spki,
    if (extensions.isNotEmpty) _explicit(3, _sequence(extensions)),
  ];
  final tbs = _sequence(tbsChildren);
  final signerEngine = Signer('SHA-256/RSA')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(signer));
  final signature = (signerEngine.generateSignature(tbs) as RSASignature).bytes;
  return _sequence(<Uint8List>[tbs, algorithm, _bitString(signature)]);
}

Uint8List _extension({
  required List<int> oid,
  required bool critical,
  required Uint8List value,
}) {
  return _sequence(<Uint8List>[
    _oid(oid),
    if (critical) _tag(0x01, Uint8List.fromList(<int>[0xff])),
    _tag(0x04, value),
  ]);
}

Uint8List _name(String commonName) {
  return _sequence(<Uint8List>[
    _tag(
      0x31,
      _sequence(<Uint8List>[
        _oid(const <int>[2, 5, 4, 3]),
        _tag(0x13, ascii.encode(commonName)),
      ]),
    ),
  ]);
}

Uint8List _pkcs1(RSAPrivateKey key, BigInt publicExponent) {
  final p = key.p!;
  final q = key.q!;
  return _sequence(<Uint8List>[
    _integer(BigInt.zero),
    _integer(key.modulus!),
    _integer(publicExponent),
    _integer(key.privateExponent!),
    _integer(p),
    _integer(q),
    _integer(key.privateExponent! % (p - BigInt.one)),
    _integer(key.privateExponent! % (q - BigInt.one)),
    _integer(q.modInverse(p)),
  ]);
}

class _CsrParts {
  const _CsrParts(this.commonName, this.publicKey);
  final String commonName;
  final RSAPublicKey publicKey;
}

_CsrParts? _csrParts(String pem) {
  try {
    final parser = ASN1Parser(_derFromPem(pem));
    final outer = parser.nextObject() as ASN1Sequence;
    final info = outer.elements![0] as ASN1Sequence;
    final subject = info.elements![1] as ASN1Sequence;
    final set = subject.elements![0] as ASN1Set;
    final cnSeq = set.elements![0] as ASN1Sequence;
    final cn = utf8.decode((cnSeq.elements![1] as ASN1Object).valueBytes!);
    final spki = info.elements![2] as ASN1Sequence;
    final bit = spki.elements![1] as ASN1BitString;
    final keyParser = ASN1Parser(Uint8List.fromList(bit.stringValues!));
    final keySeq = keyParser.nextObject() as ASN1Sequence;
    final modulus = (keySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (keySeq.elements![1] as ASN1Integer).integer!;
    return _CsrParts(cn, RSAPublicKey(modulus, exponent));
  } catch (_) {
    return null;
  }
}

String? _commonNameFromCertificate(String pem) {
  try {
    final parser = ASN1Parser(_derFromPem(pem));
    final outer = parser.nextObject() as ASN1Sequence;
    final tbs = outer.elements![0] as ASN1Sequence;
    final subject = tbs.elements!.whereType<ASN1Sequence>().elementAt(4);
    final set = subject.elements![0] as ASN1Set;
    final cnSeq = set.elements![0] as ASN1Sequence;
    return ascii.decode((cnSeq.elements![1] as ASN1Object).valueBytes!);
  } catch (_) {
    return null;
  }
}

RSAPrivateKey? _privateKeyFromPem(String pem) {
  try {
    final parser = ASN1Parser(_derFromPem(pem));
    final seq = parser.nextObject() as ASN1Sequence;
    final values = seq.elements!.whereType<ASN1Integer>().map((item) => item.integer!).toList();
    return RSAPrivateKey(values[1], values[3], values[4], values[5]);
  } catch (_) {
    return null;
  }
}

Uint8List _derFromPem(String pem) {
  final body = pem
      .replaceAll('\r', '')
      .split('\n')
      .where((line) => !line.startsWith('-----'))
      .join();
  return Uint8List.fromList(base64Decode(body));
}

String _pem(String label, Uint8List der) {
  final text = base64Encode(der);
  final lines = <String>[];
  for (var index = 0; index < text.length; index += 64) {
    final end = index + 64 > text.length ? text.length : index + 64;
    lines.add(text.substring(index, end));
  }
  return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
}

Uint8List _ipv4(String ip) {
  return Uint8List.fromList(ip.split('.').map(int.parse).toList());
}

Uint8List _utc(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  final text = '${two(time.year % 100)}${two(time.month)}${two(time.day)}'
      '${two(time.hour)}${two(time.minute)}${two(time.second)}Z';
  return _tag(0x17, ascii.encode(text));
}

Uint8List _explicit(int number, Uint8List inner) => _tag(0xA0 + number, inner);

Uint8List _context(int number, List<int> body) => _tag(0x80 + number, Uint8List.fromList(body));

Uint8List _bitString(Uint8List payload) {
  return _tag(0x03, Uint8List.fromList(<int>[0, ...payload]));
}

Uint8List _sequence(List<Uint8List> children) => _tag(0x30, _join(children));

Uint8List _integer(BigInt value) {
  if (value == BigInt.zero) return _tag(0x02, Uint8List.fromList(<int>[0]));
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final bytes = <int>[];
  for (var index = 0; index < hex.length; index += 2) {
    bytes.add(int.parse(hex.substring(index, index + 2), radix: 16));
  }
  if ((bytes[0] & 0x80) != 0) bytes.insert(0, 0);
  return _tag(0x02, Uint8List.fromList(bytes));
}

Uint8List _oid(List<int> arcs) {
  final body = <int>[arcs[0] * 40 + arcs[1]];
  for (final arc in arcs.skip(2)) {
    final encoded = <int>[arc & 0x7f];
    var value = arc >> 7;
    while (value > 0) {
      encoded.insert(0, (value & 0x7f) | 0x80);
      value >>= 7;
    }
    body.addAll(encoded);
  }
  return _tag(0x06, Uint8List.fromList(body));
}

Uint8List _tag(int tag, Uint8List body) {
  final length = <int>[];
  if (body.length < 128) {
    length.add(body.length);
  } else {
    final bytes = <int>[];
    var value = body.length;
    while (value > 0) {
      bytes.insert(0, value & 0xff);
      value >>= 8;
    }
    length.add(0x80 | bytes.length);
    length.addAll(bytes);
  }
  return Uint8List.fromList(<int>[tag, ...length, ...body]);
}

Uint8List _join(List<Uint8List> parts) {
  final out = BytesBuilder(copy: false);
  for (final part in parts) {
    out.add(part);
  }
  return out.toBytes();
}
