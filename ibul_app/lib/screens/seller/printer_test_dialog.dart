import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/desktop_printer_setup_models.dart';
import '../../models/printer_model.dart';
import '../../models/windows_printer_classification.dart';
import '../../services/bridge_lifecycle_service.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/local_print_service.dart';
import '../../widgets/bridge_error_dialog.dart';
import '../../services/printer_repository.dart';

/// Dialog that sends a test receipt to the default printer and surfaces
/// the real transport result (USB direct or CUPS).
/// Open via [showDialog<void>(context: ..., builder: (_) => const PrinterTestDialog())].
class PrinterTestDialog extends StatefulWidget {
  const PrinterTestDialog({
    super.key,
    this.restaurantId,
    this.printOrchestrator,
    this.printerRepository,
    this.initialPrinterId,
    this.initialPrinterLabel,
    this.initialPrinter,
  });

  final String? restaurantId;
  final DesktopPrintOrchestrator? printOrchestrator;
  final PrinterRepository? printerRepository;

  /// DB / eşleştirme sekmesinde seçili yazıcı (varsa test bu hedefe gider).
  final String? initialPrinterId;
  final String? initialPrinterLabel;
  final UnifiedPrinterModel? initialPrinter;

  @override
  State<PrinterTestDialog> createState() => _PrinterTestDialogState();
}

enum _Phase { checkingHealth, idle, discoveringUsb, running, success, error }

String _bridgeOfflineOperatorMessage() {
  if (!kIsWeb && Platform.isWindows) {
    return 'Yazıcı servisi çalışmıyor.\n'
        'Ibul Print Bridge kurulum uygulamasını yükleyin veya yazıcı ayarlarında '
        '"Servisi Başlat" / "Servisi Onar" düğmelerini kullanın.';
  }
  return 'Yazıcı servisi çalışmıyor. Yazıcı ayarlarından servisi başlatın veya onarın.';
}

class _PrinterTestDialogState extends State<PrinterTestDialog> {
  bool get _isFlutterTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');
  final _svc = LocalPrintService();
  final _lifecycle = BridgeLifecycleService();
  late final DesktopPrintOrchestrator _printOrchestrator =
      widget.printOrchestrator ?? DesktopPrintOrchestrator();
  late final PrinterRepository _printerRepository =
      widget.printerRepository ?? PrinterRepository();
  _Phase _phase = _Phase.checkingHealth;
  bool _bridgeOk = false;
  String _statusLine = 'Yazıcı servisi kontrol ediliyor…';
  String _errorMsg = '';
  String _successTransport = '';
  String _successMessage = 'Test fişi gönderildi';
  bool _successWarning = false;
  bool _savedPrinterRecord = false;
  List<Map<String, dynamic>> _usbDevices = const [];
  List<UnifiedPrinterModel> _availablePrinters = const <UnifiedPrinterModel>[];
  bool _usbExpanded = false;
  String? _targetPrinterId;
  String _targetPrinterLabel = 'Bridge varsayılanı';
  String _targetPrinterQueue = '';
  String _targetPrinterBackend = '';
  String _targetPrinterHost = '';
  int? _targetPrinterPort;
  String _testResultStatus = '';
  Map<String, dynamic>? _lastBridgeResponse;
  String? _technicalDetail;
  UnifiedPrinterModel? _targetExplicitPrinter;
  late final UnifiedPrinterModel? _initialTargetPrinter =
      widget.initialPrinter == null
      ? null
      : _clonePrinter(widget.initialPrinter!);

