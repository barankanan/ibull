part of '../../main.dart';

class IhizPricingConfig {
  const IhizPricingConfig({
    required this.baseFee,
    required this.perKmFee,
    required this.platformFee,
    required this.minDeliveryFee,
    required this.maxDeliveryFee,
    required this.dynamicPricingEnabled,
    required this.customerFee0To3Km,
    required this.customerFee3To6Km,
    required this.customerFee6PlusKm,
    required this.sellerContributionMode,
    required this.freeDeliveryCampaignEnabled,
    required this.externalSellerPaysAll,
    required this.externalServiceFee,
    required this.externalMinFee,
    required this.nightBonus,
    required this.rainBonus,
    required this.surgeBonus,
    required this.multiOrderExtraFee,
    required this.multiOrderEnabled,
    required this.minWalletBalance,
    required this.lowBalanceWarningLevel,
    required this.walletFlowMode,
    required this.cancelBeforeAssignRefundPct,
    required this.cancelAfterAssignRefundPct,
    required this.cancelAfterPickupRefundPct,
    required this.cancelPenaltyPct,
    required this.courierBaseEarning,
    required this.courierPerKmEarning,
    required this.courierMinutePrice,
    required this.courierNightBonus,
    required this.courierRainBonus,
    required this.courierSurgeBonus,
    required this.courierMultiOrderBonus,
    required this.weeklyPayoutDay,
    required this.otpRequired,
    required this.deliveryGeoFenceMeters,
    required this.etaPerKmMinute,
    required this.etaBaseMinute,
  });

  final double baseFee;
  final double perKmFee;
  final double platformFee;
  final double minDeliveryFee;
  final double maxDeliveryFee;
  final bool dynamicPricingEnabled;
  final double customerFee0To3Km;
  final double customerFee3To6Km;
  final double customerFee6PlusKm;
  final String sellerContributionMode;
  final bool freeDeliveryCampaignEnabled;
  final bool externalSellerPaysAll;
  final double externalServiceFee;
  final double externalMinFee;
  final double nightBonus;
  final double rainBonus;
  final double surgeBonus;
  final double multiOrderExtraFee;
  final bool multiOrderEnabled;
  final double minWalletBalance;
  final double lowBalanceWarningLevel;
  final String walletFlowMode;
  final double cancelBeforeAssignRefundPct;
  final double cancelAfterAssignRefundPct;
  final double cancelAfterPickupRefundPct;
  final double cancelPenaltyPct;
  final double courierBaseEarning;
  final double courierPerKmEarning;
  final double courierMinutePrice;
  final double courierNightBonus;
  final double courierRainBonus;
  final double courierSurgeBonus;
  final double courierMultiOrderBonus;
  final String weeklyPayoutDay;
  final bool otpRequired;
  final double deliveryGeoFenceMeters;
  final double etaPerKmMinute;
  final double etaBaseMinute;

  static const IhizPricingConfig defaults = IhizPricingConfig(
    baseFee: 28,
    perKmFee: 7,
    platformFee: 10,
    minDeliveryFee: 35,
    maxDeliveryFee: 350,
    dynamicPricingEnabled: true,
    customerFee0To3Km: 35,
    customerFee3To6Km: 45,
    customerFee6PlusKm: 55,
    sellerContributionMode: 'remaining_after_customer',
    freeDeliveryCampaignEnabled: false,
    externalSellerPaysAll: true,
    externalServiceFee: 0,
    externalMinFee: 45,
    nightBonus: 12,
    rainBonus: 15,
    surgeBonus: 10,
    multiOrderExtraFee: 25,
    multiOrderEnabled: true,
    minWalletBalance: 100,
    lowBalanceWarningLevel: 200,
    walletFlowMode: 'reserve_capture_release',
    cancelBeforeAssignRefundPct: 100,
    cancelAfterAssignRefundPct: 70,
    cancelAfterPickupRefundPct: 10,
    cancelPenaltyPct: 15,
    courierBaseEarning: 28,
    courierPerKmEarning: 7,
    courierMinutePrice: 4,
    courierNightBonus: 12,
    courierRainBonus: 15,
    courierSurgeBonus: 10,
    courierMultiOrderBonus: 25,
    weeklyPayoutDay: 'Cuma',
    otpRequired: true,
    deliveryGeoFenceMeters: 150,
    etaPerKmMinute: 5,
    etaBaseMinute: 6,
  );

