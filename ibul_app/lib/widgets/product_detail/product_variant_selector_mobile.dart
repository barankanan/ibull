import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductVariantSelectorMobile extends StatelessWidget {
  const ProductVariantSelectorMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final maps = viewModel.variantMaps;
    if (maps.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryGroups = _extractSecondaryGroups(maps);
    final hasExplicitColors = maps.any(_isGenuineColor);

    final cardVariants = hasExplicitColors
        ? _extractColorVariants(maps, viewModel.selectedVariants)
        : const <Map<String, dynamic>>[];

    final selectedColor = (viewModel.selectedVariants['color'] ??
            viewModel.selectedVariantMap?['color'] ??
            '')
        .toString()
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A) Renk ve Görselli Varyant Kartları (72x88 px)
        if (cardVariants.isNotEmpty) ...[
          if (selectedColor.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Renk:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF1F5F9) : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedColor,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            height: 96,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: cardVariants.map((variant) {
                  final colorName = (variant['color'] ??
                          variant['Renk'] ??
                          variant['renk'] ??
                          variant['size'] ??
                          '')
                      .toString()
                      .trim();
                  final isSelected = selectedColor.isNotEmpty
                      ? (viewModel.selectedVariants['color'] == colorName)
                      : (viewModel.selectedVariantMap == variant);

                  return _buildVariantCard(
                    context: context,
                    viewModel: viewModel,
                    variant: variant,
                    displayName: colorName,
                    isDark: isDark,
                    isSelected: isSelected,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // B) Çoklu Nitelik Çipleri (Kapasite, Beden, Boyut vb. - Pill Chips)
        if (secondaryGroups.isNotEmpty) ...[
          for (final entry in secondaryGroups.entries) ...[
            _buildSecondaryGroupSection(
              context: context,
              viewModel: viewModel,
              maps: maps,
              groupKey: entry.key,
              values: entry.value,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildVariantCard({
    required BuildContext context,
    required ProductDetailViewModel viewModel,
    required Map<String, dynamic> variant,
    required String displayName,
    required bool isDark,
    required bool isSelected,
  }) {
    final hexCode = (variant['colorHex'] ??
            variant['color_hex'] ??
            variant['hex'])
        ?.toString()
        .trim();
    final swatchColor = _resolveVariantColor(displayName, hexCode);

    final rawUrl = variant['imageUrl'] ??
        variant['image_url'] ??
        variant['imagePath'] ??
        variant['image_path'];
    final imageUrl = rawUrl?.toString().trim();
    final hasValidImage =
        imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('blob:');

    final rawDiff =
        variant['priceDifference'] ?? variant['price_difference'];
    final diff = (rawDiff as num?)?.toDouble() ??
        double.tryParse(rawDiff?.toString().replaceAll(',', '.') ?? '') ??
        0.0;
    final priceDiffLabel = diff == 0
        ? ''
        : (diff > 0
            ? '+${diff.toStringAsFixed(0)} ₺'
            : '${diff.toStringAsFixed(0)} ₺');

    final rawStock =
        variant['stock'] ?? variant['stock_quantity'] ?? variant['stok'];
    final stock = (rawStock as num?)?.toInt() ??
        int.tryParse(rawStock?.toString() ?? '') ??
        1;
    final isOutOfStock = stock <= 0;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: isOutOfStock
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$displayName seçeneği tükenmiştir.'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : () {
                viewModel.selectVariant(variant);
              },
        child: Opacity(
          opacity: isOutOfStock ? 0.5 : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 88,
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 48x48 Yuvarlak Köşeli Varyant Görseli veya Color Avatar
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: hasValidImage
                            ? Image.network(
                                imageUrl,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildColorAvatar(swatchColor, isDark),
                              )
                            : _buildColorAvatar(swatchColor, isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 11px Renk Adı
                    Text(
                      displayName.isEmpty ? '-' : displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF1E293B)),
                        decoration:
                            isOutOfStock ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    // Varsa Fiyat Farkı Rozeti (+50 ₺)
                    if (priceDiffLabel.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        priceDiffLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Sağ Üst Onay Rozeti (Checkmark Badge)
              if (isSelected)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Tükendi Rozeti
              if (isOutOfStock)
                Positioned(
                  top: 22,
                  left: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Tükendi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorAvatar(Color color, bool isDark) {
    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryGroupSection({
    required BuildContext context,
    required ProductDetailViewModel viewModel,
    required List<Map<String, dynamic>> maps,
    required String groupKey,
    required List<String> values,
    required bool isDark,
  }) {
    String currentSelected =
        viewModel.selectedVariants[groupKey] ?? '';
    if (currentSelected.isEmpty) {
      if (groupKey == 'Kapasite') {
        currentSelected = viewModel.selectedVariants['storage'] ?? '';
      } else if (groupKey == 'RAM') {
        currentSelected = viewModel.selectedVariants['ram'] ?? '';
      } else if (groupKey == 'Beden / Boyut' || groupKey == 'Boyut / Beden') {
        currentSelected = viewModel.selectedVariants['size'] ?? '';
      }
    }
    if (currentSelected.isEmpty && values.isNotEmpty) {
      currentSelected = values.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$groupKey:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF1F5F9) : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              currentSelected,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: values.map((val) {
              final isChipSelected = val == currentSelected;
              final inStock = _isSecondaryValueInStock(
                maps,
                groupKey,
                val,
                viewModel.selectedVariants,
              );

              // Find matching variant to display price difference if any
              Map<String, dynamic>? matchingVariant;
              for (final m in maps) {
                final opts = m['options'];
                if (opts is Map && opts[groupKey]?.toString().trim() == val) {
                  matchingVariant = m;
                  break;
                }
                final optType =
                    (m['optionType'] ?? m['option_type'])?.toString().trim();
                if (optType == groupKey &&
                    (m['size'] ?? m['beden'])?.toString().trim() == val) {
                  matchingVariant = m;
                  break;
                }
                if (groupKey == 'Kapasite') {
                  if ((m['storage'] ?? m['hafıza'] ?? m['hafiza'])
                          ?.toString()
                          .trim() ==
                      val) {
                    matchingVariant = m;
                    break;
                  }
                } else if (groupKey == 'RAM') {
                  if (m['ram']?.toString().trim() == val) {
                    matchingVariant = m;
                    break;
                  }
                } else if (groupKey == 'Beden / Boyut' ||
                    groupKey == 'Boyut / Beden') {
                  if ((m['size'] ?? m['beden'])?.toString().trim() == val) {
                    matchingVariant = m;
                    break;
                  }
                }
                final rawColor =
                    (m['color'] ?? m['Renk'] ?? m['renk'])?.toString().trim();
                if (rawColor == val) {
                  matchingVariant = m;
                  break;
                }
              }

              final rawDiff = matchingVariant?['priceDifference'] ??
                  matchingVariant?['price_difference'];
              final diff = (rawDiff as num?)?.toDouble() ??
                  double.tryParse(
                          rawDiff?.toString().replaceAll(',', '.') ?? '') ??
                      0.0;

              final String chipLabel;
              if (diff != 0) {
                final diffStr = diff > 0
                    ? '+${diff.toStringAsFixed(0)} ₺'
                    : '${diff.toStringAsFixed(0)} ₺';
                chipLabel = '$val ($diffStr)';
              } else {
                chipLabel = val;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: !inStock
                      ? () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$val seçeneği tükenmiştir.'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      : () {
                          if (matchingVariant != null &&
                              matchingVariant.isNotEmpty) {
                            viewModel.selectVariant(matchingVariant);
                          }
                          if (groupKey == 'Kapasite') {
                            viewModel.updateSelectedVariant('storage', val);
                          } else if (groupKey == 'RAM') {
                            viewModel.updateSelectedVariant('ram', val);
                          } else if (groupKey == 'Beden / Boyut' ||
                              groupKey == 'Boyut / Beden') {
                            viewModel.updateSelectedVariant('size', val);
                          } else {
                            viewModel.updateSelectedVariant(groupKey, val);
                          }
                        },
                  borderRadius: BorderRadius.circular(10),
                  child: Opacity(
                    opacity: inStock ? 1.0 : 0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isChipSelected
                            ? AppColors.primary.withValues(
                                alpha: isDark ? 0.22 : 0.10,
                              )
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChipSelected
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                          width: isChipSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Text(
                        chipLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChipSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isChipSelected
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155)),
                          decoration:
                              inStock ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static bool _isGenuineColor(Map<String, dynamic> v) {
    final hexCode =
        (v['colorHex'] ?? v['color_hex'] ?? v['hex'])?.toString().trim();
    if (hexCode != null && hexCode.isNotEmpty && hexCode != '#') {
      return true;
    }
    final rawColor =
        (v['color'] ?? v['Renk'] ?? v['renk'])?.toString().trim();
    if (rawColor == null || rawColor.isEmpty) return false;
    final lower = rawColor.toLowerCase();
    if (lower == 'standart' ||
        lower == '-' ||
        lower == 'yok' ||
        lower == 'default') {
      return false;
    }
    // Check if it looks like a size/dimension/storage/numeric value instead of a color
    if (RegExp(
      r'\b(\d+(?:[.,]\d+)?\s*(?:inç|inch|"|cm|mm|m|gb|tb|mb|mah|w|volt|v|numara|no))\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return false;
    }
    if (RegExp(r'^\d+([.,]\d+)?$').hasMatch(lower)) {
      return false;
    }
    const nonColorWords = {
      'ekran',
      'boyut',
      'kapasite',
      'beden',
      'numara',
      'hafıza',
      'hafiza',
      'ram',
      'adet',
      'paket'
    };
    if (nonColorWords.any((w) => lower.contains(w))) {
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _extractColorVariants(
    List<Map<String, dynamic>> maps,
    Map<String, String> selectedVariants,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final v in maps) {
      if (!_isGenuineColor(v)) continue;
      final color =
          (v['color'] ?? v['Renk'] ?? v['renk'])?.toString().trim() ?? '';
      if (color.isEmpty || seen.contains(color)) continue;
      seen.add(color);

      // Try finding the exact variant that matches color + current secondary options
      final match = maps.firstWhere(
        (candidate) {
          final c = (candidate['color'] ??
                  candidate['Renk'] ??
                  candidate['renk'])
              ?.toString()
              .trim();
          if (c != color) return false;
          for (final entry in selectedVariants.entries) {
            if (entry.key == 'color') continue;
            final candVal = (candidate[entry.key] ??
                    (candidate['options'] is Map
                        ? (candidate['options'] as Map)[entry.key]
                        : null))
                ?.toString()
                .trim();
            if (candVal != null &&
                candVal.isNotEmpty &&
                candVal != entry.value) {
              return false;
            }
          }
          return true;
        },
        orElse: () => v,
      );

      result.add(match);
    }

    return result;
  }

  Map<String, List<String>> _extractSecondaryGroups(
    List<Map<String, dynamic>> maps,
  ) {
    final groups = <String, Set<String>>{};

    for (final map in maps) {
      final options = map['options'];
      if (options is Map) {
        for (final entry in options.entries) {
          final key = entry.key.toString().trim();
          final val = entry.value?.toString().trim() ?? '';
          if (key.isNotEmpty &&
              val.isNotEmpty &&
              key.toLowerCase() != 'color' &&
              key.toLowerCase() != 'renk') {
            groups.putIfAbsent(key, () => <String>{}).add(val);
          }
        }
      }

      final optionType =
          (map['optionType'] ?? map['option_type'])?.toString().trim();
      final size = (map['size'] ?? map['beden'])?.toString().trim();
      if (optionType != null &&
          optionType.isNotEmpty &&
          size != null &&
          size.isNotEmpty &&
          optionType.toLowerCase() != 'color' &&
          optionType.toLowerCase() != 'renk') {
        groups.putIfAbsent(optionType, () => <String>{}).add(size);
      }

      final storage = (map['storage'] ??
              map['hafıza'] ??
              map['hafiza'])
          ?.toString()
          .trim();
      if (storage != null && storage.isNotEmpty) {
        groups.putIfAbsent('Kapasite', () => <String>{}).add(storage);
      }

      final ram = map['ram']?.toString().trim();
      if (ram != null && ram.isNotEmpty) {
        groups.putIfAbsent('RAM', () => <String>{}).add(ram);
      }

      // If variant has non-genuine color string (e.g. "55 inç" entered as color):
      final rawColor =
          (map['color'] ?? map['Renk'] ?? map['renk'])?.toString().trim();
      if (rawColor != null && rawColor.isNotEmpty && !_isGenuineColor(map)) {
        final label = (optionType != null && optionType.isNotEmpty)
            ? optionType
            : (rawColor.contains('inç') || rawColor.contains('"')
                ? 'Ekran Boyutu'
                : 'Seçenek');
        groups.putIfAbsent(label, () => <String>{}).add(rawColor);
      }

      if (optionType == null || optionType.isEmpty) {
        if (size != null &&
            size.isNotEmpty &&
            size.toLowerCase() != 'standart' &&
            size != '-') {
          final label = (size.contains('inç') || size.contains('"'))
              ? 'Ekran Boyutu'
              : 'Beden / Boyut';
          groups.putIfAbsent(label, () => <String>{}).add(size);
        }
      }
    }

    return groups.map((k, v) => MapEntry(k, v.toList()));
  }

  bool _isSecondaryValueInStock(
    List<Map<String, dynamic>> maps,
    String groupKey,
    String val,
    Map<String, String> selectedVariants,
  ) {
    final matching = maps.where((m) {
      if (groupKey == 'Kapasite') {
        return (m['storage'] ?? m['hafıza'] ?? m['hafiza'])?.toString().trim() ==
            val;
      } else if (groupKey == 'RAM') {
        return m['ram']?.toString().trim() == val;
      } else if (groupKey == 'Beden / Boyut') {
        return (m['size'] ?? m['beden'])?.toString().trim() == val;
      } else {
        final opts = m['options'];
        if (opts is Map && opts[groupKey]?.toString().trim() == val) {
          return true;
        }
        final optType =
            (m['optionType'] ?? m['option_type'])?.toString().trim();
        if (optType == groupKey &&
            (m['size'] ?? m['beden'])?.toString().trim() == val) {
          return true;
        }
      }
      return false;
    });

    if (matching.isEmpty) return true;
    return matching.any((m) {
      final rawStock = m['stock'] ?? m['stock_quantity'] ?? m['stok'];
      final st = (rawStock as num?)?.toInt() ??
          int.tryParse(rawStock?.toString() ?? '') ??
          1;
      return st > 0;
    });
  }

  Color _resolveVariantColor(String? colorName, String? hexCode) {
    if (hexCode != null && hexCode.trim().isNotEmpty) {
      String cleanHex = hexCode.trim().replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      final val = int.tryParse(cleanHex, radix: 16);
      if (val != null) return Color(val);
    }

    final name = (colorName ?? '').toLowerCase().trim();
    if (name.contains('gümüş') ||
        name.contains('gumus') ||
        name.contains('silver')) {
      return const Color(0xFFC0C0C0);
    }
    if (name.contains('kırmızı') ||
        name.contains('kirmizi') ||
        name.contains('red')) {
      return const Color(0xFFE11D48);
    }
    if (name.contains('siyah') || name.contains('black')) {
      return const Color(0xFF1E293B);
    }
    if (name.contains('beyaz') || name.contains('white')) {
      return const Color(0xFFF8FAFC);
    }
    if (name.contains('mavi') ||
        name.contains('blue') ||
        name.contains('lacivert')) {
      return const Color(0xFF2563EB);
    }
    if (name.contains('yeşil') ||
        name.contains('yesil') ||
        name.contains('green')) {
      return const Color(0xFF16A34A);
    }
    if (name.contains('sarı') ||
        name.contains('sari') ||
        name.contains('yellow')) {
      return const Color(0xFFEAB308);
    }
    if (name.contains('turuncu') || name.contains('orange')) {
      return const Color(0xFFF97316);
    }
    if (name.contains('mor') ||
        name.contains('purple') ||
        name.contains('lila')) {
      return const Color(0xFF9333EA);
    }
    if (name.contains('pembe') || name.contains('pink')) {
      return const Color(0xFFEC4899);
    }
    if (name.contains('gri') ||
        name.contains('grey') ||
        name.contains('gray')) {
      return const Color(0xFF94A3B8);
    }
    if (name.contains('altın') ||
        name.contains('altin') ||
        name.contains('gold')) {
      return const Color(0xFFD97706);
    }
    if (name.contains('kahve') || name.contains('brown')) {
      return const Color(0xFF78350F);
    }
    if (name.contains('bej') ||
        name.contains('beige') ||
        name.contains('krem')) {
      return const Color(0xFFF5F5DC);
    }
    return const Color(0xFF64748B);
  }
}
