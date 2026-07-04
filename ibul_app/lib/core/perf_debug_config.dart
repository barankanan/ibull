import 'package:flutter/foundation.dart';

import 'perf_debug_config_stub.dart'
    if (dart.library.html) 'perf_debug_config_web.dart' as impl;

/// Whether on-screen perf/boot debug panels are shown.
///
/// Default: debug builds only. Production: enable via `?debugBoot=1` or `?perf=1`.
bool get perfDebugPanelEnabled => impl.perfDebugPanelEnabled(kDebugMode);
