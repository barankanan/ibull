import 'package:flutter/material.dart';

import '../app/shared_app_widgets.dart';
import 'phase14_router.dart';

/// H0 plus the real buildSafeHome wrapper.
void main() {
  final router = createPhase14Router(
    home: () => buildSafeHome(source: 'phase14-h2'),
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    ),
  );
}
