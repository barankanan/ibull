import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'offline_identity_seal.dart';
import 'offline_panel_identity.dart';

/// Seals what the LAN center learned about a staff member while the cloud was
/// reachable, so it can be trusted (for a limited time) when it is not.
///
/// The seal is an HMAC-SHA256 under the device secret that lives only in the
/// platform keystore. When the keystore refuses, nothing is signed and
/// nothing verifies: the center then admits no one without the cloud. There is
/// no settings-file fallback.
abstract class LanAuthoritySealer {
  Future<String?> sign(String canonical);
  Future<bool> verify(String canonical, String seal);
}

String _mac(String keyBase64, String canonical) {
  return Hmac(sha256, base64Decode(keyBase64))
      .convert(utf8.encode('lan-authority.v1|$canonical'))
      .toString();
}

bool _same(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

class KeystoreLanAuthoritySealer implements LanAuthoritySealer {
  KeystoreLanAuthoritySealer([OfflineSealKeyVault? vault])
    : _vault = vault ?? KeystoreSealKeyVault();

  final OfflineSealKeyVault _vault;

  @override
  Future<String?> sign(String canonical) async {
    final key = await _vault.readOrCreate();
    if (key == null || key.isEmpty) return null;
    try {
      return _mac(key, canonical);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> verify(String canonical, String seal) async {
    if (seal.isEmpty) return false;
    final key = await _vault.read();
    if (key == null || key.length < 32) return false;
    try {
      return _same(_mac(key, canonical), seal);
    } catch (_) {
      return false;
    }
  }
}

/// Test double with a fixed key; `available: false` models a keystore that
/// refuses.
class MemoryLanAuthoritySealer extends KeystoreLanAuthoritySealer {
  MemoryLanAuthoritySealer({bool available = true})
    : super(_MemoryVault(available ? OfflineIdentitySeal.newKey() : null));
}

class _MemoryVault implements OfflineSealKeyVault {
  _MemoryVault(this._key);
  final String? _key;

  @override
  Future<String?> read() async => _key;

  @override
  Future<String?> readOrCreate() async => _key;
}
