import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/home_data_diagnostics.dart';
import '../../../core/web_perf_trace.dart';
import '../../../models/db_product.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_full_rail.dart' deferred as full_rail_section;

/// Lazy full product rail — must call [full_rail_section.loadLibrary] before factory.
class DeferredHomeFullRailSection extends StatefulWidget {
  const DeferredHomeFullRailSection({
    super.key,
    this.delay = Duration.zero,
    required this.title,
    required this.products,
    this.isLoading = false,
    this.maxItems = 12,
    this.errorMessage,
    this.onRetry,
    this.showViewAll = true,
    this.suppressSkeleton = false,
    this.maxSkeletonDuration = const Duration(seconds: 4),
  });

  final Duration delay;
  final String title;
  final List<DBProduct> products;
  final bool isLoading;
  final int maxItems;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showViewAll;
  final bool suppressSkeleton;
  final Duration maxSkeletonDuration;

  @override
  State<DeferredHomeFullRailSection> createState() =>
      _DeferredHomeFullRailSectionState();
}

class _DeferredHomeFullRailSectionState extends State<DeferredHomeFullRailSection> {
  Future<void>? _loadFuture;
  bool _scheduled = false;
  bool _renderStartedLogged = false;
  bool _skeletonTimedOut = false;
  Timer? _skeletonTimer;

  @override
  void initState() {
    super.initState();
    _skeletonTimer = Timer(widget.maxSkeletonDuration, () {
      if (!mounted || _skeletonTimedOut) return;
      setState(() => _skeletonTimedOut = true);
      HomeSkeletonDiagnostics.timeout(source: 'full_rail_${widget.title}');
      HomeSectionDiagnostics.state(section: widget.title, state: 'hidden');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }

  Future<void> _scheduleLoad() async {
    if (_scheduled) return;
    _scheduled = true;
    final effectiveDelay = widget.products.isNotEmpty && !widget.isLoading
        ? Duration.zero
        : widget.delay;
    if (effectiveDelay > Duration.zero) {
      await Future<void>.delayed(effectiveDelay);
    }
    if (!mounted) return;
    setState(() => _loadFuture = _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailLoadStarted);
    try {
      await full_rail_section.loadLibrary();
      WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailLoadCompleted);
    } catch (error) {
      WebPerfTrace.instance.mark(
        WebPerfTraceStage.fullRailLoadError,
        error: error.toString(),
      );
      rethrow;
    }
  }

  void _retry() {
    setState(() => _loadFuture = _loadLibrary());
  }

  void _logRenderStartedOnce() {
    if (_renderStartedLogged) return;
    _renderStartedLogged = true;
    WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailRenderStarted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailRenderCompleted);
    });
  }

  @override
  void didUpdateWidget(covariant DeferredHomeFullRailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.suppressSkeleton && widget.suppressSkeleton) {
      _skeletonTimer?.cancel();
      if (!_skeletonTimedOut && mounted) {
        setState(() => _skeletonTimedOut = true);
        HomeSkeletonDiagnostics.hide(
          source: 'full_rail_${widget.title}',
          reason: 'products_loaded',
        );
      }
    }
  }

  bool get _shouldShowSkeleton {
    if (widget.suppressSkeleton || _skeletonTimedOut) return false;
    if (widget.products.isNotEmpty && !widget.isLoading) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SkeletonLoading(
        width: double.infinity,
        height: 280,
        borderRadius: 12,
      ),
    );

    final future = _loadFuture;
    if (future == null) {
      if (!_shouldShowSkeleton) {
        return const SizedBox.shrink();
      }
      HomeSkeletonDiagnostics.show(
        source: 'full_rail',
        reason: 'library_pending',
      );
      return placeholder;
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (!_shouldShowSkeleton) {
            return const SizedBox.shrink();
          }
          HomeSkeletonDiagnostics.show(
            source: 'full_rail',
            reason: 'library_loading',
          );
          return placeholder;
        }
        if (snapshot.hasError) {
          HomeSectionDiagnostics.state(section: widget.title, state: 'error');
          return HomeSectionError(
            message: 'Ürün bölümü şu an yüklenemedi.',
            onRetry: _retry,
          );
        }
        HomeSkeletonDiagnostics.hide(
          source: 'full_rail',
          reason: 'library_loaded',
        );
        _logRenderStartedOnce();
        HomeSectionDiagnostics.state(
          section: widget.title,
          state: widget.products.isEmpty ? 'empty' : 'content',
          count: widget.products.length,
        );
        return full_rail_section.buildHomeFullProductRailSection(
          title: widget.title,
          products: widget.products,
          isLoading: widget.isLoading,
          maxItems: widget.maxItems,
          errorMessage: widget.errorMessage,
          onRetry: widget.onRetry,
          showViewAll: widget.showViewAll,
        );
      },
    );
  }
}
