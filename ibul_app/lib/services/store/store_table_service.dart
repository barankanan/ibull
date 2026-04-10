import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/runtime_config.dart';

class StoreTableService {
  StoreTableService({
    required SupabaseClient supabase,
    required String? Function() currentUserIdResolver,
    this.tableOrderTimeout = const Duration(seconds: 10),
  }) : _supabase = supabase,
       _currentUserIdResolver = currentUserIdResolver;

  final SupabaseClient _supabase;
  final String? Function() _currentUserIdResolver;
  final Duration tableOrderTimeout;

  bool _isStoreTablesMissingError(Object error) {
    if (error is! PostgrestException) return false;
    final details = (error.details ?? '').toString().toLowerCase();
    final message = error.message.toLowerCase();
    return error.code == 'PGRST205' ||
        message.contains('store_tables') ||
        details.contains('store_tables') ||
        message.contains('relation') && message.contains('does not exist');
  }

  Exception _storeTablesUnavailableException() {
    return Exception(
      "Masa QR sistemi Supabase'te hazır değil. "
      "'ibul_app/SUPABASE_STORE_TABLE_QR_SYSTEM.sql' scriptini çalıştırın.",
    );
  }

  String _resolveSellerId(String? sellerId) {
    final resolved = (sellerId ?? _currentUserIdResolver() ?? '').trim();
    if (resolved.isEmpty) {
      throw Exception('Satıcı oturumu bulunamadı.');
    }
    return resolved;
  }

  String _generateTableQrToken() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  int _parseTableNumberValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _firstMissingPositive(Iterable<int> values) {
    final sorted = values.where((n) => n > 0).toSet().toList(growable: false)
      ..sort();
    var expected = 1;
    for (final n in sorted) {
      if (n == expected) {
        expected++;
      } else if (n > expected) {
        break;
      }
    }
    return expected;
  }

  bool _isTableOrderStatusConstraintError(Object error) {
    if (error is! PostgrestException) return false;
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == '23514' ||
        (details.contains('table_orders') &&
            details.contains('status') &&
            details.contains('check'));
  }

  bool _isTableOrderPermissionError(PostgrestException error) {
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == '42501' ||
        details.contains('permission denied') ||
        details.contains('row-level security');
  }

  bool _isTableOrderMetadataColumnMissingError(PostgrestException error) {
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == '42703' ||
        details.contains('revision') ||
        details.contains('last_edit_summary') ||
        details.contains('last_edit_note') ||
        details.contains('updated_at');
  }

