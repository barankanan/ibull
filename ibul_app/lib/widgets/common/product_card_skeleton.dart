import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shimmer animasyonu sağlayan temel efekt widget'ı.
/// Açık ve koyu tema renklerine duyarlıdır.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF262632) : const Color(0xFFE8E8EE);
    final highlightColor =
        isDark ? const Color(0xFF333342) : const Color(0xFFF5F5F7);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final stop1 = (0.0 + _animation.value * 0.4).clamp(0.0, 1.0);
          final stop2 = (0.5 + _animation.value * 0.4).clamp(0.0, 1.0);
          final stop3 = (1.0 + _animation.value * 0.4).clamp(0.0, 1.0);

          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [baseColor, highlightColor, baseColor],
                stops: [
                  math.min(stop1, stop2),
                  stop2,
                  math.max(stop2, stop3),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ProductCard'ın dikey en-boy oranına (aspect ratio), 12px köşe yuvarlatmasına,
/// AspectRatio(1.0) görsel alanına ve tema renklerine %100 uyan Shimmer İskelet Kartı.
class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;

  const ProductCardSkeleton({
    super.key,
    this.width,
    this.height,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF262632) : const Color(0xFFEEEEEE);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1:1 Sabit AspectRatio Görsel Alanı (Zero CLS)
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Row(
                        children: [
                          ShimmerBox(
                            width: 22,
                            height: 22,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          const SizedBox(width: 4),
                          ShimmerBox(
                            width: 22,
                            height: 22,
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Rozet / Kategori Satırı
              ShimmerBox(
                width: 72,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 5),

              // Başlık Satırları (2 satır)
              ShimmerBox(
                width: double.infinity,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 3),
              ShimmerBox(
                width: 110,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),

              // Değerlendirme / Puan
              ShimmerBox(
                width: 64,
                height: 11,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 5),

              // Fiyat Satırı
              ShimmerBox(
                width: 88,
                height: 15,
                borderRadius: BorderRadius.circular(4),
              ),

              const Spacer(),

              // Alt Buton (CTA)
              ShimmerBox(
                width: double.infinity,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 8 adet ProductCardSkeleton içeren responsive GridView.
/// Web ve mobil ekran genişliğine göre birebir aynı ölçüleri kullanır.
class ProductCardSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  static const double webCardWidth = 220;
  static const double webCardHeight = 348;
  static const double webCardGap = 12;

  const ProductCardSkeletonGrid({
    super.key,
    this.itemCount = 8,
    this.padding = const EdgeInsets.all(16),
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 900;

        if (isWeb) {
          final available = math.max(
            webCardWidth,
            constraints.maxWidth - 32,
          );
          final columns = math.max(
            1,
            ((available + webCardGap) / (webCardWidth + webCardGap)).floor(),
          );
          final gridWidth =
              columns * webCardWidth + (columns - 1) * webCardGap;
          final rightInset = math.max(0.0, available - gridWidth);

          return GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16 + rightInset, 16),
            physics: physics,
            shrinkWrap: shrinkWrap,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: webCardHeight,
              crossAxisSpacing: webCardGap,
              mainAxisSpacing: webCardGap,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) => const ProductCardSkeleton(),
          );
        }

        return GridView.builder(
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => const ProductCardSkeleton(),
        );
      },
    );
  }
}
