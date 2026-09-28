import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../models/vehicle_wizard_draft.dart';

class VehicleListingPreview extends StatelessWidget {
  const VehicleListingPreview({super.key, required this.listing});

  final VehicleListing listing;

  factory VehicleListingPreview.fromDraft({
    required VehicleWizardDraft draft,
    required List<VehicleDraftPhoto> photos,
    required String sellerId,
    String? listingId,
    VehicleGallerySummary? gallery,
  }) {
    final cover =
        photos.where((p) => p.isCover && p.ready).firstOrNull ??
        photos.where((p) => p.ready).firstOrNull;
    final media = photos
        .where((p) => p.ready)
        .map(
          (p) => VehicleMedia(
            id: p.id ?? p.localId,
            slot: VehicleMediaSlot.other,
            url: p.url!,
            sortOrder: p.sortOrder,
            isCover: p.isCover,
            objectPath: p.objectPath,
          ),
        )
        .toList(growable: false);
    final listing = VehicleListing(
      id: listingId ?? 'preview',
      sellerId: sellerId,
      listingType: draft.listingType,
      status: VehicleListingStatus.draft,
      specs: draft.toSpecs(),
      salePrice: draft.salePrice,
      negotiable: draft.negotiable,
      financing: draft.financing,
      tradeIn: draft.tradeIn,
      description: draft.description,
      city: draft.city ?? gallery?.city,
      district: draft.district ?? gallery?.district,
      coverUrl: cover?.url,
      media: media,
      rental: draft.rental,
      gallery: gallery,
      extras: draft.toExtras(),
    );
    return VehicleListingPreview(listing: listing);
  }

  @override
  Widget build(BuildContext context) {
    final urls = <String>[
      if (listing.coverUrl != null && listing.coverUrl!.isNotEmpty)
        listing.coverUrl!,
      ...listing.media.map((m) => m.url),
    ].where((u) => u.isNotEmpty).toSet().toList();
    final price = listing.listingType.allowsSale && listing.salePrice != null
        ? VehicleMoney.format(listing.salePrice!)
        : listing.rental != null
        ? '${VehicleMoney.format(listing.rental!.dailyPrice)} / gün'
        : 'Fiyat sorulur';
    final location = [
      if (listing.district != null && listing.district!.isNotEmpty)
        listing.district,
      if (listing.city != null && listing.city!.isNotEmpty) listing.city,
    ].join(' / ');
    final featureLabels = listing.featureIds
        .map(VehicleCatalog.featureLabel)
        .whereType<String>()
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.md),
            ),
            child: urls.isEmpty
                ? const SizedBox(
                    height: 200,
                    child: ColoredBox(
                      color: AppColors.surfaceMuted,
                      child: Center(
                        child: Icon(Icons.directions_car_outlined, size: 48),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 220,
                    child: PageView.builder(
                      itemCount: urls.length,
                      itemBuilder: (context, index) => OptimizedImage(
                        imageUrlOrPath: urls[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('${listing.specs.year}'),
                    if (listing.specs.mileageKm != null)
                      _chip('${_km(listing.specs.mileageKm!)} km'),
                    if (listing.specs.transmission != null)
                      _chip(listing.specs.transmission!),
                    if (listing.specs.fuel != null) _chip(listing.specs.fuel!),
                    if (listing.specs.bodyType != null)
                      _chip(listing.specs.bodyType!),
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '📍 $location',
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                ],
                if ((listing.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Açıklama',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(listing.description!.trim()),
                ],
                if (featureLabels.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Özellikler',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in featureLabels)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('✓ $label'),
                          backgroundColor: AppColors.surfaceMuted,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(text),
      backgroundColor: AppColors.surfaceMuted,
    );
  }

  String _km(int value) {
    final digits = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buf.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }
}
