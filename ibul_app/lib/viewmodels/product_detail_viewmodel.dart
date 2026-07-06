import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/product_cart_identity.dart';
import '../core/product_purchasability_helper.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../services/database_helper.dart';
import '../services/review_repository.dart';
import '../services/store_service.dart';
import '../services/cart_validation_service.dart';
import '../services/supabase_service.dart';
import '../utils/product_visibility_helper.dart';

class ProductDetailViewModel extends ChangeNotifier {
  Product initialProduct;
  final AppState appState;
  final String openSource;
  late ReviewSummary _reviewSummary;
  String? _storeLogoUrl;

  // State variables
  int currentImageIndex = 0;
  int selectedTabIndex = 0;
  bool isFavorite = false;
  bool isBookmarked = false;
  bool isFollowing = false;

  // Product variant selections
  final Map<String, List<String>> variantOptions = {};
  final Map<String, String> selectedVariants = {};
  final Set<String> selectedAttributes = {};

  // Variant system
  List<Product> groupVariants = [];
  List<DBProduct> groupVariantDbProducts = [];
  bool loadingVariants = false;
  final Map<String, Set<String>> allAvailableOptions = {};

  // Other stores products
  List<Map<String, dynamic>> otherStoresWithProducts = [];
  bool loadingOtherStores = false;

  // Similar products
  List<Product> similarProducts = [];
  bool loadingSimilarProducts = false;

  // Complementary products (Combination)
  List<Product> complementaryProducts = [];
  bool loadingComplementary = false;

  // Cart & Delivery
  bool isAddedToCart = false;
  bool isWarrantyAdded = false;
  bool isFastDeliverySelected = false;
  bool isAddToCartInProgress = false;
  int? _catalogStock;
  String? _matchBarcode;
  String? _matchModelCode;

  int _detailLoadGeneration = 0;

  // Selected spare parts for damaged/second-hand products
  List<Product> selectedParts = [];

  void setSelectedParts(List<Product> parts) {
    selectedParts = List<Product>.from(parts);
    notifyListeners();
  }

  final List<String> tabs = [
    'Ürün Açıklaması',
    'Yakın Lokasyon',
    'Ürün Özellikleri',
  ];

  ProductDetailViewModel({
    required this.initialProduct,
    required this.appState,
    this.openSource = 'product_detail',
  }) {
    final localReviews = List<Map<String, dynamic>>.unmodifiable(
      appState.getProductReviewsFor(
        productName: initialProduct.name,
        storeName: initialProduct.store,
      ),
    );
    _reviewSummary = ReviewRepository.instance.getInitialProductReviewSummary(
      productName: initialProduct.name,
      storeName: initialProduct.store,
      localReviews: localReviews,
      fallbackRating: initialProduct.rating,
      fallbackCount: initialProduct.reviewCount,
    );
    _init();
  }

  void _init() {
    appState.addRecentlyViewedProduct(
      initialProduct,
      source: openSource,
    );
    _parseVariantOptions();
    _syncSelectedVariantsFromStructuredVariants();
    isFavorite = appState.isFavorite(initialProduct);
    isAddedToCart = appState.isInCart(initialProduct);

    // Initialize fast delivery state from app state logic or default
    if (appState.hasFastDelivery(initialProduct)) {
      isFastDeliverySelected = true;
    }

    if (isAddedToCart) {
      try {
        final cartProduct = appState.cart.firstWhere(
          (p) =>
              p.name == initialProduct.name && p.brand == initialProduct.brand,
        );
        if (cartProduct.selectedServices.isNotEmpty) {
          if (cartProduct.selectedServices.any(
            (s) => s.contains('GARANTİ') || s.contains('MONTAJ'),
          )) {
            isWarrantyAdded = true;
          }
          if (cartProduct.selectedServices.contains('Hızlı Kargo')) {
            isFastDeliverySelected = true;
          }
        }
      } catch (_) {}
    }

    final generation = ++_detailLoadGeneration;
    unawaited(_refreshProductExtrasFromSupabase(generation));
    unawaited(refreshReviewSummary());
    unawaited(loadStoreLogo());
    unawaited(_loadDeferredSections(generation));
  }

  Future<void> _loadDeferredSections(int generation) async {
    await Future<void>.delayed(Duration.zero);
    if (generation != _detailLoadGeneration) return;

    unawaited(_loadOtherStoresWithProducts(generation));
    unawaited(_loadVariantGroupData(generation));
    unawaited(_loadSimilarProducts(generation));
  }

  ReviewSummary get reviewSummary => _reviewSummary;

