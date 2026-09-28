import '../screens/home_screen_gate.dart';
import 'phase15_app.dart';

/// Phase 16 candidate on the same router shell as Phase 15 H3.
void main() {
  runPhase15Home(() {
    markPhase15('phase15_gate_constructed');
    return const HomeScreenGate();
  });
}
