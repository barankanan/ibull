import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_route_table.dart';

/// R9: the production route table, dispatched with a runtime path.
void main() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final path = state.uri.path;
          return pageForAppRoute(
                path,
                settings: RouteSettings(name: path, arguments: state.extra),
                includeAuthRoutes: true,
              ) ??
              const SizedBox.shrink();
        },
      ),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
