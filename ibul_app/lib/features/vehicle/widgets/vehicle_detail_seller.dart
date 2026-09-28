import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_spec_table.dart';

class VehicleDetailSellerCard extends StatelessWidget {
  const VehicleDetailSellerCard({
    super.key,
    required this.listing,
    this.previewMode = false,
    this.compact = false,
    this.following = false,
    this.onFollow,
    this.onMessage,
    this.onOpenGallery,
    this.onCall,
  });

  final VehicleListing listing;
  final bool previewMode;
  final bool compact;
  final bool following;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final g = listing.gallery;
    if (g == null || g.name.trim().isEmpty) {
      return const Text(
        'Galeri bilgisi yok.',
        style: TextStyle(color: AppColors.textGrey),
      );
    }
    return compact ? _mobile(context, g) : _desktop(context, g);
  }

  Widget _mobile(BuildContext context, VehicleGallerySummary g) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _logo(g, 44),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: previewMode ? null : onOpenGallery,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      g.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (g.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 16, color: Colors.blue),
                  ],
                  if (g.rating != null && g.rating! > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        g.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _followButton(height: 32, fontSize: 11, hPad: 12),
                    const SizedBox(width: 8),
                    _askButton(height: 32, fontSize: 11, hPad: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktop(BuildContext context, VehicleGallerySummary g) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: previewMode ? null : onOpenGallery,
            child: Row(
              children: [
                _logo(g, 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              g.name.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          if (g.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (g.rating != null && g.rating! > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                g.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              'Mağaza Puanı',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _followButton(height: 36, fontSize: 13, hPad: 10),
              ),
              const SizedBox(width: 12),
              Expanded(child: _askButton(height: 36, fontSize: 13, hPad: 10)),
            ],
          ),
          if (onCall != null && !previewMode) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.phone_outlined, size: 16),
                label: const Text(
                  'Telefonla Ara',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF673AB7),
                  side: const BorderSide(color: Color(0xFF673AB7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _followButton({
    required double height,
    required double fontSize,
    required double hPad,
  }) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: previewMode ? null : onFollow,
        style: OutlinedButton.styleFrom(
          foregroundColor: following ? Colors.grey : const Color(0xFF673AB7),
          backgroundColor: following ? Colors.grey.shade100 : null,
          side: BorderSide(
            color: following ? Colors.grey.shade300 : const Color(0xFF673AB7),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: hPad),
          minimumSize: Size(0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            following ? 'Takip Ediliyor' : 'Takip Et',
            maxLines: 1,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: following ? Colors.grey.shade600 : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _askButton({
    required double height,
    required double fontSize,
    required double hPad,
  }) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: previewMode ? null : onMessage,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF673AB7),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: hPad),
          minimumSize: Size(0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Satıcıya Sor',
            maxLines: 1,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _logo(VehicleGallerySummary g, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: (g.logoUrl ?? '').isEmpty
          ? Text(
              g.name.trim().isEmpty ? 'G' : g.name.trim()[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF673AB7),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                g.logoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

class VehicleDetailLocation extends StatelessWidget {
  const VehicleDetailLocation({super.key, required this.listing});

  final VehicleListing listing;

  @override
  Widget build(BuildContext context) {
    final location = VehicleDetailSpecBuilder.locationOf(listing);
    final g = listing.gallery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.isEmpty ? 'Konum belirtilmedi' : location,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if ((g?.address ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            g!.address!,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ],
        if (g?.lat != null && g?.lng != null) ...[
          const SizedBox(height: 10),
          Container(
            height: 92,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.iconMuted,
                ),
                SizedBox(width: 6),
                Text(
                  'Konum işaretlendi',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
