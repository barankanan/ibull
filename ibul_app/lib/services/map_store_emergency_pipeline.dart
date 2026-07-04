import 'package:supabase_flutter/supabase_flutter.dart';

import '../ads/models/home_card_template.dart';
import '../ads/services/home_feature_ad_service.dart';
import '../core/map_store_pipeline_helpers.dart';
import '../core/runtime_diagnostic_logger.dart';
import 'store/store_mapping_helpers.dart';
import 'supabase_service.dart';

/// Result of the emergency map store loading pipeline.
class MapStoreEmergencyResult {
  const MapStoreEmergencyResult({
    required this.rows,
    required this.primarySource,
    required this.stats,
  });

  final List<Map<String, dynamic>> rows;
  final String primarySource;
  final MapStorePipelineStats stats;
}

class MapStorePipelineStats {
  const MapStorePipelineStats({
    this.storesTableCount = 0,
    this.storesTableMinimalCount = 0,
    this.productSellerStoresCount = 0,
    this.activeProductsCount = 0,
    this.uniqueSellersCount = 0,
    this.homeAdsStoresCount = 0,
    this.syntheticGeneratedCount = 0,
    this.mergedUniqueCount = 0,
  });

  final int storesTableCount;
  final int storesTableMinimalCount;
  final int productSellerStoresCount;
  final int activeProductsCount;
  final int uniqueSellersCount;
  final int homeAdsStoresCount;
  final int syntheticGeneratedCount;
  final int mergedUniqueCount;
}

/// Guaranteed multi-source store loader for the map tab.
class MapStoreEmergencyPipeline {
  MapStoreEmergencyPipeline({
    SupabaseClient? client,
    HomeFeatureAdService? homeFeatureAdService,
  })  : _client = client ?? Supabase.instance.client,
        _homeFeatureAdService = homeFeatureAdService ?? HomeFeatureAdService();

  final SupabaseClient _client;
  final HomeFeatureAdService _homeFeatureAdService;

  static const _pipelineLog = 'MapPipeline';

  void _pipe(String message) => RuntimeDiagnosticLogger.map(message);

  Future<MapStoreEmergencyResult> load() async {
    _pipe('stores query started');
    final merged = <String, Map<String, dynamic>>{};
    var primarySource = 'none';
    var stats = const MapStorePipelineStats();

    // 1) stores_table full attempts
    _pipe('[$_pipelineLog] source=stores_table start');
    var storesTableCount = 0;
    const attempts = <({bool brand, bool desc})>[
      (brand: true, desc: true),
      (brand: false, desc: true),
      (brand: true, desc: false),
      (brand: false, desc: false),
    ];
    for (final attempt in attempts) {
      try {
        final rows = await _client
            .from('stores')
            .select(
              mapStoreSelect(
                includeBrandVerified: attempt.brand,
                includeDescription: attempt.desc,
              ),
            );
        final list = List<Map<String, dynamic>>.from(rows as List);
        storesTableCount = list.length;
        _mergeRows(merged, list, tag: 'stores_table');
        if (list.isNotEmpty) {
          primarySource = 'stores_table';
          break;
        }
      } catch (e) {
        if (!_isMissingColumnError(e)) {
          _pipe('[$_pipelineLog] stores_table failed error=$e');
        }
      }
    }
    _pipe('[$_pipelineLog] source=stores_table raw count=$storesTableCount');

    // 2) stores_table minimal
    var minimalCount = 0;
    if (merged.isEmpty) {
      try {
        final rows = await _client.from('stores').select(mapStoreSelectMinimal);
        final list = List<Map<String, dynamic>>.from(rows as List);
        minimalCount = list.length;
        _mergeRows(merged, list, tag: 'stores_table_minimal');
        if (list.isNotEmpty) primarySource = 'stores_table_minimal';
        _pipe(
          '[$_pipelineLog] source=stores_table_minimal raw count=$minimalCount',
        );
      } on PostgrestException catch (e) {
        _pipe(
          '[$_pipelineLog] stores_table_minimal failed '
          'code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
        );
      } catch (e) {
        _pipe('[$_pipelineLog] stores_table_minimal failed error=$e');
      }
    }

    // 3) product sellers — stats + store rows + synthetic rows
    var activeProducts = 0;
    var uniqueSellers = 0;
    var productStoreRows = 0;
    var syntheticFromProducts = 0;
    try {
      final sellerStats = await _loadActiveProductSellerStats();
      activeProducts = sellerStats.productCount;
      uniqueSellers = sellerStats.uniqueSellerCount;
      RuntimeDiagnosticLogger.mapFallback(
        'active products count=$activeProducts',
      );
      RuntimeDiagnosticLogger.mapFallback('unique sellers count=$uniqueSellers');

      if (sellerStats.sellerIds.isNotEmpty) {
        final storeRows = await _fetchStoresForSellerIds(sellerStats.sellerIds);
        productStoreRows = storeRows.length;
        _mergeRows(merged, storeRows, tag: 'product_sellers_fallback');
        if (merged.isNotEmpty && primarySource == 'none') {
          primarySource = 'product_sellers_fallback';
        }
      }

      if (sellerStats.entries.isNotEmpty) {
        final synthetic = buildSyntheticMapStoresFromProducts(
          sellers: sellerStats.entries,
        );
        syntheticFromProducts = synthetic.length;
        _mergeRows(merged, synthetic, tag: 'products_synthetic');
        if (merged.isNotEmpty && primarySource == 'none') {
          primarySource = 'products_synthetic';
        }
      }
    } catch (e, st) {
      RuntimeDiagnosticLogger.logFailure(
        'Map',
        e,
        st,
        context: 'product_sellers_fallback',
      );
    }

    // 4) home / category ads fallback (destina, sem usta, …)
    var homeAdsCount = 0;
    try {
      final homeRows = await _loadHomeCategoryAdStores();
      homeAdsCount = homeRows.length;
      RuntimeDiagnosticLogger.mapFallback(
        'home/category ads stores count=$homeAdsCount',
      );
      _mergeRows(merged, homeRows, tag: 'home_ads');
      if (merged.isNotEmpty && primarySource == 'none') {
        primarySource = 'home_ads';
      }
    } catch (e, st) {
      RuntimeDiagnosticLogger.logFailure(
        'Map',
        e,
        st,
        context: 'home_ads_fallback',
      );
    }

    // 5) emergency synthetic for any row still missing coords is handled at marker build

    final resultRows = merged.values.toList(growable: false);
    stats = MapStorePipelineStats(
      storesTableCount: storesTableCount,
      storesTableMinimalCount: minimalCount,
      productSellerStoresCount: productStoreRows,
      activeProductsCount: activeProducts,
      uniqueSellersCount: uniqueSellers,
      homeAdsStoresCount: homeAdsCount,
      syntheticGeneratedCount: syntheticFromProducts,
      mergedUniqueCount: resultRows.length,
    );

    if (resultRows.isEmpty) {
      final diagnosis = diagnoseMapStoresEmpty(
        storesTableCount: storesTableCount,
        productSellerFallbackCount: productStoreRows,
        syntheticFromProductsCount: syntheticFromProducts,
        activeProductsWithSeller: activeProducts,
        uniqueSellers: uniqueSellers,
        markerCount: 0,
      );
      _pipe('empty reason=$diagnosis');
    } else {
      _pipe('stores raw count=${resultRows.length} source=$primarySource');
    }

    return MapStoreEmergencyResult(
      rows: resultRows,
      primarySource: primarySource,
      stats: stats,
    );
  }

