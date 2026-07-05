import 'package:flutter/material.dart';

import '../../../ads/enums/ad_enums.dart';
import '../../../core/web_perf_trace.dart';
import '../../../widgets/sponsored_product_lists_section.dart';

/// Sponsored rails — deferred from home core.
class HomeSponsoredSection extends StatelessWidget {
  const HomeSponsoredSection({
    super.key,
    this.suppressSkeleton = false,
  });

  final bool suppressSkeleton;

  @override
  Widget build(BuildContext context) {
    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredCampaignLoaded);
    return Column(
      children: [
        SponsoredProductListsSection(
          title: 'Öne Çıkan Listeler',
          subtitle: 'Ana sayfada sponsorlu olarak gösterilen ürün listeleri',
          placement: AdPlacement.homeFeed,
          suppressSkeleton: suppressSkeleton,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

Widget buildHomeSponsoredSection({bool suppressSkeleton = false}) {
  return HomeSponsoredSection(suppressSkeleton: suppressSkeleton);
}
