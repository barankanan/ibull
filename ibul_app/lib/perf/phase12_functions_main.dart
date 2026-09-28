import 'package:flutter/material.dart';
import 'package:functions_client/functions_client.dart';
import 'package:go_router/go_router.dart';

import '../app/ibul_go_router.dart';

/// Functions client constructed on the production router.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final functions = FunctionsClient(
    'https://example.supabase.co/functions/v1',
    const {'apikey': 'test-anon-key'},
  );
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: functions.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
