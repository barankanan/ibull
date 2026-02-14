import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/filter_sidebar.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../core/constants.dart';
import 'home_screen.dart';

class SearchResultsPage extends StatefulWidget {
  final String query;
  final List<Product> results;

  const SearchResultsPage({super.key, required this.query, required this.results});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late List<Product> _filteredResults;
  Map<String, dynamic> _activeFilters = {};
  
  // Standard Filters for Sidebar
  final Map<String, List<String>> _standardFilters = {
    'Kategori': [
      'Telefon', 'Bilgisayar', 'Elektronik Aksesuarlar', 'Giyim', 'Ayakkabı', 'Ev & Yaşam', 'Süpermarket'
    ],
    'Marka': [
      'Apple', 'Samsung', 'Xiaomi', 'Huawei', 'Sony', 'LG', 'Philips', 'Nike', 'Adidas', 'Puma', 'Zara', 'Mavi'
    ],
    'Avantaj Seç': [
      'Hızlı Kargo', 'İndirimli Ürün', 'Yakın Lokasyon', 'Garantili', 'Kargo Bedava'
    ],
    'Renk': [
      'Kırmızı', 'Mavi', 'Beyaz', 'Siyah', 'Mor', 'Sarı', 'Pembe', 'Yeşil', 'Gri', 'Altın', 'Gümüş'
    ],
    'Fiyat (Aralık Belirleme)': [],
    'Garanti Tipi': [
      'Distribütör Garantili', 'İthalatçı Garantili', 'Satıcı Garantili'
    ],
    'Kozmetik Durumu': [
      'Çok İyi', 'İyi', 'Orta'
    ],
    'Ürün Puanı': [
      '4 Yıldız ve Üzeri', '3 Yıldız ve Üzeri', '2 Yıldız ve Üzeri', '1 Yıldız ve Üzeri'
    ],
    'Fotoğraflı Yorumlar': ['Sadece Fotoğraflı Yorumlar'],
    'Videolu Ürünler': ['Sadece Videolu Ürünler'],
    'Kampanyalı Ürünler': ['Tüm Kampanyalar'],
    'Kuponlu Ürünler': ['Kuponlu Ürünler'],
  };

  // Sidebar state
  final Map<String, Set<String>> _sidebarSelectedOptions = {};
  RangeValues _sidebarPriceRange = const RangeValues(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _filteredResults = widget.results;
  }

  void _filterResults() {
    setState(() {
      _filteredResults = widget.results.where((product) {
        double price = _parsePrice(product.price);

        // 1. Sidebar Price Filter
        if (price < _sidebarPriceRange.start || price > _sidebarPriceRange.end) {
          return false;
        }

        // 2. Sidebar Options Filter
        for (var entry in _sidebarSelectedOptions.entries) {
          if (entry.value.isEmpty) continue;
          final category = entry.key;
          final options = entry.value;

          if (category == 'Kategori') {
            bool match = options.any((opt) => 
              (product.subCategory ?? '').contains(opt) || 
              (product.category ?? '').contains(opt)
            );
            if (!match) return false;
          } else if (category == 'Marka') {
            if (!options.contains(product.brand)) return false;
          } else if (category == 'Renk') {
             bool match = options.any((opt) => 
               (product.variantOptions ?? '').contains(opt) ||
               (product.description ?? '').contains(opt)
             );
             if (!match) return false;
          } else if (category == 'Avantaj Seç') {
             bool match = options.any((opt) => product.tags.contains(opt));
             if (!match) return false;
          } else if (category == 'Garanti Tipi') {
             // Mock check
             return true;
          } else if (category == 'Kozmetik Durumu') {
             // Mock check
             return true;
          } else if (category == 'Ürün Puanı') {
             // "4 Yıldız ve Üzeri" -> extract 4
             bool match = options.any((opt) {
               int minStar = int.tryParse(opt.split(' ')[0]) ?? 0;
               return product.rating >= minStar;
             });
             if (!match) return false;
          }
        }

        // 3. Mobile BottomSheet Filters (_activeFilters)
        if (_activeFilters.isNotEmpty) {
           if (_activeFilters['minPrice'] != null && price < _activeFilters['minPrice']) return false;
           if (_activeFilters['maxPrice'] != null && price > _activeFilters['maxPrice']) return false;
           
           if (_activeFilters['brands'] != null && 
               (_activeFilters['brands'] as List).isNotEmpty && 
               !(_activeFilters['brands'] as List).contains(product.brand)) {
             return false;
           }

           if (_activeFilters['minRating'] != null && product.rating < _activeFilters['minRating']) return false;

           if (_activeFilters['freeShipping'] == true && !product.tags.contains('Ücretsiz Kargo')) return false;
           if (_activeFilters['fastShipping'] == true && !product.tags.contains('Hızlı Kargo')) return false;
        }

        return true;
      }).toList();
    });
  }

