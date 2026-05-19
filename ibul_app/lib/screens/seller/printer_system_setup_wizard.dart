import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../core/config/runtime_config.dart';
import '../../models/desktop_printer_setup_models.dart';
import '../../models/turkish_encoding_calibration.dart';
import '../../models/windows_printer_classification.dart';
import '../../models/printer_model.dart';
import '../../services/bridge_manager.dart';
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
    this.windowsBridgeUiModeOverride,
    this.showWindowsInstallerDownloadOverride,
  });

  final String restaurantId;
  final PrinterRepositoryPort? printerRepository;
  final DesktopPrintOrchestrator? printOrchestrator;
  final LocalPrintServiceFactory? localPrintServiceFactory;
  final String? detectedPlatformOverride;

  /// Test/release override: `dev` shows manual bridge commands, `packaged` shows installer.
  final String? windowsBridgeUiModeOverride;

  /// Test-only: force web-style unified installer download CTA on Windows.
  final bool? showWindowsInstallerDownloadOverride;

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
  bool _turkishEncodingVerified = false;
  bool _turkishCalibrationBusy = false;
  String? _selectedEncodingCandidateId;
  String? _turkishCalibrationError;
  String? _turkishCalibrationMessage;
  String _selectedTurkishPrintMode = kTurkishPrintModeText;
  bool _turkishCombinedSheetPrinted = false;

  List<Map<String, dynamic>> _detectedPrinters = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _stalePrinters = const <Map<String, dynamic>>[];
  bool _duplicatePrinterWarning = false;
  String? _selectedTestPrinterId;
  String? _receiptPrinterId;
  String? _kitchenPrinterId;
  bool _bridgeReachable = false;
  bool _bridgeHealthy = false;
  Map<String, dynamic>? _bridgeHealth;
  int _livePrinterCount = 0;
  bool _bridgeStartBusy = false;
  String? _bridgeStartMessage;

  String get _windowsInstallerUrl =>
      AppRuntimeConfig.windowsInstallerDownloadUrl;

  bool get _windowsDevBridgeMode {
    switch (widget.windowsBridgeUiModeOverride) {
      case 'dev':
        return true;
      case 'packaged':
        return false;
      default:
        return !kIsWeb &&
            kDebugMode &&
            _selectedPlatform == 'windows' &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                widget.detectedPlatformOverride == 'windows');
    }
  }

  bool get _showPackagedWindowsInstaller {
    final showDownload = widget.showWindowsInstallerDownloadOverride ?? kIsWeb;
    return showDownload &&
        _selectedPlatform == 'windows' &&
        !_windowsDevBridgeMode;
  }

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
        forceRefresh: true,
      );
      Map<String, dynamic>? driverHelp;
      try {
        driverHelp = await service.driverHelp();
      } catch (_) {}
      if (!mounted) return;
      final legacyPrinters = snapshot.livePrinters
          .map(_printerToLegacyMap)
          .toList(growable: false);
      final stalePrinters = snapshot.stalePrinters
          .map(_printerToLegacyMap)
          .toList(growable: false);
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
        _bridgeReachable = snapshot.bridgeReachable;
        _bridgeHealthy = snapshot.bridgeHealthy;
        _bridgeHealth = snapshot.bridgeHealth;
        _livePrinterCount = snapshot.livePrinterCount;
        _setupStatus = snapshot.buildOperatorSetupStatus();
        _prerequisites = snapshot.prerequisites ??
            <String, dynamic>{
              'ok': snapshot.bridgeReachable && snapshot.bridgeHealthy,
              'checks': snapshot.buildOperatorSetupStatus()['checks'],
            };
        _driverHelp = driverHelp;
        _detectedPrinters = _sortDetectedPrinters(decoratedPrinters);
        _stalePrinters = stalePrinters;
        _duplicatePrinterWarning = duplicateMeta.isNotEmpty;
        _selectedTestPrinterId =
            _selectedTestPrinterId ??
            recommendedId ??
            _firstReadyPrinterId(_detectedPrinters) ??
            _firstPrinterId(_detectedPrinters);
        _receiptPrinterId = _coerceLiveSelectionId(
          currentId: _receiptPrinterId,
          snapshotId:
              snapshot.selectedReceiptPrinterRecordId ??
              snapshot.localConfig?.receiptSelection?.printer.printerRecordId ??
              snapshot.localConfig?.receiptSelection?.printer.id ??
              snapshot.selectedReceiptPrinterId,
          livePrinters: decoratedPrinters,
        );
        _kitchenPrinterId = _coerceLiveSelectionId(
          currentId: _kitchenPrinterId,
          snapshotId:
              snapshot.selectedKitchenPrinterRecordId ??
              snapshot.localConfig?.kitchenSelection?.printer.printerRecordId ??
              snapshot.localConfig?.kitchenSelection?.printer.id ??
              snapshot.selectedKitchenPrinterId,
          livePrinters: decoratedPrinters,
        );
        if (_selectedTestPrinterId == null && _detectedPrinters.isNotEmpty) {
          _selectedTestPrinterId = _detectedPrinters.first['id']?.toString();
        }
        _receiptPrinterId ??= recommendedId ?? _selectedTestPrinterId;
        _kitchenPrinterId ??= recommendedId ?? _selectedTestPrinterId;
      });
    } catch (error) {
      if (!mounted) return;
      try {
        final snapshot = await _printOrchestrator.loadSetupSnapshot(
          restaurantId: widget.restaurantId,
          forceRefresh: true,
        );
        if (snapshot.bridgeReachable) {
          final legacyPrinters = snapshot.livePrinters
              .map(_printerToLegacyMap)
              .toList(growable: false);
          setState(() {
            _bridgeReachable = snapshot.bridgeReachable;
            _bridgeHealthy = snapshot.bridgeHealthy;
            _bridgeHealth = snapshot.bridgeHealth;
            _livePrinterCount = snapshot.livePrinterCount;
            _setupStatus = snapshot.buildOperatorSetupStatus();
            _detectedPrinters = legacyPrinters;
            _stalePrinters = snapshot.stalePrinters
                .map(_printerToLegacyMap)
                .toList(growable: false);
            _setupError = null;
            _setupTechnicalError = error.toString();
          });
          return;
        }
      } catch (_) {}
      setState(() {
        _bridgeReachable = false;
        _bridgeHealthy = false;
        _livePrinterCount = 0;
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
      if (!mounted) return;
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: widget.restaurantId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _autostartResponse = response;
        _bridgeReachable = snapshot.bridgeReachable;
        _bridgeHealthy = snapshot.bridgeHealthy;
        _bridgeHealth = snapshot.bridgeHealth;
        _livePrinterCount = snapshot.livePrinterCount;
        _setupStatus = snapshot.buildOperatorSetupStatus();
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
        forceRefresh: true,
      );
      final legacyPrinters = snapshot.livePrinters
          .map(_printerToLegacyMap)
          .toList(growable: false);
      final stalePrinters = snapshot.stalePrinters
          .map(_printerToLegacyMap)
          .toList(growable: false);
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
        _bridgeReachable = snapshot.bridgeReachable;
        _bridgeHealthy = snapshot.bridgeHealthy;
        _bridgeHealth = snapshot.bridgeHealth;
        _livePrinterCount = snapshot.livePrinterCount;
        _setupStatus = snapshot.buildOperatorSetupStatus();
        _detectedPrinters = _sortDetectedPrinters(printers);
        _stalePrinters = stalePrinters;
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
    final operatorTier = printer.raw['operatorTier']?.toString() ?? 'normal';
    final isPosCandidate = printer.raw['isPosCandidate'] == true;
    final printVerified = printer.lastTestStatus == 'ok';
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
      'isLive': printer.isLiveDiscovery,
      'isSavedOnly': printer.isStaleSavedMapping,
      'operatorTier': operatorTier,
      'isPosCandidate': isPosCandidate,
      'isRecommended': isPosCandidate,
      'printVerified': printVerified,
      'selectionWarning': WindowsPrinterClassification.selectionWarningFor(
        printer,
      ),
      'statusLevel': printer.isStaleSavedMapping
          ? 'error'
          : (printer.statusLevel ?? (printer.canPrint ? 'ready' : 'warning')),
      'statusMessage': printer.isStaleSavedMapping
          ? 'Eski/kayıp — canlı taramada yok'
          : printer.statusMessage,
      'connectionType':
          printer.raw['connectionType']?.toString() ??
          printer.raw['connection_type']?.toString(),
      'portName':
          printer.raw['portName']?.toString() ??
          printer.raw['port_name']?.toString(),
      'driverName':
          printer.raw['driverName']?.toString() ??
          printer.raw['driver_name']?.toString(),
    };
  }

  List<Map<String, dynamic>> _sortDetectedPrinters(
    List<Map<String, dynamic>> printers,
  ) {
    int rank(Map<String, dynamic> printer) {
      final tier = printer['operatorTier']?.toString() ?? 'normal';
      switch (tier) {
        case 'pos_candidate':
          return 0;
        case 'normal':
          return 1;
        case 'not_recommended':
          return 2;
        default:
          return 3;
      }
    }

    final sorted = List<Map<String, dynamic>>.from(printers);
    sorted.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
    });
    return sorted;
  }

  bool get _hasWindowsPosCandidate =>
      _detectedPrinters.any((printer) => printer['isPosCandidate'] == true);

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
      final failureDetails = result.ok
          ? null
          : WindowsPrinterClassification.formatTestFailureDetails(result.raw);
      final bridgeBody = result.raw == null || result.raw!.isEmpty
          ? ''
          : const JsonEncoder.withIndent('  ').convert(result.raw);
      setState(() {
        _testResponse = result.raw;
        _testPassed = result.ok;
        _testError = result.ok
            ? null
            : failureDetails != null && failureDetails.isNotEmpty
            ? '${result.message}\n$failureDetails'
            : bridgeBody.isNotEmpty
            ? '${result.status}: ${result.message}\n\nBridge yanıtı:\n$bridgeBody'
            : '${result.status}: ${result.message}';
        _testWarning = result.ok && result.status != 'ready'
            ? result.message
            : null;
      });
      if (result.ok) {
        await _refreshTurkishEncodingStatus();
      }
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

  Future<void> _refreshTurkishEncodingStatus() async {
    final printer = _selectedUnifiedPrinter();
    if (printer == null) {
      if (!mounted) return;
      setState(() {
        _turkishEncodingVerified = false;
        _selectedEncodingCandidateId = null;
        _turkishCalibrationMessage = null;
      });
      return;
    }
    final profile = await _printOrchestrator.loadEncodingProfile(
      restaurantId: widget.restaurantId,
      printerId: printer.id,
    );
    if (!mounted) return;
    setState(() {
      _turkishEncodingVerified = profile != null;
      _selectedEncodingCandidateId = profile?.candidateId;
      _selectedTurkishPrintMode =
          profile?.printMode ?? kTurkishPrintModeText;
      _turkishCalibrationMessage = profile == null
          ? null
          : profile.isGuaranteeMode
          ? 'Türkçe Garanti Modu (görsel/raster)'
          : '${profile.encoding} / ESC t ${profile.codePage}';
    });
  }

  Future<void> _saveTurkishPrintModeSelection() async {
    final printer = _selectedUnifiedPrinter();
    if (printer == null) {
      setState(() {
        _turkishCalibrationError = 'Önce test yazıcısı seçin.';
      });
      return;
    }
    setState(() {
      _turkishCalibrationBusy = true;
      _turkishCalibrationError = null;
    });
    try {
      final result = await _printOrchestrator.saveTurkishPrintMode(
        restaurantId: widget.restaurantId,
        printer: printer,
        printMode: _selectedTurkishPrintMode,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _turkishCalibrationError = result.message);
        return;
      }
      setState(() {
        _turkishEncodingVerified = true;
        _turkishCalibrationMessage = result.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _turkishCalibrationError = _operatorErrorMessage(
          error,
          fallback: 'Baskı modu kaydedilemedi.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _turkishCalibrationBusy = false);
      }
    }
  }

  Future<void> _printTurkishGuaranteeSample() async {
    final printer = _selectedUnifiedPrinter();
    if (printer == null) {
      setState(() {
        _turkishCalibrationError = 'Önce test yazıcısı seçin.';
      });
      return;
    }
    setState(() {
      _turkishCalibrationBusy = true;
      _turkishCalibrationError = null;
    });
    try {
      await _printOrchestrator.saveTurkishPrintMode(
        restaurantId: widget.restaurantId,
        printer: printer,
        printMode: kTurkishPrintModeGuarantee,
      );
      final result = await _printOrchestrator.printTurkishGuaranteeSample(
        restaurantId: widget.restaurantId,
        printer: printer,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _turkishCalibrationError = result.message);
        return;
      }
      setState(() {
        _selectedTurkishPrintMode = kTurkishPrintModeGuarantee;
        _turkishEncodingVerified = true;
        _turkishCalibrationMessage =
            'Garanti modu test fişi gönderildi. Çiğ Köfte, Ciğer Şiş, Kuşbaşı '
            've Kıyma Dürüm satırlarını kontrol edin.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _turkishCalibrationError = _operatorErrorMessage(
          error,
          fallback: 'Garanti modu test fişi gönderilemedi.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _turkishCalibrationBusy = false);
      }
    }
  }

  Future<void> _printTurkishEncodingCombinedSheet() async {
    final printer = _selectedUnifiedPrinter();
    if (printer == null) {
      setState(() {
        _turkishCalibrationError = 'Önce test yazıcısı seçin.';
      });
      return;
    }
    setState(() {
      _turkishCalibrationBusy = true;
      _turkishCalibrationError = null;
    });
    try {
      final result =
          await _printOrchestrator.printTurkishEncodingCalibrationSheet(
            restaurantId: widget.restaurantId,
            printer: printer,
          );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _turkishCalibrationError = result.message;
        });
        return;
      }
      setState(() {
        _turkishCalibrationMessage = result.message;
        _turkishCombinedSheetPrinted = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _turkishCalibrationError = _operatorErrorMessage(
          error,
          fallback: 'Türkçe karakter testi gönderilemedi.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _turkishCalibrationBusy = false;
        });
      }
    }
  }

  Future<void> _confirmTurkishEncodingSelection() async {
    final candidate = turkishEncodingCandidateById(_selectedEncodingCandidateId);
    final printer = _selectedUnifiedPrinter();
    if (candidate == null || printer == null) {
      setState(() {
        _turkishCalibrationError =
            'Önce tek fiş testini basın ve doğru çıkan satırı seçin.';
      });
      return;
    }
    setState(() {
      _turkishCalibrationBusy = true;
      _turkishCalibrationError = null;
    });
    try {
      final result = await _printOrchestrator.saveEncodingProfileFromCandidate(
        restaurantId: widget.restaurantId,
        printer: printer,
        candidate: candidate,
        printModeOverride: _selectedTurkishPrintMode,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _turkishCalibrationError = result.message;
          _turkishEncodingVerified = false;
        });
        return;
      }
      setState(() {
        _turkishEncodingVerified = true;
        _turkishCalibrationMessage = result.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _turkishCalibrationError = _operatorErrorMessage(
          error,
          fallback: 'Türkçe karakter profili kaydedilemedi.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _turkishCalibrationBusy = false;
        });
      }
    }
  }

  UnifiedPrinterModel? _selectedUnifiedPrinter() {
    final selected = _selectedPrinter;
    if (selected == null) return null;
    return UnifiedPrinterModel.fromBridgeMap(
      <String, dynamic>{
        ...selected,
        'id': selected['id']?.toString() ?? '',
        'name': selected['queue']?.toString() ?? selected['name']?.toString(),
        'queue': selected['queue']?.toString() ?? selected['name']?.toString(),
        'backend': selected['backend']?.toString() ?? 'windows-spool',
        'source': 'usb_scan',
        'statusLevel': selected['statusLevel']?.toString() ?? 'ready',
        'ready': selected['statusLevel']?.toString() == 'ready',
      },
      os: DesktopPrinterOs.windows,
    );
  }

  Future<PrinterActionResult> _runWizardTestPrint({
    required String printerId,
    required Map<String, dynamic>? selectedPrinter,
    required PrinterSetupRole role,
  }) async {
    final explicit = _selectedUnifiedPrinter();
    debugPrint(
      '[WIZARD_TEST_PAYLOAD] '
      'uiSelectedId=$printerId '
      'uiMap=${selectedPrinter == null ? '-' : jsonEncode(selectedPrinter)} '
      'explicit.id=${explicit?.id ?? '-'} '
      'explicit.queue=${explicit?.queueName ?? '-'} '
      'explicit.backend=${explicit?.backend.value ?? '-'}',
    );
    return _printOrchestrator.printTestReceipt(
      restaurantId: widget.restaurantId,
      role: role,
      printerId: explicit?.id ?? printerId,
      explicitLivePrinter: explicit,
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
        requireSuccessfulRoleTests: true,
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
          'label': 'Yazıcı servisi çalışıyor',
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
      'message': 'Yazıcı servisi kapalı olduğu için gereksinimler doğrulanamadı.',
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
        return 'Yazıcı Servisi Çalışmıyor';
      case 'printer_selection_pending':
        return 'Yazıcı Seçimi Bekleniyor';
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

  String _printerLevelLabel(Map<String, dynamic> printer) {
    if (printer['printVerified'] == true) {
      return 'Baskı doğrulandı';
    }
    final tier = printer['operatorTier']?.toString() ?? '';
    if (tier == 'pos_candidate') return 'POS önerilir';
    if (tier == 'not_recommended') return 'Uygun değil';
    switch ((printer['statusLevel']?.toString() ?? '').trim().toLowerCase()) {
      case 'ready':
        return 'Çevrimiçi';
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
        return _bridgeReachable;
      case 3:
        return true;
      case 4:
        return _selectedTestPrinterId != null;
      case 5:
        return _testPassed && _turkishEncodingVerified;
      case 6:
        return !_saving;
      default:
        return false;
    }
  }

  bool get _canCompleteSetup =>
      !_saving &&
      _testPassed &&
      _turkishEncodingVerified &&
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

  String get _headerStatusKey => bridgeOperatorSetupStatusKey(
    bridgeReachable: _bridgeReachable,
    bridgeHealthy: _bridgeHealthy,
    livePrinterCount: _livePrinterCount,
    bridgeHealth: _bridgeHealth,
  );

  String? _coerceLiveSelectionId({
    required String? currentId,
    required String? snapshotId,
    required List<Map<String, dynamic>> livePrinters,
  }) {
    for (final candidate in <String?>[currentId, snapshotId]) {
      final id = candidate?.trim() ?? '';
      if (id.isEmpty) continue;
      for (final printer in livePrinters) {
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
    }
    return null;
  }

  Future<void> _startBridgeService() async {
    setState(() {
      _bridgeStartBusy = true;
      _bridgeStartMessage = 'Yazıcı servisi başlatılıyor...';
      _setupError = null;
    });
    try {
      final startResult = await BridgeManager.ensureReady(
        onProgress: (message) {
          if (!mounted) return;
          setState(() => _bridgeStartMessage = message);
        },
      );
      await _refreshSystemCheck();
      if (!mounted) return;
      setState(() {
        _bridgeStartMessage = _bridgeReachable
            ? 'Yazıcı servisi hazır.'
            : (startResult.message.isNotEmpty
                  ? startResult.message
                  : (kIsWeb
                        ? 'Yazıcı servisi başlatılamadı. Ibul Satıcı Windows kurulumunu çalıştırın.'
                        : 'Yazıcı servisini başlatın veya onarın.'));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bridgeStartMessage = _operatorErrorMessage(
          error,
          fallback: 'Yazıcı servisi başlatılamadı.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _bridgeStartBusy = false);
      }
    }
  }

  Future<void> _repairBridgeService() async {
    setState(() {
      _bridgeStartBusy = true;
      _bridgeStartMessage = 'Yazıcı servisi onarılıyor...';
      _setupError = null;
    });
    try {
      final startResult = await BridgeManager.ensureReady(
        onProgress: (message) {
          if (!mounted) return;
          setState(() => _bridgeStartMessage = message);
        },
      );
      if (!startResult.ok || !_bridgeReachable) {
        final service = _localPrintServiceFactory();
        await service.setupStart();
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await _refreshSystemCheck();
      if (!mounted) return;
      setState(() {
        _bridgeStartMessage = _bridgeReachable
            ? 'Yazıcı servisi hazır.'
            : (kIsWeb
                  ? 'Yazıcı servisi onarılamadı. Ibul Satıcı Windows kurulumunu yeniden çalıştırın.'
                  : 'Yazıcı servisini onarın veya uygulamayı yeniden başlatın.');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bridgeStartMessage = _operatorErrorMessage(
          error,
          fallback: 'Yazıcı servisi onarılamadı.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _bridgeStartBusy = false);
      }
    }
  }

  Widget _buildBridgeOperatorButtons({bool compact = false}) {
    final spacing = compact ? 8.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            FilledButton.icon(
              onPressed: _bridgeStartBusy ? null : _startBridgeService,
              icon: _bridgeStartBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline),
              label: Text(
                _bridgeStartBusy ? 'Başlatılıyor...' : 'Yazıcı servisini başlat',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _bridgeStartBusy ? null : _repairBridgeService,
              icon: const Icon(Icons.build_circle_outlined),
              label: const Text('Yazıcı servisini onar'),
            ),
            OutlinedButton.icon(
              onPressed: (_bridgeStartBusy || !_bridgeReachable || _detectingPrinters)
                  ? null
                  : _detectPrinters,
              icon: _detectingPrinters
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Yazıcıları Yeniden Tara'),
            ),
          ],
        ),
        if (_bridgeStartMessage != null) ...[
          SizedBox(height: spacing),
          Text(
            _bridgeStartMessage!,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
        ],
      ],
    );
  }

  Future<void> _sendAdvancedBitmapTest() async {
    final printerId = _selectedTestPrinterId;
    final selectedPrinter = _selectedPrinter;
    if (printerId == null || selectedPrinter == null) return;

    setState(() {
      _testingPrinter = true;
      _testError = null;
      _testWarning = null;
      _testTechnicalError = null;
    });
    try {
      final explicit = _selectedUnifiedPrinter();
      final service = _localPrintServiceFactory();
      final response = await service.printAdvancedBitmapTest(
        printerId: explicit?.id ?? printerId,
        printerName: explicit?.queueName ?? selectedPrinter['queue']?.toString(),
        printer: explicit == null
            ? selectedPrinter
            : <String, dynamic>{
                'id': explicit.id,
                'name': explicit.displayName,
                'queue': explicit.queueName,
                'queueName': explicit.queueName,
                'backend': explicit.backend.value,
                'connectionType': explicit.raw['connectionType'] ??
                    explicit.raw['connection_type'] ??
                    'usb',
              },
      );
      if (!mounted) return;
      final ok = response?['ok'] == true;
      final failureDetails = ok
          ? null
          : WindowsPrinterClassification.formatTestFailureDetails(response);
      setState(() {
        _testResponse = response;
        _testPassed = ok;
        _testError = ok
            ? null
            : failureDetails != null && failureDetails.isNotEmpty
            ? 'Gelişmiş bitmap testi başarısız.\n$failureDetails'
            : 'Gelişmiş bitmap testi başarısız.';
        _testWarning = ok ? 'Bitmap testi gönderildi (Pillow gerekir).' : null;
      });
    } catch (error) {
      if (!mounted) return;
      final details = error is LocalPrintServiceException &&
              error.details is Map<String, dynamic>
          ? WindowsPrinterClassification.formatTestFailureDetails(
              error.details! as Map<String, dynamic>,
            )
          : '';
      setState(() {
        _testPassed = false;
        _testError = details.isNotEmpty
            ? 'Gelişmiş bitmap testi başarısız.\n$details'
            : _operatorErrorMessage(
                error,
                fallback: 'Gelişmiş bitmap testi gönderilemedi.',
              );
        _testTechnicalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _testingPrinter = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _headerStatusKey;
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
                      title: const Text('Yazıcı Kurulumu'),
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
        if (!_bridgeReachable) ...[
          const SizedBox(height: 12),
          _buildBridgeOperatorButtons(),
        ],
        if (kDebugMode)
          _TechnicalDetails(
            data: <String, dynamic>{
              'setupStatus': _setupStatus,
              if (_prerequisites != null) 'prerequisites': _prerequisites,
              if (_driverHelp != null) 'driverHelp': _driverHelp,
              if (_setupTechnicalError != null) 'error': _setupTechnicalError,
              if (kDebugMode && _selectedPlatform == 'windows')
                'devStartHint': 'BridgeManager.ensureReady uses packaged EXE when installed',
            },
          ),
      ],
    );
  }

  Widget _buildInstallStep() {
    final status = _headerStatusKey;
    final isWindows = _selectedPlatform == 'windows';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWindows && !_showPackagedWindowsInstaller
              ? 'Yazıcı servisi bu bilgisayarda çalışıyor olmalı. Kapalıysa aşağıdaki düğmeyle başlatın veya onarın.'
              : isWindows
              ? 'Tarayıcı Windows cihazınıza doğrudan servis kuramaz. Kurulum için yükleyiciyi indirip çalıştırın, sonra tekrar kontrol edin.'
              : 'Yerel yazıcı servisini işletim sistemi üzerinde kurup çalıştırdıktan sonra tekrar kontrol edin.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        _StatusRow(
          title: kDebugMode ? 'Bridge (/health)' : 'Yazıcı servisi',
          value: _bridgeReachable ? 'Erişilebilir' : 'Kapalı',
          color: _bridgeReachable
              ? const Color(0xFF15803D)
              : const Color(0xFFB91C1C),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          title: 'Yazıcılar (/printers)',
          value: '$_livePrinterCount yazıcı',
          color: _livePrinterCount > 0
              ? const Color(0xFF15803D)
              : const Color(0xFFB45309),
        ),
        if (kDebugMode &&
            formatBridgeProcessIdentity(_bridgeHealth).isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            formatBridgeProcessIdentity(_bridgeHealth),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
        ],
        if (!_bridgeReachable) ...[
          const SizedBox(height: 8),
          _buildBridgeOperatorButtons(compact: true),
        ] else ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _detectingPrinters ? null : _detectPrinters,
            icon: _detectingPrinters
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Yazıcıları Yeniden Tara'),
          ),
        ],
        if (_showPackagedWindowsInstaller) ...[
          FilledButton.icon(
            onPressed: _downloadWindowsInstaller,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Ibul Satıcı Windows\'u İndir'),
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
        _StatusRow(
          title: 'Durum',
          value: _wizardStatusLabel(status),
          color: _wizardStatusColor(status),
        ),
        if (status == 'not_installed')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Kurulum tamamlanmadan bu adımı geçemezsiniz.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ),
        if (status == 'running_unhealthy')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Yazıcı servisi yanıt veriyor. Yazıcı taramaya devam edebilirsiniz; sonraki adım hangi parçanın eksik olduğunu gösterecek.',
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
              label: const Text('Yazıcıları Yeniden Tara'),
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
        if (_selectedPlatform == 'windows' && !_hasWindowsPosCandidate) ...[
          const SizedBox(height: 12),
          _WindowsPosSetupGuide(),
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
            child: Text(
              _selectedPlatform == 'windows'
                  ? 'Yazıcı bulunamadı. Lütfen Windows\'ta yazıcı sürücüsünü kurun ve sınama sayfası basın. Ardından "Yazıcıları Yeniden Tara" ile listeyi yenileyin.'
                  : 'Henüz seçilebilir yazıcı bulunamadı. Önce "Yazıcıları Yeniden Tara" ile tekrar deneyin. MacBook üzerinde yazıcı listesi boşsa sistemi veya CUPS yazıcısını eklemeniz gerekir.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
        ],
        if (_stalePrinters.isNotEmpty) ...[
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
              '${_stalePrinters.length} kayıtlı yazıcı bu bilgisayarda canlı taramada yok '
              '(ör. eski Mac/CUPS). Aktif yazıcı olarak kullanılamaz; aşağıdan yeni bir Windows yazıcısı seçin.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF991B1B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final printer in _stalePrinters)
            _DetectedPrinterCard(
              printer: printer,
              selected: false,
              onTap: () {},
              levelLabel: 'Eski/kayıp',
              levelColor: const Color(0xFFB91C1C),
            ),
        ],
        const SizedBox(height: 12),
        for (final printer in _detectedPrinters)
          _DetectedPrinterCard(
            printer: printer,
            selected: printer['id']?.toString() == _selectedTestPrinterId,
            onTap: () {
              final warning = printer['selectionWarning']?.toString();
              setState(() {
                _selectedTestPrinterId = printer['id']?.toString();
                _receiptPrinterId ??= _selectedTestPrinterId;
                _kitchenPrinterId ??= _selectedTestPrinterId;
              });
              unawaited(_refreshTurkishEncodingStatus());
              if (warning != null && warning.trim().isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(warning),
                    backgroundColor: const Color(0xFFB45309),
                  ),
                );
              }
            },
            levelLabel: _printerLevelLabel(printer),
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
          label: const Text('Test Fişi Gönder (Metin / ESC-POS)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _testingPrinter || selectedPrinter == null
              ? null
              : _sendAdvancedBitmapTest,
          icon: const Icon(Icons.image_outlined, size: 16),
          label: const Text('Gelişmiş Bitmap Testi'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Varsayılan test Pillow gerektirmez. Bitmap testi yalnızca gelişmiş doğrulama içindir.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), height: 1.35),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          title: 'Test durumu',
          value: _testPassed
              ? (_testWarning == null
                    ? 'Baskı doğrulandı'
                    : 'Kuyruğa gönderildi (doğrulanmadı)')
              : 'Test edilmedi',
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
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        _buildTurkishEncodingCalibrationSection(),
        _TechnicalDetails(
          data: <String, dynamic>{
            'testResponse': _testResponse,
            if (_testTechnicalError != null) 'error': _testTechnicalError,
          },
        ),
      ],
    );
  }

  Widget _buildTurkishEncodingCalibrationSection() {
    final printerSelected = _selectedTestPrinterId != null;
    final guaranteeMode = _selectedTurkishPrintMode == kTurkishPrintModeGuarantee;
    final recommendGuarantee = !guaranteeMode &&
        _turkishCombinedSheetPrinted &&
        !_turkishEncodingVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Türkçe Baskı Modu',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        RadioListTile<String>(
          value: kTurkishPrintModeText,
          groupValue: _selectedTurkishPrintMode,
          onChanged: printerSelected && !_turkishCalibrationBusy
              ? (value) {
                  if (value == null) return;
                  setState(() => _selectedTurkishPrintMode = value);
                }
              : null,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Hızlı Mod (Text / RAW)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Daha hızlı; bazı POS-58 klon yazıcılarda Türkçe bozulabilir.',
            style: TextStyle(fontSize: 11, height: 1.3),
          ),
        ),
        RadioListTile<String>(
          value: kTurkishPrintModeGuarantee,
          groupValue: _selectedTurkishPrintMode,
          onChanged: printerSelected && !_turkishCalibrationBusy
              ? (value) {
                  if (value == null) return;
                  setState(() => _selectedTurkishPrintMode = value);
                }
              : null,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Türkçe Garanti Modu (Görsel / Raster)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Biraz daha yavaş; gömülü font ile Türkçe karakterler doğru basılır.',
            style: TextStyle(fontSize: 11, height: 1.3),
          ),
        ),
        if (recommendGuarantee)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Text(
              'Bu yazıcıda Türkçe karakterler text modda güvenilir görünmüyor. '
              'Türkçe Garanti Modu önerilir.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.35),
            ),
          ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Türkçe Karakter Testi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          printerSelected
              ? (_turkishEncodingVerified
                    ? (guaranteeMode
                          ? 'Türkçe Garanti Modu kayıtlı.'
                          : 'Türkçe karakter doğrulandı.')
                    : guaranteeMode
                    ? 'Garanti modu test fişini basıp kaydedin.'
                    : 'Tek fişte tüm seçenekleri basıp doğru satırı seçin.')
              : 'Önce yukarıdan test yazıcısı seçin.',
          style: TextStyle(
            fontSize: 12,
            color: _turkishEncodingVerified
                ? const Color(0xFF15803D)
                : const Color(0xFFB45309),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        _StatusRow(
          title: 'Türkçe karakter',
          value: _turkishEncodingVerified
              ? (guaranteeMode ? 'Garanti modu kayıtlı' : 'Türkçe karakter doğrulandı')
              : 'Doğrulanmadı',
          color: _turkishEncodingVerified
              ? const Color(0xFF15803D)
              : const Color(0xFFB45309),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          title: 'Baskı hızı',
          value: _testPassed
              ? (_testWarning == null ? 'Baskı doğrulandı' : 'Kuyruğa gönderildi')
              : 'Önce test fişi gönderin',
          color: _testPassed
              ? (_testWarning == null
                    ? const Color(0xFF15803D)
                    : const Color(0xFFD97706))
              : const Color(0xFF6B7280),
        ),
        if (_turkishCalibrationMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _turkishCalibrationMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
        const SizedBox(height: 10),
        if (guaranteeMode) ...[
          FilledButton.icon(
            onPressed: !printerSelected || _turkishCalibrationBusy
                ? null
                : _printTurkishGuaranteeSample,
            icon: _turkishCalibrationBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            label: const Text('Garanti modu test fişi bas'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: !printerSelected || _turkishCalibrationBusy
                ? null
                : _saveTurkishPrintModeSelection,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Garanti modunu kaydet'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: !printerSelected || _turkishCalibrationBusy
                ? null
                : _printTurkishEncodingCombinedSheet,
            icon: _turkishCalibrationBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            label: const Text('Tüm seçenekleri tek fişte bas'),
          ),
          const SizedBox(height: 10),
        ],
        if (!guaranteeMode)
        ...kTurkishEncodingCalibrationCandidates.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final candidate = entry.value;
          final selected = _selectedEncodingCandidateId == candidate.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<String>(
                  value: candidate.id,
                  groupValue: _selectedEncodingCandidateId,
                  onChanged: printerSelected && !_turkishCalibrationBusy
                      ? (value) {
                          setState(() {
                            _selectedEncodingCandidateId = value;
                          });
                        }
                      : null,
                ),
                Expanded(
                  child: Text(
                    candidate.formatReceiptOptionLine(index),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: const Color(0xFF111827),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (!guaranteeMode)
          FilledButton.icon(
            onPressed: !printerSelected ||
                    _turkishCalibrationBusy ||
                    _selectedEncodingCandidateId == null
                ? null
                : _confirmTurkishEncodingSelection,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Doğru satırı kaydet'),
          ),
        if (_turkishCalibrationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _turkishCalibrationError!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
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
    final tier = printer['operatorTier']?.toString() ?? '';
    final tierBadge = tier == 'pos_candidate'
        ? 'POS / Termal'
        : tier == 'not_recommended'
        ? 'Önerilmez'
        : '';
    final tierColor = tier == 'pos_candidate'
        ? const Color(0xFF15803D)
        : const Color(0xFF9CA3AF);
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
            if (tierBadge.isNotEmpty) ...[
              const SizedBox(height: 6),
              _StatusChip(label: tierBadge, color: tierColor),
            ],
            if (badge.isNotEmpty) ...[
              const SizedBox(height: 6),
              _StatusChip(label: badge, color: badgeColor),
            ],
            if (printer['printVerified'] == true) ...[
              const SizedBox(height: 6),
              const _StatusChip(
                label: 'Baskı doğrulandı',
                color: Color(0xFF15803D),
              ),
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

class _WindowsPosSetupGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = WindowsPrinterClassification.windowsPosSetupGuideSteps();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POS58 termal yazıcı kurulum rehberi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Canlı taramada POS/termal aday bulunamadı. Generic / Text Only veya Fax hedefleri fiş basmaz.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF7C2D12), height: 1.4),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${i + 1}. ${steps[i]}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7C2D12),
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
    if (!kDebugMode || data == null) return const SizedBox.shrink();
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
