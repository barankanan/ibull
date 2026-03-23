import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../core/app_state.dart';
import '../services/auth_service.dart';
import '../services/search_telemetry_service.dart';
import '../services/supabase_service.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/filter_sidebar.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../core/constants.dart';
import '../utils/text_normalizer.dart';
import 'home_screen.dart';

class SearchResultsPage extends StatefulWidget {
  final String query;

  const SearchResultsPage({super.key, required this.query});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _hasLoggedTelemetry = false;
  String? _nextCursor;

  List<Product> _baseResults = [];
  late List<Product> _filteredResults;
  Map<String, dynamic> _activeFilters = {};
  int _visibleCount = 0;

  // Standard Filters for Sidebar
  final Map<String, List<String>> _standardFilters = {
    'Kategori': [
      'Telefon',
      'Bilgisayar',
      'Elektronik Aksesuarlar',
      'Giyim',
      'Ayakkabı',
      'Ev & Yaşam',
      'Süpermarket',
    ],
    'Marka': [
      'Apple',
      'Samsung',
      'Xiaomi',
      'Huawei',
      'Sony',
      'LG',
      'Philips',
      'Nike',
      'Adidas',
      'Puma',
      'Zara',
      'Mavi',
    ],
    'Avantaj Seç': [
      'Hızlı Kargo',
      'İndirimli Ürün',
      'Yakın Lokasyon',
      'Garantili',
      'Kargo Bedava',
    ],
    'Renk': [
      'Kırmızı',
      'Mavi',
      'Beyaz',
      'Siyah',
      'Mor',
      'Sarı',
      'Pembe',
      'Yeşil',
      'Gri',
      'Altın',
      'Gümüş',
    ],
    'Fiyat (Aralık Belirleme)': [],
    'Garanti Tipi': [
      'Distribütör Garantili',
      'İthalatçı Garantili',
      'Satıcı Garantili',
    ],
    'Kozmetik Durumu': ['Çok İyi', 'İyi', 'Orta'],
    'Ürün Puanı': [
      '4 Yıldız ve Üzeri',
      '3 Yıldız ve Üzeri',
      '2 Yıldız ve Üzeri',
      '1 Yıldız ve Üzeri',
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
    _filteredResults = [];
    _scrollController.addListener(_onScroll);
    _loadAndSearch();
  }

  @override
  void didUpdateWidget(covariant SearchResultsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.trim() != widget.query.trim()) {
      _hasLoggedTelemetry = false;
      _loadAndSearch();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore) return;
    if (!_scrollController.hasClients) return;
    if (_visibleCount >= _filteredResults.length && _nextCursor == null) return;

    final threshold = 300.0;
    if (_scrollController.position.extentAfter < threshold) {
      if (_visibleCount < _filteredResults.length) {
        setState(() {
          _visibleCount = (_visibleCount + 20).clamp(
            0,
            _filteredResults.length,
          );
        });
      } else if (_nextCursor != null) {
        _loadAndSearch(loadMore: true);
      }
    }
  }

  String _normalize(String value) {
    return TextNormalizer.normalize(value);
  }

  List<String> _splitWords(String normalizedText) {
    return normalizedText
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
  }

  bool _isEditDistanceAtMost1(String a, String b) {
    final la = a.length;
    final lb = b.length;
    final diff = (la - lb).abs();
    if (diff > 1) return false;
    if (a == b) return true;

    var i = 0;
    var j = 0;
    var edits = 0;

    while (i < la && j < lb) {
      if (a.codeUnitAt(i) == b.codeUnitAt(j)) {
        i++;
        j++;
        continue;
      }
      edits++;
      if (edits > 1) return false;

      if (la == lb) {
        i++;
        j++;
      } else if (la > lb) {
        i++;
      } else {
        j++;
      }
    }

    if (i < la || j < lb) edits++;
    return edits <= 1;
  }

  bool _tokenMatchesAnyWord(String token, List<String> words) {
    for (final w in words) {
      if (w.contains(token) || token.contains(w)) return true;
      if (token.length >= 4 &&
          w.length >= 4 &&
          _isEditDistanceAtMost1(token, w))
        return true;
    }
    return false;
  }

