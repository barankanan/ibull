import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../core/app_state.dart';
import '../core/app_motion.dart';
import '../services/auth_service.dart';
import '../services/search_telemetry_service.dart';
import '../services/supabase_service.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/filter_sidebar.dart';
import '../widgets/optimized_image.dart';
import '../widgets/staggered_reveal.dart';
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

class _SearchGridMetrics {
  const _SearchGridMetrics({
    required this.crossAxisCount,
    required this.rowExtent,
  });

  final int crossAxisCount;
  final double rowExtent;
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
  double _lastScrollOffset = 0;
  final Set<String> _prefetchedImageKeys = <String>{};

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

    _prefetchDirectionalImages();

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

  String _productRevealToken(Product product) {
    final productId = product.productId?.trim();
    if (productId != null && productId.isNotEmpty) {
      return productId;
    }

    final store = product.store?.trim() ?? '';
    return '${product.name.trim()}|$store';
  }

  String? _productPrimaryImageUrl(Product product) {
    if (product.images.isNotEmpty && product.images.first.trim().isNotEmpty) {
      return product.images.first.trim();
    }

    final thumb = product.thumbnailPublicUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }

    return null;
  }

  List<Product> _sameDayProducts() {
    return _filteredResults
        .where(
          (p) =>
              p.tags.contains('Hızlı Teslimat') ||
              p.tags.contains('Hızlı Kargo'),
        )
        .take(4)
        .toList(growable: false);
  }

  bool _isWebLayout(BuildContext context) {
    return MediaQuery.of(context).size.width > 900;
  }

  _SearchGridMetrics _gridMetricsForContext(BuildContext context) {
    const webMaxContentWidth = 1400.0;
    const webHorizontalPadding = 24.0;
    const webSidebarWidth = 280.0;
    const webSidebarGap = 24.0;
    const webSpacing = 16.0;
    const webMaxCrossAxisExtent = 250.0;
    const mobileSpacing = 10.0;
    const gridAspectRatio = 0.65;

    final screenWidth = MediaQuery.of(context).size.width;
    if (_isWebLayout(context)) {
      final constrainedWidth = math.min(screenWidth, webMaxContentWidth);
      final rowWidth =
          constrainedWidth -
          (webHorizontalPadding * 2) -
          webSidebarWidth -
          webSidebarGap;
      final safeWidth = math.max(webMaxCrossAxisExtent, rowWidth);
      final crossAxisCount = math.max(
        1,
        ((safeWidth + webSpacing) / (webMaxCrossAxisExtent + webSpacing))
            .ceil(),
      );
      final itemWidth =
          (safeWidth - (crossAxisCount - 1) * webSpacing) / crossAxisCount;

      return _SearchGridMetrics(
        crossAxisCount: crossAxisCount,
        rowExtent: (itemWidth / gridAspectRatio) + webSpacing,
      );
    }

    final safeWidth = math.max(220.0, screenWidth - 24.0);
    final itemWidth = (safeWidth - mobileSpacing) / 2;
    return _SearchGridMetrics(
      crossAxisCount: 2,
      rowExtent: (itemWidth / gridAspectRatio) + 12.0,
    );
  }

  int _aboveTheFoldResultCount(BuildContext context) {
    final metrics = _gridMetricsForContext(context);
    final rows = _isWebLayout(context) ? 2 : 3;
    return math.min(_filteredResults.length, metrics.crossAxisCount * rows);
  }

  (int cacheWidth, int cacheHeight) _searchImageCacheSize(
    BuildContext context,
  ) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final isWeb = _isWebLayout(context);
    final logicalWidth = isWeb ? 198.0 : 188.0;
    final logicalHeight = isWeb ? 155.0 : 145.0;
    return (
      (logicalWidth * dpr).round().clamp(160, 520),
      (logicalHeight * dpr).round().clamp(160, 520),
    );
  }

  void _scheduleInitialImageWarmup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _filteredResults.isEmpty) {
        return;
      }

      final aboveFoldCount = _aboveTheFoldResultCount(context);
      final metrics = _gridMetricsForContext(context);
      final sameDayProducts = _sameDayProducts();
      _prefetchProducts(sameDayProducts);
      _prefetchProductRange(
        start: 0,
        count: aboveFoldCount + (metrics.crossAxisCount * 2),
      );
    });
  }

  void _prefetchDirectionalImages() {
    if (!mounted || !_scrollController.hasClients || _filteredResults.isEmpty) {
      return;
    }

    final position = _scrollController.position;
    final metrics = _gridMetricsForContext(context);
    final viewportRows = math.max(
      1,
      (position.viewportDimension / metrics.rowExtent).ceil(),
    );
    final currentOffset = position.pixels;
    final firstVisibleRow = math.max(
      0,
      (currentOffset / metrics.rowExtent).floor(),
    );
    final firstVisibleIndex = firstVisibleRow * metrics.crossAxisCount;
    final windowItemCount = viewportRows * metrics.crossAxisCount;
    final prefetchItemCount = metrics.crossAxisCount * 2;
    final isScrollingDown = currentOffset >= _lastScrollOffset;

    final start = isScrollingDown
        ? firstVisibleIndex + windowItemCount
        : math.max(0, firstVisibleIndex - prefetchItemCount);

    _prefetchProductRange(start: start, count: prefetchItemCount);
    _lastScrollOffset = currentOffset;
  }

  void _prefetchProductRange({required int start, required int count}) {
    if (_filteredResults.isEmpty || count <= 0) {
      return;
    }

    final safeStart = start.clamp(0, _filteredResults.length);
    final safeEnd = math.min(_filteredResults.length, safeStart + count);
    if (safeStart >= safeEnd) {
      return;
    }

    _prefetchProducts(_filteredResults.sublist(safeStart, safeEnd));
  }

  void _prefetchProducts(Iterable<Product> products) {
    if (!mounted) {
      return;
    }

    final (cacheWidth, cacheHeight) = _searchImageCacheSize(context);
    for (final product in products) {
      final imageUrl = _productPrimaryImageUrl(product);
      if (imageUrl == null || !_prefetchedImageKeys.add(imageUrl)) {
        continue;
      }

      unawaited(
        OptimizedImage.prefetch(
          context: context,
          imageUrlOrPath: imageUrl,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        ),
      );
    }
  }

  Widget _wrapSearchProductReveal({
    required String scope,
    required int index,
    required Product product,
    required Widget child,
  }) {
    return StaggeredReveal(
      revealId:
          'search|${widget.query.trim()}|$scope|${_productRevealToken(product)}',
      index: index,
      enabled: index < 8,
      child: child,
    );
  }

  Future<void> _loadAndSearch({bool loadMore = false}) async {
    final appState = context.read<AppState>();
    if (loadMore) {
      if (_nextCursor == null) return;
      setState(() => _isLoadingMore = true);
    } else {
      _prefetchedImageKeys.clear();
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
      _lastScrollOffset = 0;
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
      } else {
        _scheduleInitialImageWarmup();
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
              price < _activeFilters['minPrice']) {
            return false;
          }
          if (_activeFilters['maxPrice'] != null &&
              price > _activeFilters['maxPrice']) {
            return false;
          }

          if (_activeFilters['brands'] != null &&
              (_activeFilters['brands'] as List).isNotEmpty &&
              !(_activeFilters['brands'] as List).contains(product.brand)) {
            return false;
          }

          if (_activeFilters['minRating'] != null &&
              product.rating < _activeFilters['minRating']) {
            return false;
          }

          if (_activeFilters['freeShipping'] == true &&
              !product.tags.contains('Ücretsiz Kargo')) {
            return false;
          }
          if (_activeFilters['fastShipping'] == true &&
              !product.tags.contains('Hızlı Kargo')) {
            return false;
          }
        }

        return true;
      }).toList();
      _visibleCount = (_filteredResults.length).clamp(0, 20);
    });
    _scheduleInitialImageWarmup();
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
                buildAppPageRoute<void>(
                  builder: (_) => SearchResultsPage(query: q),
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
                buildAppPageRoute<void>(
                  builder: (_) => SearchResultsPage(query: q),
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
    final sameDayProducts = _sameDayProducts();
    final aboveFoldCount = _aboveTheFoldResultCount(context);

    const maxContentWidth = 1400.0;
    const horizontalPadding = 24.0;
    const sidebarWidth = 280.0;
    const sidebarGap = 24.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = constraints.maxWidth > maxContentWidth
            ? (constraints.maxWidth - maxContentWidth) / 2
            : 0.0;

        return Column(
          children: [
            WebHeader(
              initialQuery: widget.query,
              onSearch: (q) {
                // Navigate to new search or update current
                Navigator.pushReplacement(
                  context,
                  buildAppPageRoute<void>(
                    builder: (_) => SearchResultsPage(query: q),
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
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: sideInset + horizontalPadding,
                    ),
                    sliver: SliverCrossAxisGroup(
                      slivers: [
                        SliverConstrainedCrossAxis(
                          maxExtent: sidebarWidth + sidebarGap,
                          sliver: SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(right: sidebarGap),
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
                                      _sidebarSelectedOptions[key]!.remove(
                                        value,
                                      );
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
                          ),
                        ),
                        SliverCrossAxisExpanded(
                          flex: 1,
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              if (sameDayProducts.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _buildWebSameDaySection(
                                    sameDayProducts,
                                  ),
                                ),
                              if (sameDayProducts.isNotEmpty)
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 32),
                                ),
                              SliverToBoxAdapter(
                                child: _buildWebResultsHeader(),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),
                              if (_filteredResults.isEmpty)
                                SliverToBoxAdapter(child: _buildEmptyState())
                              else
                                SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 250,
                                        childAspectRatio: 0.65,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final product = _filteredResults[index];
                                    return _wrapSearchProductReveal(
                                      scope: 'web-results',
                                      index: index,
                                      product: product,
                                      child: ProductCard(
                                        product: product,
                                        compact: false,
                                        margin: EdgeInsets.zero,
                                        imagePriority: index < aboveFoldCount
                                            ? OptimizedImagePriority.high
                                            : OptimizedImagePriority.lazy,
                                      ),
                                    );
                                  }, childCount: _visibleCount),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  const SliverToBoxAdapter(child: WebFooter()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWebResultsHeader() {
    return Row(
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
    );
  }

  Widget _buildWebSameDaySection(List<Product> sameDayProducts) {
    const maxCrossAxisExtent = 250.0;
    const spacing = 16.0;
    const childAspectRatio = 0.65;

    return Container(
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
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount =
                  ((constraints.maxWidth + spacing) /
                          (maxCrossAxisExtent + spacing))
                      .ceil()
                      .clamp(1, sameDayProducts.length);
              final itemWidth =
                  (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                  crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(sameDayProducts.length, (index) {
                  final product = sameDayProducts[index];
                  return SizedBox(
                    width: itemWidth,
                    child: AspectRatio(
                      aspectRatio: childAspectRatio,
                      child: _wrapSearchProductReveal(
                        scope: 'web-same-day',
                        index: index,
                        product: product,
                        child: ProductCard(
                          product: product,
                          compact: false,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
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
                final aboveFoldCount = _aboveTheFoldResultCount(context);
                final product = _filteredResults[index];
                return _wrapSearchProductReveal(
                  scope: 'mobile-results',
                  index: index,
                  product: product,
                  child: ProductCard(
                    product: product,
                    compact: false,
                    tight: true,
                    margin: EdgeInsets.zero,
                    imagePriority: index < aboveFoldCount
                        ? OptimizedImagePriority.high
                        : OptimizedImagePriority.lazy,
                  ),
                );
              },
            ),
    );
  }
}
