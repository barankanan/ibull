import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb, setEquals;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/desktop_printer_setup_models.dart';
import '../models/printer_profile.dart';
import '../models/windows_printer_classification.dart';
import '../models/printer_model.dart';
import '../models/station_printer_model.dart';
import 'desktop_print_ports.dart';
import 'local_print_service.dart';
import 'macos_admin_release_models.dart';
import 'macos_usb_permission_recovery_service.dart';
import '../models/turkish_encoding_calibration.dart';
import 'printer_encoding_profile_store.dart';
import 'printer_event_log_service.dart';
import 'print_station_service.dart';
import 'printer_repository.dart';
import 'working_printer_store.dart';
import 'kitchen_print_trace_log.dart';
import 'kitchen_routing_service.dart';

typedef LocalPrintServiceFactory = LocalPrintService Function();

class PrintPayload {
  const PrintPayload({required this.documentType, required this.body});

  final String documentType;
  final Map<String, dynamic> body;

  bool get isReceipt => documentType == 'receipt';

  factory PrintPayload.testForRole(PrinterSetupRole role) {
    final now = DateTime.now().toLocal().toIso8601String();
    if (role == PrinterSetupRole.mutfak) {
      return PrintPayload(
        documentType: 'kitchen',
        body: <String, dynamic>{
          'title': 'MUTFAK TEST FISI',
          'store_name': 'ibul',
          'order_no': 'TEST',
          'table_no': 'TEST',
          'table_name': 'Test Masa',
          'area_name': 'Test Alan',
          'waiter_name': 'Sistem',
          'job_type': 'test_receipt',
          'datetime': now,
          'items': const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'kitchen-test-item',
              'name': 'Mutfak Test Urunu',
              'quantity': 1,
              'note': 'Rol test baskisi',
            },
          ],
        },
      );
    }
    return PrintPayload(
      documentType: 'receipt',
      body: <String, dynamic>{
        'store_name': 'ibul',
        'branch': 'TEST',
        'phone': '-',
        'table_no': 'TEST',
        'datetime': now,
        'items': const <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Adisyon Test Fisi',
            'qty': 1,
            'price': 0,
            'total': 0,
          },
        ],
        'subtotal': 0,
        'discount': 0,
        'grand_total': 0,
        'footer_note': 'Rol test baskisi',
      },
    );
  }

  factory PrintPayload.fromQueuedJob(Map<String, dynamic> body) {
    final normalizedBody = Map<String, dynamic>.from(body);
    final documentType =
        (normalizedBody['document_type']?.toString().trim().toLowerCase() ?? '')
            .isEmpty
        ? 'kitchen'
        : normalizedBody['document_type']!.toString().trim().toLowerCase();
    return PrintPayload(documentType: documentType, body: normalizedBody);
  }

  factory PrintPayload.receipt(Map<String, dynamic> body) {
    return PrintPayload(
      documentType: 'receipt',
      body: Map<String, dynamic>.from(body),
    );
  }
}

class QueuedPrintPayloadResolution {
  const QueuedPrintPayloadResolution({
    required this.payload,
    required this.printer,
    required this.resolutionSource,
    this.userMessage,
  });

  final Map<String, dynamic> payload;
  final UnifiedPrinterModel? printer;
  final String resolutionSource;
  final String? userMessage;
}

class _SnapshotCacheEntry {
  const _SnapshotCacheEntry({required this.snapshot, required this.fetchedAt});

  final PrinterSetupSnapshot snapshot;
  final DateTime fetchedAt;
}

class _PhysicalPrintVerification {
  const _PhysicalPrintVerification({
    required this.ok,
    required this.status,
    required this.message,
  });

  final bool ok;
  final String status;
  final String message;
}

class _KitchenDbRoutingExpectation {
  const _KitchenDbRoutingExpectation({required this.expected});

  final ExpectedKitchenPrinterResolution expected;

  String get source => expected.source;
  PrinterModel get printer => expected.printer;
  String? get stationId => expected.stationId;
  String? get stationName => expected.stationName;

  bool get isEthernet => expected.isTcp;
}

class DesktopPrintOrchestrator {
  DesktopPrintOrchestrator({
    PrinterRepositoryPort? printerRepository,
    PrintStationServicePort? printStationService,
    LocalPrintServiceFactory? printServiceFactory,
    MacosUsbPermissionRecoveryService? usbPermissionRecoveryService,
    PrinterEventLogService? eventLogService,
    PrinterEncodingProfileStore? encodingProfileStore,
  }) : _printerRepository = printerRepository ?? PrinterRepository(),
       _printStationService = printStationService ?? PrintStationService(),
       _printServiceFactory =
           printServiceFactory ?? (() => LocalPrintService()),
       _usbPermissionRecoveryService =
           usbPermissionRecoveryService ?? MacosUsbPermissionRecoveryService(),
       _eventLogService = eventLogService ?? PrinterEventLogService(),
       _encodingProfileStore =
           encodingProfileStore ?? PrinterEncodingProfileStore();

  static const String _localConfigPrefix = 'ibul_unified_printer_setup_v1_';
  static const Set<PrinterRole> _managedRoles = <PrinterRole>{
    PrinterRole.receipt,
    PrinterRole.kitchen,
  };
  static const Duration _snapshotCacheTtl = Duration(seconds: 30);

