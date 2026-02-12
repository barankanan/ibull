import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/all_reviews_page.dart';

class ProductReviewsSection extends StatelessWidget {
  const ProductReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Değerlendirmeler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),

        // Summary row
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Rating bars
              Expanded(
                child: Column(
                  children: [
                    _buildRatingBar('5', 0.7, '310'),
                    _buildRatingBar('4', 0.4, '110'),
                    _buildRatingBar('3', 0.25, '80'),
                    _buildRatingBar('2', 0.1, '20'),
                    _buildRatingBar('1', 0.15, '60'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Overall
              Column(
                children: [
                  const Text('5.0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Row(children: List.generate(5, (_) => const Icon(Icons.star, color: Colors.amber, size: 14))),
                  const SizedBox(height: 2),
                  Text('580 Kişi', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Review card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Baran K***', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 6),
                      ...List.generate(5, (_) => const Icon(Icons.star, color: Colors.amber, size: 12)),
                    ],
                  ),
                  Text('30/08/2023', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Muhteşem paketleme çok ilgili davranıldı, Ürün 8 saat sonra elime ulaştı. İçerisinde hediyelerle birlikte geldi. Herkese tavsiye ettiğim bir ürün.',
                style: TextStyle(fontSize: 11, height: 1.3, color: Colors.black87),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // See all button
        SizedBox(
          width: double.infinity,
          height: 32,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AllReviewsPage(
                    productName: product.name,
                    brand: product.brand ?? '',
                    rating: product.rating,
                    reviewCount: product.reviewCount,
                    images: product.images,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: EdgeInsets.zero,
            ),
            child: const Text('Tüm Değerlendirmeleri Gör', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double pct, String count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 12, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))),
          const SizedBox(width: 4),
          Expanded(
            child: Stack(
              children: [
                Container(height: 6, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 6, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(3))),
                ),
              ],
            ),
          ),
          SizedBox(width: 30, child: Text(count, textAlign: TextAlign.end, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
