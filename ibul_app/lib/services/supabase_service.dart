import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/db_product.dart';
import '../models/db_banner.dart';
import '../models/db_category.dart';
import '../models/paged_result.dart';
import '../models/product_model.dart';
import '../models/product_pricing.dart';
import 'store/store_mapping_helpers.dart';
import '../utils/text_normalizer.dart';
import '../utils/category_product_filter.dart';
import '../utils/product_visibility_helper.dart';
import 'store_follow_service.dart';
import '../utils/product_edit_log.dart';
import '../core/runtime_diagnostic_logger.dart';
import '../core/home_data_diagnostics.dart';
import '../core/config/runtime_config.dart';
import '../core/product_filter_audit.dart';
import '../models/home_products_fetch_report.dart';
import '../models/ad_linked_products_fetch_report.dart';

class SupabaseService {
  // Singleton pattern
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  final SupabaseClient _supabase = Supabase.instance.client;
  static const int homePageSize = 24;
  static const int defaultPageSize = 20;

  /// First-paint page size for the mobile home grid. Kept smaller than
  /// [homePageSize] so the initial Supabase round-trip is lighter/faster on
  /// mobile; more products load as the user scrolls / on refresh.
  static const int homeInitialPageSize = 10;

  /// Anonim alışveriş vitrininde gösterilen ürün durumları (admin onaylı).
  /// Supabase `products` SELECT RLS politikası bu liste ile uyumlu olmalıdır.
  static const List<String> publicCatalogProductStatuses = ['Aktif', 'active'];

  static bool isPublicCatalogProductStatus(String? status) {
    return ProductVisibilityHelper.isPublicCatalogProductStatus(status);
  }

  String _stripUnsupportedColumnsFromSelect(
    String select, {
    required String message,
  }) {
    // PostgREST errors look like:
    // "column products.pricing_mode does not exist"
    final rawTokens = select
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    List<String> filtered = rawTokens.where((token) {
      // Keep embedded selects like stores(business_name) intact.
      if (token.contains('(') && token.contains(')')) return true;
      if (catalogRequiredProductColumns.contains(token)) return true;
      for (final col in optionalProductColumns) {
        if (message.contains(col) && token == col) return false;
      }
      return true;
    }).toList();

    // If message didn't match any token, fall back to removing *all* optional
    // columns from the selection (best-effort).
    if (filtered.length == rawTokens.length) {
      filtered = rawTokens.where((token) {
        if (token.contains('(') && token.contains(')')) return true;
        if (catalogRequiredProductColumns.contains(token)) return true;
        return !optionalProductColumns.contains(token);
      }).toList();
    }

    return filtered.join(', ');
  }

  Future<List<Map<String, dynamic>>> _runProductsSelectWithFallback({
    required String select,
    required Future<dynamic> Function(String effectiveSelect) action,
  }) async {
    String currentSelect = select;
    Object? lastError;

    // Some environments have a "minimal" products schema. PostgREST fails fast
    // on unknown columns, so we progressively strip optional columns until the
    // SELECT works (or we hit a non-column error).
    for (var attempt = 0; attempt <= optionalProductColumns.length; attempt++) {
      try {
        final sw = kDebugMode ? (Stopwatch()..start()) : null;
        final response = await action(currentSelect);
        final rows = ProductVisibilityHelper.filterPublicProductMaps(
          List<Map<String, dynamic>>.from(response as List),
        );
        if (sw != null) {
          sw.stop();
          if (sw.elapsedMilliseconds > 800) {
            debugPrint(
              'SLOW_PRODUCT_QUERY ${sw.elapsedMilliseconds}ms select=$currentSelect',
            );
          }
        }
        return rows;
      } catch (e) {
        lastError = e;
        final message = e.toString();
        if (!isOptionalProductColumnError(message)) rethrow;

        final stripped = _stripUnsupportedColumnsFromSelect(
          currentSelect,
          message: message,
        );
        // If stripping no longer changes the projection, stop retrying.
        if (stripped == currentSelect) break;
        currentSelect = stripped;
      }
    }

    if (lastError != null) throw lastError;
    throw StateError('Product select fallback ended unexpectedly.');
  }

