import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../helpers/seller_badge_visuals.dart';
import '../models/seller_badge_models.dart';

/// Katmanlı premium rozet ikonu — glow replay token destekli.
class SellerBadgeIcon extends StatefulWidget {
  const SellerBadgeIcon({
    super.key,
    required this.progress,
    this.size = 42,
    this.showLabel = false,
    this.animateGlow = false,
    this.glowReplayToken = 0,
    this.compact = false,
  });

  final SellerBadgeProgress progress;
  final double size;
  final bool showLabel;
  final bool animateGlow;
  final int glowReplayToken;
  final bool compact;

  @override
  State<SellerBadgeIcon> createState() => _SellerBadgeIconState();
}

class _SellerBadgeIconState extends State<SellerBadgeIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _glowController;
  int _lastReplayToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureGlowIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SellerBadgeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glowReplayToken != widget.glowReplayToken &&
        widget.glowReplayToken != _lastReplayToken) {
      _lastReplayToken = widget.glowReplayToken;
      _restartGlow();
      return;
    }
    if (widget.animateGlow && !oldWidget.animateGlow) {
      _restartGlow();
      return;
    }
    if (!widget.animateGlow &&
        oldWidget.animateGlow &&
        widget.glowReplayToken == 0) {
      _disposeGlow();
      return;
    }
    if (oldWidget.progress.definition.badgeId !=
        widget.progress.definition.badgeId) {
      _disposeGlow();
      _ensureGlowIfNeeded();
    }
  }

  void _ensureGlowIfNeeded() {
    if (widget.animateGlow && _glowController == null) {
      _restartGlow();
    }
  }

  bool get _reduceMotion {
    return WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.reduceMotion ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
  }

  void _restartGlow() {
    if (!widget.progress.allowsPremiumGlow) return;
    if (_reduceMotion) return;
    _disposeGlow();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..forward();
  }

  void _disposeGlow() {
    _glowController?.dispose();
    _glowController = null;
  }

  @override
  void dispose() {
    _disposeGlow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.progress.definition;
    final visual = sellerBadgeVisualSpec(widget.progress);
    final isNewSeller = definition.badgeId == 'new_seller';

    Widget badge = _buildLayeredBadge(visual);

    if (_glowController != null) {
      badge = AnimatedBuilder(
        animation: _glowController!,
        builder: (context, child) {
          final t = _glowController!.value;
          final rise = t < 0.42
              ? Curves.easeOutCubic.transform(t / 0.42)
              : Curves.easeInCubic.transform((1 - t) / 0.58);
          final scale = 1.0 + (0.09 * rise);
          final glow = rise;
          final sweepRotation = t * math.pi * 2.2;
          final sparkle = (math.sin(t * math.pi * 4) * 0.5 + 0.5) * rise;

          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: visual.depthShadowColor
                        .withValues(alpha: 0.14 + 0.34 * glow),
                    blurRadius: 8 + 20 * glow,
                    spreadRadius: 0.5 + 4 * glow,
                    offset: Offset(0, 3 + 2 * glow),
                  ),
                  BoxShadow(
                    color: visual.accentColor.withValues(alpha: 0.1 + 0.3 * glow),
                    blurRadius: 12 + 24 * glow,
                    spreadRadius: 1 + 3 * glow,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06 + 0.14 * glow),
                    blurRadius: 18 + 10 * sparkle,
                    spreadRadius: 1.5 * glow,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child!,
                  if (glow > 0.08)
                    Transform.rotate(
                      angle: sweepRotation,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.42 * glow),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.12, 0.22, 1.0],
                          ),
                        ),
                      ),
                    ),
                  if (sparkle > 0.2) ...[
                    Positioned(
                      top: widget.size * 0.08,
                      right: widget.size * 0.14,
                      child: _sparkleDot(visual.sparkleColor, sparkle * 0.9),
                    ),
                    Positioned(
                      bottom: widget.size * 0.16,
                      left: widget.size * 0.12,
                      child: _sparkleDot(visual.sparkleColor, sparkle * 0.7),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        child: badge,
      );
    }

    if (!widget.showLabel) return badge;

    return SizedBox(
      width: widget.compact ? 72 : 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(height: 6),
          Text(
            definition.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: widget.compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              height: 1.15,
            ),
          ),
          if (isNewSeller) ...[
            const SizedBox(height: 2),
            Text(
              'İBUL’a yeni katılan mağaza',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade600,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sparkleDot(Color color, double opacity) {
    return Container(
      width: widget.size * 0.1,
      height: widget.size * 0.1,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.25 + 0.55 * opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35 * opacity),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _buildLayeredBadge(SellerBadgeVisualSpec visual) {
    final rimWidth = visual.badgeShapeVariant == 1 ? 2.4 : 2.0;
    final innerSize = widget.size - rimWidth * 2;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Depth shadow plate
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: visual.depthShadowColor.withValues(alpha: 0.22),
                  blurRadius: 6 + visual.specialEffectLevel.toDouble(),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          // Outer rim (bevel)
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: visual.rimGradient,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Inner surface
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.32, -0.4),
                radius: 1.05,
                colors: visual.backgroundGradient,
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner highlight
                Positioned(
                  top: innerSize * 0.08,
                  left: innerSize * 0.14,
                  child: Container(
                    width: innerSize * 0.42,
                    height: innerSize * 0.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Icon with subtle depth
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(visual.iconColor, Colors.white, 0.22)!,
                        visual.iconColor,
                        Color.lerp(visual.iconColor, visual.accentColor, 0.35)!,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: Icon(
                    visual.icon,
                    size: innerSize * 0.5,
                    color: Colors.white,
                  ),
                ),
                // Accent glyph
                if (visual.accentGlyph != null)
                  Positioned(
                    right: innerSize * 0.1,
                    top: innerSize * 0.08,
                    child: Icon(
                      visual.accentGlyph,
                      size: innerSize * 0.22,
                      color: visual.sparkleColor.withValues(alpha: 0.92),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
