// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../models/desktop_printer_setup_models.dart';
import '../models/turkish_encoding_calibration.dart';
import '../services/desktop_print_orchestrator.dart';

/// Turkish encoding calibration for ESC/POS text printers (e.g. POS-58).
class TurkishEncodingCalibrationDialog extends StatefulWidget {
  const TurkishEncodingCalibrationDialog({
    super.key,
    required this.restaurantId,
    required this.printOrchestrator,
    required this.printer,
  });

  final String restaurantId;
  final DesktopPrintOrchestrator printOrchestrator;
  final UnifiedPrinterModel printer;

  static Future<bool?> show(
    BuildContext context, {
    required String restaurantId,
    required DesktopPrintOrchestrator printOrchestrator,
    required UnifiedPrinterModel printer,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => TurkishEncodingCalibrationDialog(
        restaurantId: restaurantId,
        printOrchestrator: printOrchestrator,
        printer: printer,
      ),
    );
  }

  @override
  State<TurkishEncodingCalibrationDialog> createState() =>
      _TurkishEncodingCalibrationDialogState();
}

class _TurkishEncodingCalibrationDialogState
    extends State<TurkishEncodingCalibrationDialog> {
  bool _busy = false;
  bool _verified = false;
  String? _selectedCandidateId;
  String? _error;
  String? _message;
  String _selectedPrintMode = kTurkishPrintModeText;
  bool _combinedSheetPrinted = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.printOrchestrator.loadEncodingProfile(
      restaurantId: widget.restaurantId,
      printerId: widget.printer.id,
    );
    if (!mounted) return;
    setState(() {
      _verified = profile != null;
      _selectedCandidateId = profile?.candidateId;
      _selectedPrintMode = profile?.printMode ?? kTurkishPrintModeText;
      _message = profile == null
          ? null
          : profile.isGuaranteeMode
          ? 'Türkçe Garanti Modu kayıtlı (uygulama yeniden açılsa da geçerli).'
          : '${profile.encoding} · ${profile.effectiveCodepageCommand} kayıtlı '
                '(uygulama yeniden açılsa da geçerli).';
    });
  }

  Future<void> _printCombinedSheet() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await widget.printOrchestrator.printTurkishEncodingCalibrationSheet(
            restaurantId: widget.restaurantId,
            printer: widget.printer,
          );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _error = result.message);
        return;
      }
      setState(() {
        _message = result.message;
        _combinedSheetPrinted = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _printGuaranteeSample() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.printOrchestrator.printTurkishGuaranteeSample(
        restaurantId: widget.restaurantId,
        printer: widget.printer,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _error = result.message);
        return;
      }
      setState(() {
        _selectedPrintMode = kTurkishPrintModeGuarantee;
        _verified = true;
        _message = result.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveSelection() async {
    if (_selectedPrintMode == kTurkishPrintModeGuarantee) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final result = await widget.printOrchestrator.saveTurkishPrintMode(
          restaurantId: widget.restaurantId,
          printer: widget.printer,
          printMode: kTurkishPrintModeGuarantee,
        );
        if (!mounted) return;
        if (!result.ok) {
          setState(() {
            _error = result.message;
            _verified = false;
          });
          return;
        }
        setState(() {
          _verified = true;
          _message = '${result.message} Profil bu cihazda kalıcı olarak saklandı.';
        });
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = error.toString());
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
      return;
    }

    final candidate = turkishEncodingCandidateById(_selectedCandidateId);
    if (candidate == null) {
      setState(() => _error = 'Fişte doğru görünen satırı seçin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await widget.printOrchestrator.saveEncodingProfileFromCandidate(
            restaurantId: widget.restaurantId,
            printer: widget.printer,
            candidate: candidate,
            printModeOverride: kTurkishPrintModeText,
          );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _error = result.message;
          _verified = false;
        });
        return;
      }
      setState(() {
        _verified = true;
        _message =
            '${result.message} Profil bu cihazda kalıcı olarak saklandı.';
      });
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerLabel = widget.printer.queueName.trim().isNotEmpty
        ? widget.printer.queueName
        : widget.printer.displayName;
    final guaranteeMode = _selectedPrintMode == kTurkishPrintModeGuarantee;
    final recommendGuarantee =
        !guaranteeMode && _combinedSheetPrinted && !_verified;
    return AlertDialog(
      title: const Text('Türkçe Baskı Ayarı'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Yazıcı: $printerLabel (${widget.printer.id})',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                value: kTurkishPrintModeText,
                groupValue: _selectedPrintMode,
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedPrintMode = value);
                      },
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Hızlı Mod (Text / RAW)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Daha hızlı; bazı yazıcılarda Türkçe bozulabilir.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              RadioListTile<String>(
                value: kTurkishPrintModeGuarantee,
                groupValue: _selectedPrintMode,
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedPrintMode = value);
                      },
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Türkçe Garanti Modu (Görsel / Raster)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Gömülü font ile Türkçe karakterler doğru basılır.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              if (recommendGuarantee)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Bu yazıcıda Türkçe karakterler text modda güvenilir görünmüyor. '
                    'Türkçe Garanti Modu önerilir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A3412),
                      height: 1.35,
                    ),
                  ),
                ),
              const Divider(height: 24),
              Text(
                _verified
                    ? (guaranteeMode
                          ? 'Türkçe Garanti Modu kayıtlı.'
                          : 'Türkçe karakter doğrulandı.')
                    : 'Türkçe ayarı henüz kaydedilmedi.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _verified
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 12),
              if (guaranteeMode) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _printGuaranteeSample,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.image_outlined),
                  label: const Text('Garanti modu test fişi bas'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _printCombinedSheet,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_outlined),
                  label: const Text('Tüm seçenekleri tek fişte bas'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fişte basılan satırlar:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...kTurkishEncodingCalibrationCandidates.asMap().entries.map((
                  entry,
                ) {
                  final index = entry.key + 1;
                  final candidate = entry.value;
                  final selected = _selectedCandidateId == candidate.id;
                  final preview = candidate.formatReceiptOptionLine(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () {
                              setState(() => _selectedCandidateId = candidate.id);
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE5E7EB),
                          ),
                          color: selected
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: candidate.id,
                              groupValue: _selectedCandidateId,
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _selectedCandidateId = value,
                                      );
                                    },
                            ),
                            Expanded(
                              child: Text(
                                preview,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: const Color(0xFF111827),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: _busy ||
                  (!guaranteeMode && _selectedCandidateId == null)
              ? null
              : _saveSelection,
          icon: const Icon(Icons.save_outlined),
          label: Text(guaranteeMode ? 'Garanti modunu kaydet' : 'Doğru satırı kaydet'),
        ),
      ],
    );
  }
}
