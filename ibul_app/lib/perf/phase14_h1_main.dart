import 'package:flutter/material.dart';

import '../screens/home_screen_gate.dart';
import 'phase14_router.dart';

/// H0 plus HomeScreenGate retained and not built.
void main() {
  final Object retained = HomeScreenGate.new;
  final router = createPhase14Router(home: () => const Text('home'));
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: retained.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
