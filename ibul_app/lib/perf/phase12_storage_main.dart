import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:storage_client/storage_client.dart';

import '../app/ibul_go_router.dart';

/// Storage client constructed. No upload, so MIME lookup is not called.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SupabaseStorageClient(
    'https://example.supabase.co/storage/v1',
    const {'apikey': 'test-anon-key'},
  );
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: storage.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
