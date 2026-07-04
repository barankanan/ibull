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
    return SizedBox(
      height: 412,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: DeferredHomeHeroSection(
              delay: heroDelay,
              bannerImageUrls: bannerImageUrls,
              isLoading: isLoadingHero,
              embedded: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: DeferredHomeCouponDealColumn(delay: sideDelay),
          ),
        ],
      ),
    );
  }
}
