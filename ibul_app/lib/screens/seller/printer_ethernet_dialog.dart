// Ethernet / TCP printer add dialog.
//
// Lives next to ``printer_wizard.dart`` and is used by:
//   - System > Printer Settings > Printers > "Ethernet Yazıcı Ekle"
//   - System > Printer Settings > Printer Center > Step-by-step setup
//     (Ethernet / Ağ Yazıcısı flow)
//
// Goal: let an operator add a NETUM ZJ-8360 (or any ESC/POS Ethernet
// printer) by typing the IP and port shown on the printer self-test, run a
// real test print, and assign Adisyon / Mutfak roles. The save reuses
// ``PrinterRepository.upsertEthernetPrinter`` so the dispatcher recognises
// the row as a TCP printer and bypasses CUPS/USB.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/runtime_config.dart';
import '../../features/seller/panel/widgets/seller_download_app_content.dart';
import '../../models/desktop_printer_setup_models.dart';
import '../../models/printer_discovery_result.dart';
import '../../models/printer_model.dart';
import '../../models/printer_profile.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/local_print_service.dart';
import '../../services/mobile_ethernet_printer_service.dart';
import '../../services/printer_error_messages.dart';
import '../../services/printer_repository.dart';
import '../../services/restaurant_offline/restaurant_connectivity_service.dart';
import '../../services/restaurant_offline/restaurant_offline_snapshot_sync.dart';
import '../../features/seller/panel/printer_center/widgets/printer_receipt_length_settings_section.dart';
import '../../services/printer_receipt_length_settings.dart';

/// Opens the Ethernet printer dialog and returns the saved [PrinterModel]
/// when the operator finishes the flow, or ``null`` on cancel.
Future<PrinterModel?> showAddEthernetPrinterDialog(
  BuildContext context, {
  required String restaurantId,
  PrinterModel? existing,
  PrinterRepository? repository,
  DesktopPrintOrchestrator? orchestrator,
}) {
  return Navigator.of(context).push<PrinterModel>(
    MaterialPageRoute<PrinterModel>(
      fullscreenDialog: true,
      builder: (_) => AddEthernetPrinterScreen(
        restaurantId: restaurantId,
        existing: existing,
        repository: repository,
        orchestrator: orchestrator,
      ),
    ),
  );
}

/// Roles selectable for an Ethernet printer. Mirrors the kitchen routing
/// vocabulary used by the rest of the printer wizard.
enum EthernetPrinterRole { adisyon, mutfak, both }

extension EthernetPrinterRoleX on EthernetPrinterRole {
  List<PrinterRole> get assignedRoles {
    switch (this) {
      case EthernetPrinterRole.adisyon:
        return const <PrinterRole>[PrinterRole.receipt];
      case EthernetPrinterRole.mutfak:
        return const <PrinterRole>[PrinterRole.kitchen];
      case EthernetPrinterRole.both:
        return const <PrinterRole>[PrinterRole.receipt, PrinterRole.kitchen];
    }
  }
}

class AddEthernetPrinterScreen extends StatefulWidget {
  const AddEthernetPrinterScreen({
    super.key,
    required this.restaurantId,
    this.existing,
    this.repository,
    this.orchestrator,
    this.localPrintService,
  });

  final String restaurantId;
  final PrinterModel? existing;
  final PrinterRepository? repository;
  final DesktopPrintOrchestrator? orchestrator;
  final LocalPrintService? localPrintService;

  @override
  State<AddEthernetPrinterScreen> createState() =>
      _AddEthernetPrinterScreenState();
}

class _AddEthernetPrinterScreenState extends State<AddEthernetPrinterScreen> {
  late final DesktopPrintOrchestrator _orchestrator =
      widget.orchestrator ?? DesktopPrintOrchestrator();
  // Web'de seller paneli masaüstü agent'a (localhost bridge) bağlanabilir.
  late final LocalPrintService _localPrintService =
      widget.localPrintService ?? LocalPrintService(allowWebAgent: true);

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ipCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController(
    text: PrinterModel.ethernetDefaultPort.toString(),
  );

  int _paperWidth = PrinterModel.defaultPaperWidthMm;
  String _selectedProfileId = PrinterProfile.pos80.id;
  bool _autoCut = true;
  EthernetPrinterRole _role = EthernetPrinterRole.adisyon;

  bool _connectionTesting = false;
  EthernetConnectionDiagnostic? _connectionDiagnostic;
  Map<String, dynamic>? _networkPreflight;

  bool _printTesting = false;
  EthernetConnectionDiagnostic? _printDiagnostic;

  bool _helpExpanded = false;
  bool _technicalExpanded = false;
  bool _migrationGuideExpanded = false;

  bool _scanning = false;
  EthernetScanResult? _scanResult;
  String? _scanError;
  String? _scanProgressLabel;

  // Bulunan yazıcı kartlarının düzenlenebilir durumu (endpoint anahtarlı).
  final Map<String, TextEditingController> _deviceNameCtrls =
      <String, TextEditingController>{};
  final Map<String, String> _deviceProfileIds = <String, String>{};
  final Map<String, EthernetConnectionDiagnostic> _deviceTestResults =
      <String, EthernetConnectionDiagnostic>{};

  /// Aynı seller altındaki kayıtlı yazıcı adları (çakışma kontrolü için).
  List<String> _existingPrinterNames = const <String>[];

  /// Web: masaüstü yazıcı yardımcısı (local print agent) durumu.
  /// null = kontrol ediliyor, true = bağlı, false = yok.
  bool? _webAgentHealthy;
  bool _webAgentChecking = false;

  // Mobil (Android) direct-TCP yolu: bridge yok, tarama/test/baskı telefon
  // üzerinden doğrudan TCP socket ile yapılır. Masaüstü/iOS akışı değişmez.
  MobileEthernetPrinterService? _mobileTcpService;
  MobileEthernetScanSession? _mobileScanSession;

  MobileEthernetPrinterService get _mobileTcp =>
      _mobileTcpService ??= MobileEthernetPrinterService();

