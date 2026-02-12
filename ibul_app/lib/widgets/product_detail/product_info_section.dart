import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_detail_page.dart';

class ProductInfoSection extends StatelessWidget {
  const ProductInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category badge
        if (product.subCategory != null)
          Row(
            children: [
              Text(
                '${product.subCategory} kategorisinde',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'En Çok Satan #1',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
            ],
          ),
        const SizedBox(height: 6),
        
        // Product name
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${product.brand} ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: product.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Rating row
        Row(
          children: [
            Text(
              product.rating.toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < product.rating.round() ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                );
              }),
            ),
            const SizedBox(width: 6),
            Text(
              '${product.reviewCount} Değerlendirme',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            const Text('·', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 4),
            Text(
              '${(product.reviewCount * 0.5).round()} Soru-Cevap',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // "Kullanıcılar Beğeniyor" row
        Row(
          children: [
            const Icon(Icons.star_rate, size: 14, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              'Kullanıcılar Beğeniyor!',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green[700]),
            ),
            const SizedBox(width: 4),
            Text(
              'Yorumları İncele',
              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
            Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
          ],
        ),
        const SizedBox(height: 6),

        // Urgency row
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 14, color: Colors.orange[700]),
            const SizedBox(width: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11),
                children: [
                  TextSpan(
                    text: '13B kişinin ',
                    style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: 'sepetinde, tükenmeden al!',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        // Divider
        Divider(color: Colors.grey[200], height: 1),
        const SizedBox(height: 10),

        // Quick variant selector ("Seç" area)
        _buildQuickVariantSelector(viewModel),

        // Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              viewModel.totalPrice,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            if (product.oldPrice != null && product.oldPrice!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                product.oldPrice!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQuickVariantSelector(ProductDetailViewModel viewModel) {
    final hasVariants = viewModel.allAvailableOptions.isNotEmpty;

    if (!hasVariants) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune, size: 14, color: Colors.black54),
            const SizedBox(width: 4),
            Text(
              'Seç',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...viewModel.allAvailableOptions.entries.map((entry) {
          final optionKey = entry.key;
          final options = entry.value.toList();
          final isColor = optionKey.toLowerCase().contains('renk') || optionKey.toLowerCase().contains('color');

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$optionKey: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      viewModel.selectedVariants[optionKey] ?? options.first,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: isColor ? 38 : 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final optionValue = options[index];
                      final isSelected = viewModel.selectedVariants[optionKey] == optionValue;
                      final tempSelection = Map<String, String>.from(viewModel.selectedVariants);
                      tempSelection[optionKey] = optionValue;
                      final isAvailable = viewModel.hasInStockVariantForSelection(tempSelection);

                      return GestureDetector(
                        onTap: isAvailable
                            ? () {
                                viewModel.updateSelectedVariant(optionKey, optionValue);
                                final target = viewModel.getMatchingVariant();
                                if (target != null && target.name != viewModel.initialProduct.name) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => ProductDetailPage(product: target)),
                                  );
                                }
                              }
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isColor ? 8 : 12, vertical: isColor ? 4 : 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(isColor ? 8 : 16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : (isAvailable ? Colors.grey.shade300 : Colors.grey.shade200),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: isColor
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: _getColorFromName(optionValue),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        optionValue,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isAvailable ? (isSelected ? AppColors.primary : Colors.black87) : Colors.grey[400],
                                          decoration: !isAvailable ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    optionValue,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isAvailable ? (isSelected ? AppColors.primary : Colors.black87) : Colors.grey[400],
                                      decoration: !isAvailable ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Divider(color: Colors.grey[200], height: 1),
        const SizedBox(height: 10),
      ],
    );
  }

  Color _getColorFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('siyah') || lower.contains('black')) return Colors.black;
    if (lower.contains('beyaz') || lower.contains('white')) return Colors.white;
    if (lower.contains('kırmızı') || lower.contains('red')) return Colors.red;
    if (lower.contains('mavi') || lower.contains('blue')) return Colors.blue;
    if (lower.contains('yeşil') || lower.contains('green')) return Colors.green;
    if (lower.contains('sarı') || lower.contains('yellow')) return Colors.yellow;
    if (lower.contains('turuncu') || lower.contains('orange')) return Colors.orange;
    if (lower.contains('mor') || lower.contains('purple')) return Colors.purple;
    if (lower.contains('pembe') || lower.contains('pink')) return Colors.pink;
    if (lower.contains('gri') || lower.contains('gray') || lower.contains('grey')) return Colors.grey;
    if (lower.contains('kahve') || lower.contains('brown')) return Colors.brown;
    if (lower.contains('titan') || lower.contains('titanium')) return const Color(0xFF8E8E93);
    if (lower.contains('gümüş') || lower.contains('silver')) return const Color(0xFFC0C0C0);
    if (lower.contains('altın') || lower.contains('gold')) return const Color(0xFFFFD700);
    return Colors.grey.shade300;
  }
}
