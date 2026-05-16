import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/desktop_print_ports.dart';
import '../../models/desktop_printer_setup_models.dart';
import '../../models/printer_model.dart';
import '../../models/printer_profile.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/desktop_print_hub.dart';
import '../../services/print_station_service.dart';
import '../../services/printer_repository.dart';
import '../../widgets/bridge_error_dialog.dart';
import 'printer_system_setup_wizard.dart';
import 'printer_wizard.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Printer Setup Page
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen setup page for the desktop print system.
///
/// 3 tabs:
///   Tab 0 “Yazıcılar”  — printer list with wizard + per-printer test
///   Tab 1 “Dinleyici” — bridge health, listener stats, failed jobs
///   Tab 2 “Kılavuz”   — static setup guide
class DesktopPrinterSetupPage extends StatelessWidget {
  const DesktopPrinterSetupPage({
    super.key,
    this.restaurantIdOverride,
    this.onRefreshRequested,
    this.listenerTabOverride,
    this.guideTabOverride,
    this.printOrchestrator,
    this.printStationService,
    this.printerStreamBuilder,
  });

  final String? restaurantIdOverride;
  final VoidCallback? onRefreshRequested;
  final Widget? listenerTabOverride;
  final Widget? guideTabOverride;
  final DesktopPrintOrchestrator? printOrchestrator;
  final PrintStationServicePort? printStationService;
  final Stream<List<PrinterModel>> Function(String restaurantId)?
  printerStreamBuilder;

