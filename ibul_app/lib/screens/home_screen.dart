import 'package:flutter/material.dart';

import 'home_screen_gate.dart';

/// Navigation-compat wrapper — does not import [HomeScreenCore] (deferred only).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.initialIndex = 0, this.initialCategory});

  final int initialIndex;
  final String? initialCategory;

  @override
  Widget build(BuildContext context) {
    return HomeScreenGate(
      initialIndex: initialIndex,
      initialCategory: initialCategory,
    );
  }
}
