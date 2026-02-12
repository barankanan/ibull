import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_features_page.dart';
import '../../screens/compare_page.dart';
import '../../models/product_model.dart';

class ProductImageSlider extends StatelessWidget {
  const ProductImageSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final images = viewModel.images;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Main image with nav arrows + action icons
          Stack(
            children: [
              SizedBox(
                height: 280,
                child: PageView.builder(
                  onPageChanged: viewModel.updateImageIndex,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = images[index];
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
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
              // Left arrow
              if (images.length > 1)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavArrow(Icons.chevron_left),
                  ),
                ),
              // Right arrow
              if (images.length > 1)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavArrow(Icons.chevron_right),
                  ),
                ),
              // Action icons (top-left badges)
              Positioned(
                top: 8,
                left: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadge('HIZLI TESLİMAT', const Color(0xFF4CAF50)),
                    const SizedBox(height: 4),
                    _buildBadge('SİGORTAYA UYGUN', const Color(0xFF2196F3)),
                  ],
                ),
              ),
              // Right side action icons
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    _buildSmallIconButton(
                      Icons.share_outlined,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 6),
                    _buildSmallIconButton(
                      viewModel.isFavorite ? Icons.favorite : Icons.favorite_border,
                      iconColor: viewModel.isFavorite ? Colors.red : Colors.grey,
                      onPressed: viewModel.toggleFavorite,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Thumbnail row
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = viewModel.currentImageIndex == index;
                final imageUrl = images[index];
                return GestureDetector(
                  onTap: () => viewModel.updateImageIndex(index),
                  child: Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: imageUrl.startsWith('http')
                          ? Image.network(imageUrl, fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(Icons.image, size: 20, color: Colors.grey))
                          : Image.asset(imageUrl, fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(Icons.image, size: 20, color: Colors.grey)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildNavArrow(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(icon, size: 18, color: Colors.grey[600]),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSmallIconButton(IconData icon, {VoidCallback? onPressed, Color iconColor = Colors.grey}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}