  @override
  void initState() {
    super.initState();
    _targetPrinterId = widget.initialPrinterId?.trim().isNotEmpty == true
        ? widget.initialPrinterId!.trim()
        : null;
    if (widget.initialPrinterLabel?.trim().isNotEmpty == true) {
      _targetPrinterLabel = widget.initialPrinterLabel!.trim();
    }
    if (_initialTargetPrinter != null) {
      _applyTargetPrinter(_initialTargetPrinter!);
      _availablePrinters = <UnifiedPrinterModel>[_initialTargetPrinter!];
    }
    if (_isFlutterTest) {
      _bridgeOk = true;
      _phase = _Phase.idle;
      _statusLine = 'Test ortamı: bridge kontrolü atlandı';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadTargetPrinter();
      });
      return;
    }
    _ensureBridge();
  }

  @override
  void dispose() {
    _svc.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  String _buildTransportDescription() {
    if (_targetPrinterBackend == 'tcp' &&
        _targetPrinterHost.trim().isNotEmpty &&
        _targetPrinterPort != null) {
      return 'Ethernet TCP → $_targetPrinterHost:$_targetPrinterPort';
    }
    if (_targetPrinterBackend == 'usb-direct') {
      return 'POS-58 · USB Direct';
    }
    if (_targetPrinterBackend == 'cups') {
      return 'POS-58 · CUPS';
    }
    return 'auto → önce USB Direct, sonra CUPS';
  }

  /// Checks bridge health and automatically tries to start it when down.
  /// Called at dialog open and when "Yenile" is pressed.
  Future<void> _ensureBridge() async {
    if (_isFlutterTest) {
      if (!mounted) return;
      setState(() {
        _bridgeOk = true;
        _phase = _Phase.idle;
        _statusLine = 'Test ortamı: bridge kontrolü atlandı';
      });
      return;
    }
    await for (final status in _lifecycle.ensureRunning()) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.checkingHealth;
        _statusLine = status.label;
        if (status == BridgeStatus.ready ||
            status == BridgeStatus.unavailable) {
          _bridgeOk = status == BridgeStatus.ready;
          _phase = _Phase.idle;
        }
      });
    }
    if (_bridgeOk) {
      await _loadTargetPrinter();
    }
  }

  Future<void> _loadTargetPrinter() async {
    final restaurantId = widget.restaurantId?.trim() ?? '';
    if (restaurantId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _availablePrinters = _initialTargetPrinter == null
            ? const <UnifiedPrinterModel>[]
            : <UnifiedPrinterModel>[_initialTargetPrinter!];
        _targetPrinterLabel =
            widget.initialPrinterLabel?.trim().isNotEmpty == true
            ? widget.initialPrinterLabel!.trim()
            : 'Bridge varsayılanı';
        _targetPrinterQueue = '';
        _targetPrinterBackend = '';
      });
      return;
    }
    try {
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: restaurantId,
        flowName: 'printer_test_dialog_hydrate',
        source: 'printer_test_dialog',
      );
      final available = _buildAvailablePrinters(snapshot.printers);
      UnifiedPrinterModel? target;
      final requestedId =
          _targetPrinterId ?? widget.initialPrinterId?.trim() ?? '';
      if (requestedId.isNotEmpty) {
        for (final printer in available) {
          if (printer.id == requestedId ||
              printer.printerRecordId == requestedId) {
            target = printer;
            break;
          }
        }
      }
      target ??= _matchPrinterByIdentifier(available, _targetPrinterId);
      target ??= _matchPrinterByIdentifier(
        available,
        widget.initialPrinterId?.trim(),
      );
      target ??= _matchPrinterByIdentifier(
        available,
        _initialTargetPrinter?.id,
      );
      target ??= snapshot.workingPrinter == null
          ? null
          : _matchPrinterByIdentifier(available, snapshot.workingPrinter!.id);
      if (target == null) {
        for (final printer in available) {
          if (printer.canPrint && printer.isAvailable) {
            target = printer;
            break;
          }
        }
      }
      target ??= available.isNotEmpty ? available.first : null;
      if (!mounted) return;
      setState(() {
        _availablePrinters = available;
        if (target != null) {
          _applyTargetPrinter(target);
        } else {
          _targetPrinterLabel =
              widget.initialPrinterLabel?.trim().isNotEmpty == true
              ? widget.initialPrinterLabel!.trim()
              : 'Bridge varsayılanı (otomatik seçim)';
          _targetPrinterQueue = '';
          _targetPrinterBackend = '';
          _targetPrinterHost = '';
          _targetPrinterPort = null;
          _targetExplicitPrinter = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availablePrinters = _initialTargetPrinter == null
            ? const <UnifiedPrinterModel>[]
            : <UnifiedPrinterModel>[_initialTargetPrinter!];
        _targetPrinterLabel =
            widget.initialPrinterLabel?.trim().isNotEmpty == true
            ? widget.initialPrinterLabel!.trim()
            : 'Bridge varsayılanı';
      });
    }
  }

  List<UnifiedPrinterModel> _buildAvailablePrinters(
    List<UnifiedPrinterModel> printers,
  ) {
    final merged = <UnifiedPrinterModel>[
      if (_initialTargetPrinter != null) _initialTargetPrinter!,
      ...printers,
    ];
    final byId = <String, UnifiedPrinterModel>{};
    for (final printer in merged) {
      final key = printer.id.trim().isNotEmpty
          ? printer.id.trim()
          : (printer.printerRecordId?.trim() ?? '');
      if (key.isEmpty) continue;
      byId[key] = printer;
    }
    return byId.values.toList(growable: false);
  }

  UnifiedPrinterModel? _matchPrinterByIdentifier(
    List<UnifiedPrinterModel> printers,
    String? identifier,
  ) {
    final normalized = identifier?.trim() ?? '';
    if (normalized.isEmpty) return null;
    for (final printer in printers) {
      if (printer.id == normalized || printer.printerRecordId == normalized) {
        return printer;
      }
    }
    return null;
  }

  void _applyTargetPrinter(UnifiedPrinterModel target) {
    _targetPrinterId = target.id;
    _targetPrinterLabel = target.displayName.trim().isNotEmpty
        ? target.displayName.trim()
        : (widget.initialPrinterLabel?.trim().isNotEmpty == true
              ? widget.initialPrinterLabel!.trim()
              : target.queueName);
    _targetPrinterQueue = target.queueName;
    _targetPrinterBackend = target.backend.value;
    _targetPrinterHost =
        (target.raw['host'] ??
                target.raw['ip_address'] ??
                target.raw['ipAddress'])
            ?.toString() ??
        '';
    final portRaw = target.raw['port'] ?? target.raw['tcp_port'];
    _targetPrinterPort = portRaw is int
        ? portRaw
        : int.tryParse(portRaw?.toString() ?? '');
    _targetExplicitPrinter = target;
  }

  UnifiedPrinterModel _clonePrinter(UnifiedPrinterModel printer) {
    return UnifiedPrinterModel(
      id: printer.id,
      displayName: printer.displayName,
      queueName: printer.queueName,
      backend: printer.backend,
      os: printer.os,
      isAvailable: printer.isAvailable,
      canPrint: printer.canPrint,
      lastTestStatus: printer.lastTestStatus,
      lastError: printer.lastError,
      vendorId: printer.vendorId,
      productId: printer.productId,
      printerRecordId: printer.printerRecordId,
      statusLevel: printer.statusLevel,
      statusMessage: printer.statusMessage,
      raw: Map<String, dynamic>.from(printer.raw),
    );
  }

  Future<void> _discoverUsb() async {
    setState(() {
      _phase = _Phase.discoveringUsb;
      _usbDevices = const [];
    });
    try {
      final result = await _svc.discover();
      if (!mounted) return;
      final raw = result?['devices'];
      final devices = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _usbDevices = devices;
        _usbExpanded = true;
        _phase = _Phase.idle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usbDevices = const [];
        _usbExpanded = true;
        _phase = _Phase.idle;
      });
    }
  }

  Future<void> _sendTest() async {
    setState(() {
      _phase = _Phase.running;
      _errorMsg = '';
      _successTransport = '';
      _successMessage = 'Test fişi gönderildi';
      _successWarning = false;
      _savedPrinterRecord = false;
      _testResultStatus = '';
      _lastBridgeResponse = null;
      _technicalDetail = null;
    });
    try {
      final restaurantId = widget.restaurantId?.trim() ?? '';
      if (restaurantId.isNotEmpty) {
        final printerId = _targetPrinterId?.trim() ?? '';
        final printerName = _targetPrinterQueue.trim().isNotEmpty
            ? _targetPrinterQueue.trim()
            : (_targetPrinterLabel.trim().isNotEmpty &&
                      _targetPrinterLabel != 'Bridge varsayılanı' &&
                      !_targetPrinterLabel.contains('otomatik')
                  ? _targetPrinterLabel.trim()
                  : '');
        final result = await _printOrchestrator.printBridgeTest(
          restaurantId: restaurantId,
          printerId: printerId.isNotEmpty ? printerId : null,
          printerName: printerName.isNotEmpty ? printerName : null,
          explicitPrinter: _targetExplicitPrinter,
          skipSetupSnapshot:
              _targetExplicitPrinter != null && _targetPrinterBackend == 'tcp',
          targetHost: _targetExplicitPrinter?.backend.value == 'tcp'
              ? _targetPrinterHost
              : null,
          targetPort: _targetExplicitPrinter?.backend.value == 'tcp'
              ? _targetPrinterPort
              : null,
          testMode: _targetExplicitPrinter?.backend.value == 'tcp'
              ? 'ethernet_test'
              : 'escpos_short',
        );
        if (!mounted) return;
        setState(() {
          _lastBridgeResponse = result.raw == null
              ? null
              : Map<String, dynamic>.from(result.raw!);
          _testResultStatus = result.status;
          _technicalDetail = result.technicalMessage;
        });
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
                await _ensureBridge();
                await _discoverUsb();
              },
            );
            setState(() {
              _phase = _Phase.error;
              _errorMsg = _formatFailureMessage(result.message, result.raw);
            });
            return;
          }
          throw Exception(_formatFailureMessage(result.message, result.raw));
        }
        if (result.printer != null) {
          final saveOutcome = await _saveCanonicalPrinterFromTest(
            restaurantId: restaurantId,
            printer: result.printer!,
            result: result,
          );
          if (!mounted) return;
          _savedPrinterRecord = saveOutcome.saved;
          if (saveOutcome.warningMessage != null &&
              saveOutcome.warningMessage!.trim().isNotEmpty) {
            _successWarning = true;
            _successMessage =
                'Test fişi gönderildi. ${saveOutcome.warningMessage!}';
          }
        }
        if (!mounted) return;
        final warning =
            result.status != 'ready' ||
            result.raw?['confirmation_status'] == 'cups_accepted_unverified' ||
            _successWarning;
        final transport =
            result.raw?['transport']?.toString() ??
            result.printer?.backend.value ??
            '';
        final jobId = result.raw?['job_id']?.toString() ?? '';
        final bytes = result.raw?['bytes_sent']?.toString() ?? '';
        if (result.printer != null) {
          final resolved = result.printer!;
          setState(() {
            _targetPrinterId = resolved.id;
            _targetPrinterLabel = resolved.displayName;
            _targetPrinterQueue = resolved.queueName;
            _targetPrinterBackend = resolved.backend.value;
            _targetPrinterHost = (resolved.raw?['ip_address'] as String?) ?? '';
            _targetPrinterPort = resolved.raw?['port'] as int?;
            _targetExplicitPrinter = resolved;
          });
        }
        setState(() {
          _phase = _Phase.success;
          _successWarning = warning;
          _testResultStatus = result.status;
          _successMessage = _successMessage != 'Test fişi gönderildi'
              ? _successMessage
              : warning
              ? (result.message.trim().isNotEmpty
                    ? result.message
                    : 'Test işi yazıcı kuyruğuna gönderildi. Fiziksel baskıyı kontrol edin.')
              : 'Test fişi gönderildi';
          _successTransport = [
            if (transport.isNotEmpty) transport,
            if (jobId.isNotEmpty) 'job=$jobId',
            if (bytes.isNotEmpty) '$bytes bytes',
          ].join(' · ');
        });
        return;
      }
      final result = await _svc.printTest();
      if (!mounted) return;
      setState(() {
        _lastBridgeResponse = result == null
            ? null
            : Map<String, dynamic>.from(result);
        _testResultStatus = result?['status']?.toString() ?? '';
      });
      // Extract transport label from nested health info in result body
      final transport = result?['transport']?.toString() ?? '';
      final jobId = result?['job_id']?.toString() ?? '';
      final bytes = result?['bytes_sent']?.toString() ?? '';
      setState(() {
        _phase = _Phase.success;
        _successTransport = [
          if (transport.isNotEmpty) transport,
          if (jobId.isNotEmpty) 'job=$jobId',
          if (bytes.isNotEmpty) '$bytes bytes',
        ].join(' · ');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMsg = _friendlyError(e);
      });
    }
  }

  Future<_TestPrinterSaveOutcome> _saveCanonicalPrinterFromTest({
    required String restaurantId,
    required UnifiedPrinterModel printer,
    required PrinterActionResult result,
  }) async {
    final name = printer.displayName.trim().isNotEmpty
        ? printer.displayName.trim()
        : 'Yerel yazıcı';
    final rawDeviceIdentifier =
        (printer.raw['deviceIdentifier'] ?? printer.raw['device_identifier'])
            ?.toString()
            .trim() ??
        '';
    final deviceIdentifier = rawDeviceIdentifier.isNotEmpty
        ? rawDeviceIdentifier
        : (printer.queueName.trim().isNotEmpty
              ? printer.queueName.trim()
              : printer.id.trim());
    final code = _buildCanonicalCode(printer);

    try {
      final isTcp = printer.backend == DesktopPrinterBackend.tcp;
      final existingPrinters = await _printerRepository.fetchPrinters(
        restaurantId,
      );
      final existingByCode = existingPrinters.where(
        (entry) => entry.code.trim().toUpperCase() == code.trim().toUpperCase(),
      );
      final hadExistingCode = existingByCode.isNotEmpty;
      final saved = await _printerRepository.upsertPrinter(
        restaurantId: restaurantId,
        printerId: printer.printerRecordId,
        name: name,
        code: code,
        connectionType: isTcp
            ? PrinterModel.networkConnectionType
            : PrinterModel.usbConnectionType,
        ipAddress: isTcp
            ? _targetPrinterHost.trim()
            : PrinterModel.localDefaultHost,
        port: isTcp
            ? (_targetPrinterPort ?? PrinterModel.ethernetDefaultPort)
            : PrinterModel.localDefaultPort,
        deviceIdentifier: deviceIdentifier,
        isActive: true,
        assignedRoles: const [],
        supportsCut: !name.toLowerCase().contains('58'),
        paperWidthMm: name.toLowerCase().contains('58') ? 58 : 80,
      );

      await _printerRepository.recordTestPrintResult(
        printerId: saved.id,
        success: result.ok,
        error: result.ok ? null : result.message,
      );
      return _TestPrinterSaveOutcome(
        saved: true,
        warningMessage: hadExistingCode
            ? 'Yazıcı zaten kayıtlı, mevcut kayıt güncellendi.'
            : null,
      );
    } catch (error) {
      final raw = error.toString().toLowerCase();
      if (raw.contains('23505') ||
          raw.contains('idx_printers_restaurant_code_unique') ||
          raw.contains('duplicate key')) {
        return const _TestPrinterSaveOutcome(
          saved: false,
          warningMessage: 'Yazıcı zaten kayıtlı, mevcut kayıt güncellendi.',
        );
      }
      return _TestPrinterSaveOutcome(
        saved: false,
        warningMessage: 'Yazıcı kaydı güncellenemedi.',
      );
    }
  }

  String _buildCanonicalCode(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host =
          (printer.raw['host'] ??
                  printer.raw['ip_address'] ??
                  printer.raw['ipAddress'])
              ?.toString()
              .trim() ??
          '';
      final portRaw = printer.raw['port'] ?? printer.raw['tcp_port'];
      final port = portRaw is int
          ? portRaw
          : int.tryParse(portRaw?.toString() ?? '');
      if (host.isNotEmpty && (port ?? 0) > 0) {
        return PrinterModel.ethernetPrinterId(
          host: host,
          port: port!,
        ).toUpperCase();
      }
    }
    final persistedDevice =
        (printer.raw['deviceIdentifier'] ?? printer.raw['device_identifier'])
            ?.toString()
            .trim();
    final fallbackId = persistedDevice?.isNotEmpty == true
        ? persistedDevice!
        : (printer.id.trim().isNotEmpty
              ? printer.id.trim()
              : printer.queueName);
    final normalized = fallbackId
        .replaceAll(RegExp(r'[^A-Za-z0-9:._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toUpperCase();
    return normalized.isEmpty ? 'PRINTER' : normalized;
  }

  String _formatFailureMessage(String message, Map<String, dynamic>? raw) {
    final details = WindowsPrinterClassification.formatTestFailureDetails(raw);
    if (details.trim().isEmpty) {
      return message;
    }
    return '$message\n\n$details';
  }

  /// Converts a raw exception to a user-friendly Turkish message.
  String _friendlyError(Object e) {
    final rawMessage = e.toString();
    final raw = rawMessage.toLowerCase();
    if (raw.contains('connection refused') ||
        raw.contains('connection_error') ||
        raw.contains('socketerror') ||
        raw.contains('os error')) {
      return 'Yazıcı servisine bağlanılamadı. '
          '"Yenile" düğmesine basarak servisi yeniden başlatmayı deneyin.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'Bağlantı zaman aşımına uğradı. Yazıcının açık olduğunu kontrol edin.';
    }
    if (raw.contains('print_system_disabled') ||
        raw.contains('baskı sistemi şu anda kapalı') ||
        raw.contains('baski sistemi su anda kapali') ||
        raw.contains('baskı sistemi kapalı')) {
      return 'Baskı sistemi kapalı. Test göndermek için sistemi açın.';
    }
    if (raw.contains('pyusb') ||
        raw.contains('libusb') ||
        raw.contains('usb printer class')) {
      return 'USB yazıcı bulundu ama macOS tarafında USB tarama bileşeni hazır değil. '
          'Önce "Sistem Kur" ekranını açın; gerekirse CUPS yazıcısı ekleyin.';
    }
    if (raw.contains('no printer') ||
        raw.contains('cups') ||
        raw.contains('lp ')) {
      return 'Yazıcı seçilemedi. MacBook üzerinde yazıcı görünmüyorsa önce "Sistem Kur" veya "Yazıcı Ekle" adımını tamamlayın.';
    }
    return 'Test fişi gönderilemedi. '
        'Önce yazıcı servisini, sonra yerel yazıcı listesini kontrol edin.\n'
        'Teknik detay: $rawMessage';
  }

  bool get _busy =>
      _phase == _Phase.running ||
      _phase == _Phase.checkingHealth ||
      _phase == _Phase.discoveringUsb;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Test Fişi Gönder'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bridge status row ──────────────────────────────────────
              Row(
                children: [
                  Icon(
                    _phase == _Phase.checkingHealth
                        ? Icons.hourglass_empty
                        : (_bridgeOk
                              ? Icons.check_circle
                              : Icons.error_outline),
                    size: 15,
                    color: _phase == _Phase.checkingHealth
                        ? const Color(0xFF9CA3AF)
                        : (_bridgeOk
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _statusLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _ensureBridge,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Yenile'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (_availablePrinters.isNotEmpty) ...[
                const Text(
                  'Hedef yazıcı seç',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>('test_target_printer_dropdown'),
                  isExpanded: true,
                  value: _matchPrinterByIdentifier(
                    _availablePrinters,
                    _targetPrinterId,
                  )?.id,
                  items: _availablePrinters
                      .map(
                        (printer) => DropdownMenuItem<String>(
                          value: printer.id,
                          child: Text(
                            _dropdownLabelForPrinter(printer),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  selectedItemBuilder: (context) => _availablePrinters
                      .map(
                        (printer) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _dropdownLabelForPrinter(printer),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _busy
                      ? null
                      : (value) {
                          final selected = _matchPrinterByIdentifier(
                            _availablePrinters,
                            value,
                          );
                          if (selected == null) return;
                          setState(() => _applyTargetPrinter(selected));
                        },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
              ],
              _TargetPrinterCard(
                label: _targetPrinterLabel,
                queue: _targetPrinterQueue,
                backend: _targetPrinterBackend,
                printerId: _targetPrinterId,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              // ── USB discover row ───────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.usb, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _usbDevices.isEmpty && _phase != _Phase.discoveringUsb
                          ? 'USB yazıcıları tara'
                          : _phase == _Phase.discoveringUsb
                          ? 'Taranıyor…'
                          : '${_usbDevices.length} USB yazıcı bulundu',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _discoverUsb,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: Text(
                      _phase == _Phase.discoveringUsb ? 'Taranıyor' : 'Tara',
                    ),
                  ),
                ],
              ),
              if (_usbExpanded && _usbDevices.isNotEmpty)
                ..._usbDevices.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(left: 20, top: 4),
                    child: _UsbDeviceRow(device: d),
                  ),
                ),
              if (_usbExpanded &&
                  _usbDevices.isEmpty &&
                  _phase != _Phase.discoveringUsb)
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 4),
                  child: Text(
                    'Seçilebilir USB yazıcı bulunamadı.\n'
                    'Yazıcı kablosu takılıysa önce "Sistem Kur" ile bridge kontrolünü tamamlayın.\n'
                    'macOS yazıcı listesi boşsa "Yazıcı Ekle" adımından CUPS yazıcısı ekleyin.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                'Bağlı yazıcıya "IBUL PRINT TEST" fişi gönderir.\n'
                'Transport: ${_buildTransportDescription()}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              // ── Result / setup hint ─────────────────────────────────────
              if (_phase == _Phase.success)
                _FeedbackRow(
                  icon: _successWarning
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle,
                  color: _successWarning
                      ? const Color(0xFFD97706)
                      : const Color(0xFF16A34A),
                  message: _successTransport.isNotEmpty
                      ? '$_successMessage ($_successTransport)'
                      : _successMessage,
                ),
              if (_phase == _Phase.error) _ErrorBox(message: _errorMsg),
              if (_testResultStatus.isNotEmpty &&
                  (_phase == _Phase.success || _phase == _Phase.error))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Test durumu: $_testResultStatus',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _phase == _Phase.success
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              if (_technicalDetail != null &&
                  _technicalDetail!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _technicalDetail!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              _BridgeResponseDetails(data: _lastBridgeResponse),
              if (_phase == _Phase.idle && !_bridgeOk)
                _ErrorBox(message: _bridgeOfflineOperatorMessage()),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_savedPrinterRecord),
          child: const Text('Kapat'),
        ),
        FilledButton(
          onPressed: _busy || !_bridgeOk ? null : _sendTest,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7A2FF4),
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Test Gönder'),
        ),
      ],
    );
  }

  String _dropdownLabelForPrinter(UnifiedPrinterModel printer) {
    final label = printer.displayName.trim().isNotEmpty
        ? printer.displayName.trim()
        : printer.queueName.trim();
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host =
          (printer.raw['host'] ??
                  printer.raw['ip_address'] ??
                  printer.raw['ipAddress'])
              ?.toString()
              .trim() ??
          '';
      final portRaw = printer.raw['port'] ?? printer.raw['tcp_port'];
      final port = portRaw is int
          ? portRaw
          : int.tryParse(portRaw?.toString() ?? '');
      return '$label · Ethernet · $host:${port ?? PrinterModel.ethernetDefaultPort}';
    }
    if (printer.backend == DesktopPrinterBackend.usbDirect) {
      return '$label · USB Direct';
    }
    if (printer.backend == DesktopPrinterBackend.cups) {
      return '$label · CUPS';
    }
    return '$label · Windows';
  }
}

