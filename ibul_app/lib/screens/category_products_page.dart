import 'package:flutter/gestures.dart'; // Scroll behavior için eklendi
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../core/constants.dart';
import '../models/category_attribute_filter_group.dart';
import '../models/product_model.dart';
import '../services/category_attribute_service.dart';
import '../widgets/product_card.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/custom_header.dart';
import '../widgets/address_bar.dart';
import 'product_detail_page.dart';

class CategoryProductsPage extends StatefulWidget {
  final String category;
  final String subCategory;
  final List<Product> products;

  const CategoryProductsPage({
    super.key,
    required this.category,
    required this.subCategory,
    required this.products,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _todayProductsScrollController = ScrollController();
  final CategoryAttributeService _categoryAttributeService =
      CategoryAttributeService.instance;
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoadingAttributeFilters = false;
  List<CategoryAttributeFilterGroup> _attributeFilterGroups =
      const <CategoryAttributeFilterGroup>[];
  final Map<String, Set<String>> _selectedAttributeFilters =
      <String, Set<String>>{};

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

  String _normalize(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

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

    // Eğer yemek kategorisi ise ve ürün yoksa, örnek yemekler oluştur
    _filteredProducts = _getDisplayProducts();
    if (widget.subCategory != 'Yemek') {
      _loadAttributeFilters();
      _applyAllFilters();
    }

    debugPrint('DEBUG: Toplam ürün sayısı: ${widget.products.length}');
    debugPrint('DEBUG: Filtrelenmiş ürün sayısı: ${_filteredProducts.length}');
  }

  List<Product> _getDisplayProducts() {
    if (widget.products.isNotEmpty) {
      final selectedCategory = _normalize(widget.category);
      final selectedSubCategory = _normalize(widget.subCategory);

      final filtered = widget.products.where((product) {
        final productCategory = _normalize(product.category ?? '');
        final productSubCategory = _normalize(product.subCategory ?? '');

        final categoryMatch = productCategory == selectedCategory;

        if (widget.subCategory == 'HEPSİ') {
          return categoryMatch;
        }

        final subCategoryMatch =
            productSubCategory.isNotEmpty &&
            productSubCategory == selectedSubCategory;

        return categoryMatch && subCategoryMatch;
      }).toList();

      return filtered;
    }

    if (widget.subCategory == 'Yemek') {
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
    _tabController.dispose();
    _todayProductsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAttributeFilters() async {
    if (!mounted || widget.subCategory == 'Yemek') return;

    setState(() {
      _isLoadingAttributeFilters = true;
    });

    try {
      final groups = await _categoryAttributeService
          .buildFilterGroupsForProducts(
            mainCategory: widget.category,
            subCategory: widget.subCategory,
            products: _getDisplayProducts(),
          );
      if (!mounted) return;
      setState(() {
        _attributeFilterGroups = groups;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attributeFilterGroups = const <CategoryAttributeFilterGroup>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAttributeFilters = false;
        });
      }
    }
  }

  void _applyAllFilters() {
    if (widget.subCategory == 'Yemek') return;
    final baseProducts = _getDisplayProducts();
    final filtered = baseProducts.where((product) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final searchMatch =
            product.name.toLowerCase().contains(query) ||
            product.brand.toLowerCase().contains(query);
        if (!searchMatch) return false;
      }

      if (_selectedAttributeFilters.isEmpty) {
        return true;
      }

      final specs = CategoryAttributeService.decodeProductSpecifications(
        product.specifications,
      );
      for (final entry in _selectedAttributeFilters.entries) {
        if (entry.value.isEmpty) continue;
        final currentValue = (specs[entry.key] ?? '').trim();
        if (!entry.value.contains(currentValue)) {
          return false;
        }
      }
      return true;
    }).toList();

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _toggleAttributeFilter(
    String attributeName,
    String value,
    bool selected,
  ) {
    final current = _selectedAttributeFilters.putIfAbsent(
      attributeName,
      () => <String>{},
    );
    if (selected) {
      current.add(value);
    } else {
      current.remove(value);
      if (current.isEmpty) {
        _selectedAttributeFilters.remove(attributeName);
      }
    }
    _applyAllFilters();
  }

  void _clearAttributeFilters() {
    setState(() {
      _selectedAttributeFilters.clear();
    });
    _applyAllFilters();
  }

  void _onSearch(String query) {
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
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
          // Sıralama ve Filtreleme Alanı
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
                    onTap: () {
                      // Sıralama işlemi
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Sıralama',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
                    onTap: () {
                      _openAttributeFiltersSheet();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_selectedAttributeFilters.isNotEmpty) ...[
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
                              _selectedAttributeFilters.values
                                  .fold<int>(
                                    0,
                                    (sum, item) => sum + item.length,
                                  )
                                  .toString(),
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

          // Yatay Filtreler (Modeller, Renk, Fiyat, Hızlı Teslimat)
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
                                  child: ProductCard(product: product),
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

                Widget grid = GridView.builder(
                  padding: const EdgeInsets.all(16),
                  cacheExtent: 900,
                  gridDelegate: isWeb
                      ? const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        )
                      : const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailPage(product: product),
                          ),
                        );
                      },
                      child: _wrapCategoryProductReveal(
                        scope: 'product-grid',
                        index: index,
                        product: product,
                        child: ProductCard(
                          product: product,
                          compact: false,
                          tight: true,
                        ),
                      ),
                    );
                  },
                );

                if (isWeb) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: grid,
                    ),
                  );
                }

                return grid;
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuickFilterChips() {
    if (_isLoadingAttributeFilters) {
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

    if (_attributeFilterGroups.isEmpty) {
      return [_buildQuickFilterChip('Filtre bulunamadı', isActive: false)];
    }

    final items = <Widget>[];
    for (final group in _attributeFilterGroups.take(4)) {
      final selectedCount =
          _selectedAttributeFilters[group.attributeName]?.length ?? 0;
      items.add(
        _buildQuickFilterChip(
          selectedCount > 0
              ? '${group.attributeName} ($selectedCount)'
              : group.attributeName,
          isActive: selectedCount > 0,
        ),
      );
      items.add(const SizedBox(width: 8));
    }
    if (items.isNotEmpty) {
      items.removeLast();
    }
    return items;
  }

  Future<void> _openAttributeFiltersSheet() async {
    if (_attributeFilterGroups.isEmpty || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ozellik Filtreleri',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _clearAttributeFilters();
                              modalSetState(() {});
                            },
                            child: const Text('Temizle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._attributeFilterGroups.map((group) {
                        final selected =
                            _selectedAttributeFilters[group.attributeName] ??
                            <String>{};
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.attributeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: group.values.map((value) {
                                  final isSelected = selected.contains(value);
                                  return FilterChip(
                                    label: Text(value),
                                    selected: isSelected,
                                    onSelected: (next) {
                                      modalSetState(() {
                                        _toggleAttributeFilter(
                                          group.attributeName,
                                          value,
                                          next,
                                        );
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickFilterChip(String label, {bool isActive = false}) {
    return InkWell(
      onTap: _attributeFilterGroups.isEmpty ? null : _openAttributeFiltersSheet,
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
