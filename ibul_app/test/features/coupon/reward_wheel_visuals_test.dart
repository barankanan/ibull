import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/coupon/widgets/reward_wheel_visuals.dart';

void main() {
  test('slice sweeps follow weights and start at 12 o clock', () {
    final sweeps = RewardWheelVisuals.sweepsFor(const [50, 25, 25]);
    expect(sweeps, [pi, pi / 2, pi / 2]);
    expect(RewardWheelVisuals.startAngle, -pi / 2);
    expect(
      RewardWheelVisuals.winnerCenter(weights: const [50, 50], index: 0),
      -pi / 2 + pi / 2,
    );
  });

  test('long labels are shortened without breaking layout math', () {
    expect(RewardWheelVisuals.ellipsize('500 TL Hoşgeldin Kuponu', 10).endsWith('…'), isTrue);
    expect(RewardWheelVisuals.ellipsize('Araç', 10), 'Araç');
  });

  test('customer mystery colors stay purple and hide no-prize slate', () {
    expect(RewardWheelVisuals.mysterySliceColor(0), isNot(RewardWheelVisuals.noPrizeColor));
    expect(RewardWheelVisuals.sliceColor(0, isNoPrize: true), RewardWheelVisuals.noPrizeColor);
    for (var i = 0; i < 8; i++) {
      final color = RewardWheelVisuals.mysterySliceColor(i);
      expect(color, isNot(RewardWheelVisuals.noPrizeColor));
    }
  });

  test('spin curve accelerates then coasts to a stop', () {
    const curve = RewardWheelSpinCurve();
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    expect(curve.transform(0.12), lessThan(curve.transform(0.5)));
    expect(curve.transform(0.9) - curve.transform(0.8), lessThan(curve.transform(0.3) - curve.transform(0.2)));
  });
}
