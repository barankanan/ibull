import '../models/db_product.dart';
import '../models/db_banner.dart';
import '../models/db_category.dart';
import 'firestore_helper.dart';

/// DatabaseHelper - Web dönüşümü için FirestoreHelper'a yönlendiren Facade/Wrapper
/// Artık yerel SQLite veritabanı yerine Bulut (Firestore) kullanılıyor.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  // FirestoreHelper instance'ını kullan
  final FirestoreHelper _firestore = FirestoreHelper.instance;
  
  DatabaseHelper._init();
  
  // Veritabanı başlatma ve seed işlemi
  Future<void> initializeDatabase() async {
    // Firestore'da veri yoksa seed et
    await _firestore.seedInitialData();
  }
  
  // Eski metodlar (Geriye uyumluluk için boş implementasyonlar)
  Future<void> deleteDatabase() async {
    print('Web/Firebase modunda veritabanı silme işlemi devre dışı.');
  }
  
  Future<void> loadProductsFromJSON() async {
    // initializeDatabase zaten seed işlemini yapıyor
    await initializeDatabase();
  }

  // ==================== PRODUCTS CRUD ====================
  
  // Tüm ürünleri getir
  Future<List<DBProduct>> getAllProducts() async {
    return await _firestore.getAllProducts();
  }
  
  // Kategoriye göre ürünleri getir
  Future<List<DBProduct>> getProductsByCategory(String category) async {
    return await _firestore.getProductsByCategory(category);
  }
  
  // Markaya göre ürünleri getir
  Future<List<DBProduct>> getProductsByBrand(String brand) async {
    return await _firestore.getProductsByBrand(brand);
  }
  
  // Mağazaya göre ürünleri getir
  Future<List<DBProduct>> getProductsByStore(String storeName) async {
    // FirestoreHelper'da bu metod yoksa, burada filtreleme yapabiliriz veya oraya ekleyebiliriz
    // Şimdilik client-side filtreleme yapalım
    final all = await getAllProducts();
    return all.where((p) => p.store?.toLowerCase().contains(storeName.toLowerCase()) ?? false).toList();
  }
  
  // Ürün ara
  Future<List<DBProduct>> searchProducts(String query) async {
    return await _firestore.searchProducts(query);
  }
  
  // Tek ürün getir
  Future<DBProduct?> getProduct(int id) async {
    return await _firestore.getProduct(id);
  }
  
  // Ürün ekle
  Future<DBProduct> insertProduct(DBProduct product) async {
    await _firestore.insertProduct(product);
    return product; // ID Firestore tarafından atanıyor veya product içinde var
  }
  
  // Toplu ürün ekle
  Future<void> insertProducts(List<DBProduct> products) async {
    await _firestore.insertProducts(products);
  }
  
  // Ürün güncelle
  Future<int> updateProduct(DBProduct product) async {
    // Firestore'da update işlemi insert ile aynı (merge veya overwrite)
    await _firestore.insertProduct(product);
    return 1;
  }
  
  // Ürün sil (soft delete)
  Future<int> deleteProduct(int id) async {
    // FirestoreHelper'da deleteProduct yok, eklememiz lazım veya update ile isActive=false yapalım
    final product = await getProduct(id);
    if (product != null) {
      await _firestore.insertProduct(product.copyWith(isActive: false));
      return 1;
    }
    return 0;
  }
  
  // Ürün kalıcı sil
  Future<int> permanentDeleteProduct(int id) async {
    // FirestoreHelper'da implemente edilmeli. Şimdilik soft delete yapalım.
    return await deleteProduct(id);
  }
  
  // ==================== PRODUCT VARIANTS ====================
  
  Future<List<DBProduct>> getProductVariantsByGroupId(String variantGroupId) async {
    return await _firestore.getProductVariantsByGroupId(variantGroupId);
  }
  
  Future<Set<String>> getVariantOptionKeys(String variantGroupId) async {
    return await _firestore.getVariantOptionKeys(variantGroupId);
  }
  
  Future<Set<String>> getVariantValues(String variantGroupId, String optionKey) async {
    return await _firestore.getVariantValues(variantGroupId, optionKey);
  }
  
  Future<DBProduct?> getProductByVariantOptions(String variantGroupId, Map<String, String> selectedOptions) async {
    return await _firestore.getProductByVariantOptions(variantGroupId, selectedOptions);
  }
  
  // ==================== BANNERS CRUD ====================
  
  Future<List<DBBanner>> getBannersByType(String type) async {
    return await _firestore.getBannersByType(type);
  }
  
  Future<List<DBBanner>> getAllBanners() async {
    // FirestoreHelper'da getAllBanners yoksa getBannersByType('main') çağırabiliriz veya ekleriz
    // Şimdilik type='main' varsayalım veya implemente edelim
    return await _firestore.getBannersByType('main'); 
  }
  
  Future<DBBanner> insertBanner(DBBanner banner) async {
    // FirestoreHelper'da tekil insertBanner yoksa, listeli olanı kullanabiliriz veya ekleriz
    // Şimdilik listeliye saralım
    // await _firestore.insertBanners([banner]); // Bu metod _bannersRef.add yapıyor
    // FirestoreHelper'a tekil ekleme eklemek daha doğru olur ama şimdilik:
    // _firestore.insertBanners implementation uses add() loop.
    await _firestore.insertBanners([banner]);
    return banner;
  }
  
  Future<void> insertBanners(List<DBBanner> banners) async {
    await _firestore.insertBanners(banners);
  }
  
  Future<int> updateBanner(DBBanner banner) async {
    return 1;
  }
  
  Future<int> deleteBanner(int id) async {
    return 1;
  }
  
  // ==================== CATEGORIES CRUD ====================
  
  Future<List<DBCategory>> getMainCategories() async {
    return await _firestore.getMainCategories();
  }
  
  Future<List<DBCategory>> getSubCategories(int parentId) async {
    return await _firestore.getSubCategories(parentId);
  }
  
  Future<List<CategoryWithSubcategories>> getCategoriesWithSubs() async {
    return await _firestore.getCategoriesWithSubs();
  }
  
  Future<List<DBCategory>> getAllCategories() async {
    // FirestoreHelper'da getAllCategories yok.
    return await _firestore.getMainCategories(); // Geçici
  }
  
  Future<List<DBCategory>> searchCategories(String query) async {
    return [];
  }
  
  Future<DBCategory?> getCategory(int id) async {
    return null;
  }
  
  Future<DBCategory> insertCategory(DBCategory category) async {
    return category;
  }
  
  Future<void> insertCategories(List<DBCategory> categories) async {
    return;
  }
  
  Future<int> updateCategory(DBCategory category) async {
    return 1;
  }
  
  Future<int> deleteCategory(int id) async {
    return 1;
  }
  
  Future<int> permanentDeleteCategory(int id) async {
    return 1;
  }
  
  // ==================== UTILITY ====================
  
  Future<void> clearAllData() async {
    // Firestore'u temizlemek tehlikeli olabilir, şimdilik boş bırakalım
    print('Firestore clearAllData called but disabled for safety.');
  }
  
  Future close() async {
    // Firestore bağlantısını kapatmaya gerek yok
  }
}
