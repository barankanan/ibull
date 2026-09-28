import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_card.dart';

export 'vehicle_detail_actions.dart';
export 'vehicle_detail_commerce_panel.dart';
export 'vehicle_detail_damage.dart';
export 'vehicle_detail_header.dart';
export 'vehicle_detail_seller.dart';
export 'vehicle_detail_spec_table.dart';

class VehicleDetailSectionCard extends StatelessWidget {
  const VehicleDetailSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class VehicleDetailDescription extends StatelessWidget {
  const VehicleDetailDescription({
    super.key,
    required this.text,
    required this.expanded,
    required this.onToggle,
    this.showToggle = true,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final bool showToggle;

  bool _needsToggle(String body) {
    return body.length > 360 || body.split('\n').length > 10;
  }

  @override
  Widget build(BuildContext context) {
    final body = text.replaceAll('\r\n', '\n').trim();
    if (body.isEmpty) {
      return const Text(
        'Açıklama eklenmedi.',
        style: TextStyle(color: AppColors.textGrey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          maxLines: expanded ? null : 10,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            height: 1.45,
            fontSize: 14,
            color: Color(0xFF1F1F1F),
          ),
        ),
        if (showToggle && _needsToggle(body))
          TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(expanded ? 'Daha Az Göster' : 'Daha Fazla Göster'),
          ),
      ],
    );
  }
}

class VehicleDetailFeatureSection extends StatelessWidget {
  const VehicleDetailFeatureSection({super.key, required this.listing});

  final VehicleListing listing;

  static List<VehicleFeatureGroup> dedupe(List<VehicleFeatureGroup> groups) {
    final seen = <String>{};
    return [
      for (final group in groups)
        VehicleFeatureGroup(
          id: group.id,
          label: group.label,
          items: [
            for (final item in group.items)
              if (seen.add(item.id)) item,
          ],
        ),
    ].where((group) => group.items.isNotEmpty).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final groups = VehicleDetailFeatureSection.dedupe(
      VehicleCatalog.featureGroupsFor(listing.vehicleClass),
    );
    final selected = listing.featureIds.toSet();
    if (groups.isEmpty) {
      return const Text(
        'Bu araç tipi için donanım grubu yok.',
        style: TextStyle(color: AppColors.textGrey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          Text(
            _groupLabel(group),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 640
                  ? 3
                  : constraints.maxWidth >= 400
                  ? 2
                  : 1;
              final width = (constraints.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final item in group.items)
                    SizedBox(
                      width: width,
                      child: _item(item.label, selected.contains(item.id)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _groupLabel(VehicleFeatureGroup group) {
    return switch (group.id) {
      'drive' => 'Sürüş Destek',
      'park' => 'Park / Kamera',
      'interior' => 'İç Donanım',
      _ => group.label,
    };
  }

  Widget _item(String label, bool on) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            on ? Icons.check : Icons.close,
            size: 14,
            color: on ? AppColors.success : AppColors.iconMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? AppColors.ink : AppColors.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleDetailRelatedRail extends StatelessWidget {
  const VehicleDetailRelatedRail({
    super.key,
    required this.related,
    this.onOpenRelated,
  });

  final List<VehicleListing> related;
  final ValueChanged<VehicleListing>? onOpenRelated;

  @override
  Widget build(BuildContext context) {
    if (related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Benzer Araçlar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 272,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = related[index];
              return VehicleCard(
                listing: item,
                width: 220,
                onTap: onOpenRelated == null
                    ? null
                    : () => onOpenRelated!(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
