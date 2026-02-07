import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../product_card.dart';

class SimilarProductsSection extends StatelessWidget {
  const SimilarProductsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductDetailViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.loadingSimilarProducts) {
          return const Center(child: CircularProgressIndicator());
        }

        final similarProducts = viewModel.similarProducts;

        if (similarProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Benzer Ürünler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360, // Height for ProductCard (increased to prevent overflow)
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: similarProducts[index],
                    width: 160,
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