  String get storeName =>
      initialProduct.store?.trim().isNotEmpty == true
      ? initialProduct.store!.trim()
      : initialProduct.brand.trim();

  String? get storeLogoUrl => _storeLogoUrl;

  Future<void> refreshReviewSummary() async {
    final localReviews = appState.getProductReviewsFor(
      productName: initialProduct.name,
      storeName: initialProduct.store,
    );
    final summary = await ReviewRepository.instance.getProductReviewSummary(
      productName: initialProduct.name,
      storeName: initialProduct.store,
      localReviews: localReviews,
    );

    final summaryChanged =
        _reviewSummary.reviewCount != summary.reviewCount ||
        _reviewSummary.averageRating != summary.averageRating ||
        _reviewSummary.reviews.length != summary.reviews.length;
    final productChanged =
        initialProduct.rating != summary.averageRating ||
        initialProduct.reviewCount != summary.reviewCount;

    if (!summaryChanged && !productChanged) {
      return;
    }

    _reviewSummary = summary;
    if (productChanged) {
      initialProduct = initialProduct.copyWith(
        rating: summary.averageRating,
        reviewCount: summary.reviewCount,
      );
    }
    notifyListeners();
  }

  Future<void> loadStoreLogo() async {
    if (_storeLogoUrl != null) return;

    var logoUrl = '';
    final sellerId = initialProduct.sellerId?.trim() ?? '';
    if (sellerId.isNotEmpty) {
      final info = await StoreService().getStorePublicInfoById(sellerId);
      logoUrl = info?['logoUrl']?.toString().trim() ?? '';
    }

    if (logoUrl.isEmpty) {
      final resolvedStoreName = storeName.trim();
      if (resolvedStoreName.isNotEmpty) {
        final info = await StoreService().getStorePublicInfoByBusinessName(
          resolvedStoreName,
        );
        logoUrl = info?['logoUrl']?.toString().trim() ?? '';
      }
    }

    _storeLogoUrl = logoUrl.isEmpty ? '' : logoUrl;
    notifyListeners();
  }

  void toggleAttribute(String value) {
    if (selectedAttributes.contains(value)) {
      selectedAttributes.remove(value);
    } else {
      selectedAttributes.add(value);
    }
    notifyListeners();
  }

