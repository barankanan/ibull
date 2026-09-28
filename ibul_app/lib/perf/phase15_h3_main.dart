import 'package:flutter/material.dart';

import '../screens/home_screen_gate.dart';
import 'phase15_app.dart';

/// Deferred gate, same shell as the direct-core variant.
void main() {
  runPhase15Home(() {
    markPhase15('phase15_gate_constructed');
    return const HomeScreenGate();
  });
}
