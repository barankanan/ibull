import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // Scroll behavior için eklendi
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:carousel_slider/carousel_slider.dart';
import '../core/constants.dart';
import '../core/catalog_image_priority.dart';
import '../features/products/helpers/product_filter_engine.dart';
import '../features/products/helpers/product_quick_filter_chip_groups.dart';
import '../features/products/helpers/category_filter_config.dart';
import '../features/products/models/product_filter_models.dart';
import '../features/products/widgets/product_filter_bottom_sheet.dart';
import '../features/products/widgets/product_quick_filter_bottom_sheet.dart';
import '../features/products/widgets/product_filter_sidebar.dart';
import '../features/products/widgets/product_sort_bottom_sheet.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import '../widgets/product_card.dart';
import '../widgets/ibul_page_state.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/custom_header.dart';
import '../widgets/address_bar.dart';
import '../utils/category_product_filter.dart';
import 'home_lazy_routes.dart';

class CategoryProductsPage extends StatefulWidget {
  final String category;
  final String subCategory;
  final List<Product> products;
  final Map<String, ProductFilterMeta>? productMeta;
  final String? initialNextCursor;

  const CategoryProductsPage({
    super.key,
    required this.category,
    required this.subCategory,
    required this.products,
    this.productMeta,
    this.initialNextCursor,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage>
    with SingleTickerProviderStateMixin {
  static const int _remotePageSize = 24;

  late TabController _tabController;
  final ScrollController _todayProductsScrollController = ScrollController();
  final ScrollController _productGridScrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Product> _baseProducts = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoadingFilters = false;
  bool _isLoadingMore = false;
  bool _remotePaginationEnabled = false;
  String? _nextCursor;
  int _remoteLoadRequestId = 0;
  Map<String, ProductFilterMeta> _productMetaById = {};
  Timer? _searchDebounce;
  List<ProductFilterGroup> _filterGroups = const <ProductFilterGroup>[];
  ProductFilterState _filterState = const ProductFilterState();

  // Yemek kategorileri - 12 adet
  final List<Map<String, dynamic>> _foodCategories = [
    {'name': 'Tavuk', 'icon': '🍗'},
    {'name': 'Et', 'icon': '🥩'},
    {'name': 'Ev Yemekleri', 'icon': '🏠'},
    {'name': 'Pide - Lahmacun', 'icon': '🫓'},
    {'name': 'Kahve', 'icon': '☕'},
    {'name': 'Çiğ Köfte', 'icon': '🌯'},
    {'name': 'Tatlı - Pasta', 'icon': '🍰'},
    {'name': 'Pilav', 'icon': '🍚'},
    {'name': 'Burger - pizza', 'icon': '🍔'},
    {'name': 'Börek', 'icon': '🥟'},
    {'name': 'Salata - Diyet', 'icon': '🥗'},
    {'name': 'Dondurma', 'icon': '🍦'},
  ];

  final List<String> _allowedSubCategories = [
    'Telefon',
    'Telefonlar',
    'Akıllı Telefonlar',
  ];

  String _productRevealToken(Product product) {
    final productId = product.productId?.trim();
    if (productId != null && productId.isNotEmpty) {
      return productId;
    }

    final store = product.store?.trim() ?? '';
    return '${product.name.trim()}|$store';
  }

  Widget _wrapCategoryProductReveal({
    required String scope,
    required int index,
    required Product product,
    required Widget child,
  }) {
    return StaggeredReveal(
      revealId:
          'category|${widget.category}|${widget.subCategory}|$scope|${_productRevealToken(product)}',
      index: index,
      enabled: index < 8,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // Menüler sekmesine geçildiğinde ürünleri yeniden yükle
          if (_tabController.index == 0 && _filteredProducts.isEmpty) {
            _filteredProducts = _getDisplayProducts();
          }
        });
      }
    });