  Future<void> _refreshProductExtrasFromSupabase(int generation) async {
    try {
      final extras = await SupabaseService.instance
          .getProductExtrasByNameBrand(
            name: initialProduct.name,
            brand: initialProduct.brand,
          )
          .timeout(const Duration(seconds: 12));
      if (extras == null || generation != _detailLoadGeneration) return;

      _catalogStock = (extras['stock'] as num?)?.toInt();
      _matchBarcode = ProductVisibilityHelper.catalogBarcode(extras);
      _matchModelCode = ProductVisibilityHelper.catalogModelCode(extras);
      final resolvedGroupId =
          extras['variant_group_id']?.toString().trim() ?? '';
      if (resolvedGroupId.isNotEmpty &&
          (initialProduct.variantGroupId == null ||
              initialProduct.variantGroupId!.isEmpty)) {
        initialProduct = initialProduct.copyWith(
          variantGroupId: resolvedGroupId,
        );
      }

      final videoUrl = extras['video_url']?.toString();
      final videoPath = extras['video_path']?.toString();
      final videoPublicUrl = extras['video_public_url']?.toString();
      final thumbnailPath = extras['thumbnail_path']?.toString();
      final thumbnailPublicUrl = extras['thumbnail_public_url']?.toString();
      final videoDurationSeconds = (extras['video_duration_seconds'] as num?)
          ?.toInt();
      final videoSizeBytes = (extras['video_size_bytes'] as num?)?.toInt();
      final thumbnailSizeBytes = (extras['thumbnail_size_bytes'] as num?)
          ?.toInt();
      final videoStatus = extras['video_status']?.toString();
      final variantsRaw = extras['variants'];
      List<dynamic>? variants;
      if (variantsRaw is List) {
        variants = variantsRaw;
      } else if (variantsRaw is String && variantsRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(variantsRaw);
          if (decoded is List) variants = decoded;
        } catch (_) {}
      }

      List<String>? attributes;
      final attrs = extras['attributes'];
      if (attrs is List) {
        attributes = attrs.map((e) => e.toString()).toList();
      } else if (attrs is String && attrs.isNotEmpty) {
        try {
          final decoded = jsonDecode(attrs);
          if (decoded is List) {
            attributes = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      final additionalInfo = extras['additional_info']?.toString();
      List<String>? accessories;
      final rawAccessories = extras['accessories'];
      if (rawAccessories is List) {
        accessories = rawAccessories.map((e) => e.toString()).toList();
      } else if (rawAccessories is String && rawAccessories.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawAccessories);
          if (decoded is List) {
            accessories = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      List<Map<String, String>>? faq;
      try {
        final rawFaq = extras['faq'];
        if (rawFaq is List) {
          faq = rawFaq.map((e) => Map<String, String>.from(e as Map)).toList();
        }
      } catch (_) {}

      initialProduct = initialProduct.copyWith(
        videoUrl: (videoPublicUrl != null && videoPublicUrl.trim().isNotEmpty)
            ? videoPublicUrl
            : (videoUrl != null && videoUrl.trim().isNotEmpty)
            ? videoUrl
            : null,
        videoPath: (videoPath != null && videoPath.trim().isNotEmpty)
            ? videoPath
            : initialProduct.videoPath,
        videoPublicUrl:
            (videoPublicUrl != null && videoPublicUrl.trim().isNotEmpty)
            ? videoPublicUrl
            : initialProduct.videoPublicUrl,
        thumbnailPath:
            (thumbnailPath != null && thumbnailPath.trim().isNotEmpty)
            ? thumbnailPath
            : initialProduct.thumbnailPath,
        thumbnailPublicUrl:
            (thumbnailPublicUrl != null && thumbnailPublicUrl.trim().isNotEmpty)
            ? thumbnailPublicUrl
            : initialProduct.thumbnailPublicUrl,
        videoDurationSeconds:
            videoDurationSeconds ?? initialProduct.videoDurationSeconds,
        videoSizeBytes: videoSizeBytes ?? initialProduct.videoSizeBytes,
        thumbnailSizeBytes:
            thumbnailSizeBytes ?? initialProduct.thumbnailSizeBytes,
        videoStatus: (videoStatus != null && videoStatus.trim().isNotEmpty)
            ? videoStatus
            : initialProduct.videoStatus,
        variants: variants ?? initialProduct.variants,
        attributes: attributes ?? initialProduct.attributes,
        accessories: accessories ?? initialProduct.accessories,
        additionalInfo:
            (additionalInfo != null && additionalInfo.trim().isNotEmpty)
            ? additionalInfo
            : initialProduct.additionalInfo,
        faq: faq ?? initialProduct.faq,
      );
      _syncSelectedVariantsFromStructuredVariants();
      await _loadComplementaryProducts(generation);
      if (generation == _detailLoadGeneration) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadComplementaryProducts([int? generation]) async {
    final activeGeneration = generation ?? _detailLoadGeneration;
    loadingComplementary = true;
    notifyListeners();

    try {
      var accessoryIds = List<String>.from(initialProduct.accessories ?? const []);

      final currentProductId = initialProduct.productId?.trim() ?? '';
      accessoryIds = accessoryIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .where((id) => currentProductId.isEmpty || id != currentProductId)
          .toList(growable: false);

      if (accessoryIds.isEmpty) {
        complementaryProducts = const [];
        return;
      }

      final linkedProducts = await SupabaseService.instance
          .getProductsByIds(accessoryIds)
          .timeout(const Duration(seconds: 12));
      if (activeGeneration != _detailLoadGeneration) return;

      complementaryProducts = linkedProducts
          .map((product) => Product.fromDBProduct(product))
          .where(
            (product) =>
                currentProductId.isEmpty || product.productId != currentProductId,
          )
          .take(8)
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error loading complementary products: $e');
      complementaryProducts = const [];
    } finally {
      if (activeGeneration == _detailLoadGeneration) {
        loadingComplementary = false;
        notifyListeners();
      }
    }
  }

  void addCombinationToCart() async {
    final error = await addToCart();
    if (error != null) return;

    for (var product in complementaryProducts) {
      await appState.addToCart(product);
    }

    notifyListeners();
  }

  Future<void> _loadSimilarProducts(int generation) async {
    loadingSimilarProducts = true;
    notifyListeners();

    try {
      final results = await SupabaseService.instance
          .getSimilarPublicProducts(
            excludeProductId: initialProduct.productId ?? '',
            productName: initialProduct.name,
            brand: initialProduct.brand,
            mainCategory: initialProduct.category,
            subCategory: initialProduct.subCategory,
            limit: 12,
          )
          .timeout(const Duration(seconds: 12));
      if (generation != _detailLoadGeneration) return;

      similarProducts = results
          .map((dbProduct) => Product.fromDBProduct(dbProduct))
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error loading similar products: $e');
      similarProducts = const [];
    } finally {
      if (generation == _detailLoadGeneration) {
        loadingSimilarProducts = false;
        notifyListeners();
      }
    }
  }

  // Image Navigation Methods
  void updateImageIndex(int index) {
    currentImageIndex = index;
    notifyListeners();
  }

  void nextImage() {
    if (images.isEmpty) return;
    if (currentImageIndex < images.length - 1) {
      currentImageIndex++;
    } else {
      currentImageIndex = 0; // Loop back to start
    }
    notifyListeners();
  }

  void prevImage() {
    if (images.isEmpty) return;
    if (currentImageIndex > 0) {
      currentImageIndex--;
    } else {
      currentImageIndex = images.length - 1; // Loop to end
    }
    notifyListeners();
  }

  // Helper to get all displayable images - Already defined below, so we use that one or remove this if redundant.
  // But wait, the previous `get images` was at the bottom.
  // Let's remove the duplicate definition I added earlier.

  void updateTabIndex(int index) {
    selectedTabIndex = index;
    notifyListeners();
  }

  String getTabContentText() {
    switch (selectedTabIndex) {
      case 0:
        return initialProduct.getDisplayDescription();
      case 1:
        return 'Yakınınızdaki mağazalarda bu ürünü bulabilirsiniz. Harita üzerinden en yakın satış noktalarını görebilirsiniz.';
      case 2:
        return initialProduct.getDisplaySpecs();
      case 3:
        return 'Bu ürünü parçalara ayırarak satın alabilirsiniz. Detaylı bilgi için parçalama seçeneklerini inceleyebilirsiniz.';
      default:
        return '';
    }
  }

  void toggleFavorite() {
    appState.toggleFavorite(initialProduct);
    isFavorite = appState.isFavorite(initialProduct);
    notifyListeners();
  }

  void toggleBookmark() {
    isBookmarked = !isBookmarked;
    notifyListeners();
  }

  void addProductToList(int listId) {
    appState.addProductToUserList(listId, initialProduct);
    // Automatically bookmark when added to a list if not already
    if (!isBookmarked) {
      isBookmarked = true;
      notifyListeners();
    }
  }

  // Variant Logic
  Future<void> _loadVariantGroupData(int generation) async {
    allAvailableOptions.clear();
    _parseVariantOptionsToAllAvailable();

    String? groupId = initialProduct.variantGroupId;

    if (groupId == null || groupId.isEmpty) {
      try {
        groupId = await SupabaseService.instance.lookupVariantGroupIdByNameBrand(
          name: initialProduct.name,
          brand: initialProduct.brand,
        );
      } catch (e) {
        debugPrint('Error finding variantGroupId fallback: $e');
      }
    }

    if (groupId == null || groupId.isEmpty) {
      if (allAvailableOptions.isEmpty) {
        _addFallbackVariantOptions();
      }
      if (generation == _detailLoadGeneration) {
        notifyListeners();
      }
      return;
    }

    loadingVariants = true;
    if (generation == _detailLoadGeneration) {
      notifyListeners();
    }

    try {
      final dbHelper = DatabaseHelper.instance;
      final dbVariants = await dbHelper
          .getProductVariantsByGroupId(groupId)
          .timeout(const Duration(seconds: 12));
      if (generation != _detailLoadGeneration) return;

      groupVariantDbProducts = dbVariants;
      groupVariants = dbVariants.map((p) => Product.fromDBProduct(p)).toList();

      for (var variant in groupVariants) {
        if (variant.variantOptions != null &&
            variant.variantOptions!.isNotEmpty) {
          final parts = variant.variantOptions!.split('|');
          for (var part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim();
              final value = keyValue[1].trim();

              if (!allAvailableOptions.containsKey(key)) {
                allAvailableOptions[key] = {};
              }
              allAvailableOptions[key]!.add(value);
            }
          }
        }
      }

      // If DB returned no variants, add fallback options
      if (groupVariants.isEmpty && allAvailableOptions.isNotEmpty) {
        _addFallbackVariantOptions();
      }
    } catch (e) {
      debugPrint('Error loading variants: $e');
      // On error, still show fallback options
      if (allAvailableOptions.isEmpty) {
        _addFallbackVariantOptions();
      }
    } finally {
      if (generation == _detailLoadGeneration) {
        loadingVariants = false;
        notifyListeners();
      }
    }
  }

  void _addFallbackVariantOptions() {
    // Add common variant options based on product category
    final category = (initialProduct.category ?? '').toLowerCase();
    final subCategory = (initialProduct.subCategory ?? '').toLowerCase();

    if (subCategory.contains('telefon') || subCategory.contains('phone')) {
      allAvailableOptions['Renk'] = {'Siyah', 'Beyaz', 'Mavi', 'Kırmızı'};
      allAvailableOptions['Depolama'] = {'128 GB', '256 GB', '512 GB', '1 TB'};
      // Set current selection from product's variantOptions if available
      _setCurrentSelectionFromProduct();
    } else if (subCategory.contains('bilgisayar') ||
        subCategory.contains('laptop')) {
      allAvailableOptions['Renk'] = {'Gümüş', 'Uzay Grisi', 'Gece Yarısı'};
      allAvailableOptions['RAM'] = {'8 GB', '16 GB', '24 GB'};
      allAvailableOptions['Depolama'] = {'256 GB', '512 GB', '1 TB'};
      _setCurrentSelectionFromProduct();
    } else if (category.contains('elektronik')) {
      allAvailableOptions['Renk'] = {'Siyah', 'Beyaz', 'Gri'};
      _setCurrentSelectionFromProduct();
    } else if (subCategory.contains('saç bakım') ||
        subCategory.contains('şampuan')) {
      allAvailableOptions['Boyut'] = {'250 ml', '400 ml', '700 ml'};
      _setCurrentSelectionFromProduct();
    }
  }

  void _setCurrentSelectionFromProduct() {
    if (initialProduct.variantOptions != null &&
        initialProduct.variantOptions!.isNotEmpty) {
      final parts = initialProduct.variantOptions!.split('|');
      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          selectedVariants[key] = value;
        }
      }
    } else {
      // Default to first option for each key
      for (var entry in allAvailableOptions.entries) {
        if (!selectedVariants.containsKey(entry.key)) {
          selectedVariants[entry.key] = entry.value.first;
        }
      }
    }
  }

  void _parseVariantOptionsToAllAvailable() {
    if (initialProduct.variantOptions != null &&
        initialProduct.variantOptions!.isNotEmpty) {
      final parts = initialProduct.variantOptions!.split('|');
      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          if (!allAvailableOptions.containsKey(key)) {
            allAvailableOptions[key] = {};
          }
          allAvailableOptions[key]!.add(value);
        }
      }
    }
  }

