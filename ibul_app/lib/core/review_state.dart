import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/review_repository.dart';
import '../services/review_service.dart';

@immutable
class ProductRatingSummary {
  const ProductRatingSummary({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductRatingSummary &&
        other.rating == rating &&
        other.reviewCount == reviewCount;
  }

  @override
  int get hashCode => Object.hash(rating, reviewCount);
}

class ReviewState extends ChangeNotifier {
  static final ReviewState _instance = ReviewState._internal();

  factory ReviewState() => _instance;

  ReviewState._internal() {
    initialize();
  }

  Future<void>? _initializationFuture;
  bool _isInitialized = false;
  final List<Map<String, dynamic>> _productReviews = [];
  final List<Map<String, dynamic>> _sellerReviews = [];
  final Map<String, List<Map<String, dynamic>>> _productReviewCache = {};
  final Map<String, List<Map<String, dynamic>>> _storeProductReviewCache = {};
  final Map<String, List<Map<String, dynamic>>> _sellerReviewCache = {};
  final Map<String, ProductRatingSummary> _productRatingCache = {};

  List<Map<String, dynamic>> get productReviews =>
      List.unmodifiable(_productReviews);
  List<Map<String, dynamic>> get sellerReviews =>
      List.unmodifiable(_sellerReviews);

  Future<void> initialize() {
    return _initializationFuture ??= _loadPersistedReviews();
  }

  Future<void> _loadPersistedReviews() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawProductReviews = prefs.getString('product_reviews_v1');
      final rawSellerReviews = prefs.getString('seller_reviews_v1');

