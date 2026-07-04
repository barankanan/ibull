import '../models/printer_model.dart';
import 'print_tail_padding_policy.dart';

/// Per-printer receipt tail length persisted in `printers` table.
class PrinterReceiptLengthSettings {
  const PrinterReceiptLengthSettings({
    this.preset = ReceiptLengthPreset.normal,
    this.bottomFeedLines,
    this.cutFeedLines,
    this.minTrailingBlankLines,
    this.bottomPaddingPx,
    this.minReceiptHeightPx,
  });

  static const int maxFeedLines = 30;
  static const int maxBottomPaddingPx = 700;
  static const int minReceiptHeightPxMin = 0;
  static const int minReceiptHeightPxMax = 1600;

  final ReceiptLengthPreset preset;
  final int? bottomFeedLines;
  final int? cutFeedLines;
  final int? minTrailingBlankLines;
  final int? bottomPaddingPx;
  final int? minReceiptHeightPx;

  static const PrinterReceiptLengthSettings normal =
      PrinterReceiptLengthSettings();

  /// Sensible Özel defaults when the operator first picks custom (POS-80).
  static const PrinterReceiptLengthSettings pos80CustomDefaults =
      PrinterReceiptLengthSettings(
    preset: ReceiptLengthPreset.custom,
    bottomFeedLines: 5,
    cutFeedLines: 4,
    minTrailingBlankLines: 5,
    bottomPaddingPx: 120,
    minReceiptHeightPx: 620,
  );

  /// Sensible Özel defaults when the operator first picks custom (POS-58).
  static const PrinterReceiptLengthSettings pos58CustomDefaults =
      PrinterReceiptLengthSettings(
    preset: ReceiptLengthPreset.custom,
    bottomFeedLines: 6,
    cutFeedLines: 5,
    minTrailingBlankLines: 6,
    bottomPaddingPx: 110,
    minReceiptHeightPx: 580,
  );

  static PrinterReceiptLengthSettings customDefaultsForPaper(int paperWidthMm) {
    return paperWidthMm <= 58 ? pos58CustomDefaults : pos80CustomDefaults;
  }

  factory PrinterReceiptLengthSettings.fromPrinterModel(PrinterModel printer) {
    return PrinterReceiptLengthSettings.fromMap(printer.toMap());
  }

  factory PrinterReceiptLengthSettings.fromMap(Map<String, dynamic> map) {
    final preset = ReceiptLengthPreset.parse(
      map['receipt_length_preset']?.toString() ??
          map['receipt_length']?.toString(),
    );
    return PrinterReceiptLengthSettings(
      preset: preset,
      bottomFeedLines: _parseOptionalInt(map['receipt_bottom_feed_lines']) ??
          _parseOptionalInt(map['bottom_feed_lines']),
      cutFeedLines: _parseOptionalInt(map['receipt_cut_feed_lines']) ??
          _parseOptionalInt(map['cut_feed_lines']),
      minTrailingBlankLines:
          _parseOptionalInt(map['receipt_min_trailing_blank_lines']) ??
              _parseOptionalInt(map['min_trailing_blank_lines']),
      bottomPaddingPx: _parseOptionalInt(map['receipt_bottom_padding_px']) ??
          _parseOptionalInt(map['bottom_padding_px']) ??
          _parseOptionalInt(map['raster_bottom_padding_px']),
      minReceiptHeightPx:
          _parseOptionalInt(map['receipt_min_receipt_height_px']) ??
              _parseOptionalInt(map['min_receipt_height_px']),
    );
  }

  PrinterReceiptLengthSettings copyWith({
    ReceiptLengthPreset? preset,
    int? bottomFeedLines,
    int? cutFeedLines,
    int? minTrailingBlankLines,
    int? bottomPaddingPx,
    int? minReceiptHeightPx,
    bool clearCustomFields = false,
  }) {
    if (clearCustomFields) {
      return PrinterReceiptLengthSettings(
        preset: preset ?? this.preset,
      );
    }
    return PrinterReceiptLengthSettings(
      preset: preset ?? this.preset,
      bottomFeedLines: bottomFeedLines ?? this.bottomFeedLines,
      cutFeedLines: cutFeedLines ?? this.cutFeedLines,
      minTrailingBlankLines:
          minTrailingBlankLines ?? this.minTrailingBlankLines,
      bottomPaddingPx: bottomPaddingPx ?? this.bottomPaddingPx,
      minReceiptHeightPx: minReceiptHeightPx ?? this.minReceiptHeightPx,
    );
  }