  bool get _useMobileDirectTcp {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  bool _saving = false;
  String? _formError;
  String? _technicalError;
  String? _saveStatusMessage;
  bool _savedToDb = false;
  String? _ipError;
  String? _portError;
  PrinterReceiptLengthSettings _receiptLengthSettings =
      PrinterReceiptLengthSettings.normal;

  PrinterProfile get _selectedPrinterProfile =>
      PrinterProfile.resolveForEthernetSetup(
        explicitProfileId: _selectedProfileId,
        paperWidthMm: _paperWidth,
      );

  Map<String, dynamic> _ethernetProfileFields() =>
      PrinterProfile.bridgeProfileFields(_selectedPrinterProfile);

  void _applyProfileSelection(String profileId) {
    final profile = PrinterProfile.byId(profileId);
    if (profile == null) return;
    setState(() {
      _selectedProfileId = profile.id;
      _paperWidth = profile.paperWidthMm;
      _autoCut = profile.supportsCut;
    });
  }

  bool get _connectionOk => _connectionDiagnostic?.ok == true;
  bool get _printOk => _printDiagnostic?.ok == true;

  String get _saveStatusLabel {
    if (_savedToDb) return 'Kaydedildi';
    if (_saveStatusMessage != null && _saveStatusMessage!.isNotEmpty) {
      return _saveStatusMessage!;
    }
    if (_connectionOk && _printOk) return 'Hazır';
    if (_connectionOk) return 'Hazır';
    if (_connectionTesting || _printTesting || _saving) {
      return 'Bağlantı bekleniyor';
    }
    return 'Bağlantı bekleniyor';
  }

  String? get _manualScanSuccessMessage {
    if (!_connectionOk) return null;
    final scanFailed = _scanError != null ||
        (_scanResult != null && (_scanResult!.devices.isEmpty));
    if (!scanFailed) return null;
    return 'Otomatik tarama cihaz bulamadı. Manuel IP ile bağlantı başarılı.';
  }

  EthernetNetworkCompatibilityPlan get _networkCompatibilityPlan {
    final host = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ??
        PrinterModel.ethernetDefaultPort;
    Map<String, dynamic>? payload = _networkPreflight == null
        ? null
        : Map<String, dynamic>.from(_networkPreflight!);
    if (_connectionDiagnostic != null) {
      payload = <String, dynamic>{
        ...?payload,
        'local_ips': _connectionDiagnostic!.localIps,
        'same_subnet': _connectionDiagnostic!.sameSubnet,
        if (_connectionDiagnostic!.hasNetworkMismatch)
          'network_state': 'network_mismatch',
        if (_connectionDiagnostic!.networkHint.isNotEmpty)
          'mismatch_guidance': _connectionDiagnostic!.networkHint,
      };
    }
    if (_scanResult != null) {
      payload = <String, dynamic>{
        ...?payload,
        'local_ips': _scanResult!.localIps,
        'scanned_subnets': _scanResult!.subnets,
        if (_scanResult!.suggestedPrinterIp.isNotEmpty)
          'suggested_printer_ip': _scanResult!.suggestedPrinterIp,
        if (_scanResult!.suggestedTargetSubnet.isNotEmpty)
          'suggested_target_subnet': _scanResult!.suggestedTargetSubnet,
        if (_scanResult!.mismatchGuidance.isNotEmpty)
          'mismatch_guidance': _scanResult!.mismatchGuidance,
      };
    }
    return EthernetNetworkCompatibilityPlan.fromContext(
      localIps: const <String>[],
      printerHost: host,
      port: port,
      bridgePayload: payload,
    );
  }

  @override
  void initState() {
    super.initState();
    _ipCtrl.addListener(_onNetworkFieldsChanged);
    _portCtrl.addListener(_onNetworkFieldsChanged);
    if (kIsWeb) {
      unawaited(_checkWebAgent());
    }
    final existing = widget.existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _ipCtrl.text = existing.ethernetHost;
      _portCtrl.text = existing.ethernetPort.toString();
      _selectedProfileId =
          existing.printerProfileId ??
          (existing.paperWidthMm <= 58
              ? PrinterProfile.pos58.id
              : PrinterProfile.pos80.id);
      _paperWidth = _selectedPrinterProfile.paperWidthMm;
      _autoCut = existing.supportsCut;
      if (existing.assignedRoles.contains(PrinterRole.receipt) &&
          existing.assignedRoles.contains(PrinterRole.kitchen)) {
        _role = EthernetPrinterRole.both;
      } else if (existing.assignedRoles.contains(PrinterRole.kitchen)) {
        _role = EthernetPrinterRole.mutfak;
      } else {
        _role = EthernetPrinterRole.adisyon;
      }
      _receiptLengthSettings =
          PrinterReceiptLengthSettings.fromPrinterModel(existing);
    }
  }

  void _onNetworkFieldsChanged() {
    if (_connectionDiagnostic != null ||
        _networkPreflight != null ||
        _printDiagnostic != null) {
      setState(() {
        _connectionDiagnostic = null;
        _networkPreflight = null;
        _printDiagnostic = null;
        _technicalExpanded = false;
      });
    }
    _maybeRefreshNetworkPreflight();
  }

  // ── bulunan yazıcı kartı yardımcıları ────────────────────────────────────

  String _deviceKey(EthernetDiscoveredDevice device) => device.endpointLabel;

  /// Karttaki düzenlenebilir ad controller'ı; ilk erişimde çakışmasız
  /// varsayılan ad üretilir ("POS Yazıcı - 45").
  TextEditingController _deviceNameCtrl(EthernetDiscoveredDevice device) {
    return _deviceNameCtrls.putIfAbsent(_deviceKey(device), () {
      final taken = <String>[
        ..._existingPrinterNames,
        for (final ctrl in _deviceNameCtrls.values) ctrl.text,
      ];
      return TextEditingController(
        text: PrinterDiscoveryNaming.defaultNameFor(
          device.host,
          existingNames: taken,
        ),
      );
    });
  }

  String _deviceProfileId(EthernetDiscoveredDevice device) =>
      _deviceProfileIds[_deviceKey(device)] ?? _selectedProfileId;

  void _setDeviceProfile(EthernetDiscoveredDevice device, String profileId) {
    setState(() => _deviceProfileIds[_deviceKey(device)] = profileId);
  }

  void _applyDeviceNameTemplate(
    EthernetDiscoveredDevice device,
    String template,
  ) {
    final taken = <String>[
      ..._existingPrinterNames,
      for (final entry in _deviceNameCtrls.entries)
        if (entry.key != _deviceKey(device)) entry.value.text,
    ];
    setState(() {
      _deviceNameCtrl(device).text = PrinterDiscoveryNaming.applyTemplate(
        template,
        device.host,
        existingNames: taken,
      );
      // Şablon rol önerisi: mutfak/bar → mutfak, diğerleri → adisyon.
      _role =
          PrinterDiscoveryNaming.suggestedRoleForTemplate(template) == 'mutfak'
              ? EthernetPrinterRole.mutfak
              : EthernetPrinterRole.adisyon;
    });
  }

  /// Çakışma kontrolü için kayıtlı yazıcı adlarını arka planda çeker.
  Future<void> _prefetchExistingPrinterNames() async {
    try {
      final repo = widget.repository ?? PrinterRepository();
      final printers = await repo.fetchPrinters(widget.restaurantId);
      if (!mounted) return;
      setState(() {
        _existingPrinterNames = <String>[
          for (final printer in printers)
            if (printer.id != (widget.existing?.id ?? '')) printer.name,
        ];
      });
    } catch (_) {
      // Offline/hata: çakışma kontrolü best-effort kalır.
    }
  }

  void _applyDiscoveredDevice(EthernetDiscoveredDevice device) {
    final deviceName = _deviceNameCtrl(device).text.trim();
    final profileId = _deviceProfileId(device);
    setState(() {
      _ipCtrl.text = device.host;
      _portCtrl.text = device.port.toString();
      if (deviceName.isNotEmpty) {
        _nameCtrl.text = deviceName;
      }
      _connectionDiagnostic = null;
      _printDiagnostic = null;
      _networkPreflight = null;
      _technicalExpanded = false;
      _ipError = null;
      _portError = null;
      _formError = null;
    });
    if (profileId != _selectedProfileId) {
      _applyProfileSelection(profileId);
    }
    _maybeRefreshNetworkPreflight();
  }

  // ── web: masaüstü yazıcı yardımcısı (local print agent) ─────────────────

  /// Web'de localhost agent health check'i. Tarayıcı doğrudan TCP açamaz;
  /// tarama/test/baskı ancak agent (İBUL Satıcı Masaüstü) açıkken yapılır.
  Future<void> _checkWebAgent() async {
    if (!kIsWeb || _webAgentChecking) return;
    setState(() => _webAgentChecking = true);
    try {
      _localPrintService.invalidateBridgeStatusCache();
      final status = await _localPrintService.checkAvailability(
        timeout: const Duration(milliseconds: 2500),
      );
      if (!mounted) return;
      setState(() => _webAgentHealthy = status.isAvailable);
    } catch (_) {
      if (!mounted) return;
      setState(() => _webAgentHealthy = false);
    } finally {
      if (mounted) {
        setState(() => _webAgentChecking = false);
      }
    }
  }

  static const String _webAgentMissingMessage =
      'Web\'den yazıcı taramak için İBUL Satıcı Masaüstü uygulaması açık '
      'olmalı. Web tarayıcı güvenliği nedeniyle yazıcıya doğrudan '
      'bağlanamaz; masaüstü uygulaması açıkken tarama, test ve baskı '
      'yapılabilir.';

