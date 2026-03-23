import 'package:geolocator/geolocator.dart';

import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/ad_metrics.dart';
import '../models/ad_placement_result.dart';
import '../models/placement_mix_item.dart';
import '../models/user_interest.dart';
import '../models/user_product_event.dart';
import 'frequency_cap_helper.dart';
import 'user_interest_engine_helper.dart';

class RankingEngineHelper {
  const RankingEngineHelper._();

  static AdPlacementResult scorePlacement({
    required AdCampaign campaign,
    required AdPlacement placement,
    required AdMetrics metrics,
    required List<UserInterest> interests,
    required List<UserProductEvent> events,
    required CampaignAssetResolver assetResolver,
    String? cityCode,
    double? latitude,
    double? longitude,
  }) {
    final asset = assetResolver(campaign, placement);
    final entityId = asset?.entityId;
    final entityEvents = events
        .where((event) {
          return event.productId == entityId ||
              event.storeId == entityId ||
              event.collectionId == entityId;
        })
        .toList(growable: false);

    final sponsoredWeight = _sponsoredWeight(campaign);
    final relevanceWeight = _relevanceWeight(campaign, interests, entityEvents);
    final qualityWeight = _qualityWeight(campaign, asset);
    final distanceWeight = _distanceWeight(
      campaign,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
    );
    final performanceWeight = _performanceWeight(metrics);
    final conversionProbability = _conversionProbability(
      campaign: campaign,
      metrics: metrics,
      entityEvents: entityEvents,
    );
    final fatiguePenalty = _fatiguePenalty(
      campaign: campaign,
      metrics: metrics,
    );

    final finalScore =
        sponsoredWeight +
        relevanceWeight +
        qualityWeight +
        distanceWeight +
        performanceWeight +
        conversionProbability -
        fatiguePenalty;

    return AdPlacementResult(
      placement: placement,
      campaignId: campaign.id,
      campaignType: campaign.type,
      score: finalScore,
      reason: _reason(
        sponsoredWeight: sponsoredWeight,
        relevanceWeight: relevanceWeight,
        qualityWeight: qualityWeight,
        distanceWeight: distanceWeight,
        performanceWeight: performanceWeight,
        conversionProbability: conversionProbability,
      ),
      assetId: asset?.id,
      entityId: entityId,
      bidAmount: campaign.bidAmount,
      estimatedCtr: metrics.ctr,
      estimatedConversionRate: metrics.conversionRate,
      isRetargeted: entityEvents.isNotEmpty,
      isGeoMatched: distanceWeight > 0,
      sponsoredWeight: sponsoredWeight,
      relevanceWeight: relevanceWeight,
      qualityWeight: qualityWeight,
      distanceWeight: distanceWeight,
      performanceWeight: performanceWeight,
      conversionProbability: conversionProbability,
      fatiguePenalty: fatiguePenalty,
      metadata: <String, dynamic>{
        'campaign_name': campaign.name,
        'seller_id': campaign.sellerId,
        'organic_balance_guard': _organicBalanceGuard(metrics),
      },
    );
  }

  static List<AdPlacementResult> homeSponsoredRanking(
    Iterable<AdPlacementResult> results,
  ) {
    return _rankForPlacement(results, AdPlacement.homeFeed);
  }

  static List<AdPlacementResult> relatedProductRanking(
    Iterable<AdPlacementResult> results,
  ) {
    return _rankForPlacement(results, AdPlacement.relatedProducts);
  }

  static List<AdPlacementResult> searchSponsoredRanking(
    Iterable<AdPlacementResult> results,
  ) {
    return _rankForPlacement(results, AdPlacement.searchResults);
  }

  static List<AdPlacementResult> mapStoreRanking(
    Iterable<AdPlacementResult> results,
  ) {
    return _rankForPlacement(results, AdPlacement.storeMap);
  }

  static List<AdPlacementResult> collectionRanking(
    Iterable<AdPlacementResult> results,
  ) {
    return _rankForPlacement(results, AdPlacement.explore);
  }

  static List<PlacementMixItem> mixSponsoredWithOrganic({
    required Iterable<AdPlacementResult> sponsored,
    required Iterable<String> organicEntityIds,
    int maxConsecutiveSponsored = 2,
  }) {
    final sponsoredQueue = sponsored.toList(growable: false);
    final organicQueue = organicEntityIds.toList(growable: false);
    final mixed = <PlacementMixItem>[];
    var sponsoredIndex = 0;
    var organicIndex = 0;

    while (sponsoredIndex < sponsoredQueue.length ||
        organicIndex < organicQueue.length) {
      for (
        var count = 0;
        count < maxConsecutiveSponsored &&
            sponsoredIndex < sponsoredQueue.length;
        count += 1
      ) {
        final item = sponsoredQueue[sponsoredIndex];
        if ((item.metadata['organic_balance_guard'] as bool?) == true &&
            organicIndex < organicQueue.length) {
          break;
        }
        mixed.add(
          PlacementMixItem(
            entityId: item.entityId ?? item.campaignId,
            isSponsored: true,
            campaignId: item.campaignId,
            score: item.score,
            metadata: item.metadata,
          ),
        );
        sponsoredIndex += 1;
      }
      if (organicIndex < organicQueue.length) {
        mixed.add(
          PlacementMixItem(
            entityId: organicQueue[organicIndex],
            isSponsored: false,
          ),
        );
        organicIndex += 1;
      } else if (sponsoredIndex < sponsoredQueue.length) {
        final item = sponsoredQueue[sponsoredIndex];
        mixed.add(
          PlacementMixItem(
            entityId: item.entityId ?? item.campaignId,
            isSponsored: true,
            campaignId: item.campaignId,
            score: item.score,
            metadata: item.metadata,
          ),
        );
        sponsoredIndex += 1;
      }
    }

    return mixed;
  }