  PrinterSetupSnapshot? peekCachedSetupSnapshot(String restaurantId) {
    final normalized = restaurantId.trim();
    if (normalized.isEmpty) return null;
    final cached = _snapshotCache[normalized];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.fetchedAt) > _snapshotCacheTtl) {
      return null;
    }
    return cached.snapshot;
  }

  Future<UnifiedPrinterModel?> resolveKitchenPrinterForGarsonFast(
    String restaurantId,
  ) async {
    return resolveKitchenPrinterForStationOrRole(
      restaurantId: restaurantId,
      flowName: 'kitchen_order',
      source: 'garson_fast',
      minimalSnapshot: true,
    );
  }

  Future<UnifiedPrinterModel?> resolveReceiptPrinterForGarsonFast(
    String restaurantId,
  ) async {
    final snapshot = peekCachedSetupSnapshot(restaurantId);
    if (snapshot != null) {
      final resolved = await _resolvePrinterForRole(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: PrinterSetupRole.adisyon,
      );
      if (resolved != null) {
        return _normalizePrinterForPhysicalDispatch(resolved);
      }
    }
    return resolvePrinterForDispatch(
      restaurantId: restaurantId,
      role: PrinterSetupRole.adisyon,
      flowName: 'waiter_receipt',
      documentType: 'receipt',
      source: 'garson_fast',
      minimalSnapshot: true,
    );
  }

  static const Duration _bridgeReachableCacheTtl = Duration(seconds: 5);
  DateTime? _bridgeReachableCachedAt;
  bool _bridgeReachableCachedValue = false;
  static const String _pos58UsbVendorId = '0x0416';
  static const String _pos58UsbProductId = '0x5011';

  final PrinterRepositoryPort _printerRepository;
  final PrintStationServicePort _printStationService;
  final LocalPrintServiceFactory _printServiceFactory;
  LocalPrintService? _sharedPrintService;
  final PrinterEventLogService _eventLogService;
  final MacosUsbPermissionRecoveryService _usbPermissionRecoveryService;
  final PrinterEncodingProfileStore _encodingProfileStore;
  final WorkingPrinterStore _workingPrinterStore = WorkingPrinterStore();
  final Map<String, PrinterEncodingProfile> _encodingProfileMemoryCache =
      <String, PrinterEncodingProfile>{};
  final Map<String, _SnapshotCacheEntry> _snapshotCache =
      <String, _SnapshotCacheEntry>{};
  final Map<String, String> _lastRoleMappingReloadJson = <String, String>{};
  final Map<String, String> _lastRoleMappingCacheToken = <String, String>{};

  /// Reuse a single LocalPrintService instance so short-lived caches
  /// (health/printers) actually survive across consecutive print requests.
  /// This is critical for the "bridge ready => instant dispatch" path.
  LocalPrintService _service() =>
      _sharedPrintService ??= _printServiceFactory();

  void invalidateBridgeStatusCache() {
    _bridgeReachableCachedAt = null;
    _bridgeReachableCachedValue = false;
    _service().invalidateBridgeStatusCache();
  }

  void invalidateRoleMappingCache(String restaurantId) {
    final normalized = restaurantId.trim();
    if (normalized.isEmpty) return;
    _snapshotCache.remove(normalized);
    _lastRoleMappingReloadJson.remove(normalized);
    _lastRoleMappingCacheToken.remove(normalized);
    debugPrint(
      '[PrintOrchestrator][role_mapping_cache_invalidated] '
      'restaurantId=$normalized',
    );
  }

  void stampEncodingProfileOnPayload(
    Map<String, dynamic> payload,
    PrinterEncodingProfile profile,
  ) {
    payload['printer_encoding'] = profile.encoding;
    payload['encoding'] = profile.encoding;
    payload['printer_code_page'] = profile.codePage;
    payload['codepage'] = profile.codePage;
    payload['code_page'] = profile.codePage;
    payload['esc_t_value'] = profile.codePage;
    payload['codepage_command'] = profile.effectiveCodepageCommand;
    if (profile.escRValue != null) {
      payload['esc_r_value'] = profile.escRValue;
      payload['printer_esc_r'] = profile.escRValue;
    }
    payload['encoding_profile_verified'] = true;
    payload['encoding_profile_missing'] = false;
    payload['encoding_profile_candidate_id'] = profile.candidateId;
    payload['turkish_print_mode'] = profile.printMode;
    if (profile.isGuaranteeMode) {
      payload['render_mode'] = 'image';
      payload['turkish_guarantee_mode'] = true;
      payload['use_bundled_font_only'] = true;
    }
    if (profile.codepageLabel != null && profile.codepageLabel!.isNotEmpty) {
      payload['codepage_label'] = profile.codepageLabel;
    }
  }

  void stampDefaultTurkishGuaranteeOnPayload(Map<String, dynamic> payload) {
    payload['encoding_profile_verified'] = true;
    payload['encoding_profile_missing'] = false;
    payload['turkish_print_mode'] = kTurkishPrintModeGuarantee;
    payload['render_mode'] = 'image';
    payload['turkish_guarantee_mode'] = true;
    payload['use_bundled_font_only'] = true;
    payload['encoding_profile_candidate_id'] = 'turkish_guarantee';
  }

  PrintPayload buildFastRoleTestPayload({
    required PrinterSetupRole role,
    PrinterEncodingProfile? profile,
    String? storeName,
  }) {
    final base = PrintPayload.testForRole(role);
    final body = Map<String, dynamic>.from(base.body);
    if (storeName != null && storeName.trim().isNotEmpty) {
      body['store_name'] = storeName.trim();
    }
    if (profile != null) {
      stampEncodingProfileOnPayload(body, profile);
    } else {
      stampDefaultTurkishGuaranteeOnPayload(body);
    }
    body['flow_type'] = role == PrinterSetupRole.mutfak
        ? 'kitchen_test'
        : 'adisyon_test';
    return PrintPayload(documentType: base.documentType, body: body);
  }

  UnifiedPrinterModel? resolvePrinterFromBridgeMaps({
    required List<Map<String, dynamic>> bridgePrinters,
    required String? printerId,
    required DesktopPrinterOs os,
  }) {
    final normalizedId = printerId?.trim() ?? '';
    if (normalizedId.isEmpty) return null;
    for (final printer in bridgePrinters) {
      if (printer['isLive'] == false) continue;
      final bridgeId = printer['id']?.toString().trim() ?? '';
      final recordId =
          printer['printerRecordId']?.toString().trim() ??
          printer['printer_record_id']?.toString().trim() ??
          '';
      if (bridgeId == normalizedId || recordId == normalizedId) {
        return _normalizePrinterForPhysicalDispatch(
          UnifiedPrinterModel.fromBridgeMap(
            Map<String, dynamic>.from(printer),
            os: os,
          ),
        );
      }
    }
    return null;
  }

  DesktopPrinterOs detectOs() {
    if (kIsWeb) {
      return DesktopPrinterOs.windows;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return DesktopPrinterOs.windows;
      case TargetPlatform.macOS:
      default:
        return DesktopPrinterOs.macos;
    }
  }

  Future<void> saveWorkingPrinter(
    String restaurantId,
    UnifiedPrinterModel printer,
  ) async {
    if (!_isBridgeReadyPrinter(printer)) return;
    await _workingPrinterStore.save(restaurantId, printer);
  }

  Future<PrinterActionResult> saveSingleRoleSelection({
    required String restaurantId,
    required PrinterSetupRole role,
    required String printerRecordId,
    bool markThisDeviceAsPrintStation = false,
    String flowName = 'role_mapping_save_single',
    String source = 'orchestrator',
  }) async {
    final recordId = printerRecordId.trim();
    if (recordId.isEmpty) {
      return const PrinterActionResult(
        ok: false,
        status: 'printer_not_found',
        message: 'PrinterRecordId boş. Önce yazıcıyı kaydedin.',
      );
    }
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
    );
    final resolved = await _resolveSavedPrinterSelection(
      snapshot: snapshot,
      requestedId: recordId,
      role: role,
    );
    final existing =
        snapshot.localConfig ??
        PrinterSetupLocalConfig(restaurantId: restaurantId, os: detectOs());

    // Preserve the other role selection (local first). If local is missing but
    // remote has record ids, hydrate best-effort so we don't wipe role_mappings.
    PrinterRoleSelection? preservedReceipt = existing.receiptSelection;
    PrinterRoleSelection? preservedKitchen = existing.kitchenSelection;
    if (preservedReceipt == null &&
        snapshot.selectedReceiptPrinterRecordId?.trim().isNotEmpty == true) {
      try {
        final other = await _resolveSavedPrinterSelection(
          snapshot: snapshot,
          requestedId: snapshot.selectedReceiptPrinterRecordId!.trim(),
          role: PrinterSetupRole.adisyon,
        );
        preservedReceipt = PrinterRoleSelection(
          role: PrinterSetupRole.adisyon,
          printer: other,
        );
      } catch (_) {}
    }
    if (preservedKitchen == null &&
        snapshot.selectedKitchenPrinterRecordId?.trim().isNotEmpty == true) {
      try {
        final other = await _resolveSavedPrinterSelection(
          snapshot: snapshot,
          requestedId: snapshot.selectedKitchenPrinterRecordId!.trim(),
          role: PrinterSetupRole.mutfak,
        );
        preservedKitchen = PrinterRoleSelection(
          role: PrinterSetupRole.mutfak,
          printer: other,
        );
      } catch (_) {}
    }

    final nextConfig = role == PrinterSetupRole.adisyon
        ? existing.copyWith(
            receiptSelection: PrinterRoleSelection(
              role: role,
              printer: resolved,
            ),
            kitchenSelection: preservedKitchen,
            receiptTest: null,
            kitchenTest: null,
            savedAt: DateTime.now(),
            thisDeviceIsPrintStation: markThisDeviceAsPrintStation,
          )
        : existing.copyWith(
            receiptSelection: preservedReceipt,
            kitchenSelection: PrinterRoleSelection(
              role: role,
              printer: resolved,
            ),
            receiptTest: null,
            kitchenTest: null,
            savedAt: DateTime.now(),
            thisDeviceIsPrintStation: markThisDeviceAsPrintStation,
          );
    await _saveLocalConfig(nextConfig);
    _logRoleMappingState(
      action: 'role_mapping_save',
      restaurantId: restaurantId,
      config: nextConfig,
    );
    invalidateRoleMappingCache(restaurantId);
    await saveWorkingPrinter(restaurantId, resolved);

    // Patch cloud config without wiping the other role.
    final fields = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      'role_mappings': _roleMappingsPayload(nextConfig),
    };
    if (role == PrinterSetupRole.adisyon) {
      fields['adisyon_printer_id'] = recordId;
      fields['adisyon_printer_name'] = resolved.displayName;
    } else {
      fields['kitchen_printer_id'] = recordId;
      fields['kitchen_printer_name'] = resolved.displayName;
    }
    try {
      await _printStationService.patchStationConfiguration(
        restaurantId: restaurantId,
        fields: fields,
      );
      await _printStationService.invalidateRoleMappingCacheState(
        restaurantId: restaurantId,
        roleMappings: fields['role_mappings'] as Map<String, dynamic>?,
        source: flowName,
      );
    } catch (error) {
      return PrinterActionResult(
        ok: true,
        status: 'saved_warning',
        message:
            'Yerel rol eşleştirmesi kaydedildi ama bulut senkronu başarısız: $error',
        printer: resolved,
        raw: <String, dynamic>{'cloud_error': error.toString()},
      );
    }
    await loadSetupSnapshot(
      restaurantId: restaurantId,
      forceRefresh: true,
      minimal: true,
      flowName: '${flowName}_reloaded',
      source: source,
    );
    return PrinterActionResult(
      ok: true,
      status: 'saved',
      message: role == PrinterSetupRole.adisyon
          ? 'Adisyon yazıcısı eşleştirildi.'
          : 'Mutfak yazıcısı eşleştirildi.',
      printer: resolved,
    );
  }

  Future<void> clearWorkingPrinter(String restaurantId) async {
    await _workingPrinterStore.clear(restaurantId);
  }

  Future<PrinterActionResult> repairLegacyRoleMappings({
    required String restaurantId,
    String flowName = 'role_mapping_repair',
    String source = 'orchestrator',
  }) async {
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
    );
    final localConfig = snapshot.localConfig;
    if (localConfig == null) {
      return const PrinterActionResult(
        ok: false,
        status: 'no_local_config',
        message: 'Yerel rol eşleştirmesi bulunamadı.',
      );
    }

    UnifiedPrinterModel? legacyReceipt = localConfig.receiptSelection?.printer;
    UnifiedPrinterModel? legacyKitchen = localConfig.kitchenSelection?.printer;
    final receiptNeedsRepair =
        legacyReceipt != null &&
        (legacyReceipt.printerRecordId?.trim().isEmpty ?? true);
    final kitchenNeedsRepair =
        legacyKitchen != null &&
        (legacyKitchen.printerRecordId?.trim().isEmpty ?? true);
    if (!receiptNeedsRepair && !kitchenNeedsRepair) {
      return const PrinterActionResult(
        ok: true,
        status: 'already_canonical',
        message: 'Rol eşleştirmesi zaten güncel.',
      );
    }

    UnifiedPrinterModel resolveCandidate(UnifiedPrinterModel legacy) {
      for (final candidate in snapshot.printers) {
        if (_printersMatch(legacy, candidate)) return candidate;
      }
      return legacy;
    }

    final toSync = <PrinterSetupRole, UnifiedPrinterModel>{};
    if (receiptNeedsRepair) {
      toSync[PrinterSetupRole.adisyon] = resolveCandidate(legacyReceipt);
    }
    if (kitchenNeedsRepair) {
      toSync[PrinterSetupRole.mutfak] = resolveCandidate(legacyKitchen);
    }

    Map<PrinterSetupRole, UnifiedPrinterModel> synced = const {};
    try {
      synced = await _syncPrinterRecords(
        restaurantId: restaurantId,
        selections: toSync,
      );
    } catch (error) {
      return PrinterActionResult(
        ok: false,
        status: 'printer_upsert_failed',
        message: 'Yazıcı kaydı oluşturulamadı. Yetki/bağlantı hatası olabilir.',
        technicalMessage: error.toString(),
      );
    }

    final receiptRecordId =
        (localConfig.receiptSelection?.printer.printerRecordId
                ?.trim()
                .isNotEmpty ??
            false)
        ? localConfig.receiptSelection!.printer.printerRecordId!.trim()
        : (synced[PrinterSetupRole.adisyon]?.printerRecordId?.trim() ?? '');
    final kitchenRecordId =
        (localConfig.kitchenSelection?.printer.printerRecordId
                ?.trim()
                .isNotEmpty ??
            false)
        ? localConfig.kitchenSelection!.printer.printerRecordId!.trim()
        : (synced[PrinterSetupRole.mutfak]?.printerRecordId?.trim() ?? '');

    if (receiptRecordId.isEmpty && localConfig.receiptSelection != null) {
      return const PrinterActionResult(
        ok: false,
        status: 'receipt_printer_record_missing',
        message: 'Adisyon yazıcısı için DB kaydı oluşturulamadı.',
      );
    }
    if (kitchenRecordId.isEmpty && localConfig.kitchenSelection != null) {
      return const PrinterActionResult(
        ok: false,
        status: 'kitchen_printer_record_missing',
        message: 'Mutfak yazıcısı için DB kaydı oluşturulamadı.',
      );
    }

    // Persist repaired mapping using the standard path (local + remote),
    // and clear stale test state.
    if (localConfig.receiptSelection != null &&
        localConfig.kitchenSelection != null) {
      return await savePrinterRoles(
        restaurantId: restaurantId,
        receiptPrinterId: receiptRecordId,
        kitchenPrinterId: kitchenRecordId,
        flowName: flowName,
        source: source,
      );
    }
    if (localConfig.receiptSelection != null) {
      return await saveSingleRoleSelection(
        restaurantId: restaurantId,
        role: PrinterSetupRole.adisyon,
        printerRecordId: receiptRecordId,
        flowName: flowName,
        source: source,
      );
    }
    return await saveSingleRoleSelection(
      restaurantId: restaurantId,
      role: PrinterSetupRole.mutfak,
      printerRecordId: kitchenRecordId,
      flowName: flowName,
      source: source,
    );
  }

  String? _runtimePayloadStoreId(Map<String, dynamic>? payload) {
    final value =
        payload?['store_id']?.toString() ??
        payload?['storeId']?.toString() ??
        payload?['branch_id']?.toString();
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _runtimePayloadTableId(Map<String, dynamic>? payload) {
    final value =
        payload?['table_id']?.toString() ??
        payload?['tableId']?.toString() ??
        payload?['table_no']?.toString() ??
        payload?['tableNo']?.toString();
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _runtimePayloadPrintJobId(
    Map<String, dynamic>? jobRecord,
    Map<String, dynamic>? payload,
  ) {
    final value =
        jobRecord?['id']?.toString() ??
        payload?['print_job_id']?.toString() ??
        payload?['job_id']?.toString();
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _runtimeLog({
    required String restaurantId,
    required String event,
    required String flowName,
    required String source,
    String? role,
    String? documentType,
    UnifiedPrinterModel? printer,
    String? bridgePrinterId,
    String? printerRecordId,
    String? printerName,
    String? backend,
    String? queue,
    String? deviceIdentifier,
    String? storeId,
    String? tableId,
    String? printJobId,
    bool usedFallback = false,
    String? fallbackReason,
    String? errorMessage,
    String level = 'info',
    Map<String, dynamic>? details,
  }) async {
    final resolvedPrinter = printer;
    try {
      await _eventLogService.appendRuntime(
        restaurantId: restaurantId,
        event: event,
        flowName: flowName,
        source: source,
        role: role,
        documentType: documentType,
        bridgePrinterId: bridgePrinterId ?? resolvedPrinter?.id,
        printerRecordId: printerRecordId ?? resolvedPrinter?.printerRecordId,
        printerName: printerName ?? resolvedPrinter?.displayName,
        backend: backend ?? resolvedPrinter?.backend.value,
        queue: queue ?? resolvedPrinter?.queueName,
        deviceIdentifier:
            deviceIdentifier ??
            (resolvedPrinter == null
                ? null
                : _persistedDeviceIdentifier(resolvedPrinter)),
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        usedFallback: usedFallback,
        fallbackReason: fallbackReason,
        errorMessage: errorMessage,
        level: level,
        details: details,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[PrintOrchestrator] runtime log failed '
        'event=$event restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
    }
  }

  Future<Map<String, dynamic>?> _dispatchBridgeTest({
    required LocalPrintService service,
    UnifiedPrinterModel? printer,
    String? printerId,
    String? printerName,
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    Map<String, dynamic>? extraBody,
    String renderMode = 'text',
    String testMode = 'escpos_short',
  }) {
    final dispatchTarget = _dispatchTargetFromPrinter(
      printer: printer,
      documentType: 'test',
      role: _readText(extraBody?['printer_role']).isEmpty
          ? 'test'
          : _readText(extraBody?['printer_role']),
      overrideHost: targetHost,
      overridePort: targetPort,
    );
    _debugBridgeDispatchPayload(dispatchTarget);
    if (dispatchTarget.backend == DesktopPrinterBackend.tcp.value &&
        dispatchTarget.host != null &&
        dispatchTarget.port != null) {
      debugPrint('[TCP_PRINT][start]');
      debugPrint('host=${dispatchTarget.host}');
      debugPrint('port=${dispatchTarget.port}');
    }
    final resolvedHost =
        targetHost ??
        (printer?.raw['host'] ??
                printer?.raw['ip_address'] ??
                printer?.raw['ipAddress'])
            ?.toString();
    final resolvedPortRaw =
        targetPort ?? printer?.raw['port'] ?? printer?.raw['tcp_port'];
    final resolvedPort = resolvedPortRaw is int
        ? resolvedPortRaw
        : int.tryParse(resolvedPortRaw?.toString() ?? '');
    if ((printer?.backend == DesktopPrinterBackend.tcp) ||
        (resolvedHost?.trim().isNotEmpty ?? false)) {
      debugPrint(
        '[PrintOrchestrator][dispatch] '
        'backend=tcp transport=ethernet host=${resolvedHost ?? '-'} '
        'port=${resolvedPort ?? PrinterModel.ethernetDefaultPort}',
      );
    }
    return service.printTest(
      targetHost: targetHost,
      targetPort: targetPort,
      encoding: encoding,
      codePage: codePage,
      printerId: printer?.id ?? printerId,
      printerName: printer?.queueName ?? printerName,
      printer: printer == null ? null : _bridgePrinterPayload(printer),
      extraBody: extraBody,
      renderMode: renderMode,
      testMode: testMode,
    );
  }

  _PhysicalPrintVerification _verifyBridgeTestResult({
    required UnifiedPrinterModel? printer,
    required Map<String, dynamic>? response,
  }) {
    final bridgeOk = response?['ok'] == true;
    final queueStatus = _readText(response?['queue_status']).toLowerCase();
    if (!bridgeOk || queueStatus == 'failed' || queueStatus == 'error') {
      return _PhysicalPrintVerification(
        ok: false,
        status: 'test_failed',
        message: _friendlyTestFailure(response),
      );
    }
    final usedFallback = response?['used_fallback'] == true;
    final warningMessage = _readText(response?['warning']);
    final actualBackend = _readText(
      response?['actual_backend'] ??
          response?['selected_backend'] ??
          response?['transport_type'],
    ).toLowerCase();
    if (printer != null &&
        actualBackend.isNotEmpty &&
        actualBackend != printer.backend.value.toLowerCase()) {
      if (usedFallback) {
        return _PhysicalPrintVerification(
          ok: true,
          status: 'ready_warning',
          message: warningMessage.isNotEmpty
              ? warningMessage
              : 'Test işi yedek backend ile gönderildi. Fiziksel baskıyı kontrol edin.',
        );
      }
      if (printer.backend != DesktopPrinterBackend.usbDirect) {
        return _PhysicalPrintVerification(
          ok: true,
          status: 'ready_warning',
          message: warningMessage.isNotEmpty
              ? warningMessage
              : 'Test işi farklı bir backend ile gönderildi. Fiziksel baskıyı kontrol edin.',
        );
      }
      return _PhysicalPrintVerification(
        ok: false,
        status: 'test_failed',
        message:
            'Seçilen yazıcı backend\'i ${printer.backend.value} ama bridge $actualBackend kullandı. Bu baskı başarısız sayıldı.',
      );
    }
    final physicalConfirmation = response?['physical_confirmation'];
    final bytesSent = int.tryParse(_readText(response?['bytes_sent'])) ?? 0;
    if (physicalConfirmation == false && actualBackend == 'cups') {
      return _PhysicalPrintVerification(
        ok: true,
        status: 'ready_unverified',
        message:
            'Test işi yazıcı kuyruğuna gönderildi. Fiziksel baskıyı kontrol edin.',
      );
    }
    if (physicalConfirmation == false) {
      // Do not fail test solely on missing physical confirmation.
      // Accept if bytes were dispatched and bridge didn't error.
      if (bytesSent > 0) {
        return _PhysicalPrintVerification(
          ok: true,
          status: 'ready_unverified',
          message:
              _readText(response?['physical_confirmation_message']).isNotEmpty
              ? _readText(response?['physical_confirmation_message'])
              : 'Test gönderildi ama fiziksel doğrulama yok. Yazıcı çıktısını kontrol edin.',
        );
      }
      return _PhysicalPrintVerification(
        ok: false,
        status: 'test_failed',
        message:
            _readText(response?['physical_confirmation_message']).isNotEmpty
            ? _readText(response?['physical_confirmation_message'])
            : 'Test gönderildi ama bytes gönderilemedi. Yazıcı bağlantısını kontrol edin.',
      );
    }
    if (printer?.backend == DesktopPrinterBackend.usbDirect) {
      final transportDetails =
          '${_transportOutput(response)} '
                  '${_readText(response?['transport_type'] ?? response?['transport'])}'
              .toLowerCase();
      if (!transportDetails.contains('usb')) {
        return const _PhysicalPrintVerification(
          ok: false,
          status: 'test_failed',
          message:
              'CUPS tamamlandı ama USB termal yazıcı fiziksel çıktı vermedi.',
        );
      }
    }
    if (warningMessage.isNotEmpty) {
      return _PhysicalPrintVerification(
        ok: true,
        status: 'ready_warning',
        message: warningMessage,
      );
    }
    return const _PhysicalPrintVerification(
      ok: true,
      status: 'ready',
      message: 'Hazir',
    );
  }

  Future<void> _logCupsAcceptedWithoutPhysicalConfirmation({
    required String restaurantId,
    required String flowName,
    required String source,
    required String documentType,
    required UnifiedPrinterModel? printer,
    required Map<String, dynamic>? response,
    String? role,
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    if (printer == null || printer.backend != DesktopPrinterBackend.cups) {
      return;
    }
    await _runtimeLog(
      restaurantId: restaurantId,
      event: 'cups_job_accepted_but_no_physical_confirmation',
      flowName: flowName,
      source: source,
      role: role,
      documentType: documentType,
      printer: printer,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      level: 'warning',
      details: <String, dynamic>{
        'route': documentType == 'test' ? '/print/test' : null,
        'queue_status': _readText(response?['queue_status']),
        'transport_output': _transportOutput(response),
        'bridgeResult': response ?? const <String, dynamic>{},
      }..removeWhere((key, value) => value == null || value == ''),
    );
  }

  Future<UnifiedPrinterModel?> _resolveWorkingPrinter({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
  }) async {
    final storedPrinter = await _workingPrinterStore.load(restaurantId);
    if (storedPrinter == null || !_isBridgeReadyPrinter(storedPrinter)) {
      return null;
    }

    final resolved = await _resolveStoredPrinterCandidate(
      restaurantId: restaurantId,
      snapshot: snapshot,
      candidate: storedPrinter,
    );
    if (resolved != null) {
      return _normalizePrinterForPhysicalDispatch(
        resolved.copyWith(printerRecordId: storedPrinter.printerRecordId),
      );
    }

    for (final printer in snapshot.printers) {
      if (_printersMatch(storedPrinter, printer)) {
        return _normalizePrinterForPhysicalDispatch(
          printer.copyWith(printerRecordId: storedPrinter.printerRecordId),
        );
      }
    }
    return null;
  }

  Future<PrinterActionResult> adoptWorkingPrinter({
    required String restaurantId,
    required UnifiedPrinterModel workingPrinter,
    Session? session,
    bool markThisDeviceAsPrintStation = false,
    String? stationPlatform,
  }) async {
    final normalizedPrinter = _normalizePrinterForPhysicalDispatch(
      workingPrinter,
    );
    final printerId = normalizedPrinter.id.trim().isNotEmpty
        ? normalizedPrinter.id.trim()
        : null;
    final printerName = normalizedPrinter.displayName.trim().isNotEmpty
        ? normalizedPrinter.displayName.trim()
        : 'USB Yazıcı';
    final printerCode = _buildPrinterCode(
      normalizedPrinter,
      const <PrinterRole>{PrinterRole.receipt, PrinterRole.kitchen},
    );

    final savedPrinter = await _printerRepository.upsertPrinter(
      restaurantId: restaurantId,
      printerId: printerId,
      name: printerName,
      code: printerCode,
      connectionType: PrinterModel.usbConnectionType,
      deviceIdentifier: normalizedPrinter.queueName.trim().isNotEmpty
          ? normalizedPrinter.queueName.trim()
          : normalizedPrinter.id.trim(),
      paperWidthMm: 80,
      isActive: true,
      supportsCut: true,
      assignedRoles: const <PrinterRole>[
        PrinterRole.receipt,
        PrinterRole.kitchen,
      ],
    );

    await saveWorkingPrinter(restaurantId, normalizedPrinter);

    return await savePrinterRoles(
      restaurantId: restaurantId,
      receiptPrinterId: savedPrinter.id,
      kitchenPrinterId: savedPrinter.id,
      session: session,
      markThisDeviceAsPrintStation: markThisDeviceAsPrintStation,
      stationPlatform: stationPlatform,
    );
  }

  Future<PrinterSetupSnapshot> loadSetupSnapshot({
    required String restaurantId,
    bool forceRefresh = false,
    bool minimal = false,
    String flowName = 'setup_snapshot',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final roleMappingCacheToken = normalizedRestaurantId.isEmpty
        ? null
        : await _printStationService.readRoleMappingCacheToken(
            normalizedRestaurantId,
          );
    if (normalizedRestaurantId.isNotEmpty &&
        roleMappingCacheToken != null &&
        _lastRoleMappingCacheToken[normalizedRestaurantId] !=
            roleMappingCacheToken) {
      invalidateRoleMappingCache(normalizedRestaurantId);
      _lastRoleMappingCacheToken[normalizedRestaurantId] =
          roleMappingCacheToken;
      forceRefresh = true;
    }
    if (!forceRefresh && normalizedRestaurantId.isNotEmpty) {
      final cached = _snapshotCache[normalizedRestaurantId];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) <= _snapshotCacheTtl) {
        return cached.snapshot;
      }
    }
    final os = detectOs();
    final localConfigFuture = _loadLocalConfig(restaurantId);
    final remoteConfigFuture = _safeFetchRemoteConfig(restaurantId);
    final workingPrinterFuture = _workingPrinterStore.load(restaurantId);
    final printStationFlagFuture = _printStationService
        .isThisDevicePrintStation();
    final savedPrintersFuture = _printerRepository.fetchPrinters(restaurantId);

    final workingPrinter = await workingPrinterFuture;
    var bridgeReachable = false;
    var bridgeHealthy = false;
    String? discoveryWarning;
    String bridgeStatusLabel = 'Bridge calismiyor';
    Map<String, dynamic>? health;
    Map<String, dynamic>? setupStatus;
    Map<String, dynamic>? prerequisites;
    Map<String, dynamic>? queueStatus;
    List<UnifiedPrinterModel> printers = const <UnifiedPrinterModel>[];

    final service = _service();
    List<UnifiedPrinterModel> liveBridgePrinters =
        const <UnifiedPrinterModel>[];
    try {
      final runtime = await _probeBridgeRuntime(service: service, os: os);
      bridgeReachable = runtime.reachable;
      bridgeHealthy = runtime.healthy;
      health = runtime.health;
      liveBridgePrinters = runtime.livePrinters;

      if (bridgeReachable) {
        if (!minimal) {
          try {
            setupStatus = await service.setupStatus();
          } catch (_) {}
          try {
            prerequisites = await service.setupPrerequisites();
          } catch (_) {}
          try {
            queueStatus = await _printStationService.fetchLocalQueueStatus();
          } catch (_) {}
        }
        if (!minimal && liveBridgePrinters.isEmpty) {
          final discoverResponse = await service.discover();
          liveBridgePrinters = _normalizeBridgePrinters(
            discoverResponse?['printers'],
            os: os,
          );
          if (liveBridgePrinters.isEmpty) {
            liveBridgePrinters = _normalizeDiscoveryFallback(
              discoverResponse,
              os: os,
            );
          }
          discoveryWarning = _discoveryWarningFromResponse(
            os: os,
            response: discoverResponse,
            prerequisites: prerequisites,
          );
        }
        List<PrinterModel> savedPrinters = const <PrinterModel>[];
        try {
          savedPrinters = await savedPrintersFuture;
        } catch (error, stackTrace) {
          debugPrint(
            '[PrintOrchestrator] saved printers fetch failed '
            'restaurantId=$restaurantId error=$error',
          );
          debugPrint('$stackTrace');
        }
        printers = _mergeCanonicalPrinterCatalog(
          livePrinters: liveBridgePrinters,
          savedPrinters: savedPrinters,
          os: os,
          workingPrinter: workingPrinter,
        );
        _logDiscoveredPrinters(restaurantId: restaurantId, printers: printers);
        bridgeHealthy = _isBridgeOperational(
          health: health,
          queueStatus: queueStatus,
          printers: printers,
        );
      } else {
        discoveryWarning = runtime.probeError ?? 'Bridge calismiyor';
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[PrintOrchestrator] loadSetupSnapshot failed '
        'restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
      discoveryWarning = _friendlyBridgeFailure(error);
    }

    if (bridgeReachable && bridgeHealthy) {
      bridgeStatusLabel = 'Hazir';
    } else if (bridgeReachable) {
      bridgeStatusLabel = 'Bridge calisiyor ama yazici hazir degil';
    }

    var localConfig = await localConfigFuture;
    final remoteConfig = await remoteConfigFuture;
    final isPrintStationDevice = await printStationFlagFuture;
    if (localConfig != null) {
      localConfig = localConfig.copyWith(
        thisDeviceIsPrintStation: isPrintStationDevice,
      );
    }

    final receiptSelection = _resolveSelection(
      role: PrinterSetupRole.adisyon,
      localConfig: localConfig,
      remoteConfig: remoteConfig,
      printers: printers,
      os: os,
    );
    final kitchenSelection = _resolveSelection(
      role: PrinterSetupRole.mutfak,
      localConfig: localConfig,
      remoteConfig: remoteConfig,
      printers: printers,
      os: os,
    );
    final receiptTestReady = _latestTestStillMatches(
      localConfig?.receiptTest,
      receiptSelection,
    );
    final kitchenTestReady = _latestTestStillMatches(
      localConfig?.kitchenTest,
      kitchenSelection,
    );
    final localHeartbeatOnline =
        isPrintStationDevice &&
        _printStationService.isLocalStationReady(queueStatus);
    final heartbeatOnline =
        localHeartbeatOnline ||
        _printStationService.isStationOnline(remoteConfig);
    final roleMappingsSaved =
        localConfig?.savedAt != null ||
        remoteConfig?['updated_at']?.toString().trim().isNotEmpty == true;

    final baseLocalConfig =
        localConfig ??
        PrinterSetupLocalConfig(restaurantId: restaurantId, os: os);
    final effectiveLocalConfig = PrinterSetupLocalConfig(
      restaurantId: baseLocalConfig.restaurantId,
      os: baseLocalConfig.os,
      receiptSelection: receiptSelection == null
          ? null
          : PrinterRoleSelection(
              role: PrinterSetupRole.adisyon,
              printer: receiptSelection,
            ),
      kitchenSelection: kitchenSelection == null
          ? null
          : PrinterRoleSelection(
              role: PrinterSetupRole.mutfak,
              printer: kitchenSelection,
            ),
      receiptTest: receiptSelection == null ? null : localConfig?.receiptTest,
      kitchenTest: kitchenSelection == null ? null : localConfig?.kitchenTest,
      savedAt: baseLocalConfig.savedAt,
      lastCloudWarning: baseLocalConfig.lastCloudWarning,
      thisDeviceIsPrintStation: isPrintStationDevice,
    );

    final steps = <PrinterSetupStepStatus>[
      PrinterSetupStepStatus(
        stepNumber: 1,
        label: 'OS detected',
        isReady: true,
        statusKey: 'ready',
      ),
      PrinterSetupStepStatus(
        stepNumber: 2,
        label: 'bridge running',
        isReady: bridgeReachable,
        statusKey: bridgeReachable ? 'ready' : 'bridge_not_running',
      ),
      PrinterSetupStepStatus(
        stepNumber: 3,
        label: 'printer discovery successful',
        isReady: printers.any(isSelectableLivePrinter),
        statusKey: printers.any(isSelectableLivePrinter)
            ? 'ready'
            : 'printer_not_found',
      ),
      PrinterSetupStepStatus(
        stepNumber: 4,
        label: 'adisyon printer selected',
        isReady: receiptSelection != null,
        statusKey: receiptSelection != null ? 'ready' : 'selection_required',
      ),
      PrinterSetupStepStatus(
        stepNumber: 5,
        label: 'mutfak printer selected',
        isReady: kitchenSelection != null,
        statusKey: kitchenSelection != null ? 'ready' : 'selection_required',
      ),
      PrinterSetupStepStatus(
        stepNumber: 6,
        label: 'adisyon test receipt printed',
        isReady: receiptTestReady,
        statusKey: receiptTestReady ? 'ready' : 'test_required',
      ),
      PrinterSetupStepStatus(
        stepNumber: 7,
        label: 'mutfak test receipt printed',
        isReady: kitchenTestReady,
        statusKey: kitchenTestReady ? 'ready' : 'test_required',
      ),
      PrinterSetupStepStatus(
        stepNumber: 8,
        label: 'role mappings saved',
        isReady: roleMappingsSaved,
        statusKey: roleMappingsSaved ? 'ready' : 'save_required',
      ),
      PrinterSetupStepStatus(
        stepNumber: 9,
        label: 'print station heartbeat online',
        isReady: heartbeatOnline,
        statusKey: heartbeatOnline ? 'ready' : 'heartbeat_offline',
      ),
      PrinterSetupStepStatus(
        stepNumber: 10,
        label: 'setup completed',
        isReady:
            bridgeReachable &&
            printers.isNotEmpty &&
            receiptSelection != null &&
            kitchenSelection != null &&
            receiptTestReady &&
            kitchenTestReady &&
            roleMappingsSaved &&
            heartbeatOnline,
        statusKey:
            bridgeReachable &&
                printers.isNotEmpty &&
                receiptSelection != null &&
                kitchenSelection != null &&
                receiptTestReady &&
                kitchenTestReady &&
                roleMappingsSaved &&
                heartbeatOnline
            ? 'ready'
            : 'setup_incomplete',
      ),
    ];

    final snapshot = PrinterSetupSnapshot(
      os: os,
      bridgeReachable: bridgeReachable,
      bridgeHealthy: bridgeHealthy,
      bridgeHealth: health,
      printers: printers,
      steps: steps,
      localConfig: effectiveLocalConfig,
      remoteConfig: remoteConfig,
      queueStatus: queueStatus,
      setupStatus: _mergeOperatorSetupStatus(
        bridgeReachable: bridgeReachable,
        bridgeHealthy: bridgeHealthy,
        livePrinterCount: printers.where((p) => p.isLiveDiscovery).length,
        remoteStatus: setupStatus,
        bridgeHealth: health,
      ),
      prerequisites: _mergeOperatorPrerequisites(
        bridgeReachable: bridgeReachable,
        bridgeHealthy: bridgeHealthy,
        livePrinterCount: printers.where((p) => p.isLiveDiscovery).length,
        remotePrerequisites: prerequisites,
        bridgeHealth: health,
      ),
      discoveryWarning: discoveryWarning,
      workingPrinter: workingPrinter,
      bridgeStatusLabel: bridgeStatusLabel,
    );
    if (effectiveLocalConfig.receiptSelection != null ||
        effectiveLocalConfig.kitchenSelection != null) {
      final reloadJson = jsonEncode(effectiveLocalConfig.toJson());
      if (_lastRoleMappingReloadJson[restaurantId] != reloadJson) {
        _lastRoleMappingReloadJson[restaurantId] = reloadJson;
        _logRoleMappingState(
          action: 'role_mapping_reload',
          restaurantId: restaurantId,
          config: effectiveLocalConfig,
        );
      }
    }
    if (normalizedRestaurantId.isNotEmpty) {
      _snapshotCache[normalizedRestaurantId] = _SnapshotCacheEntry(
        snapshot: snapshot,
        fetchedAt: DateTime.now(),
      );
    }
    final hydratedPrinter =
        effectiveLocalConfig.receiptSelection?.printer ??
        effectiveLocalConfig.kitchenSelection?.printer;
    await _runtimeLog(
      restaurantId: restaurantId,
      event: 'role_mapping_hydrated',
      flowName: flowName,
      source: source,
      role: 'all',
      documentType: 'setup_snapshot',
      printer: hydratedPrinter,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      details: <String, dynamic>{
        'selected_receipt_printer_record_id':
            snapshot.selectedReceiptPrinterRecordId ?? '-',
        'selected_kitchen_printer_record_id':
            snapshot.selectedKitchenPrinterRecordId ?? '-',
        'bridge_reachable': snapshot.bridgeReachable,
        'bridge_healthy': snapshot.bridgeHealthy,
        'printer_count': snapshot.printers.length,
      },
    );
    return snapshot;
  }

  Future<PrinterActionResult> printTestReceipt({
    required String restaurantId,
    PrinterSetupRole? role,
    String? printerId,
    UnifiedPrinterModel? explicitLivePrinter,
    String testSource = 'role_test',
    String flowName = 'role_test',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final requestedRole = role;
    _logRoleTestEvent(
      restaurantId: restaurantId,
      role: requestedRole,
      event: _testRequestedEvent(requestedRole),
      message: requestedRole == PrinterSetupRole.mutfak
          ? 'Mutfak test fişi istendi.'
          : 'Adisyon test fişi istendi.',
      details: <String, dynamic>{'requestedPrinterId': printerId?.trim()},
    );
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      // Role test is a "click => instant dispatch" flow.
      // Avoid setup/status/prerequisites/queue/discover round-trips here.
      minimal: testSource == 'role_test' && explicitLivePrinter == null,
    );
    if (!_isPrintSystemEnabledFromSnapshot(snapshot)) {
      return _printSystemDisabledResult();
    }
    if (!snapshot.bridgeReachable) {
      return const PrinterActionResult(
        ok: false,
        status: 'bridge_not_running',
        message: 'Bridge calismiyor',
      );
    }

    final allowRoleFallback =
        testSource != 'wizard_test' && explicitLivePrinter == null;
    UnifiedPrinterModel? legacyKitchenRoute;
    final resolvedPrinter =
        explicitLivePrinter ??
        await (() async {
          if (requestedRole == PrinterSetupRole.mutfak &&
              (printerId?.trim().isEmpty ?? true)) {
            final dbKitchenPrinter =
                await _resolveKitchenPrinterForStationOrRole(
                  restaurantId: restaurantId,
                  snapshot: snapshot,
                  flowName: flowName,
                  source: source,
                );
            legacyKitchenRoute = await _resolvePrinterForRole(
              restaurantId: restaurantId,
              snapshot: snapshot,
              role: PrinterSetupRole.mutfak,
              allowWorkingPrinterFallback: false,
              preferRemoteFirst: false,
            );
            if (dbKitchenPrinter != null &&
                legacyKitchenRoute != null &&
                !_sameResolvedPrinterRoute(
                  dbKitchenPrinter,
                  legacyKitchenRoute!,
                )) {
              _eventLogService
                  .append(
                    restaurantId: restaurantId,
                    event: 'printer_route_mismatch',
                    message:
                        'Mutfak test rotası ile eski runtime rotası farklı bulundu.',
                    level: 'error',
                    role: PrinterSetupRole.mutfak.value,
                    printerId:
                        dbKitchenPrinter.printerRecordId ?? dbKitchenPrinter.id,
                    queueName: dbKitchenPrinter.queueName,
                    backend: dbKitchenPrinter.backend.value,
                    details: <String, dynamic>{
                      'test_backend': dbKitchenPrinter.backend.value,
                      'test_host': _printerHost(dbKitchenPrinter),
                      'test_port': _printerPort(dbKitchenPrinter),
                      'real_backend': legacyKitchenRoute!.backend.value,
                      'real_queue': legacyKitchenRoute!.queueName,
                      'real_printer': legacyKitchenRoute!.displayName,
                    },
                  )
                  .ignore();
            }
            return dbKitchenPrinter;
          }
          return _resolvePrinterForTest(
            restaurantId: restaurantId,
            snapshot: snapshot,
            role: role,
            printerId: printerId,
            allowRoleFallback: allowRoleFallback,
          );
        })();
    final resolvedRole =
        role ??
        _inferRoleForPrinter(snapshot: snapshot, printer: resolvedPrinter);
    _eventLogService
        .append(
          restaurantId: restaurantId,
          event: 'printer_resolution',
          message: resolvedPrinter != null
              ? 'Test icin yazici cozuldu.'
              : 'Test icin yazici cozumlenemedi.',
          level: resolvedPrinter != null ? 'info' : 'error',
          role: resolvedRole?.value ?? requestedRole?.value,
          printerId: resolvedPrinter?.printerRecordId ?? resolvedPrinter?.id,
          queueName: resolvedPrinter?.queueName,
          backend: resolvedPrinter?.backend.value,
          details: <String, dynamic>{
            'requestedRole': requestedRole?.value,
            'resolvedRole': resolvedRole?.value,
            'requestedPrinterId': printerId?.trim(),
            'bridgePrinterId': resolvedPrinter?.id,
            'resolutionSource': resolvedPrinter == null ? 'none' : 'role_test',
            'resolvedPrinter': resolvedPrinter?.toJson(),
          },
        )
        .ignore();
    if (resolvedPrinter == null) {
      if (testSource == 'role_test') {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'role_test_print_failure',
              message: 'Rol test baskısı için yazıcı çözümlenemedi.',
              level: 'error',
              role: (resolvedRole ?? requestedRole)?.value,
              details: <String, dynamic>{
                'requestedPrinterId': printerId?.trim(),
                'error': 'printer_not_found',
              },
            )
            .ignore();
      }
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: 'physical_print_failure',
        level: 'error',
        message: 'Test fişi için yazıcı çözümlenemedi.',
        details: <String, dynamic>{
          'requestedPrinterId': printerId?.trim(),
          'error': 'printer_not_found',
        },
      );
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_failed',
        flowName: flowName,
        source: source,
        role: (resolvedRole ?? requestedRole)?.value,
        documentType: 'test',
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        usedFallback: false,
        fallbackReason: 'printer_not_found',
        errorMessage: 'printer_not_found',
        level: 'error',
      );
      return PrinterActionResult(
        ok: false,
        status: 'printer_not_found',
        message: role == PrinterSetupRole.mutfak
            ? 'Mutfak yazicisi secin'
            : 'Adisyon yazicisi secin',
      );
    }
    // Role tests must dispatch via a canonical DB record id.
    // If we don't have a record id, fail loudly (no silent bridge-id fallback).
    if (testSource == 'role_test' && explicitLivePrinter == null) {
      final recordId = resolvedPrinter.printerRecordId?.trim() ?? '';
      if (recordId.isEmpty) {
        await _runtimeLog(
          restaurantId: restaurantId,
          event: 'physical_print_failed',
          flowName: flowName,
          source: source,
          role: (resolvedRole ?? requestedRole)?.value,
          documentType: 'test',
          printer: resolvedPrinter,
          storeId: storeId,
          tableId: tableId,
          printJobId: printJobId,
          usedFallback: false,
          fallbackReason: 'printer_record_id_missing',
          errorMessage: 'printer_record_id_missing',
          level: 'error',
        );
        return PrinterActionResult(
          ok: false,
          status: 'printer_record_id_missing',
          message:
              'Yazıcı kaydı bozuk (printerRecordId yok). Lütfen yazıcıyı yeniden kaydedin ve eşleştirin.',
          printer: resolvedPrinter,
        );
      }
    }
    _logRoleTestEvent(
      restaurantId: restaurantId,
      role: resolvedRole ?? requestedRole,
      event: _resolvedPrinterEvent(resolvedRole ?? requestedRole),
      message: resolvedRole == PrinterSetupRole.mutfak
          ? 'Mutfak rol yazıcısı çözüldü.'
          : 'Adisyon rol yazıcısı çözüldü.',
      printer: resolvedPrinter,
      details: <String, dynamic>{
        'requestedPrinterId': printerId?.trim(),
        'bridgePrinterId': resolvedPrinter.id,
      },
    );
    if (!resolvedPrinter.isAvailable) {
      final message = resolvedPrinter.os == DesktopPrinterOs.windows
          ? 'Yazici cevrimdisi'
          : 'Yazici bulunamadi';
      if (testSource == 'role_test') {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'role_test_print_failure',
              message: 'Rol test baskısı için çözülen yazıcı çevrimdışı.',
              level: 'error',
              role: (resolvedRole ?? requestedRole)?.value,
              printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
              queueName: resolvedPrinter.queueName,
              backend: resolvedPrinter.backend.value,
              details: <String, dynamic>{
                'error': message,
                'technicalMessage':
                    resolvedPrinter.lastError ?? resolvedPrinter.statusMessage,
              },
            )
            .ignore();
      }
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: 'physical_print_failure',
        level: 'error',
        message: 'Test fişi için çözülen yazıcı çevrimdışı.',
        printer: resolvedPrinter,
        details: <String, dynamic>{
          'error': message,
          'technicalMessage':
              resolvedPrinter.lastError ?? resolvedPrinter.statusMessage,
        },
      );
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_failed',
        flowName: flowName,
        source: source,
        role: (resolvedRole ?? requestedRole)?.value,
        documentType: 'test',
        printer: resolvedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: message,
        level: 'error',
      );
      return PrinterActionResult(
        ok: false,
        status: 'printer_offline',
        message: message,
        printer: resolvedPrinter,
        technicalMessage:
            resolvedPrinter.lastError ?? resolvedPrinter.statusMessage,
      );
    }
    if (resolvedPrinter.os == DesktopPrinterOs.windows &&
        WindowsPrinterClassification.isNotRecommended(resolvedPrinter)) {
      final warning =
          WindowsPrinterClassification.selectionWarningFor(resolvedPrinter) ??
          resolvedPrinter.statusMessage ??
          'Bu Windows hedefi ESC/POS termal baskı için uygun değildir.';
      return PrinterActionResult(
        ok: false,
        status: 'printer_not_recommended',
        message: warning,
        printer: resolvedPrinter,
        technicalMessage: resolvedPrinter.statusMessage,
      );
    }
    if (resolvedPrinter.os != DesktopPrinterOs.windows &&
        !resolvedPrinter.canPrint) {
      if (testSource == 'role_test') {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'role_test_print_failure',
              message: 'Rol test baskısı için Windows yazıcısı hazır değil.',
              level: 'error',
              role: (resolvedRole ?? requestedRole)?.value,
              printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
              queueName: resolvedPrinter.queueName,
              backend: resolvedPrinter.backend.value,
              details: <String, dynamic>{
                'error': 'printer_warning',
                'technicalMessage':
                    resolvedPrinter.statusMessage ?? resolvedPrinter.lastError,
              },
            )
            .ignore();
      }
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: 'physical_print_failure',
        level: 'error',
        message: 'Windows yazıcısı test baskısı için hazır değil.',
        printer: resolvedPrinter,
        details: <String, dynamic>{
          'error': 'printer_warning',
          'technicalMessage':
              resolvedPrinter.statusMessage ?? resolvedPrinter.lastError,
        },
      );
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_failed',
        flowName: flowName,
        source: source,
        role: (resolvedRole ?? requestedRole)?.value,
        documentType: 'test',
        printer: resolvedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: 'printer_warning',
        level: 'error',
      );
      return PrinterActionResult(
        ok: false,
        status: 'printer_warning',
        message: 'Windows yazicisi test icin hazir degil',
        printer: resolvedPrinter,
        technicalMessage:
            resolvedPrinter.statusMessage ?? resolvedPrinter.lastError,
      );
    }

    final isTcpOnlyTest = resolvedPrinter.backend == DesktopPrinterBackend.tcp;
    final resolvedTcpHost = isTcpOnlyTest ? _printerHost(resolvedPrinter) : '';
    final resolvedTcpPort = isTcpOnlyTest ? _printerPort(resolvedPrinter) : 0;
    final service = _printServiceFactory();
    try {
      final encodingSelection = isTcpOnlyTest
          ? null
          : await resolveEncodingSelection(
              restaurantId: restaurantId,
              printer: resolvedPrinter,
            );
      if (testSource == 'role_test' &&
          (resolvedRole ?? requestedRole) != null) {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'role_test_print_attempt',
              message: 'Rol test baskısı fiziksel yazıcıya gönderiliyor.',
              role: (resolvedRole ?? requestedRole)?.value,
              printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
              queueName: resolvedPrinter.queueName,
              backend: resolvedPrinter.backend.value,
              details: <String, dynamic>{'route': '/print/test'},
            )
            .ignore();
      }
      final dispatchLog = <String, dynamic>{
        'selectedPrinter.id': resolvedPrinter.id,
        'selectedPrinter.name': resolvedPrinter.displayName,
        'selectedPrinter.queue': resolvedPrinter.queueName,
        'selectedPrinter.backend': resolvedPrinter.backend.value,
        'selectedPrinter.connectionType':
            resolvedPrinter.raw['connectionType']?.toString() ??
            resolvedPrinter.raw['connection_type']?.toString(),
        'payload.printer_id': resolvedPrinter.id,
        'payload.printer_name': resolvedPrinter.queueName,
        'document_type': 'test',
        'render_mode': 'text',
        'test_mode': isTcpOnlyTest ? 'ethernet_test' : 'escpos_short',
        'spool_mode':
            resolvedPrinter.backend == DesktopPrinterBackend.windowsSpool
            ? 'RAW'
            : '-',
        'resolutionSource': explicitLivePrinter != null
            ? 'explicit_live'
            : 'resolved',
        'allowRoleFallback': allowRoleFallback,
        'skipSetupSnapshot': isTcpOnlyTest,
        'targetHost': isTcpOnlyTest ? resolvedTcpHost : null,
        'targetPort': isTcpOnlyTest ? resolvedTcpPort : null,
      };
      debugPrint('[TEST_PRINT_DISPATCH] ${jsonEncode(dispatchLog)}');
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: 'physical_print_called',
        message: 'Fiziksel test baskısı çağrıldı.',
        printer: resolvedPrinter,
        details: <String, dynamic>{'route': '/print/test', ...dispatchLog},
      );
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_started',
        flowName: flowName,
        source: source,
        role: (resolvedRole ?? requestedRole)?.value,
        documentType: 'test',
        printer: resolvedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        details: <String, dynamic>{'route': '/print/test'},
      );
      final response = await _dispatchBridgeTest(
        service: service,
        printer: resolvedPrinter,
        targetHost: isTcpOnlyTest && resolvedTcpHost.isNotEmpty
            ? resolvedTcpHost
            : null,
        targetPort: isTcpOnlyTest && resolvedTcpPort > 0
            ? resolvedTcpPort
            : null,
        encoding: encodingSelection?.encoding,
        codePage: encodingSelection?.codePage,
        extraBody: isTcpOnlyTest
            ? <String, dynamic>{
                'document_type':
                    (resolvedRole ?? requestedRole) == PrinterSetupRole.mutfak
                    ? 'kitchen'
                    : 'receipt',
                'printer_role': (resolvedRole ?? requestedRole)?.value,
                'test_source': testSource,
              }
            : null,
        renderMode: isTcpOnlyTest ? 'image' : 'text',
        testMode: isTcpOnlyTest ? 'ethernet_test' : 'escpos_short',
      );
      final verification = _verifyBridgeTestResult(
        printer: resolvedPrinter,
        response: response,
      );
      final ok = verification.ok;
      final message = verification.message;
      final result = PrinterActionResult(
        ok: ok,
        status: verification.status,
        message: message,
        printer: resolvedPrinter.copyWith(
          lastTestStatus: ok
              ? (verification.status == 'ready' ? 'ok' : verification.status)
              : 'failed',
          lastError: ok && verification.status != 'ready'
              ? null
              : (ok ? null : message),
        ),
        raw: response,
      );
      await _persistTestResult(
        restaurantId: restaurantId,
        role: resolvedRole,
        printer: resolvedPrinter,
        result: result,
      );
      await _recordDbTestResult(
        restaurantId: restaurantId,
        printer: resolvedPrinter,
        result: result,
      );
      _log(
        'testPrint',
        'restaurantId=$restaurantId role=${resolvedRole?.value ?? role?.value ?? '-'} '
            'printerId=${resolvedPrinter.id} backend=${resolvedPrinter.backend.value} '
            'queue=${resolvedPrinter.queueName} recordId=${resolvedPrinter.printerRecordId ?? '-'} ok=$ok',
      );
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: ok ? 'physical_print_success' : 'physical_print_failure',
        level: ok ? 'info' : 'error',
        message: ok
            ? 'Fiziksel test baskısı başarılı oldu.'
            : 'Fiziksel test baskısı başarısız oldu.',
        printer: resolvedPrinter,
        details: <String, dynamic>{
          'route': '/print/test',
          'bridgeResult': response ?? const <String, dynamic>{},
          if (!ok) 'error': message,
        },
      );
      if (ok) {
        await _logCupsAcceptedWithoutPhysicalConfirmation(
          restaurantId: restaurantId,
          flowName: flowName,
          source: source,
          role: (resolvedRole ?? requestedRole)?.value,
          documentType: 'test',
          printer: resolvedPrinter,
          response: response,
          storeId: storeId,
          tableId: tableId,
          printJobId: printJobId,
        );
      }
      await _runtimeLog(
        restaurantId: restaurantId,
        event: ok ? 'physical_print_success' : 'physical_print_failed',
        flowName: flowName,
        source: source,
        role: (resolvedRole ?? requestedRole)?.value,
        documentType: 'test',
        printer: resolvedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: ok ? null : message,
        level: ok ? 'info' : 'error',
        details: <String, dynamic>{
          'route': '/print/test',
          'bridgeResult': response ?? const <String, dynamic>{},
        },
      );
      if (testSource == 'role_test') {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: ok ? 'role_test_print_success' : 'role_test_print_failure',
              message: ok
                  ? 'Rol test baskısı başarılı oldu.'
                  : 'Rol test baskısı başarısız oldu.',
              level: ok ? 'info' : 'error',
              role: (resolvedRole ?? requestedRole)?.value,
              printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
              queueName: resolvedPrinter.queueName,
              backend: resolvedPrinter.backend.value,
              details: <String, dynamic>{
                'route': '/print/test',
                'bridgeResult': response ?? const <String, dynamic>{},
                if (!ok) 'error': message,
              },
            )
            .ignore();
      }
      if (ok && testSource == 'direct_test') {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'direct_test_print_success',
              message: 'Direkt test baskısı başarılı oldu.',
              role: (resolvedRole ?? requestedRole)?.value,
              printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
              queueName: resolvedPrinter.queueName,
              backend: resolvedPrinter.backend.value,
              details: <String, dynamic>{
                'route': '/print/test',
                'bridgeResult': response ?? const <String, dynamic>{},
              },
            )
            .ignore();
      }
      return result;
    } catch (error, stackTrace) {
      debugPrint(
        '[PrintOrchestrator] printTestReceipt failed '
        'restaurantId=$restaurantId printerId=${resolvedPrinter.id} error=$error',
      );
      debugPrint('$stackTrace');
      final raw =
          (error is LocalPrintServiceException &&
              error.details is Map<String, dynamic>)
          ? (error.details! as Map<String, dynamic>)
          : null;
      final result = PrinterActionResult(
        ok: false,
        status: 'test_failed',
        message: _friendlyBridgeFailure(error),
        printer: resolvedPrinter.copyWith(
          lastTestStatus: 'failed',
          lastError: error.toString(),
        ),
        technicalMessage: error.toString(),
        raw: raw,
      );
      await _persistTestResult(
        restaurantId: restaurantId,
        role: resolvedRole,
        printer: resolvedPrinter,
        result: result,
      );
      await _recordDbTestResult(
        restaurantId: restaurantId,
        printer: resolvedPrinter,
        result: result,
      );
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: 'physical_print_failure',
        level: 'error',
        message: 'Fiziksel test baskısı bridge hatası verdi.',
        printer: resolvedPrinter,
        details: <String, dynamic>{
          'route': '/print/test',
          'error': error.toString(),
        },
      );
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_failed',
        flowName: flowName,
        source: source,
        role: (resolvedRole ?? requestedRole)?.value,
        documentType: 'test',
        printer: resolvedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: error.toString(),
        level: 'error',
        details: <String, dynamic>{'route': '/print/test'},
      );
      if (testSource == 'role_test') {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'role_test_print_failure',
              message: 'Rol test baskısı bridge hatası verdi.',
              level: 'error',
              role: (resolvedRole ?? requestedRole)?.value,
              printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
              queueName: resolvedPrinter.queueName,
              backend: resolvedPrinter.backend.value,
              details: <String, dynamic>{
                'route': '/print/test',
                'error': error.toString(),
              },
            )
            .ignore();
      }
      return result;
    } finally {
      service.dispose();
    }
  }

  Future<PrinterActionResult> printBridgeTest({
    required String restaurantId,
    String? printerId,
    String? printerName,
    UnifiedPrinterModel? explicitPrinter,
    bool skipSetupSnapshot = false,
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    Map<String, dynamic>? extraBody,
    String renderMode = 'image',
    String testMode = 'escpos_short',
    String flowName = 'generic_printer_test',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    if (skipSetupSnapshot) {
      final requestedPrinter =
          explicitPrinter ??
          _buildDirectTcpPrinterFromTarget(
            targetHost: targetHost,
            targetPort: targetPort,
            printerId: printerId,
            printerName: printerName,
          );
      final service = _printServiceFactory();
      try {
        final response = await _dispatchBridgeTest(
          service: service,
          printer: requestedPrinter,
          printerId: printerId,
          printerName: printerName,
          targetHost: targetHost,
          targetPort: targetPort,
          encoding: encoding,
          codePage: codePage,
          extraBody: extraBody,
          renderMode: renderMode,
          testMode: testMode,
        );
        final verification = _verifyBridgeTestResult(
          printer: requestedPrinter,
          response: response,
        );
        return PrinterActionResult(
          ok: verification.ok,
          status: verification.status,
          message: verification.message,
          printer: requestedPrinter,
          raw: response,
        );
      } catch (error) {
        final raw =
            (error is LocalPrintServiceException &&
                error.details is Map<String, dynamic>)
            ? (error.details! as Map<String, dynamic>)
            : null;
        return PrinterActionResult(
          ok: false,
          status: 'test_failed',
          message: _friendlyBridgeFailure(error),
          technicalMessage: error.toString(),
          printer: requestedPrinter,
          raw: raw,
        );
      } finally {
        service.dispose();
      }
    }
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
    );
    if (!_isPrintSystemEnabledFromSnapshot(snapshot)) {
      return _printSystemDisabledResult();
    }
    final requestedPrinterId = printerId?.trim() ?? '';
    final requestedPrinterName = printerName?.trim() ?? '';
    UnifiedPrinterModel? requestedPrinter = explicitPrinter;
    if (requestedPrinter == null && requestedPrinterId.isNotEmpty) {
      requestedPrinter = await _resolvePrinterForTest(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: null,
        printerId: requestedPrinterId,
      );
    } else if (requestedPrinter == null && requestedPrinterName.isNotEmpty) {
      requestedPrinter = _resolvePrinterByQueueOrName(
        printers: snapshot.printers,
        queueName: requestedPrinterName,
        displayName: requestedPrinterName,
      );
      if (requestedPrinter != null) {
        requestedPrinter = await _resolveStoredPrinterCandidate(
          restaurantId: restaurantId,
          snapshot: snapshot,
          candidate: requestedPrinter,
        );
      }
    }
    // If the caller supplied a queue name but we couldn't match it to a scanned printer,
    // still try dispatching via an embedded CUPS printer payload to avoid falling back
    // to the bridge's default queue (which may be unset or different).
    if (requestedPrinter == null &&
        requestedPrinterId.isEmpty &&
        requestedPrinterName.isNotEmpty &&
        targetHost == null) {
      requestedPrinter = UnifiedPrinterModel(
        id: 'cups:$requestedPrinterName',
        displayName: requestedPrinterName,
        queueName: requestedPrinterName,
        backend: DesktopPrinterBackend.cups,
        os: snapshot.os,
        isAvailable: true,
        canPrint: true,
        raw: <String, dynamic>{
          'source': 'synthetic_queue',
          'queue': requestedPrinterName,
          'backend': 'cups',
        },
      );
    }

    final service = _printServiceFactory();
    try {
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'working_test_button_called',
            message:
                'Genel test baskısı ortak orchestrator üzerinden çağrıldı.',
            details: <String, dynamic>{
              'requestedPrinterId': requestedPrinterId,
              'requestedPrinterName': requestedPrinterName,
              'targetHost': targetHost,
              'targetPort': targetPort,
            },
          )
          .ignore();
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_started',
        flowName: flowName,
        source: source,
        documentType: 'test',
        printer: requestedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        details: <String, dynamic>{
          'route': '/print/test',
          'requested_printer_id': requestedPrinterId,
          'requested_printer_name': requestedPrinterName,
        },
      );
      // TCP-only ethernet tests must not fallback to CUPS
      final isTcpOnlyTest =
          testMode == 'ethernet_test' &&
          requestedPrinter?.backend == DesktopPrinterBackend.tcp;
      final allowBackendFallback =
          requestedPrinter != null &&
          _allowAutomaticBackendFallback(
            printer: requestedPrinter,
            documentType: 'receipt',
          );
      final hasConflictWarning = !isTcpOnlyTest && allowBackendFallback
          ? await _hasUsbCupsConflictForPrinter(
              restaurantId: restaurantId,
              printer: requestedPrinter,
            )
          : false;
      final fallbackPrinter = hasConflictWarning && !isTcpOnlyTest
          ? await _resolveUsbConflictCupsFallbackPrinter(
              restaurantId: restaurantId,
              printer: requestedPrinter,
            )
          : null;
      final dispatchPrinter = fallbackPrinter ?? requestedPrinter;

      final response = await _dispatchBridgeTest(
        service: service,
        printer: dispatchPrinter,
        printerId: requestedPrinterId,
        printerName: requestedPrinterName,
        targetHost: targetHost,
        targetPort: targetPort,
        encoding: encoding,
        codePage: codePage,
        extraBody: extraBody,
        renderMode: renderMode,
        testMode: testMode,
      );
      UnifiedPrinterModel? resolvedPrinter =
          dispatchPrinter ??
          await _resolvePrinterFromBridgeTestResponse(
            restaurantId: restaurantId,
            snapshot: snapshot,
            response: response,
          );
      if (resolvedPrinter != null) {
        resolvedPrinter = _normalizePrinterForPhysicalDispatch(
          await _attachStoredPrinterRecordId(
            restaurantId: restaurantId,
            printer: resolvedPrinter,
          ),
        );
      }
      final verification = _verifyBridgeTestResult(
        printer: resolvedPrinter ?? requestedPrinter,
        response: response,
      );
      final ok = verification.ok;
      final usedTcpOnlyTest =
          testMode == 'ethernet_test' &&
          requestedPrinter?.backend == DesktopPrinterBackend.tcp;
      final message = fallbackPrinter == null || usedTcpOnlyTest
          ? verification.message
          : 'USB Direct macOS tarafından kilitli olabilir; test CUPS yolu ile gönderildi. ${verification.message}';
      final result = PrinterActionResult(
        ok: ok,
        status: verification.status,
        message: message,
        printer: resolvedPrinter,
        raw: response,
      );
      if (ok && resolvedPrinter != null) {
        await saveWorkingPrinter(restaurantId, resolvedPrinter);
        await _recordDbTestResult(
          restaurantId: restaurantId,
          printer: resolvedPrinter,
          result: result,
        );
        await _runtimeLog(
          restaurantId: restaurantId,
          event: 'printer_test_success_promoted_to_canonical',
          flowName: flowName,
          source: source,
          documentType: 'test',
          printer: resolvedPrinter,
          storeId: storeId,
          tableId: tableId,
          printJobId: printJobId,
          details: <String, dynamic>{
            'route': '/print/test',
            'requested_printer_id': requestedPrinterId,
            'requested_printer_name': requestedPrinterName,
          },
        );
      }
      if (ok) {
        await _logCupsAcceptedWithoutPhysicalConfirmation(
          restaurantId: restaurantId,
          flowName: flowName,
          source: source,
          documentType: 'test',
          printer: resolvedPrinter ?? requestedPrinter,
          response: response,
          storeId: storeId,
          tableId: tableId,
          printJobId: printJobId,
        );
      }
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: ok ? 'physical_print_success' : 'physical_print_failure',
            message: ok
                ? 'Genel test baskısı başarılı oldu.'
                : 'Genel test baskısı başarısız oldu.',
            level: ok ? 'info' : 'error',
            printerId: resolvedPrinter?.printerRecordId ?? resolvedPrinter?.id,
            queueName: resolvedPrinter?.queueName,
            backend: resolvedPrinter?.backend.value,
            details: <String, dynamic>{
              'route': '/print/test',
              'bridgeResult': response ?? const <String, dynamic>{},
              if (!ok) 'error': message,
            },
          )
          .ignore();
      await _runtimeLog(
        restaurantId: restaurantId,
        event: ok ? 'physical_print_success' : 'physical_print_failed',
        flowName: flowName,
        source: source,
        documentType: 'test',
        printer: resolvedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: ok ? null : message,
        level: ok ? 'info' : 'error',
        details: <String, dynamic>{
          'route': '/print/test',
          'bridgeResult': response ?? const <String, dynamic>{},
        },
      );
      return result;
    } catch (error) {
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'physical_print_failure',
            message: 'Genel test baskısı bridge hatası verdi.',
            level: 'error',
            details: <String, dynamic>{
              'route': '/print/test',
              'error': error.toString(),
            },
          )
          .ignore();
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'physical_print_failed',
        flowName: flowName,
        source: source,
        documentType: 'test',
        printer: requestedPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: error.toString(),
        level: 'error',
        details: <String, dynamic>{'route': '/print/test'},
      );
      final raw =
          (error is LocalPrintServiceException &&
              error.details is Map<String, dynamic>)
          ? (error.details! as Map<String, dynamic>)
          : null;
      return PrinterActionResult(
        ok: false,
        status: 'test_failed',
        message: _friendlyBridgeFailure(error),
        technicalMessage: error.toString(),
        raw: raw,
      );
    } finally {
      service.dispose();
    }
  }

  UnifiedPrinterModel? _buildDirectTcpPrinterFromTarget({
    required String? targetHost,
    required int? targetPort,
    required String? printerId,
    required String? printerName,
  }) {
    final host = targetHost?.trim() ?? '';
    if (host.isEmpty) return null;
    final port = targetPort ?? PrinterModel.ethernetDefaultPort;
    final id = printerId?.trim().isNotEmpty == true
        ? printerId!.trim()
        : PrinterModel.ethernetPrinterId(host: host, port: port);
    final name = printerName?.trim().isNotEmpty == true
        ? printerName!.trim()
        : 'Ethernet Yazıcı $host';
    return UnifiedPrinterModel(
      id: id,
      displayName: name,
      queueName: name,
      backend: DesktopPrinterBackend.tcp,
      os: detectOs(),
      isAvailable: true,
      canPrint: true,
      statusLevel: 'ready',
      statusMessage: 'Ethernet yazıcı hazır.',
      raw: <String, dynamic>{
        'id': id,
        'name': name,
        'backend': PrinterModel.ethernetBridgeBackend,
        'transportType': PrinterModel.ethernetBridgeTransport,
        'transport_type': PrinterModel.ethernetBridgeTransport,
        'host': host,
        'ip_address': host,
        'ipAddress': host,
        'port': port,
      },
    );
  }

  Future<UnifiedPrinterModel?> resolvePrinterForRole({
    required String restaurantId,
    required PrinterSetupRole role,
    bool? allowWorkingPrinterFallback,
    bool preferRemoteFirst = false,
    String flowName = 'role_resolution',
    String source = 'orchestrator',
    String documentType = '-',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final allowFallback = _allowWorkingPrinterFallbackForRole(
      role,
      allowWorkingPrinterFallback,
    );
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
    );
    final candidate = _resolveSelection(
      role: role,
      localConfig: snapshot.localConfig,
      remoteConfig: snapshot.remoteConfig,
      printers: snapshot.printers,
      os: snapshot.os,
      preferRemoteFirst: preferRemoteFirst,
    );
    final printerRecordId =
        candidate?.printerRecordId?.trim() ??
        (role == PrinterSetupRole.adisyon
            ? snapshot.selectedReceiptPrinterRecordId?.trim()
            : snapshot.selectedKitchenPrinterRecordId?.trim()) ??
        '';

    if (printerRecordId.isNotEmpty) {
      final storedPrinter = await _printerRepository.getPrinterByRecordId(
        printerRecordId,
      );
      if (storedPrinter != null) {
        final resolved = _resolveUnifiedPrinterFromLegacy(
          storedPrinter,
          printers: snapshot.printers,
          os: snapshot.os,
        );
        if (resolved != null &&
            resolved.id.trim().isNotEmpty &&
            resolved.queueName.trim().isNotEmpty &&
            resolved.backend.value.trim().isNotEmpty) {
          final normalized = resolved.copyWith(
            printerRecordId: storedPrinter.id,
          );
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'printer_resolution',
                message: 'Yazıcı rolü başarıyla çözüldü.',
                level: 'info',
                role: role.value,
                printerId: normalized.printerRecordId,
                queueName: normalized.queueName,
                backend: normalized.backend.value,
                details: <String, dynamic>{
                  'source': 'role_mapping',
                  'bridgePrinterId': normalized.id,
                  'resolvedPrinter': normalized.toJson(),
                },
              )
              .ignore();
          await _runtimeLog(
            restaurantId: restaurantId,
            event: 'role_printer_resolved',
            flowName: flowName,
            source: source,
            role: role.value,
            documentType: documentType,
            printer: normalized,
            storeId: storeId,
            tableId: tableId,
            printJobId: printJobId,
          );
          return normalized;
        }
      }

      // Production rule: if the user already has an explicit role mapping,
      // do not silently fall back to a different printer (e.g. a "working"
      // printer from a previous test run). Treat this as a stale/missing device.
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'printer_resolution_failed',
            message: 'Yazıcı rolü kayıtlı ama fiziksel yazıcıya çözümlenemedi.',
            level: 'error',
            role: role.value,
            printerId: printerRecordId,
            details: <String, dynamic>{'source': 'bridge_printer_resolution'},
          )
          .ignore();
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'role_printer_resolved',
        flowName: flowName,
        source: source,
        role: role.value,
        documentType: documentType,
        printerRecordId: printerRecordId,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: 'bridge_printer_resolution_failed',
        level: 'error',
      );
      return null;
    }

    final persistedConfig = await _loadLocalConfig(restaurantId);
    if (persistedConfig?.selectionForRole(role) != null && candidate == null) {
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'printer_resolution_failed',
            message:
                'Kayıtlı rol eşlemesi bu bilgisayarda canlı yazıcıya çözümlenemedi.',
            level: 'error',
            role: role.value,
            details: const <String, dynamic>{'source': 'stale_role_mapping'},
          )
          .ignore();
      return null;
    }

    final workingPrinter = allowFallback
        ? await _resolveWorkingPrinter(
            restaurantId: restaurantId,
            snapshot: snapshot,
          )
        : null;
    if (workingPrinter != null) {
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'printer_resolution',
            message:
                'Rol kaydı bulunamadı, testten geçen canonical yazıcı kullanıldı.',
            level: 'info',
            role: role.value,
            printerId: workingPrinter.printerRecordId ?? workingPrinter.id,
            queueName: workingPrinter.queueName,
            backend: workingPrinter.backend.value,
            details: <String, dynamic>{'source': 'working_printer_store'},
          )
          .ignore();
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'role_printer_resolved',
        flowName: flowName,
        source: source,
        role: role.value,
        documentType: documentType,
        printer: workingPrinter,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        usedFallback: true,
        fallbackReason: 'working_printer_store',
      );
      return workingPrinter;
    }
    _eventLogService
        .append(
          restaurantId: restaurantId,
          event: 'printer_resolution_failed',
          message: 'Yazıcı rolü kaydı bulunamadı.',
          level: 'error',
          role: role.value,
          details: <String, dynamic>{'source': 'local_and_remote_role_mapping'},
        )
        .ignore();
    await _runtimeLog(
      restaurantId: restaurantId,
      event: 'role_printer_resolved',
      flowName: flowName,
      source: source,
      role: role.value,
      documentType: documentType,
      printerRecordId: printerRecordId,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      errorMessage: printerRecordId.isNotEmpty
          ? 'bridge_printer_resolution_failed'
          : 'role_mapping_missing',
      level: 'error',
    );
    return null;
  }

  Future<UnifiedPrinterModel?> resolvePrinterForDispatch({
    required String restaurantId,
    required PrinterSetupRole role,
    String? printerId,
    bool? allowWorkingPrinterFallback,
    String flowName = 'dispatch_resolution',
    String source = 'orchestrator',
    String documentType = '-',
    String? storeId,
    String? tableId,
    String? printJobId,
    bool minimalSnapshot = false,
  }) async {
    final allowFallback = _allowWorkingPrinterFallbackForRole(
      role,
      allowWorkingPrinterFallback,
    );
    final normalizedRestaurantId = restaurantId.trim();
    final directId = printerId?.trim() ?? '';
    if (minimalSnapshot &&
        directId.isNotEmpty &&
        normalizedRestaurantId.isNotEmpty) {
      final cached = _snapshotCache[normalizedRestaurantId];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) <= _snapshotCacheTtl) {
        final cachedResolved = await _resolvePrinterForTest(
          restaurantId: normalizedRestaurantId,
          snapshot: cached.snapshot,
          role: role,
          printerId: directId,
          allowWorkingPrinterFallback: allowFallback,
        );
        if (cachedResolved != null) {
          return _normalizePrinterForPhysicalDispatch(cachedResolved);
        }
      }
    }
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      minimal: minimalSnapshot,
    );
    final resolved = await _resolvePrinterForTest(
      restaurantId: restaurantId,
      snapshot: snapshot,
      role: role,
      printerId: printerId,
      allowWorkingPrinterFallback: allowFallback,
    );
    if (resolved == null) {
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'role_printer_resolved',
        flowName: flowName,
        source: source,
        role: role.value,
        documentType: documentType,
        printerRecordId: printerId,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
        errorMessage: 'printer_not_found',
        level: 'error',
      );
      return null;
    }
    final normalized = _normalizePrinterForPhysicalDispatch(resolved);
    await _runtimeLog(
      restaurantId: restaurantId,
      event: 'role_printer_resolved',
      flowName: flowName,
      source: source,
      role: role.value,
      documentType: documentType,
      printer: normalized,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      usedFallback:
          printerId?.trim().isNotEmpty == true &&
          normalized.id != printerId?.trim() &&
          normalized.printerRecordId != printerId?.trim(),
      fallbackReason:
          printerId?.trim().isNotEmpty == true &&
              normalized.id != printerId?.trim() &&
              normalized.printerRecordId != printerId?.trim()
          ? 'requested_printer_mapped_to_canonical'
          : null,
    );
    return normalized;
  }

  Future<PrinterActionResult> assignWorkingPrinterToRoles({
    required String restaurantId,
    Session? session,
    bool markThisDeviceAsPrintStation = false,
  }) async {
    final snapshot = await loadSetupSnapshot(restaurantId: restaurantId);
    final workingPrinter = await _resolveWorkingPrinter(
      restaurantId: restaurantId,
      snapshot: snapshot,
    );
    if (workingPrinter == null) {
      return const PrinterActionResult(
        ok: false,
        status: 'printer_not_found',
        message: 'Testten geçen canonical yazıcı bulunamadı.',
      );
    }
    final requestedId =
        workingPrinter.printerRecordId?.trim().isNotEmpty == true
        ? workingPrinter.printerRecordId!.trim()
        : workingPrinter.id;
    return savePrinterRoles(
      restaurantId: restaurantId,
      receiptPrinterId: requestedId,
      kitchenPrinterId: requestedId,
      session: session,
      markThisDeviceAsPrintStation: markThisDeviceAsPrintStation,
    );
  }

  Future<UnifiedPrinterModel?> resolveKitchenPrinterForStationOrRole({
    required String restaurantId,
    String? stationId,
    String? stationName,
    String? tableId,
    String? orderId,
    String? printJobId,
    String flowName = 'kitchen_order',
    String source = 'orchestrator',
    bool minimalSnapshot = false,
  }) async {
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
      tableId: tableId,
      printJobId: printJobId,
      minimal: minimalSnapshot,
    );
    return _resolveKitchenPrinterForStationOrRole(
      restaurantId: restaurantId,
      snapshot: snapshot,
      stationId: stationId,
      stationName: stationName,
      tableId: tableId,
      orderId: orderId,
      printJobId: printJobId,
      flowName: flowName,
      source: source,
    );
  }

  Future<PrinterActionResult> savePrinterRoles({
    required String restaurantId,
    required String receiptPrinterId,
    required String kitchenPrinterId,
    Session? session,
    bool markThisDeviceAsPrintStation = false,
    bool requireSuccessfulRoleTests = false,
    String? stationPlatform,
    String flowName = 'role_mapping_save',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      flowName: '${flowName}_hydrate',
      source: source,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
    );
    final receiptPrinter = await _resolveSavedPrinterSelection(
      snapshot: snapshot,
      requestedId: receiptPrinterId,
      role: PrinterSetupRole.adisyon,
    );
    final kitchenPrinter = await _resolveSavedPrinterSelection(
      snapshot: snapshot,
      requestedId: kitchenPrinterId,
      role: PrinterSetupRole.mutfak,
    );

    if (!isSelectableLivePrinter(receiptPrinter)) {
      return PrinterActionResult(
        ok: false,
        status: 'printer_not_live',
        message:
            'Adisyon yazıcısı canlı taramada bulunamadı. Önce test fişi ile doğrulayın.',
        printer: receiptPrinter,
      );
    }
    if (!isSelectableLivePrinter(kitchenPrinter)) {
      return PrinterActionResult(
        ok: false,
        status: 'printer_not_live',
        message:
            'Mutfak yazıcısı canlı taramada bulunamadı. Önce test fişi ile doğrulayın.',
        printer: kitchenPrinter,
      );
    }
    if (!receiptPrinter.canPrint) {
      return PrinterActionResult(
        ok: false,
        status: 'printer_offline',
        message: 'Adisyon yazicisi hazir degil',
        printer: receiptPrinter,
      );
    }
    if (!kitchenPrinter.canPrint) {
      return PrinterActionResult(
        ok: false,
        status: 'printer_offline',
        message: 'Mutfak yazicisi hazir degil',
        printer: kitchenPrinter,
      );
    }

    if (requireSuccessfulRoleTests) {
      final samePrinterSelected =
          receiptPrinter.id.trim() == kitchenPrinter.id.trim();
      final receiptTestReady = _latestTestStillMatches(
        snapshot.localConfig?.receiptTest,
        receiptPrinter,
      );
      final kitchenTestReady = _latestTestStillMatches(
        snapshot.localConfig?.kitchenTest,
        kitchenPrinter,
      );
      final sharedPrinterTestReady =
          samePrinterSelected && (receiptTestReady || kitchenTestReady);
      if ((!receiptTestReady && !sharedPrinterTestReady) ||
          (!kitchenTestReady && !sharedPrinterTestReady)) {
        debugPrint(
          '[PrinterRoleSave] error '
          'seller_id=$restaurantId store_id=${storeId ?? '-'} '
          'printer_id=${receiptPrinter.id} printer_name=${receiptPrinter.displayName} '
          'role=receipt+kitchen station_id=- area_id=- '
          'rpc=savePrinterRoles status=test_required '
          'receiptTestReady=$receiptTestReady kitchenTestReady=$kitchenTestReady '
          'samePrinter=$samePrinterSelected',
        );
        return const PrinterActionResult(
          ok: false,
          status: 'test_required',
          message:
              'Rolleri kaydetmeden önce adisyon ve mutfak için test fişi başarılı olmalı.',
        );
      }
    }

    debugPrint(
      '[PrinterRoleSave] request '
      'seller_id=$restaurantId store_id=${storeId ?? '-'} '
      'receipt_printer_id=${receiptPrinter.id} receipt_printer_name=${receiptPrinter.displayName} '
      'kitchen_printer_id=${kitchenPrinter.id} kitchen_printer_name=${kitchenPrinter.displayName} '
      'role=receipt+kitchen rpc=savePrinterRoles',
    );
    await _debugPrinterMappingSaveStart(
      restaurantId: restaurantId,
      receiptPrinter: receiptPrinter,
      kitchenPrinter: kitchenPrinter,
    );

    final canonicalSelections = <PrinterSetupRole, UnifiedPrinterModel>{
      PrinterSetupRole.adisyon: receiptPrinter,
      PrinterSetupRole.mutfak: kitchenPrinter,
    };
    var printerRecordSyncSaved = false;
    var stationConfigSaved = false;
    String? cloudWarning;
    try {
      final syncedSelections = await _syncPrinterRecords(
        restaurantId: restaurantId,
        selections: canonicalSelections,
      );
      canonicalSelections.addAll(syncedSelections);
      printerRecordSyncSaved = true;
    } catch (error, stackTrace) {
      debugPrint(
        '[PrintOrchestrator] printer role sync failed '
        'restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
      cloudWarning = 'Yerel kayıt yapıldı, bulut senkronu bekliyor.';
    }

    final canonicalReceiptPrinter =
        canonicalSelections[PrinterSetupRole.adisyon] ?? receiptPrinter;
    final canonicalKitchenPrinter =
        canonicalSelections[PrinterSetupRole.mutfak] ?? kitchenPrinter;
    final localConfig = PrinterSetupLocalConfig(
      restaurantId: restaurantId,
      os: detectOs(),
      receiptSelection: PrinterRoleSelection(
        role: PrinterSetupRole.adisyon,
        printer: canonicalReceiptPrinter,
      ),
      kitchenSelection: PrinterRoleSelection(
        role: PrinterSetupRole.mutfak,
        printer: canonicalKitchenPrinter,
      ),
      // Clear stale test status when role mapping changes. A previous failed
      // test must not block a newly saved canonical mapping.
      receiptTest: null,
      kitchenTest: null,
      savedAt: DateTime.now(),
      thisDeviceIsPrintStation: markThisDeviceAsPrintStation,
    );

    await _saveLocalConfig(localConfig);
    _logRoleMappingState(
      action: 'role_mapping_save',
      restaurantId: restaurantId,
      config: localConfig,
    );
    invalidateRoleMappingCache(restaurantId);
    if (markThisDeviceAsPrintStation) {
      await _printStationService.setThisDevicePrintStation(true);
    }
    await saveWorkingPrinter(restaurantId, canonicalReceiptPrinter);

    try {
      final normalizedPlatform = _printStationService.normalizeStationPlatform(
        stationPlatform ?? _printStationService.currentPlatformLabel(),
      );
      final roleMappings = _roleMappingsPayload(localConfig);
      final bridgePreset = _buildBridgePreset(
        platformName: normalizedPlatform,
        printer: canonicalReceiptPrinter,
      );
      if (markThisDeviceAsPrintStation && session != null) {
        final queueResponse = await _printStationService
            .configureLocalBridgeAsPrintStation(
              restaurantId: restaurantId,
              session: session,
              deviceName: _printStationService.currentDeviceName(),
              platformName: normalizedPlatform,
              receiptPrinterId: canonicalReceiptPrinter.id,
              receiptPrinterName: _printStationPrinterLabel(
                canonicalReceiptPrinter,
              ),
              kitchenPrinterId: canonicalKitchenPrinter.id,
              kitchenPrinterName: _printStationPrinterLabel(
                canonicalKitchenPrinter,
              ),
              bridgeTransportMode: bridgePreset['bridge_transport_mode'],
              bridgePrinterQueue: bridgePreset['bridge_printer_queue'],
              bridgeUsbVendorId: bridgePreset['bridge_usb_vendor_id'],
              bridgeUsbProductId: bridgePreset['bridge_usb_product_id'],
            );
        if (queueResponse?['ok'] != true) {
          throw StateError(
            queueResponse?['error']?.toString() ?? 'bridge_config_failed',
          );
        }
      }
      await _printStationService.saveStationConfiguration(
        restaurantId: restaurantId,
        deviceName: _printStationService.currentDeviceName(),
        platformName: normalizedPlatform,
        receiptPrinterId: _storagePrinterId(canonicalReceiptPrinter),
        receiptPrinterName: _printStationPrinterLabel(canonicalReceiptPrinter),
        kitchenPrinterId: _storagePrinterId(canonicalKitchenPrinter),
        kitchenPrinterName: _printStationPrinterLabel(canonicalKitchenPrinter),
        roleMappings: roleMappings,
      );
      await _printStationService.invalidateRoleMappingCacheState(
        restaurantId: restaurantId,
        roleMappings: roleMappings,
        source: flowName,
      );
      stationConfigSaved = true;
    } catch (error, stackTrace) {
      debugPrint(
        '[PrintOrchestrator] cloud role save failed '
        'restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
      cloudWarning = 'Yerel kayıt yapıldı, bulut senkronu bekliyor.';
    }
    final cloudSaved = printerRecordSyncSaved && stationConfigSaved;
    if (!cloudSaved) {
      await _saveLocalConfig(
        localConfig.copyWith(lastCloudWarning: cloudWarning),
      );
    }

    _log(
      'saveRoles',
      'restaurantId=$restaurantId receipt=${canonicalReceiptPrinter.id} '
          'receiptRecord=${canonicalReceiptPrinter.printerRecordId ?? '-'} '
          'kitchen=${canonicalKitchenPrinter.id} kitchenRecord=${canonicalKitchenPrinter.printerRecordId ?? '-'} '
          'cloudSaved=$cloudSaved '
          'printStation=$markThisDeviceAsPrintStation',
    );
    await _runtimeLog(
      restaurantId: restaurantId,
      event: 'role_mapping_saved',
      flowName: flowName,
      source: source,
      role: 'all',
      documentType: 'role_mapping',
      printer: canonicalReceiptPrinter,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
      usedFallback: !cloudSaved,
      fallbackReason: cloudSaved ? null : 'local_saved_only',
      errorMessage: cloudSaved ? null : cloudWarning,
      level: cloudSaved ? 'info' : 'warning',
      details: <String, dynamic>{
        'receipt_bridge_printer_id': canonicalReceiptPrinter.id,
        'receipt_printer_record_id':
            canonicalReceiptPrinter.printerRecordId ?? '-',
        'kitchen_bridge_printer_id': canonicalKitchenPrinter.id,
        'kitchen_printer_record_id':
            canonicalKitchenPrinter.printerRecordId ?? '-',
        'cloud_saved': cloudSaved,
        'printer_record_sync_saved': printerRecordSyncSaved,
        'station_config_saved': stationConfigSaved,
      },
    );

    debugPrint(
      '[PrinterRoleSave] ${cloudSaved ? 'success' : 'partial'} '
      'seller_id=$restaurantId store_id=${storeId ?? '-'} '
      'receipt_printer_id=${canonicalReceiptPrinter.id} '
      'kitchen_printer_id=${canonicalKitchenPrinter.id} '
      'cloud_saved=$cloudSaved station_config_saved=$stationConfigSaved',
    );
    final reloadedSnapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      forceRefresh: true,
      minimal: true,
      flowName: 'role_mapping_reloaded',
      source: source,
      storeId: storeId,
      tableId: tableId,
      printJobId: printJobId,
    );
    final reloadedReceipt =
        reloadedSnapshot.localConfig?.receiptSelection?.printer;
    final reloadedKitchen =
        reloadedSnapshot.localConfig?.kitchenSelection?.printer;
    debugPrint('[PrintOrchestrator][role_mapping_reloaded]');
    debugPrint(
      'receipt=${reloadedReceipt?.displayName ?? reloadedReceipt?.queueName ?? '-'}',
    );
    debugPrint(
      'kitchen=${reloadedKitchen?.displayName ?? reloadedKitchen?.queueName ?? '-'} '
      'backend=${reloadedKitchen?.backend.value ?? '-'} '
      'host=${reloadedKitchen == null ? '-' : _printerHost(reloadedKitchen)} '
      'port=${reloadedKitchen == null ? '-' : _printerPort(reloadedKitchen).toString()}',
    );
    debugPrint('[PrinterMapping][save_done]');
    return PrinterActionResult(
      ok: true,
      status: cloudSaved ? 'ready' : 'local_saved_only',
      message: cloudSaved
          ? 'Kurulum tamamlandi'
          : (cloudWarning ?? 'Yerel kayıt yapıldı, bulut senkronu bekliyor.'),
      localSaved: true,
      cloudSaved: cloudSaved,
    );
  }

  Future<PrinterActionResult> printPhysicalToPrinter(
    UnifiedPrinterModel printer,
    PrintPayload payload, {
    String? restaurantId,
    String flowName = 'physical_print',
    String? flowType,
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final dispatchWatch = Stopwatch()..start();
    var profileResolveMs = 0;
    var payloadBuildMs = 0;
    var bridgeRequestMs = 0;
    final fastFlow = _isFastPhysicalPrintFlow(flowType, flowName);
    if (!fastFlow && restaurantId != null && restaurantId.trim().isNotEmpty) {
      final snapshot = await loadSetupSnapshot(
        restaurantId: restaurantId,
        flowName: '${flowName}_hydrate',
        source: source,
        storeId: storeId,
        tableId: tableId,
        printJobId: printJobId,
      );
      if (!_isPrintSystemEnabledFromSnapshot(snapshot)) {
        return _printSystemDisabledResult();
      }
    }
    final normalizedPrinter = _normalizePrinterForPhysicalDispatch(printer);
    final allowBackendFallback = _allowAutomaticBackendFallback(
      printer: normalizedPrinter,
      documentType: payload.documentType,
    );
    final hasConflictWarning = fastFlow || !allowBackendFallback
        ? false
        : await _hasUsbCupsConflictForPrinter(
            restaurantId: restaurantId,
            printer: normalizedPrinter,
          );
    final fallbackPrinter = hasConflictWarning
        ? await _resolveUsbConflictCupsFallbackPrinter(
            restaurantId: restaurantId,
            printer: normalizedPrinter,
          )
        : null;
    final dispatchPrinter = fallbackPrinter ?? normalizedPrinter;
    if (!payload.isReceipt &&
        normalizedPrinter.backend == DesktopPrinterBackend.tcp &&
        dispatchPrinter.backend != DesktopPrinterBackend.tcp) {
      debugPrint('[KitchenPrinterResolve][expected]');
      debugPrint('role=mutfak');
      debugPrint('expectedPrinter=${normalizedPrinter.displayName}');
      debugPrint('expectedBackend=${normalizedPrinter.backend.value}');
      debugPrint('expectedHost=${_printerHost(normalizedPrinter)}');
      debugPrint('expectedPort=${_printerPort(normalizedPrinter)}');
      debugPrint('[KitchenPrinterResolve][actual]');
      debugPrint('actualPrinter=${dispatchPrinter.displayName}');
      debugPrint('actualBackend=${dispatchPrinter.backend.value}');
      debugPrint('[KitchenPrinterResolve][FINAL_MISMATCH]');
      debugPrint('expectedPrinter=${normalizedPrinter.displayName}');
      debugPrint('expectedBackend=${normalizedPrinter.backend.value}');
      debugPrint('actualPrinter=${dispatchPrinter.displayName}');
      debugPrint('actualBackend=${dispatchPrinter.backend.value}');
      debugPrint('blocked=true');
      debugPrint('reason=kitchen_would_fallback_to_adisyon_or_usb');
      return PrinterActionResult(
        ok: false,
        status: 'kitchen_printer_resolution_mismatch',
        message:
            'Mutfak yazıcısı Ethernet olarak seçili ama POS-58 çözüldü. Fallback engellendi.',
        printer: normalizedPrinter,
      );
    }
    final printerRole = payload.isReceipt
        ? PrinterSetupRole.adisyon
        : PrinterSetupRole.mutfak;
    final kitchenResolveSource = !payload.isReceipt
        ? _kitchenResolveSourceLabel(
            rawSource:
                _readText(payload.body['printer_resolution_source']).isNotEmpty
                ? _readText(payload.body['printer_resolution_source'])
                : _readText(
                    normalizedPrinter.raw['resolution_source'] ??
                        normalizedPrinter.raw['source'],
                  ),
            usedFallback: fallbackPrinter != null,
          )
        : '';
    final dispatchTarget = _dispatchTargetFromPrinter(
      printer: dispatchPrinter,
      documentType: payload.documentType,
      role: printerRole.value,
    );
    final requestPayload = _injectResolvedPrinterIntoPayload(
      Map<String, dynamic>.from(payload.body),
      printer: dispatchPrinter,
      printerRole: printerRole,
      jobRecord: payload.body,
    );
    requestPayload['document_type'] = payload.documentType;
    _applyPhysicalDispatchDefaults(
      requestPayload,
      printer: dispatchPrinter,
      flowType: flowType ?? flowName,
      endpoint: _physicalPrintEndpoint(payload),
    );
    if (dispatchPrinter.backend == DesktopPrinterBackend.tcp) {
      _stampTcpDispatchTarget(requestPayload, dispatchPrinter);
    }
    final resolvedKitchenRoute = !payload.isReceipt
        ? _kitchenDispatchRouteFromPrinter(normalizedPrinter)
        : null;
    final actualKitchenRoute = !payload.isReceipt
        ? _kitchenDispatchRouteFromPayload(
            requestPayload,
            fallbackPrinter: dispatchPrinter,
          )
        : null;
    final preDispatchKitchenRouteVerification =
        resolvedKitchenRoute == null || actualKitchenRoute == null
        ? <String, dynamic>{
            'route_match': true,
            'reason': 'guard_skipped',
            'message': 'guard_skipped',
            'resolved': resolvedKitchenRoute ?? const <String, String>{},
            'actual': actualKitchenRoute ?? const <String, String>{},
          }
        : _verifyKitchenDispatchRouteConsistency(
            resolved: resolvedKitchenRoute,
            actual: actualKitchenRoute,
          );
    debugPrint('[PrintOrchestrator][dispatch]');
    debugPrint('document=${payload.documentType}');
    debugPrint('backend=${dispatchPrinter.backend.value}');
    debugPrint('host=${_printerHost(dispatchPrinter)}');
    debugPrint('port=${_printerPort(dispatchPrinter)}');
    if (!payload.isReceipt) {
      debugPrint('[KITCHEN_TCP_RESOLVE]');
      debugPrint(
        'restaurant_id=${restaurantId?.trim().isNotEmpty == true ? restaurantId!.trim() : '-'}',
      );
      debugPrint('printer_role=kitchen');
      debugPrint(
        'resolved_printer_id=${normalizedPrinter.printerRecordId ?? normalizedPrinter.id}',
      );
      debugPrint('resolved_printer_name=${normalizedPrinter.displayName}');
      debugPrint('resolved_backend=${normalizedPrinter.backend.value}');
      debugPrint('resolved_host=${_printerHost(normalizedPrinter)}');
      debugPrint('resolved_port=${_printerPort(normalizedPrinter)}');
      debugPrint('resolved_queue=${normalizedPrinter.queueName}');
      debugPrint('source=$kitchenResolveSource');
    }
    if (!payload.isReceipt) {
      final restaurantKey = restaurantId?.trim() ?? '';
      final stamped =
          KitchenTicketHeaderResolver.stampProductionHeaderOnKitchenPayload(
            requestPayload,
            stationNamesById: restaurantKey.isEmpty
                ? null
                : KitchenTicketHeaderResolver.stationNamesForRestaurant(
                    restaurantKey,
                  ),
            stationCodesById: restaurantKey.isEmpty
                ? null
                : KitchenTicketHeaderResolver.stationCodesForRestaurant(
                    restaurantKey,
                  ),
            productStationByProductId: restaurantKey.isEmpty
                ? null
                : KitchenTicketHeaderResolver.productMappingsForRestaurant(
                    restaurantKey,
                  ),
          );
      requestPayload
        ..clear()
        ..addAll(stamped);
    }
    final encodingAlreadyStamped =
        requestPayload['encoding_profile_verified'] == true &&
        requestPayload['turkish_print_mode'] != null;
    if (restaurantId != null &&
        restaurantId.trim().isNotEmpty &&
        !(fastFlow && encodingAlreadyStamped)) {
      final profileWatch = Stopwatch()..start();
      await applyEncodingProfileToPayload(
        requestPayload,
        restaurantId: restaurantId,
        printer: dispatchPrinter,
      );
      profileResolveMs = profileWatch.elapsedMilliseconds;
    }
    payloadBuildMs = dispatchWatch.elapsedMilliseconds;
    if (!payload.isReceipt) {
      final printerPayload = requestPayload['printer'] as Map<String, dynamic>?;
      debugPrint('[KITCHEN_TCP_REQUEST_PAYLOAD]');
      debugPrint(
        'printer.backend=${_readText(printerPayload?['backend'] ?? printerPayload?['transportType'])}',
      );
      debugPrint(
        'printer.host=${_readText(printerPayload?['host'] ?? printerPayload?['ip_address'] ?? printerPayload?['ipAddress'])}',
      );
      debugPrint('printer.port=${_readText(printerPayload?['port'])}');
      debugPrint('payload.host=${_readText(requestPayload['host'])}');
      debugPrint(
        'payload.ip_address=${_readText(requestPayload['ip_address'] ?? requestPayload['ipAddress'])}',
      );
      debugPrint('payload.port=${_readText(requestPayload['port'])}');
      debugPrint(
        'payload.printer_queue=${_readText(requestPayload['printer_queue'])}',
      );
      debugPrint(
        'payload.deviceIdentifier=${_readText(requestPayload['deviceIdentifier'] ?? requestPayload['device_identifier'] ?? requestPayload['printer_device_identifier'])}',
      );
      debugPrint('payload.keys=${requestPayload.keys.toList()..sort()}');
    }
    final dispatchDiagnostics = _buildPhysicalDispatchDiagnostics(
      flowType: flowType ?? flowName,
      selectedPrinter: dispatchPrinter,
      requestedPrinter: normalizedPrinter,
      payload: requestPayload,
      endpoint: _physicalPrintEndpoint(payload),
    );
    debugPrint('[PHYSICAL_PRINT_DISPATCH] ${jsonEncode(dispatchDiagnostics)}');
    _debugBridgeDispatchPayload(dispatchTarget);
    if (dispatchPrinter.backend == DesktopPrinterBackend.tcp) {
      debugPrint('[TCP_PRINT][start]');
      debugPrint('host=${dispatchTarget.host ?? '-'}');
      debugPrint('port=${dispatchTarget.port?.toString() ?? '-'}');
      debugPrint(
        '[PrintOrchestrator][dispatch] '
        'document=${payload.documentType} backend=tcp '
        'host=${_printerHost(dispatchPrinter)} port=${_printerPort(dispatchPrinter)}',
      );
    }
    if (payload.isReceipt) {
      debugPrint(
        '[RECEIPT_REQUEST_TABLE_LABEL] '
        'table_no=${requestPayload['table_no'] ?? ''} '
        'table_number=${requestPayload['table_number'] ?? ''} '
        'area_table_number=${requestPayload['area_table_number'] ?? ''} '
        'table_area_name=${requestPayload['table_area_name'] ?? ''} '
        'area_name=${requestPayload['area_name'] ?? ''} '
        'display_table_label=${requestPayload['display_table_label'] ?? ''} '
        'table_display_name=${requestPayload['table_display_name'] ?? ''} '
        'table_name=${requestPayload['table_name'] ?? ''}',
      );
    }
    if (fallbackPrinter != null) {
      requestPayload['used_fallback'] = true;
      requestPayload['fallback_reason'] = 'usb_cups_conflict_cups_fallback';
    }
    final service = _printServiceFactory();
    try {
      Future<Map<String, dynamic>?> dispatchPrint() {
        return payload.isReceipt
            ? service.printReceipt(requestPayload)
            : service.printKitchen(requestPayload);
      }

      if (restaurantId != null && restaurantId.trim().isNotEmpty) {
        if (!payload.isReceipt) {
          final resolvedRoute =
              preDispatchKitchenRouteVerification['resolved']
                  as Map<String, String>;
          final actualRoute =
              preDispatchKitchenRouteVerification['actual']
                  as Map<String, String>;
          final routeMatch =
              preDispatchKitchenRouteVerification['route_match'] == true;
          final routeReason =
              preDispatchKitchenRouteVerification['reason']?.toString() ?? '';
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_dispatch_target_verified',
                message: routeReason == 'non_tcp_skip'
                    ? 'Mutfak strict route doğrulama atlandı: non-TCP yazıcı.'
                    : routeMatch
                    ? 'Mutfak dispatch hedefi doğrulandı.'
                    : 'Mutfak dispatch hedefi resolved route ile uyuşmuyor.',
                level: routeMatch ? 'info' : 'error',
                role: printerRole.value,
                printerId: actualRoute['printer_id'],
                queueName: actualRoute['queue'],
                backend: actualRoute['backend'],
                details: <String, dynamic>{
                  'resolved_printer_id': resolvedRoute['printer_id'],
                  'resolved_printer_name': resolvedRoute['printer_name'],
                  'resolved_backend': resolvedRoute['backend'],
                  'resolved_host': resolvedRoute['host'],
                  'resolved_port': resolvedRoute['port'],
                  'resolved_queue': resolvedRoute['queue'],
                  'actual_printer_id': actualRoute['printer_id'],
                  'actual_printer_name': actualRoute['printer_name'],
                  'actual_backend': actualRoute['backend'],
                  'actual_host': actualRoute['host'],
                  'actual_port': actualRoute['port'],
                  'actual_queue': actualRoute['queue'],
                  'route_match': routeMatch,
                  'reason': routeReason,
                },
              )
              .ignore();
          if (!routeMatch) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'kitchen_dispatch_route_mismatch',
                  message:
                      'Mutfak fişi yazdırılamadı: çözümlenen yazıcı ile fiziksel dispatch hedefi uyuşmuyor.',
                  level: 'error',
                  role: printerRole.value,
                  printerId: actualRoute['printer_id'],
                  queueName: actualRoute['queue'],
                  backend: actualRoute['backend'],
                  details: <String, dynamic>{
                    'resolved_printer_id': resolvedRoute['printer_id'],
                    'resolved_backend': resolvedRoute['backend'],
                    'resolved_host': resolvedRoute['host'],
                    'resolved_port': resolvedRoute['port'],
                    'resolved_queue': resolvedRoute['queue'],
                    'actual_printer_id': actualRoute['printer_id'],
                    'actual_backend': actualRoute['backend'],
                    'actual_host': actualRoute['host'],
                    'actual_port': actualRoute['port'],
                    'actual_queue': actualRoute['queue'],
                    'route_match': false,
                  },
                )
                .ignore();
            return PrinterActionResult(
              ok: false,
              status: 'kitchen_dispatch_route_mismatch',
              message:
                  'Ethernet mutfak yazıcısı seçili ama fiziksel dispatch POS58/CUPS/USB\'ye sapıyor.',
              printer: normalizedPrinter,
            );
          }
        }
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: fallbackPrinter == null
                  ? 'physical_print_method_called'
                  : 'physical_print_method_called_with_cups_fallback',
              message: fallbackPrinter == null
                  ? 'Ortak fiziksel print metodu çağrıldı.'
                  : 'USB/CUPS çakışması nedeniyle fiziksel baskı CUPS fallback ile çağrıldı.',
              role: printerRole.value,
              printerId: dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
              queueName: dispatchPrinter.queueName,
              backend: dispatchPrinter.backend.value,
              details: <String, dynamic>{
                'documentType': payload.documentType,
                'requestedPrinterId': normalizedPrinter.id,
                'requestedBackend': normalizedPrinter.backend.value,
                'printer_device_identifier': _persistedDeviceIdentifier(
                  dispatchPrinter,
                ),
              },
            )
            .ignore();
        final runtimeLog = _runtimeLog(
          restaurantId: restaurantId,
          event: 'physical_print_started',
          flowName: flowName,
          source: source,
          role: printerRole.value,
          documentType: payload.documentType,
          printer: dispatchPrinter,
          storeId: storeId ?? _runtimePayloadStoreId(requestPayload),
          tableId: tableId ?? _runtimePayloadTableId(requestPayload),
          printJobId:
              printJobId ?? _runtimePayloadPrintJobId(null, requestPayload),
          usedFallback: fallbackPrinter != null,
          fallbackReason: fallbackPrinter == null
              ? null
              : 'usb_cups_conflict_cups_fallback',
          details: <String, dynamic>{
            'requested_printer_id': normalizedPrinter.id,
            'requested_backend': normalizedPrinter.backend.value,
          },
        );
        if (fastFlow) {
          unawaited(runtimeLog);
        } else {
          await runtimeLog;
        }
      }
      var releaseAttempted = false;
      Map<String, dynamic>? response;
      final bridgeWatch = Stopwatch()..start();
      try {
        if (!payload.isReceipt &&
            dispatchPrinter.backend == DesktopPrinterBackend.tcp &&
            restaurantId != null &&
            restaurantId.trim().isNotEmpty) {
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_physical_print_dispatched',
                message: 'Ethernet mutfak fişi bridge\'e gönderiliyor.',
                role: printerRole.value,
                printerId:
                    dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                queueName: dispatchPrinter.queueName,
                backend: dispatchPrinter.backend.value,
                details: <String, dynamic>{
                  'document': payload.documentType,
                  'job_id':
                      printJobId ??
                      _runtimePayloadPrintJobId(null, requestPayload),
                  'station_id': _readText(requestPayload['station_id']),
                  'station_name': _readText(
                    requestPayload['station_name'] ??
                        requestPayload['kitchen_ticket_header'],
                  ),
                  'host': _printerHost(dispatchPrinter),
                  'port': _printerPort(dispatchPrinter),
                  'payload_bytes': utf8
                      .encode(jsonEncode(requestPayload))
                      .length,
                },
              )
              .ignore();
        }
        response = await dispatchPrint();
        bridgeRequestMs = bridgeWatch.elapsedMilliseconds;
        if (!payload.isReceipt &&
            dispatchPrinter.backend == DesktopPrinterBackend.tcp &&
            restaurantId != null &&
            restaurantId.trim().isNotEmpty) {
          final postDispatchKitchenRouteVerification =
              _verifyKitchenDispatchRouteConsistency(
                resolved: _kitchenDispatchRouteFromPrinter(normalizedPrinter),
                actual: _kitchenDispatchRouteFromBridgeResponse(
                  response,
                  fallbackPayload: requestPayload,
                  fallbackPrinter: dispatchPrinter,
                ),
              );
          final resolvedRoute =
              postDispatchKitchenRouteVerification['resolved']
                  as Map<String, String>;
          final actualRoute =
              postDispatchKitchenRouteVerification['actual']
                  as Map<String, String>;
          final routeMatch =
              postDispatchKitchenRouteVerification['route_match'] == true;
          final routeReason =
              postDispatchKitchenRouteVerification['reason']?.toString() ?? '';
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_dispatch_target_verified',
                message: routeReason == 'non_tcp_skip'
                    ? 'Mutfak strict route doğrulama atlandı: non-TCP yazıcı.'
                    : routeMatch
                    ? 'Mutfak fiziksel dispatch hedefi doğrulandı.'
                    : 'Mutfak fiziksel dispatch hedefi resolved route ile uyuşmuyor.',
                level: routeMatch ? 'info' : 'error',
                role: printerRole.value,
                printerId: actualRoute['printer_id'],
                queueName: actualRoute['queue'],
                backend: actualRoute['backend'],
                details: <String, dynamic>{
                  'resolved_printer_id': resolvedRoute['printer_id'],
                  'resolved_printer_name': resolvedRoute['printer_name'],
                  'resolved_backend': resolvedRoute['backend'],
                  'resolved_host': resolvedRoute['host'],
                  'resolved_port': resolvedRoute['port'],
                  'resolved_queue': resolvedRoute['queue'],
                  'actual_printer_id': actualRoute['printer_id'],
                  'actual_printer_name': actualRoute['printer_name'],
                  'actual_backend': actualRoute['backend'],
                  'actual_host': actualRoute['host'],
                  'actual_port': actualRoute['port'],
                  'actual_queue': actualRoute['queue'],
                  'route_match': routeMatch,
                  'reason': routeReason,
                },
              )
              .ignore();
          if (!routeMatch) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'kitchen_dispatch_route_mismatch',
                  message:
                      'Mutfak fişi yazdırılamadı: çözümlenen yazıcı ile fiziksel dispatch hedefi uyuşmuyor.',
                  level: 'error',
                  role: printerRole.value,
                  printerId: actualRoute['printer_id'],
                  queueName: actualRoute['queue'],
                  backend: actualRoute['backend'],
                  details: <String, dynamic>{
                    'resolved_printer_id': resolvedRoute['printer_id'],
                    'resolved_backend': resolvedRoute['backend'],
                    'resolved_host': resolvedRoute['host'],
                    'resolved_port': resolvedRoute['port'],
                    'resolved_queue': resolvedRoute['queue'],
                    'actual_printer_id': actualRoute['printer_id'],
                    'actual_backend': actualRoute['backend'],
                    'actual_host': actualRoute['host'],
                    'actual_port': actualRoute['port'],
                    'actual_queue': actualRoute['queue'],
                    'route_match': false,
                    'bridge_response': response ?? const <String, dynamic>{},
                  },
                )
                .ignore();
            return PrinterActionResult(
              ok: false,
              status: 'kitchen_dispatch_route_mismatch',
              message:
                  'Ethernet mutfak yazıcısı seçili ama fiziksel dispatch POS58/CUPS/USB\'ye sapıyor.',
              printer: normalizedPrinter,
              raw: response,
            );
          }
        }
      } catch (error) {
        if (_shouldRetryUsbClaimFailure(
              printer: dispatchPrinter,
              error: error,
            ) &&
            _allowAutomaticBackendFallback(
              printer: dispatchPrinter,
              documentType: payload.documentType,
            )) {
          releaseAttempted = true;
          if (restaurantId != null && restaurantId.trim().isNotEmpty) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'usb_claim_failed',
                  message: 'USB yazıcı claim hatası verdi.',
                  level: 'error',
                  role: printerRole.value,
                  printerId:
                      dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                  queueName: dispatchPrinter.queueName,
                  backend: dispatchPrinter.backend.value,
                  details: <String, dynamic>{
                    'documentType': payload.documentType,
                    'error': error.toString(),
                  },
                )
                .ignore();
          }
          final approved = await _usbPermissionRecoveryService
              .requestAdminUsbRelease(hasConflictWarning: hasConflictWarning);
          if (restaurantId != null && restaurantId.trim().isNotEmpty) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'admin_cups_release_requested',
                  message:
                      'macOS yazıcıyı kilitledi. Kilidi kaldırmak için izin gerekiyor.',
                  level: approved ? 'info' : 'error',
                  role: printerRole.value,
                  printerId:
                      dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                  queueName: dispatchPrinter.queueName,
                  backend: dispatchPrinter.backend.value,
                  details: <String, dynamic>{
                    'documentType': payload.documentType,
                    'approved': approved,
                    'hasConflictWarning': hasConflictWarning,
                  },
                )
                .ignore();
          }
          if (!approved) {
            if (restaurantId != null && restaurantId.trim().isNotEmpty) {
              _eventLogService
                  .append(
                    restaurantId: restaurantId,
                    event: 'admin_cups_release_failure',
                    message:
                        'USB kilit açma akışı kullanıcı tarafından iptal edildi.',
                    level: 'error',
                    role: printerRole.value,
                    printerId:
                        dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                    queueName: dispatchPrinter.queueName,
                    backend: dispatchPrinter.backend.value,
                    details: <String, dynamic>{
                      'documentType': payload.documentType,
                      'error': 'user_cancelled',
                    },
                  )
                  .ignore();
              await _runtimeLog(
                restaurantId: restaurantId,
                event: 'physical_print_failed',
                flowName: flowName,
                source: source,
                role: printerRole.value,
                documentType: payload.documentType,
                printer: dispatchPrinter,
                storeId: storeId ?? _runtimePayloadStoreId(requestPayload),
                tableId: tableId ?? _runtimePayloadTableId(requestPayload),
                printJobId:
                    printJobId ??
                    _runtimePayloadPrintJobId(null, requestPayload),
                usedFallback: fallbackPrinter != null,
                fallbackReason: 'macos_permission_denied',
                errorMessage: 'user_cancelled',
                level: 'error',
              );
            }
            return PrinterActionResult(
              ok: false,
              status: 'print_failed',
              message:
                  'macOS yazıcıyı kilitledi. Kilidi kaldırmak için izin gerekiyor.',
              printer: dispatchPrinter,
              technicalMessage: error.toString(),
            );
          }

          AdminCupsReleaseResult adminRelease;
          while (true) {
            adminRelease = await _usbPermissionRecoveryService
                .runAdminUsbRelease();
            if (adminRelease.ok) {
              break;
            }
            if (adminRelease.error != 'user_cancelled') {
              break;
            }
            final retry = await _usbPermissionRecoveryService
                .requestRetryAfterAdminCancelled(
                  hasConflictWarning: hasConflictWarning,
                );
            if (!retry) {
              break;
            }
          }
          if (restaurantId != null && restaurantId.trim().isNotEmpty) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: adminRelease.ok
                      ? 'admin_cups_release_success'
                      : 'admin_cups_release_failure',
                  message: adminRelease.ok
                      ? 'Yönetici izniyle CUPS yeniden başlatıldı.'
                      : 'Yönetici izniyle CUPS yeniden başlatılamadı.',
                  level: adminRelease.ok ? 'info' : 'error',
                  role: printerRole.value,
                  printerId:
                      dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                  queueName: dispatchPrinter.queueName,
                  backend: dispatchPrinter.backend.value,
                  details: <String, dynamic>{
                    'documentType': payload.documentType,
                    if (adminRelease.output != null)
                      'output': adminRelease.output,
                    if (adminRelease.error != null) 'error': adminRelease.error,
                  },
                )
                .ignore();
          }
          if (!adminRelease.ok) {
            if (restaurantId != null && restaurantId.trim().isNotEmpty) {
              await _runtimeLog(
                restaurantId: restaurantId,
                event: 'physical_print_failed',
                flowName: flowName,
                source: source,
                role: printerRole.value,
                documentType: payload.documentType,
                printer: dispatchPrinter,
                storeId: storeId ?? _runtimePayloadStoreId(requestPayload),
                tableId: tableId ?? _runtimePayloadTableId(requestPayload),
                printJobId:
                    printJobId ??
                    _runtimePayloadPrintJobId(null, requestPayload),
                usedFallback: fallbackPrinter != null,
                fallbackReason: 'admin_cups_release_failed',
                errorMessage: adminRelease.error ?? adminRelease.message,
                level: 'error',
              );
            }
            return PrinterActionResult(
              ok: false,
              status: 'print_failed',
              message: adminRelease.message,
              printer: dispatchPrinter,
              technicalMessage: adminRelease.error,
            );
          }
          if (hasConflictWarning) {
            debugPrint(
              '[PrintOrchestrator] POS58 printer detected both in CUPS and USB direct inventory.',
            );
          }
          if (restaurantId != null && restaurantId.trim().isNotEmpty) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'usb_print_retry_started',
                  message:
                      'USB yazıcı macOS tarafından kilitli. CUPS yeniden başlatıldı, tekrar deneniyor.',
                  role: printerRole.value,
                  printerId:
                      dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                  queueName: dispatchPrinter.queueName,
                  backend: dispatchPrinter.backend.value,
                  details: <String, dynamic>{
                    'documentType': payload.documentType,
                  },
                )
                .ignore();
          }
          try {
            response = await dispatchPrint();
          } catch (retryError) {
            await _usbPermissionRecoveryService
                .showPostReleaseFailureInstructions(
                  hasConflictWarning: hasConflictWarning,
                );
            final failureMessage = _friendlyPhysicalPrintException(
              dispatchPrinter,
              retryError,
              releaseAttempted: releaseAttempted,
            );
            if (restaurantId != null && restaurantId.trim().isNotEmpty) {
              _eventLogService
                  .append(
                    restaurantId: restaurantId,
                    event: 'physical_print_failure',
                    message: 'Ortak fiziksel print metodu bridge hatası verdi.',
                    level: 'error',
                    role: printerRole.value,
                    printerId:
                        dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                    queueName: dispatchPrinter.queueName,
                    backend: dispatchPrinter.backend.value,
                    details: <String, dynamic>{
                      'documentType': payload.documentType,
                      'error': retryError.toString(),
                      'releaseAttempted': true,
                    },
                  )
                  .ignore();
            }
            return PrinterActionResult(
              ok: false,
              status: 'print_failed',
              message: failureMessage,
              printer: dispatchPrinter,
              technicalMessage: retryError.toString(),
            );
          }
        } else {
          final failureMessage = _friendlyPhysicalPrintException(
            dispatchPrinter,
            error,
          );
          if (restaurantId != null && restaurantId.trim().isNotEmpty) {
            _eventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'physical_print_failure',
                  message: 'Ortak fiziksel print metodu bridge hatası verdi.',
                  level: 'error',
                  role: printerRole.value,
                  printerId:
                      dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                  queueName: dispatchPrinter.queueName,
                  backend: dispatchPrinter.backend.value,
                  details: <String, dynamic>{
                    'documentType': payload.documentType,
                    'error': error.toString(),
                  },
                )
                .ignore();
          }
          return PrinterActionResult(
            ok: false,
            status: 'print_failed',
            message: failureMessage,
            printer: dispatchPrinter,
            technicalMessage: error.toString(),
          );
        }
      }
      final verification = _verifyPhysicalPrintResult(
        printer: dispatchPrinter,
        response: response,
        documentType: payload.documentType,
      );
      final ok = verification.ok;
      final message = verification.message;
      if (!ok &&
          releaseAttempted &&
          dispatchPrinter.backend == DesktopPrinterBackend.usbDirect) {
        await _usbPermissionRecoveryService.showPostReleaseFailureInstructions(
          hasConflictWarning: hasConflictWarning,
        );
      }
      if (ok && restaurantId != null && restaurantId.trim().isNotEmpty) {
        await _logCupsAcceptedWithoutPhysicalConfirmation(
          restaurantId: restaurantId,
          flowName: flowName,
          source: source,
          role: printerRole.value,
          documentType: payload.documentType,
          printer: dispatchPrinter,
          response: response,
          storeId: storeId ?? _runtimePayloadStoreId(requestPayload),
          tableId: tableId ?? _runtimePayloadTableId(requestPayload),
          printJobId:
              printJobId ?? _runtimePayloadPrintJobId(null, requestPayload),
        );
      }
      if (restaurantId != null && restaurantId.trim().isNotEmpty) {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: ok ? 'physical_print_success' : 'physical_print_failure',
              message: ok
                  ? 'Ortak fiziksel print metodu başarılı oldu.'
                  : 'Ortak fiziksel print metodu başarısız oldu.',
              level: ok ? 'info' : 'error',
              role: printerRole.value,
              printerId: dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
              queueName: dispatchPrinter.queueName,
              backend: dispatchPrinter.backend.value,
              details: <String, dynamic>{
                'documentType': payload.documentType,
                'bridgeResult': response ?? const <String, dynamic>{},
                'transport_output': _transportOutput(response),
                if (!ok) 'error': message,
              },
            )
            .ignore();
        if (!payload.isReceipt &&
            dispatchPrinter.backend == DesktopPrinterBackend.tcp) {
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: ok
                    ? 'kitchen_physical_print_completed'
                    : 'kitchen_physical_print_failed',
                message: ok
                    ? 'Ethernet mutfak fişi başarıyla yazdırıldı.'
                    : 'Ethernet mutfak fişi yazdırılamadı.',
                level: ok ? 'info' : 'error',
                role: printerRole.value,
                printerId:
                    dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                queueName: dispatchPrinter.queueName,
                backend: dispatchPrinter.backend.value,
                details: <String, dynamic>{
                  'document': payload.documentType,
                  'job_id':
                      printJobId ??
                      _runtimePayloadPrintJobId(null, requestPayload),
                  'station_id': _readText(requestPayload['station_id']),
                  'station_name': _readText(
                    requestPayload['station_name'] ??
                        requestPayload['kitchen_ticket_header'],
                  ),
                  'host': _printerHost(dispatchPrinter),
                  'port': _printerPort(dispatchPrinter),
                  'bridge_status': verification.status,
                  'bridge_response': response ?? const <String, dynamic>{},
                  if (!ok) 'bridge_error': message,
                },
              )
              .ignore();
        }
        await _runtimeLog(
          restaurantId: restaurantId,
          event: ok ? 'physical_print_success' : 'physical_print_failed',
          flowName: flowName,
          source: source,
          role: printerRole.value,
          documentType: payload.documentType,
          printer: dispatchPrinter,
          storeId: storeId ?? _runtimePayloadStoreId(requestPayload),
          tableId: tableId ?? _runtimePayloadTableId(requestPayload),
          printJobId:
              printJobId ?? _runtimePayloadPrintJobId(null, requestPayload),
          usedFallback: fallbackPrinter != null,
          fallbackReason: fallbackPrinter == null
              ? null
              : 'usb_cups_conflict_cups_fallback',
          errorMessage: ok ? null : message,
          level: ok ? 'info' : 'error',
        );
      }
      final totalDispatchMs = dispatchWatch.elapsedMilliseconds;
      final resultDiagnostics = _buildPhysicalDispatchDiagnostics(
        flowType: flowType ?? flowName,
        selectedPrinter: dispatchPrinter,
        requestedPrinter: normalizedPrinter,
        payload: requestPayload,
        endpoint: _physicalPrintEndpoint(payload),
        bridgeResponse: response,
      );
      resultDiagnostics['payload_build_ms'] = payloadBuildMs;
      resultDiagnostics['profile_resolve_ms'] = profileResolveMs;
      resultDiagnostics['bridge_request_ms'] = bridgeRequestMs;
      resultDiagnostics['total_dispatch_ms'] = totalDispatchMs;
      debugPrint(
        '[PHYSICAL_PRINT_TIMING] flow=${flowType ?? flowName} '
        'profile_resolve_ms=$profileResolveMs payload_build_ms=$payloadBuildMs '
        'bridge_request_ms=$bridgeRequestMs total_dispatch_ms=$totalDispatchMs',
      );
      return PrinterActionResult(
        ok: ok,
        status: verification.status,
        message: message,
        printer: dispatchPrinter,
        raw: _mergePhysicalDispatchDiagnostics(response, resultDiagnostics),
      );
    } catch (error) {
      if (restaurantId != null && restaurantId.trim().isNotEmpty) {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'physical_print_failure',
              message: 'Ortak fiziksel print metodu bridge hatası verdi.',
              level: 'error',
              role: printerRole.value,
              printerId: dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
              queueName: dispatchPrinter.queueName,
              backend: dispatchPrinter.backend.value,
              details: <String, dynamic>{
                'documentType': payload.documentType,
                'error': error.toString(),
              },
            )
            .ignore();
        if (!payload.isReceipt &&
            dispatchPrinter.backend == DesktopPrinterBackend.tcp) {
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_physical_print_failed',
                message: 'Ethernet mutfak fişi yazdırılamadı.',
                level: 'error',
                role: printerRole.value,
                printerId:
                    dispatchPrinter.printerRecordId ?? dispatchPrinter.id,
                queueName: dispatchPrinter.queueName,
                backend: dispatchPrinter.backend.value,
                details: <String, dynamic>{
                  'document': payload.documentType,
                  'job_id':
                      printJobId ??
                      _runtimePayloadPrintJobId(null, requestPayload),
                  'station_id': _readText(requestPayload['station_id']),
                  'station_name': _readText(
                    requestPayload['station_name'] ??
                        requestPayload['kitchen_ticket_header'],
                  ),
                  'host': _printerHost(dispatchPrinter),
                  'port': _printerPort(dispatchPrinter),
                  'bridge_error': error.toString(),
                },
              )
              .ignore();
        }
        await _runtimeLog(
          restaurantId: restaurantId,
          event: 'physical_print_failed',
          flowName: flowName,
          source: source,
          role: printerRole.value,
          documentType: payload.documentType,
          printer: dispatchPrinter,
          storeId: storeId ?? _runtimePayloadStoreId(requestPayload),
          tableId: tableId ?? _runtimePayloadTableId(requestPayload),
          printJobId:
              printJobId ?? _runtimePayloadPrintJobId(null, requestPayload),
          usedFallback: fallbackPrinter != null,
          fallbackReason: fallbackPrinter == null
              ? null
              : 'usb_cups_conflict_cups_fallback',
          errorMessage: error.toString(),
          level: 'error',
        );
      }
      final failureDiagnostics = _buildPhysicalDispatchDiagnostics(
        flowType: flowType ?? flowName,
        selectedPrinter: dispatchPrinter,
        requestedPrinter: normalizedPrinter,
        payload: requestPayload,
        endpoint: _physicalPrintEndpoint(payload),
        bridgeResponse:
            (error is LocalPrintServiceException &&
                error.details is Map<String, dynamic>)
            ? (error.details! as Map<String, dynamic>)
            : null,
      );
      return PrinterActionResult(
        ok: false,
        status: 'print_failed',
        message: _friendlyBridgeFailure(error),
        printer: dispatchPrinter,
        technicalMessage: error.toString(),
        raw: _mergePhysicalDispatchDiagnostics(
          (error is LocalPrintServiceException &&
                  error.details is Map<String, dynamic>)
              ? (error.details! as Map<String, dynamic>)
              : null,
          failureDiagnostics,
        ),
      );
    } finally {
      service.dispose();
    }
  }

  Future<QueuedPrintPayloadResolution> prepareQueuedPrintPayload({
    required String restaurantId,
    required Map<String, dynamic> jobRecord,
    required Map<String, dynamic> payload,
  }) async {
    final normalizedPayload = Map<String, dynamic>.from(payload);
    _synthesizeTcpPayloadMetadata(normalizedPayload);
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      forceRefresh: false,
    );
    final printerRole = _inferQueuedPrinterRole(jobRecord, normalizedPayload);
    UnifiedPrinterModel? resolvedPrinter;
    final printerQueue = _readText(
      normalizedPayload['printer_device_identifier'] ??
          normalizedPayload['printer_queue'],
    );
    String? userMessage;
    var resolutionSource = 'unresolved';
    final jobStationId = _readText(
      jobRecord['station_id'] ?? normalizedPayload['station_id'],
    );
    final jobStationName = _readText(
      normalizedPayload['station_name'] ??
          normalizedPayload['kitchen_station_name'] ??
          normalizedPayload['kitchen_ticket_header'],
    );
    final jobOrderId = _readText(
      jobRecord['order_id'] ?? normalizedPayload['order_id'],
    );
    final embeddedPayloadPrinter = _extractEmbeddedPayloadPrinter(
      normalizedPayload,
      os: snapshot.os,
    );
    final explicitTcpPayloadPrinter = _explicitTcpPayloadPrinter(
      normalizedPayload,
      os: snapshot.os,
    );
    final printJobId = _runtimePayloadPrintJobId(jobRecord, normalizedPayload);
    final dbKitchenExpectation = printerRole == PrinterSetupRole.mutfak
        ? await _resolveKitchenDbRoutingExpectation(
            restaurantId: restaurantId,
            snapshot: snapshot,
            stationId: jobStationId,
            stationName: jobStationName,
          )
        : null;
    String? ignoredKitchenSource;
    UnifiedPrinterModel? ignoredKitchenPrinter;
    var usedLocalConfig = false;
    var usedPersistedPayload = false;
    var staleLocalConfigIgnored = false;
    var stalePersistedPayloadIgnored = false;
    final localKitchenSelection = snapshot.localConfig
        ?.selectionForRole(PrinterSetupRole.mutfak)
        ?.printer;

    if (printerRole == PrinterSetupRole.mutfak) {
      resolutionSource = 'unresolved';
      if (dbKitchenExpectation != null) {
        resolvedPrinter = await _resolveExpectedKitchenPrinterFromDb(
          snapshot: snapshot,
          expected: dbKitchenExpectation.expected,
        );
        resolutionSource = dbKitchenExpectation.source;
      }

      if (resolvedPrinter != null) {
        if (embeddedPayloadPrinter != null &&
            _kitchenPrinterLooksLikeFallback(
              expectedPrinter: resolvedPrinter,
              actualPrinter: embeddedPayloadPrinter,
            )) {
          ignoredKitchenSource ??= 'persisted_payload';
          ignoredKitchenPrinter ??= embeddedPayloadPrinter;
          stalePersistedPayloadIgnored = true;
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'stale_persisted_payload_ignored',
                message:
                    'Mutfak: eski payload yazıcısı yok sayıldı (DB mapping ile çelişkili).',
                level: 'warning',
                role: 'mutfak',
                details: <String, dynamic>{
                  'resolved_printer_id': resolvedPrinter.id,
                  'resolved_backend': resolvedPrinter.backend.value,
                  'ignored_backend': embeddedPayloadPrinter.backend.value,
                  'job_station_id': jobStationId,
                  'station_name': jobStationName,
                },
              )
              .ignore();
        }
        if (localKitchenSelection != null &&
            _kitchenPrinterLooksLikeFallback(
              expectedPrinter: resolvedPrinter,
              actualPrinter: localKitchenSelection,
            )) {
          ignoredKitchenSource ??= 'local_config';
          ignoredKitchenPrinter ??= localKitchenSelection;
          staleLocalConfigIgnored = true;
          _eventLogService
              .append(
                restaurantId: restaurantId,
                event: 'stale_local_config_ignored',
                message:
                    'Mutfak: yerel setup yapılandırması yok sayıldı (DB mapping ile çelişkili).',
                level: 'warning',
                role: 'mutfak',
                details: <String, dynamic>{
                  'resolved_printer_id': resolvedPrinter.id,
                  'resolved_backend': resolvedPrinter.backend.value,
                  'ignored_backend': localKitchenSelection.backend.value,
                  'job_station_id': jobStationId,
                  'station_name': jobStationName,
                },
              )
              .ignore();
        }
      } else if (dbKitchenExpectation != null &&
          dbKitchenExpectation.isEthernet) {
        resolutionSource = 'failed';
        userMessage =
            'Mutfak fişi yazdırılamadı: mutfak yazıcısı Ethernet olarak atanmış ama runtime çözümleme başarısız.';
      } else if (explicitTcpPayloadPrinter != null) {
        resolvedPrinter =
            await _resolveStoredPrinterCandidate(
              restaurantId: restaurantId,
              snapshot: snapshot,
              candidate: explicitTcpPayloadPrinter,
            ) ??
            _normalizePrinterForPhysicalDispatch(explicitTcpPayloadPrinter);
        resolutionSource = 'persisted_payload';
        usedPersistedPayload = true;
      } else {
        resolvedPrinter = await _resolveKitchenLocalFallback(
          restaurantId: restaurantId,
          snapshot: snapshot,
        );
        if (resolvedPrinter != null) {
          resolutionSource = 'local_config';
          usedLocalConfig = true;
        }
      }
      if (resolvedPrinter != null) {
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'printer_route_resolved',
              message:
                  'Mutfak yazıcısı çözümlendi: $resolutionSource → ${resolvedPrinter.displayName}',
              level: 'info',
              role: 'mutfak',
              details: <String, dynamic>{
                'document_type': 'kitchen',
                'role': 'mutfak',
                'station_id': jobStationId,
                'station_name': jobStationName,
                'resolution_source': resolutionSource,
                'selected_printer_id':
                    resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
                'selected_printer_name': resolvedPrinter.displayName,
                'backend': resolvedPrinter.backend.value,
                'host': _printerHost(resolvedPrinter),
                'port': _printerPort(resolvedPrinter),
                'queue': resolvedPrinter.queueName,
                'used_local_config': usedLocalConfig,
                'used_persisted_payload': usedPersistedPayload,
                'stale_local_config_ignored': staleLocalConfigIgnored,
                'stale_persisted_payload_ignored': stalePersistedPayloadIgnored,
              },
            )
            .ignore();
      }
      if (resolvedPrinter == null) {
        resolutionSource = 'failed';
        userMessage ??= 'Mutfak fişi yazdırılamadı: yazıcı çözümlenemedi.';
        _eventLogService
            .append(
              restaurantId: restaurantId,
              event: 'kitchen_printer_resolution_failed',
              message: 'Mutfak yazıcısı çözümlenemedi.',
              level: 'error',
              role: 'mutfak',
              details: <String, dynamic>{
                'station_id': jobStationId,
                'station_name': jobStationName,
                'order_id': jobOrderId,
                'expected_printer': dbKitchenExpectation?.printer.name,
                'expected_backend': dbKitchenExpectation?.expected.backend,
                'expected_host': dbKitchenExpectation?.expected.host,
                'expected_port': dbKitchenExpectation?.expected.port,
              },
            )
            .ignore();
      }
    } else if (printerRole != null) {
      resolvedPrinter = await _resolvePrinterForRole(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: printerRole,
      );
      if (resolvedPrinter != null) {
        resolutionSource = 'role_selection';
      }
    }

    if (printerRole != PrinterSetupRole.mutfak &&
        resolvedPrinter == null &&
        printerQueue.isNotEmpty) {
      resolvedPrinter = _resolvePrinterByQueueOrName(
        printers: snapshot.printers,
        queueName: printerQueue,
        displayName: _readText(payload['printer_name']),
      );
      if (!_isBridgeReadyPrinter(resolvedPrinter)) {
        resolvedPrinter = null;
      }
      if (resolvedPrinter != null) {
        resolutionSource = 'payload_queue';
      }
    }

    if (printerRole != PrinterSetupRole.mutfak && resolvedPrinter == null) {
      final legacyPrinterId = _readText(
        jobRecord['printer_id'] ?? normalizedPayload['printer_id'],
      );
      if (legacyPrinterId.isNotEmpty) {
        final legacyPrinter = await _printerRepository.fetchPrinterById(
          legacyPrinterId,
        );
        if (legacyPrinter != null) {
          resolvedPrinter = _resolveUnifiedPrinterFromLegacy(
            legacyPrinter,
            printers: snapshot.printers,
            os: snapshot.os,
          );
          if (!_isBridgeReadyPrinter(resolvedPrinter)) {
            resolvedPrinter = null;
          }
          if (resolvedPrinter != null) {
            resolutionSource = 'legacy_printer';
          }
        }
      }
    }

    if (printerRole != PrinterSetupRole.mutfak && resolvedPrinter == null) {
      resolvedPrinter = _extractEmbeddedPayloadPrinter(
        normalizedPayload,
        os: snapshot.os,
      );
      if (!_isBridgeReadyPrinter(resolvedPrinter)) {
        resolvedPrinter = null;
      }
      if (resolvedPrinter != null) {
        resolutionSource = 'payload';
      }
    }

    if (printerRole != PrinterSetupRole.mutfak && resolvedPrinter == null) {
      resolvedPrinter = await _resolveWorkingPrinter(
        restaurantId: restaurantId,
        snapshot: snapshot,
      );
      if (_isBridgeReadyPrinter(resolvedPrinter)) {
        resolutionSource = 'working_printer';
      }
    }

    if (resolvedPrinter != null && printerRole != PrinterSetupRole.mutfak) {
      resolvedPrinter = await _resolveStoredPrinterCandidate(
        restaurantId: restaurantId,
        snapshot: snapshot,
        candidate: resolvedPrinter,
      );
    }

    if (printerRole == PrinterSetupRole.mutfak &&
        resolvedPrinter != null &&
        embeddedPayloadPrinter != null &&
        _kitchenPrinterLooksLikeFallback(
          expectedPrinter: resolvedPrinter,
          actualPrinter: embeddedPayloadPrinter,
        )) {
      ignoredKitchenSource ??= 'persisted_payload';
      ignoredKitchenPrinter ??= embeddedPayloadPrinter;
    }

    final enrichedPayload = _injectResolvedPrinterIntoPayload(
      normalizedPayload,
      printer: resolvedPrinter,
      printerRole: printerRole,
      jobRecord: jobRecord,
    );
    enrichedPayload['printer_resolution_source'] = resolutionSource;
    enrichedPayload['printer_resolution_failed'] = resolvedPrinter == null;
    if (printerRole == PrinterSetupRole.mutfak &&
        resolvedPrinter != null &&
        ignoredKitchenSource != null &&
        ignoredKitchenPrinter != null) {
      final ignoredEvent = ignoredKitchenSource == 'persisted_payload'
          ? 'stale_persisted_payload_ignored'
          : 'stale_local_config_ignored';
      final details = <String, dynamic>{
        'print_job_id': printJobId,
        'station_id': jobStationId,
        'station_name': jobStationName,
        'expected_role': 'mutfak',
        'actual_printer': ignoredKitchenPrinter.displayName,
        'actual_backend': ignoredKitchenPrinter.backend.value,
        'expected_printer': resolvedPrinter.displayName,
        'expected_backend': resolvedPrinter.backend.value,
        'new_printer': resolvedPrinter.displayName,
        'reason': 'stale_local_config_or_persisted_payload',
        'backend': resolvedPrinter.backend.value,
        'host': _printerHost(resolvedPrinter),
        'port': _printerPort(resolvedPrinter),
      };
      logKitchenWrongPrinterSelected(
        event: ignoredEvent,
        reason: details['reason']!.toString(),
        expectedPrinter: resolvedPrinter.displayName,
        actualPrinter: ignoredKitchenPrinter.displayName,
        backend: resolvedPrinter.backend.value,
        host: _printerHost(resolvedPrinter),
        port: _printerPort(resolvedPrinter),
      );
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'kitchen_wrong_printer_selected',
            message: 'Mutfak job için yanlış yazıcı seçimi engellendi.',
            level: 'warning',
            jobId: printJobId,
            role: 'mutfak',
            printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
            queueName: resolvedPrinter.queueName,
            backend: resolvedPrinter.backend.value,
            details: details,
          )
          .ignore();
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: ignoredEvent,
            message: ignoredKitchenSource == 'persisted_payload'
                ? 'Eski payload yazıcı bilgisi yok sayıldı.'
                : 'Eski local yazıcı seçimi yok sayıldı.',
            jobId: printJobId,
            role: 'mutfak',
            printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
            queueName: resolvedPrinter.queueName,
            backend: resolvedPrinter.backend.value,
            details: details,
          )
          .ignore();
      _eventLogService
          .append(
            restaurantId: restaurantId,
            event: 'kitchen_wrong_printer_corrected',
            message: 'Mutfak job doğru Ethernet yazıcısına düzeltildi.',
            jobId: printJobId,
            role: 'mutfak',
            printerId: resolvedPrinter.printerRecordId ?? resolvedPrinter.id,
            queueName: resolvedPrinter.queueName,
            backend: resolvedPrinter.backend.value,
            details: details,
          )
          .ignore();
      enrichedPayload['ignored_printer_source'] = ignoredKitchenSource;
      enrichedPayload['ignored_printer_name'] =
          ignoredKitchenPrinter.displayName;
      enrichedPayload['stale_local_config_ignored'] =
          ignoredKitchenSource == 'local_config';
      enrichedPayload['stale_persisted_payload_ignored'] =
          ignoredKitchenSource == 'persisted_payload';
      enrichedPayload['wrong_printer_corrected'] = true;
      enrichedPayload['wrong_printer_reason'] =
          'stale_local_config_or_persisted_payload';
    }
    enrichedPayload['fallback_used'] =
        printerRole == PrinterSetupRole.mutfak &&
        resolutionSource == 'mutfak_role_mapping' &&
        jobStationId.isNotEmpty;
    if (printerRole == PrinterSetupRole.mutfak &&
        resolutionSource == 'mutfak_role_mapping' &&
        jobStationId.isNotEmpty) {
      enrichedPayload['fallback_reason'] = 'station_mapping_not_found';
    }
    if (resolvedPrinter != null) {
      _applyPhysicalDispatchDefaults(
        enrichedPayload,
        printer: resolvedPrinter,
        flowType: printerRole == PrinterSetupRole.adisyon
            ? 'waiter_receipt'
            : 'kitchen_ticket',
        endpoint: printerRole == PrinterSetupRole.adisyon
            ? '/print/receipt'
            : '/print/kitchen',
      );
      await applyEncodingProfileToPayload(
        enrichedPayload,
        restaurantId: restaurantId,
        printer: resolvedPrinter,
      );
      final raw = resolvedPrinter.raw;
      enrichedPayload['selected_printer_id'] =
          resolvedPrinter.printerRecordId ?? resolvedPrinter.id;
      enrichedPayload['selected_printer_name'] = resolvedPrinter.displayName;
      enrichedPayload['selected_printer_backend'] =
          resolvedPrinter.backend.value;
      enrichedPayload['selected_printer_connection_type'] = _readText(
        raw['connection_type'] ?? raw['connectionType'],
      );
      enrichedPayload['selected_printer_host'] = _readText(
        raw['host'] ?? raw['ip_address'] ?? raw['ipAddress'],
      );
      enrichedPayload['selected_printer_port'] = _printerPort(resolvedPrinter);
      enrichedPayload['selected_printer_profile_id'] = _readText(
        enrichedPayload['printer_profile_id'] ?? raw['printer_profile_id'],
      );
      enrichedPayload['selected_printer_paper_width_mm'] =
          enrichedPayload['paper_width_mm'] ?? raw['paper_width_mm'];
      enrichedPayload['selected_printer_raster_width_px'] =
          enrichedPayload['raster_width_px'];
      enrichedPayload['selected_printer_chars_per_line'] =
          enrichedPayload['chars_per_line'];
    } else {
      enrichedPayload['selected_printer_id'] = _readText(
        jobRecord['printer_id'] ?? payload['printer_id'],
      );
      enrichedPayload['selected_printer_name'] = _readText(
        payload['printer_name'],
      );
    }
    if (printerRole == PrinterSetupRole.mutfak && resolvedPrinter == null) {
      enrichedPayload['printer_resolution_error'] =
          'Mutfak yazıcısı atanmadı veya Ethernet yazıcıya ulaşılamadı.';
    }
    _log(
      'resolveJobPrinter',
      'restaurantId=$restaurantId jobId=${jobRecord['id'] ?? '-'} '
          'role=${printerRole?.value ?? '-'} source=$resolutionSource '
          'printer=${resolvedPrinter?.id ?? '-'} recordId=${resolvedPrinter?.printerRecordId ?? '-'} '
          'queue=${resolvedPrinter?.queueName ?? '-'} backend=${resolvedPrinter?.backend.value ?? '-'}',
    );
    debugPrint('[QueuedPrintPayloadResolution]');
    debugPrint('jobId=${jobRecord['id'] ?? '-'}');
    debugPrint('role=${printerRole?.value ?? '-'}');
    debugPrint('resolutionSource=$resolutionSource');
    debugPrint('stationId=${jobStationId.isEmpty ? '-' : jobStationId}');
    debugPrint('stationName=${jobStationName.isEmpty ? '-' : jobStationName}');
    debugPrint(
      'selectedPrinterId=${enrichedPayload['selected_printer_id'] ?? '-'}',
    );
    debugPrint(
      'selectedPrinterName=${enrichedPayload['selected_printer_name'] ?? '-'}',
    );
    debugPrint('backend=${enrichedPayload['selected_printer_backend'] ?? '-'}');
    debugPrint('host=${enrichedPayload['selected_printer_host'] ?? '-'}');
    debugPrint(
      'port=${enrichedPayload['selected_printer_port']?.toString() ?? '-'}',
    );
    _eventLogService
        .append(
          restaurantId: restaurantId,
          event: 'printer_resolution',
          message: resolvedPrinter != null
              ? 'Yazici rol eslestirmesi veya payload uzerinden secildi.'
              : 'Yazici cozumleme basarisiz oldu.',
          role: printerRole?.value,
          printerId: resolvedPrinter?.printerRecordId ?? resolvedPrinter?.id,
          queueName: resolvedPrinter?.queueName,
          backend: resolvedPrinter?.backend.value,
          details: <String, dynamic>{
            'resolutionSource': resolutionSource,
            'printerRole': printerRole?.value,
            'printerQueue': printerQueue,
            'legacyPrinterId': _readText(
              jobRecord['printer_id'] ?? payload['printer_id'],
            ),
            'payloadPrinterId': _readText(payload['printer_id']),
            'payloadBackend': _readText(
              payload['printer_backend'] ?? payload['backend'],
            ),
            'payloadHost': _readText(
              payload['host'] ??
                  payload['ip_address'] ??
                  payload['ipAddress'] ??
                  payload['target_host'],
            ),
            'payloadPort': _readText(payload['port'] ?? payload['target_port']),
            'selectedPrinterName': enrichedPayload['selected_printer_name'],
            'selectedBackend': enrichedPayload['selected_printer_backend'],
            'selectedHost': enrichedPayload['selected_printer_host'],
            'selectedPort': enrichedPayload['selected_printer_port'],
          },
        )
        .ignore();
    return QueuedPrintPayloadResolution(
      payload: enrichedPayload,
      printer: resolvedPrinter,
      resolutionSource: resolutionSource,
      userMessage: userMessage,
    );
  }

  bool _kitchenPrinterLooksLikeFallback({
    required UnifiedPrinterModel expectedPrinter,
    required UnifiedPrinterModel actualPrinter,
  }) {
    if (expectedPrinter.backend != DesktopPrinterBackend.tcp) {
      return false;
    }
    final actualName = actualPrinter.displayName.toLowerCase();
    return actualPrinter.backend == DesktopPrinterBackend.usbDirect ||
        actualPrinter.backend == DesktopPrinterBackend.cups ||
        actualName.contains('pos-58') ||
        actualName.contains('pos58');
  }

  Future<PrinterActionResult> deletePrinter({
    required String restaurantId,
    required String printerId,
    bool force = false,
  }) async {
    final legacyPrinter = await _printerRepository.fetchPrinterById(printerId);
    if (legacyPrinter == null) {
      return const PrinterActionResult(
        ok: false,
        status: 'printer_not_found',
        message: 'Yazici kaydi bulunamadi.',
      );
    }
    final mappings = (await _printerRepository.fetchStationPrinterMappings(
      restaurantId,
    )).whereType<StationPrinterModel>().toList(growable: false);
    final isMapped = mappings.any((mapping) => mapping.printerId == printerId);
    final localConfig = await _loadLocalConfig(restaurantId);
    final remoteConfig = await _safeFetchRemoteConfig(restaurantId);
    final usedByReceipt = _printerMatchesRoleSelection(
      legacyPrinter,
      localConfig?.receiptSelection?.printer,
    );
    final usedByKitchen = _printerMatchesRoleSelection(
      legacyPrinter,
      localConfig?.kitchenSelection?.printer,
    );
    if (!force && (isMapped || usedByReceipt || usedByKitchen)) {
      return const PrinterActionResult(
        ok: false,
        status: 'printer_in_use',
        message:
            'Bu yazici adisyon, mutfak veya alan eslestirmesinde kullaniliyor. Silmek icin onay verin.',
      );
    }

    await _clearRoleSelectionsFromLocalConfig(restaurantId);
    await _clearRoleMappingsFromRemoteConfig(
      restaurantId: restaurantId,
      remoteConfig: remoteConfig,
    );
    await _printerRepository.deleteStationPrinterMappingsForPrinter(printerId);
    await _printerRepository.deletePrinter(printerId);
    _snapshotCache.remove(restaurantId.trim());
    _lastRoleMappingReloadJson.remove(restaurantId);
    _log(
      'deletePrinter',
      'restaurantId=$restaurantId printerId=$printerId '
          'mapped=$isMapped receipt=$usedByReceipt kitchen=$usedByKitchen',
    );
    return const PrinterActionResult(
      ok: true,
      status: 'deleted',
      message: 'Yazici kaldirildi.',
      localSaved: true,
      cloudSaved: true,
    );
  }

  Future<PrinterActionResult> hardResetPrinters({
    required String restaurantId,
  }) async {
    final remoteConfig = await _safeFetchRemoteConfig(restaurantId);
    await _clearLocalConfig(restaurantId);
    await _clearRoleMappingsFromRemoteConfig(
      restaurantId: restaurantId,
      remoteConfig: remoteConfig,
    );
    await _printerRepository.deleteStationPrinterMappingsForRestaurant(
      restaurantId,
    );
    await _printerRepository.deletePrintersForRestaurant(restaurantId);
    await _workingPrinterStore.clear(restaurantId);
    _snapshotCache.remove(restaurantId.trim());
    _lastRoleMappingReloadJson.remove(restaurantId);
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      forceRefresh: true,
    );
    _log(
      'hardResetPrinters',
      'restaurantId=$restaurantId remainingScanPrinters=${snapshot.printers.length}',
    );
    return PrinterActionResult(
      ok: true,
      status: 'hard_reset_complete',
      message: 'Yazici kayitlari sifirlandi ve yeni tarama yapildi.',
      localSaved: true,
      cloudSaved: true,
      raw: <String, dynamic>{'remainingScanPrinters': snapshot.printers.length},
    );
  }

  Future<PrinterActionResult> cleanupUnusedPrinters({
    required String restaurantId,
  }) async {
    final printers = await _printerRepository.fetchPrinters(restaurantId);
    final mappings = (await _printerRepository.fetchStationPrinterMappings(
      restaurantId,
    )).whereType<StationPrinterModel>().toList(growable: false);
    final localConfig = await _loadLocalConfig(restaurantId);
    final mappedPrinterIds = mappings.map((item) => item.printerId).toSet();
    var removedCount = 0;
    for (final printer in printers) {
      final selectedLocally =
          _printerMatchesRoleSelection(
            printer,
            localConfig?.receiptSelection?.printer,
          ) ||
          _printerMatchesRoleSelection(
            printer,
            localConfig?.kitchenSelection?.printer,
          );
      if (printer.isActive ||
          mappedPrinterIds.contains(printer.id) ||
          selectedLocally) {
        continue;
      }
      await _printerRepository.deletePrinter(printer.id);
      removedCount += 1;
    }
    _snapshotCache.remove(restaurantId.trim());
    _log(
      'cleanupPrinters',
      'restaurantId=$restaurantId removedCount=$removedCount',
    );
    return PrinterActionResult(
      ok: true,
      status: 'cleanup_complete',
      message: removedCount == 0
          ? 'Temizlenecek bozuk yazici bulunamadi.'
          : '$removedCount yazici kaldirildi.',
      raw: <String, dynamic>{'removedCount': removedCount},
      localSaved: true,
      cloudSaved: true,
    );
  }

  List<UnifiedPrinterModel> _normalizeBridgePrinters(
    Object? raw, {
    required DesktopPrinterOs os,
  }) {
    if (raw is! List) return const <UnifiedPrinterModel>[];
    return raw
        .whereType<Map>()
        .map(
          (entry) => UnifiedPrinterModel.fromBridgeMap(
            Map<String, dynamic>.from(entry),
            os: os,
          ),
        )
        .toList(growable: false);
  }

  List<UnifiedPrinterModel> _normalizeDiscoveryFallback(
    Map<String, dynamic>? response, {
    required DesktopPrinterOs os,
  }) {
    if (response == null) return const <UnifiedPrinterModel>[];
    final entries = <UnifiedPrinterModel>[];
    for (final field in <String>['usb', 'devices', 'cups', 'windows']) {
      final raw = response[field];
      if (raw is! List) continue;
      for (final entry in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(entry);
        final backend =
            map['backend']?.toString() ??
            (field == 'cups'
                ? 'cups'
                : field == 'windows'
                ? 'windows-spool'
                : 'usb-direct');
        final normalized = <String, dynamic>{
          ...map,
          'backend': backend,
          'name':
              map['name']?.toString() ??
              map['product']?.toString() ??
              map['queue']?.toString() ??
              'Yazici',
          'queue': map['queue']?.toString() ?? map['name']?.toString(),
          'statusLevel': map['statusLevel']?.toString() ?? 'warning',
          'ready': map['ready'] ?? (field != 'windows'),
          'id':
              map['id']?.toString() ??
              '$backend:${map['queue'] ?? map['name'] ?? map['product'] ?? 'printer'}',
        };
        entries.add(UnifiedPrinterModel.fromBridgeMap(normalized, os: os));
      }
    }
    final byId = <String, UnifiedPrinterModel>{};
    for (final printer in entries) {
      byId[printer.id] = printer;
    }
    return byId.values.toList(growable: false);
  }

  List<UnifiedPrinterModel> _sortPrinters(
    List<UnifiedPrinterModel> printers, {
    required DesktopPrinterOs os,
  }) {
    final sorted = List<UnifiedPrinterModel>.from(printers);
    int priority(UnifiedPrinterModel printer) {
      if (os == DesktopPrinterOs.macos) {
        switch (printer.backend) {
          case DesktopPrinterBackend.usbDirect:
            return 0;
          case DesktopPrinterBackend.cups:
            return 1;
          case DesktopPrinterBackend.windowsSpool:
            return 2;
          case DesktopPrinterBackend.tcp:
            return 3;
        }
      }
      switch (printer.backend) {
        case DesktopPrinterBackend.windowsSpool:
          return 0;
        case DesktopPrinterBackend.usbDirect:
          return 1;
        case DesktopPrinterBackend.cups:
          return 2;
        case DesktopPrinterBackend.tcp:
          return 3;
      }
    }

    sorted.sort((left, right) {
      final byPriority = priority(left).compareTo(priority(right));
      if (byPriority != 0) {
        return byPriority;
      }
      final byReady = right.canPrint == left.canPrint
          ? 0
          : (right.canPrint ? 1 : -1);
      if (byReady != 0) {
        return byReady;
      }
      return left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
    });
    return sorted;
  }

  bool _isBridgeHealthy(
    Map<String, dynamic>? health, {
    List<UnifiedPrinterModel> printers = const <UnifiedPrinterModel>[],
  }) {
    if (health == null || health.isEmpty) return false;
    final queue =
        health['printer_queue']?.toString() ??
        health['default_queue']?.toString() ??
        '';
    if (queue.trim().isEmpty && _isBridgeQueuePending(health)) {
      return false;
    }
    if (health['ok'] == false) return false;
    final printer = health['printer'];
    if (printer is Map && printer['queue_pending'] == true) {
      return false;
    }
    if (queue.trim().isNotEmpty && !_containsExplicitFalse(printer)) {
      return true;
    }
    return !_containsExplicitFalse(printer);
  }

  bool _isBridgeQueuePending(Map<String, dynamic>? health) {
    if (health == null) return true;
    final queue =
        health['printer_queue']?.toString() ??
        health['default_queue']?.toString() ??
        '';
    if (queue.trim().isNotEmpty) return false;
    final printer = health['printer'];
    if (printer is Map && printer['queue_pending'] == true) return true;
    if (printer is Map && printer['ok'] == false) return true;
    return queue.trim().isEmpty;
  }

  bool _isBridgeOperational({
    required Map<String, dynamic>? health,
    required Map<String, dynamic>? queueStatus,
    required List<UnifiedPrinterModel> printers,
  }) {
    if (printers.any((printer) => printer.isLiveDiscovery)) {
      return true;
    }
    if (printers.any(isSelectableLivePrinter)) {
      return true;
    }
    if (_isLocalQueueReady(queueStatus)) {
      return true;
    }
    if (_isBridgeHealthy(health, printers: printers)) {
      return true;
    }
    if (printers.any(isSelectableLivePrinter) &&
        _isBridgeQueuePending(health)) {
      return true;
    }
    return health?['ok'] == true &&
        printers.any((printer) => printer.isLiveDiscovery);
  }

  /// Probes GET /health and GET /printers — authoritative bridge state for all UIs.
  Future<BridgeRuntimeSnapshot> _probeBridgeRuntime({
    required LocalPrintService service,
    required DesktopPrinterOs os,
  }) async {
    Map<String, dynamic>? health;
    Map<String, dynamic>? printersPayload;
    var reachable = false;
    String? probeError;

    try {
      health = await service.health(useCache: true);
      if (health?['ok'] == true) {
        reachable = true;
      }
    } catch (error) {
      probeError ??= error.toString();
    }

    if (!reachable) {
      try {
        final availability = await service.checkAvailability(
          timeout: const Duration(milliseconds: 1200),
        );
        reachable = availability.isAvailable;
      } catch (error) {
        probeError ??= error.toString();
      }
    }

    try {
      printersPayload = await service.printers(useCache: true);
      final rawPrinters = _normalizeBridgePrinters(
        printersPayload?['printers'],
        os: os,
      );
      if (rawPrinters.isNotEmpty) {
        reachable = true;
      }
      final healthy = _isBridgeOperational(
        health: health,
        queueStatus: null,
        printers: rawPrinters,
      );
      return BridgeRuntimeSnapshot(
        reachable: reachable,
        healthy: healthy,
        health: health,
        printersPayload: printersPayload,
        livePrinters: rawPrinters,
        probeError: probeError,
      );
    } catch (error) {
      probeError ??= error.toString();
    }

    final healthy =
        reachable && (health?['ok'] == true || _isBridgeHealthy(health));
    return BridgeRuntimeSnapshot(
      reachable: reachable,
      healthy: healthy,
      health: health,
      printersPayload: printersPayload,
      livePrinters: const <UnifiedPrinterModel>[],
      probeError: probeError,
    );
  }

  bool _isLocalQueueReady(Map<String, dynamic>? queueStatus) {
    final queue = queueStatus?['queue'];
    final normalizedQueue = queue is Map<String, dynamic>
        ? queue
        : (queue is Map ? Map<String, dynamic>.from(queue) : null);
    if (normalizedQueue == null) return false;
    final enabled = normalizedQueue['enabled'] == true;
    final ready = normalizedQueue['ready'] != false;
    return enabled && ready;
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

  String? _discoveryWarningFromResponse({
    required DesktopPrinterOs os,
    required Map<String, dynamic>? response,
    required Map<String, dynamic>? prerequisites,
  }) {
    if (response == null) return null;
    final cupsAvailable = _cupsAvailable(prerequisites);
    final usbDevices = response['usb'] as List?;
    final cupsQueues = response['cups'] as List?;
    if (os == DesktopPrinterOs.macos && (usbDevices?.isNotEmpty ?? false)) {
      return 'USB yazici bulundu ama secilebilir liste hazir degil';
    }
    if (os == DesktopPrinterOs.macos &&
        !(cupsAvailable ?? true) &&
        (cupsQueues?.isEmpty ?? true)) {
      return 'CUPS kullanilamiyor';
    }
    if (os == DesktopPrinterOs.windows &&
        (response['windows'] as List?)?.isEmpty == true) {
      return 'Windows yazici bulunamadi';
    }
    return null;
  }

  bool? _cupsAvailable(Map<String, dynamic>? prerequisites) {
    final dependencies = prerequisites?['dependencies'];
    if (dependencies is Map) {
      final cups = dependencies['cups']?.toString().trim().toLowerCase();
      if (cups == 'available') return true;
      if (cups == 'missing') return false;
    }
    return null;
  }

  UnifiedPrinterModel? _resolveSelection({
    required PrinterSetupRole role,
    required PrinterSetupLocalConfig? localConfig,
    required Map<String, dynamic>? remoteConfig,
    required List<UnifiedPrinterModel> printers,
    required DesktopPrinterOs os,
    bool preferRemoteFirst = false,
  }) {
    UnifiedPrinterModel? resolveLocal() {
      final localSelection = localConfig?.selectionForRole(role)?.printer;
      if (localSelection == null) {
        return null;
      }
      for (final printer in printers) {
        if (_printersMatch(localSelection, printer)) {
          return printer.copyWith(
            lastTestStatus: localSelection.lastTestStatus,
            lastError: localSelection.lastError,
            printerRecordId:
                localSelection.printerRecordId ?? printer.printerRecordId,
          );
        }
      }
      if (localSelection.printerRecordId?.isNotEmpty ?? false) {
        for (final printer in printers) {
          if (localSelection.printerRecordId == printer.printerRecordId) {
            return printer.copyWith(
              lastTestStatus: localSelection.lastTestStatus,
              lastError: localSelection.lastError,
              printerRecordId:
                  localSelection.printerRecordId ?? printer.printerRecordId,
            );
          }
        }
      }
      _log(
        'selection_stale_ignored',
        'role=${role.value} source=cache printer=${localSelection.id} '
            'recordId=${localSelection.printerRecordId ?? '-'} '
            'queue=${localSelection.queueName}',
      );
      return null;
    }

    UnifiedPrinterModel? resolveRemote() {
      final mappings = remoteConfig?['role_mappings'];
      if (mappings is Map) {
        final roleMap = mappings[role.value];
        if (roleMap is Map) {
          final remotePrinter = UnifiedPrinterModel.fromJson(
            Map<String, dynamic>.from(roleMap),
          );
          for (final printer in printers) {
            if (_printersMatch(remotePrinter, printer)) {
              return printer.copyWith(
                printerRecordId:
                    remotePrinter.printerRecordId ?? printer.printerRecordId,
              );
            }
          }
          if (remotePrinter.printerRecordId?.isNotEmpty ?? false) {
            for (final printer in printers) {
              if (remotePrinter.printerRecordId == printer.printerRecordId) {
                return printer.copyWith(
                  printerRecordId:
                      remotePrinter.printerRecordId ?? printer.printerRecordId,
                );
              }
            }
          }
          _log(
            'selection_stale_ignored',
            'role=${role.value} source=db printer=${remotePrinter.id} '
                'recordId=${remotePrinter.printerRecordId ?? '-'} '
                'queue=${remotePrinter.queueName}',
          );
          return null;
        }
      }

      final legacyId = role == PrinterSetupRole.adisyon
          ? remoteConfig == null
                ? null
                : remoteConfig['adisyon_printer_id']?.toString()
          : remoteConfig == null
          ? null
          : remoteConfig['kitchen_printer_id']?.toString();
      if (legacyId != null && legacyId.trim().isNotEmpty) {
        for (final printer in printers) {
          if (printer.id == legacyId.trim()) {
            return printer;
          }
        }
        _log(
          'selection_stale_ignored',
          'role=${role.value} source=db printer=${legacyId.trim()} queue=-',
        );
      }
      return null;
    }

    if (preferRemoteFirst) {
      return resolveRemote() ?? resolveLocal();
    }
    return resolveLocal() ?? resolveRemote();
  }

  bool _latestTestStillMatches(
    PrinterTestRecord? test,
    UnifiedPrinterModel? selection,
  ) {
    if (test == null || selection == null || !test.success) {
      return false;
    }
    final selectedRecordId = selection.printerRecordId?.trim();
    if (selectedRecordId != null && selectedRecordId.isNotEmpty) {
      final testRecordId = test.printerRecordId?.trim();
      if (testRecordId != null && testRecordId.isNotEmpty) {
        return selectedRecordId == testRecordId;
      }
    }
    return test.printerId == selection.id;
  }

  bool _matchesPrinterIdentifier(
    UnifiedPrinterModel printer,
    String identifier,
  ) {
    final needle = identifier.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final values = <String>[
      printer.id,
      printer.queueName,
      printer.displayName,
      printer.printerRecordId ?? '',
    ];
    for (final value in values) {
      if (value.trim().toLowerCase() == needle) {
        return true;
      }
    }
    if (needle.startsWith('windows:')) {
      final queue = needle.substring('windows:'.length);
      if (printer.queueName.trim().toLowerCase() == queue) {
        return true;
      }
    }
    return false;
  }

  UnifiedPrinterModel? _findLivePrinterByIdentifier(
    PrinterSetupSnapshot snapshot,
    String identifier,
  ) {
    for (final printer in snapshot.livePrinters) {
      if (_matchesPrinterIdentifier(printer, identifier)) {
        return printer;
      }
    }
    return null;
  }

  Future<UnifiedPrinterModel?> _resolvePrinterForTest({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    required PrinterSetupRole? role,
    required String? printerId,
    bool allowRoleFallback = true,
    bool? allowWorkingPrinterFallback,
  }) async {
    final directId = printerId?.trim() ?? '';
    if (directId.isNotEmpty) {
      final live = _findLivePrinterByIdentifier(snapshot, directId);
      if (live != null) {
        return _normalizePrinterForPhysicalDispatch(live);
      }
      for (final printer in snapshot.printers) {
        if (_matchesPrinterIdentifier(printer, directId) &&
            printer.isLiveDiscovery) {
          return _normalizePrinterForPhysicalDispatch(printer);
        }
      }
      if (!allowRoleFallback) {
        return null;
      }
      final selection = snapshot.localConfig?.selectionForRole(
        role ?? PrinterSetupRole.adisyon,
      );
      if (selection != null &&
          _matchesPrinterIdentifier(selection.printer, directId)) {
        return _resolveStoredPrinterCandidate(
          restaurantId: restaurantId,
          snapshot: snapshot,
          candidate: selection.printer,
        );
      }
      final legacyPrinter = await _printerRepository.fetchPrinterById(directId);
      if (legacyPrinter != null) {
        final resolved = _resolveUnifiedPrinterFromLegacy(
          legacyPrinter,
          printers: snapshot.livePrinters,
          os: snapshot.os,
        );
        if (resolved != null) {
          return _resolveStoredPrinterCandidate(
            restaurantId: restaurantId,
            snapshot: snapshot,
            candidate: resolved,
          );
        }
      }
      if (role == null) return null;
      return _resolvePrinterForRole(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: role,
        allowWorkingPrinterFallback: allowWorkingPrinterFallback,
      );
    }
    if (role == null) return null;
    if (!allowRoleFallback) return null;
    return _resolvePrinterForRole(
      restaurantId: restaurantId,
      snapshot: snapshot,
      role: role,
      allowWorkingPrinterFallback: allowWorkingPrinterFallback,
    );
  }

  Future<UnifiedPrinterModel?> _resolvePrinterFromBridgeTestResponse({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    required Map<String, dynamic>? response,
  }) async {
    final rawPrinter = response?['printer'];
    UnifiedPrinterModel? candidate;
    if (rawPrinter is Map) {
      final printerMap = Map<String, dynamic>.from(rawPrinter);
      candidate = _extractEmbeddedPayloadPrinter(printerMap, os: snapshot.os);
      candidate ??= UnifiedPrinterModel.fromBridgeMap(
        printerMap,
        os: snapshot.os,
      );
    }
    candidate ??= _printerFromDirectBridgeTestResponse(
      response,
      os: snapshot.os,
    );
    if (candidate == null) {
      return null;
    }
    return _resolveStoredPrinterCandidate(
      restaurantId: restaurantId,
      snapshot: snapshot,
      candidate: candidate,
    );
  }

  PrinterSetupRole? _inferRoleForPrinter({
    required PrinterSetupSnapshot snapshot,
    required UnifiedPrinterModel? printer,
  }) {
    if (printer == null) return null;
    final receipt = snapshot.localConfig?.receiptSelection?.printer;
    if (receipt != null && _printersMatch(receipt, printer)) {
      return PrinterSetupRole.adisyon;
    }
    final kitchen = snapshot.localConfig?.kitchenSelection?.printer;
    if (kitchen != null && _printersMatch(kitchen, printer)) {
      return PrinterSetupRole.mutfak;
    }
    return null;
  }

  bool _printersMatch(UnifiedPrinterModel left, UnifiedPrinterModel right) {
    final leftId = left.id.trim().toLowerCase();
    final rightId = right.id.trim().toLowerCase();
    if (leftId.isNotEmpty && rightId.isNotEmpty && leftId == rightId) {
      return true;
    }
    final leftQueue = left.queueName.trim().toLowerCase();
    final rightQueue = right.queueName.trim().toLowerCase();
    if (leftQueue.isNotEmpty &&
        rightQueue.isNotEmpty &&
        leftQueue == rightQueue) {
      return true;
    }
    final leftName = left.displayName.trim().toLowerCase();
    final rightName = right.displayName.trim().toLowerCase();
    return leftName.isNotEmpty && rightName.isNotEmpty && leftName == rightName;
  }

  Future<PrinterSetupLocalConfig?> _loadLocalConfig(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_localConfigPrefix$restaurantId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return PrinterSetupLocalConfig.decode(raw);
    } catch (error) {
      debugPrint(
        '[PrintOrchestrator] local config decode failed '
        'restaurantId=$restaurantId error=$error',
      );
      return null;
    }
  }

  Future<void> _clearLocalConfig(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_localConfigPrefix$restaurantId');
    _snapshotCache.remove(restaurantId.trim());
  }

  List<UnifiedPrinterModel> _annotatePrintersWithRecordIds(
    List<UnifiedPrinterModel> printers,
    List<PrinterModel> savedPrinters,
  ) {
    return printers
        .map((printer) {
          final matched = _matchExistingPrinter(savedPrinters, printer);
          if (matched == null) {
            return printer;
          }
          return printer.copyWith(printerRecordId: matched.id);
        })
        .toList(growable: false);
  }

  List<UnifiedPrinterModel> _mergeCanonicalPrinterCatalog({
    required List<UnifiedPrinterModel> livePrinters,
    required List<PrinterModel> savedPrinters,
    required DesktopPrinterOs os,
    required UnifiedPrinterModel? workingPrinter,
  }) {
    final annotatedLive = _annotatePrintersWithRecordIds(
      livePrinters,
      savedPrinters,
    );

    // When /printers returns live Windows queues, do not inject stale DB-only rows.
    if (os == DesktopPrinterOs.windows && livePrinters.isNotEmpty) {
      final merged = List<UnifiedPrinterModel>.from(annotatedLive);
      if (workingPrinter != null && workingPrinter.isLiveDiscovery) {
        final matchedSaved = _matchExistingPrinter(
          savedPrinters,
          workingPrinter,
        );
        final canonicalWorkingPrinter = workingPrinter.copyWith(
          printerRecordId: workingPrinter.printerRecordId ?? matchedSaved?.id,
        );
        if (!merged.any((p) => _printersMatch(p, canonicalWorkingPrinter))) {
          merged.add(canonicalWorkingPrinter);
        }
      }
      return _sortPrinters(merged, os: os);
    }

    final merged = <UnifiedPrinterModel>[...annotatedLive];

    for (final savedPrinter in savedPrinters) {
      // Ethernet printers are not discovered by the bridge; surface them in
      // the catalog directly from the saved record so the setup wizard can
      // list and select them.
      if (savedPrinter.isEthernetConnection) {
        final ethernetPrinter = _buildEthernetUnifiedPrinter(
          savedPrinter,
          os: os,
        );
        if (!merged.any((p) => _printersMatch(p, ethernetPrinter))) {
          merged.add(ethernetPrinter);
        }
        continue;
      }
      final resolvedLive = _resolveUnifiedPrinterFromLegacy(
        savedPrinter,
        printers: merged,
        os: os,
      );
      if (resolvedLive != null) {
        continue;
      }
      final fallback = _legacyPrinterToFallbackUnified(savedPrinter, os: os);
      if (fallback != null) {
        merged.add(fallback);
      }
    }

    if (workingPrinter != null) {
      final matchedSaved = _matchExistingPrinter(savedPrinters, workingPrinter);
      final canonicalWorkingPrinter = workingPrinter.copyWith(
        printerRecordId: workingPrinter.printerRecordId ?? matchedSaved?.id,
      );
      final alreadyPresent = merged.any(
        (printer) => _printersMatch(printer, canonicalWorkingPrinter),
      );
      if (!alreadyPresent) {
        merged.add(canonicalWorkingPrinter);
      }
    }

    final byKey = <String, UnifiedPrinterModel>{};
    for (final printer in merged) {
      final recordId = printer.printerRecordId?.trim() ?? '';
      final key = recordId.isNotEmpty
          ? 'record:$recordId'
          : 'bridge:${printer.id}';
      byKey[key] = printer;
    }
    return _sortPrinters(byKey.values.toList(growable: false), os: os);
  }

  UnifiedPrinterModel? _legacyPrinterToFallbackUnified(
    PrinterModel printer, {
    required DesktopPrinterOs os,
  }) {
    final deviceIdentifier = (printer.deviceIdentifier ?? '').trim();
    final resolvedName = printer.name.trim().isEmpty
        ? 'Yazıcı'
        : printer.name.trim();
    final queueName =
        deviceIdentifier.isNotEmpty && !deviceIdentifier.startsWith('/print/')
        ? deviceIdentifier
        : resolvedName;
    final normalizedDevice = deviceIdentifier.toLowerCase();
    final aliasFingerprint = '${printer.name} ${printer.code} $deviceIdentifier'
        .toLowerCase();
    final looksUsb =
        printer.formConnectionType == PrinterModel.usbConnectionType ||
        normalizedDevice.startsWith('usb-') ||
        _looksLikePos58Alias(aliasFingerprint);
    final backend = os == DesktopPrinterOs.windows
        ? DesktopPrinterBackend.windowsSpool
        : looksUsb
        ? DesktopPrinterBackend.usbDirect
        : DesktopPrinterBackend.cups;
    return UnifiedPrinterModel(
      id: printer.id,
      displayName: resolvedName,
      queueName: queueName,
      backend: backend,
      os: os,
      isAvailable: false,
      canPrint: false,
      lastTestStatus: printer.testPrintStatus,
      lastError: printer.lastError,
      printerRecordId: printer.id,
      statusLevel: printer.isActive ? 'saved' : 'inactive',
      statusMessage: printer.isActive ? 'Kayitli' : 'Pasif',
      raw: <String, dynamic>{
        'id': printer.id,
        'name': resolvedName,
        'queue': queueName,
        'backend': backend.value,
        'printerRecordId': printer.id,
        'printer_record_id': printer.id,
        'source': 'saved_record',
        'isSavedOnly': true,
        'deviceIdentifier': deviceIdentifier,
        'device_identifier': deviceIdentifier,
      },
    );
  }

  Future<UnifiedPrinterModel?> _resolvePrinterForRole({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    required PrinterSetupRole role,
    bool? allowWorkingPrinterFallback,
    bool preferRemoteFirst = false,
  }) async {
    final allowFallback = _allowWorkingPrinterFallbackForRole(
      role,
      allowWorkingPrinterFallback,
    );
    final candidate = _resolveSelection(
      role: role,
      localConfig: snapshot.localConfig,
      remoteConfig: snapshot.remoteConfig,
      printers: snapshot.printers,
      os: snapshot.os,
      preferRemoteFirst: preferRemoteFirst,
    );
    if (candidate != null) {
      final resolvedCandidate = await _resolveStoredPrinterCandidate(
        restaurantId: restaurantId,
        snapshot: snapshot,
        candidate: candidate,
      );
      if (_isBridgeReadyPrinter(resolvedCandidate)) {
        return _normalizePrinterForPhysicalDispatch(
          resolvedCandidate!.copyWith(
            lastTestStatus: candidate.lastTestStatus,
            lastError: candidate.lastError,
            printerRecordId:
                candidate.printerRecordId ?? resolvedCandidate.printerRecordId,
          ),
        );
      }
    }
    final fallbackRecordId =
        candidate?.printerRecordId?.trim() ??
        (role == PrinterSetupRole.adisyon
            ? snapshot.selectedReceiptPrinterId?.trim()
            : snapshot.selectedKitchenPrinterId?.trim()) ??
        '';
    final printerRecordId = fallbackRecordId;
    if (printerRecordId.isEmpty) {
      if (!allowFallback) {
        return null;
      }
      final workingPrinter = await _resolveWorkingPrinter(
        restaurantId: restaurantId,
        snapshot: snapshot,
      );
      if (workingPrinter != null) {
        return _normalizePrinterForPhysicalDispatch(workingPrinter);
      }
      return null;
    }

    final storedPrinter = await _printerRepository.getPrinterByRecordId(
      printerRecordId,
    );
    if (storedPrinter == null) return null;

    final resolved = _resolveUnifiedPrinterFromLegacy(
      storedPrinter,
      printers: snapshot.printers,
      os: snapshot.os,
    );
    if (resolved == null || !_isBridgeReadyPrinter(resolved)) {
      if (!allowFallback) {
        return null;
      }
      final workingPrinter = await _resolveWorkingPrinter(
        restaurantId: restaurantId,
        snapshot: snapshot,
      );
      if (workingPrinter != null) {
        return _normalizePrinterForPhysicalDispatch(workingPrinter);
      }
      return null;
    }

    return _normalizePrinterForPhysicalDispatch(
      resolved.copyWith(
        lastTestStatus: candidate?.lastTestStatus,
        lastError: candidate?.lastError,
        printerRecordId: storedPrinter.id,
      ),
    );
  }

  Future<UnifiedPrinterModel?> _resolveKitchenPrinterForStationOrRole({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    String? stationId,
    String? stationName,
    String? tableId,
    String? orderId,
    String? printJobId,
    required String flowName,
    required String source,
  }) async {
    final normalizedStationId = stationId?.trim() ?? '';
    final normalizedTableId = tableId?.trim() ?? '-';
    final normalizedOrderId = orderId?.trim().isNotEmpty == true
        ? orderId!.trim()
        : (printJobId?.trim().isNotEmpty == true ? printJobId!.trim() : '-');
    var effectiveStationName = _kitchenResolveStationLabel(
      stationName: stationName,
      stationId: normalizedStationId,
    );
    final dbExpectation = await _resolveKitchenDbRoutingExpectation(
      restaurantId: restaurantId,
      snapshot: snapshot,
      stationId: normalizedStationId,
      stationName: effectiveStationName,
    );
    StationPrinterModel? selectedMapping;
    PrinterModel? stationMappedPrinter;
    UnifiedPrinterModel? stationResolvedPrinter;

    debugPrint('[KitchenPrinterResolve][start]');
    debugPrint('role=mutfak');
    debugPrint('station=$effectiveStationName');
    debugPrint(
      'stationId=${normalizedStationId.isEmpty ? '-' : normalizedStationId}',
    );
    debugPrint('table=$normalizedTableId');
    debugPrint('orderId=$normalizedOrderId');

    if (normalizedStationId.isNotEmpty) {
      final mappings = (await _printerRepository.fetchStationPrinterMappings(
        restaurantId,
      )).whereType<StationPrinterModel>().toList(growable: false);
      selectedMapping = _resolvePrimaryStationPrinterMapping(
        mappings,
        normalizedStationId,
      );
      if (selectedMapping != null) {
        if ((stationName?.trim().isEmpty ?? true) &&
            (selectedMapping.stationName?.trim().isNotEmpty ?? false)) {
          effectiveStationName = selectedMapping.stationName!.trim();
        }
        stationMappedPrinter = await _printerRepository.getPrinterByRecordId(
          selectedMapping.printerId,
        );
        if (stationMappedPrinter != null) {
          final resolved = _resolveUnifiedPrinterFromLegacy(
            stationMappedPrinter,
            printers: snapshot.printers,
            os: snapshot.os,
          );
          if (resolved != null) {
            stationResolvedPrinter = _normalizePrinterForPhysicalDispatch(
              resolved.copyWith(printerRecordId: stationMappedPrinter.id),
            );
          }
        }
      }
    }

    if (selectedMapping != null &&
        stationMappedPrinter != null &&
        _isEthernetPrinterRow(stationMappedPrinter) &&
        stationResolvedPrinter == null) {
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'printer_route_resolved',
        flowName: flowName,
        source: source,
        role: PrinterSetupRole.mutfak.value,
        documentType: 'kitchen',
        tableId: tableId,
        printJobId: printJobId,
        fallbackReason: 'station_mapping_ethernet_resolution_failed',
        errorMessage:
            'Mutfak fişi yazdırılamadı: mutfak yazıcısı Ethernet olarak atanmış ama runtime çözümleme başarısız.',
        level: 'error',
        details: <String, dynamic>{
          'resolution_source': 'station_mapping',
          'station_id': normalizedStationId,
          'station_name': effectiveStationName,
          'expected_printer': stationMappedPrinter.name,
          'expected_backend': 'tcp',
          'expected_host': _legacyPrinterHost(stationMappedPrinter),
          'expected_port': _legacyPrinterPort(stationMappedPrinter),
        },
      );
      return null;
    }

    _debugKitchenPrinterResolveSelection(
      phase: 'station_mapping',
      recordId: selectedMapping?.printerId,
      fallbackName: stationMappedPrinter?.name ?? selectedMapping?.printerName,
      printer: stationResolvedPrinter,
      legacyPrinter: stationMappedPrinter,
    );

    UnifiedPrinterModel? roleResolvedPrinter;
    if (stationResolvedPrinter == null && selectedMapping == null) {
      roleResolvedPrinter = await _resolvePrinterForRole(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: PrinterSetupRole.mutfak,
        allowWorkingPrinterFallback: false,
        preferRemoteFirst: true,
      );
    }

    if (stationResolvedPrinter == null &&
        roleResolvedPrinter == null &&
        dbExpectation != null &&
        dbExpectation.source == 'mutfak_role_mapping' &&
        dbExpectation.isEthernet) {
      await _runtimeLog(
        restaurantId: restaurantId,
        event: 'printer_route_resolved',
        flowName: flowName,
        source: source,
        role: PrinterSetupRole.mutfak.value,
        documentType: 'kitchen',
        tableId: tableId,
        printJobId: printJobId,
        fallbackReason: 'mutfak_role_mapping_ethernet_resolution_failed',
        errorMessage:
            'Mutfak fişi yazdırılamadı: mutfak yazıcısı Ethernet olarak atanmış ama runtime çözümleme başarısız.',
        level: 'error',
        details: <String, dynamic>{
          'resolution_source': 'mutfak_role_mapping',
          'station_id': normalizedStationId,
          'station_name': effectiveStationName,
          'expected_printer': dbExpectation.printer.name,
          'expected_backend': 'tcp',
          'expected_host': _legacyPrinterHost(dbExpectation.printer),
          'expected_port': _legacyPrinterPort(dbExpectation.printer),
        },
      );
      return null;
    }

    _debugKitchenPrinterResolveSelection(
      phase: 'role_mapping',
      recordId: roleResolvedPrinter?.printerRecordId,
      fallbackName: roleResolvedPrinter?.displayName,
      printer: roleResolvedPrinter,
    );

    final receiptPrinter = snapshot.localConfig?.receiptSelection?.printer;
    final kitchenRolePrinter = snapshot.localConfig?.kitchenSelection?.printer;
    debugPrint('[KitchenPrinterResolve][expected_mapping]');
    debugPrint('receiptPrinter=${receiptPrinter?.displayName ?? '-'}');
    debugPrint('kitchenPrinter=${kitchenRolePrinter?.displayName ?? '-'}');
    debugPrint('kitchenBackend=${kitchenRolePrinter?.backend.value ?? '-'}');
    debugPrint(
      'kitchenHost=${kitchenRolePrinter == null ? '-' : _printerHost(kitchenRolePrinter)}',
    );
    debugPrint(
      'kitchenPort=${kitchenRolePrinter == null ? '-' : _printerPort(kitchenRolePrinter).toString()}',
    );
    debugPrint(
      'stationPrinter=${stationResolvedPrinter?.displayName ?? stationMappedPrinter?.name ?? '-'}',
    );
    debugPrint(
      'stationBackend=${stationResolvedPrinter?.backend.value ?? _legacyPrinterBackend(stationMappedPrinter) ?? '-'}',
    );
    debugPrint(
      'stationHost=${stationResolvedPrinter == null ? (_legacyPrinterHost(stationMappedPrinter) ?? '-') : _printerHost(stationResolvedPrinter)}',
    );
    debugPrint(
      'stationPort=${stationResolvedPrinter == null ? (_legacyPrinterPort(stationMappedPrinter)?.toString() ?? '-') : _printerPort(stationResolvedPrinter).toString()}',
    );

    final expectedResolvedPrinter = dbExpectation == null
        ? null
        : await _resolveExpectedKitchenPrinterFromDb(
            snapshot: snapshot,
            expected: dbExpectation.expected,
          );
    var finalPrinter = stationResolvedPrinter ?? roleResolvedPrinter;
    if (dbExpectation != null &&
        expectedResolvedPrinter != null &&
        (finalPrinter == null ||
            !_sameResolvedPrinterRoute(
              finalPrinter,
              expectedResolvedPrinter,
            ))) {
      finalPrinter = expectedResolvedPrinter;
    }
    if (dbExpectation != null &&
        dbExpectation.isEthernet &&
        (finalPrinter == null ||
            _isBlockedKitchenPrinterCandidate(finalPrinter))) {
      if (expectedResolvedPrinter == null ||
          !_isBridgeReadyPrinter(expectedResolvedPrinter)) {
        await _runtimeLog(
          restaurantId: restaurantId,
          event: 'printer_route_resolved',
          flowName: flowName,
          source: source,
          role: PrinterSetupRole.mutfak.value,
          documentType: 'kitchen',
          tableId: tableId,
          printJobId: printJobId,
          fallbackReason: 'db_ethernet_target_unavailable',
          errorMessage:
              'Mutfak fişi yazdırılamadı: mutfak yazıcısı Ethernet olarak atanmış ama runtime çözümleme başarısız.',
          level: 'error',
          details: <String, dynamic>{
            'actual_printer': finalPrinter?.displayName,
            'actual_backend': finalPrinter?.backend.value,
            'expected_printer': dbExpectation.printer.name,
            'expected_backend': dbExpectation.expected.backend,
            'expected_host': dbExpectation.expected.host,
            'expected_port': dbExpectation.expected.port,
            'reason': 'stale_local_config_or_persisted_payload',
          },
        );
        return null;
      }
      finalPrinter = expectedResolvedPrinter;
    }
    final finalSource =
        dbExpectation?.source ??
        (stationResolvedPrinter != null
            ? 'station_mapping'
            : (roleResolvedPrinter != null ? 'mutfak_role_mapping' : 'error'));
    debugPrint('[KitchenPrinterResolve][final]');
    debugPrint('source=$finalSource');
    debugPrint('printerId=${finalPrinter?.id ?? '-'}');
    debugPrint('printerName=${finalPrinter?.displayName ?? '-'}');
    debugPrint('backend=${finalPrinter?.backend.value ?? '-'}');
    debugPrint(
      'transportType=${finalPrinter == null ? '-' : _transportTypeForPrinter(finalPrinter)}',
    );
    debugPrint(
      'host=${finalPrinter == null ? '-' : _printerHost(finalPrinter)}',
    );
    debugPrint(
      'port=${finalPrinter == null ? '-' : _printerPort(finalPrinter).toString()}',
    );

    await _runtimeLog(
      restaurantId: restaurantId,
      event: 'role_printer_resolved',
      flowName: flowName,
      source: source,
      role: PrinterSetupRole.mutfak.value,
      documentType: 'kitchen',
      printer: finalPrinter,
      tableId: tableId,
      printJobId: printJobId,
      fallbackReason: finalPrinter == null
          ? 'kitchen_printer_unassigned'
          : null,
      errorMessage: finalPrinter == null ? 'Mutfak yazıcısı atanmadı.' : null,
      level: finalPrinter == null ? 'error' : 'info',
      details: <String, dynamic>{
        'station_id': normalizedStationId.isEmpty ? '-' : normalizedStationId,
        'station_name': effectiveStationName,
        'order_id': normalizedOrderId,
        'resolution_source': finalSource,
        'selected_mapping_id': selectedMapping?.id,
        'selected_printer_id':
            stationMappedPrinter?.id ??
            roleResolvedPrinter?.printerRecordId ??
            finalPrinter?.printerRecordId,
        'selected_printer_name':
            stationMappedPrinter?.name ?? finalPrinter?.displayName,
        'fallback_used':
            stationResolvedPrinter == null && roleResolvedPrinter != null,
        'fallback_reason':
            stationResolvedPrinter == null &&
                roleResolvedPrinter != null &&
                normalizedStationId.isNotEmpty
            ? 'station_mapping_not_found'
            : null,
      },
    );
    return finalPrinter;
  }

  StationPrinterModel? _resolvePrimaryStationPrinterMapping(
    List<StationPrinterModel> mappings,
    String stationId,
  ) {
    for (final mapping in mappings) {
      if (mapping.stationId == stationId && mapping.isPrimary) {
        return mapping;
      }
    }
    for (final mapping in mappings) {
      if (mapping.stationId == stationId) {
        return mapping;
      }
    }
    return null;
  }

  Future<_KitchenDbRoutingExpectation?> _resolveKitchenDbRoutingExpectation({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    required String stationId,
    String? stationName,
  }) async {
    final expected = await _printerRepository.resolveExpectedKitchenPrinter(
      restaurantId: restaurantId,
      stationId: stationId,
      stationName: stationName,
    );
    if (expected == null) {
      return null;
    }
    return _KitchenDbRoutingExpectation(expected: expected);
  }

  bool _isEthernetPrinterRow(PrinterModel? printer) {
    return printer?.connectionType == PrinterModel.networkConnectionType;
  }

  bool _isBlockedKitchenPrinterCandidate(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.cups ||
        printer.backend == DesktopPrinterBackend.usbDirect) {
      return true;
    }
    final text = '${printer.id} ${printer.queueName} ${printer.displayName}'
        .toLowerCase();
    return _looksLikePos58Alias(text);
  }

  bool _sameResolvedPrinterRoute(
    UnifiedPrinterModel left,
    UnifiedPrinterModel right,
  ) {
    final leftRecordId = left.printerRecordId?.trim() ?? '';
    final rightRecordId = right.printerRecordId?.trim() ?? '';
    if (leftRecordId.isNotEmpty &&
        rightRecordId.isNotEmpty &&
        leftRecordId == rightRecordId) {
      return true;
    }
    if (left.backend != right.backend) {
      return false;
    }
    final leftHost = _printerHost(left);
    final rightHost = _printerHost(right);
    if (leftHost.isNotEmpty || rightHost.isNotEmpty) {
      return leftHost == rightHost && _printerPort(left) == _printerPort(right);
    }
    return left.queueName.trim().toLowerCase() ==
        right.queueName.trim().toLowerCase();
  }

  Future<UnifiedPrinterModel?> _resolveExpectedKitchenPrinterFromDb({
    required PrinterSetupSnapshot snapshot,
    required ExpectedKitchenPrinterResolution expected,
  }) async {
    final resolved = _resolveUnifiedPrinterFromLegacy(
      expected.printer,
      printers: snapshot.printers,
      os: snapshot.os,
    );
    if (resolved == null) {
      return null;
    }
    return _normalizePrinterForPhysicalDispatch(
      resolved.copyWith(printerRecordId: expected.printer.id),
    );
  }

  Future<UnifiedPrinterModel?> _resolveKitchenLocalFallback({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
  }) async {
    final localKitchenSelection = snapshot.localConfig
        ?.selectionForRole(PrinterSetupRole.mutfak)
        ?.printer;
    if (localKitchenSelection == null) {
      return null;
    }
    final resolved = await _resolveStoredPrinterCandidate(
      restaurantId: restaurantId,
      snapshot: snapshot,
      candidate: localKitchenSelection,
    );
    if (resolved == null) return null;
    if (!_isBridgeReadyPrinter(resolved)) {
      return null;
    }
    return _normalizePrinterForPhysicalDispatch(resolved);
  }

  bool _allowWorkingPrinterFallbackForRole(
    PrinterSetupRole role,
    bool? override,
  ) {
    if (override != null) return override;
    return role != PrinterSetupRole.mutfak;
  }

  void _debugKitchenPrinterResolveSelection({
    required String phase,
    required String? recordId,
    required String? fallbackName,
    required UnifiedPrinterModel? printer,
    PrinterModel? legacyPrinter,
  }) {
    debugPrint('[KitchenPrinterResolve][$phase]');
    debugPrint(
      'selectedPrinterId=${printer?.id ?? (recordId?.trim().isNotEmpty == true ? recordId!.trim() : '-')}',
    );
    debugPrint(
      'selectedPrinterName=${printer?.displayName ?? fallbackName ?? '-'}',
    );
    debugPrint(
      'backend=${printer?.backend.value ?? _legacyPrinterBackend(legacyPrinter) ?? '-'}',
    );
    debugPrint(
      'host=${printer == null ? (_legacyPrinterHost(legacyPrinter) ?? '-') : _printerHost(printer)}',
    );
    debugPrint(
      'port=${printer == null ? (_legacyPrinterPort(legacyPrinter)?.toString() ?? '-') : _printerPort(printer).toString()}',
    );
  }

  String _kitchenResolveStationLabel({String? stationName, String? stationId}) {
    final normalizedName = stationName?.trim() ?? '';
    if (normalizedName.isNotEmpty) return normalizedName;
    final normalizedId = stationId?.trim() ?? '';
    if (normalizedId.isNotEmpty) return normalizedId;
    return 'Genel';
  }

  String _transportTypeForPrinter(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.tcp) {
      return PrinterModel.ethernetBridgeTransport;
    }
    return printer.backend.value;
  }

  String _printerHost(UnifiedPrinterModel? printer) {
    if (printer == null) return '';
    return (printer.raw['host'] ??
                printer.raw['ip_address'] ??
                printer.raw['ipAddress'])
            ?.toString()
            .trim() ??
        '';
  }

  int _printerPort(UnifiedPrinterModel? printer) {
    if (printer == null) return 0;
    final rawPort = printer.raw['port'] ?? printer.raw['tcp_port'];
    if (rawPort is int) return rawPort;
    return int.tryParse(rawPort?.toString() ?? '') ?? 0;
  }

  String? _legacyPrinterBackend(PrinterModel? printer) {
    if (printer == null) return null;
    if (printer.isEthernetConnection) {
      return PrinterModel.ethernetBridgeBackend;
    }
    if (printer.connectionType == PrinterModel.usbConnectionType) {
      return DesktopPrinterBackend.usbDirect.value;
    }
    return DesktopPrinterBackend.cups.value;
  }

  String? _legacyPrinterHost(PrinterModel? printer) {
    if (printer == null || !printer.isEthernetConnection) return null;
    final host = printer.ethernetHost.trim();
    return host.isEmpty ? null : host;
  }

  int? _legacyPrinterPort(PrinterModel? printer) {
    if (printer == null || !printer.isEthernetConnection) return null;
    return printer.ethernetPort;
  }

  bool _isBridgeReadyPrinter(UnifiedPrinterModel? printer) {
    if (printer == null) return false;
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host = _printerHost(printer);
      final port = _printerPort(printer);
      return printer.id.trim().isNotEmpty &&
          printer.queueName.trim().isNotEmpty &&
          printer.backend.value.trim().isNotEmpty &&
          host.isNotEmpty &&
          port > 0;
    }
    return isSelectableLivePrinter(printer) &&
        printer.id.trim().isNotEmpty &&
        printer.queueName.trim().isNotEmpty &&
        printer.backend.value.trim().isNotEmpty;
  }

  Map<String, dynamic> _mergeOperatorSetupStatus({
    required bool bridgeReachable,
    required bool bridgeHealthy,
    required int livePrinterCount,
    required Map<String, dynamic>? remoteStatus,
    Map<String, dynamic>? bridgeHealth,
  }) {
    final operator = buildBridgeOperatorSetupStatus(
      bridgeReachable: bridgeReachable,
      bridgeHealthy: bridgeHealthy,
      livePrinterCount: livePrinterCount,
      bridgeHealth: bridgeHealth,
    );
    if (remoteStatus == null || remoteStatus.isEmpty) {
      return operator;
    }
    final remoteKey = remoteStatus['status']?.toString().trim().toLowerCase();
    if (!bridgeReachable) {
      return operator;
    }
    if (bridgeReachable && (bridgeHealthy || livePrinterCount > 0)) {
      return <String, dynamic>{
        ...remoteStatus,
        ...operator,
        'status': bridgeHealthy ? 'ready' : 'running_unhealthy',
        'message': operator['message'],
        'errorCode': bridgeHealthy ? null : 'running_unhealthy',
        'ok': bridgeHealthy,
      };
    }
    if (remoteKey == 'driver_missing' || remoteKey == 'printer_offline') {
      return <String, dynamic>{...operator, ...remoteStatus};
    }
    return <String, dynamic>{...remoteStatus, ...operator};
  }

  Map<String, dynamic>? _mergeOperatorPrerequisites({
    required bool bridgeReachable,
    required bool bridgeHealthy,
    required int livePrinterCount,
    required Map<String, dynamic>? remotePrerequisites,
    Map<String, dynamic>? bridgeHealth,
  }) {
    final operatorChecks = buildBridgeOperatorSetupStatus(
      bridgeReachable: bridgeReachable,
      bridgeHealthy: bridgeHealthy,
      livePrinterCount: livePrinterCount,
      bridgeHealth: bridgeHealth,
    )['checks'];
    if (remotePrerequisites == null || remotePrerequisites.isEmpty) {
      return <String, dynamic>{
        'ok': bridgeReachable && bridgeHealthy,
        'checks': operatorChecks,
      };
    }
    return <String, dynamic>{
      ...remotePrerequisites,
      'ok': bridgeReachable && bridgeHealthy,
      'checks': operatorChecks,
    };
  }

  Future<UnifiedPrinterModel?> _resolveStoredPrinterCandidate({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    required UnifiedPrinterModel? candidate,
  }) async {
    if (candidate == null) return null;

    for (final printer in snapshot.printers) {
      if (_printersMatch(candidate, printer)) {
        return _normalizePrinterForPhysicalDispatch(
          printer.copyWith(
            lastTestStatus: candidate.lastTestStatus,
            lastError: candidate.lastError,
            printerRecordId:
                candidate.printerRecordId ?? printer.printerRecordId,
          ),
        );
      }
    }
    if (candidate.printerRecordId?.isNotEmpty ?? false) {
      for (final printer in snapshot.printers) {
        if (candidate.printerRecordId == printer.printerRecordId) {
          return _normalizePrinterForPhysicalDispatch(
            printer.copyWith(
              lastTestStatus: candidate.lastTestStatus,
              lastError: candidate.lastError,
              printerRecordId:
                  candidate.printerRecordId ?? printer.printerRecordId,
            ),
          );
        }
      }
    }

    final candidateRecordId = candidate.printerRecordId?.trim() ?? '';
    if (candidateRecordId.isNotEmpty) {
      final savedPrinter = await _printerRepository.fetchPrinterById(
        candidateRecordId,
      );
      if (savedPrinter != null) {
        final resolved = _resolveUnifiedPrinterFromLegacy(
          savedPrinter,
          printers: snapshot.printers,
          os: snapshot.os,
        );
        if (resolved != null) {
          return _normalizePrinterForPhysicalDispatch(
            resolved.copyWith(
              lastTestStatus: candidate.lastTestStatus,
              lastError: candidate.lastError,
              printerRecordId: savedPrinter.id,
            ),
          );
        }
      }
    }

    final savedPrinters = await _printerRepository.fetchPrinters(restaurantId);
    final matchedSavedPrinter = _matchExistingPrinter(savedPrinters, candidate);
    if (matchedSavedPrinter != null) {
      final resolved = _resolveUnifiedPrinterFromLegacy(
        matchedSavedPrinter,
        printers: snapshot.printers,
        os: snapshot.os,
      );
      if (resolved != null) {
        return _normalizePrinterForPhysicalDispatch(
          resolved.copyWith(
            lastTestStatus: candidate.lastTestStatus,
            lastError: candidate.lastError,
            printerRecordId: matchedSavedPrinter.id,
          ),
        );
      }
    }

    return null;
  }

  Future<void> _saveLocalConfig(PrinterSetupLocalConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_localConfigPrefix${config.restaurantId}',
      config.encode(),
    );
    _snapshotCache.remove(config.restaurantId.trim());
  }

  Future<UnifiedPrinterModel> _resolveSavedPrinterSelection({
    required PrinterSetupSnapshot snapshot,
    required String requestedId,
    required PrinterSetupRole role,
  }) async {
    final normalizedId = requestedId.trim();
    if (normalizedId.isEmpty) {
      throw StateError('${role.value}_printer_not_found');
    }

    for (final printer in snapshot.printers) {
      if (printer.id == normalizedId) {
        return printer;
      }
    }

    final legacyPrinter = await _printerRepository.fetchPrinterById(
      normalizedId,
    );
    if (legacyPrinter != null) {
      final resolved = _resolveUnifiedPrinterFromLegacy(
        legacyPrinter,
        printers: snapshot.printers,
        os: snapshot.os,
      );
      if (resolved != null) {
        return resolved;
      }
    }

    for (final printer in snapshot.printers) {
      if (printer.printerRecordId == normalizedId) {
        return _normalizePrinterForPhysicalDispatch(printer);
      }
    }

    throw StateError('${role.value}_printer_not_found');
  }

  void _logRoleMappingState({
    required String action,
    required String restaurantId,
    required PrinterSetupLocalConfig config,
  }) {
    final localConfigJson = jsonEncode(config.toJson());
    _log(action, 'restaurantId=$restaurantId localConfigJson=$localConfigJson');
    debugPrint('[PrintOrchestrator][$action] restaurantId=$restaurantId');
    _eventLogService
        .append(
          restaurantId: restaurantId,
          event: action,
          message: action == 'role_mapping_save'
              ? 'Yerel rol eşleştirmesi kaydedildi.'
              : 'Yerel rol eşleştirmesi yeniden yüklendi.',
          role: 'all',
          details: <String, dynamic>{'localConfigJson': localConfigJson},
        )
        .ignore();
  }

  Future<Map<String, dynamic>?> _safeFetchRemoteConfig(
    String restaurantId,
  ) async {
    try {
      return await _printStationService.fetchStationConfig(restaurantId);
    } catch (error) {
      debugPrint(
        '[PrintOrchestrator] fetch remote config failed '
        'restaurantId=$restaurantId error=$error',
      );
      return null;
    }
  }

  Future<void> _debugPrinterMappingSaveStart({
    required String restaurantId,
    required UnifiedPrinterModel receiptPrinter,
    required UnifiedPrinterModel kitchenPrinter,
  }) async {
    debugPrint('[PrinterMapping][save_start]');
    debugPrint('receipt=${receiptPrinter.displayName}');
    debugPrint(
      'kitchen=${kitchenPrinter.displayName} '
      'backend=${kitchenPrinter.backend.value} '
      'host=${_printerHost(kitchenPrinter).isEmpty ? '-' : _printerHost(kitchenPrinter)} '
      'port=${_printerPort(kitchenPrinter) > 0 ? _printerPort(kitchenPrinter) : '-'}',
    );
    final printerRows = await _printerRepository.fetchPrinters(restaurantId);
    final printerById = <String, PrinterModel>{
      for (final printer in printerRows) printer.id: printer,
    };
    final mappings = (await _printerRepository.fetchStationPrinterMappings(
      restaurantId,
    )).whereType<StationPrinterModel>().toList(growable: false);
    final seenStations = <String>{};
    for (final mapping in mappings) {
      if (!mapping.isPrimary || !seenStations.add(mapping.stationId)) {
        continue;
      }
      final mappedPrinter = printerById[mapping.printerId];
      final backend = _legacyPrinterBackend(mappedPrinter) ?? '-';
      final host = _legacyPrinterHost(mappedPrinter) ?? '-';
      final port = _legacyPrinterPort(mappedPrinter)?.toString() ?? '-';
      final stationLabel = mapping.stationName?.trim().isNotEmpty == true
          ? mapping.stationName!.trim()
          : mapping.stationId;
      final printerLabel =
          mappedPrinter?.name ??
          mapping.printerName?.trim() ??
          mapping.printerId;
      debugPrint(
        'station=$stationLabel printer=$printerLabel backend=$backend host=$host port=$port',
      );
    }
  }

  Map<String, dynamic> _roleMappingsPayload(PrinterSetupLocalConfig config) {
    return <String, dynamic>{
      PrinterSetupRole.adisyon.value: config.receiptSelection == null
          ? null
          : _roleMappingPrinterPayload(config.receiptSelection!.printer),
      PrinterSetupRole.mutfak.value: config.kitchenSelection == null
          ? null
          : _roleMappingPrinterPayload(config.kitchenSelection!.printer),
    };
  }

  void _logDiscoveredPrinters({
    required String restaurantId,
    required List<UnifiedPrinterModel> printers,
  }) {
    for (final printer in printers) {
      _log(
        'printer_inventory',
        'restaurantId=$restaurantId source=${printer.raw['source'] ?? 'usb_scan'} '
            'printer=${printer.id} recordId=${printer.printerRecordId ?? '-'} '
            'queue=${printer.queueName} backend=${printer.backend.value}',
      );
    }
  }

  Map<String, String> _buildBridgePreset({
    required String platformName,
    required UnifiedPrinterModel printer,
  }) {
    if (_printStationService.normalizeStationPlatform(platformName) ==
        'windows') {
      return <String, String>{
        'bridge_transport_mode': 'auto',
        'bridge_printer_queue': printer.queueName,
      };
    }
    if (printer.backend == DesktopPrinterBackend.usbDirect &&
        (printer.vendorId?.isNotEmpty ?? false) &&
        (printer.productId?.isNotEmpty ?? false)) {
      return <String, String>{
        'bridge_transport_mode': 'usb-direct',
        'bridge_usb_vendor_id': _normalizeUsbHex(printer.vendorId)!,
        'bridge_usb_product_id': _normalizeUsbHex(printer.productId)!,
      };
    }
    return <String, String>{
      'bridge_transport_mode': 'cups',
      'bridge_printer_queue': printer.queueName,
    };
  }

  Future<void> _persistTestResult({
    required String restaurantId,
    required PrinterSetupRole? role,
    required UnifiedPrinterModel printer,
    required PrinterActionResult result,
  }) async {
    if (role == null) return;
    final current =
        await _loadLocalConfig(restaurantId) ??
        PrinterSetupLocalConfig(restaurantId: restaurantId, os: detectOs());
    final record = PrinterTestRecord(
      role: role,
      printerId: printer.id,
      printerRecordId: printer.printerRecordId,
      success: result.ok,
      status: result.status,
      message: result.message,
      testedAt: DateTime.now(),
    );
    final updated = current.copyWith(
      receiptSelection: current.receiptSelection,
      kitchenSelection: current.kitchenSelection,
      receiptTest: role == PrinterSetupRole.adisyon
          ? record
          : current.receiptTest,
      kitchenTest: role == PrinterSetupRole.mutfak
          ? record
          : current.kitchenTest,
    );
    await _saveLocalConfig(updated);
    if (result.ok) {
      await saveWorkingPrinter(
        restaurantId,
        await _attachStoredPrinterRecordId(
          restaurantId: restaurantId,
          printer: printer,
        ),
      );
    }
  }

  Future<void> _recordDbTestResult({
    required String restaurantId,
    required UnifiedPrinterModel printer,
    required PrinterActionResult result,
  }) async {
    try {
      final rows = await _printerRepository.fetchPrinters(restaurantId);
      var matched = _matchExistingPrinter(rows, printer);
      if (matched == null && result.ok) {
        final saved = await _upsertCanonicalPrinterRecord(
          restaurantId: restaurantId,
          existingPrinterId: null,
          printer: printer,
          code: _buildUnassignedPrinterCode(printer),
          assignedRoles: const <PrinterRole>[],
        );
        matched = saved;
      }
      if (matched != null) {
        await _printerRepository.recordTestPrintResult(
          printerId: matched.id,
          success: result.ok,
          error: result.ok ? null : result.message,
        );
      }
    } catch (error) {
      debugPrint(
        '[PrintOrchestrator] db test result skip '
        'restaurantId=$restaurantId printer=${printer.id} error=$error',
      );
    }
  }

  Future<Map<PrinterSetupRole, UnifiedPrinterModel>> _syncPrinterRecords({
    required String restaurantId,
    required Map<PrinterSetupRole, UnifiedPrinterModel> selections,
  }) async {
    final existing = await _printerRepository.fetchPrinters(restaurantId);
    final savedById = <String, PrinterModel>{};
    final resolvedSelections = <PrinterSetupRole, UnifiedPrinterModel>{};
    for (final entry in selections.entries) {
      final printer = entry.value;
      final roles = selections.entries
          .where((item) => item.value.id == printer.id)
          .map(
            (item) => item.key == PrinterSetupRole.adisyon
                ? PrinterRole.receipt
                : PrinterRole.kitchen,
          )
          .toSet();
      final existingPrinter = _matchExistingPrinter(existing, printer);
      final saved = await _upsertCanonicalPrinterRecord(
        restaurantId: restaurantId,
        existingPrinterId: existingPrinter?.id,
        printer: printer,
        code: _buildPrinterCode(printer, roles),
        assignedRoles: roles.toList(growable: false),
      );
      savedById[saved.id] = saved;
      resolvedSelections[entry.key] = printer.copyWith(
        printerRecordId: saved.id,
      );
    }

    for (final printer in existing) {
      final currentRoles = printer.assignedRoles.toSet();
      final unmanagedRoles = currentRoles.difference(_managedRoles);
      final assigned =
          savedById[printer.id]?.assignedRoles.toSet() ?? const <PrinterRole>{};
      final merged = <PrinterRole>{...unmanagedRoles, ...assigned};
      if (!setEquals(currentRoles, merged)) {
        await _printerRepository.updateAssignedRoles(
          printer.id,
          merged.toList(growable: false),
        );
      }
    }
    for (final saved in savedById.values) {
      if (!existing.any((printer) => printer.id == saved.id)) {
        await _printerRepository.updateAssignedRoles(
          saved.id,
          saved.assignedRoles,
        );
      }
    }
    return resolvedSelections;
  }

  PrinterModel? _matchExistingPrinter(
    List<PrinterModel> existing,
    UnifiedPrinterModel printer,
  ) {
    final normalizedId = printer.id.trim().toLowerCase();
    final normalizedQueue = printer.queueName.trim().toLowerCase();
    final normalizedName = printer.displayName.trim().toLowerCase();
    final normalizedDeviceIdentifier = _persistedDeviceIdentifier(
      printer,
    ).trim().toLowerCase();
    for (final entry in existing) {
      final device = (entry.deviceIdentifier ?? '').trim().toLowerCase();
      final name = entry.name.trim().toLowerCase();
      if (device.isNotEmpty &&
          normalizedDeviceIdentifier.isNotEmpty &&
          device == normalizedDeviceIdentifier) {
        return entry;
      }
      if (device.isNotEmpty && device == normalizedQueue) {
        return entry;
      }
      if (name.isNotEmpty && name == normalizedName) {
        return entry;
      }
      if (_isPos58UsbPrinter(printer) &&
          (_looksLikePos58Alias(device) || _looksLikePos58Alias(name))) {
        return entry;
      }
      if (entry.code.trim().toLowerCase() == _slugify(normalizedId)) {
        return entry;
      }
    }
    return null;
  }

  String _testRequestedEvent(PrinterSetupRole? role) {
    return role == PrinterSetupRole.mutfak
        ? 'mutfak_test_requested'
        : 'adisyon_test_requested';
  }

  String _resolvedPrinterEvent(PrinterSetupRole? role) {
    return role == PrinterSetupRole.mutfak
        ? 'resolved_mutfak_printer'
        : 'resolved_adisyon_printer';
  }

  void _logRoleTestEvent({
    required String restaurantId,
    required PrinterSetupRole? role,
    required String event,
    required String message,
    String level = 'info',
    UnifiedPrinterModel? printer,
    Map<String, dynamic>? details,
  }) {
    _eventLogService
        .append(
          restaurantId: restaurantId,
          event: event,
          message: message,
          level: level,
          role: role?.value ?? 'adisyon',
          printerId: printer?.printerRecordId ?? printer?.id,
          queueName: printer?.queueName,
          backend: printer?.backend.value,
          details: details,
        )
        .ignore();
  }

  String _buildPrinterCode(
    UnifiedPrinterModel printer,
    Set<PrinterRole> roles,
  ) {
    final prefix =
        roles.contains(PrinterRole.receipt) &&
            roles.contains(PrinterRole.kitchen)
        ? 'ADISYON_MUTFAK'
        : roles.contains(PrinterRole.receipt)
        ? 'ADISYON'
        : 'MUTFAK';
    return '${prefix}_${_slugify(printer.queueName)}';
  }

  String _buildUnassignedPrinterCode(UnifiedPrinterModel printer) {
    final slug = _slugify(printer.queueName);
    return slug.isEmpty ? 'GENEL' : 'GENEL_$slug';
  }

  String _slugify(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit).toLowerCase();
      final isAlphaNum =
          (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122);
      if (isAlphaNum) {
        buffer.write(char);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('_')) {
        buffer.write('_');
      }
    }
    final raw = buffer.toString().replaceAll(RegExp('_+'), '_');
    return raw.replaceAll(RegExp(r'^_|_$'), '');
  }

  String _friendlyBridgeFailure(Object error) {
    if (error is LocalPrintServiceException &&
        error.details is Map<String, dynamic>) {
      return _friendlyTestFailure(error.details! as Map<String, dynamic>);
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('print_system_disabled') ||
        raw.contains('baskı sistemi şu anda kapalı') ||
        raw.contains('baski sistemi su anda kapali') ||
        raw.contains('baskı sistemi kapalı')) {
      return 'Baskı sistemi kapalı. Test göndermek için sistemi açın.';
    }
    if (raw.contains('cups işi kabul etti ama fiziksel baskı doğrulanamadı')) {
      return 'CUPS işi kabul etti ama fiziksel baskı doğrulanamadı. Yazıcı kuyruğunu ve macOS yazıcı durumunu kontrol edin.';
    }
    if (raw.contains('seçilen yazıcı backend') ||
        raw.contains('selected printer backend')) {
      final original = error.toString().replaceFirst('Exception: ', '').trim();
      return original.isEmpty ? 'Test basarisiz' : original;
    }
    if (_isUsbClaimFailure(error)) {
      return 'Bu yazıcı macOS tarafından tutuluyor. Adisyon için CUPS yolunu kullanmanız önerilir.';
    }
    if (raw.contains('connection refused') ||
        raw.contains('connection_error')) {
      return 'Bridge calismiyor';
    }
    if (raw.contains('timeout') || raw.contains('client_timeout')) {
      if (error is LocalPrintServiceException &&
          error.details is Map<String, dynamic>) {
        final details = WindowsPrinterClassification.formatTestFailureDetails(
          error.details! as Map<String, dynamic>,
        );
        if (details.isNotEmpty) {
          return 'Yazıcı servisi yanıt vermedi.\n$details';
        }
      }
      return 'Yazıcı servisi yanıt vermedi. Bridge çalışıyor mu kontrol edin.';
    }
    if (raw.contains('cups')) {
      return 'CUPS kullanilamiyor';
    }
    if (raw.contains('lpstat') || raw.contains('lp ')) {
      return 'Yazici bulunamadi';
    }
    return 'Test basarisiz';
  }

  String _friendlyTestFailure(Map<String, dynamic>? response) {
    final errorCode = response?['errorCode']?.toString().trim() ?? '';
    final message = response?['message']?.toString().trim() ?? '';
    final error = response?['error']?.toString().trim() ?? '';
    final queueStatus = response?['queue_status']?.toString().trim() ?? '';
    final queueMsg = response?['queue_message']?.toString().trim() ?? '';
    final activeJobId = response?['active_job_id']?.toString().trim() ?? '';
    final activeJobIdsRaw = response?['active_job_ids'];
    final activeJobIds = activeJobIdsRaw is List
        ? activeJobIdsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    final combined = '$message $error'.trim().toLowerCase();

    if (errorCode == 'client_timeout') {
      final details = WindowsPrinterClassification.formatTestFailureDetails(
        response,
      );
      return details.isNotEmpty
          ? 'Yazıcı servisi yanıt vermedi.\n$details'
          : 'Yazıcı servisi yanıt vermedi. Bridge çalışıyor mu kontrol edin.';
    }
    if (errorCode == 'print_system_disabled') {
      return 'Baskı sistemi şu anda kapalı. Yazıcı Ayarları > Baskı Sistemi > Aç butonunu kullanın.';
    }
    if (errorCode == 'duplicate_test_suppressed') {
      return 'Aynı test kısa süre önce gönderildi. Lütfen birkaç saniye bekleyin.';
    }
    if (errorCode == 'usb_interface_claim_denied') {
      final operatorMessage =
          response?['operator_message']?.toString().trim() ?? '';
      if (operatorMessage.isNotEmpty) {
        return operatorMessage;
      }
      return 'Bu yazıcı macOS tarafından tutuluyor. Adisyon için CUPS yolunu kullanmanız önerilir.';
    }
    if (errorCode.startsWith('tcp_')) {
      if (message.isNotEmpty) return message;
      if (error.isNotEmpty) return error;
      return 'Ethernet yazıcıya bağlantı kurulamadı.';
    }
    if (errorCode == 'cups_queue_busy') {
      final jobs = activeJobIds.isNotEmpty
          ? activeJobIds.join(', ')
          : activeJobId;
      return jobs.trim().isNotEmpty
          ? 'Yazıcı kuyruğunda bekleyen/takılan işler var. Kuyruğu temizleyin.\nBekleyen işler: $jobs'
          : 'Yazıcı kuyruğunda bekleyen/takılan işler var. Kuyruğu temizleyin.';
    }
    if (errorCode == 'cups_queue_stuck') {
      final waitingHint =
          queueMsg.toLowerCase().contains(
            'waiting for printer to become available',
          ) ||
          queueMsg.toLowerCase().contains(
            'yazıcının kullanılabilir olması bekleniyor',
          ) ||
          combined.contains('waiting for printer to become available') ||
          combined.contains('yazıcının kullanılabilir olması bekleniyor');
      final jobs = activeJobIds.isNotEmpty
          ? activeJobIds.join(', ')
          : activeJobId;
      if (waitingHint) {
        final base =
            'CUPS yazıcı işi kabul etti ama yazıcıya aktaramıyor. USB kablo, kağıt, kapak ve CUPS sürücü/raw ayarını kontrol edin.';
        return jobs.trim().isNotEmpty ? '$base\nBekleyen işler: $jobs' : base;
      }
      return jobs.trim().isNotEmpty
          ? 'Yazıcı kuyruğunda bekleyen/takılan işler var. Kuyruğu temizleyin.\nBekleyen işler: $jobs'
          : 'Yazıcı kuyruğunda bekleyen/takılan işler var. Kuyruğu temizleyin.';
    }
    if (combined.contains('fiziksel baskı doğrulanamadı')) {
      return 'CUPS işi kabul etti ama fiziksel baskı doğrulanamadı. Yazıcı kuyruğunu ve macOS yazıcı durumunu kontrol edin.';
    }
    if (combined.contains('offline')) return 'Yazici cevrimdisi';
    if (combined.contains('not found')) return 'Yazici bulunamadi';
    if (combined.contains('driver')) return 'Yazici surucusu eksik';
    if (combined.contains('bridge')) return 'Bridge calismiyor';
    final windowsDetails =
        WindowsPrinterClassification.formatTestFailureDetails(response);
    if (windowsDetails.isNotEmpty) {
      if (message.isNotEmpty) return '$message\n$windowsDetails';
      if (error.isNotEmpty) return '$error\n$windowsDetails';
      return windowsDetails;
    }
    if (message.isNotEmpty) return message;
    if (error.isNotEmpty) return error;
    final code = errorCode.isNotEmpty ? errorCode : 'unknown';
    final extra = [
      if (queueStatus.isNotEmpty) 'queue_status=$queueStatus',
      if (activeJobId.isNotEmpty) 'active_job_id=$activeJobId',
      if (queueMsg.isNotEmpty) 'queue_message=$queueMsg',
    ].join(' ');
    return extra.isEmpty
        ? 'Test basarisiz (errorCode=$code)'
        : 'Test basarisiz (errorCode=$code $extra)';
  }

  bool _isPrintSystemEnabledFromSnapshot(PrinterSetupSnapshot snapshot) {
    final queueStatus = snapshot.queueStatus;
    final queuePayload = queueStatus?['queue'];
    final queueMap = queuePayload is Map<String, dynamic>
        ? queuePayload
        : (queuePayload is Map
              ? Map<String, dynamic>.from(queuePayload)
              : null);
    final localRuntime =
        queueMap?['print_system_enabled'] ??
        queueMap?['printSystemEnabled'] ??
        queueMap?['print_system'] ??
        queueMap?['enabled'];
    if (localRuntime is bool) return localRuntime;
    final remote = snapshot.remoteConfig;
    final remoteEnabled =
        remote?['print_system_enabled'] ?? remote?['printSystemEnabled'];
    if (remoteEnabled is bool) return remoteEnabled;
    return true;
  }

  PrinterActionResult _printSystemDisabledResult() {
    return const PrinterActionResult(
      ok: false,
      status: 'print_system_disabled',
      message:
          'Baskı sistemi kapalı. Yazdırmak için Yazıcı Merkezi’nden sistemi açın.',
      raw: <String, dynamic>{
        'ok': false,
        'errorCode': 'print_system_disabled',
        'error':
            'Baskı sistemi kapalı. Sipariş kaydedilir ancak fiş yazdırılmaz.',
        'print_system_enabled': false,
      },
    );
  }

  String _friendlyPhysicalPrintFailure(
    Map<String, dynamic>? response, {
    required String documentType,
  }) {
    final error = response?['error']?.toString().trim() ?? '';
    final message = response?['message']?.toString().trim() ?? '';
    if (error.isNotEmpty) return error;
    if (message.isNotEmpty) return message;
    return documentType == 'receipt'
        ? 'Adisyon yazdirilamadi'
        : 'Mutfak yazdirilamadi';
  }

  String _friendlyPhysicalPrintException(
    UnifiedPrinterModel printer,
    Object error, {
    bool releaseAttempted = false,
  }) {
    if (error is LocalPrintServiceException &&
        error.details is Map<String, dynamic>) {
      final details = error.details! as Map<String, dynamic>;
      final errorCode = details['errorCode']?.toString().trim() ?? '';
      if (errorCode == 'cups_queue_busy' || errorCode == 'cups_queue_stuck') {
        final ids = details['active_job_ids'];
        final jobList = ids is List ? ids.join(', ') : '';
        final queue =
            details['printer_queue']?.toString() ??
            details['queue']?.toString() ??
            printer.queueName;
        return jobList.isNotEmpty
            ? 'Yazıcı kuyruğunda bekleyen işler var ($queue): $jobList. Önce kuyruğu temizleyin.'
            : 'Yazıcı kuyruğunda bekleyen işler var ($queue). Önce kuyruğu temizleyin.';
      }
    }
    if (printer.backend == DesktopPrinterBackend.usbDirect &&
        _isUsbClaimFailure(error)) {
      return releaseAttempted
          ? 'Bu yazıcı macOS tarafından tutuluyor. CUPS yeniden başlatıldı ama fiziksel çıktı alınamadı.'
          : 'Bu yazıcı macOS tarafından tutuluyor. Adisyon için CUPS yolunu kullanmanız önerilir.';
    }
    return _friendlyBridgeFailure(error);
  }

  void _log(String action, String message) {
    debugPrint('[PrintOrchestrator][$action] $message');
  }

  UnifiedPrinterModel? _extractEmbeddedPayloadPrinter(
    Map<String, dynamic> payload, {
    required DesktopPrinterOs os,
  }) {
    final rawPrinter = payload['printer'];
    if (rawPrinter is Map) {
      final map = Map<String, dynamic>.from(rawPrinter);
      if ((map['queueName'] ?? map['queue']) != null) {
        final normalized = <String, dynamic>{
          'id': map['id'],
          'displayName': map['displayName'] ?? map['name'],
          'queueName': map['queueName'] ?? map['queue'] ?? map['name'],
          'backend': map['backend'],
          'os': map['os'] ?? os.value,
          'isAvailable': true,
          'canPrint': true,
          'vendorId': map['vendorId'],
          'productId': map['productId'],
          'raw': map,
        };
        return UnifiedPrinterModel.fromJson(normalized);
      }
      return UnifiedPrinterModel.fromBridgeMap(map, os: os);
    }
    return null;
  }

  UnifiedPrinterModel? _printerFromDirectBridgeTestResponse(
    Map<String, dynamic>? response, {
    required DesktopPrinterOs os,
  }) {
    if (response == null) return null;
    final printerId = _readText(response['printer_id']);
    final printerName = _readText(
      response['printer_name'] ??
          response['printer_queue'] ??
          response['queue'],
    );
    if (printerId.isEmpty && printerName.isEmpty) {
      return null;
    }
    final backend = DesktopPrinterBackend.fromValue(
      response['backend']?.toString() ?? response['transport']?.toString(),
    );
    final queueName = printerName.isNotEmpty ? printerName : printerId;
    return UnifiedPrinterModel(
      id: printerId.isNotEmpty ? printerId : '${backend.value}:$queueName',
      displayName: printerName.isNotEmpty ? printerName : queueName,
      queueName: queueName,
      backend: backend,
      os: os,
      isAvailable: true,
      canPrint: true,
      raw: <String, dynamic>{
        'id': printerId,
        'name': printerName,
        'queue': queueName,
        'backend': backend.value,
      },
    );
  }

  PrinterSetupRole? _inferQueuedPrinterRole(
    Map<String, dynamic> jobRecord,
    Map<String, dynamic> payload,
  ) {
    final explicit = _readText(
      jobRecord['printer_role'] ?? payload['printer_role'],
    ).toLowerCase();
    if (explicit == 'adisyon' || explicit == 'receipt') {
      return PrinterSetupRole.adisyon;
    }
    if (explicit == 'mutfak' || explicit == 'kitchen') {
      return PrinterSetupRole.mutfak;
    }
    final documentType = _readText(
      jobRecord['document_type'] ?? payload['document_type'],
    ).toLowerCase();
    final jobType = _readText(
      jobRecord['job_type'] ?? payload['job_type'],
    ).toLowerCase();
    if (documentType == 'receipt' || jobType == 'receipt') {
      return PrinterSetupRole.adisyon;
    }
    return PrinterSetupRole.mutfak;
  }

  String _readText(Object? value) => value?.toString().trim() ?? '';

  UnifiedPrinterModel? _resolvePrinterByQueueOrName({
    required List<UnifiedPrinterModel> printers,
    required String queueName,
    required String displayName,
  }) {
    final normalizedQueue = queueName.trim().toLowerCase();
    final normalizedName = displayName.trim().toLowerCase();
    final candidates = printers
        .where((printer) {
          final queue = printer.queueName.trim().toLowerCase();
          final name = printer.displayName.trim().toLowerCase();
          final id = printer.id.trim().toLowerCase();
          return (normalizedQueue.isNotEmpty &&
                  (queue == normalizedQueue ||
                      name == normalizedQueue ||
                      id == normalizedQueue)) ||
              (normalizedName.isNotEmpty &&
                  (name == normalizedName || queue == normalizedName));
        })
        .toList(growable: false);
    if (candidates.isNotEmpty) {
      return _normalizePrinterForPhysicalDispatch(
        _sortPrinters(candidates, os: candidates.first.os).first,
      );
    }
    final preferredUsb = _preferUsbDirectCandidate(
      printers: printers,
      queueName: queueName,
      displayName: displayName,
    );
    if (preferredUsb != null) {
      return _normalizePrinterForPhysicalDispatch(preferredUsb);
    }
    return null;
  }

  UnifiedPrinterModel? _resolveUnifiedPrinterFromLegacy(
    PrinterModel legacyPrinter, {
    required List<UnifiedPrinterModel> printers,
    required DesktopPrinterOs os,
  }) {
    // Ethernet / raw TCP printers are not discovered by the bridge (network
    // printers are entered manually). Synthesize a UnifiedPrinterModel
    // directly from the saved row so the bridge sees a tcp backend with
    // host/port instead of falling back to CUPS/USB.
    if (legacyPrinter.isEthernetConnection) {
      return _buildEthernetUnifiedPrinter(legacyPrinter, os: os);
    }
    final matched = _resolvePrinterByQueueOrName(
      printers: printers,
      queueName: legacyPrinter.deviceIdentifier?.trim() ?? '',
      displayName: legacyPrinter.name,
    );
    if (matched != null) {
      return _normalizePrinterForPhysicalDispatch(
        matched.copyWith(printerRecordId: legacyPrinter.id),
      );
    }
    final preferredUsb = _preferUsbDirectCandidate(
      printers: printers,
      queueName: legacyPrinter.deviceIdentifier?.trim() ?? '',
      displayName: legacyPrinter.name,
    );
    if (preferredUsb != null) {
      return _normalizePrinterForPhysicalDispatch(
        preferredUsb.copyWith(printerRecordId: legacyPrinter.id),
      );
    }
    return null;
  }

  UnifiedPrinterModel _buildEthernetUnifiedPrinter(
    PrinterModel legacyPrinter, {
    required DesktopPrinterOs os,
  }) {
    final host = legacyPrinter.ethernetHost;
    final port = legacyPrinter.ethernetPort;
    final id = PrinterModel.ethernetPrinterId(host: host, port: port);
    final raw = <String, dynamic>{
      'id': id,
      'name': legacyPrinter.name,
      'backend': PrinterModel.ethernetBridgeBackend,
      'transportType': PrinterModel.ethernetBridgeTransport,
      'transport_type': PrinterModel.ethernetBridgeTransport,
      'connectionType': PrinterModel.networkConnectionType,
      'connection_type': PrinterModel.networkConnectionType,
      'host': host,
      'ip_address': host,
      'ipAddress': host,
      'port': port,
      'paper_width_mm': legacyPrinter.paperWidthMm,
      'paperWidthMm': legacyPrinter.paperWidthMm,
      'auto_cut': legacyPrinter.supportsCut,
      'autoCut': legacyPrinter.supportsCut,
      'deviceIdentifier': legacyPrinter.deviceIdentifier ?? id,
      'device_identifier': legacyPrinter.deviceIdentifier ?? id,
      'source': 'ethernet_saved_record',
    };
    return UnifiedPrinterModel(
      id: id,
      displayName: legacyPrinter.name,
      queueName: legacyPrinter.name,
      backend: DesktopPrinterBackend.tcp,
      os: os,
      isAvailable: true,
      canPrint: true,
      vendorId: null,
      productId: null,
      printerRecordId: legacyPrinter.id,
      statusLevel: 'ready',
      statusMessage: 'Ethernet yazıcı hazır.',
      raw: raw,
    );
  }

  bool _printerIdLooksLikeTcp(String value) =>
      value.trim().toLowerCase().startsWith('tcp:');

  void _synthesizeTcpPayloadMetadata(Map<String, dynamic> payload) {
    final printerId = _readText(payload['printer_id']);
    final explicitHost = _readText(
      payload['host'] ??
          payload['ip_address'] ??
          payload['ipAddress'] ??
          payload['target_host'],
    );
    final explicitPortRaw = payload['port'] ?? payload['target_port'];
    final explicitPort = explicitPortRaw is int
        ? explicitPortRaw
        : int.tryParse(explicitPortRaw?.toString() ?? '');
    if (!_printerIdLooksLikeTcp(printerId) &&
        (explicitHost.isEmpty || (explicitPort ?? 0) <= 0)) {
      return;
    }

    var host = explicitHost;
    var port = explicitPort ?? 0;
    var normalizedPrinterId = printerId;
    if (_printerIdLooksLikeTcp(printerId)) {
      final parts = printerId.split(':');
      if (parts.length >= 3) {
        host = host.isNotEmpty ? host : parts[1].trim();
        port = port > 0 ? port : (int.tryParse(parts[2].trim()) ?? 0);
      }
    }
    if (host.isEmpty || port <= 0) {
      return;
    }
    if (!_printerIdLooksLikeTcp(normalizedPrinterId)) {
      normalizedPrinterId = PrinterModel.ethernetPrinterId(
        host: host,
        port: port,
      );
    }
    payload['printer_id'] = normalizedPrinterId;
    payload['printer_backend'] = DesktopPrinterBackend.tcp.value;
    payload['backend'] = DesktopPrinterBackend.tcp.value;
    payload['transportType'] = PrinterModel.ethernetBridgeTransport;
    payload['transport_type'] = PrinterModel.ethernetBridgeTransport;
    payload['host'] = host;
    payload['ip_address'] = host;
    payload['ipAddress'] = host;
    payload['port'] = port;
    payload['paper_width_mm'] = payload['paper_width_mm'] ?? 80;
    payload['auto_cut'] = payload['auto_cut'] ?? true;
  }

  UnifiedPrinterModel? _explicitTcpPayloadPrinter(
    Map<String, dynamic> payload, {
    required DesktopPrinterOs os,
  }) {
    final normalized = Map<String, dynamic>.from(payload);
    _synthesizeTcpPayloadMetadata(normalized);
    if (!_printerIdLooksLikeTcp(_readText(normalized['printer_id'])) &&
        _readText(normalized['backend']) != DesktopPrinterBackend.tcp.value &&
        _readText(normalized['printer_backend']) !=
            DesktopPrinterBackend.tcp.value) {
      final embedded = normalized['printer'];
      if (embedded is! Map) {
        return null;
      }
    }

    final embedded = normalized['printer'];
    if (embedded is Map) {
      final printerMap = Map<String, dynamic>.from(embedded);
      _synthesizeTcpPayloadMetadata(printerMap);
      final fromEmbedded = _extractEmbeddedPayloadPrinter(printerMap, os: os);
      if (fromEmbedded != null &&
          fromEmbedded.backend == DesktopPrinterBackend.tcp) {
        return fromEmbedded;
      }
    }

    final host = _readText(
      normalized['host'] ??
          normalized['ip_address'] ??
          normalized['ipAddress'] ??
          normalized['target_host'],
    );
    final portRaw = normalized['port'] ?? normalized['target_port'];
    final port = portRaw is int
        ? portRaw
        : int.tryParse(portRaw?.toString() ?? '');
    final printerId = _readText(normalized['printer_id']);
    if (host.isEmpty || (port ?? 0) <= 0) {
      return null;
    }
    final id = _printerIdLooksLikeTcp(printerId)
        ? printerId
        : PrinterModel.ethernetPrinterId(host: host, port: port!);
    return UnifiedPrinterModel(
      id: id,
      displayName: _readText(
        normalized['printer_name'] ??
            normalized['printer_queue'] ??
            normalized['station_name'] ??
            'Mutfak Ethernet',
      ),
      queueName: _readText(
        normalized['printer_queue'] ??
            normalized['printer_name'] ??
            normalized['station_name'] ??
            'Mutfak Ethernet',
      ),
      backend: DesktopPrinterBackend.tcp,
      os: os,
      isAvailable: true,
      canPrint: true,
      printerRecordId: _readText(normalized['printer_record_id']).isEmpty
          ? null
          : _readText(normalized['printer_record_id']),
      raw: <String, dynamic>{
        'id': id,
        'name': _readText(
          normalized['printer_name'] ??
              normalized['printer_queue'] ??
              normalized['station_name'] ??
              'Mutfak Ethernet',
        ),
        'backend': DesktopPrinterBackend.tcp.value,
        'transportType': PrinterModel.ethernetBridgeTransport,
        'transport_type': PrinterModel.ethernetBridgeTransport,
        'connectionType': PrinterModel.networkConnectionType,
        'connection_type': PrinterModel.networkConnectionType,
        'host': host,
        'ip_address': host,
        'ipAddress': host,
        'port': port,
        'paper_width_mm': normalized['paper_width_mm'] ?? 80,
        'auto_cut': normalized['auto_cut'] ?? true,
        if (_readText(normalized['printer_record_id']).isNotEmpty)
          'printer_record_id': _readText(normalized['printer_record_id']),
        'source': 'queued_payload_tcp',
      },
    );
  }

  Map<String, dynamic> _injectResolvedPrinterIntoPayload(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel? printer,
    required PrinterSetupRole? printerRole,
    required Map<String, dynamic> jobRecord,
  }) {
    final nextPayload = Map<String, dynamic>.from(payload);
    _synthesizeTcpPayloadMetadata(nextPayload);
    if (printerRole != null) {
      nextPayload['printer_role'] = printerRole.value;
    }
    if (_readText(nextPayload['document_type']).isEmpty) {
      nextPayload['document_type'] = printerRole == PrinterSetupRole.adisyon
          ? 'receipt'
          : 'kitchen';
    }
    if (_readText(nextPayload['job_type']).isEmpty) {
      nextPayload['job_type'] = _readText(jobRecord['job_type']).isNotEmpty
          ? _readText(jobRecord['job_type'])
          : (printerRole == PrinterSetupRole.adisyon ? 'receipt' : 'kitchen');
    }
    if (printer == null) {
      return nextPayload;
    }
    _clearNonTcpPrinterKeys(nextPayload);
    nextPayload['printer'] = _bridgePrinterPayload(printer);
    nextPayload['printer_id'] = printer.id;
    if (printer.printerRecordId?.isNotEmpty ?? false) {
      nextPayload['printer_record_id'] = printer.printerRecordId;
    }
    nextPayload['printer_name'] =
        printer.backend == DesktopPrinterBackend.windowsSpool
        ? printer.queueName
        : printer.displayName;
    nextPayload['printer_backend'] = printer.backend.value;
    nextPayload['backend'] = printer.backend.value;
    nextPayload['transportType'] = _transportTypeForPrinter(printer);
    nextPayload['transport_type'] = _transportTypeForPrinter(printer);
    if (printer.backend == DesktopPrinterBackend.usbDirect) {
      nextPayload['printer_device_identifier'] = _persistedDeviceIdentifier(
        printer,
      );
      nextPayload.remove('printer_queue');
    } else if (printer.backend != DesktopPrinterBackend.tcp) {
      nextPayload['printer_device_identifier'] = _persistedDeviceIdentifier(
        printer,
      );
      nextPayload['printer_queue'] = printer.queueName;
    }
    if (printer.vendorId?.isNotEmpty ?? false) {
      nextPayload['vendorId'] = _normalizeUsbHex(printer.vendorId);
    }
    if (printer.productId?.isNotEmpty ?? false) {
      nextPayload['productId'] = _normalizeUsbHex(printer.productId);
    }
    if (printer.backend == DesktopPrinterBackend.tcp) {
      _stampTcpDispatchTarget(nextPayload, printer);
    }
    _applyPrinterProfileMetadata(
      nextPayload,
      printer: printer,
      documentType: _readText(nextPayload['document_type']),
      role: printerRole?.value ?? _readText(nextPayload['printer_role']),
    );
    return nextPayload;
  }

  String _encodingProfileCacheKey(String restaurantId, String printerId) =>
      '${restaurantId.trim()}::${printerId.trim()}';

  Future<PrinterEncodingProfile?> loadEncodingProfile({
    required String restaurantId,
    required String printerId,
  }) async {
    final key = _encodingProfileCacheKey(restaurantId, printerId);
    final cached = _encodingProfileMemoryCache[key];
    if (cached != null) return cached;
    final loaded = await _encodingProfileStore.load(
      restaurantId: restaurantId,
      printerId: printerId,
    );
    if (loaded != null) {
      _encodingProfileMemoryCache[key] = loaded;
    }
    return loaded;
  }

  Future<PrinterEncodingSelection> resolveEncodingSelection({
    required String restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    final profile = await loadEncodingProfile(
      restaurantId: restaurantId,
      printerId: printer.id,
    );
    if (profile != null) {
      return profile.toSelection();
    }
    final recordId = printer.printerRecordId?.trim() ?? '';
    if (recordId.isNotEmpty) {
      final row = await _printerRepository.getPrinterByRecordId(recordId);
      if (row != null) {
        return row.encodingSelection;
      }
    }
    return PrinterEncodingSelection.normalize(
      charset: PrinterCharset.cp857,
      codePage: PrinterEncodingSelection.defaultTurkishCodePage,
    );
  }

  Future<void> applyEncodingProfileToPayload(
    Map<String, dynamic> payload, {
    required String restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    final profile = await loadEncodingProfile(
      restaurantId: restaurantId,
      printerId: printer.id,
    );
    if (profile != null) {
      payload['printer_encoding'] = profile.encoding;
      payload['encoding'] = profile.encoding;
      payload['printer_code_page'] = profile.codePage;
      payload['codepage'] = profile.codePage;
      payload['code_page'] = profile.codePage;
      payload['esc_t_value'] = profile.codePage;
      payload['codepage_command'] = profile.effectiveCodepageCommand;
      if (profile.escRValue != null) {
        payload['esc_r_value'] = profile.escRValue;
        payload['printer_esc_r'] = profile.escRValue;
      }
      payload['encoding_profile_verified'] = true;
      payload['encoding_profile_missing'] = false;
      payload['encoding_profile_candidate_id'] = profile.candidateId;
      payload['turkish_print_mode'] = profile.printMode;
      if (profile.isGuaranteeMode) {
        payload['render_mode'] = 'image';
        payload['turkish_guarantee_mode'] = true;
        payload['use_bundled_font_only'] = true;
      }
      if (profile.codepageLabel != null && profile.codepageLabel!.isNotEmpty) {
        payload['codepage_label'] = profile.codepageLabel;
      }
      return;
    }

    final selection = await resolveEncodingSelection(
      restaurantId: restaurantId,
      printer: printer,
    );
    payload['printer_encoding'] = selection.encoding;
    payload['encoding'] = selection.encoding;
    payload['printer_code_page'] = selection.codePage;
    payload['codepage'] = selection.codePage;
    payload['code_page'] = selection.codePage;
    payload['esc_t_value'] = selection.codePage;
    payload['codepage_command'] = 'ESC t ${selection.codePage}';
    payload['encoding_profile_verified'] = false;
    payload['encoding_profile_missing'] = true;
    payload['turkish_print_mode'] = kTurkishPrintModeText;
    if (selection.warning != null && selection.warning!.isNotEmpty) {
      payload['encoding_warning'] = selection.warning;
    }
  }

  void stampDispatchProfileOnPayload(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel printer,
    required String documentType,
    required String role,
  }) {
    _applyPrinterProfileMetadata(
      payload,
      printer: printer,
      documentType: documentType,
      role: role,
    );
    _applyRecommendedRenderMetadata(
      payload,
      printer: printer,
      documentType: documentType,
      role: role,
    );
  }

  Future<PrinterModel> _upsertCanonicalPrinterRecord({
    required String restaurantId,
    required String? existingPrinterId,
    required UnifiedPrinterModel printer,
    required String code,
    required List<PrinterRole> assignedRoles,
  }) {
    final isTcpPrinter = printer.backend == DesktopPrinterBackend.tcp;
    final host = _printerHost(printer);
    final port = _printerPort(printer);
    return _printerRepository.upsertPrinter(
      restaurantId: restaurantId,
      printerId: existingPrinterId,
      name: printer.displayName,
      code: code,
      connectionType: isTcpPrinter
          ? PrinterModel.networkConnectionType
          : PrinterModel.usbConnectionType,
      ipAddress: isTcpPrinter ? host : PrinterModel.localDefaultHost,
      port: isTcpPrinter ? port : PrinterModel.localDefaultPort,
      deviceIdentifier: _persistedDeviceIdentifier(printer),
      paperWidthMm: printer.displayName.toLowerCase().contains('58') ? 58 : 80,
      isActive: true,
      supportsCut: isTcpPrinter
          ? true
          : !printer.displayName.toLowerCase().contains('58'),
      assignedRoles: assignedRoles,
    );
  }

  Future<PrinterActionResult> saveTurkishPrintMode({
    required String restaurantId,
    required UnifiedPrinterModel printer,
    required String printMode,
  }) async {
    final existing = await loadEncodingProfile(
      restaurantId: restaurantId,
      printerId: printer.id,
    );
    final profile = PrinterEncodingProfile(
      printerId: printer.id,
      encoding: existing?.encoding ?? 'cp857',
      codePage: existing?.codePage ?? 13,
      verifiedAt: DateTime.now(),
      candidateId:
          existing?.candidateId ??
          (printMode == kTurkishPrintModeGuarantee
              ? 'turkish_guarantee'
              : null),
      printerName: _printStationPrinterLabel(printer),
      codepageCommand: existing?.codepageCommand ?? 'ESC t 13',
      escRValue: existing?.escRValue,
      printMode: printMode,
      codepageLabel: printMode == kTurkishPrintModeGuarantee
          ? 'Türkçe Garanti Modu'
          : existing?.codepageLabel,
    );
    await _encodingProfileStore.save(
      restaurantId: restaurantId,
      profile: profile,
    );
    _encodingProfileMemoryCache[_encodingProfileCacheKey(
          restaurantId,
          printer.id,
        )] =
        profile;
    return PrinterActionResult(
      ok: true,
      status: 'ready',
      message: printMode == kTurkishPrintModeGuarantee
          ? 'Türkçe Garanti Modu kaydedildi. Fişler görsel/raster olarak basılacak.'
          : 'Hızlı Mod kaydedildi. Fişler text/RAW olarak basılacak.',
      printer: printer,
    );
  }

  /// Sample receipt for Turkish Guarantee Mode (bundled mono font raster).
  Future<PrinterActionResult> printTurkishGuaranteeSample({
    required String restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    await saveTurkishPrintMode(
      restaurantId: restaurantId,
      printer: printer,
      printMode: kTurkishPrintModeGuarantee,
    );
    final body = <String, dynamic>{
      'store_name': 'IBUL Test',
      'table_no': '1',
      'display_table_label': 'Test Masa',
      'receipt_printed_at': DateTime.now().toIso8601String(),
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Çiğ Köfte',
          'qty': 1,
          'price': '120',
          'total': '120',
          'note': 'az pişmiş, soğansız',
        },
        <String, dynamic>{
          'name': 'Ciğer Şiş',
          'qty': 2,
          'price': '180',
          'total': '360',
        },
        <String, dynamic>{
          'name': 'Kuşbaşı',
          'qty': 1,
          'price': '200',
          'total': '200',
        },
        <String, dynamic>{
          'name': 'Kıyma Dürüm',
          'qty': 1,
          'price': '95',
          'total': '95',
        },
      ],
      'currency': 'TRY',
      'grand_total': '775',
      'subtotal': '775',
    };
    return printPhysicalToPrinter(
      printer,
      PrintPayload.receipt(body),
      restaurantId: restaurantId,
      flowName: 'turkish_guarantee_test',
      flowType: 'adisyon_test',
      source: 'turkish_guarantee_test',
    );
  }

  Future<bool> isLocalBridgeReachable({bool useCache = true}) async {
    if (useCache &&
        _bridgeReachableCachedAt != null &&
        DateTime.now().difference(_bridgeReachableCachedAt!) <=
            _bridgeReachableCacheTtl) {
      return _bridgeReachableCachedValue;
    }
    final service = _service();
    try {
      final health = await service.health(useCache: useCache);
      final ok = health?['ok'] == true;
      _bridgeReachableCachedAt = DateTime.now();
      _bridgeReachableCachedValue = ok;
      return ok;
    } catch (_) {
      _bridgeReachableCachedAt = DateTime.now();
      _bridgeReachableCachedValue = false;
      return false;
    }
  }

  static const Set<String> _fastPhysicalPrintFlows = <String>{
    'kitchen_order',
    'kitchen_ticket',
    'kitchen_test',
    'adisyon_test',
    'receipt_test',
    'waiter_receipt',
    'new_order',
    'add_item',
    'cancel_item',
    'reprint',
    'setup_test',
  };

  bool _isFastPhysicalPrintFlow(String? flowType, String flowName) {
    final normalized = (flowType ?? flowName).trim().toLowerCase();
    return _fastPhysicalPrintFlows.contains(normalized);
  }

  Future<bool> isTurkishEncodingVerified({
    required String restaurantId,
    required String printerId,
  }) async {
    final profile = await loadEncodingProfile(
      restaurantId: restaurantId,
      printerId: printerId,
    );
    return profile != null;
  }

  Future<PrinterActionResult> saveEncodingProfileFromCandidate({
    required String restaurantId,
    required UnifiedPrinterModel printer,
    required TurkishEncodingCandidate candidate,
    String? printModeOverride,
  }) async {
    final effectivePrintMode = printModeOverride ?? candidate.printMode;
    await _encodingProfileStore.saveFromCandidate(
      restaurantId: restaurantId,
      printerId: printer.id,
      candidate: TurkishEncodingCandidate(
        id: candidate.id,
        label: candidate.label,
        encoding: candidate.encoding,
        codePage: candidate.codePage,
        escRValue: candidate.escRValue,
        printMode: effectivePrintMode,
      ),
      printerName: _printStationPrinterLabel(printer),
    );
    _encodingProfileMemoryCache[_encodingProfileCacheKey(
      restaurantId,
      printer.id,
    )] = PrinterEncodingProfile(
      printerId: printer.id,
      encoding: candidate.encoding,
      codePage: candidate.codePage,
      verifiedAt: DateTime.now(),
      candidateId: candidate.id,
      printerName: _printStationPrinterLabel(printer),
      codepageCommand: candidate.codepageCommand,
      escRValue: candidate.escRValue,
      printMode: effectivePrintMode,
      codepageLabel: candidate.label,
    );
    final recordId = printer.printerRecordId?.trim() ?? '';
    if (recordId.isNotEmpty) {
      try {
        final row = await _printerRepository.getPrinterByRecordId(recordId);
        if (row != null) {
          await _printerRepository.upsertPrinter(
            restaurantId: restaurantId,
            printerId: recordId,
            name: row.name,
            code: row.code,
            connectionType: row.connectionType,
            deviceIdentifier: row.deviceIdentifier,
            paperWidthMm: row.paperWidthMm,
            isActive: row.isActive,
            supportsCut: row.supportsCut,
            charset: PrinterCharset.fromValue(candidate.encoding),
            codePage: candidate.codePage,
            assignedRoles: row.assignedRoles,
            printerProfileId: row.printerProfileId,
          );
        }
      } catch (error) {
        debugPrint(
          '[PrintOrchestrator] encoding profile DB sync failed '
          'printerId=${printer.id} error=$error',
        );
      }
    }
    return const PrinterActionResult(
      ok: true,
      status: 'ready',
      message: 'Türkçe karakter profili kaydedildi.',
    );
  }

  List<Map<String, dynamic>> _turkishEncodingCombinedCandidatesPayload() {
    return <Map<String, dynamic>>[
      for (
        var index = 0;
        index < kTurkishEncodingCalibrationCandidates.length;
        index++
      )
        <String, dynamic>{
          'index': index + 1,
          ...kTurkishEncodingCalibrationCandidates[index].toJson(),
          'line': kTurkishEncodingCalibrationCandidates[index]
              .formatOptionHeader(index + 1),
          'lines': kTurkishEncodingCalibrationCandidates[index]
              .formatReceiptBlock(index + 1),
        },
    ];
  }

  /// Prints every encoding/codepage option on a single calibration receipt.
  Future<PrinterActionResult> printTurkishEncodingCalibrationSheet({
    required String restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    final service = _printServiceFactory();
    try {
      final response = await service.printTurkishEncodingCalibrationCombined(
        printerId: printer.id,
        printerName: printer.queueName,
        printer: _bridgePrinterPayload(printer),
        candidates: _turkishEncodingCombinedCandidatesPayload(),
        testLine: kTurkishCalibrationPrimaryTestLine,
        timeout: const Duration(seconds: 12),
      );
      final verification = _verifyBridgeTestResult(
        printer: printer,
        response: response,
      );
      return PrinterActionResult(
        ok: verification.ok,
        status: verification.status,
        message: verification.ok
            ? 'Tüm kod sayfası seçenekleri tek fişte basıldı. Doğru satırı seçip kaydedin.'
            : verification.message,
        printer: printer,
        raw: response,
      );
    } catch (error) {
      return PrinterActionResult(
        ok: false,
        status: 'error',
        message: error.toString(),
        printer: printer,
      );
    }
  }

  Future<PrinterActionResult> printTurkishEncodingCalibration({
    required String restaurantId,
    required UnifiedPrinterModel printer,
    required TurkishEncodingCandidate candidate,
  }) async {
    return printTurkishEncodingCalibrationSheet(
      restaurantId: restaurantId,
      printer: printer,
    );
  }

  Map<String, dynamic> _bridgePrinterPayload(UnifiedPrinterModel printer) {
    final raw = Map<String, dynamic>.from(printer.raw);
    raw['id'] = printer.id;
    raw['name'] = printer.backend == DesktopPrinterBackend.tcp
        ? printer.displayName
        : (printer.queueName.trim().isNotEmpty
              ? printer.queueName
              : (raw['name'] ?? printer.displayName));
    raw['displayName'] = printer.displayName;
    raw['backend'] = printer.backend.value;
    raw['connectionType'] =
        raw['connectionType'] ??
        raw['connection_type'] ??
        printer.raw['connectionType'] ??
        printer.raw['connection_type'];
    if (printer.backend == DesktopPrinterBackend.tcp) {
      // Ethernet / raw TCP printers: bridge dispatches over a plain socket and
      // never touches CUPS/USB. Carry host/port/transport so the smart-router
      // can pick the network branch.
      raw.remove('queue');
      raw.remove('queueName');
      raw.remove('deviceIdentifier');
      raw.remove('device_identifier');
      raw.remove('vendorId');
      raw.remove('productId');
      raw['transportType'] = PrinterModel.ethernetBridgeTransport;
      raw['transport_type'] = PrinterModel.ethernetBridgeTransport;
      final host =
          (raw['host'] ?? raw['ip_address'] ?? raw['ipAddress'])?.toString() ??
          '';
      final portRaw = raw['port'] ?? raw['tcp_port'];
      final port = portRaw is int
          ? portRaw
          : int.tryParse(portRaw?.toString() ?? '') ??
                PrinterModel.ethernetDefaultPort;
      if (host.isNotEmpty) {
        raw['host'] = host;
        raw['ip_address'] = host;
        raw['ipAddress'] = host;
      }
      raw['port'] = port;
    } else if (printer.backend == DesktopPrinterBackend.usbDirect) {
      raw.remove('queue');
      raw['deviceIdentifier'] = _persistedDeviceIdentifier(printer);
      raw['device_identifier'] = _persistedDeviceIdentifier(printer);
    } else {
      raw['queue'] = raw['queue'] ?? printer.queueName;
      raw['queueName'] = raw['queue'] ?? printer.queueName;
    }
    if (printer.vendorId != null && printer.vendorId!.isNotEmpty) {
      raw['vendorId'] = _normalizeUsbHex(printer.vendorId);
    }
    if (printer.productId != null && printer.productId!.isNotEmpty) {
      raw['productId'] = _normalizeUsbHex(printer.productId);
    }
    if (printer.printerRecordId != null &&
        printer.printerRecordId!.isNotEmpty) {
      raw['printer_record_id'] =
          raw['printer_record_id'] ?? printer.printerRecordId;
    }
    final profileId = _resolvedPrinterProfileId(
      printer,
      documentType: _readText(raw['document_type']),
      role: _readText(raw['printer_role']),
    );
    raw['paper_width_mm'] =
        raw['paper_width_mm'] ?? _resolvedPaperWidthMm(printer: printer);
    raw['auto_cut'] = raw['auto_cut'] ?? _resolvedAutoCut(printer: printer);
    raw['printer_profile'] = raw['printer_profile'] ?? profileId;
    raw['printer_profile_id'] = raw['printer_profile_id'] ?? profileId;
    return raw;
  }

  Map<String, dynamic> buildDispatchPrinterPayload(
    UnifiedPrinterModel printer,
  ) {
    return _bridgePrinterPayload(printer);
  }

  bool _printerMatchesRoleSelection(
    PrinterModel legacyPrinter,
    UnifiedPrinterModel? selectedPrinter,
  ) {
    if (selectedPrinter == null) return false;
    final deviceIdentifier =
        legacyPrinter.deviceIdentifier?.trim().toLowerCase() ?? '';
    final queueName = selectedPrinter.queueName.trim().toLowerCase();
    final displayName = selectedPrinter.displayName.trim().toLowerCase();
    final recordId =
        selectedPrinter.printerRecordId?.trim().toLowerCase() ?? '';
    final selectedDeviceIdentifier = _persistedDeviceIdentifier(
      selectedPrinter,
    ).trim().toLowerCase();
    return (deviceIdentifier.isNotEmpty && deviceIdentifier == queueName) ||
        (deviceIdentifier.isNotEmpty &&
            selectedDeviceIdentifier.isNotEmpty &&
            deviceIdentifier == selectedDeviceIdentifier) ||
        legacyPrinter.name.trim().toLowerCase() == displayName ||
        (recordId.isNotEmpty &&
            legacyPrinter.id.trim().toLowerCase() == recordId) ||
        legacyPrinter.id.trim().toLowerCase() ==
            selectedPrinter.id.trim().toLowerCase();
  }

  UnifiedPrinterModel _normalizePrinterForPhysicalDispatch(
    UnifiedPrinterModel printer,
  ) {
    if (printer.backend == DesktopPrinterBackend.cups) {
      return printer;
    }
    // Ethernet / TCP printers MUST never be coerced into USB-direct.
    if (printer.backend == DesktopPrinterBackend.tcp) {
      return printer;
    }
    // Windows spooler queues (e.g. POS-58 on USB002) must stay on windows-spool.
    if (printer.os == DesktopPrinterOs.windows &&
        printer.backend == DesktopPrinterBackend.windowsSpool) {
      return printer;
    }
    final vendorId = _normalizeUsbHex(printer.vendorId);
    final productId = _normalizeUsbHex(printer.productId);
    final shouldForceUsbDirect =
        printer.backend == DesktopPrinterBackend.usbDirect ||
        (vendorId == _pos58UsbVendorId && productId == _pos58UsbProductId);
    if (!shouldForceUsbDirect) {
      return printer;
    }
    return UnifiedPrinterModel(
      id: printer.id,
      displayName: printer.displayName,
      queueName: printer.queueName,
      backend: DesktopPrinterBackend.usbDirect,
      os: printer.os,
      isAvailable: printer.isAvailable,
      canPrint: printer.canPrint,
      lastTestStatus: printer.lastTestStatus,
      lastError: printer.lastError,
      vendorId: vendorId ?? printer.vendorId,
      productId: productId ?? printer.productId,
      printerRecordId: printer.printerRecordId,
      statusLevel: printer.statusLevel,
      statusMessage: printer.statusMessage,
      raw: <String, dynamic>{
        ...printer.raw,
        'backend': DesktopPrinterBackend.usbDirect.value,
        ...?vendorId == null ? null : <String, dynamic>{'vendorId': vendorId},
        ...?productId == null
            ? null
            : <String, dynamic>{'productId': productId},
        'deviceIdentifier': _persistedDeviceIdentifier(printer),
        'device_identifier': _persistedDeviceIdentifier(printer),
      },
    );
  }

  UnifiedPrinterModel? _preferUsbDirectCandidate({
    required List<UnifiedPrinterModel> printers,
    required String queueName,
    required String displayName,
  }) {
    final normalizedQueue = queueName.trim().toLowerCase();
    final normalizedName = displayName.trim().toLowerCase();
    final usbPrinters = printers
        .where((printer) => printer.backend == DesktopPrinterBackend.usbDirect)
        .toList(growable: false);
    if (usbPrinters.isEmpty) return null;

    for (final printer in usbPrinters) {
      final deviceIdentifier = _persistedDeviceIdentifier(
        printer,
      ).trim().toLowerCase();
      if (deviceIdentifier.isNotEmpty &&
          (deviceIdentifier == normalizedQueue ||
              deviceIdentifier == normalizedName)) {
        return printer;
      }
    }

    final wantsPos58Usb =
        _looksLikePos58Alias(normalizedQueue) ||
        _looksLikePos58Alias(normalizedName);
    if (wantsPos58Usb) {
      final matches = usbPrinters
          .where(_isPos58UsbPrinter)
          .toList(growable: false);
      if (matches.isNotEmpty) {
        return _sortPrinters(matches, os: matches.first.os).first;
      }
    }
    return null;
  }

  bool _isPos58UsbPrinter(UnifiedPrinterModel printer) {
    if (printer.backend != DesktopPrinterBackend.usbDirect) {
      return false;
    }
    final vendorId = _normalizeUsbHex(printer.vendorId);
    final productId = _normalizeUsbHex(printer.productId);
    if (vendorId == _pos58UsbVendorId && productId == _pos58UsbProductId) {
      return true;
    }
    final text = '${printer.id} ${printer.queueName} ${printer.displayName}'
        .toLowerCase();
    return _looksLikePos58Alias(text);
  }

  bool _looksLikePos58Alias(String value) {
    return value.contains('pos58') || value.contains('stmicroelectronics');
  }

  String _persistedDeviceIdentifier(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host =
          (printer.raw['host'] ??
                  printer.raw['ip_address'] ??
                  printer.raw['ipAddress'])
              ?.toString()
              .trim();
      final portRaw = printer.raw['port'] ?? printer.raw['tcp_port'];
      final port = portRaw is int
          ? portRaw
          : int.tryParse(portRaw?.toString() ?? '') ??
                PrinterModel.ethernetDefaultPort;
      if (host != null && host.isNotEmpty) {
        return PrinterModel.ethernetPrinterId(host: host, port: port);
      }
    }
    final vendorId = _normalizeUsbHex(printer.vendorId);
    final productId = _normalizeUsbHex(printer.productId);
    final looksUsb =
        printer.backend == DesktopPrinterBackend.usbDirect ||
        _looksLikePos58Alias(
          '${printer.id} ${printer.queueName} ${printer.displayName}'
              .toLowerCase(),
        );
    if (looksUsb && vendorId != null && productId != null) {
      return 'usb-${vendorId.substring(2)}:${productId.substring(2)}';
    }
    return printer.queueName;
  }

  String _storagePrinterId(UnifiedPrinterModel printer) {
    final recordId = printer.printerRecordId?.trim() ?? '';
    if (recordId.isNotEmpty) {
      return recordId;
    }
    return printer.id.trim();
  }

  String _printStationPrinterLabel(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.windowsSpool &&
        printer.queueName.trim().isNotEmpty) {
      return printer.queueName.trim();
    }
    final displayName = printer.displayName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return printer.queueName.trim();
  }

  String _physicalPrintEndpoint(PrintPayload payload) {
    return payload.isReceipt ? '/print/receipt' : '/print/kitchen';
  }

  void _applyPhysicalDispatchDefaults(
    Map<String, dynamic> requestPayload, {
    required UnifiedPrinterModel printer,
    String? flowType,
    String? endpoint,
  }) {
    final inferredDocumentType =
        _readText(requestPayload['document_type']).isEmpty
        ? (endpoint == '/print/receipt' ? 'receipt' : 'kitchen')
        : _readText(requestPayload['document_type']);
    final inferredRole = _readText(requestPayload['printer_role']).isEmpty
        ? (inferredDocumentType == 'receipt' ? 'adisyon' : 'mutfak')
        : _readText(requestPayload['printer_role']);
    _applyPrinterProfileMetadata(
      requestPayload,
      printer: printer,
      documentType: inferredDocumentType,
      role: inferredRole,
    );
    _applyRecommendedRenderMetadata(
      requestPayload,
      printer: printer,
      documentType: inferredDocumentType,
      role: inferredRole,
    );
    final testMode = _readText(requestPayload['test_mode']).toLowerCase();
    if (testMode == 'bitmap') {
      requestPayload['render_mode'] = 'image';
      if (printer.backend == DesktopPrinterBackend.windowsSpool) {
        requestPayload['spool_mode'] = 'RAW';
      }
    } else if (requestPayload['turkish_print_mode'] ==
            kTurkishPrintModeGuarantee ||
        requestPayload['turkish_guarantee_mode'] == true) {
      requestPayload['render_mode'] = 'image';
      if (printer.backend == DesktopPrinterBackend.windowsSpool) {
        requestPayload['spool_mode'] = 'RAW';
      }
    } else if (printer.backend == DesktopPrinterBackend.windowsSpool) {
      requestPayload['render_mode'] = 'text';
      requestPayload['spool_mode'] = 'RAW';
    } else {
      final existing = _readText(requestPayload['render_mode']).toLowerCase();
      if (existing.isEmpty) {
        requestPayload['render_mode'] = 'text';
      }
    }
    if (flowType != null && flowType.trim().isNotEmpty) {
      requestPayload['flow_type'] = flowType.trim();
    }
    if (endpoint != null && endpoint.trim().isNotEmpty) {
      requestPayload['endpoint'] = endpoint.trim();
    }
  }

  void _applyPrinterProfileMetadata(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel printer,
    required String documentType,
    required String role,
  }) {
    final profileId = _resolvedPrinterProfileId(
      printer,
      documentType: documentType,
      role: role,
    );
    final profile = PrinterProfile.byId(profileId);
    final paperWidthMm =
        (payload['paper_width_mm'] as num?)?.toInt() ??
        _resolvedPaperWidthMm(printer: printer, profile: profile);
    payload['paper_width_mm'] = paperWidthMm;
    payload['paperWidthMm'] = payload['paperWidthMm'] ?? paperWidthMm;
    payload['printer_profile'] = profileId;
    payload['printer_profile_id'] = profileId;
    payload['auto_cut'] =
        payload['auto_cut'] ??
        _resolvedAutoCut(printer: printer, profile: profile);
    payload['autoCut'] = payload['autoCut'] ?? payload['auto_cut'];
    payload['chars_per_line'] =
        payload['chars_per_line'] ??
        (profile?.charsPerLine ?? (paperWidthMm <= 58 ? 32 : 48));
    payload['raster_width_px'] =
        payload['raster_width_px'] ?? _rasterWidthPxForPaper(paperWidthMm);
  }

  void _applyRecommendedRenderMetadata(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel printer,
    required String documentType,
    required String role,
  }) {
    final forceImage = _shouldUseRasterImageMode(
      payload: payload,
      printer: printer,
      documentType: documentType,
      role: role,
    );
    payload['render_engine'] =
        payload['render_engine'] ?? 'unified_escpos_renderer';
    if (!forceImage) {
      return;
    }
    payload['render_mode'] = 'image';
    payload['turkish_print_mode'] =
        payload['turkish_print_mode'] ?? kTurkishPrintModeGuarantee;
    payload['turkish_guarantee_mode'] = true;
    payload['use_bundled_font_only'] = true;
    payload['code_page_profile'] = 'image';
    payload['printer_code_page_mode'] = 'image';
  }

  bool _shouldUseRasterImageMode({
    required Map<String, dynamic> payload,
    required UnifiedPrinterModel printer,
    required String documentType,
    required String role,
  }) {
    if (printer.backend == DesktopPrinterBackend.windowsSpool) {
      return false;
    }
    if (printer.backend == DesktopPrinterBackend.tcp &&
        documentType == 'kitchen') {
      return true;
    }
    final paperWidthMm = _resolvedPaperWidthMm(printer: printer);
    if (documentType == 'receipt' &&
        paperWidthMm <= 58 &&
        (printer.backend == DesktopPrinterBackend.usbDirect ||
            printer.backend == DesktopPrinterBackend.cups)) {
      return true;
    }
    if (_containsTurkishCharacters(payload)) {
      return true;
    }
    final explicitMode = _readText(payload['turkish_print_mode']).toLowerCase();
    return explicitMode == kTurkishPrintModeGuarantee || role == 'mutfak';
  }

  bool _containsTurkishCharacters(Object? value) {
    if (value is String) {
      return RegExp(r'[ÇĞİÖŞÜçğıöşü]').hasMatch(value);
    }
    if (value is Map) {
      for (final entry in value.values) {
        if (_containsTurkishCharacters(entry)) return true;
      }
      return false;
    }
    if (value is List) {
      for (final entry in value) {
        if (_containsTurkishCharacters(entry)) return true;
      }
      return false;
    }
    return false;
  }

  int _resolvedPaperWidthMm({
    required UnifiedPrinterModel printer,
    PrinterProfile? profile,
  }) {
    final rawWidth =
        (printer.raw['paper_width_mm'] ?? printer.raw['paperWidthMm']) as num?;
    if (rawWidth != null && rawWidth.toInt() > 0) {
      return rawWidth.toInt();
    }
    return profile?.paperWidthMm ??
        (printer.backend == DesktopPrinterBackend.tcp ? 80 : 58);
  }

  bool _resolvedAutoCut({
    required UnifiedPrinterModel printer,
    PrinterProfile? profile,
  }) {
    final raw = printer.raw['auto_cut'] ?? printer.raw['autoCut'];
    if (raw is bool) return raw;
    return profile?.supportsCut ??
        (printer.backend == DesktopPrinterBackend.tcp);
  }

  String _resolvedPrinterProfileId(
    UnifiedPrinterModel printer, {
    required String documentType,
    required String role,
  }) {
    final explicitProfile = _readText(printer.raw['printer_profile']).isNotEmpty
        ? _readText(printer.raw['printer_profile'])
        : _readText(printer.raw['printer_profile_id']);
    if (explicitProfile.isNotEmpty) {
      return explicitProfile;
    }
    final paperWidthMm = _resolvedPaperWidthMm(printer: printer);
    if (printer.backend == DesktopPrinterBackend.tcp) {
      return PrinterProfile.generic80mmEscpos.id;
    }
    if (paperWidthMm <= 58) {
      return PrinterProfile.pos58.id;
    }
    if (documentType == 'receipt' || role == 'adisyon') {
      return PrinterProfile.receipt80mm.id;
    }
    return PrinterProfile.standard80mm.id;
  }

  int _rasterWidthPxForPaper(int paperWidthMm) =>
      paperWidthMm <= 58 ? 384 : 576;

  PrinterDispatchTarget _dispatchTargetFromPrinter({
    required UnifiedPrinterModel? printer,
    required String documentType,
    required String role,
    String? overrideHost,
    int? overridePort,
  }) {
    final backend = printer?.backend.value ?? '';
    final host =
        overrideHost ?? (printer == null ? null : _printerHost(printer));
    final port =
        overridePort ?? (printer == null ? null : _printerPort(printer));
    return PrinterDispatchTarget(
      printerId: printer?.id ?? '-',
      name: printer?.displayName ?? printer?.queueName ?? '-',
      backend: backend,
      transportType: backend == DesktopPrinterBackend.tcp.value
          ? 'ethernet'
          : backend,
      host: host,
      port: port,
      documentType: documentType,
      role: role,
      printerRecordId: printer?.printerRecordId,
      queueName: printer?.queueName,
    );
  }

  void _debugBridgeDispatchPayload(PrinterDispatchTarget target) {
    debugPrint('[BridgeDispatch][payload]');
    debugPrint('printer_id=${target.printerId}');
    debugPrint('backend=${target.backend.isEmpty ? '-' : target.backend}');
    debugPrint(
      'transportType=${target.transportType.isEmpty ? '-' : target.transportType}',
    );
    debugPrint(
      'target_host=${target.host?.isNotEmpty == true ? target.host : '-'}',
    );
    debugPrint('target_port=${target.port?.toString() ?? '-'}');
  }

  Map<String, String> _kitchenDispatchRouteFromPrinter(
    UnifiedPrinterModel printer,
  ) {
    return <String, String>{
      'printer_id': (printer.printerRecordId?.trim().isNotEmpty ?? false)
          ? printer.printerRecordId!.trim()
          : printer.id,
      'printer_name': printer.displayName,
      'backend': printer.backend.value,
      'host': _printerHost(printer),
      'port': _printerPort(printer).toString(),
      'queue': printer.queueName,
    };
  }

  Map<String, String> _kitchenDispatchRouteFromPayload(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel fallbackPrinter,
  }) {
    final printerPayload = payload['printer'] is Map
        ? Map<String, dynamic>.from(payload['printer'] as Map)
        : const <String, dynamic>{};
    final nestedBackend = _readText(
      printerPayload['backend'] ??
          printerPayload['transportType'] ??
          printerPayload['transport_type'],
    ).toLowerCase();
    final nestedLooksTcp =
        nestedBackend == DesktopPrinterBackend.tcp.value ||
        nestedBackend == PrinterModel.ethernetBridgeTransport;
    final selectedBackend = _readText(
      payload['selected_printer_backend'],
    ).toLowerCase();
    final selectedLooksTcp =
        selectedBackend == DesktopPrinterBackend.tcp.value ||
        selectedBackend == PrinterModel.ethernetBridgeTransport;
    final effectiveBackend = nestedLooksTcp
        ? DesktopPrinterBackend.tcp.value
        : (selectedLooksTcp
              ? DesktopPrinterBackend.tcp.value
              : (_readText(
                      payload['selected_printer_backend'] ??
                          printerPayload['backend'] ??
                          printerPayload['transportType'] ??
                          printerPayload['transport_type'] ??
                          payload['backend'] ??
                          payload['printer_backend'],
                    ).isNotEmpty
                    ? _readText(
                        payload['selected_printer_backend'] ??
                            printerPayload['backend'] ??
                            printerPayload['transportType'] ??
                            printerPayload['transport_type'] ??
                            payload['backend'] ??
                            payload['printer_backend'],
                      ).toLowerCase()
                    : fallbackPrinter.backend.value));
    return <String, String>{
      'printer_id':
          _readText(
            printerPayload['printer_record_id'] ??
                printerPayload['id'] ??
                payload['selected_printer_id'] ??
                payload['printer_record_id'] ??
                payload['printer_id'],
          ).isNotEmpty
          ? _readText(
              printerPayload['printer_record_id'] ??
                  printerPayload['id'] ??
                  payload['selected_printer_id'] ??
                  payload['printer_record_id'] ??
                  payload['printer_id'],
            )
          : (fallbackPrinter.printerRecordId ?? fallbackPrinter.id),
      'printer_name':
          _readText(
            printerPayload['displayName'] ??
                printerPayload['name'] ??
                payload['selected_printer_name'] ??
                payload['printer_name'],
          ).isNotEmpty
          ? _readText(
              printerPayload['displayName'] ??
                  printerPayload['name'] ??
                  payload['selected_printer_name'] ??
                  payload['printer_name'],
            )
          : fallbackPrinter.displayName,
      'backend': effectiveBackend,
      'host': _readText(
        printerPayload['host'] ??
            printerPayload['ip_address'] ??
            printerPayload['ipAddress'] ??
            payload['selected_printer_host'] ??
            payload['host'] ??
            payload['ip_address'] ??
            payload['ipAddress'],
      ),
      'port': _readText(
        printerPayload['port'] ??
            payload['selected_printer_port'] ??
            payload['port'],
      ),
      'queue': effectiveBackend == DesktopPrinterBackend.tcp.value
          ? ''
          : _readText(
              printerPayload['queue'] ??
                  printerPayload['queueName'] ??
                  payload['selected_printer_queue'] ??
                  payload['printer_queue'] ??
                  payload['queue'] ??
                  payload['queueName'],
            ),
    };
  }

  Map<String, String> _kitchenDispatchRouteFromBridgeResponse(
    Map<String, dynamic>? response, {
    required Map<String, dynamic> fallbackPayload,
    required UnifiedPrinterModel fallbackPrinter,
  }) {
    final body = response ?? const <String, dynamic>{};
    final payloadRoute = _kitchenDispatchRouteFromPayload(
      fallbackPayload,
      fallbackPrinter: fallbackPrinter,
    );
    return <String, String>{
      'printer_id':
          _readText(
            body['actual_printer_id'] ??
                body['printer_record_id'] ??
                body['printer_id'] ??
                body['selected_printer_id'],
          ).isNotEmpty
          ? _readText(
              body['actual_printer_id'] ??
                  body['printer_record_id'] ??
                  body['printer_id'] ??
                  body['selected_printer_id'],
            )
          : payloadRoute['printer_id'] ?? '',
      'printer_name':
          _readText(
            body['actual_printer_name'] ??
                body['printer_name'] ??
                body['selected_printer_name'],
          ).isNotEmpty
          ? _readText(
              body['actual_printer_name'] ??
                  body['printer_name'] ??
                  body['selected_printer_name'],
            )
          : payloadRoute['printer_name'] ?? '',
      'backend':
          _readText(
            body['actual_backend'] ??
                body['selected_backend'] ??
                body['transport_type'] ??
                body['transport'] ??
                body['backend'],
          ).isNotEmpty
          ? _readText(
              body['actual_backend'] ??
                  body['selected_backend'] ??
                  body['transport_type'] ??
                  body['transport'] ??
                  body['backend'],
            ).toLowerCase()
          : payloadRoute['backend'] ?? '',
      'host': _readText(
        body['actual_host'] ??
            body['selected_host'] ??
            body['target_host'] ??
            body['host'] ??
            fallbackPayload['selected_printer_host'] ??
            fallbackPayload['host'] ??
            fallbackPayload['ip_address'] ??
            fallbackPayload['ipAddress'],
      ),
      'port': _readText(
        body['actual_port'] ??
            body['selected_port'] ??
            body['target_port'] ??
            body['port'] ??
            fallbackPayload['selected_printer_port'] ??
            fallbackPayload['port'],
      ),
      'queue': _readText(
        body['actual_queue'] ??
            body['queue'] ??
            body['queueName'] ??
            body['selected_printer_queue'] ??
            body['device_identifier'] ??
            fallbackPayload['selected_printer_queue'] ??
            fallbackPayload['printer_queue'] ??
            fallbackPayload['queue'] ??
            fallbackPayload['queueName'],
      ),
    };
  }

  void _clearNonTcpPrinterKeys(Map<String, dynamic> payload) {
    for (final staleKey in const <String>[
      'printer_base_url',
      'printer_http_route',
      'printer_target_host',
      'printer_target_port',
      'printer_target_route',
      'target_host',
      'target_port',
      'target_route',
      'printer_ip_address',
      'printer_port',
      'ip_address',
      'ipAddress',
      'port',
      'queue',
      'queueName',
      'printer_queue',
      'deviceIdentifier',
      'device_identifier',
      'printer_device_identifier',
      'vendorId',
      'productId',
      'selected_printer_queue',
      'selected_printer_host',
      'selected_printer_port',
      'selected_printer_backend',
      'printer_backend',
      'backend',
    ]) {
      payload.remove(staleKey);
    }
  }

  Map<String, dynamic> _buildTcpBridgePrinterPayload(
    UnifiedPrinterModel printer,
  ) {
    final next = _bridgePrinterPayload(printer);
    final host = _printerHost(printer);
    final port = _printerPort(printer);
    next['backend'] = DesktopPrinterBackend.tcp.value;
    next['transportType'] = PrinterModel.ethernetBridgeTransport;
    next['transport_type'] = PrinterModel.ethernetBridgeTransport;
    next['host'] = host;
    next['ip_address'] = host;
    next['ipAddress'] = host;
    next['port'] = port;
    next.remove('queue');
    next.remove('queueName');
    next.remove('deviceIdentifier');
    next.remove('device_identifier');
    next.remove('vendorId');
    next.remove('productId');
    return next;
  }

  void _stampTcpDispatchTarget(
    Map<String, dynamic> payload,
    UnifiedPrinterModel printer,
  ) {
    final host = _printerHost(printer);
    final port = _printerPort(printer);
    _clearNonTcpPrinterKeys(payload);
    payload['selected_printer_backend'] = DesktopPrinterBackend.tcp.value;
    payload['selected_printer_host'] = host;
    payload['selected_printer_port'] = port;
    payload['selected_printer_queue'] = '';
    payload['printer_backend'] = DesktopPrinterBackend.tcp.value;
    payload['backend'] = DesktopPrinterBackend.tcp.value;
    payload['host'] = host;
    payload['ip_address'] = host;
    payload['ipAddress'] = host;
    payload['port'] = port;
    payload['transportType'] = PrinterModel.ethernetBridgeTransport;
    payload['transport_type'] = PrinterModel.ethernetBridgeTransport;
    payload['printer'] = _buildTcpBridgePrinterPayload(printer);
    payload['paper_width_mm'] =
        payload['paper_width_mm'] ?? printer.raw['paper_width_mm'] ?? 80;
    payload['auto_cut'] =
        payload['auto_cut'] ?? printer.raw['auto_cut'] ?? true;
  }

  Map<String, dynamic> _verifyKitchenDispatchRouteConsistency({
    required Map<String, String> resolved,
    required Map<String, String> actual,
  }) {
    final resolvedBackend = (resolved['backend'] ?? '').trim().toLowerCase();
    final actualBackend = (actual['backend'] ?? '').trim().toLowerCase();
    final actualQueue = (actual['queue'] ?? '').trim().toLowerCase();
    final resolvedHost = (resolved['host'] ?? '').trim().toLowerCase();
    final actualHost = (actual['host'] ?? '').trim().toLowerCase();
    final resolvedPort = (resolved['port'] ?? '').trim();
    final actualPort = (actual['port'] ?? '').trim();

    final strictTcpGuard = resolvedBackend == DesktopPrinterBackend.tcp.value;
    final routeMatch = !strictTcpGuard
        ? true
        : actualBackend == DesktopPrinterBackend.tcp.value &&
              resolvedHost.isNotEmpty &&
              actualHost.isNotEmpty &&
              resolvedHost == actualHost &&
              resolvedPort.isNotEmpty &&
              actualPort.isNotEmpty &&
              resolvedPort == actualPort &&
              !_looksLikePos58Alias(actualQueue);
    final reason = !strictTcpGuard
        ? 'non_tcp_skip'
        : routeMatch
        ? 'route_match'
        : 'route_mismatch';

    return <String, dynamic>{
      'route_match': routeMatch,
      'reason': reason,
      'message': !strictTcpGuard
          ? 'non_tcp_skip'
          : routeMatch
          ? 'route_match'
          : 'Mutfak fişi yazdırılamadı: çözümlenen yazıcı ile fiziksel dispatch hedefi uyuşmuyor.',
      'resolved': resolved,
      'actual': actual,
    };
  }

  String _kitchenResolveSourceLabel({
    required String rawSource,
    required bool usedFallback,
  }) {
    if (usedFallback) {
      return 'fallback';
    }
    final normalized = rawSource.trim().toLowerCase();
    if (normalized == 'station_mapping') {
      return 'station_mapping';
    }
    if (normalized == 'mutfak_role_mapping' ||
        normalized == 'role_mapping' ||
        normalized == 'role_selection') {
      return 'role_mapping';
    }
    if (normalized == 'working_printer' ||
        normalized == 'local_config' ||
        normalized == 'persisted_payload' ||
        normalized == 'payload' ||
        normalized == 'payload_queue' ||
        normalized == 'legacy_printer' ||
        normalized == 'saved_record' ||
        normalized == 'ethernet_saved_record') {
      return 'fallback';
    }
    return normalized.isEmpty ? 'fallback' : normalized;
  }

  Map<String, dynamic> _buildPhysicalDispatchDiagnostics({
    required String flowType,
    required UnifiedPrinterModel selectedPrinter,
    required UnifiedPrinterModel requestedPrinter,
    required Map<String, dynamic> payload,
    required String endpoint,
    Map<String, dynamic>? bridgeResponse,
    UnifiedPrinterModel? rolePrinter,
  }) {
    return <String, dynamic>{
      'flow_type': flowType,
      'endpoint': endpoint,
      'selected_printer_id': selectedPrinter.id,
      'selected_printer_name': _printStationPrinterLabel(selectedPrinter),
      'selected_printer_queue': selectedPrinter.queueName,
      'selected_printer_backend': selectedPrinter.backend.value,
      'requested_printer_id': requestedPrinter.id,
      'requested_printer_name': _printStationPrinterLabel(requestedPrinter),
      'role_printer_id': rolePrinter?.id ?? selectedPrinter.id,
      'role_printer_name': rolePrinter == null
          ? _printStationPrinterLabel(selectedPrinter)
          : _printStationPrinterLabel(rolePrinter),
      'payload_printer_id': _readText(payload['printer_id']),
      'payload_printer_name': _readText(payload['printer_name']),
      'render_mode': _readText(payload['render_mode']),
      'turkish_print_mode': _readText(payload['turkish_print_mode']),
      'turkish_guarantee_mode': payload['turkish_guarantee_mode'] == true,
      'spool_mode': _readText(payload['spool_mode']),
      if (bridgeResponse != null) ...<String, dynamic>{
        'bridge_response': bridgeResponse,
      },
    };
  }

  Map<String, dynamic> _mergePhysicalDispatchDiagnostics(
    Map<String, dynamic>? raw,
    Map<String, dynamic> diagnostics,
  ) {
    final merged = Map<String, dynamic>.from(raw ?? const <String, dynamic>{});
    merged['dispatch'] = diagnostics;
    return merged;
  }

  Map<String, dynamic> _roleMappingPrinterPayload(UnifiedPrinterModel printer) {
    final json = Map<String, dynamic>.from(printer.toJson());
    final deviceIdentifier = _persistedDeviceIdentifier(printer);
    json['id'] = printer.id;
    json['printer_id'] = printer.id;
    json['name'] = _printStationPrinterLabel(printer);
    json['printer_name'] = _printStationPrinterLabel(printer);
    json['queue'] = printer.queueName;
    json['displayName'] = printer.displayName;
    json['queueName'] = printer.queueName;
    json['backend'] = printer.backend.value;
    json['transportType'] = _transportTypeForPrinter(printer);
    json['transport_type'] = _transportTypeForPrinter(printer);
    json['deviceIdentifier'] = deviceIdentifier;
    json['device_identifier'] = deviceIdentifier;
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host = _printerHost(printer);
      final port = _printerPort(printer);
      if (host.isNotEmpty) {
        json['host'] = host;
        json['ip_address'] = host;
        json['ipAddress'] = host;
      }
      if (port > 0) {
        json['port'] = port;
      }
    }
    if (printer.printerRecordId != null &&
        printer.printerRecordId!.isNotEmpty) {
      json['printerRecordId'] = printer.printerRecordId;
      json['printer_record_id'] = printer.printerRecordId;
    }
    return json;
  }

  Future<UnifiedPrinterModel> _attachStoredPrinterRecordId({
    required String restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    if (printer.printerRecordId?.trim().isNotEmpty ?? false) {
      return printer;
    }
    final rows = await _printerRepository.fetchPrinters(restaurantId);
    final matched = _matchExistingPrinter(rows, printer);
    if (matched == null) {
      return printer;
    }
    return printer.copyWith(printerRecordId: matched.id);
  }

  String? _normalizeUsbHex(String? value) {
    final cleaned = value?.trim().toLowerCase() ?? '';
    if (cleaned.isEmpty) return null;
    final digits = cleaned.startsWith('0x') ? cleaned.substring(2) : cleaned;
    if (digits.isEmpty) return null;
    return '0x${digits.padLeft(4, '0')}';
  }

  _PhysicalPrintVerification _verifyPhysicalPrintResult({
    required UnifiedPrinterModel printer,
    required Map<String, dynamic>? response,
    required String documentType,
  }) {
    final bridgeOk = response?['ok'] == true;
    if (!bridgeOk) {
      return _PhysicalPrintVerification(
        ok: false,
        status: 'print_failed',
        message: _friendlyPhysicalPrintFailure(
          response,
          documentType: documentType,
        ),
      );
    }
    if (printer.backend == DesktopPrinterBackend.usbDirect) {
      final transportOutput = _transportOutput(response);
      if (!transportOutput.contains('usb')) {
        return const _PhysicalPrintVerification(
          ok: false,
          status: 'print_failed',
          message:
              'CUPS tamamlandı ama USB termal yazıcı fiziksel çıktı vermedi.',
        );
      }
    }
    final warningMessage = _readText(response?['warning']);
    if (warningMessage.isNotEmpty) {
      return _PhysicalPrintVerification(
        ok: true,
        status: 'ready_warning',
        message: warningMessage,
      );
    }
    if (response?['confirmation_status']?.toString() ==
        'cups_accepted_unverified') {
      return const _PhysicalPrintVerification(
        ok: true,
        status: 'ready_unverified',
        message:
            'Test işi yazıcı kuyruğuna gönderildi. Fiziksel baskıyı kontrol edin.',
      );
    }
    return const _PhysicalPrintVerification(
      ok: true,
      status: 'ready',
      message: 'Hazir',
    );
  }

  String _transportOutput(Map<String, dynamic>? response) {
    return _readText(
      response?['transport_output'] ??
          response?['transport_type'] ??
          response?['transport'] ??
          response?['transportMode'] ??
          response?['transport_mode'] ??
          response?['backend'],
    ).toLowerCase();
  }

  bool _shouldRetryUsbClaimFailure({
    required UnifiedPrinterModel printer,
    required Object error,
  }) {
    return printer.backend == DesktopPrinterBackend.usbDirect &&
        printer.os == DesktopPrinterOs.macos &&
        _isUsbClaimFailure(error);
  }

  bool _isUsbClaimFailure(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('cannot claim usb interface') ||
        raw.contains('access denied');
  }

  bool _allowAutomaticBackendFallback({
    required UnifiedPrinterModel printer,
    required String documentType,
  }) {
    final normalizedDocumentType = documentType.trim().toLowerCase();
    if (normalizedDocumentType == 'receipt' && _isPos58UsbPrinter(printer)) {
      return false;
    }
    return true;
  }

  Future<UnifiedPrinterModel?> _resolveUsbConflictCupsFallbackPrinter({
    required String? restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    if (restaurantId == null ||
        restaurantId.trim().isEmpty ||
        printer.backend != DesktopPrinterBackend.usbDirect ||
        !_isPos58UsbPrinter(printer)) {
      return null;
    }
    final snapshot = await loadSetupSnapshot(restaurantId: restaurantId);
    final cupsCandidates = snapshot.printers
        .where((candidate) {
          if (candidate.backend != DesktopPrinterBackend.cups) {
            return false;
          }
          final text =
              '${candidate.id} ${candidate.queueName} ${candidate.displayName}'
                  .toLowerCase();
          return _looksLikePos58Alias(text);
        })
        .toList(growable: false);
    if (cupsCandidates.isEmpty) {
      return null;
    }
    final requestedRecordId = printer.printerRecordId?.trim() ?? '';
    if (requestedRecordId.isNotEmpty) {
      for (final candidate in cupsCandidates) {
        if (candidate.printerRecordId == requestedRecordId) {
          return candidate;
        }
      }
    }
    return _sortPrinters(cupsCandidates, os: cupsCandidates.first.os).first;
  }

  Future<bool> _hasUsbCupsConflictForPrinter({
    required String? restaurantId,
    required UnifiedPrinterModel printer,
  }) async {
    if (restaurantId == null ||
        restaurantId.trim().isEmpty ||
        !_isPos58UsbPrinter(printer)) {
      return false;
    }
    final snapshot = await loadSetupSnapshot(restaurantId: restaurantId);
    final hasUsb = snapshot.printers.any(_isPos58UsbPrinter);
    final hasCups = snapshot.printers.any((candidate) {
      if (candidate.backend != DesktopPrinterBackend.cups) {
        return false;
      }
      final text =
          '${candidate.id} ${candidate.queueName} ${candidate.displayName}'
              .toLowerCase();
      return _looksLikePos58Alias(text);
    });
    return hasUsb && hasCups;
  }

  Future<void> _clearRoleSelectionsFromLocalConfig(String restaurantId) async {
    final current = await _loadLocalConfig(restaurantId);
    if (current == null) return;
    final updated = PrinterSetupLocalConfig(
      restaurantId: current.restaurantId,
      os: current.os,
      receiptSelection: null,
      kitchenSelection: null,
      receiptTest: null,
      kitchenTest: null,
      savedAt: DateTime.now(),
      lastCloudWarning: current.lastCloudWarning,
      thisDeviceIsPrintStation: current.thisDeviceIsPrintStation,
    );
    await _saveLocalConfig(updated);
  }

  Future<void> _clearRoleMappingsFromRemoteConfig({
    required String restaurantId,
    required Map<String, dynamic>? remoteConfig,
  }) async {
    if (remoteConfig == null) return;
    final fields = <String, dynamic>{
      'role_mappings': <String, dynamic>{},
      'adisyon_printer_id': null,
      'adisyon_printer_name': null,
      'kitchen_printer_id': null,
      'kitchen_printer_name': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await _printStationService.patchStationConfiguration(
        restaurantId: restaurantId,
        fields: fields,
      );
    } catch (error) {
      debugPrint(
        '[PrintOrchestrator] remote printer cleanup skipped '
        'restaurantId=$restaurantId error=$error',
      );
    }
  }
}
