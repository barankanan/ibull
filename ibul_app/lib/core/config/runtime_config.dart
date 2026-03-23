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

class AppRuntimeConfig {
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

  static String _requireEnv(String name, String value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      throw StateError(
        '$name dart-define is required. Add --dart-define=$name=...',
      );
    }
    return normalized;
  }

  static String? _normalize(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
