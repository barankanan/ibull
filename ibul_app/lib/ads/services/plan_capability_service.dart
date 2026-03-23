import '../enums/ad_enums.dart';
import '../helpers/plan_capability_helper.dart';
import '../models/ad_campaign.dart';
import '../models/campaign_permission_result.dart';

class PlanCapabilityService {
  const PlanCapabilityService();

  Set<AdFeature> getCapabilities(SellerPlanTier tier) {
    return PlanCapabilityHelper.capabilities(tier);
  }

  bool canUseFeature({
    required SellerPlanTier tier,
    required AdFeature feature,
  }) {
    return PlanCapabilityHelper.canUseFeature(tier: tier, feature: feature);
  }

  CampaignPermissionResult checkCampaignPermission({
    required SellerPlanTier tier,
    required AdCampaign campaign,
  }) {
    return PlanCapabilityHelper.checkCampaignPermission(
      tier: tier,
      campaign: campaign,
    );
  }

  Map<String, dynamic> featureGate({
    required SellerPlanTier tier,
    required AdFeature feature,
  }) {
    return PlanCapabilityHelper.featureGate(tier: tier, feature: feature);
  }
}
