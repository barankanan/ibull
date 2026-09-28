import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/home_data_diagnostics.dart';
import '../../../core/web_perf_trace.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_sponsored.dart' deferred as sponsored_section;

/// Lazy sponsored rails — loads [sponsored_section] before building widgets.
class DeferredHomeSponsoredSection extends StatefulWidget {
  const DeferredHomeSponsoredSection({
    super.key,
    this.delay = Duration.zero,
    this.suppressSkeleton = false,
    this.maxSkeletonDuration = const Duration(seconds: 4),
  });

  final Duration delay;
  final bool suppressSkeleton;
  final Duration maxSkeletonDuration;

  @override
  State<DeferredHomeSponsoredSection> createState() =>
      _DeferredHomeSponsoredSectionState();
}

class _DeferredHomeSponsoredSectionState extends State<DeferredHomeSponsoredSection> {
  Future<void>? _loadFuture;
  bool _scheduled = false;
  bool _skeletonTimedOut = false;
  Timer? _skeletonTimer;

  @override
  void initState() {
    super.initState();
    _skeletonTimer = Timer(widget.maxSkeletonDuration, () {
      if (!mounted || _skeletonTimedOut) return;
      setState(() => _skeletonTimedOut = true);
      HomeSkeletonDiagnostics.timeout(source: 'sponsored');
      HomeSectionDiagnostics.state(section: 'sponsored', state: 'hidden');
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
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted) return;
    setState(() => _loadFuture = _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    await sponsored_section.loadLibrary();
    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredCampaignLoaded);
  }

  void _retry() {
    setState(() => _loadFuture = _loadLibrary());
  }

  @override
  void didUpdateWidget(covariant DeferredHomeSponsoredSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.suppressSkeleton && widget.suppressSkeleton) {
      _skeletonTimer?.cancel();
      if (!_skeletonTimedOut && mounted) {
        setState(() => _skeletonTimedOut = true);
        HomeSkeletonDiagnostics.hide(
          source: 'sponsored',
          reason: 'products_loaded',
        );
      }
    }
  }

  bool get _shouldShowSkeleton {
    if (widget.suppressSkeleton || _skeletonTimedOut) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SkeletonLoading(
        width: double.infinity,
        height: 120,
        borderRadius: 12,
      ),
    );

    final future = _loadFuture;
    if (future == null) {
      if (!_shouldShowSkeleton) {
        return const SizedBox.shrink();
      }
      HomeSkeletonDiagnostics.show(source: 'sponsored', reason: 'library_pending');
      return placeholder;
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (!_shouldShowSkeleton) {
            return HomeSectionError(
              message: 'Sponsorlu bölüm yüklenirken zaman aşımına uğradı.',
              onRetry: _retry,
            );
          }
          HomeSkeletonDiagnostics.show(
            source: 'sponsored',
            reason: 'library_loading',
          );
          return placeholder;
        }
        if (snapshot.hasError) {
          HomeSectionDiagnostics.state(section: 'sponsored', state: 'error');
          return HomeSectionError(
            message: 'Sponsorlu bölüm şu an yüklenemedi.',
            onRetry: _retry,
          );
        }
        HomeSkeletonDiagnostics.hide(
          source: 'sponsored',
          reason: 'library_loaded',
        );
        return sponsored_section.buildHomeSponsoredSection(
          suppressSkeleton: widget.suppressSkeleton,
        );
      },
    );
  }
}
