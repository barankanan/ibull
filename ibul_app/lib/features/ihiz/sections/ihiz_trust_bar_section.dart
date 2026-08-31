import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

class IhizTrustBarSection extends StatelessWidget {
  const IhizTrustBarSection({super.key});

  static const _items = [
    (Icons.bolt_rounded, 'Hızlı Teslimat'),
    (Icons.my_location_rounded, 'Canlı Takip'),
    (Icons.verified_user_rounded, 'Güvenli Teslimat'),
    (Icons.hub_outlined, 'Yerel Kurye Ağı'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final compact = !IhizBrand.useMediumGrid(w);
        final children = [
          for (final item in _items)
            _TrustItem(icon: item.$1, label: item.$2, compact: compact),
        ];

        if (IhizBrand.useWideGrid(w)) {
          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        // Mobile / tablet: 2x2 without hardcoded half-width overflow risk.
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 10),
                Expanded(child: children[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: children[2]),
                const SizedBox(width: 10),
                Expanded(child: children[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: IhizBrand.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: IhizBrand.blue, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12.5 : 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
