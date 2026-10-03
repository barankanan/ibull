import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app/ibul_router.dart';
import '../app/marketplace_paths.dart';
import '../core/runtime_diagnostic_logger.dart';
import '../models/product_model.dart';
import 'account_page.dart' deferred as account_page;
import 'ai_chat_page.dart' deferred as ai_chat_page;
import 'business_detail_page.dart' deferred as business_detail_page;
import 'camera_page.dart' deferred as camera_page;
import 'cart_page.dart' deferred as cart_page;
import 'categories_page.dart' deferred as categories_page;
import 'compare_products_page.dart' deferred as compare_page;
import 'favorites_page.dart' deferred as favorites_page;
import 'login_page.dart' deferred as login_page;
import 'map_page.dart' deferred as map_page;
import 'product_detail_page.dart' deferred as product_detail_page;
import 'search_results_page.dart' deferred as search_page;

/// Deferred route helpers — keeps map/detail/checkout out of initial home chunk.
abstract final class HomeLazyRoutes {
  static bool _hotPrefetchStarted = false;
  static bool _interactionArmed = false;
  static bool _pointerRouteAdded = false;

  /// Web cold start must not compile search/cart/PDP/account while the home
  /// shell is still painting. Those chunks load on the first pointer event.
  /// Native keeps the previous immediate prefetch.
  static void armPrefetchAfterInteraction() {
    if (_hotPrefetchStarted || _interactionArmed) return;
    _interactionArmed = true;
    if (!kIsWeb) {
      unawaited(prefetchHotPaths());
      return;
    }
    _pointerRouteAdded = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPrefetchPointer);
  }

  static void _onPrefetchPointer(PointerEvent event) {
    if (_pointerRouteAdded) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPrefetchPointer);
      _pointerRouteAdded = false;
    }
    unawaited(prefetchHotPaths());
  }

  /// Downloads search/cart/PDP/account chunks after first paint.
  /// Sequential so hero/product images keep the network.
  static Future<void> prefetchHotPaths() async {
    if (_hotPrefetchStarted) return;
    _hotPrefetchStarted = true;
    await Future.wait<void>([
      _prefetchQuiet(search_page.loadLibrary),
      _prefetchQuiet(cart_page.loadLibrary),
      _prefetchQuiet(product_detail_page.loadLibrary),
      _prefetchQuiet(account_page.loadLibrary),
    ]);
  }

  static Future<void> _prefetchQuiet(Future<void> Function() load) async {
    try {
      await load();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[HomeLazyRoutes] prefetch failed: $error');
      }
    }
  }

  @visibleForTesting
  static void resetPrefetchForTests() {
    _hotPrefetchStarted = false;
    _interactionArmed = false;
    if (_pointerRouteAdded) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPrefetchPointer);
      _pointerRouteAdded = false;
    }
  }
  static Future<Widget> categoriesTab() async {
    await categories_page.loadLibrary();
    return categories_page.CategoriesPage();
  }

  static Future<Widget> mapTab() async {
    RuntimeDiagnosticLogger.map('[MapRoute] ACTIVE MapPage');
    await map_page.loadLibrary();
    return map_page.MapPage();
  }

  static Future<Widget> cartTab() async {
    await cart_page.loadLibrary();
    return cart_page.CartPage(usedAsTab: true);
  }

  static Future<Widget> accountTab() async {
    await account_page.loadLibrary();
    return account_page.AccountPage();
  }

  static Future<void> openSearch(BuildContext context, String query) async {
    await search_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => search_page.SearchResultsPage(query: query),
      ),
    );
  }

  static Future<void> openProductDetail(
    BuildContext context,
    Product product, {
    String? heroTag,
  }) async {
    final id = product.productId?.trim() ?? '';
    if (IbulRouter.usesRootRouter) {
      if (id.isEmpty) {
        debugPrint(
          '[Nav] product click skipped: empty productId name=${product.name}',
        );
        return;
      }
      if (!context.mounted) return;
      await IbulRouter.push(
        context,
        MarketplacePaths.product(id, slug: product.name),
        extra: product,
      );
      return;
    }
    await product_detail_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => product_detail_page.ProductDetailPage(
          product: product,
          heroTag: heroTag,
        ),
      ),
    );
  }

  static Future<void> openLogin(BuildContext context) async {
    await login_page.loadLibrary();
    if (!context.mounted) return;
    if (IbulRouter.usesRootRouter) {
      await IbulRouter.push(context, '/login');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => login_page.LoginPage(),
      ),
    );
  }

  static Future<void> openBusinessDetail(
    BuildContext context, {
    required Map<String, dynamic> business,
    bool forceTableSelection = false,
    int? initialTableNumber,
    bool fromQr = false,
    bool unverifiedQrTableFlow = false,
    List<Product>? storeProducts,
  }) async {
    await business_detail_page.loadLibrary();
    if (!context.mounted) return;
    final storeId = (business['seller_id'] ?? '').toString().trim();
    if (IbulRouter.usesRootRouter &&
        storeId.isNotEmpty &&
        !fromQr &&
        !unverifiedQrTableFlow) {
      await IbulRouter.push(
        context,
        MarketplacePaths.store(
          storeId,
          slug: business['name']?.toString(),
        ),
        extra: business,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => business_detail_page.BusinessDetailPage(
          business: business,
          forceTableSelection: forceTableSelection,
          initialTableNumber: initialTableNumber,
          fromQr: fromQr,
          unverifiedQrTableFlow: unverifiedQrTableFlow,
          storeProducts: storeProducts,
        ),
      ),
    );
  }

  static Future<void> openMap(
    BuildContext context, {
    String? query,
    String? contentType,
    String? brand,
    String? model,
  }) async {
    await map_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => map_page.MapPage(
          initialSearchQuery: query,
          contentType: contentType,
          vehicleBrand: brand,
          vehicleModel: model,
        ),
      ),
    );
  }

  static Future<void> openAccount(BuildContext context) async {
    if (IbulRouter.usesRootRouter) {
      if (IbulRouter.currentPath(context) == MarketplacePaths.account) return;
      await IbulRouter.push(context, MarketplacePaths.account);
      return;
    }
    await account_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => account_page.AccountPage(),
      ),
    );
  }

  static Future<void> openFavorites(BuildContext context) async {
    if (IbulRouter.usesRootRouter) {
      if (IbulRouter.currentPath(context) == MarketplacePaths.favorites) {
        return;
      }
      await IbulRouter.push(context, MarketplacePaths.favorites);
      return;
    }
    await favorites_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => favorites_page.FavoritesPage(),
      ),
    );
  }

  static Future<void> openCart(BuildContext context) async {
    await cart_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => cart_page.CartPage(),
      ),
    );
  }

  static Future<void> openCamera(BuildContext context) async {
    await camera_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => camera_page.CameraPage(),
      ),
    );
  }

  static Future<void> openCompare(BuildContext context) async {
    await compare_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => compare_page.CompareProductsPage(),
      ),
    );
  }

  static Future<void> openAiChat(BuildContext context) async {
    await ai_chat_page.loadLibrary();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ai_chat_page.AIChatPage(),
    );
  }
}
