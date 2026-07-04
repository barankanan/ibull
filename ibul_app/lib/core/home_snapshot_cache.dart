import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ads/models/home_card_template.dart';
import '../models/db_product.dart';
import 'app_perf_logger.dart';
import 'simple_memory_ttl_cache.dart';
import 'web_boot_step_profiler.dart';

const homeSnapshotDefaultTtl = Duration(minutes: 3);
const homeSnapshotPrefsKey = 'home_snapshot_cache_v1';
const homePopularProductsPrefsKey = 'home_popular_products_cache_v1';
const homePopularProductsCacheKey = 'popular_products';
const homePopularProductsLimit = 12;
const homePersonalizedProductsPrefsKey = 'home_personalized_products_cache_v1';
const homePersonalizedProductsCacheKey = 'personalized_products';
const homePersonalizedProductsLimit = 8;
const homeSnapshotProductsLimit = 24;
const homeSnapshotCategoryGroupsLimit = 8;
const homeSnapshotResolvedProductsPerAdLimit = 12;
const homeLegacyProductsCacheLimit = 24;
const homeSnapshotMaxRawBytes = 512 * 1024;
const homeSnapshotSlowDecodeMs = 500;

/// Ana sayfa anlık görüntüsü — cache-first render için.
class HomeSnapshot {
  const HomeSnapshot({
    this.categories = const [],
    this.heroAds = const [],
    this.products = const [],
    this.categoryCardGroups = const [],
    this.createdAt,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> heroAds;
  final List<DBProduct> products;
  final List<HomeCategoryCardGroup> categoryCardGroups;
  final DateTime? createdAt;

  bool get isEmpty =>
      categories.isEmpty &&
      heroAds.isEmpty &&
      products.isEmpty &&
      categoryCardGroups.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt?.toIso8601String(),
      'categories': categories,
      'heroAds': heroAds,
      'products': products.map((p) => p.toMap()).toList(growable: false),
      'categoryCardGroups': categoryCardGroups
          .map(_encodeCategoryCardGroup)
          .toList(growable: false),
    };
  }

