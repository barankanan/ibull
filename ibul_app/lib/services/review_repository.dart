import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'review_service.dart';

/// Shared review identity for product detail and compare.
///
/// A row with [productId] matches only that id, even when the stored name or
/// store text is wrong. Name and store apply only when the row has no id.
/// Ambiguous legacy rows (same name and seller on more than one product) are
/// left unmatched.
List<Map<String, dynamic>> reviewsVisibleForProduct({
  required String? productId,
  required String productName,
  required String? storeName,
  required List<Map<String, dynamic>> reviews,
  String? sellerId,
  bool legacyNameIsAmbiguous = false,
}) {
  final selectedId = productId?.trim() ?? '';
  final selectedName = productName.trim().toLowerCase();
  final selectedStore = (storeName ?? '').trim().toLowerCase();
  final selectedSeller = (sellerId ?? '').trim();
  return [
    for (final review in reviews)
      if (_reviewVisibleForProduct(
        review,
        selectedId: selectedId,
        selectedName: selectedName,
        selectedStore: selectedStore,
        selectedSeller: selectedSeller,
        legacyNameIsAmbiguous: legacyNameIsAmbiguous,
      ))
        review,
  ];
}

bool _reviewVisibleForProduct(
  Map<String, dynamic> review, {
  required String selectedId,
  required String selectedName,
  required String selectedStore,
  required String selectedSeller,
  required bool legacyNameIsAmbiguous,
}) {
  final reviewId =
      (review['productId'] ?? review['product_id'])?.toString().trim() ?? '';
  if (reviewId.isNotEmpty) {
    return selectedId.isNotEmpty && reviewId == selectedId;
  }
  if (legacyNameIsAmbiguous) return false;
  final reviewName =
      (review['productName'] ?? review['product_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  final reviewStore =
      (review['storeName'] ?? review['store_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  final reviewSeller =
      (review['sellerId'] ?? review['seller_id'] ?? '').toString().trim();
  if (reviewName.isEmpty) return true;
  if (selectedName.isEmpty || reviewName != selectedName) return false;
  if (selectedSeller.isNotEmpty &&
      reviewSeller.isNotEmpty &&
      reviewSeller != selectedSeller) {
    return false;
  }
  if (selectedStore.isNotEmpty &&
      reviewStore.isNotEmpty &&
      reviewStore != selectedStore) {
    return false;
  }
  return true;
}

class ReviewSummary {
  const ReviewSummary({
    required this.reviews,
    required this.reviewCount,
    required this.averageRating,
  });

  final List<Map<String, dynamic>> reviews;
  final int reviewCount;
  final double averageRating;

  factory ReviewSummary.fromReviews(
    List<Map<String, dynamic>> reviews, {
    double fallbackRating = 0,
    int fallbackCount = 0,
  }) {
    final sortedReviews = List<Map<String, dynamic>>.from(reviews)
      ..sort(
        (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
          a['createdAt']?.toString() ?? '',
        ),
      );
    final numericRatings = sortedReviews
        .map((review) => (review['rating'] as num?)?.toDouble())
        .whereType<double>()
        .where((rating) => rating > 0)
        .toList(growable: false);
    final count = sortedReviews.isNotEmpty
        ? sortedReviews.length
        : fallbackCount;
    final average = numericRatings.isNotEmpty
        ? numericRatings.reduce((a, b) => a + b) / numericRatings.length
        : fallbackRating;
    return ReviewSummary(
      reviews: sortedReviews,
      reviewCount: count,
      averageRating: average,
    );
  }
}

@immutable
class ProductReviewLookup {
  const ProductReviewLookup({required this.productName, this.storeName});

  final String productName;
  final String? storeName;
}

@visibleForTesting
List<Map<String, dynamic>> reviewsMatchingLookup({
  required List<Map<String, dynamic>> mappedReviews,
  required ProductReviewLookup lookup,
  required int limit,
}) {
  final product = lookup.productName.trim().toLowerCase();
  final store = (lookup.storeName ?? '').trim().toLowerCase();
  return mappedReviews
      .where((row) {
        final name = (row['productName'] as String? ?? '').trim().toLowerCase();
        if (name != product) return false;
        if (store.isEmpty) return true;
        return (row['storeName'] as String? ?? '').trim().toLowerCase() ==
            store;
      })
      .take(limit)
      .toList(growable: false);
}

class _ReviewCacheEntry {
  const _ReviewCacheEntry(
    this.future,
    this.expiresAt,
    this.lastAccessAt, {
    this.value,
  });

  final Future<ReviewSummary> future;
  final DateTime expiresAt;
  final DateTime lastAccessAt;
  final ReviewSummary? value;

  _ReviewCacheEntry touch() =>
      _ReviewCacheEntry(future, expiresAt, DateTime.now(), value: value);

  _ReviewCacheEntry withValue(ReviewSummary nextValue) =>
      _ReviewCacheEntry(future, expiresAt, DateTime.now(), value: nextValue);
}

class ReviewRepository {
  ReviewRepository._();

  static final ReviewRepository instance = ReviewRepository._();

  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _maxEntries = 80;
  static const String _productReviewSelect =
      'id,user_id,user_name,product_name,store_name,seller_id,product_image_url,product_code,rating,comment,image_urls,likes,created_at';

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, _ReviewCacheEntry> _summaryCache = {};

  String buildProductLookupKey({
    required String productName,
    String? storeName,
  }) {
    return 'product::${productName.trim()}::${(storeName ?? '').trim()}';
  }

  ReviewSummary? peekProductReviewSummary({
    required String productName,
    String? storeName,
    int limit = 50,
  }) {
    final cacheKey = _buildProductSummaryCacheKey(
      productName: productName,
      storeName: storeName,
      limit: limit,
    );
    final now = DateTime.now();
    final cached = _summaryCache[cacheKey];
    if (cached == null || cached.expiresAt.isBefore(now)) {
      return null;
    }
    _summaryCache[cacheKey] = cached.touch();
    return cached.value;
  }

  ReviewSummary getInitialProductReviewSummary({
    required String productName,
    String? storeName,
    List<Map<String, dynamic>> localReviews = const [],
    double fallbackRating = 0,
    int fallbackCount = 0,
    int limit = 50,
  }) {
    final cached = peekProductReviewSummary(
      productName: productName,
      storeName: storeName,
      limit: limit,
    );
    if (cached == null) {
      return ReviewSummary.fromReviews(
        localReviews,
        fallbackRating: fallbackRating,
        fallbackCount: fallbackCount,
      );
    }

    return ReviewSummary.fromReviews(
      _mergeReviews(localReviews, cached.reviews),
      fallbackRating: fallbackRating,
      fallbackCount: fallbackCount,
    );
  }

  Future<void> preloadProductReviewSummaries(
    Iterable<ProductReviewLookup> lookups, {
    int limit = 50,
  }) async {
    final unique = <String, ProductReviewLookup>{};
    for (final lookup in lookups) {
      final productName = lookup.productName.trim();
      if (productName.isEmpty) continue;
      unique.putIfAbsent(
        buildProductLookupKey(
          productName: productName,
          storeName: lookup.storeName,
        ),
        () => ProductReviewLookup(
          productName: productName,
          storeName: lookup.storeName?.trim(),
        ),
      );
    }
    if (unique.isEmpty) return;

    final pending = unique.values.where((lookup) {
      return peekProductReviewSummary(
            productName: lookup.productName,
            storeName: lookup.storeName,
            limit: limit,
          ) ==
          null;
    }).toList(growable: false);
    if (pending.isEmpty) return;

    final names = pending
        .map((lookup) => lookup.productName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (names.isEmpty) return;

    try {
      final rowLimit = names.length * limit;
      final cappedLimit = rowLimit > 200
          ? 200
          : (rowLimit < limit ? limit : rowLimit);
      final rows = await _supabase
          .from('product_reviews')
          .select(_productReviewSelect)
          .inFilter('product_name', names)
          .order('created_at', ascending: false)
          .limit(cappedLimit);
      final mapped = List<Map<String, dynamic>>.from(rows as List)
          .map(_mapProductReviewRow)
          .toList(growable: false);
      for (final lookup in pending) {
        final matched = reviewsMatchingLookup(
          mappedReviews: mapped,
          lookup: lookup,
          limit: limit,
        );
        _seedProductSummary(
          productName: lookup.productName,
          storeName: lookup.storeName,
          limit: limit,
          summary: ReviewSummary.fromReviews(matched),
        );
      }
    } catch (e) {
      debugPrint('ReviewRepository.preloadProductReviewSummaries warn: $e');
      await Future.wait(
        pending.map(
          (lookup) => getProductReviewSummary(
            productName: lookup.productName,
            storeName: lookup.storeName,
            limit: limit,
          ),
        ),
      );
    }
  }

  bool _productIdColumnMissing = false;

  Future<ReviewSummary> getProductReviewSummary({
    required String productName,
    String? storeName,
    String? productId,
    String? sellerId,
    List<Map<String, dynamic>> localReviews = const [],
    int limit = 50,
  }) {
    final trimmedProductName = productName.trim();
    final trimmedStoreName = (storeName ?? '').trim();
    final trimmedProductId = productId?.trim() ?? '';
    final cacheKey = _buildProductSummaryCacheKey(
      productName: trimmedProductName,
      storeName: trimmedStoreName,
      limit: limit,
      productId: trimmedProductId,
    );

    return _getCachedSummary(cacheKey, () async {
      try {
        if (trimmedProductId.isNotEmpty && !_productIdColumnMissing) {
          try {
            final identified = await _reviewsForProductId(
              productId: trimmedProductId,
              productName: trimmedProductName,
              storeName: trimmedStoreName,
              sellerId: sellerId,
              localReviews: localReviews,
              limit: limit,
            );
            return ReviewSummary.fromReviews(identified);
          } catch (error) {
            if (!_isMissingProductIdColumn(error)) rethrow;
            _productIdColumnMissing = true;
          }
        }
        return ReviewSummary.fromReviews(
          _mergeReviews(
            localReviews,
            await _reviewsByNameAndStore(
              productName: trimmedProductName,
              storeName: trimmedStoreName,
              limit: limit,
            ),
          ),
        );
      } catch (e) {
        debugPrint('ReviewRepository.getProductReviewSummary warn: $e');
        return ReviewSummary.fromReviews(localReviews);
      }
    });
  }

  Future<List<Map<String, dynamic>>> _reviewsForProductId({
    required String productId,
    required String productName,
    required String storeName,
    required String? sellerId,
    required List<Map<String, dynamic>> localReviews,
    required int limit,
  }) async {
    final select = '$_productReviewSelect,product_id';
    final byId = await _supabase
        .from('product_reviews')
        .select(select)
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(limit);
    final identified = List<Map<String, dynamic>>.from(byId as List)
        .map(_mapProductReviewRow)
        .toList(growable: false);
    final ambiguous = await _legacyNameIsAmbiguous(
      sellerId: sellerId,
      productName: productName,
    );
    final legacy = ambiguous
        ? const <Map<String, dynamic>>[]
        : await _reviewsByNameAndStore(
            productName: productName,
            storeName: storeName,
            limit: limit,
            onlyNullProductId: true,
          );
    return reviewsVisibleForProduct(
      productId: productId,
      productName: productName,
      storeName: storeName,
      sellerId: sellerId,
      legacyNameIsAmbiguous: ambiguous,
      reviews: _mergeReviews(localReviews, [...identified, ...legacy]),
    );
  }

  Future<bool> _legacyNameIsAmbiguous({
    required String? sellerId,
    required String productName,
  }) async {
    final seller = (sellerId ?? '').trim();
    if (seller.isEmpty || productName.isEmpty) return false;
    try {
      final rows = await _supabase
          .from('products')
          .select('id')
          .eq('seller_id', seller)
          .ilike('name', productName)
          .limit(2);
      return (rows as List).length > 1;
    } catch (error) {
      debugPrint('ReviewRepository legacy ambiguity check warn: $error');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _reviewsByNameAndStore({
    required String productName,
    required String storeName,
    required int limit,
    bool onlyNullProductId = false,
  }) async {
    var query = _supabase.from('product_reviews').select(_productReviewSelect);
    if (onlyNullProductId) {
      query = query.isFilter('product_id', null);
    }
    query = query.ilike('product_name', productName);
    if (storeName.isNotEmpty) {
      query = query.ilike('store_name', storeName);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows as List)
        .map(_mapProductReviewRow)
        .toList(growable: false);
  }

  bool _isMissingProductIdColumn(Object error) =>
      reviewWriteMissingProductIdColumn(error);

  Future<ReviewSummary> getSellerReviewSummary({
    String? sellerId,
    String? storeName,
    List<Map<String, dynamic>> localReviews = const [],
    int limit = 50,
  }) {
    final trimmedSellerId = (sellerId ?? '').trim();
    final trimmedStoreName = (storeName ?? '').trim();
    final cacheKey = 'seller::$trimmedSellerId::$trimmedStoreName::$limit';

    return _getCachedSummary(cacheKey, () async {
      try {
        var query = _supabase
            .from('seller_reviews')
            .select(
              'id,user_id,user_name,store_name,seller_id,rating,comment,image_urls,created_at',
            );
        if (trimmedSellerId.isNotEmpty) {
          query = query.eq('seller_id', trimmedSellerId);
        } else if (trimmedStoreName.isNotEmpty) {
          query = query.ilike('store_name', trimmedStoreName);
        }
        final rows = await query
            .order('created_at', ascending: false)
            .limit(limit);
        final remoteReviews = List<Map<String, dynamic>>.from(
          rows as List,
        ).map(_mapSellerReviewRow).toList(growable: false);
        return ReviewSummary.fromReviews(
          _mergeReviews(localReviews, remoteReviews),
        );
      } catch (e) {
        debugPrint('ReviewRepository.getSellerReviewSummary warn: $e');
        return ReviewSummary.fromReviews(localReviews);
      }
    });
  }

  void invalidateProduct({required String productName, String? storeName}) {
    final prefix =
        'product::${productName.trim()}::${(storeName ?? '').trim()}::';
    _summaryCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  void invalidateSeller({String? sellerId, String? storeName}) {
    final prefix =
        'seller::${(sellerId ?? '').trim()}::${(storeName ?? '').trim()}::';
    _summaryCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<ReviewSummary> _getCachedSummary(
    String key,
    Future<ReviewSummary> Function() loader,
  ) {
    final now = DateTime.now();
    final cached = _summaryCache[key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      _summaryCache[key] = cached.touch();
      return cached.future;
    }

    final future = loader().then((summary) {
      final cachedEntry = _summaryCache[key];
      if (cachedEntry != null) {
        _summaryCache[key] = cachedEntry.withValue(summary);
      }
      return summary;
    });
    _summaryCache[key] = _ReviewCacheEntry(future, now.add(_cacheTtl), now);
    _trimCacheIfNeeded();
    return future;
  }

  String _buildProductSummaryCacheKey({
    required String productName,
    String? storeName,
    int limit = 50,
    String productId = '',
  }) {
    final base =
        '${buildProductLookupKey(productName: productName, storeName: storeName)}::$limit';
    final id = productId.trim();
    return id.isEmpty ? base : '$base::$id';
  }

  void _seedProductSummary({
    required String productName,
    String? storeName,
    required int limit,
    required ReviewSummary summary,
  }) {
    final key = _buildProductSummaryCacheKey(
      productName: productName,
      storeName: storeName,
      limit: limit,
    );
    final now = DateTime.now();
    _summaryCache[key] = _ReviewCacheEntry(
      Future<ReviewSummary>.value(summary),
      now.add(_cacheTtl),
      now,
      value: summary,
    );
    _trimCacheIfNeeded();
  }

  void _trimCacheIfNeeded() {
    if (_summaryCache.length <= _maxEntries) return;
    final entries = _summaryCache.entries.toList()
      ..sort((a, b) => a.value.lastAccessAt.compareTo(b.value.lastAccessAt));
    final removeCount = _summaryCache.length - _maxEntries;
    for (final entry in entries.take(removeCount)) {
      _summaryCache.remove(entry.key);
    }
  }

  List<Map<String, dynamic>> _mergeReviews(
    List<Map<String, dynamic>> localReviews,
    List<Map<String, dynamic>> remoteReviews,
  ) {
    final mergedById = <String, Map<String, dynamic>>{};
    for (final review in [...remoteReviews, ...localReviews]) {
      final id =
          review['id']?.toString().trim() ??
          '${review['userName']}_${review['createdAt']}_${review['comment']}';
      if (id.isEmpty) continue;
      mergedById[id] = review;
    }
    return mergedById.values.toList(growable: false)..sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> _mapProductReviewRow(Map<String, dynamic> row) {
    return {
      'id': row['id']?.toString() ?? '',
      'userId': row['user_id']?.toString(),
      'userName': row['user_name']?.toString() ?? 'Kullanıcı',
      'productName': row['product_name']?.toString() ?? '',
      'storeName': row['store_name']?.toString() ?? '',
      'sellerId': row['seller_id']?.toString() ?? '',
      'productImageUrl': row['product_image_url']?.toString() ?? '',
      'productCode': row['product_code']?.toString() ?? '',
      if (row['product_id'] != null) 'productId': row['product_id'].toString(),
      'rating': (row['rating'] as num?)?.toDouble() ?? 0,
      'comment': row['comment']?.toString() ?? '',
      'imageUrls': List<String>.from(row['image_urls'] ?? const []),
      'likes': (row['likes'] as num?)?.toInt() ?? 0,
      'createdAt': row['created_at']?.toString(),
    };
  }

  Map<String, dynamic> _mapSellerReviewRow(Map<String, dynamic> row) {
    return {
      'id': row['id']?.toString() ?? '',
      'userId': row['user_id']?.toString(),
      'userName': row['user_name']?.toString() ?? 'Kullanıcı',
      'storeName': row['store_name']?.toString() ?? '',
      'sellerId': row['seller_id']?.toString() ?? '',
      'rating': (row['rating'] as num?)?.toDouble() ?? 0,
      'comment': row['comment']?.toString() ?? '',
      'imageUrls': List<String>.from(row['image_urls'] ?? const []),
      'createdAt': row['created_at']?.toString(),
    };
  }
}