  Map<String, dynamic> toDbFields() {
    final fields = <String, dynamic>{
      'receipt_length_preset': preset.bridgeValue,
    };
    if (preset == ReceiptLengthPreset.custom) {
      final normalized = _normalizedCustomFields(paperWidthMm: 80);
      fields['receipt_bottom_feed_lines'] = normalized.bottomFeedLines;
      fields['receipt_cut_feed_lines'] = normalized.cutFeedLines;
      fields['receipt_min_trailing_blank_lines'] =
          normalized.minTrailingBlankLines;
      fields['receipt_bottom_padding_px'] = normalized.bottomPaddingPx;
      fields['receipt_min_receipt_height_px'] = normalized.minReceiptHeightPx;
    } else {
      fields['receipt_bottom_feed_lines'] = null;
      fields['receipt_cut_feed_lines'] = null;
      fields['receipt_min_trailing_blank_lines'] = null;
      fields['receipt_bottom_padding_px'] = null;
      fields['receipt_min_receipt_height_px'] = null;
    }
    return fields;
  }

  /// Bridge payload fields for live test / dispatch override.
  Map<String, dynamic> toLiveBridgeFields({required int paperWidthMm}) {
    return <String, dynamic>{
      ...resolvePolicy(paperWidthMm: paperWidthMm).toBridgeFields(),
      'receipt_length_live_override': true,
      'receipt_length_source': 'live_form',
    };
  }

  PrintTailPaddingPolicy resolvePolicy({required int paperWidthMm}) {
    if (preset == ReceiptLengthPreset.custom) {
      return _normalizedCustomFields(paperWidthMm: paperWidthMm);
    }
    return PrintTailPaddingPolicy.forPaperWidth(
      paperWidthMm,
      preset: preset,
    );
  }

  PrintTailPaddingPolicy _normalizedCustomFields({required int paperWidthMm}) {
    final fallback = PrintTailPaddingPolicy.forPaperWidth(paperWidthMm);
    int clampFeed(int? value) =>
        (value ?? fallback.bottomFeedLines).clamp(0, maxFeedLines);
    int clampPadding(int? value) => (value ?? fallback.bottomPaddingPx)
        .clamp(0, maxBottomPaddingPx);
    int clampHeight(int? value) => (value ?? fallback.minReceiptHeightPx)
        .clamp(minReceiptHeightPxMin, minReceiptHeightPxMax);
    final bottom = clampFeed(bottomFeedLines);
    final cut = clampFeed(cutFeedLines);
    final trailing = clampFeed(
      minTrailingBlankLines ?? bottom,
    );
    return PrintTailPaddingPolicy(
      bottomFeedLines: bottom,
      cutFeedLines: cut,
      minTrailingBlankLines: trailing >= bottom ? trailing : bottom,
      bottomPaddingPx: clampPadding(bottomPaddingPx),
      minReceiptHeightPx: clampHeight(minReceiptHeightPx),
      preset: ReceiptLengthPreset.custom,
    );
  }

