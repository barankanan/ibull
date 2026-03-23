import '../enums/ad_enums.dart';

class CampaignPermissionResult {
  const CampaignPermissionResult({
    required this.allowed,
    required this.planTier,
    this.missingFeatures = const [],
    this.message,
  });

  final bool allowed;
  final SellerPlanTier planTier;
  final List<AdFeature> missingFeatures;
  final String? message;
}
