import 'package:flutter/material.dart';

import '../screens/home_screen_core.dart';
import 'phase15_app.dart';

/// Direct core. Same providers, theme, locale, and router as H3.
void main() {
  runPhase15Home(() {
    markPhase15('phase15_core_constructed');
    return const HomeScreenCore();
  });
}
