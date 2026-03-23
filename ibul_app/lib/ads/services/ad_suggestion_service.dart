import '../enums/ad_enums.dart';
import '../helpers/ad_campaign_helper.dart';
import '../helpers/coupon_offer_helper.dart';
import '../helpers/recommendation_helper.dart';
import '../models/ad_campaign.dart';
import '../models/ad_insight.dart';
import '../models/ad_metrics.dart';
import '../models/user_product_event.dart';

class AdSuggestionService {
  const AdSuggestionService();

  List<AdCampaignType> recommendTypes(CampaignObjective objective) {
    return AdCampaignHelper.recommendedTypesForObjective(objective);
  }

  List<AdPlacement> recommendPlacements(AdCampaignType type) {
    return AdCampaignHelper.defaultPlacementsForType(type);
  }

  double suggestDailyBudget({
    required CampaignObjective objective,
    bool premiumPlacement = false,
  }) {
    return AdCampaignHelper.suggestedDailyBudget(
      objective: objective,
      premiumPlacement: premiumPlacement,
    );
  }

  List<AdInsight> buildSetupSuggestions(AdCampaign campaign) {
    final suggestions = <AdInsight>[];
    if (!campaign.isPremiumPlacementEnabled &&
        campaign.objective == CampaignObjective.orders) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-premium',
          campaignId: campaign.id,
          title: 'Premium placement',
          description:
              'Order-focused campaigns usually benefit from premium slots.',
          value: 1,
          deltaPercentage: 14,
          severity: 'watch',
          actionLabel: 'Enable premium delivery',
        ),
      );
    }
    if ((campaign.target?.keywords.length ?? 0) < 3) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-keywords',
          campaignId: campaign.id,
          title: 'Audience depth',
          description:
              'More keywords improve semantic targeting and AI matching.',
          value: (campaign.target?.keywords.length ?? 0).toDouble(),
          deltaPercentage: 0,
          severity: 'watch',
          actionLabel: 'Add at least 3 intent keywords',
        ),
      );
    }
    if (campaign.assets.length < 2) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-creative',
          campaignId: campaign.id,
          title: 'Creative rotation',
          description: 'A/B testing performs better with at least two assets.',
          value: campaign.assets.length.toDouble(),
          deltaPercentage: 0,
          severity: 'watch',
          actionLabel: 'Add another creative asset',
        ),
      );
    }
    return suggestions;
  }

  List<AdInsight> buildPerformanceSuggestions({
    required AdCampaign campaign,
    required AdMetrics metrics,
    required Iterable<UserProductEvent> recentEvents,
  }) {
    final suggestions = RecommendationHelper.buildRecommendations(
      campaign: campaign,
      metrics: metrics,
      events: recentEvents,
    ).toList(growable: true);
    if (CouponOfferHelper.isEligible(
      campaign: campaign,
      events: recentEvents,
    )) {
      suggestions.add(
        AdInsight(
          id: '${campaign.id}-coupon-opportunity',
          campaignId: campaign.id,
          title: 'Kuponlu reklam firsati',
          description:
              'Bu kampanya icin kuponlu teklif donusumu yukseltebilir.',
          value: 1,
          deltaPercentage: 9,
          severity: 'good',
          actionLabel: 'Ozel teklifi yayina al',
        ),
      );
    }
    return suggestions;
  }
}
