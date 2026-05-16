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
const String _kIbulWindowsInstallerDownloadUrl = String.fromEnvironment(
  'IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL',
  defaultValue:
      'https://ibul-ecommerce.web.app/downloads/IbulPrintBridgeSetup.exe',
);
const String _kIbulSellerDesktopWindowsDownloadUrl = String.fromEnvironment(
  'IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL',
  defaultValue:
      'https://github.com/barankanan/ibull/releases/latest/download/IbulSellerDesktopSetup.exe',
);
const String _kIbulSellerDesktopMacosDownloadUrl = String.fromEnvironment(
  'IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL',
  defaultValue:
      'https://github.com/barankanan/ibull/releases/latest/download/IbulSellerDesktop.dmg',
);

class AppRuntimeConfig {
  static String get rawSupabaseUrl => _kIbulSupabaseUrl;

  static String get rawSupabaseAnonKey => _kIbulSupabaseAnonKey;

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

  static String get windowsInstallerDownloadUrl => _requireHttpUrl(
    'IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL',
    _kIbulWindowsInstallerDownloadUrl,
  );

  static String get sellerDesktopWindowsDownloadUrl => _requireHttpUrl(
    'IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL',
    _kIbulSellerDesktopWindowsDownloadUrl,
  );

  static String get sellerDesktopMacosDownloadUrl => _requireHttpUrl(
    'IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL',
    _kIbulSellerDesktopMacosDownloadUrl,
  );

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
