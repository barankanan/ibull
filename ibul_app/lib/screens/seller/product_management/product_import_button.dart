import 'package:flutter/material.dart';

import 'product_import_center_modal.dart';

/// Satıcı paneli "Ürünlerim" ekranı için "Siteden Ürün Getir" aksiyon butonu
class ProductImportButton extends StatelessWidget {
  const ProductImportButton({
    super.key,
    this.isCompact = false,
    this.outlined = true,
    this.onImportCompleted,
  });

  final bool isCompact;
  final bool outlined;
  final VoidCallback? onImportCompleted;

  Future<void> _handlePressed(BuildContext context) async {
    final bool? result = await ProductImportCenterModal.show(context);
    if (!context.mounted || result != true) {
      return;
    }
    onImportCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.cloud_download_outlined, size: 18);
    final label = Text(isCompact ? 'Siteden Getir' : 'Siteden Ürün Getir');

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: () => _handlePressed(context),
        icon: icon,
        label: label,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F766E), // İBUL Teal Primary
          side: BorderSide(color: const Color(0xFF0F766E).withValues(alpha: 0.24)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _handlePressed(context),
      icon: icon,
      label: label,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
