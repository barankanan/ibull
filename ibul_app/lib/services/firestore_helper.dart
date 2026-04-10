import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/db_product.dart';
import '../models/db_banner.dart';
import '../models/db_category.dart';

class FirestoreHelper {
  // Singleton pattern
  static final FirestoreHelper instance = FirestoreHelper._init();
  FirestoreHelper._init();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference<Map<String, dynamic>> get _productsRef => _firestore.collection('products');
  CollectionReference<Map<String, dynamic>> get _bannersRef => _firestore.collection('banners');
  CollectionReference<Map<String, dynamic>> get _categoriesRef => _firestore.collection('categories');

  Map<String, dynamic> _normalizeFirestorePayload(Map<String, dynamic> raw) {
    final payload = Map<String, dynamic>.from(raw);
    final isActive = payload['isActive'];
    if (isActive is int) {
      payload['isActive'] = isActive == 1;
    }
    final isPart = payload['isPart'];
    if (isPart is int) {
      payload['isPart'] = isPart == 1;
    }
    return payload;
  }

  int _productIdValue(String? id) => int.tryParse(id ?? '') ?? 0;

  // ==================== PRODUCTS CRUD ====================

  // Tüm ürünleri getir
  Future<List<DBProduct>> getAllProducts() async {
    try {
      final snapshot = await _productsRef
          .where('isActive', whereIn: [true, 1])
          // .orderBy('id', descending: false) // İndeks hatasını önlemek için sıralamayı kaldırdık
          .get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        return DBProduct.fromMap(data);
      }).toList();
      
      // Client-side sıralama (ID'ye göre)
      products.sort((a, b) => _productIdValue(a.id).compareTo(_productIdValue(b.id)));
      
      return products;
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  // Kategoriye göre ürünleri getir
  Future<List<DBProduct>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _productsRef
          .where('category', isEqualTo: category)
          .where('isActive', whereIn: [true, 1])
          // .orderBy('id', descending: true)
          .get();

      final products = snapshot.docs.map((doc) => DBProduct.fromMap(doc.data())).toList();
      
      // Client-side sıralama
      products.sort((a, b) => _productIdValue(b.id).compareTo(_productIdValue(a.id)));
      
