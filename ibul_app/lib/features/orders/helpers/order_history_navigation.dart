import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../models/product_model.dart';
import '../../../screens/product_detail_page.dart';
import '../services/order_history_service.dart';

class OrderHistoryNavigation {
  const OrderHistoryNavigation._();

  static Future<void> openOrderHistoryProductDetail(
    BuildContext context,
    Map<String, dynamic> item, {
    String failureMessage = 'Ürün şu anda görüntülenemiyor.',
  }) async {
    Product? product;
    try {
      product = await OrderHistoryService.instance.resolveProductForNavigation(
        item,
      );
    } catch (e, stackTrace) {
      debugPrint('openOrderHistoryProductDetail resolve failed: $e\n$stackTrace');
    }

    if (!context.mounted) return;

    if (product == null || !OrderHistoryService.isNavigableProduct(product)) {
      _showFailureSnackBar(context, failureMessage);
      return;
    }

    try {
      await Navigator.of(context).push(
        buildAppPageRoute(
          builder: (routeContext) => ProductDetailPage(product: product!),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('openOrderHistoryProductDetail push failed: $e\n$stackTrace');
      if (!context.mounted) return;
      _showFailureSnackBar(context, failureMessage);
    }
  }

  static Future<void> openProductDetail(
    BuildContext context,
    Map<String, dynamic> item, {
    String notFoundMessage = 'Ürün sayfası açılamadı.',
  }) {
    return openOrderHistoryProductDetail(
      context,
      item,
      failureMessage: notFoundMessage,
    );
  }

  static Future<void> openProductForReorder(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    return openOrderHistoryProductDetail(
      context,
      item,
      failureMessage: 'Ürün şu anda görüntülenemiyor.',
    );
  }

  static void _showFailureSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
