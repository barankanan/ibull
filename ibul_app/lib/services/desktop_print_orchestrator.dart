import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb, setEquals;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/desktop_printer_setup_models.dart';
import '../models/printer_model.dart';
import '../models/station_printer_model.dart';
import 'desktop_print_ports.dart';
import 'local_print_service.dart';
import 'macos_admin_release_models.dart';
import 'macos_usb_permission_recovery_service.dart';
import 'printer_event_log_service.dart';
import 'print_station_service.dart';
import 'printer_repository.dart';
import 'working_printer_store.dart';

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
}

class QueuedPrintPayloadResolution {
  const QueuedPrintPayloadResolution({
    required this.payload,
    required this.printer,
    required this.resolutionSource,
  });

  final Map<String, dynamic> payload;
  final UnifiedPrinterModel? printer;
  final String resolutionSource;
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

class DesktopPrintOrchestrator {
  DesktopPrintOrchestrator({
    PrinterRepositoryPort? printerRepository,
    PrintStationServicePort? printStationService,
    LocalPrintServiceFactory? printServiceFactory,
    MacosUsbPermissionRecoveryService? usbPermissionRecoveryService,
    PrinterEventLogService? eventLogService,
  }) : _printerRepository = printerRepository ?? PrinterRepository(),
       _printStationService = printStationService ?? PrintStationService(),
       _printServiceFactory =
           printServiceFactory ?? (() => LocalPrintService()),
       _usbPermissionRecoveryService =
           usbPermissionRecoveryService ?? MacosUsbPermissionRecoveryService(),
       _eventLogService = eventLogService ?? PrinterEventLogService();

  static const String _localConfigPrefix = 'ibul_unified_printer_setup_v1_';
  static const Set<PrinterRole> _managedRoles = <PrinterRole>{
    PrinterRole.receipt,
    PrinterRole.kitchen,
  };
  static const Duration _snapshotCacheTtl = Duration(seconds: 3);
  static const String _pos58UsbVendorId = '0x0416';
  static const String _pos58UsbProductId = '0x5011';

