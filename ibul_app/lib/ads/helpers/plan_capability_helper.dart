import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/campaign_permission_result.dart';

class PlanCapabilityHelper {
  const PlanCapabilityHelper._();

  static const Map<SellerPlanTier, Set<AdFeature>> _featuresByPlan =
      <SellerPlanTier, Set<AdFeature>>{
        SellerPlanTier.free: <AdFeature>{AdFeature.collectionBoost},
        SellerPlanTier.boost: <AdFeature>{
          AdFeature.collectionBoost,
          AdFeature.productBoost,
          AdFeature.couponAds,
        },
        SellerPlanTier.pro: <AdFeature>{
          AdFeature.collectionBoost,
          AdFeature.productBoost,
          AdFeature.storeBoost,
          AdFeature.couponAds,
          AdFeature.advancedAnalytics,
          AdFeature.wideReach,
          AdFeature.premiumPlacement,
        },
        SellerPlanTier.premium: <AdFeature>{
          AdFeature.collectionBoost,
          AdFeature.productBoost,
          AdFeature.storeBoost,
          AdFeature.couponAds,
          AdFeature.advancedAnalytics,
          AdFeature.wideReach,
          AdFeature.premiumPlacement,
          AdFeature.geoFence,
          AdFeature.abTesting,
          AdFeature.heatmapAnalytics,
          AdFeature.advancedBidding,
        },
      };

  static Set<AdFeature> capabilities(SellerPlanTier tier) {
    return _featuresByPlan[tier] ?? const <AdFeature>{};
  }

  static bool canUseFeature({
    required SellerPlanTier tier,
    required AdFeature feature,
  }) {
    return capabilities(tier).contains(feature);
  }

  static CampaignPermissionResult checkCampaignPermission({
    required SellerPlanTier tier,
    required AdCampaign campaign,
  }) {
    final requiredFeatures = <AdFeature>{
      switch (campaign.type) {
        AdCampaignType.productBoost => AdFeature.productBoost,
        AdCampaignType.storeBoost => AdFeature.storeBoost,
        AdCampaignType.collectionBoost => AdFeature.collectionBoost,
        AdCampaignType.geoPush => AdFeature.geoFence,
        AdCampaignType.banner => AdFeature.wideReach,
        AdCampaignType.categorySponsor => AdFeature.advancedBidding,
      },
      if (campaign.abTestEnabled) AdFeature.abTesting,
      if (campaign.isPremiumPlacementEnabled) AdFeature.premiumPlacement,
      if (campaign.metadata['coupon_enabled'] == true) AdFeature.couponAds,
      if (campaign.target?.radiusMeters != null) AdFeature.geoFence,
    };

    final missing = requiredFeatures
        .where((feature) => !canUseFeature(tier: tier, feature: feature))
        .toList(growable: false);

    if (missing.isEmpty) {
      return CampaignPermissionResult(
        allowed: true,
        planTier: tier,
        message: 'Campaign features are allowed for this seller plan.',
      );
    }

    return CampaignPermissionResult(
      allowed: false,
      planTier: tier,
      missingFeatures: missing,
      message: 'Plan upgrade required for selected campaign capabilities.',
    );
  }

  static Map<String, dynamic> featureGate({
    required SellerPlanTier tier,
    required AdFeature feature,
  }) {
    return <String, dynamic>{
      'enabled': canUseFeature(tier: tier, feature: feature),
      'plan_tier': tier.dbValue,
      'feature': feature.dbValue,
      'upgrade_required': !canUseFeature(tier: tier, feature: feature),
    };
  }
}
