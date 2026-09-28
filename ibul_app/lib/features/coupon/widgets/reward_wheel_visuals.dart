import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/reward_wheel_probability.dart';

/// Shared slice colors. Purple-first, muted slate for "try again".
abstract final class RewardWheelVisuals {
  static const startAngle = -pi / 2;
  static const ringWidth = 16.0;
  static const hubRatio = 0.24;
  static const labelRadiusRatio = 0.64;
  static const pointerColor = Color(0xFFE11D48);
  static const gold = Color(0xFFF5D78A);
  static const goldDeep = Color(0xFFC9A227);

  static const sliceColors = <Color>[
    Color(0xFF7A2FF4),
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFFD97706),
  ];
  static const noPrizeColor = Color(0xFF475569);

  /// Customer-only palette: tonal purple so prize type is not readable.
  static const mysterySliceColors = <Color>[
    Color(0xFF6D28D9),
    Color(0xFF8B5CF6),
    Color(0xFF5B21B6),
    Color(0xFF7A2FF4),
    Color(0xFF4C1D95),
    Color(0xFFA78BFA),
    Color(0xFF7C3AED),
    Color(0xFF6B21A8),
  ];

  static Color sliceColor(int index, {required bool isNoPrize}) {
    if (isNoPrize) return noPrizeColor;
    return sliceColors[index % sliceColors.length];
  }

  static Color mysterySliceColor(int index) =>
      mysterySliceColors[index % mysterySliceColors.length];

  static Color textOn(Color background) =>
      background.computeLuminance() > 0.55 ? const Color(0xFF111827) : Colors.white;

  static String ellipsize(String value, int maxChars) {
    final trimmed = value.trim();
    if (trimmed.length <= maxChars) return trimmed;
    if (maxChars <= 1) return '…';
    return '${trimmed.substring(0, maxChars - 1)}…';
  }

  static List<double> sweepsFor(List<int> weights) {
    if (weights.isEmpty) return const [];
    final total = weights.fold<int>(0, (sum, value) => sum + max(value, 0));
    if (total <= 0) {
      final equal = 2 * pi / weights.length;
      return [for (final _ in weights) equal];
    }
    return [for (final weight in weights) 2 * pi * weight / total];
  }

  static double midAngle(double start, double sweep) => start + sweep / 2;

  static double winnerCenter({
    required List<int> weights,
    required int index,
  }) {
    final sweeps = sweepsFor(weights);
    if (sweeps.isEmpty) return startAngle;
    final safeIndex = index.clamp(0, sweeps.length - 1);
    var start = startAngle;
    for (var i = 0; i < safeIndex; i++) {
      start += sweeps[i];
    }
    return midAngle(start, sweeps[safeIndex]);
  }
}

/// Fast launch, long coast — used only by the customer spin.
class RewardWheelSpinCurve extends Curve {
  const RewardWheelSpinCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.14) {
      return Curves.easeInCubic.transform(t / 0.14) * 0.08;
    }
    return 0.08 + Curves.easeOutCubic.transform((t - 0.14) / 0.86) * 0.92;
  }
}

class RewardWheelSlice {
  const RewardWheelSlice({
    required this.label,
    required this.percent,
    required this.color,
    required this.isNoPrize,
  });

  final String label;
  final int percent;
  final Color color;
  final bool isNoPrize;

  Color get textColor => RewardWheelVisuals.textOn(color);
}

class RewardWheelSlicePainter extends CustomPainter {
  RewardWheelSlicePainter({
    required this.slices,
    this.showLabels = true,
    this.mystery = false,
  });

