import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizCourierSection extends StatelessWidget {
  const IhizCourierSection({super.key, required this.onApply});

  final VoidCallback onApply;

  static const _perks = [
    (Icons.schedule_rounded, 'Esnek çalışma saatleri'),
    (Icons.near_me_outlined, 'Yakın bölgeden siparişler'),
    (Icons.payments_outlined, 'Anlık kazanç takibi'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 860;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KURYELER İÇİN',
              style: TextStyle(
                color: IhizBrand.blue,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kendi zamanının patronu ol.',
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w900,
                fontSize: mobile ? 28 : 34,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'İstediğin zaman, istediğin bölgede çalış. İHIZ ile yakındaki siparişleri gör ve kazancını panelden takip et.',
              style: TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            IhizPrimaryButton(
              label: 'Kurye Ol',
              icon: Icons.two_wheeler_rounded,
              onPressed: onApply,
              expanded: mobile,
            ),
          ],
        );

        final perks = Column(
          children: [
            for (var i = 0; i < _perks.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _PerkRow(icon: _perks[i].$1, label: _perks[i].$2),
            ],
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(mobile ? 18 : 28),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: IhizBrand.line),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 18),
                    perks,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 12, child: copy),
                    const SizedBox(width: 28),
                    Expanded(flex: 8, child: perks),
                  ],
                ),
        );
      },
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: IhizBrand.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
