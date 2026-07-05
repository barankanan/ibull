import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/enums/ad_enums.dart';
import 'package:ibul_app/ads/repositories/ads_repository.dart';
import 'package:ibul_app/ads/services/home_sponsored_content_service.dart';

void main() {
  test('RPC mapper exposes only customer-safe campaign fields', () {
    final campaign = AdsRepository.mapHomeSponsoredCollectionRpcRow({
      'campaign_id': 'cmp_1',
      'seller_id': '00000000-0000-4000-8000-000000000001',
      'store_id': 'store_1',
      'collection_id': 'list_1',
      'title': 'Yaz Koleksiyonu',
      'cover_url': 'https://cdn.example/cover.jpg',
      'placement': 'home_feed',
      'starts_at': '2026-06-01T00:00:00.000Z',
      'ends_at': '2026-12-31T23:59:59.000Z',
    });

    expect(campaign.id, 'cmp_1');
    expect(campaign.bidAmount, 0);
    expect(campaign.isPremiumPlacementEnabled, isFalse);
    expect(campaign.dailyBudget, 0);
    expect(campaign.totalBudget, 0);
    expect(campaign.spentAmount, 0);
    expect(campaign.reviewNotes, isNull);
    expect(campaign.metadata, isEmpty);
    expect(HomeSponsoredContentService.collectionId(campaign), 'list_1');
    expect(
      HomeSponsoredContentService.supportsPlacement(
        campaign,
        AdPlacement.homeFeed,
      ),
      isTrue,
    );
  });

  test('RPC mapper ignores rank_score if present in payload', () {
    final campaign = AdsRepository.mapHomeSponsoredCollectionRpcRow({
      'campaign_id': 'cmp_1',
      'seller_id': '00000000-0000-4000-8000-000000000001',
      'collection_id': 'list_1',
      'title': 'Test',
      'placement': 'home_feed',
      'rank_score': 99.9,
      'bid_amount': 50,
      'starts_at': '2026-06-01T00:00:00.000Z',
      'ends_at': '2026-12-31T23:59:59.000Z',
    });

    expect(campaign.bidAmount, 0);
    expect(campaign.isPremiumPlacementEnabled, isFalse);
  });

  test('getActiveHomeCollectionCampaigns uses secure RPC not table select', () {
    final source = File('lib/ads/repositories/ads_repository.dart')
        .readAsStringSync();

    expect(source.contains('fetch_active_home_sponsored_collections'), isTrue);
    expect(source.contains('_homeCollectionCampaignSelect'), isFalse);
    expect(source.contains('rank_score'), isFalse);
    expect(
      source.contains(".from(AdsTableNames.campaigns)\n            .select(_homeCollectionCampaignSelect)"),
      isFalse,
    );
  });

  test('HomeSponsoredContentService preserves RPC order without client ranking', () {
    final source = File('lib/ads/services/home_sponsored_content_service.dart')
        .readAsStringSync();

    expect(source.contains('bidAmount'), isFalse);
    expect(source.contains('..sort((a, b)'), isFalse);
  });

  test('previewListFromCampaign uses RPC metadata when list hydration fails', () {
    final campaign = AdsRepository.mapHomeSponsoredCollectionRpcRow({
      'campaign_id': 'cmp_1',
      'seller_id': '00000000-0000-4000-8000-000000000001',
      'store_id': 'store_1',
      'collection_id': 'list_1',
      'title': 'Yaz Koleksiyonu',
      'cover_url': 'https://cdn.example/cover.jpg',
      'placement': 'home_feed',
      'starts_at': '2026-06-01T00:00:00.000Z',
      'ends_at': '2026-12-31T23:59:59.000Z',
    });

    final preview = HomeSponsoredContentService.previewListFromCampaign(campaign);
    expect(preview, isNotNull);
    expect(preview!.id, 'list_1');
    expect(preview.name, 'Yaz Koleksiyonu');
    expect(preview.iconUrl, 'https://cdn.example/cover.jpg');

    final resolved = HomeSponsoredContentService.resolveSponsoredPreviewLists(
      listIds: const ['list_1'],
      hydratedLists: const [],
      campaignByCollectionId: {'list_1': campaign},
    );
    expect(resolved, hasLength(1));
    expect(resolved.first.id, 'list_1');
  });
}
