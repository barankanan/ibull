import 'coupon_enums.dart';

abstract final class CouponStatusLabels {
  static String effective(CouponEffectiveStatus status) => switch (status) {
    CouponEffectiveStatus.draft => 'Taslak',
    CouponEffectiveStatus.pendingReview => 'Onay Bekliyor',
    CouponEffectiveStatus.approved => 'Onaylandı',
    CouponEffectiveStatus.scheduled => 'Planlandı',
    CouponEffectiveStatus.active => 'Aktif',
    CouponEffectiveStatus.paused => 'Duraklatıldı',
    CouponEffectiveStatus.rejected => 'Reddedildi',
    CouponEffectiveStatus.expired => 'Süresi Doldu',
  };

  static String source(CouponSourceType source) => switch (source) {
    CouponSourceType.ibul => 'İBUL',
    CouponSourceType.seller => 'Satıcı',
    CouponSourceType.couponAd => 'Kupon Reklamı',
  };

  static String discount(CouponDiscountType type) => switch (type) {
    CouponDiscountType.percent => 'Yüzde indirim',
    CouponDiscountType.fixed => 'Sabit TL indirim',
    CouponDiscountType.freeShipping => 'Ücretsiz teslimat',
    CouponDiscountType.special => 'Özel kampanya',
  };

  static String scope(CouponScopeType type) => switch (type) {
    CouponScopeType.all => 'Tüm İBUL',
    CouponScopeType.categories => 'Belirli kategoriler',
    CouponScopeType.stores => 'Belirli mağazalar',
    CouponScopeType.products => 'Belirli ürünler',
  };

  static CouponEffectiveStatus compute({
    required CouponApprovalStatus approval,
    required bool paused,
    required DateTime startsAt,
    required DateTime endsAt,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now().toUtc();
    final start = startsAt.toUtc();
    final end = endsAt.toUtc();
    if (approval == CouponApprovalStatus.rejected) {
      return CouponEffectiveStatus.rejected;
    }
    if (approval == CouponApprovalStatus.draft) {
      return CouponEffectiveStatus.draft;
    }
    if (approval == CouponApprovalStatus.pendingReview) {
      return CouponEffectiveStatus.pendingReview;
    }
    if (paused) return CouponEffectiveStatus.paused;
    if (current.isBefore(start)) return CouponEffectiveStatus.scheduled;
    if (current.isAfter(end)) return CouponEffectiveStatus.expired;
    return CouponEffectiveStatus.active;
  }
}