  Widget _buildScaffold({
    required String restaurantId,
    required VoidCallback onRefresh,
    required Widget listenerTab,
    required Widget guideTab,
  }) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: const BackButton(),
          title: const Text(
            'Yazıcı Ayarları',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Durumu Yenile',
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.print_outlined, size: 18),
                text: 'Yazıcılar',
              ),
              Tab(icon: Icon(Icons.sensors, size: 18), text: 'Dinleyici'),
              Tab(
                icon: Icon(Icons.menu_book_outlined, size: 18),
                text: 'Kılavuz',
              ),
            ],
            labelColor: Color(0xFF8B5CF6),
            unselectedLabelColor: Color(0xFF6B7280),
            indicatorColor: Color(0xFF8B5CF6),
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        body: TabBarView(
          children: [
            _PrintersTab(
              restaurantId: restaurantId,
              printOrchestrator: printOrchestrator,
              printStationService: printStationService,
              printerStreamBuilder: printerStreamBuilder,
            ),
            listenerTab,
            guideTab,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (restaurantIdOverride != null) {
      return _buildScaffold(
        restaurantId: restaurantIdOverride ?? '',
        onRefresh: onRefreshRequested ?? () {},
        listenerTab: listenerTabOverride ?? const SizedBox.shrink(),
        guideTab: guideTabOverride ?? const _GuideTab(),
      );
    }
    return Consumer<DesktopPrintHub>(
      builder: (ctx, hub, _) {
        final restaurantId = hub.restaurantId ?? '';
        return _buildScaffold(
          restaurantId: restaurantId,
          onRefresh: hub.checkBridge,
          listenerTab: _ListenerTabView(hub: hub),
          guideTab: const _GuideTab(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Tab 0 — Yazıcılar
// ─────────────────────────────────────────────────────────────────────────────────

class _PrintersTab extends StatefulWidget {
  const _PrintersTab({
    required this.restaurantId,
    this.printOrchestrator,
    this.printStationService,
    this.printerStreamBuilder,
  });

  final String restaurantId;
  final DesktopPrintOrchestrator? printOrchestrator;
  final PrintStationServicePort? printStationService;
  final Stream<List<PrinterModel>> Function(String restaurantId)?
  printerStreamBuilder;

  @override
  State<_PrintersTab> createState() => _PrintersTabState();
}

class _PrintersTabState extends State<_PrintersTab> {
  late final DesktopPrintOrchestrator _printOrchestrator;
  late final PrintStationServicePort _printStationService;
  bool _loadingPrintCenter = true;
  bool _runningMaintenance = false;
  bool _runningHardReset = false;
  bool _savingPrintCenter = false;
  bool _testingReceipt = false;
  bool _testingKitchen = false;
  bool _testingGeneric = false; // Generic test that auto-selects USB printer
  bool _savingPrintSystemEnabled = false;
  bool _printSystemEnabled = true;
  bool _printSystemEnabledLoaded = false;
  bool _printSystemSourceIsLocalRuntime = false;
  bool? _localPrintSystemEnabled;
  bool? _remotePrintSystemEnabled;
  List<Map<String, dynamic>> _pausedPrintJobs = const <Map<String, dynamic>>[];
  String? _printCenterError;
  String? _printSystemError;
  String? _printSystemSyncNotice;
  String? _selectedReceiptPrinterId;
  String? _selectedKitchenPrinterId;
  Map<String, dynamic>?
  _workingTestPrinter; // Captured from successful /print/test
  bool _bridgeReachable = false;
  bool _bridgeHealthy = false;
  List<Map<String, dynamic>> _bridgePrinters = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _bridgeHealth;
  Map<String, dynamic>? _printSystemQueueStatus;

  bool get _isQueuePrintSystemDisabled =>
      _queueRuntimePrintSystemDisabled(_printSystemQueueStatus);

  bool _isWarningResult(PrinterActionResult result) {
    if (!result.ok) {
      return false;
    }
    if (result.status != 'ready') {
      return true;
    }
    final confirmationStatus =
        result.raw?['confirmation_status']?.toString().trim() ?? '';
    return confirmationStatus == 'cups_accepted_unverified';
  }

  String _successMessageForResult(
    PrinterActionResult result, {
    required String successFallback,
  }) {
    if (_isWarningResult(result)) {
      return result.message.trim().isNotEmpty
          ? result.message
          : 'Test işi yazıcı kuyruğuna gönderildi. Fiziksel baskıyı kontrol edin.';
    }
    return successFallback;
  }

  Map<String, dynamic>? _setupStatus;
  Map<String, dynamic>? _setupPrerequisites;
  Map<String, dynamic>? _discoverResult;

  @override
  void initState() {
    super.initState();
    _printOrchestrator =
        widget.printOrchestrator ?? DesktopPrintOrchestrator();
    _printStationService = widget.printStationService ?? PrintStationService();
    unawaited(_loadPrintCenterState());
  }

  Future<void> _loadPrintCenterState() async {
    if (!mounted) return;
    setState(() {
      _loadingPrintCenter = true;
      _printCenterError = null;
    });
    try {
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: widget.restaurantId,
        forceRefresh: true,
      );
      final bridgePrinters = snapshot.printers
          .map(_printerToLegacyMap)
          .toList(growable: false);
      var localPrintSystemEnabled = _extractLocalPrintSystemEnabled(
        snapshot.queueStatus,
      );
      var remotePrintSystemEnabled = _extractRemotePrintSystemEnabled(
        snapshot.remoteConfig,
      );
      var syncNotice = _buildPrintSystemSyncNotice(
        localEnabled: localPrintSystemEnabled,
        remoteEnabled: remotePrintSystemEnabled,
      );
      if (localPrintSystemEnabled != null &&
          remotePrintSystemEnabled != localPrintSystemEnabled) {
        try {
          await _printStationService.patchStationConfiguration(
            restaurantId: widget.restaurantId,
            fields: <String, dynamic>{
              'print_system_enabled': localPrintSystemEnabled,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          remotePrintSystemEnabled = localPrintSystemEnabled;
          syncNotice =
              'Yerel bridge çalışma değeri ile bulut ayarı farklıydı. Bridge runtime değeri buluta senkronlandı.';
        } catch (_) {
          syncNotice ??=
              'Yerel bridge çalışma değeri ekranda gösteriliyor. Bulut ayarı senkronlanamadı.';
        }
      }
      if (!mounted) return;
      final pausedJobs = await _printStationService
          .fetchPausedPrintJobs(widget.restaurantId);
      if (!mounted) return;
      final queueDisabled =
          _queueRuntimePrintSystemDisabled(snapshot.queueStatus);
      setState(() {
        _bridgeReachable = snapshot.bridgeReachable;
        _bridgeHealthy = snapshot.bridgeHealthy;
        _bridgeHealth = snapshot.bridgeHealth ?? const <String, dynamic>{};
        _printSystemQueueStatus = snapshot.queueStatus;
        _setupStatus = snapshot.setupStatus;
        _setupPrerequisites = snapshot.prerequisites;
        _discoverResult = snapshot.discoveryWarning == null
            ? null
            : <String, dynamic>{'warning': snapshot.discoveryWarning};
        _bridgePrinters = bridgePrinters;
        _selectedReceiptPrinterId = _coerceSelectedPrinterId(
          printers: bridgePrinters,
          currentSelectedId: _selectedReceiptPrinterId,
          snapshotSelectedId:
              snapshot.selectedReceiptPrinterRecordId ??
              snapshot.localConfig?.receiptSelection?.printer.printerRecordId ??
              snapshot.localConfig?.receiptSelection?.printer.id ??
              snapshot.selectedReceiptPrinterId,
        );
        _selectedKitchenPrinterId = _coerceSelectedPrinterId(
          printers: bridgePrinters,
          currentSelectedId: _selectedKitchenPrinterId,
          snapshotSelectedId:
              snapshot.selectedKitchenPrinterRecordId ??
              snapshot.localConfig?.kitchenSelection?.printer.printerRecordId ??
              snapshot.localConfig?.kitchenSelection?.printer.id ??
              snapshot.selectedKitchenPrinterId,
        );
        _localPrintSystemEnabled = localPrintSystemEnabled;
        _remotePrintSystemEnabled = remotePrintSystemEnabled;
        _printSystemSourceIsLocalRuntime = localPrintSystemEnabled != null;
        _printSystemEnabled = localPrintSystemEnabled ??
            remotePrintSystemEnabled ??
            (queueDisabled ? false : true);
        _printSystemEnabledLoaded = localPrintSystemEnabled != null ||
            remotePrintSystemEnabled != null ||
            snapshot.queueStatus != null;
        _printSystemSyncNotice = syncNotice;
        _pausedPrintJobs = pausedJobs;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPrintCenter = false;
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
    await _loadPrintCenterState();
  }

  String _setupStatusKey() {
    return (_setupStatus?['status']?.toString() ?? '').trim().toLowerCase();
  }

  String _setupActionRequired() {
    return (_setupStatus?['actionRequired']?.toString() ?? '')
        .trim()
        .toLowerCase();
  }

  bool get _hasDetectedPrinters =>
      _bridgePrinters.any((printer) => printer['isLive'] == true);

  bool get _canSelectPrinterRoles => _bridgeHealthy && _hasDetectedPrinters;

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

    final messenger = ScaffoldMessenger.of(context);
    final errorMessage =
        'Baskı sistemi güncellenemedi. Yerel bridge ve bulut ayarı eski duruma geri alındı.';
    try {
      final result = await _printStationService.setPrintSystemEnabled(
        restaurantId: widget.restaurantId,
        enabled: enabled,
        previousEnabled: previousEnabled,
      );
      if (!result) {
        throw Exception(errorMessage);
      }
      await _loadPrintCenterState();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Baskı sistemi açıldı. Yeni siparişler otomatik yazdırılır.'
                : 'Baskı sistemi kapatıldı. Siparişler alınır ancak fişler otomatik yazdırılmaz.',
          ),
          backgroundColor: enabled
              ? const Color(0xFF10B981)
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
        _printSystemError = message.isEmpty ? errorMessage : message;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_printSystemError ?? errorMessage),
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

  String _printSystemStateDetailLabel(bool? value) {
    if (value == null) {
      return 'Bilinmiyor';
    }
    return _printSystemStateLabel(value);
  }

  String? _buildPrintSystemSyncNotice({
    required bool? localEnabled,
    required bool? remoteEnabled,
  }) {
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

  bool _guardPrintSystemDisabled({required String actionLabel}) {
    final effectivelyOff = _isQueuePrintSystemDisabled || !_printSystemEnabled;
    if (!_printSystemEnabledLoaded || !effectivelyOff) {
      return false;
    }
    final message =
        'Baskı sistemi kapalı. $actionLabel için önce sistemi açın.';
    setState(() {
      _printCenterError = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF59E0B),
      ),
    );
    return true;
  }

  Widget _buildPrintSystemControlCard() {
    final isQueueDisabled = _isQueuePrintSystemDisabled;
    final uiEnabled = !isQueueDisabled && _printSystemEnabled;
    final statusLabel = !_printSystemEnabledLoaded
        ? 'Yükleniyor...'
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
    final subtitle = !_printSystemEnabledLoaded
        ? 'Durum yükleniyor...'
        : isQueueDisabled
        ? 'Bridge Queue: print_system_disabled'
        : _printSystemDescription(_printSystemEnabled);
    final bannerColor = !_printSystemEnabledLoaded
        ? const Color(0xFFF3F4F6)
        : uiEnabled
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFFEDD5);
    final bannerBorder = !_printSystemEnabledLoaded
        ? const Color(0xFFD1D5DB)
        : uiEnabled
        ? const Color(0xFF16A34A)
        : const Color(0xFFEA580C);
    final primaryButtonColor = uiEnabled
        ? const Color(0xFFDC2626)
        : const Color(0xFF15803D);
    final primaryButtonLabel = uiEnabled
        ? 'Baskı Sistemini Kapat'
        : 'Baskı Sistemini Aç';
    final sourceLabel = _printSystemSourceIsLocalRuntime
        ? 'Gösterilen kaynak: Yerel bridge runtime'
        : 'Gösterilen kaynak: Bulut ayarı';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
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
                  color: bannerBorder,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _printSystemEnabledLoaded
                        ? _printSystemBannerText(uiEnabled)
                        : 'Baskı sistemi durumu yükleniyor...',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: !_printSystemEnabledLoaded
                          ? const Color(0xFF374151)
                          : uiEnabled
                          ? const Color(0xFF166534)
                          : const Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.power_settings_new,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baskı Sistemi',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: uiEnabled,
                onChanged:
                    _savingPrintSystemEnabled || !_printSystemEnabledLoaded
                    ? null
                    : _togglePrintSystemEnabled,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineStatusChip(
                label:
                    'Bridge runtime: ${_printSystemStateDetailLabel(_localPrintSystemEnabled)}',
                color: _localPrintSystemEnabled == null
                    ? const Color(0xFF6B7280)
                    : (_localPrintSystemEnabled!
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309)),
              ),
              _InlineStatusChip(
                label:
                    'Bulut ayarı: ${_printSystemStateDetailLabel(_remotePrintSystemEnabled)}',
                color: _remotePrintSystemEnabled == null
                    ? const Color(0xFF6B7280)
                    : (_remotePrintSystemEnabled!
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sourceLabel,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _savingPrintSystemEnabled || !_printSystemEnabledLoaded
                  ? null
                  : () => _togglePrintSystemEnabled(!uiEnabled),
              icon: _savingPrintSystemEnabled
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      uiEnabled
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
              label: Text(primaryButtonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: primaryButtonColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_pausedPrintJobs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Text(
                'Bekleyen baskı sayısı: ${_pausedPrintJobs.length}.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
          ],
          if (_printSystemSyncNotice != null &&
              _printSystemSyncNotice!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _printSystemSyncNotice!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF075985),
                ),
              ),
            ),
          if (_printSystemError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _printSystemError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ),
        ],
      ),
    );
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
    return _bridgeHealthy ? 'Bridge hazır' : 'Bridge çalışıyor ama hatalı';
  }

  String _bridgeSummaryMessage() {
    if (!_bridgeReachable) {
      return 'Yerel yazıcı servisine ulaşılamıyor. Önce bridge kurulumunu tamamlayın veya servisi başlatın.';
    }
    final details = _bridgeHealth?['printer']?['details']?.toString().trim();
    if (_bridgeHealthy) {
      return 'Yazıcı servisi yanıt veriyor. Sıradaki adım yerel yazıcıları taramak.';
    }
    if (details != null && details.isNotEmpty) {
      return 'Bridge yanıt veriyor ama yazıcı doğrulaması başarısız: $details';
    }
    return _setupStatus?['message']?.toString() ??
        'Bridge yanıt veriyor ancak yazıcı doğrulaması tamamlanamadı.';
  }

  String? _printerDiscoveryGuidance() {
    final status = _setupStatusKey();
    final action = _setupActionRequired();
    final printerDetails = _bridgeHealth?['printer']?['details']
        ?.toString()
        .trim();
    final transportMode = (_bridgeHealth?['transport_mode']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final queueName = (_bridgeHealth?['printer_queue']?.toString() ?? '')
        .trim();
    final usbDevices =
        (_discoverResult?['usb'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    final cupsQueues =
        (_discoverResult?['cups'] as List?)
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
      return 'Bridge şu anda sadece CUPS kuyruğu "$queueName" ile çalışıyor ama bu kuyruk MacBook üzerinde geçerli değil. Yazıcı bağlıysa adım adım kurulumla USB/CUPS seçimini yeniden yapın.';
    }
    if (!_hasDetectedPrinters && usbDevices.isNotEmpty) {
      final firstUsb = usbDevices.first;
      final product = firstUsb['name']?.toString() ?? 'USB yazıcı';
      return '$product USB üzerinden bağlı görünüyor fakat bridge henüz kullanılabilir yazıcı listesi oluşturamadı. Adım adım kurulum USB ayarlarını tamamlamalı.';
    }
    if (!_hasDetectedPrinters && cupsQueues.isNotEmpty) {
      return 'macOS bazı yazıcı kuyrukları görüyor ama seçilebilir liste oluşmadı. Adım adım kurulumla doğru adisyon/mutfak yazıcısını eşleştirin.';
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

  Future<void> _savePrintCenter() async {
    final receiptPrinterId = _selectedReceiptPrinterId?.trim() ?? '';
    final kitchenPrinterId = _selectedKitchenPrinterId?.trim() ?? '';
    if (receiptPrinterId.isEmpty || kitchenPrinterId.isEmpty) {
      setState(() {
        _printCenterError = 'Önce adisyon ve mutfak yazıcılarını seçin.';
      });
      return;
    }

    setState(() {
      _savingPrintCenter = true;
      _printCenterError = null;
    });
    try {
      final result = await _printOrchestrator.savePrinterRoles(
        restaurantId: widget.restaurantId,
        receiptPrinterId: receiptPrinterId,
        kitchenPrinterId: kitchenPrinterId,
        session: Supabase.instance.client.auth.currentSession,
        markThisDeviceAsPrintStation: true,
      );
      if (!result.ok) {
        throw Exception(result.message);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPrintCenter = false;
        });
      }
    }
  }

  Future<void> _sendTestReceipt({required bool kitchen}) async {
    if (_guardPrintSystemDisabled(
      actionLabel: kitchen ? 'Mutfak testi' : 'Adisyon testi',
    )) {
      return;
    }
    final printerId = kitchen
        ? _selectedKitchenPrinterId?.trim() ?? ''
        : _selectedReceiptPrinterId?.trim() ?? '';
    if (printerId.isEmpty) {
      setState(() {
        _printCenterError = kitchen
            ? 'Önce mutfak yazıcısını seçin.'
            : 'Önce adisyon yazıcısını seçin.';
      });
      return;
    }

    setState(() {
      if (kitchen) {
        _testingKitchen = true;
      } else {
        _testingReceipt = true;
      }
      _printCenterError = null;
    });
    try {
      final result = await _printOrchestrator.printTestReceipt(
        restaurantId: widget.restaurantId,
        role: kitchen ? PrinterSetupRole.mutfak : PrinterSetupRole.adisyon,
        printerId: printerId,
      );
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
              await _loadPrintCenterState();
            },
          );
          setState(() {
            _printCenterError = result.message;
          });
          return;
        }
        throw Exception(result.message);
      }
      if (!mounted) return;
      final warning = _isWarningResult(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _successMessageForResult(
              result,
              successFallback: kitchen
                  ? 'Mutfak test fişi gönderildi.'
                  : 'Adisyon test fişi gönderildi.',
            ),
          ),
          backgroundColor: warning
              ? Colors.orange.shade700
              : const Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          if (kitchen) {
            _testingKitchen = false;
          } else {
            _testingReceipt = false;
          }
        });
      }
    }
  }

  Future<void> _sendGenericTest() async {
    if (_guardPrintSystemDisabled(actionLabel: 'Manuel test baskısı')) {
      return;
    }
    setState(() {
      _testingGeneric = true;
      _printCenterError = null;
      _workingTestPrinter = null; // Clear previous working printer
    });
    try {
      final result = await _printOrchestrator.printBridgeTest(
        restaurantId: widget.restaurantId,
      );
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
              await _loadPrintCenterState();
            },
          );
          setState(() {
            _printCenterError = result.message;
          });
          return;
        }
        throw Exception(result.message);
      }
      if (result.printer != null) {
        setState(() {
          _workingTestPrinter = result.printer!.toJson();
        });
      }
      if (!mounted) return;
      final warning = _isWarningResult(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _successMessageForResult(
              result,
              successFallback:
                  'Genel test başarılı! Çalışan yazıcı canonical olarak işaretlendi.',
            ),
          ),
          backgroundColor: warning
              ? Colors.orange.shade700
              : const Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _testingGeneric = false;
        });
      }
    }
  }

  Future<void> _useWorkingTestPrinter() async {
    if (_workingTestPrinter == null) return;

    setState(() {
      _savingPrintCenter = true;
      _printCenterError = null;
    });
    try {
      final printerName =
          _workingTestPrinter?['displayName']?.toString() ??
          _workingTestPrinter?['name']?.toString() ??
          'Yazıcı';
      final result = await _printOrchestrator.assignWorkingPrinterToRoles(
        restaurantId: widget.restaurantId,
        session: Supabase.instance.client.auth.currentSession,
        markThisDeviceAsPrintStation: true,
      );
      if (!result.ok) {
        throw Exception(result.message);
      }

      setState(() {
        _workingTestPrinter = null;
      });

      await _loadPrintCenterState();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$printerName" canonical yazıcı olarak kaydedildi ve roller atandı.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPrintCenter = false;
        });
      }
    }
  }

  Future<void> _cleanupBrokenPrinters() async {
    setState(() {
      _runningMaintenance = true;
      _printCenterError = null;
    });
    try {
      final result = await _printOrchestrator.cleanupUnusedPrinters(
        restaurantId: widget.restaurantId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningMaintenance = false;
        });
      }
    }
  }

  Future<void> _hardResetPrinters() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hard Reset Printers'),
          content: const Text(
            'Bu islem yerel ayarlari, rol eslestirmelerini ve kayitli yazici satirlarini temizler. Ardindan yeni bir tarama yapilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sifirla'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _runningHardReset = true;
      _printCenterError = null;
    });
    try {
      final result = await _printOrchestrator.hardResetPrinters(
        restaurantId: widget.restaurantId,
      );
      await _loadPrintCenterState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printCenterError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningHardReset = false;
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
      'isLive': printer.raw['source'] != 'saved_record',
      'isSavedOnly': printer.raw['source'] == 'saved_record',
      'backend': printer.backend.value,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'statusLevel': printer.canPrint
          ? 'ready'
          : (printer.isAvailable ? 'warning' : 'error'),
      'statusMessage': printer.statusMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.restaurantId.isEmpty) {
      return const Center(
        child: Text(
          'Restoran kimliği bulunamadı. Lütfen tekrar giriş yapın.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    final printerStream =
        widget.printerStreamBuilder?.call(widget.restaurantId) ??
        PrinterRepository().watchPrinters(widget.restaurantId);

    return StreamBuilder<List<PrinterModel>>(
      stream: printerStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Yazıcı listesi yüklenemedi:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
          );
        }

        final printers = _filterPrintersToCurrentScan(snapshot.data ?? []);

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final saved = await showPrinterWizard(
                context,
                restaurantId: widget.restaurantId,
              );
              if (saved != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '"${saved.name}" yazıcısı başarıyla kaydedildi.',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yazıcı Ekle'),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: printers.isEmpty ? 4 : printers.length + 3,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildPrintSystemControlCard();
              }
              if (index == 1) {
                return _DesktopPrintCenterCard(
                  loading: _loadingPrintCenter,
                  saving: _savingPrintCenter,
                  testingReceipt: _testingReceipt,
                  testingKitchen: _testingKitchen,
                  testingGeneric: _testingGeneric,
                  errorText: _printCenterError,
                  setupStatusLabel: _wizardStatusLabel(_setupStatusKey()),
                  setupStatusColor: _wizardStatusColor(_setupStatusKey()),
                  bridgeSummaryLabel: _bridgeSummaryLabel(),
                  bridgeSummaryMessage: _bridgeSummaryMessage(),
                  scanGuidance: _printerDiscoveryGuidance(),
                  canSelectPrinterRoles: _canSelectPrinterRoles,
                  bridgeReachable: _bridgeReachable,
                  bridgeHealthy: _bridgeHealthy,
                  hasDetectedPrinters: _hasDetectedPrinters,
                  workingTestPrinter: _workingTestPrinter,
                  setupChecks:
                      (_setupPrerequisites?['checks'] as List?)
                          ?.whereType<Map>()
                          .map((entry) => Map<String, dynamic>.from(entry))
                          .toList(growable: false) ??
                      const <Map<String, dynamic>>[],
                  onOpenGuidedSetup: _openGuidedSetup,
                  bridgePrinters: _bridgePrinters,
                  selectedReceiptPrinterId: _selectedReceiptPrinterId,
                  selectedKitchenPrinterId: _selectedKitchenPrinterId,
                  onRefreshPrinters: _loadPrintCenterState,
                  onReceiptPrinterChanged: (value) {
                    setState(() => _selectedReceiptPrinterId = value);
                  },
                  onKitchenPrinterChanged: (value) {
                    setState(() => _selectedKitchenPrinterId = value);
                  },
                  onSendReceiptTest: () => _sendTestReceipt(kitchen: false),
                  onSendKitchenTest: () => _sendTestReceipt(kitchen: true),
                  onSendGenericTest: _sendGenericTest,
                  onUseWorkingTestPrinter: _useWorkingTestPrinter,
                  onSavePrintCenter: _savePrintCenter,
                );
              }
              if (index == 2) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yazici bakimi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Liste canonical yazıcı kayıtlarını gösterir; canlı taramadakiler üstte, kayıtlı ama şu an görünmeyenler altta kalır.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _runningMaintenance
                                ? null
                                : _cleanupBrokenPrinters,
                            icon: _runningMaintenance
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cleaning_services_outlined),
                            label: const Text('Temizle'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _runningHardReset
                                ? null
                                : _hardResetPrinters,
                            icon: _runningHardReset
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.restart_alt_rounded),
                            label: const Text('Hard Reset Printers'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              if (printers.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.print_disabled_outlined,
                          size: 52,
                          color: Color(0xFFD1D5DB),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Henüz kayıtlı yazıcı yok.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Önce Yazıcıları Tara veya Yazıcı Ekle ile başlayın.',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final printer = printers[index - 3];
              return _PrinterCard(
                printer: printer,
                restaurantId: widget.restaurantId,
              );
            },
          ),
        );
      },
    );
  }

  String? _coerceSelectedPrinterId({
    required List<Map<String, dynamic>> printers,
    required String? currentSelectedId,
    required String? snapshotSelectedId,
  }) {
    if (_hasBridgePrinter(printers, currentSelectedId)) {
      return currentSelectedId?.trim();
    }
    if (_hasBridgePrinter(printers, snapshotSelectedId)) {
      return snapshotSelectedId?.trim();
    }
    return null;
  }

  bool _hasBridgePrinter(
    List<Map<String, dynamic>> printers,
    String? selectedId,
  ) {
    final id = selectedId?.trim() ?? '';
    if (id.isEmpty) return false;
    return printers.any((printer) {
      final bridgeId = printer['id']?.toString().trim() ?? '';
      final selectionId = printer['selectionId']?.toString().trim() ?? '';
      final recordId =
          printer['printerRecordId']?.toString().trim() ??
          printer['printer_record_id']?.toString().trim() ??
          '';
      return bridgeId == id || selectionId == id || recordId == id;
    });
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
    final printerName = printer.name.trim().toLowerCase();
    for (final bridgePrinter in _bridgePrinters) {
      final recordId =
          bridgePrinter['printerRecordId']?.toString().trim() ?? '';
      final bridgeDevice =
          (bridgePrinter['deviceIdentifier'] ?? bridgePrinter['queue'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      final bridgeName = (bridgePrinter['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
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
}

// ─────────────────────────────────────────────────────────────────────────────────
// Desktop Print Center Card
// ─────────────────────────────────────────────────────────────────────────────────

class _DesktopPrintCenterCard extends StatelessWidget {
  const _DesktopPrintCenterCard({
    required this.loading,
    required this.saving,
    required this.testingReceipt,
    required this.testingKitchen,
    required this.testingGeneric,
    required this.errorText,
    required this.setupStatusLabel,
    required this.setupStatusColor,
    required this.bridgeSummaryLabel,
    required this.bridgeSummaryMessage,
    required this.scanGuidance,
    required this.canSelectPrinterRoles,
    required this.bridgeReachable,
    required this.bridgeHealthy,
    required this.hasDetectedPrinters,
    required this.workingTestPrinter,
    required this.setupChecks,
    required this.onOpenGuidedSetup,
    required this.bridgePrinters,
    required this.selectedReceiptPrinterId,
    required this.selectedKitchenPrinterId,
    required this.onRefreshPrinters,
    required this.onReceiptPrinterChanged,
    required this.onKitchenPrinterChanged,
    required this.onSendReceiptTest,
    required this.onSendKitchenTest,
    required this.onSendGenericTest,
    required this.onUseWorkingTestPrinter,
    required this.onSavePrintCenter,
  });

  final bool loading;
  final bool saving;
  final bool testingReceipt;
  final bool testingKitchen;
  final bool testingGeneric;
  final String? errorText;
  final String setupStatusLabel;
  final Color setupStatusColor;
  final String bridgeSummaryLabel;
  final String bridgeSummaryMessage;
  final String? scanGuidance;
  final bool canSelectPrinterRoles;
  final bool bridgeReachable;
  final bool bridgeHealthy;
  final bool hasDetectedPrinters;
  final Map<String, dynamic>? workingTestPrinter;
  final List<Map<String, dynamic>> setupChecks;
  final Future<void> Function() onOpenGuidedSetup;
  final List<Map<String, dynamic>> bridgePrinters;
  final String? selectedReceiptPrinterId;
  final String? selectedKitchenPrinterId;
  final Future<void> Function() onRefreshPrinters;
  final ValueChanged<String?> onReceiptPrinterChanged;
  final ValueChanged<String?> onKitchenPrinterChanged;
  final Future<void> Function() onSendReceiptTest;
  final Future<void> Function() onSendKitchenTest;
  final Future<void> Function() onSendGenericTest;
  final Future<void> Function() onUseWorkingTestPrinter;
  final Future<void> Function() onSavePrintCenter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          const Row(
            children: [
              Icon(Icons.local_printshop_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seller Desktop Yazıcı Merkezi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu alanda kurulum sıralı ilerler: önce bridge ve sistem kontrol edilir, sonra yazıcı taranır, ardından adisyon ve mutfak rolleri seçilir.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineStatusChip(
                label: setupStatusLabel,
                color: setupStatusColor,
              ),
              _InlineStatusChip(
                label: bridgeSummaryLabel,
                color: bridgeHealthy
                    ? const Color(0xFF15803D)
                    : bridgeReachable
                    ? const Color(0xFFB45309)
                    : const Color(0xFFB91C1C),
              ),
              _InlineStatusChip(
                label: hasDetectedPrinters
                    ? '${bridgePrinters.length} yazıcı bulundu'
                    : 'Yazıcı bekleniyor',
                color: hasDetectedPrinters
                    ? const Color(0xFF15803D)
                    : const Color(0xFF6B7280),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GuidedStepTile(
            stepNumber: '1',
            title: 'Bridge ve sistem kontrolü',
            subtitle: bridgeSummaryMessage,
            done: bridgeHealthy,
          ),
          for (final check in setupChecks)
            _GuidedStepTile(
              stepNumber: '•',
              title: check['label']?.toString() ?? 'Kontrol',
              subtitle: check['message']?.toString() ?? '',
              done: check['ok'] == true,
              compact: true,
            ),
          _GuidedStepTile(
            stepNumber: '2',
            title: 'Yerel yazıcıları tara',
            subtitle:
                scanGuidance ??
                (hasDetectedPrinters
                    ? 'Tarama tamamlandı. Şimdi adisyon ve mutfak rollerini seçebilirsiniz.'
                    : 'Önce yazıcıları tara butonunu kullanın.'),
            done: hasDetectedPrinters,
          ),
          _GuidedStepTile(
            stepNumber: '3',
            title: 'Yazıcı rollerini seç',
            subtitle: canSelectPrinterRoles
                ? 'Adisyon ve mutfak yazıcısını seçip test fişi gönderebilirsiniz.'
                : 'Bu adım bridge sağlıklı ve yazıcı listesi dolu olduğunda açılır.',
            done:
                canSelectPrinterRoles &&
                _hasPrinter(bridgePrinters, selectedReceiptPrinterId) &&
                _hasPrinter(bridgePrinters, selectedKitchenPrinterId),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: loading ? null : onOpenGuidedSetup,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Adım adım kurulum'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : onRefreshPrinters,
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Yazıcıları Tara'),
              ),
              OutlinedButton.icon(
                onPressed: testingGeneric ? null : onSendGenericTest,
                icon: testingGeneric
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
                label: const Text('Test Gönder'),
              ),
            ],
          ),
          if (scanGuidance != null && scanGuidance!.trim().isNotEmpty) ...[
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
                scanGuidance!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF92400E),
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _hasPrinter(bridgePrinters, selectedReceiptPrinterId)
                ? selectedReceiptPrinterId
                : null,
            decoration: const InputDecoration(
              labelText: 'Adisyon Yazıcısı Seç',
              border: OutlineInputBorder(),
            ),
            items: bridgePrinters
                .map(
                  (printer) => DropdownMenuItem<String>(
                    value:
                        printer['selectionId']?.toString() ??
                        printer['id']?.toString() ??
                        '',
                    child: Text(
                      '${printer['name']?.toString() ?? 'Yazıcı'}'
                      '${printer['isSavedOnly'] == true ? ' (Kayıtlı)' : ''}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: canSelectPrinterRoles ? onReceiptPrinterChanged : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _hasPrinter(bridgePrinters, selectedKitchenPrinterId)
                ? selectedKitchenPrinterId
                : null,
            decoration: const InputDecoration(
              labelText: 'Mutfak Yazıcısı Seç',
              border: OutlineInputBorder(),
            ),
            items: bridgePrinters
                .map(
                  (printer) => DropdownMenuItem<String>(
                    value:
                        printer['selectionId']?.toString() ??
                        printer['id']?.toString() ??
                        '',
                    child: Text(
                      '${printer['name']?.toString() ?? 'Yazıcı'}'
                      '${printer['isSavedOnly'] == true ? ' (Kayıtlı)' : ''}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: canSelectPrinterRoles ? onKitchenPrinterChanged : null,
          ),
          if (workingTestPrinter != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF16A34A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF16A34A),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Çalışan yazıcı bulundu!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${workingTestPrinter!['name'] ?? 'USB Yazıcı'} (${workingTestPrinter!['backend'] ?? 'usb-direct'})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : onUseWorkingTestPrinter,
                      icon: saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Çalışan test yazıcısını kullan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: !canSelectPrinterRoles || testingReceipt
                    ? null
                    : onSendReceiptTest,
                icon: testingReceipt
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: const Text('Test Fişi Gönder'),
              ),
              OutlinedButton.icon(
                onPressed: !canSelectPrinterRoles || testingKitchen
                    ? null
                    : onSendKitchenTest,
                icon: testingKitchen
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restaurant_menu_outlined),
                label: const Text('Mutfak Testi Gönder'),
              ),
              FilledButton.icon(
                onPressed: !canSelectPrinterRoles || saving
                    ? null
                    : onSavePrintCenter,
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.hub_outlined),
                label: const Text('Bu cihazı Yazıcı Merkezi yap'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _hasPrinter(
    List<Map<String, dynamic>> printers,
    String? selectedId,
  ) {
    final id = selectedId?.trim() ?? '';
    if (id.isEmpty) return false;
    return printers.any((printer) {
      final bridgeId = printer['id']?.toString().trim() ?? '';
      final selectionId = printer['selectionId']?.toString().trim() ?? '';
      final recordId =
          printer['printerRecordId']?.toString().trim() ??
          printer['printer_record_id']?.toString().trim() ??
          '';
      return bridgeId == id || selectionId == id || recordId == id;
    });
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
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    color: const Color(0xFF4B5563),
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

// ─────────────────────────────────────────────────────────────────────────────────
// Printer Card
// ─────────────────────────────────────────────────────────────────────────────────

class _PrinterCard extends StatefulWidget {
  const _PrinterCard({required this.printer, required this.restaurantId});

  final PrinterModel printer;
  final String restaurantId;

  @override
  State<_PrinterCard> createState() => _PrinterCardState();
}

class _PrinterCardState extends State<_PrinterCard> {
  final DesktopPrintOrchestrator _printOrchestrator =
      DesktopPrintOrchestrator();
  bool _testing = false;
  bool _deleting = false;
  String? _testError;
  bool? _lastTestOk;

  // Build the correct connection label using formConnectionType so local
  // printers stored as 'network' with IP 127.0.0.1 are shown as 'Yerel'.
  String get _connectionLabel {
    final p = widget.printer;
    switch (p.formConnectionType) {
      case PrinterModel.localConnectionType:
        return 'Yerel';
      case PrinterModel.usbConnectionType:
        return 'USB';
      case PrinterModel.bluetoothConnectionType:
        return 'BT';
      case PrinterModel.networkConnectionType:
      default:
        return 'TCP/IP';
    }
  }

  Color get _statusDotColor {
    final s = widget.printer.testPrintStatus;
    if (s == 'ok' && widget.printer.isActive) return const Color(0xFF10B981);
    if (s == 'failed') return const Color(0xFFEF4444);
    return const Color(0xFF9CA3AF);
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }

  String get _connectionSubtitle {
    final p = widget.printer;
    if (p.isLocalConnection) {
      final dev = p.deviceIdentifier?.trim() ?? '';
      return dev.isNotEmpty
          ? dev
          : '127.0.0.1:${PrinterModel.localDefaultPort}';
    }
    if (p.formConnectionType == PrinterModel.networkConnectionType) {
      return '${p.ipAddress ?? '–'}:${p.port ?? 9100}';
    }
    if (p.deviceIdentifier != null && p.deviceIdentifier!.isNotEmpty) {
      return p.deviceIdentifier!;
    }
    return p.targetHost;
  }

  Future<void> _handleTest() async {
    setState(() {
      _testing = true;
      _testError = null;
      _lastTestOk = null;
    });
    final p = widget.printer;
    try {
      final result = await _printOrchestrator.printTestReceipt(
        restaurantId: widget.restaurantId,
        printerId: p.id,
      );
      if (!result.ok) {
        throw Exception(result.message);
      }
      if (mounted) {
        setState(() {
          _lastTestOk = true;
          _testing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${p.name}" test fişi gönderildi.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastTestOk = false;
          _testError = e.toString().replaceFirst('Exception: ', '');
          _testing = false;
        });
      }
    }
  }

  Future<void> _handleEdit() async {
    final saved = await showPrinterWizard(
      context,
      restaurantId: widget.restaurantId,
      existing: widget.printer,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${saved.name}" güncellendi.'),
          backgroundColor: const Color(0xFF8B5CF6),
        ),
      );
    }
  }

  Future<void> _handleActiveToggle(bool value) async {
    try {
      await PrinterRepository().setPrinterActive(widget.printer.id, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Güncelleme hatası: $e')));
      }
    }
  }

  Future<void> _handleDelete({bool force = false}) async {
    if (!force) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Yazıcıyı sil'),
            content: Text(
              '"${widget.printer.name}" kaydını kaldırmak istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
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
      _deleting = true;
      _testError = null;
    });
    try {
      final result = await _printOrchestrator.deletePrinter(
        restaurantId: widget.restaurantId,
        printerId: widget.printer.id,
        force: force,
      );
      if (!result.ok && result.status == 'printer_in_use' && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Yazıcı kullanımda'),
              content: Text(result.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yine de sil'),
                ),
              ],
            );
          },
        );
        if (confirmed == true && mounted) {
          setState(() => _deleting = false);
          await _handleDelete(force: true);
        }
        return;
      }
      if (!result.ok) {
        throw Exception(result.message);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _testError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.printer;
    final hasError =
        (p.lastError != null && p.lastError!.isNotEmpty) || _testError != null;
    final errorText = _testError ?? p.lastError;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError && _lastTestOk != true
              ? const Color(0xFFFECACA)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: p.isActive,
                    onChanged: _handleActiveToggle,
                    activeTrackColor: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
          // ── Info pills ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Pill(
                  _connectionLabel,
                  bg: const Color(0xFFF3F0FF),
                  fg: const Color(0xFF8B5CF6),
                ),
                _Pill(
                  '${p.paperWidthMm}mm',
                  bg: const Color(0xFFF0F9FF),
                  fg: const Color(0xFF0EA5E9),
                ),
                if (p.supportsCut)
                  _Pill(
                    'Kesici',
                    bg: const Color(0xFFF0FDF4),
                    fg: const Color(0xFF10B981),
                  ),
                // Profile pill: show resolved profile label for quick identification.
                Builder(
                  builder: (ctx) {
                    final profile = p.resolvedProfile;
                    return _Pill(
                      profile.label,
                      bg: const Color(0xFFFFFBEB),
                      fg: const Color(0xFFF59E0B),
                    );
                  },
                ),
                ...p.assignedRoles.map((r) => _RolePill(r)),
              ],
            ),
          ),
          // ── Connection detail ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              _connectionSubtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontFamily: 'monospace',
              ),
            ),
          ),
          // ── Test status ───────────────────────────────────────────────
          if (p.testPrintStatus != null || p.lastTestPrintAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                children: [
                  _TestStatusBadge(p.testPrintStatus),
                  const SizedBox(width: 6),
                  if (p.lastTestPrintAt != null)
                    Text(
                      _timeAgo(p.lastTestPrintAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
          // ── Error panel ───────────────────────────────────────────────
          if (errorText != null && errorText.isNotEmpty && _lastTestOk != true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFDC2626),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _handleTest,
                  icon: _testing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_outlined, size: 14),
                  label: const Text('Test', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFFDDD6FF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : _handleDelete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Sil', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _handleEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Düzenle', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

// ─────────────────────────────────────────────────────────────────────────────────
// Badge helpers
// ─────────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill(this.role);

  final PrinterRole role;

  static const _colors = <PrinterRole, Color>{
    PrinterRole.receipt: Color(0xFF8B5CF6),
    PrinterRole.kitchen: Color(0xFFEF4444),
    PrinterRole.bakery: Color(0xFFF59E0B),
    PrinterRole.bar: Color(0xFF06B6D4),
    PrinterRole.general: Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[role] ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _TestStatusBadge extends StatelessWidget {
  const _TestStatusBadge(this.status);

  final String? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    final (label, bg, fg) = switch (status) {
      'ok' => ('Test OK', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'failed' => (
        'Test Başarısız',
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
      _ => ('Bekliyor', const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Tab 1 — Dinleyici (wrapper around existing widgets)
// ─────────────────────────────────────────────────────────────────────────────────

class _ListenerTabView extends StatefulWidget {
  const _ListenerTabView({required this.hub});

  final DesktopPrintHub hub;

  @override
  State<_ListenerTabView> createState() => _ListenerTabViewState();
}

class _ListenerTabViewState extends State<_ListenerTabView> {
  final PrintStationService _printStationService = PrintStationService();
  bool _loadingPausedJobs = false;
  List<Map<String, dynamic>> _pausedPrintJobs = const <Map<String, dynamic>>[];
  String? _pausedJobsError;
  String? _resumingJobId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPausedJobs());
  }

  Future<void> _loadPausedJobs() async {
    if (!mounted) return;
    setState(() {
      _loadingPausedJobs = true;
      _pausedJobsError = null;
    });

    try {
      final jobs = await _printStationService.fetchPausedPrintJobs(
        widget.hub.restaurantId ?? '',
      );
      if (!mounted) return;
      setState(() {
        _pausedPrintJobs = jobs;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pausedJobsError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPausedJobs = false;
        });
      }
    }
  }

  Future<void> _resumePausedJob(String jobId) async {
    if (!mounted) return;
    setState(() {
      _resumingJobId = jobId;
      _pausedJobsError = null;
    });

    try {
      final success = await _printStationService.resumePausedPrintJob(
        restaurantId: widget.hub.restaurantId ?? '',
        jobId: jobId,
      );
      if (!success) {
        throw Exception('Bekleyen baskı yeniden etkinleştirilemedi.');
      }
      if (!mounted) return;
      await _loadPausedJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bekleyen baskı yeniden etkinleştirildi.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pausedJobsError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _resumingJobId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BridgeStatusCard(hub: widget.hub),
        const SizedBox(height: 12),
        _ListenerStatusCard(hub: widget.hub),
        const SizedBox(height: 12),
        _QuickActionsRow(hub: widget.hub),
        if (widget.hub.failedJobs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FailedJobsCard(hub: widget.hub),
        ],
        if (widget.hub.launchAgentCheckDone && !widget.hub.launchAgentInstalled) ...[
          const SizedBox(height: 12),
          _LaunchAgentCard(),
        ],
        if (widget.hub.lastJobDescription != null) ...[
          const SizedBox(height: 12),
          _LastJobCard(hub: widget.hub),
        ],
        const SizedBox(height: 12),
        _PausedPrintJobsCard(
          loading: _loadingPausedJobs,
          pausedJobs: _pausedPrintJobs,
          errorText: _pausedJobsError,
          resumingJobId: _resumingJobId,
          onRefresh: _loadPausedJobs,
          onResumeJob: _resumePausedJob,
        ),
        const SizedBox(height: 12),
        _SetupInfoCard(),
      ],
    );
  }
}

class _PausedPrintJobsCard extends StatelessWidget {
  const _PausedPrintJobsCard({
    required this.loading,
    required this.pausedJobs,
    required this.errorText,
    required this.resumingJobId,
    required this.onRefresh,
    required this.onResumeJob,
  });

  final bool loading;
  final List<Map<String, dynamic>> pausedJobs;
  final String? errorText;
  final String? resumingJobId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String jobId) onResumeJob;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bekleyen Baskılar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!loading)
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Yenile'),
                ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sistem kapalıyken oluşturulan ve fiziksel baskıya gönderilmeyen işleri burada görebilir, yeniden etkinleştirebilirsiniz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.45),
          ),
          const SizedBox(height: 12),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ),
          if (!loading && pausedJobs.isEmpty)
            const Text(
              'Bekleyen baskı yok.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          for (final job in pausedJobs)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['document_type']?.toString() ?? 'Fiş',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${job['id'] ?? '-'} • Rol: ${job['printer_role'] ?? '-'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job['created_at']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: resumingJobId == job['id']?.toString()
                        ? null
                        : () => onResumeJob(job['id']?.toString() ?? ''),
                    child: resumingJobId == job['id']?.toString()
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Yeniden Etkinleştir'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Tab 2 — Kılavuz
// ─────────────────────────────────────────────────────────────────────────────────

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _GuideSection(
          icon: Icons.rocket_launch_outlined,
          title: 'Hızlı Kurulum',
          color: Color(0xFF8B5CF6),
          steps: [
            'Seller Desktop App ile giriş yapın.',
            'Yazıcıları Tara butonuna basın.',
            'Adisyon ve mutfak yazıcılarını seçin.',
            'Test fişlerini göndererek bağlantıyı doğrulayın.',
            'Bu cihazı Yazıcı Merkezi yap butonuyla kaydedin.',
          ],
        ),
        SizedBox(height: 12),
        _GuideSection(
          icon: Icons.print_outlined,
          title: 'Desteklenen Yazıcılar',
          color: Color(0xFF0EA5E9),
          steps: [
            'ESC/POS uyumlu termal yazıcılar (58mm, 72mm, 80mm).',
            'CUPS kuyruğuna eklenmiş USB yazıcılar.',
            'TCP/IP üzerinden erişilebilen ağ yazıcıları (port 9100).',
            'Test edilenler: Epson TM-T20, TM-T88, Star TSP143.',
          ],
        ),
        SizedBox(height: 12),
        _GuideSection(
          icon: Icons.build_circle_outlined,
          title: 'Sorun Giderme',
          color: Color(0xFFEF4444),
          steps: [
            'Yazıcı servisi kapalıysa "Yazıcı Servisini Başlat" butonunu kullanın.',
            'Test başarısızsa yazıcının işletim sisteminde kurulu ve hazır olduğunu doğrulayın.',
            'Windows için yazıcı adını yeniden tara; macOS için CUPS kuyruğunu kontrol edin.',
            'Print Station offline ise işler kuyrukta bekler ve cihaz geri dönünce otomatik basılır.',
            'Yazıcıda kağıt, bağlantı ve sürücü durumunu kontrol edin.',
          ],
        ),
        SizedBox(height: 12),
        _GuideSection(
          icon: Icons.settings_suggest_outlined,
          title: 'Otomatik Başlatma',
          color: Color(0xFFF59E0B),
          steps: [
            'Seller Desktop App açıldığında yazdırma servisini otomatik başlatmayı dener.',
            'macOS tarafında LaunchAgent, Windows tarafında başlangıç entegrasyonu kullanılabilir.',
            'Paketleme ve release notları için docs/SELLER_DESKTOP_SETUP.md belgesini izleyin.',
            'Amaç kullanıcıya terminal veya manuel Python ihtiyacı bırakmamaktır.',
          ],
        ),
        SizedBox(height: 12),
        _GuideSection(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Öneriler',
          color: Color(0xFF10B981),
          steps: [
            'Her yazıcı için anlamlı bir ad verin (örn: "Mutfak 1").',
            'Roller bilgi amaçlıdır; asıl yönlendirme İstasyon ekranında yapılır.',
            'Yeni yazıcı ekledikten sonra test adımını atlamamayın.',
            'Aktif olmayan yazıcılar sipariş almaz; gerekirse pasife alın.',
          ],
        ),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 1, right: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bridge Status Card
// ─────────────────────────────────────────────────────────────────────────────

class _BridgeStatusCard extends StatelessWidget {
  const _BridgeStatusCard({required this.hub});

  final DesktopPrintHub hub;

  @override
  Widget build(BuildContext context) {
    final (bg, border, dot, title, subtitle) = switch (hub.bridgeStatus) {
      BridgeStatus.online => (
        const Color(0xFFF0FDF4),
        const Color(0xFFBBF7D0),
        const Color(0xFF10B981),
        'Yazıcı Köprüsü Aktif',
        'Yerel yazıcı servisi 127.0.0.1:3001 adresinde çalışıyor.',
      ),
      BridgeStatus.offline => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        const Color(0xFFEF4444),
        'Yazıcı Köprüsü Kapalı',
        'Yerel yazdırma servisi ulaşılamıyor. "Yazıcı Servisini Başlat" butonuna basın.',
      ),
      BridgeStatus.error => (
        const Color(0xFFFFF7ED),
        const Color(0xFFFED7AA),
        const Color(0xFFF97316),
        'Yazıcı Köprüsü Hata',
        'Servise ulaşıldı ancak beklenmedik bir yanıt alındı.',
      ),
      BridgeStatus.checking => (
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        const Color(0xFFF59E0B),
        'Bağlantı Kontrol Ediliyor…',
        '127.0.0.1:3001 — yanıt bekleniyor.',
      ),
      BridgeStatus.unknown => (
        const Color(0xFFF9FAFB),
        const Color(0xFFE5E7EB),
        const Color(0xFF9CA3AF),
        'Durum Bilinmiyor',
        'Köprü durumu henüz kontrol edilmedi.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hub.bridgeStatus == BridgeStatus.checking)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dot,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
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

// ─────────────────────────────────────────────────────────────────────────────
// Listener Status Card
// ─────────────────────────────────────────────────────────────────────────────

class _ListenerStatusCard extends StatelessWidget {
  const _ListenerStatusCard({required this.hub});

  final DesktopPrintHub hub;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    return '${diff.inHours}sa önce';
  }

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Icon(Icons.sensors, size: 17, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text(
                'Sipariş Dinleyici',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                label: 'Durum',
                value: switch (hub.listenerStatus) {
                  ListenerStatus.active => 'Aktif',
                  ListenerStatus.stopped => 'Bekleniyor…',
                  ListenerStatus.error => 'Hata',
                },
                color: switch (hub.listenerStatus) {
                  ListenerStatus.active => const Color(0xFF10B981),
                  ListenerStatus.stopped => const Color(0xFFF59E0B),
                  ListenerStatus.error => const Color(0xFFEF4444),
                },
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Yazdırıldı',
                value: '${hub.dispatchedCount}',
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Hata',
                value: '${hub.failedCount}',
                color: hub.failedCount > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
          if (hub.lastJobTime != null) ...[
            const SizedBox(height: 10),
            Text(
              'Son işlem: ${_timeAgo(hub.lastJobTime!)}'
              '${hub.lastJobDescription != null ? '  •  ${hub.lastJobDescription}' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
          if (hub.lastJobError != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Hata: ${hub.lastJobError}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFDC2626),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions Row
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatefulWidget {
  const _QuickActionsRow({required this.hub});

  final DesktopPrintHub hub;

  @override
  State<_QuickActionsRow> createState() => _QuickActionsRowState();
}

class _QuickActionsRowState extends State<_QuickActionsRow> {
  bool _startingBridge = false;
  bool _testingPrint = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.hub.checkBridge,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Yenile'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _startingBridge ? null : _handleStartBridge,
            icon: _startingBridge
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline_rounded, size: 16),
            label: const Text('Yazıcı Servisini Başlat'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _testingPrint ? null : _handleTestPrint,
            icon: _testingPrint
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.receipt_long_outlined, size: 16),
            label: const Text('Test Yazdır'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleStartBridge() async {
    if (!mounted) return;
    setState(() => _startingBridge = true);
    try {
      final ok = await widget.hub.tryStartBridge();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Yazıcı servisi otomatik başlatılamadı. Desktop kurulum notlarını kontrol edin.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingBridge = false);
    }
  }

  Future<void> _handleTestPrint() async {
    if (!mounted) return;
    setState(() => _testingPrint = true);
    try {
      await widget.hub.testPrint();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test fişi yazıcıya gönderildi.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test yazdırma hatası: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _testingPrint = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Last Job Card
// ─────────────────────────────────────────────────────────────────────────────

class _LastJobCard extends StatelessWidget {
  const _LastJobCard({required this.hub});

  final DesktopPrintHub hub;

  @override
  Widget build(BuildContext context) {
    final hasError = hub.lastJobError != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: hasError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasError
                  ? 'Son hata: ${hub.lastJobError}'
                  : 'Son iş: ${hub.lastJobDescription}',
              style: TextStyle(
                fontSize: 12,
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Failed Jobs Card
// ─────────────────────────────────────────────────────────────────────────────

class _FailedJobsCard extends StatelessWidget {
  const _FailedJobsCard({required this.hub});

  final DesktopPrintHub hub;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    return '${diff.inHours}sa önce';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 17,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Text(
                  'Başarısız İşler (${hub.failedJobs.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: hub.clearFailedJobs,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Temizle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFEE2E2)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hub.failedJobs.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Color(0xFFF9FAFB)),
            itemBuilder: (context, index) {
              final job = hub.failedJobs[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.description,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            job.error,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDC2626),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _timeAgo(job.failedAt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RetryButton(hub: hub, jobId: job.jobId),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.hub, required this.jobId});

  final DesktopPrintHub hub;
  final String jobId;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _retrying ? null : _handleRetry,
      icon: _retrying
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.replay_rounded, size: 14),
      label: const Text('Tekrar', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8B5CF6),
        side: const BorderSide(color: Color(0xFFDDD6FF)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _handleRetry() async {
    if (!mounted) return;
    setState(() => _retrying = true);
    try {
      await widget.hub.retryJob(widget.jobId);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LaunchAgent Card
// ─────────────────────────────────────────────────────────────────────────────

/// Shown when the LaunchAgent plist is not installed.
/// Guides the user to set up auto-startup without opening a terminal.
class _LaunchAgentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.settings_suggest_outlined,
                size: 15,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 6),
              Text(
                'Otomatik Başlatma Kurulmadı',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SelectableText(
            'Yazdırma servisi bu masaüstü uygulamasıyla birlikte otomatik başlamalıdır.\n'
            'macOS ve Windows release notları için docs/SELLER_DESKTOP_SETUP.md belgesini takip edin.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF92400E),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _SetupInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEDE9F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: Color(0xFF8B5CF6),
              ),
              SizedBox(width: 6),
              Text(
                'Seller Desktop Yazdırma Servisi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C1D95),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SelectableText(
            '1. Seller Desktop App yazdırma servisini uygulama içinde yönetir.\n'
            '2. Yazıcıları Tara ile yerel yazıcı listesini yenileyin.\n'
            '3. Adisyon ve mutfak rollerini bu ekrandan seçin.\n'
            '4. Bu cihazı Yazıcı Merkezi yaptığınızda diğer cihazlar sadece iş gönderir.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.6,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
