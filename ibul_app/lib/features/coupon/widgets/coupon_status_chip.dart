import 'package:flutter/material.dart';

import '../domain/coupon_enums.dart';
import '../domain/coupon_status_labels.dart';

class CouponStatusChip extends StatelessWidget {
  const CouponStatusChip({required this.status, super.key});

  final CouponEffectiveStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      CouponEffectiveStatus.active => (
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      CouponEffectiveStatus.pendingReview => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
      CouponEffectiveStatus.scheduled => (
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
      ),
      CouponEffectiveStatus.rejected => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
      ),
      CouponEffectiveStatus.expired => (
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      ),
      CouponEffectiveStatus.paused => (
        const Color(0xFFFFEDD5),
        const Color(0xFFC2410C),
      ),
      CouponEffectiveStatus.approved => (
        const Color(0xFFE0E7FF),
        const Color(0xFF3730A3),
      ),
      CouponEffectiveStatus.draft => (
        const Color(0xFFF3F4F6),
        const Color(0xFF4B5563),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        CouponStatusLabels.effective(status),
        style: TextStyle(
          color: colors.$2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
