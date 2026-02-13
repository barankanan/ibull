
import 'dart:convert';
import 'dart:async';
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
import 'product_detail_page.dart';
import 'ai_chat_page.dart';

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
  final ScrollController _flashProductsScrollController = ScrollController();
  final ScrollController _todayProductsScrollController = ScrollController();

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
    _flashProductsScrollController.dispose();
    _todayProductsScrollController.dispose();
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
            imageUrl: 'assets/products/iphone15_beyaz_on.png',
            category: 'Elektronik',
            brand: 'Apple',
            description: 'Apple iPhone 12, 5G desteği, A14 Bionic çip, 12MP çift kamera sistemi ve Super Retina XDR ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayın. Ceramic Shield ön kapak, IP68 su ve toz dayanıklılığı, MagSafe kablosuz şarj desteği. iOS ekosistemiyle sorunsuz entegrasyon.',
            rating: 4.8,
            reviewCount: 1250,
            tags: '["Hızlı Kargo", "Ücretsiz Kargo"]',
            subCategory: 'Telefon',
            store: 'Apple Store',
            variantOptions: 'Renk:Siyah|Depolama:128 GB',
            variantGroupId: 'iphone13',
          ),
          DBProduct(
            id: 2,
            name: 'Samsung Galaxy S23 Ultra',
            price: '45.999 TL',
            imageUrl: 'assets/products/s24_mor.jpeg',
            category: 'Elektronik',
            brand: 'Samsung',
            description: '200 MP Kamera, S Pen dahil.',
            rating: 4.9,
            reviewCount: 850,
            tags: '["Yeni", "Fırsat"]',
            subCategory: 'Telefon',
            variantOptions: 'Renk:Siyah|Depolama:256 GB',
            variantGroupId: 'galaxys23',
            store: 'Samsung TR',
          ),
          DBProduct(
            id: 3,
            name: 'Dyson V15 Detect',
            price: '24.999 TL',
            imageUrl: 'assets/products/dyson_v15.jpeg',
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
            imageUrl: 'assets/products/sony_xm5.jpg',
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
            name: 'MacBook Pro M3',
            price: '58.999 TL',
            imageUrl: 'assets/products/macbook_pro_m3.jpeg',
            category: 'Elektronik',
            brand: 'Apple',
            description: 'M3 çip, 18 saat pil ömrü.',
            rating: 4.8,
            reviewCount: 5600,
            tags: '["Popüler"]',
            subCategory: 'Bilgisayar',
            store: 'Apple Store',
          ),

          // --- SAÇ BAKIM ÜRÜNLERİ (DUMMY) ---
          
          // Urban Care
          DBProduct(
            id: 101,
            name: 'Urban Care Hyaluronic Acid & Collagen Şampuan',
            price: '199.90 TL',
            oldPrice: '250.00 TL',
            imageUrl: 'assets/products/Urban Care Hyaluronic Şampuan.jpg',
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
            imageUrl: 'assets/products/Urban Care Argan Oil Şampuan.jpeg',
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
            imageUrl: 'assets/products/Urban Care Biotin & Kafein Tonik.jpeg',
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
            imageUrl: 'assets/products/Head & Shoulders Mentol Ferahlığı Şampuan.jpeg',
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
            imageUrl: 'assets/products/Head & Shoulders Mentol Ferahlığı Şampuan.jpeg',
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
            imageUrl: 'assets/products/Elseve Şampuan Glycolic Gloss.jpeg',
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
            imageUrl: 'assets/products/Elseve Şampuan Glycolic Gloss.jpeg',
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
            imageUrl: 'assets/products/Mood Onarıcı Saç Şampuanı.jpeg',
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
            imageUrl: 'assets/products/Morfose Milk Therapy Saç Köpüğü.jpeg',
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
            imageUrl: 'assets/products/Dove Yoğun Onarım Şampuan.jpeg',
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
            imageUrl: 'assets/products/Dove Yoğun Onarım Şampuan.jpeg',
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
            imageUrl: 'assets/products/Clear Men Güçlü & Parlak Şampuan.jpeg',
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
            imageUrl: 'assets/products/Clear Men Güçlü & Parlak Şampuan.jpeg',
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
            imageUrl: 'assets/products/iphone15_beyaz_on.png',
            category: 'Elektronik',
            brand: 'Apple',
            description: 'Apple iPhone 12, 5G desteği, A14 Bionic çip, 12MP çift kamera sistemi ve Super Retina XDR ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayın.',
            rating: 4.8,
            reviewCount: 1250,
            tags: '["Hızlı Kargo", "Ücretsiz Kargo"]',
            subCategory: 'Telefon',
            store: 'Apple Store',
            variantOptions: 'Renk:Siyah|Depolama:128 GB',
            variantGroupId: 'iphone13',
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
      'logo': '',
      'adUrls': <String>[],
      'products': [] // Veritabanından çekilecek
    },
    'Samsung': {
      'logo': '',
      'adUrls': <String>[],
      'products': []
    },
    'Dyson': {
      'logo': '',
      'adUrls': <String>[],
      'products': []
    },
    'Sony': {
      'logo': '',
      'adUrls': <String>[],
      'products': []
    },
    'Philips': {
      'logo': '',
      'adUrls': <String>[],
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
      // Web'de FloatingActionButton Yapay Zeka, Mobil'de Çark
      floatingActionButton: _buildFab(context),
      // Web'de BottomNavigationBar'ı gizle
      bottomNavigationBar: MediaQuery.of(context).size.width >= 1100 
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

  Widget? _buildFab(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 1100;
    
    // Web için Yapay Zeka Butonu
    if (isWeb) {
      return SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              barrierColor: Colors.black54, // Yarı saydam arka plan
              builder: (context) => const AIChatPage(),
            );
          },
          backgroundColor: AppColors.primary,
          tooltip: 'Yapay Zekaya Danış',
          elevation: 4,
          shape: const CircleBorder(), // Tam yuvarlak
          child: const Icon(Icons.psychology, color: Colors.white, size: 32),
        ),
      );
    }

    // Mobil için Çark (Sadece Ana Sayfada ve henüz çevrilmediyse)
    if (_selectedIndex == 0 && !_hasSpunWheel) {
       return AnimatedBuilder(
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
          );
    }
    
    return null;
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

    // Breakpoint increased to 1100 to prevent WebHeader overflow on smaller screens (tablets, small laptops)
    final isWeb = MediaQuery.of(context).size.width >= 1100;

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
            'assets/images/banners/yakin-lokasyon-banner.png',
            'assets/images/banners/urunleri-listele-banner.png',
            'assets/images/banners/gorsel-zeka-banner.png',
            'assets/images/banners/ibul-premium-banner.png',
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
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                        ),
                      ),
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
                      height: 340,
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
                          height: 340,
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
                      height: 340,
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
                          height: 340,
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
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: displayProducts.length > 8 ? 8 : displayProducts.length, // Limit for demo
                itemBuilder: (context, index) {
                   return ProductCard(
                     product: _convertToProduct(displayProducts[index]),
                     margin: EdgeInsets.zero,
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
      'assets/images/banners/ibul-premium-banner.png',
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
                        childAspectRatio: 0.75, // Kart oranı
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: popularProducts.length,
                      itemBuilder: (context, index) {
                        final dbProduct = popularProducts[index];
                        return ProductCard(
                          product: _convertToProduct(dbProduct),
                          margin: EdgeInsets.zero,
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
                height: 380,
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
                                height: 380,
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
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.primary.withOpacity(0.06), Colors.white],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 10)],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  Center(
                                    child: popularProducts.isNotEmpty 
                                      ? DealOfTheDaySlider(products: popularProducts)
                                      : const CircularProgressIndicator(),
                                  ),
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFF9800), AppColors.primary],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.flash_on, color: Colors.white, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Günün Fırsatı',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            flex: 2,
                            child: const CouponSlider(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // 2.5 Bugün Kapında (Yeni Alan)
              Container(
                padding: const EdgeInsets.all(24),
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
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bugün Kapında',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                            ),
                            Text(
                              'Yakın Lokasyon ile çevrendeki mağazalardan alışveriş yapabilirsin',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_outlined, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Hızlı Teslimat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Yatay Liste
                    popularProducts.isNotEmpty
                      ? SizedBox(
                          height: 340,
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
                                  itemCount: popularProducts.length > 10 ? 10 : popularProducts.length,
                                  separatorBuilder: (context, index) => const SizedBox(width: 20),
                                  itemBuilder: (context, index) {
                                    final dbProduct = popularProducts[index];
                                    return SizedBox(
                                      width: 220,
                                      child: ProductCard(
                                        product: _convertToProduct(dbProduct),
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
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.blue),
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
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.blue),
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
                        )
                      : const SizedBox.shrink(),
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
                    height: 340,
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
                                child: ProductCard(
                                  product: _convertToProduct(dbProduct),
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

              // 4.5 Flaş Ürünler - Grid Bölümü
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.04),
                      Colors.white,
                      Colors.red.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flash_on, color: Colors.red, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flaş Ürünler',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                            ),
                            Text(
                              'Kaçırılmayacak fırsatlar',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Sınırlı Süre', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Grid yerine Yatay Liste
                    popularProducts.length > 1
                      ? SizedBox(
                          height: 340,
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
                                  controller: _flashProductsScrollController,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: popularProducts.length > 10 ? 10 : popularProducts.length,
                                  separatorBuilder: (context, index) => const SizedBox(width: 20),
                                  itemBuilder: (context, index) {
                                    final dbProduct = popularProducts[index];
                                    return SizedBox(
                                      width: 220,
                                      child: ProductCard(
                                        product: _convertToProduct(dbProduct),
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
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primary),
                                      onPressed: () {
                                        _flashProductsScrollController.animateTo(
                                          _flashProductsScrollController.offset - 300,
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
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_forward_ios, size: 20, color: AppColors.primary),
                                      onPressed: () {
                                        _flashProductsScrollController.animateTo(
                                          _flashProductsScrollController.offset + 300,
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
                        )
                      : const SizedBox.shrink(),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 5. Markalar ve Bakım Bölümü
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _buildHairCareSection(),
              ),
              const SizedBox(height: 40),

              // 5.5 Neden iBul? Bölümü
              _buildWhyIbulSection(),
              const SizedBox(height: 40),

              // 6. Teknoloji Dünyası Bölümü
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _buildTechSection(),
              ),
              
              const SizedBox(height: 80),

              // Avantaj Çubuğu (En Alta Taşındı)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 40),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.05), Colors.white, AppColors.primary.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTrustItem(Icons.local_shipping_outlined, 'Ücretsiz Kargo', '150 TL üzeri'),
                    _buildTrustDivider(),
                    _buildTrustItem(Icons.verified_user_outlined, 'Güvenli Ödeme', '256-bit SSL'),
                    _buildTrustDivider(),
                    _buildTrustItem(Icons.replay_outlined, '14 Gün İade', 'Koşulsuz iade'),
                    _buildTrustDivider(),
                    _buildTrustItem(Icons.support_agent_outlined, '7/24 Destek', 'Canlı yardım'),
                    _buildTrustDivider(),
                    _buildTrustItem(Icons.workspace_premium_outlined, 'Orijinal Ürün', 'Garantili'),
                  ],
                ),
              ),
              
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

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.grey[200],
    );
  }

  Widget _buildWhyIbulSection() {
    final items = [
      {
        'icon': Icons.location_on_outlined,
        'color': const Color(0xFF4CAF50),
        'title': 'Yakın Lokasyon',
        'desc': 'En yakın mağazaları haritada bul, hızlı teslimat al.',
      },
      {
        'icon': Icons.compare_arrows,
        'color': const Color(0xFF2196F3),
        'title': 'Fiyat Karşılaştırma',
        'desc': 'Aynı ürünü farklı satıcılarda karşılaştır, en uygun fiyatı yakala.',
      },
      {
        'icon': Icons.auto_awesome,
        'color': AppColors.primary,
        'title': 'Yapay Zeka Asistanı',
        'desc': 'Fotoğraf çek, aradığın ürünü anında bul.',
      },
      {
        'icon': Icons.verified,
        'color': const Color(0xFFFF9800),
        'title': 'Güvenilir Satıcılar',
        'desc': 'Onaylı mağazalar ve gerçek kullanıcı yorumları.',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.03),
            Colors.white,
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text(
            'Neden iBul?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 6),
          Text(
            'Alışverişin en akıllı yolu',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 28),
          Row(
            children: items.map((item) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (item['color'] as Color).withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item['title'] as String,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['desc'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.4),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class CouponSlider extends StatefulWidget {
  const CouponSlider({super.key});

  @override
  State<CouponSlider> createState() => _CouponSliderState();
}

class _CouponSliderState extends State<CouponSlider> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  final Set<int> _usedCoupons = {};

  final List<Map<String, dynamic>> _coupons = [
    {
      'title': '200 TL İndirim',
      'subtitle': 'İlk Siparişe Özel',
      'color': [const Color(0xFF6A11CB), const Color(0xFF2575FC)], // Purple-Blue
      'icon': Icons.card_giftcard,
    },
    {
      'title': '%15 İndirim',
      'subtitle': 'Teknoloji Ürünlerinde',
      'color': [const Color(0xFFFF512F), const Color(0xFFDD2476)], // Orange-Red
      'icon': Icons.devices,
    },
    {
      'title': 'Kargo Bedava',
      'subtitle': '150 TL Üzeri',
      'color': [const Color(0xFF00B09B), const Color(0xFF96C93D)], // Green
      'icon': Icons.local_shipping,
    },
    {
      'title': '3 Al 2 Öde',
      'subtitle': 'Kişisel Bakım',
      'color': [const Color(0xFFDA22FF), const Color(0xFF9733EE)], // Purple
      'icon': Icons.shopping_basket,
    },
    {
      'title': '50 TL Puan',
      'subtitle': 'Cüzdan ile Ödemede',
      'color': [const Color(0xFFFF8008), const Color(0xFFFFC837)], // Orange-Yellow
      'icon': Icons.account_balance_wallet,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.7);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimer();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      
      if (_currentPage < _coupons.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 12, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text('Kuponlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800)),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _coupons.length,
              itemBuilder: (context, index) {
                final coupon = _coupons[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Stack(
                    children: [
                      // Arka Plan
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.grey.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      // Sol Taraf (Renk Çubuğu)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: coupon['color'] as List<Color>,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      // İçerik
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (coupon['color'][0] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(coupon['icon'] as IconData, color: coupon['color'][0] as Color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    coupon['title'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    coupon['subtitle'],
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_usedCoupons.contains(index)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bu kupon zaten tanımlandı!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  return;
                                }
                                
                                setState(() {
                                  _usedCoupons.add(index);
                                });
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${coupon['title']} kuponu hesabınıza tanımlandı!'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _usedCoupons.contains(index) ? Colors.grey : (coupon['color'][0] as Color),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_usedCoupons.contains(index) ? Colors.grey : coupon['color'][0] as Color).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _usedCoupons.contains(index) ? 'KULLANILDI' : 'KULLAN',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kesik Çizgiler (Bilet Efekti - Opsiyonel, şimdilik sade tutalım)
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class DealOfTheDaySlider extends StatefulWidget {
  final List<DBProduct> products;

  const DealOfTheDaySlider({super.key, required this.products});

  @override
  State<DealOfTheDaySlider> createState() => _DealOfTheDaySliderState();
}

class _DealOfTheDaySliderState extends State<DealOfTheDaySlider> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimer();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (widget.products.isEmpty) return;
      
      if (_currentPage < widget.products.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();

    return PageView.builder(
      controller: _pageController,
      itemCount: widget.products.length,
      itemBuilder: (context, index) {
        final product = widget.products[index];
        
        // İndirim oranını hesapla
        String? discountRate;
        if (product.oldPrice != null && product.oldPrice!.isNotEmpty) {
          try {
            double price = double.parse(product.price.replaceAll(RegExp(r'[^0-9.]'), ''));
            double oldPrice = double.parse(product.oldPrice!.replaceAll(RegExp(r'[^0-9.]'), ''));
            if (oldPrice > price) {
              int rate = ((oldPrice - price) / oldPrice * 100).round();
              discountRate = '%$rate';
            }
          } catch (e) {
            // Fiyat formatı hatası olursa yoksay
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(product: Product.fromDBProduct(product)),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Görsel Alanı
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Image.asset(
                            product.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image, size: 50, color: Colors.grey);
                            },
                          ),
                        ),
                      ),
                      if (discountRate != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              discountRate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Bilgi Alanı
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.oldPrice != null)
                                Text(
                                  product.oldPrice!,
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              Text(
                                product.price,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
