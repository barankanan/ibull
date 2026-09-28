import 'package:flutter/material.dart';

import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_photo_grid.dart';
import '../../widgets/vehicle_wizard_chrome.dart';

class VehicleWizardPhotosStep extends StatelessWidget {
  const VehicleWizardPhotosStep({
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
  final Future<void> Function(VehicleDraftPhoto photo) onDelete;
  final Future<void> Function(VehicleDraftPhoto photo) onCover;
  final VoidCallback onRetry;
  final Future<void> Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VehicleWizardSection(
          title: 'Fotoğraflar',
          subtitle:
              'Yüklenen görseller hemen görünür. En az 3 fotoğraf önerilir.',
          child: VehiclePhotoGrid(
            photos: photos,
            onAdd: onAdd,
            onDelete: onDelete,
            onCover: onCover,
            onRetry: (_) => onRetry(),
            onMove: onMove,
          ),
        ),
      ],
    );
  }
}
