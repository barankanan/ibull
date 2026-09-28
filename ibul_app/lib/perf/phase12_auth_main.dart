import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gotrue/gotrue.dart';

import '../app/ibul_go_router.dart';

/// Auth subsystem constructed on the production router. No Supabase.initialize.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = GoTrueClient(url: 'https://example.supabase.co/auth/v1');
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: auth.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
