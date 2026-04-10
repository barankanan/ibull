import 'package:flutter/material.dart';
import '../../core/constants.dart';

class FilterBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onApply;
  final double minPrice;
  final double maxPrice;
  final List<String> availableBrands;

  const FilterBottomSheet({
    super.key,
    required this.onApply,
    this.minPrice = 0,
    this.maxPrice = 100000,
    this.availableBrands = const [],
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late RangeValues _currentPriceRange;
  final Set<String> _selectedBrands = {};
  int _minRating = 0;
  bool _freeShipping = false;
  bool _fastShipping = false;

  @override
  void initState() {
    super.initState();
    _currentPriceRange = RangeValues(widget.minPrice, widget.maxPrice);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtrele',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          
          // Price Range
          const Text(
            'Fiyat Aralığı',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          RangeSlider(
            values: _currentPriceRange,
            min: widget.minPrice,
            max: widget.maxPrice,
            divisions: 100,
            activeColor: AppColors.primary,
            labels: RangeLabels(
              '${_currentPriceRange.start.round()} TL',
              '${_currentPriceRange.end.round()} TL',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                _currentPriceRange = values;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_currentPriceRange.start.round()} TL'),
              Text('${_currentPriceRange.end.round()} TL'),
            ],
          ),
          const SizedBox(height: 16),

          // Brands
          if (widget.availableBrands.isNotEmpty) ...[
            const Text(
              'Marka',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.availableBrands.map((brand) {
                return FilterChip(
                  label: Text(brand),
                  selected: _selectedBrands.contains(brand),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedBrands.add(brand);
                      } else {
                        _selectedBrands.remove(brand);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Rating
          const Text(
            'Puan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(4, (index) {
                final rating = 4 - index; // 4, 3, 2, 1
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$rating'),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const Text(' ve üzeri'),
                      ],
                    ),
                    selected: _minRating == rating,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (bool selected) {
                      setState(() {
                        _minRating = selected ? rating : 0;
                      });
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Shipping
          const Text(
            'Kargo Seçenekleri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          CheckboxListTile(
            title: const Text('Ücretsiz Kargo'),
            value: _freeShipping,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (bool? value) {
              setState(() {
                _freeShipping = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Hızlı Kargo'),
            value: _fastShipping,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (bool? value) {
              setState(() {
                _fastShipping = value ?? false;
              });
            },
          ),
          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply({
                  'minPrice': _currentPriceRange.start,
                  'maxPrice': _currentPriceRange.end,
                  'brands': _selectedBrands.toList(),
                  'minRating': _minRating,
                  'freeShipping': _freeShipping,
                  'fastShipping': _fastShipping,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Filtreleri Uygula',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
