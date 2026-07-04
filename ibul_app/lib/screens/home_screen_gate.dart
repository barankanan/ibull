import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ibul_app/screens/home_screen_deferred_entry.dart' deferred as home_entry;

import '../core/perf_debug_config.dart';
import '../core/web_boot_trace.dart';
import '../core/web_perf_trace.dart';
import '../widgets/deferred_module_screen.dart';
import '../widgets/web_perf_debug_panel.dart';
import 'web_home_boot_shell.dart';

/// Defers the heavy home module; shows [WebHomeShell] until loaded or on failure.
class HomeScreenGate extends StatefulWidget {
  const HomeScreenGate({super.key, this.initialIndex = 0, this.initialCategory});

  final int initialIndex;
  final String? initialCategory;

  static const String moduleName = 'home_screen_deferred_entry';

  /// Start downloading the home chunk as early as possible (web cold start).
  static void prefetch() {
    // ignore: discarded_futures
    home_entry.loadLibrary();
  }

  @override
  State<HomeScreenGate> createState() => _HomeScreenGateState();
}

class _HomeScreenGateState extends State<HomeScreenGate> {
  late final WebBootTraceNotifier _trace =
      WebBootTraceNotifier(module: HomeScreenGate.moduleName);
  Timer? _shellTicker;

  @override
  void initState() {
    super.initState();
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeShellVisible);
    _trace.setStage(WebBootTraceStage.shellStarted);
    _shellTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _trace.isComplete) return;
      _trace.tickElapsed();
    });
  }

  @override
  void dispose() {
    _shellTicker?.cancel();
    super.dispose();
  }

  Widget _buildDeferredHome() {
    _trace.setStage(WebBootTraceStage.deferredFactoryStarted);
    try {
      final homeWidget = home_entry.buildDeferredHomeScreen(
        initialIndex: widget.initialIndex,
        initialCategory: widget.initialCategory,
      );
      _trace.setStage(WebBootTraceStage.deferredFactoryCompleted);
      _trace.setStage(WebBootTraceStage.homeCoreWidgetCreated);
      return homeWidget;
    } catch (error, stack) {
      _trace.setStage(WebBootTraceStage.deferredFactoryError);
      _trace.setError('$error');
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DeferredModuleScreen(
            moduleName: HomeScreenGate.moduleName,
            loadLibrary: home_entry.loadLibrary,
            timeout: const Duration(seconds: 90),
            trace: _trace,
            loading: const WebHomeShell(),
            builder: _buildDeferredHome,
          ),
        ),
        ListenableBuilder(
          listenable: _trace,
          builder: (context, _) => WebPerfDebugPanel(
            bootSnapshot: _trace.snapshot,
            visible: perfDebugPanelEnabled && !_trace.isComplete,
          ),
        ),
      ],
    );
  }
}
