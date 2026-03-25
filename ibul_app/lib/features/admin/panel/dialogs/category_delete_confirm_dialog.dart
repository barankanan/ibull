import 'package:flutter/material.dart';

import '../../../../core/mobile_category_catalog.dart';

Future<void> showManagedCategoryDeleteConfirmDialog({
  required BuildContext context,
  required MobileCategoryNode node,
  MobileCategoryNode? parent,
  required Future<void> Function() onConfirm,
}) {
  final isMainCategory = parent == null;
  final childCount = node.subCategories.length;
  final description = isMainCategory && childCount > 0
      ? '"${node.name}" kategorisi ve bağlı $childCount alt kategori silinecek.'
      : '"${node.name}" kaydını silmek istediğinize emin misiniz?';

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kategoriyi Sil'),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            await onConfirm();
          },
          child: const Text('Sil', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
