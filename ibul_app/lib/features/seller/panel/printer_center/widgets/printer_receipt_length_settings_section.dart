import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../services/print_tail_padding_policy.dart';
import '../../../../../services/printer_receipt_length_settings.dart';

/// Yazıcı Merkezi — Fiş uzunluğu ayarı (Kısa / Normal / Uzun / Özel).
class PrinterReceiptLengthSettingsSection extends StatefulWidget {
  const PrinterReceiptLengthSettingsSection({
    super.key,
    required this.paperWidthMm,
    required this.settings,
    required this.onChanged,
    this.showTestButton = false,
    this.onTestReceipt,
    this.testing = false,
    this.showAbTests = false,
    this.onAbMinimumTest,
    this.onAbMaximumTest,
    this.abTesting = false,
  });

  final int paperWidthMm;
  final PrinterReceiptLengthSettings settings;
  final ValueChanged<PrinterReceiptLengthSettings> onChanged;
  final bool showTestButton;
  final VoidCallback? onTestReceipt;
  final bool testing;
  final bool showAbTests;
  final VoidCallback? onAbMinimumTest;
  final VoidCallback? onAbMaximumTest;
  final bool abTesting;

  @override
  State<PrinterReceiptLengthSettingsSection> createState() =>
      _PrinterReceiptLengthSettingsSectionState();
}

