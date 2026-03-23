import 'package:flutter/foundation.dart';

import '../models/db_product.dart';
import '../models/db_banner.dart';
import '../models/db_category.dart';
import '../models/paged_result.dart';
import 'supabase_service.dart';

/// DatabaseHelper - Web dönüşümü için SupabaseService'e yönlendiren Facade/Wrapper
/// Artık yerel SQLite veritabanı yerine Bulut (Supabase) kullanılıyor.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  // SupabaseService instance'ını kullan
  final SupabaseService _supabase = SupabaseService.instance;

  DatabaseHelper._init();

  // Veritabanı başlatma ve seed işlemi
  Future<void> initializeDatabase() async {
    // Supabase'de veri yoksa seed et
    await _supabase.seedInitialData();
  }

  // Eski metodlar (Geriye uyumluluk için boş implementasyonlar)
  Future<void> deleteDatabase() async {
    debugPrint('Web/Supabase modunda veritabanı silme işlemi devre dışı.');
  }

  Future<void> loadProductsFromJSON() async {
    // initializeDatabase zaten seed işlemini yapıyor
    await initializeDatabase();
  }

  // ==================== PRODUCTS CRUD ====================

  // Tüm ürünleri getir
  Future<List<DBProduct>> getAllProducts() async {
    return await _supabase.getAllProducts();
  }

  Future<List<DBProduct>> getProductsPage({
    int limit = SupabaseService.defaultPageSize,
    int offset = 0,
    String? category,
    String? brand,
    String? searchQuery,
  }) async {
    return await _supabase.getProductsPage(
      limit: limit,
      offset: offset,
      category: category,
      brand: brand,
      searchQuery: searchQuery,
    );
  }

  // Kategoriye göre ürünleri getir
  Future<List<DBProduct>> getProductsByCategory(String category) async {
    return await _supabase.getProductsByCategory(category);
  }

  Future<PagedResult<DBProduct>> getCategoryProductsPaged({
    required String category,
    String? subCategory,
    int limit = SupabaseService.defaultPageSize,
    String? cursor,
  }) async {
    return await _supabase.getCategoryProductsPaged(
      category: category,
      subCategory: subCategory,
      limit: limit,
      cursor: cursor,
    );
  }

  // Markaya göre ürünleri getir
  Future<List<DBProduct>> getProductsByBrand(String brand) async {
    return await _supabase.getProductsByBrand(brand);
  }

  // Mağazaya göre ürünleri getir
  Future<List<DBProduct>> getProductsByStore(
    String storeName, {
    int limit = 20,
  }) async {
    return await _supabase.getProductsByStore(
      storeName: storeName,
      limit: limit,
    );
  }

  Future<Map<String, List<DBProduct>>> getProductsPreviewByStores({
    List<String> sellerIds = const [],
    List<String> storeNames = const [],
    int perStoreLimit = 5,
  }) async {
    return await _supabase.getProductsPreviewByStores(
      sellerIds: sellerIds,
      storeNames: storeNames,
      perStoreLimit: perStoreLimit,
    );
  }

  // Ürün ara
  Future<List<DBProduct>> searchProducts(String query) async {
    return await _supabase.searchProducts(query);
  }

  Future<List<DBProduct>> getProductSuggestions({
    required String query,
    int limit = 8,
  }) async {
    return await _supabase.getProductSuggestions(query: query, limit: limit);
  }

  // Tek ürün getir
  Future<DBProduct?> getProduct(int id) async {
    return await _supabase.getProduct(id);
  }

  // Ürün ekle
  Future<DBProduct> insertProduct(DBProduct product) async {
    await _supabase.insertProduct(product);
    return product; // ID Supabase tarafından atanıyor veya product içinde var
  }

  // Toplu ürün ekle
  Future<void> insertProducts(List<DBProduct> products) async {
    await _supabase.insertProducts(products);
  }

  // Ürün güncelle
  Future<int> updateProduct(DBProduct product) async {
    // Supabase'de update işlemi insert ile aynı (upsert)
    await _supabase.insertProduct(product);
    return 1;
  }

  // Ürün sil (soft delete)
  Future<int> deleteProduct(int id) async {
    // SupabaseService'de deleteProduct yok, eklememiz lazım veya update ile isActive=false yapalım
    final product = await getProduct(id);
    if (product != null) {
      await _supabase.insertProduct(product.copyWith(isActive: false));
      return 1;
    }
    return 0;
  }

  // Ürün kalıcı sil
  Future<int> permanentDeleteProduct(int id) async {
    // SupabaseService'de implemente edilmeli. Şimdilik soft delete yapalım.
    return await deleteProduct(id);
  }

  // ==================== PRODUCT VARIANTS ====================

  Future<List<DBProduct>> getProductVariantsByGroupId(
    String variantGroupId,
  ) async {
    return await _supabase.getProductVariantsByGroupId(variantGroupId);
  }

  Future<Set<String>> getVariantOptionKeys(String variantGroupId) async {
    return await _supabase.getVariantOptionKeys(variantGroupId);
  }

  Future<Set<String>> getVariantValues(
    String variantGroupId,
    String optionKey,
  ) async {
    return await _supabase.getVariantValues(variantGroupId, optionKey);
  }

  Future<DBProduct?> getProductByVariantOptions(
    String variantGroupId,
    Map<String, String> selectedOptions,
  ) async {
    return await _supabase.getProductByVariantOptions(
      variantGroupId,
      selectedOptions,
    );
  }

  // ==================== BANNERS CRUD ====================

  Future<List<DBBanner>> getBannersByType(String type) async {
    return await _supabase.getBannersByType(type);
  }

  Future<List<DBBanner>> getAllBanners() async {
    // SupabaseService'de getAllBanners yoksa getBannersByType('main') çağırabiliriz veya ekleriz
    // Şimdilik type='main' varsayalım veya implemente edelim
    return await _supabase.getBannersByType('main');
  }

  Future<DBBanner> insertBanner(DBBanner banner) async {
    await _supabase.insertBanners([banner]);
    return banner;
  }

  Future<void> insertBanners(List<DBBanner> banners) async {
    await _supabase.insertBanners(banners);
  }

  Future<int> updateBanner(DBBanner banner) async {
    return 1;
  }

  Future<int> deleteBanner(int id) async {
    return 1;
  }

  // ==================== CATEGORIES CRUD ====================

  Future<List<DBCategory>> getMainCategories() async {
    return await _supabase.getMainCategories();
  }

  Future<List<DBCategory>> getSubCategories(int parentId) async {
    return await _supabase.getSubCategories(parentId);
  }

  Future<List<CategoryWithSubcategories>> getCategoriesWithSubs() async {
    return await _supabase.getCategoriesWithSubs();
  }

  Future<List<DBCategory>> getAllCategories() async {
    // SupabaseService'de getAllCategories yok.
    return await _supabase.getMainCategories(); // Geçici
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
    // Supabase'i temizlemek tehlikeli olabilir, şimdilik boş bırakalım
    debugPrint('Supabase clearAllData called but disabled for safety.');
  }

  Future close() async {
    // Supabase bağlantısını kapatmaya gerek yok
  }
}
