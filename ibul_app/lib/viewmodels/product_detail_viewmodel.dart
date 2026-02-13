import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../data/business_data.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../services/database_helper.dart';

class ProductDetailViewModel extends ChangeNotifier {
  final Product initialProduct;
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

  final List<String> tabs = [
    'Ürün Açıklaması',
    'Yakın Lokasyon',
    'Ürün Özellikleri',
  ];

  ProductDetailViewModel({required this.initialProduct, required this.appState}) {
    _init();
  }

  void _init() {
    _parseVariantOptions();
    isFavorite = appState.favorites.contains(initialProduct);
    isAddedToCart = appState.isInCart(initialProduct);
    
    // Initialize fast delivery state from app state logic or default
    if (appState.hasFastDelivery(initialProduct)) {
      isFastDeliverySelected = true;
    }

    if (isAddedToCart) {
      try {
        final cartProduct = appState.cart.firstWhere(
          (p) => p.name == initialProduct.name && p.brand == initialProduct.brand
        );
        if (cartProduct.selectedServices.isNotEmpty) {
          if (cartProduct.selectedServices.any((s) => s.contains('GARANTİ') || s.contains('MONTAJ'))) {
            isWarrantyAdded = true;
          }
          if (cartProduct.selectedServices.contains('Hızlı Kargo')) {
            isFastDeliverySelected = true;
          }
        }
      } catch (_) {}
    }

    _loadOtherStoresWithProducts();
    _loadVariantGroupData();
    _loadSimilarProducts();
    _loadComplementaryProducts();
  }

  Future<void> _loadComplementaryProducts() async {
    loadingComplementary = true;
    notifyListeners();

    try {
      // 1. Try to get from actual accessories field if available
      if (initialProduct.accessories != null && initialProduct.accessories!.isNotEmpty) {
         // Mock logic: fetching by name from fallback list for now, 
         // in real app this would query DB by ID
      }
      
      // 2. Fallback: Generate based on category
      complementaryProducts = _generateFallbackComplementaryProducts();
      
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
      results.add(Product(
        name: 'Hızlı Şarj Adaptörü 20W',
        brand: 'Apple',
        price: '649.00 TL',
        rating: 4.8,
        reviewCount: 1500,
        tags: ['Orijinal'],
        images: ['assets/products/iphone15_beyaz_arka.png'], // Placeholder image
        category: 'Elektronik',
        subCategory: 'Aksesuar'
      ));
      results.add(Product(
        name: 'Magsafe Şeffaf Kılıf',
        brand: 'Apple',
        price: '1299.00 TL',
        rating: 4.6,
        reviewCount: 800,
        tags: ['MagSafe'],
        images: ['assets/products/iphone15_mavi_yan.webp'], // Placeholder
        category: 'Elektronik',
        subCategory: 'Aksesuar'
      ));
    } else if (subCategory.contains('bilgisayar') || subCategory.contains('laptop')) {
       results.add(Product(
        name: 'Magic Mouse Siyah',
        brand: 'Apple',
        price: '3500.00 TL',
        rating: 4.5,
        reviewCount: 300,
        tags: ['Kablosuz'],
        images: ['assets/products/macbook_pro_m3.jpeg'], // Placeholder
        category: 'Elektronik',
        subCategory: 'Aksesuar'
      ));
       results.add(Product(
        name: 'USB-C Hub Çoklayıcı',
        brand: 'Baseus',
        price: '899.00 TL',
        rating: 4.7,
        reviewCount: 1200,
        tags: ['Çok Satan'],
        images: ['assets/products/macbook_pro_m3_back.jpg'], // Placeholder
        category: 'Elektronik',
        subCategory: 'Aksesuar'
      ));
    } else if (subCategory.contains('saç') || category.contains('kozmetik')) {
      results.add(Product(
        name: 'Saç Bakım Yağı',
        brand: 'Urban Care',
        price: '189.00 TL',
        rating: 4.8,
        reviewCount: 450,
        tags: ['Besleyici'],
        images: ['assets/products/Urban Care Argan Oil Şampuan.jpeg'], // Placeholder
        category: 'Kişisel Bakım',
        subCategory: 'Saç Bakımı'
      ));
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
      final currentCategory = (initialProduct.category ?? '').toLowerCase();
      final currentSubCategory = (initialProduct.subCategory ?? '').toLowerCase();

      // Filter products: same category or subcategory, exclude current
      similarProducts = allProducts.where((p) {
        final pName = p.name.toLowerCase();
        if (pName == currentName) return false;

        final pCategory = p.category.toLowerCase();
        final pSubCategory = (p.subCategory ?? '').toLowerCase();

        return pCategory == currentCategory || pSubCategory == currentSubCategory;
      }).map((dbP) => _convertToProduct(dbP)).take(10).toList();

      // Fallback: if DB is empty, generate similar products from test data
      if (similarProducts.isEmpty) {
        similarProducts = _generateFallbackSimilarProducts();
      }

    } catch (e) {
      debugPrint('Error loading similar products: $e');
    } finally {
      loadingSimilarProducts = false;
      notifyListeners();
    }
  }

