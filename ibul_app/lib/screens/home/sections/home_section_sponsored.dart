import 'package:flutter/material.dart';

import '../../../ads/enums/ad_enums.dart';
import '../../../core/web_perf_trace.dart';
import '../../../widgets/sponsored_product_lists_section.dart';

/// Sponsored rails — deferred from home core.
class HomeSponsoredSection extends StatelessWidget {
  const HomeSponsoredSection({super.key});

  @override
  Widget build(BuildContext context) {
    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredCampaignLoaded);
    return const Column(
      children: [
        SponsoredProductListsSection(
          title: 'Öne Çıkan Listeler',
          subtitle: 'Ana sayfada sponsorlu olarak gösterilen ürün listeleri',
          placement: AdPlacement.homeFeed,
        ),
        SizedBox(height: 16),
      ],
    );
  }
}

Widget buildHomeSponsoredSection() => const HomeSponsoredSection();
