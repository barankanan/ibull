import 'dart:async';

import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:ibul_app/screens/home_screen_deferred_entry.dart' deferred as home_entry;

import '../core/perf_debug_config.dart';
import '../core/web_boot_error_store.dart';
import '../core/web_boot_trace.dart';
import '../core/web_perf_trace.dart';
import '../widgets/web_perf_debug_panel.dart';
import 'home/home_initial_page.dart';

/// Defers the heavy home module; shows [WebHomeShell] until loaded or on failure.
class HomeScreenGate extends StatefulWidget {
  const HomeScreenGate({
    super.key,
    this.initialIndex = 0,
    this.initialCategory,
    this.initialSearchQuery,
  });

  final int initialIndex;
  final String? initialCategory;
  final String? initialSearchQuery;

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
    }).catchError((Object error, StackTrace stackTrace) {
      // Chunk yüklenemedi — hata izlenebilir ve yeniden fırlatılarak
      // çağıran (DeferredModuleScreen retry / test) doğru şekilde bilgilendirilir.
      debugPrint('[HomeScreenGate] deferred chunk load failed: $error');
      saveWebBootError(
        module: 'home_screen_gate',
        message: 'Deferred home chunk load failed: $error',
        detail: stackTrace.toString(),
      );
      Error.throwWithStackTrace(error, stackTrace);
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: HomeInitialPage(
            initialIndex: widget.initialIndex,
            initialCategory: widget.initialCategory,
            initialSearchQuery: widget.initialSearchQuery,
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
