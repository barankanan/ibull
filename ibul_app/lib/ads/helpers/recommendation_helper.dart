import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/ad_insight.dart';
import '../models/ad_metrics.dart';
import '../models/user_product_event.dart';

class RecommendationHelper {
  const RecommendationHelper._();

  static List<AdInsight> buildRecommendations({
    required AdCampaign campaign,
    required AdMetrics metrics,
    required Iterable<UserProductEvent> events,
  }) {
    final recommendations = <AdInsight>[
      ...lowPerformanceDetector(campaign: campaign, metrics: metrics),
      ...budgetAlertHelper(campaign: campaign, metrics: metrics),
      ...opportunityDetector(
        campaign: campaign,
        metrics: metrics,
        events: events,
      ),
    ];
    return recommendations;
  }

  static List<AdInsight> lowPerformanceDetector({
    required AdCampaign campaign,
    required AdMetrics metrics,
  }) {
    final issues = <AdInsight>[];
    if (metrics.ctr < 0.012) {
      issues.add(
        AdInsight(
          id: '${campaign.id}-low-ctr',
          campaignId: campaign.id,
          title: 'Dusuk CTR',
          description: 'Bu kampanyanin tiklama orani beklentinin altinda.',
          value: metrics.ctr,
          deltaPercentage: -24,
          severity: 'warning',
          actionLabel: 'Gorsel ve CTA metnini yenile',
        ),
      );
    }
    if (metrics.conversionRate < 0.02) {
      issues.add(
        AdInsight(
          id: '${campaign.id}-low-conversion',
          campaignId: campaign.id,
          title: 'Dusuk donusum',
          description: 'Tiklamalar siparise yeterince donusmuyor.',
          value: metrics.conversionRate,
          deltaPercentage: -18,
          severity: 'critical',
          actionLabel: 'Retargeting ve kuponlu teklif aktiflestir',
        ),
      );
    }
    return issues;
  }

  static List<AdInsight> budgetAlertHelper({
    required AdCampaign campaign,
    required AdMetrics metrics,
  }) {
    final remaining = campaign.totalBudget - campaign.spentAmount;
    if (remaining > campaign.dailyBudget * 2) return const <AdInsight>[];
    return <AdInsight>[
      AdInsight(
        id: '${campaign.id}-budget-alert',
        campaignId: campaign.id,
        title: 'Butce bitmek uzere',
        description: 'Kampanya kalan butce ile kisa sure icinde durabilir.',
        value: remaining,
        deltaPercentage: -8,
        severity: 'watch',
        actionLabel: 'Butceyi yukselterek teslimi koru',
      ),
    ];
  }

  static List<AdInsight> opportunityDetector({
    required AdCampaign campaign,
    required AdMetrics metrics,
    required Iterable<UserProductEvent> events,
  }) {
    final suggestions = <AdInsight>[];
    final hourCounts = <int, int>{};
    for (final event in events) {
      hourCounts[event.createdAt.hour] =
          (hourCounts[event.createdAt.hour] ?? 0) + 1;
    }
    final bestHour = hourCounts.entries.isEmpty
        ? null
        : (hourCounts.entries.toList(
            growable: false,
          )..sort((a, b) => b.value.compareTo(a.value))).first.key;
    if (bestHour != null && bestHour >= 18) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-best-hour',
          campaignId: campaign.id,
          title: 'Aksam saatleri guclu',
          description: 'Etkilesim aksam saatlerinde daha yuksek gidiyor.',
          value: bestHour.toDouble(),
          deltaPercentage: 12,
          severity: 'good',
          actionLabel: 'Yayin planini 18:00 sonrasi agirlastir',
        ),
      );
    }
    if (campaign.type != AdCampaignType.collectionBoost &&
        metrics.collectionOpens > metrics.detailViews &&
        metrics.collectionOpens > 20) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-collection-opportunity',
          campaignId: campaign.id,
          title: 'Liste kampanyasi daha verimli olabilir',
          description: 'Liste etkilesimi urun detayina gore daha guclu.',
          value: metrics.collectionOpens.toDouble(),
          deltaPercentage: 16,
          severity: 'good',
          actionLabel: 'Liste one cikar testi yap',
        ),
      );
    }
    if (campaign.type == AdCampaignType.storeBoost &&
        metrics.storeVisits > 25) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-nearby-opportunity',
          campaignId: campaign.id,
          title: 'Yakin cevrede etkili',
          description:
              'Magaza kampanyasi yakin cevrede guclu performans veriyor.',
          value: metrics.storeVisits.toDouble(),
          deltaPercentage: 14,
          severity: 'good',
          actionLabel: 'Geofence teklifini ac',
        ),
      );
    }
    final stock = (campaign.metadata['stock'] as num?)?.toInt();
    if (stock != null && stock < 5) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-low-stock',
          campaignId: campaign.id,
          title: 'Dusuk stok',
          description: 'Stok azalmis urun icin agresif reklam onerilmez.',
          value: stock.toDouble(),
          deltaPercentage: -5,
          severity: 'warning',
          actionLabel: 'Butceyi daha guclu stoklu urune kaydir',
        ),
      );
    }
    return suggestions;
  }
}
