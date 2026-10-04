// Manual category resolver. Not part of the test suite and not a live call.
// The previous copy imported package:ibul_app/core/env.dart, which does not exist.
// Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define if this is run by hand.

void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || anonKey.isEmpty) {
    return;
  }
}
