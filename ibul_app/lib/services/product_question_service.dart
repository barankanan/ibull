import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/text_normalizer.dart';

class _QuestionCacheEntry {
  const _QuestionCacheEntry({required this.expiresAt, required this.items});

  final DateTime expiresAt;
  final List<Map<String, dynamic>> items;
}

class ProductQuestionService {
  ProductQuestionService._();
  static final ProductQuestionService instance = ProductQuestionService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, _QuestionCacheEntry> _questionCache =
      <String, _QuestionCacheEntry>{};
  static const Duration _cacheTtl = Duration(minutes: 10);

  Future<List<Map<String, dynamic>>> getQuestions({
    required String productName,
    String? storeName,
    int limit = 30,
    String? cursor,
  }) async {
    final cacheKey = [
      TextNormalizer.normalize(productName),
      TextNormalizer.normalize(storeName),
      cursor ?? '0',
      '$limit',
    ].join('|');
    final cached = _questionCache[cacheKey];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.items;
    }

    final offset = int.tryParse(cursor ?? '0') ?? 0;
    try {
      var query = _supabase
          .from('product_questions')
          .select(
            'id, user_id, user_name, product_name, store_name, seller_id, '
            'product_image_url, question, answer, likes, created_at, answered_at',
          )
          .ilike('product_name', productName);
      if (storeName != null && storeName.trim().isNotEmpty) {
        query = query.ilike('store_name', storeName.trim());
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final items = List<Map<String, dynamic>>.from(
        rows as List,
      ).map(_mapQuestionRow).toList(growable: false);
      _questionCache[cacheKey] = _QuestionCacheEntry(
        expiresAt: now.add(_cacheTtl),
        items: items,
      );
      return items;
    } catch (e) {
      debugPrint('ProductQuestionService.getQuestions warn: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllQuestions({
    bool unansweredOnly = false,
    int limit = 50,
    String? cursor,
  }) async {
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    try {
      var query = _supabase
          .from('product_questions')
          .select(
            'id, user_id, user_name, product_name, store_name, seller_id, '
            'product_image_url, question, answer, likes, created_at, answered_at',
          );
      if (unansweredOnly) {
        query = query.or('answer.is.null,answer.eq.');
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map(_mapQuestionRow).toList(growable: false);
    } catch (e) {
      debugPrint('ProductQuestionService.getAllQuestions warn: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSellerQuestions({
    String? sellerId,
    String? storeName,
    bool unansweredOnly = false,
    int limit = 100,
    String? cursor,
  }) async {
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    try {
      var query = _supabase
          .from('product_questions')
          .select(
            'id, user_id, user_name, product_name, store_name, seller_id, '
            'product_image_url, question, answer, likes, created_at, answered_at',
          );
      if (sellerId != null && sellerId.trim().isNotEmpty) {
        query = query.eq('seller_id', sellerId.trim());
      } else if (storeName != null && storeName.trim().isNotEmpty) {
        query = query.ilike('store_name', storeName.trim());
      } else {
        return [];
      }
      if (unansweredOnly) {
        query = query.or('answer.is.null,answer.eq.');
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map(_mapQuestionRow).toList(growable: false);
    } catch (e) {
      debugPrint('ProductQuestionService.getSellerQuestions warn: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createQuestion({
    required String productName,
    required String storeName,
    required String sellerId,
    required String productImageUrl,
    required String question,
    required String userId,
    required String userName,
  }) async {
    final row = await _supabase
        .from('product_questions')
        .insert({
          'product_name': productName,
          'store_name': storeName,
          'seller_id': sellerId,
          'product_image_url': productImageUrl,
          'question': question.trim(),
          'user_id': userId,
          'user_name': userName,
        })
        .select()
        .single();
    _questionCache.clear();

    return _mapQuestionRow(Map<String, dynamic>.from(row));
  }

  Future<void> answerQuestion({
    required String questionId,
    required String answer,
  }) async {
    await _supabase
        .from('product_questions')
        .update({
          'answer': answer.trim(),
          'answered_at': DateTime.now().toIso8601String(),
          'answer_by': _supabase.auth.currentUser?.id,
        })
        .eq('id', questionId);
    _questionCache.clear();
  }

  Map<String, dynamic> _mapQuestionRow(Map<String, dynamic> row) {
    return {
      'id': row['id']?.toString() ?? '',
      'userId': row['user_id']?.toString(),
      'userName': row['user_name']?.toString() ?? 'Kullanıcı',
      'productName': row['product_name']?.toString() ?? '',
      'storeName': row['store_name']?.toString() ?? '',
      'sellerId': row['seller_id']?.toString() ?? '',
      'productImageUrl': row['product_image_url']?.toString() ?? '',
      'question': row['question']?.toString() ?? '',
      'answer': row['answer']?.toString() ?? '',
      'likes': (row['likes'] as num?)?.toInt() ?? 0,
      'createdAt': row['created_at']?.toString(),
      'answeredAt': row['answered_at']?.toString(),
    };
  }
}
