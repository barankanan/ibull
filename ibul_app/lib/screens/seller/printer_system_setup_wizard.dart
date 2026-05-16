import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../core/config/runtime_config.dart';
import '../../models/desktop_printer_setup_models.dart';
import '../../models/printer_model.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/desktop_print_ports.dart';
import '../../services/local_print_service.dart';
import '../../services/printer_repository.dart';
import '../../utils/external_navigation.dart';
import '../../widgets/bridge_error_dialog.dart';

Future<List<PrinterModel>?> showPrinterSystemSetupWizard(
  BuildContext context, {
  required String restaurantId,
}) {
  return Navigator.of(context).push<List<PrinterModel>>(
    MaterialPageRoute<List<PrinterModel>>(
      fullscreenDialog: true,
      builder: (_) => PrinterSystemSetupWizard(restaurantId: restaurantId),
    ),
  );
}

class PrinterSystemSetupWizard extends StatefulWidget {
  const PrinterSystemSetupWizard({
    super.key,
    required this.restaurantId,
    this.printerRepository,
    this.printOrchestrator,
    this.localPrintServiceFactory,
    this.detectedPlatformOverride,
  });

  final String restaurantId;
  final PrinterRepositoryPort? printerRepository;
  final DesktopPrintOrchestrator? printOrchestrator;
  final LocalPrintServiceFactory? localPrintServiceFactory;
  final String? detectedPlatformOverride;

  @override
  State<PrinterSystemSetupWizard> createState() =>
      _PrinterSystemSetupWizardState();
}

class _PrinterSystemSetupWizardState extends State<PrinterSystemSetupWizard> {
  late final PrinterRepositoryPort _printerRepository =
      widget.printerRepository ?? PrinterRepository();
  late final DesktopPrintOrchestrator _printOrchestrator =
      widget.printOrchestrator ?? DesktopPrintOrchestrator();
  late final LocalPrintServiceFactory _localPrintServiceFactory =
      widget.localPrintServiceFactory ?? (() => LocalPrintService());

  late final String _detectedPlatform =
      widget.detectedPlatformOverride ?? _detectPlatform();
  late String _selectedPlatform = _detectedPlatform;

  int _currentStep = 0;
  bool _checkingSystem = false;
  bool _installerDownloadStarted = false;
  bool _autostartBusy = false;
  bool _detectingPrinters = false;
  bool _testingPrinter = false;
  bool _saving = false;
  bool _autoDetectTriggered = false;

  Map<String, dynamic>? _setupStatus;
  Map<String, dynamic>? _prerequisites;
  Map<String, dynamic>? _autostartResponse;
  Map<String, dynamic>? _testResponse;
  Map<String, dynamic>? _driverHelp;
  String? _setupError;
  String? _printerDetectionError;
  String? _testError;
  String? _testWarning;
  String? _setupTechnicalError;
  String? _printerDetectionTechnicalError;
  String? _testTechnicalError;
  bool _testPassed = false;

  List<Map<String, dynamic>> _detectedPrinters = const <Map<String, dynamic>>[];
  bool _duplicatePrinterWarning = false;
  String? _selectedTestPrinterId;
  String? _receiptPrinterId;
  String? _kitchenPrinterId;

  String get _windowsInstallerUrl =>
      AppRuntimeConfig.windowsInstallerDownloadUrl;

  @override
  void initState() {
    super.initState();
    _refreshSystemCheck();
  }

