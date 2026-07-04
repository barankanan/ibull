import 'runtime_diagnostic_logger.dart';

/// Release-safe home UI data-source diagnostics.
abstract final class HomeUiDiagnostics {
  static void demoDataDisabled() {
    RuntimeDiagnosticLogger.home('[HomeUI] demo data disabled');
  }

  static void realProducts({required int count, required String source}) {
    RuntimeDiagnosticLogger.home(
      '[HomeUI] using $source products count=$count',
    );
  }

  static void cacheProducts({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeUI] using cache products count=$count');
  }

  static void noProductsEmptyState() {
    RuntimeDiagnosticLogger.home('[HomeUI] no products, showing empty state');
  }

  static void realAds({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeUI] rendering real ad count=$count');
  }

  static void noAdsHidden() {
    RuntimeDiagnosticLogger.home('[HomeUI] no ads, hiding ad section');
  }

  static void realBanners({required int count}) {
    RuntimeDiagnosticLogger.home('[HomeUI] rendering real banner count=$count');
  }

  static void noBannersHidden() {
    RuntimeDiagnosticLogger.home('[HomeUI] no banners, hiding hero section');
  }

  static void realProductCard({required int count}) {
    RuntimeDiagnosticLogger.home(
      '[HomeCard] renderer=real_product_card count=$count',
    );
  }
}
