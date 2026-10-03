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
    this.height,
  });

  final List<String> bannerImageUrls;
  final bool isLoading;
  final bool preferMobile;
  final bool embedded;
  final double? height;

  List<String> get _effectiveUrls => bannerImageUrls;

  @override
  Widget build(BuildContext context) {
    final bannerHeight = height ?? (embedded ? 264.0 : (preferMobile ? 160.0 : 180.0));
    if (isLoading && bannerImageUrls.isEmpty) {
      return _buildSkeleton(bannerHeight);
    }

    final urls = _effectiveUrls;

    if (urls.isEmpty) {
      return HomeHeroSlotPlaceholder(
        height: bannerHeight,
        preferMobile: preferMobile,
        embedded: embedded,
      );
    }

    WebPerfTrace.instance.mark(WebPerfTraceStage.deferredHeroLoaded);

    final carousel = CarouselSlider(
      options: CarouselOptions(
        height: bannerHeight,
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
        child: SizedBox(height: bannerHeight, child: carousel),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: bannerHeight, child: carousel),
      ),
    );
  }

  Widget _buildSkeleton(double height) {
    return embedded
        ? SkeletonLoading(
            width: double.infinity,
            height: height,
            borderRadius: 16,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SkeletonLoading(
              width: double.infinity,
              height: height,
              borderRadius: 12,
            ),
          );
  }
}

/// Painted campaign chrome when `campaign_images` is empty — not a product fake.
class HomeHeroSlotPlaceholder extends StatelessWidget {
  const HomeHeroSlotPlaceholder({
    super.key,
    required this.height,
    required this.preferMobile,
    required this.embedded,
  });

  final double height;
  final bool preferMobile;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(embedded ? 16 : 12),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: preferMobile
                  ? const [Color(0xFF5B21B6), Color(0xFF7C3AED)]
                  : const [Color(0xFF4C1D95), Color(0xFF6D28D9)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(preferMobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  preferMobile
                      ? 'Yakınındaki Mağazaları Anında Keşfet'
                      : '1 SAATTE KAPINDA!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: preferMobile ? 18 : 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: preferMobile ? 6 : 12),
                Text(
                  preferMobile
                      ? 'Yakındaki mağaza ve restoranları tek ekranda gör.'
                      : 'Yakınınızdaki mağazadan hızlı, güvenli teslimat',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: preferMobile ? 12 : 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (embedded) return panel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: panel,
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
      fit: BoxFit.contain,
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
  double? height,
}) {
  return HomeHeroBannerSection(
    bannerImageUrls: bannerImageUrls,
    isLoading: isLoading,
    preferMobile: preferMobile,
    embedded: embedded,
    height: height,
  );
}
