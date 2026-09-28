import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:realtime_client/realtime_client.dart';

import '../app/ibul_go_router.dart';

/// Realtime client constructed. [connect] is not called.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final realtime = RealtimeClient('https://example.supabase.co/realtime/v1');
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: realtime.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
