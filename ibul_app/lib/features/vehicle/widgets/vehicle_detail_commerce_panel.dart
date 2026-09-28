import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_spec_table.dart';

const Color _kCommercePurple = Color(0xFF6200EA);

class VehicleDetailCtaRow extends StatelessWidget {
  const VehicleDetailCtaRow({
    super.key,
    required this.listing,
    this.previewMode = false,
    this.onMessage,
    this.onCall,
    this.onOffer,
    this.onReserve,
    this.dense = false,
  });

  final VehicleListing listing;
  final bool previewMode;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onOffer;
  final VoidCallback? onReserve;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final sale = listing.listingType.allowsSale;
    final rental = listing.listingType.allowsRental;
    final height = dense ? 40.0 : 44.0;
    return Row(
      children: [
        Expanded(
          child: _filledCta(
            key: const ValueKey('vehicle-detail-inline-message'),
            height: height,
            label: 'Satıcıya Sor',
            onPressed: previewMode ? null : onMessage,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _outlinedCta(
            key: const ValueKey('vehicle-detail-inline-call'),
            height: height,
            label: 'Hemen Ara',
            onPressed: previewMode ? null : onCall,
          ),
        ),
        if (rental) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _outlinedCta(
              key: const ValueKey('vehicle-detail-inline-reserve'),
              height: height,
              label: 'Kirala',
              onPressed: previewMode ? null : onReserve,
            ),
          ),
        ],
        if (sale) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _outlinedCta(
              key: const ValueKey('vehicle-detail-inline-offer'),
              height: height,
              label: 'Teklif Sor',
              onPressed: previewMode ? null : onOffer,
            ),
          ),
        ],
      ],
    );
  }

  Widget _filledCta({
    required Key key,
    required double height,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        key: key,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCommercePurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _outlinedCta({
    required Key key,
    required double height,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kCommercePurple,
          side: const BorderSide(color: _kCommercePurple, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class VehicleDetailAdditionalServices extends StatelessWidget {
  const VehicleDetailAdditionalServices({
    super.key,
    required this.listing,
    this.hasVideo = false,
    this.onNearby,
    this.onVideo,
    this.onScrollSpecs,
  });

  final VehicleListing listing;
  final bool hasVideo;
  final VoidCallback? onNearby;
  final VoidCallback? onVideo;
  final VoidCallback? onScrollSpecs;

  @override
  Widget build(BuildContext context) {
    final items = <_ServiceRow>[
      if (onNearby != null)
        _ServiceRow(
          icon: Icons.location_on_outlined,
          title: 'Yakın Lokasyon',
          subtitle: 'Haritada ilanı ve galeriyi gör',
          onTap: onNearby,
        ),
      if (listing.specs.hasExpertise)
        _ServiceRow(
          icon: Icons.fact_check_outlined,
          title: 'Ekspertiz',
          subtitle: 'Satıcı ekspertiz beyanı mevcut',
          onTap: onScrollSpecs,
        ),
      if (listing.tradeIn)
        _ServiceRow(
          icon: Icons.swap_horiz,
          title: 'Takas',
          subtitle: 'Takas uygun ilan',
        ),
      if (hasVideo && onVideo != null)
        _ServiceRow(
          icon: Icons.play_circle_outline,
          title: 'Araç Videosu',
          subtitle: 'Galeri videosunu izle',
          onTap: onVideo,
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _serviceCard(items[i]),
        ],
      ],
    );
  }

  Widget _serviceCard(_ServiceRow row) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: row.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(row.icon, color: _kCommercePurple, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (row.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          row.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow {
  const _ServiceRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
}

class VehicleDetailSectionNav extends StatelessWidget {
  const VehicleDetailSectionNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const tabs = <String>[
    'Açıklama',
    'Özellikler',
    'Donanım',
    'Konum',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF673AB7) : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF673AB7)
                      : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VehicleDetailGalleryTabsPanel extends StatelessWidget {
  const VehicleDetailGalleryTabsPanel({
    super.key,
    required this.listing,
    required this.selectedIndex,
    required this.onSelected,
    this.onScrollSection,
  });

  final VehicleListing listing;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onScrollSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VehicleDetailSectionNav(
          selectedIndex: selectedIndex,
          onSelected: (index) {
            onSelected(index);
            onScrollSection?.call(index);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: _previewBody(selectedIndex),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewBody(int index) {
    switch (index) {
      case 0:
        final text = (listing.description ?? '').trim();
        if (text.isEmpty) {
          return const Text(
            'Açıklama eklenmedi.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          );
        }
        return Text(
          text,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(height: 1.45, fontSize: 13),
        );
      case 1:
        final rows = VehicleDetailSpecBuilder.compactRows(listing).take(8);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 2:
        return Text(
          '${listing.featureIds.length} donanım seçili',
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
        );
      default:
        return Text(
          VehicleDetailSpecBuilder.locationOf(listing).isEmpty
              ? 'Konum bilgisi yok'
              : VehicleDetailSpecBuilder.locationOf(listing),
          style: const TextStyle(fontSize: 13),
        );
    }
  }
}

class VehicleDetailSidebarFacts extends StatelessWidget {
  const VehicleDetailSidebarFacts({super.key, required this.listing});

  final VehicleListing listing;

  @override
  Widget build(BuildContext context) {
    final rows = VehicleDetailSpecBuilder.sidebarRows(listing);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'İlan Özeti',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
