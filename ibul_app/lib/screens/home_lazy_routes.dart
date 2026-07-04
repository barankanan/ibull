import 'package:flutter/material.dart';

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
    return cart_page.CartPage();
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

  static Future<void> openMap(BuildContext context) async {
    await map_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => map_page.MapPage(),
      ),
    );
  }

  static Future<void> openAccount(BuildContext context) async {
    await account_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => account_page.AccountPage(),
      ),
    );
  }

  static Future<void> openFavorites(BuildContext context) async {
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