  final List<RewardWheelSlice> slices;
  final bool showLabels;
  final bool mystery;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweeps = RewardWheelVisuals.sweepsFor(
      slices.map((slice) => slice.percent).toList(),
    );
    var start = RewardWheelVisuals.startAngle;
    final fill = Paint()..style = PaintingStyle.fill;
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mystery ? 1.6 : 2
      ..color = mystery
          ? RewardWheelVisuals.gold.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.88);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mystery ? 3.2 : 2.4
      ..color = mystery ? RewardWheelVisuals.gold : const Color(0xFFF8FAFC);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweep = sweeps[i];
      if (mystery) {
        fill.shader = RadialGradient(
          center: const Alignment(-0.28, -0.38),
          radius: 1.12,
          colors: [
            Color.lerp(slice.color, Colors.white, 0.28)!,
            slice.color,
            Color.lerp(slice.color, const Color(0xFF1E1B4B), 0.38)!,
          ],
          stops: const [0.08, 0.52, 1],
        ).createShader(rect);
      } else {
        fill.shader = null;
        fill.color = slice.color;
      }
      canvas.drawArc(rect, start, sweep, true, fill);
      canvas.drawArc(rect, start, sweep, true, divider);
      if (mystery) {
        _paintMysteryMark(
          canvas: canvas,
          center: center,
          radius: radius,
          start: start,
          sweep: sweep,
        );
      } else if (showLabels) {
        _paintLabel(
          canvas: canvas,
          center: center,
          radius: radius,
          start: start,
          sweep: sweep,
          slice: slice,
        );
      }
      start += sweep;
    }

    if (mystery) {
      final gloss = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.55),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawCircle(center, radius, gloss);
    }
    canvas.restore();
    canvas.drawCircle(center, radius, rim);
  }

  void _paintMysteryMark({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double start,
    required double sweep,
  }) {
    if (sweep < 0.22) return;
    final mid = RewardWheelVisuals.midAngle(start, sweep);
    final pos = Offset(
      center.dx + radius * 0.66 * cos(mid),
      center.dy + radius * 0.66 * sin(mid),
    );
    final gem = Path();
    const r = 5.4;
    gem
      ..moveTo(pos.dx, pos.dy - r)
      ..lineTo(pos.dx + r * 0.38, pos.dy)
      ..lineTo(pos.dx, pos.dy + r)
      ..lineTo(pos.dx - r * 0.38, pos.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()..color = RewardWheelVisuals.gold.withValues(alpha: 0.92),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _paintLabel({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double start,
    required double sweep,
    required RewardWheelSlice slice,
  }) {
    if (sweep < 0.18) return;
    final mid = RewardWheelVisuals.midAngle(start, sweep);
    final maxChars = sweep < 0.45 ? 8 : 14;
    final name = RewardWheelVisuals.ellipsize(slice.label, maxChars);
    final percent = '%${slice.percent}';
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: slice.textColor,
          fontSize: sweep < 0.4 ? 9 : 11,
          fontWeight: FontWeight.w800,
          height: 1.05,
          shadows: const [Shadow(color: Color(0x66000000), blurRadius: 2)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: radius * 0.62);
    final percentPainter = TextPainter(
      text: TextSpan(
        text: percent,
        style: TextStyle(
          color: slice.textColor.withValues(alpha: 0.92),
          fontSize: sweep < 0.4 ? 10 : 12,
          fontWeight: FontWeight.w700,
          height: 1.05,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRadius = radius * RewardWheelVisuals.labelRadiusRatio;
    canvas.save();
    canvas.translate(
      center.dx + labelRadius * cos(mid),
      center.dy + labelRadius * sin(mid),
    );
    var rotation = mid + pi / 2;
    if (rotation > pi / 2 && rotation < 3 * pi / 2) {
      rotation += pi;
    }
    canvas.rotate(rotation);
    final totalHeight = namePainter.height + 2 + percentPainter.height;
    namePainter.paint(canvas, Offset(-namePainter.width / 2, -totalHeight / 2));
    percentPainter.paint(
      canvas,
      Offset(-percentPainter.width / 2, -totalHeight / 2 + namePainter.height + 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RewardWheelSlicePainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.mystery != mystery;
}

class RewardWheelPointerPainter extends CustomPainter {
  RewardWheelPointerPainter({this.premium = false});

  final bool premium;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(4, 8)
      ..quadraticBezierTo(size.width / 2, 0, size.width - 4, 8)
      ..close();
    canvas.drawShadow(path, const Color(0x99000000), premium ? 6 : 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = premium ? const Color(0xFFBE123C) : RewardWheelVisuals.pointerColor,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = premium ? 1.8 : 1.4
        ..color = premium ? RewardWheelVisuals.gold : Colors.white,
    );
    if (premium) {
      canvas.drawCircle(
        Offset(size.width / 2, 11),
        2.2,
        Paint()..color = RewardWheelVisuals.gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RewardWheelPointerPainter oldDelegate) =>
      oldDelegate.premium != premium;
}

class RewardWheelRingDotsPainter extends CustomPainter {
  RewardWheelRingDotsPainter({this.count = 16, this.premium = false});

  final int count;
  final bool premium;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - (premium ? 7.5 : 6);
    final fill = Paint()..color = premium ? RewardWheelVisuals.gold : Colors.white;
    final glow = Paint()
      ..color = premium ? const Color(0xCCFDE68A) : const Color(0xB3FDE68A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    final core = Paint()..color = Colors.white;
    for (var i = 0; i < count; i++) {
      final angle = RewardWheelVisuals.startAngle + (2 * pi * i / count);
      final offset = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawCircle(offset, premium ? 3.8 : 3.4, glow);
      canvas.drawCircle(offset, premium ? 2.5 : 2.6, fill);
      if (premium) canvas.drawCircle(offset, 1.1, core);
    }
  }

  @override
  bool shouldRepaint(covariant RewardWheelRingDotsPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.premium != premium;
}

class RewardWheelHubButton extends StatelessWidget {
  const RewardWheelHubButton({
    required this.size,
    required this.label,
    this.busy = false,
    this.premium = false,
    this.onTap,
    super.key,
  });

  final double size;
  final String label;
  final bool busy;
  final bool premium;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: premium ? const Color(0xFF4C1D95) : Colors.white,
      shape: const CircleBorder(),
      elevation: premium ? 10 : 6,
      shadowColor: AppColors.primary.withValues(alpha: premium ? 0.45 : 0.28),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: premium ? RewardWheelVisuals.gold : const Color(0xFFE9D5FF),
              width: premium ? 3.4 : 3,
            ),
            gradient: premium
                ? const RadialGradient(
                    center: Alignment(-0.25, -0.3),
                    colors: [Color(0xFF9F67FF), Color(0xFF5B21B6)],
                  )
                : const RadialGradient(
                    colors: [Colors.white, Color(0xFFF5F3FF)],
                  ),
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: size * 0.34,
                    height: size * 0.34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: premium ? RewardWheelVisuals.gold : AppColors.primary,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: premium ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: size < 64 ? 11 : 13,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

int rewardWheelPercentOf(int bps) => RewardWheelProbability.bpsToPercent(bps);
