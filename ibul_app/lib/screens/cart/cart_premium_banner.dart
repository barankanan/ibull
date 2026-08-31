import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../account/account_menu_navigation.dart';

/// Web sepetindeki Yakında girişi — satış vaadi değil, raf.
class CartPremiumBanner extends StatelessWidget {
  const CartPremiumBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Yakında',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Premium, tamir, montaj ve barkod henüz satışta değil.',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton(
              key: const Key('cart-premium-cta'),
              onPressed: () => AccountMenuNavigation.openShelf(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.borderStrong),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
              child: const Text(
                'Listeyi gör',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
