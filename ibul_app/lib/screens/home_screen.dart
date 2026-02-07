import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../core/app_state.dart';
import '../widgets/custom_header.dart';
import '../widgets/web_header.dart'; // Web Header eklendi
import '../widgets/web_footer.dart'; // Web Footer eklendi
import '../widgets/address_bar.dart';
import '../widgets/feature_menu.dart';
import '../widgets/product_card.dart';
import '../widgets/brand_section.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/common/custom_error_view.dart';
import '../services/database_helper.dart';
import '../widgets/game/fortune_wheel_dialog.dart';
import 'dart:math' as math;
import 'categories_page.dart'; // Imported CategoriesPage
import 'map_page.dart';
import 'cart_page.dart';
import 'account_page.dart';
import 'search_results_page.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  String _selectedBrand = 'Urban';
  final AppState _appState = AppState();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<DBProduct> _dbProducts = [];
  bool _isLoadingProducts = true;
  String? _errorMessage;
  late AnimationController _spinController;
  bool _hasSpunWheel = false; // Çark çevrildi mi kontrolü
  
  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(); // Sürekli dön

    _selectedIndex = widget.initialIndex;
    _appState.cartCountNotifier.value = _appState.cart.length;
    _loadProducts();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });
    
    try {
      // Veritabanı başlatma ve seed işlemleri
      await _dbHelper.initializeDatabase();
      
      _dbProducts = await _dbHelper.getAllProducts();
      print('✅ ${_dbProducts.length} ürün yüklendi');
      
      // Görseli olan ürün sayısını yazdır
      final withImages = _dbProducts.where((p) => p.imageUrl.isNotEmpty).length;
      print('📸 Görseli olan ürün sayısı: $withImages/${_dbProducts.length}');
      
      // Urban Care ve diğer saç bakım ürünlerinin mağaza bilgilerini yazdır
      final hairCareProducts = _dbProducts.where((p) => p.subCategory == 'Saç Bakımı').toList();
      print('🔍 Saç Bakımı ürünleri (${hairCareProducts.length} adet):');
      for (var p in hairCareProducts) {
        print('  - ${p.name} | Mağaza: ${p.store} | Marka: ${p.brand}');
      }
    } catch (e) {
      print('❌ Ürün yükleme hatası: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Prevent unnecessary rebuild
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onBrandSelected(String brand) {
    if (_selectedBrand == brand) return; // Prevent unnecessary rebuild
    setState(() {
      _selectedBrand = brand;
    });
  }

  List<Product> _gatherAllProducts() {
    // Veritabanındaki tüm ürünleri Product modeline dönüştür
    return _dbProducts.map((dbProduct) => Product.fromDBProduct(dbProduct)).toList();
  }

  void _onSearch(String query) {
    final normalized = query.toLowerCase();
    final results = _gatherAllProducts().where((p) {
      return p.name.toLowerCase().contains(normalized) ||
          p.brand.toLowerCase().contains(normalized);
    }).toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchResultsPage(query: query, results: results),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _buildCartIcon({required bool isActive}) {
    return ValueListenableBuilder<int>(
      valueListenable: _appState.cartCountNotifier,
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Dummy Data for Brand Section
  final Map<String, dynamic> _brandData = {
    'Urban': {
      'logo': 'assets/haircare/urbanlogo.png',
      'adUrls': [
        'assets/haircare/urban reklam 1.png',
        'assets/haircare/urban reklam 2.png',
      ],
      'products': [
        {'name': 'Urban Care Hyaluronic', 'price': '199.90 TL', 'rating': 4.5, 'reviews': 63, 'tags': ['Hızlı Kargo', 'Ücretsiz Kargo'], 'images': ['']},
        {'name': 'Urban Care Argan Oil', 'price': '220.00 TL', 'rating': 4.7, 'reviews': 120, 'tags': ['%30 indirim'], 'images': ['']},
      ]
    },
    'Head & Shoulders': {
      'logo': 'assets/haircare/head&shoulderslogo.png',
      'adUrls': [
        'assets/haircare/head & shoulders reklam 1.png',
        'assets/haircare/head & shoulders reklam 2.png',
      ],
      'products': [
         {'name': 'Head & Shoulders Menthol', 'price': '145.50 TL', 'rating': 4.6, 'reviews': 200, 'tags': ['Hızlı Kargo'], 'images': ['']},
      ]
    },
    'L\'Oreal': {
      'logo': 'assets/haircare/loreal logo.jpeg',
      'adUrls': [
        'assets/haircare/Lorel reklam.png',
      ],
      'products': []
    },
    'Elidor': {
      'logo': 'assets/haircare/elidorlogo.jpeg',
      'adUrls': [
        'assets/haircare/Elidor reklam.png',
      ],
      'products': []
    },
    'Dove': {
      'logo': 'assets/haircare/dove.png',
      'adUrls': [
        'assets/haircare/Dove reklam.png',
      ],
      'products': [
        {'name': 'Dove Beauty Bar', 'price': '50.00 TL', 'rating': 4.8, 'reviews': 500, 'tags': ['Ücretsiz Kargo'], 'images': ['']},
      ]
    },
    'Clear': {
      'logo': 'assets/haircare/clear.jpeg',
      'adUrls': [
        'assets/haircare/clear reklam 1.png',
        'assets/haircare/clear reklam 2.png',
      ],
      'products': [
        {'name': 'Clear Women Clarifying', 'price': '92.50 TL', 'rating': 4.3, 'reviews': 456, 'tags': ['%30 indirim'], 'images': ['']},
      ]
    },
  };

  // Dummy Data for "Baran, sana özel ürünler"
  final List<Product> _specialProducts = [
    Product(
      name: 'City CT-23 2300 W İnfared Tipi Ayaklı Isıtıcı Gri',
      brand: 'Ufo',
      price: '3.890 TL',
      rating: 4.8,
      reviewCount: 62,
      tags: ['Ücretsiz Kargo', '%15 Kupon'],
      images: [''],
      isDigital: false,
    ),
    Product(
      name: 'Solar Plus RT3',
      brand: 'Haylou',
      price: '2.500 TL',
      rating: 3.0,
      reviewCount: 2,
      tags: ['Hızlı Kargo', 'Dijital Ürün'],
      images: [
        '',
        '',
        '',
      ],
      isDigital: true,
      accessories: [
        '',
        '',
        '',
      ],
    ),
    Product(
      name: 'iPhone 12 / 128 GB Kırık ekran yurt içi',
      brand: 'Apple',
      price: '21.999 TL',
      rating: 0.0,
      reviewCount: 1888,
      tags: ['Hızlı Kargo'],
      images: ['https://via.placeholder.com/300x300.png?text=iPhone+12'],
    ),
  ];


  @override
  Widget build(BuildContext context) {
    // Localization initialized check or fallback? 
    // Usually build is called after MaterialApp is set up, so context has localization.
    // But we need to be careful if we are wrapping things. 
    // AppLocalizations.of(context) might return null if context is not under Localizations widget.
    // HomeScreen is under MaterialApp in main.dart, so it should be fine.
    
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildCurrentPage(),
      // Web'de FloatingActionButton'ı gizle
      floatingActionButton: (_selectedIndex == 0 && !_hasSpunWheel && MediaQuery.of(context).size.width < 800)
        ? AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _spinController.value * 2 * math.pi,
                child: child,
              );
            },
            child: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (context) => FortuneWheelDialog(
                    onSpinComplete: () {
                      setState(() {
                        _hasSpunWheel = true;
                      });
                    },
                  ),
                );
              },
              backgroundColor: Colors.white,
              shape: const CircleBorder(side: BorderSide(color: AppColors.primary, width: 2)),
              child: const Icon(Icons.casino, color: AppColors.primary, size: 28),
            ),
          )
        : null,
      // Web'de BottomNavigationBar'ı gizle
      bottomNavigationBar: MediaQuery.of(context).size.width >= 800 
          ? null 
          : Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.primary, // Mor when selected
          unselectedItemColor: Colors.black,    // Black when unselected
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
             BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: l10n?.home ?? 'Ana Sayfa',
            ),
             BottomNavigationBarItem(
              icon: const Icon(Icons.segment), // Icons.list or similar
              label: l10n?.categories ?? 'Kategori',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map), 
              label: 'Harita',
            ),
            BottomNavigationBarItem(
              icon: _buildCartIcon(isActive: false),
              activeIcon: _buildCartIcon(isActive: true),
              label: l10n?.cart ?? 'Sepet',
            ),
             BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: l10n?.profile ?? 'Hesap',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeView();
      case 1:
        return const CategoriesPage();
      case 2:
        return const MapPage();
      case 3:
        return const CartPage();
      case 4:
        return const AccountPage();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    if (_errorMessage != null) {
      return CustomErrorView(
        message: _errorMessage,
        onRetry: _loadProducts,
      );
    }

    final isWeb = MediaQuery.of(context).size.width >= 800;

    return SafeArea(
      child: Column(
        children: [
          // Header: Web için WebHeader, Mobil için CustomHeader
          isWeb 
            ? WebHeader(onSearch: _onSearch)
            : CustomHeader(onSearch: _onSearch),
          
          Expanded(
            child: SingleChildScrollView(
              child: isWeb 
                  ? _buildWebHomeContent() // Web İçeriği
                  : _buildMobileHomeContent(), // Mobil İçerik (Eski)
            ),
          ),
        ],
      ),
    );
  }

  // --- MOBİL GÖRÜNÜM (Eski Kod) ---
  Widget _buildMobileHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AddressBar(),
        const FeatureMenu(),
        const SizedBox(height: 8),
        // Banner Carousel
        CarouselSlider(
          options: CarouselOptions(
            height: 110,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            aspectRatio: 3.25,
          ),
          items: [
            'assets/images/banners/Yakın lokasyon banner.png',
            'assets/images/banners/ürünleri listele banner.png',
            'assets/images/banners/Görsel zeka banner.png',
            'assets/images/banners/ibul premium banner.png',
          ].map((imagePath) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        
        // "Baran, sana özel ürünler" section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Baran, sana özel ürünler',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
              _isLoadingProducts
                  ? SizedBox(
                      height: 400,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => const ProductCardSkeleton(),
                      ),
                    )
                  : _dbProducts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'Henüz ürün yok',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 400,
                          child: Builder(
                            builder: (context) {
                              // Görseli olan ilk 10 ürünü filtrele
                              final productsWithImages = _dbProducts
                                  .where((p) => p.imageUrl.isNotEmpty)
                                  .take(10)
                                  .toList();
                              
                              return ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                cacheExtent: 500,
                                itemCount: productsWithImages.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final dbProduct = productsWithImages[index];
                                  return SizedBox(
                                    width: 200,
                                    child: ProductCard(
                                      product: _convertToProduct(dbProduct),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // "Bakımlı Saçlar" section
        _buildHairCareSection(),
        
        const SizedBox(height: 24),
        
        // "Daha Önce Gezdiklerin" section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daha Önce Gezdiklerin',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
              _isLoadingProducts
                  ? SizedBox(
                      height: 400,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => const ProductCardSkeleton(),
                      ),
                    )
                  : _dbProducts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'Henüz ürün yok',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 400,
                          child: Builder(
                            builder: (context) {
                              // Görseli olan 11-20 arası ürünleri filtrele
                              final productsWithImages = _dbProducts
                                  .where((p) => p.imageUrl.isNotEmpty)
                                  .skip(10)
                                  .take(10)
                                  .toList();
                              
                              return ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                cacheExtent: 500,
                                itemCount: productsWithImages.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final dbProduct = productsWithImages[index];
                                  return SizedBox(
                                    width: 200,
                                    child: ProductCard(
                                      product: _convertToProduct(dbProduct),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),

        const SizedBox(height: 96), // Bottom spacing
      ],
    );
  }

  // --- WEB GÖRÜNÜM (Yeni Tasarım) ---
  Widget _buildWebHomeContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // İçeriği ortala
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. Üst Reklam Banner (Medion)
            Container(
              width: double.infinity,
              height: 60,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Image.asset(
                'assets/images/banners/medion_banner.png', // Bu görseli eklemeniz gerekebilir veya placeholder kullanırız
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF0055FF),
                  child: const Center(
                    child: Text(
                      'MEDION - Güç, Yeniden Tanımlandı',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),

            // 1. Fırsat Kartları (Kare/Yuvarlak İkonlar)
            _buildOpportunityCards(),
            
            const SizedBox(height: 24),

            // 2. İkili Büyük Banner Alanı
            SizedBox(
              height: 240, // Yükseklik 300'den 240'a düşürüldü
              child: Row(
                children: [
                  // Sol: Kampanya Slider (Büyük)
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CarouselSlider(
                        options: CarouselOptions(
                          height: 240, // Yükseklik güncellendi
                          viewportFraction: 1.0,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 5),
                        ),
                        items: [
                          'assets/images/banners/sevgililer_gunu.png',
                          'assets/images/banners/teknoloji_firsatlari.png',
                        ].map((i) {
                          return Builder(
                            builder: (BuildContext context) {
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
                                child: Image.asset(
                                  i, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: Colors.pink.shade100,
                                    child: const Center(child: Text('Kampanya Görseli', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pink))),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // Sağ: Senin İçin Seçtiklerimiz (Reklam + Ürün)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row( // Column yerine Row yapıldı (Yatay yerleşim)
                        children: [
                          // Başlık (Dikey Metin veya küçük alan)
                          Container(
                            width: 40,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.1),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
                            ),
                            child: const Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  'Sizin İçin',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                ),
                              ),
                            ),
                          ),
                          
                          // Ürün Kartı (Örnek)
                          Expanded(
                            child: Center(
                              child: _dbProducts.isNotEmpty 
                                ? Transform.scale(
                                    scale: 0.85, // Kartı biraz küçült
                                    child: ProductCard(
                                      product: _convertToProduct(_dbProducts.first),
                                      width: 160,
                                    ),
                                  )
                                : const CircularProgressIndicator(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // 3. Popüler Ürünler Başlığı
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Popüler Ürünler',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
            ),
            const SizedBox(height: 16),
            
            // 4. Popüler Ürünler Grid
            _dbProducts.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, // Yan yana 5 ürün (Hepsiburada tarzı)
                    childAspectRatio: 0.60,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _dbProducts.length,
                  itemBuilder: (context, index) {
                    final dbProduct = _dbProducts[index];
                    return ProductCard(
                      product: _convertToProduct(dbProduct),
                    );
                  },
                ),
                
            const SizedBox(height: 64),
            
            // 5. Footer
            const WebFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunityCards() {
    final opportunities = [
      {'title': 'Fırsatları Kaçırma', 'color': Colors.pink, 'icon': Icons.flash_on},
      {'title': 'Bu Fiyatlar Kaçmaz', 'color': Colors.red, 'icon': Icons.timer},
      {'title': '7/24 Altın Al', 'color': Colors.amber, 'icon': Icons.monetization_on},
      {'title': 'Teknoloji Ürünleri', 'color': Colors.blue, 'icon': Icons.computer},
      {'title': 'Eskiyi Yenile', 'color': Colors.green, 'icon': Icons.phone_iphone},
      {'title': 'Küçük Ev Aletleri', 'color': Colors.purple, 'icon': Icons.coffee},
      {'title': 'Favori Markalar', 'color': Colors.orange, 'icon': Icons.star},
      {'title': 'Alışverişe Başla', 'color': Colors.teal, 'icon': Icons.shopping_basket},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opportunities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = opportunities[index];
          return Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (item['color'] as Color).withValues(alpha: 0.3)),
                ),
                child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 32),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  item['title'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHairCareSection() {
    final brandData = _brandData[_selectedBrand]!;
    final brandKeys = _brandData.keys.toList();
    
    // Veritabanından seçili markaya ait saç bakımı ürünlerini filtrele
    final brandProducts = _dbProducts.where((p) => 
      p.subCategory == 'Saç Bakımı' && 
      p.brand.contains(_selectedBrand)
    ).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Bakımlı Saçlar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Brand logos - horizontal scroll
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: brandKeys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final brand = brandKeys[index];
              final isSelected = brand == _selectedBrand;
              final brandInfo = _brandData[brand]!;
              
              return GestureDetector(
                onTap: () => _onBrandSelected(brand),
                child: Column(
                  children: [
                    // Brand logo circle
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: brandInfo['logo'] != null && brandInfo['logo'].isNotEmpty
                          ? Image.asset(
                              brandInfo['logo'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    brand.substring(0, 1),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                brand.substring(0, 1),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Brand name
                    Text(
                      brand,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        
        // Brand ad banner - carousel for multiple ads
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildAdSection(brandData),
        ),
        const SizedBox(height: 20),
        
        // Brand products - VERİTABANINDAN
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: brandProducts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'Bu marka için henüz ürün yok',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 400,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: brandProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final dbProduct = brandProducts[index];
                      return SizedBox(
                        width: 200,
                        child: ProductCard(
                          product: _convertToProduct(dbProduct),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAdSection(Map<String, dynamic> brandData) {
    final adUrls = brandData['adUrls'] as List;
    
    if (adUrls.isEmpty) {
      return _buildPlaceholderAd();
    }
    
    if (adUrls.length > 1) {
      return CarouselSlider(
        options: CarouselOptions(
          height: 150,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 3),
          enlargeCenterPage: false,
          viewportFraction: 1.0,
        ),
        items: adUrls.map<Widget>((adUrl) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              adUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderAd();
              },
            ),
          );
        }).toList(),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        adUrls[0],
        width: double.infinity,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderAd();
        },
      ),
    );
  }

  Widget _buildPlaceholderAd() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              '$_selectedBrand Reklam Alanı',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// DBProduct'ı Product modeline dönüştürür
  Product _convertToProduct(DBProduct dbProduct) {
    // Görselleri parse et
    List<String> images = [];
    
    // imageUrls JSON array ise decode et
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
          print('📸 ${dbProduct.name}: ${images.length} görsel yüklendi - ${images.first}');
        }
      } catch (e) {
        print('⚠️ ${dbProduct.name}: JSON decode hatası - $e');
        // JSON decode başarısız olursa imageUrl kullan
        if (dbProduct.imageUrl.isNotEmpty) {
          images.add(dbProduct.imageUrl);
        }
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
      print('📸 ${dbProduct.name}: imageUrl kullanıldı - ${dbProduct.imageUrl}');
    }
    
    // Etiketleri parse et
    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags.split('|').map<String>((e) => e.toString().trim()).toList();
    }

    return Product(
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
      variantOptions: dbProduct.variantOptions,
    );
  }
}
