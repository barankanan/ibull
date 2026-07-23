import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// "Neden İHIZ?" — three feature cards under the hero.
class IhizWhySection extends StatelessWidget {
  const IhizWhySection({super.key});

  static const List<_WhyItem> _items = [
    _WhyItem(
      icon: Icons.bolt_rounded,
      title: 'Hızlı Teslimat',
      body: '1 saat içinde kapında; siparişin en yakın kuryeyle eşleşir.',
      accent: IhizBrand.blueBright,
    ),
    _WhyItem(
      icon: Icons.my_location_rounded,
      title: 'Canlı Takip',
      body: 'Kuryeni haritada anlık gör; rota ve varış süresi şeffaf.',
      accent: IhizBrand.blue,
    ),
    _WhyItem(
      icon: Icons.verified_user_rounded,
      title: 'Güvenli İade',
      body: 'Beğenmezsen gün içinde kapından güvenli iade süreci.',
      accent: IhizBrand.mint,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              eyebrow: 'NEDEN İHIZ?',
              title: 'Hızlı, şeffaf ve güvenli teslimat',
            ),
            const SizedBox(height: 18),
            if (wide)
              // IntrinsicHeight gives the Row a bounded cross-axis so the
              // stretched (equal-height) cards work inside the vertical scroll
              // view; without it, `stretch` under an unbounded height throws
              // "RenderBox was not laid out".
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: _WhyCard(item: _items[i])),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _WhyCard(item: _items[i]),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _WhyItem {
  const _WhyItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.item});

  final _WhyItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: IhizBrand.line),
        boxShadow: [
          BoxShadow(
            color: IhizBrand.navy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.accent, size: 27),
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.body,
            style: const TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable eyebrow + title heading for marketing sections.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: IhizBrand.blue,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
