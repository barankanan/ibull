import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../core/constants.dart';

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

  @override
  void initState() {
    super.initState();
    _filteredResults = widget.results;
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _activeFilters = filters;
      _filteredResults = widget.results.where((product) {
        // Price Filter
        double price = _parsePrice(product.price);
        if (price < filters['minPrice'] || price > filters['maxPrice']) {
          return false;
        }

        // Brand Filter
        if (filters['brands'] != null && 
            (filters['brands'] as List).isNotEmpty && 
            !(filters['brands'] as List).contains(product.brand)) {
          return false;
        }

        // Rating Filter
        if (product.rating < filters['minRating']) {
          return false;
        }

        // Shipping Filters
        if (filters['freeShipping'] == true && !product.tags.contains('Ücretsiz Kargo')) {
          return false;
        }
        if (filters['fastShipping'] == true && !product.tags.contains('Hızlı Kargo')) {
          return false;
        }

        return true;
      }).toList();
    });
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
