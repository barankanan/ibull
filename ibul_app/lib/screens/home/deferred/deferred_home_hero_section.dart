import 'package:flutter/material.dart';

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
  });

  final Duration delay;
  final List<String> bannerImageUrls;
  final bool isLoading;
  final bool preferMobile;
  final bool embedded;

  @override
  State<DeferredHomeHeroSection> createState() => _DeferredHomeHeroSectionState();
}

class _DeferredHomeHeroSectionState extends State<DeferredHomeHeroSection> {
  Future<void>? _loadFuture;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
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
    await hero_section.loadLibrary();
    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredHeroLoaded);
  }

  void _retry() {
    setState(() => _loadFuture = _loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.embedded
        ? const SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 16,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SkeletonLoading(
              width: double.infinity,
              height: 160,
              borderRadius: 12,
            ),
          );

    final future = _loadFuture;
    if (future == null) return placeholder;

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder;
        }
        if (snapshot.hasError) {
          return HomeSectionError(
            message: 'Banner bölümü şu an yüklenemedi.',
            onRetry: _retry,
          );
        }
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
