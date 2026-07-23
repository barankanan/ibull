import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// "İHIZ Kurye Ağına Katıl" call-to-action. The primary button reuses the
/// existing courier application flow via [onApply].
class IhizCourierCtaSection extends StatelessWidget {
  const IhizCourierCtaSection({super.key, required this.onApply});

  final VoidCallback onApply;

  static const List<String> _perks = [
    'Esnek çalışma saatleri',
    'Anlık kazanç takibi',
    'Yakın sipariş eşleştirme',
    'İade + teslim operasyonu',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final perks = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final perk in _perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        perk,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

        final button = ElevatedButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.two_wheeler_rounded),
          label: const Text('Kurye Başvurusu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: IhizBrand.navy,
            minimumSize: const Size.fromHeight(58),
            elevation: 6,
            shadowColor: const Color(0x33000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        );

        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: const Text(
                'KURYE OL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'İHIZ Kurye Ağına Katıl',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kendi saatlerinde çalış, yakın siparişleri al, kazancını anlık takip et.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(wide ? 40 : 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: IhizBrand.heroGradient,
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.24),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: textBlock),
                    const SizedBox(width: 34),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          perks,
                          const SizedBox(height: 8),
                          button,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    textBlock,
                    const SizedBox(height: 20),
                    perks,
                    const SizedBox(height: 6),
                    button,
                  ],
                ),
        );
      },
    );
  }
}
