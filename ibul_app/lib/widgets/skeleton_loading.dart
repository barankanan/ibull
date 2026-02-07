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

class _SkeletonLoadingState extends State<SkeletonLoading> with SingleTickerProviderStateMixin {
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
    return AnimatedBuilder(
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
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Skeleton
          const SkeletonLoading(width: double.infinity, height: 160, borderRadius: 12),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  // Badge Skeleton
                  SkeletonLoading(width: 80, height: 20, borderRadius: 12),
                  SizedBox(height: 8),
                  // Title Skeleton
                  SkeletonLoading(width: 120, height: 14, borderRadius: 4),
                  SizedBox(height: 4),
                  SkeletonLoading(width: 100, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  // Rating Skeleton
                  SkeletonLoading(width: 80, height: 12, borderRadius: 4),
                  Spacer(),
                  // Price Skeleton
                  SkeletonLoading(width: 90, height: 18, borderRadius: 4),
                  SizedBox(height: 10),
                  // Button Skeleton
                  SkeletonLoading(width: double.infinity, height: 34, borderRadius: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
