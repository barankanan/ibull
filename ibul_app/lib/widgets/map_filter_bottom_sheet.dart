import 'package:flutter/material.dart';
import '../core/constants.dart';

class MapFilterBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onApply;
  final double currentDistance;
  final List<String> currentCategories;
  final bool openNow;

  const MapFilterBottomSheet({
    super.key,
    required this.onApply,
    this.currentDistance = 10.0,
    this.currentCategories = const [],
    this.openNow = false,
  });

  @override
  State<MapFilterBottomSheet> createState() => _MapFilterBottomSheetState();
}

class _MapFilterBottomSheetState extends State<MapFilterBottomSheet> {
  late double _distance;
  late bool _openNow;
  final List<String> _selectedCategories = [];
  
  final List<String> _allCategories = [
    'Teknoloji', 'Giyim', 'Restoran', 'Market', 
    'Kozmetik', 'Kitap', 'Oyuncak', 'Tamir'
  ];

  @override
  void initState() {
    super.initState();
    _distance = widget.currentDistance;
    _openNow = widget.openNow;
    _selectedCategories.addAll(widget.currentCategories);
  }

  @override
  Widget build(BuildContext context) {
    // Determine status message and color based on distance
    final bool isNear = _distance <= 30;
    final String statusMessage = isNear
        ? 'Yakın lokasyon alışverişi yapabilirsiniz'
        : 'Yakın lokasyon alışverişi yapamazsınız';
    final Color statusColor = isNear ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                'Harita Filtrele',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 30),

          // Distance Slider Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bölgesel Uzaklık',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_distance.round()} km',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _distance,
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: AppColors.primary,
            label: '${_distance.round()} km',
            onChanged: (value) {
              setState(() {
                _distance = value;
              });
            },
          ),
          
          // Distance Warning Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isNear ? Icons.check_circle_outline : Icons.error_outline,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Categories Section
          const Text(
            'Kategoriler',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
                backgroundColor: Colors.grey[100],
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 1,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Open Now Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sadece Açık Olanlar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _openNow,
                activeThumbColor: AppColors.primary,
                onChanged: (value) {
                  setState(() {
                    _openNow = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply({
                  'distance': _distance,
                  'categories': _selectedCategories,
                  'openNow': _openNow,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Filtreleri Uygula',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
