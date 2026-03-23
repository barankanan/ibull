import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final requests = <Future<ReviewSummary>>[];
    final seen = <String>{};

    for (final lookup in lookups) {
      final key = buildProductLookupKey(
        productName: lookup.productName,
        storeName: lookup.storeName,
      );
      if (!seen.add(key)) continue;

      requests.add(
        getProductReviewSummary(
          productName: lookup.productName,
          storeName: lookup.storeName,
          limit: limit,
        ),
      );
    }

    if (requests.isEmpty) return;
    await Future.wait(requests);
  }

  Future<ReviewSummary> getProductReviewSummary({
    required String productName,
    String? storeName,
    List<Map<String, dynamic>> localReviews = const [],
    int limit = 50,
  }) {
    final trimmedProductName = productName.trim();
    final trimmedStoreName = (storeName ?? '').trim();
    final cacheKey = _buildProductSummaryCacheKey(
      productName: trimmedProductName,
      storeName: trimmedStoreName,
      limit: limit,
    );

    return _getCachedSummary(cacheKey, () async {
      try {
        var query = _supabase
            .from('product_reviews')
            .select(
              'id,user_id,user_name,product_name,store_name,seller_id,product_image_url,product_code,rating,comment,image_urls,likes,created_at',
            )
            .ilike('product_name', trimmedProductName);
        if (trimmedStoreName.isNotEmpty) {
          query = query.ilike('store_name', trimmedStoreName);
        }
        final rows = await query
            .order('created_at', ascending: false)
            .limit(limit);
        final remoteReviews = List<Map<String, dynamic>>.from(
          rows as List,
        ).map(_mapProductReviewRow).toList(growable: false);
        return ReviewSummary.fromReviews(
          _mergeReviews(localReviews, remoteReviews),
        );
      } catch (e) {
        debugPrint('ReviewRepository.getProductReviewSummary warn: $e');
        return ReviewSummary.fromReviews(localReviews);
      }
    });
  }

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
  }) {
    return '${buildProductLookupKey(productName: productName, storeName: storeName)}::$limit';
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