  void _applyFilters(Map<String, dynamic> filters) {
    _activeFilters = filters;
    _filterResults();
  }

  double _parsePrice(String priceStr) {
    try {
      String clean = priceStr.replaceAll('TL', '').replaceAll('.', '').replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _showFilterSheet() {
    // Extract available brands
    final brands = widget.results.map((p) => p.brand).toSet().toList();
    
    // Calculate price range
    double minPrice = 0;
    double maxPrice = 100000;
    if (widget.results.isNotEmpty) {
      final prices = widget.results.map((p) => _parsePrice(p.price)).toList();
      prices.sort();
      minPrice = prices.first;
      maxPrice = prices.last;
      // Add some buffer
      maxPrice = (maxPrice * 1.2).ceilToDouble();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        onApply: _applyFilters,
        minPrice: minPrice,
        maxPrice: maxPrice == 0 ? 10000 : maxPrice,
        availableBrands: brands,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check screen size
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isWeb ? _buildWebLayout(context) : _buildMobileLayout(context),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    // Filter products for "Bugün Kapında" (mock logic: products with "Hızlı Teslimat" tag)
    final sameDayProducts = _filteredResults.where((p) => p.tags.contains('Hızlı Teslimat') || p.tags.contains('Hızlı Kargo')).take(4).toList();

    return Column(
      children: [
        WebHeader(
          initialQuery: widget.query,
          onSearch: (q) {
             // Navigate to new search or update current
             Navigator.pushReplacement(
               context, 
               PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SearchResultsPage(query: q, results: widget.results), // In real app, fetch new results
                  transitionDuration: Duration.zero,
               )
             );
          },
          onCategorySelected: (category) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(initialCategory: category),
              ),
              (route) => false,
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                
                // Main Content
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Sidebar
                          SizedBox(
                            width: 280,
                            child: FilterSidebar(
                              filters: _standardFilters,
                              onFilterChanged: (key, value, isSelected) {
                                setState(() {
                                  if (_sidebarSelectedOptions[key] == null) {
                                    _sidebarSelectedOptions[key] = {};
                                  }
                                  if (isSelected) {
                                    _sidebarSelectedOptions[key]!.add(value);
                                  } else {
                                    _sidebarSelectedOptions[key]!.remove(value);
                                  }
                                  _filterResults();
                                });
                              },
                              onPriceRangeChanged: (range) {
                                setState(() {
                                  _sidebarPriceRange = range;
                                  _filterResults();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // Right Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // "Bugün Kapında" Section
                                if (sameDayProducts.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.local_shipping, color: Colors.blue, size: 24),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Bugün Kapında',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${sameDayProducts.length} ürün',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 250,
                                            childAspectRatio: 0.65,
                                            mainAxisSpacing: 16,
                                            crossAxisSpacing: 16,
                                          ),
                                          itemCount: sameDayProducts.length,
                                          itemBuilder: (context, index) {
                                            return ProductCard(
                                              product: sameDayProducts[index],
                                              compact: false,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],

                                // Header: Title + Sort
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      widget.query.isEmpty ? 'Tüm Ürünler' : widget.query,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: const [
                                          Text('Önerilen Sıralama', style: TextStyle(fontSize: 14)),
                                          SizedBox(width: 8),
                                          Icon(Icons.keyboard_arrow_down, size: 20),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Product Grid
                                _filteredResults.isEmpty 
                                ? _buildEmptyState()
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 250,
                                      childAspectRatio: 0.65,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                    ),
                                    itemCount: _filteredResults.length,
                                    itemBuilder: (context, index) {
                                      return ProductCard(
                                        product: _filteredResults[index],
                                        compact: false,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const WebFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Sonuç bulunamadı',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (_activeFilters.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _activeFilters = {};
                  _filteredResults = widget.results;
                });
              },
              child: const Text('Filtreleri Temizle'),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${widget.query}" için sonuçlar', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (_activeFilters.isNotEmpty)
              Text(
                '${_filteredResults.length} sonuç (Filtrelendi)',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_activeFilters.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterSheet,
            tooltip: 'Filtrele',
          ),
        ],
      ),
      body: _filteredResults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Sonuç bulunamadı',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  if (_activeFilters.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _activeFilters = {};
                          _filteredResults = widget.results;
                        });
                      },
                      child: const Text('Filtreleri Temizle'),
                    ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.48, 
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
              ),
              itemCount: _filteredResults.length,
              itemBuilder: (context, index) {
                return ProductCard(
                  product: _filteredResults[index],
                  compact: true,
                );
              },
            ),
    );
  }
}
