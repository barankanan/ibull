import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:storage_client/storage_client.dart';

import '../app/ibul_go_router.dart';

/// Storage constructor retained and not called.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Object retained = SupabaseStorageClient.new;
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
