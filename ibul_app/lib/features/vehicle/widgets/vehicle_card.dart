import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/app_image_cdn.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../navigation/vehicle_routes.dart';
import 'vehicle_card_actions.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.listing,
    this.width,
    this.onTap,
    this.storefront = false,
    this.tight = false,
    this.margin,
    this.showActions = true,
  });

  final VehicleListing listing;
  final double? width;
  final VoidCallback? onTap;
  final bool storefront;
  final bool tight;
  final EdgeInsetsGeometry? margin;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    if (storefront) return _StorefrontVehicleCard(card: this);
    return _HubVehicleCard(card: this);
  }
}

class _HubVehicleCard extends StatelessWidget {
  const _HubVehicleCard({required this.card});

  final VehicleCard card;

  @override
  Widget build(BuildContext context) {
    final listing = card.listing;
    return SizedBox(
      width: card.width ?? 180,
      child: Stack(
        children: [
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap:
                  card.onTap ??
                  () => VehicleRoutes.openDetail(
                    context,
                    listing.id,
                    slug: listing.title,
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.md),
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child:
                          listing.coverUrl == null || listing.coverUrl!.isEmpty
                          ? ColoredBox(
                              color: AppColors.surfaceMuted,
                              child: Icon(
                                Icons.directions_car_outlined,
                                color: AppColors.iconMuted,
                              ),
                            )
                          : OptimizedImage(
                              imageUrlOrPath: AppImageCdn.buildUrl(listing.coverUrl!, AppImageVariant.card),
                              fit: BoxFit.cover,
                              cacheWidth: 600,
                              cacheHeight: 600,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _metaLine(listing),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _priceLine(listing),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (card.showActions) VehicleCardActionOverlay(listing: listing),
        ],
      ),
    );
  }
}

class _StorefrontVehicleCard extends StatelessWidget {
  const _StorefrontVehicleCard({required this.card});

  final VehicleCard card;

  @override
  Widget build(BuildContext context) {
    final listing = card.listing;
    final padding = card.tight ? 4.0 : 8.0;
    return SizedBox(
      width: card.width,
      child: Container(
        margin: card.margin ?? const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Material(
                color: Colors.white,
                child: InkWell(
                  onTap:
                      card.onTap ??
                      () => VehicleRoutes.openDetail(
                    context,
                    listing.id,
                    slug: listing.title,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ColoredBox(
                                  color: const Color(0xFFF7F7F8),
                                  child:
                                      listing.coverUrl == null ||
                                          listing.coverUrl!.isEmpty
                                      ? const Center(
                                          child: Icon(
                                            Icons.directions_car_outlined,
                                            color: AppColors.iconMuted,
                                            size: 36,
                                          ),
                                        )
                                      : OptimizedImage(
                                          imageUrlOrPath: AppImageCdn.buildUrl(listing.coverUrl!, AppImageVariant.card),
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          cacheWidth: 600,
                                          cacheHeight: 600,
                                        ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: _badge(listing),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.ink,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _metaLine(listing),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _priceLine(listing),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (card.showActions) VehicleCardActionOverlay(listing: listing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(VehicleListing listing) {
    final sale = listing.listingType.allowsSale;
    final rental = listing.listingType.allowsRental;
    final label = sale && rental
        ? 'Satılık / Kiralık'
        : rental
        ? 'Kiralık'
        : 'Satılık';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4CF4A),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2F2A16),
        ),
      ),
    );
  }
}

String _priceLine(VehicleListing listing) {
  if (listing.listingType.allowsSale && listing.salePrice != null) {
    return VehicleMoney.format(listing.salePrice!);
  }
  if (listing.rental != null) {
    return '${VehicleMoney.format(listing.rental!.dailyPrice)} / gün';
  }
  return 'Fiyat sorulur';
}

String _metaLine(VehicleListing listing) {
  return [
    if (listing.specs.year > 0) '${listing.specs.year}',
    if (listing.specs.mileageKm != null)
      VehicleMoney.km(listing.specs.mileageKm!),
    if (listing.city != null && listing.city!.isNotEmpty) listing.city!,
    if (listing.district != null && listing.district!.isNotEmpty)
      listing.district!,
  ].join(' · ');
}

class VehicleVerifiedChip extends StatelessWidget {
  const VehicleVerifiedChip({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    if (!verified) {
      return const Text(
        'Galerici tarafından girildi',
        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified, size: 14, color: AppColors.success),
        SizedBox(width: 4),
        Text(
          'Doğrulanmış',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}
