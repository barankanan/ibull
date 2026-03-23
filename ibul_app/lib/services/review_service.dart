import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    final row = await _supabase
        .from('product_reviews')
        .insert({
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
        })
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
