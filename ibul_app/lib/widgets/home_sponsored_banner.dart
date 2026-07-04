import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'optimized_image.dart';
import 'skeleton_loading.dart';

/// Ana sayfa sponsorlu banner alanı için sabit boyut hesapları.
class HomeSponsoredBannerDimensions {
  HomeSponsoredBannerDimensions._();

  static const double bannerAspectRatio = 6;
  static const double desktopBannerMaxWidth = 1320;
  static const double desktopBannerMaxHeight = 220;
  static const double desktopBannerMinHeight = 160;
  static const double mobileMaxHeight = 120;
  static const double mobileHeroBannerHeight = 130;
  static const double borderRadius = 12;

  static ({double width, double height}) resolve({
    required double availableWidth,
    required double screenWidth,
  }) {
    if (screenWidth < 600) {
      var width = availableWidth;
      var height = width / bannerAspectRatio;
      if (height > mobileMaxHeight) {
        height = mobileMaxHeight;
        width = height * bannerAspectRatio;
      }
      return (width: width, height: height);
    }

    final isDesktop = screenWidth >= 1100;
    var width = isDesktop
        ? math.min(availableWidth, desktopBannerMaxWidth)
        : availableWidth;
    final maxHeight = isDesktop ? desktopBannerMaxHeight : 180.0;
    var height = width / bannerAspectRatio;

    if (height > maxHeight) {
      height = maxHeight;
      width = height * bannerAspectRatio;
    } else if (isDesktop && height < desktopBannerMinHeight) {
      height = desktopBannerMinHeight;
      width = height * bannerAspectRatio;
      if (width > availableWidth) {
        width = availableWidth;
        height = width / bannerAspectRatio;
      }
      width = math.min(width, desktopBannerMaxWidth);
      height = width / bannerAspectRatio;
    }

    return (width: width, height: height);
  }

  static BoxFit fitForScreen(double screenWidth) =>
      screenWidth >= 600 ? BoxFit.contain : BoxFit.cover;
}

/// Sabit yükseklikte sponsorlu banner slotu.
/// İlk frame'den itibaren alan ayrılır; içerik geç gelse bile layout kaymaz.
class HomeSponsoredBanner extends StatelessWidget {
  const HomeSponsoredBanner({
    required this.width,
    required this.height,
    this.imageUrl,
    this.isLoading = false,
    this.fit = BoxFit.cover,
    this.onTap,
    this.borderRadius = HomeSponsoredBannerDimensions.borderRadius,
    super.key,
  });

  final double width;
  final double height;
  final String? imageUrl;
  final bool isLoading;
  final BoxFit fit;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasImage = !isLoading && (imageUrl?.trim().isNotEmpty ?? false);

    Widget content;
    if (isLoading) {
      content = SkeletonLoading(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    } else if (hasImage) {
      content = OptimizedImage(
        imageUrlOrPath: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.center,
        cacheWidth: 1200,
        cacheHeight: 200,
        placeholder: SkeletonLoading(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
        errorWidget: _BannerFallbackSurface(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
      );
    } else {
      content = _BannerFallbackSurface(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: content,
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: _SponsoredBadge(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Sponsorlu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _BannerFallbackSurface extends StatelessWidget {
  const _BannerFallbackSurface({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Colors.grey.shade100,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 28,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