  void _parseVariantOptions() {
    if (initialProduct.variantOptions != null &&
        initialProduct.variantOptions!.isNotEmpty) {
      final parts = initialProduct.variantOptions!.split('|');
      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          if (variantOptions.containsKey(key)) {
            variantOptions[key]!.add(value);
          } else {
            variantOptions[key] = [value];
            selectedVariants[key] = value;
          }
        }
      }
    }
  }

  void updateSelectedVariant(String key, String value) {
    selectedVariants[key] = value;
    currentImageIndex = 0;
    notifyListeners();
  }

  bool hasInStockVariantForSelection(Map<String, String> selection) {
    if (groupVariantDbProducts.isEmpty) {
      return true;
    }
    return groupVariantDbProducts.any((variant) {
      final options = _parseVariantOptionsString(variant.variantOptions);
      if (!_matchesSelectedVariants(options, selection)) {
        return false;
      }
      return (variant.stock ?? 0) > 0;
    });
  }

  Map<String, String> _parseVariantOptionsString(String? options) {
    if (options == null || options.isEmpty) {
      return {};
    }
    final parsed = <String, String>{};
    final parts = options.split('|');
    for (var part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        parsed[keyValue[0].trim()] = keyValue[1].trim();
      }
    }
    return parsed;
  }

  bool _matchesSelectedVariants(
    Map<String, String> options,
    Map<String, String> selected,
  ) {
    for (var entry in selected.entries) {
      if (options[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Product? getMatchingVariant() {
    // Aday ürünler: veritabanından gelenler + mevcut ürün
    final candidates = [...groupVariants];
    // Mevcut ürünü de ekle (eğer listede yoksa)
    if (!candidates.any(
      (p) =>
          p.name == initialProduct.name &&
          p.variantOptions == initialProduct.variantOptions,
    )) {
      candidates.add(initialProduct);
    }

    try {
      return candidates.firstWhere((p) {
        if (p.variantOptions == null) return false;

        // Parse options of the candidate product
        final pOptions = _parseVariantOptionsString(p.variantOptions);

        // Check match
        for (var entry in selectedVariants.entries) {
          if (pOptions[entry.key] != entry.value) {
            return false;
          }
        }
        return true;
      });
    } catch (e) {
      return null;
    }
  }

  // Other Stores Logic
  Future<void> _loadOtherStoresWithProducts(int generation) async {
    loadingOtherStores = true;
    notifyListeners();

    try {
      final barcode = _matchBarcode ??
          ProductVisibilityHelper.catalogBarcode({
            'specifications': initialProduct.specifications,
          });
      final modelCode = _matchModelCode ??
          ProductVisibilityHelper.catalogModelCode({
            'specifications': initialProduct.specifications,
          });

      final rows = await SupabaseService.instance
          .getOtherSellerOfferRows(
            productName: initialProduct.name,
            brand: initialProduct.brand,
            barcode: barcode,
            modelCode: modelCode,
            excludeSellerId: initialProduct.sellerId,
            excludeProductId: initialProduct.productId,
            limit: 10,
          )
          .timeout(const Duration(seconds: 12));
      if (generation != _detailLoadGeneration) return;

      otherStoresWithProducts = rows.map((row) {
        final product = Product.fromDBProduct(row);
        final stores = row['stores'];
        String storeName = product.store?.trim() ?? '';
        String? logoUrl;
        if (stores is Map) {
          storeName =
              stores['business_name']?.toString().trim().isNotEmpty == true
              ? stores['business_name'].toString()
              : storeName;
          final rawLogo = stores['logo_url']?.toString().trim();
          if (rawLogo != null && rawLogo.isNotEmpty) {
            logoUrl = rawLogo;
          }
        }

        return {
          'store': {
            'name': storeName.isNotEmpty ? storeName : product.brand,
            'logoUrl': logoUrl,
            'sellerId': row['seller_id']?.toString() ?? product.sellerId,
          },
          'product': product,
        };
      }).toList(growable: false);
    } catch (e) {
      debugPrint('Error loading other stores products: $e');
      otherStoresWithProducts = const [];
    } finally {
      if (generation == _detailLoadGeneration) {
        loadingOtherStores = false;
        notifyListeners();
      }
    }
  }

  // Cart Logic
  void removeFromCart() {
    appState.removeFromCart(displayProduct);
    isAddedToCart = false;
    notifyListeners();
  }

  Future<String?> addToCart() async {
    if (isAddToCartInProgress) {
      return null;
    }

    final variantComplete = allAvailableOptions.isEmpty ||
        allAvailableOptions.keys.every((key) {
          final selected = selectedVariants[key]?.trim() ?? '';
          return selected.isNotEmpty &&
              (allAvailableOptions[key]?.contains(selected) ?? false);
        });
    if (!variantComplete) {
      return CartValidationService.variantRequiredMessage;
    }
    if (!hasInStockVariantForSelection(selectedVariants)) {
      return CartValidationService.outOfStockMessage;
    }
    if (_catalogStock != null && _catalogStock! <= 0) {
      return CartValidationService.outOfStockMessage;
    }

    isAddToCartInProgress = true;
    notifyListeners();
    try {
      final cartProduct = ProductCartIdentity.withCanonicalId(
        displayProduct.copyWith(
          selectedServices: selectedServices,
          selectedParts: selectedParts,
        ),
      );
      final error = await appState.addToCart(
        cartProduct,
        variantSelectionComplete: variantComplete,
      );
      if (error != null) {
        return error;
      }
      isAddedToCart = true;
      return null;
    } finally {
      isAddToCartInProgress = false;
      notifyListeners();
    }
  }

  void updateReviewSummary({required double rating, required int reviewCount}) {
    _reviewSummary = ReviewSummary(
      reviews: _reviewSummary.reviews,
      reviewCount: reviewCount,
      averageRating: rating,
    );
    if (initialProduct.rating == rating &&
        initialProduct.reviewCount == reviewCount) {
      return;
    }

    initialProduct = initialProduct.copyWith(
      rating: rating,
      reviewCount: reviewCount,
    );
    notifyListeners();
  }

  /// Ürünün satın alınabilirlik değerlendirmesi (tek kaynak helper).
  ///
  /// Yerel snapshot'a ek olarak Supabase'den tazelenen katalog stoğunu da
  /// hesaba katar; böylece "Stokta (0)" durumunda buton kesin bloklanır.
  ProductPurchasability get purchasability {
    final base = ProductPurchasabilityHelper.evaluate(displayProduct);
    if (_catalogStock != null && _catalogStock! <= 0) {
      return const ProductPurchasability(
        canPurchase: false,
        reason: ProductPurchasabilityReason.outOfStock,
        userMessage: ProductPurchasabilityHelper.outOfStockMessage,
      );
    }
    return base;
  }

  Product get displayProduct {
    final matchingVariant = getMatchingVariant();
    if (matchingVariant != null) {
      return matchingVariant.copyWith(
        images: _buildDisplayImages(),
        selectedServices: selectedServices,
        selectedParts: selectedParts,
      );
    }

    return initialProduct.copyWith(
      price: _formatPrice(_baseVariantAdjustedPrice),
      images: _buildDisplayImages(),
      selectedServices: selectedServices,
      selectedParts: selectedParts,
    );
  }

  List<String> get images {
    final imgs = _buildDisplayImages();
    if (imgs.isEmpty) {
      imgs.add('https://via.placeholder.com/300x300.png?text=%C3%9Cr%C3%BCn');
    }
    return imgs;
  }

  bool get isSecondHandDamaged {
    // Ürün adında "hasarlı", "2.el", "ikinci el", "kırık" gibi kelimeler varsa
    final nameLower = initialProduct.name.toLowerCase();
    if (nameLower.contains('hasarlı') ||
        nameLower.contains('hasarli') ||
        nameLower.contains('2.el') ||
        nameLower.contains('2. el') ||
        nameLower.contains('ikinci el') ||
        nameLower.contains('kırık') ||
        nameLower.contains('kirik')) {
      return true;
    }

    // Etiketlerde kontrol et
    for (var tag in initialProduct.tags) {
      final tagLower = tag.toLowerCase();
      if (tagLower.contains('hasarlı') ||
          tagLower.contains('hasarli') ||
          tagLower.contains('2.el') ||
          tagLower.contains('2. el') ||
          tagLower.contains('ikinci el') ||
          tagLower.contains('kırık') ||
          tagLower.contains('kirik')) {
        return true;
      }
    }

    return false;
  }

  // Warranty Logic
  String get warrantyTitle {
    if (initialProduct.brand.toLowerCase().contains('ikea')) {
      return 'ÜRÜN MONTAJ';
    } else if (isSecondHandDamaged) {
      return 'İBUL GARANTİ';
    } else if ((initialProduct.category ?? '').toLowerCase().contains(
          'elektronik',
        ) ||
        (initialProduct.category ?? '').toLowerCase().contains('teknoloji')) {
      return 'İBUL GARANTİ';
    }
    return '';
  }

  String get warrantyDescription {
    if (initialProduct.brand.toLowerCase().contains('ikea')) {
      return 'Profesyonel montaj hizmeti';
    } else if (isSecondHandDamaged) {
      return '1 Yıl Kapsamlı Garanti';
    } else if ((initialProduct.category ?? '').toLowerCase().contains(
          'elektronik',
        ) ||
        (initialProduct.category ?? '').toLowerCase().contains('teknoloji')) {
      return '+1 Yıl Ek Garanti';
    }
    return '';
  }

  // Warranty Price Logic
  double get warrantyPrice {
    if (initialProduct.brand.toLowerCase().contains('ikea')) {
      return 450.0;
    } else if (isSecondHandDamaged) {
      return 2499.0;
    } else if ((initialProduct.category ?? '').toLowerCase().contains(
          'elektronik',
        ) ||
        (initialProduct.category ?? '').toLowerCase().contains('teknoloji')) {
      return 3499.0;
    }
    return 0.0;
  }

  String get warrantyPriceFormatted {
    final price = warrantyPrice;
    if (price == 0) return '';
    return _formatPrice(price);
  }

  String get totalPrice {
    double basePrice = _baseVariantAdjustedPrice;

    // Add selected parts prices
    for (var part in selectedParts) {
      basePrice += _parsePrice(part.price);
    }

    // Add warranty if selected
    if (isWarrantyAdded) {
      basePrice += warrantyPrice;
    }

    // Format back to string with Turkish locale (dots for thousands)
    return _formatPrice(basePrice);
  }

  void _syncSelectedVariantsFromStructuredVariants() {
    final maps = _variantMapsFromProduct(initialProduct);
    if (maps.isEmpty) return;

    for (final key in const ['storage', 'ram', 'size', 'color']) {
      final values = maps
          .map((map) => map[key]?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      if (values.isEmpty) continue;
      final current = selectedVariants[key];
      if (current == null || !values.contains(current)) {
        selectedVariants[key] = values.first;
      }
    }
  }

  List<Map<String, dynamic>> _variantMapsFromProduct(Product product) {
    final raw = product.variants;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((variant) => Map<String, dynamic>.from(variant))
        .where((variant) => variant.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic>? get selectedVariantMap {
    final maps = _variantMapsFromProduct(initialProduct);
    if (maps.isEmpty) return null;

    for (final variant in maps) {
      final matchesColor =
          !_hasSelectedVariantValue('color') ||
          _matchesVariantValue(variant, 'color', selectedVariants['color']);
      final matchesStorage =
          !_hasSelectedVariantValue('storage') ||
          _matchesVariantValue(variant, 'storage', selectedVariants['storage']);
      final matchesRam =
          !_hasSelectedVariantValue('ram') ||
          _matchesVariantValue(variant, 'ram', selectedVariants['ram']);
      final matchesSize =
          !_hasSelectedVariantValue('size') ||
          _matchesVariantValue(variant, 'size', selectedVariants['size']);
      if (matchesColor && matchesStorage && matchesRam && matchesSize) {
        return variant;
      }
    }

    return maps.first;
  }

  bool _hasSelectedVariantValue(String key) {
    final value = selectedVariants[key];
    return value != null && value.trim().isNotEmpty;
  }

  bool _matchesVariantValue(
    Map<String, dynamic> variant,
    String key,
    String? selectedValue,
  ) {
    if (selectedValue == null || selectedValue.trim().isEmpty) return true;
    final candidate = variant[key]?.toString().trim() ?? '';
    return candidate == selectedValue.trim();
  }

  double get _baseVariantAdjustedPrice {
    return _parsePrice(initialProduct.price) + currentVariantPriceDifference;
  }

  double get currentVariantPriceDifference {
    final rawDiff = selectedVariantMap?['priceDifference'];
    if (rawDiff is num) return rawDiff.toDouble();
    return double.tryParse(rawDiff?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  List<String> _buildDisplayImages() {
    final orderedImages = <String>[];
    final variant = selectedVariantMap;
    final variantImage = _variantImageFromMap(variant);
    if (variantImage != null && variantImage.isNotEmpty) {
      orderedImages.add(variantImage);
    }

    for (final image in initialProduct.images) {
      final trimmed = image.trim();
      if (trimmed.isEmpty || orderedImages.contains(trimmed)) continue;
      orderedImages.add(trimmed);
    }

    return orderedImages;
  }

  String? _variantImageFromMap(Map<String, dynamic>? variant) {
    if (variant == null) return null;
    for (final key in const [
      'imageUrl',
      'image_url',
      'imagePath',
      'image_path',
    ]) {
      final value = variant[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  List<String> get selectedServices {
    List<String> services = [];
    if (isWarrantyAdded && warrantyTitle.isNotEmpty) {
      services.add(warrantyTitle);
    }
    if (isFastDeliverySelected) {
      services.add('Hızlı Kargo');
    }

    // Add selected parts to services
    for (var part in selectedParts) {
      if (part.name.isNotEmpty) {
        services.add('Parça: ${part.name}');
      }
    }

    return services;
  }

  String _formatPrice(double price) {
    // 25000.0 -> 25.000 TL
    // 1234.56 -> 1.234,56 TL

    String priceStr = price.toStringAsFixed(2); // 1234.56
    List<String> parts = priceStr.split('.');
    String wholePart = parts[0];
    String decimalPart = parts[1];

    // Add dots to whole part
    final buffer = StringBuffer();
    for (int i = 0; i < wholePart.length; i++) {
      if (i > 0 && (wholePart.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(wholePart[i]);
    }

    // If decimal part is 00, omit it for cleaner look (like "25.000 TL")
    // If it has value, use comma (like "25.000,50 TL")
    if (decimalPart == "00") {
      return '${buffer.toString()} TL';
    } else {
      return '${buffer.toString()},$decimalPart TL';
    }
  }

  double _parsePrice(String priceStr) {
    try {
      String clean = priceStr.replaceAll('TL', '').trim();

      // Handle 1.234,56 format (Turkish) vs 1,234.56 (English)
      if (clean.contains(',') && clean.contains('.')) {
        if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
          // 1.234,56 -> 1234.56
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // 1,234.56 -> 1234.56
          clean = clean.replaceAll(',', '');
        }
      } else if (clean.contains(',')) {
        // 1234,56 -> 1234.56
        clean = clean.replaceAll(',', '.');
      } else if (clean.contains('.')) {
        // 25.000 -> 25000 (Turkish thousand separator)
        // Remove dots as they are thousand separators
        clean = clean.replaceAll('.', '');
      }

      return double.tryParse(clean) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void toggleWarranty(bool value) {
    isWarrantyAdded = value;
    notifyListeners();
  }

  void toggleFastDelivery() {
    isFastDeliverySelected = !isFastDeliverySelected;
    notifyListeners();
  }
}
