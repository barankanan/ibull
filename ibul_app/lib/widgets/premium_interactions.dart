import 'package:flutter/material.dart';
import '../core/app_motion.dart';

const Duration kPremiumInteractionDuration = AppMotion.fastInteractionDuration;
const Curve kPremiumInteractionCurve = AppMotion.tapFeedbackCurve;

class PremiumPressable extends StatefulWidget {
  const PremiumPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.enableHover = true,
    this.pressedScale = 0.985,
    this.hoverScale = 1.006,
    this.hoverLift = 1.5,
    this.pressedOpacity = 0.985,
    this.hoverOpacity = 1,
    this.duration = kPremiumInteractionDuration,
    this.curve = kPremiumInteractionCurve,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final Widget child;
  final bool enabled;
  final bool enableHover;
  final double pressedScale;
  final double hoverScale;
  final double hoverLift;
  final double pressedOpacity;
  final double hoverOpacity;
  final Duration duration;
  final Curve curve;
  final MouseCursor mouseCursor;

  @override
  State<PremiumPressable> createState() => _PremiumPressableState();
}

class _PremiumPressableState extends State<PremiumPressable> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  void _setHovered(bool value) {
    if (!widget.enabled || !widget.enableHover || _hovered == value) return;
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hovered =
        widget.enabled && widget.enableHover && _hovered && !_pressed;
    final scale = _pressed
        ? widget.pressedScale
        : (hovered ? widget.hoverScale : 1.0);
    final opacity = _pressed
        ? widget.pressedOpacity
        : (hovered ? widget.hoverOpacity : 1.0);
    final translateY = hovered ? -widget.hoverLift : 0.0;

    return MouseRegion(
      cursor: widget.enabled ? widget.mouseCursor : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedOpacity(
          duration: widget.duration,
          curve: widget.curve,
          opacity: opacity,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: translateY),
            duration: widget.duration,
            curve: widget.curve,
            builder: (context, animatedTranslateY, child) {
              return Transform.translate(
                offset: Offset(0, animatedTranslateY),
                child: AnimatedScale(
                  duration: widget.duration,
                  curve: widget.curve,
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

ButtonStyle premiumButtonInteractionStyle(
  ButtonStyle style, {
  Color? overlayColor,
  Duration duration = kPremiumInteractionDuration,
}) {
  final resolvedOverlayColor = overlayColor ?? Colors.black;

  return style.copyWith(
    animationDuration: duration,
    mouseCursor: const WidgetStatePropertyAll<MouseCursor>(
      SystemMouseCursors.click,
    ),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return resolvedOverlayColor.withValues(alpha: 0.10);
      }
      if (states.contains(WidgetState.hovered)) {
        return resolvedOverlayColor.withValues(alpha: 0.06);
      }
      if (states.contains(WidgetState.focused)) {
        return resolvedOverlayColor.withValues(alpha: 0.08);
      }
      return null;
    }),
  );
}
