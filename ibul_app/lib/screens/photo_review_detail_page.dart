import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../core/constants.dart';

class PhotoReviewDetailPage extends StatefulWidget {
  final List<Map<String, dynamic>> galleryItems;
  final int initialIndex;

  const PhotoReviewDetailPage({
    super.key,
    required this.galleryItems,
    this.initialIndex = 0,
  });

  @override
  State<PhotoReviewDetailPage> createState() => _PhotoReviewDetailPageState();
}

class _PhotoReviewDetailPageState extends State<PhotoReviewDetailPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.galleryItems.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxContentWidth = screenSize.width > 900 ? 720.0 : screenSize.width;

    return Scaffold(
      backgroundColor: const Color(0xFF111018),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1}/${widget.galleryItems.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.galleryItems.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final galleryItem = widget.galleryItems[index];
                  return _GalleryImagePane(
                    item: galleryItem,
                    maxWidth: maxContentWidth,
                    maxHeight: screenSize.height * 0.62,
                  );
                },
              ),
            ),
            if (widget.galleryItems.isNotEmpty)
              _ReviewInfoCard(
                item: widget.galleryItems[_currentIndex],
                maxWidth: maxContentWidth,
              ),
            if (widget.galleryItems.length > 1)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.galleryItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final previewItem = widget.galleryItems[index];
                    final isSelected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Container(
                        width: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _ReviewImage(
                            imageUrl: previewItem['imageUrl']?.toString() ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryImagePane extends StatelessWidget {
  final Map<String, dynamic> item;
  final double maxWidth;
  final double maxHeight;

  const _GalleryImagePane({
    required this.item,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 3,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: _ReviewImage(
              imageUrl: item['imageUrl']?.toString() ?? '',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewInfoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double maxWidth;

  const _ReviewInfoCard({required this.item, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final rating = (item['rating'] as num?)?.toDouble() ?? 0;
    final userName = item['userName']?.toString() ?? 'Kullanıcı';
    final comment = item['comment']?.toString().trim() ?? '';
    final date = item['date']?.toString() ?? '';
    final productName = item['productName']?.toString() ?? '';

    if (comment.isEmpty && userName == 'Kullanıcı' && date.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E2F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (productName.isNotEmpty)
                  Text(
                    productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (productName.isNotEmpty) const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (date.isNotEmpty)
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (rating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: const Color(0xFFF4C542),
                          );
                        }),
                      ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const _ReviewImage({required this.imageUrl, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      return Image.memory(
        UriData.parse(imageUrl).contentAsBytes(),
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (imageUrl.startsWith('http')) {
      return OptimizedImage(
        imageUrlOrPath: imageUrl,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (imageUrl.isEmpty) {
      return _fallback();
    }
    return Image.asset(
      imageUrl,
      fit: fit,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF1E1A28),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade500, size: 36),
    );
  }
}
