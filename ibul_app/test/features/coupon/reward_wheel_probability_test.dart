import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/coupon/domain/coupon_campaign.dart';
import 'package:ibul_app/features/coupon/domain/coupon_enums.dart';
import 'package:ibul_app/features/coupon/domain/coupon_models.dart';
import 'package:ibul_app/features/coupon/domain/reward_wheel_personalization.dart';
import 'package:ibul_app/features/coupon/domain/reward_wheel_probability.dart';

CouponCampaign _coupon({
  required String id,
  required String name,
  DateTime? startsAt,
  DateTime? endsAt,
  CouponApprovalStatus approval = CouponApprovalStatus.approved,
  int usedCount = 0,
  int? quota,
  List<String> categoryNames = const [],
}) {
  return CouponCampaign(
    id: id,
    name: name,
    code: name.toUpperCase(),
    sourceType: CouponSourceType.ibul,
    discountType: CouponDiscountType.percent,
    discountValue: 10,
    minOrderAmount: 0,
    startsAt: startsAt ?? DateTime.utc(2026, 1, 1),
    endsAt: endsAt ?? DateTime.utc(2026, 12, 31),
    approvalStatus: approval,
    scopeType: CouponScopeType.categories,
    usedCount: usedCount,
    totalUsageLimit: quota,
    categoryNames: categoryNames,
  );
}

void main() {
  test('remainder distribute fills selected coupons to 100 without floats', () {
    const current = [40, 10, 10];
    expect(RewardWheelProbability.totalPercent(current), 60);
    expect(RewardWheelProbability.isComplete(current), isFalse);
    expect(RewardWheelProbability.remainingPercent(current), 40);

    final filled = RewardWheelProbability.distributeRemainder(
      current,
      targetIndexes: const [1, 2],
    );
    expect(filled, [40, 30, 30]);
    expect(RewardWheelProbability.isComplete(filled), isTrue);
    expect(RewardWheelProbability.percentToBps(filled[0]), 4000);
    expect(
      filled.fold<int>(0, (sum, value) => sum + RewardWheelProbability.percentToBps(value)),
      10000,
    );
  });

  test('equal distribute always sums to 100', () {
    for (final count in [1, 2, 3, 7, 11]) {
      final parts = RewardWheelProbability.equalDistribute(count);
      expect(RewardWheelProbability.totalPercent(parts), 100);
    }
  });

  test('parsePercent ignores decimals that would break save', () {
    expect(RewardWheelProbability.parsePercent('10.9'), 11);
    expect(RewardWheelProbability.parsePercent('99.999999'), 100);
    expect(RewardWheelProbability.parsePercent('abc'), 0);
  });

  test('personalization keeps admin probabilities and dumps leftover on no-prize', () {
    final electronics = _coupon(
      id: 'e1',
      name: 'Elektronik',
      categoryNames: const ['elektronik'],
    );
    final food = _coupon(
      id: 'f1',
      name: 'Yemek',
      categoryNames: const ['yemek'],
    );
    const items = [
      RewardWheelItem(label: 'Tekrar dene', isNoPrize: true, probabilityBps: 4000),
      RewardWheelItem(label: 'Elektronik', campaignId: 'e1', probabilityBps: 1000),
      RewardWheelItem(label: 'Yemek', campaignId: 'f1', probabilityBps: 5000),
    ];
    final composed = RewardWheelPersonalization.compose(
      items: items,
      campaigns: {electronics.id: electronics, food.id: food},
      signals: RewardWheelSignalSnapshot.fromTokens(categories: ['elektronik']),
      useGlobalPool: false,
    );
    expect(composed.any((item) => item.campaignId == 'f1'), isFalse);
    expect(composed.any((item) => item.campaignId == 'e1'), isTrue);
    final electronicsItem = composed.firstWhere((item) => item.campaignId == 'e1');
    expect(electronicsItem.probabilityBps, 1000);
    final noPrize = composed.firstWhere((item) => item.isNoPrize);
    expect(noPrize.probabilityBps, 9000);
  });

  test('expired and quota-exhausted coupons cannot enter the wheel pool', () {
    final expired = _coupon(
      id: 'x1',
      name: 'Eski',
      endsAt: DateTime.utc(2026, 1, 1),
    );
    final exhausted = _coupon(
      id: 'q1',
      name: 'Kota',
      usedCount: 10,
      quota: 10,
    );
    expect(
      RewardWheelPersonalization.isCouponEligible(
        expired,
        now: DateTime.utc(2026, 9, 21),
      ),
      isFalse,
    );
    expect(
      RewardWheelPersonalization.isCouponEligible(
        exhausted,
        now: DateTime.utc(2026, 9, 21),
      ),
      isFalse,
    );
  });
}
