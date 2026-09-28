import 'package:flutter/material.dart';

import 'phase14_router.dart';

/// Production routes, home body is a placeholder, no HomeScreenGate import.
void main() {
  final router = createPhase14Router(home: () => const Text('home'));
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: phase14ProductType.toString(),
      routerConfig: router,
    ),
  );
}
