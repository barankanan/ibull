import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/printer_model.dart';
import '../../models/printer_profile.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/local_print_service.dart';
import '../../services/printer_event_log_service.dart';
import '../../widgets/bridge_error_dialog.dart';
import '../../services/printer_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrinterWizard — 5-step stepper for adding / editing a printer
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the [PrinterWizard] as a full-screen dialog.
///
/// Returns the saved [PrinterModel] on success, null on cancel.
Future<PrinterModel?> showPrinterWizard(
  BuildContext context, {
  required String restaurantId,
  PrinterModel? existing,
}) {
  return Navigator.of(context).push<PrinterModel>(
    MaterialPageRoute<PrinterModel>(
      fullscreenDialog: true,
      builder: (_) =>
          PrinterWizard(restaurantId: restaurantId, existing: existing),
    ),
  );
}

class PrinterWizard extends StatefulWidget {
  const PrinterWizard({super.key, required this.restaurantId, this.existing});

  final String restaurantId;
  final PrinterModel? existing;

  @override
  State<PrinterWizard> createState() => _PrinterWizardState();
}

class _PrinterWizardState extends State<PrinterWizard> {
  // ── step index ──
  int _step = 0;

  // ── step 1: connection type ──
  String _connectionType = PrinterModel.localConnectionType;

  // ── step 2: profile ──
  String? _selectedProfileId;

  // ── step 3: connection details ──
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _hostCtrl = TextEditingController(text: PrinterModel.localDefaultHost);
  final _portCtrl = TextEditingController(
    text: PrinterModel.localDefaultPort.toString(),
  );
  // NOTE: intentionally empty — route is set dynamically for local connections.
  final _deviceCtrl = TextEditingController();
  final _codePageCtrl = TextEditingController();
  String? _step2Error;

  // ── step 3: features ──
  int _paperWidth = 80;
  bool _supportsCut = false;
  PrinterCharset _charset = PrinterCharset.cp857;

  // ── step 4: roles ──
  final Set<PrinterRole> _selectedRoles = {};

  // ── step 2: scan/discover ──
  List<Map<String, dynamic>> _discoveredDevices = [];
  bool _discovering = false;
  String? _discoverError;

  // ── step 5: test print ──
  _TestState _testState = _TestState.idle;
  String? _testError;
  bool _testPassed = false;

  // ── Turkish diagnostic test ──
  _TestState _diagState = _TestState.idle;
  String? _diagError;

  // ── saving ──
  bool _saving = false;

  final _repo = PrinterRepository();
  final _printOrchestrator = DesktopPrintOrchestrator();
  final _eventLogService = PrinterEventLogService();

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _connectionType = p.formConnectionType;
      _selectedProfileId = p.printerProfileId;
      _nameCtrl.text = p.name;
      _codeCtrl.text = p.code;
      _hostCtrl.text = p.resolvedHost;
      _portCtrl.text = p.resolvedPort?.toString() ?? '';
      // For USB/BT: only physical device identifier (never an HTTP route).
      // For local: use deviceIdentifier if set, else derive from name/code.
      final isUsbOrBt =
          p.formConnectionType == PrinterModel.usbConnectionType ||
          p.formConnectionType == PrinterModel.bluetoothConnectionType;
      if (isUsbOrBt) {
        _deviceCtrl.text = p.deviceIdentifier ?? '';
        // USB/BT don't use host/port from the app side — bridge handles it.
        _hostCtrl.text = '';
        _portCtrl.text = '';
      } else {
        _deviceCtrl.text = p.deviceIdentifier ?? p.targetRoute;
      }
      _paperWidth = p.paperWidthMm;
      _supportsCut = p.supportsCut;
      _charset = p.charset;
      _codePageCtrl.text = p.codePage?.toString() ?? '';
      _selectedRoles.addAll(p.assignedRoles);
      if (p.testPrintStatus == 'ok') _testPassed = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _deviceCtrl.dispose();
    _codePageCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──

  bool get _isEdit => widget.existing != null;

  int? get _parsedCodePage =>
      PrinterEncodingSelection.tryParseCodePage(_codePageCtrl.text);

  PrinterEncodingSelection get _selectedEncodingSelection =>
      PrinterEncodingSelection.normalize(
        charset: _charset,
        codePage: _parsedCodePage,
      );

