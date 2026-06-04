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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/desktop_printer_setup_models.dart';
import '../../models/printer_model.dart';
import '../../models/printer_profile.dart';
import '../../services/desktop_print_orchestrator.dart';
import '../../services/local_print_service.dart';
import '../../services/printer_repository.dart';

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
  });

  final String restaurantId;
  final PrinterModel? existing;
  final PrinterRepository? repository;
  final DesktopPrintOrchestrator? orchestrator;

  @override
  State<AddEthernetPrinterScreen> createState() =>
      _AddEthernetPrinterScreenState();
}

class _AddEthernetPrinterScreenState extends State<AddEthernetPrinterScreen> {
  late final DesktopPrintOrchestrator _orchestrator =
      widget.orchestrator ?? DesktopPrintOrchestrator();
  final LocalPrintService _localPrintService = LocalPrintService();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ipCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController(
    text: PrinterModel.ethernetDefaultPort.toString(),
  );

  int _paperWidth = PrinterModel.defaultPaperWidthMm;
  bool _autoCut = true;
  EthernetPrinterRole _role = EthernetPrinterRole.adisyon;

  bool _connectionTesting = false;
  String? _connectionMessage;
  bool _connectionOk = false;

  bool _printTesting = false;
  String? _printMessage;
  bool _printOk = false;

  bool _saving = false;
  String? _formError;
  String? _ipError;
  String? _portError;

