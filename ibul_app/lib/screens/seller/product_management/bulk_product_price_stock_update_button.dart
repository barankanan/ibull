import 'package:flutter/material.dart';
import 'package:ibul_app/core/constants.dart';

import 'bulk_product_price_stock_update_modal.dart';

class BulkProductPriceStockUpdateButton extends StatelessWidget {
  const BulkProductPriceStockUpdateButton({
    super.key,
    this.outlined = true,
    this.onUpdateCompleted,
  });

  final bool outlined;
  final VoidCallback? onUpdateCompleted;

  Future<void> _handlePressed(BuildContext context) async {
    final bool? result = await BulkProductPriceStockUpdateModal.show(context);
    if (!context.mounted || result != true) {
      return;
    }
    onUpdateCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    const Widget icon = Icon(Icons.price_change_outlined, size: 18);
    const Widget label = Text('Toplu Güncelle');

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: () => _handlePressed(context),
        icon: icon,
        label: label,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.24)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _handlePressed(context),
      icon: icon,
      label: label,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}