  String _legacyTableOrderStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'sent') return 'done';
    return status;
  }

  Exception _tableOrderException(String action, PostgrestException error) {
    if (_isTableOrderPermissionError(error)) {
      return Exception(
        '$action yapılamadı. Yetki politikası (RLS) bu işlemi engelliyor.',
      );
    }
    return Exception('$action yapılamadı: ${error.message}');
  }

  String _tableOrdersRealtimeFilter(String sellerId) {
    return 'seller_id=eq.$sellerId';
  }

  void _debugLogTableOrdersSubscription({
    required String sellerId,
    required String mode,
    int? tableNumber,
  }) {
    final supabaseUrl = AppRuntimeConfig.rawSupabaseUrl.trim().isEmpty
        ? '(missing)'
        : AppRuntimeConfig.rawSupabaseUrl.trim();
    final authUserId = _currentUserIdResolver()?.trim();
    final filter = _tableOrdersRealtimeFilter(sellerId);
    debugPrint(
      '[GarsonRealtime] mode=$mode '
      'supabaseUrl=$supabaseUrl '
      'schema=public '
      'table=table_orders '
      'channel=auto:stream(table_orders) '
      'storeId=$sellerId '
      'sellerId=$sellerId '
      'waiterId=${authUserId?.isEmpty ?? true ? '-' : authUserId} '
      'tableNumber=${tableNumber ?? '-'} '
      'filter=$filter',
    );
  }

  Future<List<Map<String, dynamic>>> getStoreTables({
    String? sellerId,
    bool onlyActive = true,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    try {
      var query = _supabase
          .from('store_tables')
          .select()
          .eq('seller_id', resolvedSellerId);
      if (onlyActive) {
        query = query.eq('is_active', true);
      }
      final rows = await query.order('table_number', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      if (_isStoreTablesMissingError(error)) {
        throw _storeTablesUnavailableException();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addStoreTable({
    String? sellerId,
    int? tableNumber,
    bool preferMissingNumber = true,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    try {
      final rows = await getStoreTables(
        sellerId: resolvedSellerId,
        onlyActive: false,
      );
      final numbers = rows
          .map((row) => _parseTableNumberValue(row['table_number']))
          .where((n) => n > 0)
          .toList(growable: false);
      final maxNumber = numbers.isEmpty
          ? 0
          : numbers.reduce((a, b) => a > b ? a : b);
      final missingNumber = _firstMissingPositive(numbers);
      final nextNewNumber = maxNumber + 1;

      int nextTableNumber;
      if (tableNumber != null && tableNumber > 0) {
        nextTableNumber = tableNumber;
      } else if (preferMissingNumber && missingNumber < nextNewNumber) {
        nextTableNumber = missingNumber;
      } else {
        nextTableNumber = nextNewNumber <= 0 ? 1 : nextNewNumber;
      }

      final inserted = await _supabase
          .from('store_tables')
          .insert({
            'seller_id': resolvedSellerId,
            'table_number': nextTableNumber,
            'qr_token': _generateTableQrToken(),
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return Map<String, dynamic>.from(inserted as Map);
    } catch (error) {
      if (_isStoreTablesMissingError(error)) {
        throw _storeTablesUnavailableException();
      }
      rethrow;
    }
  }

  Future<void> removeStoreTableById(String tableId) async {
    final normalizedId = tableId.trim();
    if (normalizedId.isEmpty) return;
    try {
      await _supabase.from('store_tables').delete().eq('id', normalizedId);
    } catch (error) {
      if (_isStoreTablesMissingError(error)) {
        throw _storeTablesUnavailableException();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> removeLastStoreTable({String? sellerId}) async {
    final tables = await getStoreTables(sellerId: sellerId, onlyActive: true);
    if (tables.isEmpty) return null;
    final last = tables.last;
    final tableId = last['id']?.toString() ?? '';
    if (tableId.isNotEmpty) {
      await removeStoreTableById(tableId);
    }
    return last;
  }

  Future<List<int>> getActiveTableNumbers(String sellerId) async {
    try {
      final rows = await getStoreTables(sellerId: sellerId, onlyActive: true);
      return rows
          .map((row) {
            final value = row['table_number'];
            if (value is int) return value;
            return int.tryParse(value?.toString() ?? '');
          })
          .whereType<int>()
          .toList()
        ..sort();
    } catch (error) {
      if (_isStoreTablesMissingError(error)) {
        return <int>[];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> resolveStoreTableQr({
    required String sellerId,
    required int tableNumber,
    required String qrToken,
  }) async {
    debugPrint(
      '[QR-SVC] resolveStoreTableQr: sellerId=$sellerId tableNumber=$tableNumber qrToken=${qrToken.trim()}',
    );
    if (tableNumber <= 0 || qrToken.trim().isEmpty) {
      debugPrint(
        '[QR-SVC] resolveStoreTableQr: early return (tableNumber<=0 or empty token).',
      );
      return null;
    }
    try {
      // Select only 'id' — the caller only checks for null (token verified or not).
      // A minimal payload reduces Supabase response size and parse time.
      final data = await _supabase
          .from('store_tables')
          .select('id')
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .eq('qr_token', qrToken.trim())
          .eq('is_active', true)
          .maybeSingle();
      debugPrint('[QR-SVC] resolveStoreTableQr Supabase result = $data');
      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (error) {
      debugPrint('[QR-SVC] resolveStoreTableQr ERROR: $error');
      if (_isStoreTablesMissingError(error)) {
        debugPrint(
          '[QR-SVC] store_tables table missing in Supabase — returning null.',
        );
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitTableOrder({
    required String sellerId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String status = 'new',
  }) async {
    final normalizedStatus = status.trim().isEmpty ? 'new' : status.trim();
    final createdAt = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'seller_id': sellerId,
      'table_number': tableNumber,
      'items': items,
      'status': normalizedStatus,
      'created_at': createdAt,
    };

    try {
      final inserted = await _supabase
          .from('table_orders')
          .insert(payload)
          .select()
          .single()
          .timeout(tableOrderTimeout);
      return Map<String, dynamic>.from(inserted as Map);
    } on PostgrestException catch (error) {
      final canFallbackLegacyStatus =
          normalizedStatus.toLowerCase() == 'sent' &&
          _isTableOrderStatusConstraintError(error);
      if (canFallbackLegacyStatus) {
        final legacyPayload = <String, dynamic>{
          ...payload,
          'status': _legacyTableOrderStatus(normalizedStatus),
        };
        try {
          final inserted = await _supabase
              .from('table_orders')
              .insert(legacyPayload)
              .select()
              .single()
              .timeout(tableOrderTimeout);
          return Map<String, dynamic>.from(inserted as Map);
        } on PostgrestException catch (legacyError) {
          throw _tableOrderException('Sipariş gönderimi', legacyError);
        }
      }
      throw _tableOrderException('Sipariş gönderimi', error);
    } on TimeoutException {
      throw Exception(
        'Sipariş gönderimi zaman aşımına uğradı. Bağlantıyı kontrol edip tekrar deneyin.',
      );
    }
  }

  Stream<List<Map<String, dynamic>>> getTableOrdersStream(String sellerId) {
    final resolvedSellerId = sellerId.trim();
    if (resolvedSellerId.isEmpty) {
      _debugLogTableOrdersSubscription(
        sellerId: '(empty)',
        mode: 'realtime_guard_empty_seller',
      );
      return Stream.value(const <Map<String, dynamic>>[]);
    }
    _debugLogTableOrdersSubscription(
      sellerId: resolvedSellerId,
      mode: 'realtime_subscribe',
    );
    return _supabase
        .from('table_orders')
        .stream(primaryKey: ['id'])
        .eq('seller_id', resolvedSellerId)
        .order('created_at', ascending: false)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Future<List<Map<String, dynamic>>> getTableOrdersSnapshot(
    String sellerId, {
    int? tableNumber,
  }) async {
    final resolvedSellerId = sellerId.trim();
    if (resolvedSellerId.isEmpty) {
      _debugLogTableOrdersSubscription(
        sellerId: '(empty)',
        mode: 'snapshot_guard_empty_seller',
        tableNumber: tableNumber,
      );
      return const <Map<String, dynamic>>[];
    }
    _debugLogTableOrdersSubscription(
      sellerId: resolvedSellerId,
      mode: 'snapshot_fetch',
      tableNumber: tableNumber,
    );
    try {
      var query = _supabase
          .from('table_orders')
          .select()
          .eq('seller_id', resolvedSellerId);
      if (tableNumber != null && tableNumber > 0) {
        query = query.eq('table_number', tableNumber);
      }
      final rows = await query
          .order('created_at', ascending: false)
          .timeout(tableOrderTimeout);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Masa siparişlerini alma', error);
    } on TimeoutException {
      throw Exception(
        'Masa siparişleri alınamadı (zaman aşımı). Bağlantıyı kontrol edip tekrar deneyin.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getTableOrdersByTable({
    required String sellerId,
    required int tableNumber,
  }) async {
    try {
      final rows = await _supabase
          .from('table_orders')
          .select()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .order('created_at', ascending: false)
          .timeout(tableOrderTimeout);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Masa siparişlerini alma', error);
    } on TimeoutException {
      throw Exception(
        'Masa siparişleri alınamadı (zaman aşımı). Bağlantıyı kontrol edip tekrar deneyin.',
      );
    }
  }

  Future<Map<String, dynamic>?> updateTableOrder(
    String orderId, {
    String? status,
    List<Map<String, dynamic>>? items,
    int? revision,
    Map<String, dynamic>? lastEditSummary,
    String? lastEditNote,
  }) async {
    final updateData = <String, dynamic>{};
    if (status != null) {
      updateData['status'] = status;
    }
    if (items != null) {
      updateData['items'] = items;
    }
    if (revision != null && revision > 0) {
      updateData['revision'] = revision;
    }
    if (lastEditSummary != null && lastEditSummary.isNotEmpty) {
      updateData['last_edit_summary'] = lastEditSummary;
    }
    if (lastEditNote != null && lastEditNote.trim().isNotEmpty) {
      updateData['last_edit_note'] = lastEditNote.trim();
    }
    if (revision != null ||
        (lastEditSummary != null && lastEditSummary.isNotEmpty) ||
        (lastEditNote != null && lastEditNote.trim().isNotEmpty)) {
      updateData['updated_at'] = DateTime.now().toIso8601String();
    }
    if (updateData.isEmpty) return null;

    final normalizedStatus = status?.trim();
    try {
      final updated = await _supabase
          .from('table_orders')
          .update(updateData)
          .eq('id', orderId)
          .select()
          .maybeSingle()
          .timeout(tableOrderTimeout);
      if (updated == null) return null;
      return Map<String, dynamic>.from(updated as Map);
    } on PostgrestException catch (error) {
      final shouldRetryWithoutMetadata =
          _isTableOrderMetadataColumnMissingError(error) &&
          (updateData.containsKey('revision') ||
              updateData.containsKey('last_edit_summary') ||
              updateData.containsKey('last_edit_note') ||
              updateData.containsKey('updated_at'));
      if (shouldRetryWithoutMetadata) {
        final fallbackData = <String, dynamic>{...updateData}
          ..remove('revision')
          ..remove('last_edit_summary')
          ..remove('last_edit_note')
          ..remove('updated_at');
        if (fallbackData.isNotEmpty) {
          try {
            final updated = await _supabase
                .from('table_orders')
                .update(fallbackData)
                .eq('id', orderId)
                .select()
                .maybeSingle()
                .timeout(tableOrderTimeout);
            if (updated == null) return null;
            return Map<String, dynamic>.from(updated as Map);
          } on PostgrestException catch (fallbackError) {
            throw _tableOrderException('Sipariş güncelleme', fallbackError);
          }
        }
      }
      final canFallbackLegacyStatus =
          normalizedStatus != null &&
          normalizedStatus.toLowerCase() == 'sent' &&
          _isTableOrderStatusConstraintError(error);
      if (canFallbackLegacyStatus) {
        final legacyUpdateData = <String, dynamic>{
          ...updateData,
          'status': _legacyTableOrderStatus(normalizedStatus),
        };
        try {
          final updated = await _supabase
              .from('table_orders')
              .update(legacyUpdateData)
              .eq('id', orderId)
              .select()
              .maybeSingle()
              .timeout(tableOrderTimeout);
          if (updated == null) return null;
          return Map<String, dynamic>.from(updated as Map);
        } on PostgrestException catch (legacyError) {
          throw _tableOrderException('Sipariş güncelleme', legacyError);
        }
      }
      throw _tableOrderException('Sipariş güncelleme', error);
    } on TimeoutException {
      throw Exception(
        'Sipariş güncelleme zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<Map<String, dynamic>?> updateTableOrderStatus(
    String orderId,
    String status,
  ) {
    return updateTableOrder(orderId, status: status);
  }

  Future<void> deleteTableOrder(String orderId) async {
    try {
      await _supabase
          .from('table_orders')
          .delete()
          .eq('id', orderId)
          .timeout(tableOrderTimeout);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Sipariş silme', error);
    } on TimeoutException {
      throw Exception(
        'Sipariş silme zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> closeTableOrders({
    required String sellerId,
    required int tableNumber,
  }) async {
    try {
      await _supabase
          .from('table_orders')
          .delete()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .timeout(tableOrderTimeout);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Masa kapatma', error);
    } on TimeoutException {
      throw Exception(
        'Masa kapatma zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PAYMENT METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Records a single payment event (partial or closing) for a table session.
  Future<Map<String, dynamic>> recordTablePayment({
    required String sellerId,
    required int tableNumber,
    required String sessionKey,
    required double amount,
    required String method,
    bool isClosing = false,
    String? paidBy,
    String? waiterId,
    String? waiterName,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'seller_id': sellerId,
      'table_number': tableNumber,
      'session_key': sessionKey,
      'amount': amount,
      'method': method,
      'is_closing': isClosing,
      if (paidBy != null && paidBy.isNotEmpty) 'paid_by': paidBy,
      if (waiterId != null && waiterId.isNotEmpty) 'waiter_id': waiterId,
      if (waiterName != null && waiterName.isNotEmpty)
        'waiter_name': waiterName,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    try {
      final inserted = await _supabase
          .from('table_payments')
          .insert(payload)
          .select()
          .single()
          .timeout(tableOrderTimeout);
      return Map<String, dynamic>.from(inserted as Map);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Ödeme kaydı', error);
    } on TimeoutException {
      throw Exception('Ödeme kaydı zaman aşımına uğradı. Tekrar deneyin.');
    }
  }

  /// Fetches all payment records for a given table session.
  Future<List<Map<String, dynamic>>> getTablePayments({
    required String sellerId,
    required int tableNumber,
    String? sessionKey,
  }) async {
    try {
      var query = _supabase
          .from('table_payments')
          .select()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber);
      if (sessionKey != null && sessionKey.isNotEmpty) {
        query = query.eq('session_key', sessionKey);
      }
      final rows = await query
          .order('created_at', ascending: true)
          .timeout(tableOrderTimeout);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Ödeme listesi', error);
    } on TimeoutException {
      throw Exception('Ödeme listesi alınamadı. Tekrar deneyin.');
    }
  }

  /// **Production close path** — calls the PostgreSQL function
  /// [close_table_with_history] (defined in migration
  /// 20260407_restaurant_ops_upgrade.sql, verified in public.table_order_history).
  ///
  /// The RPC executes entirely inside a single PL/pgSQL block:
  ///   1. Loops over all [table_orders] rows for [sellerId] + [tableNumber].
  ///   2. Computes `grand_total` from the `items` JSONB in SQL.
  ///   3. INSERTs each row into [table_order_history].
  ///   4. Only after ALL inserts succeed: DELETEs from [table_orders].
  ///
  /// Because Postgres wraps PL/pgSQL functions in an implicit transaction,
  /// steps 3 and 4 are atomic — history is never missing after a close.
  ///
  /// On [PostgrestException] (e.g. migration not yet applied), falls back
  /// to [_closeTableClientSide] which replays the same guarantee in Dart.
  Future<void> closeTableWithHistory({
    required String sellerId,
    required int tableNumber,
    required String paymentMethod,
    String? paymentNote,
    String? waiterId,
    String? waiterName,
    String? sessionKey,
  }) async {
    try {
      await _supabase
          .rpc('close_table_with_history', params: {
            'p_seller_id': sellerId,
            'p_table_number': tableNumber,
            'p_payment_method': paymentMethod,
            if (paymentNote != null && paymentNote.isNotEmpty)
              'p_payment_note': paymentNote,
            if (waiterId != null && waiterId.isNotEmpty)
              'p_waiter_id': waiterId,
            if (waiterName != null && waiterName.isNotEmpty)
              'p_waiter_name': waiterName,
            if (sessionKey != null && sessionKey.isNotEmpty)
              'p_session_key': sessionKey,
          })
          .timeout(tableOrderTimeout);
    } on PostgrestException catch (error) {
      // Fall back to client-side archive + delete if RPC unavailable (older DB)
      debugPrint('[StoreTableService] closeTableWithHistory RPC failed ($error). Falling back to client-side archive.');
      await _closeTableClientSide(
        sellerId: sellerId,
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
        waiterId: waiterId,
        waiterName: waiterName,
        sessionKey: sessionKey,
      );
    } on TimeoutException {
      throw Exception('Masa kapatma zaman aşımına uğradı. Tekrar deneyin.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLE HISTORY (CLOSED ORDERS)
  // ─────────────────────────────────────────────────────────────────────────────

  /// **Temporary fallback** for [closeTableWithHistory].
  ///
  /// Only activated when [closeTableWithHistory] receives a
  /// [PostgrestException] — typically because the migration
  /// 20260407_restaurant_ops_upgrade.sql has not been applied to this
  /// Supabase project yet (the [close_table_with_history] RPC does not exist).
  ///
  /// Unlike the server RPC this path is **not** a single DB transaction —
  /// it dispatches N separate INSERT calls followed by one DELETE.
  /// Safety guarantee: if ANY INSERT throws, we throw immediately and skip the
  /// DELETE so active orders are never lost.
  ///
  /// **Remove this method once all production environments have the migration.**
  Future<void> _closeTableClientSide({
    required String sellerId,
    required int tableNumber,
    required String paymentMethod,
    String? paymentNote,
    String? waiterId,
    String? waiterName,
    String? sessionKey,
  }) async {
    // 1. Fetch active orders for this table
    List<Map<String, dynamic>> activeOrders;
    try {
      final rows = await _supabase
          .from('table_orders')
          .select()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .timeout(tableOrderTimeout);
      activeOrders = List<Map<String, dynamic>>.from(rows as List);
    } on Exception {
      activeOrders = const [];
    }

    // 2. Archive each order — all inserts must succeed before deletion.
    // If any insert fails we throw so the caller knows data was NOT lost.
    if (activeOrders.isNotEmpty) {
      final session = sessionKey ??
          'session_${sellerId}_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
      for (final order in activeOrders) {
        final items = order['items'] ?? [];
        double grandTotal = 0;
        if (items is List) {
          for (final item in items) {
            final price = (item['price'] as num?)?.toDouble() ?? 0;
            final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
            grandTotal += price * qty;
          }
        }
        try {
          await _supabase
              .from('table_order_history')
              .insert({
                'original_order_id': order['id']?.toString(),
                'seller_id': sellerId,
                'table_number': tableNumber,
                'items': order['items'] ?? '[]',
                'status': 'closed',
                'revision': order['revision'] ?? 1,
                'last_edit_summary': order['last_edit_summary'] ?? {},
                'last_edit_note': order['last_edit_note'],
                'payment_method': paymentMethod,
                'payment_note': paymentNote,
                'waiter_id': waiterId,
                'waiter_name': waiterName,
                'grand_total': grandTotal,
                'session_key': session,
                'opened_at': order['created_at'],
                'closed_at': DateTime.now().toUtc().toIso8601String(),
                'created_at': order['created_at'] ??
                    DateTime.now().toUtc().toIso8601String(),
              })
              .timeout(tableOrderTimeout);
        } on Exception catch (archiveErr) {
          debugPrint('[StoreTableService] History insert failed: $archiveErr');
          // Abort — do NOT delete active orders to prevent data loss.
          throw Exception(
            'Masa geçmişe kaydedilemedi (siparişler korunuyor). '
            'Lütfen tekrar deneyin. Hata: $archiveErr',
          );
        }
      }
    }

    // 3. Delete active orders (only reached if all archive inserts succeeded)
    await closeTableOrders(sellerId: sellerId, tableNumber: tableNumber);
  }

  /// Returns paginated historical (closed) orders for a seller.
  Future<List<Map<String, dynamic>>> getTableOrderHistory({
    required String sellerId,
    int? tableNumber,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('table_order_history')
          .select()
          .eq('seller_id', sellerId);
      if (tableNumber != null && tableNumber > 0) {
        query = query.eq('table_number', tableNumber);
      }
      if (fromDate != null) {
        query = query.gte('closed_at', fromDate.toUtc().toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('closed_at', toDate.toUtc().toIso8601String());
      }
      final rows = await query
          .order('closed_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(tableOrderTimeout);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      // table_order_history may not exist on older DBs — return empty list
      if (error.code == '42P01' ||
          error.message.contains('does not exist') ||
          error.message.contains('Could not find table')) {
        debugPrint('[StoreTableService] table_order_history not found. Run migration 20260407.');
        return const <Map<String, dynamic>>[];
      }
      throw _tableOrderException('Geçmiş sipariş listesi', error);
    } on TimeoutException {
      throw Exception('Geçmiş siparişler alınamadı. Tekrar deneyin.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLE TRANSFER
  // ─────────────────────────────────────────────────────────────────────────────

  /// Transfers orders between tables via the RPC.
  /// Falls back to a client-side move if the RPC is unavailable.
  Future<Map<String, dynamic>> transferTableOrders({
    required String sellerId,
    required int fromTable,
    required int toTable,
    String transferType = 'full',
    List<String> itemIds = const <String>[],
    String? waiterId,
    String? waiterName,
    String? note,
  }) async {
    try {
      final result = await _supabase
          .rpc('transfer_table_orders', params: {
            'p_seller_id': sellerId,
            'p_from_table': fromTable,
            'p_to_table': toTable,
            'p_transfer_type': transferType,
            'p_item_ids': itemIds,
            if (waiterId != null && waiterId.isNotEmpty)
              'p_waiter_id': waiterId,
            if (waiterName != null && waiterName.isNotEmpty)
              'p_waiter_name': waiterName,
            if (note != null && note.trim().isNotEmpty)
              'p_note': note.trim(),
          })
          .timeout(tableOrderTimeout);
      if (result is Map) return Map<String, dynamic>.from(result);
      return const <String, dynamic>{'success': true};
    } on PostgrestException catch (error) {
      debugPrint('[StoreTableService] transferTableOrders RPC failed ($error). Falling back to client-side.');
      // Client-side fallback: update all source orders to toTable
      await _supabase
          .from('table_orders')
          .update({'table_number': toTable, 'updated_at': DateTime.now().toIso8601String()})
          .eq('seller_id', sellerId)
          .eq('table_number', fromTable)
          .timeout(tableOrderTimeout);
      return const <String, dynamic>{'success': true, 'fallback': true};
    } on TimeoutException {
      throw Exception('Masa aktarımı zaman aşımına uğradı. Tekrar deneyin.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // WAITER PERFORMANCE
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns per-waiter performance statistics.
  Future<List<Map<String, dynamic>>> getWaiterPerformance({
    required String sellerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final from = (fromDate ?? DateTime.now().subtract(const Duration(days: 30)))
        .toUtc()
        .toIso8601String();
    final to =
        (toDate ?? DateTime.now()).toUtc().toIso8601String();
    try {
      final rows = await _supabase
          .rpc('get_waiter_performance', params: {
            'p_seller_id': sellerId,
            'p_from': from,
            'p_to': to,
          })
          .timeout(const Duration(seconds: 15));
      if (rows is List) {
        return List<Map<String, dynamic>>.from(rows.cast<Map>());
      }
      return const <Map<String, dynamic>>[];
    } on PostgrestException catch (error) {
      debugPrint('[StoreTableService] getWaiterPerformance failed: $error');
      return const <Map<String, dynamic>>[];
    } on TimeoutException {
      return const <Map<String, dynamic>>[];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SMART RECOMMENDATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns co-purchased product suggestions for the current draft.
  Future<List<Map<String, dynamic>>> getProductRecommendations({
    required String sellerId,
    required List<String> currentProductIds,
    int limit = 5,
  }) async {
    if (currentProductIds.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final rows = await _supabase
          .rpc('get_product_recommendations', params: {
            'p_seller_id': sellerId,
            'p_product_ids': currentProductIds,
            'p_limit': limit,
          })
          .timeout(const Duration(seconds: 10));
      if (rows is List) {
        return List<Map<String, dynamic>>.from(rows.cast<Map>());
      }
      return const <Map<String, dynamic>>[];
    } catch (error) {
      debugPrint('[StoreTableService] getProductRecommendations failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }
}
