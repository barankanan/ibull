import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Binds the saved offline identity to this device and this account.
///
/// The record itself may sit in a plain settings file. Its seal is an
/// HMAC-SHA256 over every field that grants access, keyed with a random
/// secret that exists only in this device's keystore. An edited record, a
/// record copied from another device, or a record without a seal does not
/// verify and is treated as if the account was never verified here.
///
/// No server key is involved: the seal proves "this device wrote this after
/// an online check", nothing more.
class OfflineIdentitySeal {
  const OfflineIdentitySeal._();

  static const int version = 1;

  /// Keystore entry holding the device secret.
  static const String keyName = 'ibul.offline_identity.seal_key.v1';

  static String newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Stable text of the fields the seal covers. Lists are sorted so the
  /// order in which permissions were saved does not matter.
  static String canonical(Map<String, dynamic> record) {
    String text(Object? value) => value?.toString().trim() ?? '';
    String list(Object? value) {
      if (value is! Iterable) return '~';
      final items = value.map((item) => item.toString()).toList()..sort();
      return jsonEncode(items);
    }

    return <String>[
      'v$version',
      text(record['auth_user_id']),
      text(record['owner_id']),
      text(record['store_name']),
      text(record['store_category']),
      record['is_owner'] == true ? 'owner' : 'staff',
      text(record['saved_at']),
      text(record['last_seen_at']),
      text(record['staff_role']),
      list(record['permissions']),
      list(record['visible_modules']),
      text(record['job_title']),
    ].map(jsonEncode).join('|');
  }

  static String sign(String keyBase64, Map<String, dynamic> record) {
    final key = base64Decode(keyBase64);
    return Hmac(sha256, key).convert(utf8.encode(canonical(record))).toString();
  }

  static bool verify(String keyBase64, Map<String, dynamic> record) {
    final given = record['seal']?.toString() ?? '';
    if (given.isEmpty || record['seal_v'] != version) return false;
    final List<int> key;
    try {
      key = base64Decode(keyBase64);
    } catch (_) {
      return false;
    }
    if (key.length < 32) return false;
    final expected = sign(keyBase64, record);
    if (expected.length != given.length) return false;
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected.codeUnitAt(index) ^ given.codeUnitAt(index);
    }
    return difference == 0;
  }
}

/// Where the device secret lives. The production vault is the platform
/// keystore; it never falls back to a plain settings file.
abstract class OfflineSealKeyVault {
  /// The existing secret, or null when there is none or the keystore
  /// cannot be read.
  Future<String?> read();

  /// The existing secret, or a new one stored now. Null when the keystore
  /// refuses the write: then nothing may be sealed on this device.
  Future<String?> readOrCreate();
}
