import '../enums/ad_enums.dart';
import '../helpers/ad_metrics_helper.dart';
import '../helpers/funnel_helper.dart';
import '../models/ad_health_score.dart';
import '../models/ad_insight.dart';
import '../models/ad_metrics.dart';
import '../models/funnel_metrics.dart';
import '../models/user_product_event.dart';
import '../repositories/ads_repository.dart';

class AdMetricsService {
  AdMetricsService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<AdMetrics>> getDailyMetrics({
    List<String>? campaignIds,
    DateTime? from,
    DateTime? to,
  }) {
    return _repository.getMetrics(campaignIds: campaignIds, from: from, to: to);
  }

  Future<AdMetrics> getAggregateMetrics({
    List<String>? campaignIds,
    DateTime? from,
    DateTime? to,
  }) async {
    final items = await getDailyMetrics(
      campaignIds: campaignIds,
      from: from,
      to: to,
    );
    return AdMetricsHelper.merge(items);
  }

  Future<FunnelMetrics> getFunnelMetrics({
    required String campaignId,
    int windowDays = 30,
  }) async {
    final items = await getDailyMetrics(
      campaignIds: [campaignId],
      from: DateTime.now().subtract(Duration(days: windowDays)),
    );
    return AdMetricsHelper.buildFunnel(
      campaignId: campaignId,
      metrics: items,
      windowDays: windowDays,
    );
  }

  Future<AdHealthScore> getHealthScore({
    required String campaignId,
    bool isPendingReview = false,
  }) async {
    final items = await getDailyMetrics(
      campaignIds: [campaignId],
      from: DateTime.now().subtract(const Duration(days: 30)),
    );
    return AdMetricsHelper.buildHealthScore(
      campaignId: campaignId,
      metrics: items,
      isPendingReview: isPendingReview,
    );
  }

  Future<List<AdInsight>> getInsights({
    required String campaignId,
    int windowDays = 30,
  }) async {
    final items = await getDailyMetrics(
      campaignIds: [campaignId],
      from: DateTime.now().subtract(Duration(days: windowDays)),
    );
    return AdMetricsHelper.buildInsights(
      campaignId: campaignId,
      metrics: items,
    );
  }

  Future<Map<String, double>> getMetricSnapshot({
    required String campaignId,
    int windowDays = 30,
  }) async {
    final items = await getDailyMetrics(
      campaignIds: [campaignId],
      from: DateTime.now().subtract(Duration(days: windowDays)),
    );
    final merged = AdMetricsHelper.merge(items, campaignId: campaignId);
    return <String, double>{
      'ctr': FunnelHelper.ctr(merged),
      'cpc': FunnelHelper.cpc(merged),
      'cpm': FunnelHelper.cpm(merged),
      'conversion_rate': FunnelHelper.conversionRate(merged),
      'spend_progress': FunnelHelper.spendProgress(
        spent: merged.spend,
        totalBudget: merged.revenue == 0 ? merged.spend : merged.revenue,
      ),
      'remaining_budget': FunnelHelper.remainingBudget(
        totalBudget: merged.revenue == 0 ? merged.spend : merged.revenue,
        spent: merged.spend,
      ),
    };
  }

  Future<void> trackUserEvent(UserProductEvent event) async {
    await _repository.recordUserEvent(event);
    if (event.campaignId == null || event.campaignId!.isEmpty) return;

    final day = DateTime(
      event.createdAt.year,
      event.createdAt.month,
      event.createdAt.day,
    );
    final current = await _repository.getMetrics(
      campaignIds: [event.campaignId!],
      from: day,
      to: day.add(const Duration(days: 1)),
    );

    final base = current.isEmpty
        ? AdMetrics(campaignId: event.campaignId!, date: day)
        : current.first;

    final updated = base.copyWith(
      impressions:
          base.impressions +
          (event.eventType == UserEventType.impression ? 1 : 0),
      clicks: base.clicks + (event.eventType == UserEventType.click ? 1 : 0),
      detailViews:
          base.detailViews +
          (event.eventType == UserEventType.detailView ? 1 : 0),
      favorites:
          base.favorites + (event.eventType == UserEventType.favorite ? 1 : 0),
      addToCarts:
          base.addToCarts +
          (event.eventType == UserEventType.addToCart ? event.quantity : 0),
      checkouts:
          base.checkouts +
          (event.eventType == UserEventType.checkoutStarted
              ? event.quantity
              : 0),
      orders:
          base.orders +
          (event.eventType == UserEventType.purchase ? event.quantity : 0),
      storeVisits:
          base.storeVisits +
          (event.eventType == UserEventType.storeVisit ? 1 : 0),
      collectionOpens:
          base.collectionOpens +
          (event.eventType == UserEventType.collectionOpen ? 1 : 0),
      notificationsOpened:
          base.notificationsOpened +
          (event.eventType == UserEventType.notificationOpen ? 1 : 0),
      conversions:
          base.conversions +
          (event.eventType == UserEventType.purchase ? 1 : 0),
      uniqueUsers: base.uniqueUsers + 1,
    );
    await _repository.upsertDailyMetrics(updated);
  }
}
