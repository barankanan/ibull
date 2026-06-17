import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../helpers/product_filter_engine.dart';
import '../models/product_filter_models.dart';
import '../../../models/product_model.dart';

class ProductQuickFilterBottomSheet {
  const ProductQuickFilterBottomSheet._();

  static Future<void> show({
    required BuildContext context,
    required ProductFilterGroup group,
    required ProductFilterState currentState,
    required List<Product> baseProducts,
    Map<String, ProductFilterMeta>? productMeta,
    String? searchQuery,
    required ValueChanged<ProductFilterState> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ProductQuickFilterSheetBody(
          group: group,
          currentState: currentState,
          baseProducts: baseProducts,
          productMeta: productMeta,
          searchQuery: searchQuery,
          onApply: onApply,
        );
      },
    );
  }
}

class _ProductQuickFilterSheetBody extends StatefulWidget {
  const _ProductQuickFilterSheetBody({
    required this.group,
    required this.currentState,
    required this.baseProducts,
    required this.productMeta,
    required this.searchQuery,
    required this.onApply,
  });

  final ProductFilterGroup group;
  final ProductFilterState currentState;
  final List<Product> baseProducts;
  final Map<String, ProductFilterMeta>? productMeta;
  final String? searchQuery;
  final ValueChanged<ProductFilterState> onApply;

  @override
  State<_ProductQuickFilterSheetBody> createState() =>
      _ProductQuickFilterSheetBodyState();
}

class _ProductQuickFilterSheetBodyState
    extends State<_ProductQuickFilterSheetBody> {
  late ProductFilterState _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.currentState;
  }

  String get _title {
    switch (widget.group.type) {
      case ProductFilterGroupType.brand:
        return 'Marka seç';
      case ProductFilterGroupType.priceRange:
        return 'Fiyat aralığı';
      case ProductFilterGroupType.discount:
        return 'İndirim';
      case ProductFilterGroupType.stock:
        return 'Stok';
      case ProductFilterGroupType.dynamicAttribute:
        return '${widget.group.title} seç';
      default:
        return '${widget.group.title} seç';
    }
  }

  int get _previewCount => ProductFilterEngine.resolveProducts(
        products: widget.baseProducts,
        state: _draft,
        metaByProductId: widget.productMeta,
        searchQuery: widget.searchQuery,
      ).length;

  void _applyDraft(ProductFilterState next) => setState(() => _draft = next);

  ProductFilterState _clearGroupOnly(ProductFilterState state) {
    switch (widget.group.type) {
      case ProductFilterGroupType.brand:
        return state.copyWith(selectedBrands: {});
      case ProductFilterGroupType.priceRange:
        return state.copyWith(clearPriceMin: true, clearPriceMax: true);
      case ProductFilterGroupType.discount:
        return state.copyWith(onlyDiscounted: false);
      case ProductFilterGroupType.stock:
        return state.copyWith(onlyInStock: false);
      case ProductFilterGroupType.dynamicAttribute:
        final nextMap = Map<String, Set<String>>.from(
          state.selectedDynamicAttributes,
        )..remove(widget.group.title);
        return state.copyWith(selectedDynamicAttributes: nextMap);
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.group.options;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _applyDraft(_clearGroupOnly(_draft)),
                  child: const Text('Temizle'),
                ),
              ],
            ),
            Text(
              '$_previewCount ürün',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (options.isEmpty &&
                widget.group.type != ProductFilterGroupType.priceRange)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Bu filtre için seçenek bulunamadı',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: _buildGroupBody(),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  widget.onApply(_draft);
                  Navigator.pop(context);
                },
                child: Text(
                  _previewCount == 0
                      ? 'Ürün bulunamadı'
                      : '$_previewCount ürünü göster',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupBody() {
    switch (widget.group.type) {
      case ProductFilterGroupType.priceRange:
        return Column(
          children: widget.group.quickPriceChips.map((chip) {
            final selected =
                _draft.priceMin == chip.min &&
                ((_draft.priceMax == null && chip.max == null) ||
                    _draft.priceMax == chip.max);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected,
              title: Text(chip.label),
              onChanged: (_) {
                _applyDraft(
                  _draft.copyWith(
                    priceMin: chip.min,
                    priceMax: chip.max,
                    clearPriceMax: chip.max == null,
                  ),
                );
              },
            );
          }).toList(),
        );
      case ProductFilterGroupType.discount:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.group.options.first.label),
          value: _draft.onlyDiscounted,
          activeThumbColor: AppColors.primary,
          onChanged: (value) =>
              _applyDraft(_draft.copyWith(onlyDiscounted: value)),
        );
      case ProductFilterGroupType.stock:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.group.options.first.label),
          value: _draft.onlyInStock,
          activeThumbColor: AppColors.primary,
          onChanged: (value) =>
              _applyDraft(_draft.copyWith(onlyInStock: value)),
        );
      case ProductFilterGroupType.brand:
        return Column(
          children: widget.group.options.map((option) {
            final value = option.value ?? option.label;
            final selected = _draft.selectedBrands.contains(value);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected,
              title: Text(option.label),
              activeColor: AppColors.primary,
              onChanged: (next) {
                final brands = Set<String>.from(_draft.selectedBrands);
                if (next == true) {
                  brands.add(value);
                } else {
                  brands.remove(value);
                }
                _applyDraft(_draft.copyWith(selectedBrands: brands));
              },
            );
          }).toList(),
        );
      case ProductFilterGroupType.dynamicAttribute:
        final attributeName = widget.group.title;
        final selected =
            _draft.selectedDynamicAttributes[attributeName] ?? {};
        return Column(
          children: widget.group.options.map((option) {
            final value = option.value ?? option.label;
            final isSelected = selected.contains(value);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isSelected,
              title: Text(option.label),
              activeColor: AppColors.primary,
              onChanged: (next) {
                final nextMap = Map<String, Set<String>>.from(
                  _draft.selectedDynamicAttributes,
                );
                final values = Set<String>.from(nextMap[attributeName] ?? {});
                if (next == true) {
                  values.add(value);
                } else {
                  values.remove(value);
                }
                if (values.isEmpty) {
                  nextMap.remove(attributeName);
                } else {
                  nextMap[attributeName] = values;
                }
                _applyDraft(
                  _draft.copyWith(selectedDynamicAttributes: nextMap),
                );
              },
            );
          }).toList(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
