import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizWhySection extends StatelessWidget {
  const IhizWhySection({super.key});

  static const _items = [
    (
      Icons.bolt_rounded,
      'Hız',
      'Yerel kurye ağıyla siparişler dakikalar içinde kapıda.',
      IhizBrand.blueBright,
    ),
    (
      Icons.visibility_rounded,
      'Şeffaflık',
      'Rota, ETA ve teslimat durumu her an görünür.',
      IhizBrand.blue,
    ),
    (
      Icons.shield_rounded,
      'Güven',
      'Doğrulanmış kuryeler ve güvenli teslimat akışı.',
      IhizBrand.navySoft,
    ),
    (
      Icons.auto_awesome_rounded,
      'Teknoloji',
      'Akıllı eşleştirme ve operasyon paneli tek platformda.',
      IhizBrand.blueOcean,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !IhizBrand.useMediumGrid(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IhizSectionHeader(
              eyebrow: 'NEDEN İHIZ?',
              title: 'Hızlı, şeffaf ve güvenilir teslimat altyapısı',
              subtitle:
                  'Teslimatı bir lojistik yükü olmaktan çıkarıp büyüme avantajına dönüştürüyoruz.',
              center: true,
            ),
            SizedBox(height: compact ? 18 : 24),
            IhizResponsiveCardGrid(
              children: [
                for (final item in _items)
                  IhizFeatureCard(
                    icon: item.$1,
                    title: item.$2,
                    body: item.$3,
                    accent: item.$4,
                    compact: compact,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
