
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:flutter/gestures.dart'; // Scroll behavior için eklendi
import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../core/app_state.dart';
import '../widgets/custom_header.dart';
import '../widgets/web_header.dart'; // Web Header eklendi
import '../widgets/web_footer.dart'; // Web Footer eklendi
import '../widgets/filter_sidebar.dart'; // Filter Sidebar eklendi
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
  String _selectedTechBrand = 'Apple'; // Teknoloji için seçili marka
  String _selectedCategory = 'Ana Sayfa'; // Seçili kategori
  String? _selectedSubCategory; // Seçili alt kategori
  final AppState _appState = AppState();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<DBProduct> _dbProducts = [];
  bool _isLoadingProducts = true;
  String? _errorMessage;
  late AnimationController _spinController;
  bool _hasSpunWheel = false; // Çark çevrildi mi kontrolü
  final ScrollController _popularProductsScrollController = ScrollController();
  final ScrollController _subCategoryScrollController = ScrollController();

  final Map<String, List<String>> _standardFilters = {
    'Kategori': [
      'Telefon',
      'Bilgisayar',
      'Elektronik Aksesuarlar',
      'Giyim',
      'Ayakkabı',
      'Ev & Yaşam',
      'Süpermarket'
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
      'Mavi'
    ],
    'Avantaj Seç': [
      'Hızlı Kargo',
      'İndirimli Ürün',
      'Yakın Lokasyon',
      'Garantili',
      'Kargo Bedava'
    ],
    'Renk': [
      'Kırmızı', 'Mavi', 'Beyaz', 'Siyah', 'Mor', 'Sarı', 'Pembe', 'Yeşil', 'Gri', 'Altın', 'Gümüş'
    ],
    'Fiyat (Aralık Belirleme)': [], // Special handling in widget
    'Garanti Tipi': [
      'Distribütör Garantili',
      'İthalatçı Garantili',
      'Satıcı Garantili'
    ],
    'Kozmetik Durumu': [
      'Çok İyi',
      'İyi',
      'Orta'
    ],
    'Ürün Puanı': [
      '4 Yıldız ve Üzeri',
      '3 Yıldız ve Üzeri',
      '2 Yıldız ve Üzeri',
      '1 Yıldız ve Üzeri'
    ],
    'Fotoğraflı Yorumlar': ['Sadece Fotoğraflı Yorumlar'],
    'Videolu Ürünler': ['Sadece Videolu Ürünler'],
    'Kampanyalı Ürünler': ['Tüm Kampanyalar'],
    'Kuponlu Ürünler': ['Kuponlu Ürünler'],
  };
  
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
    _popularProductsScrollController.dispose();
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

      // Eğer ürün listesi boşsa dummy veriler ekle (Web testi için)
      // VEYA Web ortamındaysak ve ürünler azsa (test için) dummy ekle
      if (_dbProducts.isEmpty || (MediaQuery.of(context).size.width >= 800 && _dbProducts.length < 5)) {
        print('⚠️ Veritabanı boş veya yetersiz, test verileri yükleniyor...');
        _dbProducts = [
          DBProduct(
            id: 1,
            name: 'Apple iPhone 13 128 GB',
            price: '35.999 TL',
            oldPrice: '38.999 TL',
            imageUrl: '',
            category: 'Elektronik',
            brand: 'Apple',
            description: 'A15 Bionic çip, Süper Retina XDR ekran.',
            rating: 4.8,
            reviewCount: 1250,
            tags: '["Hızlı Kargo", "Ücretsiz Kargo"]',
            subCategory: 'Telefon',
            store: 'Apple Store',
          ),
          DBProduct(
            id: 2,
            name: 'Samsung Galaxy S23 Ultra',
            price: '45.999 TL',
            imageUrl: '',
            category: 'Elektronik',
            brand: 'Samsung',
            description: '200 MP Kamera, S Pen dahil.',
            rating: 4.9,
            reviewCount: 850,
            tags: '["Yeni", "Fırsat"]',
            subCategory: 'Telefon',
            store: 'Samsung TR',
          ),
          DBProduct(
            id: 3,
            name: 'Dyson V15 Detect',
            price: '24.999 TL',
            imageUrl: '',
            category: 'Ev & Yaşam',
            brand: 'Dyson',
            description: 'Lazerli toz tespiti, güçlü emiş.',
            rating: 4.7,
            reviewCount: 3200,
            tags: '["Çok Satan"]',
            subCategory: 'Süpürge',
            store: 'Dyson',
          ),
          DBProduct(
            id: 4,
            name: 'Sony WH-1000XM5',
            price: '12.499 TL',
            oldPrice: '14.999 TL',
            imageUrl: '',
            category: 'Elektronik',
            brand: 'Sony',
            description: 'Gürültü engelleme, 30 saat pil.',
            rating: 4.6,
            reviewCount: 450,
            tags: '["İndirim"]',
            subCategory: 'Kulaklık',
            store: 'Sony Eurasia',
          ),
          DBProduct(
            id: 5,
            name: 'Philips Airfryer XXL',
            price: '8.999 TL',
            imageUrl: '',
            category: 'Mutfak',
            brand: 'Philips',
            description: 'Yağsız pişirme, geniş kapasite.',
            rating: 4.8,
            reviewCount: 5600,
            tags: '["Popüler"]',
            subCategory: 'Küçük Ev Aletleri',
            store: 'Philips',
          ),

          // --- SAÇ BAKIM ÜRÜNLERİ (DUMMY) ---
          
          // Urban Care
          DBProduct(
            id: 101,
            name: 'Urban Care Hyaluronic Acid & Collagen Şampuan',
            price: '199.90 TL',
            oldPrice: '250.00 TL',
            imageUrl: 'assets/haircare/urban_shampoo.png', // Placeholder path
            category: 'Kişisel Bakım',
            brand: 'Urban',
            description: 'Ekstra dolgunlaştırıcı ve nemlendirici bakım şampuanı.',
            rating: 4.5,
            reviewCount: 150,
            tags: '["Hızlı Kargo", "Kuponlu"]',
            subCategory: 'Saç Bakımı',
            store: 'Gratis',
          ),
          DBProduct(
            id: 102,
            name: 'Urban Care Argan Oil Saç Bakım Serumu',
            price: '220.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Urban',
            description: 'Kırılma karşıtı besleyici argan yağı.',
            rating: 4.7,
            reviewCount: 320,
            tags: '["Çok Satan"]',
            subCategory: 'Saç Bakımı',
            store: 'Watsons',
          ),
          DBProduct(
            id: 103,
            name: 'Urban Care Twisted Curls Hibiscus Maske',
            price: '185.50 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Urban',
            description: 'Belirgin bukleler için yoğun bakım maskesi.',
            rating: 4.6,
            reviewCount: 85,
            tags: '["Yeni"]',
            subCategory: 'Saç Bakımı',
            store: 'Rossmann',
          ),

          // Head & Shoulders
          DBProduct(
            id: 104,
            name: 'Head & Shoulders Menthol Ferahlığı',
            price: '145.50 TL',
            oldPrice: '180.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Head & Shoulders',
            description: 'Kepeğe karşı etkili, ferahlatıcı şampuan.',
            rating: 4.8,
            reviewCount: 1200,
            tags: '["Süper Fırsat"]',
            subCategory: 'Saç Bakımı',
            store: 'Migros Sanal Market',
          ),
          DBProduct(
            id: 105,
            name: 'Head & Shoulders Derinlemesine Temiz',
            price: '139.90 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Head & Shoulders',
            description: 'Yağlı saçlar için limon ferahlığı.',
            rating: 4.5,
            reviewCount: 560,
            tags: '["Ekonomik"]',
            subCategory: 'Saç Bakımı',
            store: 'CarrefourSA',
          ),

          // L'Oreal
          DBProduct(
            id: 106,
            name: 'L\'Oreal Paris Elseve Mucizevi Yağ',
            price: '275.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'L\'Oreal',
            description: '6 değerli çiçek özü yağı ile besleyici bakım.',
            rating: 4.9,
            reviewCount: 2400,
            tags: '["Yıldızlı Ürün"]',
            subCategory: 'Saç Bakımı',
            store: 'L\'Oreal Official',
          ),
          DBProduct(
            id: 107,
            name: 'L\'Oreal Paris Excellence Creme Boya',
            price: '160.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'L\'Oreal',
            description: 'Zengin renkler, %100 beyaz kapama.',
            rating: 4.6,
            reviewCount: 980,
            tags: '["İndirim"]',
            subCategory: 'Saç Bakımı',
            store: 'Gratis',
          ),

          // Elidor
          DBProduct(
            id: 108,
            name: 'Elidor Güçlü ve Parlak Şampuan',
            price: '89.90 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Elidor',
            description: 'Nutri-Shine teknolojisi ile güçlü saçlar.',
            rating: 4.4,
            reviewCount: 3500,
            tags: '["Ekonomik Paket"]',
            subCategory: 'Saç Bakımı',
            store: 'Şok Market',
          ),
          DBProduct(
            id: 109,
            name: 'Elidor 7/24 Belirgin Bukleler Krem',
            price: '115.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Elidor',
            description: 'Durulanmayan bakım kremi.',
            rating: 4.7,
            reviewCount: 1800,
            tags: '["Popüler"]',
            subCategory: 'Saç Bakımı',
            store: 'Watsons',
          ),

          // Dove
          DBProduct(
            id: 110,
            name: 'Dove Yoğun Onarıcı Bakım Maskesi',
            price: '155.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Dove',
            description: 'Yıpranmış saçlar için anında onarım.',
            rating: 4.8,
            reviewCount: 650,
            tags: '["Kargo Bedava"]',
            subCategory: 'Saç Bakımı',
            store: 'Gratis',
          ),
          DBProduct(
            id: 111,
            name: 'Dove Avokado Özlü Şampuan',
            price: '95.50 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Dove',
            description: 'Kırılma karşıtı güçlendirici bakım.',
            rating: 4.5,
            reviewCount: 420,
            tags: '["Doğal İçerik"]',
            subCategory: 'Saç Bakımı',
            store: 'Migros Sanal Market',
          ),

          // Clear
          DBProduct(
            id: 112,
            name: 'Clear Women Komple Bakım',
            price: '125.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Clear',
            description: 'Saç derisi bakımı ve kepek önleyici.',
            rating: 4.6,
            reviewCount: 900,
            tags: '["Fırsat"]',
            subCategory: 'Saç Bakımı',
            store: 'CarrefourSA',
          ),
          DBProduct(
            id: 113,
            name: 'Clear Men Cool Sport Menthol',
            price: '130.00 TL',
            imageUrl: '',
            category: 'Kişisel Bakım',
            brand: 'Clear',
            description: 'Erkekler için ferahlatıcı etki.',
            rating: 4.7,
            reviewCount: 1500,
            tags: '["Çok Satan"]',
            subCategory: 'Saç Bakımı',
            store: 'Watsons',
          ),
        ];
      }
      
      // Urban Care ve diğer saç bakım ürünlerinin mağaza bilgilerini yazdır
      final hairCareProducts = _dbProducts.where((p) => p.subCategory == 'Saç Bakımı').toList();
      print('🔍 Saç Bakımı ürünleri (${hairCareProducts.length} adet):');
      for (var p in hairCareProducts) {
        print('  - ${p.name} | Mağaza: ${p.store} | Marka: ${p.brand}');
      }
    } catch (e) {
      print('❌ Ürün yükleme hatası: $e');
      // Hata durumunda bile dummy verileri göster
       _dbProducts = [
          DBProduct(
            id: 1,
            name: 'Apple iPhone 13 128 GB',
            price: '35.999 TL',
            oldPrice: '38.999 TL',
            imageUrl: '',
            category: 'Elektronik',
            brand: 'Apple',
            description: 'A15 Bionic çip, Süper Retina XDR ekran.',
            rating: 4.8,
            reviewCount: 1250,
            tags: '["Hızlı Kargo", "Ücretsiz Kargo"]',
            subCategory: 'Telefon',
            store: 'Apple Store',
          ),
       ];
      setState(() {
        _errorMessage = null; // Hatayı kullanıcıya gösterme, dummy veriyi göster
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

  void _onTechBrandSelected(String brand) {
    if (_selectedTechBrand == brand) return; // Prevent unnecessary rebuild
    setState(() {
      _selectedTechBrand = brand;
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

  // Dummy Data for Tech Brand Section
  final Map<String, dynamic> _techBrandData = {
    'Apple': {
      'logo': 'assets/brands/apple_logo.png', // Placeholder path
      'adUrls': [
        'assets/brands/apple_ad1.png', // Placeholder
        'assets/brands/apple_ad2.png',
      ],
      'products': [] // Veritabanından çekilecek
    },
    'Samsung': {
      'logo': 'assets/brands/samsung_logo.png',
      'adUrls': [
        'assets/brands/samsung_ad1.png',
      ],
      'products': []
    },
    'Dyson': {
      'logo': 'assets/brands/dyson_logo.png',
      'adUrls': [
        'assets/brands/dyson_ad1.png',
      ],
      'products': []
    },
    'Sony': {
      'logo': 'assets/brands/sony_logo.png',
      'adUrls': [
        'assets/brands/sony_ad1.png',
      ],
      'products': []
    },
    'Philips': {
      'logo': 'assets/brands/philips_logo.png',
      'adUrls': [
        'assets/brands/philips_ad1.png',
      ],
      'products': []
    },
  };




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
            ? WebHeader(
                onSearch: _onSearch,
                selectedCategory: _selectedCategory,
                onCategorySelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                    _selectedSubCategory = null; // Reset subcategory when main category changes
                  });
                },
              )
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

  Widget _buildSubCategoryView() {
    // Filter products by selected subcategory if available
    final filteredProducts = _dbProducts.where((p) => p.subCategory == _selectedSubCategory).toList();
    // If no products found for this subcategory (e.g. dummy data missing), show all products for demo purposes
    // or show empty state. For now, let's show all but maybe limiting them, or just show a message.
    // Better to show all for demo so the grid isn't empty, but maybe with a warning?
    // Let's stick to showing all if empty, but prefer filtered.
    final displayProducts = filteredProducts.isNotEmpty ? filteredProducts : _dbProducts;

    // Prepare filters dynamically
    final Map<String, List<String>> displayFilters = {};
    _standardFilters.forEach((key, value) {
      // "Telefonlar" dışındaki kategorilerde "Kategori" ve "Marka" altı boş olsun
      if ((key == 'Kategori' || key == 'Marka') && _selectedSubCategory != 'Telefonlar') {
        displayFilters[key] = [];
      } else {
        displayFilters[key] = value;
      }
    });

    // Debug print
    print('SubCategory: $_selectedSubCategory');
    print('Kategori Options: ${displayFilters['Kategori']?.length}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar
        // Use ConstrainedBox or SizedBox to ensure width, but let height be determined by content
        // Since FilterSidebar now uses shrinkWrap ListView, it will take the height of its content.
        // And since it's in a Row with CrossAxisAlignment.start, it won't stretch vertically unless we tell it to.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 500), // Min height to match grid roughly
          child: FilterSidebar(
            key: ValueKey(_selectedSubCategory), // Force rebuild when subcategory changes
            filters: displayFilters,
            onFilterChanged: (category, option, isSelected) {
              print('Filter changed: $category -> $option : $isSelected');
            },
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Product Grid
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedSubCategory',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text('Önerilen Sıralama', style: TextStyle(fontSize: 14)),
                        Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              displayProducts.isEmpty 
                  ? const Center(child: Text("Bu kategoride ürün bulunamadı.")) 
                  : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: displayProducts.length > 8 ? 8 : displayProducts.length, // Limit for demo
                itemBuilder: (context, index) {
                   return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ProductCard(
                        product: _convertToProduct(displayProducts[index]),
                      ),
                    );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WEB GÖRÜNÜM (Yeni Tasarım) ---
  Widget _buildWebHomeContent() {
    final isElectronics = _selectedCategory == 'Elektronik';
    final isHomePage = _selectedCategory == 'Ana Sayfa';
    final isCategorySelected = !isHomePage; // Herhangi bir kategori seçili mi?

    // Popüler ürünleri kategoriye göre filtrele
    final popularProducts = isHomePage 
        ? _dbProducts 
        : _dbProducts.where((p) => p.category == _selectedCategory || p.category.contains(_selectedCategory)).toList();

    // Banner images
    final bannerImages = [
      'assets/images/banners/teknosa-duyuru-1.png',
      'assets/images/banners/arcelik-duyuru-1.png',
      'assets/images/banners/ibul premium banner.png',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // Increased horizontal padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // KATEGORİ SEÇİLİYSE (Elektronik veya Diğerleri)
            if (isCategorySelected) ...[
              const SizedBox(height: 24),
              
              // 1. Kategoriler (En üstte) - Sadece seçili kategoriye özgü ikonları göster
              _buildOpportunityCards(),
              
              const SizedBox(height: 16),
              
              // 2. Alt Kategori Filtreleme veya Teknoloji Dünyası
              if (_selectedSubCategory != null) ...[
                _buildSubCategoryView(),
              ] else if (isElectronics) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _buildTechSection(),
                ),
              ] else ...[
                 // DİĞER KATEGORİLER İÇİN SADECE ÜRÜN LİSTESİ
                 Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_selectedCategory Ürünleri',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                 popularProducts.isEmpty 
                  ? SizedBox(
                      height: 200, 
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Bu kategoride henüz ürün bulunamadı', style: TextStyle(color: Colors.grey[600])),
                          ],
                        )
                      )
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, // 5 sütunlu grid
                        childAspectRatio: 0.6, // Kart oranı
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: popularProducts.length,
                      itemBuilder: (context, index) {
                        final dbProduct = popularProducts[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ProductCard(
                            product: _convertToProduct(dbProduct),
                          ),
                        );
                      },
                    ),
              ],
              
              const SizedBox(height: 80),
              const WebFooter(),
              
            ] else ...[
              // NORMAL ANA SAYFA GÖRÜNÜMÜ
              
              // 0. Adres Çubuğu
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Teslimat Adresi:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kültür merkezi karşısı',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                      label: const Text('Değiştir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              // 1. Kategoriler / Fırsat İkonları
              _buildOpportunityCards(),
              
              const SizedBox(height: 24),

              // 2. İkili Büyük Banner Alanı
              SizedBox(
                height: 300,
                child: Row(
                  children: [
                    // Sol: Kampanya Slider
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            CarouselSlider(
                              options: CarouselOptions(
                                height: 300,
                                viewportFraction: 1.0,
                                autoPlay: true,
                                autoPlayInterval: const Duration(seconds: 6),
                                autoPlayAnimationDuration: const Duration(milliseconds: 1000),
                              ),
                              items: bannerImages.map((i) {
                                return Builder(
                                  builder: (BuildContext context) {
                                    return Container(
                                      width: MediaQuery.of(context).size.width,
                                      decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
                                      child: Image.asset(
                                        i, 
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Container(
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade400),
                                                const SizedBox(height: 16),
                                                Text('Kampanya Görseli', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Sağ: Günün Fırsatı
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.orange.shade50, Colors.white],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange.shade100),
                                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10)],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                                      child: const Text('Günün Fırsatı', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Center(
                                    child: popularProducts.isNotEmpty 
                                      ? Transform.scale(
                                          scale: 0.8,
                                          child: ProductCard(
                                            product: _convertToProduct(popularProducts.first),
                                            width: 180,
                                          ),
                                        )
                                      : const CircularProgressIndicator(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(16),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/banners/Görsel zeka banner.png'),
                                  fit: BoxFit.cover,
                                  opacity: 0.9,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.bottomLeft,
                                child: const Text(
                                  'Yapay Zeka ile\nAradığını Bul',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
              
              const SizedBox(height: 32),

              // 3. Popüler Ürünler Başlığı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Popüler Ürünler',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Tümünü Gör', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 4. Popüler Ürünler Listesi (Yatay Kaydırılabilir)
              popularProducts.isEmpty 
                ? SizedBox(
                    height: 200, 
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Bu kategoride ürün bulunamadı', style: TextStyle(color: Colors.grey[600])),
                        ],
                      )
                    )
                  )
                : SizedBox(
                    height: 380,
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
                            controller: _popularProductsScrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: popularProducts.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 20),
                            itemBuilder: (context, index) {
                              final dbProduct = popularProducts[index];
                              return SizedBox(
                                width: 220,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ProductCard(
                                    product: _convertToProduct(dbProduct),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Sol Ok
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: AppColors.primary),
                                onPressed: () {
                                  _popularProductsScrollController.animateTo(
                                    _popularProductsScrollController.offset - 300,
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
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 24, color: AppColors.primary),
                                onPressed: () {
                                  _popularProductsScrollController.animateTo(
                                    _popularProductsScrollController.offset + 300,
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
                  
              const SizedBox(height: 40),

              // 5. Markalar ve Bakım Bölümü
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _buildHairCareSection(),
              ),
              const SizedBox(height: 40),

              // 6. Teknoloji Dünyası Bölümü
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _buildTechSection(),
              ),
              
              const SizedBox(height: 80),
              
              // 7. Footer
              const WebFooter(),
            ],
          ],
        ),
      ),
    ),
  );
}

  Product _convertToProduct(DBProduct dbProduct) {
    return Product(
      name: dbProduct.name,
      price: dbProduct.price,
      oldPrice: dbProduct.oldPrice,
      images: [dbProduct.imageUrl],
      category: dbProduct.category,
      brand: dbProduct.brand,
      description: dbProduct.description,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: dbProduct.tags.isNotEmpty ? List<String>.from(json.decode(dbProduct.tags)) : [],
      subCategory: dbProduct.subCategory,
      store: dbProduct.store,
    );
  }

  Widget _buildHairCareSection() {
    return BrandSection(
      title: 'Bakımlı Saçlar',
      selectedBrand: _selectedBrand,
      brands: _brandData.keys.toList(),
      brandData: _brandData,
      onBrandSelected: _onBrandSelected,
    );
  }

  Widget _buildTechSection() {
    return BrandSection(
      title: 'Teknoloji Dünyası',
      selectedBrand: _selectedTechBrand,
      brands: _techBrandData.keys.toList(),
      brandData: _techBrandData,
      onBrandSelected: _onTechBrandSelected,
    );
  }

  Widget _buildOpportunityCards() {
    List<Map<String, dynamic>> opportunities;
    
    // Alt Kategorileri Belirle
    switch (_selectedCategory) {
      case 'Elektronik':
        opportunities = [
          {'icon': Icons.sports_esports, 'title': 'Gaming'},
          {'icon': Icons.phone_iphone, 'title': 'Telefonlar'},
          {'icon': Icons.laptop, 'title': 'Laptop & Tablet'},
          {'icon': Icons.tv, 'title': 'Televizyon'},
          {'icon': Icons.memory, 'title': 'Bilgisayar Bileşenleri'},
          {'icon': Icons.kitchen, 'title': 'Beyaz Eşya'},
          {'icon': Icons.face, 'title': 'Kişisel Bakım'},
          {'icon': Icons.ac_unit, 'title': 'Isıtma & Soğutma'},
          {'icon': Icons.keyboard, 'title': 'Oyuncu Ekipmanları'},
          {'icon': Icons.gamepad, 'title': 'Oyun Konsolları'},
          {'icon': Icons.speaker_group, 'title': 'Sinema & Ses Sistemleri'},
          {'icon': Icons.headphones_battery, 'title': 'Telefon Aksesuarları'},
          {'icon': Icons.watch, 'title': 'Giyilebilir Teknoloji'},
          {'icon': Icons.mouse, 'title': 'Bilgisayar Aksesuarları'},
          {'icon': Icons.speaker, 'title': 'Hoparlör'},
          {'icon': Icons.monitor, 'title': 'Monitör'},
          {'icon': Icons.print, 'title': 'Yazıcı & Tarayıcı'},
        ];
        break;
      case 'Erkek':
        opportunities = [
          {'icon': Icons.checkroom, 'title': 'Giyim'},
          {'icon': Icons.watch, 'title': 'Saat'},
          {'icon': Icons.style, 'title': 'Aksesuar'},
          {'icon': Icons.hiking, 'title': 'Ayakkabı & Çanta'},
          {'icon': Icons.directions_run, 'title': 'Spor & Outdoor'},
          {'icon': Icons.face, 'title': 'Kişisel Bakım'},
          {'icon': Icons.accessibility_new, 'title': 'Büyük Beden'},
        ];
        break;
      case 'Kadın':
        opportunities = [
          {'icon': Icons.checkroom, 'title': 'Giyim'},
          {'icon': Icons.brush, 'title': 'Kozmetik'},
          {'icon': Icons.style, 'title': 'Aksesuar'},
          {'icon': Icons.shopping_bag, 'title': 'Ayakkabı & Çanta'},
          {'icon': Icons.hotel, 'title': 'Ev & İç Giyim'},
          {'icon': Icons.directions_run, 'title': 'Spor & Outdoor'},
          {'icon': Icons.accessibility_new, 'title': 'Büyük Beden'},
        ];
        break;
      case 'Ayakkabı & Çanta':
        opportunities = [
          {'icon': Icons.girl, 'title': 'Kadın Ayakkabı'},
          {'icon': Icons.man, 'title': 'Erkek Ayakkabı'},
          {'icon': Icons.child_care, 'title': 'Çocuk Ayakkabı'},
          {'icon': Icons.shopping_bag, 'title': 'Kadın Çanta'},
          {'icon': Icons.backpack, 'title': 'Erkek Çanta'},
          {'icon': Icons.school, 'title': 'Çocuk Çanta'},
          {'icon': Icons.luggage, 'title': 'Valiz & Bavul'},
        ];
        break;
      case 'Saat & Aksesuar':
        opportunities = [
          {'icon': Icons.watch, 'title': 'Kadın Saat & Takı'},
          {'icon': Icons.watch_later, 'title': 'Erkek Saat & Takı'},
          {'icon': Icons.watch_outlined, 'title': 'Akıllı Saatler'},
          {'icon': Icons.child_friendly, 'title': 'Çocuk Saatleri'},
          {'icon': Icons.wb_sunny, 'title': 'Güneş Gözlüğü'},
        ];
        break;
      case 'Ev & Yaşam':
        opportunities = [
          {'icon': Icons.restaurant, 'title': 'Sofra & Mutfak'},
          {'icon': Icons.bed, 'title': 'Ev Tekstili'},
          {'icon': Icons.chair, 'title': 'Mobilya'},
          {'icon': Icons.lightbulb, 'title': 'Aydınlatma'},
          {'icon': Icons.bathtub, 'title': 'Banyo & Mutfak'},
          {'icon': Icons.iron, 'title': 'Elektrikli Ev Aletleri'},
          {'icon': Icons.home, 'title': 'Ev Dekorasyonu'},
          {'icon': Icons.security, 'title': 'Akıllı Ev & Güvenlik Sistemleri'},
          {'icon': Icons.water_drop, 'title': 'Su Arıtma Ürünleri'},
        ];
        break;
      case 'Kırtasiye & Ofis':
        opportunities = [
          {'icon': Icons.desk, 'title': 'Ofis Mobilyaları'},
          {'icon': Icons.attach_file, 'title': 'Ofis Malzemeleri'},
          {'icon': Icons.edit, 'title': 'Yazı Gereçleri'},
          {'icon': Icons.book, 'title': 'Defterler'},
          {'icon': Icons.menu_book, 'title': 'Kitaplar'},
          {'icon': Icons.palette, 'title': 'Sanatsal Malzemeler (Boya vb.)'},
          {'icon': Icons.backpack, 'title': 'Okul Setleri'},
        ];
        break;
      case 'Yakın Lokasyon':
        opportunities = [
          {'icon': Icons.restaurant_menu, 'title': 'Yemek'},
          {'icon': Icons.shopping_cart, 'title': 'Market'},
          {'icon': Icons.explore, 'title': 'Keşfet (Popüler Mekanlar)'},
        ];
        break;
      case 'Oto, Bahçe, Yapı Market':
        opportunities = [
          {'icon': Icons.directions_car, 'title': 'Otomobil & Motosiklet'},
          {'icon': Icons.build, 'title': 'Yapı Market & Hırdavat'},
          {'icon': Icons.grass, 'title': 'Bahçe Ürünleri'},
          {'icon': Icons.plumbing, 'title': 'Banyo Ürünleri & Tesisat'},
          {'icon': Icons.electric_car, 'title': 'Elektrikli Araç Ürünleri'},
          {'icon': Icons.speaker_group, 'title': 'Oto Ses & Görüntü Sistemleri'},
          {'icon': Icons.settings, 'title': 'Oto Yedek Parça'},
          {'icon': Icons.cleaning_services, 'title': 'Araç Bakım & Temizlik'},
          {'icon': Icons.car_repair, 'title': 'Oto Aksesuar (Paspas, Silecek vb.)'},
          {'icon': Icons.airport_shuttle, 'title': 'Karavan Aksesuarları'},
          {'icon': Icons.kitchen, 'title': 'Oto Buzdolapları'},
          {'icon': Icons.luggage, 'title': 'Seyahat Ürünleri'},
          {'icon': Icons.agriculture, 'title': 'Bahçe & Tarım Makineleri'},
          {'icon': Icons.outdoor_grill, 'title': 'Mangal & Barbekü'},
          {'icon': Icons.pool, 'title': 'Havuz Malzemeleri'},
          {'icon': Icons.health_and_safety, 'title': 'İş Güvenliği'},
        ];
        break;
      case 'Oyuncak, Müzik, Film':
        opportunities = [
          {'icon': Icons.toys, 'title': 'Oyuncaklar'},
          {'icon': Icons.extension, 'title': 'Hobi & Eğlence Oyunları'},
          {'icon': Icons.music_note, 'title': 'Müzik Enstrümanları ve Ekipmanları'},
          {'icon': Icons.album, 'title': 'Müzik Albümleri'},
          {'icon': Icons.movie, 'title': 'Filmler'},
          {'icon': Icons.confirmation_number, 'title': 'Etkinlik Biletleri'},
          {'icon': Icons.games, 'title': 'Dijital Oyun & Eğitim'},
        ];
        break;
      case 'Spor & Outdoor':
        opportunities = [
          {'icon': Icons.checkroom, 'title': 'Spor Giyim & Ayakkabı'},
          {'icon': Icons.hiking, 'title': 'Outdoor Giyim & Ayakkabı'},
          {'icon': Icons.fitness_center, 'title': 'Fitness & Kondisyon Ürünleri'},
          {'icon': Icons.sports_basketball, 'title': 'Spor Branşları (Basketbol, Futbol vb.)'},
          {'icon': Icons.cabin, 'title': 'Kamp & Kampçılık'},
          {'icon': Icons.directions_bike, 'title': 'Bisiklet'},
          {'icon': Icons.electric_scooter, 'title': 'Elektrikli Scooter, Paten & Kaykay'},
          {'icon': Icons.pool, 'title': 'Şişme Su Ürünleri'},
          {'icon': Icons.phishing, 'title': 'Balıkçılık & Avcılık'},
          {'icon': Icons.sailing, 'title': 'Tekne Malzemeleri'},
          {'icon': Icons.landscape, 'title': 'Doğa Sporları'},
          {'icon': Icons.snowboarding, 'title': 'Kış & Su Sporları'},
          {'icon': Icons.shield, 'title': 'Askeri Malzeme & Giyim'},
          {'icon': Icons.visibility, 'title': 'Dürbün, Teleskop & Navigasyon'},
          {'icon': Icons.flag, 'title': 'Taraftar Ürünleri'},
        ];
        break;
      case 'Kozmetik & Kişisel Bakım':
        opportunities = [
          {'icon': Icons.face, 'title': 'Kişisel Bakım'},
          {'icon': Icons.brush, 'title': 'Makyaj'},
          {'icon': Icons.content_cut, 'title': 'Saç Bakımı'},
          {'icon': Icons.science, 'title': 'Parfüm & Deodorant'},
          {'icon': Icons.spa, 'title': 'Profesyonel Saç Bakımı'},
          {'icon': Icons.face_retouching_natural, 'title': 'Cilt Bakımı'},
          {'icon': Icons.clean_hands, 'title': 'Ağız Bakımı'},
          {'icon': Icons.wb_sunny, 'title': 'Güneş Kremleri'},
          {'icon': Icons.medication, 'title': 'Besin Takviyeleri'},
          {'icon': Icons.shower, 'title': 'Duş & Banyo Ürünleri'},
          {'icon': Icons.content_cut, 'title': 'Erkek Tıraş Ürünleri'},
          {'icon': Icons.favorite, 'title': 'Cinsel Sağlık'},
          {'icon': Icons.health_and_safety, 'title': 'Sağlık Ürünleri'},
          {'icon': Icons.diamond, 'title': 'Lüks Kozmetik'},
        ];
        break;
      case 'Pet Shop':
        opportunities = [
          {'icon': Icons.pets, 'title': 'Köpek'},
          {'icon': Icons.cruelty_free, 'title': 'Kedi'},
          {'icon': Icons.flutter_dash, 'title': 'Kuş'},
          {'icon': Icons.set_meal, 'title': 'Balık'},
          {'icon': Icons.pest_control, 'title': 'Kemirgen & Sürüngen'},
        ];
        break;
      default:
        // Ana Sayfa Varsayılanları
        opportunities = [
          {'icon': Icons.flash_on, 'title': 'Süper Fırsat'},
          {'icon': Icons.local_offer, 'title': 'İndirimler'},
          {'icon': Icons.trending_up, 'title': 'Çok Satanlar'},
          {'icon': Icons.new_releases, 'title': 'Yeniler'},
          {'icon': Icons.diamond, 'title': 'Özel Ürünler'},
          {'icon': Icons.card_giftcard, 'title': 'Hediye'},
          {'icon': Icons.computer, 'title': 'Elektronik'},
          {'icon': Icons.chair, 'title': 'Ev & Yaşam'},
          {'icon': Icons.checkroom, 'title': 'Moda'},
          {'icon': Icons.sports_soccer, 'title': 'Spor'},
          {'icon': Icons.auto_stories, 'title': 'Kitap'},
        ];
    }

    return Container(
      width: double.infinity,
      height: 140,
      margin: const EdgeInsets.only(bottom: 24),
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
              controller: _subCategoryScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: opportunities.length,
              separatorBuilder: (context, index) => const SizedBox(width: 24),
              itemBuilder: (context, index) {
                final item = opportunities[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSubCategory = item['title'];
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item['icon'] as IconData, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Right Arrow Button
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (_subCategoryScrollController.hasClients) {
                        _subCategoryScrollController.animateTo(
                          _subCategoryScrollController.offset + 200,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
