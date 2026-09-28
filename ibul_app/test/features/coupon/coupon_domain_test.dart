import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/coupon/domain/coupon_enums.dart';
import 'package:ibul_app/features/coupon/domain/coupon_helpers.dart';
import 'package:ibul_app/features/coupon/domain/coupon_models.dart';
import 'package:ibul_app/features/coupon/domain/coupon_status_labels.dart';

void main() {
  test('effective status maps Turkish labels', () {
    expect(
      CouponStatusLabels.effective(CouponEffectiveStatus.pendingReview),
      'Onay Bekliyor',
    );
    expect(
      CouponStatusLabels.effective(CouponEffectiveStatus.active),
      'Aktif',
    );
    expect(
      CouponStatusLabels.source(CouponSourceType.couponAd),
      'Kupon Reklamı',
    );
  });

  test('approved coupon becomes active only inside the window', () {
    final start = DateTime.utc(2026, 9, 15);
    final end = DateTime.utc(2026, 9, 15, 20, 59, 59);
    expect(
      CouponStatusLabels.compute(
        approval: CouponApprovalStatus.approved,
        paused: false,
        startsAt: start,
        endsAt: end,
        now: DateTime.utc(2026, 9, 14, 23),
      ),
      CouponEffectiveStatus.scheduled,
    );
    expect(
      CouponStatusLabels.compute(
        approval: CouponApprovalStatus.approved,
        paused: false,
        startsAt: start,
        endsAt: end,
        now: DateTime.utc(2026, 9, 15, 12),
      ),
      CouponEffectiveStatus.active,
    );
    expect(
      CouponStatusLabels.compute(
        approval: CouponApprovalStatus.approved,
        paused: false,
        startsAt: start,
        endsAt: end,
        now: DateTime.utc(2026, 9, 16),
      ),
      CouponEffectiveStatus.expired,
    );
  });

  test('pending seller coupon is not treated as active', () {
    expect(
      CouponStatusLabels.compute(
        approval: CouponApprovalStatus.pendingReview,
        paused: false,
        startsAt: DateTime.utc(2026, 1, 1),
        endsAt: DateTime.utc(2026, 12, 31),
        now: DateTime.utc(2026, 9, 15),
      ),
      CouponEffectiveStatus.pendingReview,
    );
  });

  test('discount math respects min cart, percent cap and fixed amount', () {
    expect(
      CouponDiscountMath.compute(
        type: CouponDiscountType.percent,
        discountValue: 10,
        eligibleSubtotal: 200,
        maxDiscount: 15,
      ),
      15,
    );
    expect(
      CouponDiscountMath.compute(
        type: CouponDiscountType.fixed,
        discountValue: 100,
        eligibleSubtotal: 80,
      ),
      80,
    );
    expect(
      CouponDiscountMath.compute(
        type: CouponDiscountType.percent,
        discountValue: 15,
        eligibleSubtotal: 50,
        minOrderAmount: 100,
      ),
      0,
    );
  });

  test('wheel probability must total 100 percent', () {
    const invalid = RewardWheelConfig(
      isActive: true,
      dailyFreeSpins: 1,
      cooldownHours: 24,
      items: [
        RewardWheelItem(label: 'A', probabilityBps: 3000),
        RewardWheelItem(label: 'B', probabilityBps: 5700),
      ],
    );
    const valid = RewardWheelConfig(
      isActive: true,
      dailyFreeSpins: 1,
      cooldownHours: 24,
      items: [
        RewardWheelItem(label: 'A', probabilityBps: 3000),
        RewardWheelItem(label: 'B', probabilityBps: 7000),
      ],
    );
    expect(invalid.probabilityIsValid, isFalse);
    expect(valid.probabilityIsValid, isTrue);
    expect(valid.probabilityTotalBps, 10000);
  });

  test('homepage wheel stays hidden until server says the user can spin', () {
    const published = RewardWheelConfig(
      isActive: true,
      dailyFreeSpins: 1,
      cooldownHours: 24,
      canSpin: false,
      items: [
        RewardWheelItem(label: 'A', probabilityBps: 10000),
      ],
    );
    const eligible = RewardWheelConfig(
      isActive: true,
      dailyFreeSpins: 1,
      cooldownHours: 24,
      canSpin: true,
      items: [
        RewardWheelItem(label: 'A', probabilityBps: 10000),
      ],
    );
    const empty = RewardWheelConfig(
      isActive: true,
      dailyFreeSpins: 1,
      cooldownHours: 24,
      canSpin: true,
      items: [],
    );
    expect(published.visibleOnHome, isFalse);
    expect(eligible.visibleOnHome, isTrue);
    expect(empty.visibleOnHome, isFalse);
    expect(
      RewardWheelConfig.fromMap({
        'is_active': true,
        'can_spin': false,
        'items': [
          {'label': 'A', 'probability_bps': 10000},
        ],
      }).visibleOnHome,
      isFalse,
    );
    expect(
      RewardWheelConfig.fromMap({
        'is_active': true,
        'can_spin': true,
        'items': [
          {'label': 'A', 'probability_bps': 10000},
        ],
      }).visibleOnHome,
      isTrue,
    );
    expect(
      RewardWheelSpinResult.fromMap({
        'ok': false,
        'error': 'Çark çevrilemedi.',
      }).canSpin,
      isFalse,
    );
  });

  test('coupon codes are normalized case-insensitively', () {
    expect(CouponCodeGenerator.normalize(' ibul10 '), 'IBUL10');
    expect(CouponCodeGenerator.generate().length, greaterThan(6));
  });
}
