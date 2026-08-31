import 'package:flutter/foundation.dart';

import 'web_perf_trace.dart';

/// Release-safe web/mobile performance tracing (`print` so release Chrome shows logs).
class WebPerfLogger {
  WebPerfLogger._();

  static final int _appStartMs = DateTime.now().millisecondsSinceEpoch;
  static int? _firstFrameMs;
  static int? _homeShellMs;
  static int? _criticalProductsMs;
  static int? _deferredStartedMs;
  static int? _deferredCompletedMs;
  static int _imageWidgetsScheduled = 0;
  static int _supabaseInitialRequestCount = 0;

  static int get elapsedMs => DateTime.now().millisecondsSinceEpoch - _appStartMs;

  static void logAppStart() {
    WebPerfTrace.markOrigin();
    WebPerfTrace.instance.mark(WebPerfTraceStage.flutterBootStarted);
    _emit('app start ms=$elapsedMs');
  }

  static void logFirstFrame() {
    _firstFrameMs ??= elapsedMs;
    WebPerfTrace.instance.mark(WebPerfTraceStage.firstFrame);
    _emit('first frame ms=$_firstFrameMs');
  }

  static void logHomeShellRendered() {
    _homeShellMs ??= elapsedMs;
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeShellVisible);
    _emit('home shell rendered ms=$_homeShellMs');
  }

  static void logCriticalProductsLoaded({
    required int count,
    int? ms,
  }) {
    _criticalProductsMs = ms ?? elapsedMs;
    WebPerfTrace.instance
      ..setProductCounts(filtered: count, render: count)
      ..mark(WebPerfTraceStage.productFetchCompleted);
    _emit('critical products loaded count=$count ms=$_criticalProductsMs');
  }

  static void logDeferredSectionsStarted() {
    _deferredStartedMs ??= elapsedMs;
    _emit('deferred sections started ms=$_deferredStartedMs');
  }

  static void logDeferredSectionsCompleted() {
    _deferredCompletedMs = elapsedMs;
    WebPerfTrace.instance.markBootComplete();
    _emit('deferred sections completed ms=$_deferredCompletedMs');
  }

  static void recordImageWidgetsScheduled(int count) {
    if (count <= 0) return;
    _imageWidgetsScheduled += count;
    _emit('image widgets scheduled count=$_imageWidgetsScheduled');
  }

  static void recordSupabaseInitialRequest([int count = 1]) {
    if (count <= 0) return;
    _supabaseInitialRequestCount += count;
    if (count > 0 && _supabaseInitialRequestCount == count) {
      WebPerfTrace.instance.mark(WebPerfTraceStage.productFetchStarted);
    }
    _emit('supabase initial request count=$_supabaseInitialRequestCount');
  }

  @visibleForTesting
  static void resetForTests() {
    _firstFrameMs = null;
    _homeShellMs = null;
    _criticalProductsMs = null;
    _deferredStartedMs = null;
    _deferredCompletedMs = null;
    _imageWidgetsScheduled = 0;
    _supabaseInitialRequestCount = 0;
  }

  static void _emit(String message) {
    if (kReleaseMode) return;
    final line = '[WebPerf] $message';
    // ignore: avoid_print
    print(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }
}
