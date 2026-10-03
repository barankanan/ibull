import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../widgets/optimized_image.dart';
import '../widgets/system_layout_section.dart';
import 'category_edit_dialog.dart' show SystemLayoutImagePicker;

class HomeShortcutTarget {
  const HomeShortcutTarget({
    required this.key,
    required this.defaultLabel,
    required this.description,
    required this.assetPath,
  });

  final String key;
  final String defaultLabel;
  final String description;
  final String assetPath;
}

class HomeShortcutDraft {
  const HomeShortcutDraft({
    required this.targetKey,
    required this.title,
    required this.isActive,
    this.newImageBytes,
  });

  final String targetKey;
  final String title;
  final bool isActive;
  final Uint8List? newImageBytes;
}

/// Kısayol ekleme/düzenleme. Kayıt başarısız olursa diyalog açık kalır ve
/// girilen bilgiler korunur.
Future<void> showHomeShortcutEditDialog({
  required BuildContext context,
  required List<HomeShortcutTarget> targets,
  required HomeShortcutTarget initialTarget,
  String? initialTitle,
  String? imageUrl,
  bool initialActive = true,
  bool isNew = false,
  required int titleMaxLength,
  required SystemLayoutImagePicker onPickAndCropImage,
  required Future<bool> Function(HomeShortcutDraft draft) onSave,
}) async {
  final titleController = TextEditingController(
    text: initialTitle ?? initialTarget.defaultLabel,
  );
  var target = initialTarget;
  var isActive = initialActive;
  Uint8List? selectedImage;
  var isSaving = false;
  String? validation;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            final title = titleController.text.trim();
            if (title.isEmpty) {
              setDialogState(() => validation = 'Başlık boş olamaz.');
              return;
            }
            if (!targets.any((t) => t.key == target.key)) {
              setDialogState(() => validation = 'Geçerli bir hedef seçin.');
              return;
            }
            setDialogState(() {
              validation = null;
              isSaving = true;
            });
            final ok = await onSave(
              HomeShortcutDraft(
                targetKey: target.key,
                title: title,
                isActive: isActive,
                newImageBytes: selectedImage,
              ),
            );
            if (!dialogContext.mounted) return;
            if (ok) {
              Navigator.pop(dialogContext);
            } else {
              setDialogState(() => isSaving = false);
            }
          }

          return AlertDialog(
            backgroundColor: SystemLayoutColors.surface,
            title: Text(isNew ? 'Yeni Kısayol' : 'Kısayolu Düzenle'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                    setDialogState(() => selectedImage = bytes);
                                  }
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SystemLayoutColors.border,
                              ),
                              color: SystemLayoutColors.accentSoft,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: selectedImage != null
                                ? Image.memory(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : (imageUrl ?? '').isNotEmpty
                                ? OptimizedImage(
                                    imageUrlOrPath: imageUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    target.assetPath,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Görsel 512×512 (1:1) kırpılır. Görsel seçilmezse '
                            'uygulamadaki varsayılan simge kullanılır.',
                            style: TextStyle(
                              fontSize: 12,
                              color: SystemLayoutColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: target.key,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hedef',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final t in targets)
                          DropdownMenuItem(
                            value: t.key,
                            child: Text(
                              '${t.defaultLabel} — ${t.description}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: !isNew || isSaving
                          ? null
                          : (key) => setDialogState(() {
                              target = targets.firstWhere((t) => t.key == key);
                              if (titleController.text.trim().isEmpty) {
                                titleController.text = target.defaultLabel;
                              }
                            }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      maxLength: titleMaxLength,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: SystemLayoutColors.accent,
                      title: const Text('Aktif'),
                      subtitle: const Text(
                        'Pasif kısayol mobil ana sayfada “Yakında” olarak görünür.',
                      ),
                      onChanged: isSaving
                          ? null
                          : (value) => setDialogState(() => isActive = value),
                    ),
                    if (validation != null)
                      Text(
                        validation!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              FilledButton.icon(
                onPressed: isSaving ? null : submit,
                style: systemLayoutPrimaryButtonStyle(),
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(isSaving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    titleController.dispose();
  }
}
