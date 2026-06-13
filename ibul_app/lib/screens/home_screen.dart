import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:flutter/gestures.dart'; // Scroll behavior için eklendi
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/auth/user_identity.dart';
import '../ads/enums/ad_enums.dart';
import '../core/constants.dart';
import '../core/app_motion.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../core/app_state.dart';
import '../core/review_state.dart';
import '../utils/log_mask_helpers.dart';
import '../widgets/custom_header.dart';
import '../widgets/web_header.dart'; // Web Header eklendi
import '../widgets/web_sticky_footer_scroll_view.dart';
import '../widgets/filter_sidebar.dart'; // Filter Sidebar eklendi
import '../widgets/address_bar.dart';
import '../widgets/address_edit_sheet.dart';
import '../widgets/feature_menu.dart';
import '../widgets/product_card.dart';
import '../widgets/brand_section.dart';
import '../widgets/optimized_image.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/common/custom_error_view.dart';
import '../core/app_image_cdn.dart';
import '../core/qr_initial_params.dart';
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
part 'home_screen_sections.dart';

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
  static const double _homeBannerAspectRatio = 1920 / 600;
  late final ValueNotifier<int> _selectedIndexNotifier;
  late String _selectedCategory; // Seçili kategori
  String? _selectedSubCategory; // Seçili alt kategori
  final AppState _appState = AppState();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<DBProduct> _dbProducts = [];
  bool _isLoadingProducts = true;
  bool _isLoadingHeroContent = true;
  bool _isLoadingHomeSections = true;
  bool _deferredHomeSectionsEnabled = false;
  bool _deferredHomeSectionsScheduled = false;
  String? _errorMessage;
  late AnimationController _spinController;
  late final ValueNotifier<bool> _hasSpunWheelNotifier;
  final ScrollController _popularProductsScrollController = ScrollController();
  final ScrollController _subCategoryScrollController = ScrollController();
  final ScrollController _flashProductsScrollController = ScrollController();
  final ScrollController _todayProductsScrollController = ScrollController();

  final AdminService _adminService = AdminService();
  final StoreService _storeService = StoreService();
  List<Map<String, dynamic>> _hairCareLayoutsForHome = [];
  // List<Map<String, dynamic>> for campaign images
  List<Map<String, dynamic>> _mainBannerImages = [];
  List<Map<String, dynamic>> _appFeatureCategories = [];
  List<Map<String, dynamic>> _storesForFastDelivery = [];
  final Map<String, Product> _productConversionCache = {};
  int _productDataVersion = 0;
  int _bannerDataVersion = 0;
  int _fastDeliveryStoreVersion = 0;
  String? _cachedResolvedBannerImagesKey;
  List<String>? _cachedResolvedBannerImages;
  String? _cachedResolvedMobileBannerImagesKey;
  List<String>? _cachedResolvedMobileBannerImages;
  String? _cachedFeaturedHomeProductsKey;
  List<DBProduct>? _cachedFeaturedHomeProducts;
  String? _cachedRecentHomeProductsKey;
  List<DBProduct>? _cachedRecentHomeProducts;
  String? _cachedPopularProductsKey;
  List<DBProduct>? _cachedPopularProducts;
  String? _cachedSubCategoryProductsKey;
  List<DBProduct>? _cachedSubCategoryProducts;
  String? _cachedFastDeliveryProductsKey;
  List<DBProduct>? _cachedFastDeliveryProducts;
  String? _cachedOpportunityProductsKey;
  List<DBProduct>? _cachedOpportunityProducts;
  String? _scheduledAboveFoldPrecacheKey;
  bool _tableQrHandled = false;
  /// Set to true the moment QR intent is confirmed so that concurrent home-init
  /// callbacks (deferred loads, cache writes, setState chains) cannot visually
  /// override or interfere with the QR navigation that follows.
  bool _hasHandledQrIntent = false;
  int _homeLoadGeneration = 0;

  int get _selectedIndex => _selectedIndexNotifier.value;
  set _selectedIndex(int value) => _selectedIndexNotifier.value = value;

  bool get _hasSpunWheel => _hasSpunWheelNotifier.value;
  set _hasSpunWheel(bool value) => _hasSpunWheelNotifier.value = value;

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
    debugPrint('[HomeScreen] initState — mounting fresh HomeScreen. '
        'QrInitialParams.everConsumed=${QrInitialParams.everConsumed} '
        'isQrPath=${QrInitialParams.isQrPath} '
        'wasResetAfterQrExit=${QrInitialParams.wasResetAfterQrExit}');
    _selectedIndexNotifier = ValueNotifier(widget.initialIndex);
    _hasSpunWheelNotifier = ValueNotifier(false);
    _spinController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(); // Sürekli dön

    _selectedCategory = widget.initialCategory ?? 'Ana Sayfa';
    _appState.cartCountNotifier.value = _appState.cart.length;
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[HomeScreen] first frame — calling _handleTableQrLaunch');
      _handleTableQrLaunch();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _popularProductsScrollController.dispose();
    _flashProductsScrollController.dispose();
    _todayProductsScrollController.dispose();
    _selectedIndexNotifier.dispose();
    _hasSpunWheelNotifier.dispose();
    super.dispose();
  }

  List<String> _resolvedBannerImages({required bool preferMobile}) {
    final cacheKey = '$_bannerDataVersion|$preferMobile';
    if (preferMobile) {
      if (_cachedResolvedMobileBannerImagesKey == cacheKey &&
          _cachedResolvedMobileBannerImages != null) {
        return _cachedResolvedMobileBannerImages!;
      }
    } else {
      if (_cachedResolvedBannerImagesKey == cacheKey &&
          _cachedResolvedBannerImages != null) {
        return _cachedResolvedBannerImages!;
      }
    }

    final resolved = _mainBannerImages
        .map(
          (banner) =>
              _resolveBannerImagePath(banner, preferMobile: preferMobile),
        )
        .whereType<String>()
        .toList(growable: false);

    if (preferMobile) {
      _cachedResolvedMobileBannerImagesKey = cacheKey;
      _cachedResolvedMobileBannerImages = resolved;
    } else {
      _cachedResolvedBannerImagesKey = cacheKey;
      _cachedResolvedBannerImages = resolved;
    }

    return resolved;
  }

  String? _resolvePrimaryHomeProductImagePath(DBProduct product) {
    // Resolve raw URL then apply CDN card variant (420×420 @ q75) for precache.
    String raw = '';
    final rawImageUrls = product.imageUrls?.trim();
    if (rawImageUrls != null && rawImageUrls.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawImageUrls);
        if (decoded is List) {
          for (final item in decoded) {
            final imagePath = item.toString().trim();
            if (imagePath.isNotEmpty) {
              raw = imagePath;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (raw.isEmpty) raw = product.imageUrl.trim();
    if (raw.isEmpty) raw = product.thumbnailPublicUrl?.trim() ?? '';
    if (raw.isEmpty) return null;

    return AppImageCdn.buildUrl(raw, AppImageVariant.card);
  }

  ImageProvider<Object>? _buildSizedPrecacheProvider(
    String imagePath, {
    required int cacheWidth,
    required int cacheHeight,
  }) {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty) return null;
    return OptimizedImage.buildProvider(
      imageUrlOrPath: normalizedPath,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  Future<void> _precacheAboveFoldImages({
    required String? bannerImagePath,
    required int bannerCacheWidth,
    required int bannerCacheHeight,
    required List<String> productImagePaths,
    required int productCacheWidth,
    required int productCacheHeight,
  }) async {
    if (!mounted) return;

    Future<void> precachePath(
      String imagePath, {
      required int cacheWidth,
      required int cacheHeight,
    }) async {
      final provider = _buildSizedPrecacheProvider(
        imagePath,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
      if (provider == null || !mounted) return;

      try {
        await precacheImage(provider, context);
      } catch (error) {
        debugPrint('Ana sayfa görsel preload başarısız: $error');
      }
    }

    if (bannerImagePath != null && bannerImagePath.trim().isNotEmpty) {
      await precachePath(
        bannerImagePath,
        cacheWidth: bannerCacheWidth,
        cacheHeight: bannerCacheHeight,
      );
    }

    for (final imagePath in productImagePaths) {
      if (!mounted) return;
      await precachePath(
        imagePath,
        cacheWidth: productCacheWidth,
        cacheHeight: productCacheHeight,
      );
    }
  }

  void _scheduleAboveFoldImagePrecache({
    required bool isWeb,
    required List<String> bannerImages,
    required List<DBProduct> firstRailProducts,
  }) {
    if (!mounted || _selectedIndex != 0) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;

    final firstBannerImage = bannerImages.isEmpty
        ? null
        : AppImageCdn.buildUrl(bannerImages.first, AppImageVariant.hero);
    final visibleProductImagePaths = firstRailProducts
        .map(_resolvePrimaryHomeProductImagePath)
        .whereType<String>()
        .take(isWeb ? 4 : 3)
        .toList(growable: false);

    if ((firstBannerImage == null || firstBannerImage.trim().isEmpty) &&
        visibleProductImagePaths.isEmpty) {
      return;
    }

    final cacheKey = [
      isWeb ? 'web' : 'mobile',
      ...?(firstBannerImage == null ? null : <String>[firstBannerImage]),
      ...visibleProductImagePaths,
    ].join('|');
    if (_scheduledAboveFoldPrecacheKey == cacheKey) return;
    _scheduledAboveFoldPrecacheKey = cacheKey;

    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final bannerLogicalWidth = isWeb
        ? math.min(mediaQuery.size.width, 1400.0) * 0.72
        : mediaQuery.size.width * 0.95;
    final bannerCacheWidth = (bannerLogicalWidth * devicePixelRatio)
        .round()
        .clamp(640, 1200);
    final bannerCacheHeight = (bannerCacheWidth / _homeBannerAspectRatio)
        .round()
        .clamp(120, 600);
    final productCacheWidth = (198 * devicePixelRatio).round().clamp(160, 520);
    final productCacheHeight = (155 * devicePixelRatio).round().clamp(160, 520);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduledAboveFoldPrecacheKey != cacheKey) return;
      unawaited(
        _precacheAboveFoldImages(
          bannerImagePath: firstBannerImage,
          bannerCacheWidth: bannerCacheWidth,
          bannerCacheHeight: bannerCacheHeight,
          productImagePaths: visibleProductImagePaths,
          productCacheWidth: productCacheWidth,
          productCacheHeight: productCacheHeight,
        ),
      );
    });
  }

  String _productRevealTokenFromDb(DBProduct product) {
    final productId = product.id?.trim();
    if (productId != null && productId.isNotEmpty) {
      return productId;
    }

    final store = product.store?.trim() ?? '';
    return '${product.name.trim()}|$store';
  }

  Widget _wrapProductReveal({
    required String scope,
    required int index,
    required String token,
    required Widget child,
  }) {
    return StaggeredReveal(
      revealId: '$scope|$token',
      index: index,
      enabled: index < 8,
      child: child,
    );
  }

  List<DBProduct> _featuredHomeProducts() {
    final cacheKey = '$_productDataVersion';
    if (_cachedFeaturedHomeProductsKey == cacheKey &&
        _cachedFeaturedHomeProducts != null) {
      return _cachedFeaturedHomeProducts!;
    }

    var productsWithImages = _dbProducts
        .where((p) => p.imageUrl.isNotEmpty)
        .toList(growable: false);

    productsWithImages = productsWithImages
        .where((p) {
          final nameLower = p.name.toLowerCase();
          final brandLower = p.brand.toLowerCase();
          final isArcelikVacuum =
              brandLower.contains('arçelik') &&
              (nameLower.contains('ct-z3') ||
                  nameLower.contains('infinity') ||
                  nameLower.contains('2300'));
          return !isArcelikVacuum;
        })
        .toList(growable: false);

    final reordered = List<DBProduct>.from(productsWithImages);
    final haylouIndex = reordered.indexWhere((p) {
      final nameLower = p.name.toLowerCase();
      final brandLower = p.brand.toLowerCase();
      return brandLower.contains('haylou') && nameLower.contains('solar');
    });

    if (haylouIndex != -1) {
      final haylouProduct = reordered.removeAt(haylouIndex);
      reordered.add(haylouProduct);
    }

    final resolved = reordered.take(10).toList(growable: false);
    _cachedFeaturedHomeProductsKey = cacheKey;
    _cachedFeaturedHomeProducts = resolved;
    return resolved;
  }

  List<DBProduct> _recentHomeProducts() {
    if (!_deferredHomeSectionsEnabled) {
      return const <DBProduct>[];
    }

    final cacheKey = '$_productDataVersion';
    if (_cachedRecentHomeProductsKey == cacheKey &&
        _cachedRecentHomeProducts != null) {
      return _cachedRecentHomeProducts!;
    }

    final resolved = _dbProducts
        .where((p) => p.imageUrl.isNotEmpty)
        .skip(10)
        .take(10)
        .toList(growable: false);
    _cachedRecentHomeProductsKey = cacheKey;
    _cachedRecentHomeProducts = resolved;
    return resolved;
  }

  List<DBProduct> _popularProductsForSelectedCategory() {
    final cacheKey = '$_productDataVersion|$_selectedCategory';
    if (_cachedPopularProductsKey == cacheKey &&
        _cachedPopularProducts != null) {
      return _cachedPopularProducts!;
    }

    final resolved = _selectedCategory == 'Ana Sayfa'
        ? List<DBProduct>.unmodifiable(_dbProducts)
        : _dbProducts
              .where(
                (p) =>
                    p.category == _selectedCategory ||
                    p.category.contains(_selectedCategory),
              )
              .toList(growable: false);

    _cachedPopularProductsKey = cacheKey;
    _cachedPopularProducts = resolved;
    return resolved;
  }

  List<DBProduct> _getProductsForCurrentSubCategory() {
    if (_selectedSubCategory == null) {
      return [];
    }

    final cacheKey =
        '$_productDataVersion|$_selectedCategory|${_selectedSubCategory ?? ''}';
    if (_cachedSubCategoryProductsKey == cacheKey &&
        _cachedSubCategoryProducts != null) {
      return _cachedSubCategoryProducts!;
    }

    final selectedMainCategory = _normalizeText(_selectedCategory);
    final selectedSub = _normalizeText(_selectedSubCategory!);

    final baseProducts = _dbProducts.where((p) {
      final category = _normalizeText(p.category);
      return category == selectedMainCategory;
    }).toList();

    final resolved = baseProducts
        .where((p) {
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

            if (selectedSub.contains('laptop') ||
                selectedSub.contains('tablet')) {
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

            if (selectedSub.contains('isitma') ||
                selectedSub.contains('sogutma')) {
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
        })
        .toList(growable: false);

    _cachedSubCategoryProductsKey = cacheKey;
    _cachedSubCategoryProducts = resolved;
    return resolved;
  }

  Future<void> _handleTableQrLaunch() async {
    if (_tableQrHandled || !mounted) return;
    _tableQrHandled = true;
    debugPrint(
      '[QR-Bootstrap] START — source=HomeScreen '
      'tableQrHandled=$_tableQrHandled ${QrInitialParams.debugState}',
    );

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

    // PRIMARY: Use params captured at startup (before any Flutter navigation or
    // auth could overwrite window.location.href / Uri.base).
    // FALLBACK: Re-read Uri.base live (handles hot-reload or unusual startup paths).
    final params = <String, String>{
      ...QrInitialParams.consume(source: 'HomeScreen'),
    };
    if (params.isEmpty) {
      if (QrInitialParams.shouldSkipHomeBootstrap) {
        debugPrint(
          '[QR-Bootstrap] SKIPPED — source=HomeScreen '
          'reason=consumed-or-reset ${QrInitialParams.debugState}',
        );
        return;
      }
      // Fallback path — capture live Uri.base in case the startup capture
      // was skipped (non-web, test environment, etc.).
      final uri = Uri.base;
      debugPrint('[QR] startup params empty — falling back to live Uri.base = $uri');
      debugPrint('[QR] uri.queryParameters = ${uri.queryParameters}');
      debugPrint('[QR] uri.fragment        = ${uri.fragment}');
      params.addAll(uri.queryParameters);
      final fragment = uri.fragment;
      final queryIndex = fragment.indexOf('?');
      if (queryIndex >= 0 && queryIndex + 1 < fragment.length) {
        try {
          params.addAll(Uri.splitQueryString(fragment.substring(queryIndex + 1)));
        } catch (_) {}
      }
    } else {
      debugPrint('[QR] Using startup-captured params (Uri.base immune to routing changes).');
    }
    debugPrint('[QR] merged params = $params');

    // Detect QR intent: any non-empty table_qr value OR explicit seller+table combo.
    final hasQrIntent =
        (params['table_qr'] ?? '').trim().isNotEmpty ||
        ((params['seller'] ?? '').trim().isNotEmpty &&
            (params['table'] ?? '').trim().isNotEmpty);
    debugPrint('[QR] hasQrIntent = $hasQrIntent');
    if (!hasQrIntent) {
      debugPrint(
        '[QR-Bootstrap] SKIPPED — source=HomeScreen reason=no-qr-intent '
        'params=$params ${QrInitialParams.debugState}',
      );
      debugPrint('[QR] No QR intent detected — returning early.');
      return;
    }

    // Lock the flag immediately so that any concurrent home-init callbacks
    // (cache reads, deferred loads, setState chains) that are still in-flight
    // will bail out and not override the upcoming QR navigation.
    _hasHandledQrIntent = true;
    debugPrint('QR HANDLED: table_qr detected, blocking home init overrides.');

    final sellerId = firstNonEmptyParam(params, [
      'seller',
      'seller_id',
      'store',
      'store_seller',
    ]);
    // 'table_qr' carries the table number when no separate 'table' param exists.
    final tableRaw = firstNonEmptyParam(params, [
      'table',
      'table_number',
      'tableNo',
      'masa',
      'table_qr', // fallback: the table_qr value itself is the table number
    ]);
    final tableNumber = parseTableNumber(tableRaw);
    final token = firstNonEmptyParam(params, ['token', 'qr_token', 'qr', 't']);

    if (kDebugMode) {
      debugPrint('[QR] sellerId    = $sellerId');
      debugPrint('[QR] tableRaw    = $tableRaw');
      debugPrint('[QR] tableNumber = $tableNumber');
      debugPrint('[QR] token       = ${maskSensitiveToken(token)}');
    }

    if (sellerId.isEmpty) {
      const msg = 'QR bağlantısı eksik: seller parametresi bulunamadı.';
      debugPrint('[QR] ERROR: $msg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            duration: Duration(seconds: 6),
          ),
        );
      }
      return;
    }

    var qrVerified = false;
    try {
      if (kDebugMode) {
        debugPrint(
          '[QR] Calling resolveStoreTableQr: sellerId=$sellerId tableNumber=$tableNumber token=${maskSensitiveToken(token)}',
        );
      }
      // QR doğrulama ve mağaza sorgusunu paralel yap → daha hızlı açılış.
      final futures = await Future.wait<Object?>([
        (token.isNotEmpty && tableNumber != null && tableNumber > 0)
            ? _storeService.resolveStoreTableQr(
                sellerId: sellerId,
                tableNumber: tableNumber,
                qrToken: token,
              )
            : Future<Map<String, dynamic>?>.value(null),
        _storeService.getBusinessSummaryBySellerId(sellerId),
      ]);
      final resolvedTable = futures[0] as Map<String, dynamic>?;
      debugPrint('[QR] resolveStoreTableQr result = $resolvedTable');

      qrVerified = token.isNotEmpty && resolvedTable != null;
      debugPrint('[QR] qrVerified = $qrVerified');

      var business = futures[1] as Map<String, dynamic>?;
      debugPrint('[QR] getBusinessSummaryBySellerId result = $business');
      if (business == null) {
        debugPrint('[QR] Seller not found by ID — trying by business name...');
        business = await _storeService.getBusinessSummaryByBusinessName(sellerId);
        debugPrint('[QR] getBusinessSummaryByBusinessName result = $business');
      }
      if (!mounted || business == null) {
        final msg = 'Bu QR için mağaza bulunamadı. seller=$sellerId';
        debugPrint('[QR] ERROR: $msg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return;
      }
      final resolvedBusiness = business;
      debugPrint('[QR] resolved business = $resolvedBusiness');

      if (mounted && !qrVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR doğrulanamadı: sadece menü önizleme. Sipariş garson onayıyla açılır.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      debugPrint(
        '[QR] Pushing BusinessDetailPage — business=${resolvedBusiness["name"]} '
        'table=$tableNumber verified=$qrVerified',
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessDetailPage(
            business: resolvedBusiness,
            forceTableSelection: true,
            initialTableNumber: tableNumber,
            fromQr: true,
            unverifiedQrTableFlow: !qrVerified,
          ),
        ),
      );
      debugPrint('[QR] BusinessDetailPage pushed successfully.');
    } catch (error, stack) {
      debugPrint('[QR] EXCEPTION in QR flow: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR açılamadı: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    final loadGeneration = ++_homeLoadGeneration;

    setState(() {
      _isLoadingProducts = true;
      _isLoadingHeroContent = true;
      _isLoadingHomeSections = true;
      _deferredHomeSectionsEnabled = false;
      _deferredHomeSectionsScheduled = false;
      _errorMessage = null;
      _productConversionCache.clear();
    });

    final cachedProductsFuture = _loadCachedHomeProducts();
    final cachedHeroFuture = _loadCachedHomeHeroContent();
    unawaited(_loadImmediateHomeContent());
    await Future.wait<void>([cachedProductsFuture, cachedHeroFuture]);
    _scheduleDeferredHomeContentLoad(loadGeneration);

    try {
      final supabaseProducts = await SupabaseService.instance
          .getInitialHomeProducts();

      if (supabaseProducts.isNotEmpty) {
        _dbProducts = supabaseProducts;
        _productDataVersion++;
        _warmHomeProductRatings(_dbProducts);
        unawaited(_saveHomeProductsToCache(_dbProducts));
        debugPrint('✅ Supabase: ${_dbProducts.length} ürün yüklendi');
      } else if (_dbProducts.isEmpty) {
        await _dbHelper.initializeDatabase();
        _dbProducts = await _dbHelper.getProductsPage(
          limit: SupabaseService.homePageSize,
        );
        _productDataVersion++;
        _warmHomeProductRatings(_dbProducts);
        debugPrint('✅ Local DB: ${_dbProducts.length} ürün yüklendi');
      } else {
        _productDataVersion++;
        _warmHomeProductRatings(_dbProducts);
        debugPrint(
          '⚠️ Supabase boş döndü; önbellekteki ${_dbProducts.length} ürün korunuyor.',
        );
      }

      final withImages = _dbProducts.where((p) => p.imageUrl.isNotEmpty).length;
      debugPrint(
        '📸 Görseli olan ürün sayısı: $withImages/${_dbProducts.length}',
      );
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

  void _scheduleDeferredHomeContentLoad(int loadGeneration) {
    if (_deferredHomeSectionsScheduled) return;
    _deferredHomeSectionsScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 180), () async {
        if (!mounted || loadGeneration != _homeLoadGeneration) return;
        if (_hasHandledQrIntent) {
          debugPrint('HOME INIT BLOCKED: deferred section load skipped (QR active).');
          return;
        }
        if (!_deferredHomeSectionsEnabled) {
          setState(() {
            _deferredHomeSectionsEnabled = true;
          });
        }
        await _loadDeferredHomeContent();
      });
    });
  }

  Future<void> _loadImmediateHomeContent() async {
    if (_hasHandledQrIntent) {
      debugPrint('HOME INIT BLOCKED: immediate home content skipped (QR active).');
      return;
    }
    try {
      await Future.wait([_loadMainBanners(), _loadAppFeatureCategories()]);
    } catch (e) {
      debugPrint('Ana sayfa üst içerikleri yüklenemedi: $e');
    } finally {
      if (mounted && !_hasHandledQrIntent) {
        setState(() {
          _isLoadingHeroContent = false;
        });
      }
    }
  }

  Future<void> _loadDeferredHomeContent() async {
    if (_hasHandledQrIntent) {
      debugPrint('HOME INIT BLOCKED: deferred home content skipped (QR active).');
      return;
    }
    try {
      await Future.wait([
        _loadStoreDirectoryForFastDelivery(),
        _loadHairCareLayoutConfig(),
      ]);
    } catch (e) {
      debugPrint('Ana sayfa yardımcı içerikleri yüklenemedi: $e');
    } finally {
      if (mounted && !_hasHandledQrIntent) {
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
      if (_hasHandledQrIntent) {
        debugPrint('HOME INIT BLOCKED: cached products setState skipped (QR active).');
        return;
      }

      setState(() {
        _dbProducts = cachedProducts;
        _isLoadingProducts = false;
        _productConversionCache.clear();
        _productDataVersion++;
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
      if (_hasHandledQrIntent) {
        debugPrint('HOME INIT BLOCKED: cached hero content setState skipped (QR active).');
        return;
      }

      setState(() {
        if (cachedBanners.isNotEmpty) {
          _mainBannerImages = cachedBanners;
          _bannerDataVersion++;
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
        _fastDeliveryStoreVersion++;
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
    if (!_deferredHomeSectionsEnabled) {
      return const <DBProduct>[];
    }

    final currentAddress = _appState.currentDeliveryAddress ?? '';
    final cacheKey =
        '$_productDataVersion|$_fastDeliveryStoreVersion|$currentAddress|$limit';
    if (_cachedFastDeliveryProductsKey == cacheKey &&
        _cachedFastDeliveryProducts != null) {
      return _cachedFastDeliveryProducts!;
    }

    final products = _dbProducts
        .where((p) => p.imageUrl.isNotEmpty && p.isActive)
        .toList();
    if (products.isEmpty) return const <DBProduct>[];

    final userLocation = _resolveCurrentUserLocation();
    if (userLocation == null || _storesForFastDelivery.isEmpty) {
      final tagged = products.where(_hasFastDeliveryTag).toList();
      final resolved = (tagged.isNotEmpty ? tagged : products)
          .take(limit)
          .toList();
      _cachedFastDeliveryProductsKey = cacheKey;
      _cachedFastDeliveryProducts = resolved;
      return resolved;
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
      final resolved = (tagged.isNotEmpty ? tagged : products)
          .take(limit)
          .toList();
      _cachedFastDeliveryProductsKey = cacheKey;
      _cachedFastDeliveryProducts = resolved;
      return resolved;
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

    final resolved = source
        .map((item) => item.product)
        .take(limit)
        .toList(growable: false);
    _cachedFastDeliveryProductsKey = cacheKey;
    _cachedFastDeliveryProducts = resolved;
    return resolved;
  }

  List<DBProduct> _getOpportunityProducts({int limit = 10}) {
    if (!_deferredHomeSectionsEnabled) {
      return const <DBProduct>[];
    }

    final cacheKey = '$_productDataVersion|$limit';
    if (_cachedOpportunityProductsKey == cacheKey &&
        _cachedOpportunityProducts != null) {
      return _cachedOpportunityProducts!;
    }

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
      final withOldPrice = products
          .where((p) => p.oldPrice?.isNotEmpty == true)
          .take(limit)
          .toList(growable: false);
      final resolved = withOldPrice.isNotEmpty
          ? withOldPrice
          : products.take(limit).toList(growable: false);
      _cachedOpportunityProductsKey = cacheKey;
      _cachedOpportunityProducts = resolved;
      return resolved;
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final resolved = scored
        .map((item) => item.product)
        .take(limit)
        .toList(growable: false);
    _cachedOpportunityProductsKey = cacheKey;
    _cachedOpportunityProducts = resolved;
    return resolved;
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
        _bannerDataVersion++;
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
    _selectedIndex = index;
  }

  void _setSelectedCategory(String category) {
    if (_selectedCategory == category && _selectedSubCategory == null) {
      return;
    }
    setState(() {
      _selectedCategory = category;
      _selectedSubCategory = null;
    });
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
              child: ValueListenableBuilder<int>(
                valueListenable: _selectedIndexNotifier,
                builder: (context, selectedIndex, _) {
                  return BottomNavigationBar(
                    currentIndex: selectedIndex,
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
                        icon: const Icon(Icons.segment),
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
                  );
                },
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
            showAppDialog<void>(
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

    return ListenableBuilder(
      listenable: Listenable.merge([
        _selectedIndexNotifier,
        _hasSpunWheelNotifier,
      ]),
      builder: (context, _) {
        // Mobil için Çark (Sadece Ana Sayfada ve henüz çevrilmediyse)
        if (_selectedIndex != 0 || _hasSpunWheel) {
          return const SizedBox.shrink();
        }

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
              showAppDialog<void>(
                context: context,
                barrierColor: Colors.black54,
                builder: (context) => FortuneWheelDialog(
                  onSpinComplete: () {
                    _hasSpunWheel = true;
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
      },
    );
  }

  Widget _buildCurrentPageForIndex(int selectedIndex) {
    switch (selectedIndex) {
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

  Widget _buildCurrentPage() {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedIndexNotifier,
      builder: (context, selectedIndex, _) {
        return AppAnimatedIndexedStack(
          index: selectedIndex,
          children: List<Widget>.generate(5, _buildCurrentPageForIndex),
        );
      },
    );
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

  Widget _buildHomeView() => _buildHomeViewImpl();

  // --- MOBİL GÖRÜNÜM (Eski Kod) ---
  Widget _buildMobileHomeContent() => _buildMobileHomeContentImpl();

  Widget _buildSubCategoryView() => _buildSubCategoryViewImpl();

  // --- WEB GÖRÜNÜM (Yeni Tasarım) ---
  void _showAddressSelectionDialog() {
    showAppDialog<void>(
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
    showAppDialog<void>(
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

  Widget _buildWebHomeContent() => _buildWebHomeContentImpl();

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
          imageUrlOrPath: AppImageCdn.buildUrl(imagePath, AppImageVariant.hero),
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

    final product = Product.fromDBProduct(dbProduct);

    if (cacheKey != null && cacheKey.isNotEmpty) {
      _productConversionCache[cacheKey] = product;
    }
    return product;
  }


  Widget _buildTechSection() {
    return _LocalBrandSection(
      title: 'Teknoloji Dünyası',
      initialBrand: 'Apple',
      brands: _techBrandData.keys.toList(),
      brandData: _techBrandData,
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
            AppColors.primary.withValues(alpha: 0.03),
            Colors.white,
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
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
                        color: (item['color'] as Color).withValues(alpha: 0.1),
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
                          color: (item['color'] as Color).withValues(alpha: 0.1),
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
      shadowColor: Colors.black.withValues(alpha: 0.12),
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

class _LocalBrandSection extends StatefulWidget {
  const _LocalBrandSection({
    required this.title,
    required this.initialBrand,
    required this.brands,
    required this.brandData,
  });

  final String title;
  final String initialBrand;
  final List<String> brands;
  final Map<String, dynamic> brandData;

  @override
  State<_LocalBrandSection> createState() => _LocalBrandSectionState();
}

class _LocalBrandSectionState extends State<_LocalBrandSection> {
  late String _selectedBrand;

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialBrand;
  }

  @override
  void didUpdateWidget(covariant _LocalBrandSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.brands.contains(_selectedBrand) && widget.brands.isNotEmpty) {
      _selectedBrand = widget.brands.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrandSection(
      title: widget.title,
      selectedBrand: _selectedBrand,
      brands: widget.brands,
      brandData: widget.brandData,
      onBrandSelected: (brand) {
        if (_selectedBrand == brand) return;
        setState(() {
          _selectedBrand = brand;
        });
      },
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                                    .withValues(alpha: 0.1),
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
                                              .withValues(alpha: 0.3),
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
                  color: Colors.black.withValues(alpha: 0.08),
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
                            imageUrlOrPath: AppImageCdn.buildUrl(
                              product.imageUrl,
                              AppImageVariant.card,
                            ),
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
                              color: AppColors.primary.withValues(alpha: 0.1),
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
