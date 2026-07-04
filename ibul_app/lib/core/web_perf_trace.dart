import 'package:flutter/foundation.dart';

import 'web_perf_trace_stub.dart'
    if (dart.library.html) 'web_perf_trace_web.dart' as impl;

/// Unified web cold-start performance stages (`ibul_web_perf_trace_v1`).
abstract final class WebPerfTraceStage {
  static const appScriptStarted = 'app_script_started';
  static const flutterBootStarted = 'flutter_boot_started';
  static const firstFrame = 'first_frame';
  static const homeShellVisible = 'home_shell_visible';
  static const homeDeferredLoadStarted = 'home_deferred_load_started';
  static const homeDeferredLoadCompleted = 'home_deferred_load_completed';
  static const homeFirstBuildStarted = 'home_first_build_started';
  static const homeFirstFrame = 'home_first_frame';
  static const productFetchStarted = 'product_fetch_started';
  static const productFetchCompleted = 'product_fetch_completed';
  static const firstProductCardRendered = 'first_product_card_rendered';
  static const productGridFirstBatchRendered = 'product_grid_first_batch_rendered';
  static const productGridAllVisibleRendered = 'product_grid_all_visible_rendered';
  static const imageFirstLoaded = 'image_first_loaded';
  static const bootComplete = 'boot_complete';
  static const homeCoreChunkLoaded = 'home_core_chunk_loaded';
  static const previewProductsFetch = 'preview_products_fetch';
  static const firstPreviewCardRendered = 'first_preview_card_rendered';
  static const deferredHeroLoaded = 'deferred_hero_loaded';
  static const deferredCampaignLoaded = 'deferred_campaign_loaded';
  static const fullGridLoaded = 'full_grid_loaded';
  static const fullRailLoadStarted = 'full_rail_load_started';
  static const fullRailLoadCompleted = 'full_rail_load_completed';
  static const fullRailLoadError = 'full_rail_load_error';
  static const fullRailRenderStarted = 'full_rail_render_started';
  static const fullRailRenderCompleted = 'full_rail_render_completed';
}

class WebPerfTraceSnapshot {
  const WebPerfTraceSnapshot({
    required this.stage,
    required this.elapsedMs,
    this.mainJsBytes,
    this.productRawCount,
    this.productFilteredCount,
    this.productRenderCount,
    this.firstProductRenderMs,
    this.homeCoreChunkLoadedMs,
    this.previewProductsFetchMs,
    this.firstPreviewCardRenderedMs,
    this.deferredHeroLoadedMs,
    this.deferredCampaignLoadedMs,
    this.fullGridLoadedMs,
    this.fullRailLoadCompletedMs,
    this.fullRailRenderCompletedMs,
    this.lastError,
    this.timestamp,
  });

  final String stage;
  final int elapsedMs;
  final int? mainJsBytes;
  final int? productRawCount;
  final int? productFilteredCount;
  final int? productRenderCount;
  final int? firstProductRenderMs;
  final int? homeCoreChunkLoadedMs;
  final int? previewProductsFetchMs;
  final int? firstPreviewCardRenderedMs;
  final int? deferredHeroLoadedMs;
  final int? deferredCampaignLoadedMs;
  final int? fullGridLoadedMs;
  final int? fullRailLoadCompletedMs;
  final int? fullRailRenderCompletedMs;
  final String? lastError;
  final String? timestamp;

