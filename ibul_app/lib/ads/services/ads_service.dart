import 'package:flutter/foundation.dart';

import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/ad_health_score.dart';
import '../models/ad_insight.dart';
import '../models/ad_metrics.dart';
import '../models/ad_placement_result.dart';
import '../models/ad_revenue_overview.dart';
import '../models/ads_dashboard_snapshot.dart';
import '../models/ad_wallet_transaction.dart';
import '../models/campaign_review.dart';
import '../models/sponsored_collection.dart';
import '../models/sponsored_product.dart';
import '../models/sponsored_store.dart';
import 'ad_metrics_service.dart';
import 'ad_ranking_service.dart';
import 'ad_revenue_service.dart';
import 'ad_wallet_service.dart';
import 'campaign_review_service.dart';
import 'campaign_service.dart';

class AdsService {
  AdsService({
    CampaignService? campaignService,
    CampaignReviewService? campaignReviewService,
    AdMetricsService? adMetricsService,
    AdRevenueService? adRevenueService,
    AdRankingService? adRankingService,
    AdWalletService? adWalletService,
  }) : _campaignService = campaignService ?? CampaignService(),
       _campaignReviewService =
           campaignReviewService ?? CampaignReviewService(),
       _adMetricsService = adMetricsService ?? AdMetricsService(),
       _adRevenueService = adRevenueService ?? AdRevenueService(),
       _adRankingService = adRankingService ?? AdRankingService(),
       _adWalletService = adWalletService ?? AdWalletService();

  final CampaignService _campaignService;
  final CampaignReviewService _campaignReviewService;
  final AdMetricsService _adMetricsService;
  final AdRevenueService _adRevenueService;
  final AdRankingService _adRankingService;
  final AdWalletService _adWalletService;

  String? _firstAssetMediaUrl(AdCampaign? campaign) {
    if (campaign == null || campaign.assets.isEmpty) {
      return null;
    }
    return campaign.assets.first.mediaUrl;
  }

