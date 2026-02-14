import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_detail_page.dart';

class ProductInfoSectionMobile extends StatelessWidget {
  const ProductInfoSectionMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Name
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        
        // Brand Name
        GestureDetector(
          onTap: () {},
          child: Text(
            product.brand,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Ratings
        Row(
          children: [
            _buildRatingStars(product.rating),
            const SizedBox(width: 6),
            Text(
              '${product.rating}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              '(${product.reviewCount})',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Price (Mobile specific, although user asked to remove it from here if duplicated, 
        // but typically mobile info section might include it if not fixed at bottom. 
        // Following previous instruction: removed from here as it is in bottom bar)
        // _buildPrice(product), 
      ],
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        }
        return Icon(Icons.star_border, color: Colors.grey[300], size: 16);
      }),
    );
  }
}
