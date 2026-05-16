import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Satıcı olaylarında takipçilere in-app bildirim üretir (RPC).
class StoreNotificationTriggerService {
  StoreNotificationTriggerService._();
  static final StoreNotificationTriggerService instance =
      StoreNotificationTriggerService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> notifyNewProduct({
    required String storeId,
    required String storeName,
    required String productName,
    required String productId,
  }) async {
    await _create(
      storeId: storeId,
      type: 'new_product',
      title: '$storeName yeni bir ürün ekledi',
      body: productName,
      productId: productId,
    );
  }

  Future<void> notifyProductDiscount({
    required String storeId,
    required String storeName,
    required String productName,
    required String productId,
  }) async {
    await _create(
      storeId: storeId,
      type: 'product_discount',
      title: 'Takip ettiğin mağazada indirim başladı',
      body: '$storeName — $productName',
      productId: productId,
    );
  }

  Future<void> notifyStoreAnnouncement({
    required String storeId,
    required String storeName,
    String? announcementId,
  }) async {
    await _create(
      storeId: storeId,
      type: 'store_announcement',
      title: '$storeName yeni bir duyuru yayınladı',
      body: 'Mağaza duyurularını inceleyebilirsin.',
      announcementId: announcementId,
    );
  }

  Future<void> _create({
    required String storeId,
    required String type,
    required String title,
    required String body,
    String? productId,
    String? announcementId,
  }) async {
    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty) return;

    try {
      await _supabase.rpc(
        'create_store_notification',
        params: {
          'p_store_id': normalizedStoreId,
          'p_title': title,
          'p_body': body,
          'p_type': type,
          'p_product_id': productId,
          'p_announcement_id': announcementId,
        },
      );
    } catch (error) {
      debugPrint('StoreNotificationTriggerService: $error');
    }
  }
}