  IhizPricingConfig copyWith({
    double? baseFee,
    double? perKmFee,
    double? platformFee,
    double? minDeliveryFee,
    double? maxDeliveryFee,
    bool? dynamicPricingEnabled,
    double? customerFee0To3Km,
    double? customerFee3To6Km,
    double? customerFee6PlusKm,
    String? sellerContributionMode,
    bool? freeDeliveryCampaignEnabled,
    bool? externalSellerPaysAll,
    double? externalServiceFee,
    double? externalMinFee,
    double? nightBonus,
    double? rainBonus,
    double? surgeBonus,
    double? multiOrderExtraFee,
    bool? multiOrderEnabled,
    double? minWalletBalance,
    double? lowBalanceWarningLevel,
    String? walletFlowMode,
    double? cancelBeforeAssignRefundPct,
    double? cancelAfterAssignRefundPct,
    double? cancelAfterPickupRefundPct,
    double? cancelPenaltyPct,
    double? courierBaseEarning,
    double? courierPerKmEarning,
    double? courierMinutePrice,
    double? courierNightBonus,
    double? courierRainBonus,
    double? courierSurgeBonus,
    double? courierMultiOrderBonus,
    String? weeklyPayoutDay,
    bool? otpRequired,
    double? deliveryGeoFenceMeters,
    double? etaPerKmMinute,
    double? etaBaseMinute,
  }) {
    return IhizPricingConfig(
      baseFee: baseFee ?? this.baseFee,
      perKmFee: perKmFee ?? this.perKmFee,
      platformFee: platformFee ?? this.platformFee,
      minDeliveryFee: minDeliveryFee ?? this.minDeliveryFee,
      maxDeliveryFee: maxDeliveryFee ?? this.maxDeliveryFee,
      dynamicPricingEnabled:
          dynamicPricingEnabled ?? this.dynamicPricingEnabled,
      customerFee0To3Km: customerFee0To3Km ?? this.customerFee0To3Km,
      customerFee3To6Km: customerFee3To6Km ?? this.customerFee3To6Km,
      customerFee6PlusKm: customerFee6PlusKm ?? this.customerFee6PlusKm,
      sellerContributionMode:
          sellerContributionMode ?? this.sellerContributionMode,
      freeDeliveryCampaignEnabled:
          freeDeliveryCampaignEnabled ?? this.freeDeliveryCampaignEnabled,
      externalSellerPaysAll:
          externalSellerPaysAll ?? this.externalSellerPaysAll,
      externalServiceFee: externalServiceFee ?? this.externalServiceFee,
      externalMinFee: externalMinFee ?? this.externalMinFee,
      nightBonus: nightBonus ?? this.nightBonus,
      rainBonus: rainBonus ?? this.rainBonus,
      surgeBonus: surgeBonus ?? this.surgeBonus,
      multiOrderExtraFee: multiOrderExtraFee ?? this.multiOrderExtraFee,
      multiOrderEnabled: multiOrderEnabled ?? this.multiOrderEnabled,
      minWalletBalance: minWalletBalance ?? this.minWalletBalance,
      lowBalanceWarningLevel:
          lowBalanceWarningLevel ?? this.lowBalanceWarningLevel,
      walletFlowMode: walletFlowMode ?? this.walletFlowMode,
      cancelBeforeAssignRefundPct:
          cancelBeforeAssignRefundPct ?? this.cancelBeforeAssignRefundPct,
      cancelAfterAssignRefundPct:
          cancelAfterAssignRefundPct ?? this.cancelAfterAssignRefundPct,
      cancelAfterPickupRefundPct:
          cancelAfterPickupRefundPct ?? this.cancelAfterPickupRefundPct,
      cancelPenaltyPct: cancelPenaltyPct ?? this.cancelPenaltyPct,
      courierBaseEarning: courierBaseEarning ?? this.courierBaseEarning,
      courierPerKmEarning: courierPerKmEarning ?? this.courierPerKmEarning,
      courierMinutePrice: courierMinutePrice ?? this.courierMinutePrice,
      courierNightBonus: courierNightBonus ?? this.courierNightBonus,
      courierRainBonus: courierRainBonus ?? this.courierRainBonus,
      courierSurgeBonus: courierSurgeBonus ?? this.courierSurgeBonus,
      courierMultiOrderBonus:
          courierMultiOrderBonus ?? this.courierMultiOrderBonus,
      weeklyPayoutDay: weeklyPayoutDay ?? this.weeklyPayoutDay,
      otpRequired: otpRequired ?? this.otpRequired,
      deliveryGeoFenceMeters:
          deliveryGeoFenceMeters ?? this.deliveryGeoFenceMeters,
      etaPerKmMinute: etaPerKmMinute ?? this.etaPerKmMinute,
      etaBaseMinute: etaBaseMinute ?? this.etaBaseMinute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_fee': baseFee,
      'per_km_fee': perKmFee,
      'platform_fee': platformFee,
      'min_delivery_fee': minDeliveryFee,
      'max_delivery_fee': maxDeliveryFee,
      'dynamic_pricing_enabled': dynamicPricingEnabled,
      'customer_fee_0_3_km': customerFee0To3Km,
      'customer_fee_3_6_km': customerFee3To6Km,
      'customer_fee_6_plus_km': customerFee6PlusKm,
      'seller_contribution_mode': sellerContributionMode,
      'free_delivery_campaign_enabled': freeDeliveryCampaignEnabled,
      'external_seller_pays_all': externalSellerPaysAll,
      'external_service_fee': externalServiceFee,
      'external_min_fee': externalMinFee,
      'night_bonus': nightBonus,
      'rain_bonus': rainBonus,
      'surge_bonus': surgeBonus,
      'multi_order_extra_fee': multiOrderExtraFee,
      'multi_order_enabled': multiOrderEnabled,
      'min_wallet_balance': minWalletBalance,
      'low_balance_warning_level': lowBalanceWarningLevel,
      'wallet_flow_mode': walletFlowMode,
      'cancel_before_assign_refund_pct': cancelBeforeAssignRefundPct,
      'cancel_after_assign_refund_pct': cancelAfterAssignRefundPct,
      'cancel_after_pickup_refund_pct': cancelAfterPickupRefundPct,
      'cancel_penalty_pct': cancelPenaltyPct,
      'courier_base_earning': courierBaseEarning,
      'courier_per_km_earning': courierPerKmEarning,
      'courier_minute_price': courierMinutePrice,
      'courier_night_bonus': courierNightBonus,
      'courier_rain_bonus': courierRainBonus,
      'courier_surge_bonus': courierSurgeBonus,
      'courier_multi_order_bonus': courierMultiOrderBonus,
      'weekly_payout_day': weeklyPayoutDay,
      'otp_required': otpRequired,
      'delivery_geo_fence_meters': deliveryGeoFenceMeters,
      'eta_per_km_minute': etaPerKmMinute,
      'eta_base_minute': etaBaseMinute,
    };
  }