  Future<void> _loadAndSearch({bool loadMore = false}) async {
    final appState = context.read<AppState>();
    if (loadMore) {
      if (_nextCursor == null) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _baseResults = [];
        _filteredResults = [];
        _visibleCount = 0;
        _nextCursor = null;
        _activeFilters = {};
        _sidebarSelectedOptions.clear();
        _sidebarPriceRange = const RangeValues(0, double.infinity);
      });
    }

    final rawQuery = widget.query.trim();
    final normalizedQuery = _normalize(rawQuery);
    if (normalizedQuery.replaceAll(' ', '').length < 3) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Aramak için en az 3 karakter girin.';
      });
      return;
    }

    try {
      final page = await SupabaseService.instance.searchProductsPaged(
        query: rawQuery,
        limit: 30,
        cursor: loadMore ? _nextCursor : null,
      );
      final matched = page.items
          .map(Product.fromDBProduct)
          .toList(growable: false);

      if (!loadMore && !_hasLoggedTelemetry) {
        _hasLoggedTelemetry = true;
        final deliveryAddress = appState.currentDeliveryAddress;
        final currentUser = _authService.currentUser;
        unawaited(
          SearchTelemetryService.instance.logSearch(
            query: rawQuery,
            source: 'search_results',
            resultCount: matched.length,
            userId: currentUser?.id,
            isRegistered: currentUser != null,
            deliveryAddress: deliveryAddress,
          ),
        );
      }

      setState(() {
        if (loadMore) {
          _baseResults = [..._baseResults, ...matched];
          _filteredResults = [..._filteredResults, ...matched];
        } else {
          _baseResults = matched;
          _filteredResults = matched;
        }
        _nextCursor = page.nextCursor;
        _isLoading = false;
        _isLoadingMore = false;
        _visibleCount = (_filteredResults.length).clamp(0, 20);
      });
      if (_activeFilters.isNotEmpty ||
          _sidebarSelectedOptions.values.any((v) => v.isNotEmpty)) {
        _filterResults();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage =
            'Arama sırasında bir hata oluştu. Lütfen tekrar deneyin.';
      });
    }
  }

  void _filterResults() {
    setState(() {
      _filteredResults = _baseResults.where((product) {
        double price = _parsePrice(product.price);

        // 1. Sidebar Price Filter
        if (price < _sidebarPriceRange.start ||
            price > _sidebarPriceRange.end) {
          return false;
        }

        // 2. Sidebar Options Filter
        for (var entry in _sidebarSelectedOptions.entries) {
          if (entry.value.isEmpty) continue;
          final category = entry.key;
          final options = entry.value;

          if (category == 'Kategori') {
            bool match = options.any(
              (opt) =>
                  (product.subCategory ?? '').contains(opt) ||
                  (product.category ?? '').contains(opt),
            );
            if (!match) return false;
          } else if (category == 'Marka') {
            if (!options.contains(product.brand)) return false;
          } else if (category == 'Renk') {
            bool match = options.any(
              (opt) =>
                  (product.variantOptions ?? '').contains(opt) ||
                  (product.description ?? '').contains(opt),
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
          if (_activeFilters['minPrice'] != null &&
              price < _activeFilters['minPrice'])
            return false;
          if (_activeFilters['maxPrice'] != null &&
              price > _activeFilters['maxPrice'])
            return false;

          if (_activeFilters['brands'] != null &&
              (_activeFilters['brands'] as List).isNotEmpty &&
              !(_activeFilters['brands'] as List).contains(product.brand)) {
            return false;
          }

          if (_activeFilters['minRating'] != null &&
              product.rating < _activeFilters['minRating'])
            return false;

          if (_activeFilters['freeShipping'] == true &&
              !product.tags.contains('Ücretsiz Kargo'))
            return false;
          if (_activeFilters['fastShipping'] == true &&
              !product.tags.contains('Hızlı Kargo'))
            return false;
        }

        return true;
      }).toList();
      _visibleCount = (_filteredResults.length).clamp(0, 20);
    });
  }

  void _applyFilters(Map<String, dynamic> filters) {
    _activeFilters = filters;
    _filterResults();
  }

  double _parsePrice(String priceStr) {
    try {
      String clean = priceStr
          .replaceAll('TL', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return double.tryParse(clean) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _showFilterSheet() {
    // Extract available brands
    final brands = _baseResults.map((p) => p.brand).toSet().toList();

    // Calculate price range
    double minPrice = 0;
    double maxPrice = 100000;
    if (_baseResults.isNotEmpty) {
      final prices = _baseResults.map((p) => _parsePrice(p.price)).toList();
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
    if (_isLoading) {
      return Column(
        children: [
          WebHeader(
            initialQuery: widget.query,
            onSearch: (q) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SearchResultsPage(query: q),
                  transitionDuration: Duration.zero,
                ),
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
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          WebHeader(
            initialQuery: widget.query,
            onSearch: (q) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SearchResultsPage(query: q),
                  transitionDuration: Duration.zero,
                ),
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Filter products for "Bugün Kapında" (mock logic: products with "Hızlı Teslimat" tag)
    final sameDayProducts = _filteredResults
        .where(
          (p) =>
              p.tags.contains('Hızlı Teslimat') ||
              p.tags.contains('Hızlı Kargo'),
        )
        .take(4)
        .toList();

    return Column(
      children: [
        WebHeader(
          initialQuery: widget.query,
          onSearch: (q) {
            // Navigate to new search or update current
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => SearchResultsPage(query: q),
                transitionDuration: Duration.zero,
              ),
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
            controller: _scrollController,
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
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.local_shipping,
                                              color: Colors.blue,
                                              size: 24,
                                            ),
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
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
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
                                              margin: EdgeInsets.zero,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      widget.query.isEmpty
                                          ? 'Tüm Ürünler'
                                          : widget.query,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: const [
                                          Text(
                                            'Önerilen Sıralama',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 20,
                                          ),
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
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 250,
                                              childAspectRatio: 0.65,
                                              mainAxisSpacing: 16,
                                              crossAxisSpacing: 16,
                                            ),
                                        itemCount: _visibleCount,
                                        itemBuilder: (context, index) {
                                          return ProductCard(
                                            product: _filteredResults[index],
                                            compact: false,
                                            margin: EdgeInsets.zero,
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
                  _filteredResults = _baseResults;
                  _visibleCount = (_filteredResults.length).clamp(0, 20);
                });
              },
              child: const Text('Filtreleri Temizle'),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            '"${widget.query}" için sonuçlar',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            '"${widget.query}" için sonuçlar',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.query}" için sonuçlar',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (_activeFilters.isNotEmpty)
              Text(
                '${_filteredResults.length} sonuç (Filtrelendi)',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
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
                          _filteredResults = _baseResults;
                          _visibleCount = (_filteredResults.length).clamp(
                            0,
                            20,
                          );
                        });
                      },
                      child: const Text('Filtreleri Temizle'),
                    ),
                ],
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
              ),
              itemCount: _visibleCount,
              itemBuilder: (context, index) {
                return ProductCard(
                  product: _filteredResults[index],
                  compact: false,
                  tight: true,
                  margin: EdgeInsets.zero,
                );
              },
            ),
    );
  }
}
