import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/shared_app_widgets.dart';

/// R8: GoRouter plus the home bootstrap wrapper the route table calls.
void main() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => buildSafeHome(source: 'phase10-r8'),
      ),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
