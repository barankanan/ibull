import 'package:flutter/material.dart';

import '../screens/home_screen_core.dart';
import 'phase14_router.dart';

/// H0 plus HomeScreenCore retained and not built.
void main() {
  final Object retained = HomeScreenCore.new;
  final router = createPhase14Router(home: () => const Text('home'));
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: retained.runtimeType.toString(),
      routerConfig: router,
    ),
  );
}
