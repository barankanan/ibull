import 'package:flutter/material.dart';

import '../domain/coupon_models.dart';
import 'reward_wheel_visuals.dart';

class RewardWheelPreview extends StatelessWidget {
  const RewardWheelPreview({
    required this.items,
    this.size = 268,
    super.key,
  });

  final List<RewardWheelItem> items;
  final double size;

  List<RewardWheelSlice> get _slices {
    final source = items.isEmpty
        ? const [
            RewardWheelItem(
              label: 'Ödül yok',
              probabilityBps: 10000,
              isNoPrize: true,
            ),
          ]
        : items;
    return [
      for (var i = 0; i < source.length; i++)
        RewardWheelSlice(
          label: source[i].label,
          percent: rewardWheelPercentOf(source[i].probabilityBps),
          color: RewardWheelVisuals.sliceColor(
            i,
            isNoPrize: source[i].isNoPrize,
          ),
          isNoPrize: source[i].isNoPrize,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final slices = _slices;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final wheel = _WheelFace(size: size, slices: slices);
        final legend = RewardWheelLegend(slices: slices);
        if (!wide) {
          return Column(
            children: [
              wheel,
              const SizedBox(height: 14),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            wheel,
            const SizedBox(width: 18),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _WheelFace extends StatelessWidget {
  const _WheelFace({required this.size, required this.slices});

  final double size;
  final List<RewardWheelSlice> slices;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 18,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 18,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1B4B),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A2FF4).withValues(alpha: 0.18),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18 + RewardWheelVisuals.ringWidth,
            child: SizedBox(
              width: size - RewardWheelVisuals.ringWidth * 2,
              height: size - RewardWheelVisuals.ringWidth * 2,
              child: CustomPaint(
                painter: RewardWheelSlicePainter(
                  slices: slices,
                  showLabels: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: SizedBox(
              width: 28,
              height: 34,
              child: CustomPaint(painter: RewardWheelPointerPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: RewardWheelHubButton(
              size: size * RewardWheelVisuals.hubRatio,
              label: 'ÇARK',
            ),
          ),
        ],
      ),
    );
  }
}

class RewardWheelLegend extends StatelessWidget {
  const RewardWheelLegend({required this.slices, super.key});

  final List<RewardWheelSlice> slices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ödül dağılımı',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Tooltip(
              message: '${slice.label} — %${slice.percent}',
              waitDuration: const Duration(milliseconds: 280),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Text(
                    '%${slice.percent}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4C1D95),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
