import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../widgets/image_cropper_widget.dart';
import 'category_edit_dialog.dart';

class CampaignImageDialogSaveRequest {
  const CampaignImageDialogSaveRequest({
    required this.existingImage,
    required this.newDesktopBytes,
    required this.newMobileBytes,
    required this.desktopImagePath,
    required this.mobileImagePath,
    required this.title,
    required this.altText,
    required this.linkUrl,
    required this.isActive,
  });

  final Map<String, dynamic>? existingImage;
  final Uint8List? newDesktopBytes;
  final Uint8List? newMobileBytes;
  final String? desktopImagePath;
  final String? mobileImagePath;
  final String title;
  final String altText;
  final String linkUrl;
  final bool isActive;
}

Future<Uint8List?> pickAndCropSystemLayoutImageBytes({
  required BuildContext context,
  required double ratioX,
  required double ratioY,
  required double suggestedWidth,
}) async {
  try {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );

    if (image == null) {
      return null;
    }

    final imageBytes = await image.readAsBytes();
    Uint8List? croppedBytes;

    if (!context.mounted) {
      return null;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => ImageCropperWidget(
        imageData: imageBytes,
        aspectRatio: ratioX / ratioY,
        suggestedWidth: suggestedWidth,
        onCropped: (croppedData) {
          croppedBytes = croppedData;
        },
      ),
    );

    return croppedBytes;
  } catch (e) {
    debugPrint('Error picking/cropping image: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Görsel yükleme hatası: $e')));
    }
    return null;
  }
}

Future<void> showSystemLayoutDeleteConfirmDialog({
  required BuildContext context,
  required Future<void> Function() onConfirm,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Silinsin mi?'),
      content: const Text(
        'Bu kart tasarımını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await onConfirm();
          },
          child: const Text('Sil', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

Future<void> showCampaignImageDeleteConfirmDialog({
  required BuildContext context,
  required Future<void> Function() onConfirm,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Görseli Sil'),
      content: const Text('Bu görseli silmek istediğinizden emin misiniz?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () async {
            Navigator.pop(dialogContext);
            await onConfirm();
          },
          child: const Text('Sil'),
        ),
      ],
    ),
  );
}

