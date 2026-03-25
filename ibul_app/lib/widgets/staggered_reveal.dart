import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../core/app_motion.dart';

/// An [InheritedWidget] that carries the image-ready [ValueNotifier] created
/// by [StaggeredReveal] down to any [OptimizedImage] / [ProductCard] inside
/// the reveal child. The child fires the notifier once its primary image has
/// been decoded so that the slide animation starts only after the GPU texture
/// upload is complete, eliminating same-frame contention.
///
/// Call [StaggeredRevealSignal.maybeOf] from within any widget that is a
/// descendant of [StaggeredReveal] to obtain the notifier. The notifier is
/// `null` when either the item has already been revealed or the reveal is
/// disabled — in that case nothing needs to be deferred.
class StaggeredRevealSignal extends InheritedWidget {
  const StaggeredRevealSignal({
    super.key,
    required this.signal,
    required super.child,
  });

  final ValueNotifier<bool>? signal;

  /// Returns the nearest ancestor [StaggeredRevealSignal]'s notifier, or
  /// `null` if there is none (item already revealed / reveal disabled).
  static ValueNotifier<bool>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StaggeredRevealSignal>()
        ?.signal;
  }

  @override
  bool updateShouldNotify(StaggeredRevealSignal old) => signal != old.signal;
}

class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.revealId,
    required this.index,
    required this.child,
    this.enabled = true,
    this.stepDelay = const Duration(milliseconds: 28),
    this.duration = AppMotion.revealTransitionDuration,
    this.maxStaggerSteps = 8,
    this.beginOffset = const Offset(0, 0.03),
  });

  final String revealId;
  final int index;
  final Widget child;
  final bool enabled;
  final Duration stepDelay;
  final Duration duration;
  final int maxStaggerSteps;
  final Offset beginOffset;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  static const int _maxSeenEntries = 600;
  static final LinkedHashSet<String> _seenRevealIds = LinkedHashSet<String>();

  Timer? _timer;
  bool _isVisible = true;
  String? _scheduledRevealId;

  // Owned signal provided to the child via StaggeredRevealSignal. Created
  // fresh each time we enter a not-yet-revealed state, disposed on teardown.
  ValueNotifier<bool>? _ownedImageSignal;

  // Tracks the signal we currently have a listener on (always == _ownedImageSignal).
  ValueNotifier<bool>? _attachedSignal;

  // Explicit controller so SlideTransition can drive compositing without
  // calling setState on every animation tick (GPU-light path).
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: widget.duration);
    _buildSlideAnimation();
    _configureAnimation();
    _animController.value = _isVisible ? 1.0 : 0.0;
  }

  void _buildSlideAnimation() {
    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: AppMotion.revealCurve,
    ));
  }

  @override
  void didUpdateWidget(covariant StaggeredReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _animController.duration = widget.duration;
    }
    if (oldWidget.beginOffset != widget.beginOffset) {
      _buildSlideAnimation();
    }
    if (oldWidget.revealId != widget.revealId ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.index != widget.index) {
      _configureAnimation();
      if (_isVisible) _animController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _detachSignal();
    _ownedImageSignal?.dispose();
    _ownedImageSignal = null;
    _animController.dispose();
    super.dispose();
  }

  void _detachSignal() {
    _attachedSignal?.removeListener(_onImageReady);
    _attachedSignal = null;
  }

  void _onImageReady() {
    if (_attachedSignal?.value != true) return;
    _detachSignal();
    _startTimer();
  }

  bool _animationsDisabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);
  }

  void _rememberReveal(String revealId) {
    if (_seenRevealIds.contains(revealId)) return;
    _seenRevealIds.add(revealId);
    while (_seenRevealIds.length > _maxSeenEntries) {
      _seenRevealIds.remove(_seenRevealIds.first);
    }
  }

  void _configureAnimation() {
    _timer?.cancel();
    _detachSignal();
    _ownedImageSignal?.dispose();
    _ownedImageSignal = null;

    final revealId = widget.revealId.trim();
    if (!widget.enabled || revealId.isEmpty) {
      _scheduledRevealId = null;
      _isVisible = true;
      return;
    }

    if (_seenRevealIds.contains(revealId)) {
      _scheduledRevealId = revealId;
      _isVisible = true;
      return;
    }

    _scheduledRevealId = revealId;
    _isVisible = false;
    _animController.value = 0.0;

    // Create an owned signal exposed to children via StaggeredRevealSignal.
    // The child (e.g. ProductCard / OptimizedImage) must flip this to `true`
    // once its primary image texture has been uploaded to the GPU, at which
    // point we start the stagger delay so animation and texture upload do
    // not compete on the same frame.
    _ownedImageSignal = ValueNotifier<bool>(false);
    _attachedSignal = _ownedImageSignal;
    _ownedImageSignal!.addListener(_onImageReady);
  }

  void _startTimer() {
    final revealId = _scheduledRevealId;
    if (revealId == null || !mounted) return;
    final staggerStep = widget.index.clamp(0, widget.maxStaggerSteps);
    final delay = widget.stepDelay * staggerStep;
    _timer = Timer(delay, () {
      if (!mounted || _scheduledRevealId != revealId) return;
      _rememberReveal(revealId);
      setState(() {
        _isVisible = true;
      });
      _animController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final revealId = widget.revealId.trim();
    if (!widget.enabled || _animationsDisabled(context)) {
      if (revealId.isNotEmpty) {
        _rememberReveal(revealId);
      }
      return StaggeredRevealSignal(signal: null, child: widget.child);
    }

    if (_isVisible && revealId.isNotEmpty && _seenRevealIds.contains(revealId)) {
      return StaggeredRevealSignal(signal: null, child: widget.child);
    }

    return StaggeredRevealSignal(
      signal: _ownedImageSignal,
      child: RepaintBoundary(
        // SlideTransition drives the compositor directly (no setState per tick),
        // keeping this animation GPU-light on the raster thread.
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
