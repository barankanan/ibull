import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../domain/visual_search_models.dart';

class VisualSearchModuleCard extends StatelessWidget {
  const VisualSearchModuleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: subtitle == null ? 12 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softPurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class VisualSearchUploadArea extends StatelessWidget {
  const VisualSearchUploadArea({
    super.key,
    required this.onCamera,
    required this.onGallery,
    this.title,
    this.subtitle,
    this.compact = false,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showCopy = !compact && (title != null || subtitle != null);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Container(
              height: 148,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.softPurple),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                    size: 34,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Görseli buradan ekle',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (showCopy && title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          if (showCopy && subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textGrey,
              ),
            ),
          ],
          if (showCopy) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCamera,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Kamera Aç'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeriden Seç'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VisualSearchHistoryTile extends StatelessWidget {
  const VisualSearchHistoryTile({
    super.key,
    required this.job,
    required this.onTap,
    this.onDelete,
  });

  final VisualSearchJob job;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _Preview(dataUrl: job.previewDataUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.jobType.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        VisualSearchInlineStatus(status: job.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatVisualSearchDate(job.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      visualSearchSummaryLine(job),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Kaydı sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.textGrey),
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class VisualSearchInlineStatus extends StatelessWidget {
  const VisualSearchInlineStatus({super.key, required this.status});

  final VisualSearchJobStatus status;

  @override
  Widget build(BuildContext context) {
    final failed = status == VisualSearchJobStatus.failed;
    return Text(
      status.label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: failed ? AppColors.danger : AppColors.primary,
      ),
    );
  }
}

Widget _previewImage(String? dataUrl) {
  final bytes = _decodePreview(dataUrl);
  if (bytes == null) {
    return const Icon(Icons.image_outlined, color: AppColors.primary);
  }
  return Image.memory(bytes, fit: BoxFit.cover);
}

Uint8List? _decodePreview(String? dataUrl) {
  if (dataUrl == null || !dataUrl.contains(',')) return null;
  try {
    return base64Decode(dataUrl.split(',').last);
  } catch (_) {
    return null;
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.dataUrl});

  final String? dataUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: AppColors.softPurple,
        child: _previewImage(dataUrl),
      ),
    );
  }
}
