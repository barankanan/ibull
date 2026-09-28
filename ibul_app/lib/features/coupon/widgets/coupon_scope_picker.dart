import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/mobile_category_catalog.dart';
import '../../../models/seller_product.dart';

class CouponScopePicker extends StatelessWidget {
  const CouponScopePicker({
    required this.scope,
    required this.onScopeChanged,
    required this.categories,
    required this.selectedCategoryIds,
    required this.onToggleCategory,
    this.products = const [],
    this.selectedProductIds = const {},
    this.onToggleProduct,
    this.allowAllIbul = true,
    this.allowStores = true,
    super.key,
  });

  final String scope;
  final ValueChanged<String> onScopeChanged;
  final List<MobileCategoryNode> categories;
  final Set<int> selectedCategoryIds;
  final ValueChanged<int> onToggleCategory;
  final List<SellerProduct> products;
  final Set<String> selectedProductIds;
  final ValueChanged<String>? onToggleProduct;
  final bool allowAllIbul;
  final bool allowStores;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            if (allowAllIbul)
              ChoiceChip(
                label: const Text('Tüm İBUL'),
                selected: scope == 'all',
                onSelected: (_) => onScopeChanged('all'),
                selectedColor: AppColors.softPurple,
              )
            else
              ChoiceChip(
                label: const Text('Tüm mağaza'),
                selected: scope == 'all',
                onSelected: (_) => onScopeChanged('all'),
                selectedColor: AppColors.softPurple,
              ),
            ChoiceChip(
              label: Text(allowAllIbul ? 'Belirli kategoriler' : 'Kategoriler'),
              selected: scope == 'categories',
              onSelected: (_) => onScopeChanged('categories'),
              selectedColor: AppColors.softPurple,
            ),
            if (allowStores)
              ChoiceChip(
                label: const Text('Belirli mağazalar'),
                selected: scope == 'stores',
                onSelected: (_) => onScopeChanged('stores'),
                selectedColor: AppColors.softPurple,
              ),
            ChoiceChip(
              label: const Text('Belirli ürünler'),
              selected: scope == 'products',
              onSelected: (_) => onScopeChanged('products'),
              selectedColor: AppColors.softPurple,
            ),
          ],
        ),
        if (scope == 'categories') ...[
          const SizedBox(height: 12),
          ...categories.expand(_categoryTiles),
        ],
        if (scope == 'products') ...[
          const SizedBox(height: 12),
          if (products.isEmpty)
            const Text(
              'Seçilebilecek ürün bulunamadı.',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final id = product.id;
                  return CheckboxListTile(
                    dense: true,
                    value: selectedProductIds.contains(id),
                    title: Text(product.name),
                    onChanged: onToggleProduct == null
                        ? null
                        : (_) => onToggleProduct!(id),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  Iterable<Widget> _categoryTiles(MobileCategoryNode node) {
    final id = node.id;
    return [
      if (id != null)
        CheckboxListTile(
          dense: true,
          value: selectedCategoryIds.contains(id),
          title: Text(node.name),
          onChanged: (_) => onToggleCategory(id),
        ),
      for (final child in node.subCategories)
        if (child.id != null)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: CheckboxListTile(
              dense: true,
              value: selectedCategoryIds.contains(child.id),
              title: Text(child.name),
              onChanged: (_) => onToggleCategory(child.id!),
            ),
          ),
    ];
  }
}
