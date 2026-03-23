enum AdRole {
  seller,
  admin;

  String get dbValue => switch (this) {
    AdRole.seller => 'seller',
    AdRole.admin => 'admin',
  };
}

enum AdCampaignType {
  productBoost,
  storeBoost,
  collectionBoost,
  geoPush,
  banner,
  categorySponsor;

  String get dbValue => switch (this) {
    AdCampaignType.productBoost => 'product_boost',
    AdCampaignType.storeBoost => 'store_boost',
    AdCampaignType.collectionBoost => 'collection_boost',
    AdCampaignType.geoPush => 'geo_push',
    AdCampaignType.banner => 'banner',
    AdCampaignType.categorySponsor => 'category_sponsor',
  };
}

enum CampaignObjective {
  productViews,
  storeVisits,
  collectionDiscovery,
  favorites,
  addToCart,
  orders,
  driveNearbyTraffic;

  String get dbValue => switch (this) {
    CampaignObjective.productViews => 'product_views',
    CampaignObjective.storeVisits => 'store_visits',
    CampaignObjective.collectionDiscovery => 'collection_discovery',
    CampaignObjective.favorites => 'favorites',
    CampaignObjective.addToCart => 'add_to_cart',
    CampaignObjective.orders => 'orders',
    CampaignObjective.driveNearbyTraffic => 'drive_nearby_traffic',
  };
}

enum CampaignStatus {
  draft,
  pendingReview,
  approved,
  scheduled,
  active,
  paused,
  completed,
  rejected,
  stopped,
  archived;

  String get dbValue => switch (this) {
    CampaignStatus.draft => 'draft',
    CampaignStatus.pendingReview => 'pending_review',
    CampaignStatus.approved => 'approved',
    CampaignStatus.scheduled => 'scheduled',
    CampaignStatus.active => 'active',
    CampaignStatus.paused => 'paused',
    CampaignStatus.completed => 'completed',
    CampaignStatus.rejected => 'rejected',
    CampaignStatus.stopped => 'stopped',
    CampaignStatus.archived => 'archived',
  };
}

enum CampaignReviewStatus {
  pending,
  approved,
  rejected,
  changesRequested;

  String get dbValue => switch (this) {
    CampaignReviewStatus.pending => 'pending',
    CampaignReviewStatus.approved => 'approved',
    CampaignReviewStatus.rejected => 'rejected',
    CampaignReviewStatus.changesRequested => 'changes_requested',
  };
}

enum AdAssetType {
  product,
  store,
  collection,
  image,
  video,
  notification,
  deeplink;

  String get dbValue => switch (this) {
    AdAssetType.product => 'product',
    AdAssetType.store => 'store',
    AdAssetType.collection => 'collection',
    AdAssetType.image => 'image',
    AdAssetType.video => 'video',
    AdAssetType.notification => 'notification',
    AdAssetType.deeplink => 'deeplink',
  };
}

enum AdPlacement {
  homeFeed,
  relatedProducts,
  searchResults,
  storeMap,
  storeSearch,
  storeList,
  productDetail,
  explore,
  pushNotification,
  recommendationCarousel,
  bannerSlot;

  String get dbValue => switch (this) {
    AdPlacement.homeFeed => 'home_feed',
    AdPlacement.relatedProducts => 'related_products',
    AdPlacement.searchResults => 'search_results',
    AdPlacement.storeMap => 'store_map',
    AdPlacement.storeSearch => 'store_search',
    AdPlacement.storeList => 'store_list',
    AdPlacement.productDetail => 'product_detail',
    AdPlacement.explore => 'explore',
    AdPlacement.pushNotification => 'push_notification',
    AdPlacement.recommendationCarousel => 'recommendation_carousel',
    AdPlacement.bannerSlot => 'banner_slot',
  };
}

enum BillingModel {
  cpc,
  cpm,
  cpa,
  flat,
  walletDebit;

  String get dbValue => switch (this) {
    BillingModel.cpc => 'cpc',
    BillingModel.cpm => 'cpm',
    BillingModel.cpa => 'cpa',
    BillingModel.flat => 'flat',
    BillingModel.walletDebit => 'wallet_debit',
  };
}

