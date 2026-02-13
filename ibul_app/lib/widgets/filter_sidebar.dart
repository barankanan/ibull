import 'package:flutter/material.dart';
import '../core/constants.dart';

class FilterSidebar extends StatefulWidget {
  final Map<String, List<String>>? filters; // Opsiyonel yapıldı
  final List<String>? categories; // Kategoriler eklendi
  final int selectedCategoryIndex; // Seçili kategori indexi
  final Function(int index)? onCategorySelected; // Kategori seçimi callback
  final RangeValues? priceRange; // Fiyat aralığı
  final Function(RangeValues range)? onPriceRangeChanged; // Fiyat değişimi callback
  final Function(String category, String option, bool isSelected)? onFilterChanged; // Filtre değişimi callback

  const FilterSidebar({
    super.key,
    this.filters,
    this.categories,
    this.selectedCategoryIndex = 0,
    this.onCategorySelected,
    this.priceRange,
    this.onPriceRangeChanged,
    this.onFilterChanged,
  });

  @override
  State<FilterSidebar> createState() => _FilterSidebarState();
}

class _FilterSidebarState extends State<FilterSidebar> {
  // Keep track of expanded sections
  final Map<String, bool> _expandedSections = {};
  // Keep track of selected options
  final Map<String, Set<String>> _selectedOptions = {};
  
  // Price range controllers
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize all sections as expanded by default
    if (widget.filters != null) {
      for (var key in widget.filters!.keys) {
        _expandedSections[key] = true;
      }
    }
    // Kategori ve Fiyat bölümleri de açık olsun
    _expandedSections['Kategoriler'] = true;
    _expandedSections['Fiyat Aralığı'] = true;
    //_expandedSections['İlgili Kategoriler'] = true; // Ensure categories are expanded
  }
  
  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _toggleSection(String title) {
    setState(() {
      _expandedSections[title] = !(_expandedSections[title] ?? true);
    });
  }

  void _toggleOption(String category, String option, bool? value) {
    setState(() {
      if (_selectedOptions[category] == null) {
        _selectedOptions[category] = {};
      }
      
      if (value == true) {
        _selectedOptions[category]!.add(option);
      } else {
        _selectedOptions[category]!.remove(option);
      }
    });
    
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(category, option, value ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtrele',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedOptions.clear();
                      _minPriceController.clear();
                      _maxPriceController.clear();
                    });
                  },
                  icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                  label: const Text('Temizle', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          // Using shrinkWrap: true to let it scroll naturally or take needed height.
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Let parent scroll
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              if (widget.categories != null) _buildCategorySection(),
              if (widget.priceRange != null) _buildPriceSection(),
              if (widget.filters != null) 
                ...widget.filters!.entries.map((entry) {
                  return _buildFilterSection(entry.key, entry.value);
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final title = 'Kategoriler';
    final isExpanded = _expandedSections[title] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleSection(title),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                  size: 20, 
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && widget.categories != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(widget.categories!.length, (index) {
                final category = widget.categories![index];
                final isSelected = widget.selectedCategoryIndex == index;
                
                return InkWell(
                  onTap: () {
                    if (widget.onCategorySelected != null) {
                      widget.onCategorySelected!(index);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppColors.primary : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  Widget _buildPriceSection() {
    final title = 'Fiyat Aralığı';
    final isExpanded = _expandedSections[title] ?? true;
    
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSection(title),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                    size: 20, 
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Min TL',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('-', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Max TL',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, size: 20, color: Colors.white),
                      onPressed: () {
                        // Apply price filter
                        if (widget.onPriceRangeChanged != null) {
                           // Logic to parse and call callback
                        }
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      );
  }

  Widget _buildFilterSection(String title, List<String> options) {
    final isExpanded = _expandedSections[title] ?? true;
    
    // Special handling for Switch options
    if (title == 'Fotoğraflı Yorumlar' || title == 'Videolu Ürünler' || title == 'Kampanyalı Ürünler' || title == 'Kuponlu Ürünler') {
      final option = options.isNotEmpty ? options.first : title; 
      final isSelected = _selectedOptions[title]?.contains(option) ?? false;
      
      return Column(
        children: [
          InkWell(
            onTap: () => _toggleOption(title, option, !isSelected),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isSelected,
                      onChanged: (v) => _toggleOption(title, option, v),
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleSection(title),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                  size: 20, 
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              children: options.map((option) {
                final isSelected = _selectedOptions[title]?.contains(option) ?? false;
                
                // Special handling for Rating
                if (title.contains('Puan')) {
                   return InkWell(
                    onTap: () => _toggleOption(title, option, !isSelected),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (v) => _toggleOption(title, option, v),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (option.contains('Yıldız'))
                            Row(
                              children: [
                                 ...List.generate(int.tryParse(option.split(' ')[0]) ?? 0, (index) => 
                                   const Icon(Icons.star, size: 18, color: Colors.amber)
                                 ),
                                 ...List.generate(5 - (int.tryParse(option.split(' ')[0]) ?? 0), (index) => 
                                   const Icon(Icons.star_border, size: 18, color: Colors.grey)
                                 ),
                                 const SizedBox(width: 6),
                                 if (option.contains('ve Üzeri'))
                                   Text(
                                     've Üzeri', 
                                     style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                   ),
                              ],
                            )
                          else
                            Text(option, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                
                return InkWell(
                  onTap: () => _toggleOption(title, option, !isSelected),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (v) => _toggleOption(title, option, v),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? AppColors.primary : Colors.grey[800],
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
