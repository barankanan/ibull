import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/desktop_printer_setup_models.dart';
import '../../models/printer_model.dart';
import '../../models/print_job_model.dart';
import '../../models/seller_product.dart';
import '../../models/station_model.dart';
import '../../models/station_printer_model.dart';
import '../../models/mixed_service_order.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/printer_encoding_profile_store.dart';
import '../../services/order_print_job_service.dart';
import '../../services/print_job_repository.dart';
import '../../services/printer_event_log_service.dart';
import '../../services/print_station_service.dart';
import '../../services/printer_repository.dart';
import '../../services/station_repository.dart';
import '../../services/kitchen_print_trace_log.dart';
import '../../services/kitchen_product_mapping_cache_store.dart';
import '../../services/kitchen_routing_service.dart';
import '../../services/store_service.dart';
import '../../services/local_print_service.dart';
import '../../utils/print_perf_log.dart';
import '../../widgets/bridge_error_dialog.dart';
import 'printer_guide_dialog.dart';
import 'printer_system_setup_wizard.dart';
import 'printer_test_dialog.dart';
import 'printer_wizard.dart';
import '../../widgets/turkish_encoding_calibration_dialog.dart';

bool _queueRuntimePrintSystemDisabled(Map<String, dynamic>? queueStatus) {
  final queue = queueStatus?['queue'];
  final normalized = queue is Map<String, dynamic>
      ? queue
      : (queue is Map ? Map<String, dynamic>.from(queue) : null);
  if (normalized == null) {
    return false;
  }
  final runtime = normalized['runtime'];
  final runtimeMap = runtime is Map<String, dynamic>
      ? runtime
      : runtime is Map
      ? Map<String, dynamic>.from(runtime)
      : const <String, dynamic>{};
  final status = runtimeMap['status']?.toString().trim().toLowerCase() ?? '';
  return status == 'print_system_disabled';
}

class KitchenPrintManagementPage extends StatefulWidget {
  const KitchenPrintManagementPage({
    super.key,
    required this.restaurantId,
    this.stationRepository,
    this.printerRepository,
    this.printJobRepository,
    this.orderPrintJobService,
    this.storeService,
    this.printStationService,
    this.printOrchestrator,
    this.printerEventLogService,
  });

  final String restaurantId;
  final StationRepository? stationRepository;
  final PrinterRepository? printerRepository;
  final PrintJobRepository? printJobRepository;
  final OrderPrintJobService? orderPrintJobService;
  final StoreService? storeService;
  final PrintStationService? printStationService;
  final DesktopPrintOrchestrator? printOrchestrator;
  final PrinterEventLogService? printerEventLogService;

  @override
  State<KitchenPrintManagementPage> createState() =>
      _KitchenPrintManagementPageState();
}

