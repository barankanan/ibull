import 'package:flutter/material.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';

/// Ürün varyant seçici widget'ı
/// Aynı varyant grubundaki ürünler arasında geçiş yapar
/// Örnek: iPhone 15 - Farklı renkler ve depolama seçenekleri
class ProductVariantSelector extends StatefulWidget {
  final DBProduct currentProduct;
  final Function(DBProduct) onVariantSelected;

  const ProductVariantSelector({
    super.key,
    required this.currentProduct,
    required this.onVariantSelected,
  });

  @override
  State<ProductVariantSelector> createState() => _ProductVariantSelectorState();
}

class _ProductVariantSelectorState extends State<ProductVariantSelector> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<DBProduct> _variants = [];
  Map<String, Set<String>> _variantOptions = {}; // Örn: {"Renk": {"Siyah", "Beyaz"}, "Depolama": {"256GB", "512GB"}}
  Map<String, String> _selectedOptions = {}; // Örn: {"Renk": "Siyah", "Depolama": "512GB"}
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    if (widget.currentProduct.variantGroupId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Varyant grubundaki tüm ürünleri getir
      final variants = await _dbHelper.getProductVariantsByGroupId(
        widget.currentProduct.variantGroupId!,
      );

      // Varyant seçeneklerini organize et
      final Map<String, Set<String>> options = {};
      
      for (var variant in variants) {
        if (variant.variantOptions == null) continue;
        
        final variantMap = variant.getVariantOptionsMap();
        for (var entry in variantMap.entries) {
          options.putIfAbsent(entry.key, () => {});
          options[entry.key]!.add(entry.value);
        }
      }

      // Mevcut ürünün seçeneklerini başlangıç değeri olarak ayarla
      final currentOptionsMap = widget.currentProduct.getVariantOptionsMap();

      setState(() {
        _variants = variants;
        _variantOptions = options;
        _selectedOptions = currentOptionsMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Varyant yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onOptionSelected(String optionKey, String optionValue) async {
    setState(() {
      _selectedOptions[optionKey] = optionValue;
    });

    // Seçilen opsiyonlara göre ürünü bul
    final matchedProduct = await _dbHelper.getProductByVariantOptions(
      widget.currentProduct.variantGroupId!,
      _selectedOptions,
    );

    if (matchedProduct != null) {
      widget.onVariantSelected(matchedProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_variants.isEmpty || _variantOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Seçenekler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._variantOptions.entries.map((entry) {
            return _buildOptionSelector(
              entry.key,
              entry.value.toList()..sort(),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOptionSelector(String optionKey, List<String> values) {
    final selectedValue = _selectedOptions[optionKey];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            optionKey,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) {
              final isSelected = value == selectedValue;
              return _buildOptionChip(
                optionKey,
                value,
                isSelected,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip(String optionKey, String value, bool isSelected) {
    return InkWell(
      onTap: () => _onOptionSelected(optionKey, value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}
