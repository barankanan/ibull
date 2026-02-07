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

        final pCategory = (p.category ?? '').toLowerCase();
        final pSubCategory = (p.subCategory ?? '').toLowerCase();

        return pCategory == currentCategory || pSubCategory == currentSubCategory;
      }).map((dbP) => _convertToProduct(dbP)).take(10).toList();

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

    if (groupId == null || groupId.isEmpty) return;

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
    } catch (e) {
      debugPrint('Error loading variants: $e');
    } finally {
      loadingVariants = false;
      notifyListeners();
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
