import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../screens/all_reviews_page.dart';
import '../../../widgets/catalog_detail/catalog_detail_card.dart';
import '../../../widgets/catalog_detail/catalog_detail_cta_bar.dart';
import '../../../widgets/catalog_detail/catalog_detail_scope.dart';
import '../domain/vehicle_detail_adapter.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_spec_table.dart';
import 'vehicle_quick_specs.dart';

class VehicleDetailCenterCard extends StatelessWidget {
  const VehicleDetailCenterCard({
    super.key,
    required this.listing,
    required this.isMobile,
    this.previewMode = false,
    this.showCta = true,
    this.onPrimary,
    this.onSecondary,
    this.onScrollSpecs,
  });

  final VehicleListing listing;
  final bool isMobile;
  final bool previewMode;
  final bool showCta;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final VoidCallback? onScrollSpecs;

  @override
  Widget build(BuildContext context) {
    final location = VehicleDetailSpecBuilder.locationOf(listing);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Identity(listing: listing, isMobile: isMobile),
        const SizedBox(height: 12),
        Text(
          VehicleDetailSpecBuilder.priceOf(listing),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF673AB7),
          ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 16),
        VehicleQuickSpecs(listing: listing, onSeeAll: onScrollSpecs),
        if (showCta) ...[
          const SizedBox(height: 12),
          CatalogDetailCtaBar(
            price: VehicleDetailSpecBuilder.priceOf(listing),
            subtitle: VehicleDetailAdapter.ctaSubtitle(listing),
            primaryLabel: VehicleDetailAdapter.ctas(listing).primaryLabel,
            secondaryLabel: VehicleDetailAdapter.ctas(listing).secondaryLabel,
            onPrimary: previewMode ? null : onPrimary,
            onSecondary: previewMode ? null : onSecondary,
          ),
        ],
      ],
    );

    if (isMobile) return body;
    return SingleChildScrollView(child: CatalogDetailCard(child: body));
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.listing, required this.isMobile});

  final VehicleListing listing;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final vm = catalogDetailViewModelOf(context);
    final summary = vm?.reviewSummary;
    final rating = summary?.averageRating ?? listing.gallery?.rating ?? 0;
    final reviewCount = summary?.reviewCount ?? 0;
    final brand = listing.specs.brand.trim();
    final store = listing.gallery?.name.trim() ?? '';
    final accent = brand.isNotEmpty ? brand : store;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (accent.isNotEmpty)
          Text(
            accent,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: isMobile ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          listing.title,
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: isMobile ? FontWeight.w600 : FontWeight.w400,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllReviewsPage(
                  productName: listing.title,
                  brand: listing.specs.brand,
                  storeName: listing.gallery?.name,
                  images: listing.media
                      .where((item) => !item.isVideo)
                      .map((item) => item.url)
                      .toList(growable: false),
                ),
              ),
            );
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stars(rating),
                const SizedBox(width: 8),
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: isMobile ? FontWeight.bold : FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isMobile ? '($reviewCount)' : '($reviewCount Değerlendirme)',
                  style: TextStyle(
                    fontSize: 13,
                    color: isMobile ? Colors.grey[600] : AppColors.primary,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        }
        if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        }
        return Icon(Icons.star_border, color: Colors.grey[300], size: 16);
      }),
    );
  }
}