  void _showEncodingGuardMessageIfNeeded(PrinterEncodingSelection selection) {
    if (!selection.fallbackApplied || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(selection.warning!),
        backgroundColor: const Color(0xFFF59E0B),
      ),
    );
  }

  String _suggestRoute() {
    final name = _nameCtrl.text.toLowerCase();
    final code = _codeCtrl.text.toLowerCase();
    final isKitchen =
        name.contains('mutfak') ||
        name.contains('kitchen') ||
        name.contains('ocak') ||
        code.contains('mutfak') ||
        code.contains('kitchen') ||
        code.contains('ocak');
    return isKitchen
        ? PrinterModel.localKitchenRoute
        : PrinterModel.localReceiptRoute;
  }

  // ── navigation ──

  void _next() {
    if (_step == 3) {
      final err = _validateStep3();
      if (err != null) {
        setState(() => _step2Error = err);
        return;
      }
    }
    if (_step < 6) {
      setState(() {
        _step2Error = null;
        _step++;
      });
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  String? _validateStep3() {
    if (_nameCtrl.text.trim().isEmpty) return 'Yazıcı adı zorunludur.';
    if (_codeCtrl.text.trim().isEmpty) return 'Kod zorunludur.';

    // Network: IP address required
    if (_connectionType == PrinterModel.networkConnectionType) {
      if (_hostCtrl.text.trim().isEmpty) {
        return 'Network yazıcı için IP adresi zorunludur.';
      }
    }

    // USB / Bluetooth: device identifier must NOT be an HTTP route
    if (_connectionType == PrinterModel.usbConnectionType ||
        _connectionType == PrinterModel.bluetoothConnectionType) {
      final dev = _deviceCtrl.text.trim();
      if (dev.startsWith('/print/')) {
        return '\'$dev\' bir HTTP route\u2019udur. '
            'Cihaz Tanımı alanına fiziksel yol '
            '(ör: /dev/usb/lp0) veya CUPS kuyruğu adı girin. '
            'Route override için Local bağlantı tipini kullanın.';
      }
    }

    return null;
  }

  /// Called when the user picks a profile in Step 2.
  /// Auto-fills the feature fields that belong to the profile.
  void _applyProfile(String profileId) {
    final profile = PrinterProfile.byId(profileId);
    if (profile == null) return;
    setState(() {
      _selectedProfileId = profileId;
      _paperWidth = profile.paperWidthMm;
      _supportsCut = profile.supportsCut;
      _charset = profile.charset;
      _codePageCtrl.text = profile.codepage?.toString() ?? '';
      // Pre-select suggested roles if no roles are set yet.
      if (_selectedRoles.isEmpty) {
        _selectedRoles.addAll(profile.suggestedRoles);
      }
      // Pre-fill transport defaults for the chosen profile.
      final suggested = profile.suggestedTransport;
      if (_connectionType != suggested &&
          _connectionType == PrinterModel.localConnectionType &&
          suggested == PrinterModel.networkConnectionType) {
        // Only auto-switch for network profiles (don’t override an explicit USB/BT choice).
        _portCtrl.text = '9100';
      }
    });
  }

  // ── test print ──

  Future<void> _runTestPrint() async {
    setState(() {
      _testState = _TestState.running;
      _testError = null;
    });
    try {
      if (kIsWeb) {
        // Web cannot reach the local bridge — skip actual call.
        setState(() => _testState = _TestState.webUnsupported);
        return;
      }

      // All transports route through the local bridge at 127.0.0.1:3001.
      // Network printers use target_host/target_port in the POST body so the
      // bridge forwards the ESC/POS bytes via TCP instead of trying to open
      // an HTTP connection to the printer's IP:9100.
      final encodingSelection = _selectedEncodingSelection;
      _showEncodingGuardMessageIfNeeded(encodingSelection);
      final rawDevice = _deviceCtrl.text.trim();
      final sanitizedDevice = rawDevice.contains(' (') && rawDevice.endsWith(')')
          ? rawDevice.split(' (').first.trim()
          : rawDevice;
      final result = await _printOrchestrator
          .printBridgeTest(
            restaurantId: widget.restaurantId,
            printerName: sanitizedDevice.isNotEmpty
                ? sanitizedDevice
                : _nameCtrl.text.trim(),
            targetHost: _connectionType == PrinterModel.networkConnectionType
                ? _hostCtrl.text.trim()
                : null,
            targetPort: _connectionType == PrinterModel.networkConnectionType
                ? (int.tryParse(_portCtrl.text.trim()) ?? 9100)
                : null,
            encoding: encodingSelection.encoding,
            codePage: encodingSelection.codePage,
            renderMode: 'image',
          )
          .timeout(const Duration(seconds: 8));
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
              await _performDiscover();
            },
          );
          setState(() {
            _testState = _TestState.failed;
            _testError = result.message;
            _testPassed = false;
          });
          return;
        }
        throw Exception(result.message);
      }

      setState(() {
        _testState = _TestState.success;
        _testPassed = true;
      });
    } catch (e) {
      _eventLogService
          .append(
            restaurantId: widget.restaurantId,
            event: 'physical_print_failure',
            message: 'Yazıcı ekle testi fiziksel baskıda başarısız oldu.',
            level: 'error',
            details: <String, dynamic>{
              'path': '/print/test',
              'error': e.toString(),
            },
          )
          .ignore();
      setState(() {
        _testState = _TestState.failed;
        final selectedPrinterName = (_deviceCtrl.text.trim().isNotEmpty
                ? _deviceCtrl.text.trim()
                : _nameCtrl.text.trim())
            .trim();
        final available = _discoveredDevices
            .map((d) => d['id']?.toString() ?? d['name']?.toString() ?? '')
            .where((v) => v.trim().isNotEmpty)
            .toList();
        _testError =
            '${e.toString()}\nselectedPrinterName=$selectedPrinterName\navailableBridgePrinterIds=${available.join(', ')}';
        _testPassed = false;
      });
    }
  }

  // ── Turkish codepage diagnostic test ──

  Future<void> _runTurkishDiagnosticTest() async {
    if (kIsWeb) return;
    setState(() {
      _diagState = _TestState.running;
      _diagError = null;
    });
    try {
      final encodingSelection = _selectedEncodingSelection;
      final targetHost = _connectionType == PrinterModel.networkConnectionType
          ? _hostCtrl.text.trim()
          : null;
      final targetPort = _connectionType == PrinterModel.networkConnectionType
          ? (int.tryParse(_portCtrl.text.trim()) ?? 9100)
          : null;
      final result = await _printOrchestrator
          .printBridgeTest(
            restaurantId: widget.restaurantId,
            targetHost: targetHost,
            targetPort: targetPort,
            encoding: encodingSelection.encoding,
            codePage: encodingSelection.codePage,
            renderMode: 'image',
            flowName: 'add_printer_turkish_bitmap_test',
            source: 'printer_wizard',
          )
          .timeout(const Duration(seconds: 20));
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
              await _performDiscover();
            },
          );
          setState(() {
            _diagState = _TestState.failed;
            _diagError = result.message;
          });
          return;
        }
        throw Exception(result.message);
      }
      setState(() => _diagState = _TestState.success);
    } catch (e) {
      setState(() {
        _diagState = _TestState.failed;
        _diagError = e.toString();
      });
    }
  }

  // ── scan/discover ──

  Future<void> _performDiscover() async {
    if (kIsWeb) return;
    setState(() {
      _discovering = true;
      _discoverError = null;
      _discoveredDevices = [];
    });
    try {
      final svc = LocalPrintService();
      try {
        final result = await svc.printers() ?? await svc.discover();
        if (result != null) {
          final printerList =
              (result['printers'] as List?)
                  ?.whereType<Map>()
                  .map((d) => Map<String, dynamic>.from(d))
                  .toList() ??
              <Map<String, dynamic>>[];
          final usbList =
              (result['usb'] as List?)
                  ?.whereType<Map>()
                  .map((d) => Map<String, dynamic>.from(d))
                  .toList() ??
              (result['devices'] as List?)
                  ?.whereType<Map>()
                  .map((d) => Map<String, dynamic>.from(d))
                  .toList() ??
              <Map<String, dynamic>>[];
          final cupsList =
              (result['cups'] as List?)
                  ?.whereType<Map>()
                  .map((d) => Map<String, dynamic>.from(d))
                  .toList() ??
              <Map<String, dynamic>>[];
          setState(() {
            _discoveredDevices = printerList.isNotEmpty
                ? printerList
                : [
                    ...usbList.map(
                      (d) => <String, dynamic>{...d, '_src': 'usb'},
                    ),
                    ...cupsList.map(
                      (d) => <String, dynamic>{...d, '_src': 'cups'},
                    ),
                  ];
          });
        }
      } finally {
        svc.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => _discoverError = e.toString());
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  void _applyDiscoveredDevice(Map<String, dynamic> device) {
    final queue = device['queue'] as String? ?? '';
    final name =
        device['name'] as String? ?? device['product'] as String? ?? 'Yazıcı';
    final vendor =
        device['vendorId'] as String? ?? device['vid'] as String? ?? '';
    final product =
        device['productId'] as String? ?? device['pid'] as String? ?? '';
    if (queue.isNotEmpty) {
      setState(() => _deviceCtrl.text = queue);
      return;
    }
    if (vendor.isNotEmpty || product.isNotEmpty) {
      final vidPid = [vendor, product].where((v) => v.isNotEmpty).join(':');
      setState(() => _deviceCtrl.text = '$name ($vidPid)');
      return;
    }
    setState(() => _deviceCtrl.text = name);
  }

  // ── save ──

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final normalizedConnectionType =
          _connectionType == PrinterModel.localConnectionType
          ? PrinterModel.networkConnectionType
          : _connectionType;
      final normalizedHost = _hostCtrl.text.trim().isEmpty
          ? (_connectionType == PrinterModel.localConnectionType
                ? PrinterModel.localDefaultHost
                : null)
          : _hostCtrl.text.trim();
      final normalizedPort =
          int.tryParse(_portCtrl.text.trim()) ??
          (_connectionType == PrinterModel.localConnectionType
              ? PrinterModel.localDefaultPort
              : null);
      final normalizedDevice = _deviceCtrl.text.trim().isEmpty
          ? (_connectionType == PrinterModel.localConnectionType
                ? _suggestRoute()
                : null)
          : _deviceCtrl.text.trim();
      final encodingSelection = _selectedEncodingSelection;
      _showEncodingGuardMessageIfNeeded(encodingSelection);

      final saved = await _repo.upsertPrinter(
        restaurantId: widget.restaurantId,
        printerId: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        connectionType: normalizedConnectionType,
        ipAddress: normalizedHost,
        port: normalizedPort,
        deviceIdentifier: normalizedDevice,
        paperWidthMm: _paperWidth,
        isActive: _testPassed,
        supportsCut: _supportsCut,
        charset: encodingSelection.charset,
        codePage: encodingSelection.codePage,
        assignedRoles: _selectedRoles.toList(),
        printerProfileId: _selectedProfileId,
      );

      // Record test result in DB if we tested
      if (_testState == _TestState.success) {
        await _repo.recordTestPrintResult(printerId: saved.id, success: true);
      } else if (_testState == _TestState.failed) {
        await _repo.recordTestPrintResult(
          printerId: saved.id,
          success: false,
          error: _testError,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Yazıcı Düzenle' : 'Yeni Yazıcı Ekle',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentStep(),
                  const SizedBox(height: 24),
                  _InlineWizardActions(
                    step: _step,
                    totalSteps: 7,
                    onBack: _step > 0 ? _back : null,
                    onNext: _step < 6 ? _next : null,
                    onSave: _step == 6
                        ? (!_testPassed &&
                                  _testState != _TestState.webUnsupported
                              ? null
                              : _saving
                              ? null
                              : _save)
                        : null,
                    saving: _saving,
                    canSave:
                        _testPassed || _testState == _TestState.webUnsupported,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _Step1ConnectionType(
          selected: _connectionType,
          onChanged: (v) => setState(() {
            _connectionType = v;
            if (v == PrinterModel.localConnectionType) {
              // Local → bridge at 127.0.0.1:3001, HTTP route
              _hostCtrl.text = PrinterModel.localDefaultHost;
              _portCtrl.text = PrinterModel.localDefaultPort.toString();
              if (_deviceCtrl.text.isEmpty ||
                  _deviceCtrl.text.startsWith('0x') ||
                  !_deviceCtrl.text.startsWith('/')) {
                _deviceCtrl.text = _suggestRoute();
              }
            } else if (v == PrinterModel.networkConnectionType) {
              // Network → IP:9100 direct TCP
              _hostCtrl.clear();
              _portCtrl.text = '9100';
              _deviceCtrl.clear();
            } else if (v == PrinterModel.usbConnectionType) {
              // USB → bridge handles transport; host/port not needed in app
              _hostCtrl.clear();
              _portCtrl.clear();
              // Clear any HTTP route that may have been pre-filled
              if (_deviceCtrl.text.startsWith('/print/')) {
                _deviceCtrl.clear();
              }
            } else {
              // Bluetooth / other
              _hostCtrl.clear();
              _portCtrl.clear();
              _deviceCtrl.clear();
            }
          }),
        );
      case 1:
        return _Step2Scan(
          connectionType: _connectionType,
          discovering: _discovering,
          devices: _discoveredDevices,
          error: _discoverError,
          onDiscover: _performDiscover,
          onDeviceSelected: _applyDiscoveredDevice,
        );
      case 2:
        return _Step2ProfileSelect(
          connectionType: _connectionType,
          selectedProfileId: _selectedProfileId,
          onProfileSelected: _applyProfile,
        );
      case 3:
        return _Step3ConnectionDetails(
          connectionType: _connectionType,
          nameCtrl: _nameCtrl,
          codeCtrl: _codeCtrl,
          hostCtrl: _hostCtrl,
          portCtrl: _portCtrl,
          deviceCtrl: _deviceCtrl,
          error: _step2Error,
          onNameChanged: (_) {
            if (_connectionType == PrinterModel.localConnectionType &&
                (_deviceCtrl.text.isEmpty ||
                    _deviceCtrl.text == PrinterModel.localReceiptRoute ||
                    _deviceCtrl.text == PrinterModel.localKitchenRoute)) {
              _deviceCtrl.text = _suggestRoute();
            }
          },
        );
      case 4:
        return _Step4Features(
          paperWidth: _paperWidth,
          supportsCut: _supportsCut,
          charset: _charset,
          codePageCtrl: _codePageCtrl,
          onPaperWidthChanged: (v) => setState(() => _paperWidth = v),
          onSupportsCutChanged: (v) => setState(() => _supportsCut = v),
          onCharsetChanged: (v) => setState(() => _charset = v),
        );
      case 5:
        return _Step5Roles(
          selected: _selectedRoles,
          onToggle: (role) => setState(() {
            if (_selectedRoles.contains(role)) {
              _selectedRoles.remove(role);
            } else {
              _selectedRoles.add(role);
            }
          }),
        );
      case 6:
        return _Step6TestPrint(
          connectionType: _connectionType,
          host: _hostCtrl.text,
          port: _portCtrl.text,
          testState: _testState,
          testError: _testError,
          onTest: _runTestPrint,
          diagState: _diagState,
          diagError: _diagError,
          onDiagTest: kIsWeb ? null : _runTurkishDiagnosticTest,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  static const _labels = [
    'Bağlantı',
    'Tara',
    'Profil',
    'Detaylar',
    'Özellikler',
    'Roller',
    'Test',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIndex = i ~/ 2;
            final done = stepIndex < current;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? const Color(0xFF8B5CF6) : const Color(0xFFE5E7EB),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final active = stepIndex == current;
          final done = stepIndex < current;
          return _StepDot(
            index: stepIndex,
            label: _labels[stepIndex],
            active: active,
            done: done,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? const Color(0xFF8B5CF6)
                : active
                ? const Color(0xFF8B5CF6)
                : const Color(0xFFF3F4F6),
            border: Border.all(
              color: active || done
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : const Color(0xFF9CA3AF),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active || done
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _InlineWizardActions extends StatelessWidget {
  const _InlineWizardActions({
    required this.step,
    required this.totalSteps,
    required this.onBack,
    required this.onNext,
    required this.onSave,
    required this.saving,
    required this.canSave,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSave;
  final bool saving;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 10,
        children: [
          if (onBack != null)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Geri'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          if (onNext != null)
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('İleri'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          if (onSave != null || step == totalSteps - 1)
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
              style: FilledButton.styleFrom(
                backgroundColor: canSave
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFD1D5DB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Scan / Discover
// ─────────────────────────────────────────────────────────────────────────────

class _Step2Scan extends StatelessWidget {
  const _Step2Scan({
    required this.connectionType,
    required this.discovering,
    required this.devices,
    required this.error,
    required this.onDiscover,
    required this.onDeviceSelected,
  });

  final String connectionType;
  final bool discovering;
  final List<Map<String, dynamic>> devices;
  final String? error;
  final VoidCallback onDiscover;
  final ValueChanged<Map<String, dynamic>> onDeviceSelected;

  bool get _canDiscover =>
      connectionType == PrinterModel.localConnectionType ||
      connectionType == PrinterModel.usbConnectionType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 2,
          title: 'Yazıcı Tara',
          subtitle: _canDiscover
              ? 'Sisteme bağlı yazıcıları otomatik tespit edin. '
                    'İsterseniz bu adımı geçip bilgileri elle girebilirsiniz.'
              : connectionType == PrinterModel.networkConnectionType
              ? 'Ağ yazıcıları için otomatik tarama desteklenmez. '
                    'İleri\'ye basarak IP adresini girebilirsiniz.'
              : 'Bu bağlantı tipi için otomatik tarama '
                    'bu sürümde desteklenmez.',
        ),
        const SizedBox(height: 24),
        if (!_canDiscover)
          _InfoBox(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF6B7280),
            bg: const Color(0xFFF9FAFB),
            text: connectionType == PrinterModel.networkConnectionType
                ? 'Ağ yazıcıları için tarama desteklenmez. '
                      'Bir sonraki adımda IP adresini elle girin.'
                : 'Bluetooth yazıcılar için otomatik tarama '
                      'bu sürümde desteklenmez.',
          )
        else ...[
          Center(
            child: FilledButton.icon(
              onPressed: discovering ? null : onDiscover,
              icon: discovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded, size: 18),
              label: Text(discovering ? 'Taranıyor…' : 'Yazıcıları Tara'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: error!),
          ],
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${devices.length} yazıcı bulundu — seçerek bilgileri otomatik doldurun',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 10),
            ...devices.map((d) {
              final connectionType =
                  (d['connectionType'] as String? ?? d['_src'] as String? ?? '')
                      .toLowerCase();
              final backend = (d['backend'] as String? ?? '').toLowerCase();
              final isUsb = connectionType == 'usb';
              final label =
                  d['name'] as String? ??
                  d['product'] as String? ??
                  d['queue'] as String? ??
                  d['label'] as String? ??
                  'Yazıcı';
              final mfr = (d['manufacturer'] as String? ?? '').trim();
              final detail =
                  d['detail'] as String? ??
                  (isUsb
                      ? (mfr.isNotEmpty ? 'USB • $mfr' : 'USB yazıcı')
                      : backend == 'windows-spool'
                      ? 'Windows yazıcı kuyruğu'
                      : 'Sistem yazıcı kuyruğu');
              return GestureDetector(
                onTap: () => onDeviceSelected(d),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isUsb ? Icons.usb_rounded : Icons.print_rounded,
                          size: 18,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              detail,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Color(0xFFD1D5DB),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (!discovering && error == null) ...[
            const SizedBox(height: 20),
            _InfoBox(
              icon: Icons.info_outline_rounded,
              color: const Color(0xFF6B7280),
              bg: const Color(0xFFF9FAFB),
              text:
                  'Taramak için butona basın. Yazıcı bulunamazsa '
                  '"İleri" ile devam ederek bilgileri elle girebilirsiniz.',
            ),
          ],
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Connection Type
// ─────────────────────────────────────────────────────────────────────────────

class _Step1ConnectionType extends StatelessWidget {
  const _Step1ConnectionType({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _types = [
    (
      value: PrinterModel.localConnectionType,
      icon: Icons.computer_rounded,
      title: 'Local Bridge',
      subtitle:
          'Bu bilgisayardaki yazıcı. Yerel Python bridge (127.0.0.1:3001) üzerinden bağlanır. En yaygın kurulum.',
      recommended: true,
    ),
    (
      value: PrinterModel.networkConnectionType,
      icon: Icons.lan_rounded,
      title: 'Network / IP',
      subtitle:
          'Ağdaki TCP/IP yazıcı. IP adresi ve port gerektirir (genelde 9100).',
      recommended: false,
    ),
    (
      value: PrinterModel.usbConnectionType,
      icon: Icons.usb_rounded,
      title: 'USB',
      subtitle:
          'USB ile fiziksel bağlantı. Bridge (127.0.0.1:3001) USB transportu otomatik yönetir. '
          'Cihaz tanımı opsiyoneldir.',
      recommended: false,
    ),
    (
      value: PrinterModel.bluetoothConnectionType,
      icon: Icons.bluetooth_rounded,
      title: 'Bluetooth',
      subtitle: 'Bluetooth yazıcı. Cihaz MAC adresi veya tanımı gerektirir.',
      recommended: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 1,
          title: 'Bağlantı Tipi Seç',
          subtitle: 'Yazıcınızın bu sisteme nasıl bağlandığını seçin.',
        ),
        const SizedBox(height: 20),
        ...List.generate(_types.length, (i) {
          final t = _types[i];
          final isSelected = selected == t.value;
          return GestureDetector(
            onTap: () => onChanged(t.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF3F0FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      t.icon,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFF4C1D95)
                                    : const Color(0xFF111827),
                              ),
                            ),
                            if (t.recommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Önerilen',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Custom radio indicator replaces deprecated Radio<String> API
                  Container(
                    width: 20,
                    height: 20,
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
                              width: 10,
                              height: 10,
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

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Profile Selection
// ─────────────────────────────────────────────────────────────────────────────

class _Step2ProfileSelect extends StatelessWidget {
  const _Step2ProfileSelect({
    required this.connectionType,
    required this.selectedProfileId,
    required this.onProfileSelected,
  });

  final String connectionType;
  final String? selectedProfileId;
  final ValueChanged<String> onProfileSelected;

  @override
  Widget build(BuildContext context) {
    // Suggest profiles that match the selected transport first.
    final sorted = [...PrinterProfile.all]
      ..sort((a, b) {
        final aMatch = a.suggestedTransport == connectionType ? 0 : 1;
        final bMatch = b.suggestedTransport == connectionType ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 3,
          title: 'Yazıcı Profili Seç',
          subtitle:
              'Donanımınıza en yakın profili seçin. Özellikler otomatik doldurulur, isterseniz değiştirebilirsiniz.',
        ),
        const SizedBox(height: 20),
        ...sorted.map((profile) {
          final isSelected = selectedProfileId == profile.id;
          // Highlight profiles matching the chosen transport
          final suggestMatch = profile.suggestedTransport == connectionType;
          return GestureDetector(
            onTap: () => onProfileSelected(profile.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF3F0FF)
                    : suggestMatch
                    ? const Color(0xFFF0FDF4)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : suggestMatch
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE5E7EB),
                  width: isSelected || suggestMatch ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : suggestMatch
                          ? const Color(0xFF059669)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      size: 20,
                      color: isSelected || suggestMatch
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFF4C1D95)
                                      : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            if (suggestMatch && !isSelected) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Önerilen',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          profile.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            _ProfileChip(
                              label: '${profile.paperWidthMm}mm',
                              icon: Icons.straighten_rounded,
                            ),
                            _ProfileChip(
                              label: profile.charset.label,
                              icon: Icons.text_fields_rounded,
                            ),
                            if (profile.supportsCut)
                              const _ProfileChip(
                                label: 'Auto-cut',
                                icon: Icons.content_cut_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
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
                              width: 10,
                              height: 10,
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
        const SizedBox(height: 8),
        _InfoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF6B7280),
          bg: const Color(0xFFF9FAFB),
          text:
              'Profil seçmek zorunlu değildir. Seçerseniz bir sonraki adımda özellikler otomatik dolar; istediğiniz gibi değiştirebilirsiniz.',
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: const Color(0xFF6B7280)),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Connection Details
// ─────────────────────────────────────────────────────────────────────────────

class _Step3ConnectionDetails extends StatelessWidget {
  const _Step3ConnectionDetails({
    required this.connectionType,
    required this.nameCtrl,
    required this.codeCtrl,
    required this.hostCtrl,
    required this.portCtrl,
    required this.deviceCtrl,
    required this.error,
    required this.onNameChanged,
  });

  final String connectionType;
  final TextEditingController nameCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController hostCtrl;
  final TextEditingController portCtrl;
  final TextEditingController deviceCtrl;
  final String? error;
  final ValueChanged<String> onNameChanged;

  bool get _isLocal => connectionType == PrinterModel.localConnectionType;
  bool get _isNetwork => connectionType == PrinterModel.networkConnectionType;
  bool get _isUsb => connectionType == PrinterModel.usbConnectionType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 4,
          title: 'Yazıcı Bilgileri',
          subtitle: 'Yazıcı adını ve bağlantı detaylarını girin.',
        ),
        const SizedBox(height: 20),
        _WizardField(
          label: 'Yazıcı Adı',
          hint: 'örn: Adisyon Yazıcısı, Mutfak 1',
          controller: nameCtrl,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 14),
        _WizardField(
          label: 'Kod',
          hint: 'örn: ADISYON, MUTFAK1',
          controller: codeCtrl,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLocal) ...[
          _InfoBox(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF8B5CF6),
            bg: const Color(0xFFF3F0FF),
            text:
                'Local bridge bağlantısı için host 127.0.0.1, port 3001 olarak önceden dolduruldu.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _WizardField(
                  label: 'Host',
                  hint: '127.0.0.1',
                  controller: hostCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _WizardField(
                  label: 'Port',
                  hint: '3001',
                  controller: portCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WizardField(
            label: 'Route (HTTP Yolu)',
            hint: '/print/receipt  veya  /print/kitchen',
            controller: deviceCtrl,
            helperText:
                'Adisyon: /print/receipt  ·  Mutfak/Ocak: /print/kitchen',
          ),
        ] else if (_isNetwork) ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _WizardField(
                  label: 'IP Adresi',
                  hint: '192.168.1.100',
                  controller: hostCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _WizardField(
                  label: 'Port',
                  hint: '9100',
                  controller: portCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WizardField(
            label: 'CUPS Kuyruğu / Cihaz Tanımı (Opsiyonel)',
            hint: 'YAZICI_1 veya boş bırakın',
            controller: deviceCtrl,
            helperText:
                'Fiziksel CUPS kuyruğu adı. HTTP route buraya yazılmamalıdır.',
          ),
        ] else if (_isUsb) ...[
          _InfoBox(
            icon: Icons.usb_rounded,
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
            text:
                'USB yazıcı yerel bridge üzerinden çalışır (127.0.0.1:3001). '
                'Cihaz tanımı opsiyoneldir — bridge konfigürasyonunda '
                'PRINT_BRIDGE_TRANSPORT=usb ayarlıysa USB transportu '
                'otomatik yönetilir.',
          ),
          const SizedBox(height: 14),
          _WizardField(
            label: 'CUPS Kuyruğu veya Cihaz Yolu (Opsiyonel)',
            hint: 'YAZICI_1 veya /dev/usb/lp0 veya boş bırakın',
            controller: deviceCtrl,
            helperText:
                'Boş bırakırsanız bridge varsayılan USB cihazını kullanır.',
          ),
        ] else ...[
          _WizardField(
            label: 'Bluetooth MAC Adresi',
            hint: 'örn: AA:BB:CC:DD:EE:FF',
            controller: deviceCtrl,
            helperText: 'Cihazın Bluetooth MAC adresi.',
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: error!),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Features
// ─────────────────────────────────────────────────────────────────────────────

class _Step4Features extends StatelessWidget {
  const _Step4Features({
    required this.paperWidth,
    required this.supportsCut,
    required this.charset,
    required this.codePageCtrl,
    required this.onPaperWidthChanged,
    required this.onSupportsCutChanged,
    required this.onCharsetChanged,
  });

  final int paperWidth;
  final bool supportsCut;
  final PrinterCharset charset;
  final TextEditingController codePageCtrl;
  final ValueChanged<int> onPaperWidthChanged;
  final ValueChanged<bool> onSupportsCutChanged;
  final ValueChanged<PrinterCharset> onCharsetChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 5,
          title: 'Yazıcı Özellikleri',
          subtitle:
              'ESC/POS kağıt genişliği, otomatik kesici ve karakter seti seçin.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Kağıt Genişliği',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [58, 72, 80].map((w) {
            final isSelected = paperWidth == w;
            return GestureDetector(
              onTap: () => onPaperWidthChanged(w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  '${w}mm',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SwitchListTile.adaptive(
            value: supportsCut,
            onChanged: onSupportsCutChanged,
            activeThumbColor: const Color(0xFF8B5CF6),
            title: const Text(
              'Otomatik Kesici (Auto-cut)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            subtitle: const Text(
              'Yazıcının kağıdı otomatik kesebildiği durumlarda etkinleştirin.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Karakter Seti (Charset)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PrinterCharset>(
              value: charset,
              isExpanded: true,
              items: PrinterCharset.values.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.label));
              }).toList(),
              onChanged: (v) {
                if (v != null) onCharsetChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: codePageCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'ESC/POS Codepage',
            hintText: 'Örn: 13',
            helperText:
                'Klon yazıcılarda codepage numarası değişebilir. Boş bırakırsanız güvenli Türkçe varsayımı uygulanır.',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _InfoBox(
          icon: Icons.lightbulb_outline_rounded,
          color: const Color(0xFFF59E0B),
          bg: const Color(0xFFFFFBEB),
          text:
              'Raw ESC/POS için UTF-8 güvenilir değildir. Türkçe fişlerde önce CP857 + codepage 13 ile başlayın; klon yazıcılarda doğru değeri test fişi ile bulun.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Roles
// ─────────────────────────────────────────────────────────────────────────────

class _Step5Roles extends StatelessWidget {
  const _Step5Roles({required this.selected, required this.onToggle});

  final Set<PrinterRole> selected;
  final ValueChanged<PrinterRole> onToggle;

  static const _roleInfo = [
    (
      role: PrinterRole.receipt,
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF8B5CF6),
      desc: 'Müşteriye verilen yemek/ürün fişi',
    ),
    (
      role: PrinterRole.kitchen,
      icon: Icons.outdoor_grill_outlined,
      color: Color(0xFFEF4444),
      desc: 'Ocak siparişleri',
    ),
    (
      role: PrinterRole.bakery,
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFF97316),
      desc: 'Fırın siparişleri',
    ),
    (
      role: PrinterRole.bar,
      icon: Icons.local_bar_outlined,
      color: Color(0xFF0EA5E9),
      desc: 'Bar içecek siparişleri',
    ),
    (
      role: PrinterRole.general,
      icon: Icons.print_outlined,
      color: Color(0xFF6B7280),
      desc: 'Genel amaçlı yazdırma',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 6,
          title: 'Rol Ata',
          subtitle:
              'Bu yazıcının hangi iş akışlarında kullanılacağını seçin. Birden fazla rol seçebilirsiniz.',
        ),
        const SizedBox(height: 20),
        ...List.generate(_roleInfo.length, (i) {
          final info = _roleInfo[i];
          final isSelected = selected.contains(info.role);
          return GestureDetector(
            onTap: () => onToggle(info.role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? info.color.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? info.color : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(info.icon, size: 22, color: info.color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.role.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? info.color
                                : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          info.desc,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    activeColor: info.color,
                    onChanged: (_) => onToggle(info.role),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        _InfoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF6B7280),
          bg: const Color(0xFFF9FAFB),
          text:
              'Roller bilgi amaçlıdır. Gerçek yönlendirme "Alan → Yazıcı Eşleştirme" ekranından yapılır.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Test Print
// ─────────────────────────────────────────────────────────────────────────────

enum _TestState { idle, running, success, failed, webUnsupported }

class _Step6TestPrint extends StatelessWidget {
  const _Step6TestPrint({
    required this.connectionType,
    required this.host,
    required this.port,
    required this.testState,
    required this.testError,
    required this.onTest,
    this.diagState = _TestState.idle,
    this.diagError,
    this.onDiagTest,
  });

  final String connectionType;
  final String host;
  final String port;
  final _TestState testState;
  final String? testError;
  final VoidCallback onTest;
  final _TestState diagState;
  final String? diagError;
  final VoidCallback? onDiagTest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardSectionHeader(
          step: 7,
          title: 'Test Fişi Bas',
          subtitle:
              'Kaydetmeden önce yazıcının çalıştığını doğrulayın. Test başarılı olmazsa yazıcı aktif olarak kaydedilmez.',
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              _TestStatusIcon(state: testState),
              const SizedBox(height: 16),
              Text(
                _stateTitle(testState),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _stateSubtitle(testState, host, port, connectionType),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              if (testError != null && testState == _TestState.failed) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: SelectableText(
                    testError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFDC2626),
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (testState != _TestState.webUnsupported)
                FilledButton.icon(
                  onPressed: testState == _TestState.running ? null : onTest,
                  icon: testState == _TestState.running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(
                    testState == _TestState.running
                        ? 'Test Gönderiliyor…'
                        : testState == _TestState.success
                        ? 'Tekrar Test Et'
                        : 'Test Fişi Bas',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: testState == _TestState.success
                        ? const Color(0xFF10B981)
                        : const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              if (onDiagTest != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: diagState == _TestState.running
                      ? null
                      : onDiagTest,
                  icon: diagState == _TestState.running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate_rounded, size: 18),
                  label: Text(
                    diagState == _TestState.running
                        ? 'Türkçe Bitmap Testi Gönderiliyor…'
                        : diagState == _TestState.success
                        ? 'Türkçe Bitmap Testini Tekrarla'
                        : 'Türkçe Bitmap Testi',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: diagState == _TestState.success
                        ? const Color(0xFF10B981)
                        : const Color(0xFF8B5CF6),
                    side: BorderSide(
                      color: diagState == _TestState.success
                          ? const Color(0xFF10B981)
                          : const Color(0xFF8B5CF6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (diagState == _TestState.success)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Türkçe örnek metin bitmap olarak basıldı.\n'
                      'Bu test gerçek siparişlerin kullandığı image/raster yolunu doğrular.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ),
                if (diagState == _TestState.failed && diagError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Türkçe bitmap test hatası: $diagError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFDC2626),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (testState == _TestState.failed) ...[
          _InfoBox(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444),
            bg: const Color(0xFFFEF2F2),
            text:
                'Test başarısız. Yazıcı pasif olarak kaydedilecek. Kurulumu tamamladıktan sonra bu ekrandan tekrar test edebilirsiniz.',
          ),
        ],
        if (testState == _TestState.webUnsupported) ...[
          _InfoBox(
            icon: Icons.web_rounded,
            color: const Color(0xFFF59E0B),
            bg: const Color(0xFFFFFBEB),
            text:
                'Web üzerinden yerel bridge\'e erişilemez. Yazıcı ilk kurulumda pasif olarak kaydedilecek. Masaüstü uygulamasında test edebilirsiniz.',
          ),
        ],
      ],
    );
  }

  String _stateTitle(_TestState s) {
    switch (s) {
      case _TestState.idle:
        return 'Test Fişi Göndermeye Hazır';
      case _TestState.running:
        return 'Test Gönderiliyor…';
      case _TestState.success:
        return 'Test Başarılı!';
      case _TestState.failed:
        return 'Test Başarısız';
      case _TestState.webUnsupported:
        return 'Web\'den Test Yapılamaz';
    }
  }

  String _stateSubtitle(
    _TestState s,
    String host,
    String port,
    String connectionType,
  ) {
    switch (s) {
      case _TestState.idle:
        if (connectionType == PrinterModel.networkConnectionType) {
          return 'Yerel bridge aracılığıyla $host:$port adresine test fişi gönderilecek.';
        }
        if (connectionType == PrinterModel.usbConnectionType) {
          return 'Bridge üzerinden USB yazıcısına test fişi gönderilecek.';
        }
        return 'Bridge (127.0.0.1:${PrinterModel.localDefaultPort}) üzerinden test fişi gönderilecek.';
      case _TestState.running:
        return 'Yazıcı yanıtı bekleniyor…';
      case _TestState.success:
        return 'Yazıcı testi geçti. Kaydet butonuna basarak tamamlayın.';
      case _TestState.failed:
        return 'Aşağıdaki hatayı inceleyin. Bridge çalışıyor mu? Yazıcı açık mı?';
      case _TestState.webUnsupported:
        return 'Tarayıcı güvenlik kısıtlamaları yerel bridge\'e bağlanmayı engeller.';
    }
  }
}

class _TestStatusIcon extends StatelessWidget {
  const _TestStatusIcon({required this.state});

  final _TestState state;

  @override
  Widget build(BuildContext context) {
    if (state == _TestState.running) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      );
    }
    final (icon, color, bg) = switch (state) {
      _TestState.success => (
        Icons.check_circle_outline_rounded,
        const Color(0xFF10B981),
        const Color(0xFFF0FDF4),
      ),
      _TestState.failed => (
        Icons.error_outline_rounded,
        const Color(0xFFEF4444),
        const Color(0xFFFEF2F2),
      ),
      _TestState.webUnsupported => (
        Icons.web_rounded,
        const Color(0xFFF59E0B),
        const Color(0xFFFFFBEB),
      ),
      _ => (
        Icons.print_outlined,
        const Color(0xFF8B5CF6),
        const Color(0xFFF3F0FF),
      ),
    };
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 36, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WizardSectionHeader extends StatelessWidget {
  const _WizardSectionHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adım $step / 7',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _WizardField extends StatelessWidget {
  const _WizardField({
    required this.label,
    required this.controller,
    this.hint,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

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
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
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

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.color,
    required this.bg,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
