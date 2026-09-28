import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_actions.dart';
import 'vehicle_detail_spec_table.dart';

class VehicleDetailBreadcrumb extends StatelessWidget {
  const VehicleDetailBreadcrumb({
    super.key,
    required this.listing,
    this.previewMode = false,
  });

  final VehicleListing listing;
  final bool previewMode;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      'iBul',
      if (listing.specs.brand.trim().isNotEmpty) listing.specs.brand.trim(),
      'Araç',
      listing.title.trim(),
    ].where((e) => e.isNotEmpty).toList(growable: false);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
      child: Row(
        children: [
          if (previewMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Text(
                'Önizleme',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: parts.asMap().entries.map((entry) {
                  final isLast = entry.key == parts.length - 1;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 11,
                          color: isLast ? Colors.black54 : AppColors.primary,
                          fontWeight:
                              isLast ? FontWeight.w400 : FontWeight.w500,
                        ),
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleDetailTitleBlock extends StatelessWidget {
  const VehicleDetailTitleBlock({
    super.key,
    required this.listing,
    required this.isMobile,
    this.onNearby,
    this.showNearbyChip = true,
  });

  final VehicleListing listing;
  final bool isMobile;
  final VoidCallback? onNearby;
  final bool showNearbyChip;

  @override
  Widget build(BuildContext context) {
    final brand = listing.specs.brand.trim();
    final store = listing.gallery?.name.trim() ?? '';
    final accent = brand.isNotEmpty ? brand : store;
    final highlights = VehicleDetailSpecBuilder.highlights(listing);
    final location = VehicleDetailSpecBuilder.locationOf(listing);
    final rating = listing.gallery?.rating ?? 0;
    final count = listing.gallery?.vehicleCount ?? 0;

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
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _ratingRow(rating, count, isMobile),
              ),
            ),
            if (isMobile && showNearbyChip) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: VehicleDetailNearbyButton(onTap: onNearby),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          VehicleDetailSpecBuilder.priceOf(listing),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF673AB7),
          ),
        ),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (icon, label) in highlights)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _ratingRow(double rating, int count, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          if (index < rating.floor()) {
            return const Icon(Icons.star, color: Colors.amber, size: 16);
          }
          if (index < rating) {
            return const Icon(Icons.star_half, color: Colors.amber, size: 16);
          }
          return Icon(Icons.star_border, color: Colors.grey[300], size: 16);
        }),
        const SizedBox(width: 6),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : '0.0',
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: isMobile ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Text(
            isMobile ? '($count)' : '($count ilan)',
            style: TextStyle(
              fontSize: 13,
              color: isMobile ? Colors.grey[600] : AppColors.primary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ],
    );
  }
}
