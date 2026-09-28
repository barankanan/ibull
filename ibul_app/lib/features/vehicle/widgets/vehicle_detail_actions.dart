import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/catalog_detail/catalog_detail_cta_bar.dart';
import '../domain/vehicle_detail_adapter.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_spec_table.dart';

const Color _kProductAction = Color(0xFF673AB7);
const Color _kProductPill = Color(0xFF6B21A8);

class VehicleDetailRailButton extends StatelessWidget {
  const VehicleDetailRailButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.iconColor = _kProductAction,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class VehicleDetailActionRail extends StatelessWidget {
  const VehicleDetailActionRail({
    super.key,
    required this.favorite,
    required this.compared,
    this.previewMode = false,
    this.onShare,
    this.onSave,
    this.onCompare,
    this.onFavorite,
  });

  final bool favorite;
  final bool compared;
  final bool previewMode;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onCompare;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final locked = previewMode;
    return Column(
      children: [
        VehicleDetailRailButton(
          key: const ValueKey('vehicle-detail-share'),
          icon: Icons.share_outlined,
          tooltip: 'Paylaş',
          onPressed: locked ? null : onShare,
        ),
        const SizedBox(height: 12),
        VehicleDetailRailButton(
          key: const ValueKey('vehicle-detail-save'),
          icon: Icons.bookmark_border,
          tooltip: 'Kaydet',
          onPressed: locked ? null : onSave,
        ),
        const SizedBox(height: 12),
        VehicleDetailRailButton(
          key: const ValueKey('vehicle-detail-compare'),
          icon: Icons.compare_arrows,
          tooltip: 'Karşılaştır',
          iconColor: compared ? AppColors.primary : _kProductAction,
          onPressed: locked ? null : onCompare,
        ),
        const SizedBox(height: 12),
        VehicleDetailRailButton(
          key: const ValueKey('vehicle-detail-favorite'),
          icon: favorite ? Icons.favorite : Icons.favorite_border,
          tooltip: 'Beğeni',
          iconColor: favorite ? Colors.red : _kProductAction,
          onPressed: locked ? null : onFavorite,
        ),
      ],
    );
  }
}

class VehicleDetailVideoPill extends StatelessWidget {
  const VehicleDetailVideoPill({
    super.key,
    required this.hasVideo,
    this.compact = false,
    this.onTap,
  });

  final bool hasVideo;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        key: const ValueKey('vehicle-detail-video'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: compact ? 15 : 18,
                color: hasVideo ? _kProductPill : AppColors.textGrey,
              ),
              const SizedBox(width: 6),
              Text(
                compact ? 'Ürün Videosu' : 'Video',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: hasVideo ? _kProductPill : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleDetailFeaturesPill extends StatelessWidget {
  const VehicleDetailFeaturesPill({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        key: const ValueKey('vehicle-detail-all-features'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tüm Özellikler',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kProductPill,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14, color: _kProductPill),
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleDetailNearbyButton extends StatelessWidget {
  const VehicleDetailNearbyButton({
    super.key,
    this.onTap,
    this.compact = false,
  });

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          key: const ValueKey('vehicle-detail-nearby'),
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6200EA),
            side: const BorderSide(color: Color(0xFF6200EA), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'YAKIN LOKASYON',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const ValueKey('vehicle-detail-nearby'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Yakın Lokasyon',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleDetailStickyBar extends StatelessWidget {
  const VehicleDetailStickyBar({
    super.key,
    required this.listing,
    this.previewMode = false,
    this.onPrimary,
    this.onSecondary,
  });

  final VehicleListing listing;
  final bool previewMode;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ctas = VehicleDetailAdapter.ctas(listing);
    return CatalogDetailCtaBar(
      price: VehicleDetailSpecBuilder.priceOf(listing),
      subtitle: VehicleDetailAdapter.ctaSubtitle(listing),
      primaryLabel: ctas.primaryLabel,
      secondaryLabel: ctas.secondaryLabel,
      onPrimary: previewMode ? null : onPrimary,
      onSecondary: previewMode ? null : onSecondary,
      sticky: true,
    );
  }
}
