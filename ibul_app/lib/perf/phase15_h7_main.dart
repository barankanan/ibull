import 'package:flutter/material.dart';

import '../screens/home_screen_deferred_entry.dart' deferred as home_entry;
import '../widgets/deferred_module_screen.dart';
import 'phase15_app.dart';

/// Real home library load. Does not construct HomeScreenCore.
void main() {
  runPhase15Home(() {
    markPhase15('phase15_gate_constructed');
    return DeferredModuleScreen(
      moduleName: 'home_screen_deferred_entry',
      loadLibrary: () {
        markPhase15('phase15_load_start');
        return home_entry.loadLibrary().whenComplete(
          () => markPhase15('phase15_load_complete'),
        );
      },
      loading: const Text('loading'),
      builder: () {
        // Keep the real library in the deferred graph without constructing it.
        final Object loaded = home_entry.buildDeferredHomeScreen;
        return Text('home loaded ${loaded.runtimeType}');
      },
    );
  });
}