  static List<AdPlacementResult> _rankForPlacement(
    Iterable<AdPlacementResult> results,
    AdPlacement placement,
  ) {
    return results
        .where((result) => result.placement == placement)
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  static double _sponsoredWeight(AdCampaign campaign) {
    final bidWeight = (campaign.bidAmount / 10).clamp(0.0, 1.2);
    final premiumWeight = campaign.isPremiumPlacementEnabled ? 0.35 : 0.0;
    final typeWeight = switch (campaign.type) {
      AdCampaignType.productBoost => 0.35,
      AdCampaignType.storeBoost => 0.28,
      AdCampaignType.collectionBoost => 0.24,
      AdCampaignType.geoPush => 0.3,
      AdCampaignType.banner => 0.2,
      AdCampaignType.categorySponsor => 0.32,
    };
    return bidWeight + premiumWeight + typeWeight;
  }

  static double _relevanceWeight(
    AdCampaign campaign,
    List<UserInterest> interests,
    List<UserProductEvent> entityEvents,
  ) {
    final campaignKeys = <String>{
      ...?campaign.target?.categories,
      ...?campaign.target?.keywords,
    };
    final interestScore = UserInterestEngineHelper.computeRelevanceScore(
      campaignKeys: campaignKeys,
      interests: interests,
    );
    final retargetingBoost = entityEvents.isNotEmpty ? 0.25 : 0.0;
    return (interestScore * 1.1) + retargetingBoost;
  }

  static double _qualityWeight(AdCampaign campaign, dynamic asset) {
    final metadataScore =
        ((campaign.metadata['quality_score'] as num?)?.toDouble() ?? 0.72)
            .clamp(0.0, 1.0);
    final assetDepth = (campaign.assets.length / 3).clamp(0.0, 1.0);
    final priorityBonus = asset == null
        ? 0.0
        : ((asset.priority as int) / 10).clamp(0.0, 0.2);
    return (metadataScore * 0.8) + (assetDepth * 0.2) + priorityBonus;
  }

  static double _distanceWeight(
    AdCampaign campaign, {
    String? cityCode,
    double? latitude,
    double? longitude,
  }) {
    final targetCities = campaign.target?.cityCodes ?? const <String>[];
    final cityScore = cityCode != null && targetCities.contains(cityCode)
        ? 0.3
        : 0.0;
    final storeLatitude = (campaign.metadata['store_latitude'] as num?)
        ?.toDouble();
    final storeLongitude = (campaign.metadata['store_longitude'] as num?)
        ?.toDouble();
    if (latitude == null ||
        longitude == null ||
        storeLatitude == null ||
        storeLongitude == null) {
      return cityScore;
    }
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      storeLatitude,
      storeLongitude,
    );
    final radius = (campaign.target?.radiusMeters ?? 5000).toDouble();
    final proximity = (1 - (distance / radius)).clamp(0.0, 1.0);
    return cityScore + (proximity * 0.4);
  }

  static double _performanceWeight(AdMetrics metrics) {
    return ((metrics.ctr * 6) +
            (metrics.conversionRate * 8) +
            (metrics.roas * 0.18))
        .clamp(0.0, 1.7);
  }

  static double _conversionProbability({
    required AdCampaign campaign,
    required AdMetrics metrics,
    required List<UserProductEvent> entityEvents,
  }) {
    final objectiveBoost = switch (campaign.objective) {
      CampaignObjective.orders => 0.35,
      CampaignObjective.addToCart => 0.24,
      CampaignObjective.productViews => 0.12,
      CampaignObjective.storeVisits => 0.18,
      CampaignObjective.collectionDiscovery => 0.16,
      CampaignObjective.favorites => 0.14,
      CampaignObjective.driveNearbyTraffic => 0.2,
    };
    final behaviorBoost =
        entityEvents.any((event) => event.eventType.dbValue == 'add_to_cart')
        ? 0.22
        : entityEvents.any((event) => event.eventType.dbValue == 'detail_view')
        ? 0.12
        : 0.0;
    return (objectiveBoost + behaviorBoost + (metrics.conversionRate * 4))
        .clamp(0.0, 1.3);
  }

  static double _fatiguePenalty({
    required AdCampaign campaign,
    required AdMetrics metrics,
  }) {
    return FrequencyCapHelper.adFatigueScore(
      metrics: metrics,
      maxFrequencyCap: campaign.frequencyCapPerUser,
    );
  }

  static bool _organicBalanceGuard(AdMetrics metrics) {
    return metrics.ctr < 0.01 || metrics.frequencyProxy > 2.8;
  }

  static String _reason({
    required double sponsoredWeight,
    required double relevanceWeight,
    required double qualityWeight,
    required double distanceWeight,
    required double performanceWeight,
    required double conversionProbability,
  }) {
    final components = <String, double>{
      'Sponsored advantage': sponsoredWeight,
      'Audience relevance': relevanceWeight,
      'Creative quality': qualityWeight,
      'Distance fit': distanceWeight,
      'Performance momentum': performanceWeight,
      'Conversion signal': conversionProbability,
    };
    final top = components.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return top.first.key;
  }
}

typedef CampaignAssetResolver =
    dynamic Function(AdCampaign campaign, AdPlacement placement);
