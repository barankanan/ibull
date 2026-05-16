import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/runtime_config.dart';
import 'desktop_print_ports.dart';
import 'local_print_service.dart';

class PrintStationService implements PrintStationServicePort {
  PrintStationService({
    SupabaseClient? client,
    LocalPrintService? localPrintService,
  }) : _client = client ?? Supabase.instance.client,
       _localPrintService = localPrintService;

  static const String _kDeviceModeKey = 'ibul_print_station_device_mode_v1';
  static const Duration _stationHeartbeatGrace = Duration(seconds: 45);

  final SupabaseClient _client;
  final LocalPrintService? _localPrintService;

  LocalPrintService _service() => _localPrintService ?? LocalPrintService();

  @override
  Future<bool> isThisDevicePrintStation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDeviceModeKey) ?? false;
  }

  @override
  Future<void> setThisDevicePrintStation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeviceModeKey, value);
  }

  @override
  String currentPlatformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  String currentDeviceName() {
    final platform = currentPlatformLabel();
    return 'ibul-$platform-device';
  }

  String defaultPrintStationPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return 'macos';
      case TargetPlatform.windows:
      case TargetPlatform.android:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'windows';
    }
  }

  @override
  String normalizeStationPlatform(String? value) {
    final raw = value?.trim().toLowerCase() ?? '';
    if (raw == 'macbook' || raw == 'mac' || raw == 'darwin') {
      return 'macos';
    }
    if (raw == 'win' || raw == 'windows') {
      return 'windows';
    }
    return defaultPrintStationPlatform();
  }

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async {
    if (restaurantId.trim().isEmpty) return null;
    final row = await _client
        .from('restaurant_print_station_configs')
        .select()
        .eq('restaurant_id', restaurantId.trim())
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  @override
  bool isStationOnline(Map<String, dynamic>? config) {
    if (config == null) return false;
    final bridgeEnabled = config['bridge_enabled'] == true;
    if (!bridgeEnabled) return false;
    final lastSeenAt = DateTime.tryParse(
      config['last_seen_at']?.toString() ?? '',
    );
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt.toLocal()) <=
        _stationHeartbeatGrace;
  }

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) {
    final queue = queueStatus?['queue'];
    final normalizedQueue = queue is Map<String, dynamic>
        ? queue
        : (queue is Map ? Map<String, dynamic>.from(queue) : null);
    if (normalizedQueue == null) return false;
    final enabled = normalizedQueue['enabled'] == true;
    final ready = normalizedQueue['ready'] != false;
    return enabled && ready;
  }

  bool isBridgeHealthy(Map<String, dynamic>? health) {
    if (health == null || health.isEmpty) return false;
    if (health['ok'] == false) return false;
    return !_containsExplicitFalse(health['printer']);
  }

  bool isLocalBridgeOperational({
    Map<String, dynamic>? queueStatus,
    Map<String, dynamic>? bridgeHealth,
    bool bridgeReachable = false,
  }) {
    if (isLocalStationReady(queueStatus)) {
      return true;
    }
    if (isBridgeHealthy(bridgeHealth)) {
      return true;
    }
    return bridgeReachable && bridgeHealth?['ok'] == true;
  }

  String offlineWarningMessage() {
    return 'Yazıcı merkezi çevrimdışı. Sipariş alındı ama fiş henüz basılmadı.';
  }

  @override
  Future<Map<String, dynamic>?> saveStationConfiguration({
    required String restaurantId,
    required String deviceName,
    required String platformName,
    required String receiptPrinterId,
    required String receiptPrinterName,
    required String kitchenPrinterId,
    required String kitchenPrinterName,
    Map<String, dynamic>? roleMappings,
  }) async {
    final now = DateTime.now().toIso8601String();
    final row = await _client
        .from('restaurant_print_station_configs')
        .upsert({
          'restaurant_id': restaurantId.trim(),
          'bridge_enabled': true,
          'bridge_status': 'configuring',
          'device_name': deviceName.trim(),
          'device_platform': platformName.trim(),
          'adisyon_printer_id': receiptPrinterId.trim(),
          'adisyon_printer_name': receiptPrinterName.trim(),
          'kitchen_printer_id': kitchenPrinterId.trim(),
          'kitchen_printer_name': kitchenPrinterName.trim(),
          ...?roleMappings == null
              ? null
              : <String, dynamic>{'role_mappings': roleMappings},
          'updated_at': now,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async {
    final payload = <String, dynamic>{
      'restaurant_id': restaurantId.trim(),
      ...fields,
    };
    try {
      final row = await _client
          .from('restaurant_print_station_configs')
          .upsert(payload)
          .select()
          .single();
      return Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyPrintStationConfigError(error));
    }
  }

  /// Maps missing-column / stale schema cache errors to an actionable Turkish message.
  String _friendlyPrintStationConfigError(PostgrestException error) {
    final combined =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    if (error.code == 'PGRST204' &&
        combined.contains('print_system_enabled')) {
      return 'Supabase şemasında restaurant_print_station_configs.print_system_enabled '
          'kolonu yok veya PostgREST önbelleği güncel değil. SQL Editor’de bu kolonu '
          'ekleyin (migration: 20260504 veya 20260507_ensure_print_system_enabled_and_reload_schema.sql) '
          've ardından notify pgrst, \'reload schema\'; çalıştırın. '
          'Teknik: ${error.message}';
    }
    return error.message;
  }

  @override
  Future<Map<String, dynamic>?> configureLocalBridgeAsPrintStation({
    required String restaurantId,
    required Session session,
    required String deviceName,
    required String platformName,
    required String receiptPrinterId,
    required String receiptPrinterName,
    required String kitchenPrinterId,
    required String kitchenPrinterName,
    String? bridgeTransportMode,
    String? bridgePrinterQueue,
    String? bridgeUsbVendorId,
    String? bridgeUsbProductId,
  }) async {
    final service = _service();
    try {
      return await service.configurePrintStation({
        'enabled': true,
        'restaurant_id': restaurantId.trim(),
        'supabase_url': AppRuntimeConfig.supabaseUrl,
        'supabase_anon_key': AppRuntimeConfig.supabaseAnonKey,
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'user_id': session.user.id,
        'device_name': deviceName.trim(),
        'device_platform': platformName.trim(),
        'adisyon_printer_id': receiptPrinterId.trim(),
        'adisyon_printer_name': receiptPrinterName.trim(),
        'kitchen_printer_id': kitchenPrinterId.trim(),
        'kitchen_printer_name': kitchenPrinterName.trim(),
        if (bridgeTransportMode != null &&
            bridgeTransportMode.trim().isNotEmpty)
          'bridge_transport_mode': bridgeTransportMode.trim(),
        if (bridgePrinterQueue != null && bridgePrinterQueue.trim().isNotEmpty)
          'bridge_printer_queue': bridgePrinterQueue.trim(),
        if (bridgeUsbVendorId != null && bridgeUsbVendorId.trim().isNotEmpty)
          'bridge_usb_vendor_id': bridgeUsbVendorId.trim(),
        if (bridgeUsbProductId != null && bridgeUsbProductId.trim().isNotEmpty)
          'bridge_usb_product_id': bridgeUsbProductId.trim(),
      });
    } finally {
      if (_localPrintService == null) {
        service.dispose();
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async {
    final service = _service();
    try {
      return await service.queueStatus();
    } finally {
      if (_localPrintService == null) {
        service.dispose();
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(
    String restaurantId,
  ) async {
    final normalizedRestaurantId = restaurantId.trim();
    if (normalizedRestaurantId.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final response = await _client
        .from('print_jobs')
        .select()
        .eq('restaurant_id', normalizedRestaurantId)
        .eq('status', 'paused_by_operator')
        .order('created_at', ascending: true)
        .limit(100);
    return response
        .whereType<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async {
    final service = _service();
    final previousConfig = await fetchStationConfig(restaurantId);
    final priorEnabled =
        previousEnabled ?? previousConfig?['print_system_enabled'] == true;
    var localUpdated = false;
    try {
      final localResult = await service.configurePrintStationStrict(
        {'print_system_enabled': enabled},
      );
      if (localResult == null || localResult['ok'] != true) {
        throw Exception(
          localResult?['error']?.toString().trim().isNotEmpty == true
              ? localResult!['error'].toString().trim()
              : 'Yerel bridge ayarı güncellenemedi.',
        );
      }
      localUpdated = true;
      final patched = await patchStationConfiguration(
        restaurantId: restaurantId,
        fields: {
          'print_system_enabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      if (patched == null) {
        throw Exception('Bulut ayarı güncellenemedi.');
      }
      return true;
    } catch (error) {
      if (localUpdated && priorEnabled != enabled) {
        try {
          await service.configurePrintStationStrict(
            {'print_system_enabled': priorEnabled},
          );
        } catch (_) {
          // ignore revert failures
        }
      }
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(
        message.isEmpty ? 'Baskı sistemi güncellenemedi.' : message,
      );
    } finally {
      if (_localPrintService == null) {
        service.dispose();
      }
    }
  }

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedJobId = jobId.trim();
    if (normalizedRestaurantId.isEmpty || normalizedJobId.isEmpty) {
      return false;
    }

    final now = DateTime.now().toIso8601String();
    final response = await _client
        .from('print_jobs')
        .update(<String, dynamic>{
          'status': 'pending',
          'updated_at': now,
          'last_error': null,
        })
        .eq('restaurant_id', normalizedRestaurantId)
        .eq('id', normalizedJobId)
        .select();
    return response.isNotEmpty;
  }

  Future<Map<String, dynamic>> enqueueReceiptPrintJob({
    required String restaurantId,
    required int tableNumber,
    required Map<String, dynamic> payload,
    String? waiterId,
    String? waiterName,
    String? sourceDevice,
  }) async {
    final response = await _enqueueReceiptPrintJobRpc(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      payload: payload,
      waiterId: waiterId,
      waiterName: waiterName,
      sourceDevice: sourceDevice,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{};
  }

  Future<bool> isEffectivelyOnline(String restaurantId) async {
    final service = _service();
    try {
      final localQueue = await service.queueStatus();
      final localHealth = await service.health();
      if (isLocalBridgeOperational(
        queueStatus: localQueue,
        bridgeHealth: localHealth,
        bridgeReachable: localHealth != null && localHealth.isNotEmpty,
      )) {
        return true;
      }
    } catch (_) {
      // Fall through to remote status.
    } finally {
      if (_localPrintService == null) {
        service.dispose();
      }
    }
    final remote = await fetchStationConfig(restaurantId);
    return isStationOnline(remote);
  }

  bool _containsExplicitFalse(Object? value) {
    if (value == false) return true;
    if (value is Map) {
      for (final entry in value.values) {
        if (_containsExplicitFalse(entry)) {
          return true;
        }
      }
    }
    if (value is List) {
      for (final entry in value) {
        if (_containsExplicitFalse(entry)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<dynamic> _enqueueReceiptPrintJobRpc({
    required String restaurantId,
    required int tableNumber,
    required Map<String, dynamic> payload,
    required String? waiterId,
    required String? waiterName,
    required String? sourceDevice,
  }) async {
    try {
      return await _client.rpc(
        'create_adisyon_print_job',
        params: {
          'p_restaurant_id': restaurantId,
          'p_table_number': tableNumber,
          'p_payload': payload,
          'p_waiter_id': (waiterId == null || waiterId.trim().isEmpty)
              ? null
              : waiterId,
          'p_waiter_name': waiterName,
          'p_source_device': sourceDevice ?? currentPlatformLabel(),
        },
      );
    } on PostgrestException catch (error) {
      throw Exception(_friendlyReceiptQueueError(error));
    }
  }

  /// Geçmiş (kapanmış) bir masa için adisyon yeniden basımı.
  ///
  /// Canlı `table_orders` satırı oluşturmaz; sadece print_jobs kuyruğuna
  /// "(ESKİ MASA)" başlıklı bir adisyon kaydı düşer.
  Future<Map<String, dynamic>> enqueueAdisyonReprintPrintJob({
    required String restaurantId,
    required int tableNumber,
    required Map<String, dynamic> payload,
    String? waiterId,
    String? waiterName,
    String? sourceDevice,
    String? historyRecordId,
  }) async {
    try {
      final response = await _client.rpc(
        'create_adisyon_reprint_print_job',
        params: {
          'p_restaurant_id': restaurantId,
          'p_table_number': tableNumber,
          'p_payload': payload,
          'p_waiter_id': (waiterId == null || waiterId.trim().isEmpty)
              ? null
              : waiterId,
          'p_waiter_name': waiterName,
          'p_source_device': sourceDevice ?? currentPlatformLabel(),
          'p_history_id':
              (historyRecordId == null || historyRecordId.trim().isEmpty)
              ? null
              : historyRecordId,
        },
      );
      if (response is Map<String, dynamic>) return response;
      if (response is Map) return Map<String, dynamic>.from(response);
      return <String, dynamic>{};
    } on PostgrestException catch (error) {
      throw Exception(_friendlyReceiptQueueError(error));
    }
  }

  /// Geçmiş (kapanmış) bir masa için mutfak fişi yeniden basımı.
  Future<Map<String, dynamic>> enqueueKitchenReprintPrintJob({
    required String restaurantId,
    required int tableNumber,
    required Map<String, dynamic> payload,
    String? waiterId,
    String? waiterName,
    String? sourceDevice,
    String? historyRecordId,
  }) async {
    try {
      final response = await _client.rpc(
        'create_kitchen_reprint_print_job',
        params: {
          'p_restaurant_id': restaurantId,
          'p_table_number': tableNumber,
          'p_payload': payload,
          'p_waiter_id': (waiterId == null || waiterId.trim().isEmpty)
              ? null
              : waiterId,
          'p_waiter_name': waiterName,
          'p_source_device': sourceDevice ?? currentPlatformLabel(),
          'p_history_id':
              (historyRecordId == null || historyRecordId.trim().isEmpty)
              ? null
              : historyRecordId,
        },
      );
      if (response is Map<String, dynamic>) return response;
      if (response is Map) return Map<String, dynamic>.from(response);
      return <String, dynamic>{};
    } on PostgrestException catch (error) {
      throw Exception(_friendlyKitchenReprintError(error));
    }
  }

  String _friendlyReceiptQueueError(PostgrestException error) {
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    if (error.code == '42501' ||
        details.contains('permission denied') ||
        details.contains('bu restoran için işlem yetkiniz yok') ||
        details.contains('row-level security')) {
      return 'Adisyon kuyruğa alınamadı. Garson hesabının bu restoranda aktif '
          'yazdırma yetkisi yok. Supabase tarafında store_sub_admins kaydında '
          'email veya telefon eşleşmesi gerekli.';
    }
    if (details.contains('could not find the function') ||
        details.contains('does not exist')) {
      return 'Geçmiş masa yeniden basımı için RPC bulunamadı. Lütfen '
          'SUPABASE_TABLE_HISTORY_REPRINT.sql migration\'ını çalıştırın.';
    }
    return error.message;
  }

  String _friendlyKitchenReprintError(PostgrestException error) {
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    if (error.code == '42501' ||
        details.contains('permission denied') ||
        details.contains('bu restoran için işlem yetkiniz yok') ||
        details.contains('row-level security')) {
      return 'Mutfak fişi kuyruğa alınamadı. Garson hesabının bu restoranda '
          'aktif yazdırma yetkisi yok.';
    }
    if (details.contains('could not find the function') ||
        details.contains('does not exist')) {
      return 'Geçmiş masa mutfak yeniden basımı için RPC bulunamadı. Lütfen '
          'SUPABASE_TABLE_HISTORY_REPRINT.sql migration\'ını çalıştırın.';
    }
    return error.message;
  }
}
