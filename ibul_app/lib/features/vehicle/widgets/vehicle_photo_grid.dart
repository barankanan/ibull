import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_wizard_draft.dart';

class VehiclePhotoGrid extends StatelessWidget {
  const VehiclePhotoGrid({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onDelete,
    required this.onCover,
    required this.onRetry,
    required this.onMove,
  });

  final List<VehicleDraftPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<VehicleDraftPhoto> onDelete;
  final ValueChanged<VehicleDraftPhoto> onCover;
  final ValueChanged<VehicleDraftPhoto> onRetry;
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${photos.where((p) => p.ready).length} / ${VehicleCatalog.maxPhotos} fotoğraf  ·  en az ${VehicleCatalog.minPhotos}',
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 6),
        const Text(
          'İlanınız daha fazla fotoğraf içerdiğinde daha fazla dikkat çekebilir.',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _AddTile(
                enabled: photos.length < VehicleCatalog.maxPhotos,
                onAdd: onAdd,
              );
            }
            final photo = photos[index - 1];
            return _PhotoTile(
              photo: photo,
              onDelete: () => onDelete(photo),
              onCover: () => onCover(photo),
              onRetry: () => onRetry(photo),
              onLeft: index > 1 ? () => onMove(index - 1, index - 2) : null,
              onRight: index < photos.length
                  ? () => onMove(index - 1, index)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.enabled, required this.onAdd});
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: enabled ? onAdd : null,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
            SizedBox(height: 6),
            Text('Fotoğraf ekle', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onDelete,
    required this.onCover,
    required this.onRetry,
    this.onLeft,
    this.onRight,
  });

  final VehicleDraftPhoto photo;
  final VoidCallback onDelete;
  final VoidCallback onCover;
  final VoidCallback onRetry;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: AppColors.surfaceMuted, child: _image()),
          if (photo.uploading)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Yükleniyor…',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          if (photo.failed)
            ColoredBox(
              color: const Color(0x99000000),
              child: Center(
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text(
                    '⚠ Yüklenemedi\nTekrar dene',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          if (photo.ready)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Icon(Icons.check_circle, color: Colors.white, size: 16),
            ),
          if (photo.isCover)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'ANA',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: Row(
              children: [
                if (onLeft != null) _iconBtn(Icons.chevron_left, onLeft!),
                if (onRight != null) _iconBtn(Icons.chevron_right, onRight!),
                if (!photo.isCover && photo.ready)
                  _iconBtn(Icons.star_outline, onCover),
                _iconBtn(Icons.close, onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    if (photo.previewBytes != null) {
      return Image.memory(photo.previewBytes!, fit: BoxFit.cover);
    }
    if (photo.url != null && photo.url!.isNotEmpty) {
      return OptimizedImage(imageUrlOrPath: photo.url!, fit: BoxFit.cover);
    }
    return const Icon(Icons.image_outlined, color: AppColors.iconMuted);
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0x99000000),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
