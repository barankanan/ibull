import 'runtime_diagnostic_logger.dart';

/// Throttled release-safe home product/ad fetch diagnostics.
abstract final class HomeDataDiagnostics {
  static int _lastSuccessLogMs = 0;
  static int _lastFilterLogMs = 0;

  static void requestStart({required String source}) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] product request start source=$source',
    );
  }

  static void requestSuccess({
    required int count,
    required String source,
    int? ms,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSuccessLogMs < 1500) return;
    _lastSuccessLogMs = now;
    final timing = ms == null ? '' : ' ms=$ms';
    RuntimeDiagnosticLogger.home(
      '[HomeData] product request success count=$count source=$source$timing',
    );
  }

  static void requestError({required String error}) {
    RuntimeDiagnosticLogger.home('[HomeData] product request error=$error');
  }

  static void rawRows({required int count, required String source}) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] raw rows count=$count source=$source',
    );
  }

  static void afterVisibilityFilter({required int count}) {
    _logFilterStep('[HomeData] after visibility filter count=$count');
  }

  static void afterApprovalFilter({required int count}) {
    _logFilterStep('[HomeData] after approval filter count=$count');
  }

  static void afterImageResolve({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] after image resolve count=$count',
    );
  }

  static void afterParse({
    required int successCount,
    required int failCount,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] after parse success=$successCount fail=$failCount',
    );
  }

  static void firstProduct({
    required String id,
    required String title,
    required String storeId,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] first product id=$id title=$title store_id=$storeId',
    );
  }

  static void renderingProducts({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeData] rendering products count=$count');
  }

  static void approvalFilterRetry({
    required int rawCount,
    required int activeCount,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] approval projection dropped rows raw=$rawCount active=$activeCount retry=catalog_select',
    );
  }

  static void _logFilterStep(String message) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFilterLogMs < 800) return;
    _lastFilterLogMs = now;
    RuntimeDiagnosticLogger.home(message);
  }

  static void resetForTests() {
    _lastSuccessLogMs = 0;
    _lastFilterLogMs = 0;
  }
}

/// Throttled release-safe home ad fetch diagnostics.
abstract final class HomeAdsDiagnostics {
    static void requestStart({required String source}) {
    RuntimeDiagnosticLogger.home('[HomeAds] request start source=$source');
  }

  static void rawCount({required int count, required String source}) {
    RuntimeDiagnosticLogger.home('[HomeAds] raw count=$count source=$source');
  }

  static void activeCount({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] active count=$count');
  }

  static void rendered({
    required int count,
    required String placement,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] rendered count=$count placement=$placement',
    );
  }

  static void hidden({required String reason}) {
    RuntimeDiagnosticLogger.home('[HomeAds] hidden reason=$reason');
  }

  static void demoDisabled() {
    RuntimeDiagnosticLogger.home('[HomeAds] demo disabled');
  }

  static void heroRequestStart() {
    RuntimeDiagnosticLogger.home('[HomeAds] hero request start');
  }

  static void heroRaw({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] hero raw count=$count');
  }

  static void heroActive({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] hero active count=$count');
  }

  static void heroRendered({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] hero rendered count=$count');
  }

  static void heroHidden({required String reason}) {
    RuntimeDiagnosticLogger.home('[HomeAds] hero hidden reason=$reason');
  }

  static void sponsoredRequestStart({required String source}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] sponsored request start source=$source',
    );
  }

  static void sponsoredAfterPlacementFilter({
    required int count,
    required String placement,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] sponsored after placement filter count=$count placement=$placement',
    );
  }

  static void sponsoredAfterDateFilter({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] sponsored after date filter count=$count',
    );
  }

  static void sponsoredAfterApprovalFilter({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] sponsored after approval filter count=$count',
    );
  }

  static void sponsoredRendered({
    required int count,
    required String widget,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] sponsored rendered count=$count widget=$widget',
    );
  }

  static void sponsoredHidden({required String reason}) {
    RuntimeDiagnosticLogger.home('[HomeAds] sponsored hidden reason=$reason');
  }

  static void featureRaw({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] feature raw count=$count');
  }

  static void featureRendered({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] feature rendered count=$count');
  }

  static void heroBanners({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] source=hero_banners count=$count',
    );
  }

  static void sponsoredContent({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] source=home_sponsored count=$count',
    );
    RuntimeDiagnosticLogger.home('[HomeAds] sponsored rendered count=$count');
  }

  static void sponsoredRaw({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] sponsored raw count=$count');
  }

  static void sponsoredHydration({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] sponsored hydration count=$count');
  }

  static void sponsoredRpcFallback({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeAds] sponsored rpc fallback count=$count');
  }

  static void featureAds({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] source=home_feature_ads count=$count',
    );
  }

  static void sectionHidden({required String source}) {
    RuntimeDiagnosticLogger.home(
      '[HomeAds] no ads, section hidden source=$source',
    );
  }
}

/// Store detail / map diagnostics for cross-pipeline comparison.
abstract final class StoreDetailDataDiagnostics {
  static void products({required int count, String source = 'store_detail'}) {
    RuntimeDiagnosticLogger.home(
      '[StoreDetailData] products count=$count source=$source',
    );
  }
}

abstract final class MapDataDiagnostics {
  static void stores({required int count}) {
    RuntimeDiagnosticLogger.home('[MapData] stores count=$count');
  }
}

/// Throttled home skeleton visibility diagnostics.
abstract final class HomeSkeletonDiagnostics {
  static void show({required String source, required String reason}) {
    RuntimeDiagnosticLogger.home(
      '[HomeSkeleton] show source=$source reason=$reason',
    );
  }

  static void hide({required String source, required String reason}) {
    RuntimeDiagnosticLogger.home(
      '[HomeSkeleton] hide source=$source reason=$reason',
    );
  }

  static void timeout({required String source}) {
    RuntimeDiagnosticLogger.home('[HomeSkeleton] timeout source=$source');
  }

  static void stillVisible({required String source, required String reason}) {
    RuntimeDiagnosticLogger.home(
      '[HomeSkeleton] still_visible source=$source reason=$reason',
    );
  }
}

/// Home layout routing diagnostics (desktop vs mobile).
abstract final class HomeLayoutDiagnostics {
  static int _lastLogMs = 0;

  static void log({
    required String platform,
    required double width,
    required String mode,
    required String widget,
    required bool mobileDesignActive,
    bool legacyDemoSectionDisabled = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLogMs < 1200) return;
    _lastLogMs = now;
    RuntimeDiagnosticLogger.home(
      '[HomeLayout] platform=$platform width=${width.toStringAsFixed(0)} '
      'mode=$mode widget=$widget mobile design active=$mobileDesignActive '
      'mobile legacy demo section disabled=$legacyDemoSectionDisabled',
    );
  }
}

/// Section-level state logging for home deferred blocks.
abstract final class HomeSectionDiagnostics {
  static void state({
    required String section,
    required String state,
    int count = 0,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeSection] state=$state section=$section count=$count',
    );
  }

  static void loading({required String section}) {
    state(section: section, state: 'loading');
  }

  static void render({required String section, required int itemCount}) {
    RuntimeDiagnosticLogger.home(
      '[HomeSection] render section=$section itemCount=$itemCount',
    );
  }

  static void hidden({
    required String section,
    required String reason,
  }) {
    RuntimeDiagnosticLogger.home(
      '[HomeSection] hidden section=$section reason=$reason',
    );
  }
}
