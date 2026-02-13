import 'package:flutter/material.dart';
import '../../core/constants.dart';

class AdvancedFilterDrawer extends StatefulWidget {
  final VoidCallback onApply;
  final VoidCallback onClose;

  const AdvancedFilterDrawer({
    super.key,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<AdvancedFilterDrawer> createState() => _AdvancedFilterDrawerState();
}

class _AdvancedFilterDrawerState extends State<AdvancedFilterDrawer> {
  RangeValues _priceRange = const RangeValues(0, 50000);
  final List<String> _selectedBrands = [];
  final List<String> _brands = ['Apple', 'Samsung', 'Xiaomi', 'Sony', 'Huawei', 'Dyson'];
  double? _selectedRating;
  String? _selectedColor;
  final List<String> _colors = ['Siyah', 'Beyaz', 'Mavi', 'Kırmızı', 'Yeşil', 'Mor'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gelişmiş Filtreleme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Price Range
                const Text('Fiyat Aralığı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_priceRange.start.round()} TL'),
                    Text('${_priceRange.end.round()} TL'),
                  ],
                ),
                RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 100000,
                  divisions: 100,
                  activeColor: AppColors.primary,
                  labels: RangeLabels(
                    '${_priceRange.start.round()} TL',
                    '${_priceRange.end.round()} TL',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _priceRange = values;
                    });
                  },
                ),
                const Divider(height: 32),

                // Brands
                const Text('Marka', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ..._brands.map((brand) => CheckboxListTile(
                  title: Text(brand),
                  value: _selectedBrands.contains(brand),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedBrands.add(brand);
                      } else {
                        _selectedBrands.remove(brand);
                      }
                    });
                  },
                )),
                const Divider(height: 32),

                // Rating
                const Text('Puan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [4.0, 3.0, 2.0, 1.0].map((rating) {
                    final isSelected = _selectedRating == rating;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRating = isSelected ? null : rating;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$rating ve üzeri',
                              style: TextStyle(
                                color: isSelected ? AppColors.primary : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 32),

                // Colors
                const Text('Renk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((color) {
                    final isSelected = _selectedColor == color;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedColor = isSelected ? null : color;
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getColor(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 2,
                                )
                              ] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                          const SizedBox(height: 4),
                          Text(color, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Temizle', style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(String name) {
    switch (name.toLowerCase()) {
      case 'siyah': return Colors.black;
      case 'beyaz': return Colors.white;
      case 'mavi': return Colors.blue;
      case 'kırmızı': return Colors.red;
      case 'yeşil': return Colors.green;
      case 'mor': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
