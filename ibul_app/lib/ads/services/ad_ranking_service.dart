import '../enums/ad_enums.dart';
import '../helpers/ad_metrics_helper.dart';
import '../helpers/frequency_cap_helper.dart';
import '../helpers/ranking_engine_helper.dart';
import '../helpers/user_interest_engine_helper.dart';
import '../models/ad_campaign.dart';
import '../models/ad_metrics.dart';
import '../models/ad_placement_result.dart';
import '../models/placement_mix_item.dart';
import '../models/user_interest.dart';
import '../models/user_product_event.dart';
import '../repositories/ads_repository.dart';

class AdRankingService {
  AdRankingService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<AdPlacementResult>> rankPlacement({
    required AdPlacement placement,
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) async {
    final campaigns = await _repository.getCampaigns(
      statuses: const [
        CampaignStatus.active,
        CampaignStatus.approved,
        CampaignStatus.scheduled,
      ],
      limit: 120,
    );
    final campaignIds = campaigns
        .map((item) => item.id)
        .toList(growable: false);
    final metrics = await _repository.getMetrics(
      campaignIds: campaignIds,
      from: DateTime.now().subtract(const Duration(days: 30)),
    );
    final interests = userId == null
        ? const <UserInterest>[]
        : await _repository.getUserInterests(userId: userId);
    final events = userId == null
        ? const <UserProductEvent>[]
        : await _repository.getUserEvents(
            userId: userId,
            from: DateTime.now().subtract(const Duration(days: 14)),
          );
    final inferredInterests = userId == null
        ? interests
        : UserInterestEngineHelper.buildInterestProfile(
            userId: userId,
            events: events,
            existing: interests,
          );

    final metricsByCampaign = <String, List<AdMetrics>>{};
    for (final metric in metrics) {
      metricsByCampaign
          .putIfAbsent(metric.campaignId, () => <AdMetrics>[])
          .add(metric);
    }

    final results = <AdPlacementResult>[];
    final recentlySeen = FrequencyCapHelper.recentlySeenEntityIds(events);
    for (final campaign in campaigns) {
      if (!_supportsPlacement(campaign, placement)) continue;

      final aggregated = AdMetricsHelper.merge(
        metricsByCampaign[campaign.id] ?? const [],
        campaignId: campaign.id,
      );
      final result = RankingEngineHelper.scorePlacement(
        campaign: campaign,
        placement: placement,
        metrics: aggregated,
        interests: inferredInterests,
        events: events,
        assetResolver: _resolveAsset,
        cityCode: cityCode,
        latitude: latitude,
        longitude: longitude,
      );
      if (recentlySeen.contains(result.entityId)) continue;
      if (!_passesFrequencyCap(campaign, events)) continue;
      results.add(result);
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    if (results.length <= limit) return results;
    return results.take(limit).toList(growable: false);
  }

  Future<List<AdPlacementResult>> rankHomeSponsored({
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) {
    return rankPlacement(
      placement: AdPlacement.homeFeed,
      userId: userId,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  Future<List<AdPlacementResult>> rankRelatedProducts({
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) {
    return rankPlacement(
      placement: AdPlacement.relatedProducts,
      userId: userId,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  Future<List<AdPlacementResult>> rankSearchSponsored({
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) {
    return rankPlacement(
      placement: AdPlacement.searchResults,
      userId: userId,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  Future<List<AdPlacementResult>> rankMapStores({
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) {
    return rankPlacement(
      placement: AdPlacement.storeMap,
      userId: userId,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  Future<List<AdPlacementResult>> rankCollections({
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) {
    return rankPlacement(
      placement: AdPlacement.explore,
      userId: userId,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  List<PlacementMixItem> mixSponsoredWithOrganic({
    required List<AdPlacementResult> sponsored,
    required List<String> organicEntityIds,
  }) {
    return RankingEngineHelper.mixSponsoredWithOrganic(
      sponsored: sponsored,
      organicEntityIds: organicEntityIds,
    );
  }

  bool _supportsPlacement(AdCampaign campaign, AdPlacement placement) {
    final targetPlacements = campaign.target?.placements ?? const [];
    final assetPlacements = campaign.assets.expand((item) => item.placements);
    if (targetPlacements.isEmpty && assetPlacements.isEmpty) return true;
    return targetPlacements.contains(placement) ||
        assetPlacements.contains(placement);
  }

  bool _passesFrequencyCap(AdCampaign campaign, List<UserProductEvent> events) {
    return FrequencyCapHelper.isWithinCampaignCap(
      campaignId: campaign.id,
      events: events,
      maxPerDay:
          campaign.target?.frequencyCapPerDay ?? campaign.frequencyCapPerUser,
    );
  }

  dynamic _resolveAsset(AdCampaign campaign, AdPlacement placement) {
    if (campaign.assets.isEmpty) {
      return null;
    }
    for (final asset in campaign.assets) {
      if (asset.placements.isEmpty || asset.placements.contains(placement)) {
        return asset;
      }
    }
    return campaign.assets.first;
  }
}
