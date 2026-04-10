import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:ibul_app/widgets/skeleton_loading.dart';

class AdCarousel extends StatelessWidget {
  final List<String>? imageUrls;

  const AdCarousel({super.key, this.imageUrls});

  @override
  Widget build(BuildContext context) {
    final List<String> images = imageUrls ?? ['', ''];

    return Column(
      children: [
        RepaintBoundary(
          child: CarouselSlider(
            items: images.map((url) => _buildAdCard(url)).toList(),
            options: CarouselOptions(
              height: 110,
              autoPlay: false,
              enlargeCenterPage: false,
              viewportFraction: 0.95,
              enableInfiniteScroll: images.length > 1,
              pauseAutoPlayOnTouch: true,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'İBUL Görsel Zeka Teknolojisi',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdCard(String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            OptimizedImage(
              imageUrlOrPath: imageUrl,
              fit: BoxFit.cover,
              placeholder: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                ),
              ),
              errorWidget: Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error_outline, color: Colors.grey),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Reklam',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
