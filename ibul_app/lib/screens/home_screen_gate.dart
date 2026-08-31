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

  static bool _moduleReady = false;

  /// Deferred home chunk daha önce başarıyla yüklendiyse `true`.
  ///
  /// Senkron okunabilmesi kritik: `loadLibrary()` her zaman bir Future döner ve
  /// `.then()` en erken microtask'ta çalışır, dolayısıyla [DeferredModuleScreen]
  /// ilk build'inde modülün hazır olduğunu ASLA öğrenemez — modül dakikalardır
  /// yüklü olsa bile bir kare boyunca [WebHomeShell] build/layout/paint edilir.
  /// Bu bayrak o kareyi atlamayı mümkün kılıyor.
  static bool get isModuleReady => _moduleReady;

  /// Deferred home modülünü yükler ve başarıda [isModuleReady]'i işaretler.
  ///
  /// `loadLibrary()` Dart tarafında zaten idempotent (tekrar çağrılar aynı
  /// yüklemeyi paylaşır, başarıdan sonra anında tamamlanır), bu yüzden Future
  /// ayrıca cache'lenmiyor — hata sonrası retry doğal olarak yeniden dener.
  static Future<void> loadModule() {
    return home_entry.loadLibrary().then((_) {
      _moduleReady = true;
    });
  }

  /// Start downloading the home chunk as early as possible (web cold start).
  static void prefetch() {
    unawaited(loadModule());
  }

  @override
  State<HomeScreenGate> createState() => _HomeScreenGateState();
}

class _HomeScreenGateState extends State<HomeScreenGate> {
  late final WebBootTraceNotifier _trace =
      WebBootTraceNotifier(module: HomeScreenGate.moduleName);

  @override
  void initState() {
    super.initState();
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeShellVisible);
    _trace.setStage(WebBootTraceStage.shellStarted);
    // Elapsed ticker kasıtlı olarak yok: aşağıdaki DeferredModuleScreen'e
    // `trace: _trace` veriliyor ve o widget aynı notifier için zaten 1 sn'lik
    // Timer.periodic başlatıyordu. İki timer aynı `tickElapsed()`i çağırıyor,
    // web cold-boot'un en kritik penceresinde işi ikiye katlıyordu.
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
            loadLibrary: HomeScreenGate.loadModule,
            timeout: const Duration(seconds: 90),
            trace: _trace,
            // Modül hazırsa shell hiç kurulmasın: home route'u her
            // navigasyonda yeniden mount olduğu için (buildSafeHome →
            // MaterialApp.home / '/home' / onGenerateRoute) modül çoktan
            // yüklüyken bile bir kare WebHomeShell çiziliyordu.
            isAlreadyLoaded: HomeScreenGate.isModuleReady,
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
