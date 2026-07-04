import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SponsoredProductListsSection uses HomeSponsoredContentService', () {
    final source = File('lib/widgets/sponsored_product_lists_section.dart')
        .readAsStringSync();

    expect(source.contains('HomeSponsoredContentService'), isTrue);
    expect(source.contains('getCampaignsForAdmin'), isFalse);
    expect(source.contains('AdsService'), isFalse);
    expect(source.contains('getSponsoredCollections'), isFalse);
  });

  test('HomeSponsoredContentService source avoids admin campaign loader', () {
    final source = File('lib/ads/services/home_sponsored_content_service.dart')
        .readAsStringSync();

    expect(source.contains('getCampaignsForAdmin'), isFalse);
    expect(source.contains('getActiveHomeCollectionCampaigns'), isTrue);
  });
}
