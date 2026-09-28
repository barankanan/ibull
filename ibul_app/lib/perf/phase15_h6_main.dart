import 'package:flutter/material.dart';

import '../widgets/deferred_module_screen.dart';
import 'phase15_app.dart';
import 'phase15_tiny_home.dart' deferred as tiny;

/// Same deferred loader, tiny library.
void main() {
  runPhase15Home(() {
    markPhase15('phase15_gate_constructed');
    return DeferredModuleScreen(
      moduleName: 'phase15_tiny',
      loadLibrary: () {
        markPhase15('phase15_load_start');
        return tiny.loadLibrary().whenComplete(
          () => markPhase15('phase15_load_complete'),
        );
      },
      loading: const Text('loading'),
      builder: () => tiny.buildTinyDeferredHome(),
    );
  });
}