  void _mergeRows(
    Map<String, Map<String, dynamic>> merged,
    List<Map<String, dynamic>> rows, {
    required String tag,
  }) {
    for (final row in rows) {
      final key = _mergeKey(row);
      if (key.isEmpty) continue;
      final copy = Map<String, dynamic>.from(row);
      copy['_map_pipeline_source'] = tag;
      merged.putIfAbsent(key, () => copy);
    }
  }

  String _mergeKey(Map<String, dynamic> row) {
    final sellerId = row['seller_id']?.toString().trim();
    if (sellerId != null && sellerId.isNotEmpty) return 'sid:$sellerId';
    final name =
        row['business_name']?.toString() ??
        row['store_name']?.toString() ??
        row['name']?.toString() ??
        '';
    final normalized = name.trim().toLowerCase();
    if (normalized.isNotEmpty) return 'name:$normalized';
    return '';
  }

  bool _isMissingColumnError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('could not find') ||
        message.contains('does not exist') ||
        (message.contains('column') && message.contains('not exist'));
  }

  Future<({
    int productCount,
    int uniqueSellerCount,
    List<String> sellerIds,
    List<({String sellerId, String storeName})> entries,
  })> _loadActiveProductSellerStats() async {
    final statuses = SupabaseService.publicCatalogProductStatuses;
    final productRows = await _client
        .from('products')
        .select('seller_id, store_name')
        .inFilter('status', statuses)
        .limit(500);

    final sellerIds = <String>[];
    final entries = <({String sellerId, String storeName})>[];
    final seen = <String>{};

    for (final raw in productRows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final sellerId = row['seller_id']?.toString().trim() ?? '';
      if (sellerId.isEmpty) continue;
      final storeName = row['store_name']?.toString().trim() ?? '';
      entries.add((sellerId: sellerId, storeName: storeName));
      if (seen.add(sellerId)) sellerIds.add(sellerId);
    }

    return (
      productCount: entries.length,
      uniqueSellerCount: sellerIds.length,
      sellerIds: sellerIds,
      entries: entries,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStoresForSellerIds(
    List<String> sellerIds,
  ) async {
    if (sellerIds.isEmpty) return const [];
    final list = await _client
        .from('stores')
        .select(mapStoreSelectMinimal)
        .inFilter('seller_id', sellerIds);
    return List<Map<String, dynamic>>.from(list as List);
  }

  Future<List<Map<String, dynamic>>> _loadHomeCategoryAdStores() async {
    final groups = await _homeFeatureAdService.loadHomePageGroups();
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final HomeCategoryCardGroup group in groups) {
      for (final card in group.cards) {
        for (final ad in card.ads) {
          final sellerId = ad.sellerId.trim();
          if (sellerId.isEmpty) continue;
          final dedupe = sellerId;
          if (!seen.add(dedupe)) continue;
          rows.add({
            'seller_id': sellerId,
            'business_name': ad.storeName,
            'store_name': ad.storeName,
            'category': group.categoryName,
            'city': 'Hatay',
            'district': group.categoryName,
            'logo_url': ad.storeLogoUrl,
            '_source': 'home_ads',
          });
        }
      }
    }
    return rows;
  }
}
