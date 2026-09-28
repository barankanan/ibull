import '../models/vehicle_enums.dart';
import '../models/vehicle_wizard_draft.dart';
import 'vehicle_catalog.dart';

class VehicleQualityCheck {
  const VehicleQualityCheck({
    required this.id,
    required this.label,
    required this.done,
  });

  final String id;
  final String label;
  final bool done;
}

abstract final class VehicleListingQuality {
  static List<VehicleQualityCheck> checks({
    required VehicleWizardDraft draft,
    required int photoCount,
  }) {
    return [
      VehicleQualityCheck(
        id: 'title',
        label: 'Başlık',
        done: draft.displayTitle.trim().length >= 8,
      ),
      VehicleQualityCheck(
        id: 'brand',
        label: 'Marka',
        done: draft.brand.trim().isNotEmpty,
      ),
      VehicleQualityCheck(
        id: 'model',
        label: 'Model',
        done: draft.model.trim().isNotEmpty,
      ),
      VehicleQualityCheck(
        id: 'photos',
        label: '${VehicleCatalog.minPhotos} fotoğraf',
        done: photoCount >= VehicleCatalog.minPhotos,
      ),
      VehicleQualityCheck(
        id: 'description',
        label: 'Açıklama',
        done: (draft.description ?? '').trim().length >= 40,
      ),
      VehicleQualityCheck(id: 'price', label: 'Fiyat', done: _priceOk(draft)),
    ];
  }

  static int percent({
    required VehicleWizardDraft draft,
    required int photoCount,
  }) {
    final items = checks(draft: draft, photoCount: photoCount);
    if (items.isEmpty) return 0;
    final done = items.where((c) => c.done).length;
    return ((done / items.length) * 100).round();
  }

  static String descriptionQuality(VehicleWizardDraft draft) {
    final len = (draft.description ?? '').trim().length;
    if (len >= 80) return 'İyi';
    return 'Eksik';
  }

  static bool _priceOk(VehicleWizardDraft draft) {
    if (draft.listingType.allowsSale) {
      return draft.salePrice != null && draft.salePrice! > 0;
    }
    return draft.rental != null && draft.rental!.dailyPrice > 0;
  }
}
