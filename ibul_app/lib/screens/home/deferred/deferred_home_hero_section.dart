import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/home_data_diagnostics.dart';
import '../../../core/web_perf_trace.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_hero_banner.dart' deferred as hero_section;

/// Lazy hero banner — loads [hero_section] before touching any deferred symbol.
class DeferredHomeHeroSection extends StatefulWidget {
  const DeferredHomeHeroSection({
    super.key,
    this.delay = Duration.zero,
    required this.bannerImageUrls,
    this.isLoading = false,
    this.preferMobile = false,
    this.embedded = false,
    this.suppressSkeleton = false,
    this.maxSkeletonDuration = const Duration(seconds: 4),
  });

  final Duration delay;
  final List<String> bannerImageUrls;
  final bool isLoading;
  final bool preferMobile;
  final bool embedded;
  final bool suppressSkeleton;
  final Duration maxSkeletonDuration;

  @override
  State<DeferredHomeHeroSection> createState() => _DeferredHomeHeroSectionState();
}

class _DeferredHomeHeroSectionState extends State<DeferredHomeHeroSection> {
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
      HomeSkeletonDiagnostics.timeout(source: 'hero');
      HomeSectionDiagnostics.state(section: 'hero', state: 'hidden');
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
    final effectiveDelay = widget.bannerImageUrls.isNotEmpty
        ? Duration.zero
        : widget.delay;
    if (effectiveDelay > Duration.zero) {
      await Future<void>.delayed(effectiveDelay);
    }
    if (!mounted) return;
    setState(() => _loadFuture = _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    await hero_section.loadLibrary();
    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredHeroLoaded);
  }

  void _retry() {
    setState(() => _loadFuture = _loadLibrary());
  }

  bool get _shouldHideEntireSection => false;

  bool get _shouldShowSkeleton {
    if (widget.suppressSkeleton || _skeletonTimedOut) return false;
    if (_shouldHideEntireSection) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldHideEntireSection) {
      HomeAdsDiagnostics.heroHidden(reason: 'empty');
      return const SizedBox.shrink();
    }

    final placeholder = widget.embedded
        ? const SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 16,
          )
        : const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SkeletonLoading(
              width: double.infinity,
              height: 160,
              borderRadius: 12,
            ),
          );

    final future = _loadFuture;
    if (future == null) {
      if (!_shouldShowSkeleton) {
        return const SizedBox.shrink();
      }
      HomeSkeletonDiagnostics.show(source: 'hero', reason: 'library_pending');
      return placeholder;
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (!_shouldShowSkeleton) {
            return const SizedBox.shrink();
          }
          HomeSkeletonDiagnostics.show(source: 'hero', reason: 'library_loading');
          return placeholder;
        }
        if (snapshot.hasError) {
          HomeSectionDiagnostics.state(section: 'hero', state: 'error');
          return HomeSectionError(
            message: 'Banner bölümü şu an yüklenemedi.',
            onRetry: _retry,
          );
        }
        HomeSkeletonDiagnostics.hide(source: 'hero', reason: 'library_loaded');
        HomeSectionDiagnostics.state(
          section: 'hero',
          state: widget.bannerImageUrls.isEmpty ? 'empty' : 'content',
          count: widget.bannerImageUrls.length,
        );
        return hero_section.buildHomeHeroBannerSection(
          bannerImageUrls: widget.bannerImageUrls,
          isLoading: widget.isLoading,
          preferMobile: widget.preferMobile,
          embedded: widget.embedded,
        );
      },
    );
  }
}
