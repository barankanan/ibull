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
  CollectionReference get _productsRef => _firestore.collection('products');
  CollectionReference get _bannersRef => _firestore.collection('banners');
  CollectionReference get _categoriesRef => _firestore.collection('categories');

  // ==================== PRODUCTS CRUD ====================

  // Tüm ürünleri getir
  Future<List<DBProduct>> getAllProducts() async {
    try {
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          // .orderBy('id', descending: false) // İndeks hatasını önlemek için sıralamayı kaldırdık
          .get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DBProduct.fromMap(data);
      }).toList();
      
      // Client-side sıralama (ID'ye göre)
      products.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      
      return products;
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  // Kategoriye göre ürünleri getir
  Future<List<DBProduct>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _productsRef
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          // .orderBy('id', descending: true)
          .get();

      final products = snapshot.docs.map((doc) => DBProduct.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sıralama
      products.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      
      return products;
    } catch (e) {
      print('Error getting products by category: $e');
      return [];
    }
  }

  // Markaya göre ürünleri getir
  Future<List<DBProduct>> getProductsByBrand(String brand) async {
    try {
      final snapshot = await _productsRef
          .where('brand', isEqualTo: brand)
          .where('isActive', isEqualTo: true)
          // .orderBy('id', descending: true)
          .get();

      final products = snapshot.docs.map((doc) => DBProduct.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sıralama
      products.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      
      return products;
    } catch (e) {
      print('Error getting products by brand: $e');
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
      print('Error searching products: $e');
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
        return DBProduct.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  // Ürün ekle
  Future<void> insertProduct(DBProduct product) async {
    try {
      // ID yönetimi: Eğer ID yoksa, yeni bir ID oluşturmamız lazım.
      // Basitlik için timestamp kullanalım veya mevcut en yüksek ID + 1
      int newId = product.id ?? DateTime.now().millisecondsSinceEpoch;
      
      final productWithId = product.copyWith(id: newId);
      
      // Belge ID'si olarak da bu int ID'nin string halini kullanalım
      await _productsRef.doc(newId.toString()).set(productWithId.toMap());
    } catch (e) {
      print('Error inserting product: $e');
    }
  }

  // Toplu ürün ekle (Batch write)
  Future<void> insertProducts(List<DBProduct> products) async {
    try {
      final batch = _firestore.batch();
      
      for (var product in products) {
        int newId = product.id ?? DateTime.now().millisecondsSinceEpoch + products.indexOf(product);
        final productWithId = product.copyWith(id: newId);
        final docRef = _productsRef.doc(newId.toString());
        batch.set(docRef, productWithId.toMap());
      }
      
      await batch.commit();
    } catch (e) {
      print('Error batch inserting products: $e');
    }
  }

  // ==================== PRODUCT VARIANTS ====================

  // Varyant grubuna göre tüm ürünleri getir
  Future<List<DBProduct>> getProductVariantsByGroupId(String variantGroupId) async {
    try {
      final snapshot = await _productsRef
          .where('variantGroupId', isEqualTo: variantGroupId)
          .where('isActive', isEqualTo: true)
          // .orderBy('id', descending: false)
          .get();

      final products = snapshot.docs.map((doc) => DBProduct.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sıralama
      products.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      
      return products;
    } catch (e) {
      print('Error getting product variants: $e');
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
      await _bannersRef.add(banner.toMap());
    }
  }

  Future<List<DBBanner>> getBannersByType(String type) async {
    try {
      final snapshot = await _bannersRef
          .where('type', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          // .orderBy('orderIndex', descending: false)
          .get();

      final banners = snapshot.docs.map((doc) => DBBanner.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sıralama
      banners.sort((a, b) => (a.orderIndex ?? 0).compareTo(b.orderIndex ?? 0));
      
      return banners;
    } catch (e) {
      print('Error getting banners: $e');
      return [];
    }
  }

  // ==================== CATEGORIES CRUD ====================

  Future<List<DBCategory>> getMainCategories() async {
    try {
      // Firestore'da null sorgusu: where('parentId', isNull: true)
      final snapshot = await _categoriesRef
          .where('parentId', isNull: true)
          .where('isActive', isEqualTo: true)
          // .orderBy('orderIndex', descending: false)
          .get();

      final categories = snapshot.docs.map((doc) => DBCategory.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sıralama
      categories.sort((a, b) => (a.orderIndex ?? 0).compareTo(b.orderIndex ?? 0));
      
      return categories;
    } catch (e) {
      print('Error getting main categories: $e');
      return [];
    }
  }

  Future<List<DBCategory>> getSubCategories(int parentId) async {
    try {
      final snapshot = await _categoriesRef
          .where('parentId', isEqualTo: parentId)
          .where('isActive', isEqualTo: true)
          // .orderBy('orderIndex', descending: false)
          .get();

      final categories = snapshot.docs.map((doc) => DBCategory.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sıralama
      categories.sort((a, b) => (a.orderIndex ?? 0).compareTo(b.orderIndex ?? 0));
      
      return categories;
    } catch (e) {
      print('Error getting subcategories: $e');
      return [];
    }
  }
  
  // İlk verileri yükleme (Seeding)
  Future<void> seedInitialData() async {
    final snapshot = await _productsRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }
    
    print('🌱 Firestore boş, örnek veriler yükleniyor...');
    
    // 1. Ürünleri Ekle
    final products = [
      DBProduct(
        name: 'CT-Z3 2300 W Infinity Motor Süpürge',
        brand: 'Arçelik',
        price: '3.890 TL',
        oldPrice: '4.862 TL',
        rating: 4.8,
        reviewCount: 62,
        imageUrl: 'assets/images/products/product_placeholder.png',
        imageUrls: '["assets/images/products/product_placeholder.png"]',
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
        imageUrl: 'assets/images/products/product_placeholder.png',
        imageUrls: '["assets/images/products/product_placeholder.png"]',
        category: 'Elektronik',
        tags: '["Hızlı Kargo"]',
        description: 'Solar şarj teknolojisi ile akıllı saat',
        specifications: '{"Ekran": "1.43 inç AMOLED", "Pil Ömrü": "21 gün", "Su Geçirmezlik": "5ATM", "Sensörler": "Nabız, SpO2, GPS"}',
        stock: 8,
        isActive: true,
      ),
    ];
    
    await insertProducts(products);
    print('✅ ${products.length} ürün eklendi');

    // 2. Bannerları Ekle
    final banners = [
      DBBanner(
        imageUrl: 'assets/images/banners/banner_placeholder.png',
        link: null,
        orderIndex: 1,
        type: 'main',
        title: 'Kış İndirimleri',
        description: '%50\'ye varan indirimler',
        isActive: true,
      ),
      DBBanner(
        imageUrl: 'assets/images/banners/banner_placeholder.png',
        link: null,
        orderIndex: 2,
        type: 'main',
        title: 'Ücretsiz Kargo',
        description: 'Tüm ürünlerde ücretsiz kargo',
        isActive: true,
      ),
    ];

    for (var banner in banners) {
      await _bannersRef.add(banner.toMap());
    }
    print('✅ ${banners.length} banner eklendi');

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
      if (category.id != null) {
        await _categoriesRef.doc(category.id.toString()).set(category.toMap());
      } else {
        await _categoriesRef.add(category.toMap());
      }
    }
    print('✅ ${categories.length} kategori eklendi');
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