  static PrintTailPaddingPolicy resolveForDispatch({
    required int paperWidthMm,
    required Map<String, dynamic> printerRaw,
    Map<String, dynamic>? payload,
    PrinterReceiptLengthSettings? liveOverride,
  }) {
    if (liveOverride != null) {
      return liveOverride.resolvePolicy(paperWidthMm: paperWidthMm);
    }

    if (payload != null && _payloadHasLiveReceiptOverride(payload)) {
      return PrintTailPaddingPolicy.resolveFromPayload(
        _payloadWithPaperWidth(payload, paperWidthMm),
      );
    }

    if (payload != null && _payloadHasJobReceiptSettings(payload)) {
      return PrintTailPaddingPolicy.resolveFromPayload(
        _payloadWithPaperWidth(payload, paperWidthMm),
      );
    }

    final fromPrinter = PrinterReceiptLengthSettings.fromMap(printerRaw);
    if (_hasExplicitPrinterSetting(fromPrinter)) {
      return fromPrinter.resolvePolicy(paperWidthMm: paperWidthMm);
    }

    if (payload != null && payload.isNotEmpty) {
      final fromPayload = PrintTailPaddingPolicy.resolveFromPayload(
        _payloadWithPaperWidth(payload, paperWidthMm),
      );
      final payloadPreset = ReceiptLengthPreset.parse(
        payload['receipt_length']?.toString(),
      );
      if (payloadPreset != ReceiptLengthPreset.normal ||
          payload.containsKey('bottom_feed_lines') ||
          payload.containsKey('min_receipt_height_px')) {
        return fromPayload;
      }
    }
    return PrintTailPaddingPolicy.forPaperWidth(paperWidthMm);
  }

  /// Where the active tail policy came from (for production debug logs).
  static String resolvePolicySource({
    required Map<String, dynamic> printerRaw,
    Map<String, dynamic>? payload,
    PrinterReceiptLengthSettings? liveOverride,
  }) {
    if (liveOverride != null) return 'live_form';
    if (payload != null) {
      final source = payload['receipt_length_source']?.toString() ?? '';
      if (source == 'ab_min_test' || source == 'ab_max_test') return source;
      if (_payloadHasLiveReceiptOverride(payload)) return 'live_form';
      if (_payloadHasJobReceiptSettings(payload)) return 'job_explicit';
      if (source == 'orchestrator') {
        final fromPrinter = PrinterReceiptLengthSettings.fromMap(printerRaw);
        if (fromPrinter.preset == ReceiptLengthPreset.custom) {
          return 'db_custom';
        }
        if (fromPrinter.preset != ReceiptLengthPreset.normal) {
          return 'db_preset';
        }
      }
    }
    final fromPrinter = PrinterReceiptLengthSettings.fromMap(printerRaw);
    if (fromPrinter.preset == ReceiptLengthPreset.custom) return 'db_custom';
    if (fromPrinter.preset != ReceiptLengthPreset.normal) return 'db_preset';
    return 'default';
  }

  /// Returns a user-facing message when UI-edited printer differs from dispatch target.
  static String? printerIdMismatchDiagnostic({
    required String? uiEditedPrinterId,
    required String? dispatchPrinterRecordId,
  }) {
    final ui = (uiEditedPrinterId ?? '').trim();
    final dispatch = (dispatchPrinterRecordId ?? '').trim();
    if (ui.isEmpty || dispatch.isEmpty || ui == dispatch) return null;
    return 'Bu fiş farklı yazıcı kaydıyla basılıyor ($dispatch). '
        'Lütfen o yazıcının fiş uzunluğunu düzenleyin.';
  }

  static Map<String, dynamic> _payloadWithPaperWidth(
    Map<String, dynamic> payload,
    int paperWidthMm,
  ) {
    return <String, dynamic>{
      ...payload,
      if (!payload.containsKey('paper_width_mm') &&
          !payload.containsKey('paperWidthMm'))
        'paper_width_mm': paperWidthMm,
    };
  }

  static bool _payloadHasLiveReceiptOverride(Map<String, dynamic> payload) {
    if (payload['receipt_length_live_override'] == true) return true;
    if (payload['receipt_length_source']?.toString() == 'live_form') {
      return true;
    }
    return false;
  }

  static bool _payloadHasJobReceiptSettings(Map<String, dynamic> payload) {
    if (payload['receipt_length_source']?.toString() == 'job') {
      return true;
    }
    if (payload.containsKey('receipt_length_preset') &&
        payload['receipt_length_source']?.toString() != 'orchestrator') {
      return true;
    }
    return false;
  }

  static bool _hasExplicitPrinterSetting(PrinterReceiptLengthSettings s) {
    if (s.preset != ReceiptLengthPreset.normal) return true;
    return s.bottomFeedLines != null ||
        s.cutFeedLines != null ||
        s.minTrailingBlankLines != null ||
        s.bottomPaddingPx != null ||
        s.minReceiptHeightPx != null;
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }
}