  WebPerfTraceSnapshot copyWith({
    String? stage,
    int? elapsedMs,
    int? mainJsBytes,
    int? productRawCount,
    int? productFilteredCount,
    int? productRenderCount,
    int? firstProductRenderMs,
    int? homeCoreChunkLoadedMs,
    int? previewProductsFetchMs,
    int? firstPreviewCardRenderedMs,
    int? deferredHeroLoadedMs,
    int? deferredCampaignLoadedMs,
    int? fullGridLoadedMs,
    int? fullRailLoadCompletedMs,
    int? fullRailRenderCompletedMs,
    String? lastError,
    String? timestamp,
    bool clearError = false,
  }) {
    return WebPerfTraceSnapshot(
      stage: stage ?? this.stage,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      mainJsBytes: mainJsBytes ?? this.mainJsBytes,
      productRawCount: productRawCount ?? this.productRawCount,
      productFilteredCount: productFilteredCount ?? this.productFilteredCount,
      productRenderCount: productRenderCount ?? this.productRenderCount,
      firstProductRenderMs: firstProductRenderMs ?? this.firstProductRenderMs,
      homeCoreChunkLoadedMs:
          homeCoreChunkLoadedMs ?? this.homeCoreChunkLoadedMs,
      previewProductsFetchMs:
          previewProductsFetchMs ?? this.previewProductsFetchMs,
      firstPreviewCardRenderedMs:
          firstPreviewCardRenderedMs ?? this.firstPreviewCardRenderedMs,
      deferredHeroLoadedMs: deferredHeroLoadedMs ?? this.deferredHeroLoadedMs,
      deferredCampaignLoadedMs:
          deferredCampaignLoadedMs ?? this.deferredCampaignLoadedMs,
      fullGridLoadedMs: fullGridLoadedMs ?? this.fullGridLoadedMs,
      fullRailLoadCompletedMs:
          fullRailLoadCompletedMs ?? this.fullRailLoadCompletedMs,
      fullRailRenderCompletedMs:
          fullRailRenderCompletedMs ?? this.fullRailRenderCompletedMs,
      lastError: clearError ? null : (lastError ?? this.lastError),
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'elapsedMs': elapsedMs,
        'total_boot_elapsed_ms': elapsedMs,
        if (mainJsBytes != null) 'mainJsBytes': mainJsBytes,
        if (productRawCount != null) 'productRawCount': productRawCount,
        if (productFilteredCount != null) 'productFilteredCount': productFilteredCount,
        if (productRenderCount != null) 'productRenderCount': productRenderCount,
        if (firstProductRenderMs != null) 'firstProductRenderMs': firstProductRenderMs,
        if (homeCoreChunkLoadedMs != null)
          'home_core_chunk_loaded_ms': homeCoreChunkLoadedMs,
        if (previewProductsFetchMs != null)
          'preview_products_fetch_ms': previewProductsFetchMs,
        if (firstPreviewCardRenderedMs != null)
          'first_preview_card_rendered_ms': firstPreviewCardRenderedMs,
        if (deferredHeroLoadedMs != null)
          'deferred_hero_loaded_ms': deferredHeroLoadedMs,
        if (deferredCampaignLoadedMs != null)
          'deferred_campaign_loaded_ms': deferredCampaignLoadedMs,
        if (fullGridLoadedMs != null) 'full_grid_loaded_ms': fullGridLoadedMs,
        if (fullRailLoadCompletedMs != null)
          'full_rail_load_completed_ms': fullRailLoadCompletedMs,
        if (fullRailRenderCompletedMs != null)
          'full_rail_render_completed_ms': fullRailRenderCompletedMs,
        'lastError': lastError,
        if (timestamp != null) 'timestamp': timestamp,
      };
}

/// Singleton perf trace for web first paint; persists to localStorage on web.
class WebPerfTrace {
  WebPerfTrace._();

  static final WebPerfTrace instance = WebPerfTrace._();

  static int? _originMs;

  static int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  static int get elapsedMs {
    final origin = _originMs ?? _nowMs;
    return _nowMs - origin;
  }

  WebPerfTraceSnapshot _snapshot = WebPerfTraceSnapshot(
    stage: WebPerfTraceStage.appScriptStarted,
    elapsedMs: 0,
  );

  bool _firstProductCardLogged = false;
  bool _firstBatchLogged = false;
  bool _imageFirstLogged = false;

  WebPerfTraceSnapshot get snapshot => _snapshot;

  @visibleForTesting
  static void resetForTests() {
    _originMs = null;
    instance._snapshot = WebPerfTraceSnapshot(
      stage: WebPerfTraceStage.appScriptStarted,
      elapsedMs: 0,
    );
    instance._firstProductCardLogged = false;
    instance._firstBatchLogged = false;
    instance._imageFirstLogged = false;
  }

