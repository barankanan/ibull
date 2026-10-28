import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizHowItWorksSection extends StatelessWidget {
  const IhizHowItWorksSection({super.key});

  static const _steps = [
    (
      '1',
      'Sipariş Oluştur',
      'İşletmen siparişi sisteme girer, adres ve teslimat detaylarını paylaşır.',
      Icons.storefront_outlined,
    ),
    (
      '2',
      'Kurye Eşleşir',
      'İHIZ, bölgedeki en uygun kuryeyi yönlendirir.',
      Icons.two_wheeler_rounded,
    ),
    (
      '3',
      'Teslim Edilir',
      'Kurye siparişi alır ve müşteriye güvenle ulaştırır.',
      Icons.inventory_2_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 860;

        return Column(
          children: [
            const IhizSectionHeader(
              eyebrow: 'NASIL ÇALIŞIR?',
              title: '3 adımda kolay teslimat',
              subtitle:
                  'İHIZ, işletmeler ile kuryeleri tek platformda buluşturur. Siparişler daha hızlı, daha kolay ve daha güvenli şekilde teslim edilir.',
              center: true,
            ),
            SizedBox(height: stacked ? 18 : 28),
            if (stacked)
              Column(
                children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _StepCard(step: _steps[i]),
                  ],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: _StepCard(step: _steps[i])),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final (String, String, String, IconData) step;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: IhizBrand.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                step.$1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: IhizBrand.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(step.$4, color: IhizBrand.blue, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          step.$2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.$3,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: IhizBrand.inkSoft,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
