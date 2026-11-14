import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Device key and certificate request created inside the app.
///
/// The private key stays in the returned PEM. Callers must not log it.
class LanDeviceKeyMaterial {
  const LanDeviceKeyMaterial({required this.privateKeyPem, required this.csrPem});

  final String privateKeyPem;
  final String csrPem;
}

LanDeviceKeyMaterial createLanDeviceKey({String commonName = 'ibul-waiter'}) {
  final random = _fortuna();
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        random,
      ),
    );
  final pair = generator.generateKeyPair();
  final publicKey = pair.publicKey;
  final privateKey = pair.privateKey;
  final privatePem = _pkcs1(privateKey, publicKey.exponent!);
  final csr = _csr(
    commonName: commonName,
    publicKey: publicKey,
    privateKey: privateKey,
  );
  return LanDeviceKeyMaterial(privateKeyPem: privatePem, csrPem: csr);
}

FortunaRandom _fortuna() {
  final seed = Uint8List(32);
  final secure = Random.secure();
  for (var index = 0; index < seed.length; index++) {
    seed[index] = secure.nextInt(256);
  }
  return FortunaRandom()..seed(KeyParameter(seed));
}

String _pkcs1(RSAPrivateKey key, BigInt publicExponent) {
  final p = key.p!;
  final q = key.q!;
  final sequence = ASN1Sequence(elements: <ASN1Object>[
    ASN1Integer(BigInt.zero),
    ASN1Integer(key.modulus),
    ASN1Integer(publicExponent),
    ASN1Integer(key.privateExponent),
    ASN1Integer(p),
    ASN1Integer(q),
    ASN1Integer(key.privateExponent! % (p - BigInt.one)),
    ASN1Integer(key.privateExponent! % (q - BigInt.one)),
    ASN1Integer(q.modInverse(p)),
  ]);
  return _pem('RSA PRIVATE KEY', sequence.encode());
}

String _csr({
  required String commonName,
  required RSAPublicKey publicKey,
  required RSAPrivateKey privateKey,
}) {
  final info = ASN1Sequence(elements: <ASN1Object>[
    ASN1Integer(BigInt.zero),
    ASN1Sequence(elements: <ASN1Object>[
      ASN1Set(elements: <ASN1Object>[
        ASN1Sequence(elements: <ASN1Object>[
          ASN1ObjectIdentifier.fromIdentifierString('2.5.4.3'),
          ASN1UTF8String(utf8StringValue: commonName),
        ]),
      ]),
    ]),
    _publicKeyInfo(publicKey),
    ASN1Set(elements: <ASN1Object>[], tag: 0xA0),
  ]);
  final infoBytes = info.encode();
  final signer = Signer('SHA-256/RSA')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  final signature = signer.generateSignature(infoBytes) as RSASignature;
  final request = ASN1Sequence(elements: <ASN1Object>[
    ASN1Sequence.fromBytes(infoBytes),
    ASN1Sequence(elements: <ASN1Object>[
      ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.11'),
      ASN1Null(),
    ]),
    ASN1BitString(stringValues: signature.bytes),
  ]);
  return _pem('CERTIFICATE REQUEST', request.encode());
}

ASN1Sequence _publicKeyInfo(RSAPublicKey key) {
  final rsa = ASN1Sequence(elements: <ASN1Object>[
    ASN1Integer(key.modulus),
    ASN1Integer(key.exponent),
  ]).encode();
  return ASN1Sequence(elements: <ASN1Object>[
    ASN1Sequence(elements: <ASN1Object>[
      ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
      ASN1Null(),
    ]),
    ASN1BitString(stringValues: rsa),
  ]);
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
