import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:flutter/gestures.dart'; // Scroll behavior için eklendi
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/auth/user_identity.dart';
import '../ads/enums/ad_enums.dart';
import '../core/mobile_category_catalog.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../core/app_state.dart';
import '../core/review_state.dart';
import '../widgets/custom_header.dart';
import '../widgets/web_header.dart'; // Web Header eklendi
import '../widgets/web_footer.dart'; // Web Footer eklendi
import '../widgets/filter_sidebar.dart'; // Filter Sidebar eklendi
import '../widgets/address_bar.dart';
import '../widgets/address_edit_sheet.dart';
import '../widgets/feature_menu.dart';
import '../widgets/product_card.dart';
import '../widgets/brand_section.dart';
import '../widgets/optimized_image.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/common/custom_error_view.dart';
import '../widgets/sponsored_product_lists_section.dart';
import '../services/supabase_service.dart';
import '../services/database_helper.dart';
import '../services/admin_service.dart';
import '../services/review_repository.dart';
import '../services/store_service.dart';
import '../widgets/game/fortune_wheel_dialog.dart';
import 'dart:math' as math;
import 'categories_page.dart'; // Imported CategoriesPage
import 'map_page.dart';
import 'cart_page.dart';
import 'account_page.dart';
import 'search_results_page.dart';
import 'product_detail_page.dart';
import 'business_detail_page.dart';
import 'ai_chat_page.dart';
import '../widgets/dynamic_brand_section.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final String? initialCategory;

  const HomeScreen({super.key, this.initialIndex = 0, this.initialCategory});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _homeProductsCacheKey = 'home_products_cache_v1';
  static const String _homeBannersCacheKey = 'home_banners_cache_v1';
  static const String _homeAppCategoriesCacheKey =
      'home_app_categories_cache_v1';
  late int _selectedIndex;
  String _selectedBrand = 'Urban';
  String _selectedTechBrand = 'Apple'; // Teknoloji için seçili marka
  late String _selectedCategory; // Seçili kategori
  String? _selectedSubCategory; // Seçili alt kategori
  final AppState _appState = AppState();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<DBProduct> _dbProducts = [];
  bool _isLoadingProducts = true;
  bool _isLoadingHeroContent = true;
  bool _isLoadingHomeSections = true;
  String? _errorMessage;
  late AnimationController _spinController;
  bool _hasSpunWheel = false; // Çark çevrildi mi kontrolü
  final ScrollController _popularProductsScrollController = ScrollController();
  final ScrollController _subCategoryScrollController = ScrollController();
  final ScrollController _flashProductsScrollController = ScrollController();
  final ScrollController _todayProductsScrollController = ScrollController();

  final String _currentAddress =
      'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kültür merkezi karşısı';
  final AdminService _adminService = AdminService();
  final StoreService _storeService = StoreService();
  String? _hairCareTitle;
  int? _hairCareSlot;
  Map<String, dynamic> _hairCareBrandData = {};
  String? _hairCareSelectedBrand;
  List<Map<String, dynamic>> _hairCareLayoutsForHome = [];
  // List<Map<String, dynamic>> for campaign images
  List<Map<String, dynamic>> _mainBannerImages = [];
  List<Map<String, dynamic>> _appFeatureCategories = [];
  List<Map<String, dynamic>> _storesForFastDelivery = [];
  final Map<String, Product> _productConversionCache = {};
  bool _tableQrHandled = false;

  // _addresses is now managed by AppState

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
    'Fiyat (Aralık Belirleme)': [], // Special handling in widget
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

  String _normalizeText(String value) {
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

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(); // Sürekli dön

    _selectedIndex = widget.initialIndex;
    _selectedCategory = widget.initialCategory ?? 'Ana Sayfa';
    _appState.cartCountNotifier.value = _appState.cart.length;
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleTableQrLaunch();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _popularProductsScrollController.dispose();
    _flashProductsScrollController.dispose();
    _todayProductsScrollController.dispose();
    super.dispose();
  }

  List<DBProduct> _getProductsForCurrentSubCategory() {
    if (_selectedSubCategory == null) {
      return [];
    }

    final selectedMainCategory = _normalizeText(_selectedCategory);
    final selectedSub = _normalizeText(_selectedSubCategory!);

    final baseProducts = _dbProducts.where((p) {
      final category = _normalizeText(p.category);
      return category == selectedMainCategory;
    }).toList();

    return baseProducts.where((p) {
      final subCat = _normalizeText(p.subCategory ?? '');
      final name = _normalizeText(p.name);

      if (selectedMainCategory == _normalizeText('Elektronik')) {
        if (selectedSub.contains('telefonlar') ||
            selectedSub == _normalizeText('telefon')) {
          return subCat.contains('telefon') ||
              name.contains('telefon') ||
              name.contains('iphone') ||
              name.contains('galaxy');
        }

        if (selectedSub.contains('laptop') || selectedSub.contains('tablet')) {
          return subCat.contains('bilgisayar') ||
              subCat.contains('tablet') ||
              name.contains('laptop') ||
              name.contains('macbook') ||
              name.contains('bilgisayar');
        }

        if (selectedSub.contains('televizyon')) {
          return subCat.contains('tv') ||
              subCat.contains('televizyon') ||
              name.contains('tv') ||
              name.contains('televizyon');
        }

        if (selectedSub.contains('beyaz esya')) {
          return subCat.contains('beyaz esya');
        }

        if (selectedSub.contains('isitma') || selectedSub.contains('sogutma')) {
          return subCat.contains('klima') ||
              subCat.contains('isitici') ||
              name.contains('klima') ||
              name.contains('isitici');
        }

        if (selectedSub.contains('sinema') ||
            selectedSub.contains('ses sistemleri')) {
          return subCat.contains('tv & ses sistemleri') ||
              subCat.contains('ses') ||
              name.contains('ses sistemi');
        }

        if (selectedSub.contains('telefon aksesuar')) {
          return subCat.contains('telefon & aksesuar') ||
              name.contains('kılıf') ||
              name.contains('kulaklık') ||
              name.contains('sarj') ||
              name.contains('şarj');
        }
      }

      return subCat == selectedSub;
    }).toList();
  }

  Future<void> _handleTableQrLaunch() async {
    if (_tableQrHandled || !mounted) return;
    _tableQrHandled = true;

    String firstNonEmptyParam(Map<String, String> source, List<String> keys) {
      for (final key in keys) {
        final value = (source[key] ?? '').trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    int? parseTableNumber(String raw) {
      final direct = int.tryParse(raw.trim());
      if (direct != null) return direct;
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match == null) return null;
      return int.tryParse(match.group(0)!);
    }

    final uri = Uri.base;
    final params = <String, String>{...uri.queryParameters};
    if (params['table_qr'] != '1') {
      final fragment = uri.fragment;
      final queryIndex = fragment.indexOf('?');
      if (queryIndex >= 0 && queryIndex + 1 < fragment.length) {
        final query = fragment.substring(queryIndex + 1);
        try {
          params.addAll(Uri.splitQueryString(query));
        } catch (_) {}
      }
    }
    final hasQrIntent =
        params['table_qr'] == '1' ||
        ((params['seller'] ?? '').trim().isNotEmpty &&
            (params['table'] ?? '').trim().isNotEmpty);
    if (!hasQrIntent) return;

    final sellerId = firstNonEmptyParam(params, [
      'seller',
      'seller_id',
      'store',
      'store_seller',
    ]);
    final tableRaw = firstNonEmptyParam(params, [
      'table',
      'table_number',
      'tableNo',
      'masa',
    ]);
    final tableNumber = parseTableNumber(tableRaw);
    final token = firstNonEmptyParam(params, ['token', 'qr_token', 'qr', 't']);

    if (sellerId.isEmpty || tableNumber == null || tableNumber <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR bağlantısı eksik veya hatalı.')),
        );
      }
      return;
    }

    var qrVerified = false;
    try {
      // QR doğrulama ve mağaza sorgusunu paralel yap → daha hızlı açılış.
      final futures = await Future.wait<Object?>([
        token.isNotEmpty
            ? _storeService.resolveStoreTableQr(
                sellerId: sellerId,
                tableNumber: tableNumber,
                qrToken: token,
              )
            : Future<Map<String, dynamic>?>.value(null),
        _storeService.getBusinessSummaryBySellerId(sellerId),
      ]);
      final resolvedTable = futures[0] as Map<String, dynamic>?;
      qrVerified = token.isNotEmpty && resolvedTable != null;
      var business = futures[1] as Map<String, dynamic>?;
      business ??= await _storeService.getBusinessSummaryByBusinessName(
        sellerId,
      );
      if (!mounted || business == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu QR için mağaza bulunamadı.')),
          );
        }
        return;
      }
      final resolvedBusiness = business;

      if (mounted && token.isNotEmpty && !qrVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR doğrulanamadı, masa ekranı yine de açılıyor.'),
          ),
        );
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessDetailPage(
            business: resolvedBusiness,
            forceTableSelection: true,
            initialTableNumber: tableNumber,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR açılamadı: $error')));
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProducts = true;
      _isLoadingHeroContent = true;
      _isLoadingHomeSections = true;
      _errorMessage = null;
      _productConversionCache.clear();
    });

    await _loadCachedHomeProducts();
    await _loadCachedHomeHeroContent();

    try {
      unawaited(_loadImmediateHomeContent());
      final supabaseProducts = await SupabaseService.instance
          .getInitialHomeProducts();

      if (supabaseProducts.isNotEmpty) {
        _dbProducts = supabaseProducts;
        _warmHomeProductRatings(_dbProducts);
        unawaited(_saveHomeProductsToCache(_dbProducts));
        debugPrint('✅ Supabase: ${_dbProducts.length} ürün yüklendi');
      } else {
        await _dbHelper.initializeDatabase();
        _dbProducts = await _dbHelper.getProductsPage(
          limit: SupabaseService.homePageSize,
        );
        _warmHomeProductRatings(_dbProducts);
        debugPrint('✅ Local DB: ${_dbProducts.length} ürün yüklendi');
      }

      final withImages = _dbProducts.where((p) => p.imageUrl.isNotEmpty).length;
      debugPrint(
        '📸 Görseli olan ürün sayısı: $withImages/${_dbProducts.length}',
      );

      unawaited(_loadDeferredHomeContent());
    } catch (e) {
      debugPrint('Ürün yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ürünler yüklenirken bir hata oluştu: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadImmediateHomeContent() async {
    try {
      await Future.wait([_loadMainBanners(), _loadAppFeatureCategories()]);
    } catch (e) {
      debugPrint('Ana sayfa üst içerikleri yüklenemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHeroContent = false;
        });
      }
    }
  }

  Future<void> _loadDeferredHomeContent() async {
    try {
      await Future.wait([
        _loadStoreDirectoryForFastDelivery(),
        _loadHairCareLayoutConfig(),
      ]);
    } catch (e) {
      debugPrint('Ana sayfa yardımcı içerikleri yüklenemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHomeSections = false;
        });
      }
    }
  }

  Future<void> _loadCachedHomeProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_homeProductsCacheKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final cachedProducts = decoded
          .whereType<Map>()
          .map((item) => DBProduct.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted || cachedProducts.isEmpty) {
        return;
      }

      setState(() {
        _dbProducts = cachedProducts;
        _isLoadingProducts = false;
        _productConversionCache.clear();
      });
      _warmHomeProductRatings(cachedProducts);
    } catch (e) {
      debugPrint('Ana sayfa cache okunamadı: $e');
    }
  }

  Future<void> _loadCachedHomeHeroContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawBanners = prefs.getString(_homeBannersCacheKey);
      final rawCategories = prefs.getString(_homeAppCategoriesCacheKey);

      final cachedBanners = rawBanners == null || rawBanners.isEmpty
          ? const <Map<String, dynamic>>[]
          : (jsonDecode(rawBanners) as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false);

      final cachedCategories = rawCategories == null || rawCategories.isEmpty
          ? const <Map<String, dynamic>>[]
          : (jsonDecode(rawCategories) as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false);

      if (!mounted || (cachedBanners.isEmpty && cachedCategories.isEmpty)) {
        return;
      }

      setState(() {
        if (cachedBanners.isNotEmpty) {
          _mainBannerImages = cachedBanners;
        }
        if (cachedCategories.isNotEmpty) {
          _appFeatureCategories = cachedCategories;
        }
        _isLoadingHeroContent = false;
      });
    } catch (e) {
      debugPrint('Ana sayfa üst içerik cache okunamadı: $e');
    }
  }

  void _warmHomeProductRatings(List<DBProduct> products) {
    // Only warm ratings for the first 10 products — the visible "Sana Özel"
    // row.  Remaining items are loaded lazily as the user scrolls and their
    // ProductCards call context.select<ReviewState>.
    //
    // Deferred 800 ms so this batch of ILIKE queries does NOT compete with the
    // banner/category network requests and the first product-row render.  The
    // ReviewRepository in-memory cache ensures no duplicate requests are fired
    // on subsequent calls with the same products.
    final visibleProducts = products
        .where((p) => p.name.trim().isNotEmpty)
        .take(10)
        .toList(growable: false);

    if (visibleProducts.isEmpty || !mounted) return;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final lookups = visibleProducts
          .map(
            (p) => ProductReviewLookup(productName: p.name, storeName: p.store),
          )
          .toList(growable: false);
      final reviewState = context.read<ReviewState>();
      unawaited(
        reviewState.warmProductRatingSummaries(lookups).catchError((error) {
          debugPrint('Ana sayfa review preload başarısız: $error');
        }),
      );
    });
  }

  Future<void> _saveHomeProductsToCache(List<DBProduct> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        products.map((product) => product.toMap()).toList(),
      );
      await prefs.setString(_homeProductsCacheKey, payload);
    } catch (e) {
      debugPrint('Ana sayfa cache yazılamadı: $e');
    }
  }

  Future<void> _saveHomeBannersToCache(
    List<Map<String, dynamic>> banners,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeBannersCacheKey, jsonEncode(banners));
    } catch (e) {
      debugPrint('Ana sayfa banner cache yazılamadı: $e');
    }
  }

  Future<void> _saveHomeAppCategoriesToCache(
    List<Map<String, dynamic>> categories,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeAppCategoriesCacheKey, jsonEncode(categories));
    } catch (e) {
      debugPrint('Ana sayfa kategori cache yazılamadı: $e');
    }
  }

  Future<void> _loadStoreDirectoryForFastDelivery() async {
    try {
      // Use the lightweight fetch — only seller_id, business_name, store_lat,
      // store_lng are needed for haversine distance scoring.  This avoids
      // pulling gallery_images and banners (large JSON arrays) from every store.
      final stores = await _storeService.getStoresForFastDelivery();
      if (!mounted) return;
      setState(() {
        _storesForFastDelivery = stores;
      });
    } catch (e) {
      debugPrint('Hızlı teslimat mağaza listesi alınamadı: $e');
    }
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  double? _parseMoney(dynamic value) {
    if (value == null) return null;
    final cleaned = value
        .toString()
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  List<String> _decodeProductTags(DBProduct product) {
    final raw = product.tags.trim();
    if (raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return raw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.replaceAll('"', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _hasFastDeliveryTag(DBProduct product) {
    final tags = _decodeProductTags(product).map(_normalizeText);
    return tags.any(
      (tag) =>
          tag.contains('hizli teslimat') ||
          tag.contains('hizli kargo') ||
          tag.contains('yakin lokasyon') ||
          tag.contains('bugun kapinda'),
    );
  }

  bool _hasOpportunityTag(DBProduct product) {
    final tags = _decodeProductTags(product).map(_normalizeText);
    return tags.any(
      (tag) =>
          tag.contains('firsat') ||
          tag.contains('indirim') ||
          tag.contains('kampanya'),
    );
  }

  _GeoPoint? _resolveCurrentUserLocation() {
    final addresses = _appState.deliveryAddresses;
    if (addresses.isEmpty) return null;

    Map<String, String>? selectedAddress;
    final selectedDetail = (_appState.currentDeliveryAddress ?? '').trim();
    if (selectedDetail.isNotEmpty) {
      for (final address in addresses) {
        if ((address['detail'] ?? '').trim() == selectedDetail) {
          selectedAddress = address;
          break;
        }
      }
    }
    selectedAddress ??= addresses.first;

    final lat = _asDouble(
      selectedAddress['lat'] ?? selectedAddress['latitude'],
    );
    final lng = _asDouble(
      selectedAddress['lng'] ?? selectedAddress['longitude'],
    );
    if (lat == null || lng == null) return null;
    return _GeoPoint(lat: lat, lng: lng);
  }

  double? _distanceToProductStoreKm(
    DBProduct product,
    _GeoPoint userLocation, {
    required Map<String, Map<String, dynamic>> storeBySellerId,
    required Map<String, Map<String, dynamic>> storeByName,
  }) {
    Map<String, dynamic>? store;
    final sellerId = (product.sellerId ?? '').trim();
    if (sellerId.isNotEmpty) {
      store = storeBySellerId[sellerId];
    }
    if (store == null) {
      final storeName = (product.store ?? '').trim();
      if (storeName.isNotEmpty) {
        store = storeByName[_normalizeText(storeName)];
      }
    }
    if (store == null) return null;

    final storeLat = _asDouble(
      store['store_lat'] ?? store['latitude'] ?? store['lat'],
    );
    final storeLng = _asDouble(
      store['store_lng'] ?? store['longitude'] ?? store['lng'],
    );
    if (storeLat == null || storeLng == null) return null;

    return _haversineKm(userLocation.lat, userLocation.lng, storeLat, storeLng);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  _DiscountSignal _extractDiscountSignal(DBProduct product) {
    final price = _parseMoney(product.price);
    final oldPrice = _parseMoney(product.oldPrice);
    if (price == null || oldPrice == null || price <= 0 || oldPrice <= 0) {
      return const _DiscountSignal(rate: 0, hasDiscount: false);
    }

    final high = math.max(price, oldPrice);
    final low = math.min(price, oldPrice);
    if (high <= 0) {
      return const _DiscountSignal(rate: 0, hasDiscount: false);
    }

    final rate = ((high - low) / high).clamp(0.0, 1.0);
    return _DiscountSignal(rate: rate.toDouble(), hasDiscount: rate >= 0.05);
  }

  List<DBProduct> _getFastDeliveryProducts({int limit = 10}) {
    final products = _dbProducts
        .where((p) => p.imageUrl.isNotEmpty && p.isActive)
        .toList();
    if (products.isEmpty) return const <DBProduct>[];

    final userLocation = _resolveCurrentUserLocation();
    if (userLocation == null || _storesForFastDelivery.isEmpty) {
      final tagged = products.where(_hasFastDeliveryTag).toList();
      return (tagged.isNotEmpty ? tagged : products).take(limit).toList();
    }

    final storeBySellerId = <String, Map<String, dynamic>>{};
    final storeByName = <String, Map<String, dynamic>>{};
    for (final store in _storesForFastDelivery) {
      final sellerId = (store['seller_id'] ?? '').toString().trim();
      if (sellerId.isNotEmpty) {
        storeBySellerId[sellerId] = store;
      }
      final name = (store['business_name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        storeByName[_normalizeText(name)] = store;
      }
    }

    final scored = <_FastDeliveryScore>[];
    for (final product in products) {
      final distance = _distanceToProductStoreKm(
        product,
        userLocation,
        storeBySellerId: storeBySellerId,
        storeByName: storeByName,
      );
      if (distance == null) continue;
      scored.add(
        _FastDeliveryScore(
          product: product,
          distanceKm: distance,
          hasFastTag: _hasFastDeliveryTag(product),
        ),
      );
    }

    if (scored.isEmpty) {
      final tagged = products.where(_hasFastDeliveryTag).toList();
      return (tagged.isNotEmpty ? tagged : products).take(limit).toList();
    }

    const nearbyRadiusKm = 20.0;
    final nearby = scored
        .where((item) => item.distanceKm <= nearbyRadiusKm)
        .toList();
    final source = nearby.isNotEmpty ? nearby : scored;
    source.sort((a, b) {
      if (a.hasFastTag != b.hasFastTag) {
        return b.hasFastTag ? 1 : -1;
      }
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return source.map((item) => item.product).take(limit).toList();
  }

  List<DBProduct> _getOpportunityProducts({int limit = 10}) {
    final products = _dbProducts
        .where((p) => p.imageUrl.isNotEmpty && p.isActive)
        .toList();
    if (products.isEmpty) return const <DBProduct>[];

    final scored = <_OpportunityScore>[];
    for (var index = 0; index < products.length; index++) {
      final product = products[index];
      final signal = _extractDiscountSignal(product);
      final hasTag = _hasOpportunityTag(product);
      if (!signal.hasDiscount && !hasTag) continue;

      final recencyScore = ((products.length - index) / products.length).clamp(
        0.0,
        1.0,
      );
      final score =
          (signal.rate * 0.70) +
          (recencyScore.toDouble() * 0.25) +
          (hasTag ? 0.05 : 0.0);

      scored.add(_OpportunityScore(product: product, score: score));
    }

    if (scored.isEmpty) {
      return products
          .where((p) => p.oldPrice?.isNotEmpty == true)
          .take(limit)
          .toList();
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((item) => item.product).take(limit).toList();
  }

  Future<void> _loadMainBanners() async {
    try {
      final banners = await _adminService.getCampaignImages();
      if (!mounted) return;
      final activeBanners = banners
          .where((b) => b['is_active'] == true)
          .toList(growable: false);
      setState(() {
        _mainBannerImages = activeBanners;
      });
      unawaited(_saveHomeBannersToCache(activeBanners));
    } catch (_) {}
  }

  String? _resolveBannerImagePath(
    Map<String, dynamic> banner, {
    bool preferMobile = false,
  }) {
    final imagePath = banner['image_path']?.toString().trim() ?? '';
    final mobileImagePath =
        banner['mobile_image_path']?.toString().trim() ?? '';
    final resolved = preferMobile
        ? (mobileImagePath.isNotEmpty ? mobileImagePath : imagePath)
        : (imagePath.isNotEmpty ? imagePath : mobileImagePath);
    if (resolved.isEmpty) {
      debugPrint(
        'HomeScreen: skipping banner with missing image path (${banner['id'] ?? 'unknown'}).',
      );
      return null;
    }
    return resolved;
  }

  Future<void> _loadAppFeatureCategories() async {
    try {
      final categories = await _adminService.getAppCategories();
      if (!mounted) return;
      final mapped = List<Map<String, dynamic>>.from(categories);
      setState(() {
        _appFeatureCategories = mapped;
      });
      unawaited(_saveHomeAppCategoriesToCache(mapped));
    } catch (_) {}
  }

  Future<void> _loadHairCareLayoutConfig() async {
    try {
      final layouts = await _adminService.getHairCareLayouts();

      // If layouts is empty, we must clear the state to reflect deletion
      if (layouts.isEmpty) {
        if (mounted) {
          setState(() {
            _hairCareBrandData = {};
            _hairCareLayoutsForHome = [];
          });
        }
        return;
      }

      // Her slot için ilk geçerli layout'u seç
      final usedSlots = <int>{};
      final effectiveLayouts = <Map<String, dynamic>>[];
      for (final layout in layouts) {
        final slotValue = layout['slot'];
        int? slot;
        if (slotValue is int) {
          slot = slotValue;
        } else if (slotValue is String) {
          slot = int.tryParse(slotValue);
        }
        if (slot == null || usedSlots.contains(slot)) continue;
        usedSlots.add(slot);
        effectiveLayouts.add(layout);
      }
      if (effectiveLayouts.isEmpty) return;

      final Map<String, dynamic> brandData = {};
      final storeNamesNeedingInfo = <String>{};
      for (final layout in effectiveLayouts) {
        List<Map<String, dynamic>> stores = [];
        final brandNameField = layout['brand_name'] as String?;
        final legacyStoreName = layout['store_name'] as String?;
        if (brandNameField != null && brandNameField.startsWith('%5B')) {
          try {
            final decoded = Uri.decodeComponent(brandNameField);
            final List<dynamic> jsonList = json.decode(decoded);
            stores = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
          } catch (_) {}
        }
        if (stores.isEmpty &&
            legacyStoreName != null &&
            legacyStoreName.isNotEmpty) {
          final names = legacyStoreName.split(',');
          for (final name in names) {
            if (name.trim().isNotEmpty) {
              stores.add({'business_name': name.trim()});
            }
          }
        }
        for (final storeInfo in stores) {
          final storeName = storeInfo['business_name'] as String?;
          final logoUrl = storeInfo['logo_url'] as String?;
          if (storeName != null &&
              storeName.isNotEmpty &&
              (logoUrl == null || logoUrl.isEmpty)) {
            storeNamesNeedingInfo.add(storeName);
          }
        }
      }
      final prefetchedStoreInfo = await _storeService
          .getStorePublicInfoByBusinessNames(
            storeNamesNeedingInfo.toList(growable: false),
          );

      for (final layout in effectiveLayouts) {
        // Parse multi-store data from brand_name (JSON)
        List<Map<String, dynamic>> stores = [];
        final brandNameField = layout['brand_name'] as String?;
        final legacyStoreName = layout['store_name'] as String?;

        if (brandNameField != null && brandNameField.startsWith('%5B')) {
          try {
            final decoded = Uri.decodeComponent(brandNameField);
            final List<dynamic> jsonList = json.decode(decoded);
            stores = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
          } catch (e) {
            debugPrint('Error parsing store JSON in Home: $e');
          }
        }

        // Fallback to legacy store_name if JSON parse failed or empty
        if (stores.isEmpty &&
            legacyStoreName != null &&
            legacyStoreName.isNotEmpty) {
          // It might be comma separated
          final names = legacyStoreName.split(',');
          for (var name in names) {
            if (name.trim().isNotEmpty) {
              stores.add({'business_name': name.trim()});
            }
          }
        }

        final productIdsRaw = layout['product_ids'];
        if (productIdsRaw == null) continue;
        final productIds = (productIdsRaw as List)
            .map((e) => e.toString())
            .toSet();

        // For each store in this layout, fetch/filter products and add to brandData
        for (final storeInfo in stores) {
          final storeName = storeInfo['business_name'] as String?;
          if (storeName == null || storeName.isEmpty) continue;

          final products = _dbProducts.where((p) {
            final pStore = (p.store ?? '').toLowerCase();
            final matchesStore = pStore == storeName.toLowerCase();
            final id = p.id?.toString() ?? '';
            return matchesStore && productIds.contains(id);
          }).toList();

          if (products.isEmpty) {
            // Even if no products, we might want to show the tab?
            // But logic below skips. Let's stick to skipping empty stores to avoid clutter.
            continue;
          }

          // Use logo from JSON if available, else fetch public info
          String logoUrl = storeInfo['logo_url'] as String? ?? '';
          List<String> adUrls = <String>[];

          if (logoUrl.isEmpty) {
            final publicInfo =
                prefetchedStoreInfo[storeName] ??
                await _storeService.getStorePublicInfoByBusinessName(storeName);
            if (publicInfo != null) {
              final lu = publicInfo['logoUrl'];
              if (lu is String) logoUrl = lu;
              final banners = publicInfo['banners'];
              if (banners is List) {
                adUrls = banners
                    .map((e) => e.toString())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
            }
          }

          final mappedProducts = products.take(10).map((p) {
            final images = <String>[];
            if (p.imageUrls != null && p.imageUrls!.isNotEmpty) {
              try {
                final decoded = json.decode(p.imageUrls!);
                if (decoded is List) {
                  images.addAll(decoded.map((e) => e.toString()));
                }
              } catch (_) {
                if (p.imageUrl.isNotEmpty) images.add(p.imageUrl);
              }
            } else if (p.imageUrl.isNotEmpty) {
              images.add(p.imageUrl);
            }

            return {
              'name': p.name,
              'price': p.price,
              'oldPrice': p.oldPrice,
              'rating': p.rating,
              'reviews': p.reviewCount,
              'tags': <String>[],
              'images': images,
              'image_url': p.imageUrl, // Fallback
              'brand': p.brand,
              'category': p.category,
              'sub_category': p.subCategory,
              'description': p.description,
              'store': p.store,
            };
          }).toList();

          brandData[storeName] = {
            'slot': layout['slot'],
            'title': layout['title'],
            'logo': logoUrl,
            'adUrls': adUrls,
            'products': mappedProducts,
          };
        }
      }

      if (!mounted) return;

      effectiveLayouts.sort((a, b) {
        final aSlot = a['slot'];
        final bSlot = b['slot'];
        int aInt = 0;
        int bInt = 0;
        if (aSlot is int) {
          aInt = aSlot;
        } else if (aSlot is String) {
          aInt = int.tryParse(aSlot) ?? 0;
        }
        if (bSlot is int) {
          bInt = bSlot;
        } else if (bSlot is String) {
          bInt = int.tryParse(bSlot) ?? 0;
        }
        return aInt.compareTo(bInt);
      });

      setState(() {
        _hairCareBrandData = brandData;
        _hairCareLayoutsForHome = List<Map<String, dynamic>>.from(
          effectiveLayouts,
        );
      });
    } catch (e) {
      debugPrint('Error loading hair care config: $e');
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
    return _dbProducts
        .map((dbProduct) => Product.fromDBProduct(dbProduct))
        .toList();
  }

  void _onSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(query: trimmed),
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
        {
          'name': 'Urban Care Hyaluronic',
          'price': '199.90 TL',
          'rating': 4.5,
          'reviews': 63,
          'tags': ['Hızlı Kargo', 'Ücretsiz Kargo'],
          'images': [''],
        },
        {
          'name': 'Urban Care Argan Oil',
          'price': '220.00 TL',
          'rating': 4.7,
          'reviews': 120,
          'tags': ['%30 indirim'],
          'images': [''],
        },
      ],
    },
    'Head & Shoulders': {
      'logo': 'assets/haircare/head&shoulderslogo.png',
      'adUrls': [
        'assets/haircare/head & shoulders reklam 1.png',
        'assets/haircare/head & shoulders reklam 2.png',
      ],
      'products': [
        {
          'name': 'Head & Shoulders Menthol',
          'price': '145.50 TL',
          'rating': 4.6,
          'reviews': 200,
          'tags': ['Hızlı Kargo'],
          'images': [''],
        },
      ],
    },
    'L\'Oreal': {
      'logo': 'assets/haircare/loreal logo.jpeg',
      'adUrls': ['assets/haircare/Lorel reklam.png'],
      'products': [],
    },
    'Elidor': {
      'logo': 'assets/haircare/elidorlogo.jpeg',
      'adUrls': ['assets/haircare/Elidor reklam.png'],
      'products': [],
    },
    'Dove': {
      'logo': 'assets/haircare/dove.png',
      'adUrls': ['assets/haircare/Dove reklam.png'],
      'products': [
        {
          'name': 'Dove Beauty Bar',
          'price': '50.00 TL',
          'rating': 4.8,
          'reviews': 500,
          'tags': ['Ücretsiz Kargo'],
          'images': [''],
        },
      ],
    },
    'Clear': {
      'logo': 'assets/haircare/clear.jpeg',
      'adUrls': [
        'assets/haircare/clear reklam 1.png',
        'assets/haircare/clear reklam 2.png',
      ],
      'products': [
        {
          'name': 'Clear Women Clarifying',
          'price': '92.50 TL',
          'rating': 4.3,
          'reviews': 456,
          'tags': ['%30 indirim'],
          'images': [''],
        },
      ],
    },
  };

  // Dummy Data for Tech Brand Section
  final Map<String, dynamic> _techBrandData = {
    'Apple': {
      'logo': '',
      'adUrls': <String>[],
      'products': [], // Veritabanından çekilecek
    },
    'Samsung': {'logo': '', 'adUrls': <String>[], 'products': []},
    'Dyson': {'logo': '', 'adUrls': <String>[], 'products': []},
    'Sony': {'logo': '', 'adUrls': <String>[], 'products': []},
    'Philips': {'logo': '', 'adUrls': <String>[], 'products': []},
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
                unselectedItemColor: Colors.black, // Black when unselected
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
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
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.primary, width: 2),
          ),
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

  Widget _buildHorizontalProductSkeletons({
    double height = 310,
    int itemCount = 3,
    double itemWidth = 200,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 4.0),
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            SizedBox(width: itemWidth, child: const ProductCardSkeleton()),
      ),
    );
  }

  Widget _buildHomeBannerSkeleton({required bool isWeb}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SkeletonLoading(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            borderRadius: isWeb ? 16 : 12,
          );
        },
      ),
    );
  }

  Widget _buildHomeView() {
    if (_errorMessage != null) {
      return CustomErrorView(message: _errorMessage, onRetry: _loadProducts);
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
                      _selectedSubCategory =
                          null; // Reset subcategory when main category changes
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
    final mobileBannerImages = _mainBannerImages
        .map((banner) => _resolveBannerImagePath(banner, preferMobile: true))
        .whereType<String>()
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<AppState>(
          builder: (context, appState, _) {
            return AddressBar(
              currentAddress: appState.currentDeliveryAddress ?? 'Adres Seçin',
              onAddressChanged: (newAddress) {
                appState.setCurrentDeliveryAddress(newAddress);
              },
            );
          },
        ),
        FeatureMenu(remoteCategories: _appFeatureCategories),

        const SizedBox(height: 8),
        // Banner Carousel
        if (_isLoadingHeroContent)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: SizedBox(
              height: 130,
              child: _buildHomeBannerSkeleton(isWeb: false),
            ),
          )
        else if (mobileBannerImages.isNotEmpty)
          CarouselSlider(
            options: CarouselOptions(
              aspectRatio:
                  1920 /
                  600, // 3.2 aspect ratio based on your uploaded image dimensions
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              enlargeCenterPage: true,
              viewportFraction:
                  0.95, // Increased fraction to show more of the banner
            ),
            items: mobileBannerImages.map((imagePath) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.symmetric(horizontal: 5.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildScaledHomeBannerImage(
                        imagePath,
                        errorWidget: Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),

        if (_isLoadingHeroContent || mobileBannerImages.isNotEmpty)
          const SizedBox(height: 12),

        const SponsoredProductListsSection(
          title: 'Öne Çıkan Listeler',
          subtitle: 'Ana sayfada sponsorlu olarak gösterilen ürün listeleri',
          placement: AdPlacement.homeFeed,
        ),

        const SizedBox(height: 20),

        // "Sana özel ürünler" section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<AppState>(
                builder: (context, appState, _) {
                  final user = appState.currentUser;
                  final fullName = UserIdentity.resolveDisplayName(
                    currentUser: user,
                  );
                  final firstName = fullName.split(' ').first;

                  return RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // Default color for text spans
                        fontFamily: 'Poppins',
                      ),
                      children: [
                        TextSpan(
                          text: firstName,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        TextSpan(
                          text: ', Sana Özel Ürünler',
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _isLoadingProducts
                  ? _buildHorizontalProductSkeletons()
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
                      height: 312,
                      child: Builder(
                        builder: (context) {
                          // Görseli olan ürünleri filtrele
                          var productsWithImages = _dbProducts
                              .where((p) => p.imageUrl.isNotEmpty)
                              .toList();

                          // Arçelik CT-Z3 ürününü kaldır (brand: Arçelik ve name: CT-Z3)
                          productsWithImages = productsWithImages.where((p) {
                            final nameLower = p.name.toLowerCase();
                            final brandLower = p.brand.toLowerCase();
                            // Brand Arçelik VE name CT-Z3/Infinity içeriyorsa filtrele
                            final isArcelikVacuum =
                                brandLower.contains('arçelik') &&
                                (nameLower.contains('ct-z3') ||
                                    nameLower.contains('infinity') ||
                                    nameLower.contains('2300'));
                            if (isArcelikVacuum) {}
                            return !isArcelikVacuum;
                          }).toList();

                          // Haylou Solar RT3 ürününü bul ve en sona taşı (brand: Haylou ve name: Solar)
                          final haylouIndex = productsWithImages.indexWhere((
                            p,
                          ) {
                            final nameLower = p.name.toLowerCase();
                            final brandLower = p.brand.toLowerCase();
                            return brandLower.contains('haylou') &&
                                nameLower.contains('solar');
                          });

                          if (haylouIndex != -1) {
                            final haylouProduct = productsWithImages.removeAt(
                              haylouIndex,
                            );
                            productsWithImages.add(haylouProduct);
                          }

                          // İlk 10 ürünü al
                          final displayProducts = productsWithImages
                              .take(10)
                              .toList();

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            cacheExtent: 500,
                            itemCount: displayProducts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final dbProduct = displayProducts[index];
                              return SizedBox(
                                width: 198,
                                child: ProductCard(
                                  product: _convertToProduct(dbProduct),
                                  margin: EdgeInsets.zero,
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

        // "Hızlı Teslimat" section (Mobil)
        _buildFastDeliverySection(),

        const SizedBox(height: 24),

        // Sistem Düzeni kartları (Yemekler, Teknoloji vb.) mobilde de alt alta
        if (_hairCareLayoutsForHome.isNotEmpty) ...[
          Column(
            children: _hairCareLayoutsForHome
                .map(
                  (layout) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: DynamicBrandSection(
                      layout: layout,
                      allProducts: _dbProducts,
                    ),
                  ),
                )
                .toList(),
          ),
        ],

        // "Fırsat Ürünler" section (Mobil)
        _buildOpportunityProductsSection(),

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
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              _isLoadingProducts
                  ? _buildHorizontalProductSkeletons()
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
                      height: 312,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            cacheExtent: 500,
                            itemCount: productsWithImages.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final dbProduct = productsWithImages[index];
                              return SizedBox(
                                width: 198,
                                child: ProductCard(
                                  product: _convertToProduct(dbProduct),
                                  margin: EdgeInsets.zero,
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
    final displayProducts = _getProductsForCurrentSubCategory();

    final sameDayProducts = displayProducts
        .where(
          (p) =>
              p.tags.contains('Hızlı Teslimat') ||
              p.tags.contains('Hızlı Kargo') ||
              p.tags.contains('Yakın Lokasyon'),
        )
        .take(10)
        .toList();

    final Map<String, List<String>> displayFilters = {};
    _standardFilters.forEach((key, value) {
      // "Telefonlar" dışındaki kategorilerde "Kategori" ve "Marka" altı boş olsun
      if ((key == 'Kategori' || key == 'Marka') &&
          _selectedSubCategory != 'Telefonlar') {
        displayFilters[key] = [];
      } else {
        displayFilters[key] = value;
      }
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar
        // Use ConstrainedBox or SizedBox to ensure width, but let height be determined by content
        // Since FilterSidebar now uses shrinkWrap ListView, it will take the height of its content.
        // And since it's in a Row with CrossAxisAlignment.start, it won't stretch vertically unless we tell it to.
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 500,
          ), // Min height to match grid roughly
          child: FilterSidebar(
            key: ValueKey(
              _selectedSubCategory,
            ), // Force rebuild when subcategory changes
            filters: displayFilters,
            onFilterChanged: (category, option, isSelected) {},
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Önerilen Sıralama',
                          style: TextStyle(fontSize: 14),
                        ),
                        Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // "Bugün Kapında" Alanı
              if (sameDayProducts.isNotEmpty &&
                  (_selectedSubCategory == 'Telefonlar' ||
                      _selectedSubCategory == 'Telefon'))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50, // Mavi arka plan
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade200,
                    ), // Mavi kenarlık
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Bugün Kapında',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue, // Mavi metin
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
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 290,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: sameDayProducts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: 160,
                              child: ProductCard(
                                product: _convertToProduct(
                                  sameDayProducts[index],
                                ),
                                compact: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              displayProducts.isEmpty
                  ? _isLoadingProducts
                        ? _buildHorizontalProductSkeletons(
                            height: 312,
                            itemWidth: 198,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          )
                        : const Center(
                            child: Text("Bu kategoride ürün bulunamadı."),
                          )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            250, // Kartların aşırı genişlemesini önlemek için max genişlik
                        childAspectRatio:
                            0.65, // Oranı artırarak kart yüksekliğini azalttık (Boşlukları kapatmak için)
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: displayProducts.length > 8
                          ? 8
                          : displayProducts.length, // Limit for demo
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
  void _showAddressSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<AppState>(
          builder: (context, appState, _) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Teslimat Adresini Seçin'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (appState.deliveryAddresses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Henüz kayıtlı adresiniz yok.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...appState.deliveryAddresses.map(
                      (addr) =>
                          _buildAddressOption(addr['title']!, addr['detail']!),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add, color: AppColors.primary),
                      title: const Text(
                        'Yeni Adres Ekle',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddAddressDialog();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AddressEditSheet(
            type: 'Adres',
            onSave: (Map<String, String> newAddress) async {
              final appState = context.read<AppState>();
              await appState.addDeliveryAddress(newAddress);

              // Yeni eklenen adresi seçili yap
              if (newAddress['detail'] != null) {
                appState.setCurrentDeliveryAddress(newAddress['detail']!);
              }
            },
            onDelete: () {}, // No delete action needed for new address creation
          ),
        ),
      ),
    );
  }

  Widget _buildAddressOption(String title, String address) {
    return ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(address),
      onTap: () {
        context.read<AppState>().setCurrentDeliveryAddress(address);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildWebHomeContent() {
    final isElectronics = _selectedCategory == 'Elektronik';
    final isHomePage = _selectedCategory == 'Ana Sayfa';
    final isCategorySelected = !isHomePage; // Herhangi bir kategori seçili mi?

    // Popüler ürünleri kategoriye göre filtrele
    final popularProducts = isHomePage
        ? _dbProducts
        : _dbProducts
              .where(
                (p) =>
                    p.category == _selectedCategory ||
                    p.category.contains(_selectedCategory),
              )
              .toList();
    final fastDeliveryProducts = isHomePage
        ? _getFastDeliveryProducts(limit: 10)
        : <DBProduct>[];
    final opportunityProducts = isHomePage
        ? _getOpportunityProducts(limit: 10)
        : <DBProduct>[];

    final bannerImages = _mainBannerImages
        .map((banner) => _resolveBannerImagePath(banner))
        .whereType<String>()
        .toList(growable: false);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
          ), // Increased horizontal padding
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
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isLoadingProducts
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: 10,
                          itemBuilder: (context, index) {
                            return const ProductCardSkeleton();
                          },
                        )
                      : popularProducts.isEmpty
                      ? SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bu kategoride henüz ürün bulunamadı',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 0.58,
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
                Consumer<AppState>(
                  builder: (context, appState, _) {
                    final currentAddress =
                        appState.currentDeliveryAddress ??
                        'Teslimat Adresi Seçin';
                    return Container(
                      width: double.infinity,
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Teslimat Adresi:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _showAddressSelectionDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              backgroundColor: AppColors.primary.withOpacity(
                                0.08,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.edit_location_alt_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Değiştir',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 1. Kategoriler / Fırsat İkonları
                _buildOpportunityCards(),

                const SizedBox(height: 24),

                // 2. İkili Büyük Banner Alanı
                SizedBox(
                  height: 412,
                  child: Row(
                    children: [
                      // Sol: Kampanya Slider
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              // Use _isLoadingHeroContent (banners+categories done) not
                              // _isLoadingHomeSections (stores+layouts done).  The banner
                              // has no dependency on stores or hair-care layouts, and those
                              // deferred queries finish 300-600 ms later — holding the
                              // biggest above-fold element as a skeleton for no reason.
                              if (_isLoadingHeroContent)
                                _buildHomeBannerSkeleton(isWeb: true)
                              else if (bannerImages.isNotEmpty)
                                CarouselSlider(
                                  options: CarouselOptions(
                                    aspectRatio:
                                        1920 /
                                        600, // Correct aspect ratio for web banners
                                    height:
                                        412, // Reduced height to align with right column (250 + 12 + 150)
                                    viewportFraction: 1.0,
                                    autoPlay: true,
                                    autoPlayInterval: const Duration(
                                      seconds: 6,
                                    ),
                                    autoPlayAnimationDuration: const Duration(
                                      milliseconds: 1000,
                                    ),
                                  ),
                                  items: bannerImages.map((i) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return Container(
                                          width: MediaQuery.of(
                                            context,
                                          ).size.width,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF0F0F0),
                                          ),
                                          child: _buildScaledHomeBannerImage(
                                            i,
                                            errorWidget: Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.image_not_supported,
                                                      size: 64,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Kampanya Görseli',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                )
                              else
                                Container(
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.campaign_outlined,
                                          size: 64,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Henüz kampanya bulunmuyor',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade500,
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

                      const SizedBox(width: 24),

                      // Sağ: Günün Fırsatı ve Kuponlar
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // Günün Fırsatı
                            SizedBox(
                              height: 250, // Reverted to original height
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary.withOpacity(0.06),
                                      Colors.white,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(
                                        0.08,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: _isLoadingProducts
                                          ? const ProductCardSkeleton()
                                          : popularProducts.isNotEmpty
                                          ? DealOfTheDaySlider(
                                              products: popularProducts,
                                            )
                                          : const SizedBox(),
                                    ),
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF9800),
                                              AppColors.primary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flash_on,
                                              color: Colors.white,
                                              size: 16,
                                            ),
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
                            const SizedBox(height: 12), // Consistent spacing
                            // Kuponlar
                            SizedBox(
                              height: 150, // Reduced height as requested
                              child: CouponSlider(
                                isLoading: _isLoadingHomeSections,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 2.5 Yakın Lokasyon Alanı
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF0FF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFB9DFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9E7FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.near_me_outlined,
                              color: Color(0xFF2891F1),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Yakın Lokasyon ile çevrendeki mağazalardan alışveriş yapabilirsin',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF7A8A99),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2891F1),
                              borderRadius: BorderRadius.circular(999),
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
                                  'Yakın Lokasyon',
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
                      const SizedBox(height: 18),
                      // Yatay Liste
                      (_isLoadingProducts || _isLoadingHomeSections)
                          ? _buildHorizontalProductSkeletons(
                              height: 312,
                              itemWidth: 198,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            )
                          : fastDeliveryProducts.isNotEmpty
                          ? SizedBox(
                              height: 312,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.mouse,
                                          },
                                        ),
                                    child: ListView.separated(
                                      controller:
                                          _todayProductsScrollController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      itemCount: fastDeliveryProducts.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 20),
                                      itemBuilder: (context, index) {
                                        final dbProduct =
                                            fastDeliveryProducts[index];
                                        return SizedBox(
                                          width: 198,
                                          child: ProductCard(
                                            product: _convertToProduct(
                                              dbProduct,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Sol Ok
                                  Positioned(
                                    left: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_back_ios_new,
                                        color: const Color(0xFF2891F1),
                                        onTap: () => _scrollCarousel(
                                          _todayProductsScrollController,
                                          -300,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Sağ Ok
                                  Positioned(
                                    right: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_forward_ios,
                                        color: const Color(0xFF2891F1),
                                        onTap: () => _scrollCarousel(
                                          _todayProductsScrollController,
                                          300,
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

                const SponsoredProductListsSection(
                  title: 'Ana Sayfada Öne Çıkan Listeler',
                  subtitle:
                      'Liste reklamı verilen koleksiyonlar burada sponsorlu gösterilir.',
                  placement: AdPlacement.homeFeed,
                ),

                const SizedBox(height: 32),

                // 3. Popüler Ürünler Başlığı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Popüler Ürünler',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Tümünü Gör',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Popüler Ürünler Listesi (Yatay Kaydırılabilir)
                _isLoadingProducts
                    ? _buildHorizontalProductSkeletons(
                        height: 312,
                        itemWidth: 198,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      )
                    : popularProducts.isEmpty
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bu kategoride ürün bulunamadı',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 312,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                              child: ListView.separated(
                                controller: _popularProductsScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                itemCount: popularProducts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 20),
                                itemBuilder: (context, index) {
                                  final dbProduct = popularProducts[index];
                                  return SizedBox(
                                    width: 198,
                                    child: ProductCard(
                                      product: _convertToProduct(dbProduct),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Sol Ok
                            Positioned(
                              left: -6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildCarouselArrowButton(
                                  icon: Icons.arrow_back_ios_new,
                                  color: AppColors.primary,
                                  onTap: () => _scrollCarousel(
                                    _popularProductsScrollController,
                                    -300,
                                  ),
                                ),
                              ),
                            ),
                            // Sağ Ok
                            Positioned(
                              right: -6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildCarouselArrowButton(
                                  icon: Icons.arrow_forward_ios,
                                  color: AppColors.primary,
                                  onTap: () => _scrollCarousel(
                                    _popularProductsScrollController,
                                    300,
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
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFF0EE),
                        const Color(0xFFFFF8F7),
                        const Color(0xFFFFF0EE),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF4D2CE)),
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
                            child: const Icon(
                              Icons.flash_on,
                              color: Colors.red,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flaş Ürünler',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Kaçırılmayacak fırsatlar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
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
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Sınırlı Süre',
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
                      // Grid yerine Yatay Liste
                      _isLoadingProducts
                          ? _buildHorizontalProductSkeletons(
                              height: 312,
                              itemWidth: 198,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            )
                          : opportunityProducts.isNotEmpty
                          ? SizedBox(
                              height: 312,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.mouse,
                                          },
                                        ),
                                    child: ListView.separated(
                                      controller:
                                          _flashProductsScrollController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      itemCount: opportunityProducts.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 20),
                                      itemBuilder: (context, index) {
                                        final dbProduct =
                                            opportunityProducts[index];
                                        return SizedBox(
                                          width: 198,
                                          child: ProductCard(
                                            product: _convertToProduct(
                                              dbProduct,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Sol Ok
                                  Positioned(
                                    left: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_back_ios_new,
                                        color: AppColors.primary,
                                        onTap: () => _scrollCarousel(
                                          _flashProductsScrollController,
                                          -300,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Sağ Ok
                                  Positioned(
                                    right: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_forward_ios,
                                        color: AppColors.primary,
                                        onTap: () => _scrollCarousel(
                                          _flashProductsScrollController,
                                          300,
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

                // Neden iBul? Bölümü
                _buildWhyIbulSection(),

                // Sistem Düzeni kartları: Neden iBul'un altında alt alta
                if (_hairCareLayoutsForHome.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Column(
                    children: _hairCareLayoutsForHome
                        .map(
                          (layout) => Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: DynamicBrandSection(
                              layout: layout,
                              allProducts: _dbProducts,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 40),
                ],

                // Avantaj Çubuğu (En Alta Taşındı)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.05),
                        Colors.white,
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTrustItem(
                        Icons.local_shipping_outlined,
                        'Ücretsiz Kargo',
                        '150 TL üzeri',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.verified_user_outlined,
                        'Güvenli Ödeme',
                        '256-bit SSL',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.replay_outlined,
                        '14 Gün İade',
                        'Koşulsuz iade',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.support_agent_outlined,
                        '7/24 Destek',
                        'Canlı yardım',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.workspace_premium_outlined,
                        'Orijinal Ürün',
                        'Garantili',
                      ),
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

  Widget _buildScaledHomeBannerImage(
    String imagePath, {
    required Widget errorWidget,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaQuery.size.width;
        final targetWidth = (logicalWidth * mediaQuery.devicePixelRatio)
            .round()
            .clamp(640, 1600);
        final targetHeight = (targetWidth / (1920 / 600)).round().clamp(
          200,
          600,
        );

        return OptimizedImage(
          imageUrlOrPath: imagePath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          cacheWidth: targetWidth,
          cacheHeight: targetHeight,
          errorWidget: errorWidget,
        );
      },
    );
  }

  Product _convertToProduct(DBProduct dbProduct) {
    final cacheKey = dbProduct.id?.trim();
    final cachedProduct = cacheKey != null && cacheKey.isNotEmpty
        ? _productConversionCache[cacheKey]
        : null;
    if (cachedProduct != null) {
      return cachedProduct;
    }

    // Görselleri parse et
    List<String> images = [];
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        if (dbProduct.imageUrl.isNotEmpty) images.add(dbProduct.imageUrl);
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }

    final product = Product(
      productId: dbProduct.id,
      name: dbProduct.name,
      price: dbProduct.price,
      oldPrice: dbProduct.oldPrice,
      images: images.isEmpty ? [] : images,
      category: dbProduct.category,
      brand: dbProduct.brand,
      description: dbProduct.description,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: dbProduct.tags.isNotEmpty
          ? List<String>.from(json.decode(dbProduct.tags))
          : [],
      subCategory: dbProduct.subCategory,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
    );

    if (cacheKey != null && cacheKey.isNotEmpty) {
      _productConversionCache[cacheKey] = product;
    }
    return product;
  }

  Widget _buildHairCareSection() {
    if (_hairCareBrandData.isNotEmpty && _hairCareSelectedBrand != null) {
      final title = _hairCareTitle ?? 'Bakımlı Saçlar';
      return BrandSection(
        title: title,
        selectedBrand: _hairCareSelectedBrand!,
        brands: _hairCareBrandData.keys.toList(),
        brandData: _hairCareBrandData.map((key, value) {
          final v = value as Map<String, dynamic>;
          return MapEntry(key, {
            'logo': v['logo'],
            'adUrls': v['adUrls'],
            'products': v['products'],
          });
        }),
        onBrandSelected: (brand) {
          setState(() {
            _hairCareSelectedBrand = brand;
          });
        },
        pinActionsBottom: true,
        tightCards: true,
        listHeight: 264,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHairCareBlock() {
    if (_hairCareBrandData.isEmpty || _hairCareSelectedBrand == null) {
      return const SizedBox.shrink();
    }
    return Container(
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
    );
  }

  // Hızlı Teslimat Section (Mobil)
  Widget _buildFastDeliverySection() {
    final fastDeliveryProducts = _getFastDeliveryProducts(limit: 10);
    final isLoading = _isLoadingProducts || _isLoadingHomeSections;

    return Container(
      color: const Color(0xFFE3F2FD), // Mavi arka plan
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hızlı Teslimat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Çevrenizdeki mağazalardan hızlı alışveriş',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Hızlı Teslimat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 312,
            child: isLoading
                ? _buildHorizontalProductSkeletons()
                : fastDeliveryProducts.isEmpty
                ? const Center(child: Text('Hızlı teslimat ürünü bulunamadı'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemCount: fastDeliveryProducts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final dbProduct = fastDeliveryProducts[index];
                      return SizedBox(
                        width: 198,
                        child: ProductCard(
                          product: _convertToProduct(dbProduct),
                          margin: EdgeInsets.zero,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Fırsat Ürünler Section (Mobil)
  Widget _buildOpportunityProductsSection() {
    final opportunityProducts = _getOpportunityProducts(limit: 10);

    return Container(
      color: const Color(0xFFFFEBEE), // Kırmızı arka plan
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fırsat Ürünler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kaçırılmayacak fırsatlar',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_offer, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Fırsat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 312,
            child: _isLoadingProducts
                ? _buildHorizontalProductSkeletons()
                : opportunityProducts.isEmpty
                ? const Center(child: Text('Fırsat ürünü bulunamadı'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemCount: opportunityProducts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final dbProduct = opportunityProducts[index];
                      return SizedBox(
                        width: 198,
                        child: ProductCard(
                          product: _convertToProduct(dbProduct),
                          margin: EdgeInsets.zero,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
          {
            'icon': Icons.speaker_group,
            'title': 'Oto Ses & Görüntü Sistemleri',
          },
          {'icon': Icons.settings, 'title': 'Oto Yedek Parça'},
          {'icon': Icons.cleaning_services, 'title': 'Araç Bakım & Temizlik'},
          {
            'icon': Icons.car_repair,
            'title': 'Oto Aksesuar (Paspas, Silecek vb.)',
          },
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
          {
            'icon': Icons.music_note,
            'title': 'Müzik Enstrümanları ve Ekipmanları',
          },
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
          {
            'icon': Icons.fitness_center,
            'title': 'Fitness & Kondisyon Ürünleri',
          },
          {
            'icon': Icons.sports_basketball,
            'title': 'Spor Branşları (Basketbol, Futbol vb.)',
          },
          {'icon': Icons.cabin, 'title': 'Kamp & Kampçılık'},
          {'icon': Icons.directions_bike, 'title': 'Bisiklet'},
          {
            'icon': Icons.electric_scooter,
            'title': 'Elektrikli Scooter, Paten & Kaykay',
          },
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
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                          child: Icon(
                            item['icon'] as IconData,
                            color: AppColors.primary,
                            size: 28,
                          ),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustDivider() {
    return Container(width: 1, height: 28, color: Colors.grey[200]);
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
        'desc':
            'Aynı ürünü farklı satıcılarda karşılaştır, en uygun fiyatı yakala.',
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
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
                        child: Icon(
                          item['icon'] as IconData,
                          color: item['color'] as Color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['desc'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
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

  // Mobil Kategori Barı (Web'deki gibi)
  Widget _buildMobileCategoryBar() {
    final categories = defaultMobileCategoryNamesExcluding(
      excludedNames: const {'Yakın Lokasyon'},
    );

    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 24),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _selectedSubCategory = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: isSelected
                    ? const Border(
                        bottom: BorderSide(color: AppColors.primary, width: 2),
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : Colors.grey[800],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Mobil Alt Kategori Barı (Seçili kategoriye göre)
  Widget _buildMobileSubCategoryBar() {
    final seed = findDefaultMobileCategorySeed(_selectedCategory);
    final subCategories = seed?.subCategories ?? const <MobileCategorySeed>[];

    if (subCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Alt Kategoriler',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: subCategories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final subCat = subCategories[index];
                final isSelected = _selectedSubCategory == subCat.name;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSubCategory = subCat.name;
                    });
                  },
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          iconDataForCategoryName(subCat.iconName),
                          size: 28,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey[700],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subCat.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _scrollCarousel(ScrollController controller, double delta) {
    if (!controller.hasClients) return;

    final targetOffset = (controller.offset + delta).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );

    controller.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCarouselArrowButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _GeoPoint {
  const _GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class _FastDeliveryScore {
  const _FastDeliveryScore({
    required this.product,
    required this.distanceKm,
    required this.hasFastTag,
  });

  final DBProduct product;
  final double distanceKm;
  final bool hasFastTag;
}

class _DiscountSignal {
  const _DiscountSignal({required this.rate, required this.hasDiscount});

  final double rate;
  final bool hasDiscount;
}

class _OpportunityScore {
  const _OpportunityScore({required this.product, required this.score});

  final DBProduct product;
  final double score;
}

class CouponSlider extends StatefulWidget {
  final bool isLoading;

  const CouponSlider({super.key, this.isLoading = false});

  @override
  State<CouponSlider> createState() => _CouponSliderState();
}

class _CouponSliderState extends State<CouponSlider> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  final Set<int> _usedCoupons = {};

  final List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.7);
    if (_coupons.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTimer();
      });
    }
  }

  void _startTimer() {
    if (_coupons.isEmpty) return;

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
    if (widget.isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                SkeletonLoading(width: 18, height: 18, borderRadius: 9),
                SizedBox(width: 8),
                SkeletonLoading(width: 72, height: 14, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SkeletonLoading(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    borderRadius: 12,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (_coupons.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Kupon bulunmuyor',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
            padding: const EdgeInsets.only(left: 12, top: 12, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Kuponlar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
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
                                color: (coupon['color'][0] as Color)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                coupon['icon'] as IconData,
                                color: coupon['color'][0] as Color,
                                size: 20,
                              ),
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
                                      content: Text(
                                        'Bu kupon zaten tanımlandı!',
                                      ),
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
                                    content: Text(
                                      '${coupon['title']} kuponu hesabınıza tanımlandı!',
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _usedCoupons.contains(index)
                                      ? Colors.grey
                                      : (coupon['color'][0] as Color),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_usedCoupons.contains(index)
                                                  ? Colors.grey
                                                  : coupon['color'][0] as Color)
                                              .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _usedCoupons.contains(index)
                                      ? 'KULLANILDI'
                                      : 'KULLAN',
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
            double price = double.parse(
              product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            double oldPrice = double.parse(
              product.oldPrice!.replaceAll(RegExp(r'[^0-9.]'), ''),
            );
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
                builder: (context) =>
                    ProductDetailPage(product: Product.fromDBProduct(product)),
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
                // Görsel Alanı - Fixed height instead of Expanded
                SizedBox(
                  height: 140, // Fixed height for image area
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: OptimizedImage(
                            imageUrlOrPath: product.imageUrl,
                            fit: BoxFit.contain,
                            cacheWidth: 300,
                            cacheHeight: 200,
                            errorWidget: const Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      if (discountRate != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
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
