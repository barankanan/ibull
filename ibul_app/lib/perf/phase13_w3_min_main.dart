import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'phase13_boot.dart';

/// Wrapper with empty storage, no deeplink, no auto-refresh, no shared prefs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  mark('phase13_init_start');
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('IBUL_SUPABASE_URL'),
      anonKey: const String.fromEnvironment('IBUL_SUPABASE_ANON_KEY'),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        pkceAsyncStorage: PerfMemoryPkce(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  } catch (_) {}
  mark('phase13_init_return');
  watchAuthAfterReturn();
  await bootRouter('w3');
}
