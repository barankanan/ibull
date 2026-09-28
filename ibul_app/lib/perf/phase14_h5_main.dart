import 'package:flutter/material.dart';

import '../screens/home_screen_core.dart';
import 'phase14_router.dart';

/// H0 plus HomeScreenCore built on the home route.
void main() {
  final router = createPhase14Router(home: () => const HomeScreenCore());
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    ),
  );
}
