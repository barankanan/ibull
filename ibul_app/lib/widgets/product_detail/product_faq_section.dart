import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductFaqSection extends StatefulWidget {
  const ProductFaqSection({super.key});

  @override
  State<ProductFaqSection> createState() => _ProductFaqSectionState();
}

class _ProductFaqSectionState extends State<ProductFaqSection> {
  final Set<int> _expandedIndexes = {};

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final productName = product.name;
    final brand = product.brand;
    final fullName = '$brand $productName';

    final rawFaqs = product.faq ?? const <Map<String, String>>[];
    final faqs = rawFaqs
        .map((m) => {
              'question': (m['question'] ?? '').trim(),
              'answer': (m['answer'] ?? '').trim(),
            })
        .where((m) => m['question']!.isNotEmpty && m['answer']!.isNotEmpty)
        .take(5)
        .toList();

    if (faqs.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            '$fullName ile İlgili Sıkça Sorulan Sorular',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // FAQ items
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            final isExpanded = _expandedIndexes.contains(index);
            final number = (index + 1).toString().padLeft(2, '0');

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Question row
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedIndexes.remove(index);
                          } else {
                            _expandedIndexes.add(index);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Number
                            Text(
                              number,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Question text
                            Expanded(
                              child: Text(
                                faq['question']!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Arrow icon
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Answer (expanded)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(44, 0, 16, 14),
                        child: Text(
                          faq['answer']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
