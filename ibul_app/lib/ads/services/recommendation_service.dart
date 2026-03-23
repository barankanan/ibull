import '../helpers/recommendation_helper.dart';
import '../models/ad_campaign.dart';
import '../models/ad_insight.dart';
import '../models/ad_metrics.dart';
import '../models/user_product_event.dart';
import '../repositories/ads_repository.dart';
import 'ad_metrics_service.dart';

class RecommendationService {
  RecommendationService({
    AdsRepository? repository,
    AdMetricsService? metricsService,
  }) : _repository = repository ?? AdsRepository(),
       _metricsService =
           metricsService ?? AdMetricsService(repository: repository);

  final AdsRepository _repository;
  final AdMetricsService _metricsService;

  Future<List<AdInsight>> buildCampaignRecommendations(
    AdCampaign campaign,
  ) async {
    final metrics = await _metricsService.getAggregateMetrics(
      campaignIds: [campaign.id],
      from: DateTime.now().subtract(const Duration(days: 30)),
    );
    final events = await _repository.getUserEvents(
      from: DateTime.now().subtract(const Duration(days: 30)),
    );
    final relatedEvents = events
        .where((event) {
          return event.campaignId == campaign.id ||
              campaign.assets.any(
                (asset) =>
                    asset.entityId == event.productId ||
                    asset.entityId == event.storeId ||
                    asset.entityId == event.collectionId,
              );
        })
        .toList(growable: false);
    return RecommendationHelper.buildRecommendations(
      campaign: campaign,
      metrics: metrics,
      events: relatedEvents,
    );
  }

  List<AdInsight> lowPerformanceDetector({
    required AdCampaign campaign,
    required AdMetrics metrics,
  }) {
    return RecommendationHelper.lowPerformanceDetector(
      campaign: campaign,
      metrics: metrics,
    );
  }

  List<AdInsight> budgetAlertHelper({
    required AdCampaign campaign,
    required AdMetrics metrics,
  }) {
    return RecommendationHelper.budgetAlertHelper(
      campaign: campaign,
      metrics: metrics,
    );
  }

  List<AdInsight> opportunityDetector({
    required AdCampaign campaign,
    required AdMetrics metrics,
    required Iterable<UserProductEvent> events,
  }) {
    return RecommendationHelper.opportunityDetector(
      campaign: campaign,
      metrics: metrics,
      events: events,
    );
  }
}
