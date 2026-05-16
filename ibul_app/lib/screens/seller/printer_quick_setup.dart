import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/printer_model.dart';
import '../../services/bridge_manager.dart';
import '../../services/printer_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Zero-step printer setup — one tap to discover, confirm, and save.
///
/// Returns the saved [PrinterModel] on success, null if the user cancelled.
Future<PrinterModel?> showPrinterQuickSetup(
  BuildContext context, {
  required String restaurantId,
}) {
  return Navigator.of(context).push<PrinterModel>(
    MaterialPageRoute<PrinterModel>(
      fullscreenDialog: true,
      builder: (_) => _PrinterQuickSetupScreen(restaurantId: restaurantId),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal state machine
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase {
  idle,
  startingBridge,
  searching,
  found,
  notFound,
  saving,
  error,
}

class _PrinterQuickSetupScreen extends StatefulWidget {
  const _PrinterQuickSetupScreen({required this.restaurantId});
  final String restaurantId;

  @override
  State<_PrinterQuickSetupScreen> createState() =>
      _PrinterQuickSetupScreenState();
}

class _PrinterQuickSetupScreenState
    extends State<_PrinterQuickSetupScreen> {
  _Phase _phase = _Phase.idle;
  BridgeSetupResult? _discovered;
  String? _errorMessage;

  // Manual network fallback
  bool _showManual = false;
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');

  final _repo = PrinterRepository();

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  // ── Auto-setup flow ──────────────────────────────────────────────────────

  Future<void> _startAutoSetup() async {
    setState(() {
      _phase = _Phase.startingBridge;
      _errorMessage = null;
      _showManual = false;
    });

    // 1. Ensure the bridge process is running.
    if (!kIsWeb) {
      final alive = await BridgeManager.ensureRunning();
      if (!mounted) return;
      if (!alive) {
        setState(() {
          _phase = _Phase.error;
          _errorMessage =
              'Yazıcı servisi başlatılamadı. Uygulamayı kapatıp yeniden açın.';
        });
        return;
      }
    }

    // 2. Ask the bridge to discover + auto-configure.
    setState(() => _phase = _Phase.searching);
    final result = await BridgeManager.autoSetup();
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _phase = _Phase.found;
        _discovered = result;
      });
    } else if (result.noPrinterFound) {
      setState(() => _phase = _Phase.notFound);
    } else {
      setState(() {
        _phase = _Phase.error;
        _errorMessage = result.errorMessage;
      });
    }
  }

  // ── Save auto-detected printer ───────────────────────────────────────────

  Future<void> _saveAutoDetected() async {
    final r = _discovered;
    if (r == null) return;
    setState(() => _phase = _Phase.saving);

    try {
      // Derive a friendly name and short code from what the bridge reported.
      final name = (r.printerName?.isNotEmpty ?? false) &&
              r.printerName != 'Yazıcı'
          ? r.printerName!
          : 'Fiş Yazıcısı';
      final code =
          r.transportType == 'network' ? 'net-receipt' : 'local-receipt';
      final paperWidth = r.paperWidthMm ?? 80;

      final saved = await _repo.upsertPrinter(
        restaurantId: widget.restaurantId,
        name: name,
        code: code,
        // DB constraint: ('network','usb','bluetooth'). Local bridge printers are stored as USB.
        connectionType: PrinterModel.usbConnectionType,
        ipAddress: PrinterModel.localDefaultHost,
        port: PrinterModel.localDefaultPort,
        deviceIdentifier: PrinterModel.localReceiptRoute,
        paperWidthMm: paperWidth,
        isActive: true,
        supportsCut: paperWidth >= 80,
        assignedRoles: [PrinterRole.receipt],
      );

      // Install the macOS LaunchAgent so the bridge survives reboots.
      if (!kIsWeb && !BridgeManager.isLaunchAgentInstalled()) {
        final laResult = await BridgeManager.installLaunchAgent();
        if (!laResult.success) {
          debugPrintSetup(
              'LaunchAgent install failed: ${laResult.error}');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Kaydedilemedi: $e';
      });
    }
  }

  // ── Save network printer ─────────────────────────────────────────────────

  Future<void> _saveNetwork() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    setState(() => _phase = _Phase.saving);

    try {
      final saved = await _repo.upsertPrinter(
        restaurantId: widget.restaurantId,
        name: 'Ağ Yazıcısı',
        code: 'net-receipt',
        connectionType: PrinterModel.networkConnectionType,
        ipAddress: ip,
        port: port,
        paperWidthMm: 80,
        isActive: true,
        supportsCut: true,
        assignedRoles: [PrinterRole.receipt],
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Kaydedilemedi: $e';
      });
    }
  }

  static void debugPrintSetup(String msg) =>
      // ignore: avoid_print
      print('[PrinterQuickSetup] $msg');

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: _phase == _Phase.saving
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: const Text(
          'Yazıcı Kur',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.idle:
        return _IdleView(
          showManual: _showManual,
          ipCtrl: _ipCtrl,
          portCtrl: _portCtrl,
          onAutoSetup: _startAutoSetup,
          onToggleManual: () => setState(() => _showManual = !_showManual),
          onSaveNetwork: _saveNetwork,
        );
      case _Phase.startingBridge:
        return const _SpinnerView(message: 'Yazıcı servisi başlatılıyor…');
      case _Phase.searching:
        return const _SpinnerView(message: 'Yazıcı aranıyor…');
      case _Phase.found:
        return _FoundView(
          result: _discovered!,
          onConfirm: _saveAutoDetected,
          onRetry: _startAutoSetup,
        );
      case _Phase.notFound:
        return _NotFoundView(
          onRetry: _startAutoSetup,
          onManual: () => setState(() {
            _phase = _Phase.idle;
            _showManual = true;
          }),
        );
      case _Phase.saving:
        return const _SpinnerView(message: 'Kaydediliyor…');
      case _Phase.error:
        return _ErrorView(
          message: _errorMessage ?? 'Bilinmeyen hata.',
          onRetry: _startAutoSetup,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-views
// ─────────────────────────────────────────────────────────────────────────────

class _SpinnerView extends StatelessWidget {
  const _SpinnerView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF6B7280), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.showManual,
    required this.ipCtrl,
    required this.portCtrl,
    required this.onAutoSetup,
    required this.onToggleManual,
    required this.onSaveNetwork,
  });

  final bool showManual;
  final TextEditingController ipCtrl;
  final TextEditingController portCtrl;
  final VoidCallback onAutoSetup;
  final VoidCallback onToggleManual;
  final VoidCallback onSaveNetwork;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.print_outlined,
          size: 72,
          color: Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 24),
        const Text(
          'Yazıcıyı USB kablosuyla\nbağlayın ve butona basın',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, height: 1.4),
        ),
        const SizedBox(height: 10),
        const Text(
          'Sistem yazıcıyı otomatik bulur ve ayarlar.\nHiçbir teknik bilgi gerekmez.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
        ),
        const SizedBox(height: 36),
        FilledButton.icon(
          onPressed: onAutoSetup,
          icon: const Icon(Icons.search, size: 20),
          label: const Text(
            'Yazıcıyı Otomatik Bul',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: onToggleManual,
            child: Text(
              showManual ? 'Manuel girişi gizle' : 'Ağ yazıcısı (IP ile bağlan)',
              style: const TextStyle(color: Color(0xFF7C3AED)),
            ),
          ),
        ),
        if (showManual) ...[
          const SizedBox(height: 16),
          const Text(
            'Yazıcı IP Adresi',
            style:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    hintText: '192.168.1.100',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                    hintText: '9100',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onSaveNetwork,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ağ Yazıcısını Ekle'),
          ),
        ],
      ],
    );
  }
}