  Future<void> _runAutoScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _scanError = null;
      _scanResult = null;
    });
    if (kIsWeb && _webAgentHealthy != true) {
      setState(() {
        _scanning = false;
        _scanError = _webAgentMissingMessage;
      });
      unawaited(_checkWebAgent());
      return;
    }
    final port = int.tryParse(_portCtrl.text.trim()) ??
        PrinterModel.ethernetDefaultPort;
    final hostHint = _ipCtrl.text.trim();
    if (_useMobileDirectTcp) {
      await _runMobileAutoScan(port);
      return;
    }
    try {
      final raw = await _localPrintService
          .scanEthernetPrinters(port: port, printerHost: hostHint)
          .timeout(const Duration(seconds: 45));
      if (!mounted) return;
      final result = parseEthernetScanResult(raw);
      setState(() {
        _scanResult = result;
        if (!result.ok) {
          _scanError = result.message.isNotEmpty
              ? result.message
              : 'Ağ taraması tamamlanamadı. IP adresini manuel girebilirsiniz.';
        }
      });
      if (result.devices.isNotEmpty) {
        unawaited(_prefetchExistingPrinterNames());
      }
    } catch (error) {
      if (!mounted) return;
      final diagnostic = resolveEthernetConnectionException(
        error,
        host: _ipCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ??
            PrinterModel.ethernetDefaultPort,
      );
      setState(() {
        _scanError = diagnostic.message.isNotEmpty
            ? diagnostic.message
            : 'Ağ taraması başarısız. IP adresini manuel girebilirsiniz.';
      });
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  /// Android: bridge olmadan telefon üzerinden subnet taraması.
  Future<void> _runMobileAutoScan(int port) async {
    final session = MobileEthernetScanSession();
    _mobileScanSession = session;
    try {
      final result = await _mobileTcp.scan(
        port: port,
        session: session,
        onProgress: (done, total, rangeLabel) {
          if (!mounted) return;
          // UI'yi boğmamak için ~16 host'ta bir güncelle.
          if (done % 16 != 0 && done != total) return;
          setState(() => _scanProgressLabel = '$rangeLabel ($done/$total)');
        },
      );
      if (!mounted) return;
      setState(() {
        _scanResult = result;
        if (!result.ok) {
          _scanError = result.message.isNotEmpty
              ? result.message
              : 'Ağ taraması tamamlanamadı. IP adresini manuel girebilirsiniz.';
        }
      });
      if (result.devices.isNotEmpty) {
        unawaited(_prefetchExistingPrinterNames());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanError =
            'Ağ taraması başarısız. IP adresini manuel girebilirsiniz.';
      });
      debugPrint('[EthernetPrinter][mobile_scan_error] $error');
    } finally {
      _mobileScanSession = null;
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanProgressLabel = null;
        });
      }
    }
  }

  void _cancelMobileScan() {
    _mobileScanSession?.cancel();
  }

  Future<void> _runConnectionTestForDevice(
    EthernetDiscoveredDevice device,
  ) async {
    _applyDiscoveredDevice(device);
    await _runConnectionTest();
    if (!mounted) return;
    final diagnostic = _connectionDiagnostic;
    if (diagnostic != null) {
      setState(() => _deviceTestResults[_deviceKey(device)] = diagnostic);
    }
  }

  Future<void> _runPrintTestForDevice(EthernetDiscoveredDevice device) async {
    _applyDiscoveredDevice(device);
    if (!_connectionOk) {
      await _runConnectionTest();
      if (!mounted) return;
      if (!_connectionOk) {
        final diagnostic = _connectionDiagnostic;
        if (diagnostic != null) {
          setState(() => _deviceTestResults[_deviceKey(device)] = diagnostic);
        }
        return;
      }
    }
    await _runPrintTest();
    if (!mounted) return;
    final diagnostic = _printDiagnostic ?? _connectionDiagnostic;
    if (diagnostic != null) {
      setState(() => _deviceTestResults[_deviceKey(device)] = diagnostic);
    }
  }

  Future<void> _saveDiscoveredDevice(EthernetDiscoveredDevice device) async {
    _applyDiscoveredDevice(device);
    if (!_connectionOk ||
        _connectionDiagnostic?.host != device.host ||
        _connectionDiagnostic?.port != device.port) {
      await _runConnectionTest();
      if (!mounted) return;
    }
    await _save();
  }

  Future<void> _maybeRefreshNetworkPreflight() async {
    if (kIsWeb) return;
    final host = _ipCtrl.text.trim();
    final rawPort = _portCtrl.text.trim();
    if (host.isEmpty || !isValidEthernetIpv4(host)) {
      if (_networkPreflight != null && mounted) {
        setState(() => _networkPreflight = null);
      }
      return;
    }
    final port = int.tryParse(rawPort) ?? PrinterModel.ethernetDefaultPort;
    try {
      final preflight = await _localPrintService.fetchEthernetNetworkPreflight(
        host: host,
        port: port,
      );
      if (!mounted) return;
      setState(() => _networkPreflight = preflight);
    } catch (_) {
      // Preflight is best-effort; ignore bridge offline here.
    }
  }

  @override
  void dispose() {
    _ipCtrl.removeListener(_onNetworkFieldsChanged);
    _portCtrl.removeListener(_onNetworkFieldsChanged);
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    for (final ctrl in _deviceNameCtrls.values) {
      ctrl.dispose();
    }
    _localPrintService.dispose();
    super.dispose();
  }

  // ── validation helpers ─────────────────────────────────────────────────

  String _buildNameForHost(String host) {
    final raw = _nameCtrl.text.trim();
    if (raw.isNotEmpty) return raw;
    if (host.isEmpty) return 'Ethernet Yazıcı';
    return 'Ethernet Yazıcı $host';
  }

  _EthernetFormValidation _validateForm() {
    final host = _ipCtrl.text.trim();
    final rawPort = _portCtrl.text.trim();
    final name = _buildNameForHost(host);
    debugPrint(
      '[EthernetPrinter][form_value] '
      'name=$name ip=$host port=${rawPort.isEmpty ? PrinterModel.ethernetDefaultPort : rawPort}',
    );
    String? ipError;
    String? portError;
    if (host.isEmpty) {
      ipError = 'IP adresi boş olamaz.';
      debugPrint('[EthernetPrinter][validate_error] field=ip reason=empty');
    } else if (!isValidEthernetIpv4(host)) {
      ipError = 'Geçerli bir IPv4 adresi girin (ör. 192.168.1.100).';
      debugPrint('[EthernetPrinter][validate_error] field=ip reason=invalid_format');
    }
    int port = PrinterModel.ethernetDefaultPort;
    if (rawPort.isNotEmpty) {
      final parsedPort = int.tryParse(rawPort);
      if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        portError = 'Port 1-65535 arasında olmalı.';
        debugPrint(
          '[EthernetPrinter][validate_error] field=port reason=invalid',
        );
      } else {
        port = parsedPort;
      }
    }
    if (ipError == null && portError == null) {
      debugPrint('[EthernetPrinter][validate_success] host=$host port=$port');
    }
    return _EthernetFormValidation(
      host: host,
      port: port,
      name: name,
      ipError: ipError,
      portError: portError,
    );
  }

  UnifiedPrinterModel _buildSyntheticEthernetPrinter(
    _EthernetFormValidation form,
  ) {
    final printerId = PrinterModel.ethernetPrinterId(
      host: form.host,
      port: form.port,
    );
    return UnifiedPrinterModel(
      id: printerId,
      displayName: form.name,
      queueName: form.name,
      backend: DesktopPrinterBackend.tcp,
      os: _orchestrator.detectOs(),
      isAvailable: true,
      canPrint: true,
      statusLevel: 'ready',
      statusMessage: 'Ethernet yazıcı hazır.',
      raw: <String, dynamic>{
        'id': printerId,
        'printer_id': printerId,
        'name': form.name,
        'printer_name': form.name,
        'displayName': form.name,
        'backend': PrinterModel.ethernetBridgeBackend,
        'transportType': PrinterModel.ethernetBridgeTransport,
        'transport_type': PrinterModel.ethernetBridgeTransport,
        'connectionType': PrinterModel.networkConnectionType,
        'connection_type': PrinterModel.networkConnectionType,
        'host': form.host,
        'ip_address': form.host,
        'ipAddress': form.host,
        'port': form.port,
        ..._ethernetProfileFields(),
        'render_mode': 'image',
        'turkish_guarantee_mode': true,
        'source': 'ethernet_dialog_form',
      },
    );
  }

  Map<String, dynamic> _buildEthernetDispatchPayload(
    _EthernetFormValidation form,
  ) {
    final printerId = PrinterModel.ethernetPrinterId(
      host: form.host,
      port: form.port,
    );
    return <String, dynamic>{
      'backend': PrinterModel.ethernetBridgeBackend,
      'transportType': PrinterModel.ethernetBridgeTransport,
      'transport_type': PrinterModel.ethernetBridgeTransport,
      'host': form.host,
      'ip_address': form.host,
      'port': form.port,
      'printer_id': printerId,
      'printer_name': form.name,
      'displayName': form.name,
      ..._ethernetProfileFields(),
      'render_mode': 'image',
      'turkish_guarantee_mode': true,
      'document_type': 'test',
      'printer_role': switch (_role) {
        EthernetPrinterRole.mutfak => 'mutfak',
        _ => 'adisyon',
      },
      'source': 'ethernet_dialog_form',
      ..._receiptLengthSettings.toLiveBridgeFields(paperWidthMm: _paperWidth),
    };
  }

  void _applyValidation(_EthernetFormValidation form) {
    setState(() {
      _ipError = form.ipError;
      _portError = form.portError;
      _formError = null;
    });
  }

  String? _validateSelectedProfile() {
    if (PrinterProfile.byId(_selectedProfileId) == null) {
      return 'Yazıcı profili seçilmedi.';
    }
    return null;
  }

  // ── test actions ───────────────────────────────────────────────────────

  Future<void> _runConnectionTest() async {
    final form = _validateForm();
    if (!form.isValid) {
      _applyValidation(form);
      setState(() {
        _connectionDiagnostic = null;
      });
      return;
    }
    final payload = _buildEthernetDispatchPayload(form);
    setState(() {
      _connectionTesting = true;
      _connectionDiagnostic = null;
      _printDiagnostic = null;
      _formError = null;
      _ipError = null;
      _portError = null;
      _technicalExpanded = false;
    });
    if (kIsWeb && _webAgentHealthy != true) {
      setState(() {
        _connectionTesting = false;
        _connectionDiagnostic = EthernetConnectionDiagnostic(
          ok: false,
          errorCode: 'bridge_unreachable',
          title: 'Masaüstü uygulaması gerekli',
          message: _webAgentMissingMessage,
          host: form.host,
          port: form.port,
        );
      });
      unawaited(_checkWebAgent());
      return;
    }
    final host = form.host;
    final port = form.port;
    debugPrint(
      '[EthernetPrinter][connection_test_start] host=$host port=$port',
    );
    if (_useMobileDirectTcp) {
      try {
        final diagnostic = await _mobileTcp
            .testConnection(host: host, port: port)
            .timeout(const Duration(seconds: 8));
        if (!mounted) return;
        setState(() {
          _connectionDiagnostic = diagnostic;
          if (!diagnostic.ok) _printDiagnostic = null;
        });
        debugPrint(
          diagnostic.ok
              ? '[EthernetPrinter][mobile_connection_ok] host=$host port=$port'
              : '[EthernetPrinter][mobile_connection_error] code=${diagnostic.errorCode}',
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _connectionDiagnostic = resolveEthernetConnectionException(
            error,
            host: host,
            port: port,
          );
          _printDiagnostic = null;
        });
      } finally {
        if (mounted) {
          setState(() => _connectionTesting = false);
        }
      }
      return;
    }
    try {
      final result = await _localPrintService
          .probeTcpPrinter(host: host, port: port, printer: payload)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final diagnostic = resolveEthernetConnectionProbeResult(
        result,
        host: host,
        port: port,
      );
      setState(() {
        _connectionDiagnostic = diagnostic;
        if (!diagnostic.ok) {
          _printDiagnostic = null;
        }
      });
      debugPrint(
        diagnostic.ok
            ? '[EthernetPrinter][connection_test_success] host=$host port=$port'
            : '[EthernetPrinter][connection_test_error] code=${diagnostic.errorCode}',
      );
    } on LocalPrintServiceException catch (error) {
      if (!mounted) return;
      final details = error.details is Map<String, dynamic>
          ? Map<String, dynamic>.from(error.details! as Map<String, dynamic>)
          : null;
      final diagnostic = details == null
          ? resolveEthernetConnectionException(error, host: host, port: port)
          : resolveEthernetConnectionProbeResult(details, host: host, port: port);
      setState(() {
        _connectionDiagnostic = EthernetConnectionDiagnostic(
          ok: diagnostic.ok,
          errorCode: diagnostic.errorCode,
          title: diagnostic.title,
          message: diagnostic.message,
          technicalDetail: error.toString(),
          host: diagnostic.host,
          port: diagnostic.port,
          localIps: diagnostic.localIps,
          sameSubnet: diagnostic.sameSubnet,
          reachable: diagnostic.reachable,
          portOpen: diagnostic.portOpen,
          guidanceSteps: diagnostic.guidanceSteps,
          networkHint: diagnostic.networkHint,
        );
        _printDiagnostic = null;
      });
      debugPrint(
        '[EthernetPrinter][connection_test_error] code=${diagnostic.errorCode}',
      );
    } catch (error) {
      if (!mounted) return;
      final diagnostic = resolveEthernetConnectionException(
        error,
        host: host,
        port: port,
      );
      setState(() {
        _connectionDiagnostic = diagnostic;
        _printDiagnostic = null;
      });
      debugPrint('[EthernetPrinter][connection_test_error] code=exception');
    } finally {
      if (mounted) {
        setState(() {
          _connectionTesting = false;
        });
      }
    }
  }

  Future<void> _runPrintTest() async {
    if (!_connectionOk) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ethernetPrintBlockedWithoutConnectionMessage),
        ),
      );
      return;
    }
    final form = _validateForm();
    if (!form.isValid) {
      _applyValidation(form);
      setState(() => _printDiagnostic = null);
      return;
    }
    final profileError = _validateSelectedProfile();
    if (profileError != null) {
      setState(() {
        _formError = profileError;
        _printDiagnostic = null;
      });
      return;
    }
    final syntheticPrinter = _buildSyntheticEthernetPrinter(form);
    final payload = _buildEthernetDispatchPayload(form);
    debugPrint(
      '[ReceiptLength][ui_test] '
      'preset=${_receiptLengthSettings.preset.bridgeValue} '
      'bottom_feed_lines=${payload['bottom_feed_lines']} '
      'bottom_padding_px=${payload['bottom_padding_px']} '
      'min_receipt_height_px=${payload['min_receipt_height_px']}',
    );
    setState(() {
      _printTesting = true;
      _printDiagnostic = null;
      _formError = null;
      _ipError = null;
      _portError = null;
      _technicalExpanded = false;
    });
    if (kIsWeb && _webAgentHealthy != true) {
      setState(() {
        _printTesting = false;
        _printDiagnostic = EthernetConnectionDiagnostic(
          ok: false,
          errorCode: 'bridge_unreachable',
          title: 'Masaüstü uygulaması gerekli',
          message: _webAgentMissingMessage,
          host: form.host,
          port: form.port,
        );
      });
      unawaited(_checkWebAgent());
      return;
    }
    final host = form.host;
    final port = form.port;
    debugPrint(
      '[EthernetPrinter][test_start] host=$host port=$port backend=tcp',
    );
    if (_useMobileDirectTcp) {
      try {
        final profile = _selectedPrinterProfile;
        final diagnostic = await _mobileTcp
            .printTestReceipt(
              host: host,
              port: port,
              sellerName: form.name,
              autoCut: _autoCut && profile.supportsCut,
              charsPerLine: profile.charsPerLine,
            )
            .timeout(const Duration(seconds: 20));
        if (!mounted) return;
        setState(() => _printDiagnostic = diagnostic);
        debugPrint(
          diagnostic.ok
              ? '[EthernetPrinter][mobile_print_ok] host=$host port=$port'
              : '[EthernetPrinter][mobile_print_error] code=${diagnostic.errorCode}',
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _printDiagnostic = resolveEthernetConnectionException(
            error,
            host: host,
            port: port,
          );
        });
      } finally {
        if (mounted) {
          setState(() => _printTesting = false);
        }
      }
      return;
    }
    try {
      final result = await _orchestrator
          .printBridgeTest(
            restaurantId: widget.restaurantId,
            printerId: syntheticPrinter.id,
            printerName: form.name,
            explicitPrinter: syntheticPrinter,
            skipSetupSnapshot: true,
            targetHost: host,
            targetPort: port,
            extraBody: payload,
            renderMode: 'image',
            testMode: 'ethernet_test',
            flowName: 'ethernet_test_receipt',
            source: 'ethernet_dialog',
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final raw = result.raw;
      final duplicateSuppressed =
          raw?['errorCode']?.toString() == 'duplicate_test_suppressed';
      if (duplicateSuppressed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test fişi zaten gönderiliyor, lütfen bekleyin.'),
          ),
        );
        return;
      }
      if (result.ok) {
        setState(() {
          _printDiagnostic = EthernetConnectionDiagnostic(
            ok: true,
            errorCode: 'ready',
            title: 'Test fişi gönderildi',
            message: 'Test fişi gönderildi. Yazıcı çıktısını kontrol edin.',
            host: host,
            port: port,
          );
        });
      } else {
        final raw = result.raw;
        final diagnostic = raw is Map<String, dynamic>
            ? resolveEthernetConnectionProbeResult(raw, host: host, port: port)
            : EthernetConnectionDiagnostic(
                ok: false,
                errorCode: 'unknown',
                title: 'Test başarısız',
                message: result.message,
                technicalDetail: result.technicalMessage ?? result.message,
                host: host,
                port: port,
                guidanceSteps: ethernetPrinterIpHelpSteps(),
              );
        setState(() {
          _printDiagnostic = EthernetConnectionDiagnostic(
            ok: false,
            errorCode: diagnostic.errorCode,
            title: diagnostic.title,
            message: result.message.isNotEmpty ? result.message : diagnostic.message,
            technicalDetail:
                result.technicalMessage ??
                diagnostic.technicalDetail ??
                result.message,
            host: host,
            port: port,
            localIps: diagnostic.localIps,
            sameSubnet: diagnostic.sameSubnet,
            reachable: diagnostic.reachable,
            portOpen: diagnostic.portOpen,
            guidanceSteps: diagnostic.guidanceSteps,
            networkHint: diagnostic.networkHint,
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      final diagnostic = resolveEthernetConnectionException(
        error,
        host: host,
        port: port,
      );
      setState(() => _printDiagnostic = diagnostic);
    } finally {
      if (mounted) {
        setState(() {
          _printTesting = false;
        });
      }
    }
  }

  // ── save action ────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    final form = _validateForm();
    if (!form.isValid) {
      _applyValidation(form);
      return;
    }
    final profileError = _validateSelectedProfile();
    if (profileError != null) {
      setState(() => _formError = profileError);
      return;
    }
    if (!_connectionOk) {
      setState(() {
        _formError =
            'Kaydetmeden önce "Bağlantıyı Test Et" ile bağlantıyı doğrulayın.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
      _technicalError = null;
      _ipError = null;
      _portError = null;
      _saveStatusMessage = null;
    });
    final host = form.host;
    final port = form.port;
    final name = form.name;
    final isUpdate = widget.existing?.id.isNotEmpty == true;
    // Aynı seller altında ad çakışması engeli (best-effort: liste
    // çekilemezse kayıt engellenmez).
    if (_existingPrinterNames.isEmpty) {
      await _prefetchExistingPrinterNames();
    }
    if (!mounted) return;
    if (PrinterDiscoveryNaming.isDuplicateName(name, _existingPrinterNames)) {
      setState(() {
        _saving = false;
        _formError = 'Bu isimde yazıcı zaten var. Lütfen farklı ad girin.';
      });
      return;
    }
    try {
      final repo = widget.repository ?? PrinterRepository();
      final saved = await repo.upsertEthernetPrinter(
        restaurantId: widget.restaurantId,
        printerId: widget.existing?.id,
        name: name,
        code: 'eth_${host.replaceAll('.', '_')}_$port',
        ipAddress: host,
        port: port,
        paperWidthMm: _paperWidth,
        supportsCut: _autoCut,
        isActive: true,
        assignedRoles: _role.assignedRoles,
        printerProfileId: _selectedPrinterProfile.id,
        receiptLengthSettings: _receiptLengthSettings,
      );
      if (_connectionOk) {
        await repo.recordTestPrintResult(
          printerId: saved.id,
          success: _printOk || _connectionOk,
        );
      }
      if (!mounted) return;
      setState(() {
        _savedToDb = true;
        _saveStatusMessage = 'Kaydedildi';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUpdate ? 'Yazıcı güncellendi.' : 'Yazıcı kaydedildi.'),
        ),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      final connectivity = RestaurantConnectivityService.instance;
      await connectivity.refresh();
      final canLocalSave = !connectivity.hasNetwork ||
          !connectivity.supabaseReachable;
      if (canLocalSave) {
        try {
          await RestaurantOfflineSnapshotSync().upsertFromSellerPanelState(
            restaurantId: widget.restaurantId,
            storeName: widget.restaurantId,
            sellerId: widget.restaurantId,
            storeCategory: 'Restoran',
            printers: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': widget.existing?.id ?? 'local-${PrinterModel.ethernetPrinterId(host: host, port: port)}',
                'name': name,
                'ip_address': host,
                'port': port,
                'device_identifier': PrinterModel.ethernetPrinterId(
                  host: host,
                  port: port,
                ),
                'connection_type': PrinterModel.networkConnectionType,
                'printer_profile_id':
                    PrinterProfile.canonicalDatabaseId(
                      _selectedPrinterProfile.id,
                    ),
                'assigned_roles':
                    _role.assignedRoles.map((role) => role.value).toList(),
              },
            ],
          );
          setState(() {
            _saveStatusMessage = 'Yerel kaydedildi, senkron bekliyor';
            _formError =
                'Yazıcı yerel olarak kaydedildi. İnternet gelince senkronlanacak.';
          });
          return;
        } catch (_) {
          // fall through to DB error message
        }
      }
      setState(() {
        _formError =
            'Yazıcı kaydedilemedi. Profil ve bağlantı bilgilerini kontrol edin.';
        _technicalError = e.toString();
        _saveStatusMessage = 'Kaydedilemedi';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          widget.existing == null
              ? 'Ethernet Yazıcı Ekle'
              : 'Ethernet Yazıcı Düzenle',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroBanner(),
              const SizedBox(height: 16),
              if (kIsWeb) ...[
                WebAgentStatusBanner(
                  healthy: _webAgentHealthy,
                  checking: _webAgentChecking,
                  onRetry: _checkWebAgent,
                ),
                const SizedBox(height: 12),
              ],
              _EthernetAutoScanPanel(
                scanning: _scanning,
                scanResult: _scanResult,
                scanError: _scanError,
                printerHost: _ipCtrl.text.trim(),
                onScan: _runAutoScan,
                onSelectDevice: _applyDiscoveredDevice,
                onTestDevice: _runConnectionTestForDevice,
                onPrintTestDevice: _runPrintTestForDevice,
                onSaveDevice: _saveDiscoveredDevice,
                connectionTesting: _connectionTesting,
                printTesting: _printTesting,
                saving: _saving,
                scanProgressLabel: _scanProgressLabel,
                onCancelScan: _scanning && _useMobileDirectTcp
                    ? _cancelMobileScan
                    : null,
                nameCtrlForDevice: _deviceNameCtrl,
                profileIdForDevice: _deviceProfileId,
                onDeviceProfileChanged: _setDeviceProfile,
                onDeviceTemplateSelected: _applyDeviceNameTemplate,
                testResultForDevice: (device) =>
                    _deviceTestResults[_deviceKey(device)],
              ),
              const SizedBox(height: 16),
              const Text(
                'veya IP adresini manuel girin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Yazıcı Adı',
                fieldKey: const Key('ethernet_name_field'),
                hint: 'Yazıcı adı giriniz',
                controller: _nameCtrl,
                helper:
                    'Boş bırakılırsa kayıtta "Ethernet Yazıcı ${ _ipCtrl.text.trim().isEmpty ? "<IP>" : _ipCtrl.text.trim()}" üretilir.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Field(
                      label: 'IP Adresi',
                      fieldKey: const Key('ethernet_ip_field'),
                      hint: 'IP adresi giriniz',
                      controller: _ipCtrl,
                      errorText: _ipError,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _Field(
                      label: 'Port',
                      fieldKey: const Key('ethernet_port_field'),
                      hint: 'Port',
                      controller: _portCtrl,
                      errorText: _portError,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProfileSelector(
                selectedProfileId: _selectedProfileId,
                onChanged: _applyProfileSelection,
              ),
              const SizedBox(height: 14),
              _Toggle(
                value: _autoCut,
                onChanged: (v) => setState(() => _autoCut = v),
                title: 'Otomatik Kesici',
                subtitle:
                    'Fiş sonunda yazıcı kağıdı otomatik kessin (genelde 80mm yazıcılarda vardır).',
              ),
              const SizedBox(height: 14),
              PrinterReceiptLengthSettingsSection(
                paperWidthMm: _paperWidth,
                settings: _receiptLengthSettings,
                onChanged: (PrinterReceiptLengthSettings settings) =>
                    setState(() => _receiptLengthSettings = settings),
                showTestButton: _connectionOk,
                testing: _printTesting,
                onTestReceipt: _connectionOk ? _runPrintTest : null,
              ),
              const SizedBox(height: 14),
              _RoleSelector(
                value: _role,
                onChanged: (v) => setState(() => _role = v),
              ),
              const SizedBox(height: 14),
              _EthernetHelpPanel(expanded: _helpExpanded, onToggle: () {
                setState(() => _helpExpanded = !_helpExpanded);
              }),
              const SizedBox(height: 14),
              _NetworkCompatibilityCard(
                plan: _networkCompatibilityPlan,
                connectionDiagnostic: _connectionDiagnostic,
              ),
              if (_networkCompatibilityPlan.hasMismatch &&
                  _ipCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _EthernetIpMigrationGuide(
                  plan: _networkCompatibilityPlan,
                  expanded: _migrationGuideExpanded,
                  technicalExpanded: _technicalExpanded,
                  onToggle: () => setState(
                    () => _migrationGuideExpanded = !_migrationGuideExpanded,
                  ),
                  onToggleTechnical: () => setState(
                    () => _technicalExpanded = !_technicalExpanded,
                  ),
                ),
              ],
              if (_manualScanSuccessMessage != null) ...[
                const SizedBox(height: 10),
                _ScanMessageBanner(
                  message: _manualScanSuccessMessage!,
                  isError: false,
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _formError!),
              ],
              if (_technicalError != null) ...[
                const SizedBox(height: 8),
                _TechnicalErrorPanel(error: _technicalError!),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _connectionTesting ? null : _runConnectionTest,
                      icon: _connectionTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded, size: 16),
                      label: const Text('Bağlantıyı Test Et'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _printTesting || !_connectionOk
                          ? null
                          : _runPrintTest,
                      icon: _printTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('Test Fişi Gönder'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_connectionDiagnostic != null) ...[
                const SizedBox(height: 10),
                _DiagnosticResultCard(
                  diagnostic: _connectionDiagnostic!,
                  technicalExpanded: _technicalExpanded,
                  onToggleTechnical: () =>
                      setState(() => _technicalExpanded = !_technicalExpanded),
                ),
              ],
              if (_connectionOk && _printDiagnostic != null) ...[
                const SizedBox(height: 10),
                _DiagnosticResultCard(
                  diagnostic: _printDiagnostic!,
                  technicalExpanded: _technicalExpanded,
                  onToggleTechnical: () =>
                      setState(() => _technicalExpanded = !_technicalExpanded),
                ),
              ],
              const SizedBox(height: 12),
              _SaveStatusChip(
                label: _saveStatusLabel,
                ok: _connectionOk || _savedToDb,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────

class _IntroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF60A5FA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lan_rounded, size: 18, color: Color(0xFF2563EB)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ethernet yazıcınızı "Otomatik Tara" ile bulun veya self-test '
              'fişindeki IP adresini manuel girin. Yazıcı doğrudan TCP ile '
              'yazdırır; CUPS/USB sürücüsü gerekmez.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            errorText: errorText,
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileSelector extends StatelessWidget {
  const _ProfileSelector({
    required this.selectedProfileId,
    required this.onChanged,
  });

  final String selectedProfileId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yazıcı Profili',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        ...PrinterProfile.ethernetSetupProfiles.map((profile) {
          final isSelected = selectedProfileId == profile.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: Key('ethernet_profile_${profile.id}'),
                onTap: () => onChanged(profile.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFF4C1D95)
                                    : const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF8B5CF6),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final EthernetPrinterRole value;
  final ValueChanged<EthernetPrinterRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <(EthernetPrinterRole, IconData, String, String)>[
      (
        EthernetPrinterRole.adisyon,
        Icons.receipt_long_outlined,
        'Adisyon',
        'Müşteri/masa fişi için kullanılır.',
      ),
      (
        EthernetPrinterRole.mutfak,
        Icons.outdoor_grill_outlined,
        'Mutfak',
        'Sipariş geldiğinde mutfak fişi basar.',
      ),
      (
        EthernetPrinterRole.both,
        Icons.compare_arrows_rounded,
        'İkisi (Adisyon + Mutfak)',
        'Hem adisyon hem mutfak fişi bu yazıcıdan basılır.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rol',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        ...entries.map((entry) {
          final (role, icon, label, subtitle) = entry;
          final isSelected = role == value;
          return GestureDetector(
            onTap: () => onChanged(role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF3F0FF) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF4C1D95)
                                : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFFD1D5DB),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B5CF6),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EthernetFormValidation {
  const _EthernetFormValidation({
    required this.host,
    required this.port,
    required this.name,
    this.ipError,
    this.portError,
  });

  final String host;
  final int port;
  final String name;
  final String? ipError;
  final String? portError;

  bool get isValid => ipError == null && portError == null;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalErrorPanel extends StatelessWidget {
  const _TechnicalErrorPanel({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Teknik hatayı kopyala',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: error));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Teknik hata kopyalandı.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED);
    final border = ok ? const Color(0xFF10B981) : const Color(0xFFFDBA74);
    final fg = ok ? const Color(0xFF065F46) : const Color(0xFF9A3412);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified_outlined : Icons.info_outline,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kayıt durumu: $label',
              style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EthernetAutoScanPanel extends StatelessWidget {
  const _EthernetAutoScanPanel({
    required this.scanning,
    required this.scanResult,
    required this.scanError,
    required this.printerHost,
    required this.onScan,
    required this.onSelectDevice,
    required this.onTestDevice,
    required this.onPrintTestDevice,
    required this.onSaveDevice,
    required this.connectionTesting,
    required this.printTesting,
    required this.saving,
    this.scanProgressLabel,
    this.onCancelScan,
    required this.nameCtrlForDevice,
    required this.profileIdForDevice,
    required this.onDeviceProfileChanged,
    required this.onDeviceTemplateSelected,
    required this.testResultForDevice,
  });

  final bool scanning;
  final EthernetScanResult? scanResult;
  final String? scanError;
  final String printerHost;
  final VoidCallback onScan;
  final ValueChanged<EthernetDiscoveredDevice> onSelectDevice;
  final Future<void> Function(EthernetDiscoveredDevice) onTestDevice;
  final Future<void> Function(EthernetDiscoveredDevice) onPrintTestDevice;
  final Future<void> Function(EthernetDiscoveredDevice) onSaveDevice;
  final bool connectionTesting;
  final bool printTesting;
  final bool saving;

  /// Mobil taramada canlı ilerleme ("192.168.1.1 - 192.168.1.254 taranıyor").
  final String? scanProgressLabel;

  /// Mobil taramada iptal; null ise iptal düğmesi gösterilmez.
  final VoidCallback? onCancelScan;

  // Bulunan yazıcı kartı düzenleme durumu (dialog state'inde yaşar).
  final TextEditingController Function(EthernetDiscoveredDevice)
      nameCtrlForDevice;
  final String Function(EthernetDiscoveredDevice) profileIdForDevice;
  final void Function(EthernetDiscoveredDevice, String) onDeviceProfileChanged;
  final void Function(EthernetDiscoveredDevice, String)
      onDeviceTemplateSelected;
  final EthernetConnectionDiagnostic? Function(EthernetDiscoveredDevice)
      testResultForDevice;

  @override
  Widget build(BuildContext context) {
    final devices = scanResult?.devices ?? const <EthernetDiscoveredDevice>[];
    final busy = scanning || connectionTesting || printTesting || saving;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ağ Yazıcı Keşfi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('ethernet_auto_scan_button'),
                onPressed: busy ? null : onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 16),
                label: Text(scanning ? 'Taranıyor…' : 'Otomatik Tara'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          if (scanning && scanProgressLabel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    scanProgressLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                if (onCancelScan != null)
                  TextButton(
                    key: const Key('ethernet_scan_cancel_button'),
                    onPressed: onCancelScan,
                    child: const Text(
                      'İptal',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
          if (scanResult != null) ...[
            const SizedBox(height: 10),
            Text(
              'Bilgisayar IP: ${scanResult!.primaryLocalIp} · '
              'Taranan ağ: ${scanResult!.primarySubnet}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
          if (scanError != null) ...[
            const SizedBox(height: 10),
            _ScanMessageBanner(message: scanError!, isError: true),
          ] else if (scanResult != null && scanResult!.ok) ...[
            const SizedBox(height: 10),
            _ScanMessageBanner(
              message: devices.isEmpty
                  ? ethernetScanNoDeviceMessage(
                      scanResult: scanResult!,
                      printerHost: printerHost,
                    )
                  : (scanResult!.message.isNotEmpty
                      ? scanResult!.message
                      : '${devices.length} cihaz bulundu.'),
              isError: devices.isEmpty,
            ),
          ],
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...devices.map((device) {
              return _DiscoveredDeviceRow(
                device: device,
                localIps: scanResult?.localIps ?? const <String>[],
                busy: busy,
                onSelect: () => onSelectDevice(device),
                onTest: () => onTestDevice(device),
                onPrintTest: () => onPrintTestDevice(device),
                onSave: () => onSaveDevice(device),
                nameController: nameCtrlForDevice(device),
                profileId: profileIdForDevice(device),
                onProfileChanged: (profileId) =>
                    onDeviceProfileChanged(device, profileId),
                onTemplateSelected: (template) =>
                    onDeviceTemplateSelected(device, template),
                testResult: testResultForDevice(device),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ScanMessageBanner extends StatelessWidget {
  const _ScanMessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFDBA74) : const Color(0xFF10B981),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 11,
          color: isError ? const Color(0xFF9A3412) : const Color(0xFF065F46),
          height: 1.4,
        ),
      ),
    );
  }
}

/// Web'de masaüstü yazıcı yardımcısı (local print agent) durum kartı.
class WebAgentStatusBanner extends StatelessWidget {
  const WebAgentStatusBanner({
    super.key,
    required this.healthy,
    required this.checking,
    required this.onRetry,
  });

  final bool? healthy;
  final bool checking;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final connected = healthy == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              connected ? const Color(0xFF10B981) : const Color(0xFFFDBA74),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected
                    ? Icons.check_circle_outline
                    : Icons.desktop_windows_outlined,
                size: 18,
                color: connected
                    ? const Color(0xFF059669)
                    : const Color(0xFF9A3412),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connected
                      ? 'Masaüstü yazıcı yardımcısı bağlı'
                      : 'Web\'den yazıcı taramak için İBUL Satıcı Masaüstü '
                          'uygulaması açık olmalı.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: connected
                        ? const Color(0xFF065F46)
                        : const Color(0xFF9A3412),
                  ),
                ),
              ),
            ],
          ),
          if (!connected) ...[
            const SizedBox(height: 6),
            const Text(
              'Web tarayıcı güvenliği nedeniyle yazıcıya doğrudan '
              'bağlanamaz. Masaüstü uygulaması açıkken tarama, test ve '
              'baskı yapılabilir.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9A3412),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  key: const Key('web_agent_download_button'),
                  onPressed: () =>
                      SellerDownloadAppContent.openDownloadOrExplain(
                    context,
                    AppRuntimeConfig.sellerDesktopWindowsDownloadUrlOrNull,
                  ),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF8B5CF6),
                  ),
                  label: const Text(
                    'Masaüstü uygulamasını indir',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('web_agent_retry_button'),
                  onPressed: checking ? null : onRetry,
                  icon: checking
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  label: const Text(
                    'Tekrar dene',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveredDeviceRow extends StatelessWidget {
  const _DiscoveredDeviceRow({
    required this.device,
    required this.localIps,
    required this.busy,
    required this.onSelect,
    required this.onTest,
    required this.onPrintTest,
    required this.onSave,
    required this.nameController,
    required this.profileId,
    required this.onProfileChanged,
    required this.onTemplateSelected,
    required this.testResult,
  });

  final EthernetDiscoveredDevice device;
  final List<String> localIps;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onTest;
  final VoidCallback onPrintTest;
  final VoidCallback onSave;
  final TextEditingController nameController;
  final String profileId;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<String> onTemplateSelected;
  final EthernetConnectionDiagnostic? testResult;

  @override
  Widget build(BuildContext context) {
    final reachable = device.reachable && device.portOpen;
    final statusColor = reachable
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);
    final hint = device.sameSubnet == false
        ? (device.networkHint.isNotEmpty
            ? device.networkHint
            : formatDifferentSubnetWarning(
                localIps: localIps,
                printerHost: device.host,
              ))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: device.sameSubnet == false
              ? const Color(0xFFFDBA74)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: busy ? null : onSelect,
            child: Row(
              children: [
                Icon(
                  Icons.print_outlined,
                  size: 18,
                  color: reachable
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IP: ${device.host} · Port: ${device.port}'
                        '${device.latencyMs != null ? ' · Gecikme: ${device.latencyMs} ms' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        device.reachabilityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: Key('ethernet_select_${device.host}'),
                  onPressed: busy ? null : onSelect,
                  child: const Text('Forma Aktar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Ad düzenleme: kaydetmeden önce yazıcıya isim verin.
          TextField(
            key: Key('ethernet_device_name_${device.host}'),
            controller: nameController,
            enabled: !busy,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Yazıcı adı',
              labelStyle: const TextStyle(fontSize: 11.5),
              prefixIcon: const Icon(Icons.edit_outlined, size: 16),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Hızlı ad şablonları.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final template
                  in PrinterDiscoveryNaming.quickNameTemplates)
                ActionChip(
                  key: Key(
                    'ethernet_template_${device.host}_'
                    '${template.split(' ').first.toLowerCase()}',
                  ),
                  label: Text(
                    template,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: busy ? null : () => onTemplateSelected(template),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Profil seçimi (POS-80 / POS-58 / Generic 80mm).
          DropdownButtonFormField<String>(
            key: Key('ethernet_device_profile_${device.host}'),
            initialValue: PrinterProfile.byId(profileId) != null
                ? profileId
                : PrinterProfile.pos80.id,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Yazıcı profili',
              labelStyle: const TextStyle(fontSize: 11.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              for (final profile in PrinterProfile.ethernetSetupProfiles)
                DropdownMenuItem<String>(
                  value: profile.id,
                  child: Text(
                    profile.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) onProfileChanged(value);
                  },
          ),
          if (hint != null && hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9A3412),
                height: 1.35,
              ),
            ),
          ],
          if (testResult != null) ...[
            const SizedBox(height: 8),
            Container(
              key: Key('ethernet_device_test_status_${device.host}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: testResult!.ok
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: testResult!.ok
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Text(
                testResult!.ok
                    ? 'Test başarılı'
                    : (testResult!.message.isNotEmpty
                        ? testResult!.message
                        : 'Yazıcıya ulaşılamadı. Telefon ve yazıcı aynı '
                            'Wi-Fi ağında mı kontrol edin.'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: testResult!.ok
                      ? const Color(0xFF065F46)
                      : const Color(0xFF991B1B),
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                key: Key('ethernet_scan_test_${device.host}'),
                onPressed: busy ? null : onTest,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
                child: const Text(
                  'Bağlantıyı Test Et',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              OutlinedButton(
                key: Key('ethernet_scan_print_${device.host}'),
                onPressed: busy ? null : onPrintTest,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Test Fişi Bas',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              FilledButton(
                key: Key('ethernet_scan_save_${device.host}'),
                onPressed: busy ? null : onSave,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF10B981),
                ),
                child: const Text('Kaydet', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EthernetHelpPanel extends StatelessWidget {
  const _EthernetHelpPanel({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.help_outline, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Yazıcı IP\'sini nasıl bulurum?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ethernetPrinterIpHelpSteps().map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF374151),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetworkCompatibilityCard extends StatelessWidget {
  const _NetworkCompatibilityCard({
    required this.plan,
    this.connectionDiagnostic,
  });

  final EthernetNetworkCompatibilityPlan plan;
  final EthernetConnectionDiagnostic? connectionDiagnostic;

  @override
  Widget build(BuildContext context) {
    final portStatusLabel = _portStatusLabel(connectionDiagnostic);
    final portStatusColor = _portStatusColor(connectionDiagnostic);
    final mismatch = plan.hasMismatch;
    final guidance = plan.mismatchGuidance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mismatch ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mismatch ? const Color(0xFFFDBA74) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ağ Uyumluluk Durumu',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          _DiagnosticRow(
            label: 'Bilgisayar IP',
            value: plan.primaryLocalIp,
          ),
          _DiagnosticRow(
            label: 'Taranan ağ',
            value: plan.primaryScannedSubnet.isEmpty
                ? 'IP girilince hesaplanır'
                : plan.primaryScannedSubnet,
          ),
          _DiagnosticRow(
            label: 'Yazıcı IP',
            value: plan.printerHost.isEmpty ? '—' : plan.printerHost,
          ),
          _DiagnosticRow(
            label: 'Port',
            value: plan.printerHost.isEmpty
                ? '—'
                : '${plan.port} ($portStatusLabel)',
            valueColor: portStatusColor,
          ),
          _DiagnosticRow(
            label: 'Aynı ağda mı?',
            value: plan.sameSubnetLabel,
            valueColor: mismatch
                ? const Color(0xFFDC2626)
                : const Color(0xFF059669),
          ),
          if (guidance.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              guidance,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9A3412),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _portStatusLabel(EthernetConnectionDiagnostic? diagnostic) {
    if (diagnostic?.ok == true) return 'Açık';
    if (diagnostic == null) return 'Test edilmedi';
    final code = diagnostic.errorCode;
    if (code == 'tcp_refused') return 'Kapalı';
    if (code == 'tcp_timeout' ||
        code == 'network_unreachable' ||
        code == 'network_mismatch') {
      return 'Yanıt yok';
    }
    return 'Test edilmedi';
  }

  Color _portStatusColor(EthernetConnectionDiagnostic? diagnostic) {
    if (diagnostic?.ok == true) return const Color(0xFF059669);
    if (diagnostic != null && diagnostic.ok == false) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF6B7280);
  }
}

class _EthernetIpMigrationGuide extends StatelessWidget {
  const _EthernetIpMigrationGuide({
    required this.plan,
    required this.expanded,
    required this.technicalExpanded,
    required this.onToggle,
    required this.onToggleTechnical,
  });

  final EthernetNetworkCompatibilityPlan plan;
  final bool expanded;
  final bool technicalExpanded;
  final VoidCallback onToggle;
  final VoidCallback onToggleTechnical;

  @override
  Widget build(BuildContext context) {
    final options = ethernetPrinterMigrationOptions(plan: plan);
    final aliasCommands = ethernetTechnicalAliasCommands(
      printerHost: plan.printerHost,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: Color(0xFF9A3412),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yazıcı IP\'sini İşletme Ağına Taşı',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF9A3412),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFFDBA74)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu yazıcıyı çalıştırmak için IP adresini '
                    '${plan.suggestedTargetSubnet.replaceAll('.0/24', '.x')} '
                    'ağına almalısınız.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C2D12),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SuggestedSettingsTable(plan: plan),
                  const SizedBox(height: 12),
                  const Text(
                    'Kurulum seçenekleri',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...options.asMap().entries.map((entry) {
                    final labels = <String>['A', 'B', 'C'];
                    final label = entry.key < labels.length
                        ? labels[entry.key]
                        : '${entry.key + 1}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$label) ',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF374151),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (aliasCommands.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onToggleTechnical,
                      child: Row(
                        children: [
                          Icon(
                            technicalExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Gelişmiş / Teknik Servis',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (technicalExpanded) ...[
                      const SizedBox(height: 6),
                      ...aliasCommands.map(
                        (command) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SelectableText(
                            command,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestedSettingsTable extends StatelessWidget {
  const _SuggestedSettingsTable({required this.plan});

  final EthernetNetworkCompatibilityPlan plan;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Önerilen Yazıcı IP', plan.suggestedPrinterIp),
      ('Alt Ağ Maskesi', plan.subnetMask),
      ('Ağ Geçidi', plan.suggestedGateway),
      ('Port', '${plan.port}'),
      ('Profil', 'POS-80'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _DiagnosticRow(label: row.$1, value: row.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF111827),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticResultCard extends StatelessWidget {
  const _DiagnosticResultCard({
    required this.diagnostic,
    required this.technicalExpanded,
    required this.onToggleTechnical,
  });

  final EthernetConnectionDiagnostic diagnostic;
  final bool technicalExpanded;
  final VoidCallback onToggleTechnical;

  @override
  Widget build(BuildContext context) {
    final bg = diagnostic.ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final border = diagnostic.ok ? const Color(0xFF10B981) : const Color(0xFFFECACA);
    final fg = diagnostic.ok ? const Color(0xFF065F46) : const Color(0xFF991B1B);
    final technical = diagnostic.technicalDetail?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                diagnostic.ok
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diagnostic.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diagnostic.message,
                      style: TextStyle(fontSize: 12, color: fg, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (technical.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onToggleTechnical,
              child: Row(
                children: [
                  Icon(
                    technicalExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: fg,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Teknik detay',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: technical));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Teknik detay kopyalandı')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Kopyala', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            if (technicalExpanded)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border.withValues(alpha: 0.5)),
                ),
                child: SelectableText(
                  technical,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Color(0xFF374151),
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
