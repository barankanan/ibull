import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

List<int> lanCodeKey(String code) => sha256.convert(utf8.encode(code.trim())).bytes;

/// The one-time code proves this pairing only. The proof is bound to the
/// caller's ephemeral public key, so a sniffed code cannot wrap the session.
String lanPairingProof({
  required String code,
  required String deviceId,
  required String clientPublicKey,
}) {
  final material = '${deviceId.trim()}|${clientPublicKey.trim()}';
  final mac = Hmac(sha256, lanCodeKey(code)).convert(utf8.encode(material));
  return mac.toString();
}

bool lanPairingProofMatches({
  required String code,
  required String deviceId,
  required String proof,
  required String clientPublicKey,
}) {
  if (clientPublicKey.trim().isEmpty) return false;
  return proof.trim() ==
      lanPairingProof(
        code: code,
        deviceId: deviceId,
        clientPublicKey: clientPublicKey,
      );
}

/// AES-256-GCM with a direction-separated key and a caller-supplied counter.
/// The counter is the nonce. Request and response directions never share it.
String sealLanBox(
  List<int> key,
  String plaintext, {
  required String direction,
  required int nonce,
}) {
  if (nonce <= 0) {
    throw ArgumentError.value(nonce, 'nonce', 'AES-GCM nonce must increase from 1.');
  }
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(_directionKey(key, direction)),
        128,
        _nonceBytes(nonce),
        Uint8List(0),
      ),
    );
  final sealed = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
  return base64Encode(<int>[..._nonceBytes(nonce), ...sealed]);
}

String? openLanBox(
  List<int> key,
  String box, {
  required String direction,
}) {
  try {
    final raw = base64Decode(box);
    if (raw.length < 12 + 16) return null;
    final nonce = Uint8List.fromList(raw.sublist(0, 12));
    final sealed = Uint8List.fromList(raw.sublist(12));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_directionKey(key, direction)),
          128,
          nonce,
          Uint8List(0),
        ),
      );
    return utf8.decode(cipher.process(sealed));
  } catch (_) {
    return null;
  }
}

/// Ephemeral P-256 key. The session is sealed to this key, not to the 6-digit code.
class LanEphemeralKey {
  LanEphemeralKey._(this._pair);

  static final ECDomainParameters _domain = ECCurve_secp256r1();
  final AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _pair;

  factory LanEphemeralKey.generate() {
    final random = FortunaRandom();
    final seed = Uint8List(32);
    final source = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = source.nextInt(256);
    }
    random.seed(KeyParameter(seed));
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(ECKeyGeneratorParameters(_domain), random),
      );
    return LanEphemeralKey._(generator.generateKeyPair());
  }

  String get publicKey {
    final encoded = _pair.publicKey.Q?.getEncoded(false);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Geçici açık anahtar üretilemedi.');
    }
    return base64Encode(encoded);
  }

  String sealSession(String remotePublicKey, String session) {
    return sealLanBox(
      _shared(remotePublicKey),
      session,
      direction: 'pair',
      nonce: 1,
    );
  }

  String? openSession(String remotePublicKey, String box) {
    try {
      return openLanBox(_shared(remotePublicKey), box, direction: 'pair');
    } catch (_) {
      return null;
    }
  }

  List<int> _shared(String remotePublicKey) {
    final point = _domain.curve.decodePoint(base64Decode(remotePublicKey));
    if (point == null) {
      throw ArgumentError('Karşı tarafın açık anahtarı geçersiz.');
    }
    final agreement = ECDHBasicAgreement()..init(_pair.privateKey);
    final secret = agreement.calculateAgreement(ECPublicKey(point, _domain));
    return sha256.convert(_unsignedBytes(secret, 32)).bytes;
  }
}

Uint8List _nonceBytes(int nonce) {
  final bytes = Uint8List(12);
  var value = nonce;
  for (var i = 11; i >= 0; i--) {
    bytes[i] = value & 0xff;
    value >>= 8;
  }
  return bytes;
}

Uint8List _directionKey(List<int> key, String direction) {
  return Uint8List.fromList(
    Hmac(sha256, _aesKey(key)).convert(utf8.encode(direction)).bytes,
  );
}

Uint8List _aesKey(List<int> key) {
  if (key.length == 32) return Uint8List.fromList(key);
  return Uint8List.fromList(sha256.convert(key).bytes);
}

Uint8List _unsignedBytes(BigInt value, int width) {
  final hex = value.toRadixString(16).padLeft(width * 2, '0');
  final normalized = hex.length > width * 2
      ? hex.substring(hex.length - width * 2)
      : hex;
  final out = Uint8List(width);
  for (var i = 0; i < width; i++) {
    out[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

Map<String, dynamic> stripLanSecrets(Map<String, dynamic> row) {
  final copy = Map<String, dynamic>.from(row);
  copy.removeWhere((key, _) {
    final name = key.toLowerCase();
    return name.contains('printer') ||
        name.contains('ip_address') ||
        name == 'host';
  });
  return copy;
}
