import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

class IhizFeatureSection extends StatelessWidget {
  const IhizFeatureSection({super.key});

  static const _items = [
    (
      Icons.bolt_rounded,
      'Hızlı Teslimat',
      'En yakın kurye ile dakikalar içinde teslimat.',
    ),
    (
      Icons.my_location_rounded,
      'Canlı Takip',
      'Siparişin her aşamasını anlık olarak takip et.',
    ),
    (
      Icons.verified_user_outlined,
      'Güvenli Teslimat',
      'Doğrulama ve güvenli teslimat süreci.',
    ),
    (
      Icons.hub_outlined,
      'Yerel Kurye Ağı',
      'Bulunduğun bölgede aktif ve güvenilir kuryeler.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 980 ? 4 : (width >= 640 ? 2 : 1);
        final gap = 12.0;

        final cards = [
          for (final item in _items)
            _FeatureTile(icon: item.$1, title: item.$2, body: item.$3),
        ];

        if (cols == 1) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                cards[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += cols) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          final slice = cards.sublist(
            i,
            (i + cols).clamp(0, cards.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    Expanded(
                      child: j < slice.length
                          ? slice[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: IhizBrand.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: IhizBrand.blue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: IhizBrand.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: IhizBrand.inkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: IhizBrand.inkSoft,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
