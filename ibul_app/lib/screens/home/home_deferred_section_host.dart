import 'package:flutter/material.dart';

import '../../widgets/skeleton_loading.dart';

typedef HomeSectionLibraryLoader = Future<void> Function();
typedef HomeSectionWidgetBuilder = Widget Function();

/// Loads a deferred home section library after first frame; shows skeleton until ready.
class HomeDeferredSectionHost extends StatefulWidget {
  const HomeDeferredSectionHost({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.placeholder,
    this.delay = Duration.zero,
    this.onLoaded,
  });

  final HomeSectionLibraryLoader loadLibrary;
  final HomeSectionWidgetBuilder builder;
  final Widget? placeholder;
  final Duration delay;
  final VoidCallback? onLoaded;

  @override
  State<HomeDeferredSectionHost> createState() =>
      _HomeDeferredSectionHostState();
}

class _HomeDeferredSectionHostState extends State<HomeDeferredSectionHost> {
  Widget? _child;
  Object? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
  }

  Future<void> _scheduleLoad() async {
    if (_started) return;
    _started = true;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted) return;
    try {
      await widget.loadLibrary();
      if (!mounted) return;
      widget.onLoaded?.call();
      setState(() => _child = widget.builder());
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_child != null) return _child!;
    if (_error != null) return const SizedBox.shrink();
    return widget.placeholder ??
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SkeletonLoading(
            width: double.infinity,
            height: 120,
            borderRadius: 12,
          ),
        );
  }
}
