import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists sensitive local payloads outside SharedPreferences.
///
/// On macOS/desktop builds without Keychain entitlements, secure storage calls
/// can fail with `errSecMissingEntitlement` (-34018). Those failures fall back
/// to SharedPreferences so auth/session flows (e.g. seller login cleanup) keep
/// working instead of throwing unhandled platform errors.
class SecureLocalStore {
  SecureLocalStore._();

  static final SecureLocalStore instance = SecureLocalStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readString(String key) async {
    try {
      final secureValue = await _storage.read(key: key);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (error) {
      _logSecureStorageFailure('read', key, error);
    }
    return _migrateLegacySharedPreference(key);
  }

  Future<void> writeString(String key, String value) async {
    var wroteSecure = false;
    try {
      await _storage.write(key: key, value: value);
      wroteSecure = true;
    } catch (error) {
      _logSecureStorageFailure('write', key, error);
    }

    final prefs = await SharedPreferences.getInstance();
    if (wroteSecure) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value);
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (error) {
      _logSecureStorageFailure('delete', key, error);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  void _logSecureStorageFailure(String operation, String key, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[SecureLocalStore] $operation failed key=$key error=$error '
      '(falling back to SharedPreferences where applicable)',
    );
  }

  Future<dynamic> readJson(String key) async {
    final raw = await readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, dynamic value) async {
    await writeString(key, jsonEncode(value));
  }

  Future<String?> _migrateLegacySharedPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    try {
      await _storage.write(key: key, value: legacy);
      await prefs.remove(key);
      if (kDebugMode) {
        debugPrint('[SecureLocalStore] migrated legacy key=$key');
      }
    } catch (error) {
      _logSecureStorageFailure('migrate-write', key, error);
    }
    return legacy;
  }
}
