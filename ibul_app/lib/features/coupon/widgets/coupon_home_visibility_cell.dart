import 'package:flutter/material.dart';

import '../domain/coupon_campaign.dart';
import '../domain/coupon_helpers.dart';

/// Admin kupon tablosu: ana sayfada keşfedilebilirlik ve görünmeme nedeni.
class CouponHomeVisibilityCell extends StatelessWidget {
  const CouponHomeVisibilityCell({super.key, required this.campaign});

  final CouponCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final reason = couponDiscoveryBlockReason(campaign);
    final visible = reason == null;
    return Tooltip(
      message: visible
          ? 'Ana sayfadaki kupon alanında ve Kuponları Keşfet sayfasında görünür.'
          : 'Ana sayfada görünmüyor: $reason',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 16,
              color: visible
                  ? const Color(0xFF059669)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                reason ?? 'Yayında',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: visible
                      ? const Color(0xFF059669)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
