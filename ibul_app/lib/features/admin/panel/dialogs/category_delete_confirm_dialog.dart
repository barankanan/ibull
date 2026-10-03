import 'package:flutter/material.dart';

import '../../../../core/mobile_category_catalog.dart';

Future<void> showManagedCategoryDeleteConfirmDialog({
  required BuildContext context,
  required MobileCategoryNode node,
  MobileCategoryNode? parent,
  int? linkedProductCount,
  required Future<void> Function() onConfirm,
}) {
  final isMainCategory = parent == null;
  final childCount = node.subCategories.length;
  final description = isMainCategory && childCount > 0
      ? '"${node.name}" kategorisi ve bağlı $childCount alt kategori silinecek.'
      : '"${node.name}" kaydını silmek istediğinize emin misiniz?';
  final dependency = switch (linkedProductCount) {
    null => 'Bağlı ürün sayısı doğrulanamadı.',
    0 => 'Bu kategoriye bağlı ürün yok.',
    final count =>
      'Bu kategoriye bağlı $count ürün var. Ürün kayıtları değişmez; '
          'kategori pasifleşir ve müşteri menüsünden kalkar.',
  };

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kategoriyi Sil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 10),
          Text(
            dependency,
            style: TextStyle(
              fontSize: 13,
              color: (linkedProductCount ?? 1) > 0
                  ? const Color(0xFFB45309)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
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