  Future<void> _refreshSystemCheck() async {
    setState(() {
      _checkingSystem = true;
      _setupError = null;
      _setupTechnicalError = null;
    });

    final service = _localPrintServiceFactory();
    try {
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: widget.restaurantId,
      );
      final driverHelp = await service.driverHelp();
      if (!mounted) return;
      final legacyPrinters =
          snapshot.printers.map(_printerToLegacyMap).toList(growable: false);
      final duplicateMeta = _computeDuplicateMeta(
        legacyPrinters,
        queueStatus: snapshot.queueStatus,
        platform: snapshot.os,
      );
      final decoratedPrinters = legacyPrinters
          .map(
            (p) => <String, dynamic>{
              ...p,
              ...?duplicateMeta[p['id']?.toString() ?? ''],
            },
          )
          .toList(growable: false);
      final recommendedId = _firstRecommendedPrinterId(decoratedPrinters);
      setState(() {
        _setupStatus = snapshot.setupStatus ?? _offlineSetupStatus();
        _prerequisites = snapshot.prerequisites ?? _offlinePrerequisites();
        _driverHelp = driverHelp;
        _detectedPrinters = decoratedPrinters;
        _duplicatePrinterWarning = duplicateMeta.isNotEmpty;
        _selectedTestPrinterId =
            _selectedTestPrinterId ??
            recommendedId ??
            _firstReadyPrinterId(_detectedPrinters) ??
            _firstPrinterId(_detectedPrinters);
        _receiptPrinterId =
            _receiptPrinterId ??
            snapshot.selectedReceiptPrinterRecordId ??
            snapshot.localConfig?.receiptSelection?.printer.printerRecordId ??
            snapshot.localConfig?.receiptSelection?.printer.id ??
            snapshot.selectedReceiptPrinterId;
        _kitchenPrinterId =
            _kitchenPrinterId ??
            snapshot.selectedKitchenPrinterRecordId ??
            snapshot.localConfig?.kitchenSelection?.printer.printerRecordId ??
            snapshot.localConfig?.kitchenSelection?.printer.id ??
            snapshot.selectedKitchenPrinterId;
        if (_selectedTestPrinterId == null && _detectedPrinters.isNotEmpty) {
          _selectedTestPrinterId = _detectedPrinters.first['id']?.toString();
        }
        _receiptPrinterId ??= recommendedId ?? _selectedTestPrinterId;
        _kitchenPrinterId ??= recommendedId ?? _selectedTestPrinterId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setupStatus = _offlineSetupStatus();
        _prerequisites = _offlinePrerequisites();
        _setupError = _operatorErrorMessage(
          error,
          fallback: 'Sistem kontrolü şu anda tamamlanamadı.',
        );
        _setupTechnicalError = error.toString();
      });
    } finally {
      service.dispose();
      if (mounted) {
        setState(() {
          _checkingSystem = false;
        });
      }
    }
  }

  Future<void> _downloadWindowsInstaller() async {
    final opened = ExternalNavigation.openUrl(_windowsInstallerUrl);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: _windowsInstallerUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İndirme bağlantısı panoya kopyalandı. Tarayıcıda açarak indirimi başlatın.',
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _installerDownloadStarted = true;
      _setupError = null;
      _setupTechnicalError = null;
    });
  }

  Future<void> _copyWindowsLogPathHint() async {
    const hint = r'%LOCALAPPDATA%\IbulPrintBridge';
    await Clipboard.setData(const ClipboardData(text: hint));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Log klasörü yolu panoya kopyalandı: %LOCALAPPDATA%\\IbulPrintBridge',
        ),
      ),
    );
  }

  Future<void> _toggleAutostart(bool enabled) async {
    setState(() {
      _autostartBusy = true;
      _setupError = null;
      _setupTechnicalError = null;
    });
    final service = _localPrintServiceFactory();
    try {
      final response = enabled
          ? await service.enableAutostart()
          : await service.disableAutostart();
      final status = await service.setupStatus();
      if (!mounted) return;
      setState(() {
        _autostartResponse = response;
        _setupStatus = status ?? _setupStatus;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setupError = _operatorErrorMessage(
          error,
          fallback: 'Otomatik başlatma ayarı güncellenemedi.',
        );
        _setupTechnicalError = error.toString();
      });
    } finally {
      service.dispose();
      if (mounted) {
        setState(() {
          _autostartBusy = false;
        });
      }
    }
  }

  Future<void> _detectPrinters() async {
    setState(() {
      _detectingPrinters = true;
      _printerDetectionError = null;
      _printerDetectionTechnicalError = null;
    });
    try {
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: widget.restaurantId,
      );
      final legacyPrinters =
          snapshot.printers.map(_printerToLegacyMap).toList(growable: false);
      final duplicateMeta = _computeDuplicateMeta(
        legacyPrinters,
        queueStatus: snapshot.queueStatus,
        platform: snapshot.os,
      );
      final printers = legacyPrinters
          .map(
            (p) => <String, dynamic>{
              ...p,
              ...?duplicateMeta[p['id']?.toString() ?? ''],
            },
          )
          .toList(growable: false);
      final recommendedId = _firstRecommendedPrinterId(printers);
      if (!mounted) return;
      setState(() {
        _detectedPrinters = printers;
        _duplicatePrinterWarning = duplicateMeta.isNotEmpty;
        _selectedTestPrinterId =
            _selectedTestPrinterId ??
            recommendedId ??
            _firstReadyPrinterId(printers) ??
            _firstPrinterId(printers);
        _receiptPrinterId = _receiptPrinterId ?? _selectedTestPrinterId;
        _kitchenPrinterId =
            _kitchenPrinterId ??
            (_detectedPrinters.length > 1
                ? _detectedPrinters[1]['selectionId']?.toString() ??
                      _detectedPrinters[1]['id']?.toString() ??
                      _selectedTestPrinterId
                : _selectedTestPrinterId);
        _receiptPrinterId ??= recommendedId ?? _selectedTestPrinterId;
        _kitchenPrinterId ??= recommendedId ?? _selectedTestPrinterId;
        if (printers.isEmpty) {
          _printerDetectionError =
              snapshot.discoveryWarning ?? 'Yazici bulunamadi';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printerDetectionError = _operatorErrorMessage(
          error,
          fallback: 'Yazıcılar şu anda listelenemedi.',
        );
        _printerDetectionTechnicalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _detectingPrinters = false;
        });
      }
    }
  }

  Map<String, dynamic> _printerToLegacyMap(UnifiedPrinterModel printer) {
    return <String, dynamic>{
      'id': printer.id,
      'selectionId': printer.printerRecordId?.trim().isNotEmpty == true
          ? printer.printerRecordId
          : printer.id,
      'name': printer.displayName,
      'queue': printer.queueName,
      'backend': printer.backend.value,
      'printerRecordId': printer.printerRecordId,
      'printer_record_id': printer.printerRecordId,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'isLive': printer.raw['source'] != 'saved_record',
      'isSavedOnly': printer.raw['source'] == 'saved_record',
      'statusLevel': printer.canPrint
          ? 'ready'
          : (printer.isAvailable ? 'warning' : 'error'),
      'statusMessage': printer.statusMessage,
    };
  }

  Future<void> _sendTestPrint() async {
    final printerId = _selectedTestPrinterId?.trim() ?? '';
    if (printerId.isEmpty) {
      setState(() {
        _testError = 'Önce bir yazıcı seçin.';
      });
      return;
    }

    setState(() {
      _testingPrinter = true;
      _testError = null;
      _testWarning = null;
      _testTechnicalError = null;
    });
    try {
      final selectedPrinter = _selectedPrinter;
      final role = _selectedTestRole(printerId);
      debugPrint(
        '[WIZARD_TEST_CLICK] clicked_button=wizard_test '
        'restaurantId=${widget.restaurantId} '
        'selectedTestPrinterId=$printerId '
        'role=${role.value} '
        'selectedPrinter=${selectedPrinter == null ? "-" : jsonEncode(selectedPrinter)}',
      );
      final result = await _runWizardTestPrint(
        printerId: printerId,
        selectedPrinter: selectedPrinter,
        role: role,
      );
      if (!mounted) return;
      if (!result.ok) {
        final structured = BridgeStructuredError.tryParse(result.raw);
        if (structured != null &&
            (structured.errorCode == 'cups_queue_busy' ||
                structured.errorCode == 'cups_queue_stuck' ||
                structured.errorCode == 'duplicate_test_suppressed')) {
          await showBridgeStructuredErrorDialog(
            context,
            title: 'Test gönderilemedi',
            primaryMessage: result.message,
            error: structured,
            onAfterRefresh: () async {
              await _detectPrinters();
              await _refreshSystemCheck();
            },
          );
        }
      }
      setState(() {
        _testResponse = result.raw;
        _testPassed = result.ok;
        _testError = result.ok
            ? null
            : '${result.status}: ${result.message}';
        _testWarning = result.ok && result.status != 'ready'
            ? result.message
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testPassed = false;
        _testError = _operatorErrorMessage(
          error,
          fallback: 'Test fişi gönderilemedi.',
        );
        _testWarning = null;
        _testTechnicalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _testingPrinter = false;
        });
      }
    }
  }

  Future<PrinterActionResult> _runWizardTestPrint({
    required String printerId,
    required Map<String, dynamic>? selectedPrinter,
    required PrinterSetupRole role,
  }) async {
    return _printOrchestrator.printTestReceipt(
      restaurantId: widget.restaurantId,
      role: role,
      printerId: printerId,
      testSource: 'wizard_test',
      flowName: 'wizard_test',
      source: 'printer_system_setup_wizard',
    );
  }

  PrinterSetupRole _selectedTestRole(String printerId) {
    final normalizedPrinterId = printerId.trim();
    if (normalizedPrinterId.isNotEmpty &&
        normalizedPrinterId == _kitchenPrinterId?.trim()) {
      return PrinterSetupRole.mutfak;
    }
    return PrinterSetupRole.adisyon;
  }

  Future<void> _saveAssignments() async {
    if (!_testPassed) {
      setState(() {
        _testError = 'Kurulumu tamamlamak için test fişi başarılı olmalı.';
      });
      return;
    }

    final selections = <String, Set<PrinterRole>>{};
    void assign(String? printerId, PrinterRole role) {
      if (printerId == null || printerId.isEmpty) return;
      selections.putIfAbsent(printerId, () => <PrinterRole>{}).add(role);
    }

    assign(_receiptPrinterId, PrinterRole.receipt);
    assign(_kitchenPrinterId, PrinterRole.kitchen);

    if (selections.isEmpty) {
      setState(() {
        _setupError = 'En az bir rol için yazıcı seçin.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _setupError = null;
      _setupTechnicalError = null;
    });

    try {
      final result = await _printOrchestrator.savePrinterRoles(
        restaurantId: widget.restaurantId,
        receiptPrinterId: _receiptPrinterId ?? '',
        kitchenPrinterId: _kitchenPrinterId ?? '',
      );
      if (!result.ok) {
        throw StateError(result.message);
      }
      final savedPrinters = await _printerRepository.fetchPrinters(
        widget.restaurantId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(savedPrinters);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setupError = _operatorErrorMessage(
          error,
          fallback: 'Rol atamaları kaydedilemedi.',
        );
        _setupTechnicalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _detectPlatform() {
    if (kIsWeb) return 'windows';
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'macos';
    }
  }

  Map<String, dynamic> _offlineSetupStatus() {
    return <String, dynamic>{
      'ok': false,
      'step': 'system_check',
      'status': 'bridge_not_running',
      'message': 'Yazıcı servisine ulaşılamadı.',
      'errorCode': 'bridge_not_running',
      'platform': _selectedPlatform,
      'actionRequired': 'start_bridge',
      'checks': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Bridge çalışıyor',
          'ok': false,
          'status': 'bridge_not_running',
          'message': 'Yazıcı servisi kapalı veya yanıt vermiyor.',
        },
      ],
    };
  }

  Map<String, dynamic> _offlinePrerequisites() {
    return <String, dynamic>{
      'ok': false,
      'step': 'prerequisites',
      'status': 'bridge_not_running',
      'message': 'Bridge kapalı olduğu için gereksinimler doğrulanamadı.',
      'errorCode': 'bridge_not_running',
      'platform': _selectedPlatform,
      'actionRequired': 'start_bridge',
      'checks': const <Map<String, dynamic>>[],
    };
  }

  String? _firstReadyPrinterId(List<Map<String, dynamic>> printers) {
    for (final printer in printers) {
      if ((printer['statusLevel']?.toString() ?? '') == 'ready') {
        return printer['selectionId']?.toString() ?? printer['id']?.toString();
      }
    }
    return null;
  }

  String? _firstPrinterId(List<Map<String, dynamic>> printers) {
    if (printers.isEmpty) return null;
    return printers.first['selectionId']?.toString() ??
        printers.first['id']?.toString();
  }

  Map<String, dynamic>? get _selectedPrinter {
    for (final printer in _detectedPrinters) {
      final bridgeId = printer['id']?.toString();
      final selectionId =
          printer['selectionId']?.toString() ??
          printer['printerRecordId']?.toString();
      if (bridgeId == _selectedTestPrinterId ||
          selectionId == _selectedTestPrinterId) {
        return printer;
      }
    }
    return null;
  }

  String _operatorErrorMessage(Object error, {required String fallback}) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('timeout')) {
      return 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
    }
    if (raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('connection refused') ||
        raw.contains('xmlhttprequest error')) {
      return 'Yazıcı servisine bağlanılamadı. Servisin açık olduğundan emin olun.';
    }
    if (raw.contains('driver_missing')) {
      return 'Yazıcı sürücüsü eksik görünüyor. Önce yazıcıyı bilgisayara kurun.';
    }
    if (raw.contains('printer_offline') || raw.contains('not ready')) {
      return 'Yazıcı hazır görünmüyor. Güç ve bağlantıyı kontrol edin.';
    }
    return fallback;
  }

  String _wizardStatusLabel(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
        return 'Hazır';
      case 'not_installed':
        return 'Kurulu Değil';
      case 'installed_not_running':
        return 'Yüklü Ama Çalışmıyor';
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
      case 'tested':
        return 'Hazır (Test Edildi)';
      default:
        return 'Test Edilmedi';
    }
  }

  Color _wizardStatusColor(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
      case 'tested':
        return const Color(0xFF15803D);
      case 'running_unhealthy':
      case 'not_installed':
      case 'installed_not_running':
        return const Color(0xFFB45309);
      case 'setup_required':
      case 'bridge_not_running':
        return const Color(0xFFB45309);
      case 'driver_missing':
      case 'printer_offline':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _printerLevelLabel(String? level) {
    switch ((level ?? '').trim().toLowerCase()) {
      case 'ready':
        return 'Hazır';
      case 'warning':
        return 'Uyarı';
      case 'error':
        return 'Hata';
      default:
        return 'Bilinmiyor';
    }
  }

  Color _printerLevelColor(String? level) {
    switch ((level ?? '').trim().toLowerCase()) {
      case 'ready':
        return const Color(0xFF15803D);
      case 'warning':
        return const Color(0xFFB45309);
      case 'error':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        return _setupStatus != null;
      case 2:
        final status =
            (_setupStatus?['status']?.toString().trim().toLowerCase() ?? '');
        return status == 'ready' || status == 'running_unhealthy';
      case 3:
        return true;
      case 4:
        return _selectedTestPrinterId != null;
      case 5:
        return _testPassed;
      case 6:
        return !_saving;
      default:
        return false;
    }
  }

  bool get _canCompleteSetup =>
      !_saving &&
      _testPassed &&
      (_receiptPrinterId?.trim().isNotEmpty ?? false) &&
      (_kitchenPrinterId?.trim().isNotEmpty ?? false);

  void _goNext() {
    if (_currentStep < 6 && _canContinue) {
      setState(() {
        _currentStep += 1;
      });
      _maybeAutoDetectPrinters();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  void _maybeAutoDetectPrinters() {
    if (_currentStep != 4 || _autoDetectTriggered || _detectingPrinters) {
      return;
    }
    _autoDetectTriggered = true;
    _detectPrinters();
  }

  @override
  Widget build(BuildContext context) {
    final status = _setupStatus?['status']?.toString();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Sistem Kur')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusChip(
                        label: _wizardStatusLabel(status),
                        color: _wizardStatusColor(status),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Algılanan sistem: ${_platformTitle(_detectedPlatform)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Teknik olmayan ekip için güvenli ve yönlendirmeli yazıcı kurulumu.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(
                    context,
                  ).colorScheme.copyWith(primary: const Color(0xFF0F766E)),
                ),
                child: Stepper(
                  currentStep: _currentStep,
                  onStepTapped: (index) {
                    if (index <= _currentStep || _canContinue) {
                      setState(() {
                        _currentStep = index;
                      });
                      _maybeAutoDetectPrinters();
                    }
                  },
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          if (_currentStep > 0)
                            OutlinedButton(
                              onPressed: _saving ? null : _goBack,
                              child: const Text('Geri'),
                            ),
                          const SizedBox(width: 8),
                          if (_currentStep < 6)
                            FilledButton(
                              onPressed: _canContinue && !_saving
                                  ? _goNext
                                  : null,
                              child: const Text('Devam Et'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: _canCompleteSetup
                                  ? _saveAssignments
                                  : null,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Kurulumu Tamamla'),
                            ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('İşletim Sistemi'),
                      isActive: _currentStep >= 0,
                      content: _buildPlatformStep(),
                    ),
                    Step(
                      title: const Text('Sistem Kontrolü'),
                      isActive: _currentStep >= 1,
                      content: _buildSystemCheckStep(),
                    ),
                    Step(
                      title: const Text('Bridge Kurulumu'),
                      isActive: _currentStep >= 2,
                      content: _buildInstallStep(),
                    ),
                    Step(
                      title: const Text('Otomatik Başlat'),
                      isActive: _currentStep >= 3,
                      content: _buildAutostartStep(),
                    ),
                    Step(
                      title: const Text('Yazıcı Tespiti'),
                      isActive: _currentStep >= 4,
                      content: _buildPrinterDetectionStep(),
                    ),
                    Step(
                      title: const Text('Test Fişi'),
                      isActive: _currentStep >= 5,
                      content: _buildTestStep(),
                    ),
                    Step(
                      title: const Text('Rol Atama'),
                      isActive: _currentStep >= 6,
                      content: _buildAssignmentStep(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sistem otomatik algılandı. Gerekirse farklı işletim sistemi seçebilirsiniz.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF99F6E4)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.desktop_windows_outlined,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Algılanan sistem: ${_platformTitle(_detectedPlatform)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'windows',
              label: Text('Windows'),
              icon: Icon(Icons.window_outlined),
            ),
            ButtonSegment<String>(
              value: 'macos',
              label: Text('macOS'),
              icon: Icon(Icons.laptop_mac_outlined),
            ),
          ],
          selected: <String>{_selectedPlatform},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() {
              _selectedPlatform = selection.first;
            });
            _refreshSystemCheck();
          },
        ),
        const SizedBox(height: 12),
        Text(
          _selectedPlatform == 'windows'
              ? 'Windows yazıcı sürücüsü ve spooler ile kurulum akışı gösterilecek.'
              : 'CUPS görünürlüğü ve macOS otomatik başlatma akışı gösterilecek.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
        ),
        if (_selectedPlatform != _detectedPlatform)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Seçiminiz rehber ve kurulum akışında override olarak kullanılacak.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ),
      ],
    );
  }

  Widget _buildSystemCheckStep() {
    final checks =
        (_prerequisites?['checks'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _setupStatus?['message']?.toString() ??
                    'Sistem kontrol ediliyor.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _checkingSystem ? null : _refreshSystemCheck,
              icon: _checkingSystem
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Kontrol Et'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final check in checks)
          _CheckTile(
            label: check['label']?.toString() ?? '-',
            message: check['message']?.toString() ?? '',
            statusLabel: _wizardStatusLabel(check['status']?.toString()),
            color: _wizardStatusColor(check['status']?.toString()),
            ok: check['ok'] == true,
          ),
        if ((_setupStatus?['errorCode']?.toString() ?? '') ==
                'driver_missing' &&
            _driverHelp != null) ...[
          const SizedBox(height: 12),
          _HelpBox(
            title: _driverHelp?['helpTitle']?.toString() ?? 'Sürücü yardımı',
            steps: ((_driverHelp?['helpSteps'] as List?) ?? const <dynamic>[])
                .map((entry) => entry.toString())
                .toList(growable: false),
          ),
        ],
        if (_setupError != null) ...[
          const SizedBox(height: 12),
          Text(
            _setupError!,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        ],
        _TechnicalDetails(
          data: <String, dynamic>{
            'setupStatus': _setupStatus,
            if (_prerequisites != null) 'prerequisites': _prerequisites,
            if (_driverHelp != null) 'driverHelp': _driverHelp,
            if (_setupTechnicalError != null) 'error': _setupTechnicalError,
          },
        ),
      ],
    );
  }

  Widget _buildInstallStep() {
    final status = _setupStatus?['status']?.toString();
    final isWindows = _selectedPlatform == 'windows';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWindows
              ? 'Tarayıcı Windows cihazınıza doğrudan servis kuramaz. Kurulum için yükleyiciyi indirip çalıştırın, sonra tekrar kontrol edin.'
              : 'Yerel yazıcı servisini işletim sistemi üzerinde kurup çalıştırdıktan sonra tekrar kontrol edin.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        if (isWindows) ...[
          FilledButton.icon(
            onPressed: _downloadWindowsInstaller,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Windows Yazıcı Kurulum Uygulamasını İndir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _copyWindowsLogPathHint,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Sorun yaşıyorsan log yolunu kopyala'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _checkingSystem ? null : _refreshSystemCheck,
          icon: _checkingSystem
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Tekrar Kontrol Et'),
        ),
        const SizedBox(height: 12),
        if (status != null)
          _StatusRow(
            title: 'Durum',
            value: _wizardStatusLabel(status),
            color: _wizardStatusColor(status),
          ),
        if ((status ?? '').toLowerCase() == 'not_installed')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Kurulum tamamlanmadan bu adımı geçemezsiniz.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ),
        if ((status ?? '').toLowerCase() == 'running_unhealthy')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bridge cevap veriyor. Yazıcı taramaya devam edebilirsiniz; sonraki adım hangi parçanın eksik olduğunu gösterecek.',
              style: TextStyle(fontSize: 12, color: Color(0xFF0F766E)),
            ),
          ),
        if (_setupStatus?['message'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _setupStatus!['message'].toString(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        if ((_setupStatus?['errorCode']?.toString() ?? '') ==
                'driver_missing' &&
            _driverHelp != null) ...[
          const SizedBox(height: 12),
          _HelpBox(
            title: _driverHelp?['helpTitle']?.toString() ?? 'Sürücü yardımı',
            steps: ((_driverHelp?['helpSteps'] as List?) ?? const <dynamic>[])
                .map((entry) => entry.toString())
                .toList(growable: false),
          ),
        ],
        _TechnicalDetails(
          data: <String, dynamic>{
            'setupStatus': _setupStatus,
            if (_driverHelp != null) 'driverHelp': _driverHelp,
            'installerDownloadStarted': _installerDownloadStarted,
            'installerUrl': _windowsInstallerUrl,
            if (_setupTechnicalError != null) 'error': _setupTechnicalError,
          },
        ),
      ],
    );
  }

  Widget _buildAutostartStep() {
    final autostart = (_setupStatus?['autostart'] as Map?) != null
        ? Map<String, dynamic>.from(_setupStatus!['autostart'] as Map)
        : <String, dynamic>{};
    final enabled = autostart['enabled'] == true;
    final supported = autostart['supported'] != false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: !supported || _autostartBusy ? null : _toggleAutostart,
          title: const Text('Bilgisayar açıldığında yazıcı servisini hazırla'),
          subtitle: Text(enabled ? 'Aktif' : 'Pasif'),
        ),
        if (_autostartResponse?['message'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _autostartResponse!['message'].toString(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
        if (!supported)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bu platformda otomatik başlatma bu kurulum akışından yönetilemiyor.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ),
        _TechnicalDetails(
          data: <String, dynamic>{
            'setupStatus': _setupStatus,
            'autostartResponse': _autostartResponse,
            if (_setupTechnicalError != null) 'error': _setupTechnicalError,
          },
        ),
      ],
    );
  }

  Widget _buildPrinterDetectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _detectedPrinters.isEmpty
                    ? 'Yazıcıları tara ve kullanılabilir cihazları listele.'
                    : '${_detectedPrinters.length} yazıcı bulundu.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _detectingPrinters ? null : _detectPrinters,
              icon: _detectingPrinters
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded, size: 16),
              label: const Text('Yazıcıları Tara'),
            ),
          ],
        ),
        if (_printerDetectionError != null) ...[
          const SizedBox(height: 12),
          Text(
            _printerDetectionError!,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        ],
        if (_duplicatePrinterWarning) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Text(
              'Bu yazıcı birden fazla bağlantı yöntemiyle görünüyor. '
              'Mac için genelde CUPS önerilir. CUPS kuyruğu takılıysa USB Direct ile deneyebilirsiniz.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF3730A3),
                height: 1.4,
              ),
            ),
          ),
        ],
        if (_detectedPrinters.isEmpty && !_detectingPrinters) ...[
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
              'Henüz seçilebilir yazıcı bulunamadı. Önce "Yazıcıları Tara" ile tekrar deneyin. MacBook üzerinde yazıcı listesi boşsa sistemi veya CUPS yazıcısını eklemeniz gerekir.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final printer in _detectedPrinters)
          _DetectedPrinterCard(
            printer: printer,
            selected: printer['id']?.toString() == _selectedTestPrinterId,
            onTap: () {
              setState(() {
                _selectedTestPrinterId = printer['id']?.toString();
                _receiptPrinterId ??= _selectedTestPrinterId;
                _kitchenPrinterId ??= _selectedTestPrinterId;
              });
            },
            levelLabel: _printerLevelLabel(printer['statusLevel']?.toString()),
            levelColor: _printerLevelColor(printer['statusLevel']?.toString()),
          ),
        _TechnicalDetails(
          data: <String, dynamic>{
            'printers': _detectedPrinters,
            if (_printerDetectionTechnicalError != null)
              'error': _printerDetectionTechnicalError,
          },
        ),
      ],
    );
  }

  Widget _buildTestStep() {
    final selectedPrinter = _selectedPrinter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedPrinter == null
              ? 'Test için önce bir yazıcı seçin.'
              : 'Seçili yazıcı: ${selectedPrinter['name']}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        Text(
          selectedPrinter == null
              ? 'Buton pasif çünkü henüz test yazıcısı seçilmedi.'
              : 'Bu buton, Yazıcılar sekmesindekiyle aynı ortak test fişi yolunu kullanır.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _testingPrinter || selectedPrinter == null
              ? null
              : _sendTestPrint,
          icon: _testingPrinter
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_outlined),
          label: const Text('Test Fişi Gönder'),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          title: 'Test durumu',
          value: _testPassed
              ? (_testWarning == null
                    ? 'Hazır (Test Edildi)'
                    : 'Hazır (Kuyruğa Gönderildi)')
              : 'Test Edilmedi',
          color: _testPassed
              ? (_testWarning == null
                    ? const Color(0xFF15803D)
                    : const Color(0xFFD97706))
              : const Color(0xFF6B7280),
        ),
        if (_testWarning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _testWarning!,
              style: const TextStyle(color: Color(0xFFD97706), fontSize: 12),
            ),
          ),
        if (_testError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _testError!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ),
        if (_testPassed)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              _testWarning == null
                  ? 'Kurulumun devamı için gerekli test başarıyla tamamlandı.'
                  : 'Test işi kuyruğa gönderildi. Fiziksel baskıyı yazıcıdan kontrol edin.',
              style: TextStyle(
                color: _testWarning == null
                    ? const Color(0xFF15803D)
                    : const Color(0xFFD97706),
                fontSize: 12,
              ),
            ),
          ),
        _TechnicalDetails(
          data: <String, dynamic>{
            'testResponse': _testResponse,
            if (_testTechnicalError != null) 'error': _testTechnicalError,
          },
        ),
      ],
    );
  }

  Widget _buildAssignmentStep() {
    final options = _detectedPrinters
        .map(
          (printer) => DropdownMenuItem<String>(
            value:
                printer['selectionId']?.toString() ?? printer['id']?.toString(),
            child: Text(
              '${printer['name']?.toString() ?? 'Yazıcı'}'
              '${printer['isSavedOnly'] == true ? ' (Kayıtlı)' : ''}',
            ),
          ),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hangi yazıcının adisyon ve hangi yazıcının mutfak için kullanılacağını seçin.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _receiptPrinterId,
          items: options,
          onChanged: (value) {
            setState(() {
              _receiptPrinterId = value;
            });
          },
          decoration: const InputDecoration(
            labelText: 'Adisyon Yazıcısı',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _kitchenPrinterId,
          items: options,
          onChanged: (value) {
            setState(() {
              _kitchenPrinterId = value;
            });
          },
          decoration: const InputDecoration(
            labelText: 'Mutfak Yazıcısı',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Aynı yazıcıyı iki rol için de seçebilirsiniz.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        if (!_canCompleteSetup)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Kurulumu tamamlamak için adisyon ve mutfak yazıcısı seçilmeli, test fişi başarılı olmalı.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
        if (_setupError != null) ...[
          const SizedBox(height: 12),
          Text(
            _setupError!,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        ],
        _TechnicalDetails(
          data: <String, dynamic>{
            'selectedReceiptPrinterId': _receiptPrinterId,
            'selectedKitchenPrinterId': _kitchenPrinterId,
            if (_setupTechnicalError != null) 'error': _setupTechnicalError,
          },
        ),
      ],
    );
  }

  String _platformTitle(String value) {
    switch (value) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      default:
        return value;
    }
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.message,
    required this.statusLabel,
    required this.color,
    required this.ok,
  });

  final String label;
  final String message;
  final String statusLabel;
  final Color color;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    _StatusChip(label: statusLabel, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
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

class _DetectedPrinterCard extends StatelessWidget {
  const _DetectedPrinterCard({
    required this.printer,
    required this.selected,
    required this.onTap,
    required this.levelLabel,
    required this.levelColor,
  });

  final Map<String, dynamic> printer;
  final bool selected;
  final VoidCallback onTap;
  final String levelLabel;
  final Color levelColor;

  @override
  Widget build(BuildContext context) {
    final transport =
        printer['transportType']?.toString() ??
        printer['backend']?.toString() ??
        '-';
    final message = printer['statusMessage']?.toString() ?? '';
    final badge = printer['duplicateBadge']?.toString() ?? '';
    final badgeColorHex = printer['duplicateBadgeColor']?.toString() ?? '';
    final badgeColor = badgeColorHex.isNotEmpty
        ? Color(int.tryParse(badgeColorHex) ?? 0xFF6B7280)
        : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFEFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF0891B2) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    printer['name']?.toString() ?? 'Yazıcı',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                _StatusChip(label: levelLabel, color: levelColor),
              ],
            ),
            if (badge.isNotEmpty) ...[
              const SizedBox(height: 6),
              _StatusChip(label: badge, color: badgeColor),
            ],
            const SizedBox(height: 6),
            Text(
              'Taşıma: $transport',
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Duplicate detection helpers ───────────────────────────────────────────────

Map<String, Map<String, dynamic>> _computeDuplicateMeta(
  List<Map<String, dynamic>> printers, {
  required Map<String, dynamic>? queueStatus,
  required DesktopPrinterOs platform,
}) {
  if (platform != DesktopPrinterOs.macos) {
    return const <String, Map<String, dynamic>>{};
  }

  String? normalizeHex(String? value) {
    final raw = value?.trim().toLowerCase() ?? '';
    if (raw.isEmpty) return null;
    final cleaned = raw.startsWith('0x') ? raw.substring(2) : raw;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return null;
    return '0x${parsed.toRadixString(16).padLeft(4, '0')}';
  }

  bool looksPos58(String text) {
    final t = text.toLowerCase();
    return t.contains('pos58') ||
        t.contains('stmicroelectronics') ||
        t.contains('stmicro') ||
        t.contains('pos-58');
  }

  String? fingerprint(Map<String, dynamic> p) {
    final backend = (p['backend']?.toString() ?? '').toLowerCase();
    if (backend.isEmpty) return null;
    final name = (p['name']?.toString() ?? '').trim();
    final queue = (p['queue']?.toString() ?? '').trim();
    final combined = '$name $queue $backend';
    // POS58 special-case: prefer alias grouping over VID/PID so CUPS + USB can match.
    if (looksPos58(combined)) return 'alias:pos58';
    final vid = normalizeHex(p['vendorId']?.toString());
    final pid = normalizeHex(p['productId']?.toString());
    if (vid != null && pid != null) {
      return 'vidpid:$vid:$pid';
    }
    final normalizedQueue = queue.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalizedQueue.isNotEmpty && normalizedQueue.length >= 6) {
      return 'queue:$normalizedQueue';
    }
    return null;
  }

  final groups = <String, List<Map<String, dynamic>>>{};
  for (final p in printers) {
    final key = fingerprint(p);
    if (key == null) continue;
    groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(p);
  }

  final hasAnyDuplicate = groups.values.any((g) => g.length >= 2);
  if (!hasAnyDuplicate) return const <String, Map<String, dynamic>>{};

  // Determine local CUPS queue status (best-effort).
  final queue = queueStatus?['queue'];
  final queueMap = queue is Map<String, dynamic>
      ? queue
      : (queue is Map ? Map<String, dynamic>.from(queue) : null);
  final runtime = queueMap?['runtime'];
  final runtimeMap = runtime is Map<String, dynamic>
      ? runtime
      : (runtime is Map ? Map<String, dynamic>.from(runtime) : null);
  final runtimeStatus = (runtimeMap?['status']?.toString() ?? '').toLowerCase();
  final queueStatusText =
      (queueMap?['queue_status']?.toString() ?? '').toLowerCase();
  final hasActive =
      queueMap?['queue_has_active_job'] == true ||
      ((queueMap?['active_job_ids'] as List?)?.isNotEmpty ?? false);
  final cupsStuck = runtimeStatus == 'cups_queue_stuck' || queueStatusText == 'stuck';
  final cupsBusy = runtimeStatus == 'cups_queue_busy' || hasActive;

  bool isReady(Map<String, dynamic> p) =>
      (p['statusLevel']?.toString() ?? '').toLowerCase() == 'ready';
  bool isError(Map<String, dynamic> p) =>
      (p['statusLevel']?.toString() ?? '').toLowerCase() == 'error';

  bool isCups(Map<String, dynamic> p) =>
      (p['backend']?.toString() ?? '').toLowerCase() == 'cups';
  bool isUsb(Map<String, dynamic> p) =>
      (p['backend']?.toString() ?? '').toLowerCase() == 'usb-direct';

  const recommendedColor = '0xFF15803D';
  const altColor = '0xFF2563EB';
  const stuckColor = '0xFFB91C1C';
  const offlineColor = '0xFF6B7280';

  final metaById = <String, Map<String, dynamic>>{};
  for (final group in groups.values.where((g) => g.length >= 2)) {
    final cups = group.where(isCups).toList(growable: false);
    final usb = group.where(isUsb).toList(growable: false);
    if (cups.isEmpty || usb.isEmpty) continue;

    final cupsPrinter = cups.first;
    final usbPrinter = usb.first;
    final cupsId = cupsPrinter['id']?.toString() ?? '';
    final usbId = usbPrinter['id']?.toString() ?? '';
    if (cupsId.isEmpty || usbId.isEmpty) continue;

    final cupsEligible = !isError(cupsPrinter) && !cupsStuck && !cupsBusy;
    final usbEligible = !isError(usbPrinter);
    final recommendCups = cupsEligible || !usbEligible;

    metaById[cupsId] = <String, dynamic>{
      'duplicateGroup': true,
      'duplicateBadge': cupsStuck
          ? 'Queue takılmış'
          : cupsBusy
          ? 'Queue meşgul'
          : (recommendCups ? 'Önerilen' : 'Alternatif'),
      'duplicateBadgeColor': cupsStuck || cupsBusy
          ? (cupsStuck ? stuckColor : stuckColor)
          : (recommendCups ? recommendedColor : altColor),
      'isRecommended': recommendCups,
    };
    metaById[usbId] = <String, dynamic>{
      'duplicateGroup': true,
      'duplicateBadge': recommendCups ? 'Alternatif' : 'Önerilen',
      'duplicateBadgeColor': recommendCups ? altColor : recommendedColor,
      'isRecommended': !recommendCups,
    };

    // Mark non-ready as "Bağlı değil" to avoid misleading recommendation.
    for (final entry in group) {
      final id = entry['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (!isReady(entry) && !isError(entry)) {
        metaById[id] = <String, dynamic>{
          ...?metaById[id],
          'duplicateBadge': 'Bağlı değil',
          'duplicateBadgeColor': offlineColor,
          'isRecommended': false,
        };
      }
      if (isError(entry)) {
        metaById[id] = <String, dynamic>{
          ...?metaById[id],
          'duplicateBadge': 'Bağlı değil',
          'duplicateBadgeColor': offlineColor,
          'isRecommended': false,
        };
      }
    }
  }
  return metaById;
}

String? _firstRecommendedPrinterId(List<Map<String, dynamic>> printers) {
  for (final p in printers) {
    if (p['isRecommended'] == true) {
      return p['selectionId']?.toString() ?? p['id']?.toString();
    }
  }
  return null;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        _StatusChip(label: value, color: color),
      ],
    );
  }
}

class _HelpBox extends StatelessWidget {
  const _HelpBox({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 8),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                step,
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.data});

  final Object? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Teknik Detaylar',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(data),
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
