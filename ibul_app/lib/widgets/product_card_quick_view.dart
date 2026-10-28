import 'package:flutter/material.dart';

import '../core/app_motion.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import 'ecommerce_product_quick_info_sheet.dart';

/// Full product row for quick view. Loaded only after the eye icon is tapped.
Future<Product?> enrichQuickViewProduct(Product product) async {
  final id = product.productId?.trim() ?? '';
  if (id.isEmpty) return null;
  final row = await SupabaseService.instance.getProductByIdString(id);
  return row == null ? null : Product.fromDBProduct(row);
}

Future<void> showProductCardQuickView({
  required BuildContext context,
  required Product product,
  required VoidCallback onAddToCart,
  required VoidCallback onViewDetails,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    isScrollControlled: true,
    builder: (sheetContext) {
      return EcommerceProductQuickInfoSheet(
        product: product,
        enrich: () => enrichQuickViewProduct(product),
        onAddToCart: onAddToCart,
        onViewDetails: onViewDetails,
      );
    },
  );
}
