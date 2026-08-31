import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizHowItWorksSection extends StatelessWidget {
  const IhizHowItWorksSection({super.key});

  static const _steps = [
    (
      '01',
      'Sipariş oluşur',
      'Müşteri siparişi tamamlar; mağaza paketi hazırlar.',
      Icons.receipt_long_rounded,
    ),
    (
      '02',
      'Kurye eşleşir',
      'İhız, en yakın uygun kuryeyi otomatik eşleştirir.',
      Icons.person_search_rounded,
    ),
    (
      '03',
      'Kurye teslim alır',
      'Kurye mağazadan paketi doğrulayıp yola çıkar.',
      Icons.inventory_2_rounded,
    ),
    (
      '04',
      'Müşteriye ulaşır',
      'Canlı takip ile paket kapıya güvenle teslim edilir.',
      Icons.home_rounded,
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
              eyebrow: 'NASIL ÇALIŞIR?',
              title: 'Dört adımda şeffaf teslimat',
              subtitle:
                  'Siparişten kapıya kadar her aşama net, hızlı ve izlenebilir.',
            ),
            SizedBox(height: compact ? 18 : 24),
            IhizResponsiveCardGrid(
              children: [
                for (final step in _steps)
                  _StepCard(step: step, compact: compact),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.compact});

  final (String, String, String, IconData) step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                step.$1,
                style: TextStyle(
                  color: IhizBrand.blue,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 17 : 20,
                ),
              ),
              const Spacer(),
              Container(
                width: compact ? 34 : 40,
                height: compact ? 34 : 40,
                decoration: BoxDecoration(
                  color: IhizBrand.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  step.$4,
                  color: IhizBrand.blue,
                  size: compact ? 18 : 20,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          Text(
            step.$2,
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 15 : 16.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.$3,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 13 : 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