enum UserEventType {
  impression,
  click,
  detailView,
  favorite,
  addToCart,
  checkoutStarted,
  purchase,
  storeVisit,
  collectionOpen,
  notificationOpen,
  geoEnter;

  String get dbValue => switch (this) {
    UserEventType.impression => 'impression',
    UserEventType.click => 'click',
    UserEventType.detailView => 'detail_view',
    UserEventType.favorite => 'favorite',
    UserEventType.addToCart => 'add_to_cart',
    UserEventType.checkoutStarted => 'checkout_started',
    UserEventType.purchase => 'purchase',
    UserEventType.storeVisit => 'store_visit',
    UserEventType.collectionOpen => 'collection_open',
    UserEventType.notificationOpen => 'notification_open',
    UserEventType.geoEnter => 'geo_enter',
  };
}

enum GeoTriggerType {
  radiusEntry,
  repeatVisit,
  wishlistNearby,
  abandonedCartNearby;

  String get dbValue => switch (this) {
    GeoTriggerType.radiusEntry => 'radius_entry',
    GeoTriggerType.repeatVisit => 'repeat_visit',
    GeoTriggerType.wishlistNearby => 'wishlist_nearby',
    GeoTriggerType.abandonedCartNearby => 'abandoned_cart_nearby',
  };
}

enum WalletTransactionType {
  topUp,
  hold,
  spend,
  refund,
  adjustment,
  bonusCredit;

  String get dbValue => switch (this) {
    WalletTransactionType.topUp => 'top_up',
    WalletTransactionType.hold => 'hold',
    WalletTransactionType.spend => 'spend',
    WalletTransactionType.refund => 'refund',
    WalletTransactionType.adjustment => 'adjustment',
    WalletTransactionType.bonusCredit => 'bonus_credit',
  };
}

enum WalletTransactionStatus {
  pending,
  succeeded,
  failed,
  refunded;

  String get dbValue => switch (this) {
    WalletTransactionStatus.pending => 'pending',
    WalletTransactionStatus.succeeded => 'succeeded',
    WalletTransactionStatus.failed => 'failed',
    WalletTransactionStatus.refunded => 'refunded',
  };
}

enum RetargetingSegment {
  viewedNotPurchased,
  cartAbandoned,
  storeVisitedNoOrder,
  collectionViewedNoClick,
  active7d,
  passive30d,
  highCartValue,
  frequentBuyer;

  String get dbValue => switch (this) {
    RetargetingSegment.viewedNotPurchased => 'viewed_not_purchased',
    RetargetingSegment.cartAbandoned => 'cart_abandoned',
    RetargetingSegment.storeVisitedNoOrder => 'store_visited_no_order',
    RetargetingSegment.collectionViewedNoClick => 'collection_viewed_no_click',
    RetargetingSegment.active7d => 'active_7d',
    RetargetingSegment.passive30d => 'passive_30d',
    RetargetingSegment.highCartValue => 'high_cart_value',
    RetargetingSegment.frequentBuyer => 'frequent_buyer',
  };
}

enum SellerPlanTier {
  free,
  boost,
  pro,
  premium;

  String get dbValue => switch (this) {
    SellerPlanTier.free => 'free',
    SellerPlanTier.boost => 'boost',
    SellerPlanTier.pro => 'pro',
    SellerPlanTier.premium => 'premium',
  };
}

enum AdFeature {
  productBoost,
  storeBoost,
  collectionBoost,
  geoFence,
  abTesting,
  advancedAnalytics,
  wideReach,
  premiumPlacement,
  couponAds,
  heatmapAnalytics,
  advancedBidding;

  String get dbValue => switch (this) {
    AdFeature.productBoost => 'product_boost',
    AdFeature.storeBoost => 'store_boost',
    AdFeature.collectionBoost => 'collection_boost',
    AdFeature.geoFence => 'geo_fence',
    AdFeature.abTesting => 'ab_testing',
    AdFeature.advancedAnalytics => 'advanced_analytics',
    AdFeature.wideReach => 'wide_reach',
    AdFeature.premiumPlacement => 'premium_placement',
    AdFeature.couponAds => 'coupon_ads',
    AdFeature.heatmapAnalytics => 'heatmap_analytics',
    AdFeature.advancedBidding => 'advanced_bidding',
  };
}