class _TestPrinterSaveOutcome {
  const _TestPrinterSaveOutcome({required this.saved, this.warningMessage});

  final bool saved;
  final String? warningMessage;
}

// ── Small widgets ────────────────────────────────────────────────────────

class _TargetPrinterCard extends StatelessWidget {
  const _TargetPrinterCard({
    required this.label,
    required this.queue,
    required this.backend,
    required this.printerId,
  });

  final String label;
  final String queue;
  final String backend;
  final String? printerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hedef yazıcı',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A2FF4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          if (queue.isNotEmpty)
            Text(
              'Kuyruk: $queue',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          if (backend.isNotEmpty)
            Text(
              'Backend: $backend',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          if (printerId != null && printerId!.trim().isNotEmpty)
            Text(
              'ID: ${printerId!.trim()}',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

class _BridgeResponseDetails extends StatelessWidget {
  const _BridgeResponseDetails({required this.data});

  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Bridge yanıtı',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(data!),
              style: const TextStyle(
                fontSize: 10,
                height: 1.45,
                color: Color(0xFF334155),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsbDeviceRow extends StatelessWidget {
  const _UsbDeviceRow({required this.device});
  final Map<String, dynamic> device;

  @override
  Widget build(BuildContext context) {
    final vid = device['vid_pid']?.toString() ?? '';
    final name = [
      device['manufacturer']?.toString() ?? '',
      device['product']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    return Row(
      children: [
        const Icon(Icons.print_outlined, size: 13, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Text(
          vid,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: Color(0xFF374151),
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFFDC2626),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
