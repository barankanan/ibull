import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/enums/ad_enums.dart';
import 'package:ibul_app/ads/models/ad_campaign.dart';
import 'package:ibul_app/ads/models/campaign_asset.dart';
import 'package:ibul_app/ads/models/campaign_target.dart';
import 'package:ibul_app/ads/services/home_sponsored_content_service.dart';

AdCampaign _campaign({
  required DateTime startsAt,
  required DateTime endsAt,
  List<AdPlacement> placements = const [AdPlacement.homeFeed],
  String entityId = 'list-1',
}) {
  return AdCampaign(
    id: 'camp-1',
    sellerId: 'seller-a',
    name: 'Test',
    type: AdCampaignType.collectionBoost,
    objective: CampaignObjective.collectionDiscovery,
    status: CampaignStatus.active,
    billingModel: BillingModel.cpc,
    dailyBudget: 100,
    totalBudget: 1000,
    currency: 'TRY',
    startsAt: startsAt,
    endsAt: endsAt,
    target: CampaignTarget(
      campaignId: 'camp-1',
      objective: CampaignObjective.collectionDiscovery,
      placements: placements,
    ),
    assets: [
      CampaignAsset(
        campaignId: 'camp-1',
        assetType: AdAssetType.collection,
        entityId: entityId,
        placements: placements,
      ),
    ],
  );
}

void main() {
  final now = DateTime.utc(2026, 6, 22, 12);

  group('HomeSponsoredContentService filters', () {
    test('isCampaignActiveNow accepts window containing reference UTC', () {
      final campaign = _campaign(
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 1)),
      );
      expect(
        HomeSponsoredContentService.isCampaignActiveNow(
          campaign,
          referenceUtc: now,
        ),
        isTrue,
      );
    });

    test('isCampaignActiveNow rejects expired campaign', () {
      final campaign = _campaign(
        startsAt: now.subtract(const Duration(days: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
      );
      expect(
        HomeSponsoredContentService.isCampaignActiveNow(
          campaign,
          referenceUtc: now,
        ),
        isFalse,
      );
    });

    test('isCampaignActiveNow rejects not-yet-started campaign', () {
      final campaign = _campaign(
        startsAt: now.add(const Duration(hours: 2)),
        endsAt: now.add(const Duration(days: 1)),
      );
      expect(
        HomeSponsoredContentService.isCampaignActiveNow(
          campaign,
          referenceUtc: now,
        ),
        isFalse,
      );
    });

    test('supportsPlacement matches homeFeed target', () {
      final campaign = _campaign(
        startsAt: now,
        endsAt: now.add(const Duration(days: 1)),
        placements: const [AdPlacement.homeFeed],
      );
      expect(
        HomeSponsoredContentService.supportsPlacement(
          campaign,
          AdPlacement.homeFeed,
        ),
        isTrue,
      );
      expect(
        HomeSponsoredContentService.supportsPlacement(
          campaign,
          AdPlacement.explore,
        ),
        isFalse,
      );
    });

    test('collectionId reads first asset entity id', () {
      final campaign = _campaign(
        startsAt: now,
        endsAt: now.add(const Duration(days: 1)),
        entityId: 'collection-42',
      );
      expect(HomeSponsoredContentService.collectionId(campaign), 'collection-42');
    });
  });
}
