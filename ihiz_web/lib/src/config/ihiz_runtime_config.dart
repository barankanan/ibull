const String _kIhizSupabaseUrl = String.fromEnvironment('IHIZ_SUPABASE_URL');
const String _kIhizSupabaseAnonKey = String.fromEnvironment(
  'IHIZ_SUPABASE_ANON_KEY',
);

class IhizRuntimeConfig {
  static String get supabaseUrl =>
      _requireEnv('IHIZ_SUPABASE_URL', _kIhizSupabaseUrl);

  static String get supabaseAnonKey =>
      _requireEnv('IHIZ_SUPABASE_ANON_KEY', _kIhizSupabaseAnonKey);

  static String _requireEnv(String name, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw StateError(
        '$name dart-define is required. Add --dart-define=$name=...',
      );
    }
    return normalized;
  }
}
