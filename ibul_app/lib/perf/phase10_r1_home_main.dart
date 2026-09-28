import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_screen_gate.dart';

/// R1: empty GoRouter plus the home gate only.
void main() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeScreenGate(),
      ),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
