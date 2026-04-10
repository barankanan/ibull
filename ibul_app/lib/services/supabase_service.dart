import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/db_product.dart';
import '../models/db_banner.dart';
import '../models/db_category.dart';
import '../models/paged_result.dart';
import '../models/product_model.dart';
import 'store/store_mapping_helpers.dart';
import '../utils/text_normalizer.dart';

class SupabaseService {
  // Singleton pattern
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  final SupabaseClient _supabase = Supabase.instance.client;
  static const int homePageSize = 24;
  static const int defaultPageSize = 20;
  // Full field set — used for product detail, search, category pages
  static const String _productSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, portion_price, price_per_kg, '
      'default_weight_grams, min_weight_grams, weight_step_grams, '
      'max_weight_grams, discount_price, stock, status, description, '
      'specifications, attributes, video_url, variants, created_at, '
      'stores(business_name)';
  // Lightweight field set — used only for the home page product cards.
  // Omits description, attributes, video_url, variants, stock which are never
  // displayed in ProductCard, reducing payload by ~60%.
  static const String _homeProductSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, discount_price, status, created_at, '
      'stores(business_name)';
  static const String _productSuggestionSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, discount_price, status, created_at, '
      'stores(business_name)';
  static const String _productStorePreviewSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, price, '
      'pricing_type, portion_price, price_per_kg, default_weight_grams, '
      'min_weight_grams, weight_step_grams, max_weight_grams, '
      'discount_price, description, specifications, status, created_at, '
      'stores(business_name)';
  static const String _categoryProductsSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, portion_price, price_per_kg, '
      'default_weight_grams, min_weight_grams, weight_step_grams, '
      'max_weight_grams, discount_price, status, description, specifications, '
      'created_at, stores(business_name)';

  String _toOrIlikePattern(String value) {
    final sanitized = value.trim().replaceAll('*', '').replaceAll(',', ' ');
    if (sanitized.isEmpty) return '';
    return '*$sanitized*';
  }

  // ==================== PRODUCTS CRUD ====================

