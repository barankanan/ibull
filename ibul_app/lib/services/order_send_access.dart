import 'dart:math';

/// Stable key for one garson send. A retry of that send reuses the key so
/// the server returns the original orders and print_jobs rows.
String newOrderSendIdempotencyKey() {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final salt = Random().nextInt(0x7fffffff);
  return 'send-$now-$salt';
}

/// RPC arguments for `create_table_order_with_print_jobs`.
///
/// The idempotency argument is omitted when empty so an older 8-argument
/// function still matches.
Map<String, dynamic> buildCreateTableOrderRpcParams({
  required String restaurantId,
  required int tableNumber,
  required List<Map<String, dynamic>> items,
  String? waiterId,
  String? waiterName,
  String? notes,
  String jobType = 'new_order',
  String? idempotencyKey,
}) {
  final key = (idempotencyKey ?? '').trim();
  return <String, dynamic>{
    'p_restaurant_id': restaurantId,
    'p_table_number': tableNumber,
    'p_items': items,
    'p_waiter_id': (waiterId == null || waiterId.isEmpty) ? null : waiterId,
    'p_waiter_name': waiterName,
    'p_notes': notes,
    'p_job_type': jobType,
    'p_order_type': 'table',
    if (key.isNotEmpty) 'p_idempotency_key': key,
  };
}

/// Garson-facing text for `create_table_order_with_print_jobs` failures.
String friendlyOrderSendRpcMessage({
  required String? code,
  required String message,
  String? details,
  String? hint,
}) {
  final combined = '$message ${details ?? ''} ${hint ?? ''}'.toLowerCase();

  if (combined.contains('sipariş gönderme yetkiniz yok')) {
    return 'Sipariş gönderilemedi. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.';
  }

  if (combined.contains(
        'column "table_number" of relation "orders" does not exist',
      ) ||
      (combined.contains('orders') &&
          combined.contains('table_number') &&
          combined.contains('does not exist'))) {
    return 'Mutfak fişi oluşturulamadı. Supabase orders tablosunda table_number kolonu yok '
        'ama mutfak print RPC onu yazmaya çalışıyor. SQL patch uygulanmalı '
        '(create_table_order_with_print_jobs_impl).';
  }

  if (combined.contains('missing from-clause entry for table "v_item"')) {
    return 'Mutfak fişi oluşturulamadı. SQL mutfak payload fonksiyonunda v_item '
        'alias hatası var. (Supabase RPC: create_table_order_with_print_jobs)';
  }

  if (code == '42501' ||
      combined.contains('permission denied') ||
      combined.contains('bu restoran için işlem yetkiniz yok') ||
      combined.contains('row-level security')) {
    return 'Mutfak fişi oluşturulamadı. Garson hesabının bu restoranda aktif '
        'yazdırma yetkisi yok. Supabase tarafında store_sub_admins kaydında '
        'email veya telefon eşleşmesi gerekli.';
  }

  return message;
}
