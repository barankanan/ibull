enum CouponSourceType {
  ibul,
  seller,
  couponAd;

  String get dbValue => switch (this) {
    CouponSourceType.ibul => 'ibul',
    CouponSourceType.seller => 'seller',
    CouponSourceType.couponAd => 'coupon_ad',
  };
}

enum CouponDiscountType {
  percent,
  fixed,
  freeShipping,
  special;

  String get dbValue => switch (this) {
    CouponDiscountType.percent => 'percent',
    CouponDiscountType.fixed => 'fixed',
    CouponDiscountType.freeShipping => 'free_shipping',
    CouponDiscountType.special => 'special',
  };
}

enum CouponScopeType {
  all,
  categories,
  stores,
  products;

  String get dbValue => switch (this) {
    CouponScopeType.all => 'all',
    CouponScopeType.categories => 'categories',
    CouponScopeType.stores => 'stores',
    CouponScopeType.products => 'products',
  };
}

enum CouponApprovalStatus {
  draft,
  pendingReview,
  approved,
  rejected;

  String get dbValue => switch (this) {
    CouponApprovalStatus.draft => 'draft',
    CouponApprovalStatus.pendingReview => 'pending_review',
    CouponApprovalStatus.approved => 'approved',
    CouponApprovalStatus.rejected => 'rejected',
  };
}

enum CouponEffectiveStatus {
  draft,
  pendingReview,
  approved,
  scheduled,
  active,
  paused,
  rejected,
  expired;

  String get dbValue => switch (this) {
    CouponEffectiveStatus.draft => 'draft',
    CouponEffectiveStatus.pendingReview => 'pending_review',
    CouponEffectiveStatus.approved => 'approved',
    CouponEffectiveStatus.scheduled => 'scheduled',
    CouponEffectiveStatus.active => 'active',
    CouponEffectiveStatus.paused => 'paused',
    CouponEffectiveStatus.rejected => 'rejected',
    CouponEffectiveStatus.expired => 'expired',
  };
}

enum UserCouponStatus {
  claimed,
  reserved,
  used,
  expired;

  String get dbValue => switch (this) {
    UserCouponStatus.claimed => 'claimed',
    UserCouponStatus.reserved => 'reserved',
    UserCouponStatus.used => 'used',
    UserCouponStatus.expired => 'expired',
  };
}

T _enumFromDb<T extends Enum>(
  List<T> values,
  String Function(T) dbValue,
  String? raw,
  T fallback,
) {
  final normalized = raw?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return fallback;
  for (final value in values) {
    if (dbValue(value) == normalized) return value;
  }
  return fallback;
}

extension CouponSourceTypeParser on CouponSourceType {
  static CouponSourceType fromDb(String? value) => _enumFromDb(
    CouponSourceType.values,
    (item) => item.dbValue,
    value,
    CouponSourceType.ibul,
  );
}

extension CouponDiscountTypeParser on CouponDiscountType {
  static CouponDiscountType fromDb(String? value) => _enumFromDb(
    CouponDiscountType.values,
    (item) => item.dbValue,
    value,
    CouponDiscountType.percent,
  );
}

extension CouponScopeTypeParser on CouponScopeType {
  static CouponScopeType fromDb(String? value) => _enumFromDb(
    CouponScopeType.values,
    (item) => item.dbValue,
    value,
    CouponScopeType.all,
  );
}

extension CouponApprovalStatusParser on CouponApprovalStatus {
  static CouponApprovalStatus fromDb(String? value) => _enumFromDb(
    CouponApprovalStatus.values,
    (item) => item.dbValue,
    value,
    CouponApprovalStatus.draft,
  );
}

extension CouponEffectiveStatusParser on CouponEffectiveStatus {
  static CouponEffectiveStatus fromDb(String? value) => _enumFromDb(
    CouponEffectiveStatus.values,
    (item) => item.dbValue,
    value,
    CouponEffectiveStatus.draft,
  );
}

extension UserCouponStatusParser on UserCouponStatus {
  static UserCouponStatus fromDb(String? value) => _enumFromDb(
    UserCouponStatus.values,
    (item) => item.dbValue,
    value,
    UserCouponStatus.claimed,
  );
}
