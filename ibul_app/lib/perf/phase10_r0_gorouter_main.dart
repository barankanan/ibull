import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// R0: Material plus an empty GoRouter. No IBUL route table.
void main() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('r0'),
      ),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
