import 'dart:math' as math;

import 'package:flutter/material.dart';

class SkeletonLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: shimmer AnimationController sürekli repeat() eder ve her
    // frame repaint tetikler. İzolasyon olmadan yükleme ekranında tüm ata layer
    // (SliverToBoxAdapter home içeriği) her frame yeniden rasterlanır.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: const [
                  Color(0xFFEBEBF4),
                  Color(0xFFF4F4F4),
                  Color(0xFFEBEBF4),
                ],
                stops: [
                  0.1,
                  0.3 + (_animation.value * 0.3), // Dynamic shimmer movement
                  0.9,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.tight = false, this.margin});

  final bool tight;
  final EdgeInsetsGeometry? margin;

  static const double _layoutSlack = 4.0;

  double _horizontalPadding(bool tight) => tight ? 4.0 : 10.0;

  double _fixedBodyHeight(bool tight) {
    if (tight) {
      return 3 + 24 + 3 + 14 + 2 + 12 + 3 + 36 + 4 + 30;
    }
    return 5 + 24 + 5 + 14 + 2 + 12 + 5 + 11 + 2 + 18 + 6 + 34;
  }

  double _resolveImageHeight(BoxConstraints constraints, bool tight) {
    final fallbackWidth = tight ? 198.0 : 198.0;
    final availableWidth =
        constraints.maxWidth.isFinite && constraints.maxWidth > 0
        ? constraints.maxWidth
        : fallbackWidth;
    final horizontalPadding = _horizontalPadding(tight);
    final contentWidth = math.max(
      0.0,
      availableWidth - (horizontalPadding * 2),
    );
    final imageRatio = tight ? 0.70 : 0.72;
    final minHeight = tight ? 72.0 : 100.0;
    final maxHeight = 168.0;

    final naturalImageHeight = (contentWidth * imageRatio)
        .clamp(minHeight, maxHeight)
        .toDouble();

    if (!constraints.maxHeight.isFinite) {
      return naturalImageHeight;
    }

    final verticalPadding = horizontalPadding * 2;
    final innerMaxHeight = constraints.maxHeight - verticalPadding;
    final maxImageForCell =
        innerMaxHeight - _fixedBodyHeight(tight) - _layoutSlack;

    if (maxImageForCell >= minHeight) {
      return math.min(naturalImageHeight, maxImageForCell);
    }

    return math.max(56.0, maxImageForCell);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillCellHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final padding = _horizontalPadding(tight);
        final borderRadius = tight ? 18.0 : 16.0;
        final imageHeight = fillCellHeight
            ? null
            : _resolveImageHeight(constraints, tight);

        return Container(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : 198,
          height: fillCellHeight ? constraints.maxHeight : null,
          margin:
              margin ??
              (tight ? EdgeInsets.zero : const EdgeInsets.only(right: 12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0xFFEEEEEE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: fillCellHeight
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                if (fillCellHeight)
                  Expanded(
                    child: _buildImageSkeleton(
                      tight: tight,
                      fillAvailable: true,
                    ),
                  )
                else
                  _buildImageSkeleton(tight: tight, imageHeight: imageHeight!),
                SizedBox(height: tight ? 3 : 5),
                const SkeletonLoading(
                  width: double.infinity,
                  height: 24,
                  borderRadius: 999,
                ),
                SizedBox(height: tight ? 3 : 5),
                SkeletonLoading(
                  width: double.infinity,
                  height: tight ? 14 : 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 2),
                SkeletonLoading(
                  width: tight ? 96 : 88,
                  height: 12,
                  borderRadius: 4,
                ),
                SizedBox(height: tight ? 3 : 5),
                if (!tight) ...[
                  const SkeletonLoading(width: 96, height: 11, borderRadius: 4),
                  const SizedBox(height: 2),
                  const SkeletonLoading(
                    width: 118,
                    height: 18,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 6),
                ] else ...[
                  const SkeletonLoading(
                    width: double.infinity,
                    height: 36,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 4),
                ],
                SkeletonLoading(
                  width: double.infinity,
                  height: tight ? 30 : 34,
                  borderRadius: 12,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSkeleton({
    required bool tight,
    double? imageHeight,
    bool fillAvailable = false,
  }) {
    return Stack(
      children: [
        SkeletonLoading(
          width: double.infinity,
          height: fillAvailable ? double.infinity : imageHeight!,
          borderRadius: 14,
        ),
        Positioned(
          top: tight ? 6 : 8,
          right: 6,
          child: Row(
            children: [
              SkeletonLoading(
                width: tight ? 18 : 22,
                height: tight ? 18 : 22,
                borderRadius: 11,
              ),
              const SizedBox(width: 4),
              SkeletonLoading(
                width: tight ? 18 : 22,
                height: tight ? 18 : 22,
                borderRadius: 11,
              ),
              const SizedBox(width: 4),
              SkeletonLoading(
                width: tight ? 18 : 22,
                height: tight ? 18 : 22,
                borderRadius: 11,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal product-card placeholders matching the live home rails.
class HomeProductRailSkeleton extends StatelessWidget {
  const HomeProductRailSkeleton({
    super.key,
    this.itemCount = 5,
    this.showTitle = true,
  });

  final int itemCount;
  final bool showTitle;

  static const double cardWidth = 220;
  static const double cardHeight = 348;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoading(width: 160, height: 22, borderRadius: 8),
                SkeletonLoading(width: 72, height: 16, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: ProductCardSkeleton(margin: EdgeInsets.zero),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// First-paint home skeleton: shortcuts, hero row, then product cards.
class HomeStorefrontSkeleton extends StatelessWidget {
  const HomeStorefrontSkeleton({super.key, this.showHero = true});

  final bool showHero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => const Column(
              children: [
                SkeletonLoading(width: 56, height: 56, borderRadius: 16),
                SizedBox(height: 8),
                SkeletonLoading(width: 56, height: 10, borderRadius: 4),
              ],
            ),
          ),
        ),
        if (showHero) ...[
          const SizedBox(height: 12),
          const SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 16,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: SkeletonLoading(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: SkeletonLoading(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const HomeProductRailSkeleton(),
      ],
    );
  }
}
