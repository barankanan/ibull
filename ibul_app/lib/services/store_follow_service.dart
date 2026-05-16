import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_follow_state.dart';
import '../models/store_user_notification.dart';
import 'push_notification_service.dart';

class StoreFollowException implements Exception {
  StoreFollowException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class StoreFollowService {
  StoreFollowService._();
  static final StoreFollowService instance = StoreFollowService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  static String userFriendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('not_authenticated')) {
      return 'Bu işlem için giriş yapmalısınız.';
    }
    if (raw.contains('not_following')) {
      return 'Bildirimleri açmak için önce mağazayı takip etmelisin.';
    }
    if (raw.contains('store_not_found')) {
      return 'Mağaza bulunamadı.';
    }
    if (raw.contains('SocketException') || raw.contains('network')) {
      return 'Bağlantı sorunu oluştu. Lütfen tekrar deneyin.';
    }
    return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
  }

  Future<StoreFollowState> getStoreFollowState(String storeId) async {
    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty) {
      return const StoreFollowState(error: 'Mağaza bulunamadı.');
    }

    try {
      final response = await _supabase.rpc(
        'get_store_follow_state',
        params: {'p_store_id': normalizedStoreId},
      );
      if (response is Map) {
        return StoreFollowState.fromJson(Map<String, dynamic>.from(response));
      }
      return const StoreFollowState();
    } catch (error) {
      debugPrint('StoreFollowService.getStoreFollowState: $error');
      return StoreFollowState(error: userFriendlyError(error));
    }
  }

  Future<StoreFollowState> followStore(String storeId) async {
    return _mutateStoreFollow(
      storeId: storeId,
      rpcName: 'follow_store',
      params: {'p_store_id': storeId.trim()},
    );
  }

  Future<StoreFollowState> unfollowStore(String storeId) async {
    return _mutateStoreFollow(
      storeId: storeId,
      rpcName: 'unfollow_store',
      params: {'p_store_id': storeId.trim()},
    );
  }

  Future<StoreFollowState> _mutateStoreFollow({
    required String storeId,
    required String rpcName,
    required Map<String, dynamic> params,
  }) async {
    if (currentUserId == null) {
      throw StoreFollowException(
        'Bu işlem için giriş yapmalısınız.',
        code: 'not_authenticated',
      );
    }

    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty) {
      throw StoreFollowException('Mağaza bulunamadı.');
    }

    try {
      final response = await _supabase.rpc(rpcName, params: params);
      if (response is Map) {
        return StoreFollowState.fromJson(Map<String, dynamic>.from(response));
      }
      return await getStoreFollowState(normalizedStoreId);
    } catch (error) {
      debugPrint('StoreFollowService.$rpcName: $error');
      throw StoreFollowException(userFriendlyError(error));
    }
  }

  Future<bool> toggleStoreNotifications(
    String storeId, {
    required bool enabled,
  }) async {
    if (currentUserId == null) {
      throw StoreFollowException(
        'Bu işlem için giriş yapmalısınız.',
        code: 'not_authenticated',
      );
    }

    String? fcmToken;
    if (enabled) {
      fcmToken = await PushNotificationService.instance.getFcmTokenSafely();
    }

    try {
      final response = await _supabase.rpc(
        'toggle_store_notifications',
        params: {
          'p_store_id': storeId.trim(),
          'p_enabled': enabled,
          'p_fcm_token': fcmToken,
        },
      );
      if (response is Map) {
        return response['enabled'] == true;
      }
      return enabled;
    } catch (error) {
      debugPrint('StoreFollowService.toggleStoreNotifications: $error');
      throw StoreFollowException(userFriendlyError(error));
    }
  }

  Future<List<StoreUserNotification>> fetchStoreNotifications(
    String storeId,
  ) async {
    final userId = currentUserId;
    if (userId == null) return const [];

    try {
      final rows = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .eq('store_id', storeId.trim())
          .order('created_at', ascending: false)
          .limit(80);

      return List<Map<String, dynamic>>.from(rows as List)
          .map(StoreUserNotification.fromJson)
          .toList(growable: false);
    } catch (error) {
      debugPrint('StoreFollowService.fetchStoreNotifications: $error');
      return const [];
    }
  }

  Future<int> unreadStoreNotificationCount(String storeId) async {
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final rows = await _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('store_id', storeId.trim())
          .eq('is_read', false);
      return List.from(rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final userId = currentUserId;
    if (userId == null || notificationId.trim().isEmpty) return;

    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true})
          .eq('id', notificationId.trim())
          .eq('user_id', userId);
    } catch (error) {
      debugPrint('StoreFollowService.markNotificationAsRead: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowedStores() async {
    final userId = currentUserId;
    if (userId == null) return const [];

    try {
      final followRows = await _supabase
          .from('store_followers')
          .select('store_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final follows = List<Map<String, dynamic>>.from(followRows as List);
      if (follows.isEmpty) return const [];

      final storeIds = follows
          .map((row) => row['store_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final storeRows = await _supabase
          .from('stores')
          .select(
            'seller_id, business_name, category, logo_url, rating, follower_count',
          )
          .inFilter('seller_id', storeIds);

      final storesById = {
        for (final row in List<Map<String, dynamic>>.from(storeRows as List))
          row['seller_id']?.toString() ?? '': row,
      };

      return follows.map((follow) {
        final storeId = follow['store_id']?.toString() ?? '';
        final store = storesById[storeId] ?? const <String, dynamic>{};
        final businessName = store['business_name']?.toString() ?? 'Mağaza';
        return {
          'id': storeId,
          'seller_id': storeId,
          'name': businessName,
          'category': store['category']?.toString() ?? '',
          'logo': businessName.isNotEmpty ? businessName[0] : 'M',
          'logo_url': store['logo_url'],
          'rating': (store['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
          'followers': StoreFollowState(
            followerCount: (store['follower_count'] as num?)?.toInt() ?? 0,
          ).formattedFollowerCount,
          'distance': '-',
        };
      }).toList(growable: false);
    } catch (error) {
      debugPrint('StoreFollowService.fetchFollowedStores: $error');
      return const [];
    }
  }

  Future<Set<String>> fetchFollowedStoreIds() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      final rows = await _supabase
          .from('store_followers')
          .select('store_id')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(rows as List)
          .map((row) => row['store_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('StoreFollowService.fetchFollowedStoreIds: $error');
      return {};
    }
  }

  Future<String?> resolveStoreId({
    String? sellerId,
    String? businessName,
  }) async {
    final normalizedSellerId = sellerId?.trim() ?? '';
    if (_looksLikeUuid(normalizedSellerId)) {
      return normalizedSellerId;
    }

    final name = businessName?.trim() ?? '';
    if (name.isEmpty) return null;

    try {
      final rows = await _supabase
          .from('stores')
          .select('seller_id')
          .ilike('business_name', name)
          .limit(1);
      final parsed = List<Map<String, dynamic>>.from(rows as List);
      if (parsed.isNotEmpty) {
        return parsed.first['seller_id']?.toString();
      }
    } catch (error) {
      debugPrint('StoreFollowService.resolveStoreId: $error');
    }
    return null;
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }
}
