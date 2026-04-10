import 'package:flutter/material.dart';
import 'package:ibul_app/core/constants.dart';

import 'bulk_product_upload_modal.dart';

class BulkProductUploadButton extends StatelessWidget {
  const BulkProductUploadButton({
    super.key,
    this.isCompact = false,
    this.outlined = true,
    this.onImportCompleted,
  });

  final bool isCompact;
  final bool outlined;
  final VoidCallback? onImportCompleted;

  Future<void> _handlePressed(BuildContext context) async {
    final bool? result = await BulkProductUploadModal.show(context);
    if (!context.mounted || result != true) {
      return;
    }
    onImportCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Widget icon = const Icon(Icons.file_upload_outlined, size: 18);
    final Widget label = Text(isCompact ? 'Toplu' : 'Toplu Yükle');

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