  PrinterProfile get _selectedPrinterProfile =>
      _paperWidth <= 58 ? PrinterProfile.pos58 : PrinterProfile.pos80;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _ipCtrl.text = existing.ethernetHost;
      _portCtrl.text = existing.ethernetPort.toString();
      _paperWidth = existing.paperWidthMm == 58 ? 58 : 80;
      _autoCut = existing.supportsCut;
      if (existing.assignedRoles.contains(PrinterRole.receipt) &&
          existing.assignedRoles.contains(PrinterRole.kitchen)) {
        _role = EthernetPrinterRole.both;
      } else if (existing.assignedRoles.contains(PrinterRole.kitchen)) {
        _role = EthernetPrinterRole.mutfak;
      } else {
        _role = EthernetPrinterRole.adisyon;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
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
        'paper_width_mm': _paperWidth,
        'paperWidthMm': _paperWidth,
        'chars_per_line': _selectedPrinterProfile.charsPerLine,
        'raster_width_px': _selectedPrinterProfile.rasterWidthPx,
        'auto_cut': _autoCut,
        'autoCut': _autoCut,
        'printer_profile': _selectedPrinterProfile.id,
        'printer_profile_id': _selectedPrinterProfile.id,
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
      'paper_width_mm': _paperWidth,
      'chars_per_line': _selectedPrinterProfile.charsPerLine,
      'raster_width_px': _selectedPrinterProfile.rasterWidthPx,
      'auto_cut': _autoCut,
      'printer_profile': _selectedPrinterProfile.id,
      'printer_profile_id': _selectedPrinterProfile.id,
      'render_mode': 'image',
      'turkish_guarantee_mode': true,
      'document_type': 'test',
      'printer_role': switch (_role) {
        EthernetPrinterRole.mutfak => 'mutfak',
        _ => 'adisyon',
      },
      'source': 'ethernet_dialog_form',
    };
  }

  void _applyValidation(_EthernetFormValidation form) {
    setState(() {
      _ipError = form.ipError;
      _portError = form.portError;
      _formError = null;
    });
  }

  // ── test actions ───────────────────────────────────────────────────────

  Future<void> _runConnectionTest() async {
    final form = _validateForm();
    if (!form.isValid) {
      _applyValidation(form);
      setState(() {
        _connectionOk = false;
        _connectionMessage = null;
      });
      return;
    }
    final payload = _buildEthernetDispatchPayload(form);
    setState(() {
      _connectionTesting = true;
      _connectionMessage = null;
      _connectionOk = false;
      _formError = null;
      _ipError = null;
      _portError = null;
    });
    if (kIsWeb) {
      setState(() {
        _connectionTesting = false;
        _connectionMessage =
            'Web sürümü yerel ağa erişemez. Masaüstü uygulamasından test edin.';
      });
      return;
    }
    final host = form.host;
    final port = form.port;
    debugPrint(
      '[EthernetPrinter][connection_test_start] host=$host port=$port',
    );
    try {
      final result = await _localPrintService
          .probeTcpPrinter(host: host, port: port, printer: payload)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final ok = result?['ok'] == true;
      final suggestedMessage =
          result?['suggested_message']?.toString().trim() ?? '';
      setState(() {
        _connectionOk = ok;
        _connectionMessage = ok
            ? (suggestedMessage.isNotEmpty
                  ? suggestedMessage
                  : 'Ethernet yazıcıya bağlantı başarılı.')
            : (suggestedMessage.isNotEmpty
                  ? suggestedMessage
                  : 'Bağlantı başarısız: ${result?['error'] ?? 'Bilinmeyen hata'}');
      });
      debugPrint(
        ok
            ? '[EthernetPrinter][connection_test_success] host=$host port=$port'
            : '[EthernetPrinter][connection_test_error] '
                  'code=${result?['errorCode'] ?? 'unknown'}',
      );
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString();
      final friendlyMessage =
          rawMessage.contains('Not found') || rawMessage.contains('404')
          ? 'Baglanti dogrulanamadi. Bridge bu surumde TCP probe endpointini desteklemiyor olabilir. Test fisi hattini kullanarak tekrar deneyin.'
          : 'Baglanti basarisiz: $e';
      setState(() {
        _connectionOk = false;
        _connectionMessage = friendlyMessage;
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
    final form = _validateForm();
    if (!form.isValid) {
      _applyValidation(form);
      setState(() {
        _printOk = false;
        _printMessage = null;
      });
      return;
    }
    final syntheticPrinter = _buildSyntheticEthernetPrinter(form);
    final payload = _buildEthernetDispatchPayload(form);
    setState(() {
      _printTesting = true;
      _printMessage = null;
      _printOk = false;
      _formError = null;
      _ipError = null;
      _portError = null;
    });
    if (kIsWeb) {
      setState(() {
        _printTesting = false;
        _printMessage =
            'Web sürümü yerel ağa erişemez. Masaüstü uygulamasından test edin.';
      });
      return;
    }
    final host = form.host;
    final port = form.port;
    debugPrint(
      '[EthernetPrinter][test_start] host=$host port=$port backend=tcp',
    );
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
      setState(() {
        _printOk = result.ok;
        _printMessage = result.ok
            ? 'Test fişi gönderildi. Yazıcı çıktısını kontrol edin.'
            : 'Test başarısız: ${result.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printOk = false;
        _printMessage = 'Test başarısız: $e';
      });
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
    setState(() {
      _saving = true;
      _formError = null;
      _ipError = null;
      _portError = null;
    });
    final host = form.host;
    final port = form.port;
    final name = form.name;
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
      );
      if (_printOk) {
        await repo.recordTestPrintResult(printerId: saved.id, success: true);
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll(
        'generic_80mm_escpos',
        _selectedPrinterProfile.id,
      );
      setState(() {
        _formError = 'Kaydedilemedi: $message';
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
              _Field(
                label: 'Yazıcı Adı',
                fieldKey: const Key('ethernet_name_field'),
                hint: 'NETUM ZJ-8360 Ethernet',
                controller: _nameCtrl,
                helper:
                    'Boş bırakırsanız kayıtta "Ethernet Yazıcı ${_ipCtrl.text.trim().isEmpty ? "<IP>" : _ipCtrl.text.trim()}" üretilir.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Field(
                      label: 'IP Adresi',
                      fieldKey: const Key('ethernet_ip_field'),
                      hint: 'Değer giriniz',
                      helper: 'Örn: 192.168.1.100',
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
                      hint: PrinterModel.ethernetDefaultPort.toString(),
                      controller: _portCtrl,
                      errorText: _portError,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PaperWidthSelector(
                value: _paperWidth,
                onChanged: (v) => setState(() => _paperWidth = v),
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
              _RoleSelector(
                value: _role,
                onChanged: (v) => setState(() => _role = v),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _formError!),
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
                      onPressed: _printTesting ? null : _runPrintTest,
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
              if (_connectionMessage != null) ...[
                const SizedBox(height: 10),
                _ResultBanner(ok: _connectionOk, message: _connectionMessage!),
              ],
              if (_printMessage != null) ...[
                const SizedBox(height: 10),
                _ResultBanner(ok: _printOk, message: _printMessage!),
              ],
              const SizedBox(height: 24),
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
              'Ethernet yazıcının kendi self-test fişinde yazan IP adresi ve '
              'sunucu portunu girin. Yazıcı üzerinde port genelde 9100\'dür. '
              'Bu yazıcı CUPS/USB üzerinden değil, doğrudan TCP ile yazdırır.',
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

class _PaperWidthSelector extends StatelessWidget {
  const _PaperWidthSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kağıt Genişliği',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [80, 58].map((w) {
            final isSelected = value == w;
            return GestureDetector(
              onTap: () => onChanged(w),
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

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.ok, required this.message});

  final bool ok;
  final String message;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final border = ok ? const Color(0xFF10B981) : const Color(0xFFFECACA);
    final fg = ok ? const Color(0xFF065F46) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: fg, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
