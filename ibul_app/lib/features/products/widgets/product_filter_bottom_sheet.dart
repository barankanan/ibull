import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/product_filter_models.dart';

class ProductFilterBottomSheet extends StatefulWidget {
  const ProductFilterBottomSheet({
    super.key,
    required this.groups,
    required this.initialState,
    required this.resultCount,
    required this.onApply,
  });

  final List<ProductFilterGroup> groups;
  final ProductFilterState initialState;
  final int resultCount;
  final ValueChanged<ProductFilterState> onApply;

  static Future<void> show({
    required BuildContext context,
    required List<ProductFilterGroup> groups,
    required ProductFilterState initialState,
    required int Function(ProductFilterState draft) previewCount,
    required ValueChanged<ProductFilterState> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _ProductFilterBottomSheetBody(
            groups: groups,
            initialState: initialState,
            previewCount: previewCount,
            onApply: onApply,
          ),
        );
      },
    );
  }

  @override
  State<ProductFilterBottomSheet> createState() =>
      _ProductFilterBottomSheetState();
}

class _ProductFilterBottomSheetState extends State<ProductFilterBottomSheet> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ProductFilterBottomSheetBody extends StatefulWidget {
  const _ProductFilterBottomSheetBody({
    required this.groups,
    required this.initialState,
    required this.previewCount,
    required this.onApply,
  });

  final List<ProductFilterGroup> groups;
  final ProductFilterState initialState;
  final int Function(ProductFilterState draft) previewCount;
  final ValueChanged<ProductFilterState> onApply;

  @override
  State<_ProductFilterBottomSheetBody> createState() =>
      _ProductFilterBottomSheetBodyState();
}

