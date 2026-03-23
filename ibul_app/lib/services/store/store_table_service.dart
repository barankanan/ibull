import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (tableNumber <= 0 || qrToken.trim().isEmpty) return null;
    try {
      final data = await _supabase
          .from('store_tables')
          .select()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .eq('qr_token', qrToken.trim())
          .eq('is_active', true)
          .maybeSingle();
      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (error) {
      if (_isStoreTablesMissingError(error)) {
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
      await _supabase
          .from('table_orders')
          .insert(payload)
          .timeout(tableOrderTimeout);
      return {...payload, 'id': null};
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
          await _supabase
              .from('table_orders')
              .insert(legacyPayload)
              .timeout(tableOrderTimeout);
          return {...legacyPayload, 'id': null};
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
    return _supabase
        .from('table_orders')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map((list) => List<Map<String, dynamic>>.from(list));
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

  Future<void> updateTableOrder(
    String orderId, {
    String? status,
    List<Map<String, dynamic>>? items,
  }) async {
    final updateData = <String, dynamic>{};
    if (status != null) {
      updateData['status'] = status;
    }
    if (items != null) {
      updateData['items'] = items;
    }
    if (updateData.isEmpty) return;

    final normalizedStatus = status?.trim();
    try {
      await _supabase
          .from('table_orders')
          .update(updateData)
          .eq('id', orderId)
          .timeout(tableOrderTimeout);
    } on PostgrestException catch (error) {
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
          await _supabase
              .from('table_orders')
              .update(legacyUpdateData)
              .eq('id', orderId)
              .timeout(tableOrderTimeout);
          return;
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

  Future<void> updateTableOrderStatus(String orderId, String status) {
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
}