  void updateImageIndex(int index) {
    currentImageIndex = index;
    notifyListeners();
  }

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
          if (p.name == initialProduct.name && p.variantGroupId != null && p.variantGroupId!.isNotEmpty) {
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
        if (variant.variantOptions != null && variant.variantOptions!.isNotEmpty) {
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
    } else if (subCategory.contains('bilgisayar') || subCategory.contains('laptop')) {
      allAvailableOptions['Renk'] = {'Gümüş', 'Uzay Grisi', 'Gece Yarısı'};
      allAvailableOptions['RAM'] = {'8 GB', '16 GB', '24 GB'};
      allAvailableOptions['Depolama'] = {'256 GB', '512 GB', '1 TB'};
      _setCurrentSelectionFromProduct();
    } else if (category.contains('elektronik')) {
      allAvailableOptions['Renk'] = {'Siyah', 'Beyaz', 'Gri'};
      _setCurrentSelectionFromProduct();
    } else if (subCategory.contains('saç bakım') || subCategory.contains('şampuan')) {
      allAvailableOptions['Boyut'] = {'250 ml', '400 ml', '700 ml'};
      _setCurrentSelectionFromProduct();
    }
  }

  void _setCurrentSelectionFromProduct() {
    if (initialProduct.variantOptions != null && initialProduct.variantOptions!.isNotEmpty) {
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
    if (initialProduct.variantOptions != null && initialProduct.variantOptions!.isNotEmpty) {
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
    if (initialProduct.variantOptions != null && initialProduct.variantOptions!.isNotEmpty) {
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

  bool _matchesSelectedVariants(Map<String, String> options, Map<String, String> selected) {
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
    if (!candidates.any((p) => p.name == initialProduct.name && p.variantOptions == initialProduct.variantOptions)) {
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
      final currentSubCategory = (initialProduct.subCategory ?? '').toLowerCase();
      final currentCategory = (initialProduct.category ?? '').toLowerCase();

      for (var storeMap in candidateStores) {
        final storeName = storeMap['name'] as String;
        final products = await _getStoreProducts(storeName);
        
        if (products.isEmpty) continue;

        Product? bestMatch;

        // Priority 1: Exact Name Match
        try {
          bestMatch = products.firstWhere((p) => p.name.toLowerCase() == currentName);
        } catch (_) {}

        // Priority 2: Similar Name
        if (bestMatch == null) {
          try {
            bestMatch = products.firstWhere((p) => p.name.toLowerCase().contains(currentName) || currentName.contains(p.name.toLowerCase()));
          } catch (_) {}
        }

        // Priority 3: Same Brand & SubCategory
        if (bestMatch == null) {
          try {
            bestMatch = products.firstWhere((p) => p.brand.toLowerCase() == currentBrand && (p.subCategory ?? '').toLowerCase() == currentSubCategory);
          } catch (_) {}
        }

        // Priority 4: Same Category
        if (bestMatch == null) {
          try {
            bestMatch = products.firstWhere((p) => (p.category ?? '').toLowerCase() == currentCategory);
          } catch (_) {}
        }

        // Priority 5: Any product (Fallback)
        if (bestMatch == null && products.isNotEmpty) {
          bestMatch = products.first;
        }

        if (bestMatch != null) {
          results.add({
            'store': storeMap,
            'product': bestMatch,
          });
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
    
    if (category.contains('teknoloji') || category.contains('elektronik') || 
        subCategory.contains('teknoloji') || subCategory.contains('elektronik')) {
      targetCategory = 'teknoloji';
    } else if (category.contains('giyim') || category.contains('moda') || 
               subCategory.contains('giyim')) {
      targetCategory = 'giyim';
    } else if (category.contains('mobilya') || category.contains('ev') || 
               subCategory.contains('mobilya')) {
      targetCategory = 'mobilya';
    } else if (category.contains('kozmetik') || subCategory.contains('kozmetik')) {
      targetCategory = 'kozmetik';
    } else if (category.contains('oyuncak') || subCategory.contains('oyuncak')) {
      targetCategory = 'oyuncak';
    } else if (category.contains('kitap') || subCategory.contains('kitap')) {
      targetCategory = 'kitap';
    } else if (category.contains('tamir') || subCategory.contains('tamir')) {
      targetCategory = 'tamir';
    }

    List<Map<String, dynamic>> filteredBusinesses = businessData.where((b) => 
      b['category'] == targetCategory
    ).toList();
    
    if (filteredBusinesses.isEmpty) {
      filteredBusinesses = businessData.where((b) => b['category'] == 'market').toList();
    }
    
    return filteredBusinesses.map((store) {
      final name = store['name'] as String;
      final hash = name.hashCode;
      final multiplier = 0.90 + (hash % 20) / 100.0;
      final rating = 8.5 + (hash % 15) / 10.0;
      
      Color badgeColor = Colors.black;
      if (name.contains('Teknosa') || name.contains('Trendyol')) badgeColor = Colors.orange;
      else if (name.contains('MediaMarkt') || name.contains('H&M')) badgeColor = Colors.red;
      else if (name.contains('Ikea') || name.contains('Vatan')) badgeColor = Colors.blue;
      else if (name.contains('Vivense')) badgeColor = Colors.orange[300]!;
      else if (name.contains('ŞOK')) badgeColor = Colors.yellow[700]!;
      else if (name.contains('A101')) badgeColor = Colors.teal;

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
      
      return storeProducts.map((dbProduct) => _convertToProduct(dbProduct)).toList();
    } catch (e) {
      debugPrint('Error loading store products: $e');
      return [];
    }
  }

  List<Product> _generateFallbackSimilarProducts() {
    final currentCategory = (initialProduct.category ?? '').toLowerCase();
    final currentBrand = initialProduct.brand.toLowerCase();

    // Fallback test products for similar products section with more realistic data
    final fallbackProducts = <Product>[
      // Kişisel Bakım - Saç
      Product(name: 'Urban Care Hyaluronic Acid & Collagen Şampuan', brand: 'Urban Care', price: '199.90 TL', rating: 4.5, reviewCount: 150, tags: ['Hızlı Kargo'], images: ['assets/products/Urban Care Hyaluronic Şampuan.jpg'], store: 'Gratis', category: 'Kişisel Bakım', subCategory: 'Saç Bakımı', oldPrice: '250.00 TL'),
      Product(name: 'Argan Oil Şampuan', brand: 'Urban Care', price: '220.00 TL', rating: 4.6, reviewCount: 200, tags: ['Popüler'], images: ['assets/products/Urban Care Argan Oil Şampuan.jpeg'], store: 'Watsons', category: 'Kişisel Bakım', subCategory: 'Saç Bakımı'),
      Product(name: 'Head & Shoulders Mentol Ferahlığı Şampuan', brand: 'Head & Shoulders', price: '89.90 TL', rating: 4.4, reviewCount: 320, tags: ['En Çok Satan'], images: ['assets/products/Head & Shoulders Mentol Ferahlığı Şampuan.jpeg'], store: 'Migros', category: 'Kişisel Bakım', subCategory: 'Saç Bakımı', oldPrice: '120.00 TL'),
      Product(name: 'Elseve Şampuan Glycolic Gloss', brand: "L'Oreal Paris", price: '159.90 TL', rating: 4.7, reviewCount: 480, tags: ['Kampanyalı'], images: ['assets/products/Elseve Şampuan Glycolic Gloss.jpeg'], store: "L'Oreal Official", category: 'Kişisel Bakım', subCategory: 'Saç Bakımı'),
      Product(name: 'Dove Yoğun Onarım Şampuan', brand: 'Dove', price: '74.90 TL', rating: 4.2, reviewCount: 560, tags: ['Hızlı Kargo'], images: ['assets/products/Dove Yoğun Onarım Şampuan.jpeg'], store: 'Şok Market', category: 'Kişisel Bakım', subCategory: 'Saç Bakımı', oldPrice: '95.00 TL'),
      
      // Elektronik - Telefon
      Product(name: 'iPhone 15 Pro Max 1TB Natural Titanium', brand: 'Apple', price: '84.999 TL', rating: 4.9, reviewCount: 1200, tags: ['Hızlı Kargo'], images: ['assets/products/iphone15promax1Tb.jpeg'], store: 'Apple Store', category: 'Elektronik', subCategory: 'Telefon'),
      Product(name: 'Samsung Galaxy S24 Ultra 512GB Siyah', brand: 'Samsung', price: '69.999 TL', rating: 4.8, reviewCount: 1500, tags: ['En Çok Satan'], images: ['assets/products/s24_siyah_512gb.png'], store: 'Samsung Store', category: 'Elektronik', subCategory: 'Telefon', oldPrice: '79.999 TL'),
      Product(name: 'iPhone 15 Mavi 256GB', brand: 'Apple', price: '54.499 TL', rating: 4.7, reviewCount: 850, tags: ['Fırsat'], images: ['assets/products/iphone15_mavi_256gb.png'], store: 'Teknosa', category: 'Elektronik', subCategory: 'Telefon'),
      Product(name: 'Samsung Galaxy S24 Mor', brand: 'Samsung', price: '34.999 TL', rating: 4.6, reviewCount: 600, tags: ['Popüler'], images: ['assets/products/s24_mor.jpeg'], store: 'MediaMarkt', category: 'Elektronik', subCategory: 'Telefon'),
      
      // Elektronik - Bilgisayar/Tablet
      Product(name: 'MacBook Pro M3 Uzay Siyahı', brand: 'Apple', price: '79.999 TL', rating: 4.9, reviewCount: 800, tags: ['Popüler'], images: ['assets/products/macbook_pro_m3_space_black.jpg'], store: 'Apple Store', category: 'Elektronik', subCategory: 'Bilgisayar'),
      
      // Ev & Yaşam
      Product(name: 'Dyson V15 Detect Absolute Kablosuz Süpürge', brand: 'Dyson', price: '29.999 TL', rating: 4.9, reviewCount: 1800, tags: ['Premium'], images: ['assets/products/dyson_v15.jpeg'], store: 'Dyson', category: 'Ev & Yaşam', subCategory: 'Ev Aletleri'),
      Product(name: 'Ikea Billy Kitaplık', brand: 'Ikea', price: '2.499 TL', rating: 4.5, reviewCount: 900, tags: ['İndirimde'], images: ['assets/products/Ikea Billy Kitaplık.jpeg'], store: 'Ikea', category: 'Ev & Yaşam', subCategory: 'Mobilya'),
    ];

    // Filter: same category or brand, exclude current product
    var filtered = fallbackProducts.where((p) {
      if (p.name.toLowerCase() == initialProduct.name.toLowerCase()) return false;
      
      final pCategory = (p.category ?? '').toLowerCase();
      final pSubCategory = (p.subCategory ?? '').toLowerCase();
      final cSubCategory = (initialProduct.subCategory ?? '').toLowerCase();
      
      // Strong match: Subcategory match
      if (cSubCategory.isNotEmpty && pSubCategory == cSubCategory) return true;
      
      // Medium match: Brand match
      if (p.brand.toLowerCase() == currentBrand) return true;
      
      // Weak match: Category match
      if (pCategory == currentCategory) return true;
      
      return false;
    }).take(10).toList();

    // If no match found (or very few), return some popular items from the list
    if (filtered.length < 4) {
      final popular = fallbackProducts.where((p) => 
        p.name.toLowerCase() != initialProduct.name.toLowerCase() && 
        !filtered.contains(p)
      ).take(10 - filtered.length);
      filtered.addAll(popular);
    }

    return filtered;
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
      variantGroupId: dbProduct.variantGroupId,
    );
  }

  // Cart Logic
  void removeFromCart() {
    appState.removeFromCart(initialProduct);
    isAddedToCart = false;
    notifyListeners();
  }

  void addToCart() {
    // Find the title for warranty if applicable
    String warrantyTitle = this.warrantyTitle;

    List<String> services = [];
    if (isWarrantyAdded && warrantyTitle.isNotEmpty) {
      services.add(warrantyTitle);
    }
    if (isFastDeliverySelected) {
      services.add('Hızlı Kargo');
    }

    appState.addToCart(
      initialProduct.copyWith(
        selectedServices: services
      )
    );
    isAddedToCart = true;
    notifyListeners();
  }

  List<String> get images {
    final imgs = initialProduct.images.where((img) => img.trim().isNotEmpty).toList();
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
    } else if ((initialProduct.category ?? '').toLowerCase().contains('elektronik') || 
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
    } else if ((initialProduct.category ?? '').toLowerCase().contains('elektronik') || 
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
    } else if ((initialProduct.category ?? '').toLowerCase().contains('elektronik') || 
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
    // If warranty is not added, return original price format (preserving "25.000 TL" style)
    if (!isWarrantyAdded) {
      if (initialProduct.price.contains('TL')) {
        return initialProduct.price;
      }
      return '${initialProduct.price} TL';
    }

    // Base price
    double basePrice = _parsePrice(initialProduct.price);
    
    // Add warranty if selected
    basePrice += warrantyPrice;
    
    // Format back to string with Turkish locale (dots for thousands)
    return _formatPrice(basePrice);
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
      return '${buffer.toString()},${decimalPart} TL';
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
