import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Order-item product id. Never derived from product_code.
String? reviewProductIdFromOrderItem(Map<String, dynamic> item) {
  final raw = item['product_id'] ?? item['productId'];
  final id = raw?.toString().trim() ?? '';
  return id.isEmpty ? null : id;
}

/// Insert body for a new product review. [productId] is omitted when blank.
Map<String, dynamic> productReviewInsertPayload({
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
  String? productId,
}) {
  final payload = <String, dynamic>{
    'user_id': userId,
    'user_name': userName,
    'product_name': productName,
    'store_name': storeName,
    'seller_id': sellerId,
    'product_image_url': productImageUrl,
    'product_code': productCode,
    'rating': rating,
    'comment': comment.trim(),
    'image_urls': imageUrls,
  };
  final id = productId?.trim() ?? '';
  if (id.isNotEmpty) payload['product_id'] = id;
  return payload;
}

bool reviewWriteMissingProductIdColumn(Object error) {
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        (message.contains('product_id') && message.contains('does not exist'));
  }
  final text = error.toString().toLowerCase();
  return text.contains('42703') && text.contains('product_id');
}

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAllProductReviews() async {
    try {
      final rows = await _supabase
          .from('product_reviews')
          .select()
          .order('created_at', ascending: false)
          .limit(2000);
      return List<Map<String, dynamic>>.from(rows as List)
          .map(_mapProductReviewRow)
          .toList();
    } catch (e) {
      debugPrint('ReviewService.getAllProductReviews warn: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllSellerReviews() async {
    try {
      final rows = await _supabase
          .from('seller_reviews')
          .select()
          .order('created_at', ascending: false)
          .limit(2000);
      return List<Map<String, dynamic>>.from(rows as List)
          .map(_mapSellerReviewRow)
          .toList();
    } catch (e) {
      debugPrint('ReviewService.getAllSellerReviews warn: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createProductReview({
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
    String? productId,
  }) async {
    final payload = productReviewInsertPayload(
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
      productId: productId,
    );
    try {
      return await _insertProductReview(payload);
    } catch (error) {
      if (!payload.containsKey('product_id') ||
          !reviewWriteMissingProductIdColumn(error)) {
        rethrow;
      }
      payload.remove('product_id');
      return _insertProductReview(payload);
    }
  }

  Future<Map<String, dynamic>> _insertProductReview(
    Map<String, dynamic> payload,
  ) async {
    final row = await _supabase
        .from('product_reviews')
        .insert(payload)
        .select()
        .single();
    return _mapProductReviewRow(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> createSellerReview({
    required String storeName,
    required String sellerId,
    required double rating,
    required String comment,
    required List<String> imageUrls,
    required String userId,
    required String userName,
  }) async {
    final row = await _supabase
        .from('seller_reviews')
        .insert({
          'user_id': userId,
          'user_name': userName,
          'store_name': storeName,
          'seller_id': sellerId,
          'rating': rating,
          'comment': comment.trim(),
          'image_urls': imageUrls,
        })
        .select()
        .single();

    return _mapSellerReviewRow(Map<String, dynamic>.from(row));
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
