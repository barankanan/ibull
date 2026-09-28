import 'package:flutter/material.dart';

import '../../../features/coupon/widgets/reward_wheel_floating_button.dart'
    deferred as reward_wheel;

/// Coupon wheel stays out of the home chunk until the shell has painted.
class DeferredRewardWheelHomeOverlay extends StatefulWidget {
  const DeferredRewardWheelHomeOverlay({super.key, required this.hasBottomNav});

  final bool hasBottomNav;

  @override
  State<DeferredRewardWheelHomeOverlay> createState() =>
      _DeferredRewardWheelHomeOverlayState();
}

class _DeferredRewardWheelHomeOverlayState
    extends State<DeferredRewardWheelHomeOverlay> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reward_wheel.loadLibrary().then((_) {
        if (mounted) setState(() => _ready = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return reward_wheel.RewardWheelHomeOverlay(
      hasBottomNav: widget.hasBottomNav,
    );
  }
}
