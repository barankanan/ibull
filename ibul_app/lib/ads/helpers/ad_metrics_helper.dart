import '../models/ad_health_score.dart';
import '../models/ad_insight.dart';
import '../models/ad_metrics.dart';
import '../models/funnel_metrics.dart';
import 'ad_health_helper.dart';
import 'funnel_helper.dart';
import 'frequency_cap_helper.dart';

class AdMetricsHelper {
  const AdMetricsHelper._();

  static AdMetrics merge(
    Iterable<AdMetrics> items, {
    String campaignId = 'all',
  }) {
    var impressions = 0;
    var clicks = 0;
    var detailViews = 0;
    var favorites = 0;
    var addToCarts = 0;
    var checkouts = 0;
    var orders = 0;
    var storeVisits = 0;
    var collectionOpens = 0;
    var notificationsSent = 0;
    var notificationsOpened = 0;
    var uniqueUsers = 0;
    var conversions = 0;
    var spend = 0.0;
    var revenue = 0.0;

    for (final item in items) {
      impressions += item.impressions;
      clicks += item.clicks;
      detailViews += item.detailViews;
      favorites += item.favorites;
      addToCarts += item.addToCarts;
      checkouts += item.checkouts;
      orders += item.orders;
      storeVisits += item.storeVisits;
      collectionOpens += item.collectionOpens;
      notificationsSent += item.notificationsSent;
      notificationsOpened += item.notificationsOpened;
      uniqueUsers += item.uniqueUsers;
      conversions += item.conversions;
      spend += item.spend;
      revenue += item.revenue;
    }

    return AdMetrics(
      campaignId: campaignId,
      date: DateTime.now(),
      impressions: impressions,
      clicks: clicks,
      detailViews: detailViews,
      favorites: favorites,
      addToCarts: addToCarts,
      checkouts: checkouts,
      orders: orders,
      storeVisits: storeVisits,
      collectionOpens: collectionOpens,
      notificationsSent: notificationsSent,
      notificationsOpened: notificationsOpened,
      uniqueUsers: uniqueUsers,
      conversions: conversions,
      spend: spend,
      revenue: revenue,
    );
  }

  static FunnelMetrics buildFunnel({
    required String campaignId,
    required Iterable<AdMetrics> metrics,
    int windowDays = 30,
  }) {
    final merged = merge(metrics, campaignId: campaignId);
    return FunnelHelper.buildFunnel(
      campaignId: campaignId,
      metrics: merged,
      windowDays: windowDays,
    );
  }

  static AdHealthScore buildHealthScore({
    required String campaignId,
    required Iterable<AdMetrics> metrics,
    required bool isPendingReview,
  }) {
    final merged = merge(metrics, campaignId: campaignId);
    final fatigueScore = FrequencyCapHelper.adFatigueScore(
      metrics: merged,
      maxFrequencyCap: 3,
    );
    return AdHealthHelper.calculate(
      campaignId: campaignId,
      metrics: merged,
      isPendingReview: isPendingReview,
      fatigueScore: fatigueScore,
    );
  }

  static List<AdInsight> buildInsights({
    required String campaignId,
    required Iterable<AdMetrics> metrics,
  }) {
    final merged = merge(metrics, campaignId: campaignId);
    return [
      AdInsight(
        id: '$campaignId-ctr',
        campaignId: campaignId,
        title: 'CTR',
        description: 'Click-through rate health check',
        value: merged.ctr,
        deltaPercentage: (merged.ctr * 100) - 1.8,
        severity: merged.ctr >= 0.02 ? 'good' : 'watch',
        actionLabel: merged.ctr >= 0.02
            ? 'Scale winner creatives'
            : 'Refresh first image and CTA',
      ),
      AdInsight(
        id: '$campaignId-roas',
        campaignId: campaignId,
        title: 'ROAS',
        description: 'Spend to revenue efficiency',
        value: merged.roas,
        deltaPercentage: (merged.roas * 100) - 180,
        severity: merged.roas >= 2 ? 'good' : 'critical',
        actionLabel: merged.roas >= 2
            ? 'Increase budget gradually'
            : 'Tighten audience and retargeting window',
      ),
      AdInsight(
        id: '$campaignId-frequency',
        campaignId: campaignId,
        title: 'Frequency',
        description: 'Fatigue indicator for repeated delivery',
        value: FrequencyCapHelper.adFatigueScore(
          metrics: merged,
          maxFrequencyCap: 3,
        ),
        deltaPercentage: 0,
        severity: merged.frequencyProxy <= 2 ? 'good' : 'watch',
        actionLabel: merged.frequencyProxy <= 2
            ? 'Current cap is healthy'
            : 'Lower cap or rotate variants',
      ),
    ];
  }
}
