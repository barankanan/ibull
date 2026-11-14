/// Arguments for the live `close_table_with_history` function.
///
/// Production signature, read from `pg_proc`:
/// `close_table_with_history(uuid, integer, text, text, uuid, text, text)`.
/// PostgREST looks up the function by the names in the JSON body. Sending
/// `p_table_name`, `p_display_table_label` or `p_table_area_name` makes it
/// answer `Could not find the function public.close_table_with_history(...)`.
/// Table labels stay on the history fallback write, not on this RPC.
Map<String, dynamic> closeTableWithHistoryRpcParams({
  required String sellerId,
  required int tableNumber,
  required String paymentMethod,
  String? paymentNote,
  String? waiterId,
  String? waiterName,
  String? sessionKey,
}) {
  return <String, dynamic>{
    'p_seller_id': sellerId,
    'p_table_number': tableNumber,
    'p_payment_method': paymentMethod,
    if (paymentNote != null && paymentNote.trim().isNotEmpty)
      'p_payment_note': paymentNote.trim(),
    if (waiterId != null && waiterId.trim().isNotEmpty)
      'p_waiter_id': waiterId.trim(),
    if (waiterName != null && waiterName.trim().isNotEmpty)
      'p_waiter_name': waiterName.trim(),
    if (sessionKey != null && sessionKey.trim().isNotEmpty)
      'p_session_key': sessionKey.trim(),
  };
}

/// History id returned by a committed close. A JSON null must not become
/// the string "null" and must not trigger a second history insert.
String? serverHistoryIdFromCloseResult(Map<String, dynamic> result) {
  final raw = result['history_id'];
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

/// User-facing close failure. The technical PostgREST text stays in the log.
String friendlyTableCloseError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('could not find the function') ||
      lower.contains('pgrst202') ||
      lower.contains('schema cache')) {
    return 'Masa kapatma sunucu fonksiyonu bu uygulama sürümüyle eşleşmiyor. '
        'Masa açık kaldı.';
  }
  if (lower.contains('42501') ||
      lower.contains('yetkiniz yok') ||
      lower.contains('yetkisi yok')) {
    return 'Bu masayı kapatma yetkiniz yok. Masa açık kaldı.';
  }
  if (lower.contains('timeoutexception') || lower.contains('zaman aşımı')) {
    return 'Masa kapatma yanıtı gelmedi. Masa kapanmış sayılmadı.';
  }
  if (lower.contains('23502') ||
      lower.contains('not-null') ||
      lower.contains('null value in column')) {
    return 'Masa geçmiş kaydı yazılamadı (zorunlu sipariş numarası boş). '
        'Masa açık kaldı.';
  }
  return 'Masa kapatılamadı. Masa açık kaldı.';
}

/// User-facing transfer failure. Keeps the server sentence when it is already
/// a short Turkish business error, and always says the orders stayed put.
String friendlyTableTransferError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  final lower = raw.toLowerCase();
  if (lower.contains('42501') ||
      lower.contains('yetkiniz yok') ||
      lower.contains('yetkisi yok')) {
    return 'Masa aktarma yetkiniz yok. Siparişler yerinde kaldı.';
  }
  if (lower.contains('farklı şubede')) {
    return 'Masalar farklı şubede. Aktarma yapılmadı. Siparişler yerinde kaldı.';
  }
  if (lower.contains('parça aktarma')) {
    return 'Parça aktarma bu sipariş kaydında yok. Tam aktarma kullanın. '
        'Siparişler yerinde kaldı.';
  }
  if (lower.contains('aktarılacak sipariş yok') || lower.contains('p0002')) {
    return 'Aktarılacak açık sipariş bulunamadı. Siparişler yerinde kaldı.';
  }
  if (lower.contains('hedef masa') || lower.contains('kaynak masa')) {
    return 'Masa bu işletmede bulunamadı. Siparişler yerinde kaldı.';
  }
  if (lower.contains('timeoutexception') || lower.contains('zaman aşımı')) {
    return 'Masa aktarma yanıtı gelmedi. Siparişler yerinde kaldı.';
  }
  final sentence = raw
      .replaceFirst(RegExp(r'^Masa aktarma yapılamadı:\s*'), '')
      .replaceFirst(RegExp(r'^Bad state:\s*'), '');
  if (sentence.isNotEmpty &&
      sentence.length <= 180 &&
      !lower.contains('postgrest')) {
    if (sentence.toLowerCase().contains('yerinde kaldı')) return sentence;
    return '$sentence Siparişler yerinde kaldı.';
  }
  return 'Masa aktarılamadı. Siparişler yerinde kaldı.';
}
