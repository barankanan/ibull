import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../app/ibul_router.dart';
import '../app/marketplace_paths.dart';
import '../core/app_state.dart';
import '../models/product_model.dart';
import '../screens/business_detail_page.dart' deferred as business_detail_page;
import '../screens/cart_page.dart' deferred as cart_page;
import '../screens/login_page.dart' deferred as login_page;
import '../screens/product_detail_page.dart' deferred as product_detail_page;

/// Tap navigation for a product card.
///
/// Web uses the existing router. Page libraries load only when a non-router
/// host still needs an imperative page.
abstract final class ProductCardLinks {
  static Future<void> openProductDetail(
    BuildContext context,
    Product product, {
    String? heroTag,
  }) async {
    final id = product.productId?.trim() ?? '';
    if (context.mounted) {
      context.read<AppState>().addRecentlyViewedProduct(product);
    }
    if (IbulRouter.usesRootRouter) {
      if (id.isEmpty) return;
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
      MaterialPageRoute<void>(builder: (_) => login_page.LoginPage()),
    );
  }

  static Future<void> openCart(BuildContext context) async {
    if (IbulRouter.usesRootRouter) {
      if (!context.mounted) return;
      await IbulRouter.push<void>(context, '/sepet');
      return;
    }
    await cart_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => cart_page.CartPage()),
    );
  }

  static Future<void> openBusinessDetail(
    BuildContext context, {
    required Map<String, dynamic> business,
    bool forceTableSelection = false,
    List<Product>? storeProducts,
  }) async {
    await business_detail_page.loadLibrary();
    if (!context.mounted) return;
    final storeId = (business['seller_id'] ?? '').toString().trim();
    if (IbulRouter.usesRootRouter && storeId.isNotEmpty) {
      await IbulRouter.push(
        context,
        MarketplacePaths.store(storeId, slug: business['name']?.toString()),
        extra: business,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => business_detail_page.BusinessDetailPage(
          business: business,
          forceTableSelection: forceTableSelection,
          storeProducts: storeProducts,
        ),
      ),
    );
  }
}
