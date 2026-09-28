import '../domain/coupon_campaign.dart';
import '../domain/coupon_enums.dart';

abstract final class CouponCodeGenerator {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate({String prefix = 'IBUL'}) {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer(prefix);
    var n = seed;
    for (var i = 0; i < 6; i++) {
      buffer.write(_chars[n % _chars.length]);
      n = n ~/ _chars.length + 17;
    }
    return buffer.toString();
  }

  static String normalize(String code) => code.trim().toUpperCase();
}

abstract final class CouponDiscountMath {
  static double compute({
    required CouponDiscountType type,
    required double discountValue,
    required double eligibleSubtotal,
    double? maxDiscount,
    double minOrderAmount = 0,
  }) {
    if (eligibleSubtotal <= 0) return 0;
    if (minOrderAmount > 0 && eligibleSubtotal < minOrderAmount) return 0;
    var discount = 0.0;
    switch (type) {
      case CouponDiscountType.percent:
        discount = eligibleSubtotal * discountValue / 100;
        if (maxDiscount != null) {
          discount = discount < maxDiscount ? discount : maxDiscount;
        }
      case CouponDiscountType.fixed:
        discount = discountValue < eligibleSubtotal
            ? discountValue
            : eligibleSubtotal;
      case CouponDiscountType.freeShipping:
        discount = 0;
      case CouponDiscountType.special:
        discount = discountValue < eligibleSubtotal
            ? discountValue
            : eligibleSubtotal;
    }
    return discount < 0 ? 0 : discount;
  }
}

class CouponSchedulePreset {
  const CouponSchedulePreset({
    required this.id,
    required this.label,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final String label;
  final DateTime startsAt;
  final DateTime endsAt;
}

abstract final class CouponSchedulePresets {
  static List<CouponSchedulePreset> forLocalNow(DateTime localNow) {
    final startOfToday = DateTime(localNow.year, localNow.month, localNow.day);
    final endOfToday = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      23,
      59,
      59,
    );
    final weekday = localNow.weekday;
    final daysToSaturday = (DateTime.saturday - weekday + 7) % 7;
    final saturday = startOfToday.add(Duration(days: daysToSaturday));
    final sundayEnd = DateTime(
      saturday.year,
      saturday.month,
      saturday.day + 1,
      23,
      59,
      59,
    );
    return [
      CouponSchedulePreset(
        id: 'today',
        label: 'Bugün',
        startsAt: startOfToday,
        endsAt: endOfToday,
      ),
      CouponSchedulePreset(
        id: '24h',
        label: '24 saat',
        startsAt: localNow,
        endsAt: localNow.add(const Duration(hours: 24)),
      ),
      CouponSchedulePreset(
        id: 'week',
        label: 'Bu hafta',
        startsAt: startOfToday,
        endsAt: startOfToday.add(Duration(days: 7 - weekday, hours: 23, minutes: 59, seconds: 59)),
      ),
      CouponSchedulePreset(
        id: 'weekend',
        label: 'Hafta sonu',
        startsAt: saturday,
        endsAt: sundayEnd,
      ),
    ];
  }
}

bool couponMatchesFilters({
  required CouponCampaign campaign,
  CouponEffectiveStatus? status,
  CouponSourceType? source,
  CouponDiscountType? discountType,
  String query = '',
}) {
  if (status != null && campaign.effectiveStatus != status) return false;
  if (source != null && campaign.sourceType != source) return false;
  if (discountType != null && campaign.discountType != discountType) {
    return false;
  }
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return campaign.code.toLowerCase().contains(q) ||
      campaign.name.toLowerCase().contains(q) ||
      (campaign.storeName ?? '').toLowerCase().contains(q);
}
