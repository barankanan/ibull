import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/ibul_go_router.dart';

/// Phase 11 C: initialize tear-off is reachable, but never called.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Object retained = Supabase.initialize;
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: retained.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
