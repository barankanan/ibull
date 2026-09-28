import 'package:flutter/material.dart';

import '../screens/home_screen_gate.dart';
import 'phase14_router.dart';

/// H0 plus HomeScreenGate constructed as the home route.
void main() {
  final router = createPhase14Router(home: () => const HomeScreenGate());
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    ),
  );
}