class _PrinterReceiptLengthSettingsSectionState
    extends State<PrinterReceiptLengthSettingsSection> {
  late final TextEditingController _bottomFeedCtrl;
  late final TextEditingController _cutFeedCtrl;
  late final TextEditingController _trailingCtrl;
  late final TextEditingController _paddingCtrl;
  late final TextEditingController _minHeightCtrl;
  bool _advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    _bottomFeedCtrl = TextEditingController();
    _cutFeedCtrl = TextEditingController();
    _trailingCtrl = TextEditingController();
    _paddingCtrl = TextEditingController();
    _minHeightCtrl = TextEditingController();
    _syncControllersFromSettings();
    if (widget.settings.preset == ReceiptLengthPreset.custom) {
      _advancedExpanded = true;
    }
  }

  @override
  void didUpdateWidget(covariant PrinterReceiptLengthSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _syncControllersFromSettings();
    }
  }

  void _syncControllersFromSettings() {
    final policy = widget.settings.resolvePolicy(
      paperWidthMm: widget.paperWidthMm,
    );
    _bottomFeedCtrl.text = (widget.settings.bottomFeedLines ?? policy.bottomFeedLines)
        .toString();
    _cutFeedCtrl.text =
        (widget.settings.cutFeedLines ?? policy.cutFeedLines).toString();
    _trailingCtrl.text = (widget.settings.minTrailingBlankLines ??
            policy.minTrailingBlankLines)
        .toString();
    _paddingCtrl.text =
        (widget.settings.bottomPaddingPx ?? policy.bottomPaddingPx).toString();
    _minHeightCtrl.text = (widget.settings.minReceiptHeightPx ??
            policy.minReceiptHeightPx)
        .toString();
  }

  @override
  void dispose() {
    _bottomFeedCtrl.dispose();
    _cutFeedCtrl.dispose();
    _trailingCtrl.dispose();
    _paddingCtrl.dispose();
    _minHeightCtrl.dispose();
    super.dispose();
  }

  void _emitPreset(ReceiptLengthPreset preset) {
    if (preset == ReceiptLengthPreset.custom) {
      final defaults =
          PrinterReceiptLengthSettings.customDefaultsForPaper(widget.paperWidthMm);
      widget.onChanged(
        widget.settings.preset == ReceiptLengthPreset.custom
            ? widget.settings.copyWith(preset: preset)
            : defaults,
      );
      setState(() => _advancedExpanded = true);
      return;
    }
    widget.onChanged(
      widget.settings.copyWith(preset: preset, clearCustomFields: true),
    );
    setState(() => _advancedExpanded = false);
  }

  void _emitCustomField() {
    widget.onChanged(
      widget.settings.copyWith(
        preset: ReceiptLengthPreset.custom,
        bottomFeedLines: int.tryParse(_bottomFeedCtrl.text.trim()),
        cutFeedLines: int.tryParse(_cutFeedCtrl.text.trim()),
        minTrailingBlankLines: int.tryParse(_trailingCtrl.text.trim()),
        bottomPaddingPx: int.tryParse(_paddingCtrl.text.trim()),
        minReceiptHeightPx: int.tryParse(_minHeightCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.settings.preset == ReceiptLengthPreset.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiş Ayarı',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Fiş Uzunluğu',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        KeyedSubtree(
          key: const Key('receipt_length_dropdown'),
          child: DropdownButtonFormField<ReceiptLengthPreset>(
            key: ValueKey(widget.settings.preset),
            initialValue: widget.settings.preset,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
          items: ReceiptLengthPreset.values
              .map(
                (preset) => DropdownMenuItem(
                  value: preset,
                  child: Text(preset.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            _emitPreset(value);
          },
        ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kısa fişlerde kesimden önce bırakılacak boşluk miktarını ayarlar.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        if (isCustom) ...[
          const SizedBox(height: 12),
          const Text(
            'Türkçe karakterli fişlerde uzunluğu en çok '
            '“Görsel alt boşluk” ve “Minimum fiş yüksekliği” belirler.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () =>
                setState(() => _advancedExpanded = !_advancedExpanded),
            child: Row(
              children: [
                Icon(
                  _advancedExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Gelişmiş ayarlar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isCustom && _advancedExpanded) ...[
          const SizedBox(height: 10),
          KeyedSubtree(
            key: const Key('receipt_length_advanced_fields'),
            child: Column(
              children: [
                _numField(
                  label: 'Alt boşluk satırı',
                  controller: _bottomFeedCtrl,
                  max: PrinterReceiptLengthSettings.maxFeedLines,
                ),
                const SizedBox(height: 10),
                _numField(
                  label: 'Kesim öncesi ilerletme',
                  controller: _cutFeedCtrl,
                  max: PrinterReceiptLengthSettings.maxFeedLines,
                ),
                const SizedBox(height: 10),
                _numField(
                  label: 'Alt boş satır (metin)',
                  controller: _trailingCtrl,
                  max: PrinterReceiptLengthSettings.maxFeedLines,
                ),
                const SizedBox(height: 10),
                _numField(
                  label: 'Görsel alt boşluk',
                  controller: _paddingCtrl,
                  max: PrinterReceiptLengthSettings.maxBottomPaddingPx,
                ),
                const SizedBox(height: 10),
                _numField(
                  label: 'Minimum fiş yüksekliği',
                  controller: _minHeightCtrl,
                  min: PrinterReceiptLengthSettings.minReceiptHeightPxMin,
                  max: PrinterReceiptLengthSettings.minReceiptHeightPxMax,
                ),
              ],
            ),
          ),
        ],
        if (widget.showTestButton && widget.onTestReceipt != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('receipt_length_test_button'),
            onPressed: widget.testing ? null : widget.onTestReceipt,
            icon: widget.testing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long_outlined, size: 16),
            label: const Text('Test Fişi Bas'),
          ),
        ],
        if (widget.showAbTests &&
            widget.onAbMinimumTest != null &&
            widget.onAbMaximumTest != null) ...[
          const SizedBox(height: 10),
          const Text(
            'Fiziksel uzunluk kanıt testi (A/B)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aynı Türkçe mutfak içeriği basılır; yalnızca alt boşluk değerleri farklıdır.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('receipt_length_ab_min_button'),
                  onPressed: widget.abTesting ? null : widget.onAbMinimumTest,
                  child: const Text('Minimum Uzunluk Testi'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('receipt_length_ab_max_button'),
                  onPressed: widget.abTesting ? null : widget.onAbMaximumTest,
                  child: const Text('Maksimum Uzunluk Testi'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _numField({
    required String label,
    required TextEditingController controller,
    int min = 0,
    required int max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
      onChanged: (_) => _emitCustomField(),
    );
  }
}