  final PrinterRepositoryPort _printerRepository;
  final PrintStationServicePort _printStationService;
  final LocalPrintServiceFactory _printServiceFactory;
  final PrinterEventLogService _eventLogService;
  final MacosUsbPermissionRecoveryService _usbPermissionRecoveryService;
  final WorkingPrinterStore _workingPrinterStore = WorkingPrinterStore();
  final Map<String, _SnapshotCacheEntry> _snapshotCache =
      <String, _SnapshotCacheEntry>{};
  final Map<String, String> _lastRoleMappingReloadJson = <String, String>{};

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
            receiptSelection: PrinterRoleSelection(role: role, printer: resolved),
            kitchenSelection: preservedKitchen,
            receiptTest: null,
            kitchenTest: null,
            savedAt: DateTime.now(),
            thisDeviceIsPrintStation: markThisDeviceAsPrintStation,
          )
        : existing.copyWith(
            receiptSelection: preservedReceipt,
            kitchenSelection: PrinterRoleSelection(role: role, printer: resolved),
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
    _snapshotCache.remove(restaurantId.trim());

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
        message:
            'Yazıcı kaydı oluşturulamadı. Yetki/bağlantı hatası olabilir.',
        technicalMessage: error.toString(),
      );
    }

    final receiptRecordId =
        (localConfig.receiptSelection?.printer.printerRecordId?.trim().isNotEmpty ?? false)
        ? localConfig.receiptSelection!.printer.printerRecordId!.trim()
        : (synced[PrinterSetupRole.adisyon]?.printerRecordId?.trim() ?? '');
    final kitchenRecordId =
        (localConfig.kitchenSelection?.printer.printerRecordId?.trim().isNotEmpty ?? false)
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
    if (localConfig.receiptSelection != null && localConfig.kitchenSelection != null) {
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
    String renderMode = 'image',
  }) {
    return service.printTest(
      targetHost: targetHost,
      targetPort: targetPort,
      encoding: encoding,
      codePage: codePage,
      printerId: printer?.id ?? printerId,
      printerName: printer?.queueName ?? printerName,
      printer: printer == null ? null : _bridgePrinterPayload(printer),
      renderMode: renderMode,
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
    String flowName = 'setup_snapshot',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
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

    final service = _printServiceFactory();
    try {
      final availability = await service.checkAvailability();
      bridgeReachable = availability.isAvailable;
      if (bridgeReachable) {
        health = await service.health();
        setupStatus = await service.setupStatus();
        prerequisites = await service.setupPrerequisites();
        queueStatus = await _printStationService.fetchLocalQueueStatus();
        final printerResponse = await service.printers();
        var rawPrinters = _normalizeBridgePrinters(
          printerResponse?['printers'],
          os: os,
        );
        if (rawPrinters.isEmpty) {
          final discoverResponse = await service.discover();
          rawPrinters = _normalizeBridgePrinters(
            discoverResponse?['printers'],
            os: os,
          );
          if (rawPrinters.isEmpty) {
            rawPrinters = _normalizeDiscoveryFallback(discoverResponse, os: os);
          }
          discoveryWarning = _discoveryWarningFromResponse(
            os: os,
            response: discoverResponse,
            prerequisites: prerequisites,
          );
        }
        final savedPrinters = await savedPrintersFuture;
        printers = _mergeCanonicalPrinterCatalog(
          livePrinters: rawPrinters,
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
        discoveryWarning = 'Bridge calismiyor';
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[PrintOrchestrator] loadSetupSnapshot failed '
        'restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
      discoveryWarning = _friendlyBridgeFailure(error);
    } finally {
      service.dispose();
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
        isReady: printers.isNotEmpty,
        statusKey: printers.isNotEmpty ? 'ready' : 'printer_not_found',
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

    final resolvedPrinter = await _resolvePrinterForTest(
      restaurantId: restaurantId,
      snapshot: snapshot,
      role: role,
      printerId: printerId,
    );
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
    if (testSource == 'role_test') {
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

    final service = _printServiceFactory();
    try {
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
      _logRoleTestEvent(
        restaurantId: restaurantId,
        role: resolvedRole ?? requestedRole,
        event: 'physical_print_called',
        message: 'Fiziksel test baskısı çağrıldı.',
        printer: resolvedPrinter,
        details: <String, dynamic>{'route': '/print/test'},
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
      final raw = (error is LocalPrintServiceException &&
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
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    String renderMode = 'image',
    String flowName = 'generic_printer_test',
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
    if (!_isPrintSystemEnabledFromSnapshot(snapshot)) {
      return _printSystemDisabledResult();
    }
    final requestedPrinterId = printerId?.trim() ?? '';
    final requestedPrinterName = printerName?.trim() ?? '';
    UnifiedPrinterModel? requestedPrinter;
    if (requestedPrinterId.isNotEmpty) {
      requestedPrinter = await _resolvePrinterForTest(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: null,
        printerId: requestedPrinterId,
      );
    } else if (requestedPrinterName.isNotEmpty) {
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
      final hasConflictWarning = requestedPrinter == null
          ? false
          : await _hasUsbCupsConflictForPrinter(
              restaurantId: restaurantId,
              printer: requestedPrinter,
            );
      final fallbackPrinter = hasConflictWarning
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
        renderMode: renderMode,
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
      final message = fallbackPrinter == null
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
      final raw = (error is LocalPrintServiceException &&
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

  Future<UnifiedPrinterModel?> resolvePrinterForRole({
    required String restaurantId,
    required PrinterSetupRole role,
    String flowName = 'role_resolution',
    String source = 'orchestrator',
    String documentType = '-',
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
    final candidate = _resolveSelection(
      role: role,
      localConfig: snapshot.localConfig,
      remoteConfig: snapshot.remoteConfig,
      printers: snapshot.printers,
      os: snapshot.os,
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

    final workingPrinter = await _resolveWorkingPrinter(
      restaurantId: restaurantId,
      snapshot: snapshot,
    );
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
    String flowName = 'dispatch_resolution',
    String source = 'orchestrator',
    String documentType = '-',
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
    final resolved = await _resolvePrinterForTest(
      restaurantId: restaurantId,
      snapshot: snapshot,
      role: role,
      printerId: printerId,
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

  Future<PrinterActionResult> savePrinterRoles({
    required String restaurantId,
    required String receiptPrinterId,
    required String kitchenPrinterId,
    Session? session,
    bool markThisDeviceAsPrintStation = false,
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
    _snapshotCache.remove(restaurantId.trim());
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
              receiptPrinterName: canonicalReceiptPrinter.displayName,
              kitchenPrinterId: canonicalKitchenPrinter.id,
              kitchenPrinterName: canonicalKitchenPrinter.displayName,
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
        receiptPrinterName: canonicalReceiptPrinter.displayName,
        kitchenPrinterId: _storagePrinterId(canonicalKitchenPrinter),
        kitchenPrinterName: canonicalKitchenPrinter.displayName,
        roleMappings: roleMappings,
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
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    if (restaurantId != null && restaurantId.trim().isNotEmpty) {
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
    final hasConflictWarning = await _hasUsbCupsConflictForPrinter(
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
    final printerRole = payload.isReceipt
        ? PrinterSetupRole.adisyon
        : PrinterSetupRole.mutfak;
    final requestPayload = _injectResolvedPrinterIntoPayload(
      Map<String, dynamic>.from(payload.body),
      printer: dispatchPrinter,
      printerRole: printerRole,
      jobRecord: payload.body,
    );
    requestPayload['document_type'] = payload.documentType;
    requestPayload['render_mode'] = requestPayload['render_mode'] ?? 'image';
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
        await _runtimeLog(
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
      }
      var releaseAttempted = false;
      Map<String, dynamic>? response;
      try {
        response = await dispatchPrint();
      } catch (error) {
        if (_shouldRetryUsbClaimFailure(
          printer: dispatchPrinter,
          error: error,
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
      return PrinterActionResult(
        ok: ok,
        status: verification.status,
        message: message,
        printer: dispatchPrinter,
        raw: response,
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
      return PrinterActionResult(
        ok: false,
        status: 'print_failed',
        message: _friendlyBridgeFailure(error),
        printer: dispatchPrinter,
        technicalMessage: error.toString(),
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
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      forceRefresh: false,
    );
    final printerRole = _inferQueuedPrinterRole(jobRecord, payload);
    UnifiedPrinterModel? resolvedPrinter;
    final printerQueue = _readText(
      payload['printer_device_identifier'] ?? payload['printer_queue'],
    );
    var resolutionSource = 'unresolved';

    if (printerRole != null) {
      resolvedPrinter = await _resolvePrinterForRole(
        restaurantId: restaurantId,
        snapshot: snapshot,
        role: printerRole,
      );
      if (resolvedPrinter != null) {
        resolutionSource = 'role_selection';
      }
    }

    if (resolvedPrinter == null && printerQueue.isNotEmpty) {
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

    if (resolvedPrinter == null) {
      final legacyPrinterId = _readText(
        jobRecord['printer_id'] ?? payload['printer_id'],
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

    if (resolvedPrinter == null) {
      resolvedPrinter = _extractEmbeddedPayloadPrinter(
        payload,
        os: snapshot.os,
      );
      if (!_isBridgeReadyPrinter(resolvedPrinter)) {
        resolvedPrinter = null;
      }
      if (resolvedPrinter != null) {
        resolutionSource = 'payload';
      }
    }

    if (resolvedPrinter == null) {
      resolvedPrinter = await _resolveWorkingPrinter(
        restaurantId: restaurantId,
        snapshot: snapshot,
      );
      if (_isBridgeReadyPrinter(resolvedPrinter)) {
        resolutionSource = 'working_printer';
      }
    }

    if (resolvedPrinter != null) {
      resolvedPrinter = await _resolveStoredPrinterCandidate(
        restaurantId: restaurantId,
        snapshot: snapshot,
        candidate: resolvedPrinter,
      );
    }

    final enrichedPayload = _injectResolvedPrinterIntoPayload(
      payload,
      printer: resolvedPrinter,
      printerRole: printerRole,
      jobRecord: jobRecord,
    );
    _log(
      'resolveJobPrinter',
      'restaurantId=$restaurantId jobId=${jobRecord['id'] ?? '-'} '
          'role=${printerRole?.value ?? '-'} source=$resolutionSource '
          'printer=${resolvedPrinter?.id ?? '-'} recordId=${resolvedPrinter?.printerRecordId ?? '-'} '
          'queue=${resolvedPrinter?.queueName ?? '-'} backend=${resolvedPrinter?.backend.value ?? '-'}',
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
          },
        )
        .ignore();
    return QueuedPrintPayloadResolution(
      payload: enrichedPayload,
      printer: resolvedPrinter,
      resolutionSource: resolutionSource,
    );
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
        }
      }
      switch (printer.backend) {
        case DesktopPrinterBackend.windowsSpool:
          return 0;
        case DesktopPrinterBackend.usbDirect:
          return 1;
        case DesktopPrinterBackend.cups:
          return 2;
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

  bool _isBridgeHealthy(Map<String, dynamic>? health) {
    if (health == null || health.isEmpty) return false;
    if (health['ok'] == false) return false;
    final printer = health['printer'];
    return !_containsExplicitFalse(printer);
  }

  bool _isBridgeOperational({
    required Map<String, dynamic>? health,
    required Map<String, dynamic>? queueStatus,
    required List<UnifiedPrinterModel> printers,
  }) {
    if (_isLocalQueueReady(queueStatus)) {
      return true;
    }
    if (_isBridgeHealthy(health)) {
      return true;
    }
    return health?['ok'] == true && printers.isNotEmpty;
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
  }) {
    final localSelection = localConfig?.selectionForRole(role)?.printer;
    if (localSelection != null) {
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
      // Keep the explicit mapping visible to the rest of the system (to block
      // silent fallbacks), but mark it as not physically available.
      return localSelection.copyWith(isAvailable: false, canPrint: false);
    }

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
        return remotePrinter.copyWith(isAvailable: false, canPrint: false);
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

  Future<UnifiedPrinterModel?> _resolvePrinterForTest({
    required String restaurantId,
    required PrinterSetupSnapshot snapshot,
    required PrinterSetupRole? role,
    required String? printerId,
  }) async {
    final directId = printerId?.trim() ?? '';
    if (directId.isNotEmpty) {
      for (final printer in snapshot.printers) {
        if (printer.id == directId ||
            printer.queueName == directId ||
            printer.displayName == directId) {
          return printer;
        }
      }
      final selection = snapshot.localConfig?.selectionForRole(
        role ?? PrinterSetupRole.adisyon,
      );
      if (selection != null &&
          (selection.printer.id == directId ||
              selection.printer.queueName == directId ||
              selection.printer.displayName == directId ||
              selection.printer.printerRecordId == directId)) {
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
          printers: snapshot.printers,
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
      return role == null
          ? null
          : _resolvePrinterForRole(
              restaurantId: restaurantId,
              snapshot: snapshot,
              role: role,
            );
    }
    if (role == null) return null;
    return _resolvePrinterForRole(
      restaurantId: restaurantId,
      snapshot: snapshot,
      role: role,
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
    final merged = <UnifiedPrinterModel>[
      ..._annotatePrintersWithRecordIds(livePrinters, savedPrinters),
    ];

    for (final savedPrinter in savedPrinters) {
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
  }) async {
    final candidate = _resolveSelection(
      role: role,
      localConfig: snapshot.localConfig,
      remoteConfig: snapshot.remoteConfig,
      printers: snapshot.printers,
      os: snapshot.os,
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
    if (printerRecordId.isEmpty) return null;

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

  bool _isBridgeReadyPrinter(UnifiedPrinterModel? printer) {
    if (printer == null) return false;
    return printer.isLiveDiscovery &&
        printer.isAvailable &&
        printer.canPrint &&
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
    if (bridgeHealthy) {
      return <String, dynamic>{
        ...remoteStatus,
        ...operator,
        'status': 'ready',
        'message': operator['message'],
        'errorCode': null,
        'ok': true,
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
      receiptSelection: role == PrinterSetupRole.adisyon
          ? PrinterRoleSelection(role: role, printer: printer)
          : current.receiptSelection,
      kitchenSelection: role == PrinterSetupRole.mutfak
          ? PrinterRoleSelection(role: role, printer: printer)
          : current.kitchenSelection,
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
        final saved = await _printerRepository.upsertPrinter(
          restaurantId: restaurantId,
          name: printer.displayName,
          code: _buildUnassignedPrinterCode(printer),
          // DB constraint: ('network','usb','bluetooth'). Local bridge printers are stored as USB.
          connectionType: PrinterModel.usbConnectionType,
          ipAddress: PrinterModel.localDefaultHost,
          port: PrinterModel.localDefaultPort,
          deviceIdentifier: _persistedDeviceIdentifier(printer),
          paperWidthMm: printer.displayName.toLowerCase().contains('58')
              ? 58
              : 80,
          isActive: true,
          supportsCut: !printer.displayName.toLowerCase().contains('58'),
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
      final saved = await _printerRepository.upsertPrinter(
        restaurantId: restaurantId,
        printerId: existingPrinter?.id,
        name: printer.displayName,
        code: _buildPrinterCode(printer, roles),
        // DB constraint: ('network','usb','bluetooth'). Local bridge printers are stored as USB.
        connectionType: PrinterModel.usbConnectionType,
        ipAddress: PrinterModel.localDefaultHost,
        port: PrinterModel.localDefaultPort,
        deviceIdentifier: _persistedDeviceIdentifier(printer),
        paperWidthMm: printer.displayName.toLowerCase().contains('58')
            ? 58
            : 80,
        isActive: true,
        supportsCut: !printer.displayName.toLowerCase().contains('58'),
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
      return 'USB yazıcı macOS tarafından kilitli.';
    }
    if (raw.contains('connection refused') ||
        raw.contains('connection_error')) {
      return 'Bridge calismiyor';
    }
    if (raw.contains('timeout')) {
      return 'Bridge yanit vermedi';
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
    
    if (errorCode == 'print_system_disabled') {
      return 'Baskı sistemi şu anda kapalı. Yazıcı Ayarları > Baskı Sistemi > Aç butonunu kullanın.';
    }
    if (errorCode == 'duplicate_test_suppressed') {
      return 'Aynı test kısa süre önce gönderildi. Lütfen birkaç saniye bekleyin.';
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
          queueMsg.toLowerCase().contains('waiting for printer to become available') ||
              queueMsg.toLowerCase().contains('yazıcının kullanılabilir olması bekleniyor') ||
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
        : (queuePayload is Map ? Map<String, dynamic>.from(queuePayload) : null);
    final localRuntime = queueMap?['print_system_enabled'] ??
        queueMap?['printSystemEnabled'] ??
        queueMap?['print_system'] ??
        queueMap?['enabled'];
    if (localRuntime is bool) return localRuntime;
    final remote = snapshot.remoteConfig;
    final remoteEnabled = remote?['print_system_enabled'] ?? remote?['printSystemEnabled'];
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
        final queue = details['printer_queue']?.toString() ??
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
          ? 'USB yazıcı macOS tarafından kilitli. CUPS yeniden başlatıldı ama fiziksel çıktı alınamadı.'
          : 'USB yazıcı macOS tarafından kilitli.';
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

  Map<String, dynamic> _injectResolvedPrinterIntoPayload(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel? printer,
    required PrinterSetupRole? printerRole,
    required Map<String, dynamic> jobRecord,
  }) {
    final nextPayload = Map<String, dynamic>.from(payload);
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
      'port',
    ]) {
      nextPayload.remove(staleKey);
    }
    nextPayload['printer'] = _bridgePrinterPayload(printer);
    nextPayload['printer_id'] = printer.id;
    if (printer.printerRecordId?.isNotEmpty ?? false) {
      nextPayload['printer_record_id'] = printer.printerRecordId;
    }
    nextPayload['printer_name'] = printer.displayName;
    nextPayload['printer_backend'] = printer.backend.value;
    nextPayload['printer_device_identifier'] = _persistedDeviceIdentifier(
      printer,
    );
    if (printer.backend == DesktopPrinterBackend.usbDirect) {
      nextPayload.remove('printer_queue');
    } else {
      nextPayload['printer_queue'] = printer.queueName;
    }
    if (printer.vendorId?.isNotEmpty ?? false) {
      nextPayload['vendorId'] = _normalizeUsbHex(printer.vendorId);
    }
    if (printer.productId?.isNotEmpty ?? false) {
      nextPayload['productId'] = _normalizeUsbHex(printer.productId);
    }
    return nextPayload;
  }

  Map<String, dynamic> _bridgePrinterPayload(UnifiedPrinterModel printer) {
    final raw = Map<String, dynamic>.from(printer.raw);
    raw['id'] = printer.id;
    raw['name'] = raw['name'] ?? printer.displayName;
    raw['backend'] = printer.backend.value;
    if (printer.backend == DesktopPrinterBackend.usbDirect) {
      raw.remove('queue');
      raw['deviceIdentifier'] = _persistedDeviceIdentifier(printer);
      raw['device_identifier'] = _persistedDeviceIdentifier(printer);
    } else {
      raw['queue'] = raw['queue'] ?? printer.queueName;
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
    return raw;
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

  Map<String, dynamic> _roleMappingPrinterPayload(UnifiedPrinterModel printer) {
    final json = Map<String, dynamic>.from(printer.toJson());
    final deviceIdentifier = _persistedDeviceIdentifier(printer);
    json['name'] = printer.displayName;
    json['queue'] = printer.queueName;
    json['displayName'] = printer.displayName;
    json['queueName'] = printer.queueName;
    json['transportType'] = printer.backend.value;
    json['deviceIdentifier'] = deviceIdentifier;
    json['device_identifier'] = deviceIdentifier;
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