  static void markOrigin() {
    _originMs ??= _nowMs;
  }

  void mark(String stage, {String? error, bool clearError = false}) {
    markOrigin();
    final ms = elapsedMs;
    _snapshot = _snapshot.copyWith(
      stage: stage,
      elapsedMs: ms,
      homeCoreChunkLoadedMs: stage == WebPerfTraceStage.homeCoreChunkLoaded
          ? ms
          : _snapshot.homeCoreChunkLoadedMs,
      previewProductsFetchMs: stage == WebPerfTraceStage.previewProductsFetch
          ? ms
          : _snapshot.previewProductsFetchMs,
      firstPreviewCardRenderedMs:
          stage == WebPerfTraceStage.firstPreviewCardRendered
              ? ms
              : _snapshot.firstPreviewCardRenderedMs,
      deferredHeroLoadedMs: stage == WebPerfTraceStage.deferredHeroLoaded
          ? ms
          : _snapshot.deferredHeroLoadedMs,
      deferredCampaignLoadedMs:
          stage == WebPerfTraceStage.deferredCampaignLoaded
              ? ms
              : _snapshot.deferredCampaignLoadedMs,
      fullGridLoadedMs: stage == WebPerfTraceStage.fullGridLoaded
          ? ms
          : _snapshot.fullGridLoadedMs,
      fullRailLoadCompletedMs:
          stage == WebPerfTraceStage.fullRailLoadCompleted
              ? ms
              : _snapshot.fullRailLoadCompletedMs,
      fullRailRenderCompletedMs:
          stage == WebPerfTraceStage.fullRailRenderCompleted
              ? ms
              : _snapshot.fullRailRenderCompletedMs,
      lastError: error,
      clearError: clearError && error == null,
      timestamp: DateTime.now().toIso8601String(),
    );
    impl.persistWebPerfTrace(_snapshot);
    // ignore: avoid_print
    print('[WebPerfTrace][$stage] ${ms}ms');
  }

  void setMainJsBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return;
    markOrigin();
    _snapshot = _snapshot.copyWith(
      mainJsBytes: bytes,
      elapsedMs: elapsedMs,
      timestamp: DateTime.now().toIso8601String(),
    );
    impl.persistWebPerfTrace(_snapshot);
  }

  void setProductCounts({
    int? raw,
    int? filtered,
    int? render,
  }) {
    markOrigin();
    _snapshot = _snapshot.copyWith(
      productRawCount: raw ?? _snapshot.productRawCount,
      productFilteredCount: filtered ?? _snapshot.productFilteredCount,
      productRenderCount: render ?? _snapshot.productRenderCount,
      elapsedMs: elapsedMs,
      timestamp: DateTime.now().toIso8601String(),
    );
    impl.persistWebPerfTrace(_snapshot);
  }

  void markFirstProductCardRendered() {
    if (_firstProductCardLogged) return;
    _firstProductCardLogged = true;
    final ms = elapsedMs;
    _snapshot = _snapshot.copyWith(
      stage: WebPerfTraceStage.firstProductCardRendered,
      firstProductRenderMs: ms,
      elapsedMs: ms,
      timestamp: DateTime.now().toIso8601String(),
    );
    impl.persistWebPerfTrace(_snapshot);
    // ignore: avoid_print
    print('[WebPerfTrace][first_product_card_rendered] ${ms}ms');
  }

  void markProductGridFirstBatch({required int count}) {
    if (_firstBatchLogged) return;
    _firstBatchLogged = true;
    setProductCounts(render: count);
    mark(WebPerfTraceStage.productGridFirstBatchRendered);
  }

  void markImageFirstLoaded() {
    if (_imageFirstLogged) return;
    _imageFirstLogged = true;
    mark(WebPerfTraceStage.imageFirstLoaded);
  }

  void markBootComplete() {
    mark(WebPerfTraceStage.bootComplete);
  }

  void setError(String error) {
    mark(_snapshot.stage, error: error);
  }
}

String? readWebPerfTraceJson() => impl.readWebPerfTraceJson();

void clearWebPerfTrace() => impl.clearWebPerfTrace();