  /// Cart/checkout doğrulaması — satır döndürür, client-side public filtresi uygulamaz.
  /// RLS zaten vitrin kuralını uygular; görünürlük kararı CartValidationService'te verilir.
  Future<List<Map<String, dynamic>>> _runCartValidationSelectWithFallback({
    required String select,
    required Future<dynamic> Function(String effectiveSelect) action,
  }) async {
    String currentSelect = select;
    Object? lastError;

    for (var attempt = 0; attempt <= optionalProductColumns.length; attempt++) {
      try {
        final response = await action(currentSelect);
        // Tek kopya: `List<...>.from(...)` ara listesi hemen ardından
        // .map(...).toList() ile atılıyordu. Satır başına defansif
        // Map kopyası korunuyor — sonuç birebir aynı.
        return (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      } catch (e) {
        lastError = e;
        final message = e.toString();
        if (!isOptionalProductColumnError(message)) rethrow;

        final stripped = _stripUnsupportedColumnsFromSelect(
          currentSelect,
          message: message,
        );
        if (stripped == currentSelect) break;
        currentSelect = stripped;
      }
    }

    if (lastError != null) throw lastError;
    throw StateError('Cart validation select fallback ended unexpectedly.');
  }
  // Full field set — used for product detail, search, category pages
  static const String _productSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, '
      'default_weight_grams, min_weight_grams, weight_step_grams, '
      'max_weight_grams, discount_price, stock, status, approval_status, '
      'admin_approval_status, description, specifications, attributes, '
      'video_url, variants, created_at, stores(business_name)';
  /// Home catalog projection aligned with [StoreService.getMenuProductsBySellerId]:
  /// omits approval columns so [ProductVisibilityHelper] trusts RLS (same as store detail).
  static const String _homeProductCatalogSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, discount_price, status, '
      'stock, created_at, updated_at, stores(business_name)';
  static const String _homeProductCatalogSelectFieldsSansStore =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, discount_price, status, '
      'stock, created_at, updated_at';
  /// Card-only projection for home first paint — omits heavy arrays/text blobs.
  static const String _homeProductCardSelectFields =
      'id, seller_id, name, brand, image_url, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, discount_price, status, '
      'approval_status, admin_approval_status, stock, created_at, updated_at, '
      'stores(business_name)';
  static const String _homeProductCardSelectFieldsSansStore =
      'id, seller_id, name, brand, image_url, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, discount_price, status, '
      'approval_status, admin_approval_status, stock, created_at, updated_at';
  /// Richer home select when quick-view / eye preview needs description fields.
  /// Same as below but without `stores(...)` embed.
  /// PostgREST can fail on embeds when FK hints are missing or store RLS differs;
  /// we retry with this projection so the home grid still loads.
  static const String _homeProductSelectFieldsSansStore =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, discount_price, status, '
      'approval_status, admin_approval_status, stock, description, specifications, '
      'attributes, created_at, updated_at';
  static const String _productSelectFieldsSansStore =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, '
      'default_weight_grams, min_weight_grams, weight_step_grams, '
      'max_weight_grams, discount_price, stock, status, approval_status, '
      'admin_approval_status, description, specifications, attributes, '
      'video_url, variants, created_at';
  static const String _productSuggestionSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, discount_price, status, '
      'approval_status, admin_approval_status, created_at, '
      'stores(business_name)';
  static const String _productStorePreviewSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, price, '
      'pricing_type, pricing_mode, base_price, portion_price, price_per_kg, '
      'size_options, default_weight_grams, '
      'min_weight_grams, weight_step_grams, max_weight_grams, '
      'discount_price, description, specifications, status, approval_status, '
      'admin_approval_status, created_at, stores(business_name)';
  static const String _categoryProductsSelectFields =
      'id, seller_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, pricing_type, pricing_mode, base_price, '
      'portion_price, price_per_kg, size_options, '
      'default_weight_grams, min_weight_grams, weight_step_grams, '
      'max_weight_grams, discount_price, status, approval_status, '
      'admin_approval_status, stock, description, specifications, created_at, '
      'updated_at, stores(business_name)';

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
    Future<List<DBProduct>> runSelect(String fields) async {
      final rows = await _runProductsSelectWithFallback(
        select: fields,
        action: (effectiveSelect) async {
          var query = _supabase
              .from('products')
              .select(effectiveSelect)
              .inFilter('status', publicCatalogProductStatuses);

          if (category != null && category.isNotEmpty) {
            query = query.eq('main_category', category);
          }
          if (brand != null && brand.isNotEmpty) {
            query = query.eq('brand', brand);
          }
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            query = query.ilike('name', '%${searchQuery.trim()}%');
          }

          return await query
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
        },
      );

      return rows.map(_mapToDBProduct).toList(growable: false);
    }

