import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// Stable key for one garson send. A retry of that send reuses the key so
/// the server returns the original orders and print_jobs rows.
String newOrderSendIdempotencyKey() {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final salt = Random().nextInt(0x7fffffff);
  return 'send-$now-$salt';
}

/// Stable identity of one garson send. Trace ids and free-text notes are
/// excluded so a network retry of the same action keeps the same key.
String orderSendActionFingerprint({
  required String restaurantId,
  required int tableNumber,
  required String jobType,
  required List<Map<String, dynamic>> items,
}) {
  final canonical = items
      .map((item) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return <String, dynamic>{for (final key in keys) key: item[key]};
      })
      .toList(growable: false);
  return jsonEncode(<String, dynamic>{
    'restaurantId': restaurantId.trim(),
    'tableNumber': tableNumber,
    'jobType': jobType.trim(),
    'items': canonical,
  });
}

/// Remembers the key for an in-flight action until that action succeeds.
///
/// [restored] reloads keys that survived an app restart. A new requested key
/// does not replace a restored one: the original key must hit the server
/// again so the send is replayed instead of creating a second order.
class OrderSendKeyLedger {
  OrderSendKeyLedger({Map<String, String>? restored})
    : _keys = Map<String, String>.from(restored ?? const <String, String>{});

  final Map<String, String> _keys;
  Future<void> Function(Map<String, String> keys)? sink;

  void restore(Map<String, String> saved) {
    for (final entry in saved.entries) {
      final fingerprint = entry.key.trim();
      final key = entry.value.trim();
      if (fingerprint.isEmpty || key.isEmpty) continue;
      _keys.putIfAbsent(fingerprint, () => key);
    }
  }

  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_keys);

  Future<void> flush() async {
    final sink = this.sink;
    if (sink == null) return;
    await sink(Map<String, String>.from(_keys));
  }

  String keyFor(String fingerprint, {String Function()? mint}) {
    final existing = _keys[fingerprint];
    if (existing != null && existing.isNotEmpty) return existing;
    final minted = (mint ?? newOrderSendIdempotencyKey)();
    _keys[fingerprint] = minted;
    return minted;
  }

  void remember(String fingerprint, String key) {
    final normalized = key.trim();
    if (fingerprint.isEmpty || normalized.isEmpty) return;
    final existing = _keys[fingerprint];
    if (existing != null && existing.isNotEmpty) return;
    _keys[fingerprint] = normalized;
  }

  void complete(String fingerprint) {
    _keys.remove(fingerprint);
  }
}

String resolveOrderSendKey({
  required OrderSendKeyLedger ledger,
  required String fingerprint,
  String? requestedKey,
}) {
  final requested = (requestedKey ?? '').trim();
  if (requested.isNotEmpty) {
    ledger.remember(fingerprint, requested);
  }
  return ledger.keyFor(fingerprint);
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
    // Live create_table_order_with_print_jobs identifies a retry by
    // p_local_order_id. p_idempotency_key is not part of that 9-argument
    // function and makes PostgREST reject the whole send.
    if (key.isNotEmpty) 'p_local_order_id': key,
  };
}

/// One save attempt. A client timeout must not call [send] again.
///
/// The timed-out request is still running on the server. A second insert can
/// commit beside it and open another order plus another kitchen ticket.
/// Recovery only reads the row that the first attempt already committed.
Future<dynamic> recoverOrderSaveAfterTimeout({
  required Future<dynamic> Function() send,
  required Future<Map<String, dynamic>?> Function() lookup,
  Duration timeout = const Duration(seconds: 12),
  int pollAttempts = 4,
  Duration pollInterval = const Duration(milliseconds: 400),
}) async {
  try {
    return await send().timeout(timeout);
  } on TimeoutException {
    final attempts = pollAttempts < 1 ? 1 : pollAttempts;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0 && pollInterval > Duration.zero) {
        await Future<void>.delayed(pollInterval);
      }
      final committed = await lookup();
      if (committed != null) return committed;
    }
    throw StateError(
      'Sipariş sonucu doğrulanamadı. Aynı gönderim anahtarı duruyor.',
    );
  }
}

/// A replay may print only a job that is still pending.
/// Completed, claimed, printing and unknown states stay off the printer.
List<String> printJobIdsSafeForReplay({
  required List<String> printJobIds,
  required Map<String, String> statusById,
  required bool replay,
}) {
  if (!replay) return printJobIds;
  return <String>[
    for (final id in printJobIds)
      if (statusById[id] == 'pending') id,
  ];
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

  if (combined.contains('send_table_order_idempotent') &&
      (combined.contains('could not find') ||
          combined.contains('does not exist') ||
          combined.contains('schema cache') ||
          code == 'PGRST202' ||
          code == '42883')) {
    return 'Sipariş gönderilemedi. Sunucu güncellemesi eksik. '
        'Gönderim durduruldu; ikinci kayıt açılmadı.';
  }

  if (combined.contains('farklı bir siparişle kullanılmış')) {
    return 'Bu gönderim anahtarı başka bir siparişle kullanılmış. '
        'Siparişi yeniden oluşturun.';
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
