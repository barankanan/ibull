import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/ibul_chrome.dart';
import '../../../services/coupon_service.dart';
import '../../../widgets/game/fortune_wheel_dialog.dart';
import '../data/coupon_repository.dart';

/// Layout-only metrics. Visibility must not use screen width.
abstract final class RewardWheelFabMetrics {
  static const double desktopSize = 56;
  static const double mobileSize = 52;
  static const double edge = 16;
  static const double desktopGap = 16;
  static const double mobileGap = 12;

  static bool shouldShow({required bool canSpin}) => canSpin;

  static bool isCompactWidth(double width) => width < IbulChrome.web;

  static double sizeFor(double width) =>
      isCompactWidth(width) ? mobileSize : desktopSize;

  /// [overlayInScaffoldBody] is true when the overlay is a Scaffold.body child.
  /// Body already sits above [BottomNavigationBar]; do not add nav height again.
  static double bottomOffset({
    required bool overlayInScaffoldBody,
    required bool hasBottomNav,
    required double safeAreaBottom,
  }) {
    if (overlayInScaffoldBody) {
      if (hasBottomNav) return mobileGap;
      return desktopGap + safeAreaBottom;
    }
    final nav = hasBottomNav ? kBottomNavigationBarHeight + safeAreaBottom : 0;
    return (hasBottomNav ? mobileGap : desktopGap) + nav;
  }
}

/// Shared home overlay — one widget for desktop, tablet, mobile web and apps.
class RewardWheelHomeOverlay extends StatefulWidget {
  const RewardWheelHomeOverlay({
    super.key,
    required this.hasBottomNav,
    this.wheelActive,
  });

  /// True when Scaffold shows the marketplace bottom bar (width < 1100).
  final bool hasBottomNav;

  /// Test-only override. Production leaves this null and uses server can_spin.
  final bool? wheelActive;

  @override
  State<RewardWheelHomeOverlay> createState() => _RewardWheelHomeOverlayState();
}

class _RewardWheelHomeOverlayState extends State<RewardWheelHomeOverlay> {
  late bool _visible = widget.wheelActive ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.wheelActive == null) {
      CouponService().addListener(_onEligibilitySignal);
      _resolveFromServer();
    }
  }

  @override
  void didUpdateWidget(covariant RewardWheelHomeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wheelActive != oldWidget.wheelActive &&
        widget.wheelActive != null) {
      _visible = widget.wheelActive!;
    }
  }

  @override
  void dispose() {
    if (widget.wheelActive == null) {
      CouponService().removeListener(_onEligibilitySignal);
    }
    super.dispose();
  }

  void _onEligibilitySignal() {
    if (widget.wheelActive != null) return;
    _resolveFromServer();
  }

  Future<void> _resolveFromServer() async {
    try {
      final config = await CouponRepository().loadWheelForUser();
      final visible = config != null && config.visibleOnHome;
      if (!mounted) return;
      setState(() => _visible = visible);
    } catch (error, stack) {
      debugPrint('RewardWheelHomeOverlay: $error\n$stack');
      if (!mounted) return;
      setState(() => _visible = false);
    }
  }

  void _onSpinComplete() {
    if (widget.wheelActive != null) return;
    if (mounted) setState(() => _visible = false);
    _resolveFromServer();
  }

  @override
  Widget build(BuildContext context) {
    if (!RewardWheelFabMetrics.shouldShow(canSpin: _visible)) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final size = RewardWheelFabMetrics.sizeFor(width);
    final bottom = RewardWheelFabMetrics.bottomOffset(
      overlayInScaffoldBody: true,
      hasBottomNav: widget.hasBottomNav,
      safeAreaBottom: safeBottom,
    );

    return Positioned(
      right: RewardWheelFabMetrics.edge,
      bottom: bottom,
      child: RewardWheelFloatingButton(
        size: size,
        onSpinComplete: _onSpinComplete,
      ),
    );
  }
}

class RewardWheelFloatingButton extends StatelessWidget {
  const RewardWheelFloatingButton({super.key, this.size = 56, this.onSpinComplete});

  final double size;
  final VoidCallback? onSpinComplete;

  static Future<void> open(
    BuildContext context, {
    VoidCallback? onSpinComplete,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x9908041A),
      builder: (_) => FortuneWheelDialog(onSpinComplete: onSpinComplete),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = size <= RewardWheelFabMetrics.mobileSize ? 24.0 : 28.0;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: AppColors.primary,
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => open(context, onSpinComplete: onSpinComplete),
          child: Tooltip(
            message: 'Hediye Çarkı',
            child: Icon(
              Icons.casino_outlined,
              color: Colors.white,
              size: iconSize,
              semanticLabel: 'Hediye Çarkı',
            ),
          ),
        ),
      ),
    );
  }
}