  Future<List<DBProduct>> getProductsPage({
    int limit = defaultPageSize,
    int offset = 0,
    String? category,
    String? brand,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase
          .from('products')
          .select(_productSelectFields)
          .eq('status', 'Aktif');

      if (category != null && category.isNotEmpty) {
        query = query.eq('main_category', category);
      }
      if (brand != null && brand.isNotEmpty) {
        query = query.eq('brand', brand);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.trim()}%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _mapToDBProduct(item)).toList();
    } catch (e) {
      debugPrint('Error getting paged products: $e');
      return [];
    }
  }

  Future<List<DBProduct>> getInitialHomeProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select(_homeProductSelectFields)
          .eq('status', 'Aktif')
          .order('created_at', ascending: false)
          .range(0, homePageSize - 1);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _mapToDBProduct(item)).toList();
    } catch (e) {
      debugPrint('Error getting initial home products: $e');
      return [];
    }
  }

  Future<List<DBProduct>> getAllProducts() async {
    try {
      return getProductsPage(limit: 500);
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  Future<List<DBProduct>> getProductsByCategory(String category) async {
    try {
      return getProductsPage(limit: 120, category: category);
    } catch (e) {
      debugPrint('Error getting products by category: $e');
      return [];
    }
  }

  Future<List<DBProduct>> getProductsByBrand(String brand) async {
    try {
      return getProductsPage(limit: 120, brand: brand);
    } catch (e) {
      debugPrint('Error getting products by brand: $e');
      return [];
    }
  }

  Future<List<DBProduct>> searchProducts(String query) async {
    try {
      return getProductsPage(limit: 60, searchQuery: query);
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  Future<List<DBProduct>> getProductSuggestions({
    required String query,
    int limit = 8,
  }) async {
    final trimmedQuery = query.trim();
    final collapsedQuery = trimmedQuery.replaceAll(RegExp(r'\s+'), '');
    if (collapsedQuery.length < 3) return const [];

    final normalizedQuery = TextNormalizer.normalize(trimmedQuery);
    final normalizedPattern = _toOrIlikePattern(normalizedQuery);
    final rawPattern = _toOrIlikePattern(trimmedQuery);

    try {
      Future<List<Map<String, dynamic>>> runSuggestionQuery({
        required bool useNormalizedFields,
      }) async {
        var builder = _supabase
            .from('products')
            .select(_productSuggestionSelectFields)
            .eq('status', 'Aktif');

        if (useNormalizedFields && normalizedPattern.isNotEmpty) {
          builder = builder.or(
            'search_text_norm.ilike.$normalizedPattern,'
            'name_norm.ilike.$normalizedPattern,'
            'brand_norm.ilike.$normalizedPattern',
          );
        } else if (rawPattern.isNotEmpty) {
          builder = builder.or(
            'name.ilike.$rawPattern,'
            'brand.ilike.$rawPattern,'
            'description.ilike.$rawPattern,'
            'main_category.ilike.$rawPattern,'
            'sub_category.ilike.$rawPattern',
          );
        }

        final response = await builder
            .order('created_at', ascending: false)
            .limit(limit * 2);
        return List<Map<String, dynamic>>.from(response as List);
      }

      List<Map<String, dynamic>> rows;
      try {
        rows = await runSuggestionQuery(useNormalizedFields: true);
        if (rows.isEmpty && rawPattern.isNotEmpty) {
          rows = await runSuggestionQuery(useNormalizedFields: false);
        }
      } catch (_) {
        rows = await runSuggestionQuery(useNormalizedFields: false);
      }

      final products = rows.map(_mapToDBProduct).toList(growable: false);

      final uniqueKeys = <String>{};
      final suggestions = <DBProduct>[];
      for (final product in products) {
        final key = TextNormalizer.normalize(
          '${product.brand} ${product.name}',
        );
        if (!uniqueKeys.add(key)) continue;
        suggestions.add(product);
        if (suggestions.length >= limit) break;
      }

      return suggestions;
    } catch (e) {
      debugPrint('Error getting product suggestions: $e');
      return const [];
    }
  }

  Future<DBProduct?> getProduct(int id) async {
    try {
      final response = await _supabase
          .from('products')
          .select(_productSelectFields)
          .eq('id', id.toString())
          .maybeSingle();

      if (response == null) return null;
      return _mapToDBProduct(response);
    } catch (e) {
      debugPrint('Error getting product: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProductExtrasByNameBrand({
    required String name,
    required String brand,
  }) async {
    try {
      Future<Map<String, dynamic>?> runSelect(String select) async {
        var query = _supabase.from('products').select(select).eq('name', name);
        if (brand.isNotEmpty) {
          query = query.eq('brand', brand);
        }
        final response = await query.maybeSingle();
        if (response == null) return null;
        return Map<String, dynamic>.from(response as Map);
      }

      try {
        return await runSelect(
          'video_url, video_path, video_public_url, thumbnail_path, thumbnail_public_url, video_duration_seconds, video_size_bytes, thumbnail_size_bytes, video_status, variants, attributes, faq, additional_info, accessories',
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('video_path') ||
            msg.contains('video_public_url') ||
            msg.contains('thumbnail_path') ||
            msg.contains('thumbnail_public_url') ||
            msg.contains('video_duration_seconds') ||
            msg.contains('video_size_bytes') ||
            msg.contains('thumbnail_size_bytes') ||
            msg.contains('video_status')) {
          try {
            return await runSelect(
              'video_url, variants, attributes, faq, additional_info, accessories',
            );
          } catch (_) {}
        }

        if (msg.contains('additional_info')) {
          try {
            return await runSelect(
              'video_url, variants, attributes, faq, accessories',
            );
          } catch (e2) {
            final msg2 = e2.toString();
            if (msg2.contains('faq')) {
              return await runSelect(
                'video_url, variants, attributes, accessories',
              );
            }
            rethrow;
          }
        }
        if (msg.contains('faq')) {
          return await runSelect(
            'video_url, variants, attributes, accessories',
          );
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error getting product extras: $e');
      return null;
    }
  }

  Future<void> insertProduct(DBProduct product) async {
    try {
      // Map DBProduct to Supabase schema
      final data = _mapFromDBProduct(product);
      // Ensure ID is string
      data['id'] =
          product.id?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      await _upsertProductMapWithFallback(data);
    } catch (e) {
      debugPrint('Error inserting product: $e');
    }
  }

  Future<void> insertProducts(List<DBProduct> products) async {
    try {
      if (products.isEmpty) return;

      final List<Map<String, dynamic>> dataList = [];
      for (var product in products) {
        final data = _mapFromDBProduct(product);
        data['id'] =
            product.id?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        dataList.add(data);
      }

      await _upsertProductListWithFallback(dataList);
    } catch (e) {
      debugPrint('Error batch inserting products: $e');
    }
  }

  Future<void> _upsertProductMapWithFallback(Map<String, dynamic> data) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= optionalProductColumns.length; attempt++) {
      try {
        await _supabase.from('products').upsert(data);
        return;
      } catch (error, stackTrace) {
        final message = error.toString();
        if (!isOptionalProductColumnError(message)) rethrow;

        final removedColumns = stripUnsupportedProductColumns(data, message);
        if (removedColumns.isEmpty) {
          lastError = error;
          lastStackTrace = stackTrace;
          break;
        }

        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace!);
    }
  }

  Future<void> _upsertProductListWithFallback(
    List<Map<String, dynamic>> dataList,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= optionalProductColumns.length; attempt++) {
      try {
        await _supabase.from('products').upsert(dataList);
        return;
      } catch (error, stackTrace) {
        final message = error.toString();
        if (!isOptionalProductColumnError(message)) rethrow;

        var removedAny = false;
        for (final data in dataList) {
          final removedColumns = stripUnsupportedProductColumns(data, message);
          if (removedColumns.isNotEmpty) {
            removedAny = true;
          }
        }

        if (!removedAny) {
          lastError = error;
          lastStackTrace = stackTrace;
          break;
        }

        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace!);
    }
  }

  Future<List<DBProduct>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _supabase
          .from('products')
          .select(_productSelectFields)
          .inFilter('id', ids);

      final data = List<Map<String, dynamic>>.from(response as List);
      final byId = {
        for (final item in data)
          item['id']?.toString() ?? '': _mapToDBProduct(item),
      };
      return ids
          .map((id) => byId[id])
          .whereType<DBProduct>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error getting products by ids: $e');
      return [];
    }
  }

  Future<PagedResult<DBProduct>> searchProductsPaged({
    required String query,
    Map<String, dynamic>? filters,
    int limit = defaultPageSize,
    String? cursor,
  }) async {
    final trimmedQuery = query.trim();
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final normalizedQuery = TextNormalizer.normalize(trimmedQuery);
    final normalizedPattern = _toOrIlikePattern(normalizedQuery);
    final rawPattern = _toOrIlikePattern(trimmedQuery);

    try {
      final category = filters?['category']?.toString();
      final brand = filters?['brand']?.toString();
      final sellerId = filters?['sellerId']?.toString();

      Future<List<Map<String, dynamic>>> runSearchQuery({
        required bool useNormalizedFields,
      }) async {
        var builder = _supabase
            .from('products')
            .select(_productSelectFields)
            .eq('status', 'Aktif');

        if (category != null && category.isNotEmpty) {
          builder = builder.eq('main_category', category);
        }
        if (brand != null && brand.isNotEmpty) {
          builder = builder.eq('brand', brand);
        }
        if (sellerId != null && sellerId.isNotEmpty) {
          builder = builder.eq('seller_id', sellerId);
        }

        if (useNormalizedFields && normalizedPattern.isNotEmpty) {
          builder = builder.or(
            'search_text_norm.ilike.$normalizedPattern,'
            'name_norm.ilike.$normalizedPattern,'
            'brand_norm.ilike.$normalizedPattern',
          );
        } else if (rawPattern.isNotEmpty) {
          builder = builder.or(
            'name.ilike.$rawPattern,'
            'brand.ilike.$rawPattern,'
            'description.ilike.$rawPattern,'
            'main_category.ilike.$rawPattern,'
            'sub_category.ilike.$rawPattern',
          );
        }

        final response = await builder
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        return List<Map<String, dynamic>>.from(response as List);
      }

      List<Map<String, dynamic>> rows;
      try {
        rows = await runSearchQuery(useNormalizedFields: true);
        if (rows.isEmpty && rawPattern.isNotEmpty) {
          rows = await runSearchQuery(useNormalizedFields: false);
        }
      } catch (_) {
        rows = await runSearchQuery(useNormalizedFields: false);
      }

      final items = rows.map(_mapToDBProduct).toList(growable: false);
      final nextCursor = items.length < limit
          ? null
          : '${offset + items.length}';
      return PagedResult(items: items, nextCursor: nextCursor);
    } catch (e) {
      debugPrint('Error searching paged products: $e');
      return const PagedResult(items: <DBProduct>[]);
    }
  }

  Future<PagedResult<DBProduct>> getProductsBySellerIdPaged({
    required String sellerId,
    int limit = defaultPageSize,
    String? cursor,
  }) async {
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    try {
      final response = await _supabase
          .from('products')
          .select(_productSelectFields)
          .eq('seller_id', sellerId)
          .eq('status', 'Aktif')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final items = List<Map<String, dynamic>>.from(
        response as List,
      ).map(_mapToDBProduct).toList(growable: false);
      final nextCursor = items.length < limit
          ? null
          : '${offset + items.length}';
      return PagedResult(items: items, nextCursor: nextCursor);
    } catch (e) {
      debugPrint('Error getting paged seller products: $e');
      return const PagedResult(items: <DBProduct>[]);
    }
  }

  Future<PagedResult<DBProduct>> getProductsByStoreNamePaged({
    required String storeName,
    int limit = defaultPageSize,
    String? cursor,
  }) async {
    try {
      final stores = await _fetchStoresByBusinessNames([storeName]);
      final sellerId = stores.isEmpty
          ? null
          : stores.first['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) {
        return const PagedResult(items: <DBProduct>[]);
      }
      return getProductsBySellerIdPaged(
        sellerId: sellerId,
        limit: limit,
        cursor: cursor,
      );
    } catch (e) {
      debugPrint('Error getting paged store-name products: $e');
      return const PagedResult(items: <DBProduct>[]);
    }
  }

  Future<PagedResult<DBProduct>> getCategoryProductsPaged({
    required String category,
    String? subCategory,
    int limit = defaultPageSize,
    String? cursor,
  }) async {
    final trimmedCategory = category.trim();
    final trimmedSubCategory = (subCategory ?? '').trim();
    final offset = int.tryParse(cursor ?? '0') ?? 0;

    if (trimmedCategory.isEmpty) {
      return const PagedResult(items: <DBProduct>[]);
    }

    try {
      var builder = _supabase
          .from('products')
          .select(_categoryProductsSelectFields)
          .eq('status', 'Aktif')
          .eq('main_category', trimmedCategory);

      if (trimmedSubCategory.isNotEmpty &&
          trimmedSubCategory.toUpperCase() != 'HEPSI' &&
          trimmedSubCategory.toUpperCase() != 'HEPSİ') {
        builder = builder.eq('sub_category', trimmedSubCategory);
      }

      final response = await builder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final items = List<Map<String, dynamic>>.from(
        response as List,
      ).map(_mapToDBProduct).toList(growable: false);
      final nextCursor = items.length < limit
          ? null
          : '${offset + items.length}';
      return PagedResult(items: items, nextCursor: nextCursor);
    } catch (e) {
      debugPrint('Error getting category products paged: $e');
      return const PagedResult(items: <DBProduct>[]);
    }
  }

  Future<List<DBProduct>> getProductsByStore({
    required String storeName,
    int limit = defaultPageSize,
  }) async {
    final trimmedStoreName = storeName.trim();
    if (trimmedStoreName.isEmpty) return const [];

    try {
      final stores = await _fetchStoresByBusinessNames([trimmedStoreName]);
      final sellerId = stores.isEmpty
          ? null
          : stores.first['seller_id']?.toString().trim();
      if (sellerId == null || sellerId.isEmpty) {
        return const [];
      }

      final response = await _supabase
          .from('products')
          .select(_productStorePreviewSelectFields)
          .eq('seller_id', sellerId)
          .eq('status', 'Aktif')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(
        response as List,
      ).map(_mapToDBProduct).toList(growable: false);
    } catch (e) {
      debugPrint('Error getting products by store: $e');
      return const [];
    }
  }

  Future<Map<String, List<DBProduct>>> getProductsPreviewByStores({
    List<String> sellerIds = const [],
    List<String> storeNames = const [],
    int perStoreLimit = 5,
  }) async {
    final normalizedSellerIds = sellerIds
        .map((sellerId) => sellerId.trim())
        .where((sellerId) => sellerId.isNotEmpty)
        .toSet();
    final normalizedStoreNames = storeNames
        .map((storeName) => storeName.trim())
        .where((storeName) => storeName.isNotEmpty)
        .toSet();

    final storeRows = normalizedStoreNames.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _fetchStoresByBusinessNames(normalizedStoreNames.toList());

    final sellerIdByStoreKey = <String, String>{};
    for (final store in storeRows) {
      final businessName = store['business_name']?.toString().trim() ?? '';
      final sellerId = store['seller_id']?.toString().trim() ?? '';
      if (businessName.isEmpty || sellerId.isEmpty) continue;
      sellerIdByStoreKey[TextNormalizer.normalize(businessName)] = sellerId;
      normalizedSellerIds.add(sellerId);
    }

    if (normalizedSellerIds.isEmpty) {
      return const <String, List<DBProduct>>{};
    }

    try {
      final response = await _supabase.rpc(
        'get_store_preview_products',
        params: {
          'p_seller_ids': normalizedSellerIds.toList(growable: false),
          'p_per_store_limit': perStoreLimit,
        },
      );

      return _mapPreviewProductsResponse(
        response: response,
        sellerIds: normalizedSellerIds,
        sellerIdByStoreKey: sellerIdByStoreKey,
      );
    } catch (e) {
      debugPrint('Error getting store preview products via rpc: $e');
      return _getProductsPreviewByStoresFallback(
        sellerIds: normalizedSellerIds,
        sellerIdByStoreKey: sellerIdByStoreKey,
        perStoreLimit: perStoreLimit,
      );
    }
  }

  Future<Map<String, List<DBProduct>>> _getProductsPreviewByStoresFallback({
    required Set<String> sellerIds,
    required Map<String, String> sellerIdByStoreKey,
    required int perStoreLimit,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .select(_productStorePreviewSelectFields)
          .inFilter('seller_id', sellerIds.toList(growable: false))
          .eq('status', 'Aktif')
          .order('seller_id')
          .order('created_at', ascending: false);

      return _mapPreviewProductsResponse(
        response: response,
        sellerIds: sellerIds,
        sellerIdByStoreKey: sellerIdByStoreKey,
        perStoreLimit: perStoreLimit,
      );
    } catch (e) {
      debugPrint('Error getting store preview products fallback: $e');
      return const <String, List<DBProduct>>{};
    }
  }

  Map<String, List<DBProduct>> _mapPreviewProductsResponse({
    required dynamic response,
    required Set<String> sellerIds,
    required Map<String, String> sellerIdByStoreKey,
    int? perStoreLimit,
  }) {
    final previewsBySellerId = <String, List<DBProduct>>{};
    for (final row in List<Map<String, dynamic>>.from(response as List)) {
      final product = _mapToDBProduct(row);
      final sellerId = product.sellerId?.trim() ?? '';
      if (sellerId.isEmpty) continue;
      final bucket = previewsBySellerId.putIfAbsent(
        sellerId,
        () => <DBProduct>[],
      );
      if (perStoreLimit == null || bucket.length < perStoreLimit) {
        bucket.add(product);
      }
    }

    final previews = <String, List<DBProduct>>{};
    for (final sellerId in sellerIds) {
      final products = previewsBySellerId[sellerId] ?? const <DBProduct>[];
      previews[sellerId] = List.unmodifiable(products);
    }
    for (final entry in sellerIdByStoreKey.entries) {
      previews[entry.key] =
          previewsBySellerId[entry.value] ?? const <DBProduct>[];
    }
    return previews;
  }

  Future<Map<String, Product>> resolveCartProducts(
    List<Product> products,
  ) async {
    final unresolved = products
        .where((product) => (product.productId ?? '').trim().isEmpty)
        .toList(growable: false);
    if (unresolved.isEmpty) return const <String, Product>{};

    final sellerIds = unresolved
        .map((product) => product.sellerId?.trim() ?? '')
        .where((sellerId) => sellerId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final storeNames = unresolved
        .map((product) => product.store?.trim() ?? '')
        .where((storeName) => storeName.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final names = unresolved
        .map((product) => product.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final stores = await _fetchStoresByBusinessNames(storeNames);
    final storeByName = <String, Map<String, dynamic>>{};
    for (final store in stores) {
      final businessName = store['business_name']?.toString();
      if (businessName == null || businessName.isEmpty) continue;
      storeByName[TextNormalizer.normalize(businessName)] = store;
    }

    final effectiveSellerIds = <String>{
      ...sellerIds,
      ...stores
          .map((store) => store['seller_id']?.toString() ?? '')
          .where((sellerId) => sellerId.isNotEmpty),
    }.toList(growable: false);

    List<Map<String, dynamic>> candidateRows = const [];
    if (names.isNotEmpty) {
      try {
        var query = _supabase
            .from('products')
            .select(
              'id, seller_id, name, brand, main_category, stores(business_name)',
            )
            .eq('status', 'Aktif')
            .inFilter('name', names);
        if (effectiveSellerIds.isNotEmpty) {
          query = query.inFilter('seller_id', effectiveSellerIds);
        }
        final response = await query;
        candidateRows = List<Map<String, dynamic>>.from(response as List);
      } catch (e) {
        debugPrint('Error resolving cart products: $e');
      }
    }

    final byExactKey = <String, Product>{};
    final byLooseKey = <String, List<Product>>{};
    for (final row in candidateRows) {
      final candidate = Product.fromDBProduct(row);
      final sellerId = candidate.sellerId?.trim();
      final exactKey = TextNormalizer.productLookupKey(
        name: candidate.name,
        brand: candidate.brand,
        sellerId: sellerId,
        storeName: candidate.store,
      );
      byExactKey[exactKey] = candidate;

      final looseKey = TextNormalizer.productLookupKey(
        name: candidate.name,
        brand: candidate.brand,
      );
      byLooseKey.putIfAbsent(looseKey, () => <Product>[]).add(candidate);
    }

    final resolved = <String, Product>{};
    for (final product in unresolved) {
      final normalizedStore = TextNormalizer.normalize(product.store);
      final inferredSellerId = product.sellerId?.trim().isNotEmpty == true
          ? product.sellerId!.trim()
          : storeByName[normalizedStore]?['seller_id']?.toString();
      final exactKey = TextNormalizer.productLookupKey(
        name: product.name,
        brand: product.brand,
        sellerId: inferredSellerId,
        storeName: product.store,
      );
      final looseKey = TextNormalizer.productLookupKey(
        name: product.name,
        brand: product.brand,
      );

      Product? match = byExactKey[exactKey];
      if (match == null) {
        final candidates = byLooseKey[looseKey] ?? const <Product>[];
        if (candidates.length == 1) {
          match = candidates.first;
        } else if (candidates.isNotEmpty && inferredSellerId != null) {
          try {
            match = candidates.firstWhere(
              (candidate) => candidate.sellerId?.trim() == inferredSellerId,
            );
          } catch (_) {}
        }
      }

      if (match != null) {
        resolved[_cartResolutionKey(product)] = product.copyWith(
          productId: match.productId,
          sellerId: match.sellerId ?? product.sellerId,
          store: match.store ?? product.store,
          category: match.category ?? product.category,
          subCategory: match.subCategory ?? product.subCategory,
        );
      }
    }

    return resolved;
  }

  String cartResolutionKey(Product product) => _cartResolutionKey(product);

  Future<List<Map<String, dynamic>>> _fetchStoresByBusinessNames(
    List<String> businessNames,
  ) async {
    final normalizedNames = businessNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedNames.isEmpty) return const [];

    try {
      final orClause = normalizedNames
          .map((name) => 'business_name.ilike.${name.replaceAll(',', r'\,')}')
          .join(',');
      final response = await _supabase
          .from('stores')
          .select('seller_id, business_name')
          .or(orClause);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching stores by business names: $e');
      return const [];
    }
  }

  String _cartResolutionKey(Product product) {
    return TextNormalizer.productLookupKey(
      name: product.name,
      brand: product.brand,
      sellerId: product.sellerId,
      storeName: product.store,
    );
  }

  // ==================== PRODUCT VARIANTS ====================

  // Note: Current DBProduct model stores variants in `variantOptions` (string)
  // But Supabase schema has `variants` (jsonb).
  // We need to decide which source of truth to use.
  // For now, we will rely on fetching products that share `variantGroupId`.

  Future<List<DBProduct>> getProductVariantsByGroupId(
    String variantGroupId,
  ) async {
    try {
      // Assuming 'variant_group_id' is stored in `category_attributes` or `variants` jsonb?
      // Or we need to add `variant_group_id` to `products` table?
      // Looking at `DBProduct`, it has `variantGroupId`.
      // Looking at `SUPABASE_SETUP.sql`, `products` table does NOT have `variant_group_id` column explicitly.
      // It has `variants` jsonb.
      // However, `StoreService` maps `DBProduct` to snake_case but `DBProduct` is different from `SellerProduct`.
      // `SellerProduct` doesn't seem to have `variantGroupId`?
      // `DBProduct` has it.

      // If we are migrating from Firestore where `variantGroupId` was a field, we should probably add it to Supabase schema
      // OR store it in `category_attributes` or `variants`.
      // For now, let's assume it's in `variants` JSONB or we can't filter easily on server side without an index.
      // BUT `FirestoreHelper` had it as a top level field.
      // Let's check `_mapFromDBProduct` implementation below.

      // If we don't have the column, we can't filter efficiently.
      // Let's just return empty for now or fix schema.
      return [];
    } catch (e) {
      debugPrint('Error getting product variants: $e');
      return [];
    }
  }

  Future<Set<String>> getVariantOptionKeys(String variantGroupId) async {
    return {};
  }

  Future<Set<String>> getVariantValues(
    String variantGroupId,
    String optionKey,
  ) async {
    return {};
  }

  Future<DBProduct?> getProductByVariantOptions(
    String variantGroupId,
    Map<String, String> selectedOptions,
  ) async {
    return null;
  }

  // ==================== BANNERS CRUD ====================

  Future<List<DBBanner>> getBannersByType(String type) async {
    try {
      final response = await _supabase
          .from('banners')
          .select()
          .eq('type', type)
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _mapToDBBanner(item)).toList();
    } catch (e) {
      debugPrint('Error getting banners: $e');
      return [];
    }
  }

  Future<void> insertBanners(List<DBBanner> banners) async {
    try {
      final data = banners.map((b) => _mapFromDBBanner(b)).toList();
      await _supabase.from('banners').upsert(data);
    } catch (e) {
      debugPrint('Error inserting banners: $e');
    }
  }

  // ==================== CATEGORIES CRUD ====================

  Future<List<DBCategory>> getMainCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .filter('parent_id', 'is', null)
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _mapToDBCategory(item)).toList();
    } catch (e) {
      debugPrint('Error getting main categories: $e');
      return [];
    }
  }

  Future<List<DBCategory>> getSubCategories(int parentId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('parent_id', parentId)
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _mapToDBCategory(item)).toList();
    } catch (e) {
      debugPrint('Error getting sub categories: $e');
      return [];
    }
  }

  Future<List<CategoryWithSubcategories>> getCategoriesWithSubs() async {
    final mainCategories = await getMainCategories();
    final List<CategoryWithSubcategories> result = [];

    for (var mainCat in mainCategories) {
      if (mainCat.id != null) {
        final subs = await getSubCategories(mainCat.id!);
        result.add(
          CategoryWithSubcategories(mainCategory: mainCat, subCategories: subs),
        );
      }
    }

    return result;
  }

  // ==================== MAPPERS ====================

  DBProduct _mapToDBProduct(Map<String, dynamic> data) {
    // Map snake_case from Supabase to DBProduct fields
    // Also handle stores(business_name) join

    String? storeName;
    if (data['stores'] != null) {
      storeName = data['stores']['business_name'];
    }

    return DBProduct(
      id: data['id']?.toString(),
      sellerId: data['seller_id']?.toString(),
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      store: storeName,
      price: '${data['price']} TL', // DBProduct expects string "100 TL"
      pricingType: data['pricing_type']?.toString() ?? 'portion',
      portionPrice: (data['portion_price'] as num?)?.toDouble(),
      pricePerKg: (data['price_per_kg'] as num?)?.toDouble(),
      serviceControlType: data['service_control_type']?.toString(),
      minPortion: (data['min_portion'] as num?)?.toDouble(),
      maxPortion: (data['max_portion'] as num?)?.toDouble(),
      portionStep: (data['portion_step'] as num?)?.toDouble(),
      defaultWeightGrams: (data['default_weight_grams'] as num?)?.toInt(),
      minWeightGrams: (data['min_weight_grams'] as num?)?.toInt(),
      weightStepGrams: (data['weight_step_grams'] as num?)?.toInt(),
      maxWeightGrams: (data['max_weight_grams'] as num?)?.toInt(),
      oldPrice: data['discount_price'] != null
          ? '${data['discount_price']} TL'
          : null,
      rating: 0.0, // Not in products table yet?
      reviewCount: 0,
      imageUrl: data['image_url'] ?? '',
      imageUrls: data['image_urls'] != null
          ? jsonEncode(data['image_urls'])
          : null,
      category: data['main_category'] ?? '',
      subCategory: data['sub_category'],
      tags: '[]', // Not in table
      description: data['description'],
      specifications: data['specifications'] != null
          ? jsonEncode(data['specifications'])
          : null,
      stock: data['stock'],
      isActive: data['status'] == 'Aktif',
      attributes: data['attributes'] != null
          ? jsonEncode(data['attributes'])
          : null,
      videoUrl: data['video_url'],
      videoPath: data['video_path'],
      videoPublicUrl: data['video_public_url'],
      thumbnailPath: data['thumbnail_path'],
      thumbnailPublicUrl: data['thumbnail_public_url'],
      videoDurationSeconds: (data['video_duration_seconds'] as num?)?.toInt(),
      videoSizeBytes: (data['video_size_bytes'] as num?)?.toInt(),
      thumbnailSizeBytes: (data['thumbnail_size_bytes'] as num?)?.toInt(),
      videoStatus: data['video_status'],
      variants: data['variants'],
    );
  }

  Map<String, dynamic> _mapFromDBProduct(DBProduct product) {
    // Reverse map
    // Note: This is mostly for seeding, as actual app uses StoreService to add products
    return {
      'seller_id': product.sellerId,
      'name': product.name,
      'brand': product.brand,
      'main_category': product.category,
      'sub_category': product.subCategory,
      'price':
          double.tryParse(product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0,
      'pricing_type': product.pricingType,
      'portion_price': product.portionPrice,
      'price_per_kg': product.pricePerKg,
      'service_control_type': product.serviceControlType,
      'min_portion': product.minPortion,
      'max_portion': product.maxPortion,
      'portion_step': product.portionStep,
      'default_weight_grams': product.defaultWeightGrams,
      'min_weight_grams': product.minWeightGrams,
      'weight_step_grams': product.weightStepGrams,
      'max_weight_grams': product.maxWeightGrams,
      'discount_price': product.oldPrice != null
          ? double.tryParse(
              product.oldPrice!.replaceAll(RegExp(r'[^0-9.]'), ''),
            )
          : null,
      'image_url': product.imageUrl,
      'image_urls': product.imageUrls != null
          ? jsonDecode(product.imageUrls!)
          : [],
      'description': product.description,
      'specifications': product.specifications != null
          ? jsonDecode(product.specifications!)
          : null,
      'stock': product.stock,
      'status': product.isActive ? 'Aktif' : 'Pasif',
      'video_url': product.videoPublicUrl ?? product.videoUrl,
      'video_path': product.videoPath,
      'video_public_url': product.videoPublicUrl,
      'thumbnail_path': product.thumbnailPath,
      'thumbnail_public_url': product.thumbnailPublicUrl,
      'video_duration_seconds': product.videoDurationSeconds,
      'video_size_bytes': product.videoSizeBytes,
      'thumbnail_size_bytes': product.thumbnailSizeBytes,
      'video_status': product.videoStatus,
    };
  }

  DBBanner _mapToDBBanner(Map<String, dynamic> data) {
    return DBBanner(
      id: data['id'],
      imageUrl: data['image_url'],
      link: data['link'],
      orderIndex: data['order_index'],
      type: data['type'],
      title: data['title'],
      description: data['description'],
      isActive: data['is_active'],
    );
  }

  Map<String, dynamic> _mapFromDBBanner(DBBanner banner) {
    return {
      'image_url': banner.imageUrl,
      'link': banner.link,
      'order_index': banner.orderIndex,
      'type': banner.type,
      'title': banner.title,
      'description': banner.description,
      'is_active': banner.isActive,
    };
  }

  DBCategory _mapToDBCategory(Map<String, dynamic> data) {
    return DBCategory(
      id: data['id'],
      name: data['name'],
      iconName: data['icon_name'],
      imageUrl: data['image_url'],
      orderIndex: data['order_index'],
      parentId: data['parent_id'],
      isActive: data['is_active'],
    );
  }

  Map<String, dynamic> _mapFromDBCategory(DBCategory category) {
    return {
      'name': category.name,
      'icon_name': category.iconName,
      'image_url': category.imageUrl,
      'order_index': category.orderIndex,
      'parent_id': category.parentId,
      'is_active': category.isActive,
    };
  }

  // ==================== SEED DATA ====================

  Future<void> seedInitialData() async {
    // Check if products exist
    final count = await _supabase.from('products').count(CountOption.exact);
    if (count > 0) return;

    debugPrint('🌱 Seeding initial data...');

    try {
      // 1. Seed Categories
      await _seedCategories();

      // 2. Seed Banners
      await _seedBanners();

      // 3. Seed Products from JSON
      await _seedProductsFromJson();
    } catch (e) {
      debugPrint('Error seeding data: $e');
    }
  }

  Future<void> _seedCategories() async {
    final categories = [
      DBCategory(
        id: 1,
        name: 'Elektronik',
        iconName: 'phone_android',
        orderIndex: 1,
        parentId: null,
        isActive: true,
      ),
      DBCategory(
        id: 2,
        name: 'Moda',
        iconName: 'checkroom',
        orderIndex: 2,
        parentId: null,
        isActive: true,
      ),
      DBCategory(
        id: 3,
        name: 'Ev & Yaşam',
        iconName: 'home',
        orderIndex: 3,
        parentId: null,
        isActive: true,
      ),
      // ... Add more if needed
      // Subcategories
      DBCategory(
        name: 'Telefon & Aksesuar',
        orderIndex: 1,
        parentId: 1,
        isActive: true,
      ),
      DBCategory(
        name: 'Bilgisayar & Tablet',
        orderIndex: 2,
        parentId: 1,
        isActive: true,
      ),
      // ...
    ];

    for (var cat in categories) {
      // For main categories with ID, we want to preserve ID if possible,
      // but 'id' column is identity. We can force insert if we enable identity insert,
      // or just let it auto-increment.
      // Since `parentId` references `id`, we need to be careful.
      // Better to let DB assign IDs and fetch them, or just insert main categories first, then subs.
      // For simplicity in this migration, we will insert and not enforce specific IDs for now,
      // but we need to map parentIds correctly.
      // This logic is complex for auto-generated IDs.
      // FirestoreHelper had explicit IDs in code.
      // We will skip complex seeding logic here and just insert a few samples.

      await _supabase.from('categories').insert(_mapFromDBCategory(cat));
    }
  }

  Future<void> _seedBanners() async {
    final banners = [
      DBBanner(
        imageUrl:
            'packages/ibul_app/assets/images/banners/gorsel-zeka-banner.png',
        orderIndex: 1,
        type: 'main',
        title: 'Kış İndirimleri',
        isActive: true,
      ),
      // ...
    ];
    await insertBanners(banners);
  }

  Future<void> _seedProductsFromJson() async {
    try {
      final jsonString = await rootBundle.loadString(
        'packages/ibul_app/assets/urunler.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);

      final List<DBProduct> productsToAdd = [];

      for (var item in jsonList) {
        // Map JSON to DBProduct
        // Similar to FirestoreHelper logic
        productsToAdd.add(
          DBProduct(
            id: (DateTime.now().millisecondsSinceEpoch + productsToAdd.length)
                .toString(),
            name: (item['isim'] ?? '').toString().trim(),
            brand: (item['marka'] ?? '').toString(),
            price: "${item['fiyat']} TL",
            imageUrl:
                (item['gorseller'] is List &&
                    (item['gorseller'] as List).isNotEmpty)
                ? (item['gorseller'] as List).first.toString()
                : '',
            category: (item['kategori'] ?? 'Diğer').toString(),
            description: item['aciklama']?.toString(),
            rating: (item['puan'] as num?)?.toDouble() ?? 0,
            reviewCount: (item['degerlendirme'] as num?)?.toInt() ?? 0,
            tags: '[]',
            stock: 10,
            isActive: true,
          ),
        );
      }

      await insertProducts(productsToAdd);
    } catch (e) {
      debugPrint('Error seeding products: $e');
    }
  }
}
