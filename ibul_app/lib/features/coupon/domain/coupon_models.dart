import 'coupon_campaign.dart';
import 'coupon_enums.dart';

class UserCoupon {
  const UserCoupon({
    required this.id,
    required this.userId,
    required this.campaignId,
    required this.status,
    required this.claimedAt,
    this.source,
    this.usedAt,
    this.orderId,
    this.campaign,
  });

  final String id;
  final String userId;
  final String campaignId;
  final UserCouponStatus status;
  final String? source;
  final DateTime claimedAt;
  final DateTime? usedAt;
  final String? orderId;
  final CouponCampaign? campaign;

  bool get isUsable =>
      status == UserCouponStatus.claimed || status == UserCouponStatus.reserved;

  factory UserCoupon.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      return DateTime.tryParse('$value')?.toUtc();
    }

    final nested = map['coupon_campaigns'];
    return UserCoupon(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      campaignId: map['campaign_id']?.toString() ?? '',
      status: UserCouponStatusParser.fromDb(map['status']?.toString()),
      source: map['source']?.toString(),
      claimedAt: parseDate(map['claimed_at']) ?? DateTime.now().toUtc(),
      usedAt: parseDate(map['used_at']),
      orderId: map['order_id']?.toString(),
      campaign: nested is Map
          ? CouponCampaign.fromMap(Map<String, dynamic>.from(nested))
          : null,
    );
  }
}

class CouponQuote {
  const CouponQuote({
    required this.ok,
    this.error,
    this.campaignId,
    this.code,
    this.discountAmount = 0,
    this.freeShipping = false,
  });

  final bool ok;
  final String? error;
  final String? campaignId;
  final String? code;
  final double discountAmount;
  final bool freeShipping;

  factory CouponQuote.fromMap(Map<String, dynamic> map) {
    return CouponQuote(
      ok: map['ok'] == true,
      error: map['error']?.toString(),
      campaignId: map['campaign_id']?.toString(),
      code: map['code']?.toString(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      freeShipping: map['free_shipping'] == true,
    );
  }
}

class DailyDealProduct {
  const DailyDealProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.discountPrice,
    this.brand,
    this.imageUrl,
    this.storeName,
    this.sellerId,
    this.discountPercent = 0,
  });

  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double price;
  final double discountPrice;
  final double discountPercent;
  final String? storeName;
  final String? sellerId;

  factory DailyDealProduct.fromMap(Map<String, dynamic> map) {
    final price = (map['price'] as num?)?.toDouble() ?? 0;
    final discount = (map['discount_price'] as num?)?.toDouble() ?? 0;
    return DailyDealProduct(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      brand: map['brand']?.toString(),
      imageUrl: map['image_url']?.toString(),
      price: price,
      discountPrice: discount,
      discountPercent: (map['discount_percent'] as num?)?.toDouble() ??
          (price > 0 && discount > 0 && discount < price
              ? ((1 - discount / price) * 100)
              : 0),
      storeName: map['store_name']?.toString(),
      sellerId: map['seller_id']?.toString(),
    );
  }
}

class RewardWheelItem {
  const RewardWheelItem({
    required this.label,
    required this.probabilityBps,
    this.id,
    this.campaignId,
    this.isNoPrize = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.colorHex,
  });

  final String? id;
  final String? campaignId;
  final String label;
  final bool isNoPrize;
  final bool isActive;
  final int probabilityBps;
  final int sortOrder;
  final String? colorHex;

  double get probabilityPercent => probabilityBps / 100;

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (id != null) 'id': id,
    'campaign_id': campaignId,
    'label': label,
    'is_no_prize': isNoPrize,
    'is_active': isActive,
    'probability_bps': probabilityBps,
    'sort_order': sortOrder,
    'color_hex': colorHex,
  };

  factory RewardWheelItem.fromMap(Map<String, dynamic> map) {
    return RewardWheelItem(
      id: map['id']?.toString(),
      campaignId: map['campaign_id']?.toString(),
      label: map['label']?.toString() ?? 'Ödül',
      isNoPrize: map['is_no_prize'] == true,
      isActive: map['is_active'] != false,
      probabilityBps: (map['probability_bps'] as num?)?.toInt() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      colorHex: map['color_hex']?.toString(),
    );
  }
}

