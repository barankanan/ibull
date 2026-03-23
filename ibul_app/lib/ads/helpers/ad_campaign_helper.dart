import '../constants/ads_defaults.dart';
import '../enums/ad_enums.dart';

class AdCampaignHelper {
  const AdCampaignHelper._();

  static List<AdCampaignType> supportedTypesForObjective(
    CampaignObjective objective,
  ) {
    switch (objective) {
      case CampaignObjective.productViews:
      case CampaignObjective.favorites:
      case CampaignObjective.addToCart:
      case CampaignObjective.orders:
        return const [
          AdCampaignType.productBoost,
          AdCampaignType.collectionBoost,
        ];
      case CampaignObjective.storeVisits:
        return const [AdCampaignType.storeBoost, AdCampaignType.geoPush];
      case CampaignObjective.collectionDiscovery:
        return const [AdCampaignType.collectionBoost];
      case CampaignObjective.driveNearbyTraffic:
        return const [AdCampaignType.geoPush];
    }
  }

  static List<AdCampaignType> recommendedTypesForObjective(
    CampaignObjective objective,
  ) {
    switch (objective) {
      case CampaignObjective.productViews:
      case CampaignObjective.favorites:
      case CampaignObjective.addToCart:
      case CampaignObjective.orders:
        return const [
          AdCampaignType.productBoost,
          AdCampaignType.collectionBoost,
        ];
      case CampaignObjective.storeVisits:
        return const [AdCampaignType.storeBoost, AdCampaignType.geoPush];
      case CampaignObjective.collectionDiscovery:
        return const [AdCampaignType.collectionBoost];
      case CampaignObjective.driveNearbyTraffic:
        return const [AdCampaignType.geoPush];
    }
  }

  static bool supportsTypeForObjective({
    required CampaignObjective objective,
    required AdCampaignType type,
  }) {
    return supportedTypesForObjective(objective).contains(type);
  }

  static List<AdPlacement> defaultPlacementsForType(AdCampaignType type) {
    switch (type) {
      case AdCampaignType.productBoost:
        return const [
          AdPlacement.homeFeed,
          AdPlacement.relatedProducts,
          AdPlacement.searchResults,
        ];
      case AdCampaignType.storeBoost:
        return const [
          AdPlacement.storeMap,
          AdPlacement.storeSearch,
          AdPlacement.storeList,
        ];
      case AdCampaignType.collectionBoost:
        return const [
          AdPlacement.homeFeed,
          AdPlacement.relatedProducts,
          AdPlacement.productDetail,
          AdPlacement.explore,
        ];
      case AdCampaignType.geoPush:
        return const [AdPlacement.pushNotification];
      case AdCampaignType.banner:
        return const [AdPlacement.bannerSlot];
      case AdCampaignType.categorySponsor:
        return const [AdPlacement.explore, AdPlacement.bannerSlot];
    }
  }

  static BillingModel defaultBillingModelForObjective(
    CampaignObjective objective,
  ) {
    switch (objective) {
      case CampaignObjective.orders:
        return BillingModel.cpa;
      case CampaignObjective.driveNearbyTraffic:
        return BillingModel.flat;
      case CampaignObjective.storeVisits:
      case CampaignObjective.collectionDiscovery:
      case CampaignObjective.productViews:
      case CampaignObjective.favorites:
      case CampaignObjective.addToCart:
        return BillingModel.cpc;
    }
  }

  static double suggestedDailyBudget({
    required CampaignObjective objective,
    required bool premiumPlacement,
  }) {
    final base = switch (objective) {
      CampaignObjective.productViews => 180,
      CampaignObjective.storeVisits => 220,
      CampaignObjective.collectionDiscovery => 160,
      CampaignObjective.favorites => 140,
      CampaignObjective.addToCart => 260,
      CampaignObjective.orders => 320,
      CampaignObjective.driveNearbyTraffic => 280,
    };
    return (premiumPlacement
            ? base * AdsDefaults.premiumPlacementMultiplier
            : base)
        .toDouble();
  }
}
