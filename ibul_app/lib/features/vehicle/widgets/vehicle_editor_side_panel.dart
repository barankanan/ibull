import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../domain/vehicle_listing_quality.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_wizard_draft.dart';

class VehicleEditorSidePanel extends StatelessWidget {
  const VehicleEditorSidePanel({
    super.key,
    required this.draft,
    required this.photos,
  });

  final VehicleWizardDraft draft;
  final List<VehicleDraftPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final ready = photos.where((p) => p.ready).toList(growable: false);
    final cover =
        photos.where((p) => p.isCover && p.ready).firstOrNull ??
        ready.firstOrNull;
    final checks = VehicleListingQuality.checks(
      draft: draft,
      photoCount: ready.length,
    );
    final percent = VehicleListingQuality.percent(
      draft: draft,
      photoCount: ready.length,
    );
    final price = draft.listingType.allowsSale && draft.salePrice != null
        ? VehicleMoney.format(draft.salePrice!)
        : draft.rental != null
        ? '${VehicleMoney.format(draft.rental!.dailyPrice)} / gün'
        : 'Fiyat sorulur';
    final specs = [
      if (draft.mileageKm != null) VehicleMoney.km(draft.mileageKm!),
      if (draft.fuel != null && draft.transmission != null)
        '${draft.fuel} · ${draft.transmission}'
      else ...[
        if (draft.fuel != null) draft.fuel!,
        if (draft.transmission != null) draft.transmission!,
      ],
    ].join('\n');

    return Column(
      children: [
        _card(
          title: 'Araç Önizleme',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: cover?.url == null
                      ? const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Center(
                            child: Icon(
                              Icons.directions_car_outlined,
                              size: 42,
                              color: AppColors.iconMuted,
                            ),
                          ),
                        )
                      : OptimizedImage(
                          imageUrlOrPath: cover!.url!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                draft.displayTitle.isEmpty
                    ? 'Başlık bekleniyor'
                    : draft.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  specs,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          title: 'Hızlı Kontrol',
          child: Column(
            children: [
              for (final check in checks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        check.done ? Icons.check : Icons.radio_button_unchecked,
                        size: 16,
                        color: check.done
                            ? AppColors.primary
                            : AppColors.iconMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          check.label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          title: 'İlan Kalitesi',
          child: Column(
            children: [
              _qualityRow('Bilgi tamamlama', '%$percent'),
              _qualityRow(
                'Fotoğraf',
                '${ready.length} / ${VehicleCatalog.maxPhotos}',
              ),
              _qualityRow(
                'Açıklama',
                VehicleListingQuality.descriptionQuality(draft),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _qualityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
