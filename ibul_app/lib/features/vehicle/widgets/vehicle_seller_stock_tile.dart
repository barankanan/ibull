import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../domain/vehicle_state_machine.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';

class VehicleSellerStockTile extends StatelessWidget {
  const VehicleSellerStockTile({
    super.key,
    required this.listing,
    required this.onEdit,
    required this.onPreview,
    required this.onPublish,
    required this.onUnpublish,
    required this.onSold,
    required this.onDelete,
  });

  final VehicleListing listing;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onSold;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        listing.status == VehicleListingStatus.draft ||
        listing.status == VehicleListingStatus.inactive ||
        listing.isRejected;
    final canUnpublish = VehicleStateMachine.canTransitionListing(
      listing.status,
      VehicleListingStatus.inactive,
    );
    final canSold = VehicleStateMachine.canTransitionListing(
      listing.status,
      VehicleListingStatus.sold,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: 86,
                  height: 64,
                  child: listing.coverUrl == null || listing.coverUrl!.isEmpty
                      ? const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Icon(Icons.directions_car_outlined),
                        )
                      : OptimizedImage(
                          imageUrlOrPath: listing.coverUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (listing.specs.year > 0) '${listing.specs.year}',
                        if (listing.specs.mileageKm != null)
                          '${listing.specs.mileageKm} km',
                        if (listing.salePrice != null)
                          VehicleMoney.format(listing.salePrice!),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(listing: listing),
                    if (listing.isRejected &&
                        (listing.rejectionReason ?? '').isNotEmpty)
                      Text(
                        'Admin notu: ${listing.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onEdit, child: const Text('Düzenle')),
              TextButton(onPressed: onPreview, child: const Text('Önizle')),
              if (canSubmit)
                TextButton(
                  onPressed: onPublish,
                  child: const Text('Onaya Gönder'),
                ),
              if (listing.status == VehicleListingStatus.active && canUnpublish)
                TextButton(
                  onPressed: onUnpublish,
                  child: const Text('Yayından kaldır'),
                ),
              if (canSold)
                TextButton(onPressed: onSold, child: const Text('Satıldı')),
              TextButton(onPressed: onDelete, child: const Text('Sil')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.listing});

  final VehicleListing listing;

  @override
  Widget build(BuildContext context) {
    final live = listing.isLivePublished;
    final pending = listing.status == VehicleListingStatus.pendingReview;
    final rejected = listing.isRejected;
    final Color color;
    if (live) {
      color = const Color(0xFF15803D);
    } else if (rejected) {
      color = AppColors.danger;
    } else if (pending) {
      color = const Color(0xFFB45309);
    } else {
      color = AppColors.textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        listing.statusLabelTr,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
