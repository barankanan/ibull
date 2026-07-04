import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/app_image_cdn.dart';
import '../../../core/web_perf_trace.dart';
import '../../../widgets/optimized_image.dart';
import '../../../widgets/skeleton_loading.dart';

/// Hero / campaign carousel — Supabase URLs only (no asset fallback).
class HomeHeroBannerSection extends StatelessWidget {
  const HomeHeroBannerSection({
    super.key,
    required this.bannerImageUrls,
    this.isLoading = false,
    this.preferMobile = false,
    this.embedded = false,
  });

  final List<String> bannerImageUrls;
  final bool isLoading;
  final bool preferMobile;
  final bool embedded;

  List<String> get _effectiveUrls => bannerImageUrls;

  @override
  Widget build(BuildContext context) {
    if (isLoading && bannerImageUrls.isEmpty) {
      return _buildSkeleton();
    }

    final urls = _effectiveUrls;
    if (urls.isEmpty) return const SizedBox.shrink();

    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredHeroLoaded);

    final height = embedded
        ? 412.0
        : (preferMobile ? 160.0 : 180.0);

    final carousel = CarouselSlider(
      options: CarouselOptions(
        height: height,
        viewportFraction: 1,
        autoPlay: urls.length > 1,
        autoPlayInterval: const Duration(seconds: 6),
        enlargeCenterPage: false,
      ),
      items: urls.map((source) {
        return _BannerSlide(source: source);
      }).toList(),
    );

    if (embedded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(height: height, child: carousel),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: height, child: carousel),
      ),
    );
  }

  Widget _buildSkeleton() {
    return embedded
        ? const SkeletonLoading(
            width: double.infinity,
            height: 412,
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
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('assets/')) {
      return const SizedBox.shrink();
    }
    return OptimizedImage(
      imageUrlOrPath: AppImageCdn.buildUrl(source, AppImageVariant.hero),
      fit: BoxFit.cover,
      width: double.infinity,
      priority: OptimizedImagePriority.high,
    );
  }
}

Widget buildHomeHeroBannerSection({
  required List<String> bannerImageUrls,
  bool isLoading = false,
  bool preferMobile = false,
  bool embedded = false,
}) {
  return HomeHeroBannerSection(
    bannerImageUrls: bannerImageUrls,
    isLoading: isLoading,
    preferMobile: preferMobile,
    embedded: embedded,
  );
}
