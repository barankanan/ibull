import 'dart:async';

import 'package:flutter/material.dart';

import 'app_perf_logger.dart';
import 'home_section_trace.dart';
class LazySectionLoader extends StatefulWidget {
  const LazySectionLoader({
    required this.sectionName,
    required this.loader,
    required this.builder,
    required this.skeleton,
    this.scrollController,
    this.prefetchExtent = 480,
    this.fallbackDelay = const Duration(milliseconds: 120),
    this.maxSkeletonDuration = const Duration(seconds: 10),
    this.loadTimeout = const Duration(seconds: 10),
    super.key,
  });

  final String sectionName;
  final Future<void> Function() loader;
  final Widget Function(bool isLoaded) builder;
  final Widget skeleton;
  final ScrollController? scrollController;
  final double prefetchExtent;
  final Duration fallbackDelay;
  final Duration maxSkeletonDuration;
  final Duration loadTimeout;

  @override
  State<LazySectionLoader> createState() => _LazySectionLoaderState();
}

class _LazySectionLoaderState extends State<LazySectionLoader> {
  bool _loaded = false;
  bool _loading = false;
  bool _scheduled = false;
  Timer? _maxSkeletonTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
    _maxSkeletonTimer = Timer(widget.maxSkeletonDuration, _forceComplete);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeTrigger(from: 'postFrame', ignoreViewport: true);
      Future<void>.delayed(widget.fallbackDelay, () {
        if (mounted) _maybeTrigger(from: 'fallback', ignoreViewport: true);
      });
    });
  }

  @override
  void didUpdateWidget(covariant LazySectionLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _maxSkeletonTimer?.cancel();
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _maybeTrigger(from: 'scroll');

  void _forceComplete() {
    if (!mounted || _loaded) return;
    _completeLoad(source: 'timeout', state: 'timeout');
  }

  void _maybeTrigger({required String from, bool ignoreViewport = false}) {
    if (_loaded || _loading || _scheduled) return;
    if (!ignoreViewport && !_isNearViewport()) return;
    _scheduled = true;
    unawaited(_startLoad(from: from));
  }

  bool _isNearViewport() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return true;

    final offset = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottom = offset.dy + renderObject.size.height;
    return bottom >= -widget.prefetchExtent &&
        offset.dy <= screenHeight + widget.prefetchExtent;
  }

  Future<void> _startLoad({required String from}) async {
    if (_loading || _loaded) return;
    _loading = true;
    final started = DateTime.now().millisecondsSinceEpoch;
    var state = 'hasData';
    var source = from;
    String? error;

    try {
      await widget.loader().timeout(widget.loadTimeout);
    } on TimeoutException {
      state = 'timeout';
      source = 'timeout';
      error = 'timeout';
    } catch (e) {
      state = 'error';
      error = e.toString();
    }

    if (!mounted) return;
    _completeLoad(
      source: source,
      state: state,
      error: error,
      ms: DateTime.now().millisecondsSinceEpoch - started,
    );
  }

  void _completeLoad({
    required String source,
    required String state,
    String? error,
    int? ms,
  }) {
    _maxSkeletonTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _loading = false;
    });
    AppPerfLogger.logHomeSection(
      sectionName: widget.sectionName,
      source: source,
      state: state,
      ms: ms,
      error: error,
    );
    notifyHomeSectionLoadOutcome(
      sectionName: widget.sectionName,
      source: source,
      state: state,
      elapsedMs: ms,
      error: error,
      timeoutMs: widget.loadTimeout.inMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return widget.skeleton;
    }
    return widget.builder(true);
  }
}
