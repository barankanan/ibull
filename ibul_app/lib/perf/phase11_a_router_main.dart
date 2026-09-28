import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/ibul_go_router.dart';

/// Phase 11 A: production router, no Supabase.initialize.
/// Same async shell as B so the only source difference is the init call.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router),
  );
}