  Future<T> _guardedLoad<T>({
    required String label,
    required Future<T> Function() action,
    required T fallback,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    debugPrint('AdsService $label started');
    try {
      final result = await action().timeout(timeout);
      debugPrint('AdsService $label finished');
      return result;
    } catch (error, stackTrace) {
      debugPrint('AdsService $label failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallback;
    }
  }

  Future<AdsDashboardSnapshot> getSellerDashboard({
    required String sellerId,
  }) async {
    final campaigns = await _campaignService.getCampaignsForSeller(sellerId);
    return _buildSnapshot(
      role: AdRole.seller,
      sellerId: sellerId,
      campaigns: campaigns,
      includeInsights: false,
      includeTopPlacementResults: false,
    );
  }

  Future<AdsDashboardSnapshot> getAdminDashboard() async {
    debugPrint('AdsService admin dashboard load started');
    final campaigns = await _guardedLoad<List<AdCampaign>>(
      label: 'admin campaigns load',
      action: _campaignService.getCampaignsForAdmin,
      fallback: const <AdCampaign>[],
      timeout: const Duration(seconds: 3),
    );
    debugPrint('AdsService campaigns loaded count=${campaigns.length}');
    final snapshot = await _buildSnapshot(
      role: AdRole.admin,
      campaigns: campaigns,
      includeInsights: false,
      includeTopPlacementResults: false,
      includeHealthScores: false,
    );
    debugPrint('AdsService load finished');
    return snapshot;
  }

  Future<List<AdPlacementResult>> getPlacementResults({
    required AdPlacement placement,
    String? userId,
    String? cityCode,
    double? latitude,
    double? longitude,
    int limit = 12,
  }) {
    return _adRankingService.rankPlacement(
      placement: placement,
      userId: userId,
      cityCode: cityCode,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
    );
  }

  Future<List<SponsoredProduct>> getSponsoredProducts({
    required AdPlacement placement,
    String? userId,
    String? cityCode,
    int limit = 12,
  }) async {
    final results = await getPlacementResults(
      placement: placement,
      userId: userId,
      cityCode: cityCode,
      limit: limit,
    );
    final campaigns = await _campaignService.getCampaignsForAdmin();
    final byId = {for (final campaign in campaigns) campaign.id: campaign};
    return results
        .where((item) => item.campaignType == AdCampaignType.productBoost)
        .map((item) {
          final campaign = byId[item.campaignId];
          return SponsoredProduct(
            campaignId: item.campaignId,
            productId: item.entityId ?? '',
            sellerId: campaign?.sellerId ?? '',
            score: item.score,
            bidAmount: item.bidAmount,
            boostFactor: campaign?.isPremiumPlacementEnabled == true ? 1.25 : 1,
            placements: [item.placement],
            label: campaign?.name,
            imageUrl: _firstAssetMediaUrl(campaign),
            metadata: item.metadata,
          );
        })
        .where((item) => item.productId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<SponsoredStore>> getSponsoredStores({
    required AdPlacement placement,
    String? userId,
    String? cityCode,
    int limit = 12,
  }) async {
    final results = await getPlacementResults(
      placement: placement,
      userId: userId,
      cityCode: cityCode,
      limit: limit,
    );
    final campaigns = await _campaignService.getCampaignsForAdmin();
    final byId = {for (final campaign in campaigns) campaign.id: campaign};
    return results
        .where((item) => item.campaignType == AdCampaignType.storeBoost)
        .map((item) {
          final campaign = byId[item.campaignId];
          return SponsoredStore(
            campaignId: item.campaignId,
            storeId: item.entityId ?? '',
            sellerId: campaign?.sellerId ?? '',
            score: item.score,
            bidAmount: item.bidAmount,
            boostFactor: campaign?.isPremiumPlacementEnabled == true ? 1.2 : 1,
            placements: [item.placement],
            headline: campaign?.name,
            logoUrl: _firstAssetMediaUrl(campaign),
            metadata: item.metadata,
          );
        })
        .where((item) => item.storeId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<SponsoredCollection>> getSponsoredCollections({
    required AdPlacement placement,
    String? userId,
    String? cityCode,
    int limit = 12,
  }) async {
    final results = await getPlacementResults(
      placement: placement,
      userId: userId,
      cityCode: cityCode,
      limit: limit,
    );
    final campaigns = await _campaignService.getCampaignsForAdmin();
    final byId = {for (final campaign in campaigns) campaign.id: campaign};
    return results
        .where((item) => item.campaignType == AdCampaignType.collectionBoost)
        .map((item) {
          final campaign = byId[item.campaignId];
          return SponsoredCollection(
            campaignId: item.campaignId,
            collectionId: item.entityId ?? '',
            sellerId: campaign?.sellerId ?? '',
            score: item.score,
            bidAmount: item.bidAmount,
            boostFactor: campaign?.isPremiumPlacementEnabled == true ? 1.2 : 1,
            placements: [item.placement],
            title: campaign?.name,
            coverUrl: _firstAssetMediaUrl(campaign),
            metadata: item.metadata,
          );
        })
        .where((item) => item.collectionId.isNotEmpty)
        .toList(growable: false);
  }

  Future<AdsDashboardSnapshot> _buildSnapshot({
    required AdRole role,
    required List<AdCampaign> campaigns,
    String? sellerId,
    bool includeInsights = true,
    bool includeTopPlacementResults = true,
    bool includeHealthScores = true,
  }) async {
    final campaignIds = campaigns
        .map((item) => item.id)
        .toList(growable: false);
    final emptyAggregate = AdMetrics(campaignId: 'all', date: DateTime.now());
    final emptyRevenue = AdRevenueOverview(
      totalRevenue: 0,
      todayRevenue: 0,
      weekRevenue: 0,
      monthRevenue: 0,
      pendingPayments: 0,
      approvedPayments: 0,
      refundedPayments: 0,
      walletTopUps: 0,
      currency: 'TRY',
      generatedAt: DateTime.now(),
    );

    final aggregateMetricsFuture = _guardedLoad<AdMetrics>(
      label: 'aggregate metrics load',
      action: () async {
        if (campaignIds.isEmpty) {
          return emptyAggregate;
        }
        return _adMetricsService.getAggregateMetrics(
          campaignIds: campaignIds,
          from: DateTime.now().subtract(const Duration(days: 30)),
        );
      },
      fallback: emptyAggregate,
    );
    final revenueFuture = _guardedLoad<AdRevenueOverview>(
      label: 'revenue load',
      action: () => _adRevenueService.getRevenueOverview(sellerId: sellerId),
      fallback: emptyRevenue,
    );
    final reviewsFuture = _guardedLoad<List<CampaignReview>>(
      label: 'reviews load',
      action: () async {
        if (role == AdRole.admin) {
          return _campaignReviewService.getPendingReviews();
        }
        final reviewLists = await Future.wait(
          campaignIds.map(_campaignReviewService.getCampaignReviews),
        );
        return reviewLists.expand((item) => item).toList(growable: false);
      },
      fallback: const <CampaignReview>[],
    );
    final walletTransactionsFuture = _guardedLoad<List<AdWalletTransaction>>(
      label: 'wallet load',
      action: () async {
        if (sellerId == null) {
          return const <AdWalletTransaction>[];
        }
        return _adWalletService.getTransactions(sellerId: sellerId);
      },
      fallback: const <AdWalletTransaction>[],
    );
    final topPlacementResultsFuture = _guardedLoad<List<AdPlacementResult>>(
      label: 'top placements load',
      action: () async {
        if (!includeTopPlacementResults) {
          return const <AdPlacementResult>[];
        }
        return _adRankingService.rankPlacement(
          placement: AdPlacement.homeFeed,
          limit: 8,
        );
      },
      fallback: const <AdPlacementResult>[],
    );
    final healthScoresFuture = _guardedLoad<List<AdHealthScore>>(
      label: 'health scores load',
      action: () async {
        if (!includeHealthScores) {
          return const <AdHealthScore>[];
        }
        return Future.wait(
          campaigns.map(
            (campaign) => _adMetricsService
                .getHealthScore(
                  campaignId: campaign.id,
                  isPendingReview:
                      campaign.status == CampaignStatus.pendingReview,
                )
                .timeout(const Duration(seconds: 2)),
          ),
        );
      },
      fallback: const <AdHealthScore>[],
    );
    final insightsFuture = _guardedLoad<List<AdInsight>>(
      label: 'insights load',
      action: () async {
        if (!includeInsights) {
          return const <AdInsight>[];
        }
        final insightLists = await Future.wait(
          campaigns.map(
            (campaign) => _adMetricsService.getInsights(campaignId: campaign.id),
          ),
        );
        return insightLists.expand((item) => item).toList(growable: false);
      },
      fallback: const <AdInsight>[],
    );

    final aggregateMetrics = await aggregateMetricsFuture;
    debugPrint('AdsService metrics loaded');
    final revenue = await revenueFuture;
    final reviews = await reviewsFuture;
    debugPrint('AdsService reviews loaded count=${reviews.length}');
    final walletTransactions = await walletTransactionsFuture;
    final topPlacementResults = await topPlacementResultsFuture;
    final healthScores = await healthScoresFuture;
    final insights = await insightsFuture;

    final snapshot = AdsDashboardSnapshot(
      role: role,
      sellerId: sellerId,
      campaigns: campaigns,
      aggregateMetrics: aggregateMetrics,
      insights: insights,
      healthScores: healthScores,
      revenueOverview: revenue,
      reviews: reviews,
      walletTransactions: walletTransactions,
      topPlacementResults: topPlacementResults,
      generatedAt: DateTime.now(),
    );
    debugPrint(
      'AdsService snapshot assembled role=${role.dbValue} campaigns=${campaigns.length} reviews=${reviews.length}',
    );
    return snapshot;
  }
}
