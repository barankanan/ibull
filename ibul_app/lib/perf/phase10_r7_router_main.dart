import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/ibul_go_router.dart';

/// R7: production [createIbulGoRouter] without Supabase.initialize.
void main() {
  final router = createIbulGoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    includeAuthRoutes: true,
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
