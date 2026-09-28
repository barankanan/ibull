import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('above-fold home precache waits on product images in parallel', () {
    final helper =
        File('lib/core/home_above_fold_precache.dart').readAsStringSync();
    final rail = File(
      'lib/screens/home/sections/home_section_full_rail.dart',
    ).readAsStringSync();

    expect(helper, contains('Future.wait'));
    expect(helper, contains('precacheImage(provider, context)'));
    expect(rail, contains('CatalogImagePriority.forRailIndex'));
    expect(rail, isNot(contains('await precacheImage(provider, context);')));
  });

  test('consumer catalog paths do not dump getAllProducts', () {
    final pdpCards = File(
      'lib/widgets/product_detail/product_category_cards.dart',
    ).readAsStringSync();
    final market =
        File('lib/screens/market_list_page.dart').readAsStringSync();
    final spare =
        File('lib/screens/spare_parts_page.dart').readAsStringSync();
    final visual = File(
      'lib/screens/visual_intelligence_result_page.dart',
    ).readAsStringSync();

    expect(pdpCards, contains('getProductsByCategory'));
    expect(pdpCards, isNot(contains('getAllProducts()')));
    expect(market, contains('getProductsPage'));
    expect(market, isNot(contains('getAllProducts()')));
    expect(spare, contains('searchProducts'));
    expect(spare, isNot(contains('getAllProducts()')));
    expect(visual, contains('searchProducts'));
    expect(visual, isNot(contains('getAllProducts()')));
    expect(visual, isNot(contains('Duration(seconds: 2)')));
  });

  test('home rail is one deferred hop, not nested product_card load', () {
    final rail = File(
      'lib/screens/home/sections/home_section_full_rail.dart',
    ).readAsStringSync();
    final deferred = File(
      'lib/screens/home/deferred/deferred_home_full_rail_section.dart',
    ).readAsStringSync();
    final core = File('lib/screens/home_screen_core.dart').readAsStringSync();

    expect(rail, isNot(contains('deferred as product_card')));
    expect(rail, contains('ProductCard('));
    expect(deferred, contains('static Future<void> prefetchLibrary()'));
    expect(deferred, isNot(contains('SizedBox.shrink()')));
    expect(core, contains('DeferredHomeFullRailSection.prefetchLibrary()'));
    expect(core, contains('kProductsRevealDelay = Duration.zero'));
    expect(core, contains('_warmVisibleProductRatings'));
  });

  test('search and category grids keep a tight cacheExtent', () {
    final search =
        File('lib/screens/search_results_page.dart').readAsStringSync();
    final category =
        File('lib/screens/category_products_page.dart').readAsStringSync();
    expect(search, contains('cacheExtent: 280'));
    expect(search, isNot(contains('cacheExtent: 900')));
    expect(category, contains('cacheExtent: 280'));
    expect(category, isNot(contains('cacheExtent: 900')));
  });

  test('home idles prefetch of search cart and PDP without pulling map', () {
    final routes =
        File('lib/screens/home_lazy_routes.dart').readAsStringSync();
    final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
    final prefetchStart = routes.indexOf('prefetchHotPaths');
    final prefetchEnd = routes.indexOf('resetPrefetchForTests');
    expect(prefetchStart, greaterThan(0));
    expect(prefetchEnd, greaterThan(prefetchStart));
    final body = routes.substring(prefetchStart, prefetchEnd);
    expect(body, contains('search_page.loadLibrary'));
    expect(body, contains('cart_page.loadLibrary'));
    expect(body, contains('product_detail_page.loadLibrary'));
    expect(body, isNot(contains('map_page.loadLibrary')));
    expect(core, contains('HomeLazyRoutes.armPrefetchAfterInteraction()'));
    expect(routes, contains('pointerRouter.addGlobalRoute'));
    expect(core, contains('Priority.idle'));
  });

  test('release boot logs skip print except failures', () {
    final diagnostics =
        File('lib/core/runtime_diagnostic_logger.dart').readAsStringSync();
    final webPerf =
        File('lib/core/web_perf_logger.dart').readAsStringSync();
    expect(diagnostics, contains('kReleaseMode && !force'));
    expect(diagnostics, contains('force: true'));
    expect(webPerf, contains('if (kReleaseMode) return'));
  });
}
