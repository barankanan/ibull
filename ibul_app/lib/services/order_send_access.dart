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
