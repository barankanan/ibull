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
import 'close_table_workflow.dart';
import 'table_close_history_fallback.dart';
import 'table_order_history_utils.dart';

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
      final rows = await query.order('table_number', ascending: true);
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
      final rows = await query.order('name', ascending: true);
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
      rethrow;
    } on TimeoutException {
      return const <int>{};
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
    final payload = <String, dynamic>{
      'seller_id': sellerId,
      'table_number': tableNumber,
      'items': items,
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
    List<Map<String, dynamic>> tableOrders = const <Map<String, dynamic>>[];
    try {
      tableOrders = await _fetchTableOrdersForGarson(
        sellerId: resolvedSellerId,
        tableNumber: tableNumber,
      );
      logGarsonActiveOrdersFetchResult(
        restaurantId: resolvedSellerId,
        source: 'table_orders',
        orders: tableOrders,
      );
    } on PostgrestException catch (error, stack) {
      logGarsonActiveOrdersFetchError(
        restaurantId: resolvedSellerId,
        source: 'table_orders',
        error: error,
        stack: stack,
      );
    } on TimeoutException catch (error, stack) {
      logGarsonActiveOrdersFetchError(
        restaurantId: resolvedSellerId,
        source: 'table_orders',
        error: error,
        stack: stack,
      );
    } catch (error, stack) {
      logGarsonActiveOrdersFetchError(
        restaurantId: resolvedSellerId,
        source: 'table_orders',
        error: error,
        stack: stack,
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
    List<Map<String, dynamic>> restaurantOrders =
        const <Map<String, dynamic>>[];
    try {
      restaurantOrders = await _fetchRestaurantOrdersForGarson(
        restaurantId: resolvedSellerId,
        tableNumber: tableNumber,
      );
      logGarsonActiveOrdersFetchResult(
        restaurantId: resolvedSellerId,
        source: 'orders',
        orders: restaurantOrders,
      );
    } catch (error, stack) {
      logGarsonActiveOrdersFetchError(
        restaurantId: resolvedSellerId,
        source: 'orders',
        error: error,
        stack: stack,
      );
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
        .select()
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
          'line_total, item_note)',
        )
        .eq('restaurant_id', restaurantId)
        .or('order_type.eq.table,delivery_type.eq.table')
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
    final candidateTableNumbers = <int>{};
    for (final raw in rawOrders) {
      final tableId = raw['table_id']?.toString().trim() ?? '';
      final storeTable = tableId.isEmpty ? null : storeTablesById[tableId];
      final tableNo = _parseTableNumberValue(
        storeTable?['table_number'] ?? raw['table_number'],
      );
      if (tableNo > 0) candidateTableNumbers.add(tableNo);
    }
    final latestClosedByTable = await _loadLatestClosedMomentsByTableNumber(
      sellerId: restaurantId,
      tableNumbers: candidateTableNumbers,
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
      final mappedTableNumber = _parseTableNumberValue(mapped['table_number']);
      final latestClosedAt = latestClosedByTable[mappedTableNumber];
      final activityAt = DateTime.tryParse(
        raw['updated_at']?.toString() ?? raw['created_at']?.toString() ?? '',
      )?.toLocal();
      if (latestClosedAt != null &&
          activityAt != null &&
          !activityAt.isAfter(latestClosedAt)) {
        debugPrint(
          '[GARSON_REOPEN_GUARD] '
          'restaurant_id=$restaurantId '
          'table_number=$mappedTableNumber '
          'order_id=${raw['id']} '
          'order_activity=${activityAt.toIso8601String()} '
          'latest_closed_at=${latestClosedAt.toIso8601String()} '
          'action=suppress_stale_orders_row',
        );
        continue;
      }
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

  Future<Map<int, DateTime>> _loadLatestClosedMomentsByTableNumber({
    required String sellerId,
    required Set<int> tableNumbers,
  }) async {
    if (tableNumbers.isEmpty) return const <int, DateTime>{};
    try {
      final rows = await _runWithTableOrderHistorySchemaFallback(
        operation: (includeArchivedAt) {
          return _supabase
              .from('table_order_history')
              .select(
                includeArchivedAt
                    ? 'table_number, closed_at, archived_at'
                    : 'table_number, closed_at',
              )
              .eq('seller_id', sellerId)
              .inFilter('table_number', tableNumbers.toList(growable: false))
              .limit(tableNumbers.length * 8)
              .timeout(tableOrderTimeout);
        },
      );
      final latest = <int, DateTime>{};
      for (final raw in (rows as List)) {
        final row = Map<dynamic, dynamic>.from(raw as Map);
        final tableNumber = _parseTableNumberValue(row['table_number']);
        if (tableNumber <= 0) continue;
        final closedAt = TableOrderHistoryUtils.closedAt(row);
        if (closedAt == null) continue;
        final previous = latest[tableNumber];
        if (previous == null || closedAt.isAfter(previous)) {
          latest[tableNumber] = closedAt;
        }
      }
      return latest;
    } catch (_) {
      return const <int, DateTime>{};
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
          .or('order_type.eq.table,delivery_type.eq.table')
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
    String? tableLabel,
    String? areaName,
  }) async {
    final normalizedLabel = tableLabel?.trim();
    final normalizedArea = areaName?.trim();
    try {
      await _supabase
          .rpc(
            'close_table_with_history',
            params: {
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
              if (normalizedLabel != null && normalizedLabel.isNotEmpty) ...{
                'p_table_name': normalizedLabel,
                'p_display_table_label': normalizedLabel,
              },
              if (normalizedArea != null && normalizedArea.isNotEmpty)
                'p_table_area_name': normalizedArea,
            },
          )
          .timeout(tableOrderTimeout);
      // BUG-FIX (Reopen Bug): the RPC only clears `table_orders`; mirror the
      // close into the customer-facing `orders` table here as well.  Without
      // this, customer-placed orders survive and the table re-appears active
      // on the next refresh.
      await closeRestaurantOrdersForTable(
        sellerId: sellerId,
        tableNumber: tableNumber,
      );
    } on PostgrestException catch (error) {
      // Fall back to client-side archive + delete if RPC unavailable (older DB)
      debugPrint(
        '[StoreTableService] closeTableWithHistory RPC failed ($error). Falling back to client-side archive.',
      );
      await _closeTableClientSide(
        sellerId: sellerId,
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
        waiterId: waiterId,
        waiterName: waiterName,
        sessionKey: sessionKey,
        tableLabel: tableLabel,
        areaName: areaName,
      );
    } on TimeoutException {
      throw Exception('Masa kapatma zaman aşımına uğradı. Tekrar deneyin.');
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
  }) async {
    if (tableNumber <= 0 || closedOrders.isEmpty) return false;

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
        return false;
      }
      rethrow;
    }

    final fallbackPlan = planTableCloseHistoryFallback(
      closedOrders: closedOrders,
      recentHistoryRows: recentHistoryRows,
    );
    if (!fallbackPlan.shouldInsert) return false;

    final normalizedLabel = tableLabel?.trim();
    final normalizedArea = areaName?.trim();
    final ordersToArchive = fallbackPlan.ordersToArchive;
    final singleOrder = ordersToArchive.length == 1
        ? ordersToArchive.first
        : null;
    final singleOrderId = singleOrder?['id']?.toString().trim() ?? '';
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
              'session_key':
                  'fallback_${resolvedSellerId}_${tableNumber}_${effectiveClosedAt.millisecondsSinceEpoch}',
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

  /// **Fallback** for [closeTableWithHistory] when the RPC is unavailable or
  /// fails (e.g. an internal DB trigger blocks the server-side DELETE).
  ///
  /// Strategy:
  ///   1. Fetch active orders by (sellerId, tableNumber).
  ///   2. Archive each to [table_order_history] — **best-effort**: a failed
  ///      INSERT is logged but does NOT abort the close. Closing without a
  ///      history record is preferred over leaving a table permanently stuck.
  ///   3. Attempt a bulk DELETE via [closeTableOrders].
  ///      If the DELETE fails (e.g. a DB trigger raises P0001), fall back to
  ///      per-order UPDATE status = 'closed'. Both outcomes make the orders
  ///      invisible on the Garson board because [normalizeTableOrderToGarsonBoardOrder]
  ///      filters out any terminal-status row.
  ///   4. Verify by primary-key that every targeted order is either deleted or
  ///      carries a terminal status. Throws on any remaining active orders.
  Future<void> _closeTableClientSide({
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
    // ── 1. Fetch active orders — propagate on error (no silent empty fallback).
    List<Map<String, dynamic>> activeOrders;
    try {
      final rows = await _supabase
          .from('table_orders')
          .select()
          .eq('seller_id', sellerId)
          .eq('table_number', tableNumber)
          .timeout(tableOrderTimeout);
      activeOrders = List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (error) {
      debugPrint(
        '[StoreTableService._closeTableClientSide] '
        'fetch_active_orders failed: $error',
      );
      throw _tableOrderException(
        'Masa siparişlerini alma (kapatma öncesi)',
        error,
      );
    } on TimeoutException {
      throw Exception(
        'Masa siparişleri alınamadı (zaman aşımı). '
        'Bağlantıyı kontrol edip tekrar deneyin.',
      );
    }

    if (activeOrders.isEmpty) return; // nothing to close

    // Record IDs for ID-based verification at the end.
    final targetIds = activeOrders
        .map((o) => o['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    // ── 2. Archive — best-effort. A failed history INSERT must NOT block close.
    final session =
        sessionKey ??
        'session_${sellerId}_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
    final archivedAt = DateTime.now().toUtc().toIso8601String();
    var grandTotalAll = 0.0;
    for (final order in activeOrders) {
      for (final item in TableOrderHistoryUtils.parseJsonList(order['items'])) {
        final normalized = MixedServiceOrder.normalizeOrderItem(item);
        grandTotalAll += MixedServiceOrder.itemLineTotal(normalized);
      }
    }

    final normalizedLabel = tableLabel?.trim();
    final normalizedArea = areaName?.trim();
    var historyArchived = false;
    try {
      await _runWithTableOrderHistorySchemaFallback(
        operation: (includeArchivedAt) {
          return _supabase
              .from('table_order_history')
              .insert({
                'seller_id': sellerId,
                'table_number': tableNumber,
                'session_key': session,
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
                'grand_total': grandTotalAll,
                'archived_orders': activeOrders,
                'status': 'closed',
                'closed_at': archivedAt,
                if (includeArchivedAt) 'archived_at': archivedAt,
              })
              .timeout(tableOrderTimeout);
        },
      );
      historyArchived = true;
      debugPrint(
        '[StoreTableService._closeTableClientSide] '
        'history_insert=ok_hotfix table=$tableNumber total=$grandTotalAll',
      );
    } catch (hotfixErr) {
      debugPrint(
        '[StoreTableService._closeTableClientSide] '
        'history_insert=hotfix_failed table=$tableNumber error=$hotfixErr',
      );
    }

    if (!historyArchived) {
      for (final order in activeOrders) {
        final items = order['items'] ?? [];
        var grandTotal = 0.0;
        for (final item in TableOrderHistoryUtils.parseJsonList(items)) {
          final normalized = MixedServiceOrder.normalizeOrderItem(item);
          grandTotal += MixedServiceOrder.itemLineTotal(normalized);
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
                'closed_at': archivedAt,
                'created_at': order['created_at'] ?? archivedAt,
              })
              .timeout(tableOrderTimeout);
          debugPrint(
            '[StoreTableService._closeTableClientSide] '
            'history_insert=ok orderId=${order['id']}',
          );
        } catch (archiveErr) {
          debugPrint(
            '[StoreTableService._closeTableClientSide] '
            'history_insert=failed (best-effort, continuing close) '
            'orderId=${order['id']} error=$archiveErr',
          );
        }
      }
    }

    // ── Steps 3 & 4: delegated to the pure [runCloseTableFallbackWorkflow].
    // This separation keeps the fallback algorithm testable without a real
    // Supabase client — tests inject simple lambda mocks instead.
    await runCloseTableFallbackWorkflow(
      orderIds: targetIds,
      bulkDelete: () =>
          closeTableOrders(sellerId: sellerId, tableNumber: tableNumber),
      deleteById: (id) => deleteTableOrder(id),
      markClosed: (id) async {
        await _supabase
            .from('table_orders')
            .update({
              'status': 'closed',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', id)
            .timeout(tableOrderTimeout);
      },
      verifyByIds: (ids) => getTableOrdersByIds(ids),
      onEvent: (event) {
        debugPrint(
          '[StoreTableService._closeTableClientSide] '
          'table=$tableNumber $event',
        );
      },
    );

    // BUG-FIX (Reopen Bug): also close any matching customer-side `orders`
    // rows.  Note that `closeTableOrders` above already calls this on its
    // happy path; this extra call covers the failure-and-retry case where
    // we land in the per-order fallback loop without ever hitting the
    // happy-path mirror update.  It is idempotent because the filter excludes
    // already-terminal rows.
    await closeRestaurantOrdersForTable(
      sellerId: sellerId,
      tableNumber: tableNumber,
    );
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
      final rows = await _runWithTableOrderHistorySchemaFallback(
        operation: (includeArchivedAt) {
          var query = _supabase
              .from('table_order_history')
              .select()
              .eq('seller_id', sellerId);
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
          return query.limit(limit + 200).timeout(tableOrderTimeout);
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
      list.sort((a, b) {
        final aAt = TableOrderHistoryUtils.closedAt(
          Map<dynamic, dynamic>.from(a),
        );
        final bAt = TableOrderHistoryUtils.closedAt(
          Map<dynamic, dynamic>.from(b),
        );
        return (bAt ?? DateTime(2000)).compareTo(aAt ?? DateTime(2000));
      });
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
      debugPrint(
        '[StoreTableService] transferTableOrders RPC failed ($error). Falling back to client-side.',
      );
      // Client-side fallback: update all source orders to toTable
      await _supabase
          .from('table_orders')
          .update({
            'table_number': toTable,
            'updated_at': DateTime.now().toIso8601String(),
          })
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
