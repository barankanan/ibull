import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/product_filter_models.dart';

class ProductFilterSidebar extends StatefulWidget {
  const ProductFilterSidebar({
    super.key,
    required this.groups,
    required this.state,
    required this.onChanged,
    required this.onClear,
  });

  final List<ProductFilterGroup> groups;
  final ProductFilterState state;
  final ValueChanged<ProductFilterState> onChanged;
  final VoidCallback onClear;

  @override
  State<ProductFilterSidebar> createState() => _ProductFilterSidebarState();
}

class _ProductFilterSidebarState extends State<ProductFilterSidebar> {
  final Map<String, bool> _expanded = {};
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllers();
    for (final group in widget.groups) {
      _expanded[group.id] = true;
    }
  }

  @override
  void didUpdateWidget(covariant ProductFilterSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.priceMin != widget.state.priceMin ||
        oldWidget.state.priceMax != widget.state.priceMax) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _minPriceController.text = widget.state.priceMin?.round().toString() ?? '';
    _maxPriceController.text = widget.state.priceMax?.round().toString() ?? '';
  }

  void _update(ProductFilterState next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtrele',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Temizle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          if (widget.state.activeFilterCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedChips(),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: widget.groups.map(_buildGroup).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _selectedChips() {
    final chips = <Widget>[];
    for (final brand in widget.state.selectedBrands) {
      chips.add(_chip(brand, () {
        final next = Set<String>.from(widget.state.selectedBrands)..remove(brand);
        _update(widget.state.copyWith(selectedBrands: next));
      }));
    }
    for (final entry in widget.state.selectedDynamicAttributes.entries) {
      for (final value in entry.value) {
        chips.add(_chip('${entry.key}: $value', () {
          final nextMap = Map<String, Set<String>>.from(
            widget.state.selectedDynamicAttributes,
          );
          final values = Set<String>.from(nextMap[entry.key] ?? {})..remove(value);
          if (values.isEmpty) {
            nextMap.remove(entry.key);
          } else {
            nextMap[entry.key] = values;
          }
          _update(widget.state.copyWith(selectedDynamicAttributes: nextMap));
        }));
      }
    }
    return chips;
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onRemove,
      deleteIconColor: AppColors.primary,
    );
  }

  Widget _buildGroup(ProductFilterGroup group) {
    final expanded = _expanded[group.id] ?? true;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded[group.id] = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (expanded) _buildGroupBody(group),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  Widget _buildGroupBody(ProductFilterGroup group) {
    switch (group.type) {
      case ProductFilterGroupType.priceRange:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Min',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value.trim());
                        _update(
                          widget.state.copyWith(
                            priceMin: parsed,
                            clearPriceMin: value.trim().isEmpty,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Max',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value.trim());
                        _update(
                          widget.state.copyWith(
                            priceMax: parsed,
                            clearPriceMax: value.trim().isEmpty,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: group.quickPriceChips.map((chip) {
                  return ActionChip(
                    label: Text(chip.label, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _update(
                        widget.state.copyWith(
                          priceMin: chip.min,
                          priceMax: chip.max,
                          clearPriceMax: chip.max == null,
                        ),
                      );
                      _syncControllers();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      case ProductFilterGroupType.discount:
        return _toggle(
          group.options.first.label,
          widget.state.onlyDiscounted,
          (value) => _update(widget.state.copyWith(onlyDiscounted: value)),
        );
      case ProductFilterGroupType.stock:
        return _toggle(
          group.options.first.label,
          widget.state.onlyInStock,
          (value) => _update(widget.state.copyWith(onlyInStock: value)),
        );
      default:
        return _optionsList(group);
    }
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  Widget _optionsList(ProductFilterGroup group) {
    final visible = group.options.take(6).toList();
    return Column(
      children: [
        ...visible.map((option) => _optionTile(group, option)),
        if (group.options.length > visible.length)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showMore(group),
              child: Text('Daha fazla (${group.options.length - visible.length})'),
            ),
          ),
      ],
    );
  }

  Widget _optionTile(ProductFilterGroup group, ProductFilterOption option) {
    final selected = _isSelected(group, option);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: selected,
      title: Text(option.label, style: const TextStyle(fontSize: 12)),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      onChanged: (value) => _toggleOption(group, option, value ?? false),
    );
  }

  bool _isSelected(ProductFilterGroup group, ProductFilterOption option) {
    switch (group.type) {
      case ProductFilterGroupType.brand:
        return widget.state.selectedBrands.contains(option.value ?? option.label);
      case ProductFilterGroupType.category:
        return widget.state.selectedCategories.contains(option.value ?? option.label);
      case ProductFilterGroupType.subcategory:
        return widget.state.selectedSubcategories.contains(option.value ?? option.label);
      case ProductFilterGroupType.seller:
        return widget.state.selectedSellerIds.contains(option.value ?? option.id);
      case ProductFilterGroupType.rating:
        return widget.state.selectedRatings.contains(int.tryParse(option.id) ?? 0);
      case ProductFilterGroupType.dynamicAttribute:
        final values = widget.state.selectedDynamicAttributes[group.title] ?? {};
        return values.contains(option.value ?? option.label);
      default:
        return false;
    }
  }

  void _toggleOption(
    ProductFilterGroup group,
    ProductFilterOption option,
    bool selected,
  ) {
    switch (group.type) {
      case ProductFilterGroupType.brand:
        final next = Set<String>.from(widget.state.selectedBrands);
        selected
            ? next.add(option.value ?? option.label)
            : next.remove(option.value ?? option.label);
        _update(widget.state.copyWith(selectedBrands: next));
      case ProductFilterGroupType.category:
        final next = Set<String>.from(widget.state.selectedCategories);
        selected
            ? next.add(option.value ?? option.label)
            : next.remove(option.value ?? option.label);
        _update(widget.state.copyWith(selectedCategories: next));
      case ProductFilterGroupType.subcategory:
        final next = Set<String>.from(widget.state.selectedSubcategories);
        selected
            ? next.add(option.value ?? option.label)
            : next.remove(option.value ?? option.label);
        _update(widget.state.copyWith(selectedSubcategories: next));
      case ProductFilterGroupType.seller:
        final next = Set<String>.from(widget.state.selectedSellerIds);
        selected
            ? next.add(option.value ?? option.id)
            : next.remove(option.value ?? option.id);
        _update(widget.state.copyWith(selectedSellerIds: next));
      case ProductFilterGroupType.rating:
        final next = Set<int>.from(widget.state.selectedRatings);
        final rating = int.tryParse(option.id) ?? 0;
        selected ? next.add(rating) : next.remove(rating);
        _update(widget.state.copyWith(selectedRatings: next));
      case ProductFilterGroupType.dynamicAttribute:
        final nextMap = Map<String, Set<String>>.from(
          widget.state.selectedDynamicAttributes,
        );
        final values = Set<String>.from(nextMap[group.title] ?? {});
        final value = option.value ?? option.label;
        selected ? values.add(value) : values.remove(value);
        if (values.isEmpty) {
          nextMap.remove(group.title);
        } else {
          nextMap[group.title] = values;
        }
        _update(widget.state.copyWith(selectedDynamicAttributes: nextMap));
      default:
        break;
    }
  }

  Future<void> _showMore(ProductFilterGroup group) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.title),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: group.options
                .map((option) => _optionTile(group, option))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
