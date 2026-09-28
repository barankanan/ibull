import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/ibul_go_router.dart';

/// In-memory PKCE store. Avoids [SharedPreferencesGotrueAsyncStorage].
class PerfMemoryPkce extends GotrueAsyncStorage {
  const PerfMemoryPkce();

  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> setItem({required String key, required String value}) async {}

  @override
  Future<void> removeItem({required String key}) async {}
}

void mark(String name) => html.window.performance.mark(name);

Future<void> bootRouter(String title) async {
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: title,
      routerConfig: router,
    ),
  );
}

/// Listens after initialize returns. The initial session event is emitted
/// inside initialize, so this records only a later event.
void watchAuthAfterReturn() {
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    mark('phase13_auth_${state.event.name}');
  });
}