  static IhizPricingConfig fromJson(Map<String, dynamic> raw) {
    double toDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool toBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
      return fallback;
    }

    final defaults = IhizPricingConfig.defaults;
    return IhizPricingConfig(
      baseFee: toDouble(raw['base_fee'], defaults.baseFee),
      perKmFee: toDouble(raw['per_km_fee'], defaults.perKmFee),
      platformFee: toDouble(raw['platform_fee'], defaults.platformFee),
      minDeliveryFee: toDouble(
        raw['min_delivery_fee'],
        defaults.minDeliveryFee,
      ),
      maxDeliveryFee: toDouble(
        raw['max_delivery_fee'],
        defaults.maxDeliveryFee,
      ),
      dynamicPricingEnabled: toBool(
        raw['dynamic_pricing_enabled'],
        defaults.dynamicPricingEnabled,
      ),
      customerFee0To3Km: toDouble(
        raw['customer_fee_0_3_km'],
        defaults.customerFee0To3Km,
      ),
      customerFee3To6Km: toDouble(
        raw['customer_fee_3_6_km'],
        defaults.customerFee3To6Km,
      ),
      customerFee6PlusKm: toDouble(
        raw['customer_fee_6_plus_km'],
        defaults.customerFee6PlusKm,
      ),
      sellerContributionMode:
          raw['seller_contribution_mode']?.toString() ??
          defaults.sellerContributionMode,
      freeDeliveryCampaignEnabled: toBool(
        raw['free_delivery_campaign_enabled'],
        defaults.freeDeliveryCampaignEnabled,
      ),
      externalSellerPaysAll: toBool(
        raw['external_seller_pays_all'],
        defaults.externalSellerPaysAll,
      ),
      externalServiceFee: toDouble(
        raw['external_service_fee'],
        defaults.externalServiceFee,
      ),
      externalMinFee: toDouble(
        raw['external_min_fee'],
        defaults.externalMinFee,
      ),
      nightBonus: toDouble(raw['night_bonus'], defaults.nightBonus),
      rainBonus: toDouble(raw['rain_bonus'], defaults.rainBonus),
      surgeBonus: toDouble(raw['surge_bonus'], defaults.surgeBonus),
      multiOrderExtraFee: toDouble(
        raw['multi_order_extra_fee'],
        defaults.multiOrderExtraFee,
      ),
      multiOrderEnabled: toBool(
        raw['multi_order_enabled'],
        defaults.multiOrderEnabled,
      ),
      minWalletBalance: toDouble(
        raw['min_wallet_balance'],
        defaults.minWalletBalance,
      ),
      lowBalanceWarningLevel: toDouble(
        raw['low_balance_warning_level'],
        defaults.lowBalanceWarningLevel,
      ),
      walletFlowMode:
          raw['wallet_flow_mode']?.toString() ?? defaults.walletFlowMode,
      cancelBeforeAssignRefundPct: toDouble(
        raw['cancel_before_assign_refund_pct'],
        defaults.cancelBeforeAssignRefundPct,
      ),
      cancelAfterAssignRefundPct: toDouble(
        raw['cancel_after_assign_refund_pct'],
        defaults.cancelAfterAssignRefundPct,
      ),
      cancelAfterPickupRefundPct: toDouble(
        raw['cancel_after_pickup_refund_pct'],
        defaults.cancelAfterPickupRefundPct,
      ),
      cancelPenaltyPct: toDouble(
        raw['cancel_penalty_pct'],
        defaults.cancelPenaltyPct,
      ),
      courierBaseEarning: toDouble(
        raw['courier_base_earning'],
        defaults.courierBaseEarning,
      ),
      courierPerKmEarning: toDouble(
        raw['courier_per_km_earning'],
        defaults.courierPerKmEarning,
      ),
      courierMinutePrice: toDouble(
        raw['courier_minute_price'],
        defaults.courierMinutePrice,
      ),
      courierNightBonus: toDouble(
        raw['courier_night_bonus'],
        defaults.courierNightBonus,
      ),
      courierRainBonus: toDouble(
        raw['courier_rain_bonus'],
        defaults.courierRainBonus,
      ),
      courierSurgeBonus: toDouble(
        raw['courier_surge_bonus'],
        defaults.courierSurgeBonus,
      ),
      courierMultiOrderBonus: toDouble(
        raw['courier_multi_order_bonus'],
        defaults.courierMultiOrderBonus,
      ),
      weeklyPayoutDay:
          raw['weekly_payout_day']?.toString() ?? defaults.weeklyPayoutDay,
      otpRequired: toBool(raw['otp_required'], defaults.otpRequired),
      deliveryGeoFenceMeters: toDouble(
        raw['delivery_geo_fence_meters'],
        defaults.deliveryGeoFenceMeters,
      ),
      etaPerKmMinute: toDouble(
        raw['eta_per_km_minute'],
        defaults.etaPerKmMinute,
      ),
      etaBaseMinute: toDouble(raw['eta_base_minute'], defaults.etaBaseMinute),
    );
  }
}

class _PricingRuleVersion {
  const _PricingRuleVersion({
    required this.version,
    required this.activeFrom,
    required this.isActive,
    required this.createdAt,
    required this.note,
    required this.config,
  });

  final int version;
  final DateTime activeFrom;
  final bool isActive;
  final DateTime createdAt;
  final String note;
  final IhizPricingConfig config;
}