extension AdRoleParser on AdRole {
  static AdRole fromDbValue(String? value) => _enumFromDbValue(
    AdRole.values,
    value,
    (item) => item.dbValue,
    AdRole.seller,
  );
}

extension AdCampaignTypeParser on AdCampaignType {
  static AdCampaignType fromDbValue(String? value) => _enumFromDbValue(
    AdCampaignType.values,
    value,
    (item) => item.dbValue,
    AdCampaignType.productBoost,
  );
}

extension CampaignObjectiveParser on CampaignObjective {
  static CampaignObjective fromDbValue(String? value) => _enumFromDbValue(
    CampaignObjective.values,
    value,
    (item) => item.dbValue,
    CampaignObjective.productViews,
  );
}

extension CampaignStatusParser on CampaignStatus {
  static CampaignStatus fromDbValue(String? value) => _enumFromDbValue(
    CampaignStatus.values,
    value,
    (item) => item.dbValue,
    CampaignStatus.draft,
  );
}

extension CampaignReviewStatusParser on CampaignReviewStatus {
  static CampaignReviewStatus fromDbValue(String? value) => _enumFromDbValue(
    CampaignReviewStatus.values,
    value,
    (item) => item.dbValue,
    CampaignReviewStatus.pending,
  );
}

extension AdAssetTypeParser on AdAssetType {
  static AdAssetType fromDbValue(String? value) => _enumFromDbValue(
    AdAssetType.values,
    value,
    (item) => item.dbValue,
    AdAssetType.image,
  );
}

extension AdPlacementParser on AdPlacement {
  static AdPlacement fromDbValue(String? value) => _enumFromDbValue(
    AdPlacement.values,
    value,
    (item) => item.dbValue,
    AdPlacement.homeFeed,
  );
}

extension BillingModelParser on BillingModel {
  static BillingModel fromDbValue(String? value) => _enumFromDbValue(
    BillingModel.values,
    value,
    (item) => item.dbValue,
    BillingModel.cpc,
  );
}

extension UserEventTypeParser on UserEventType {
  static UserEventType fromDbValue(String? value) => _enumFromDbValue(
    UserEventType.values,
    value,
    (item) => item.dbValue,
    UserEventType.impression,
  );
}

extension RetargetingSegmentParser on RetargetingSegment {
  static RetargetingSegment fromDbValue(String? value) => _enumFromDbValue(
    RetargetingSegment.values,
    value,
    (item) => item.dbValue,
    RetargetingSegment.viewedNotPurchased,
  );
}

extension SellerPlanTierParser on SellerPlanTier {
  static SellerPlanTier fromDbValue(String? value) => _enumFromDbValue(
    SellerPlanTier.values,
    value,
    (item) => item.dbValue,
    SellerPlanTier.free,
  );
}

extension AdFeatureParser on AdFeature {
  static AdFeature fromDbValue(String? value) => _enumFromDbValue(
    AdFeature.values,
    value,
    (item) => item.dbValue,
    AdFeature.productBoost,
  );
}

extension GeoTriggerTypeParser on GeoTriggerType {
  static GeoTriggerType fromDbValue(String? value) => _enumFromDbValue(
    GeoTriggerType.values,
    value,
    (item) => item.dbValue,
    GeoTriggerType.radiusEntry,
  );
}

extension WalletTransactionTypeParser on WalletTransactionType {
  static WalletTransactionType fromDbValue(String? value) => _enumFromDbValue(
    WalletTransactionType.values,
    value,
    (item) => item.dbValue,
    WalletTransactionType.topUp,
  );
}

extension WalletTransactionStatusParser on WalletTransactionStatus {
  static WalletTransactionStatus fromDbValue(String? value) => _enumFromDbValue(
    WalletTransactionStatus.values,
    value,
    (item) => item.dbValue,
    WalletTransactionStatus.pending,
  );
}

T _enumFromDbValue<T>(
  Iterable<T> values,
  String? rawValue,
  String Function(T item) valueOf,
  T fallback,
) {
  final normalized = rawValue?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  for (final value in values) {
    if (valueOf(value) == normalized) {
      return value;
    }
  }
  return fallback;
}
