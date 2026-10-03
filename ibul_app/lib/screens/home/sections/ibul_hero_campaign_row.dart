import 'package:flutter/material.dart';

import '../deferred/deferred_home_coupon_deal_column.dart';
import '../deferred/deferred_home_hero_section.dart';

/// Hero + kupon/fırsat sütunu — legacy web iki sütun düzeni.
class IbulHeroCampaignRow extends StatelessWidget {
  const IbulHeroCampaignRow({
    super.key,
    required this.heroDelay,
    required this.sideDelay,
    this.bannerImageUrls = const [],
    this.isLoadingHero = false,
  });

  final Duration heroDelay;
  final Duration sideDelay;
  final List<String> bannerImageUrls;
  final bool isLoadingHero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sideWidth = (width * 0.27).clamp(260.0, 320.0);
        final heroWidth = width - sideWidth - 16;
        final aspectRatio = width < 1100 ? 2.2 : 2.65;
        final height = (heroWidth / aspectRatio).clamp(250.0, 390.0);

        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DeferredHomeHeroSection(
                  delay: heroDelay,
                  bannerImageUrls: bannerImageUrls,
                  isLoading: isLoadingHero,
                  embedded: true,
                  height: height,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: sideWidth,
                child: DeferredHomeCouponDealColumn(delay: sideDelay),
              ),
            ],
          ),
        );
      },
    );
  }
}
