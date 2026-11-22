/// Kuryeye gösterilecek teslimat senkron hata metinleri.
///
/// Ham Supabase/PostgREST hatası (tablo adı, RLS policy, satır içeriği)
/// kuryeye gösterilmez; teknik ayrıntı yalnızca `debugPrint` loglarında kalır.
/// Destek için yalnızca varsa kısa SQLSTATE kodu eklenir.
library;

/// Sipariş kimliği eksikken `_lastDeliverySyncError` içine yazılan işaret.
const String ihizMissingOrderIdSyncError = 'missing_order_id';

/// Paket teslim alınmak istenirken artık havuzda olmadığında (başka kurye
/// aldı veya sipariş durumu değişti) `_lastDeliverySyncError` içine yazılan
/// işaret.
const String ihizPickupNoLongerAvailableSyncError =
    'pickup_no_longer_available';

/// Teslim edilmek istenen sipariş sunucuda iptal/iade edilmiş olduğunda
/// `_lastDeliverySyncError` içine yazılan işaret.
const String ihizDeliveryOrderClosedSyncError = 'delivery_order_closed';

final RegExp _codePattern = RegExp(r'code=([A-Za-z0-9]{1,10})');

/// [rawError]: `_compactSupabaseError` çıktısı veya dahili işaret değeri.
String ihizCourierSyncFailureHint(String? rawError) {
  final raw = (rawError ?? '').trim();
  if (raw.isEmpty || raw == 'unknown_delivery_error') {
    return 'Bağlantınızı kontrol edip tekrar deneyin. '
        'Sorun sürerse destekle iletişime geçin.';
  }
  if (raw == ihizMissingOrderIdSyncError) {
    return 'Sipariş bilgisi eksik. Görev listesini yenileyip tekrar deneyin.';
  }
  if (raw == ihizPickupNoLongerAvailableSyncError) {
    return 'Bu paket başka bir kurye tarafından alınmış veya sipariş durumu '
        'değişmiş olabilir.';
  }
  if (raw == ihizDeliveryOrderClosedSyncError) {
    return 'Bu sipariş iptal edilmiş veya iade sürecine alınmış. '
        'Paket için destekle iletişime geçin.';
  }

  final normalized = raw.toLowerCase();
  final code = _codePattern.firstMatch(raw)?.group(1);
  final codeSuffix = code == null ? '' : ' (Hata kodu: $code)';

  if (normalized.contains('row-level security') ||
      normalized.contains('permission') ||
      normalized.contains('policy') ||
      normalized.contains('jwt') ||
      code == '42501') {
    return 'Bu işlem için kurye hesabınızın yetkisi yok. '
        'Destekle iletişime geçin.$codeSuffix';
  }
  if (normalized.contains('failed host lookup') ||
      normalized.contains('socket') ||
      normalized.contains('network') ||
      normalized.contains('timeout') ||
      normalized.contains('failed to fetch') ||
      normalized.contains('xmlhttprequest') ||
      normalized.contains('connection')) {
    return 'Sunucuya bağlanılamadı. '
        'İnternet bağlantınızı kontrol edip tekrar deneyin.';
  }
  return 'Beklenmeyen bir hata oluştu. Tekrar deneyin; '
      'sorun sürerse destekle iletişime geçin.$codeSuffix';
}