Future<void> showCampaignImageDetailsDialog({
  required BuildContext context,
  Map<String, dynamic>? existingImage,
  required SystemLayoutImagePicker onPickAndCropImage,
  required Future<bool> Function(CampaignImageDialogSaveRequest request) onSave,
  VoidCallback? onSaved,
}) async {
  final titleController = TextEditingController(text: existingImage?['title']);
  final altTextController = TextEditingController(
    text: existingImage?['alt_text'],
  );
  final linkUrlController = TextEditingController(
    text: existingImage?['link_url'],
  );
  var isActive = existingImage?['is_active'] ?? true;
  Uint8List? newDesktopBytes;
  Uint8List? newMobileBytes;
  String? desktopImagePath = existingImage?['image_path'];
  String? mobileImagePath = existingImage?['mobile_image_path'];
  var isSaving = false;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isWebOrLargeScreen =
              MediaQuery.of(dialogContext).size.width > 900;

          return AlertDialog(
            title: Text(
              existingImage == null
                  ? 'Yeni Kampanya Görseli'
                  : 'Görseli Düzenle',
            ),
            insetPadding: const EdgeInsets.all(24),
            contentPadding: const EdgeInsets.all(24),
            scrollable: true,
            content: SizedBox(
              width: isWebOrLargeScreen ? 900 : 400,
              child: isWebOrLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Masaüstü Görseli (996x412)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _CampaignImagePicker(
                                isSaving: isSaving,
                                height: 140,
                                label: 'Masaüstü Görseli Yükle',
                                imageBytes: newDesktopBytes,
                                imagePath: desktopImagePath,
                                onTap: () async {
                                  final bytes = await onPickAndCropImage(
                                    ratioX: 996,
                                    ratioY: 412,
                                    suggestedWidth: 996,
                                  );
                                  if (bytes != null) {
                                    setDialogState(() {
                                      newDesktopBytes = bytes;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Mobil Görseli (768x400)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _CampaignImagePicker(
                                isSaving: isSaving,
                                height: 140,
                                label: 'Mobil Görseli Yükle',
                                imageBytes: newMobileBytes,
                                imagePath: mobileImagePath,
                                onTap: () async {
                                  final bytes = await onPickAndCropImage(
                                    ratioX: 768,
                                    ratioY: 400,
                                    suggestedWidth: 800,
                                  );
                                  if (bytes != null) {
                                    setDialogState(() {
                                      newMobileBytes = bytes;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 4,
                          child: _CampaignImageFormFields(
                            titleController: titleController,
                            altTextController: altTextController,
                            linkUrlController: linkUrlController,
                            isActive: isActive,
                            isSaving: isSaving,
                            paddedProgress: true,
                            onActiveChanged: (val) {
                              setDialogState(() {
                                isActive = val;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Masaüstü Görseli (996x412)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _CampaignImagePicker(
                          isSaving: isSaving,
                          height: 120,
                          label: 'Masaüstü Görseli Yükle',
                          imageBytes: newDesktopBytes,
                          imagePath: desktopImagePath,
                          compactPlaceholder: true,
                          onTap: () async {
                            final bytes = await onPickAndCropImage(
                              ratioX: 996,
                              ratioY: 412,
                              suggestedWidth: 996,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                newDesktopBytes = bytes;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mobil Görseli (768x400)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _CampaignImagePicker(
                          isSaving: isSaving,
                          height: 120,
                          label: 'Mobil Görseli Yükle',
                          imageBytes: newMobileBytes,
                          imagePath: mobileImagePath,
                          compactPlaceholder: true,
                          onTap: () async {
                            final bytes = await onPickAndCropImage(
                              ratioX: 768,
                              ratioY: 400,
                              suggestedWidth: 800,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                newMobileBytes = bytes;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _CampaignImageFormFields(
                          titleController: titleController,
                          altTextController: altTextController,
                          linkUrlController: linkUrlController,
                          isActive: isActive,
                          isSaving: isSaving,
                          paddedProgress: false,
                          onActiveChanged: (val) {
                            setDialogState(() {
                              isActive = val;
                            });
                          },
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if ((existingImage == null &&
                                newDesktopBytes == null) &&
                            (desktopImagePath == null ||
                                desktopImagePath.isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen en az bir masaüstü görseli yükleyin.',
                              ),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                        });

                        final saved = await onSave(
                          CampaignImageDialogSaveRequest(
                            existingImage: existingImage,
                            newDesktopBytes: newDesktopBytes,
                            newMobileBytes: newMobileBytes,
                            desktopImagePath: desktopImagePath,
                            mobileImagePath: mobileImagePath,
                            title: titleController.text,
                            altText: altTextController.text,
                            linkUrl: linkUrlController.text,
                            isActive: isActive,
                          ),
                        );
                        if (!saved) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                          return;
                        }
                        if (!context.mounted || !dialogContext.mounted) {
                          return;
                        }
                        Navigator.pop(dialogContext);
                        onSaved?.call();
                      },
                child: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    titleController.dispose();
    altTextController.dispose();
    linkUrlController.dispose();
  }
}

class _CampaignImagePicker extends StatelessWidget {
  const _CampaignImagePicker({
    required this.isSaving,
    required this.height,
    required this.label,
    required this.imageBytes,
    required this.imagePath,
    required this.onTap,
    this.compactPlaceholder = false,
  });

  final bool isSaving;
  final double height;
  final String label;
  final Uint8List? imageBytes;
  final String? imagePath;
  final Future<void> Function() onTap;
  final bool compactPlaceholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSaving ? null : () => onTap(),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade100,
        ),
        clipBehavior: Clip.antiAlias,
        child: imageBytes != null
            ? Image.memory(imageBytes!, fit: BoxFit.cover)
            : (imagePath != null && imagePath!.isNotEmpty)
            ? OptimizedImage(imageUrlOrPath: imagePath!, fit: BoxFit.cover)
            : compactPlaceholder
            ? const Center(child: Icon(Icons.add_a_photo, color: Colors.grey))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo, color: Colors.grey, size: 32),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: Colors.grey)),
                ],
              ),
      ),
    );
  }
}

class _CampaignImageFormFields extends StatelessWidget {
  const _CampaignImageFormFields({
    required this.titleController,
    required this.altTextController,
    required this.linkUrlController,
    required this.isActive,
    required this.isSaving,
    required this.onActiveChanged,
    required this.paddedProgress,
  });

  final TextEditingController titleController;
  final TextEditingController altTextController;
  final TextEditingController linkUrlController;
  final bool isActive;
  final bool isSaving;
  final ValueChanged<bool> onActiveChanged;
  final bool paddedProgress;

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            border: OutlineInputBorder(),
          ),
          enabled: !isSaving,
        ),
        SizedBox(height: paddedProgress ? 16 : 12),
        TextField(
          controller: altTextController,
          decoration: const InputDecoration(
            labelText: 'Alt Metin',
            border: OutlineInputBorder(),
          ),
          enabled: !isSaving,
        ),
        SizedBox(height: paddedProgress ? 16 : 12),
        TextField(
          controller: linkUrlController,
          decoration: const InputDecoration(
            labelText: 'Yönlendirme Linki',
            border: OutlineInputBorder(),
          ),
          enabled: !isSaving,
        ),
        SizedBox(height: paddedProgress ? 16 : 8),
        paddedProgress
            ? Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: isSaving ? null : onActiveChanged,
                ),
              )
            : SwitchListTile(
                title: const Text('Aktif'),
                value: isActive,
                contentPadding: EdgeInsets.zero,
                onChanged: isSaving ? null : onActiveChanged,
              ),
        if (isSaving)
          paddedProgress
              ? const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'Kaydediliyor...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
      ],
    );

    return fields;
  }
}