  static HomeSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      final createdRaw = json['createdAt']?.toString();
      final createdAt = createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw);

      final categories = (json['categories'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];

      final heroAds = (json['heroAds'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];

      final products = (json['products'] as List?)
              ?.whereType<Map>()
              .map((e) => DBProduct.fromMap(Map<String, dynamic>.from(e)))
              .where((p) => p.isActive)
              .take(homeSnapshotProductsLimit)
              .toList(growable: false) ??
          const <DBProduct>[];

      final groupsRaw = json['categoryCardGroups'] as List? ?? const [];
      final categoryCardGroups = groupsRaw
          .whereType<Map>()
          .take(homeSnapshotCategoryGroupsLimit)
          .map(_decodeCategoryCardGroup)
          .whereType<HomeCategoryCardGroup>()
          .toList(growable: false);

      return HomeSnapshot(
        categories: categories,
        heroAds: heroAds,
        products: products,
        categoryCardGroups: categoryCardGroups,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _encodeCategoryCardGroup(HomeCategoryCardGroup g) {
    return {
      'categoryName': g.categoryName,
      'cards': g.cards
          .map(
            (card) => {
              'templateId': card.templateId,
              'cardTitle': card.cardTitle,
              'templateSortOrder': card.templateSortOrder,
              'ads': card.ads
                  .map(
                    (ad) => {
                      'campaignId': ad.campaignId,
                      'sellerId': ad.sellerId,
                      'storeId': ad.storeId,
                      'storeName': ad.storeName,
                      'cardTemplateId': ad.cardTemplateId,
                      'cardTitle': ad.cardTitle,
                      'categoryName': ad.categoryName,
                      'bannerUrls': ad.bannerUrls,
                      'productIds': ad.productIds,
                      'sortOrder': ad.sortOrder,
                      'sortMode': ad.sortMode,
                      'createdAt': ad.createdAt?.toIso8601String(),
                      'storeLogoUrl': ad.storeLogoUrl,
                      'resolvedProducts': ad.resolvedProducts
                          .map((p) => p.toMap())
                          .toList(growable: false),
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };
  }

  static HomeCategoryCardGroup? _decodeCategoryCardGroup(Map<dynamic, dynamic> raw) {
    try {
      final categoryName = raw['categoryName']?.toString() ?? '';
      if (categoryName.isEmpty) return null;
      final cardsRaw = raw['cards'] as List? ?? const [];
      final cards = cardsRaw.whereType<Map>().map((cardRaw) {
        final adsRaw = cardRaw['ads'] as List? ?? const [];
        final ads = adsRaw.whereType<Map>().map((adRaw) {
          final resolvedRaw = adRaw['resolvedProducts'] as List? ?? const [];
          final resolvedProducts = resolvedRaw
              .whereType<Map>()
              .map((p) => DBProduct.fromMap(Map<String, dynamic>.from(p)))
              .take(homeSnapshotResolvedProductsPerAdLimit)
              .toList(growable: false);
          return HomeFeatureDisplayAd(
            campaignId: adRaw['campaignId']?.toString() ?? '',
            sellerId: adRaw['sellerId']?.toString() ?? '',
            storeId: adRaw['storeId']?.toString(),
            storeName: adRaw['storeName']?.toString() ?? '',
            cardTemplateId: adRaw['cardTemplateId']?.toString() ?? '',
            cardTitle: adRaw['cardTitle']?.toString() ?? '',
            categoryName: adRaw['categoryName']?.toString() ?? categoryName,
            bannerUrls: (adRaw['bannerUrls'] as List?)
                    ?.map((e) => e.toString())
                    .toList(growable: false) ??
                const [],
            productIds: (adRaw['productIds'] as List?)
                    ?.map((e) => e.toString())
                    .toList(growable: false) ??
                const [],
            sortOrder: (adRaw['sortOrder'] as num?)?.toInt() ?? 0,
            sortMode: adRaw['sortMode']?.toString() ?? 'manual',
            createdAt: DateTime.tryParse(adRaw['createdAt']?.toString() ?? ''),
            storeLogoUrl: adRaw['storeLogoUrl']?.toString(),
            resolvedProducts: resolvedProducts,
          );
        }).toList(growable: false);

        return HomeCardDisplayGroup(
          templateId: cardRaw['templateId']?.toString() ?? '',
          cardTitle: cardRaw['cardTitle']?.toString() ?? categoryName,
          templateSortOrder: (cardRaw['templateSortOrder'] as num?)?.toInt() ?? 0,
          ads: ads,
        );
      }).toList(growable: false);

      return HomeCategoryCardGroup(categoryName: categoryName, cards: cards);
    } catch (_) {
      return null;
    }
  }
}

/// Bellek + SharedPreferences ana sayfa snapshot önbelleği.
class HomeSnapshotCache {
  HomeSnapshotCache._();

  static final HomeSnapshotCache instance = HomeSnapshotCache._();
  final SimpleMemoryTtlCache<HomeSnapshot> _memory =
      SimpleMemoryTtlCache(defaultTtl: homeSnapshotDefaultTtl);
  final SimpleMemoryTtlCache<List<DBProduct>> _popularProductsMemory =
      SimpleMemoryTtlCache(defaultTtl: homeSnapshotDefaultTtl);
  final SimpleMemoryTtlCache<List<DBProduct>> _personalizedProductsMemory =
      SimpleMemoryTtlCache(defaultTtl: homeSnapshotDefaultTtl);
  bool _isReadingPersisted = false;

  static Future<void> clearPersistedSnapshot(SharedPreferences prefs) async {
    await prefs.remove(homeSnapshotPrefsKey);
  }

  static Future<void> clearPopularProductsPersisted(SharedPreferences prefs) async {
    await prefs.remove(homePopularProductsPrefsKey);
  }

  static Future<void> clearPersonalizedProductsPersisted(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(homePersonalizedProductsPrefsKey);
  }

  HomeSnapshot? readMemory({Duration? ttl}) =>
      _memory.read('home', ttl: ttl);

  /// Popüler Ürünler için hafif bellek cache (ilk 12 ürün).
  List<DBProduct>? readPopularProducts({Duration? ttl}) {
    final dedicated = _popularProductsMemory.read(
      homePopularProductsCacheKey,
      ttl: ttl,
    );
    if (dedicated != null && dedicated.isNotEmpty) {
      return List<DBProduct>.from(dedicated);
    }
    final snapshot = readMemory(ttl: ttl);
    if (snapshot == null || snapshot.products.isEmpty) return null;
    return snapshot.products.take(homePopularProductsLimit).toList(growable: false);
  }

  void writePopularProducts(List<DBProduct> products) {
    final slice = products
        .where((product) => product.isActive)
        .take(homePopularProductsLimit)
        .toList(growable: false);
    if (slice.isEmpty) return;
    _popularProductsMemory.write(homePopularProductsCacheKey, slice);
  }

  Future<List<DBProduct>?> readPopularProductsPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(homePopularProductsPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      if (raw.length > homeSnapshotMaxRawBytes) {
        await clearPopularProductsPersisted(prefs);
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await clearPopularProductsPersisted(prefs);
        return null;
      }
      return decoded
          .whereType<Map>()
          .map((item) => DBProduct.fromMap(Map<String, dynamic>.from(item)))
          .where((product) => product.isActive)
          .take(homePopularProductsLimit)
          .toList(growable: false);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await clearPopularProductsPersisted(prefs);
      } catch (_) {}
      return null;
    }
  }

  Future<void> writePopularProductsPersisted(List<DBProduct> products) async {
    final slice = products
        .where((product) => product.isActive)
        .take(homePopularProductsLimit)
        .toList(growable: false);
    if (slice.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        homePopularProductsPrefsKey,
        jsonEncode(slice.map((product) => product.toMap()).toList()),
      );
      writePopularProducts(slice);
    } catch (_) {}
  }

  /// Sana Özel Ürünler için bellek cache (ilk 10 ürün).
  List<DBProduct>? readPersonalizedProducts({Duration? ttl}) {
    final dedicated = _personalizedProductsMemory.read(
      homePersonalizedProductsCacheKey,
      ttl: ttl,
    );
    if (dedicated != null && dedicated.isNotEmpty) {
      return List<DBProduct>.from(dedicated);
    }
    return null;
  }

  void writePersonalizedProducts(List<DBProduct> products) {
    final slice = products
        .where((product) => product.isActive)
        .take(homePersonalizedProductsLimit)
        .toList(growable: false);
    if (slice.isEmpty) return;
    _personalizedProductsMemory.write(homePersonalizedProductsCacheKey, slice);
  }

  Future<List<DBProduct>?> readPersonalizedProductsPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(homePersonalizedProductsPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      if (raw.length > homeSnapshotMaxRawBytes) {
        await clearPersonalizedProductsPersisted(prefs);
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await clearPersonalizedProductsPersisted(prefs);
        return null;
      }
      return decoded
          .whereType<Map>()
          .map((item) => DBProduct.fromMap(Map<String, dynamic>.from(item)))
          .where((product) => product.isActive)
          .take(homePersonalizedProductsLimit)
          .toList(growable: false);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await clearPersonalizedProductsPersisted(prefs);
      } catch (_) {}
      return null;
    }
  }

  Future<void> writePersonalizedProductsPersisted(
    List<DBProduct> products,
  ) async {
    final slice = products
        .where((product) => product.isActive)
        .take(homePersonalizedProductsLimit)
        .toList(growable: false);
    if (slice.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        homePersonalizedProductsPrefsKey,
        jsonEncode(slice.map((product) => product.toMap()).toList()),
      );
      writePersonalizedProducts(slice);
    } catch (_) {}
  }

  void writeMemory(HomeSnapshot snapshot) {
    if (snapshot.isEmpty) return;
    _memory.write(
      'home',
      HomeSnapshot(
        categories: List<Map<String, dynamic>>.from(snapshot.categories),
        heroAds: List<Map<String, dynamic>>.from(snapshot.heroAds),
        products: List<DBProduct>.from(snapshot.products),
        categoryCardGroups:
            List<HomeCategoryCardGroup>.from(snapshot.categoryCardGroups),
        createdAt: snapshot.createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<HomeSnapshot?> readPersisted() async {
    if (_isReadingPersisted) {
      return readMemory();
    }
    _isReadingPersisted = true;
    final started = DateTime.now();
    WebBootStepProfiler.start('home_snapshot_cache_read');
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(homeSnapshotPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      if (raw.length > homeSnapshotMaxRawBytes) {
        await clearPersistedSnapshot(prefs);
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clearPersistedSnapshot(prefs);
        return null;
      }
      final snapshot =
          HomeSnapshot.fromJson(Map<String, dynamic>.from(decoded));
      if (snapshot == null) {
        await clearPersistedSnapshot(prefs);
        return null;
      }
      return snapshot;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await clearPersistedSnapshot(prefs);
      } catch (_) {}
      return null;
    } finally {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (elapsed > homeSnapshotSlowDecodeMs) {
        WebBootStepProfiler.slow('home_snapshot_cache_read', elapsed);
      } else {
        WebBootStepProfiler.done('home_snapshot_cache_read', detail: 'ms=$elapsed');
      }
      _isReadingPersisted = false;
    }
  }

  Future<void> writePersisted(HomeSnapshot snapshot) async {
    if (snapshot.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        snapshot
            .copyWithCreatedAt(snapshot.createdAt ?? DateTime.now())
            .toJson(),
      );
      await prefs.setString(homeSnapshotPrefsKey, payload);
      writeMemory(snapshot);
    } catch (_) {}
  }

  void invalidate() {
    _memory.invalidate('home');
    _popularProductsMemory.invalidate(homePopularProductsCacheKey);
    _personalizedProductsMemory.invalidate(homePersonalizedProductsCacheKey);
  }
}

extension on HomeSnapshot {
  HomeSnapshot copyWithCreatedAt(DateTime createdAt) {
    return HomeSnapshot(
      categories: categories,
      heroAds: heroAds,
      products: products,
      categoryCardGroups: categoryCardGroups,
      createdAt: createdAt,
    );
  }
}

/// Ana sayfa boot/fetch zamanlaması (debug).
class HomeBootPerfTracker {
  HomeBootPerfTracker({int? startMs})
      : startMs = startMs ?? DateTime.now().millisecondsSinceEpoch;

  static HomeBootPerfTracker? current;

  final int startMs;
  int? firstFrameMs;
  int? routeReadyMs;
  bool cachedSnapshotUsed = false;

  int? categoriesMs;
  int? heroAdsMs;
  int? sponsoredListsMs;
  int? storeStoriesMs;
  int? productSectionsMs;
  int fetchStartedMs = 0;

  int? heroPrecacheMs;
  int? visibleProductImagesPrecacheMs;
  int failedImageCount = 0;

  void markFirstFrame() {
    firstFrameMs ??= DateTime.now().millisecondsSinceEpoch - startMs;
  }

  void markRouteReady() {
    routeReadyMs ??= DateTime.now().millisecondsSinceEpoch - startMs;
  }

  void markFetchStart() {
    fetchStartedMs = DateTime.now().millisecondsSinceEpoch;
  }

  int? get totalFetchMs {
    if (fetchStartedMs <= 0) return null;
    return DateTime.now().millisecondsSinceEpoch - fetchStartedMs;
  }

  void logBoot() {
    AppPerfLogger.logHomeBoot(
      startMs: startMs,
      firstFrameMs: firstFrameMs,
      routeReadyMs: routeReadyMs,
      cachedSnapshotUsed: cachedSnapshotUsed,
    );
  }

  void logFetch({bool parallel = false}) {
    AppPerfLogger.logHomeFetch(
      categoriesMs: categoriesMs,
      heroAdsMs: heroAdsMs,
      sponsoredListsMs: sponsoredListsMs,
      storeStoriesMs: storeStoriesMs,
      productSectionsMs: productSectionsMs,
      totalMs: totalFetchMs,
      parallel: parallel,
    );
  }

  void logImages() {
    AppPerfLogger.logHomeImages(
      heroPrecacheMs: heroPrecacheMs,
      visibleProductImagesPrecacheMs: visibleProductImagesPrecacheMs,
      failedImageCount: failedImageCount,
    );
  }
}
