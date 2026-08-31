import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizCourierSection extends StatelessWidget {
  const IhizCourierSection({super.key, required this.onApply});

  final VoidCallback onApply;

  static const _perks = [
    'Yakındaki görevleri gör',
    'Kazancını takip et',
    'Rotanı kolayca oluştur',
    'Paket durumunu takip et',
    'Hızlı görev seçimi',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = IhizBrand.isMobile(constraints.maxWidth);
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IhizSectionHeader(
              eyebrow: 'KURYE',
              title: 'Kendi rotanı seç. Kazancını kendin yönet.',
              subtitle:
                  'Esnek çalış, yakın görevleri seç ve her teslimatı tek ekrandan yönet.',
            ),
            const SizedBox(height: 20),
            for (final perk in _perks) IhizBulletRow(text: perk),
            const SizedBox(height: 8),
            IhizPrimaryButton(
              label: 'Kurye Başvurusu Yap',
              icon: Icons.two_wheeler_rounded,
              onPressed: onApply,
              expanded: mobile,
            ),
          ],
        );

        final visual = Container(
          width: double.infinity,
          padding: EdgeInsets.all(mobile ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: IhizBrand.heroGradient,
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bugünkü özet',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '₺642 · 5 teslimat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 18),
              _miniStat('Yakın görev', '3 açık'),
              const SizedBox(height: 10),
              _miniStat('Ortalama rota', '11 dk'),
              const SizedBox(height: 10),
              _miniStat('Tamamlama', '%98'),
            ],
          ),
        );

        if (mobile) {
          return Column(
            children: [
              text,
              const SizedBox(height: 24),
              visual,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: text),
            const SizedBox(width: 28),
            Expanded(flex: 9, child: visual),
          ],
        );
      },
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