    try {
      return await runSelect(_productSelectFields);
    } catch (e) {
      debugPrint('Error getting paged products (with store embed): $e');
      try {
        return await runSelect(_productSelectFieldsSansStore);
      } catch (e2) {
        debugPrint('Error getting paged products (sans store embed): $e2');
        return [];
      }
    }
  }

  Future<List<DBProduct>> getInitialHomeProducts() async {
    final report = await fetchInitialHomeProductsReport();
    if (report.outcome == HomeProductsFetchOutcome.queryError &&
        report.error != null) {
      throw report.error!;
    }
    return report.products;
  }

  /// Home grid fetch with filter/parse diagnostics for web production debugging.
  Future<HomeProductsFetchReport> fetchInitialHomeProductsReport() async {
    const table = 'products';
    HomeDataDiagnostics.requestStart(source: 'home_initial');
    if (!AppRuntimeConfig.hasSupabaseConfig) {
      return HomeProductsFetchReport.configMissing();
    }

    final followedStoreIds =
        StoreFollowService.instance.cachedFollowedStoreIds;
    unawaited(StoreFollowService.instance.fetchFollowedStoreIds());
    final fetchLimit = followedStoreIds.isEmpty
        ? homeInitialPageSize
        : (homeInitialPageSize * 3).clamp(homeInitialPageSize, 48);
    final statusFilter = publicCatalogProductStatuses.join(',');
    final querySummary =
        '$table.select(...).inFilter(status,[$statusFilter])'
        '.order(created_at,desc).range(0,${fetchLimit - 1})';

    final selectCandidates = <String>[
      _homeProductCatalogSelectFields,
      _homeProductCatalogSelectFieldsSansStore,
      _homeProductSelectFieldsSansStore,
    ];

    Object? lastError;
    StackTrace? lastStack;
    String lastSelect = selectCandidates.first;
    HomeProductsFetchReport? approvalFilteredEmptyReport;

    for (final select in selectCandidates) {
      lastSelect = select;
      try {
        final fetched = await _fetchHomeProductRows(
          select: select,
          fetchLimit: fetchLimit,
          source: 'home_initial',
        );
        final parseResult = _parseHomeProductRows(fetched.rows);
        HomeDataDiagnostics.afterParse(
          successCount: parseResult.successCount,
          failCount: parseResult.failCount,
        );

        List<DBProduct> products = parseResult.products;
        if (followedStoreIds.isNotEmpty && products.isNotEmpty) {
          final scored = products
              .map(
                (product) => MapEntry(
                  product,
                  _homeFeedScore(product, followedStoreIds),
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => b.value.compareTo(a.value));
          products = scored
              .map((entry) => entry.key)
              .take(homeInitialPageSize)
              .toList(growable: false);
        } else {
          products = products.take(homeInitialPageSize).toList(growable: false);
        }

        final outcome = () {
          if (parseResult.failCount > 0 && products.isEmpty) {
            return HomeProductsFetchOutcome.parseError;
          }
          if (fetched.audit.isEmptyAfterFilter) {
            return HomeProductsFetchOutcome.filterEmpty;
          }
          if (products.isEmpty) {
            return HomeProductsFetchOutcome.empty;
          }
          return HomeProductsFetchOutcome.success;
        }();

        RuntimeDiagnosticLogger.products(
          'report outcome=${outcome.name} raw=${fetched.audit.rawCount} '
          'filtered=${fetched.audit.afterVisibilityFilterCount} '
          'parsed=${products.length}',
        );

        final report = HomeProductsFetchReport(
          outcome: outcome,
          products: products,
          table: table,
          querySummary: querySummary,
          selectFields: select,
          filterAudit: fetched.audit,
          parseSuccessCount: parseResult.successCount,
          parseFailCount: parseResult.failCount,
          lastParseError: parseResult.lastError,
        );

        if (fetched.audit.isEmptyAfterFilter &&
            _homeSelectIncludesApprovalColumns(select)) {
          approvalFilteredEmptyReport ??= report;
          HomeDataDiagnostics.approvalFilterRetry(
            rawCount: fetched.audit.rawCount,
            activeCount: fetched.audit.afterActiveStatusCount,
          );
          continue;
        }

        if (products.isNotEmpty) {
          final first = products.first;
          HomeDataDiagnostics.firstProduct(
            id: first.id ?? '',
            title: first.name,
            storeId: first.sellerId ?? '',
          );
        }
        HomeDataDiagnostics.requestSuccess(
          count: products.length,
          source: 'home_initial',
        );
        HomeDataDiagnostics.renderingProducts(count: products.length);

        return report;
      } catch (e, stackTrace) {
        HomeDataDiagnostics.requestError(error: e.toString());
        lastError = e;
        lastStack = stackTrace;
        RuntimeDiagnosticLogger.logFailure(
          'Products',
          e,
          stackTrace,
          context: 'home_fetch_report select=${select.length > 40 ? '${select.substring(0, 40)}...' : select}',
        );
        final message = e.toString();
        if (!isOptionalProductColumnError(message)) {
          break;
        }
      }
    }

    final filteredEmpty = approvalFilteredEmptyReport;
    if (filteredEmpty != null) {
      return filteredEmpty;
    }

    return HomeProductsFetchReport(
      outcome: HomeProductsFetchOutcome.queryError,
      products: const [],
      table: table,
      querySummary: querySummary,
      selectFields: lastSelect,
      error: lastError ?? StateError('Home products query failed'),
      stackTrace: lastStack,
    );
  }

  static bool _homeSelectIncludesApprovalColumns(String select) {
    return select.contains('approval_status') ||
        select.contains('admin_approval_status');
  }

  Future<({List<Map<String, dynamic>> rows, ProductFilterAudit audit})>
  _fetchHomeProductRows({
    required String select,
    required int fetchLimit,
    String source = 'home',
  }) async {
    String currentSelect = select;
    Object? lastError;

    for (var attempt = 0; attempt <= optionalProductColumns.length; attempt++) {
      try {
        final response = await _supabase
            .from('products')
            .select(currentSelect)
            .inFilter('status', publicCatalogProductStatuses)
            .order('created_at', ascending: false)
            .range(0, fetchLimit - 1);
        // Ana sayfa ürün fetch'i — kritik yol. Ara `List<...>.from(...)`
        // listesi gereksizdi (tüm ürün satırları için ikinci bir liste
        // ayırıyordu). Satır başına Map kopyası aynen korunuyor.
        final rawRows = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        final audit = ProductFilterAudit.fromRows(rawRows);
        final filtered = ProductVisibilityHelper.filterPublicProductMaps(rawRows);
        HomeDataDiagnostics.rawRows(count: audit.rawCount, source: source);
        HomeDataDiagnostics.afterVisibilityFilter(
          count: audit.afterVisibilityFilterCount,
        );
        HomeDataDiagnostics.afterApprovalFilter(
          count: audit.afterApprovalStatusCount,
        );
        RuntimeDiagnosticLogger.products(
          'filter audit raw=${audit.rawCount} active=${audit.afterActiveStatusCount} '
          'approval=${audit.afterApprovalStatusCount} visible=${audit.afterVisibilityFilterCount}',
        );
        return (rows: filtered, audit: audit);
      } catch (e) {
        lastError = e;
        final message = e.toString();
        if (!isOptionalProductColumnError(message)) rethrow;
        final stripped = _stripUnsupportedColumnsFromSelect(
          currentSelect,
          message: message,
        );
        if (stripped == currentSelect) break;
        currentSelect = stripped;
      }
    }

    if (lastError != null) throw lastError;
    throw StateError('Home product row fetch fallback ended unexpectedly.');
  }

  ({List<DBProduct> products, int successCount, int failCount, String? lastError})
  _parseHomeProductRows(List<Map<String, dynamic>> rows) {
    final parsed = <DBProduct>[];
    var failCount = 0;
    String? lastError;
    for (final row in rows) {
      try {
        parsed.add(_mapToDBProduct(row));
      } catch (e) {
        failCount++;
        lastError = e.toString();
        RuntimeDiagnosticLogger.products('parse failed id=${row['id']} error=$e');
      }
    }
    return (
      products: parsed,
      successCount: parsed.length,
      failCount: failCount,
      lastError: lastError,
    );
  }

  double _homeFeedScore(DBProduct product, Set<String> followedStoreIds) {
    const followBoost = 48.0;
    const discountBoost = 15.0;
    const popularityBoostCap = 20.0;
    const ratingBoostCap = 12.0;

    var score = 0.0;

    final sellerId = product.sellerId?.trim() ?? '';
    if (sellerId.isNotEmpty && followedStoreIds.contains(sellerId)) {
      score += followBoost;
    }

    final oldPrice = double.tryParse(product.oldPrice ?? '') ?? 0;
    final price = double.tryParse(product.price) ?? 0;
    if (oldPrice > price && price > 0) {
      score += discountBoost;
    }

    score += (product.reviewCount.clamp(0, 100) / 5.0)
        .clamp(0, popularityBoostCap);

    score += product.rating.clamp(0, 5) * (ratingBoostCap / 5);

    return score;
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
            .inFilter('status', publicCatalogProductStatuses);

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

  Future<DBProduct?> getProduct(int id) async => getProductByIdString('$id');

  /// Quick view enrich: kart üzerindeki ince veriyi tam ürün satırıyla
  /// tamamlamak için string id ile tek ürün çeker. Public görünürlük
  /// filtresi uygulanır; bulunamazsa/hata olursa null döner.
  Future<DBProduct?> getProductByIdString(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    try {
      final response = await _supabase
          .from('products')
          .select(_productSelectFields)
          .eq('id', normalized)
          .maybeSingle();

      if (response == null) return null;
      final row = Map<String, dynamic>.from(response as Map);
      if (!ProductVisibilityHelper.isPublicVisibleProductMap(row)) {
        return null;
      }
      return _mapToDBProduct(row);
    } catch (e) {
      debugPrint('Error getting product: $e');
      return null;
    }
  }

  DBProduct mapRowToDBProduct(Map<String, dynamic> row) => _mapToDBProduct(row);

  static const String _cartValidationSelect =
      'id, seller_id, store_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, discount_price, sale_price, stock, status, '
      'approval_status, admin_approval_status, variant_group_id, variants, '
      'updated_at, stores(business_name)';
  static const String _cartValidationSelectSansStore =
      'id, seller_id, store_id, name, brand, image_url, image_urls, main_category, '
      'sub_category, price, discount_price, sale_price, stock, status, '
      'approval_status, admin_approval_status, variant_group_id, variants, '
      'updated_at';

  Future<Map<String, Map<String, dynamic>>> getProductRowsForCartValidation(
    List<String> ids,
  ) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }

    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await _runCartValidationSelectWithFallback(
          select: _cartValidationSelect,
          action: (effectiveSelect) => _supabase
              .from('products')
              .select(effectiveSelect)
              .inFilter('id', normalizedIds),
        );
      } catch (e) {
        debugPrint('Cart validation select (store embed) warn: $e');
        rows = await _runCartValidationSelectWithFallback(
          select: _cartValidationSelectSansStore,
          action: (effectiveSelect) => _supabase
              .from('products')
              .select(effectiveSelect)
              .inFilter('id', normalizedIds),
        );
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final id = row['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        byId[id] = row;
      }
      return byId;
    } catch (e) {
      debugPrint('Error fetching cart validation rows: $e');
      return const <String, Map<String, dynamic>>{};
    }
  }

  Future<DBProduct?> getFirstProductByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _supabase
          .from('products')
          .select(_productSelectFields)
          .eq('name', trimmed)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      final row = Map<String, dynamic>.from(response as Map);
      if (!ProductVisibilityHelper.isPublicVisibleProductMap(row)) {
        return null;
      }
      return _mapToDBProduct(row);
    } catch (e) {
      debugPrint('Error getting product by name: $e');
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
          'video_url, video_path, video_public_url, thumbnail_path, thumbnail_public_url, '
          'video_duration_seconds, video_size_bytes, thumbnail_size_bytes, video_status, '
          'variants, attributes, faq, additional_info, accessories, barcode, model_code, '
          'variant_group_id, stock, status, approval_status, admin_approval_status, '
          'specifications',
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
          if (ProductVisibilityHelper.isPublicVisibleProductMap(item))
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

  /// Home feature ad cards — seller-selected SKUs; relaxed approval gate.
  /// Prefers RPC [get_ad_linked_products_by_ids] to bypass public RLS approval.
  Future<List<DBProduct>> getAdLinkedProductsByIds(List<String> ids) async {
    final report = await fetchAdLinkedProductsReport(ids);
    return report.products;
  }

  Future<AdLinkedProductsFetchReport> fetchAdLinkedProductsReport(
    List<String> ids, {
    AdLinkedProductsFetchContext? context,
  }) async {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return AdLinkedProductsFetchReport.empty();
    }

    final campaignId = context?.campaignId?.trim();
    final sellerId = context?.sellerId?.trim();

    final rpcAttempts = <({Map<String, dynamic> params, String label})>[
      if (campaignId != null &&
          campaignId.isNotEmpty &&
          sellerId != null &&
          sellerId.isNotEmpty)
        (
          params: {
            'p_product_ids': normalized,
            'p_campaign_id': campaignId,
            'p_seller_id': sellerId,
          },
          label: 'rpc:get_ad_linked_products_by_ids(3-arg)',
        ),
      (
        params: {'p_product_ids': normalized},
        label: 'rpc:get_ad_linked_products_by_ids(1-arg)',
      ),
    ];

    Object? lastRpcError;
    for (final attempt in rpcAttempts) {
      try {
        final response = await _supabase.rpc(
          'get_ad_linked_products_by_ids',
          params: attempt.params,
        );
        final rows = List<Map<String, dynamic>>.from(response as List);
        final mapped = _mapAdLinkedProductRows(
          rows: rows,
          requestedIds: normalized,
          fromRpc: true,
        );
        var rejections = mapped.rejections;
        var missingIds = mapped.missingIds;
        var error = rows.isEmpty && mapped.products.isEmpty
            ? 'rpc_returned_empty'
            : null;
        if (rows.isEmpty && mapped.products.isEmpty) {
          final enriched = await _enrichAdLinkedDiagnostics(
            productIds: normalized,
            campaignId: campaignId,
            rejections: rejections,
            missingIds: missingIds,
          );
          rejections = enriched.rejections;
          missingIds = enriched.missingIds;
          if (enriched.primaryReason != null) {
            error = 'rpc_returned_empty:${enriched.primaryReason}';
          }
        }
        return AdLinkedProductsFetchReport(
          products: mapped.products,
          requestedIdCount: normalized.length,
          rawRpcCount: rows.length,
          rawSelectCount: 0,
          rawDbCount: rows.length,
          filteredCount: mapped.products.length,
          query: attempt.label,
          rejections: rejections,
          missingIds: missingIds,
          usedRpc: true,
          context: context,
          error: error,
        );
      } catch (e) {
        lastRpcError = e;
        if (!_isMissingAdLinkedRpcSignature(e)) {
          break;
        }
        if (kDebugMode) {
          debugPrint(
            'getAdLinkedProductsByIds rpc signature miss (${attempt.label}): $e',
          );
        }
      }
    }

    if (lastRpcError != null) {
      debugPrint('getAdLinkedProductsByIds rpc failed, falling back: $lastRpcError');
    }
    return _fetchAdLinkedProductsDirectSelect(
      normalized,
      rpcError: lastRpcError?.toString(),
      context: context,
    );
  }

  bool _isMissingAdLinkedRpcSignature(Object error) {
    final message = error.toString();
    return message.contains('PGRST202') ||
        message.contains('Could not find the function') ||
        message.contains('schema cache');
  }

  Future<
      ({
        Map<String, String> rejections,
        Map<String, String> missingIds,
        String? primaryReason,
      })> _enrichAdLinkedDiagnostics({
    required List<String> productIds,
    String? campaignId,
    required Map<String, String> rejections,
    required Map<String, String> missingIds,
  }) async {
    if (productIds.isEmpty) {
      return (
        rejections: rejections,
        missingIds: missingIds,
        primaryReason: null,
      );
    }
    try {
      final params = <String, dynamic>{'p_product_ids': productIds};
      final trimmedCampaignId = campaignId?.trim();
      if (trimmedCampaignId != null && trimmedCampaignId.isNotEmpty) {
        params['p_campaign_id'] = trimmedCampaignId;
      }
      final response = await _supabase.rpc(
        'diagnose_ad_linked_products',
        params: params,
      );
      final rows = List<Map<String, dynamic>>.from(response as List);
      if (rows.isEmpty) {
        return (
          rejections: rejections,
          missingIds: missingIds,
          primaryReason: null,
        );
      }

      final nextRejections = Map<String, String>.from(rejections);
      final nextMissingIds = Map<String, String>.from(missingIds);
      String? primaryReason;

      for (final row in rows) {
        final productId = row['product_id']?.toString().trim();
        if (productId == null || productId.isEmpty) continue;
        final reason = row['reject_reason']?.toString().trim();
        if (reason == null || reason.isEmpty || reason == 'ok') continue;
        primaryReason ??= reason;
        if (reason == 'product_not_found') {
          nextMissingIds[productId] = reason;
          nextRejections.remove(productId);
        } else {
          nextRejections[productId] = reason;
          nextMissingIds.remove(productId);
        }
      }

      return (
        rejections: nextRejections,
        missingIds: nextMissingIds,
        primaryReason: primaryReason,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('diagnose_ad_linked_products skipped: $e');
      }
      return (
        rejections: rejections,
        missingIds: missingIds,
        primaryReason: null,
      );
    }
  }

  Future<AdLinkedProductsFetchReport> _fetchAdLinkedProductsDirectSelect(
    List<String> ids, {
    String? rpcError,
    AdLinkedProductsFetchContext? context,
  }) async {
    const selectCandidates = <String>[
      _homeProductCardSelectFields,
      _homeProductCardSelectFieldsSansStore,
      _productSelectFieldsSansStore,
    ];

    Object? lastError;
    for (final select in selectCandidates) {
      try {
        final response = await _supabase
            .from('products')
            .select(select)
            .inFilter('id', ids);

        final data = List<Map<String, dynamic>>.from(response as List);
        final mapped = _mapAdLinkedProductRows(
          rows: data,
          requestedIds: ids,
          fromRpc: false,
        );
        return AdLinkedProductsFetchReport(
          products: mapped.products,
          requestedIdCount: ids.length,
          rawRpcCount: 0,
          rawSelectCount: data.length,
          rawDbCount: data.length,
          filteredCount: mapped.products.length,
          query: 'products.select(...).inFilter(id, ids)',
          error: rpcError ??
              (data.isEmpty && ids.isNotEmpty ? 'rls_or_missing_rows' : null),
          rejections: mapped.rejections,
          missingIds: mapped.missingIds,
          usedRpc: false,
          context: context,
        );
      } catch (e, stack) {
        lastError = e;
        debugPrint('getAdLinkedProductsByIds select=$select failed: $e');
        debugPrintStack(stackTrace: stack);
      }
    }

    return AdLinkedProductsFetchReport(
      products: const [],
      requestedIdCount: ids.length,
      rawRpcCount: 0,
      rawSelectCount: 0,
      rawDbCount: 0,
      filteredCount: 0,
      query: 'products.select(...).inFilter(id, ids)',
      error: lastError?.toString() ?? rpcError ?? 'query_failed',
      missingIds: {for (final id in ids) id: 'not_fetched'},
      context: context,
    );
  }

  List<DBProduct> orderAdLinkedProducts({
    required List<String> productIds,
    required List<DBProduct> products,
    int maxProducts = 12,
  }) {
    if (productIds.isEmpty || products.isEmpty) return const [];
    final byId = {
      for (final product in products)
        if (product.id != null) product.id!: product,
    };
    return productIds
        .map((id) => byId[id.trim()])
        .whereType<DBProduct>()
        .take(maxProducts)
        .toList(growable: false);
  }

  ({
    List<DBProduct> products,
    Map<String, String> rejections,
    Map<String, String> missingIds,
  }) _mapAdLinkedProductRows({
    required List<Map<String, dynamic>> rows,
    required List<String> requestedIds,
    required bool fromRpc,
  }) {
    final byId = <String, DBProduct>{};
    final rejections = <String, String>{};
    for (final item in rows) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final rejectReason =
          ProductVisibilityHelper.adLinkedDisplayRejectReason(item);
      if (rejectReason != null) {
        rejections[id] = rejectReason;
        continue;
      }
      byId[id] = _mapToDBProduct(item);
    }

    final missingIds = <String, String>{};
    for (final id in requestedIds) {
      if (byId.containsKey(id)) continue;
      if (rejections.containsKey(id)) continue;
      missingIds[id] = rows.isEmpty
          ? (fromRpc ? 'rpc_empty_or_filtered' : 'rls_or_not_found')
          : 'id_not_in_response';
    }

    final products = requestedIds
        .map((id) => byId[id])
        .whereType<DBProduct>()
        .toList(growable: false);
    return (products: products, rejections: rejections, missingIds: missingIds);
  }

  Future<List<DBProduct>> getSimilarPublicProducts({
    required String excludeProductId,
    required String productName,
    required String brand,
    String? mainCategory,
    String? subCategory,
    int limit = 10,
  }) async {
    try {
      Future<List<Map<String, dynamic>>> runSelect(String fields) async {
        var query = _supabase
            .from('products')
            .select(fields)
            .inFilter('status', publicCatalogProductStatuses);

        if (excludeProductId.trim().isNotEmpty) {
          query = query.neq('id', excludeProductId.trim());
        }

        final normalizedCategory = mainCategory?.trim() ?? '';
        final normalizedSubCategory = subCategory?.trim() ?? '';
        if (normalizedSubCategory.isNotEmpty) {
          query = query.eq('sub_category', normalizedSubCategory);
        } else if (normalizedCategory.isNotEmpty) {
          query = query.eq('main_category', normalizedCategory);
        }

        final response = await query
            .order('created_at', ascending: false)
            .limit(limit * 3);
        return List<Map<String, dynamic>>.from(response as List);
      }

      List<Map<String, dynamic>> rows;
      try {
        rows = await runSelect(_productSuggestionSelectFields);
      } catch (_) {
        rows = await runSelect(_productSelectFieldsSansStore);
      }

      final currentName = productName.trim().toLowerCase();
      final currentBrand = brand.trim().toLowerCase();

      return ProductVisibilityHelper.filterPublicProductMaps(rows)
          .where((row) {
            final name = row['name']?.toString().trim().toLowerCase() ?? '';
            final rowBrand = row['brand']?.toString().trim().toLowerCase() ?? '';
            return !(name == currentName && rowBrand == currentBrand);
          })
          .take(limit)
          .map(_mapToDBProduct)
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error getting similar public products: $e');
      return const <DBProduct>[];
    }
  }

  Future<List<Map<String, dynamic>>> getOtherSellerOfferRows({
    required String productName,
    required String brand,
    String? barcode,
    String? modelCode,
    String? excludeSellerId,
    String? excludeProductId,
    int limit = 10,
  }) async {
    final trimmedName = productName.trim();
    if (trimmedName.isEmpty &&
        (barcode?.trim().isEmpty ?? true) &&
        (modelCode?.trim().isEmpty ?? true)) {
      return const [];
    }

    try {
      const offerFields =
          'id, seller_id, name, brand, barcode, model_code, image_url, image_urls, '
          'main_category, sub_category, price, discount_price, stock, status, '
          'approval_status, admin_approval_status, attributes, specifications, '
          'variant_options, stores(business_name, logo_url)';
      const offerFieldsSansStore =
          'id, seller_id, name, brand, barcode, model_code, image_url, image_urls, '
          'main_category, sub_category, price, discount_price, stock, status, '
          'approval_status, admin_approval_status, attributes, specifications, '
          'variant_options';

      Future<List<Map<String, dynamic>>> fetchRows({
        required Future<dynamic> Function(String fields) request,
      }) async {
        List<Map<String, dynamic>> rows;
        try {
          rows = List<Map<String, dynamic>>.from(await request(offerFields));
        } catch (_) {
          rows = List<Map<String, dynamic>>.from(
            await request(offerFieldsSansStore),
          );
        }

        return ProductVisibilityHelper.dedupeOtherSellerRows(
          ProductVisibilityHelper.filterPublicProductMaps(rows),
          excludeSellerId: excludeSellerId,
          excludeProductId: excludeProductId,
          limit: limit,
        );
      }

      final trimmedBarcode = barcode?.trim() ?? '';
      if (trimmedBarcode.isNotEmpty) {
        final byBarcode = await fetchRows(
          request: (fields) => _supabase
              .from('products')
              .select(fields)
              .eq('barcode', trimmedBarcode)
              .inFilter('status', publicCatalogProductStatuses)
              .order('price', ascending: true)
              .limit(limit * 2),
        );
        if (byBarcode.isNotEmpty) {
          return byBarcode;
        }
      }

      final trimmedModelCode = modelCode?.trim() ?? '';
      if (trimmedModelCode.isNotEmpty) {
        final byModel = await fetchRows(
          request: (fields) => _supabase
              .from('products')
              .select(fields)
              .eq('model_code', trimmedModelCode)
              .inFilter('status', publicCatalogProductStatuses)
              .order('price', ascending: true)
              .limit(limit * 2),
        );
        if (byModel.isNotEmpty) {
          return byModel;
        }
      }

      if (trimmedName.isEmpty) {
        return const [];
      }

      return fetchRows(
        request: (fields) {
          var query = _supabase
              .from('products')
              .select(fields)
              .eq('name', trimmedName)
              .inFilter('status', publicCatalogProductStatuses);
          final trimmedBrand = brand.trim();
          if (trimmedBrand.isNotEmpty) {
            query = query.eq('brand', trimmedBrand);
          }
          return query.order('price', ascending: true).limit(limit * 2);
        },
      );
    } catch (e) {
      debugPrint('Error getting other seller offers: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<String?> lookupVariantGroupIdByNameBrand({
    required String name,
    required String brand,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    try {
      Future<String?> runSelect(String fields) async {
        var query = _supabase.from('products').select(fields).eq('name', trimmedName);
        final trimmedBrand = brand.trim();
        if (trimmedBrand.isNotEmpty) {
          query = query.eq('brand', trimmedBrand);
        }
        final response = await query.limit(1).maybeSingle();
        if (response == null) return null;
        final row = Map<String, dynamic>.from(response as Map);
        final groupId = row['variant_group_id']?.toString().trim() ?? '';
        return groupId.isEmpty ? null : groupId;
      }

      try {
        return await runSelect('variant_group_id');
      } catch (_) {
        return null;
      }
    } catch (e) {
      debugPrint('Error looking up variant group id: $e');
      return null;
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
            .inFilter('status', publicCatalogProductStatuses);

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

      final items = ProductVisibilityHelper.filterPublicProductMaps(rows)
          .map(_mapToDBProduct)
          .toList(growable: false);
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
          .inFilter('status', publicCatalogProductStatuses)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final items = ProductVisibilityHelper.filterPublicProductMaps(
        List<Map<String, dynamic>>.from(response as List),
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
          .inFilter('status', publicCatalogProductStatuses)
          .eq('main_category', trimmedCategory);

      if (!CategoryProductFilter.isAllSubCategory(trimmedSubCategory)) {
        final subCategoryOrClause = CategoryProductFilter.buildSubCategoryOrClause(
          mainCategory: trimmedCategory,
          subCategory: trimmedSubCategory,
        );
        if (subCategoryOrClause != null) {
          builder = builder.or(subCategoryOrClause);
        } else {
          builder = builder.eq('sub_category', trimmedSubCategory);
        }
      }

      final response = await builder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final items = ProductVisibilityHelper.filterPublicProductMaps(
        List<Map<String, dynamic>>.from(response as List),
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
          .inFilter('status', publicCatalogProductStatuses)
          .order('created_at', ascending: false)
          .limit(limit);

      return ProductVisibilityHelper.filterPublicProductMaps(
        List<Map<String, dynamic>>.from(response as List),
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
          .inFilter('status', publicCatalogProductStatuses)
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
      if (!ProductVisibilityHelper.isPublicVisibleProductMap(row)) {
        continue;
      }
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
            .inFilter('status', publicCatalogProductStatuses)
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
    if (mainCategories.isEmpty) return const [];

    // Fetch all sub-categories in a single query instead of N+1 round-trips,
    // then group by parent_id client-side.
    List<DBCategory> allSubs;
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .not('parent_id', 'is', null)
          .eq('is_active', true)
          .order('order_index', ascending: true);
      allSubs = (response as List)
          .map((item) => _mapToDBCategory(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error getting sub-categories in bulk: $e');
      allSubs = const [];
    }

    final subsByParentId = <int, List<DBCategory>>{};
    for (final sub in allSubs) {
      if (sub.parentId != null) {
        subsByParentId.putIfAbsent(sub.parentId!, () => []).add(sub);
      }
    }

    return mainCategories
        .where((cat) => cat.id != null)
        .map(
          (mainCat) => CategoryWithSubcategories(
            mainCategory: mainCat,
            subCategories: subsByParentId[mainCat.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  // ==================== MAPPERS ====================

  static DateTime? _parseCatalogUpdatedAt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

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
      pricingMode: data['pricing_mode']?.toString() ?? 'base_only',
      basePrice: (data['base_price'] as num?)?.toDouble(),
      pricingType: data['pricing_type']?.toString() ?? 'portion',
      portionPrice: (data['portion_price'] as num?)?.toDouble(),
      pricePerKg: (data['price_per_kg'] as num?)?.toDouble(),
      sizeOptions: ProductSizeOption.listFromDynamic(data['size_options']),
      selectedSizeName: data['selected_size_name']?.toString(),
      selectedSizePrice: (data['selected_size_price'] as num?)?.toDouble(),
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
      isActive: () {
        final status = data['status']?.toString();
        final visible = isPublicCatalogProductStatus(status);
        if (!visible &&
            (status ?? '').trim().isNotEmpty &&
            status!.trim().toLowerCase() != 'taslak' &&
            status.trim().toLowerCase() != 'draft') {
          productVisibilityLog(
            'hide_unapproved_product',
            extra: {'productId': data['id'], 'status': status},
          );
        }
        return visible;
      }(),
      catalogStatus: data['status']?.toString(),
      approvalStatus: data['approval_status']?.toString(),
      adminApprovalStatus: data['admin_approval_status']?.toString(),
      catalogUpdatedAt: _parseCatalogUpdatedAt(
        data['updated_at'] ?? data['created_at'],
      ),
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
        'pricing_mode': product.pricingMode,
        'base_price': product.basePrice ?? product.portionPrice,
      'pricing_type': product.pricingType,
      'portion_price': product.portionPrice,
      'price_per_kg': product.pricePerKg,
        'size_options': product.sizeOptions.map((option) => option.toJson()).toList(),
        'selected_size_name': product.selectedSizeName,
        'selected_size_price': product.selectedSizePrice,
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