class _KitchenPrintManagementPageState
    extends State<KitchenPrintManagementPage> {
  late final StationRepository _stationRepository;
  late final PrinterRepository _printerRepository;
  late final PrintJobRepository _printJobRepository;
  late final OrderPrintJobService _orderPrintJobService;
  late final StoreService _storeService;
  late final PrintStationService _printStationService;
  late final DesktopPrintOrchestrator _printOrchestrator;
  late final PrinterEventLogService _printerEventLogService;

  final Map<String, String?> _productStationDraft = <String, String?>{};
  final Map<String, bool> _productRoutingDraft = <String, bool>{};
  final Map<String, String?> _stationPrinterDraft = <String, String?>{};
  // Per-product save states (replaces global _isSavingProductRouting)
  final Map<String, bool> _productSavingMap = {};
  final Map<String, bool> _productSavedMap = {};
  final Map<String, String> _productSaveErrorMap = {};
  String _printStatusFilter = 'all';
  int _printersRefreshNonce = 0;
  int _assignmentsRefreshNonce = 0;
  int _productsRefreshNonce = 0;
  late Stream<List<PrinterModel>> _printersStream;
  late Future<List<dynamic>> _assignmentsFuture;
  late Future<List<dynamic>> _productsFuture;
  bool _loadingPrintStationState = true;
  bool _savingPrintStation = false;
  bool _savingRoleMappings = false;
  bool _runningHardReset = false;
  bool _testingPrintStation = false;
  bool _turkishEncodingVerified = false;
  bool _savingPrintSystemEnabled = false;
  bool _isThisDevicePrintStation = false;
  String _lastBridgePrinterRefreshKey = '';
  bool _bridgeReachable = false;
  bool _bridgeHealthy = false;
  String? _printStationError;
  String? _printSystemError;
  String? _printSystemSyncNotice;
  String? _selectedReceiptPrinterId;
  String? _selectedKitchenPrinterId;
  String? _selectedReceiptPrinterLabel;
  String? _selectedKitchenPrinterLabel;
  String _selectedPrintStationPlatform = '';
  bool _printSystemEnabled = true;
  bool _printSystemEnabledLoaded = false;
  bool? _localPrintSystemEnabled;
  bool? _remotePrintSystemEnabled;
  bool _printSystemSourceIsLocalRuntime = false;
  final Set<String> _deletingPrinterIds = <String>{};
  List<Map<String, dynamic>> _bridgePrinters = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _staleBridgePrinters = const <Map<String, dynamic>>[];
  bool _usbCupsConflictWarning = false;
  Map<String, dynamic>? _remotePrintStationConfig;
  Map<String, dynamic>? _localQueueStatus;
  Map<String, dynamic>? _localBridgeHealth;
  Map<String, dynamic>? _localSetupStatus;
  Map<String, dynamic>? _localSetupPrerequisites;
  Map<String, dynamic>? _localDiscoverResult;
  PrinterSetupLocalConfig? _localRoleConfig;
  bool _adoptingLocalPrinter = false;
  String? _adoptLocalPrinterError;
  Map<String, dynamic>? _lastCupsQueueBlockedDetails;
  bool _clearingCupsQueue = false;
  PrinterEncodingProfile? _cachedReceiptEncodingProfile;
  PrinterEncodingProfile? _cachedKitchenEncodingProfile;
  DateTime? _encodingProfilesCachedAt;

  @override
  void initState() {
    super.initState();
    _stationRepository = widget.stationRepository ?? StationRepository();
    _printerRepository = widget.printerRepository ?? PrinterRepository();
    _printJobRepository = widget.printJobRepository ?? PrintJobRepository();
    _orderPrintJobService =
        widget.orderPrintJobService ?? OrderPrintJobService();
    _storeService = widget.storeService ?? StoreService();
    _printStationService = widget.printStationService ?? PrintStationService();
    _printOrchestrator =
        widget.printOrchestrator ?? DesktopPrintOrchestrator();
    _printerEventLogService =
        widget.printerEventLogService ?? PrinterEventLogService();
    _printersStream = _createPrintersStream();
    _assignmentsFuture = _loadAssignmentsData();
    _productsFuture = _loadProductRoutingData();
    unawaited(
      KitchenProductMappingCacheStore.ensureHydrated(widget.restaurantId),
    );
    _loadPrintStationState();
    _logPrinterSettings(
      'Init',
      'screen=KitchenPrintManagementPage openedTab=printers sellerId=${widget.restaurantId} '
          'storeId=- backendPath=printers?restaurant_id=eq.${widget.restaurantId}&order=created_at.asc',
    );
  }

  Future<void> _loadPrintStationState({bool invalidateBridgeCache = false}) async {
    if (invalidateBridgeCache) {
      _printOrchestrator.invalidateBridgeStatusCache();
    }
    setState(() {
      _loadingPrintStationState = true;
      _printStationError = null;
      _printSystemError = null;
    });
    try {
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: widget.restaurantId,
        forceRefresh: true,
      );
      final localChoice = await _printStationService.isThisDevicePrintStation();
      var remoteConfig = snapshot.remoteConfig;
      final queueStatus = snapshot.queueStatus;
      var localPrintSystemEnabled = _extractLocalPrintSystemEnabled(queueStatus);
      var remotePrintSystemEnabled = _extractRemotePrintSystemEnabled(
        remoteConfig,
      );
      var syncNotice = _buildPrintSystemSyncNotice(
        localEnabled: localPrintSystemEnabled,
        remoteEnabled: remotePrintSystemEnabled,
        remoteConfig: remoteConfig,
      );
      if (localPrintSystemEnabled != null &&
          remotePrintSystemEnabled != localPrintSystemEnabled) {
        try {
          remoteConfig = await _printStationService.patchStationConfiguration(
            restaurantId: widget.restaurantId,
            fields: <String, dynamic>{
              'print_system_enabled': localPrintSystemEnabled,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          remotePrintSystemEnabled = localPrintSystemEnabled;
          syncNotice =
              'Yerel bridge runtime değeri ile bulut ayarı farklıydı. Bridge runtime değeri buluta senkronlandı.';
        } catch (_) {
          syncNotice ??=
              'Yerel bridge runtime değeri gösteriliyor. Bulut ayarı senkronlanamadı.';
        }
      }
      final bridgePrinters = snapshot.livePrinters
          .map(_printerToLegacyMap)
          .toList(growable: false);
      final staleBridgePrinters = snapshot.stalePrinters
          .map(_printerToLegacyMap)
          .toList(growable: false);
      final nextBridgePrinterRefreshKey = bridgePrinters
          .map(
            (printer) => [
              printer['id']?.toString() ?? '',
              printer['printerRecordId']?.toString() ?? '',
              printer['name']?.toString() ?? '',
              printer['queue']?.toString() ?? '',
              printer['backend']?.toString() ?? '',
            ].join('|'),
          )
          .join('||');
      final selectedPlatform = _printStationService.normalizeStationPlatform(
        remoteConfig?['device_platform']?.toString(),
      );
      final shouldRefreshPrinterViews =
          nextBridgePrinterRefreshKey != _lastBridgePrinterRefreshKey;
      if (!mounted) return;
      final queueDisabled = _queueRuntimePrintSystemDisabled(queueStatus);
      setState(() {
        _isThisDevicePrintStation = localChoice;
        _bridgeReachable = snapshot.bridgeReachable;
        _bridgeHealthy = snapshot.bridgeHealthy;
        _remotePrintStationConfig = remoteConfig;
        _localQueueStatus = queueStatus;
        _localBridgeHealth = snapshot.bridgeHealth ?? const <String, dynamic>{};
        _localSetupStatus = snapshot.buildOperatorSetupStatus();
        _localSetupPrerequisites = snapshot.prerequisites;
        _localRoleConfig = snapshot.localConfig;
        _localDiscoverResult = snapshot.discoveryWarning == null
            ? null
            : <String, dynamic>{'warning': snapshot.discoveryWarning};
        _usbCupsConflictWarning = _hasUsbCupsConflict(snapshot.printers);
        _bridgePrinters = bridgePrinters;
        _staleBridgePrinters = staleBridgePrinters;
        _selectedPrintStationPlatform = _selectedPrintStationPlatform.isEmpty
            ? selectedPlatform
            : _selectedPrintStationPlatform;
        _localPrintSystemEnabled = localPrintSystemEnabled;
        _remotePrintSystemEnabled = remotePrintSystemEnabled;
        _printSystemSourceIsLocalRuntime = localPrintSystemEnabled != null;
        _printSystemEnabled = localPrintSystemEnabled ??
            remotePrintSystemEnabled ??
            (queueDisabled ? false : true);
        _printSystemEnabledLoaded = localPrintSystemEnabled != null ||
            remotePrintSystemEnabled != null ||
            queueStatus != null;
        _printSystemSyncNotice = syncNotice;
        _selectedReceiptPrinterId = _coerceLiveBridgeSelectionId(
          snapshotSelectedId:
              snapshot.selectedReceiptPrinterRecordId ??
              remoteConfig?['adisyon_printer_id']?.toString() ??
              snapshot.localConfig?.receiptSelection?.printer.printerRecordId,
          bridgePrinters: bridgePrinters,
        );
        _selectedKitchenPrinterId = _coerceLiveBridgeSelectionId(
          snapshotSelectedId:
              snapshot.selectedKitchenPrinterRecordId ??
              remoteConfig?['kitchen_printer_id']?.toString() ??
              snapshot.localConfig?.kitchenSelection?.printer.printerRecordId,
          bridgePrinters: bridgePrinters,
        );
        _selectedReceiptPrinterLabel =
            _printerNameById(_selectedReceiptPrinterId) == ''
            ? snapshot.localConfig?.receiptSelection?.printer.displayName
            : _printerNameById(_selectedReceiptPrinterId);
        _selectedKitchenPrinterLabel =
            _printerNameById(_selectedKitchenPrinterId) == ''
            ? snapshot.localConfig?.kitchenSelection?.printer.displayName
            : _printerNameById(_selectedKitchenPrinterId);
        _lastBridgePrinterRefreshKey = nextBridgePrinterRefreshKey;
      });
      if (shouldRefreshPrinterViews) {
        _triggerPrintersRefresh(reason: 'bridgeScanUpdated');
        _triggerAssignmentsRefresh(reason: 'bridgeScanUpdated');
      }
      await _refreshTurkishEncodingStatus();
      unawaited(_cacheEncodingProfilesForSelectedPrinters());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printStationError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPrintStationState = false;
        });
      }
    }
  }

  String _printerNameById(String? printerId) {
    if (printerId == null || printerId.trim().isEmpty) return '';
    for (final printer in _bridgePrinters) {
      final bridgeId = printer['id']?.toString();
      final recordId = printer['printerRecordId']?.toString();
      final persistedRecordId = printer['printer_record_id']?.toString();
      if (bridgeId == printerId ||
          recordId == printerId ||
          persistedRecordId == printerId) {
        return printer['name']?.toString() ?? printerId;
      }
    }
    return printerId;
  }

  UnifiedPrinterModel? _unifiedPrinterForRole(PrinterSetupRole role) {
    final selectionId = (role == PrinterSetupRole.adisyon
            ? _selectedReceiptPrinterId
            : _selectedKitchenPrinterId)
        ?.trim();
    if (selectionId == null || selectionId.isEmpty) return null;
    return _printOrchestrator.resolvePrinterFromBridgeMaps(
      bridgePrinters: _bridgePrinters,
      printerId: selectionId,
      os: _printOrchestrator.detectOs(),
    );
  }

  UnifiedPrinterModel? _unifiedPrinterForEncodingTest() {
    return _unifiedPrinterForRole(PrinterSetupRole.adisyon) ??
        _unifiedPrinterForRole(PrinterSetupRole.mutfak);
  }

  bool _hasCachedBridgeHealthForFastPrint() {
    if (!_bridgeReachable) return false;
    if (_bridgeHealthy) return true;
    return _localBridgeHealth?['ok'] == true;
  }

  Future<void> _cacheEncodingProfilesForSelectedPrinters() async {
    final receiptPrinter = _unifiedPrinterForRole(PrinterSetupRole.adisyon);
    final kitchenPrinter = _unifiedPrinterForRole(PrinterSetupRole.mutfak);
    PrinterEncodingProfile? receiptProfile;
    PrinterEncodingProfile? kitchenProfile;
    if (receiptPrinter != null) {
      receiptProfile = await _printOrchestrator.loadEncodingProfile(
        restaurantId: widget.restaurantId,
        printerId: receiptPrinter.id,
      );
    }
    if (kitchenPrinter != null) {
      kitchenProfile = await _printOrchestrator.loadEncodingProfile(
        restaurantId: widget.restaurantId,
        printerId: kitchenPrinter.id,
      );
    }
    if (!mounted) return;
    setState(() {
      _cachedReceiptEncodingProfile = receiptProfile;
      _cachedKitchenEncodingProfile = kitchenProfile;
      _encodingProfilesCachedAt = DateTime.now();
    });
  }

  PrinterEncodingProfile? _encodingProfileForRole(PrinterSetupRole role) {
    if (_encodingProfilesCachedAt != null &&
        DateTime.now().difference(_encodingProfilesCachedAt!) <=
            const Duration(minutes: 10)) {
      return role == PrinterSetupRole.mutfak
          ? _cachedKitchenEncodingProfile
          : _cachedReceiptEncodingProfile;
    }
    return null;
  }

  Future<bool> _tryFastRoleTestPrint({
    required PrinterSetupRole role,
    required String clickedButton,
    required String perfFlow,
    required void Function(int bridgeRequestMs) onBridgeComplete,
  }) async {
    final printer = _unifiedPrinterForRole(role);
    if (printer == null || !_hasCachedBridgeHealthForFastPrint()) {
      return false;
    }
    final payload = _printOrchestrator.buildFastRoleTestPayload(
      role: role,
      profile: _encodingProfileForRole(role),
      storeName: _selectedReceiptPrinterLabel ?? _selectedKitchenPrinterLabel,
    );
    final bridgeWatch = Stopwatch()..start();
    final result = await _printOrchestrator.printPhysicalToPrinter(
      printer,
      payload,
      restaurantId: widget.restaurantId,
      flowName: 'role_test',
      flowType: clickedButton,
      source: 'kitchen_print_management_page_fast',
    );
    onBridgeComplete(bridgeWatch.elapsedMilliseconds);
    if (!result.ok) {
      final structured = BridgeStructuredError.tryParse(result.raw);
      if (structured != null &&
          (structured.errorCode == 'cups_queue_busy' ||
              structured.errorCode == 'cups_queue_stuck' ||
              structured.errorCode == 'duplicate_test_suppressed')) {
        if (!mounted) return true;
        await showBridgeStructuredErrorDialog(
          context,
          title: 'Test gönderilemedi',
          primaryMessage: result.message,
          error: structured,
          onAfterRefresh: () async {
            await _loadPrintStationState();
          },
        );
        return true;
      }
      final dispatch = result.raw?['dispatch'];
      final dispatchJson = dispatch is Map
          ? jsonEncode(dispatch)
          : (result.raw == null ? '-' : jsonEncode(result.raw));
      throw Exception(
        '${result.status}: ${result.message}'
        '\nflow_type=$clickedButton'
        '\nbackend=${printer.backend.value} queue=${printer.queueName}'
        '\nbridge_printer_id=${printer.id} printer_record_id=${printer.printerRecordId ?? "-"}'
        '\ndispatch=$dispatchJson',
      );
    }
    return true;
  }

  Future<void> _refreshTurkishEncodingStatus() async {
    final printer = _unifiedPrinterForEncodingTest();
    if (!mounted) return;
    if (printer == null) {
      setState(() => _turkishEncodingVerified = false);
      return;
    }
    final verified = await _printOrchestrator.isTurkishEncodingVerified(
      restaurantId: widget.restaurantId,
      printerId: printer.id,
    );
    if (!mounted) return;
    setState(() => _turkishEncodingVerified = verified);
  }

  Future<void> _openTurkishEncodingCalibration() async {
    if (_guardPrintSystemDisabled()) return;
    final printer = _unifiedPrinterForEncodingTest();
    if (printer == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce adisyon veya mutfak yazıcısı seçin.'),
        ),
      );
      return;
    }
    final saved = await TurkishEncodingCalibrationDialog.show(
      context,
      restaurantId: widget.restaurantId,
      printOrchestrator: _printOrchestrator,
      printer: printer,
    );
    if (saved == true) {
      await _refreshTurkishEncodingStatus();
    }
  }

  String _stationPlatformTitle(String value) {
    switch (_printStationService.normalizeStationPlatform(value)) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'MacBook / macOS';
      default:
        return value;
    }
  }

  bool get _isRemotePrintStationOnline =>
      _printStationService.isStationOnline(_remotePrintStationConfig);

  String _localSetupStatusKey() => bridgeOperatorSetupStatusKey(
    bridgeReachable: _bridgeReachable,
    bridgeHealthy: _bridgeHealthy,
    livePrinterCount: _bridgePrinters.length,
    bridgeHealth: _localBridgeHealth,
  );

  String _localSetupActionRequired() {
    return (_localSetupStatus?['actionRequired']?.toString() ?? '')
        .trim()
        .toLowerCase();
  }

  bool get _isLocalPrintRuntimeOnline =>
      _bridgeReachable && (_bridgeHealthy || _hasDetectedPrinters);

  bool get _isPrintStationOnline =>
      _isRemotePrintStationOnline || _isLocalPrintRuntimeOnline;

  bool get _hasDetectedPrinters =>
      _bridgePrinters.any((printer) => printer['isLive'] == true);

  bool _hasUsbCupsConflict(List<UnifiedPrinterModel> printers) {
    bool isPos58Like(String value) {
      final text = value.toLowerCase();
      return text.contains('pos58') || text.contains('stmicroelectronics');
    }

    final hasUsb = printers.any((printer) {
      final text = '${printer.id} ${printer.queueName} ${printer.displayName}';
      return printer.backend == DesktopPrinterBackend.usbDirect &&
          isPos58Like(text);
    });
    final hasCups = printers.any((printer) {
      final text = '${printer.id} ${printer.queueName} ${printer.displayName}';
      return printer.backend == DesktopPrinterBackend.cups && isPos58Like(text);
    });
    return hasUsb && hasCups;
  }

  String _wizardStatusLabel(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
        return 'Hazır';
      case 'running_unhealthy':
        return 'Çalışıyor Ama Sağlıksız';
      case 'setup_required':
        return 'Kurulum Gerekli';
      case 'bridge_not_running':
        return 'Bridge Çalışmıyor';
      case 'driver_missing':
        return 'Sürücü Eksik';
      case 'printer_offline':
        return 'Yazıcı Çevrimdışı';
      case 'not_installed':
        return 'Kurulu Değil';
      case 'installed_not_running':
        return 'Yüklü Ama Çalışmıyor';
      default:
        return 'Kontrol Ediliyor';
    }
  }

  Color _wizardStatusColor(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
        return const Color(0xFF15803D);
      case 'running_unhealthy':
      case 'setup_required':
      case 'not_installed':
      case 'installed_not_running':
        return const Color(0xFFB45309);
      case 'bridge_not_running':
      case 'driver_missing':
      case 'printer_offline':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _bridgeSummaryLabel() {
    if (!_bridgeReachable) return 'Bridge kapalı';
    return _bridgeHealthy || _hasDetectedPrinters
        ? 'Bridge hazır'
        : 'Bridge çalışıyor ama hatalı';
  }

  String _bridgeSummaryMessage() {
    if (!_bridgeReachable) {
      return 'Yerel yazıcı servisine ulaşılamıyor. Önce bridge kurulumunu tamamlayın veya servisi başlatın.';
    }
    final printStation = _localBridgeHealth?['print_station'];
    if (printStation is Map) {
      final stationStatus =
          printStation['status']?.toString().trim().toLowerCase() ?? '';
      final adisyonName = printStation['adisyonPrinterName']?.toString().trim();
      final kitchenName = printStation['kitchenPrinterName']?.toString().trim();
      if (stationStatus == 'waiting_config' ||
          ((adisyonName == null || adisyonName.isEmpty) &&
              (_selectedReceiptPrinterId?.trim().isEmpty ?? true)) ||
          ((kitchenName == null || kitchenName.isEmpty) &&
              (_selectedKitchenPrinterId?.trim().isEmpty ?? true))) {
        return 'Rol ataması eksik. Eşleştirme sekmesinden adisyon ve mutfak '
            'yazıcılarını kaydedin. Manuel test fişleri seçili yazıcıyla '
            'doğrudan basılabilir.';
      }
    }
    final details = _localBridgeHealth?['printer']?['details']
        ?.toString()
        .trim();
    if (_bridgeHealthy || _hasDetectedPrinters) {
      return 'Yazıcı servisi yanıt veriyor. Sıradaki adım yerel yazıcıları taramak.';
    }
    if (details != null && details.isNotEmpty) {
      return 'Bridge yanıt veriyor ama yazıcı doğrulaması başarısız: $details';
    }
    return _localSetupStatus?['message']?.toString() ??
        'Bridge yanıt veriyor ancak yazıcı doğrulaması tamamlanamadı.';
  }

  String? _printerDiscoveryGuidance() {
    final status = _localSetupStatusKey();
    final action = _localSetupActionRequired();
    final printerDetails = _localBridgeHealth?['printer']?['details']
        ?.toString()
        .trim();
    final transportMode =
        (_localBridgeHealth?['transport_mode']?.toString() ?? '')
            .trim()
            .toLowerCase();
    final queueName = (_localBridgeHealth?['printer_queue']?.toString() ?? '')
        .trim();
    final usbDevices =
        (_localDiscoverResult?['usb'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        (_localDiscoverResult?['devices'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    final cupsQueues =
        (_localDiscoverResult?['cups'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];

    if (!_bridgeReachable) {
      return 'Tarama başlamadan önce bridge çalışmalı. "Adım adım kurulum" ile servisi açın.';
    }
    if (!_bridgeHealthy &&
        transportMode == 'cups' &&
        queueName.isNotEmpty &&
        printerDetails != null &&
        printerDetails.isNotEmpty) {
      return 'Bridge şu anda sadece CUPS kuyruğu "$queueName" ile çalışıyor ama bu kuyruk bu MacBook üzerinde geçerli değil. Adım adım kurulumla yazıcıyı yeniden seçin.';
    }
    if (!_hasDetectedPrinters && usbDevices.isNotEmpty) {
      final firstUsb = usbDevices.first;
      final product = firstUsb['name']?.toString() ?? 'USB yazıcı';
      return '$product USB üzerinden bağlı görünüyor fakat henüz seçilebilir yazıcı listesi oluşmadı. "Yazıcı Ekle" ile bu yazıcıyı ekleyin veya adım adım kurulumu tamamlayın.';
    }
    if (!_hasDetectedPrinters && cupsQueues.isNotEmpty) {
      return 'macOS bazı yazıcı kuyrukları görüyor ama seçim listesi oluşmadı. "Yazıcı Ekle" ile yazıcıyı kaydedin veya adım adım kurulumu açın.';
    }
    if (!_hasDetectedPrinters &&
        (status == 'setup_required' || action == 'detect_printer')) {
      return 'Bridge açık ama yazıcı bulunamadı. Yazıcının açık olduğundan, USB kablosunun takılı olduğundan ve macOS Yazıcılar bölümünde göründüğünden emin olun.';
    }
    if (!_hasDetectedPrinters && !_bridgeHealthy) {
      return _bridgeSummaryMessage();
    }
    return null;
  }

  bool? _extractLocalPrintSystemEnabled(Map<String, dynamic>? queueStatus) {
    final queue = queueStatus?['queue'];
    final normalized = queue is Map<String, dynamic>
        ? queue
        : (queue is Map ? Map<String, dynamic>.from(queue) : null);
    if (normalized == null) {
      return null;
    }
    final raw =
        normalized['print_system_enabled'] ?? normalized['printSystemEnabled'];
    if (raw is bool) {
      return raw;
    }
    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return value == 'true' || value == '1' || value == 'yes' || value == 'on';
  }

  bool? _extractRemotePrintSystemEnabled(Map<String, dynamic>? remoteConfig) {
    if (remoteConfig == null) {
      return null;
    }
    if (!remoteConfig.containsKey('print_system_enabled')) {
      return null;
    }
    return remoteConfig['print_system_enabled'] == true;
  }

  String _printSystemStateLabel(bool enabled) => enabled ? 'Açık' : 'Kapalı';

  String _printSystemDescription(bool enabled) {
    return enabled
        ? 'Yeni siparişler otomatik olarak yazdırılır.'
        : 'Siparişler alınır ancak fişler otomatik yazdırılmaz.';
  }

  String _printSystemBannerText(bool enabled) {
    return enabled
        ? 'Baskı sistemi açık. Yeni siparişler yazdırılır.'
        : 'Baskı sistemi kapalı. Siparişler alınır ancak fişler otomatik yazdırılmaz.';
  }

  bool get _isQueuePrintSystemDisabled =>
      _queueRuntimePrintSystemDisabled(_localQueueStatus);

  String _printSystemStateDetailLabel(bool? value) {
    if (value == null) {
      return 'Bilinmiyor';
    }
    return _printSystemStateLabel(value);
  }

  String? _buildPrintSystemSyncNotice({
    required bool? localEnabled,
    required bool? remoteEnabled,
    Map<String, dynamic>? remoteConfig,
  }) {
    if (remoteConfig != null &&
        !remoteConfig.containsKey('print_system_enabled')) {
      return 'Bulut satırında print_system_enabled alanı yok. Supabase’de bu kolonu '
          'ekleyin (20260504 veya 20260507 migration) ve notify pgrst, \'reload schema\'; çalıştırın.';
    }
    if (localEnabled != null &&
        remoteEnabled != null &&
        localEnabled != remoteEnabled) {
      return 'Yerel bridge: ${_printSystemStateLabel(localEnabled)} • Bulut ayarı: ${_printSystemStateLabel(remoteEnabled)}';
    }
    if (localEnabled != null && remoteEnabled == null) {
      return 'Bridge runtime değeri bulundu ama bulut ayarı henüz kayıtlı değil.';
    }
    if (localEnabled == null && remoteEnabled != null) {
      return 'Bridge runtime değeri okunamadı. Geçici olarak bulut ayarı gösteriliyor.';
    }
    return null;
  }

  Future<void> _togglePrintSystemEnabled(bool enabled) async {
    if (_savingPrintSystemEnabled) {
      return;
    }
    if (_printSystemEnabled == enabled &&
        !(enabled && _isQueuePrintSystemDisabled)) {
      return;
    }

    final previousEnabled = _printSystemEnabled;
    final previousLocalEnabled = _localPrintSystemEnabled;
    final previousRemoteEnabled = _remotePrintSystemEnabled;
    setState(() {
      _printSystemEnabled = enabled;
      _localPrintSystemEnabled = previousLocalEnabled == null ? null : enabled;
      _remotePrintSystemEnabled = enabled;
      _printSystemSourceIsLocalRuntime = previousLocalEnabled != null;
      _savingPrintSystemEnabled = true;
      _printSystemError = null;
      _printSystemSyncNotice = null;
    });

    try {
      final result = await _printStationService.setPrintSystemEnabled(
        restaurantId: widget.restaurantId,
        enabled: enabled,
        previousEnabled: previousEnabled,
      );
      if (!result) {
        throw Exception('Baskı sistemi güncellenemedi.');
      }
      await _loadPrintStationState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Baskı sistemi açıldı'
                : 'Baskı sistemi kapatıldı',
          ),
          backgroundColor: enabled
              ? const Color(0xFF16A34A)
              : const Color(0xFFF59E0B),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _printSystemEnabled = previousEnabled;
        _localPrintSystemEnabled = previousLocalEnabled;
        _remotePrintSystemEnabled = previousRemoteEnabled;
        _printSystemSourceIsLocalRuntime = previousLocalEnabled != null;
        _printSystemError = message.isEmpty
            ? 'Baskı sistemi güncellenemedi.'
            : message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_printSystemError!),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingPrintSystemEnabled = false;
        });
      }
    }
  }

  bool _guardPrintSystemDisabled() {
    final effectivelyOff = _isQueuePrintSystemDisabled || !_printSystemEnabled;
    if (!_printSystemEnabledLoaded || !effectivelyOff) {
      return false;
    }
    const message =
        'Baskı sistemi kapalı. Test göndermek için sistemi açın.';
    setState(() {
      _printStationError = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );
    return true;
  }

  Future<void> _setNormalDeviceMode() async {
    await _printStationService.setThisDevicePrintStation(false);
    if (!mounted) return;
    setState(() {
      _isThisDevicePrintStation = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yazdırma işlemi Yazıcı Merkezi cihazından yapılacak.'),
      ),
    );
  }

  Future<void> _sendPrintStationTest({required bool kitchen}) async {
    if (_guardPrintSystemDisabled()) {
      return;
    }
    final role = kitchen ? PrinterSetupRole.mutfak : PrinterSetupRole.adisyon;
    await _runRoleBasedPhysicalPrint(
      role: role,
      payload: PrintPayload.testForRole(role),
      successMessage: kitchen
          ? 'Mutfak test fişi gönderildi.'
          : 'Adisyon test fişi gönderildi.',
    );
  }

  Future<void> _sendDirectAdisyonRoleDebugPrint() async {
    if (_guardPrintSystemDisabled()) {
      return;
    }
    await _runRoleBasedPhysicalPrint(
      role: PrinterSetupRole.adisyon,
      payload: PrintPayload.testForRole(PrinterSetupRole.adisyon),
      successMessage: 'Seçili adisyon yazıcısına direkt baskı gönderildi.',
    );
  }

  Future<void> _runRoleBasedPhysicalPrint({
    required PrinterSetupRole role,
    required PrintPayload payload,
    required String successMessage,
  }) async {
    final tapAt = DateTime.now();
    final perf = Stopwatch()..start();
    var resolvePrinterMs = 0;
    var healthCheckMs = 0;
    var payloadBuildMs = 0;
    var bridgeRequestMs = 0;
    var ok = false;
    String? errorMessage;
    final perfFlow = role == PrinterSetupRole.mutfak
        ? 'kitchen_test'
        : 'receipt_test';
    setState(() {
      _testingPrintStation = true;
      _printStationError = null;
    });
    try {
      final clickedButton = role == PrinterSetupRole.mutfak
          ? 'kitchen_test'
          : 'adisyon_test';
      _printerEventLogService
          .append(
            restaurantId: widget.restaurantId,
            event: 'role_button_clicked',
            message: 'Rol bazlı fiziksel baskı butonuna basıldı.',
            role: role.value,
            details: <String, dynamic>{
              'clicked_button': clickedButton,
              'document_type': payload.documentType,
              'testSource': 'role_test',
              'selectedReceiptPrinterId': _selectedReceiptPrinterId,
              'selectedKitchenPrinterId': _selectedKitchenPrinterId,
            },
          )
          .ignore();
      final explicitPrinterId = role == PrinterSetupRole.adisyon
          ? _selectedReceiptPrinterId
          : _selectedKitchenPrinterId;
      final payloadWatch = Stopwatch()..start();
      final fastCompleted = await _tryFastRoleTestPrint(
        role: role,
        clickedButton: clickedButton,
        perfFlow: perfFlow,
        onBridgeComplete: (ms) => bridgeRequestMs = ms,
      );
      if (fastCompleted) {
        healthCheckMs = 0;
        resolvePrinterMs = 0;
        payloadBuildMs = payloadWatch.elapsedMilliseconds;
      } else {
        final healthWatch = Stopwatch()..start();
        final bridgeReachable = await _printOrchestrator.isLocalBridgeReachable(
          useCache: true,
        );
        healthCheckMs = healthWatch.elapsedMilliseconds;
        if (!bridgeReachable) {
          throw Exception('Bridge calismiyor');
        }
        final resolveWatch = Stopwatch()..start();
        final printer = await _printOrchestrator.resolvePrinterForDispatch(
          restaurantId: widget.restaurantId,
          role: role,
          printerId: explicitPrinterId,
          flowName: clickedButton,
          documentType: payload.documentType,
          source: 'kitchen_print_management_page',
          minimalSnapshot: true,
        );
        resolvePrinterMs = resolveWatch.elapsedMilliseconds;
        if (printer == null) {
          throw Exception(
            role == PrinterSetupRole.mutfak
                ? 'Kaydedilmiş mutfak yazıcısı bulunamadı.'
                : 'Kaydedilmiş adisyon yazıcısı bulunamadı.',
          );
        }
        final fallbackPayload = _printOrchestrator.buildFastRoleTestPayload(
          role: role,
          profile: _encodingProfileForRole(role),
          storeName:
              _selectedReceiptPrinterLabel ?? _selectedKitchenPrinterLabel,
        );
        payloadBuildMs = payloadWatch.elapsedMilliseconds;
        debugPrint(
          '[ROLE_TEST_CLICK] clicked_button=$clickedButton '
          'restaurantId=${widget.restaurantId} '
          'selectedPrinterId=${explicitPrinterId ?? "-"} '
          'printerRecordId=${printer.printerRecordId ?? "-"} '
          'bridgePrinterId=${printer.id} name=${printer.displayName} '
          'backend=${printer.backend.value} queue=${printer.queueName} '
          'document_type=${payload.documentType}',
        );
        _printerEventLogService
            .append(
              restaurantId: widget.restaurantId,
              event: 'role_printer_resolved',
              message: 'Rol yazıcısı çözüldü.',
              role: role.value,
              printerId: printer.printerRecordId ?? printer.id,
              queueName: printer.queueName,
              backend: printer.backend.value,
              details: <String, dynamic>{'documentType': payload.documentType},
            )
            .ignore();
        final bridgeWatch = Stopwatch()..start();
        final result = await _printOrchestrator.printPhysicalToPrinter(
          printer,
          fallbackPayload,
          restaurantId: widget.restaurantId,
          flowName: 'role_test',
          flowType: clickedButton,
          source: 'kitchen_print_management_page',
        );
        bridgeRequestMs = bridgeWatch.elapsedMilliseconds;
        if (!result.ok) {
          final structured = BridgeStructuredError.tryParse(result.raw);
          if (structured != null &&
              (structured.errorCode == 'cups_queue_busy' ||
                  structured.errorCode == 'cups_queue_stuck' ||
                  structured.errorCode == 'duplicate_test_suppressed')) {
            if (!mounted) return;
            await showBridgeStructuredErrorDialog(
              context,
              title: 'Test gönderilemedi',
              primaryMessage: result.message,
              error: structured,
              onAfterRefresh: () async {
                await _loadPrintStationState();
              },
            );
            return;
          }
          final dispatch = result.raw?['dispatch'];
          final dispatchJson = dispatch is Map
              ? jsonEncode(dispatch)
              : (result.raw == null ? '-' : jsonEncode(result.raw));
          final msg =
              '${result.status}: ${result.message}'
              '\nflow_type=$clickedButton'
              '\nbackend=${printer.backend.value} queue=${printer.queueName}'
              '\nbridge_printer_id=${printer.id} printer_record_id=${printer.printerRecordId ?? "-"}'
              '\ndispatch=$dispatchJson';
          throw Exception(msg);
        }
      }
      if (!mounted) return;
      ok = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      errorMessage = message;
      setState(() {
        _printStationError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    } finally {
      logPrintPerf(
        perfFlow,
        <String, Object?>{
          'tap_at': tapAt.toIso8601String(),
          'resolve_printer_ms': resolvePrinterMs,
          'health_check_ms': healthCheckMs,
          'payload_build_ms': payloadBuildMs,
          'bridge_request_ms': bridgeRequestMs,
          'total_ms': perf.elapsedMilliseconds,
          'ok': ok,
          if (errorMessage != null) 'error': errorMessage,
        },
      );
      if (mounted) {
        setState(() {
          _testingPrintStation = false;
        });
      }
    }
  }

  Future<void> _savePrintStationMode() async {
    final receiptPrinterId = _selectedReceiptPrinterId?.trim() ?? '';
    final kitchenPrinterId = _selectedKitchenPrinterId?.trim() ?? '';
    if (receiptPrinterId.isEmpty || kitchenPrinterId.isEmpty) {
      setState(() {
        _printStationError =
            'Önce Eşleştirme sekmesinden adisyon ve mutfak yazıcılarını kaydedin.';
      });
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() {
        _printStationError =
            'Yazıcı Merkezi kurulumu için aktif Supabase oturumu gerekli.';
      });
      return;
    }

    setState(() {
      _savingPrintStation = true;
      _printStationError = null;
    });
    try {
      final result = await _printOrchestrator.savePrinterRoles(
        restaurantId: widget.restaurantId,
        receiptPrinterId: receiptPrinterId,
        kitchenPrinterId: kitchenPrinterId,
        session: session,
        markThisDeviceAsPrintStation: true,
        stationPlatform: _selectedPrintStationPlatform,
      );
      if (!result.ok) {
        throw Exception(result.message);
      }
      await _loadPrintStationState();
      if (!mounted) return;
      setState(() {
        _isThisDevicePrintStation = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printStationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPrintStation = false;
        });
      }
    }
  }

  Future<void> _saveRoleMappings() async {
    final receiptPrinterId = _selectedReceiptPrinterId?.trim() ?? '';
    final kitchenPrinterId = _selectedKitchenPrinterId?.trim() ?? '';
    if (receiptPrinterId.isEmpty || kitchenPrinterId.isEmpty) {
      setState(() {
        _printStationError =
            'Adisyon ve mutfak yazıcısı eşleştirmesi zorunludur.';
      });
      return;
    }

    setState(() {
      _savingRoleMappings = true;
      _printStationError = null;
    });
    try {
      final shouldConfigureLocalBridge = _isThisDevicePrintStation;
      final stationPlatform = _selectedPrintStationPlatform.isEmpty
          ? (_remotePrintStationConfig?['device_platform']?.toString())
          : _selectedPrintStationPlatform;
      final result = await _printOrchestrator.savePrinterRoles(
        restaurantId: widget.restaurantId,
        receiptPrinterId: receiptPrinterId,
        kitchenPrinterId: kitchenPrinterId,
        session: shouldConfigureLocalBridge
            ? Supabase.instance.client.auth.currentSession
            : null,
        markThisDeviceAsPrintStation: shouldConfigureLocalBridge,
        stationPlatform: stationPlatform,
      );
      if (!result.ok) {
        throw Exception(result.message);
      }
      await _loadPrintStationState();
      _triggerAssignmentsRefresh(reason: 'roleMappingsSaved');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printStationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingRoleMappings = false;
        });
      }
    }
  }

  Future<void> _openGuidedSetup() async {
    await showPrinterSystemSetupWizard(
      context,
      restaurantId: widget.restaurantId,
    );
    if (!mounted) return;
    await _loadPrintStationState();
  }

  Future<List<dynamic>> _loadAssignmentsData() async {
    _logPrinterSettings(
      'Assignments',
      'fetchStart restaurantId=${widget.restaurantId} areaCount=- printerCount=- selectedPrinterId=- selectedAreaId=- emptyBranch=pending',
    );
    try {
      final results = await Future.wait<dynamic>([
        _stationRepository.fetchStations(widget.restaurantId),
        _printerRepository.fetchPrinters(widget.restaurantId),
        _printerRepository.fetchStationPrinterMappings(widget.restaurantId),
      ]);
      final stations = results[0] as List<StationModel>;
      final activePrinters = (results[1] as List<PrinterModel>)
          .where((printer) => printer.isActive)
          .toList(growable: false);
      final printers = _filterPrintersToCurrentScan(activePrinters);
      final printerIds = printers.map((printer) => printer.id).toSet();
      final mappings = (results[2] as List<StationPrinterModel>)
          .where((mapping) => printerIds.contains(mapping.printerId))
          .toList(growable: false);
      final emptyBranch = stations.isEmpty
          ? 'no_areas'
          : printers.isEmpty
          ? 'no_active_printers'
          : mappings.isEmpty
          ? 'no_assignments'
          : 'has_rows';
      _logPrinterSettings(
        'Assignments',
        'fetchSuccess restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=- selectedAreaId=- emptyBranch=$emptyBranch',
      );
      return <dynamic>[stations, printers, mappings];
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Assignments',
        'fetchFail restaurantId=${widget.restaurantId} areaCount=- printerCount=- selectedPrinterId=- selectedAreaId=- emptyBranch=fetch_error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Map<String, dynamic> _printerToLegacyMap(UnifiedPrinterModel printer) {
    return <String, dynamic>{
      'id': printer.id,
      'selectionId':
          printer.printerRecordId?.trim().isNotEmpty == true
          ? printer.printerRecordId
          : printer.id,
      'name': printer.displayName,
      'queue': printer.queueName,
      'printerRecordId': printer.printerRecordId,
      'printer_record_id': printer.printerRecordId,
      'deviceIdentifier':
          printer.raw['deviceIdentifier'] ??
          printer.raw['device_identifier'] ??
          printer.queueName,
      'device_identifier':
          printer.raw['device_identifier'] ??
          printer.raw['deviceIdentifier'] ??
          printer.queueName,
      'source': printer.raw['source'] ?? 'usb_scan',
      'isLive': printer.isLiveDiscovery,
      'isSavedOnly': printer.isStaleSavedMapping,
      'backend': printer.backend.value,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'statusLevel': printer.isStaleSavedMapping
          ? 'error'
          : printer.canPrint
          ? 'ready'
          : (printer.isAvailable ? 'warning' : 'error'),
      'statusMessage': printer.isStaleSavedMapping
          ? 'Eski/kayıp — canlı taramada yok'
          : printer.statusMessage,
    };
  }

  String? _coerceLiveBridgeSelectionId({
    required String? snapshotSelectedId,
    required List<Map<String, dynamic>> bridgePrinters,
  }) {
    final id = snapshotSelectedId?.trim() ?? '';
    if (id.isEmpty) return null;
    for (final printer in bridgePrinters) {
      if (printer['isLive'] != true) continue;
      final bridgeId = printer['id']?.toString().trim() ?? '';
      final selectionId = printer['selectionId']?.toString().trim() ?? '';
      final recordId =
          printer['printerRecordId']?.toString().trim() ??
          printer['printer_record_id']?.toString().trim() ??
          '';
      if (bridgeId == id || selectionId == id || recordId == id) {
        return selectionId.isNotEmpty ? selectionId : bridgeId;
      }
    }
    return null;
  }

  Future<List<dynamic>> _loadProductRoutingData() async {
    _logPrinterSettings(
      'Products',
      'fetchStart restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=- emptyBranch=pending',
    );
    try {
      final results = await Future.wait<dynamic>([
        _storeService.getMenuProductsBySellerId(widget.restaurantId),
        _stationRepository.fetchStations(widget.restaurantId),
      ]);
      final products = (results[0] as List<dynamic>)
          .whereType<Map>()
          .map(
            (row) => SellerProduct.fromMap(
              Map<String, dynamic>.from(row),
              row['id']?.toString() ?? '',
            ),
          )
          .toList(growable: false);
      final stations = results[1] as List<StationModel>;
      final emptyBranch = products.isEmpty
          ? 'no_products'
          : stations.isEmpty
          ? 'no_areas'
          : 'has_rows';
      _logPrinterSettings(
        'Products',
        'fetchSuccess restaurantId=${widget.restaurantId} areaCount=${stations.length} productCount=${products.length} selectedAreaId=- emptyBranch=$emptyBranch',
      );
      _syncProductRoutingCacheFromLists(products, stations);
      for (final product in products) {
        final stationId =
            _productStationDraft[product.id] ?? product.stationId;
        if (stationId != null && stationId.isNotEmpty) {
          _upsertProductMappingCache(product, stationId, stations);
        }
      }
      return <dynamic>[products, stations];
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Products',
        'fetchFail restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=- emptyBranch=fetch_error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _showStationEditor({StationModel? station}) async {
    final nameCtrl = TextEditingController(text: station?.name ?? '');
    final codeCtrl = TextEditingController(text: station?.code ?? '');
    final colorCtrl = TextEditingController(text: station?.color ?? '');
    var isActive = station?.isActive ?? true;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              station == null ? 'Yeni Hazırlama Alanı' : 'Alan Düzenle',
            ),
            content: StatefulBuilder(
              builder: (ctx, setSheet) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Alan Adı',
                        ),
                      ),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kod (örn: OCAK)',
                        ),
                      ),
                      TextField(
                        controller: colorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Renk (opsiyonel)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isActive,
                        onChanged: (value) => setSheet(() => isActive = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktif'),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );

      if (saved != true) return;
      if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alan adı ve kod zorunludur.')),
        );
        return;
      }

      await _stationRepository.upsertStation(
        restaurantId: widget.restaurantId,
        stationId: station?.id,
        name: nameCtrl.text,
        code: codeCtrl.text,
        color: colorCtrl.text.trim().isEmpty ? null : colorCtrl.text.trim(),
        isActive: isActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            station == null
                ? 'Hazırlama alanı eklendi.'
                : 'Hazırlama alanı güncellendi.',
          ),
        ),
      );
      _triggerAssignmentsRefresh(reason: 'stationSaved');
      _triggerProductsRefresh(reason: 'stationSaved');
    } finally {
      nameCtrl.dispose();
      codeCtrl.dispose();
      colorCtrl.dispose();
    }
  }

  Future<void> _showPrinterEditor({PrinterModel? printer}) async {
    if (!mounted) return;
    final saved = await showPrinterWizard(
      context,
      restaurantId: widget.restaurantId,
      existing: printer,
    );
    if (saved == null) return;
    _triggerPrintersRefresh(
      reason: 'printerSaved',
      selectedPrinterId: saved.id,
      printerCount: 1,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          printer == null ? 'Yazıcı eklendi.' : 'Yazıcı güncellendi.',
        ),
      ),
    );
  }

  Future<void> _deletePrinter(
    PrinterModel printer, {
    bool force = false,
  }) async {
    if (!force) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Yazıcıyı sil'),
            content: Text(
              '"${printer.name}" yazıcısını silmek istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sil'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _deletingPrinterIds.add(printer.id);
      _printStationError = null;
    });
    try {
      final result = await _printOrchestrator.deletePrinter(
        restaurantId: widget.restaurantId,
        printerId: printer.id,
        force: force,
      );
      if (!result.ok && result.status == 'printer_in_use' && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Yazıcı eşleştirmede kullanılıyor'),
              content: const Text(
                'Bu yazıcı eşleştirmelerde kullanılıyor. Silersen eşleştirme kaldırılacak.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Yine de sil'),
                ),
              ],
            );
          },
        );
        if (confirmed == true && mounted) {
          setState(() {
            _deletingPrinterIds.remove(printer.id);
          });
          await _deletePrinter(printer, force: true);
        }
        return;
      }
      if (!result.ok) {
        throw Exception(result.message);
      }
      await _loadPrintStationState();
      _triggerPrintersRefresh(
        reason: 'printerDeleted',
        selectedPrinterId: printer.id,
      );
      _triggerAssignmentsRefresh(
        reason: 'printerDeleted',
        selectedPrinterId: printer.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printStationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingPrinterIds.remove(printer.id);
        });
      }
    }
  }

  void _syncProductRoutingCacheFromLists(
    List<SellerProduct> products,
    List<StationModel> stations,
  ) {
    final stationById = <String, ({String name, String code})>{
      for (final station in stations)
        station.id: (name: station.name, code: station.code),
    };
    KitchenProductMappingCacheStore.syncProductRoutingUi(
      restaurantId: widget.restaurantId,
      rows: <({String productId, String productName, String? stationId})>[
        for (final product in products)
          (
            productId: product.id,
            productName: product.name,
            stationId: _productStationDraft[product.id] ?? product.stationId,
          ),
      ],
      stationById: stationById,
    );
  }

  Future<void> _persistProductStationSelectionToDb(
    SellerProduct product,
    String? stationId,
    List<StationModel> stations,
  ) async {
    if (stationId == null || stationId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('products')
          .update({
            'station_id': stationId,
            'printer_routing_enabled':
                _productRoutingDraft[product.id] ?? product.printerRoutingEnabled,
          })
          .eq('id', product.id)
          .eq('seller_id', widget.restaurantId);
      StationModel? station;
      for (final candidate in stations) {
        if (candidate.id == stationId) {
          station = candidate;
          break;
        }
      }
      if (station == null) return;
      final header = KitchenTicketHeaderResolver.productionHeaderLabel(
        stationName: station.name,
        stationCode: station.code,
      );
      await KitchenProductMappingCacheStore.persistSingleProduct(
        restaurantId: widget.restaurantId,
        productId: product.id,
        productName: product.name,
        mapping: ProductStationMapping(
          stationId: stationId,
          stationName: header == kKitchenGeneralStationLabel
              ? station.name
              : header,
          stationCode: station.code.toUpperCase(),
        ),
      );
    } catch (_) {
      // Dropdown seçimi bellek önbelleğinde; DB yazımı best-effort.
    }
  }

  void _upsertProductMappingCache(
    SellerProduct product,
    String? stationId,
    List<StationModel> stations,
  ) {
    if (stationId == null || stationId.isEmpty) return;
    StationModel? station;
    for (final candidate in stations) {
      if (candidate.id == stationId) {
        station = candidate;
        break;
      }
    }
    if (station == null) return;
    final header = KitchenTicketHeaderResolver.productionHeaderLabel(
      stationName: station.name,
      stationCode: station.code,
    );
    KitchenProductMappingCacheStore.upsertProductSync(
      restaurantId: widget.restaurantId,
      productId: product.id,
      productName: product.name,
      mapping: ProductStationMapping(
        stationId: stationId,
        stationName:
            header == kKitchenGeneralStationLabel ? station.name : header,
        stationCode: station.code.toUpperCase(),
      ),
      source: 'dropdown_selection',
    );
  }

  Future<void> _saveProductRouting(SellerProduct product) async {
    if (_productSavingMap[product.id] == true) return;
    final selectedStation =
        _productStationDraft[product.id] ?? product.stationId;
    final routingEnabled =
        _productRoutingDraft[product.id] ?? product.printerRoutingEnabled;

    _logPrinterSettings(
      'Products',
      'mappingChanged restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=${_logField(selectedStation ?? '')} emptyBranch=pending productId=${product.id}',
    );
    setState(() {
      _productSavingMap[product.id] = true;
      _productSaveErrorMap.remove(product.id);
    });
    try {
      await Supabase.instance.client
          .from('products')
          .update({
            'station_id': selectedStation,
            'printer_routing_enabled': routingEnabled,
          })
          .eq('id', product.id)
          .eq('seller_id', widget.restaurantId);

      _logPrinterSettings(
        'Products',
        'saveSuccess restaurantId=${widget.restaurantId} areaCount=- productCount=1 selectedAreaId=${_logField(selectedStation ?? '')} emptyBranch=save_success productId=${product.id}',
      );

      if (!mounted) return;
      var stationName = product.stationName?.trim() ?? '';
      var stationCode = (product.stationCode ?? '').trim().toUpperCase();
      if (selectedStation != null && selectedStation.isNotEmpty) {
        try {
          final stations = await _stationRepository.fetchStations(
            widget.restaurantId,
          );
          for (final station in stations) {
            if (station.id == selectedStation) {
              stationName = station.name;
              stationCode = station.code.toUpperCase();
              break;
            }
          }
        } catch (_) {
          // Cache güncellemesi best-effort; hub print cache-only kalır.
        }
        final headerLabel = KitchenTicketHeaderResolver.productionHeaderLabel(
          stationName: stationName,
          stationCode: stationCode,
        );
        final mapping = ProductStationMapping(
          stationId: selectedStation,
          stationName: headerLabel == kKitchenGeneralStationLabel
              ? stationName
              : headerLabel,
          stationCode: stationCode,
        );
        unawaited(
          KitchenProductMappingCacheStore.persistSingleProduct(
            restaurantId: widget.restaurantId,
            productId: product.id,
            productName: product.name,
            mapping: mapping,
          ),
        );
      }
      logProductStationMappingLoaded(
        productId: product.id,
        productName: product.name,
        stationId: selectedStation ?? '',
        stationName: stationName,
        stationCode: stationCode,
        source: 'product_mapping_ui_save',
      );
      setState(() {
        _productStationDraft.remove(product.id);
        _productRoutingDraft.remove(product.id);
        _productSavingMap.remove(product.id);
        _productSavedMap[product.id] = true;
      });
      // Show saved state for 1.5s, then sync from Supabase.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _productSavedMap.remove(product.id));
        _triggerProductsRefresh(
          reason: 'productMappingSaved',
          selectedAreaId: selectedStation,
        );
      });
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Products',
        'saveFail restaurantId=${widget.restaurantId} areaCount=- productCount=1 selectedAreaId=${_logField(selectedStation ?? '')} emptyBranch=save_error productId=${product.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final msg = error.toString();
      setState(() {
        _productSavingMap.remove(product.id);
        _productSaveErrorMap[product.id] = msg.length > 80
            ? '${msg.substring(0, 80)}…'
            : msg;
      });
    }
  }

  Stream<List<PrinterModel>> _createPrintersStream() {
    _logPrinterSettings(
      'Printers',
      'fetchStart restaurantId=${widget.restaurantId} printerCount=- emptyBranch=pending',
    );
    return _printerRepository
        .watchPrinters(widget.restaurantId)
        .map((printers) {
          final emptyBranch = printers.isEmpty
              ? 'no_printers_db_rows'
              : 'has_rows';
          _logPrinterSettings(
            'Printers',
            'fetchSuccess restaurantId=${widget.restaurantId} printerCount=${printers.length} emptyBranch=$emptyBranch',
          );
          return _filterPrintersToCurrentScan(printers);
        })
        .handleError((Object error, StackTrace stackTrace) {
          _logPrinterSettings(
            'Printers',
            'fetchFail restaurantId=${widget.restaurantId} printerCount=- emptyBranch=fetch_error',
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> _hardResetPrinters() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hard Reset Printers'),
          content: const Text(
            'Bu islem yerel config, printer kayitlari ve rol eslestirmelerini temizler. Sonrasinda yeni tarama yapilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sifirla'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _runningHardReset = true;
      _printStationError = null;
    });
    try {
      final result = await _printOrchestrator.hardResetPrinters(
        restaurantId: widget.restaurantId,
      );
      await _loadPrintStationState();
      _triggerPrintersRefresh(reason: 'hardReset');
      _triggerAssignmentsRefresh(reason: 'hardReset');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printStationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningHardReset = false;
        });
      }
    }
  }

  Widget _buildStationsTab() {
    return StreamBuilder<List<StationModel>>(
      stream: _stationRepository.watchStations(widget.restaurantId),
      builder: (context, snapshot) {
        final stations = snapshot.data ?? const <StationModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toolbar ─────────────────────────────────────────────────
            _buildTabToolbar(
              label: 'Hazırlama Alanları',
              count: stations.length,
              onAdd: () => _showStationEditor(),
              addLabel: 'Alan Ekle',
            ),
            const Divider(height: 1),
            // ── List ────────────────────────────────────────────────────
            Expanded(
              child:
                  snapshot.connectionState == ConnectionState.waiting &&
                      stations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : stations.isEmpty
                  ? const Center(
                      child: Text(
                        'Kayıtlı hazırlama alanı bulunamadı.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      itemCount: stations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        return _buildStationRow(stations[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrintSystemControlCard() {
    final isQueueDisabled = _isQueuePrintSystemDisabled;
    final uiEnabled = !isQueueDisabled && _printSystemEnabled;
    final statusLabel = !_printSystemEnabledLoaded
        ? 'Durum yükleniyor...'
        : isQueueDisabled
        ? 'Baskı sistemi kapalı'
        : _printSystemStateLabel(_printSystemEnabled);
    final statusColor = _printSystemEnabledLoaded
        ? (isQueueDisabled
              ? const Color(0xFFDC2626)
              : (_printSystemEnabled
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626)))
        : const Color(0xFF6B7280);
    final effectiveEnabled =
        _printSystemEnabledLoaded ? uiEnabled : null;
    final bannerColor = effectiveEnabled == null
        ? const Color(0xFFF3F4F6)
        : effectiveEnabled
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFFEDD5);
    final bannerBorder = effectiveEnabled == null
        ? const Color(0xFFD1D5DB)
        : effectiveEnabled
        ? const Color(0xFF16A34A)
        : const Color(0xFFEA580C);
    final buttonLabel = uiEnabled
        ? 'Baskı Sistemini Kapat'
        : 'Baskı Sistemini Aç';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Baskı Sistemi',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !_printSystemEnabledLoaded
                          ? 'Bridge ve bulut ayarı yükleniyor...'
                          : isQueueDisabled
                          ? 'Bridge Queue: print_system_disabled'
                          : _printSystemDescription(_printSystemEnabled),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Switch.adaptive(
                    value: uiEnabled,
                    onChanged:
                        !_printSystemEnabledLoaded || _savingPrintSystemEnabled
                        ? null
                        : _togglePrintSystemEnabled,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed:
                        !_printSystemEnabledLoaded || _savingPrintSystemEnabled
                        ? null
                        : () => _togglePrintSystemEnabled(!uiEnabled),
                    icon: _savingPrintSystemEnabled
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            uiEnabled
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 18,
                          ),
                    label: Text(buttonLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: uiEnabled
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF15803D),
                      side: BorderSide(
                        color: uiEnabled
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF86EFAC),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bannerBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  uiEnabled
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: bannerBorder,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _printSystemEnabledLoaded
                        ? _printSystemBannerText(uiEnabled)
                        : 'Baskı sistemi durumu yükleniyor...',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: effectiveEnabled == null
                          ? const Color(0xFF374151)
                          : effectiveEnabled
                          ? const Color(0xFF166534)
                          : const Color(0xFF9A3412),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_printSystemSyncNotice != null &&
              _printSystemSyncNotice!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _printSystemSyncNotice!,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Bridge runtime: ${_printSystemStateDetailLabel(_localPrintSystemEnabled)}'
            ' • Bulut ayarı: ${_printSystemStateDetailLabel(_remotePrintSystemEnabled)}'
            ' • Kaynak: ${_printSystemSourceIsLocalRuntime ? 'Yerel bridge runtime' : 'Bulut ayarı'}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          if (_printSystemError != null &&
              _printSystemError!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _printSystemError!,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFB91C1C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _constrainedSection(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    );
  }

  Widget _responsive2Col({
    required Widget left,
    required Widget right,
    double gap = 12,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoCol = constraints.maxWidth >= 900;
        if (!isTwoCol) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: gap),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: gap),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  BoxDecoration _dashboardCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildPrintStationTab() {
    final queueRuntime = _localQueueStatus?['queue'];
    final selectedStationPlatform = _printStationService
        .normalizeStationPlatform(_selectedPrintStationPlatform);
    final runtime = queueRuntime is Map<String, dynamic>
        ? queueRuntime['runtime']
        : queueRuntime is Map
        ? Map<String, dynamic>.from(queueRuntime)['runtime']
        : null;
    final runtimeMap = runtime is Map<String, dynamic>
        ? runtime
        : runtime is Map
        ? Map<String, dynamic>.from(runtime)
        : const <String, dynamic>{};
    final queueStatus = runtimeMap['status']?.toString() ?? 'idle';
    final lastSeenAt =
        _remotePrintStationConfig?['last_seen_at']?.toString() ?? '-';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _constrainedSection(_buildPrintSystemControlCard()),
        const SizedBox(height: 12),
        if ((_printStationError ?? '').isNotEmpty &&
            (_lastCupsQueueBlockedDetails?['suggested_action'] == 'clear_queue'))
          _constrainedSection(
            Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Yazıcı kuyruğunda bekleyen işler var. Önce kuyruğu temizleyin.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _clearingCupsQueue
                      ? null
                      : () async {
                          setState(() => _clearingCupsQueue = true);
                          try {
                            // Best-effort clear for the active queue configured on bridge.
                            final svc = LocalPrintService();
                            final res = await svc.clearCupsQueue();
                            svc.dispose();
                            if (!mounted) return;
                            if (res?['ok'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Kuyruk temizlendi.'),
                                ),
                              );
                              await _loadPrintStationState();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Kuyruk temizlenemedi: ${res?['error'] ?? 'Bilinmeyen hata'}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kuyruk temizlenemedi: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _clearingCupsQueue = false);
                            }
                          }
                        },
                  child: _clearingCupsQueue
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kuyruğu Temizle'),
                ),
              ],
            ),
          ),
          ),
        if (_hasLegacyRoleMapping()) ...[
          _constrainedSection(_buildLegacyRoleMappingRepairCard()),
          const SizedBox(height: 12),
        ],
        StreamBuilder<List<PrinterModel>>(
          stream: _printersStream,
          builder: (context, snapshot) {
            final dbPrinters = snapshot.data ?? const <PrinterModel>[];
            final suggested = _suggestedUnsavedLocalPrinter(dbPrinters);
            if (suggested == null) return const SizedBox.shrink();
            return Column(
              children: [
                _constrainedSection(
                  _buildUnsavedLocalPrinterCard(
                    printer: suggested,
                    dbPrinters: dbPrinters,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        _constrainedSection(
          Container(
          padding: const EdgeInsets.all(16),
          decoration: _dashboardCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu cihaz yazıcı merkezi mi?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _isThisDevicePrintStation
                    ? 'Bu cihaz Yazıcı Merkezi olarak işaretli. Adisyon ve mutfak fişleri bridge arka plan servisinden basılır.'
                    : 'Bu cihaz sadece sipariş gönderecek. Yazdırma işlemi Yazıcı Merkezi cihazından yapılacak.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yazıcı Merkezi sistemi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'windows',
                          label: Text('Windows'),
                          icon: Icon(Icons.desktop_windows_outlined),
                        ),
                        ButtonSegment<String>(
                          value: 'macos',
                          label: Text('MacBook'),
                          icon: Icon(Icons.laptop_mac_outlined),
                        ),
                      ],
                      selected: <String>{selectedStationPlatform},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        setState(() {
                          _selectedPrintStationPlatform = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedStationPlatform == 'windows'
                          ? 'Windows sistemi secilirse bridge Windows yazici servisi icin ayarlanir. Diger tum cihazlar sadece is gonderir.'
                          : 'MacBook sistemi secilirse bridge macOS/CUPS veya USB direct yolu icin ayarlanir. Diger tum cihazlar sadece is gonderir.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _savingPrintStation
                        ? null
                        : _savePrintStationMode,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Bu cihazı Yazıcı Merkezi yap'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await showPrinterSystemSetupWizard(
                        context,
                        restaurantId: widget.restaurantId,
                      );
                      if (!mounted) return;
                      await _loadPrintStationState();
                    },
                    icon: const Icon(Icons.settings_suggest_outlined),
                    label: const Text('Bridge kurulumunu ac'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _savingPrintStation
                        ? null
                        : _setNormalDeviceMode,
                    icon: const Icon(Icons.send_to_mobile_outlined),
                    label: const Text('Bu cihaz sadece sipariş gönderecek'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _savingPrintStation
                        ? null
                        : () => _loadPrintStationState(invalidateBridgeCache: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Durumu yenile'),
                  ),
                ],
              ),
              if (_loadingPrintStationState) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (_printStationError != null &&
                  _printStationError!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _printStationError!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
        _constrainedSection(
          _responsive2Col(
            left: _statusTile(
              title: 'Yazıcı Merkezi',
              value: _isPrintStationOnline ? 'Cevrimici' : 'Cevrimdisi',
              subtitle:
                  'Sistem: ${_stationPlatformTitle(_remotePrintStationConfig?['device_platform']?.toString() ?? selectedStationPlatform)}\n'
                  'Son heartbeat: $lastSeenAt\n'
                  'Bridge status: ${_remotePrintStationConfig?['bridge_status'] ?? '-'}\n'
                  'Yerel runtime: ${_isLocalPrintRuntimeOnline ? 'hazır' : 'bekleniyor'}',
              accent: _isPrintStationOnline
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
            right: _statusTile(
              title: 'Bridge Queue',
              value: queueStatus,
              subtitle:
                  'runtime=${runtimeMap['running'] ?? false}\nlastError=${runtimeMap['lastError'] ?? '-'}',
              accent: queueStatus == 'error'
                  ? const Color(0xFFDC2626)
                  : queueStatus == 'print_system_disabled'
                  ? const Color(0xFFEA580C)
                  : const Color(0xFF2563EB),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _constrainedSection(
          Container(
          padding: const EdgeInsets.all(16),
          decoration: _dashboardCardDecoration(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leftChildren = <Widget>[
                const Row(
                  children: [
                    Icon(Icons.usb_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Yerel Bridge ve Test',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bu sekme sadece bridge durumunu, yerel taramayı, test fişlerini ve aktif yazıcı kayıtlarını gösterir. Adisyon, mutfak ve alan eşleştirmeleri yalnızca Eşleştirme sekmesinden yönetilir.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                if (_usbCupsConflictWarning) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Text(
                      'Bu yazıcı hem CUPS hem USB Direct olarak görünüyor. '
                      'Termal yazıcı için USB Direct kullanılacaksa CUPS kaydı kaldırılmalı.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A3412),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InlineStatusChip(
                      label: _wizardStatusLabel(_localSetupStatusKey()),
                      color: _wizardStatusColor(_localSetupStatusKey()),
                    ),
                    _InlineStatusChip(
                      label: _bridgeSummaryLabel(),
                      color: _bridgeHealthy
                          ? const Color(0xFF15803D)
                          : _bridgeReachable
                          ? const Color(0xFFB45309)
                          : const Color(0xFFB91C1C),
                    ),
                    _InlineStatusChip(
                      label: _hasDetectedPrinters
                          ? '${_bridgePrinters.length} yazici bulundu'
                          : 'Yazici bekleniyor',
                      color: _hasDetectedPrinters
                          ? const Color(0xFF15803D)
                          : const Color(0xFF6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GuidedStepTile(
                  stepNumber: '1',
                  title: 'Bridge ve sistem kontrolü',
                  subtitle: _bridgeSummaryMessage(),
                  done: _bridgeHealthy,
                ),
                for (final check
                    in ((_localSetupPrerequisites?['checks'] as List?)
                            ?.whereType<Map>()
                            .map((entry) => Map<String, dynamic>.from(entry))
                            .toList(growable: false) ??
                        const <Map<String, dynamic>>[]))
                  _GuidedStepTile(
                    stepNumber: '•',
                    title: check['label']?.toString() ?? 'Kontrol',
                    subtitle: check['message']?.toString() ?? '',
                    done: check['ok'] == true,
                    compact: true,
                  ),
                _GuidedStepTile(
                  stepNumber: '2',
                  title: 'Yerel yazicilari tara',
                  subtitle:
                      _printerDiscoveryGuidance() ??
                      (_hasDetectedPrinters
                          ? 'Tarama tamamlandi. Kayitli yazici ve eslestirme ozetleri asagida gosteriliyor.'
                          : 'Önce yazicilari tara butonunu kullanin.'),
                  done: _hasDetectedPrinters,
                ),
                _GuidedStepTile(
                  stepNumber: '3',
                  title: 'Test fişi gönder',
                  subtitle:
                      'Adisyon ve mutfak testleri, Eşleştirme sekmesinde kayıtlı aktif yazıcıları kullanır.',
                  done: _selectedReceiptPrinterId != null &&
                      _selectedKitchenPrinterId != null,
                ),
                if (_staleBridgePrinters.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      '${_staleBridgePrinters.length} kayıtlı yazıcı canlı taramada yok. '
                      'Eski Mac/CUPS eşlemesi aktif rol olarak kullanılamaz; yeni bir Windows yazıcısı seçin.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF991B1B),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _openGuidedSetup,
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      label: const Text('Adim adim kurulum'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _loadPrintStationState(invalidateBridgeCache: true),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Yazicilari tara'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _runningHardReset ? null : _hardResetPrinters,
                      icon: _runningHardReset
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restart_alt_rounded),
                      label: const Text('Hard Reset Printers'),
                    ),
                    if (!_hasDetectedPrinters)
                      OutlinedButton.icon(
                        onPressed: () => _showPrinterEditor(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Yazici ekle'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        DefaultTabController.of(context).animateTo(3);
                      },
                      icon: const Icon(Icons.alt_route_rounded),
                      label: const Text('Yazıcı Eşleştir'),
                    ),
                  ],
                ),
              ];

              final rightChildren = <Widget>[
                if (_printerDiscoveryGuidance() != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      _printerDiscoveryGuidance()!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF92400E),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSelectedPrinterSummaryCard(),
                if ((_selectedReceiptPrinterId != null ||
                        _selectedKitchenPrinterId != null) &&
                    !_turkishEncodingVerified) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Türkçe karakter doğrulaması yapılmadı. '
                      'Ürün adları bozuk basılabilir; Türkçe Karakter Testi ile doğru codepage seçin.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF92400E),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                if (_selectedReceiptPrinterId != null ||
                    _selectedKitchenPrinterId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _turkishEncodingVerified
                            ? Icons.verified_outlined
                            : Icons.warning_amber_outlined,
                        size: 16,
                        color: _turkishEncodingVerified
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _turkishEncodingVerified
                            ? 'Türkçe karakter doğrulandı'
                            : 'Türkçe karakter doğrulanmadı',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _turkishEncodingVerified
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, inner) {
                    final isGrid = inner.maxWidth >= 520;
                    Widget item(Widget child) => SizedBox(
                      width: isGrid ? (inner.maxWidth - 10) / 2 : double.infinity,
                      child: child,
                    );
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        item(
                          OutlinedButton.icon(
                            onPressed: _selectedReceiptPrinterId == null &&
                                    _selectedKitchenPrinterId == null
                                ? null
                                : _openTurkishEncodingCalibration,
                            icon: const Icon(Icons.translate_outlined),
                            label: const Text('Türkçe Karakter Testi'),
                          ),
                        ),
                        item(
                          OutlinedButton.icon(
                            onPressed: _selectedReceiptPrinterId == null ||
                                    _testingPrintStation
                                ? null
                                : () => _sendPrintStationTest(kitchen: false),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Adisyon test fişi'),
                          ),
                        ),
                        item(
                          OutlinedButton.icon(
                            onPressed: _selectedKitchenPrinterId == null ||
                                    _testingPrintStation
                                ? null
                                : () => _sendPrintStationTest(kitchen: true),
                            icon: const Icon(Icons.restaurant_menu_outlined),
                            label: const Text('Mutfak test fişi'),
                          ),
                        ),
                        item(
                          OutlinedButton.icon(
                            onPressed: _selectedReceiptPrinterId == null ||
                                    _testingPrintStation
                                ? null
                                : _sendDirectAdisyonRoleDebugPrint,
                            icon: const Icon(Icons.print_outlined),
                            label: const Text(
                              'Seçili Adisyon Yazıcısına Direkt Bas',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ];

              final isTwoCol = constraints.maxWidth >= 980;
              if (!isTwoCol) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...leftChildren,
                    const SizedBox(height: 12),
                    ...rightChildren,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: leftChildren,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rightChildren,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ),
      ],
    );
  }

  bool _hasLegacyRoleMapping() {
    final cfg = _localRoleConfig;
    if (cfg == null) return false;
    final receipt = cfg.receiptSelection?.printer;
    final kitchen = cfg.kitchenSelection?.printer;
    final receiptLegacy =
        receipt != null && (receipt.printerRecordId?.trim().isEmpty ?? true);
    final kitchenLegacy =
        kitchen != null && (kitchen.printerRecordId?.trim().isEmpty ?? true);
    return receiptLegacy || kitchenLegacy;
  }

  Widget _buildLegacyRoleMappingRepairCard() {
    final cfg = _localRoleConfig;
    final receiptName = cfg?.receiptSelection?.printer.queueName ??
        cfg?.receiptSelection?.printer.displayName ??
        '';
    final kitchenName = cfg?.kitchenSelection?.printer.queueName ??
        cfg?.kitchenSelection?.printer.displayName ??
        '';
    final details = <String>[
      if (receiptName.isNotEmpty) 'Adisyon: $receiptName',
      if (kitchenName.isNotEmpty) 'Mutfak: $kitchenName',
    ].join('\n');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu eşleştirme eski formatta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Yazıcı seçimi bridge kimliğiyle kayıtlı görünüyor. '
            'Bunu DB UUID formatına onarıp kalıcı hale getirelim.\n'
            '$details',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _savingRoleMappings
                ? null
                : () async {
                    setState(() {
                      _savingRoleMappings = true;
                      _printStationError = null;
                    });
                    try {
                      final result = await _printOrchestrator.repairLegacyRoleMappings(
                        restaurantId: widget.restaurantId,
                        flowName: 'legacy_mapping_repair',
                        source: 'print_center',
                      );
                      if (!result.ok) {
                        throw Exception(result.technicalMessage ?? result.message);
                      }
                      await _loadPrintStationState();
                      _triggerPrintersRefresh(reason: 'legacyMappingRepaired');
                      _triggerAssignmentsRefresh(reason: 'legacyMappingRepaired');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        _printStationError = e.toString().replaceFirst('Exception: ', '');
                      });
                    } finally {
                      if (mounted) {
                        setState(() => _savingRoleMappings = false);
                      }
                    }
                  },
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('Onar ve eşleştir'),
          ),
        ],
      ),
    );
  }

  UnifiedPrinterModel? _suggestedUnsavedLocalPrinter(List<PrinterModel> dbPrinters) {
    if (_bridgePrinters.isEmpty) return null;
    if (dbPrinters.isNotEmpty) return null;

    final os = _printOrchestrator.detectOs();
    final candidates = _bridgePrinters
        .whereType<Map<String, dynamic>>()
        .map((p) => UnifiedPrinterModel.fromBridgeMap(p, os: os))
        .where((p) => p.queueName.trim().isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    // Prefer CUPS when the same physical POS58 exists in both CUPS + USB direct.
    bool looksPos58(UnifiedPrinterModel p) {
      final name = '${p.displayName} ${p.queueName}'.toLowerCase();
      final isStm = name.contains('stmicroelectronics') || name.contains('pos58');
      final vid = (p.vendorId ?? '').toLowerCase();
      final pid = (p.productId ?? '').toLowerCase();
      final isKnownUsb = vid.contains('0416') && pid.contains('5011');
      return isStm || isKnownUsb;
    }
    candidates.sort((a, b) {
      final aScore = (a.canPrint ? 10 : 0) +
          (a.isAvailable ? 5 : 0) +
          (looksPos58(a) ? 10 : 0) +
          (a.backend == DesktopPrinterBackend.cups ? 3 : 0);
      final bScore = (b.canPrint ? 10 : 0) +
          (b.isAvailable ? 5 : 0) +
          (looksPos58(b) ? 10 : 0) +
          (b.backend == DesktopPrinterBackend.cups ? 3 : 0);
      return bScore.compareTo(aScore);
    });
    return candidates.first;
  }

  Widget _buildUnsavedLocalPrinterCard({
    required UnifiedPrinterModel printer,
    required List<PrinterModel> dbPrinters,
  }) {
    final backendLabel = printer.backend == DesktopPrinterBackend.usbDirect
        ? 'USB Direct'
        : (printer.backend == DesktopPrinterBackend.cups ? 'CUPS' : 'Windows');
    final queue = printer.queueName.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yerel yazıcı bulundu ama kayıtlı değil',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Yazıcı adı: $queue\nBackend: $backendLabel',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          if (_adoptLocalPrinterError != null &&
              _adoptLocalPrinterError!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _adoptLocalPrinterError!,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFB91C1C),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _adoptingLocalPrinter
                    ? null
                    : () => _adoptLocalPrinter(printer: printer, action: 'save'),
                child: _adoptingLocalPrinter
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Yazıcıyı Kaydet'),
              ),
              OutlinedButton(
                onPressed: _adoptingLocalPrinter
                    ? null
                    : () => _adoptLocalPrinter(
                          printer: printer,
                          action: 'save_receipt',
                        ),
                child: const Text('Kaydet ve Adisyon Yazıcısı Yap'),
              ),
              OutlinedButton(
                onPressed: _adoptingLocalPrinter
                    ? null
                    : () => _adoptLocalPrinter(
                          printer: printer,
                          action: 'save_kitchen',
                        ),
                child: const Text('Kaydet ve Mutfak Yazıcısı Yap'),
              ),
              OutlinedButton(
                onPressed: _adoptingLocalPrinter
                    ? null
                    : () => _adoptLocalPrinter(
                          printer: printer,
                          action: 'save_both',
                        ),
                child: const Text('Kaydet ve İkisi İçin Kullan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _canonicalCodeForPrinter(UnifiedPrinterModel printer) {
    final backend = printer.backend.value.trim().toUpperCase();
    final queue = printer.queueName.trim().isNotEmpty
        ? printer.queueName.trim()
        : printer.displayName.trim();
    final normalizedQueue = queue
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toUpperCase();
    final core = normalizedQueue.isEmpty ? 'PRINTER' : normalizedQueue;
    final suffix = backend.isEmpty ? '' : '_$backend';
    final raw = 'AUTO_$core$suffix';
    return raw.length > 32 ? raw.substring(0, 32) : raw;
  }

  Future<void> _adoptLocalPrinter({
    required UnifiedPrinterModel printer,
    required String action,
  }) async {
    if (!_printSystemEnabled) {
      setState(() {
        _adoptLocalPrinterError =
            'Baskı sistemi kapalı. Önce Baskı Sistemini Aç butonunu kullanın.';
      });
      return;
    }
    setState(() {
      _adoptingLocalPrinter = true;
      _adoptLocalPrinterError = null;
    });
    try {
      final code = _canonicalCodeForPrinter(printer);
      final name = printer.displayName.trim().isNotEmpty
          ? printer.displayName.trim()
          : printer.queueName.trim();
      final deviceIdentifier = (printer.raw['deviceIdentifier'] ??
              printer.raw['device_identifier'] ??
              printer.queueName)
          .toString()
          .trim();
      final saved = await _printerRepository.upsertPrinter(
        restaurantId: widget.restaurantId,
        name: name.isEmpty ? printer.queueName : name,
        code: code,
        // DB constraint: ('network','usb','bluetooth') — local bridge printers are stored as USB.
        connectionType: PrinterModel.usbConnectionType,
        ipAddress: PrinterModel.localDefaultHost,
        port: PrinterModel.localDefaultPort,
        deviceIdentifier: deviceIdentifier.isEmpty ? printer.queueName : deviceIdentifier,
        isActive: true,
        assignedRoles: const [],
        supportsCut: true,
        paperWidthMm: 58,
      );

      if (action == 'save_receipt') {
        final result = await _printOrchestrator.saveSingleRoleSelection(
          restaurantId: widget.restaurantId,
          role: PrinterSetupRole.adisyon,
          printerRecordId: saved.id,
          source: 'print_center',
        );
        if (!result.ok) throw Exception(result.message);
      } else if (action == 'save_kitchen') {
        final result = await _printOrchestrator.saveSingleRoleSelection(
          restaurantId: widget.restaurantId,
          role: PrinterSetupRole.mutfak,
          printerRecordId: saved.id,
          source: 'print_center',
        );
        if (!result.ok) throw Exception(result.message);
      } else if (action == 'save_both') {
        final shouldConfigureLocalBridge = _isThisDevicePrintStation;
        final stationPlatform = _selectedPrintStationPlatform.isEmpty
            ? (_remotePrintStationConfig?['device_platform']?.toString())
            : _selectedPrintStationPlatform;
        final result = await _printOrchestrator.savePrinterRoles(
          restaurantId: widget.restaurantId,
          receiptPrinterId: saved.id,
          kitchenPrinterId: saved.id,
          session: shouldConfigureLocalBridge
              ? Supabase.instance.client.auth.currentSession
              : null,
          markThisDeviceAsPrintStation: shouldConfigureLocalBridge,
          stationPlatform: stationPlatform,
          flowName: 'adopt_local_printer_save_both',
          source: 'print_center',
        );
        if (!result.ok) throw Exception(result.message);
      }

      await _loadPrintStationState();
      _triggerPrintersRefresh(reason: 'adoptLocalPrinter');
      _triggerAssignmentsRefresh(reason: 'adoptLocalPrinter');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yazıcı kaydedildi.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _adoptLocalPrinterError =
            'Yazıcı kaydedilemedi. Yetki/bağlantı hatası olabilir.\nTeknik detay: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() => _adoptingLocalPrinter = false);
      }
    }
  }

  Widget _statusTile({
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPrinterSummaryCard() {
    Widget row({
      required String title,
      required String? printerId,
      required VoidCallback onGoToMapping,
    }) {
      final normalizedId = printerId?.trim();
      final mappedName = title.contains('adisyon')
          ? (_selectedReceiptPrinterLabel ?? _printerNameById(normalizedId))
          : (_selectedKitchenPrinterLabel ?? _printerNameById(normalizedId));
      final hasPrinter = normalizedId != null && normalizedId.isNotEmpty;
      final statusText = hasPrinter
          ? mappedName
          : (title.contains('adisyon')
                ? 'Adisyon yazıcısı eşleştirilmedi'
                : 'Mutfak yazıcısı eşleştirilmedi');
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(
              hasPrinter ? Icons.check_circle_outline : Icons.info_outline,
              size: 18,
              color: hasPrinter
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasPrinter) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onGoToMapping,
                child: const Text('Yazıcı Eşleştir'),
              ),
            ],
          ],
        ),
      );
    }

    void goToMappingTab() {
      DefaultTabController.of(context).animateTo(3);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(
          title: 'Aktif adisyon yazıcısı',
          printerId: _selectedReceiptPrinterId,
          onGoToMapping: goToMappingTab,
        ),
        const SizedBox(height: 10),
        row(
          title: 'Aktif mutfak yazıcısı',
          printerId: _selectedKitchenPrinterId,
          onGoToMapping: goToMappingTab,
        ),
      ],
    );
  }

  Widget _buildStationRow(StationModel station) {
    final isActive = station.isActive;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD1D5DB),
              shape: BoxShape.circle,
            ),
          ),
          // Name + code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  station.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  station.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Active badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'Aktif' : 'Pasif',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF15803D)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle
          SizedBox(
            width: 44,
            height: 28,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: isActive,
                activeThumbColor: const Color(0xFF16A34A),
                activeTrackColor: const Color(0xFFBBF7D0),
                onChanged: (v) =>
                    _stationRepository.setStationActive(station.id, v),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Edit
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 17,
              onPressed: () => _showStationEditor(station: station),
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintersTab() {
    return StreamBuilder<List<PrinterModel>>(
      key: ValueKey<String>('printers-$_printersRefreshNonce'),
      stream: _printersStream,
      builder: (context, snapshot) {
        final printers = snapshot.data ?? const <PrinterModel>[];
        if (snapshot.hasError) {
          _logPrinterSettings(
            'Printers',
            'fetchFail restaurantId=${widget.restaurantId} printerCount=${printers.length} emptyBranch=stream_error',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrintersTabToolbar(printers.length),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Yazıcılar yüklenemedi.'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (printers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Kayıtlı yazıcı bulunamadı. Bu sekme veritabanındaki yazıcı kayıtlarını listeler.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: printers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _buildPrinterRow(printers[index]);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrinterRow(PrinterModel printer) {
    final isActive = printer.isActive;
    final isDeleting = _deletingPrinterIds.contains(printer.id);
    final connectionLabel = printer.connectionTypeLabel;
    final targetHost = printer.targetHost;
    final targetRoute = printer.targetRoute;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD1D5DB),
              shape: BoxShape.circle,
            ),
          ),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row: name + connection badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        printer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        connectionLabel,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Endpoint
                Text(
                  targetRoute.isNotEmpty
                      ? '$targetHost$targetRoute'
                      : targetHost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Active badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'Aktif' : 'Pasif',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF15803D)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle
          SizedBox(
            width: 44,
            height: 28,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: isActive,
                activeThumbColor: const Color(0xFF16A34A),
                activeTrackColor: const Color(0xFFBBF7D0),
                onChanged: isDeleting
                    ? null
                    : (value) async {
                        await _printerRepository.setPrinterActive(
                          printer.id,
                          value,
                        );
                        _triggerAssignmentsRefresh(
                          reason: 'printerActiveChanged',
                        );
                      },
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 17,
              onPressed: isDeleting ? null : () => _deletePrinter(printer),
              icon: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            ),
          ),
          const SizedBox(width: 4),
          // Edit
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 17,
              onPressed: isDeleting
                  ? null
                  : () => _showPrinterEditor(printer: printer),
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingTab() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey<String>('assignments-$_assignmentsRefreshNonce'),
      future: _assignmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Eşleştirmeler yüklenemedi.'));
        }

        final stations = snapshot.data?[0] as List<StationModel>? ?? const [];
        final printers = snapshot.data?[1] as List<PrinterModel>? ?? const [];
        final mappings =
            snapshot.data?[2] as List<StationPrinterModel>? ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toolbar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFFFAFAFA),
              child: Row(
                children: [
                  const Text(
                    'Alan → Yazıcı Eşleştirme',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${stations.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (printers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Aktif yazıcı yok',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── List ───────────────────────────────────────────────────
            Expanded(
              child: stations.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      children: [
                        _buildRoleMappingsSection(printers),
                        const SizedBox(height: 12),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Hazırlama alanı bulunamadı.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      itemCount: stations.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildRoleMappingsSection(printers);
                        }
                        final station = stations[index - 1];
                        final stationMappings = mappings
                            .where((m) => m.stationId == station.id)
                            .toList(growable: false);
                        final primaryMapping = _resolvePrimaryStationMapping(
                          stationMappings,
                        );
                        final selectedPrinterId =
                            _stationPrinterDraft[station.id] ??
                            _normalizeSelectedPrinterId(
                              printers: printers,
                              selectedPrinterId: primaryMapping?.printerId,
                            );
                        return _buildMappingRow(
                          station: station,
                          printers: printers,
                          primaryMapping: primaryMapping,
                          selectedPrinterId: selectedPrinterId,
                          stations: stations,
                          mappings: mappings,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMappingRow({
    required StationModel station,
    required List<PrinterModel> printers,
    required StationPrinterModel? primaryMapping,
    required String? selectedPrinterId,
    required List<StationModel> stations,
    required List<StationPrinterModel> mappings,
  }) {
    final isMapped = primaryMapping != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMapped ? const Color(0xFFD1FAE5) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 520;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMappingStationInfo(station, primaryMapping),
                const SizedBox(height: 8),
                _buildMappingDropdown(
                  station: station,
                  printers: printers,
                  selectedPrinterId: selectedPrinterId,
                  stations: stations,
                  mappings: mappings,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: _buildMappingStationInfo(station, primaryMapping),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildMappingDropdown(
                  station: station,
                  printers: printers,
                  selectedPrinterId: selectedPrinterId,
                  stations: stations,
                  mappings: mappings,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleMappingsSection(List<PrinterModel> printers) {
    final receiptPrinterId = _normalizeSelectedPrinterId(
      printers: printers,
      selectedPrinterId: _selectedReceiptPrinterId,
    );
    final kitchenPrinterId = _normalizeSelectedPrinterId(
      printers: printers,
      selectedPrinterId: _selectedKitchenPrinterId,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rol Eşleştirmeleri',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Adisyon, mutfak ve alan eşleştirmeleri sadece burada yönetilir. Listede yalnızca Yazıcılar sekmesindeki aktif kayıtlar görünür.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('role-receipt-${receiptPrinterId ?? 'none'}'),
            initialValue: receiptPrinterId,
            decoration: const InputDecoration(
              labelText: 'Adisyon yazıcısı',
              border: OutlineInputBorder(),
            ),
            items: printers
                .map(
                  (printer) => DropdownMenuItem<String>(
                    value: printer.id,
                    child: Text(printer.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedReceiptPrinterId = value;
                _selectedReceiptPrinterLabel = printers
                    .firstWhere(
                      (printer) => printer.id == value,
                      orElse: () => printers.first,
                    )
                    .name;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('role-kitchen-${kitchenPrinterId ?? 'none'}'),
            initialValue: kitchenPrinterId,
            decoration: const InputDecoration(
              labelText: 'Mutfak yazıcısı',
              border: OutlineInputBorder(),
            ),
            items: printers
                .map(
                  (printer) => DropdownMenuItem<String>(
                    value: printer.id,
                    child: Text(printer.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedKitchenPrinterId = value;
                _selectedKitchenPrinterLabel = printers
                    .firstWhere(
                      (printer) => printer.id == value,
                      orElse: () => printers.first,
                    )
                    .name;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: printers.isEmpty || _savingRoleMappings
                    ? null
                    : _saveRoleMappings,
                icon: _savingRoleMappings
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Rol eşleştirmelerini kaydet'),
              ),
              if (printers.isEmpty)
                const Text(
                  'Önce Yazıcılar sekmesinden aktif yazıcı ekleyin.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMappingStationInfo(
    StationModel station,
    StationPrinterModel? primaryMapping,
  ) {
    final isMapped = primaryMapping != null;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isMapped ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                station.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                isMapped
                    ? (primaryMapping.printerName ?? primaryMapping.printerId)
                    : 'Yazıcı atanmadı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isMapped
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMappingDropdown({
    required StationModel station,
    required List<PrinterModel> printers,
    required String? selectedPrinterId,
    required List<StationModel> stations,
    required List<StationPrinterModel> mappings,
  }) {
    return SizedBox(
      height: 34,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>(
          'station-${station.id}-printer-${selectedPrinterId ?? 'none'}-$_assignmentsRefreshNonce',
        ),
        initialValue: selectedPrinterId,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
        hint: const Text(
          'Yazıcı Seç',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
        items: printers
            .map(
              (printer) => DropdownMenuItem<String>(
                value: printer.id,
                child: Text(
                  printer.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(growable: false),
        onChanged: printers.isEmpty
            ? null
            : (value) async {
                if (value == null) return;
                setState(() {
                  _stationPrinterDraft[station.id] = value;
                });
                _logPrinterSettings(
                  'Assignments',
                  'dropdownChanged restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=$value selectedAreaId=${station.id} emptyBranch=selection_changed',
                );
                try {
                  final resolvedPrinterId =
                      _normalizeSelectedPrinterId(
                        printers: printers,
                        selectedPrinterId: value,
                      ) ??
                      value;
                  if (resolvedPrinterId.isEmpty) {
                    throw StateError(
                      'Yazıcı kaydı bulunamadı. Önce Yazıcılar sekmesinden POS-58 kaydını oluşturun.',
                    );
                  }
                  await _printerRepository.assignPrinterToStation(
                    stationId: station.id,
                    printerId: resolvedPrinterId,
                    isPrimary: true,
                    restaurantId: widget.restaurantId,
                    stationName: station.name,
                    printerName: _printerNameById(resolvedPrinterId),
                  );
                  _logPrinterSettings(
                    'Assignments',
                    'saveSuccess restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=$value selectedAreaId=${station.id} emptyBranch=save_success',
                  );
                  setState(() {
                    _stationPrinterDraft.remove(station.id);
                  });
                  _triggerAssignmentsRefresh(
                    reason: 'stationPrinterSaved',
                    selectedPrinterId: value,
                    selectedAreaId: station.id,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text('${station.name} için yazıcı kaydedildi.'),
                    ),
                  );
                } catch (error, stackTrace) {
                  _logPrinterSettings(
                    'Assignments',
                    'saveFail restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=$value selectedAreaId=${station.id} emptyBranch=save_error',
                    error: error,
                    stackTrace: stackTrace,
                  );
                  setState(() {
                    _stationPrinterDraft.remove(station.id);
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text('Yazıcı eşleştirilemedi: $error')),
                  );
                }
              },
      ),
    );
  }

  /// Toolbar for the "Yazıcılar" tab — includes Test and Guide actions.
  Widget _buildPrintersTabToolbar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFAFAFA),
      child: Row(
        children: [
          // Label
          const Text(
            'Yazıcılar',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: _handleSystemSetup,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.settings_suggest_outlined, size: 14),
              label: const Text('Sistem Kur'),
            ),
          ),
          const SizedBox(width: 6),
          // Test button
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: () async {
                if (_guardPrintSystemDisabled()) {
                  return;
                }
                final testPrinterId =
                    _selectedReceiptPrinterId ?? _selectedKitchenPrinterId;
                final testPrinterLabel = testPrinterId == null
                    ? null
                    : _printerNameById(testPrinterId).trim().isEmpty
                    ? null
                    : _printerNameById(testPrinterId);
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      PrinterTestDialog(
                        restaurantId: widget.restaurantId,
                        printOrchestrator: _printOrchestrator,
                        printerRepository: _printerRepository,
                        initialPrinterId: testPrinterId,
                        initialPrinterLabel: testPrinterLabel,
                      ),
                );
                if (saved == true) {
                  await _loadPrintStationState();
                  _triggerPrintersRefresh(reason: 'bridgeTestSavedPrinter');
                  _triggerAssignmentsRefresh(
                    reason: 'bridgeTestSavedPrinter',
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.print_outlined, size: 14),
              label: const Text('Test'),
            ),
          ),
          const SizedBox(width: 6),
          // Guide icon button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Kurulum Kılavuzu',
              iconSize: 18,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const PrinterGuideDialog(),
              ),
              icon: const Icon(
                Icons.menu_book_outlined,
                color: Color(0xFF7A2FF4),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Add printer button
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: () => _showPrinterEditor(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7A2FF4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Yazıcı Ekle'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSystemSetup() async {
    if (!mounted) return;
    final savedPrinters = await showPrinterSystemSetupWizard(
      context,
      restaurantId: widget.restaurantId,
    );
    if (savedPrinters == null || savedPrinters.isEmpty) return;
    _triggerPrintersRefresh(
      reason: 'systemSetupCompleted',
      selectedPrinterId: savedPrinters.first.id,
      printerCount: savedPrinters.length,
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          savedPrinters.length == 1
              ? 'Yazıcı kurulumu tamamlandı.'
              : '${savedPrinters.length} yazıcı kaydı güncellendi.',
        ),
      ),
    );
  }

  /// Shared top toolbar used by all management tabs.
  Widget _buildTabToolbar({
    required String label,
    required int count,
    required VoidCallback onAdd,
    required String addLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFAFAFA),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7A2FF4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.add, size: 15),
              label: Text(addLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRoutingTab() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey<String>('products-$_productsRefreshNonce'),
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Ürünler yüklenemedi.'));
        }
        final products = snapshot.data?[0] as List<SellerProduct>? ?? const [];
        final stations = snapshot.data?[1] as List<StationModel>? ?? const [];

        if (products.isEmpty) {
          return const Center(child: Text('Ürün bulunamadı.'));
        }

        return LayoutBuilder(
          builder: (buildCtx, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 1200
                ? 5
                : w > 960
                ? 4
                : w > 680
                ? 3
                : w > 440
                ? 2
                : 1;
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 128,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final isDirty =
                    _productStationDraft.containsKey(product.id) ||
                    _productRoutingDraft.containsKey(product.id);
                final isSaving = _productSavingMap[product.id] == true;
                final isSaved = _productSavedMap[product.id] == true;
                final saveError = _productSaveErrorMap[product.id];
                final draftStation =
                    _productStationDraft[product.id] ?? product.stationId;
                final draftEnabled =
                    _productRoutingDraft[product.id] ??
                    product.printerRoutingEnabled;
                return _buildProductMappingCard(
                  product: product,
                  stations: stations,
                  draftStation: draftStation,
                  draftEnabled: draftEnabled,
                  isDirty: isDirty,
                  isSaving: isSaving,
                  isSaved: isSaved,
                  saveError: saveError,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductMappingCard({
    required SellerProduct product,
    required List<StationModel> stations,
    required String? draftStation,
    required bool draftEnabled,
    required bool isDirty,
    required bool isSaving,
    required bool isSaved,
    required String? saveError,
  }) {
    final Color borderColor;
    final double borderWidth;
    if (saveError != null) {
      borderColor = const Color(0xFFFCA5A5); // red-200
      borderWidth = 1.5;
    } else if (isSaved) {
      borderColor = const Color(0x8086EFAC); // green-300 translucent
      borderWidth = 1.5;
    } else if (isDirty || isSaving) {
      borderColor = const Color(0xFFFBBF24); // amber-400
      borderWidth = 1.5;
    } else {
      borderColor = const Color(0xFFE5E7EB); // gray-200
      borderWidth = 1.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: saveError != null
            ? const Color(0xFFFFF7F7) // red-50
            : isSaved
            ? const Color(0xFFF0FDF4) // green-50
            : (isDirty || isSaving)
            ? const Color(0xFFFFFBEB) // amber-50
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: product name + state badge ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildProductStateBadge(
                isDirty: isDirty,
                isSaving: isSaving,
                isSaved: isSaved,
                hasError: saveError != null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Row 2: station dropdown ─────────────────────────────────────
          SizedBox(
            height: 30,
            child: DropdownButtonFormField<String?>(
              key: ValueKey<String>(
                'drop-${product.id}-$_productsRefreshNonce',
              ),
              initialValue: draftStation,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
              hint: const Text(
                'Atanmadı',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
              ),
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF111827)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Atanmadı', style: TextStyle(fontSize: 10.5)),
                ),
                ...stations.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text(
                      s.name,
                      style: const TextStyle(fontSize: 10.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      _logPrinterSettings(
                        'Products',
                        'mappingChanged restaurantId=${widget.restaurantId} '
                            'areaCount=${stations.length} '
                            'selectedAreaId=${_logField(value ?? '')} '
                            'emptyBranch=selection_changed '
                            'productId=${product.id}',
                      );
                      setState(() => _productStationDraft[product.id] = value);
                      _upsertProductMappingCache(product, value, stations);
                      unawaited(
                        _persistProductStationSelectionToDb(
                          product,
                          value,
                          stations,
                        ),
                      );
                    },
            ),
          ),
          const SizedBox(height: 3),
          // ── Row 3: routing switch + save button ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Tooltip(
                message: 'Yazıcı yönlendirmesini aç/kapat',
                child: SizedBox(
                  width: 40,
                  height: 24,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    child: Switch.adaptive(
                      value: draftEnabled,
                      activeThumbColor: const Color(0xFF16A34A),
                      activeTrackColor: const Color(0xFFBBF7D0),
                      onChanged: isSaving
                          ? null
                          : (value) => setState(
                              () => _productRoutingDraft[product.id] = value,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  draftEnabled ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    fontSize: 10,
                    color: draftEnabled
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildProductSaveButton(
                product: product,
                isDirty: isDirty,
                isSaving: isSaving,
                isSaved: isSaved,
                hasError: saveError != null,
              ),
            ],
          ),
          // ── Row 4 (optional): inline error text ─────────────────────────
          if (saveError != null) ...[
            const SizedBox(height: 2),
            Text(
              saveError,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Color(0xFFDC2626)),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact badge (top-right) indicating per-card save state.
  Widget _buildProductStateBadge({
    required bool isDirty,
    required bool isSaving,
    required bool isSaved,
    required bool hasError,
  }) {
    if (isSaving) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A2FF4)),
        ),
      );
    }
    if (isSaved) {
      return _productStatePill(
        '✓ Kaydedildi',
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      );
    }
    if (hasError) {
      return _productStatePill(
        'Hata',
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      );
    }
    if (isDirty) {
      return _productStatePill(
        'Bekliyor',
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _productStatePill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  /// Save/retry button for each product card.
  Widget _buildProductSaveButton({
    required SellerProduct product,
    required bool isDirty,
    required bool isSaving,
    required bool isSaved,
    required bool hasError,
  }) {
    final Color? bgColor;
    final VoidCallback? onPressed;
    final Widget child;

    if (isSaving) {
      bgColor = const Color(0xFF7A2FF4);
      onPressed = null;
      child = const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (isSaved) {
      bgColor = const Color(0xFF16A34A);
      onPressed = null;
      child = const Text('✓');
    } else if (hasError) {
      bgColor = const Color(0xFFDC2626);
      onPressed = () => _saveProductRouting(product);
      child = const Text('Tekrar');
    } else if (isDirty) {
      bgColor = const Color(0xFF7A2FF4);
      onPressed = () => _saveProductRouting(product);
      child = const Text('Kaydet');
    } else {
      bgColor = null;
      onPressed = null;
      child = const Text('Kaydet');
    }

    return SizedBox(
      height: 24,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          disabledBackgroundColor: const Color(0xFFF3F4F6),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 24),
          textStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: child,
      ),
    );
  }

  int _tableNumberFromOrder(Map<String, dynamic> order) {
    final raw = order['table_number'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  DateTime _orderCreatedAt(Map<String, dynamic> order) {
    final parsed = DateTime.tryParse(order['created_at']?.toString() ?? '');
    return parsed?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _orderItems(Map<String, dynamic> order) {
    final raw = order['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => MixedServiceOrder.normalizeOrderItem(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  double _orderTotal(List<Map<String, dynamic>> items) {
    return items.fold<double>(0, (sum, item) {
      return sum + MixedServiceOrder.itemLineTotal(item);
    });
  }

  List<MixedServiceDisplayEntry> _itemDetailLines(Map<String, dynamic> item) {
    final lines = <MixedServiceDisplayEntry>[];
    final notes = item['notes']?.toString().trim() ?? '';
    if (notes.isNotEmpty) {
      lines.add(MixedServiceDisplayEntry.item(notes));
    }
    lines.addAll(MixedServiceOrder.childItemDisplayEntries(item));
    return lines;
  }

  String _formatMoney(double amount) {
    final safe = amount.isFinite ? amount : 0;
    final text = safe.toStringAsFixed(2);
    final parts = text.split('.');
    final whole = parts[0];
    final decimal = parts.length > 1 ? parts[1] : '00';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final idxFromRight = whole.length - i;
      buffer.write(whole[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) {
        buffer.write('.');
      }
    }
    return '₺${buffer.toString()},$decimal';
  }

  String _orderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'waiting':
        return 'Sipariş Bekleniliyor';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'sent':
      case 'done':
        return 'Mutfakta';
      case 'closed':
        return 'Kapalı';
      default:
        return status.isEmpty ? 'Bilinmiyor' : status;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'waiting':
        return const Color(0xFFDC2626);
      case 'preparing':
        return const Color(0xFFD97706);
      case 'sent':
      case 'done':
        return const Color(0xFF16A34A);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _buildIncomingOrdersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _storeService.getTableOrdersStream(widget.restaurantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Siparişler alınamadı.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final orders =
            (snapshot.data ?? const <Map<String, dynamic>>[])
                .where((order) {
                  final status = (order['status']?.toString() ?? '')
                      .toLowerCase();
                  return status != 'closed';
                })
                .toList(growable: false)
              ..sort(
                (a, b) => _orderCreatedAt(b).compareTo(_orderCreatedAt(a)),
              );

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  'Henüz mutfağa düşen sipariş yok.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status']?.toString() ?? '';
            final statusColor = _orderStatusColor(status);
            final createdAt = _orderCreatedAt(order);
            final items = _orderItems(order);
            final tableNo = _tableNumberFromOrder(order);
            final orderNo = order['order_no']?.toString().trim();
            final total = _orderTotal(items);

            // Format creation time
            final timeStr =
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
            final dateStr =
                '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Adisyon başlık ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tableNo > 0
                                      ? 'MASA $tableNo'
                                      : 'MASA BİLİNMİYOR',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${orderNo == null || orderNo.isEmpty ? '' : '#$orderNo  •  '}$dateStr  $timeStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _orderStatusLabel(status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Adisyon satır başlıkları ────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 5,
                            child: Text(
                              'ÜRÜN ADI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 40,
                            child: Text(
                              'ADET',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'FİYAT',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 70,
                            child: Text(
                              'TUTAR',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 12, endIndent: 12),

                    // ── Adisyon kalemleri ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Column(
                        children: items
                            .map((item) {
                              final qty =
                                  (item['quantity'] as num?)?.toInt() ?? 1;
                              final name = item['name']?.toString() ?? '-';
                              final unitPrice =
                                  (item['price'] as num?)?.toDouble() ?? 0;
                              final lineTotal = unitPrice * qty;
                              final detailLines = _itemDetailLines(item);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 40,
                                          child: Text(
                                            '$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            _formatMoney(unitPrice),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            _formatMoney(lineTotal),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (detailLines.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          top: 2,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: detailLines
                                              .take(4)
                                              .map(
                                                (entry) => Text(
                                                  entry.isGroupHeader
                                                      ? entry.label
                                                      : '· ${entry.label}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    fontWeight:
                                                        entry.isGroupHeader
                                                        ? FontWeight.w700
                                                        : FontWeight.normal,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),

                    // ── Adisyon toplam ──────────────────────────────────
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${items.length} kalem',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          const Text(
                            'TOPLAM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatMoney(total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrintJobsTab() {
    final chips = const [
      ('all', 'Tümü'),
      ('pending', 'Bekliyor'),
      ('claimed', 'Claimed'),
      ('printing', 'Yazdırılıyor'),
      ('completed', 'Tamamlandı'),
      ('failed', 'Başarısız'),
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: chips
              .map(
                (item) => ChoiceChip(
                  label: Text(item.$2),
                  selected: _printStatusFilter == item.$1,
                  onSelected: (_) =>
                      setState(() => _printStatusFilter = item.$1),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: StreamBuilder<List<PrinterEventLogEntry>>(
            stream: _printerEventLogService.watchRecent(
              widget.restaurantId,
              limit: 50,
            ),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <PrinterEventLogEntry>[];
              if (entries.isEmpty) {
                return const Center(
                  child: Text('Henüz yerel yazdırma olay kaydı yok.'),
                );
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final color = entry.level == 'error'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB);
                  final meta = <String>[
                    if ((entry.role ?? '').isNotEmpty) 'rol=${entry.role}',
                    if ((entry.printerId ?? '').isNotEmpty)
                      'printer=${entry.printerId}',
                    if ((entry.queueName ?? '').isNotEmpty)
                      'queue=${entry.queueName}',
                    if ((entry.backend ?? '').isNotEmpty)
                      'backend=${entry.backend}',
                    if ((entry.jobId ?? '').isNotEmpty) 'job=${entry.jobId}',
                  ].join(' • ');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.event,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          Text(
                            entry.timestamp,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                      if (entry.details.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.details.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PrintJobModel>>(
            stream: _printJobRepository.watchJobs(
              widget.restaurantId,
              status: _printStatusFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final jobs = snapshot.data ?? const <PrintJobModel>[];
              if (jobs.isEmpty) {
                return const Center(child: Text('Print job kaydı yok.'));
              }
              return ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final color = switch (job.normalizedStatus) {
                    'failed' => const Color(0xFFDC2626),
                    'completed' => const Color(0xFF16A34A),
                    'printing' => const Color(0xFFEA580C),
                    'claimed' => const Color(0xFF7C3AED),
                    _ => const Color(0xFF2563EB),
                  };
                  return Card(
                    child: ListTile(
                      title: Text('${job.stationName} • ${job.printerName}'),
                      subtitle: Text(
                        'Sipariş: ${job.orderNo} • ${job.tableName}\n'
                        'Durum: ${job.normalizedStatus} • ${job.createdAt.toLocal()} • ${job.itemCount} kalem'
                        '${(job.lastError ?? '').trim().isEmpty ? '' : '\nHata: ${job.lastError}'}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              job.status,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () async {
                              try {
                                await _orderPrintJobService.retryPrintJob(
                                  restaurantId: widget.restaurantId,
                                  printJobId: job.id,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.maybeOf(
                                  this.context,
                                )?.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Print job yeniden yazdirildi.',
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.maybeOf(
                                  this.context,
                                )?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Print job tekrar gonderilemedi: $error',
                                    ),
                                  ),
                                );
                              }
                            },
                            tooltip: 'Yeniden Dene',
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yazıcı Ayarları'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Yazıcı Merkezi'),
              Tab(text: 'Alanlar'),
              Tab(text: 'Yazıcılar'),
              Tab(text: 'Eşleştirme'),
              Tab(text: 'Ürün Eşleme'),
              Tab(text: 'Gelen Siparişler'),
              Tab(text: 'Print Log'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: TabBarView(
            children: [
              _buildPrintStationTab(),
              _buildStationsTab(),
              _buildPrintersTab(),
              _buildMappingTab(),
              _buildProductRoutingTab(),
              _buildIncomingOrdersTab(),
              _buildPrintJobsTab(),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerPrintersRefresh({
    required String reason,
    String? selectedPrinterId,
    int? printerCount,
  }) {
    if (!mounted) return;
    setState(() {
      _printersRefreshNonce += 1;
      _assignmentsRefreshNonce += 1;
      _printersStream = _createPrintersStream();
      _assignmentsFuture = _loadAssignmentsData();
    });
    _logPrinterSettings(
      'Printers',
      'refreshTriggered restaurantId=${widget.restaurantId} printerCount=${printerCount ?? -1} selectedPrinterId=${_logField(selectedPrinterId ?? '')} emptyBranch=$reason',
    );
  }

  void _triggerAssignmentsRefresh({
    required String reason,
    String? selectedPrinterId,
    String? selectedAreaId,
  }) {
    if (!mounted) return;
    setState(() {
      _assignmentsRefreshNonce += 1;
      _assignmentsFuture = _loadAssignmentsData();
    });
    _logPrinterSettings(
      'Assignments',
      'refreshTriggered restaurantId=${widget.restaurantId} areaCount=- printerCount=- selectedPrinterId=${_logField(selectedPrinterId ?? '')} selectedAreaId=${_logField(selectedAreaId ?? '')} emptyBranch=$reason',
    );
  }

  void _triggerProductsRefresh({
    required String reason,
    String? selectedAreaId,
  }) {
    if (!mounted) return;
    setState(() {
      _productsRefreshNonce += 1;
      _productsFuture = _loadProductRoutingData();
    });
    _logPrinterSettings(
      'Products',
      'refreshTriggered restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=${_logField(selectedAreaId ?? '')} emptyBranch=$reason',
    );
  }

  StationPrinterModel? _resolvePrimaryStationMapping(
    List<StationPrinterModel> mappings,
  ) {
    for (final mapping in mappings) {
      if (mapping.isPrimary) {
        return mapping;
      }
    }
    return mappings.isEmpty ? null : mappings.first;
  }

  List<PrinterModel> _filterPrintersToCurrentScan(List<PrinterModel> printers) {
    final matched = <PrinterModel>[];
    final unmatched = <PrinterModel>[];
    for (final printer in printers) {
      if (_isPrinterPresentInCurrentScan(printer)) {
        matched.add(printer);
      } else {
        unmatched.add(printer);
      }
    }
    return <PrinterModel>[...matched, ...unmatched];
  }

  bool _isPrinterPresentInCurrentScan(PrinterModel printer) {
    final printerId = printer.id.trim();
    final deviceIdentifier = (printer.deviceIdentifier ?? '')
        .trim()
        .toLowerCase();
    final printerName = _normalizePrinterMatchText(printer.name);
    for (final bridgePrinter in _bridgePrinters) {
      if (bridgePrinter['isLive'] != true) continue;
      final recordId =
          bridgePrinter['printerRecordId']?.toString().trim() ?? '';
      final bridgeDevice =
          (bridgePrinter['deviceIdentifier'] ?? bridgePrinter['queue'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      final bridgeName = _normalizePrinterMatchText(
        (bridgePrinter['name'] ?? '').toString(),
      );
      if (recordId.isNotEmpty && recordId == printerId) {
        return true;
      }
      if (deviceIdentifier.isNotEmpty &&
          bridgeDevice.isNotEmpty &&
          deviceIdentifier == bridgeDevice) {
        return true;
      }
      if (printerName.isNotEmpty &&
          bridgeName.isNotEmpty &&
          printerName == bridgeName) {
        return true;
      }
    }
    return false;
  }

  String _normalizePrinterMatchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _normalizeSelectedPrinterId({
    required List<PrinterModel> printers,
    required String? selectedPrinterId,
  }) {
    if (selectedPrinterId == null || selectedPrinterId.isEmpty) {
      return null;
    }
    for (final printer in printers) {
      if (printer.id == selectedPrinterId) {
        return selectedPrinterId;
      }
    }
    for (final bridgePrinter in _bridgePrinters) {
      if (bridgePrinter['isLive'] != true) continue;
      final bridgeId = bridgePrinter['id']?.toString().trim() ?? '';
      final bridgeRecordId =
          bridgePrinter['printerRecordId']?.toString().trim() ??
          bridgePrinter['printer_record_id']?.toString().trim() ??
          '';
      if (bridgeId == selectedPrinterId && bridgeRecordId.isNotEmpty) {
        final matched = printers.any((printer) => printer.id == bridgeRecordId);
        if (matched) {
          return bridgeRecordId;
        }
      }
    }
    return null;
  }

  void _logPrinterSettings(
    String section,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint(
      '[PrinterSettings][$section] $message${error != null ? ' exception=$error' : ''}',
    );
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _logField(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }
}

class _InlineStatusChip extends StatelessWidget {
  const _InlineStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _GuidedStepTile extends StatelessWidget {
  const _GuidedStepTile({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.done,
    this.compact = false,
  });

  final String stepNumber;
  final String title;
  final String subtitle;
  final bool done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF15803D) : const Color(0xFF6B7280);
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 20 : 24,
            height: compact ? 20 : 24,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: done ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
