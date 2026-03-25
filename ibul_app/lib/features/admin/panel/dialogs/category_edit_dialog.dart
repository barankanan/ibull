import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../../../../core/mobile_category_catalog.dart';
import '../widgets/system_layout_managed_category_widgets.dart';

typedef SystemLayoutImagePicker =
    Future<Uint8List?> Function({
      required double ratioX,
      required double ratioY,
      required double suggestedWidth,
    });

Future<void> showManagedCategoryEditDialog({
  required BuildContext context,
  MobileCategoryNode? existing,
  MobileCategoryNode? parent,
  required int initialOrderIndex,
  required SystemLayoutImagePicker onPickAndCropImage,
  required Future<bool> Function({
    required MobileCategoryNode draft,
    MobileCategoryNode? parent,
    Uint8List? newImageBytes,
  })
  onSave,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final orderController = TextEditingController(
    text: (existing?.orderIndex ?? initialOrderIndex).toString(),
  );
  var isActive = existing?.isActive ?? true;
  Uint8List? selectedImage;
  var isSaving = false;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? (parent == null ? 'Yeni Kategori' : 'Yeni Alt Kategori')
                  : (parent == null
                        ? 'Kategori Düzenle'
                        : 'Alt Kategori Düzenle'),
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: isSaving
                        ? null
                        : () async {
                            final bytes = await onPickAndCropImage(
                              ratioX: 1,
                              ratioY: 1,
                              suggestedWidth: 512,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                selectedImage = bytes;
                              });
                            }
                          },
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD8C8FF)),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: selectedImage != null
                          ? Image.memory(selectedImage!, fit: BoxFit.cover)
                          : ManagedCategoryImage(
                              imageUrl: existing?.imageUrl,
                              fallbackAssetPath: existing?.fallbackAssetPath,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '512x512 kare görsel önerilir. Görsel seçtiğinizde aynı oranda kırpma alanı açılır.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: parent == null
                          ? 'Kategori Adı'
                          : 'Alt Kategori Adı',
                      border: const OutlineInputBorder(),
                      hintText: parent == null
                          ? 'Kategori adını yazın'
                          : 'Alt kategori adını yazın',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sıra',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    activeThumbColor: const Color(0xFF8B5CF6),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                  ),
                  if (parent != null)
                    Text(
                      'Üst kategori: ${parent.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final orderIndex =
                            int.tryParse(orderController.text.trim()) ??
                            existing?.orderIndex ??
                            1;
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kategori adı boş bırakılamaz.'),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                        });

                        try {
                          final saved = await onSave(
                            draft: MobileCategoryNode(
                              id: existing?.id,
                              parentId: existing?.parentId ?? parent?.id,
                              name: name,
                              imageUrl: existing?.imageUrl,
                              iconName: existing?.iconName ?? parent?.iconName,
                              fallbackAssetPath: existing?.fallbackAssetPath,
                              orderIndex: orderIndex,
                              isActive: isActive,
                              subCategories:
                                  existing?.subCategories ?? const [],
                            ),
                            parent: parent,
                            newImageBytes: selectedImage,
                          );
                          if (!context.mounted ||
                              !saved ||
                              !dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    nameController.dispose();
    orderController.dispose();
  }
}

Future<void> showAppCategoryEditDialog({
  required BuildContext context,
  required Map<String, dynamic> category,
  required int categoryNameMaxLength,
  required SystemLayoutImagePicker onPickAndCropImage,
  required Future<void> Function({
    Uint8List? newImageBytes,
    String? newDisplayName,
  })
  onSave,
}) async {
  final currentName = category['display_name']?.toString() ?? '';
  final nameController = TextEditingController(text: currentName);
  Uint8List? selectedImage;
  var isSaving = false;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final remaining = categoryNameMaxLength - nameController.text.length;
          final imageUrl = category['image_url']?.toString();

          return AlertDialog(
            title: const Text('Kategori Düzenle'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: isSaving
                        ? null
                        : () async {
                            final bytes = await onPickAndCropImage(
                              ratioX: 1,
                              ratioY: 1,
                              suggestedWidth: 512,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                selectedImage = bytes;
                              });
                            }
                          },
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8C8FF)),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: selectedImage != null
                          ? Image.memory(selectedImage!, fit: BoxFit.cover)
                          : (imageUrl != null && imageUrl.isNotEmpty)
                          ? OptimizedImage(imageUrlOrPath: imageUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    maxLength: categoryNameMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Kart Adı',
                      hintText: 'Kategori adı girin',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  Text(
                    '$remaining karakter kaldı',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kategori adı boş olamaz.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() {
                          isSaving = true;
                        });
                        await onSave(
                          newImageBytes: selectedImage,
                          newDisplayName: newName,
                        );
                        if (!context.mounted || !dialogContext.mounted) {
                          return;
                        }
                        Navigator.pop(dialogContext);
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    nameController.dispose();
  }
}
