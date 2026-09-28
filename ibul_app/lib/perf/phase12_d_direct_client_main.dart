import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase/supabase.dart';

import '../app/ibul_go_router.dart';

/// D: production router plus a direct [SupabaseClient], no flutter wrapper.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
  );
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: client.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