class _ProductFilterBottomSheetBodyState
    extends State<_ProductFilterBottomSheetBody> {
  late ProductFilterState _draft;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.initialState;
    _syncPriceControllers();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _syncPriceControllers() {
    _minPriceController.text =
        _draft.priceMin?.round().toString() ?? '';
    _maxPriceController.text =
        _draft.priceMax?.round().toString() ?? '';
  }

  void _updateDraft(ProductFilterState next) {
    setState(() => _draft = next);
  }

  void _clearAll() {
    _updateDraft(
      ProductFilterState.cleared(sortOption: _draft.sortOption),
    );
    _syncPriceControllers();
  }

  int get _previewCount => widget.previewCount(_draft);

  @override
  Widget build(BuildContext context) {
    final previewCount = _previewCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrele',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$previewCount ürün bulundu',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _clearAll, child: const Text('Temizle')),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (_draft.activeFilterCount > 0)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _buildSelectedChips(),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: widget.groups.map(_buildGroup).toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearAll,
                  child: const Text('Temizle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
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
                    previewCount == 0
                        ? 'Ürün bulunamadı'
                        : '$previewCount ürünü göster',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSelectedChips() {
    final chips = <Widget>[];

    void addChip(String label, VoidCallback onRemove) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InputChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onDeleted: onRemove,
            deleteIconColor: AppColors.primary,
          ),
        ),
      );
    }

    for (final brand in _draft.selectedBrands) {
      addChip(brand, () {
        final next = Set<String>.from(_draft.selectedBrands)..remove(brand);
        _updateDraft(_draft.copyWith(selectedBrands: next));
      });
    }
    for (final entry in _draft.selectedDynamicAttributes.entries) {
      for (final value in entry.value) {
        addChip('${entry.key}: $value', () {
          final nextMap = Map<String, Set<String>>.from(
            _draft.selectedDynamicAttributes,
          );
          final values = Set<String>.from(nextMap[entry.key] ?? {})..remove(value);
          if (values.isEmpty) {
            nextMap.remove(entry.key);
          } else {
            nextMap[entry.key] = values;
          }
          _updateDraft(_draft.copyWith(selectedDynamicAttributes: nextMap));
        });
      }
    }
    if (_draft.onlyDiscounted) {
      addChip('İndirimli', () {
        _updateDraft(_draft.copyWith(onlyDiscounted: false));
      });
    }
    if (_draft.onlyInStock) {
      addChip('Stokta', () {
        _updateDraft(_draft.copyWith(onlyInStock: false));
      });
    }

    return chips;
  }

  Widget _buildGroup(ProductFilterGroup group) {
    switch (group.type) {
      case ProductFilterGroupType.priceRange:
        return _buildPriceGroup(group);
      case ProductFilterGroupType.rating:
        return _buildCheckboxGroup(
          group,
          selectedIds: _draft.selectedRatings.map((v) => v.toString()).toSet(),
          onChanged: (option, selected) {
            final next = Set<int>.from(_draft.selectedRatings);
            final rating = int.tryParse(option.id) ?? 0;
            if (selected) {
              next.add(rating);
            } else {
              next.remove(rating);
            }
            _updateDraft(_draft.copyWith(selectedRatings: next));
          },
        );
      case ProductFilterGroupType.discount:
        return _buildToggleGroup(
          group,
          value: _draft.onlyDiscounted,
          onChanged: (value) => _updateDraft(_draft.copyWith(onlyDiscounted: value)),
        );
      case ProductFilterGroupType.stock:
        return _buildToggleGroup(
          group,
          value: _draft.onlyInStock,
          onChanged: (value) => _updateDraft(_draft.copyWith(onlyInStock: value)),
        );
      case ProductFilterGroupType.brand:
        return _buildCheckboxGroup(
          group,
          selectedIds: _draft.selectedBrands,
          onChanged: (option, selected) {
            final next = Set<String>.from(_draft.selectedBrands);
            if (selected) {
              next.add(option.value ?? option.label);
            } else {
              next.remove(option.value ?? option.label);
            }
            _updateDraft(_draft.copyWith(selectedBrands: next));
          },
        );
      case ProductFilterGroupType.category:
        return _buildCheckboxGroup(
          group,
          selectedIds: _draft.selectedCategories,
          onChanged: (option, selected) {
            final next = Set<String>.from(_draft.selectedCategories);
            if (selected) {
              next.add(option.value ?? option.label);
            } else {
              next.remove(option.value ?? option.label);
            }
            _updateDraft(_draft.copyWith(selectedCategories: next));
          },
        );
      case ProductFilterGroupType.subcategory:
        return _buildCheckboxGroup(
          group,
          selectedIds: _draft.selectedSubcategories,
          onChanged: (option, selected) {
            final next = Set<String>.from(_draft.selectedSubcategories);
            if (selected) {
              next.add(option.value ?? option.label);
            } else {
              next.remove(option.value ?? option.label);
            }
            _updateDraft(_draft.copyWith(selectedSubcategories: next));
          },
        );
      case ProductFilterGroupType.seller:
        return _buildCheckboxGroup(
          group,
          selectedIds: _draft.selectedSellerIds,
          onChanged: (option, selected) {
            final next = Set<String>.from(_draft.selectedSellerIds);
            if (selected) {
              next.add(option.value ?? option.id);
            } else {
              next.remove(option.value ?? option.id);
            }
            _updateDraft(_draft.copyWith(selectedSellerIds: next));
          },
        );
      case ProductFilterGroupType.dynamicAttribute:
        final attributeName = group.title;
        final selected = _draft.selectedDynamicAttributes[attributeName] ?? {};
        return _buildCheckboxGroup(
          group,
          selectedIds: selected
              .map((value) => '$attributeName::$value')
              .toSet(),
          onChanged: (option, selectedValue) {
            final nextMap = Map<String, Set<String>>.from(
              _draft.selectedDynamicAttributes,
            );
            final values = Set<String>.from(nextMap[attributeName] ?? {});
            final value = option.value ?? option.label;
            if (selectedValue) {
              values.add(value);
            } else {
              values.remove(value);
            }
            if (values.isEmpty) {
              nextMap.remove(attributeName);
            } else {
              nextMap[attributeName] = values;
            }
            _updateDraft(_draft.copyWith(selectedDynamicAttributes: nextMap));
          },
          optionIdBuilder: (option) => '${group.title}::${option.value ?? option.label}',
        );
      case ProductFilterGroupType.toggle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPriceGroup(ProductFilterGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min fiyat',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    _updateDraft(
                      _draft.copyWith(
                        priceMin: parsed,
                        clearPriceMin: value.trim().isEmpty,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max fiyat',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    _updateDraft(
                      _draft.copyWith(
                        priceMax: parsed,
                        clearPriceMax: value.trim().isEmpty,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.quickPriceChips.map((chip) {
              final isSelected =
                  _draft.priceMin == chip.min &&
                  ((_draft.priceMax == null && chip.max == null) ||
                      _draft.priceMax == chip.max);
              return FilterChip(
                label: Text(chip.label),
                selected: isSelected,
                onSelected: (_) {
                  _updateDraft(
                    _draft.copyWith(
                      priceMin: chip.min,
                      priceMax: chip.max,
                      clearPriceMax: chip.max == null,
                    ),
                  );
                  _syncPriceControllers();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleGroup(
    ProductFilterGroup group, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final option = group.options.first;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        group.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(option.label),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  Widget _buildCheckboxGroup(
    ProductFilterGroup group, {
    required Set<String> selectedIds,
    required void Function(ProductFilterOption option, bool selected) onChanged,
    String Function(ProductFilterOption option)? optionIdBuilder,
  }) {
    final visibleOptions = group.options.take(8).toList();
    final hasMore = group.options.length > visibleOptions.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...visibleOptions.map((option) {
            final id = optionIdBuilder?.call(option) ?? option.id;
            final isSelected = selectedIds.contains(id) ||
                selectedIds.contains(option.value) ||
                selectedIds.contains(option.label);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isSelected,
              title: Text(option.label, style: const TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              onChanged: (value) => onChanged(option, value ?? false),
            );
          }),
          if (hasMore)
            TextButton(
              onPressed: () => _showMoreOptions(group, selectedIds, onChanged, optionIdBuilder),
              child: Text('Daha fazla göster (${group.options.length - visibleOptions.length})'),
            ),
        ],
      ),
    );
  }

  Future<void> _showMoreOptions(
    ProductFilterGroup group,
    Set<String> selectedIds,
    void Function(ProductFilterOption option, bool selected) onChanged,
    String Function(ProductFilterOption option)? optionIdBuilder,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: group.options.map((option) {
                      final id = optionIdBuilder?.call(option) ?? option.id;
                      final isSelected = selectedIds.contains(id) ||
                          selectedIds.contains(option.value) ||
                          selectedIds.contains(option.label);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(option.label),
                        onChanged: (value) {
                          setState(() => onChanged(option, value ?? false));
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    setState(() {});
  }
}
