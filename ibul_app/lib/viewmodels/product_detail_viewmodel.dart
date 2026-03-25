import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../services/database_helper.dart';
import '../services/supabase_service.dart';

class ProductDetailViewModel extends ChangeNotifier {
  Product initialProduct;
  final AppState appState;

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
  }) {
    _init();
  }

  void _init() {
    appState.addRecentlyViewedProduct(initialProduct);
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

    _refreshProductExtrasFromSupabase();
    _loadOtherStoresWithProducts();
    _loadVariantGroupData();
    _loadSimilarProducts();
    _loadComplementaryProducts();
  }

  void toggleAttribute(String value) {
    if (selectedAttributes.contains(value)) {
      selectedAttributes.remove(value);
    } else {
      selectedAttributes.add(value);
    }
    notifyListeners();
  }

  Future<void> _refreshProductExtrasFromSupabase() async {
    try {
      final extras = await SupabaseService.instance.getProductExtrasByNameBrand(
        name: initialProduct.name,
        brand: initialProduct.brand,
      );
      if (extras == null) return;

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
      _loadComplementaryProducts();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadComplementaryProducts() async {
    loadingComplementary = true;
    notifyListeners();

    try {
      if (initialProduct.accessories != null &&
          initialProduct.accessories!.isNotEmpty) {
        final linkedProducts = await SupabaseService.instance.getProductsByIds(
          initialProduct.accessories!,
        );
        complementaryProducts = linkedProducts
            .map((product) => Product.fromDBProduct(product))
            .where(
              (product) =>
                  product.name != initialProduct.name ||
                  product.brand != initialProduct.brand,
            )
            .take(2)
            .toList();
      }
      if (complementaryProducts.isEmpty) {
        complementaryProducts = _generateFallbackComplementaryProducts();
      }
    } catch (e) {
      debugPrint('Error loading complementary products: $e');
    } finally {
      loadingComplementary = false;
      notifyListeners();
    }
  }

  List<Product> _generateFallbackComplementaryProducts() {
    final subCategory = (initialProduct.subCategory ?? '').toLowerCase();
    final category = (initialProduct.category ?? '').toLowerCase();

    List<Product> results = [];

    if (subCategory.contains('telefon') || subCategory.contains('phone')) {
      results.add(
        Product(
          name: 'Hızlı Şarj Adaptörü 20W',
          brand: 'Apple',
          price: '649.00 TL',
          rating: 4.8,
          reviewCount: 1500,
          tags: ['Orijinal'],
          images: [
            'assets/products/iphone15_beyaz_arka.png',
          ], // Placeholder image
          category: 'Elektronik',
          subCategory: 'Aksesuar',
        ),
      );
      results.add(
        Product(
          name: 'Magsafe Şeffaf Kılıf',
          brand: 'Apple',
          price: '1299.00 TL',
          rating: 4.6,
          reviewCount: 800,
          tags: ['MagSafe'],
          images: ['assets/products/iphone15_mavi_yan.webp'], // Placeholder
          category: 'Elektronik',
          subCategory: 'Aksesuar',
        ),
      );
    } else if (subCategory.contains('bilgisayar') ||
        subCategory.contains('laptop')) {
      results.add(
        Product(
          name: 'Magic Mouse Siyah',
          brand: 'Apple',
          price: '3500.00 TL',
          rating: 4.5,
          reviewCount: 300,
          tags: ['Kablosuz'],
          images: ['assets/products/macbook_pro_m3.jpeg'], // Placeholder
          category: 'Elektronik',
          subCategory: 'Aksesuar',
        ),
      );
      results.add(
        Product(
          name: 'USB-C Hub Çoklayıcı',
          brand: 'Baseus',
          price: '899.00 TL',
          rating: 4.7,
          reviewCount: 1200,
          tags: ['Çok Satan'],
          images: ['assets/products/macbook_pro_m3_back.jpg'], // Placeholder
          category: 'Elektronik',
          subCategory: 'Aksesuar',
        ),
      );
    } else if (subCategory.contains('saç') || category.contains('kozmetik')) {
      results.add(
        Product(
          name: 'Saç Bakım Yağı',
          brand: 'Urban Care',
          price: '189.00 TL',
          rating: 4.8,
          reviewCount: 450,
          tags: ['Besleyici'],
          images: [
            'assets/products/Urban Care Argan Oil Şampuan.jpeg',
          ], // Placeholder
          category: 'Kişisel Bakım',
          subCategory: 'Saç Bakımı',
        ),
      );
    }

    return results;
  }

  void addCombinationToCart() {
    // Add main product
    addToCart();

    // Add complementary products
    for (var product in complementaryProducts) {
      appState.addToCart(product);
    }

    notifyListeners();
  }

  Future<void> _loadSimilarProducts() async {
    loadingSimilarProducts = true;
    notifyListeners();

    try {
      final dbHelper = DatabaseHelper.instance;
      final allProducts = await dbHelper.getAllProducts();

      final currentName = initialProduct.name.toLowerCase();
      final currentBrand = initialProduct.brand.toLowerCase();
      final currentCategory = (initialProduct.category ?? '').toLowerCase();
      final currentSubCategory = (initialProduct.subCategory ?? '')
          .toLowerCase();

      // Sadece gerçek mağazaya bağlı ve aktif ürünleri göster.
      final eligibleProducts = allProducts.where((p) {
        final hasStore = (p.store ?? '').trim().isNotEmpty;
        if (!hasStore || !p.isActive) return false;

        final isSameNameBrand =
            p.name.toLowerCase() == currentName &&
            p.brand.toLowerCase() == currentBrand;
        return !isSameNameBrand;
      });

      similarProducts = eligibleProducts
          .where((p) {
            final pName = p.name.toLowerCase();
            if (pName == currentName) return false;

            final pCategory = p.category.toLowerCase();
            final pSubCategory = (p.subCategory ?? '').toLowerCase();

            final sameCategory = pCategory == currentCategory;
            final sameSubCategory = pSubCategory == currentSubCategory;
            final similarName = _isNameSimilar(currentName, pName);

            return sameCategory || sameSubCategory || similarName;
          })
          .map((dbP) => _convertToProduct(dbP))
          .take(10)
          .toList();
    } catch (e) {
      debugPrint('Error loading similar products: $e');
      similarProducts = [];
    } finally {
      loadingSimilarProducts = false;
      notifyListeners();
    }
  }

  bool _isNameSimilar(String base, String other) {
    final baseTokens = base
        .split(RegExp(r'[\s\-_]+'))
        .map((t) => t.trim())
        .where((t) => t.length > 2)
        .toList();

    if (baseTokens.isEmpty) {
      return false;
    }

    int matchCount = 0;
    for (final token in baseTokens) {
      if (other.contains(token)) {
        matchCount++;
        if (matchCount >= 2) {
          return true;
        }
      }
    }

    if (matchCount == 1 && base.startsWith(other.split(' ').first)) {
      return true;
    }

    return false;
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
  Future<void> _loadVariantGroupData() async {
    allAvailableOptions.clear();
    _parseVariantOptionsToAllAvailable();

    String? groupId = initialProduct.variantGroupId;

    // Fallback: If groupId is missing, try to find it in DB using exact name match
    if (groupId == null || groupId.isEmpty) {
      try {
        final dbHelper = DatabaseHelper.instance;
        final dbProducts = await dbHelper.searchProducts(initialProduct.name);

        // Find exact match
        for (var p in dbProducts) {
          if (p.name == initialProduct.name &&
              p.variantGroupId != null &&
              p.variantGroupId!.isNotEmpty) {
            groupId = p.variantGroupId;
            break;
          }
        }
      } catch (e) {
        debugPrint('Error finding variantGroupId fallback: $e');
      }
    }

    if (groupId == null || groupId.isEmpty) {
      // If product has variantOptions but no groupId, use fallback variants
      if (allAvailableOptions.isEmpty) {
        _addFallbackVariantOptions();
      }
      notifyListeners();
      return;
    }

    loadingVariants = true;
    notifyListeners();

    try {
      final dbHelper = DatabaseHelper.instance;
      final dbVariants = await dbHelper.getProductVariantsByGroupId(groupId);
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
      loadingVariants = false;
      notifyListeners();
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
  Future<void> _loadOtherStoresWithProducts() async {
    loadingOtherStores = true;
    notifyListeners();

    try {
      final candidateStores = _getOtherStores();
      List<Map<String, dynamic>> results = [];

      final currentName = initialProduct.name.toLowerCase();
      final currentBrand = initialProduct.brand.toLowerCase();
      final currentSubCategory = (initialProduct.subCategory ?? '')
          .toLowerCase();
      final currentCategory = (initialProduct.category ?? '').toLowerCase();

      for (var storeMap in candidateStores) {
        final storeName = storeMap['name'] as String;
        final products = await _getStoreProducts(storeName);

        if (products.isEmpty) continue;

        Product? bestMatch;

        // Priority 1: Exact Name Match
        try {
          bestMatch = products.firstWhere(
            (p) => p.name.toLowerCase() == currentName,
          );
        } catch (_) {}

        // Priority 2: Similar Name
        if (bestMatch == null) {
          try {
            bestMatch = products.firstWhere(
              (p) =>
                  p.name.toLowerCase().contains(currentName) ||
                  currentName.contains(p.name.toLowerCase()),
            );
          } catch (_) {}
        }

        // Priority 3: Same Brand & SubCategory
        if (bestMatch == null) {
          try {
            bestMatch = products.firstWhere(
              (p) =>
                  p.brand.toLowerCase() == currentBrand &&
                  (p.subCategory ?? '').toLowerCase() == currentSubCategory,
            );
          } catch (_) {}
        }

        // Priority 4: Same Category
        if (bestMatch == null) {
          try {
            bestMatch = products.firstWhere(
              (p) => (p.category ?? '').toLowerCase() == currentCategory,
            );
          } catch (_) {}
        }

        // Priority 5: Any product (Fallback)
        if (bestMatch == null && products.isNotEmpty) {
          bestMatch = products.first;
        }

        if (bestMatch != null) {
          results.add({'store': storeMap, 'product': bestMatch});
        }
      }

      otherStoresWithProducts = results;
    } catch (e) {
      debugPrint('Error loading other stores products: $e');
    } finally {
      loadingOtherStores = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _getOtherStores() {
    final category = (initialProduct.category ?? '').toLowerCase();
    final subCategory = (initialProduct.subCategory ?? '').toLowerCase();
    final String currentPrice = initialProduct.price;

    String targetCategory = 'market';

    if (category.contains('teknoloji') ||
        category.contains('elektronik') ||
        subCategory.contains('teknoloji') ||
        subCategory.contains('elektronik')) {
      targetCategory = 'teknoloji';
    } else if (category.contains('giyim') ||
        category.contains('moda') ||
        subCategory.contains('giyim')) {
      targetCategory = 'giyim';
    } else if (category.contains('mobilya') ||
        category.contains('ev') ||
        subCategory.contains('mobilya')) {
      targetCategory = 'mobilya';
    } else if (category.contains('kozmetik') ||
        subCategory.contains('kozmetik')) {
      targetCategory = 'kozmetik';
    } else if (category.contains('oyuncak') ||
        subCategory.contains('oyuncak')) {
      targetCategory = 'oyuncak';
    } else if (category.contains('kitap') || subCategory.contains('kitap')) {
      targetCategory = 'kitap';
    } else if (category.contains('tamir') || subCategory.contains('tamir')) {
      targetCategory = 'tamir';
    }

    // Temporary fallback data structure to replace the deleted file
    final List<Map<String, dynamic>> businessData = [
      {'name': 'Teknosa', 'category': 'teknoloji'},
      {'name': 'MediaMarkt', 'category': 'teknoloji'},
      {'name': 'Vatan Bilgisayar', 'category': 'teknoloji'},
      {'name': 'Apple Store', 'category': 'teknoloji'},
      {'name': 'Samsung', 'category': 'teknoloji'},
      {'name': 'Ikea', 'category': 'mobilya'},
      {'name': 'Vivense', 'category': 'mobilya'},
      {'name': 'Koçtaş', 'category': 'mobilya'},
      {'name': 'LC Waikiki', 'category': 'giyim'},
      {'name': 'Mavi', 'category': 'giyim'},
      {'name': 'Zara', 'category': 'giyim'},
      {'name': 'H&M', 'category': 'giyim'},
      {'name': 'Gratis', 'category': 'kozmetik'},
      {'name': 'Watsons', 'category': 'kozmetik'},
      {'name': 'Rossmann', 'category': 'kozmetik'},
      {'name': 'D&R', 'category': 'kitap'},
      {'name': 'Toyzz Shop', 'category': 'oyuncak'},
      {'name': 'Migros', 'category': 'market'},
      {'name': 'CarrefourSA', 'category': 'market'},
      {'name': 'A101', 'category': 'market'},
      {'name': 'ŞOK', 'category': 'market'},
      {'name': 'BİM', 'category': 'market'},
    ];

    List<Map<String, dynamic>> filteredBusinesses = businessData
        .where((b) => b['category'] == targetCategory)
        .toList();

    if (filteredBusinesses.isEmpty) {
      filteredBusinesses = businessData
          .where((b) => b['category'] == 'market')
          .toList();
    }

    return filteredBusinesses.map((store) {
      final name = store['name'] as String;
      final hash = name.hashCode;
      final multiplier = 0.90 + (hash % 20) / 100.0;
      final rating = 8.5 + (hash % 15) / 10.0;

      Color badgeColor = Colors.black;
      if (name.contains('Teknosa') || name.contains('Trendyol'))
        badgeColor = Colors.orange;
      else if (name.contains('MediaMarkt') || name.contains('H&M'))
        badgeColor = Colors.red;
      else if (name.contains('Ikea') || name.contains('Vatan'))
        badgeColor = Colors.blue;
      else if (name.contains('Vivense'))
        badgeColor = Colors.orange[300]!;
      else if (name.contains('ŞOK'))
        badgeColor = Colors.yellow[700]!;
      else if (name.contains('A101'))
        badgeColor = Colors.teal;

      return {
        'name': name,
        'rating': rating.toStringAsFixed(1),
        'badgeColor': badgeColor,
        'price': _calculateStorePrice(currentPrice, multiplier),
      };
    }).toList();
  }

  String _calculateStorePrice(String originalPrice, double multiplier) {
    try {
      String clean = originalPrice.replaceAll('TL', '').trim();

      double val = 0;
      if (clean.contains(',') && clean.contains('.')) {
        if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        } else {
          clean = clean.replaceAll(',', '');
        }
      } else if (clean.contains(',')) {
        clean = clean.replaceAll(',', '.');
      } else if (clean.contains('.')) {
        clean = clean.replaceAll('.', '');
      }

      val = double.tryParse(clean) ?? 0;
      if (val == 0) return originalPrice;

      double newVal = val * multiplier;

      return '${newVal.toStringAsFixed(2)} TL';
    } catch (e) {
      return originalPrice;
    }
  }

  Future<List<Product>> _getStoreProducts(String storeName) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final allProducts = await dbHelper.getAllProducts();

      final storeProducts = allProducts.where((product) {
        return product.store?.toLowerCase() == storeName.toLowerCase();
      }).toList();

      return storeProducts
          .map((dbProduct) => _convertToProduct(dbProduct))
          .toList();
    } catch (e) {
      debugPrint('Error loading store products: $e');
      return [];
    }
  }

  Product _convertToProduct(DBProduct dbProduct) {
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

    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags
          .split('|')
          .map<String>((e) => e.toString().trim())
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
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
      variantOptions: dbProduct.variantOptions,
      variantGroupId: dbProduct.variantGroupId,
    );
  }

  // Cart Logic
  void removeFromCart() {
    appState.removeFromCart(displayProduct);
    isAddedToCart = false;
    notifyListeners();
  }

  void addToCart() {
    appState.addToCart(
      displayProduct.copyWith(
        selectedServices: selectedServices,
        selectedParts: selectedParts,
      ),
    );
    isAddedToCart = true;
    notifyListeners();
  }

  void updateReviewSummary({
    required double rating,
    required int reviewCount,
  }) {
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
