import 'package:flutter/foundation.dart';

import '../ibul_boot_stage.dart';

const String _kIbulSupabaseUrl = String.fromEnvironment('IBUL_SUPABASE_URL');
const String _kIbulSupabaseAnonKey = String.fromEnvironment(
  'IBUL_SUPABASE_ANON_KEY',
);
const String _kIbulGoogleClientId = String.fromEnvironment(
  'IBUL_GOOGLE_CLIENT_ID',
);
const String _kIbulGoogleServerClientId = String.fromEnvironment(
  'IBUL_GOOGLE_SERVER_CLIENT_ID',
);
/// `full_installer` (web download, bundled print service) or `microsoft_store`.
const String _kIbulDistributionChannel = String.fromEnvironment(
  'IBUL_DISTRIBUTION_CHANNEL',
  defaultValue: 'full_installer',
);
const String _kIbulSellerDesktopWindowsDownloadUrl = String.fromEnvironment(
  'IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL',
  defaultValue:
      'https://github.com/barankanan/ibull/releases/download/v1.0.2-windows-seller/IbulSellerSetup.exe',
);
const String _kIbulSellerDesktopMacosDownloadUrl = String.fromEnvironment(
  'IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL',
  defaultValue:
      'https://github.com/barankanan/ibull/releases/latest/download/IbulSellerDesktop.dmg',
);
const bool _kIbulSafeBoot = bool.fromEnvironment(
  'IBUL_SAFE_BOOT',
  defaultValue: false,
);
const String _kIbulBootStage = String.fromEnvironment(
  'IBUL_BOOT_STAGE',
  defaultValue: 'normal',
);

class AppRuntimeConfig {
  static bool? _safeBootOverride;
  static IbulBootStage? _bootStageOverride;

  @visibleForTesting
  static void setSafeBootOverrideForTest(bool? value) {
    _safeBootOverride = value;
  }

  @visibleForTesting
  static void setBootStageOverrideForTest(IbulBootStage? value) {
    _bootStageOverride = value;
  }

  @visibleForTesting
  static bool parseSafeBootFlag(String? raw) {
    if (raw == null) return false;
    final normalized = raw.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  static String get rawSupabaseUrl => _kIbulSupabaseUrl;

  static String get rawSupabaseAnonKey => _kIbulSupabaseAnonKey;

  static bool get hasSupabaseConfig =>
      rawSupabaseUrl.trim().isNotEmpty && rawSupabaseAnonKey.trim().isNotEmpty;

  static String get supabaseUrl =>
      _requireEnv('IBUL_SUPABASE_URL', _kIbulSupabaseUrl);

  static String get supabaseAnonKey =>
      _requireEnv('IBUL_SUPABASE_ANON_KEY', _kIbulSupabaseAnonKey);

  static String get googleClientId =>
      _requireEnv('IBUL_GOOGLE_CLIENT_ID', _kIbulGoogleClientId);

  static String? get googleServerClientId {
    final serverClientId = _normalize(_kIbulGoogleServerClientId);
    if (serverClientId != null) return serverClientId;
    return _normalize(_kIbulGoogleClientId);
  }

  static String? get optionalGoogleClientId => _normalize(_kIbulGoogleClientId);

  /// GitHub Release download for the unified Windows seller installer (web + panel).
  static String get sellerDesktopWindowsDownloadUrl => _requireHttpUrl(
    'IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL',
    _kIbulSellerDesktopWindowsDownloadUrl,
  );

  /// Legacy name — same unified installer as [sellerDesktopWindowsDownloadUrl].
  static String get windowsInstallerDownloadUrl =>
      sellerDesktopWindowsDownloadUrl;

  static String get sellerDesktopMacosDownloadUrl => _requireHttpUrl(
    'IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL',
    _kIbulSellerDesktopMacosDownloadUrl,
  );

  /// Store builds may restrict background print service; full installer is preferred.
  static bool get isMicrosoftStoreDistribution =>
      _normalize(_kIbulDistributionChannel) == 'microsoft_store';

  static bool get isFullInstallerDistribution => !isMicrosoftStoreDistribution;

  /// Minimal web boot: bypass provider tree and heavy init.
  static bool get safeBootMode => _safeBootOverride ?? _kIbulSafeBoot;

  static IbulBootStage get bootStage =>
      _bootStageOverride ?? parseIbulBootStage(_kIbulBootStage);

  static bool get skipHomeCacheLoad => bootStage == IbulBootStage.homeNoCache;

  static String _requireEnv(String name, String value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      throw StateError(
        '$name dart-define is required. Add --dart-define=$name=...',
      );
    }
    return normalized;
  }

  static String _requireHttpUrl(String name, String value) {
    final normalized = _requireEnv(name, value);
    final uri = Uri.tryParse(normalized);
    final isValidHttpUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (!isValidHttpUrl) {
      throw StateError(
        '$name must be an absolute http/https URL. Current value: $normalized',
      );
    }
    return normalized;
  }

  static String? _normalize(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
