import '../enums/ad_enums.dart';
import 'ad_campaign.dart';
import 'ad_health_score.dart';
import 'ad_insight.dart';
import 'ad_metrics.dart';
import 'ad_placement_result.dart';
import 'ad_revenue_overview.dart';
import 'ad_wallet_transaction.dart';
import 'campaign_review.dart';

class AdsDashboardSnapshot {
  const AdsDashboardSnapshot({
    required this.role,
    required this.campaigns,
    required this.aggregateMetrics,
    required this.insights,
    required this.healthScores,
    required this.revenueOverview,
    required this.reviews,
    required this.walletTransactions,
    required this.topPlacementResults,
    required this.generatedAt,
    this.sellerId,
  });

  final AdRole role;
  final String? sellerId;
  final List<AdCampaign> campaigns;
  final AdMetrics aggregateMetrics;
  final List<AdInsight> insights;
  final List<AdHealthScore> healthScores;
  final AdRevenueOverview revenueOverview;
  final List<CampaignReview> reviews;
  final List<AdWalletTransaction> walletTransactions;
  final List<AdPlacementResult> topPlacementResults;
  final DateTime generatedAt;
}