    _baseProducts = _getDisplayProducts();
    _filteredProducts = List<Product>.from(_baseProducts);
    _productMetaById = Map<String, ProductFilterMeta>.from(
      widget.productMeta ?? const {},
    );
    _remotePaginationEnabled = !CategoryFilterConfig.isFoodCategory(widget.category);
    _nextCursor = widget.initialNextCursor;
    _productGridScrollController.addListener(_onProductGridScroll);
    _filterGroups = ProductFilterEngine.buildFilterGroups(
      products: _baseProducts,
      mainCategory: widget.category,
      subCategory: widget.subCategory,
    );
    if (CategoryFilterConfig.shouldLoadDbAttributeGroups(
      mainCategory: widget.category,
      subCategory: widget.subCategory,
    )) {
      _loadFilterGroups();
    }
  }

  Product _productFromDb(DBProduct dbProduct) {
    List<String> images = [];
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        if (dbProduct.imageUrl.isNotEmpty) {
          images.add(dbProduct.imageUrl);
        }
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }

    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags
          .split('|')
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return Product(
      productId: dbProduct.id,
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
      variantOptions: dbProduct.variantOptions,
      attributes: _parseAttributes(dbProduct.attributes),
    );
  }

  List<String>? _parseAttributes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      try {
        final decoded = json.decode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return trimmed
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _onProductGridScroll() {
    if (!_remotePaginationEnabled || _isLoadingMore || _nextCursor == null) {
      return;
    }
    if (_searchQuery.isNotEmpty || _filterState.hasActiveFilters) {
      return;
    }
    final position = _productGridScrollController.position;
    if (position.pixels < position.maxScrollExtent - 480) {
      return;
    }
    unawaited(_loadMoreRemoteProducts());
  }

  Future<void> _loadMoreRemoteProducts() async {
    final cursor = _nextCursor;
    if (!_remotePaginationEnabled ||
        _isLoadingMore ||
        cursor == null ||
        _searchQuery.isNotEmpty ||
        _filterState.hasActiveFilters) {
      return;
    }

    final requestId = ++_remoteLoadRequestId;
    if (!mounted) return;
    setState(() => _isLoadingMore = true);

    try {
      final page = await _dbHelper
          .getCategoryProductsPaged(
            category: widget.category,
            subCategory: CategoryProductFilter.isAllSubCategory(
              widget.subCategory,
            )
                ? null
                : widget.subCategory,
            limit: _remotePageSize,
            cursor: cursor,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted || requestId != _remoteLoadRequestId) return;

      final newProducts = page.items
          .map(_productFromDb)
          .where(
            (product) => CategoryProductFilter.productMatchesSelection(
              mainCategory: widget.category,
              subCategory: widget.subCategory,
              productMainCategory: product.category,
              productSubCategory: product.subCategory,
              productName: product.name,
            ),
          )
          .toList(growable: false);

      setState(() {
        _nextCursor = page.nextCursor;
        _baseProducts = [..._baseProducts, ...newProducts];
        for (final item in page.items) {
          final id = item.id?.trim();
          if (id == null || id.isEmpty) continue;
          _productMetaById[id] = ProductFilterMeta(stock: item.stock);
        }
        _filteredProducts = ProductFilterEngine.resolveProducts(
          products: _baseProducts,
          state: _filterState,
          metaByProductId: _productMetaById,
          searchQuery: _searchQuery,
        );
      });
    } catch (e) {
      debugPrint('Kategori sayfalama hatası: $e');
    } finally {
      if (mounted && requestId == _remoteLoadRequestId) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  List<Product> _getDisplayProducts() {
    if (widget.products.isNotEmpty) {
      final filtered = widget.products.where((product) {
        return CategoryProductFilter.productMatchesSelection(
          mainCategory: widget.category,
          subCategory: widget.subCategory,
          productMainCategory: product.category,
          productSubCategory: product.subCategory,
          productName: product.name,
        );
      }).toList();

      return filtered;
    }

    if (widget.subCategory == 'Yemek' && kDebugMode) {
      return _createSampleFoodProducts();
    }

    return [];
  }

  List<Product> _createSampleFoodProducts() {
    return [
      Product(
        name: 'Hatay Usulü Tavuk Dürüm',
        brand: 'ABDO DÖNER',
        price: '53,90 TL',
        rating: 4.5,
        reviewCount: 120,
        tags: ['Yemek', 'Döner', 'Tavuk'],
        category: 'Yakın Lokasyon',
        subCategory: 'Yemek',
        store: 'ABDO DÖNER',
        images: ['assets/products/doner1.jpg'],
        description: 'Ekmek Arası Döner + Ayran (18 cl.)',
      ),
      Product(
        name: 'Bol Malzemos Döner',
        brand: 'Baran DÖNER',
        price: '93,90 TL',
        rating: 4.7,
        reviewCount: 85,
        tags: ['Yemek', 'Döner'],
        category: 'Yakın Lokasyon',
        subCategory: 'Yemek',
        store: 'Baran DÖNER',
        images: ['assets/products/doner2.jpg'],
        description: 'Ekmek Arası Döner + Ayran (18 cl.)',
      ),
      Product(
        name: 'Çıtır Tavuk Tabağı',
        brand: 'CİA DÖNER',
        price: '63,90 TL',
        rating: 4.3,
        reviewCount: 95,
        tags: ['Yemek', 'Tavuk'],
        category: 'Yakın Lokasyon',
        subCategory: 'Yemek',
        store: 'CİA DÖNER',
        images: ['assets/products/tavuk.jpg'],
        description: 'Ekmek Arası Döner + Ayran (18 cl.)',
      ),
      Product(
        name: 'Bol Salatalı Döner',
        brand: '2001 DÖNER',
        price: '88,90 TL',
        rating: 4.6,
        reviewCount: 110,
        tags: ['Yemek', 'Döner', 'Salata'],
        category: 'Yakın Lokasyon',
        subCategory: 'Yemek',
        store: '2001 DÖNER',
        images: ['assets/products/wrap.jpg'],
        description: 'Ekmek Arası Döner + Ayran (18 cl.)',
      ),
      Product(
        name: 'Özel soslu döner',
        brand: 'MISIRLI DÖNER',
        price: '73,90 TL',
        rating: 4.4,
        reviewCount: 75,
        tags: ['Yemek', 'Döner'],
        category: 'Yakın Lokasyon',
        subCategory: 'Yemek',
        store: 'MISIRLI DÖNER',
        images: ['assets/products/doner3.jpg'],
        description: 'Ekmek Arası Döner + Ayran (18 cl.)',
      ),
    ];
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _todayProductsScrollController.dispose();
    _productGridScrollController.removeListener(_onProductGridScroll);
    _productGridScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterGroups() async {
    if (!mounted ||
        !CategoryFilterConfig.shouldLoadDbAttributeGroups(
          mainCategory: widget.category,
          subCategory: widget.subCategory,
        )) {
      return;
    }

    setState(() => _isLoadingFilters = true);

    try {
      final dbGroups = await ProductFilterEngine.loadDbAttributeGroups(
        mainCategory: widget.category,
        subCategory: widget.subCategory,
        products: _baseProducts,
      );
      if (!mounted) return;
      final groups = ProductFilterEngine.buildFilterGroups(
        products: _baseProducts,
        mainCategory: widget.category,
        subCategory: widget.subCategory,
        dbAttributeGroups: dbGroups,
      );
      setState(() {
        _filterGroups = groups;
      });
      _refreshProducts();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _filterGroups = ProductFilterEngine.buildFilterGroups(
          products: _baseProducts,
          mainCategory: widget.category,
          subCategory: widget.subCategory,
        );
      });
      _refreshProducts();
    } finally {
      if (mounted) {
        setState(() => _isLoadingFilters = false);
      }
    }
  }

  void _refreshProducts() {
    if (CategoryFilterConfig.isFoodCategory(widget.category)) return;
    setState(() {
      _filteredProducts = ProductFilterEngine.resolveProducts(
        products: _baseProducts,
        state: _filterState,
        metaByProductId: _productMetaById,
        searchQuery: _searchQuery,
      );
    });
  }

  void _updateFilterState(ProductFilterState next) {
    setState(() => _filterState = next);
    _refreshProducts();
  }

  void _clearFilters() {
    _updateFilterState(
      ProductFilterState.cleared(sortOption: _filterState.sortOption),
    );
  }

  Future<void> _openSortSheet() async {
    await ProductSortBottomSheet.show(
      context: context,
      initialSort: _filterState.sortOption,
      onApply: (sortOption) {
        _updateFilterState(_filterState.copyWith(sortOption: sortOption));
      },
    );
  }

  Future<void> _openQuickFilterSheet(ProductFilterGroup group) async {
    if (!mounted) return;
    await ProductQuickFilterBottomSheet.show(
      context: context,
      group: group,
      currentState: _filterState,
      baseProducts: _baseProducts,
      productMeta: _productMetaById,
      searchQuery: _searchQuery,
      onApply: _updateFilterState,
    );
  }

  List<ProductFilterGroup> _quickChipGroups() {
    return ProductQuickFilterChipGroups.resolve(
      _filterGroups,
      mainCategory: widget.category,
    );
  }

  /// Hızlı chip'ler ekrana basılmadan hemen önce tekilleştirilir.
  List<ProductFilterGroup> _finalQuickChipGroupsForRender() {
    final candidates = _quickChipGroups();
    final deduped = <String, ProductFilterGroup>{};

    for (final group in candidates) {
      deduped.putIfAbsent(
        ProductQuickFilterChipGroups.quickFilterCanonicalKey(group),
        () => group,
      );
    }

    return ProductQuickFilterChipGroups.dedupeForRender(
      deduped.values.toList(growable: false),
    );
  }

  bool _isQuickChipActive(ProductFilterGroup group) {
    switch (group.type) {
      case ProductFilterGroupType.brand:
        return _filterState.selectedBrands.isNotEmpty;
      case ProductFilterGroupType.priceRange:
        return _filterState.priceMin != null || _filterState.priceMax != null;
      case ProductFilterGroupType.discount:
        return _filterState.onlyDiscounted;
      case ProductFilterGroupType.stock:
        return _filterState.onlyInStock;
      case ProductFilterGroupType.dynamicAttribute:
        return (_filterState.selectedDynamicAttributes[group.title]?.isNotEmpty ??
            false);
      default:
        return false;
    }
  }

  String _quickChipLabel(ProductFilterGroup group) {
    final baseLabel = ProductQuickFilterChipGroups.quickChipDisplayLabel(group);
    final foodLabel = CategoryFilterConfig.quickChipLabel(
      mainCategory: widget.category,
      group: group,
      defaultLabel: baseLabel,
    );
    if (foodLabel != baseLabel) return foodLabel;
    switch (group.type) {
      case ProductFilterGroupType.dynamicAttribute:
        final count =
            _filterState.selectedDynamicAttributes[group.title]?.length ?? 0;
        return count > 0 ? '$baseLabel ($count)' : baseLabel;
      case ProductFilterGroupType.brand:
        final count = _filterState.selectedBrands.length;
        return count > 0 ? '$baseLabel ($count)' : baseLabel;
      case ProductFilterGroupType.priceRange:
        return 'Fiyat';
      case ProductFilterGroupType.discount:
        return 'İndirim';
      default:
        return baseLabel;
    }
  }

  Future<void> _openFilterSheet() async {
    if (!mounted) return;

    await ProductFilterBottomSheet.show(
      context: context,
      groups: _filterGroups,
      initialState: _filterState,
      previewCount: (draft) => ProductFilterEngine.resolveProducts(
        products: _baseProducts,
        state: draft,
        metaByProductId: _productMetaById,
        searchQuery: _searchQuery,
      ).length,
      onApply: _updateFilterState,
    );
  }

  void _onSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _searchQuery = query.trim();
      if (widget.subCategory == 'Yemek') {
        setState(() {
          if (_searchQuery.isEmpty) {
            _filteredProducts = _getDisplayProducts();
          } else {
            final normalized = _searchQuery.toLowerCase();
            final baseProducts = _getDisplayProducts();
            _filteredProducts = baseProducts.where((p) {
              return p.name.toLowerCase().contains(normalized) ||
                  p.brand.toLowerCase().contains(normalized);
            }).toList();
          }
        });
        return;
      }
      _applyAllFilters();
    });
  }

  void _applyAllFilters() {
    _refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    // Eğer Yemek kategorisi ise özel tasarım
    if (widget.subCategory == 'Yemek') {
      return _buildFoodPage();
    }

    // Diğer kategoriler için varsayılan tasarım
    return _buildDefaultPage();
  }

  Widget _buildFoodPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header with Search
            CustomHeader(onSearch: _onSearch),

            // Ana içerik
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address Bar
                    const AddressBar(),

                    const SizedBox(height: 8),

                    // Banner Carousel (Ana sayfadaki gibi)
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 110,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 4),
                        autoPlayAnimationDuration: const Duration(
                          milliseconds: 800,
                        ),
                        enlargeCenterPage: true,
                        viewportFraction: 0.9,
                        aspectRatio: 2.5,
                      ),
                      items: ['assets/images/food_banner.png'].map((imagePath) {
                        return Builder(
                          builder: (BuildContext context) {
                            return Container(
                              width: MediaQuery.of(context).size.width,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.red.shade400,
                                  ],
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange.shade400,
                                            Colors.red.shade400,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.restaurant,
                                              size: 48,
                                              color: Colors.white,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Özel KORE YEMEKLERİ',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'YENİLENMİŞ MENÜYLE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              'SİZLERİ BEKLİYOR',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Yemekler Başlığı
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Yemekler',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Yemek Kategorileri Grid (4 sütun, 3 satır = 12 kare)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: _foodCategories.length,
                        itemBuilder: (context, index) {
                          final category = _foodCategories[index];

                          return GestureDetector(
                            onTap: () {
                              // Kategori filtreleme devre dışı - her zaman tüm ürünler gösterilsin
                              // _filterByCategory(category['name']);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 65,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      category['icon'],
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category['name'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tab Bar (Menüler, Dükkanlar, İçecekler)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _buildTabButton('Menüler', 0)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTabButton('Dükkanlar', 1)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTabButton('İçecekler', 2)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tab içerikleri
                    if (_tabController.index == 0) ...[
                      // Menüler - Yemek Listesi
                      _filteredProducts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Henüz yemek eklenmemiş',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return _buildFoodItem(product);
                              },
                            ),
                    ] else if (_tabController.index == 1) ...[
                      // Dükkanlar
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.store,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Dükkanlar yakında eklenecek',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // İçecekler
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_drink,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'İçecekler yakında eklenecek',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _tabController.index == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItem(Product product) {
    // Rastgele restoran isimleri
    final restaurants = [
      'ABDO DÖNER',
      'Baran DÖNER',
      'CİA DÖNER',
      '2001 DÖNER',
      'MISIRLI DÖNER',
    ];
    final randomRestaurant =
        restaurants[product.name.hashCode % restaurants.length];
    final deliveryTime = [
      '25Dk',
      '25Dk',
      '15Dk',
      '55Dk',
      '5Dk',
    ][product.name.hashCode % 5];
    final minPrice = [
      'Min 140',
      'Min 140',
      'Min 140',
      'Min 140',
      'Min 140',
    ][product.name.hashCode % 5];
    final distance = [
      '25 KM',
      '25 KM',
      '30 KM',
      '65 KM',
      '2 KM',
    ][product.name.hashCode % 5];
    final oldPrice = [
      '58,00 TL',
      '69,00 TL',
      '68,00 TL',
      '68,00 TL',
      '68,00 TL',
    ][product.name.hashCode % 5];

    return GestureDetector(
      onTap: () {
        HomeLazyRoutes.openProductDetail(context, product);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol taraf: Ürün Bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ürün Adı
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Açıklama
                  Text(
                    'Ekmek Arası Döner + Ayran (18 cl.)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Restoran adı
                  Text(
                    randomRestaurant,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Teslimat bilgisi
                  Row(
                    children: [
                      Icon(
                        Icons.two_wheeler,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$deliveryTime - $minPrice',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fiyat satırı
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // İndirim ikonu
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.label,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Eski fiyat (üstü çizili)
                      Text(
                        oldPrice,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Yeni fiyat
                      Text(
                        product.price,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Sağ taraf: Ürün Görseli
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.images.isNotEmpty
                  ? Image.asset(
                      product.images[0],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Diğer kategoriler için varsayılan sayfa
  Widget _buildDefaultPage() {
    // "Bugün Kapında" ürünlerini filtrele (Hızlı Teslimat, Hızlı Kargo, Yakın Lokasyon)
    final sameDayProducts = _filteredProducts
        .where(
          (p) =>
              p.tags.contains('Hızlı Teslimat') ||
              p.tags.contains('Hızlı Kargo') ||
              p.tags.contains('Yakın Lokasyon'),
        )
        .take(10)
        .toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.subCategory,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_filteredProducts.length}+ Ürün',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Desktop Header / Breadcrumb
          if (isWeb)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '${widget.category} > ${widget.subCategory}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredProducts.length} ürün bulundu',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  // Dropdown or button for sort
                  DropdownButton<ProductSortOption>(
                    value: _filterState.sortOption,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.sort, size: 20),
                    items: ProductSortOption.values.map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(opt == ProductSortOption.recommended ? 'Sıralama' : opt.label, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _updateFilterState(_filterState.copyWith(sortOption: val));
                      }
                    },
                  ),
                ],
              ),
            ),
            
          if (!isWeb) ...[
            // Mobil: Sıralama ve Filtreleme Alanı
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // Sıralama
                  Expanded(
                    child: InkWell(
                      onTap: _openSortSheet,
                      child: Row(
                        children: [
                          const Icon(Icons.sort, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _filterState.sortOption == ProductSortOption.recommended
                                  ? 'Sıralama'
                                  : _filterState.sortOption.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Dikey Ayırıcı
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  // Filtrele
                  Expanded(
                    child: InkWell(
                      onTap: _openFilterSheet,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_filterState.activeFilterCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _filterState.activeFilterCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Text(
                            'Filtrele',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.filter_list, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
  
            // Mobil: Yatay Filtreler (Modeller, Renk, Fiyat, Hızlı Teslimat)
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: _buildQuickFilterChips(),
              ),
            ),
          ],

          // "Bugün Kapında" Alanı
          if (sameDayProducts.isNotEmpty &&
              _allowedSubCategories.contains(widget.subCategory))
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE3F2FD), // Light Blue
                    Colors.white,
                    const Color(0xFFBBDEFB), // Blue 100
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bugün Kapında',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          Text(
                            'Yakın Lokasyon ile çevrendeki mağazalardan alışveriş yapabilirsin',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Hızlı Teslimat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Yatay Liste
                  SizedBox(
                    height: 460,
                    child: Stack(
                      children: [
                        ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: ListView.separated(
                            controller: _todayProductsScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: sameDayProducts.length > 10
                                ? 10
                                : sameDayProducts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 20),
                            itemBuilder: (context, index) {
                              final product = sameDayProducts[index];
                              return SizedBox(
                                width: 220,
                                child: _wrapCategoryProductReveal(
                                  scope: 'same-day-rail',
                                  index: index,
                                  product: product,
                                  child: ProductCard(
                                    product: product,
                                    imagePriority:
                                        CatalogImagePriority.forRailIndex(
                                      index,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Sol Ok
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  _todayProductsScrollController.animateTo(
                                    _todayProductsScrollController.offset - 300,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                tooltip: 'Sola Kaydır',
                              ),
                            ),
                          ),
                        ),
                        // Sağ Ok
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  _todayProductsScrollController.animateTo(
                                    _todayProductsScrollController.offset + 300,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                tooltip: 'Sağa Kaydır',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Ürün Listesi
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWeb = constraints.maxWidth > 1100;

                Widget content;
                if (_filteredProducts.isEmpty) {
                  content = _buildEmptyFilterState();
                } else {
                  final showLoadMoreFooter = _remotePaginationEnabled &&
                      _searchQuery.isEmpty &&
                      !_filterState.hasActiveFilters &&
                      (_isLoadingMore || _nextCursor != null);
                  final itemCount =
                      _filteredProducts.length + (showLoadMoreFooter ? 1 : 0);

                  if (isWeb) {
                    content = _buildWebProductGrid(itemCount);
                  } else {
                    content = GridView.builder(
                      controller: _productGridScrollController,
                      padding: const EdgeInsets.all(16),
                      cacheExtent: 280,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index >= _filteredProducts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final product = _filteredProducts[index];
                        return _wrapCategoryProductReveal(
                          scope: 'product-grid',
                          index: index,
                          product: product,
                          child: ProductCard(
                            product: product,
                            compact: false,
                            tight: true,
                            imagePriority: CatalogImagePriority.forGridIndex(
                              index,
                              crossAxisCount: 2,
                            ),
                          ),
                        );
                      },
                    );
                  }
                }

                if (isWeb) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 250,
                            height: constraints.maxHeight,
                            child: ProductFilterSidebar(
                              groups: _filterGroups,
                              state: _filterState,
                              onChanged: _updateFilterState,
                              onClear: _clearFilters,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: content),
                        ],
                      ),
                    ),
                  );
                }

                return content;
              },
            ),
          ),
        ],
      ),
    );
  }

  // Same box as the home product rail (home_section_full_rail.dart) so the
  // shared ProductCard resolves the same image area and body layout.
  static const double _webCardWidth = 220;
  static const double _webCardHeight = 348;
  static const double _webCardGap = 12;
  static const double _webGridPadding = 16;

  Widget _buildWebProductGrid(int itemCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(
          _webCardWidth,
          constraints.maxWidth - _webGridPadding * 2,
        );
        final columns = math.max(
          1,
          ((available + _webCardGap) / (_webCardWidth + _webCardGap)).floor(),
        );
        final gridWidth =
            columns * _webCardWidth + (columns - 1) * _webCardGap;
        final rightInset = math.max(0.0, available - gridWidth);

        return GridView.builder(
          controller: _productGridScrollController,
          padding: EdgeInsets.fromLTRB(
            _webGridPadding,
            _webGridPadding,
            _webGridPadding + rightInset,
            _webGridPadding,
          ),
          cacheExtent: _webCardHeight,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: _webCardHeight,
            crossAxisSpacing: _webCardGap,
            mainAxisSpacing: _webCardGap,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= _filteredProducts.length) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final product = _filteredProducts[index];
            return _wrapCategoryProductReveal(
              scope: 'product-grid',
              index: index,
              product: product,
              child: ProductCard(
                product: product,
                width: _webCardWidth,
                margin: EdgeInsets.zero,
                imagePriority: CatalogImagePriority.forGridIndex(
                  index,
                  crossAxisCount: columns,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildQuickFilterChips() {
    if (_isLoadingFilters) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }

    final chipGroups = _finalQuickChipGroupsForRender();
    if (chipGroups.isEmpty) {
      return const [SizedBox.shrink()];
    }

    final items = <Widget>[];
    for (final group in chipGroups) {
      items.add(
        _buildQuickFilterChip(
          group: group,
          label: _quickChipLabel(group),
          isActive: _isQuickChipActive(group),
        ),
      );
      items.add(const SizedBox(width: 8));
    }
    if (items.isNotEmpty) {
      items.removeLast();
    }
    return items;
  }

  Widget _buildEmptyFilterState() {
    final hasFilters = _filterState.hasActiveFilters || _searchQuery.isNotEmpty;
    return IbulPageState.empty(
      icon: Icons.search_off,
      iconSize: 56,
      iconColor: Colors.grey.shade400,
      title: hasFilters
          ? 'Bu filtrelerle ürün bulunamadı'
          : 'Bu kategoride ürün bulunamadı',
      titleSize: 18,
      titleWeight: FontWeight.w600,
      message: hasFilters
          ? 'Filtreleri temizleyerek tekrar deneyebilirsin.'
          : 'Başka bir alt kategori seçmeyi deneyebilirsin.',
      messageColor: Colors.grey.shade600,
      padding: const EdgeInsets.all(32),
      actionLabel: hasFilters ? 'Filtreleri Temizle' : null,
      onAction: hasFilters ? _clearFilters : null,
    );
  }

  Widget _buildQuickFilterChip({
    required ProductFilterGroup group,
    required String label,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: () => _openQuickFilterSheet(group),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.primary : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: isActive ? AppColors.primary : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
