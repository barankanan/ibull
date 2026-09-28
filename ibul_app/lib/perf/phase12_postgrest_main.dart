import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:postgrest/postgrest.dart';

import '../app/ibul_go_router.dart';

/// PostgREST client constructed on the production router.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final rest = PostgrestClient('https://example.supabase.co/rest/v1');
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: rest.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
