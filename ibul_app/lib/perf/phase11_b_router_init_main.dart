import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/ibul_go_router.dart';

/// Phase 11 B: same router as A, plus Supabase.initialize.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  html.window.performance.mark('phase11_supabase_init_start');
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('IBUL_SUPABASE_URL'),
      anonKey: const String.fromEnvironment('IBUL_SUPABASE_ANON_KEY'),
    );
    html.window.performance.mark('phase11_supabase_init_return');
  } catch (_) {
    html.window.performance.mark('phase11_supabase_init_return');
  }
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router),
  );
}
