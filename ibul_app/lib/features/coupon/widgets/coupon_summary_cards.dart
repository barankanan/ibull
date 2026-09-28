import 'package:flutter/material.dart';

import '../domain/coupon_models.dart';

class CouponSummaryCards extends StatelessWidget {
  const CouponSummaryCards({required this.summary, super.key});

  final CouponAdminSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Aktif Kuponlar', summary.active, const Color(0xFF16A34A)),
      ('Onay Bekleyenler', summary.pending, const Color(0xFFD97706)),
      ('Planlananlar', summary.scheduled, const Color(0xFF7C3AED)),
      ('Süresi Dolanlar', summary.expired, const Color(0xFF6B7280)),
      ('Hediye Çarkında Olanlar', summary.wheel, const Color(0xFF8B5CF6)),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          Container(
            width: 180,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.$2}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: item.$3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
