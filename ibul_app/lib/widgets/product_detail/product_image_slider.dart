import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_features_page.dart';
import 'comparison_modal.dart';
import 'product_360_viewer.dart';

class ProductImageSlider extends StatefulWidget {
  final bool isMobile;
  const ProductImageSlider({super.key, this.isMobile = false});

  @override
  State<ProductImageSlider> createState() => _ProductImageSliderState();
}

class _ProductImageSliderState extends State<ProductImageSlider> {
  late PageController _pageController;
  bool _show360 = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final images = viewModel.images;

    // Sync controller if the ViewModel index changes externally
    if (_pageController.hasClients && 
        _pageController.page?.round() != viewModel.currentImageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            viewModel.currentImageIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Column(
      children: [
        // Main Image Area
        Container(
          decoration: widget.isMobile
              ? const BoxDecoration(color: Colors.white) // Mobile: Flat
              : BoxDecoration( // Web: Card style
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: widget.isMobile ? 1.3 : 1.0, // Reduced height for mobile (was 1.0)
                child: _show360 && viewModel.initialProduct.threeSixtyImages != null
                    ? Product360Viewer(
                        imageUrls: viewModel.initialProduct.threeSixtyImages!,
                        autoRotate: false,
                      )
                    : PageView.builder(
                        controller: _pageController,
                        onPageChanged: viewModel.updateImageIndex,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final imageUrl = images[index];
                          return Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16.0),
                            child: imageUrl.startsWith('http')
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildPlaceholder(),
                                  )
                                : Image.asset(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildPlaceholder(),
                                  ),
                          );
                        },
                      ),
              ),
              
              // Navigation Arrows (Web only or if multiple images)
              if (images.length > 1 && !widget.isMobile) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavArrow(
                      Icons.chevron_left, 
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavArrow(
                      Icons.chevron_right,
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Badges (Top Left) - Adjusted for mobile (lower to avoid back button)
              Positioned(
                top: widget.isMobile ? 60 : 12, 
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadge('HIZLI TESLİMAT', const Color(0xFF4CAF50)),
                    const SizedBox(height: 6),
                    _buildBadge('SİGORTAYA UYGUN', const Color(0xFF2196F3)),
                  ],
                ),
              ),

              // Action Icons (Top Right - Floating Vertical Stack)
              Positioned(
                top: widget.isMobile ? 12 + MediaQuery.of(context).padding.top : 12,
                right: 12,
                child: Column(
                  children: [
                    _buildFloatingActionButton(
                      Icons.share_outlined,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingActionButton(
                      Icons.bookmark_border,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingActionButton(
                      Icons.compare_arrows,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ComparisonModal(
                            currentProduct: viewModel.initialProduct,
                            similarProducts: viewModel.similarProducts,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingActionButton(
                      viewModel.isFavorite ? Icons.favorite : Icons.favorite_border,
                      iconColor: viewModel.isFavorite ? Colors.red : const Color(0xFF673AB7),
                      onPressed: viewModel.toggleFavorite,
                    ),
                  ],
                ),
              ),

              // Mobile Dots Indicator (Inside Stack)
              if (images.length > 1 && widget.isMobile)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      final isSelected = viewModel.currentImageIndex == index;
                      return Container(
                        width: isSelected ? 8 : 6,
                        height: isSelected ? 8 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

              // Bottom Pills (Product Video & All Specs)
              if (widget.isMobile) ...[
                Positioned(
                  bottom: 32, // Moved up slightly to clear dots if needed, or keeping corners
                  left: 16,
                  child: Row(
                    children: [
                      if (viewModel.initialProduct.threeSixtyImages != null &&
                          viewModel.initialProduct.threeSixtyImages!.isNotEmpty) ...[
                        _buildPillButton(
                          text: _show360 ? 'Normal' : '360°',
                          icon: _show360 ? Icons.close : Icons.threesixty,
                          onPressed: () {
                            setState(() {
                              _show360 = !_show360;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildPillButton(
                        text: 'Video',
                        icon: Icons.play_arrow,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 32,
                  right: 16,
                  child: _buildPillButton(
                    text: 'Tüm Özellikler',
                    icon: Icons.chevron_right,
                    isIconRight: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductFeaturesPage(
                            product: viewModel.initialProduct,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // Thumbnails (Hidden on mobile)
        if (images.length > 1 && !widget.isMobile) ...[
          const SizedBox(height: 12),
          // ... thumbnails code ...
          Padding(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = viewModel.currentImageIndex == index;
                  final imageUrl = images[index];
                  return GestureDetector(
                    onTap: () => viewModel.updateImageIndex(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        boxShadow: isSelected 
                            ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 4)] 
                            : null,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: imageUrl.startsWith('http')
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Image.asset(imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[50],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildNavArrow(IconData icon, {VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 10, 
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(IconData icon, {VoidCallback? onPressed, Color iconColor = const Color(0xFF673AB7)}) {
    return Container(
      width: 36, // Reduced from 40
      height: 36, // Reduced from 40
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: 18, color: iconColor), // Reduced from 20
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String text, 
    required IconData icon, 
    required VoidCallback onPressed,
    bool isIconRight = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16), // Slightly tighter radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isIconRight) ...[
              Icon(icon, size: 14, color: Colors.black87), // Reduced from 16
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (isIconRight) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: Colors.black87), // Reduced from 16
            ],
          ],
        ),
      ),
    );
  }
}