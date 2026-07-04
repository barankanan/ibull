import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/skeleton_loading.dart';

/// Sağ sütun: Günün Fırsatı + Kupon alanı (legacy görünüm, hafif).
class HomeCouponDealColumn extends StatelessWidget {
  const HomeCouponDealColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.92),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günün Fırsatı',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bugünün en iyi indirimlerini kaçırma',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Spacer(),
                Icon(Icons.local_offer_outlined, color: Colors.white, size: 40),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kuponlarım',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Sepette kullanabileceğin kuponları gör',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
                ),
                Spacer(),
                Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Kuponları Keşfet',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget buildHomeCouponDealColumn() => const HomeCouponDealColumn();

/// Placeholder while deferred chunk loads.
Widget buildHomeCouponDealColumnSkeleton() {
  return Column(
    children: [
      Expanded(
        child: SkeletonLoading(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        ),
      ),
      const SizedBox(height: 12),
      SkeletonLoading(width: double.infinity, height: 150, borderRadius: 16),
    ],
  );
}
