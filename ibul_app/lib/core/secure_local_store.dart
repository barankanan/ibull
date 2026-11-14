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

  /// Existing production seller sessions. Do not rename.
  static const sellerMacOsSecureAccount = 'flutter_secure_storage_service';

  /// Customer macOS app. Distinct from the seller account and the LAN test.
  static const customerMacOsSecureAccount = 'ibul.customer';

  /// Matches `offlineTestKeychainAccount`. Selected only for offline-test builds.
  static const offlineTestMacOsSecureAccount = 'ibul.sellerdesktop.offlinetest';

  static String macOsAccountName = const bool.fromEnvironment('IBUL_OFFLINE_TEST')
      ? offlineTestMacOsSecureAccount
      : sellerMacOsSecureAccount;

  static FlutterSecureStorage? _opened;

  /// v10 migrates Jetpack EncryptedSharedPreferences into the custom cipher
  /// on first access. [encryptedSharedPreferences] is ignored by the plugin
  /// and kept so this call site records the v9 storage backend.
  /// [resetOnError] stays false so a failed read does not wipe existing keys.
  static FlutterSecureStorage get _storage {
    return _opened ??= FlutterSecureStorage(
      aOptions: const AndroidOptions(
        // ignore: deprecated_member_use
        encryptedSharedPreferences: true,
        resetOnError: false,
        migrateOnAlgorithmChange: true,
        migrateWithBackup: true,
      ),
      mOptions: MacOsOptions(accountName: macOsAccountName),
    );
  }

  /// Points later Keychain writes at the customer account.
  ///
  /// The seller desktop entry does not call this, so its existing account
  /// stays in place. An offline-test build keeps its own account.
  static void useCustomerMacOsAccount() {
    if (const bool.fromEnvironment('IBUL_OFFLINE_TEST')) return;
    if (_opened != null && macOsAccountName != customerMacOsSecureAccount) {
      throw StateError(
        'Secure store already opened with $macOsAccountName',
      );
    }
    macOsAccountName = customerMacOsSecureAccount;
  }

  Future<String?> readString(String key) async {
    try {
      final secureValue = await _storage.read(key: key);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (error) {
      _logSecureStorageFailure('read', key, error);
    }
    final legacy = await _migrateLegacySharedPreference(key);
    if (legacy == null || legacy.isEmpty) return legacy;
    try {
      await _storage.write(key: key, value: legacy);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (error) {
      _logSecureStorageFailure('migrate', key, error);
    }
    return legacy;
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

  /// Stores a private key in the platform keystore. A failed write does not
  /// fall back to SharedPreferences.
  Future<bool> writeSecret(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (error) {
      _logSecureStorageFailure('secret-write', key, error);
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    return true;
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
