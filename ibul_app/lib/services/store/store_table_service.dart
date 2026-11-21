import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/runtime_config.dart';
import '../../models/mixed_service_order.dart';
import '../../utils/garson_active_orders_fetch.dart';
import '../../utils/order_status_constants.dart';
import '../../utils/table_labels.dart';
import '../restaurant_offline/restaurant_connectivity_service.dart';
import '../staff_login_policy.dart';
import 'close_table_rpc_args.dart';
import 'table_close_history_fallback.dart';
import 'table_order_history_utils.dart';

/// Columns present on `table_orders` in the checked migrations.
/// A missing column fails the read instead of being treated as zero.
const String garsonTableOrdersSnapshotColumns =
    'id, seller_id, table_number, items, status, created_at, updated_at, '
    'revision, last_edit_summary, last_edit_note, display_table_label, '
    'table_display_name, table_name, table_area_name, area_name, '
    'area_table_number, placement_source';

/// Columns present on `table_payments` in the checked migrations.
const String garsonTablePaymentsColumns =
    'id, seller_id, table_number, session_key, amount, method, paid_by, '
    'waiter_id, waiter_name, note, is_closing, created_at, client_request_id';

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
  bool? _tableOrderHistorySupportsArchivedAt;

  /// One hung cloud call must not freeze the next screen for the same budget.
  Future<T> _guardCloud<T>(Future<T> Function() action) async {
    if (RestaurantCloudGate.shouldFailFast) {
      throw TimeoutException(
        'Bulut erişilemiyor. Son doğrulanmış ekran korunuyor.',
      );
    }
    try {
      final value = await action().timeout(tableOrderTimeout);
      RestaurantCloudGate.noteSuccess();
      return value;
    } on TimeoutException {
      RestaurantCloudGate.noteFailure();
      rethrow;
    }
  }

  Exception _garsonOrderReadFailure(Object error) {
    final text = error.toString();
    final code = error is PostgrestException ? error.code : null;
    if (code == '57014' ||
        text.contains('57014') ||
        text.contains('statement timeout')) {
      return Exception(
        'Sunucu adisyon sorgusunu kesti (57014). '
        'Dolu masalar boş gösterilmedi.',
      );
    }
    if (error is TimeoutException) {
      return Exception(
        'Uygulama adisyon sorgusunu 10 saniyede yanıtladıramadı. '
        'Bu, sunucunun 57014 kesmesi değildir. Dolu masalar boş gösterilmedi.',
      );
    }
    if (error is Exception) return error;
    return Exception(text);
  }

  bool _isStoreTablesMissingError(Object error) {
    if (error is! PostgrestException) return false;
    final details = (error.details ?? '').toString().toLowerCase();
    final message = error.message.toLowerCase();
    // IMPORTANT: do not treat every "relation does not exist" as store_tables missing.
    // We need to distinguish missing store_table_areas vs store_tables.
    if (!((error.code ?? '').toString().trim() == 'PGRST205')) {
      return false;
    }
    return message.contains('store_tables') || details.contains('store_tables');
  }

  Exception _storeTablesUnavailableException() {
    return Exception(
      "Masa QR sistemi Supabase'te hazır değil. "
      "'ibul_app/SUPABASE_STORE_TABLE_QR_SYSTEM.sql' scriptini çalıştırın.",
    );
  }

  bool _isStoreTableAreasMissingError(Object error) {
    if (error is! PostgrestException) return false;
    if (!((error.code ?? '').toString().trim() == 'PGRST205')) return false;
    final details = (error.details ?? '').toString().toLowerCase();
    final message = error.message.toLowerCase();
    return message.contains('store_table_areas') ||
        details.contains('store_table_areas') ||
        message.contains('public.store_table_areas') ||
        details.contains('public.store_table_areas');
  }

  Exception _storeTableAreasUnavailableException() {
    return Exception(
      "Alan bazlı masa sistemi Supabase'te hazır değil. "
      "'ibul_app/supabase/migrations/20260606_store_table_areas.sql' migration’ını çalıştırın.",
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

  String _text(dynamic v) => (v ?? '').toString().trim();

  int _parsePositiveInt(dynamic value) {
    final n = _parseTableNumberValue(value);
    return n > 0 ? n : 0;
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

  bool _isTableOrderHistoryArchivedAtMissingError(Object error) {
    if (error is! PostgrestException) return false;
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == '42703' ||
        details.contains('archived_at does not exist') ||
        details.contains('archived_at');
  }

  Future<T> _runWithTableOrderHistorySchemaFallback<T>({
    required Future<T> Function(bool includeArchivedAt) operation,
  }) async {
    final preferArchivedAt = _tableOrderHistorySupportsArchivedAt != false;
    try {
      final result = await operation(preferArchivedAt);
      if (preferArchivedAt) {
        _tableOrderHistorySupportsArchivedAt = true;
      }
      return result;
    } catch (error) {
      if (preferArchivedAt &&
          _isTableOrderHistoryArchivedAtMissingError(error)) {
        _tableOrderHistorySupportsArchivedAt = false;
        return operation(false);
      }
      rethrow;
    }
  }

  String _tableOrderHistorySinceFilter({
    required String wideFromIso,
    required bool includeArchivedAt,
  }) {
    if (includeArchivedAt) {
      return 'closed_at.gte.$wideFromIso,archived_at.gte.$wideFromIso';
    }
    return 'closed_at.gte.$wideFromIso';
  }

  String _legacyTableOrderStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'sent') return 'done';
    return status;
  }

  bool _isZeroRowPostgrestError(PostgrestException error) {
    final blob = '${error.code} ${error.message} ${error.details}'.toLowerCase();
    return error.code == 'PGRST116' ||
        blob.contains('0 rows') ||
        blob.contains('0 row');
  }

  Exception _tableOrderException(String action, PostgrestException error) {
    if (_isZeroRowPostgrestError(error)) {
      return Exception(
        'Kayıtlı sipariş satırı bulunamadı veya bu hesap güncelleyemiyor. Düzenleme taslağı duruyor.',
      );
    }
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
    String? areaId,
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
      final normalizedAreaId = _text(areaId);
      if (normalizedAreaId.isNotEmpty) {
        query = query.eq('area_id', normalizedAreaId);
      }
      final rows = await _guardCloud(
        () => query.order('table_number', ascending: true),
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      if (_isStoreTablesMissingError(error)) {
        throw _storeTablesUnavailableException();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTableAreas({
    String? sellerId,
    bool onlyActive = true,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    try {
      var query = _supabase
          .from('store_table_areas')
          .select()
          .eq('seller_id', resolvedSellerId);
      if (onlyActive) {
        query = query.eq('is_active', true);
      }
      final rows = await _guardCloud(() => query.order('name', ascending: true));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      // Backwards compatible: if areas table doesn't exist yet, behave as if
      // we have a single implicit "Salon" area.
      if (_isStoreTableAreasMissingError(error)) {
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'implicit_salon',
            'seller_id': resolvedSellerId,
            'name': 'Salon',
            'is_active': true,
          },
        ];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addTableArea({
    String? sellerId,
    required String name,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw Exception('Alan adı boş olamaz.');
    }
    try {
      final inserted = await _supabase
          .from('store_table_areas')
          .insert({
            'seller_id': resolvedSellerId,
            'name': normalized,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return Map<String, dynamic>.from(inserted as Map);
    } catch (error) {
      if (_isStoreTableAreasMissingError(error)) {
        throw _storeTableAreasUnavailableException();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> ensureDefaultArea({
    String? sellerId,
    String defaultName = 'Salon',
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    final areas = await getTableAreas(
      sellerId: resolvedSellerId,
      onlyActive: false,
    );
    final existing = areas.firstWhere(
      (a) => _text(a['name']).toLowerCase() == defaultName.toLowerCase(),
      orElse: () => const <String, dynamic>{},
    );
    if (existing.isNotEmpty && _text(existing['id']).isNotEmpty) {
      return Map<String, dynamic>.from(existing);
    }
    // If areas table is missing, return implicit.
    if (areas.isNotEmpty && _text(areas.first['id']) == 'implicit_salon') {
      return Map<String, dynamic>.from(areas.first);
    }
    return addTableArea(sellerId: resolvedSellerId, name: defaultName);
  }

  Future<Map<String, dynamic>> addStoreTable({
    String? sellerId,
    int? tableNumber,
    bool preferMissingNumber = true,
    String? areaId,
    String? areaName,
    int? areaTableNumber,
    String? tableName,
    String? branchId,
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

      final normalizedAreaId = _text(areaId);
      final normalizedAreaName = _text(areaName);
      final resolvedAreaTableNo = _parsePositiveInt(areaTableNumber) > 0
          ? _parsePositiveInt(areaTableNumber)
          : nextTableNumber;
      final resolvedTableName = _text(tableName).isNotEmpty
          ? _text(tableName)
          : (normalizedAreaName.isNotEmpty
                ? '$normalizedAreaName $resolvedAreaTableNo'
                : 'Masa $nextTableNumber');

      final inserted = await _supabase
          .from('store_tables')
          .insert({
            'seller_id': resolvedSellerId,
            'table_number': nextTableNumber,
            'qr_token': _generateTableQrToken(),
            'is_active': true,
            if (_text(branchId).isNotEmpty) 'branch_id': _text(branchId),
            if (normalizedAreaId.isNotEmpty) 'area_id': normalizedAreaId,
            if (normalizedAreaName.isNotEmpty) 'area_name': normalizedAreaName,
            'area_table_number': resolvedAreaTableNo,
            'table_name': resolvedTableName,
            'display_label': resolvedTableName,
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

  /// Moves an existing table to a different area by updating its area_id,
  /// area_name and area_table_number.  Pass an empty areaId/areaName to clear.
  Future<void> updateStoreTableArea({
    required String tableId,
    required String areaId,
    required String areaName,
  }) async {
    final normalizedTableId = tableId.trim();
    if (normalizedTableId.isEmpty) return;
    try {
      // Count existing tables in the target area for area_table_number.
      int areaTableNumber = 1;
      if (areaId.trim().isNotEmpty) {
        final existing = await _supabase
            .from('store_tables')
            .select('area_table_number')
            .eq('area_id', areaId.trim());
        final nums = (existing as List)
            .map((r) => _parseTableNumberValue(r['area_table_number']))
            .where((n) => n > 0)
            .toList(growable: false);
        final max = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
        areaTableNumber = max + 1;
      }
      await _supabase
          .from('store_tables')
          .update({
            'area_id': areaId.trim().isEmpty ? null : areaId.trim(),
            'area_name': areaName.trim().isEmpty ? null : areaName.trim(),
            'area_table_number': areaTableNumber,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', normalizedTableId);
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

  /// Returns the set of table numbers that currently have at least one
  /// non-closed (active) order in [table_orders] for [sellerId].
  /// Used by the customer-facing table picker to mark occupied tables.
  Future<Set<int>> getOccupiedTableNumbers(String sellerId) async {
    final resolved = sellerId.trim();
    if (resolved.isEmpty) return const <int>{};
    try {
      // Live database has table_orders. list_occupied_table_numbers is in a
      // migration that is not in the schema cache, so it is not called.
      final rows = await _supabase
          .from('table_orders')
          .select('table_number, status')
          .eq('seller_id', resolved)
          .timeout(tableOrderTimeout);
      final result = <int>{};
      for (final row in (rows as List)) {
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isTerminalStatus(status)) continue;
        final tableNum = _parseTableNumberValue(row['table_number']);
        if (tableNum > 0) result.add(tableNum);
      }
      return result;
    } on PostgrestException catch (error) {
      if (_isStoreTablesMissingError(error)) return const <int>{};
      if (error.code == '57014') {
        throw Exception(
          'Dolu masa sorgusu zaman aşımına uğradı (57014). '
          'Boş masa olarak gösterilmedi.',
        );
      }
      rethrow;
    } on TimeoutException {
      throw Exception(
        'Dolu masa sorgusu zaman aşımına uğradı. Boş masa olarak gösterilmedi.',
      );
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
    Map<String, dynamic>? tableRow,
    String? placementSource,
  }) async {
    final normalizedStatus = status.trim().isEmpty ? 'new' : status.trim();
    final createdAt = DateTime.now().toIso8601String();
    final storedItems = items
        .map(MixedServiceOrder.persistNumericItemPrices)
        .toList(growable: false);
    final payload = <String, dynamic>{
      'seller_id': sellerId,
      'table_number': tableNumber,
      'items': storedItems,
      'status': normalizedStatus,
      'created_at': createdAt,
    };
    final src = placementSource?.trim() ?? '';
    if (src.isNotEmpty) {
      payload['placement_source'] = src;
    }
    payload.addAll(
      resolvePrintableTablePayloadFields(
        tableRow: tableRow,
        tableNumber: tableNumber,
      ),
    );

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

  /// Customer table order or waiter call. The server checks the store,
  /// the table, catalog price, and the 100 metre limit. Coordinates are
  /// not written to the order row.
  Future<Map<String, dynamic>> placeCustomerTableRequest({
    required String sellerId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    required String action,
    required double? latitude,
    required double? longitude,
    required double? accuracyMeters,
    required String clientRequestId,
    String? grantCode,
    String? customerSessionId,
    bool confirmServerPrice = false,
    String? qrToken,
    String? priceConfirmToken,
  }) async {
    try {
      final result = await _supabase
          .rpc(
            'place_customer_table_order',
            params: <String, dynamic>{
              'p_seller_id': sellerId,
              'p_table_number': tableNumber,
              'p_items': items,
              'p_latitude': latitude,
              'p_longitude': longitude,
              'p_accuracy_m': accuracyMeters,
              'p_action': action,
              'p_client_request_id': clientRequestId,
              'p_confirm_server_price': confirmServerPrice,
              if (grantCode != null && grantCode.trim().isNotEmpty)
                'p_grant_code': grantCode.trim(),
              if (customerSessionId != null && customerSessionId.trim().isNotEmpty)
                'p_customer_session_id': customerSessionId.trim(),
              if (qrToken != null && qrToken.trim().isNotEmpty)
                'p_qr_token': qrToken.trim(),
              if (priceConfirmToken != null && priceConfirmToken.trim().isNotEmpty)
                'p_price_confirm_token': priceConfirmToken.trim(),
            },
          )
          .timeout(const Duration(seconds: 12));
      if (result is Map) return Map<String, dynamic>.from(result);
      return const <String, dynamic>{};
    } on PostgrestException catch (error) {
      final details =
          '${error.code} ${error.message} ${error.details ?? ''}'.toLowerCase();
      if (error.code == 'PGRST202' ||
          details.contains('could not find the function')) {
        throw StateError(
          'Masa siparişi sunucuda doğrulanamıyor. Sipariş kaydedilmedi.',
        );
      }
      final label = action == 'waiter_call' ? 'Garson çağırma' : 'Sipariş gönderimi';
      throw _tableOrderException(label, error);
    } on TimeoutException {
      throw StateError(
        'Masa isteği doğrulanamadı. Aynı gönderim tekrar denenebilir.',
      );
    }
  }

  Future<Map<String, dynamic>> issueCustomerProximityGrant({
    required String sellerId,
    required int tableNumber,
    required String customerSessionId,
    required bool staffConfirmed,
  }) async {
    try {
      final result = await _supabase.rpc(
        'issue_customer_proximity_grant',
        params: <String, dynamic>{
          'p_seller_id': sellerId,
          'p_table_number': tableNumber,
          'p_customer_session_id': customerSessionId.trim(),
          'p_staff_confirmed': staffConfirmed,
        },
      ).timeout(const Duration(seconds: 12));
      if (result is Map) return Map<String, dynamic>.from(result);
      return const <String, dynamic>{};
    } on PostgrestException catch (error) {
      throw _tableOrderException('Masa konum onayı', error);
    } on TimeoutException {
      throw StateError('Onay kodu oluşturulamadı. Tekrar deneyin.');
    }
  }

  /// Creates a waiter call for [tableNumber], reusing an existing active call
  /// instead of inserting a duplicate.
  ///
  /// A waiter call is stored as a `table_orders` row with status
  /// `call_waiter`. Tapping "Garson Çağır" repeatedly (or double taps) must not
  /// pile up 10 separate active calls for the same table, so we first look for a
  /// still-active (non-terminal) `call_waiter` row for this seller+table and
  /// reuse it when present.
  Future<Map<String, dynamic>> ensureWaiterCall({
    required String sellerId,
    required int tableNumber,
    Map<String, dynamic>? tableRow,
  }) async {
    debugPrint(
      '[WaiterCall][db] ensureWaiterCall seller=$sellerId table=$tableNumber',
    );
    try {
      final existing = await _supabase
          .from('table_orders')
          .select()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .eq('status', 'call_waiter')
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(tableOrderTimeout);
      final rows = List<Map<String, dynamic>>.from(existing as List);
      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);
        debugPrint(
          '[WaiterCall][db] reused active call id=${row['id']} table=$tableNumber',
        );
        return row;
      }
    } on TimeoutException {
      // Dedup lookup timed out — fall through and create the call anyway.
    } catch (error) {
      // Never block a waiter call on the dedup lookup; fall through to insert.
      debugPrint('[WaiterCall][db] dedup lookup failed: $error');
    }

    final inserted = await submitTableOrder(
      sellerId: sellerId,
      tableNumber: tableNumber,
      items: const [
        {
          'name': 'Garson Çağrıldı',
          'quantity': 1,
          'price': 0.0,
          'type': 'waiter_call',
        },
      ],
      status: 'call_waiter',
      tableRow: tableRow,
      placementSource: 'customer',
    );
    debugPrint(
      '[WaiterCall][db] inserted id=${inserted['id']} table=$tableNumber',
    );
    return inserted;
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
    // IMPORTANT: Stream delivers EVERY row, including archived/closed orders
    // from the RPC close_table_orders. Without filtering these out, they get
    // re-inserted into board state and make a closed table appear "open again"
    return _supabase
        .from('table_orders')
        .stream(primaryKey: ['id'])
        .eq('seller_id', resolvedSellerId)
        .order('created_at', ascending: false)
        .map(
          (list) => List<Map<String, dynamic>>.from(
            list.where(
              (row) => !OrderStatusConstants.isTerminalStatus(row['status']?.toString()),
            ),
          ),
        );
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
    logGarsonOrdersDebugSql(restaurantId: resolvedSellerId);

    final tableOrdersQuery = garsonTableOrdersSnapshotQueryDescription(
      restaurantId: resolvedSellerId,
      tableNumber: tableNumber,
    );
    logGarsonActiveOrdersFetchStart(
      restaurantId: resolvedSellerId,
      source: 'table_orders',
      query: tableOrdersQuery,
      tableFilter: tableNumber != null && tableNumber > 0
          ? 'table_number=$tableNumber'
          : '',
    );
    if (RestaurantCloudGate.shouldFailFast) {
      throw TimeoutException(
        'Bulut erişilemiyor. Son doğrulanmış ekran korunuyor.',
      );
    }
    final restaurantOrdersQuery =
        garsonRestaurantOrdersSnapshotQueryDescription(
          restaurantId: resolvedSellerId,
        );
    logGarsonActiveOrdersFetchStart(
      restaurantId: resolvedSellerId,
      source: 'orders',
      query: restaurantOrdersQuery,
    );
    final fetched = await Future.wait<({
      List<Map<String, dynamic>> rows,
      Object? failure,
    })>([
      () async {
        try {
          final rows = await _fetchTableOrdersForGarson(
            sellerId: resolvedSellerId,
            tableNumber: tableNumber,
          );
          logGarsonActiveOrdersFetchResult(
            restaurantId: resolvedSellerId,
            source: 'table_orders',
            orders: rows,
          );
          return (rows: rows, failure: null);
        } catch (error, stack) {
          logGarsonActiveOrdersFetchError(
            restaurantId: resolvedSellerId,
            source: 'table_orders',
            error: error,
            stack: stack,
          );
          if (error is TimeoutException) {
          RestaurantCloudGate.noteFailure();
        }
        return (rows: const <Map<String, dynamic>>[], failure: error);
        }
      }(),
      () async {
        try {
          final rows = await _fetchRestaurantOrdersForGarson(
            restaurantId: resolvedSellerId,
            tableNumber: tableNumber,
          );
          logGarsonActiveOrdersFetchResult(
            restaurantId: resolvedSellerId,
            source: 'orders',
            orders: rows,
          );
          return (rows: rows, failure: null);
        } catch (error, stack) {
          logGarsonActiveOrdersFetchError(
            restaurantId: resolvedSellerId,
            source: 'orders',
            error: error,
            stack: stack,
          );
          if (error is TimeoutException) {
            RestaurantCloudGate.noteFailure();
          }
          return (rows: const <Map<String, dynamic>>[], failure: error);
        }
      }(),
    ]);
    final tableOrders = fetched[0].rows;
    final tableOrdersFailure = fetched[0].failure;
    final restaurantOrders = fetched[1].rows;
    final restaurantOrdersFailure = fetched[1].failure;
    if (tableOrdersFailure == null && restaurantOrdersFailure == null) {
      RestaurantCloudGate.noteSuccess();
    }
    if (tableOrdersFailure != null && restaurantOrders.isEmpty) {
      throw _garsonOrderReadFailure(tableOrdersFailure);
    }
    if (restaurantOrdersFailure != null && tableOrders.isEmpty) {
      throw _garsonOrderReadFailure(restaurantOrdersFailure);
    }

    final merged = mergeGarsonActiveOrderSources(
      tableOrders: tableOrders,
      restaurantOrders: restaurantOrders,
    );
    logGarsonActiveOrdersFetchResult(
      restaurantId: resolvedSellerId,
      source: 'merged_active_orders',
      orders: merged,
    );

    return merged;
  }

  Future<List<Map<String, dynamic>>> _fetchTableOrdersForGarson({
    required String sellerId,
    int? tableNumber,
  }) async {
    // Exclude terminal-status rows at the DB level.  This is the definitive
    // guard against closed/archived orders "coming back" after a page refresh:
    // even if UPDATE status='archived' succeeded (instead of DELETE), these
    var query = _supabase
        .from('table_orders')
        .select(garsonTableOrdersSnapshotColumns)
        .eq('seller_id', sellerId)
        .not('status', 'in', OrderStatusConstants.terminalStatuses.toList());
    if (tableNumber != null && tableNumber > 0) {
      query = query.eq('table_number', tableNumber);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .timeout(tableOrderTimeout);
    final rawOrders = List<Map<String, dynamic>>.from(rows as List);
    if (rawOrders.isEmpty) return const <Map<String, dynamic>>[];

    final tableIds = rawOrders
        .map(
          (order) =>
              order['table_id']?.toString().trim() ??
              order['store_table_id']?.toString().trim() ??
              '',
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    final tableNumbers = rawOrders
        .map((order) => _parseTableNumberValue(order['table_number']))
        .where((number) => number > 0)
        .toSet();
    final storeTablesById = await _loadStoreTablesById(
      sellerId: sellerId,
      tableIds: tableIds,
    );
    final storeTablesByNumber = await _loadStoreTablesByNumber(
      sellerId: sellerId,
      tableNumbers: tableNumbers,
    );

    final normalized = <Map<String, dynamic>>[];
    for (final raw in rawOrders) {
      final tableId =
          raw['table_id']?.toString().trim() ??
          raw['store_table_id']?.toString().trim() ??
          '';
      final tableNo = _parseTableNumberValue(raw['table_number']);
      final storeTable =
          (tableId.isNotEmpty ? storeTablesById[tableId] : null) ??
          (tableNo > 0 ? storeTablesByNumber[tableNo] : null);
      final mapped = normalizeTableOrderToGarsonBoardOrder(
        order: raw,
        storeTable: storeTable,
      );
      if (mapped == null) continue;
      normalized.add(mapped);
    }
    return normalized;
  }

  Future<List<Map<String, dynamic>>> _fetchRestaurantOrdersForGarson({
    required String restaurantId,
    int? tableNumber,
  }) async {
    // BUG-FIX (Reopen Bug): The `orders` table is the customer-self-ordering
    // source (QR menu, e-commerce flow). The garson close path only touches
    // `table_orders`; without a DB-level terminal filter here, every closed
    // customer order keeps coming back after each refresh — making the table
    // appear "open" again.  We mirror the exact `_fetchTableOrdersForGarson`
    // exclusion list.
    //
    // IMPORTANT — only filter on `status`, NOT on `order_status`:
    //   PostgREST `.not(col, in, ...)` translates to SQL
    //   `col NOT IN (...)` which evaluates to `NULL` for NULL values, and
    //   `NULL` filters the row out.  Legacy `orders` rows can have
    //   `order_status = NULL` (the column was added later), so a
    //   `.not('order_status', 'in', terminal)` clause silently HIDES every
    //   such legitimately-active row.  `status` is always populated by the
    //   canonical insert path (see migration
    //   20260607_fix_create_table_order_with_print_jobs_impl_orders_schema.sql)
    //   so filtering on it alone is safe.  `order_status` consistency is
    final rows = await _supabase
        .from('orders')
        .select(
          'id, restaurant_id, table_id, order_status, status, order_type, '
          'delivery_type, total_amount, created_at, updated_at, '
          'order_items(id, product_id, product_name, quantity, unit_price, '
          'line_total, item_note, station_id, attributes)',
        )
        .eq('restaurant_id', restaurantId)
        .or('order_type.eq.table,delivery_type.eq.table,order_type.eq.online')
        .not('status', 'in', OrderStatusConstants.terminalStatuses.toList())
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(tableOrderTimeout);
    final rawOrders = List<Map<String, dynamic>>.from(rows as List);
    if (rawOrders.isEmpty) return const <Map<String, dynamic>>[];

    final tableIds = rawOrders
        .map((order) => order['table_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final storeTablesById = await _loadStoreTablesById(
      sellerId: restaurantId,
      tableIds: tableIds,
    );
    final normalized = <Map<String, dynamic>>[];
    for (final raw in rawOrders) {
      if (!isGarsonRestaurantTableOrderRow(raw)) continue;
      final tableId = raw['table_id']?.toString().trim() ?? '';
      final storeTable = tableId.isEmpty ? null : storeTablesById[tableId];
      final rawItems = raw['order_items'] is List
          ? List<dynamic>.from(raw['order_items'] as List)
          : const <dynamic>[];
      final items = normalizeRestaurantOrderItems(rawItems);
      final mapped = normalizeRestaurantOrderToGarsonTableOrder(
        order: raw,
        items: items,
        storeTable: storeTable,
      );
      if (mapped == null) continue;
      // A non-terminal row is an open bill even when an older visit was
      // archived. Hiding it made the card and the close query disagree.
      normalized.add(mapped);
    }

    return filterGarsonActiveOrdersByTableNumber(
      orders: normalized,
      tableNumber: tableNumber ?? 0,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadStoreTablesById({
    required String sellerId,
    required Set<String> tableIds,
  }) async {
    if (tableIds.isEmpty) return const <String, Map<String, dynamic>>{};
    try {
      final rows = await _supabase
          .from('store_tables')
          .select(
            'id, seller_id, table_number, area_name, area_table_number, '
            'display_label, table_name',
          )
          .eq('seller_id', sellerId)
          .inFilter('id', tableIds.toList(growable: false))
          .timeout(tableOrderTimeout);
      final out = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        out[id] = map;
      }
      if (out.isEmpty && tableIds.isNotEmpty) {
        // Identity-mismatch beacon: `orders.table_id` references a
        // `store_tables.id` that does NOT belong to the seller we are
        // querying for.  Possible causes:
        //   • the order was created under a different `restaurant_id`
        //     than `_resolveGarsonSellerId()` is currently returning
        //   • the seller_id was rewritten (rare migration drift)
        //   • the `store_tables` row was deleted but the order survived
        // The fetch path will skip such orders (no `table_number`
        // resolved), but emitting this beacon allows ops to detect the
        // drift in production logs.
        debugPrint(
          '[GARSON_IDENTITY_MISMATCH] '
          'context=loadStoreTablesById '
          'sellerId=$sellerId '
          'requested_table_ids=${tableIds.length} '
          'resolved_table_ids=0 '
          'effect=orders_will_be_skipped_for_missing_table_number',
        );
      }
      return out;
    } catch (_) {
      return const <String, Map<String, dynamic>>{};
    }
  }

  Future<Map<int, Map<String, dynamic>>> _loadStoreTablesByNumber({
    required String sellerId,
    required Set<int> tableNumbers,
  }) async {
    if (tableNumbers.isEmpty) return const <int, Map<String, dynamic>>{};
    try {
      final rows = await _supabase
          .from('store_tables')
          .select(
            'id, seller_id, table_number, area_name, area_table_number, '
            'display_label, table_name',
          )
          .eq('seller_id', sellerId)
          .inFilter('table_number', tableNumbers.toList(growable: false))
          .timeout(tableOrderTimeout);
      final out = <int, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final number = _parseTableNumberValue(map['table_number']);
        if (number <= 0) continue;
        out[number] = map;
      }
      return out;
    } catch (_) {
      return const <int, Map<String, dynamic>>{};
    }
  }

  /// Open rows for one physical table.
  ///
  /// The card can show a Bahçe 1 bill whose `table_orders.table_number` is
  /// still the area index. This read keeps that row with the canonical table,
  /// and it also reads `orders.table_id` directly so a global 50-row snapshot
  /// cannot hide the visit.
  Future<List<Map<String, dynamic>>> getTableCloseSession({
    required String sellerId,
    required int tableNumber,
    Map<String, dynamic>? tableRow,
    List<String> visibleOrderIds = const <String>[],
  }) async {
    final resolvedSellerId = sellerId.trim();
    if (resolvedSellerId.isEmpty || tableNumber <= 0) {
      return const <Map<String, dynamic>>[];
    }
    final anchor = tableRow ??
        await _loadStoreTablesByNumber(
          sellerId: resolvedSellerId,
          tableNumbers: <int>{tableNumber},
        ).then((rows) => rows[tableNumber]);
    final byId = <String, Map<String, dynamic>>{};

    void take(Map<String, dynamic>? order, {int? storedTableNumber}) {
      if (order == null) return;
      if (!garsonOrderBelongsToCloseTable(
        table: anchor,
        canonicalTableNumber: tableNumber,
        order: order,
      )) {
        return;
      }
      final id = order['id']?.toString().trim() ?? '';
      if (id.isEmpty) return;
      final copy = Map<String, dynamic>.from(order);
      if (storedTableNumber != null && storedTableNumber > 0) {
        copy['_stored_table_number'] = storedTableNumber;
      }
      byId[id] = copy;
    }

    final canonical = await getTableOrdersSnapshot(
      resolvedSellerId,
      tableNumber: tableNumber,
    );
    for (final order in canonical) {
      take(order, storedTableNumber: _parseTableNumberValue(order['table_number']));
    }

    final areaName = anchor?['area_name']?.toString().trim() ?? '';
    final areaNo = _parseTableNumberValue(anchor?['area_table_number']);
    if (areaName.isNotEmpty && areaNo > 0) {
      final rows = await _supabase
          .from('table_orders')
          .select(garsonTableOrdersSnapshotColumns)
          .eq('seller_id', resolvedSellerId)
          .eq('area_name', areaName)
          .eq('area_table_number', areaNo)
          .not('status', 'in', OrderStatusConstants.terminalStatuses.toList())
          .limit(40)
          .timeout(tableOrderTimeout);
      for (final raw in (rows as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final stored = _parseTableNumberValue(row['table_number']);
        final mapped = normalizeTableOrderToGarsonBoardOrder(
          order: row,
          storeTable: anchor,
        );
        take(mapped, storedTableNumber: stored);
      }
    }

    final tableId = anchor?['id']?.toString().trim() ?? '';
    if (tableId.isNotEmpty) {
      final rows = await _supabase
          .from('orders')
          .select(
            'id, restaurant_id, table_id, order_status, status, order_type, '
            'delivery_type, total_amount, created_at, updated_at, '
            'order_items(id, product_id, product_name, quantity, unit_price, '
            'line_total, item_note, station_id, attributes)',
          )
          .eq('restaurant_id', resolvedSellerId)
          .eq('table_id', tableId)
          .or('order_type.eq.table,delivery_type.eq.table')
          .not('status', 'in', OrderStatusConstants.terminalStatuses.toList())
          .limit(40)
          .timeout(tableOrderTimeout);
      for (final raw in (rows as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (!isGarsonRestaurantTableOrderRow(row)) continue;
        final rawItems = row['order_items'] is List
            ? List<dynamic>.from(row['order_items'] as List)
            : const <dynamic>[];
        take(
          normalizeRestaurantOrderToGarsonTableOrder(
            order: row,
            items: normalizeRestaurantOrderItems(rawItems),
            storeTable: anchor,
          ),
        );
      }
    }

    final ids = visibleOrderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !byId.containsKey(id))
        .toList(growable: false);
    if (ids.isNotEmpty) {
      final rows = await _supabase
          .from('table_orders')
          .select()
          .inFilter('id', ids)
          .eq('seller_id', resolvedSellerId)
          .timeout(tableOrderTimeout);
      for (final raw in (rows as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (OrderStatusConstants.isTerminalStatus(row['status']?.toString())) {
          continue;
        }
        final stored = _parseTableNumberValue(row['table_number']);
        take(
          normalizeTableOrderToGarsonBoardOrder(order: row, storeTable: anchor),
          storedTableNumber: stored,
        );
      }
    }

    return byId.values.toList(growable: false);
  }

  Future<void> realignTableOrderNumber({
    required String sellerId,
    required String orderId,
    required int canonicalTableNumber,
    required int storedTableNumber,
  }) async {
    if (orderId.trim().isEmpty ||
        canonicalTableNumber <= 0 ||
        storedTableNumber <= 0 ||
        storedTableNumber == canonicalTableNumber) {
      return;
    }
    await _supabase
        .from('table_orders')
        .update(<String, dynamic>{
          'table_number': canonicalTableNumber,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('seller_id', sellerId)
        .eq('table_number', storedTableNumber)
        .timeout(tableOrderTimeout);
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
      updateData['items'] = items
          .map(MixedServiceOrder.persistNumericItemPrices)
          .toList(growable: false);
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
      if (updated == null) {
        throw Exception(
          'Kayıtlı sipariş satırı bulunamadı veya bu hesap güncelleyemiyor. Düzenleme taslağı duruyor.',
        );
      }
      return Map<String, dynamic>.from(updated as Map);
    } on PostgrestException catch (error) {
      if (_isZeroRowPostgrestError(error)) {
        throw _tableOrderException('Sipariş güncelleme', error);
      }
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

  /// Returns only the rows from [table_orders] whose primary-key [ids] still
  /// exist in the database. Used by [_closeGarsonTable] to verify that every
  /// targeted order was actually deleted/closed — a filter-based re-query
  /// (seller_id + table_number) can produce a false-empty result if orders
  /// were never in [table_orders] or if row-level-security blocks the filter.
  Future<List<Map<String, dynamic>>> getTableOrdersByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final rows = await _supabase
          .from('table_orders')
          .select()
          .inFilter('id', ids)
          .timeout(tableOrderTimeout);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      throw _tableOrderException('Sipariş doğrulama', error);
    } on TimeoutException {
      throw Exception(
        'Sipariş doğrulama zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Resolves the canonical `store_tables.id` values for a given seller +
  /// table_number.  Returns an empty list when no physical row matches —
  /// the caller MUST treat this as "nothing to close" rather than silently
  /// no-op'ing on a wrong table.
  ///
  /// Why this matters: `public.orders` does not have a `table_number`
  /// column (see migration 20260607_fix_create_table_order_with_print_jobs_impl_orders_schema.sql).
  /// The only canonical link between a logical table (number) and an order
  /// row is `orders.table_id` → `store_tables.id`.  Any close/update on
  /// `orders` that doesn't constrain `table_id` will affect the wrong
  /// table(s).
  Future<List<String>> resolveStoreTableIdsForNumber({
    required String sellerId,
    required int tableNumber,
  }) async {
    if (sellerId.trim().isEmpty || tableNumber <= 0) return const <String>[];
    try {
      final rows = await _supabase
          .from('store_tables')
          .select('id, seller_id, table_number')
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .timeout(tableOrderTimeout);
      final ids = <String>[];
      for (final row in (rows as List)) {
        final id = (row as Map)['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
      return ids;
    } catch (error) {
      debugPrint(
        '[StoreTableService.resolveStoreTableIdsForNumber] '
        'sellerId=$sellerId tableNumber=$tableNumber '
        'lookup_failed error=$error',
      );
      return const <String>[];
    }
  }

  /// BUG-FIX (Reopen Bug + schema-aware close):
  /// Marks every active row in the customer-facing `orders` table for the
  /// given (sellerId, tableNumber) as `closed`.  The garson board reads from
  /// BOTH `table_orders` and `orders`; without this update, customer-placed
  /// orders survive the close and re-appear on the next refresh.
  ///
  /// Schema constraint: `public.orders` has NO `table_number` column.  The
  /// only correct way to scope this update to a single logical table is to
  /// first resolve `store_tables.id` from `(seller_id, table_number)` and
  /// then filter `orders.table_id IN (resolved_ids)`.  Filtering only by
  /// `restaurant_id` (as a previous version of this function did) would
  /// close EVERY table's active customer orders — a destructive bug.
  ///
  /// Best-effort: failures here are logged but do NOT abort the close.
  /// `_fetchRestaurantOrdersForGarson` also filters terminal rows at fetch
  /// time so a leftover row would still be hidden from the board even if
  /// this UPDATE silently fails.
  /// Returns the number of `orders` rows actually flipped to `closed`.
  ///
  /// A return value of **0** is a strong signal that something failed
  /// silently (RLS reject, identity mismatch, or no matching customer
  /// orders existed in the first place).  Callers should surface this to
  /// the UI rather than treat it as success.
  Future<int> closeRestaurantOrdersForTable({
    required String sellerId,
    required int tableNumber,
  }) async {
    if (sellerId.trim().isEmpty || tableNumber <= 0) {
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTable] '
        'skipped reason=invalid_params '
        'sellerId=$sellerId tableNumber=$tableNumber',
      );
      return 0;
    }

    // Preferred path: SECURITY DEFINER RPC so waiter/sub-admin sessions can
    // close customer-side `orders` rows under the parent restaurant identity.
    // If the migration is not applied yet, fall back to the legacy direct
    // UPDATE path below.
    try {
      final rpcResult = await _supabase
          .rpc(
            'close_restaurant_orders_for_table',
            params: <String, dynamic>{
              'p_seller_id': sellerId,
              'p_table_number': tableNumber,
            },
          )
          .timeout(tableOrderTimeout);
      final closedCount = _coerceAffectedRowCount(rpcResult);
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTable] '
        'rpc=ok sellerId=$sellerId tableNumber=$tableNumber '
        'orders_closed=$closedCount',
      );
      return closedCount;
    } on PostgrestException catch (error) {
      final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
      final rpcMissing =
          error.code == '42883' ||
          message.contains('close_restaurant_orders_for_table') ||
          message.contains('function') ||
          message.contains('schema cache');
      if (!rpcMissing) {
        debugPrint(
          '[StoreTableService.closeRestaurantOrdersForTable] '
          'rpc=failed_non_fallback sellerId=$sellerId tableNumber=$tableNumber '
          'error=$error',
        );
        return 0;
      }
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTable] '
        'rpc=missing sellerId=$sellerId tableNumber=$tableNumber '
        'action=falling_back_to_direct_update',
      );
    } on TimeoutException {
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTable] '
        'rpc=timeout sellerId=$sellerId tableNumber=$tableNumber '
        'action=falling_back_to_direct_update',
      );
    }

    return _closeRestaurantOrdersForTableDirect(
      sellerId: sellerId,
      tableNumber: tableNumber,
    );
  }

  Future<int> _closeRestaurantOrdersForTableDirect({
    required String sellerId,
    required int tableNumber,
  }) async {
    final authUid = _supabase.auth.currentUser?.id;
    final identityMatches =
        authUid != null && authUid.trim() == sellerId.trim();
    if (!identityMatches) {
      debugPrint(
        '[GARSON_IDENTITY_MISMATCH] '
        'context=closeRestaurantOrdersForTable '
        'authUid=${authUid ?? "<null>"} '
        'resolvedSellerId=$sellerId '
        'tableNumber=$tableNumber '
        'warning=orders_update_will_likely_be_RLS_rejected_to_zero_rows',
      );
    }

    final tableIds = await resolveStoreTableIdsForNumber(
      sellerId: sellerId,
      tableNumber: tableNumber,
    );
    if (tableIds.isEmpty) {
      // Identity-mismatch signal: store_tables has no row for this
      // (sellerId, tableNumber).  Either:
      //   • the seller never created this physical table, OR
      //   • `_resolveGarsonSellerId()` produced a UUID that differs from
      //     `store_tables.seller_id` (sub-user / waiter scenario), OR
      //   • the seller deleted the table.
      // In all cases: there is no `orders.table_id` to scope to, so a
      // restaurant_id-only update would be unsafe.  Bail out.
      debugPrint(
        '[GARSON_IDENTITY_MISMATCH] '
        'context=closeRestaurantOrdersForTable '
        'sellerId=$sellerId tableNumber=$tableNumber '
        'reason=store_tables_returned_zero_rows '
        'effect=orders_update_skipped_to_avoid_closing_wrong_table',
      );
      return 0;
    }
    try {
      final updatedRows = await _supabase
          .from('orders')
          .update(<String, dynamic>{
            'status': 'closed',
            'order_status': 'closed',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('restaurant_id', sellerId)
          .or('order_type.eq.table,delivery_type.eq.table,order_type.eq.online')
          .inFilter('table_id', tableIds)
          .not(
            'status',
            'in',
            OrderStatusConstants.terminalStatuses.toList(),
          )
          .select('id, table_id, status')
          .timeout(tableOrderTimeout);
      final updatedList = updatedRows as List;
      final closedCount = updatedList.length;
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTable] '
        'sellerId=$sellerId tableNumber=$tableNumber '
        'resolved_table_ids=${tableIds.length} '
        'orders_closed=$closedCount '
        'identity_matches=$identityMatches',
      );
      if (closedCount == 0) {
        // Active `orders` rows could be invisible because of one of three
        // mutually-exclusive reasons.  Probe each — the diff is decisive
        // for the reopen bug.
        final probeRows = await _supabase
            .from('orders')
            .select('id, status, order_status, table_id, restaurant_id')
            .eq('restaurant_id', sellerId)
            .inFilter('table_id', tableIds)
            .limit(20)
            .timeout(tableOrderTimeout);
        final probeList = probeRows as List;
        final visibleToClient = probeList.length;
        debugPrint(
          '[GARSON_ORDERS_CLOSE_ZERO] '
          'sellerId=$sellerId tableNumber=$tableNumber '
          'resolved_table_ids=${tableIds.length} '
          'probe_visible_to_client=$visibleToClient '
          'identity_matches=$identityMatches '
          'interpretation=${visibleToClient == 0 ? (identityMatches ? 'no_active_customer_orders_for_this_table' : 'rls_likely_blocked_due_to_auth_uid_mismatch') : 'rows_visible_to_read_but_update_returned_zero_rows_'
                    'check_RLS_USING_vs_WITH_CHECK_clauses'}',
        );
      }
      return closedCount;
    } on PostgrestException catch (error) {
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTableDirect] '
        'PostgrestException sellerId=$sellerId tableNumber=$tableNumber '
        'resolved_table_ids=${tableIds.length} '
        'identity_matches=$identityMatches '
        'best_effort=failed error=$error',
      );
      if (error.code == '42501' || error.message.contains('RLS')) {
        throw Exception('RLS Violation during table close: ${error.message}');
      }
      return 0;
    } catch (error) {
      debugPrint(
        '[StoreTableService.closeRestaurantOrdersForTableDirect] '
        'sellerId=$sellerId tableNumber=$tableNumber '
        'resolved_table_ids=${tableIds.length} '
        'identity_matches=$identityMatches '
        'best_effort=failed error=$error',
      );
      return 0;
    }
  }

  int _coerceAffectedRowCount(dynamic result) {
    if (result is num) return result.toInt();
    if (result is String) return int.tryParse(result) ?? 0;
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is num) return first.toInt();
      if (first is Map) {
        for (final key in ['closed_count', 'count', 'rows_affected']) {
          final value = first[key];
          if (value is num) return value.toInt();
          final parsed = int.tryParse(value?.toString() ?? '');
          if (parsed != null) return parsed;
        }
      }
    }
    if (result is Map) {
      for (final key in ['closed_count', 'count', 'rows_affected']) {
        final value = result[key];
        if (value is num) return value.toInt();
        final parsed = int.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  Future<void> closeTableOrders({
    required String sellerId,
    required int tableNumber,
  }) async {
    // ── Strategy: try RPC first (SECURITY DEFINER — bypasses RLS and the
    // broken DELETE trigger), fall back to direct DELETE only if RPC is
    // unavailable.  The RPC uses UPDATE status='archived' internally so it
    // never triggers the recursive DELETE trigger that caused P0001 errors.
    try {
      await _supabase
          .rpc(
            'close_table_orders',
            params: <String, dynamic>{
              'p_seller_id': sellerId,
              'p_table_number': tableNumber,
            },
          )
          .timeout(tableOrderTimeout);
      debugPrint(
        '[StoreTableService.closeTableOrders] rpc=ok '
        'table=$tableNumber sellerId=$sellerId',
      );
      // Mirror the close into the customer-facing `orders` table so a refresh
      // doesn't re-surface the same customer order.  Best-effort.
      await closeRestaurantOrdersForTable(
        sellerId: sellerId,
        tableNumber: tableNumber,
      );
      return;
    } on PostgrestException catch (rpcError) {
      // RPC not found or permission error — fall through to direct DELETE.
      debugPrint(
        '[StoreTableService.closeTableOrders] rpc=failed '
        'code=${rpcError.code} msg=${rpcError.message} '
        '— falling back to direct DELETE',
      );
    } on TimeoutException {
      // RPC timed out — fall through to direct DELETE.
      debugPrint(
        '[StoreTableService.closeTableOrders] rpc=timeout — falling back to direct DELETE',
      );
    }

    // ── Fallback: direct DELETE (may still trigger the problematic trigger,
    // but the trigger now has working functions so it should complete) ────────
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
    // Mirror the close into the customer-facing `orders` table — same reason
    // as in the RPC happy path above.
    await closeRestaurantOrdersForTable(
      sellerId: sellerId,
      tableNumber: tableNumber,
    );
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
    String? clientRequestId,
  }) async {
    final requestId = clientRequestId?.trim() ?? '';
    if (requestId.isEmpty) {
      throw Exception(
        'Ödeme isteği kimliği olmadan tahsilat yapılmadı.',
      );
    }
    try {
      final inserted = await _supabase
          .rpc(
            'record_table_payment',
            params: {
              'p_seller_id': sellerId,
              'p_table_number': tableNumber,
              'p_session_key': sessionKey,
              'p_amount': amount,
              'p_method': method,
              'p_is_closing': isClosing,
              'p_client_request_id': requestId,
              if (paidBy != null && paidBy.isNotEmpty) 'p_paid_by': paidBy,
              if (waiterId != null && waiterId.isNotEmpty)
                'p_waiter_id': waiterId,
              if (waiterName != null && waiterName.isNotEmpty)
                'p_waiter_name': waiterName,
              if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
            },
          )
          .timeout(tableOrderTimeout);
      if (inserted is Map) {
        return Map<String, dynamic>.from(inserted);
      }
      throw Exception('Ödeme sonucu belirsiz. İkinci tahsilat başlatılmadı.');
    } on PostgrestException catch (error) {
      final text = '${error.message} ${error.details}'.toLowerCase();
      final guardMissing = error.code == 'PGRST202' ||
          text.contains('record_table_payment') ||
          text.contains('could not find the function');
      if (guardMissing) {
        throw Exception(
          'Sunucuda ödeme koruması yok. Tahsilat yapılmadı.',
        );
      }
      if (error.code == '23505' || text.contains('ibul_payment_replay')) {
        final existing = await _supabase
            .from('table_payments')
            .select(garsonTablePaymentsColumns)
            .eq('seller_id', sellerId)
            .eq('client_request_id', requestId)
            .maybeSingle()
            .timeout(tableOrderTimeout);
        if (existing != null) {
          return {
            ...Map<String, dynamic>.from(existing),
            'idempotent_replay': true,
          };
        }
        throw Exception(
          'Ödeme sonucu belirsiz. İkinci tahsilat başlatılmadı.',
        );
      }
      throw _tableOrderException('Ödeme kaydı', error);
    } on TimeoutException {
      throw Exception(
        'Ödeme sonucu belirsiz. İkinci tahsilat başlatılmadı.',
      );
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
          .select(garsonTablePaymentsColumns)
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber);
      if (sessionKey != null && sessionKey.isNotEmpty) {
        query = query.eq('session_key', sessionKey);
      }
      final rows = await _guardCloud(
        () => query.order('created_at', ascending: true),
      );
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
  /// The RPC runs in one PostgreSQL transaction. For each open order it
  /// inserts one `table_order_history` row, then archives `table_orders` and
  /// sets `orders.status` to closed. It does not insert or delete
  /// `table_payments`. A timeout does not call the function again.
  ///
  /// Any RPC failure stops here. A direct `table_orders` delete or status
  /// update would skip the server permission and the atomic history write.
  Future<Map<String, dynamic>> closeTableWithHistory({
    required String sellerId,
    required int tableNumber,
    required String paymentMethod,
    String? paymentNote,
    String? waiterId,
    String? waiterName,
    String? sessionKey,
    String? tableLabel,
    String? areaName,
  }) async {
    try {
      final raw = await _supabase
          .rpc(
            'close_table_with_history',
            params: closeTableWithHistoryRpcParams(
              sellerId: sellerId,
              tableNumber: tableNumber,
              paymentMethod: paymentMethod,
              paymentNote: paymentNote,
              waiterId: waiterId,
              waiterName: waiterName,
              sessionKey: sessionKey,
            ),
          )
          .timeout(tableOrderTimeout);
      final result = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      // The live function closes `orders` in the same transaction. A second
      // update runs only when that payload is missing, so an older server
      // still clears customer orders and a current server is not closed twice.
      if (!result.containsKey('orders_updated')) {
        final closed = await closeRestaurantOrdersForTable(
          sellerId: sellerId,
          tableNumber: tableNumber,
        );
        result['orders_updated'] = closed;
        result['orders_close_fallback'] = true;
      }
      return result;
    } on PostgrestException catch (error) {
      if (directTableOrderWriteAllowedAfterRpcFailure(
        code: error.code,
        message: error.message,
      )) {
        throw StateError('Doğrudan masa yazımı kapalı.');
      }
      throw _tableOrderException('Masa kapatma', error);
    } on TimeoutException {
      throw Exception(
        'Masa kapatma sonucu belirsiz. Aynı kapatma isteği yeniden gönderilmedi.',
      );
    }
  }

  /// Ensures a just-closed table session is queryable from `table_order_history`
  /// even if the primary archive path partially failed and the caller had to
  /// finish the close via per-order fallback.
  ///
  /// Returns `true` when a fallback history row was inserted, `false` when a
  /// recent matching row already existed or when there was nothing to archive.
  Future<bool> ensureTableHistoryRecorded({
    required String sellerId,
    required int tableNumber,
    required List<Map<String, dynamic>> closedOrders,
    required String paymentMethod,
    String? paymentNote,
    String? waiterId,
    String? waiterName,
    String? tableLabel,
    DateTime? closedAt,
    String? areaName,
    String? sessionKey,
    String? knownServerHistoryId,
  }) async {
    if (tableNumber <= 0 || closedOrders.isEmpty) return false;
    final serverAlreadyArchived =
        (knownServerHistoryId ?? '').trim().isNotEmpty;

    final resolvedSellerId = _resolveSellerId(sellerId);
    final effectiveClosedAt = (closedAt ?? DateTime.now()).toUtc();
    final recentFrom = effectiveClosedAt.subtract(const Duration(minutes: 15));
    var recentHistoryRows = const <Map<String, dynamic>>[];
    try {
      recentHistoryRows = List<Map<String, dynamic>>.from(
        await _runWithTableOrderHistorySchemaFallback(
          operation: (includeArchivedAt) {
            var query = _supabase
                .from('table_order_history')
                .select(
                  includeArchivedAt
                      ? 'id, original_order_id, session_key, table_number, '
                            'grand_total, items, status, closed_at, '
                            'archived_at, archived_orders, '
                            'display_table_label, table_display_name, '
                            'table_name'
                      : 'id, original_order_id, session_key, table_number, '
                            'grand_total, items, status, closed_at, '
                            'archived_orders, display_table_label, '
                            'table_display_name, table_name',
                )
                .eq('seller_id', resolvedSellerId)
                .eq('table_number', tableNumber);
            query = includeArchivedAt
                ? query.or(
                    _tableOrderHistorySinceFilter(
                      wideFromIso: recentFrom.toIso8601String(),
                      includeArchivedAt: true,
                    ),
                  )
                : query.gte('closed_at', recentFrom.toIso8601String());
            return query.limit(20).timeout(tableOrderTimeout);
          },
        ),
      );
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == '42P01' ||
          message.contains('does not exist') ||
          message.contains('could not find table') ||
          message.contains('schema cache')) {
        debugPrint(
          '[StoreTableService.ensureTableHistoryRecorded] '
          'table_order_history unavailable, skipping fallback archive.',
        );
        throw Exception(
          'Geçmiş masa tablosu bulunamadı. '
          'Migration 20260407_restaurant_ops_upgrade.sql uygulanmalı.',
        );
      }
      rethrow;
    }

    final fallbackPlan = planTableCloseHistoryFallback(
      tableNumber: tableNumber,
      closedOrders: closedOrders,
      recentHistoryRows: recentHistoryRows,
      closedAt: effectiveClosedAt.toLocal(),
    );

    Map<String, dynamic>? storeTableRow;
    try {
      final tableRows = await _supabase
          .from('store_tables')
          .select()
          .eq('seller_id', resolvedSellerId)
          .eq('table_number', tableNumber)
          .limit(1)
          .timeout(tableOrderTimeout);
      final tables = List<Map<String, dynamic>>.from(tableRows as List);
      if (tables.isNotEmpty) {
        storeTableRow = Map<String, dynamic>.from(tables.first);
      }
    } catch (_) {}

    final identityFields = TableOrderHistoryUtils.historyIdentityForArchive(
      tableNumber: tableNumber,
      tableLabel: tableLabel,
      tableAreaNameHint: areaName,
      storeTableRow: storeTableRow,
      orders: closedOrders,
    );

    if (!fallbackPlan.shouldInsert || serverAlreadyArchived) {
      await _patchRecentHistoryIdentityIfMissing(
        sellerId: resolvedSellerId,
        tableNumber: tableNumber,
        recentHistoryRows: recentHistoryRows,
        identityFields: identityFields,
        closedAt: effectiveClosedAt,
      );
      return false;
    }

    final normalizedLabel = identityFields['display_table_label'];
    final normalizedArea = identityFields['table_area_name'];
    final ordersToArchive = fallbackPlan.ordersToArchive;
    final singleOrder = ordersToArchive.length == 1
        ? ordersToArchive.first
        : null;
    final singleOrderId = singleOrder?['id']?.toString().trim() ?? '';
    final normalizedSessionKey = sessionKey?.trim() ?? '';
    final earliestCreatedAt = ordersToArchive
        .map(
          (order) => DateTime.tryParse(order['created_at']?.toString() ?? ''),
        )
        .whereType<DateTime>()
        .fold<DateTime?>(null, (earliest, current) {
          if (earliest == null || current.isBefore(earliest)) return current;
          return earliest;
        });

    await _runWithTableOrderHistorySchemaFallback(
      operation: (includeArchivedAt) {
        return _supabase
            .from('table_order_history')
            .insert({
              'seller_id': resolvedSellerId,
              'table_number': tableNumber,
              'session_key': normalizedSessionKey.isNotEmpty
                  ? normalizedSessionKey
                  : 'fallback_${resolvedSellerId}_${tableNumber}_${effectiveClosedAt.millisecondsSinceEpoch}',
              'payment_method': paymentMethod,
              if (paymentNote != null && paymentNote.isNotEmpty)
                'payment_note': paymentNote,
              if (waiterId != null && waiterId.isNotEmpty)
                'waiter_id': waiterId,
              if (waiterName != null && waiterName.isNotEmpty)
                'waiter_name': waiterName,
              if (normalizedLabel != null && normalizedLabel.isNotEmpty) ...{
                'display_table_label': normalizedLabel,
                'table_display_name': normalizedLabel,
                'table_name': normalizedLabel,
              },
              if (normalizedArea != null && normalizedArea.isNotEmpty)
                'table_area_name': normalizedArea,
              if (singleOrderId.isNotEmpty) 'original_order_id': singleOrderId,
              if (singleOrder?['items'] != null) 'items': singleOrder!['items'],
              if (singleOrder?['revision'] != null)
                'revision': singleOrder!['revision'],
              if (singleOrder?['last_edit_summary'] != null)
                'last_edit_summary': singleOrder!['last_edit_summary'],
              if (singleOrder?['last_edit_note'] != null)
                'last_edit_note': singleOrder!['last_edit_note'],
              'grand_total': fallbackPlan.grandTotal,
              'archived_orders': ordersToArchive,
              'status': 'closed',
              'closed_at': effectiveClosedAt.toIso8601String(),
              if (includeArchivedAt)
                'archived_at': effectiveClosedAt.toIso8601String(),
              if (earliestCreatedAt != null)
                'opened_at': earliestCreatedAt.toUtc().toIso8601String(),
              'created_at': (earliestCreatedAt ?? effectiveClosedAt)
                  .toUtc()
                  .toIso8601String(),
            })
            .timeout(tableOrderTimeout);
      },
    );
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLE HISTORY (CLOSED ORDERS)
  // ─────────────────────────────────────────────────────────────────────────────


  /// Returns paginated historical (closed) orders for a seller.
  Future<List<Map<String, dynamic>>> getTableOrderHistory({
    required String sellerId,
    int? tableNumber,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    try {
      final rows = await _runWithTableOrderHistorySchemaFallback(
        operation: (includeArchivedAt) {
          var query = _supabase
              .from('table_order_history')
              .select()
              .eq('seller_id', resolvedSellerId);
          if (tableNumber != null && tableNumber > 0) {
            query = query.eq('table_number', tableNumber);
          }
          if (fromDate != null) {
            final wideFrom = fromDate
                .subtract(const Duration(days: 1))
                .toUtc()
                .toIso8601String();
            query = includeArchivedAt
                ? query.or(
                    _tableOrderHistorySinceFilter(
                      wideFromIso: wideFrom,
                      includeArchivedAt: true,
                    ),
                  )
                : query.gte('closed_at', wideFrom);
          }
          if (toDate != null) {
            final wideTo = toDate
                .add(const Duration(days: 1))
                .toUtc()
                .toIso8601String();
            query = query.lte('closed_at', wideTo);
          }
          final fetchLimit = math.max(limit + offset + 50, limit + 200);
          return query
              .order('closed_at', ascending: false)
              .range(offset, offset + fetchLimit - 1)
              .timeout(tableOrderTimeout);
        },
      );
      var list = List<Map<String, dynamic>>.from(rows as List);
      if (fromDate != null || toDate != null) {
        final from = fromDate ?? DateTime(2000);
        final to = toDate ?? DateTime(2100, 12, 31);
        list = list
            .where(
              (row) => TableOrderHistoryUtils.isWithinRange(
                Map<dynamic, dynamic>.from(row),
                from,
                to,
              ),
            )
            .toList(growable: false);
      }
      list = TableOrderHistoryUtils.dedupeHistoryRowsLatestPerChain(list);
      if (list.length > limit) {
        list = list.sublist(0, limit);
      }
      return list;
    } on PostgrestException catch (error) {
      // table_order_history may not exist on older DBs — return empty list
      final msg = error.message.toLowerCase();
      if (error.code == '42P01' ||
          msg.contains('does not exist') ||
          msg.contains('could not find table') ||
          msg.contains('could not find the table') ||
          msg.contains('schema cache')) {
        debugPrint(
          '[StoreTableService] table_order_history not found. '
          'Run migration 20260407_restaurant_ops_upgrade.sql.',
        );
        return const <Map<String, dynamic>>[];
      }
      throw _tableOrderException('Geçmiş sipariş listesi', error);
    } on TimeoutException {
      throw Exception('Geçmiş siparişler alınamadı. Tekrar deneyin.');
    }
  }

  /// Returns true when at least one history row exists for the table since [since].
  Future<bool> hasRecentTableHistory({
    required String sellerId,
    required int tableNumber,
    required DateTime since,
  }) async {
    if (tableNumber <= 0) return false;
    final resolvedSellerId = _resolveSellerId(sellerId);
    final sinceUtc = since.toUtc().toIso8601String();
    try {
      final rows = await _runWithTableOrderHistorySchemaFallback(
        operation: (includeArchivedAt) {
          var query = _supabase
              .from('table_order_history')
              .select('id, table_number, closed_at')
              .eq('seller_id', resolvedSellerId)
              .eq('table_number', tableNumber);
          query = includeArchivedAt
              ? query.or(
                  _tableOrderHistorySinceFilter(
                    wideFromIso: sinceUtc,
                    includeArchivedAt: true,
                  ),
                )
              : query.gte('closed_at', sinceUtc);
          return query
              .order('closed_at', ascending: false)
              .limit(1)
              .timeout(tableOrderTimeout);
        },
      );
      return (rows as List).isNotEmpty;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == '42P01' ||
          message.contains('does not exist') ||
          message.contains('could not find table') ||
          message.contains('schema cache')) {
        return false;
      }
      rethrow;
    }
  }

  /// Re-opens a closed table session by inserting archived items back into
  /// [table_orders]. Does not mutate the history row.
  ///
  /// Guard: throws when the table already has non-terminal active orders.
  Future<List<Map<String, dynamic>>> restoreTableFromHistory({
    required String sellerId,
    required String historyId,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    final normalizedHistoryId = historyId.trim();
    if (resolvedSellerId.isEmpty || normalizedHistoryId.isEmpty) {
      throw Exception('Geçmiş masa geri yüklenemedi: eksik kimlik.');
    }

    Map<String, dynamic>? historyRow;
    try {
      final rows = await _runWithTableOrderHistorySchemaFallback(
        operation: (_) {
          return _supabase
              .from('table_order_history')
              .select()
              .eq('seller_id', resolvedSellerId)
              .eq('id', normalizedHistoryId)
              .limit(1)
              .timeout(tableOrderTimeout);
        },
      );
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        historyRow = Map<String, dynamic>.from(list.first);
      }
    } on PostgrestException catch (error) {
      throw _tableOrderException('Geçmiş masa kaydı', error);
    }

    if (historyRow == null || historyRow.isEmpty) {
      throw Exception('Geçmiş masa kaydı bulunamadı.');
    }

    final tableNumber =
        int.tryParse(historyRow['table_number']?.toString() ?? '') ?? 0;
    if (tableNumber <= 0) {
      throw Exception('Geçmiş masa kaydında geçersiz masa numarası var.');
    }

    final activeOrders = await getTableOrdersByTable(
      sellerId: resolvedSellerId,
      tableNumber: tableNumber,
    );
    final blockingOrders = activeOrders.where((order) {
      return !OrderStatusConstants.isTerminalStatus(
        order['status']?.toString(),
      );
    }).toList(growable: false);
    if (blockingOrders.isNotEmpty) {
      throw Exception(
        'Masa $tableNumber zaten açık. Önce mevcut oturumu kapatın.',
      );
    }

    final archivedOrders = TableOrderHistoryUtils.parseJsonList(
      historyRow['archived_orders'],
    );
    final ordersToRestore = archivedOrders.isNotEmpty
        ? archivedOrders
        : <Map<String, dynamic>>[
            if (TableOrderHistoryUtils.displayItems(historyRow).isNotEmpty)
              <String, dynamic>{
                'items': TableOrderHistoryUtils.displayItems(historyRow),
                'status': historyRow['status']?.toString() ?? 'sent',
                'revision': historyRow['revision'],
                'last_edit_summary': historyRow['last_edit_summary'],
                'last_edit_note': historyRow['last_edit_note'],
                'created_at': historyRow['opened_at'] ?? historyRow['created_at'],
              },
          ];

    if (ordersToRestore.isEmpty) {
      throw Exception('Geri yüklenecek sipariş satırı bulunamadı.');
    }

    Map<String, dynamic>? tableRow;
    try {
      final tableRows = await _supabase
          .from('store_tables')
          .select()
          .eq('seller_id', resolvedSellerId)
          .eq('table_number', tableNumber)
          .limit(1)
          .timeout(tableOrderTimeout);
      final tables = List<Map<String, dynamic>>.from(tableRows as List);
      if (tables.isNotEmpty) {
        tableRow = Map<String, dynamic>.from(tables.first);
      }
    } catch (error) {
      debugPrint(
        '[StoreTableService.restoreTableFromHistory] '
        'table_row_lookup_failed table=$tableNumber error=$error',
      );
    }

    final historyIdentity = TableOrderHistoryUtils.historyIdentityForArchive(
      tableNumber: tableNumber,
      tableLabel: TableOrderHistoryUtils.tableLabel(historyRow),
      tableAreaNameHint: TableOrderHistoryUtils.areaName(historyRow),
      storeTableRow: tableRow,
      orders: ordersToRestore,
    );
    if (tableRow != null) {
      final enrichedTableRow = Map<String, dynamic>.from(tableRow)
        ..addAll(historyIdentity);
      if (historyIdentity['table_area_name']?.isNotEmpty == true) {
        enrichedTableRow['area_name'] = historyIdentity['table_area_name'];
      }
      if (historyIdentity['display_table_label']?.isNotEmpty == true) {
        enrichedTableRow['display_label'] = historyIdentity['display_table_label'];
      }
      tableRow = enrichedTableRow;
    } else if (historyIdentity.isNotEmpty) {
      tableRow = Map<String, dynamic>.from(historyIdentity);
    }

    final restoredOrders = <Map<String, dynamic>>[];
    for (final sourceOrder in ordersToRestore) {
      final items = TableOrderHistoryUtils.parseJsonList(sourceOrder['items']);
      if (items.isEmpty) continue;

      final rawStatus = sourceOrder['status']?.toString().trim() ?? 'sent';
      final restoreStatus = OrderStatusConstants.isTerminalStatus(rawStatus)
          ? 'sent'
          : rawStatus;

      final inserted = await submitTableOrder(
        sellerId: resolvedSellerId,
        tableNumber: tableNumber,
        items: items,
        status: restoreStatus,
        tableRow: tableRow,
        placementSource: 'history_restore',
      );

      final insertedId = inserted['id']?.toString() ?? '';
      final revision = sourceOrder['revision'];
      final lastEditSummary = sourceOrder['last_edit_summary'];
      final lastEditNote = sourceOrder['last_edit_note'];
      if (insertedId.isNotEmpty &&
          (revision != null ||
              (lastEditSummary is Map && lastEditSummary.isNotEmpty) ||
              (lastEditNote?.toString().trim().isNotEmpty ?? false))) {
        final updated = await updateTableOrder(
          insertedId,
          revision: revision is num ? revision.toInt() : null,
          lastEditSummary: lastEditSummary is Map
              ? Map<String, dynamic>.from(lastEditSummary)
              : null,
          lastEditNote: lastEditNote?.toString(),
        );
        restoredOrders.add(updated ?? inserted);
      } else {
        restoredOrders.add(inserted);
      }
    }

    if (restoredOrders.isEmpty) {
      throw Exception('Masa geri yüklenemedi: sipariş satırları boş.');
    }

    debugPrint(
      '[StoreTableService.restoreTableFromHistory] '
      'historyId=$normalizedHistoryId table=$tableNumber '
      'restoredCount=${restoredOrders.length}',
    );
    return restoredOrders;
  }

  /// Deletes a single archived table session from [table_order_history].
  /// Returns `true` only when the row was actually removed (RLS / id mismatch → `false`).
  Future<bool> deleteTableOrderHistoryRecord({
    required String sellerId,
    required String historyId,
  }) async {
    final resolvedSellerId = _resolveSellerId(sellerId);
    final normalizedHistoryId = historyId.trim();
    if (normalizedHistoryId.isEmpty) {
      throw Exception('Geçmiş masa kaydı silinemedi: eksik kimlik.');
    }

    try {
      final deleted = await _supabase
          .from('table_order_history')
          .delete()
          .eq('id', normalizedHistoryId)
          .select('id')
          .timeout(tableOrderTimeout);
      final rows = List<Map<String, dynamic>>.from(deleted as List);
      if (rows.isEmpty) {
        debugPrint(
          '[StoreTableService.deleteTableOrderHistoryRecord] '
          'no_rows_deleted historyId=$normalizedHistoryId seller=$resolvedSellerId',
        );
        return false;
      }
      return true;
    } on PostgrestException catch (error) {
      throw _tableOrderException('Geçmiş masa kaydı silme', error);
    }
  }

  /// After restore → re-close, remove the superseded history row so the list
  /// shows a single chain entry (latest close only).
  Future<bool> supersedeRestoredHistoryOnReclose({
    required String sellerId,
    required String supersededHistoryId,
  }) async {
    final normalizedId = supersededHistoryId.trim();
    if (normalizedId.isEmpty) return false;
    return deleteTableOrderHistoryRecord(
      sellerId: sellerId,
      historyId: normalizedId,
    );
  }

  /// Removes duplicate history rows that share the same [session_key] chain,
  /// keeping only the latest [closed_at] entry (RPC inserts one row per order).
  Future<int> consolidateDuplicateHistoryChain({
    required String sellerId,
    required int tableNumber,
    String? sessionKey,
    DateTime? closedAfter,
  }) async {
    if (tableNumber <= 0) return 0;

    final resolvedSellerId = _resolveSellerId(sellerId);
    final since = (closedAfter ?? DateTime.now())
        .subtract(const Duration(minutes: 30))
        .toUtc();

    List<Map<String, dynamic>> rows;
    try {
      var query = _supabase
          .from('table_order_history')
          .select(
            'id, session_key, table_number, closed_at, original_order_id, '
            'archived_orders',
          )
          .eq('seller_id', resolvedSellerId)
          .eq('table_number', tableNumber)
          .gte('closed_at', since.toIso8601String());
      final normalizedSessionKey = sessionKey?.trim() ?? '';
      if (normalizedSessionKey.isNotEmpty) {
        query = query.eq('session_key', normalizedSessionKey);
      }
      rows = List<Map<String, dynamic>>.from(
        await query.timeout(tableOrderTimeout),
      );
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == '42P01' ||
          message.contains('does not exist') ||
          message.contains('could not find table') ||
          message.contains('schema cache')) {
        return 0;
      }
      throw _tableOrderException('Geçmiş masa zinciri birleştirme', error);
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final chainKey = TableOrderHistoryUtils.historyChainKey(row);
      grouped.putIfAbsent(chainKey, () => <Map<String, dynamic>>[]).add(row);
    }

    var deletedCount = 0;
    for (final group in grouped.values) {
      if (group.length <= 1) continue;
      group.sort((a, b) {
        final aAt =
            TableOrderHistoryUtils.closedAt(a) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bAt =
            TableOrderHistoryUtils.closedAt(b) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });

      final keeper = group.first;
      for (var index = 1; index < group.length; index++) {
        if (!TableOrderHistoryUtils.historyRowIsRedundantCopy(
          keeper: keeper,
          candidate: group[index],
        )) {
          continue;
        }
        final historyId = group[index]['id']?.toString().trim() ?? '';
        if (historyId.isEmpty) continue;
        final deleted = await deleteTableOrderHistoryRecord(
          sellerId: resolvedSellerId,
          historyId: historyId,
        );
        if (deleted) deletedCount++;
      }
    }

    if (deletedCount > 0) {
      debugPrint(
        '[StoreTableService.consolidateDuplicateHistoryChain] '
        'table=$tableNumber session=${sessionKey ?? '-'} deleted=$deletedCount',
      );
    }
    return deletedCount;
  }

  Future<void> _patchRecentHistoryIdentityIfMissing({
    required String sellerId,
    required int tableNumber,
    required List<Map<String, dynamic>> recentHistoryRows,
    required Map<String, String> identityFields,
    required DateTime closedAt,
  }) async {
    if (identityFields.isEmpty || recentHistoryRows.isEmpty) return;

    final candidates = recentHistoryRows.where((row) {
      final rowTableNumber =
          int.tryParse(row['table_number']?.toString() ?? '') ?? 0;
      if (rowTableNumber != tableNumber) return false;
      if (!TableOrderHistoryUtils.historyRowMissingIdentity(row)) return false;
      final rowClosedAt = TableOrderHistoryUtils.closedAt(row);
      if (rowClosedAt == null) return false;
      return closedAt.toLocal().difference(rowClosedAt).abs() <
          const Duration(minutes: 3);
    }).toList(growable: false);

    for (final row in candidates) {
      final historyId = row['id']?.toString().trim() ?? '';
      if (historyId.isEmpty) continue;
      try {
        await _supabase
            .from('table_order_history')
            .update(identityFields)
            .eq('seller_id', sellerId)
            .eq('id', historyId)
            .timeout(tableOrderTimeout);
        debugPrint(
          '[StoreTableService._patchRecentHistoryIdentityIfMissing] '
          'historyId=$historyId table=$tableNumber patched=${identityFields.keys.join(',')}',
        );
      } catch (error) {
        debugPrint(
          '[StoreTableService._patchRecentHistoryIdentityIfMissing] '
          'historyId=$historyId error=$error',
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLE TRANSFER
  // ─────────────────────────────────────────────────────────────────────────────

  /// Transfers orders between tables via the RPC.
  /// A failed RPC does not update `table_orders` from the client.
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
          .rpc(
            'transfer_table_orders',
            params: {
              'p_seller_id': sellerId,
              'p_from_table': fromTable,
              'p_to_table': toTable,
              'p_transfer_type': transferType,
              'p_item_ids': itemIds,
              if (waiterId != null && waiterId.isNotEmpty)
                'p_waiter_id': waiterId,
              if (waiterName != null && waiterName.isNotEmpty)
                'p_waiter_name': waiterName,
              if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
            },
          )
          .timeout(tableOrderTimeout);
      if (result is Map) return Map<String, dynamic>.from(result);
      return const <String, dynamic>{'success': true};
    } on PostgrestException catch (error) {
      if (directTableOrderWriteAllowedAfterRpcFailure(
        code: error.code,
        message: error.message,
      )) {
        throw StateError('Doğrudan masa yazımı kapalı.');
      }
      throw _tableOrderException('Masa aktarma', error);
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
    final to = (toDate ?? DateTime.now()).toUtc().toIso8601String();
    try {
      final rows = await _supabase
          .rpc(
            'get_waiter_performance',
            params: {'p_seller_id': sellerId, 'p_from': from, 'p_to': to},
          )
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
          .rpc(
            'get_product_recommendations',
            params: {
              'p_seller_id': sellerId,
              'p_product_ids': currentProductIds,
              'p_limit': limit,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (rows is List) {
        return List<Map<String, dynamic>>.from(rows.cast<Map>());
      }
      return const <Map<String, dynamic>>[];
    } catch (error) {
      debugPrint(
        '[StoreTableService] getProductRecommendations failed: $error',
      );
      return const <Map<String, dynamic>>[];
    }
  }
}