      _productReviews
        ..clear()
        ..addAll(_decodeStoredReviewList(rawProductReviews));
      _sellerReviews
        ..clear()
        ..addAll(_decodeStoredReviewList(rawSellerReviews));
      _invalidateAllCaches();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading persisted reviews: $e');
      }
    }
  }

  List<Map<String, dynamic>> _decodeStoredReviewList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistReviewLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('product_reviews_v1', jsonEncode(_productReviews));
      await prefs.setString('seller_reviews_v1', jsonEncode(_sellerReviews));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving persisted reviews: $e');
      }
    }
  }

  String _normalizeReviewKey(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  String _productCacheKey({required String productName, String? storeName}) {
    return '${_normalizeReviewKey(productName)}::${_normalizeReviewKey(storeName ?? '')}';
  }

  String _productRatingCacheKey({
    required String productName,
    String? storeName,
    required double fallbackRating,
    required int fallbackReviewCount,
  }) {
    return '${_productCacheKey(productName: productName, storeName: storeName)}::$fallbackRating::$fallbackReviewCount';
  }

  String _storeCacheKey(String storeName) {
    return _normalizeReviewKey(storeName);
  }

  String _sellerCacheKey({String? sellerId, String? storeName}) {
    return '${(sellerId ?? '').trim()}::${_normalizeReviewKey(storeName ?? '')}';
  }

  void _invalidateAllCaches() {
    _productReviewCache.clear();
    _storeProductReviewCache.clear();
    _sellerReviewCache.clear();
    _productRatingCache.clear();
  }

  void _invalidateProductCaches({
    required String productName,
    String? storeName,
  }) {
    final productKey = _productCacheKey(
      productName: productName,
      storeName: storeName,
    );
    final storeKey = _storeCacheKey(storeName ?? '');
    _productReviewCache.remove(productKey);
    _productRatingCache.removeWhere(
      (key, _) => key.startsWith('$productKey::'),
    );
    if (storeKey.isNotEmpty) {
      _storeProductReviewCache.remove(storeKey);
    }
  }

  void _invalidateSellerCaches({String? sellerId, String? storeName}) {
    final sellerKey = _sellerCacheKey(sellerId: sellerId, storeName: storeName);
    _sellerReviewCache.remove(sellerKey);
  }

  List<Map<String, dynamic>> _sortReviews(
    Iterable<Map<String, dynamic>> reviews,
  ) {
    final result = reviews
        .map((review) => Map<String, dynamic>.from(review))
        .toList();
    result.sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
    return List.unmodifiable(result);
  }

  List<Map<String, dynamic>> getProductReviewsFor({
    required String productName,
    String? storeName,
  }) {
    final cacheKey = _productCacheKey(
      productName: productName,
      storeName: storeName,
    );
    final cached = _productReviewCache[cacheKey];
    if (cached != null) return cached;

    final normalizedProduct = _normalizeReviewKey(productName);
    final normalizedStore = _normalizeReviewKey(storeName ?? '');
    final reviews = _sortReviews(
      _productReviews.where((review) {
        final reviewProduct = _normalizeReviewKey(
          review['productName']?.toString() ?? '',
        );
        final reviewStore = _normalizeReviewKey(
          review['storeName']?.toString() ?? '',
        );
        if (reviewProduct != normalizedProduct) return false;
        if (normalizedStore.isEmpty) return true;
        return reviewStore == normalizedStore;
      }),
    );
    _productReviewCache[cacheKey] = reviews;
    return reviews;
  }

  List<Map<String, dynamic>> getProductReviewsForStore({
    required String storeName,
  }) {
    final cacheKey = _storeCacheKey(storeName);
    final cached = _storeProductReviewCache[cacheKey];
    if (cached != null) return cached;

    final normalizedStore = _normalizeReviewKey(storeName);
    final reviews = _sortReviews(
      _productReviews.where((review) {
        final reviewStore = _normalizeReviewKey(
          review['storeName']?.toString() ?? '',
        );
        return reviewStore == normalizedStore;
      }),
    );
    _storeProductReviewCache[cacheKey] = reviews;
    return reviews;
  }

  List<Map<String, dynamic>> getSellerReviewsFor({
    String? sellerId,
    String? storeName,
  }) {
    final cacheKey = _sellerCacheKey(sellerId: sellerId, storeName: storeName);
    final cached = _sellerReviewCache[cacheKey];
    if (cached != null) return cached;

    final normalizedSellerId = (sellerId ?? '').trim();
    final normalizedStore = _normalizeReviewKey(storeName ?? '');
    final reviews = _sortReviews(
      _sellerReviews.where((review) {
        final reviewSellerId = review['sellerId']?.toString().trim() ?? '';
        final reviewStore = _normalizeReviewKey(
          review['storeName']?.toString() ?? '',
        );
        if (normalizedSellerId.isNotEmpty &&
            reviewSellerId == normalizedSellerId) {
          return true;
        }
        if (normalizedStore.isEmpty) return false;
        return reviewStore == normalizedStore;
      }),
    );
    _sellerReviewCache[cacheKey] = reviews;
    return reviews;
  }

  ProductRatingSummary getProductRatingSummary({
    required String productName,
    String? storeName,
    double fallbackRating = 0,
    int fallbackReviewCount = 0,
  }) {
    final cacheKey = _productRatingCacheKey(
      productName: productName,
      storeName: storeName,
      fallbackRating: fallbackRating,
      fallbackReviewCount: fallbackReviewCount,
    );
    final cached = _productRatingCache[cacheKey];
    if (cached != null) return cached;

    final reviews = getProductReviewsFor(
      productName: productName,
      storeName: storeName,
    );
    final initialSummary = ReviewRepository.instance
        .getInitialProductReviewSummary(
          productName: productName,
          storeName: storeName,
          localReviews: reviews,
          fallbackRating: fallbackRating,
          fallbackCount: fallbackReviewCount,
        );

    final summary = ProductRatingSummary(
      rating: double.parse(initialSummary.averageRating.toStringAsFixed(1)),
      reviewCount: initialSummary.reviewCount,
    );
    _productRatingCache[cacheKey] = summary;
    return summary;
  }

  Future<void> warmProductRatingSummaries(
    Iterable<ProductReviewLookup> lookups, {
    int limit = 50,
  }) async {
    final uniqueLookups = <String, ProductReviewLookup>{};
    for (final lookup in lookups) {
      final productName = lookup.productName.trim();
      if (productName.isEmpty) continue;
      final key = ReviewRepository.instance.buildProductLookupKey(
        productName: productName,
        storeName: lookup.storeName,
      );
      uniqueLookups.putIfAbsent(
        key,
        () => ProductReviewLookup(
          productName: productName,
          storeName: lookup.storeName?.trim(),
        ),
      );
    }

    if (uniqueLookups.isEmpty) return;

    await ReviewRepository.instance.preloadProductReviewSummaries(
      uniqueLookups.values,
      limit: limit,
    );

    for (final lookup in uniqueLookups.values) {
      final productKey = _productCacheKey(
        productName: lookup.productName,
        storeName: lookup.storeName,
      );
      _productRatingCache.removeWhere(
        (key, _) => key.startsWith('$productKey::'),
      );
    }

    notifyListeners();
  }

  List<Map<String, dynamic>> getMyProductReviews(String userId) {
    if (userId.isEmpty) return const [];
    return _sortReviews(
      _productReviews.where((review) => review['userId']?.toString() == userId),
    );
  }

  List<Map<String, dynamic>> getMySellerReviews(String userId) {
    if (userId.isEmpty) return const [];
    return _sortReviews(
      _sellerReviews.where((review) => review['userId']?.toString() == userId),
    );
  }

  Future<void> addProductReview({
    required String productName,
    required String storeName,
    required String sellerId,
    required String productImageUrl,
    required String productCode,
    required double rating,
    required String comment,
    required List<String> imageUrls,
    required String userId,
    required String userName,
  }) async {
    final review = await ReviewService.instance.createProductReview(
      productName: productName,
      storeName: storeName,
      sellerId: sellerId,
      productImageUrl: productImageUrl,
      productCode: productCode,
      rating: rating,
      comment: comment,
      imageUrls: imageUrls,
      userId: userId,
      userName: userName,
    );

    _productReviews.removeWhere(
      (item) => item['id']?.toString() == review['id']?.toString(),
    );
    _productReviews.insert(0, review);
    _invalidateProductCaches(productName: productName, storeName: storeName);
    ReviewRepository.instance.invalidateProduct(
      productName: productName,
      storeName: storeName,
    );
    notifyListeners();
    await _persistReviewLists();
  }

  Future<void> addSellerReview({
    required String storeName,
    required String sellerId,
    required double rating,
    required String comment,
    required List<String> imageUrls,
    required String userId,
    required String userName,
  }) async {
    final review = await ReviewService.instance.createSellerReview(
      storeName: storeName,
      sellerId: sellerId,
      rating: rating,
      comment: comment,
      imageUrls: imageUrls,
      userId: userId,
      userName: userName,
    );

    _sellerReviews.removeWhere(
      (item) => item['id']?.toString() == review['id']?.toString(),
    );
    _sellerReviews.insert(0, review);
    _invalidateSellerCaches(sellerId: sellerId, storeName: storeName);
    ReviewRepository.instance.invalidateSeller(
      sellerId: sellerId,
      storeName: storeName,
    );
    notifyListeners();
    await _persistReviewLists();
  }
}