      return products;
    } catch (e) {
      debugPrint('Error getting products by category: $e');
      return [];
    }
  }

  // Markaya göre ürünleri getir
  Future<List<DBProduct>> getProductsByBrand(String brand) async {
    try {
      final snapshot = await _productsRef
          .where('brand', isEqualTo: brand)
          .where('isActive', whereIn: [true, 1])
          // .orderBy('id', descending: true)
          .get();

      final products = snapshot.docs.map((doc) => DBProduct.fromMap(doc.data())).toList();
      
      // Client-side sıralama
      products.sort((a, b) => _productIdValue(b.id).compareTo(_productIdValue(a.id)));
      
      return products;
    } catch (e) {
      debugPrint('Error getting products by brand: $e');
      return [];
    }
  }

  // Ürün ara (Basit arama - Firestore tam metin aramayı desteklemez, bu yüzden sadece başlangıç eşleşmesi veya client-side filtreleme)
  Future<List<DBProduct>> searchProducts(String query) async {
    // Not: Gerçek bir arama için Algolia veya benzeri bir servis önerilir.
    // Burada client-side filtreleme yapacağız (küçük veri setleri için uygun)
    try {
      final allProducts = await getAllProducts();
      final lowerQuery = query.toLowerCase();
      
      return allProducts.where((product) {
        return product.name.toLowerCase().contains(lowerQuery) ||
               product.brand.toLowerCase().contains(lowerQuery) ||
               (product.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  // Tek ürün getir
  Future<DBProduct?> getProduct(int id) async {
    try {
      final snapshot = await _productsRef
          .where('id', isEqualTo: id)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DBProduct.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product: $e');
      return null;
    }
  }

  // Ürün ekle
  Future<void> insertProduct(DBProduct product) async {
    try {
      // ID yönetimi: Eğer ID yoksa, yeni bir ID oluşturmamız lazım.
      // Basitlik için timestamp kullanalım veya mevcut en yüksek ID + 1
      final newId = product.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      final productWithId = product.copyWith(id: newId);
      
      // Belge ID'si olarak da bu int ID'nin string halini kullanalım
      await _productsRef.doc(newId).set(_normalizeFirestorePayload(productWithId.toMap()));
    } catch (e) {
      debugPrint('Error inserting product: $e');
    }
  }

  // Toplu ürün ekle (Batch write)
  Future<void> insertProducts(List<DBProduct> products) async {
    try {
      if (products.isEmpty) {
        return;
      }

      const maxWritesPerBatch = 400;
      final baseId = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < products.length; i += maxWritesPerBatch) {
        final batch = _firestore.batch();
        final end = (i + maxWritesPerBatch) > products.length ? products.length : (i + maxWritesPerBatch);

        for (var j = i; j < end; j++) {
          final product = products[j];
          final newId = product.id ?? (baseId + j).toString();
          final productWithId = product.copyWith(id: newId);
          final docRef = _productsRef.doc(newId);
          batch.set(docRef, _normalizeFirestorePayload(productWithId.toMap()));
        }

        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error batch inserting products: $e');
    }
  }

  // ==================== PRODUCT VARIANTS ====================

  // Varyant grubuna göre tüm ürünleri getir
  Future<List<DBProduct>> getProductVariantsByGroupId(String variantGroupId) async {
    try {
      final snapshot = await _productsRef
          .where('variantGroupId', isEqualTo: variantGroupId)
          .where('isActive', whereIn: [true, 1])
          // .orderBy('id', descending: false)
          .get();

      final products = snapshot.docs.map((doc) => DBProduct.fromMap(doc.data())).toList();
      
      // Client-side sıralama
      products.sort((a, b) => _productIdValue(a.id).compareTo(_productIdValue(b.id)));
      
      return products;
    } catch (e) {
      debugPrint('Error getting product variants: $e');
      return [];
    }
  }

  // Bir varyant grubunun seçenek anahtarlarını getir
  Future<Set<String>> getVariantOptionKeys(String variantGroupId) async {
    final variants = await getProductVariantsByGroupId(variantGroupId);
    final Set<String> keys = {};
    
    for (var variant in variants) {
      if (variant.variantOptions != null) {
        final optionsMap = variant.getVariantOptionsMap();
        keys.addAll(optionsMap.keys);
      }
    }
    
    return keys;
  }

  // Bir seçenek anahtarı için mevcut değerleri getir
  Future<Set<String>> getVariantValues(String variantGroupId, String optionKey) async {
    final variants = await getProductVariantsByGroupId(variantGroupId);
    final Set<String> values = {};
    
    for (var variant in variants) {
      if (variant.variantOptions != null) {
        final optionsMap = variant.getVariantOptionsMap();
        if (optionsMap.containsKey(optionKey)) {
          values.add(optionsMap[optionKey]!);
        }
      }
    }
    
    return values;
  }

  // Seçilen varyant kombinasyonuna göre ürün bul
  Future<DBProduct?> getProductByVariantOptions(
    String variantGroupId,
    Map<String, String> selectedOptions,
  ) async {
    final variants = await getProductVariantsByGroupId(variantGroupId);
    
    for (var variant in variants) {
      if (variant.variantOptions == null) continue;
      
      final variantOptionsMap = variant.getVariantOptionsMap();
      
      // Tüm seçilen opsiyonlar eşleşiyor mu kontrol et
      bool matches = true;
      for (var entry in selectedOptions.entries) {
        if (variantOptionsMap[entry.key] != entry.value) {
          matches = false;
          break;
        }
      }
      
      if (matches) {
        return variant;
      }
    }
    
    return null;
  }

  // ==================== BANNERS CRUD ====================

  Future<void> insertBanners(List<DBBanner> banners) async {
    for (var banner in banners) {
      await _bannersRef.add(_normalizeFirestorePayload(banner.toMap()));
    }
  }

  Future<List<DBBanner>> getBannersByType(String type) async {
    try {
      final snapshot = await _bannersRef
          .where('type', isEqualTo: type)
          .where('isActive', whereIn: [true, 1])
          // .orderBy('orderIndex', descending: false)
          .get();

      final banners = snapshot.docs.map((doc) => DBBanner.fromMap(doc.data())).toList();
      
      // Client-side sıralama
      banners.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      
      return banners;
    } catch (e) {
      debugPrint('Error getting banners: $e');
      return [];
    }
  }

  // ==================== CATEGORIES CRUD ====================

  Future<List<DBCategory>> getMainCategories() async {
    try {
      // Firestore'da null sorgusu: where('parentId', isNull: true)
      final snapshot = await _categoriesRef
          .where('parentId', isNull: true)
          .where('isActive', whereIn: [true, 1])
          // .orderBy('orderIndex', descending: false)
          .get();

      final categories = snapshot.docs.map((doc) => DBCategory.fromMap(doc.data())).toList();
      
      // Client-side sıralama
      categories.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      
      return categories;
    } catch (e) {
      debugPrint('Error getting main categories: $e');
      return [];
    }
  }

  Future<List<DBCategory>> getSubCategories(int parentId) async {
    try {
      final snapshot = await _categoriesRef
          .where('parentId', isEqualTo: parentId)
          .where('isActive', whereIn: [true, 1])
          // .orderBy('orderIndex', descending: false)
          .get();

      final categories = snapshot.docs.map((doc) => DBCategory.fromMap(doc.data())).toList();
      
      // Client-side sıralama
      categories.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      
      return categories;
    } catch (e) {
      debugPrint('Error getting subcategories: $e');
      return [];
    }
  }
  
  // Eski verileri packages/ibul_app öneki ile güncelle
  Future<void> _fixImagePaths() async {
    try {
      // 1. Ürünleri düzelt
      final productSnapshot = await _productsRef.where('isActive', isEqualTo: true).get();
      int updatedCount = 0;
      
      final batch = _firestore.batch();
      
      for (var doc in productSnapshot.docs) {
        final data = doc.data();
        String imageUrl = data['imageUrl'] ?? '';
        String imageUrls = data['imageUrls'] ?? '[]';
        
        bool needsUpdate = false;
        
        // Ana görseli kontrol et
        if (imageUrl.isNotEmpty && imageUrl.startsWith('assets/') && !imageUrl.startsWith('packages/ibul_app/')) {
          imageUrl = 'packages/ibul_app/$imageUrl';
          needsUpdate = true;
        }
        
        // Görsel listesini kontrol et
        if (imageUrls.isNotEmpty && imageUrls != '[]') {
          try {
            List<dynamic> urls = json.decode(imageUrls);
            bool listChanged = false;
            for (int i = 0; i < urls.length; i++) {
              String url = urls[i].toString();
              if (url.startsWith('assets/') && !url.startsWith('packages/ibul_app/')) {
                urls[i] = 'packages/ibul_app/$url';
                listChanged = true;
              }
            }
            if (listChanged) {
              imageUrls = json.encode(urls);
              needsUpdate = true;
            }
          } catch (e) {
            // JSON hatası olursa yoksay
          }
        }
        
        if (needsUpdate) {
          batch.update(doc.reference, {
            'imageUrl': imageUrl,
            'imageUrls': imageUrls,
          });
          updatedCount++;
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('🛠️ $updatedCount ürün görsel yolu düzeltildi (packages/ibul_app/ eklendi)');
      }
      
      // 2. Bannerları düzelt
      final bannerSnapshot = await _bannersRef.where('isActive', isEqualTo: true).get();
      int updatedBanners = 0;
      final bannerBatch = _firestore.batch();
      
      for (var doc in bannerSnapshot.docs) {
        final data = doc.data();
        String imageUrl = data['imageUrl'] ?? '';
        
        if (imageUrl.isNotEmpty && imageUrl.startsWith('assets/') && !imageUrl.startsWith('packages/ibul_app/')) {
          imageUrl = 'packages/ibul_app/$imageUrl';
          bannerBatch.update(doc.reference, {'imageUrl': imageUrl});
          updatedBanners++;
        }
      }
      
      if (updatedBanners > 0) {
        await bannerBatch.commit();
        debugPrint('🛠️ $updatedBanners banner görsel yolu düzeltildi');
      }
      
    } catch (e) {
      debugPrint('Error fixing image paths: $e');
    }
  }

  Future<void> seedInitialData() async {
    // 1. Önce eski yolları düzelt
    await _fixImagePaths();
    
    final snapshot = await _productsRef.limit(5).get();

    if (snapshot.docs.length >= 5) {
      await _seedBanners();
      await _seedCategories();
      return;
    }

    debugPrint('🌱 Veri kontrolü yapılıyor, eksik veriler assets/urunler.json dosyasından tamamlanacak...');
    
    try {
      // JSON dosyasını doğrudan uygulama asset'inden oku
      final jsonString = await rootBundle.loadString('packages/ibul_app/assets/urunler.json');
      
      final List<dynamic> jsonList = json.decode(jsonString);
      
      // Mevcut ürün isimlerini al (tekrar eklememek için)
      final existingNames = snapshot.docs
          .map((doc) => (doc.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet();
      
      final List<DBProduct> productsToAdd = [];
      
      for (var item in jsonList) {
        final name = (item['isim'] ?? '').toString().trim();
        if (name.isEmpty || existingNames.contains(name)) continue;

        // Fiyat formatlama: 64.999 (double) -> "64.999 TL"
        // Eğer tam sayı ise: 2500 -> "2.500 TL" formatı gerekebilir ama şimdilik basit toString
        final price = (item['fiyat'] ?? '').toString();
        // Eğer nokta yoksa ve 3 haneden büyükse binlik ayracı ekle (basitçe)
        // Ama JSON'da zaten 64.999 gibi nokta ile geliyor.
        
        productsToAdd.add(DBProduct(
          name: name,
          brand: (item['marka'] ?? '').toString(),
          store: (item['magaza'] ?? '').toString(),
          price: "$price TL",
          oldPrice: item['eski_fiyat'] != null ? "${item['eski_fiyat']} TL" : null,
          rating: (item['puan'] as num?)?.toDouble() ?? 0,
          reviewCount: (item['degerlendirme'] as num?)?.toInt() ?? 0,
          imageUrl: (item['gorseller'] is List && (item['gorseller'] as List).isNotEmpty)
              ? (item['gorseller'] as List).first.toString()
              : '',
          imageUrls: json.encode(item['gorseller'] ?? []),
          category: (item['kategori'] ?? 'Diğer').toString(),
          subCategory: item['alt_kategori']?.toString(),
          tags: json.encode(item['etiketler'] ?? []),
          description: item['aciklama']?.toString(),
          specifications: json.encode(item['ozellikler'] ?? {}),
          stock: (item['stok'] as num?)?.toInt(),
          variantGroupId: item['varyant_grup_id']?.toString(),
          variantOptions: item['varyant_secenekler']?.toString(),
          isActive: true,
        ));
      }
      
      if (productsToAdd.isNotEmpty) {
        await insertProducts(productsToAdd);
        debugPrint('✅ ${productsToAdd.length} ürün JSON\'dan eklendi');
      } else {
        debugPrint('ℹ️ Eklenecek yeni ürün bulunamadı.');
      }

    } catch (e) {
      debugPrint('Error seeding from JSON: $e');
      // JSON yüklenemezse fallback olarak manuel ekle
      if (snapshot.docs.isEmpty) {
        await _seedFallbackProducts();
      }
    }

    // Banner ve Kategorileri de kontrol et
    await _seedBanners();
    await _seedCategories();
  }

  Future<void> _seedFallbackProducts() async {
    // 1. Ürünleri Ekle
    final products = [
      DBProduct(
        name: 'CT-Z3 2300 W Infinity Motor Süpürge',
        brand: 'Arçelik',
        price: '3.890 TL',
        oldPrice: '4.862 TL',
        rating: 4.8,
        reviewCount: 62,
        imageUrl: 'packages/ibul_app/assets/products/dyson_v15.jpeg',
        imageUrls: '["packages/ibul_app/assets/products/dyson_v15.jpeg"]',
        category: 'Elektronik',
        tags: '["Ücretsiz Kargo", "%25 indirim"]',
        description: 'Güçlü motor teknolojisi ile derin temizlik',
        specifications: '{"Güç": "2300W", "Motor": "Infinity Motor", "Toz Kapasitesi": "2.5L", "Kablo Uzunluğu": "8m"}',
        stock: 15,
        isActive: true,
      ),
      DBProduct(
        name: 'Solar Plus RT3 Akıllı Saat',
        brand: 'Haylou',
        price: '2.500 TL',
        oldPrice: null,
        rating: 3.0,
        reviewCount: 2,
        imageUrl: 'packages/ibul_app/assets/products/sony_xm5.jpg',
        imageUrls: '["packages/ibul_app/assets/products/sony_xm5.jpg"]',
        category: 'Elektronik',
        tags: '["Hızlı Kargo"]',
        description: 'Solar şarj teknolojisi ile akıllı saat',
        specifications: '{"Ekran": "1.43 inç AMOLED", "Pil Ömrü": "21 gün", "Su Geçirmezlik": "5ATM", "Sensörler": "Nabız, SpO2, GPS"}',
        stock: 8,
        isActive: true,
      ),
    ];
    
    await insertProducts(products);
    debugPrint('✅ ${products.length} ürün (fallback) eklendi');
  }

  Future<void> _seedBanners() async {
    final snapshot = await _bannersRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    // 2. Bannerları Ekle
    final banners = [
      DBBanner(
        imageUrl: 'packages/ibul_app/assets/images/banners/gorsel-zeka-banner.png',
        link: null,
        orderIndex: 1,
        type: 'main',
        title: 'Kış İndirimleri',
        description: '%50\'ye varan indirimler',
        isActive: true,
      ),
      DBBanner(
        imageUrl: 'packages/ibul_app/assets/images/banners/yakin-lokasyon-banner.png',
        link: null,
        orderIndex: 2,
        type: 'main',
        title: 'Ücretsiz Kargo',
        description: 'Tüm ürünlerde ücretsiz kargo',
        isActive: true,
      ),
    ];

    for (var banner in banners) {
      await _bannersRef.add(_normalizeFirestorePayload(banner.toMap()));
    }
    debugPrint('✅ ${banners.length} banner eklendi');
  }

  Future<void> _seedCategories() async {
    final snapshot = await _categoriesRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    // 3. Kategorileri Ekle
    final categories = [
      // Ana Kategoriler
      DBCategory(id: 1, name: 'Elektronik', iconName: 'phone_android', orderIndex: 1, parentId: null, isActive: true),
      DBCategory(id: 2, name: 'Moda', iconName: 'checkroom', orderIndex: 2, parentId: null, isActive: true),
      DBCategory(id: 3, name: 'Ev & Yaşam', iconName: 'home', orderIndex: 3, parentId: null, isActive: true),
      DBCategory(id: 4, name: 'Kozmetik', iconName: 'spa', orderIndex: 4, parentId: null, isActive: true),
      DBCategory(id: 5, name: 'Spor & Outdoor', iconName: 'sports_soccer', orderIndex: 5, parentId: null, isActive: true),
      DBCategory(id: 6, name: 'Süpermarket', iconName: 'shopping_cart', orderIndex: 6, parentId: null, isActive: true),
      DBCategory(id: 7, name: 'Kitap & Hobi', iconName: 'menu_book', orderIndex: 7, parentId: null, isActive: true),
      DBCategory(id: 8, name: 'Oyuncak & Bebek', iconName: 'child_care', orderIndex: 8, parentId: null, isActive: true),
      DBCategory(id: 9, name: '2.el Ürünler', iconName: 'recycling', orderIndex: 9, parentId: null, isActive: true),
      
      // Elektronik Alt Kategorileri
      DBCategory(name: 'Telefon & Aksesuar', orderIndex: 1, parentId: 1, isActive: true),
      DBCategory(name: 'Bilgisayar & Tablet', orderIndex: 2, parentId: 1, isActive: true),
      DBCategory(name: 'TV & Ses Sistemleri', orderIndex: 3, parentId: 1, isActive: true),
      DBCategory(name: 'Beyaz Eşya', orderIndex: 4, parentId: 1, isActive: true),
      DBCategory(name: 'Klima & Isıtıcı', orderIndex: 5, parentId: 1, isActive: true),
      
      // Moda Alt Kategorileri
      DBCategory(name: 'Kadın Giyim', orderIndex: 1, parentId: 2, isActive: true),
      DBCategory(name: 'Erkek Giyim', orderIndex: 2, parentId: 2, isActive: true),
      DBCategory(name: 'Ayakkabı & Çanta', orderIndex: 3, parentId: 2, isActive: true),
      DBCategory(name: 'Saat & Aksesuar', orderIndex: 4, parentId: 2, isActive: true),
      DBCategory(name: 'Çocuk Giyim', orderIndex: 5, parentId: 2, isActive: true),
      
      // Ev & Yaşam Alt Kategorileri
      DBCategory(name: 'Mobilya', orderIndex: 1, parentId: 3, isActive: true),
      DBCategory(name: 'Ev Tekstili', orderIndex: 2, parentId: 3, isActive: true),
      DBCategory(name: 'Mutfak & Sofra', orderIndex: 3, parentId: 3, isActive: true),
      DBCategory(name: 'Mutfak Gereçleri', orderIndex: 4, parentId: 3, isActive: true),
      DBCategory(name: 'Banyo & Organizasyon', orderIndex: 5, parentId: 3, isActive: true),
      DBCategory(name: 'Aydınlatma & Dekorasyon', orderIndex: 6, parentId: 3, isActive: true),
    ];

    for (var category in categories) {
      // Kategori ID'si varsa onu kullan, yoksa otomatik
      final payload = _normalizeFirestorePayload(category.toMap());
      if (category.id != null) {
        await _categoriesRef.doc(category.id.toString()).set(payload);
      } else {
        await _categoriesRef.add(payload);
      }
    }
    debugPrint('✅ ${categories.length} kategori eklendi');
  }

  // ==================== UTILITY ====================
  
  // Kategori ve alt kategorilerini birlikte getir
  Future<List<CategoryWithSubcategories>> getCategoriesWithSubs() async {
    final mainCategories = await getMainCategories();
    final List<CategoryWithSubcategories> result = [];
    
    for (var mainCat in mainCategories) {
      final subs = await getSubCategories(mainCat.id!);
      result.add(CategoryWithSubcategories(
        mainCategory: mainCat,
        subCategories: subs,
      ));
    }
    
    return result;
  }
}
