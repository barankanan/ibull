import 'package:flutter/material.dart';

import '../../../core/constants.dart';

/// Alt güven/ avantaj şeridi — legacy "Neden iBul?" benzeri.
class IbulTrustBarSection extends StatelessWidget {
  const IbulTrustBarSection({super.key});

  static const _items = [
    (Icons.local_shipping_outlined, 'Ücretsiz Kargo', 'Seçili ürünlerde'),
    (Icons.verified_user_outlined, 'Güvenli Ödeme', '256-bit SSL'),
    (Icons.replay_outlined, '14 Gün İade', 'Koşulsuz iade'),
    (Icons.support_agent_outlined, '7/24 Destek', 'Canlı yardım'),
    (Icons.verified_outlined, 'Orijinal Ürün', 'Garantili'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 16,
        runSpacing: 12,
        children: _items
            .map(
              (item) => _TrustItem(
                icon: item.$1,
                title: item.$2,
                subtitle: item.$3,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }
}