class RewardWheelConfig {
  const RewardWheelConfig({
    required this.isActive,
    required this.dailyFreeSpins,
    required this.cooldownHours,
    required this.items,
    this.id,
    this.startsAt,
    this.endsAt,
    this.useGlobalPool = true,
    this.perUserDailyLimit = 1,
    this.canSpin = false,
    this.nextSpinAt,
  });

  final String? id;
  final bool isActive;
  final int dailyFreeSpins;
  final int perUserDailyLimit;
  final bool useGlobalPool;
  final double cooldownHours;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<RewardWheelItem> items;
  final bool canSpin;
  final DateTime? nextSpinAt;

  int get probabilityTotalBps =>
      items.fold<int>(0, (sum, item) => sum + item.probabilityBps);

  bool get probabilityIsValid => probabilityTotalBps == 10000;

  /// Homepage FAB: server eligibility, not just "wheel is published".
  bool get visibleOnHome => isActive && items.isNotEmpty && canSpin;

  factory RewardWheelConfig.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      return DateTime.tryParse('$value')?.toUtc();
    }

    final rawItems = map['items'] ?? map['reward_wheel_items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (row) => RewardWheelItem.fromMap(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(growable: false)
        : const <RewardWheelItem>[];
    return RewardWheelConfig(
      id: map['id']?.toString(),
      isActive: map['is_active'] == true,
      dailyFreeSpins: (map['daily_free_spins'] as num?)?.toInt() ?? 1,
      perUserDailyLimit: (map['per_user_daily_limit'] as num?)?.toInt() ??
          (map['daily_free_spins'] as num?)?.toInt() ??
          1,
      useGlobalPool: map['use_global_pool'] != false,
      cooldownHours: (map['cooldown_hours'] as num?)?.toDouble() ?? 24,
      startsAt: parseDate(map['starts_at']),
      endsAt: parseDate(map['ends_at']),
      items: items,
      canSpin: map.containsKey('can_spin')
          ? map['can_spin'] == true
          : map['is_active'] == true && items.isNotEmpty,
      nextSpinAt: parseDate(map['next_spin_at']),
    );
  }
}

class RewardWheelSpinResult {
  const RewardWheelSpinResult({
    required this.ok,
    this.error,
    this.alreadyProcessed = false,
    this.isWin = false,
    this.isNoPrize = false,
    this.canSpin = false,
    this.label,
    this.campaignId,
    this.itemId,
    this.sortOrder = 0,
  });

  final bool ok;
  final String? error;
  final bool alreadyProcessed;
  final bool isWin;
  final bool isNoPrize;
  final bool canSpin;
  final String? label;
  final String? campaignId;
  final String? itemId;
  final int sortOrder;

  factory RewardWheelSpinResult.fromMap(Map<String, dynamic> map) {
    return RewardWheelSpinResult(
      ok: map['ok'] == true,
      error: map['error']?.toString(),
      alreadyProcessed: map['already_processed'] == true,
      isWin: map['is_win'] == true,
      isNoPrize: map['is_no_prize'] == true,
      canSpin: map['can_spin'] == true,
      label: map['label']?.toString(),
      campaignId: map['campaign_id']?.toString(),
      itemId: map['item_id']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CouponAdminSummary {
  const CouponAdminSummary({
    this.active = 0,
    this.pending = 0,
    this.scheduled = 0,
    this.expired = 0,
    this.wheel = 0,
  });

  final int active;
  final int pending;
  final int scheduled;
  final int expired;
  final int wheel;
}

class RewardWheelAdminStats {
  const RewardWheelAdminStats({
    this.activeRewards = 0,
    this.pendingSellerOffers = 0,
    this.todaySpins = 0,
    this.todayWins = 0,
  });

  final int activeRewards;
  final int pendingSellerOffers;
  final int todaySpins;
  final int todayWins;

  factory RewardWheelAdminStats.fromMap(Map<String, dynamic> map) {
    return RewardWheelAdminStats(
      activeRewards: (map['active_rewards'] as num?)?.toInt() ?? 0,
      pendingSellerOffers:
          (map['pending_seller_offers'] as num?)?.toInt() ?? 0,
      todaySpins: (map['today_spins'] as num?)?.toInt() ?? 0,
      todayWins: (map['today_wins'] as num?)?.toInt() ?? 0,
    );
  }
}
