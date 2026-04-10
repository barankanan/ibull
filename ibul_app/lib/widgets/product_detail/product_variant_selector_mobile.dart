import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductVariantSelectorMobile extends StatefulWidget {
  const ProductVariantSelectorMobile({super.key});

  @override
  State<ProductVariantSelectorMobile> createState() =>
      _ProductVariantSelectorMobileState();
}

class _ProductVariantSelectorMobileState
    extends State<ProductVariantSelectorMobile> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;

    final maps = _variantMaps(product.variants);
    if (maps.isEmpty) return const SizedBox.shrink();

    final isElectronics = _isElectronicsProduct(product);
    if (isElectronics) {
      return _buildElectronicsStyleSelector(
        viewModel: viewModel,
        product: product,
        maps: maps,
      );
    }

    final groups = _groupsForProduct(
      product,
    ).where((g) => _hasAnyValue(maps, g.key)).toList();
    if (groups.isEmpty) return const SizedBox.shrink();

    final selection = Map<String, String>.from(viewModel.selectedVariants);
    for (final group in groups) {
      final values = _availableValuesForKey(
        maps: maps,
        selection: selection,
        keyName: group.key,
      );
      if (values.isEmpty) continue;
      final current = selection[group.key];
      if (current == null || !values.contains(current)) {
        selection[group.key] = values.first;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _GroupSection(
            title: group.title,
            selectedValue: selection[group.key] ?? '',
            child: group.style == _GroupStyle.colorRow
                ? _ColorRow(
                    values: _availableValuesForKey(
                      maps: maps,
                      selection: selection,
                      keyName: group.key,
                    ),
                    selected: selection[group.key],
                    imageUrlForValue: (value) =>
                        _imageUrlForKeyValue(maps, group.key, value),
                    onSelect: (v) =>
                        viewModel.updateSelectedVariant(group.key, v),
                  )
                : _ChipGrid(
                    values: _availableValuesForKey(
                      maps: maps,
                      selection: selection,
                      keyName: group.key,
                    ),
                    selected: selection[group.key],
                    onSelect: (v) =>
                        viewModel.updateSelectedVariant(group.key, v),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildElectronicsStyleSelector({
    required ProductDetailViewModel viewModel,
    required dynamic product,
    required List<Map<String, dynamic>> maps,
  }) {
    final selection = Map<String, String>.from(viewModel.selectedVariants);
    final capacities = _uniqueValues(maps, 'storage');
    if (capacities.isEmpty) return const SizedBox.shrink();

    final colors = _uniqueValues(maps, 'color');
    final resolvedSelection = _resolveElectronicsSelection(
      maps: maps,
      selection: selection,
      capacities: capacities,
      colors: colors,
    );
    final selectedCapacity = resolvedSelection['storage'] ?? capacities.first;
    final selectedColor = resolvedSelection['color'] ?? '';
    final byCapacity = Map<String, String>.from(resolvedSelection)
      ..['storage'] = selectedCapacity;

    if (selectedCapacity.isNotEmpty &&
        viewModel.selectedVariants['storage'] != selectedCapacity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        viewModel.updateSelectedVariant('storage', selectedCapacity);
      });
    }
    if (selectedColor.isNotEmpty &&
        viewModel.selectedVariants['color'] != selectedColor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        viewModel.updateSelectedVariant('color', selectedColor);
      });
    }

    final variantForColor = _findVariant(
      maps: maps,
      selection: byCapacity,
      key: 'color',
      value: selectedColor,
    );
    final basePrice = _parsePrice(product.price?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kapasite:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedCapacity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: capacities.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final capacity = capacities[index];
                        final selected = capacity == selectedCapacity;
                        final nextColor = _firstAvailableColorForCapacity(
                          maps: maps,
                          capacity: capacity,
                          fallbackColor: selectedColor,
                        );
                        return GestureDetector(
                          onTap: () {
                            viewModel.updateSelectedVariant(
                              'storage',
                              capacity,
                            );
                            if (nextColor.isNotEmpty &&
                                nextColor != selectedColor) {
                              viewModel.updateSelectedVariant(
                                'color',
                                nextColor,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF6B21A8)
                                    : Colors.grey.shade300,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              capacity,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? const Color(0xFF6B21A8)
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1.5,
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B21A8).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Renk:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedColor.isEmpty ? '-' : selectedColor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 148,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: colors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final color = colors[index];
                        final selected = color == selectedColor;
                        final effectiveCapacity =
                            _firstAvailableCapacityForColor(
                              maps: maps,
                              color: color,
                              fallbackCapacity: selectedCapacity,
                            );
                        final variant = _findVariant(
                          maps: maps,
                          selection: {'storage': effectiveCapacity},
                          key: 'color',
                          value: color,
                        );
                        final imageUrl = _imageUrlFromVariant(variant);
                        final priceText = _priceText(
                          basePrice: basePrice,
                          diff: _variantPriceDiff(variant),
                        );
                        return GestureDetector(
                          onTap: () {
                            viewModel.updateSelectedVariant('color', color);
                            if (effectiveCapacity.isNotEmpty &&
                                effectiveCapacity != selectedCapacity) {
                              viewModel.updateSelectedVariant(
                                'storage',
                                effectiveCapacity,
                              );
                            }
                          },
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF6B21A8)
                                    : Colors.grey.shade300,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _PreviewImage(url: imageUrl),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  color,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? const Color(0xFF6B21A8)
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  priceText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (variantForColor != null &&
            (variantForColor['priceDifference'] ?? '')
                .toString()
                .isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Fiyat farkı: ${_priceDiffLabel(_variantPriceDiff(variantForColor))}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  bool _isElectronicsProduct(dynamic product) {
    final category = (product.category ?? '').toString().toLowerCase();
    final sub = (product.subCategory ?? '').toString().toLowerCase();
    return category.contains('elektr') ||
        sub.contains('telefon') ||
        sub.contains('phone') ||
        sub.contains('bilgisayar') ||
        sub.contains('laptop');
  }

  List<Map<String, dynamic>> _variantMaps(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => m.isNotEmpty)
        .toList();
  }

  bool _hasAnyValue(List<Map<String, dynamic>> maps, String key) {
    return maps.any((m) {
      final v = m[key];
      return v != null && v.toString().trim().isNotEmpty;
    });
  }

  List<String> _availableValuesForKey({
    required List<Map<String, dynamic>> maps,
    required Map<String, String> selection,
    required String keyName,
  }) {
    final values = <String>{};
    for (final m in maps) {
      var ok = true;
      for (final entry in selection.entries) {
        if (entry.key == keyName) continue;
        final v = m[entry.key];
        if (v == null) continue;
        if (v.toString() != entry.value) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final v = m[keyName];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      values.add(s);
    }
    return values.toList();
  }

  List<String> _uniqueValues(List<Map<String, dynamic>> maps, String key) {
    final values = <String>{};
    for (final m in maps) {
      final v = m[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) values.add(s);
    }
    return values.toList();
  }

  Map<String, dynamic>? _findVariant({
    required List<Map<String, dynamic>> maps,
    required Map<String, String> selection,
    required String key,
    required String value,
  }) {
    final target = Map<String, String>.from(selection)..[key] = value;
    for (final m in maps) {
      var ok = true;
      for (final entry in target.entries) {
        if (entry.value.trim().isEmpty) continue;
        final v = (m[entry.key] ?? '').toString().trim();
        if (v.isEmpty) continue;
        if (v != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) return m;
    }
    return null;
  }

  Map<String, String> _resolveElectronicsSelection({
    required List<Map<String, dynamic>> maps,
    required Map<String, String> selection,
    required List<String> capacities,
    required List<String> colors,
  }) {
    final resolved = Map<String, String>.from(selection);
    if (capacities.isNotEmpty) {
      final current = resolved['storage'];
      if (current == null || !capacities.contains(current)) {
        resolved['storage'] = capacities.first;
      }
    }
    if (colors.isNotEmpty) {
      final current = resolved['color'];
      if (current == null || !colors.contains(current)) {
        resolved['color'] = colors.first;
      }
    }

    final hasExactMatch = _findVariant(
      maps: maps,
      selection: {'storage': resolved['storage'] ?? ''},
      key: 'color',
      value: resolved['color'] ?? '',
    );
    if (hasExactMatch != null) return resolved;

    final currentColor = resolved['color'] ?? '';
    if (currentColor.isNotEmpty) {
      resolved['storage'] = _firstAvailableCapacityForColor(
        maps: maps,
        color: currentColor,
        fallbackCapacity: resolved['storage'] ?? '',
      );
    }

    final currentCapacity = resolved['storage'] ?? '';
    if (currentCapacity.isNotEmpty) {
      resolved['color'] = _firstAvailableColorForCapacity(
        maps: maps,
        capacity: currentCapacity,
        fallbackColor: resolved['color'] ?? '',
      );
    }

    return resolved;
  }

  String _firstAvailableColorForCapacity({
    required List<Map<String, dynamic>> maps,
    required String capacity,
    required String fallbackColor,
  }) {
    final matching = maps.where((variant) {
      return (variant['storage'] ?? '').toString().trim() == capacity;
    }).toList();
    if (matching.isEmpty) return fallbackColor;
    if (fallbackColor.isNotEmpty &&
        matching.any(
          (variant) =>
              (variant['color'] ?? '').toString().trim() == fallbackColor,
        )) {
      return fallbackColor;
    }
    return (matching.first['color'] ?? '').toString().trim();
  }

  String _firstAvailableCapacityForColor({
    required List<Map<String, dynamic>> maps,
    required String color,
    required String fallbackCapacity,
  }) {
    final matching = maps.where((variant) {
      return (variant['color'] ?? '').toString().trim() == color;
    }).toList();
    if (matching.isEmpty) return fallbackCapacity;
    if (fallbackCapacity.isNotEmpty &&
        matching.any(
          (variant) =>
              (variant['storage'] ?? '').toString().trim() == fallbackCapacity,
        )) {
      return fallbackCapacity;
    }
    return (matching.first['storage'] ?? '').toString().trim();
  }

  String? _imageUrlFromVariant(Map<String, dynamic>? variant) {
    if (variant == null) return null;
    final url =
        variant['imageUrl'] ??
        variant['image_url'] ??
        variant['imagePath'] ??
        variant['image_path'];
    final s = url?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  double _variantPriceDiff(Map<String, dynamic>? variant) {
    if (variant == null) return 0;
    final raw = variant['priceDifference'] ?? variant['price_difference'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  double _parsePrice(String text) {
    final cleaned = text
        .replaceAll('TL', '')
        .replaceAll('₺', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String _priceText({required double basePrice, required double diff}) {
    final total = basePrice + diff;
    if (total <= 0) return 'Fiyat yok';
    return '${total.toStringAsFixed(0)} TL';
  }

  String _priceDiffLabel(double diff) {
    if (diff == 0) return 'Ana fiyat';
    final sign = diff > 0 ? '+' : '-';
    return '$sign${diff.abs().toStringAsFixed(0)} TL';
  }

  String? _imageUrlForKeyValue(
    List<Map<String, dynamic>> maps,
    String key,
    String value,
  ) {
    for (final m in maps) {
      final v = m[key];
      if (v == null) continue;
      if (v.toString() != value) continue;
      final url =
          m['imageUrl'] ?? m['image_url'] ?? m['imagePath'] ?? m['image_path'];
      final s = url?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  List<_VariantGroup> _groupsForProduct(dynamic product) {
    final category = (product.category ?? '').toString().toLowerCase();
    final sub = (product.subCategory ?? '').toString().toLowerCase();

    final isFood =
        category.contains('yemek') ||
        sub.contains('yemek') ||
        sub.contains('food');
    final isElectronics =
        category.contains('elektr') ||
        sub.contains('telefon') ||
        sub.contains('phone') ||
        sub.contains('bilgisayar') ||
        sub.contains('laptop');
    final isClothing =
        category.contains('giyim') ||
        sub.contains('giyim') ||
        sub.contains('tekstil') ||
        sub.contains('kıyafet') ||
        sub.contains('kiyafet');

    if (isFood) {
      return const [
        _VariantGroup(
          key: 'color',
          title: 'Porsiyon',
          style: _GroupStyle.colorRow,
        ),
        _VariantGroup(key: 'size', title: 'Seçenek', style: _GroupStyle.chips),
      ];
    }

    if (isClothing) {
      return const [
        _VariantGroup(key: 'color', title: 'Renk', style: _GroupStyle.colorRow),
        _VariantGroup(key: 'size', title: 'Beden', style: _GroupStyle.chips),
        _VariantGroup(key: 'boy', title: 'Boy', style: _GroupStyle.chips),
      ];
    }

    if (isElectronics) {
      return const [
        _VariantGroup(key: 'color', title: 'Renk', style: _GroupStyle.colorRow),
        _VariantGroup(
          key: 'storage',
          title: 'Dahili Hafıza',
          style: _GroupStyle.chips,
        ),
        _VariantGroup(key: 'ram', title: 'RAM', style: _GroupStyle.chips),
        _VariantGroup(key: 'size', title: 'Boyut', style: _GroupStyle.chips),
      ];
    }

    return const [
      _VariantGroup(key: 'color', title: 'Renk', style: _GroupStyle.colorRow),
      _VariantGroup(key: 'size', title: 'Boyut', style: _GroupStyle.chips),
      _VariantGroup(key: 'ram', title: 'RAM', style: _GroupStyle.chips),
      _VariantGroup(
        key: 'storage',
        title: 'Depolama',
        style: _GroupStyle.chips,
      ),
    ];
  }
}

enum _GroupStyle { colorRow, chips }

class _VariantGroup {
  final String key;
  final String title;
  final _GroupStyle style;

  const _VariantGroup({
    required this.key,
    required this.title,
    required this.style,
  });
}

class _GroupSection extends StatelessWidget {
  final String title;
  final String selectedValue;
  final Widget child;

  const _GroupSection({
    required this.title,
    required this.selectedValue,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$title:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final List<String> values;
  final String? selected;
  final String? Function(String value) imageUrlForValue;
  final ValueChanged<String> onSelect;

  const _ColorRow({
    required this.values,
    required this.selected,
    required this.imageUrlForValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final v = values[index];
          final isSelected = selected == v;
          final isPopular = index == 0;
          final imageUrl = imageUrlForValue(v);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(v),
              child: SizedBox(
                width: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF673AB7)
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: _PreviewImage(url: imageUrl),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            v,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? const Color(0xFF673AB7)
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPopular)
                      Positioned(
                        top: -8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Text(
                              'Popüler',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChipGrid extends StatelessWidget {
  final List<String> values;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ChipGrid({
    required this.values,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((v) {
        final isSelected = selected == v;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF673AB7)
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                v,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF673AB7) : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  final String? url;

  const _PreviewImage({this.url});

  @override
  Widget build(BuildContext context) {
    final v = (url ?? '').trim();
    if (v.isEmpty) {
      return Container(color: Colors.grey.shade100);
    }
    if (v.startsWith('http')) {
      return OptimizedImage(
        imageUrlOrPath: v,
        fit: BoxFit.cover,
        errorWidget: Container(color: Colors.grey.shade100),
      );
    }
    return Image.asset(
      v,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(color: Colors.grey.shade100),
    );
  }
}
