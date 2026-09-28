import 'coupon_enums.dart';
import 'coupon_status_labels.dart';

class CouponCampaign {
  const CouponCampaign({
    required this.id,
    required this.name,
    required this.code,
    required this.sourceType,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.startsAt,
    required this.endsAt,
    required this.approvalStatus,
    required this.scopeType,
    this.description,
    this.maxDiscount,
    this.perUserLimit = 1,
    this.totalUsageLimit,
    this.usedCount = 0,
    this.newUsersOnly = false,
    this.isPublic = true,
    this.paymentType,
    this.sellerId,
    this.storeId,
    this.storeName,
    this.rejectionReason,
    this.paused = false,
    this.wheelEnabled = false,
    this.wheelRequested = false,
    this.adBudget,
    this.adDurationDays,
    this.storeLogoUrl,
    this.viewCount = 0,
    this.claimCount = 0,
    this.totalDiscountGranted = 0,
    this.categoryIds = const [],
    this.productIds = const [],
    this.storeIds = const [],
    this.categoryNames = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String code;
  final CouponSourceType sourceType;
  final CouponDiscountType discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final int perUserLimit;
  final int? totalUsageLimit;
  final int usedCount;
  final bool newUsersOnly;
  final bool isPublic;
  final String? paymentType;
  final CouponScopeType scopeType;
  final String? sellerId;
  final String? storeId;
  final String? storeName;
  final CouponApprovalStatus approvalStatus;
  final String? rejectionReason;
  final bool paused;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool wheelEnabled;
  final bool wheelRequested;
  final double? adBudget;
  final int? adDurationDays;
  final String? storeLogoUrl;
  final int viewCount;
  final int claimCount;
  final double totalDiscountGranted;
  final List<int> categoryIds;
  final List<String> productIds;
  final List<String> storeIds;
  final List<String> categoryNames;

  CouponEffectiveStatus get effectiveStatus => CouponStatusLabels.compute(
    approval: approvalStatus,
    paused: paused,
    startsAt: startsAt,
    endsAt: endsAt,
  );

  String get discountLabel {
    return switch (discountType) {
      CouponDiscountType.percent => '%${discountValue.toStringAsFixed(0)}',
      CouponDiscountType.fixed => '${discountValue.toStringAsFixed(0)} TL',
      CouponDiscountType.freeShipping => 'Ücretsiz teslimat',
      CouponDiscountType.special => 'Özel kampanya',
    };
  }

  factory CouponCampaign.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value.toUtc();
      return DateTime.tryParse('$value')?.toUtc() ?? DateTime.now().toUtc();
    }

    List<int> intsOf(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((item) => int.tryParse('$item'))
          .whereType<int>()
          .toList(growable: false);
    }

    List<String> stringsOf(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return CouponCampaign(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      code: map['code']?.toString() ?? '',
      sourceType: CouponSourceTypeParser.fromDb(map['source_type']?.toString()),
      discountType: CouponDiscountTypeParser.fromDb(
        map['discount_type']?.toString(),
      ),
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0,
      maxDiscount: (map['max_discount'] as num?)?.toDouble(),
      minOrderAmount: (map['min_order_amount'] as num?)?.toDouble() ?? 0,
      perUserLimit: (map['per_user_limit'] as num?)?.toInt() ?? 1,
      totalUsageLimit: (map['total_usage_limit'] as num?)?.toInt(),
      usedCount: (map['used_count'] as num?)?.toInt() ?? 0,
      newUsersOnly: map['new_users_only'] == true,
      isPublic: map['is_public'] != false,
      paymentType: map['payment_type']?.toString(),
      scopeType: CouponScopeTypeParser.fromDb(map['scope_type']?.toString()),
      sellerId: map['seller_id']?.toString(),
      storeId: map['store_id']?.toString(),
      storeName:
          map['store_name']?.toString() ??
          map['business_name']?.toString(),
      approvalStatus: CouponApprovalStatusParser.fromDb(
        map['approval_status']?.toString(),
      ),
      rejectionReason: map['rejection_reason']?.toString(),
      paused: map['lifecycle_status']?.toString() == 'paused',
      startsAt: parseDate(map['starts_at']),
      endsAt: parseDate(map['ends_at']),
      wheelEnabled: map['wheel_enabled'] == true,
      wheelRequested: map['wheel_requested'] == true,
      adBudget: (map['ad_budget'] as num?)?.toDouble(),
      adDurationDays: (map['ad_duration_days'] as num?)?.toInt(),
      storeLogoUrl: map['store_logo_url']?.toString() ?? map['logo_url']?.toString(),
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      claimCount: (map['claim_count'] as num?)?.toInt() ?? 0,
      totalDiscountGranted:
          (map['total_discount_granted'] as num?)?.toDouble() ?? 0,
      categoryIds: intsOf(map['category_ids']),
      productIds: stringsOf(map['product_ids']),
      storeIds: stringsOf(map['store_ids']),
      categoryNames: stringsOf(map['category_names']),
    );
  }

  Map<String, dynamic> toUpsertPayload() {
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      'code': code,
      'source_type': sourceType.dbValue,
      'discount_type': discountType.dbValue,
      'discount_value': discountValue,
      'max_discount': maxDiscount,
      'min_order_amount': minOrderAmount,
      'per_user_limit': perUserLimit,
      'total_usage_limit': totalUsageLimit,
      'new_users_only': newUsersOnly,
      'is_public': isPublic,
      'payment_type': paymentType,
      'scope_type': scopeType.dbValue,
      'seller_id': sellerId,
      'store_id': storeId,
      'approval_status': approvalStatus.dbValue,
      'lifecycle_status': paused ? 'paused' : 'draft',
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'wheel_requested': wheelRequested,
      'ad_budget': adBudget,
      'ad_duration_days': adDurationDays,
      'category_ids': categoryIds,
      'product_ids': productIds,
      'store_ids': storeIds,
    };
  }
}