// ── Found ─────────────────────────────────────────────────────────────────────

class _FoundView extends StatelessWidget {
  const _FoundView({
    required this.result,
    required this.onConfirm,
    required this.onRetry,
  });

  final BridgeSetupResult result;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isUsb = (result.transportType ?? 'usb') == 'usb';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 72,
          color: Color(0xFF059669),
        ),
        const SizedBox(height: 16),
        const Text(
          'Yazıcı Bulundu!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF059669),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Icon(
                isUsb ? Icons.usb : Icons.wifi,
                size: 40,
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.printerName ?? 'Yazıcı',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isUsb ? 'USB' : 'CUPS'}  ·  '
                      '${result.paperWidthMm ?? 80}mm kağıt',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Bu Yazıcıyı Kullan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onRetry,
          child: const Text(
            'Tekrar Ara',
            style: TextStyle(color: Color(0xFF7C3AED)),
          ),
        ),
      ],
    );
  }
}

// ── Not found ─────────────────────────────────────────────────────────────────

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.onRetry, required this.onManual});
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.print_disabled_outlined,
          size: 72,
          color: Color(0xFFEF4444),
        ),
        const SizedBox(height: 20),
        const Text(
          'Yazıcı Bulunamadı',
          style:
              TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Yazıcının açık ve USB ile bağlı olduğundan emin olun,\nardından tekrar deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF6B7280), height: 1.6, fontSize: 14),
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar Dene'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onManual,
          child: const Text(
            'Ağ yazıcısı (IP ile bağlan)',
            style: TextStyle(color: Color(0xFF7C3AED)),
          ),
        ),
      ],
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.error_outline,
          size: 72,
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(height: 20),
        const Text(
          'Bir sorun oluştu',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF6B7280), height: 1.5, fontSize: 13),
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar Dene'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
