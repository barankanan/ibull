import 'package:flutter/widgets.dart';

import 'home_screen_core.dart';

/// Stable deferred entry — lean home core (sections deferred inside chunk).
Widget buildDeferredHomeScreen({
  int initialIndex = 0,
  String? initialCategory,
}) {
  return HomeScreenCore(
    initialIndex: initialIndex,
    initialCategory: initialCategory,
  );
}
