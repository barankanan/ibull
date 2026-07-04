import '../models/printer_profile.dart';

/// Receipt tail padding preset for Yazıcı Merkezi "Fiş Uzunluğu".
enum ReceiptLengthPreset {
  short,
  normal,
  long,
  custom;

  static ReceiptLengthPreset parse(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized == 'short' || normalized == 'kisa' || normalized == 'kısa') {
      return ReceiptLengthPreset.short;
    }
    if (normalized == 'long' || normalized == 'uzun') {
      return ReceiptLengthPreset.long;
    }
    if (normalized == 'custom' ||
        normalized == 'özel' ||
        normalized == 'ozel') {
      return ReceiptLengthPreset.custom;
    }
    return ReceiptLengthPreset.normal;
  }

  String get bridgeValue {
    switch (this) {
      case ReceiptLengthPreset.short:
        return 'short';
      case ReceiptLengthPreset.normal:
        return 'normal';
      case ReceiptLengthPreset.long:
        return 'long';
      case ReceiptLengthPreset.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case ReceiptLengthPreset.short:
        return 'Kısa';
      case ReceiptLengthPreset.normal:
        return 'Normal';
      case ReceiptLengthPreset.long:
        return 'Uzun';
      case ReceiptLengthPreset.custom:
        return 'Özel';
    }
  }
}

/// Minimum receipt length / bottom padding for restaurant ESC/POS tickets.
class PrintTailPaddingPolicy {
  const PrintTailPaddingPolicy({
    required this.bottomFeedLines,
    required this.cutFeedLines,
    required this.minTrailingBlankLines,
    required this.bottomPaddingPx,
    required this.minReceiptHeightPx,
    this.preset = ReceiptLengthPreset.normal,
  });

  final int bottomFeedLines;
  final int cutFeedLines;
  final int minTrailingBlankLines;
  final int bottomPaddingPx;
  final int minReceiptHeightPx;
  final ReceiptLengthPreset preset;

  /// Bridge + orchestrator payload fields (top-level or nested printer map).
  Map<String, dynamic> toBridgeFields() => <String, dynamic>{
        'bottom_feed_lines': bottomFeedLines,
        'cut_feed_lines': cutFeedLines,
        'min_trailing_blank_lines': minTrailingBlankLines,
        'bottom_padding_px': bottomPaddingPx,
        'raster_bottom_padding_px': bottomPaddingPx,
        'min_receipt_height_px': minReceiptHeightPx,
        'receipt_length': preset.bridgeValue,
      };

  static PrintTailPaddingPolicy forPaperWidth(
    int paperWidthMm, {
    ReceiptLengthPreset preset = ReceiptLengthPreset.normal,
  }) {
    final isNarrow = paperWidthMm <= 58;
    switch (preset) {
      case ReceiptLengthPreset.short:
        if (isNarrow) {
          return const PrintTailPaddingPolicy(
            bottomFeedLines: 3,
            cutFeedLines: 2,
            minTrailingBlankLines: 3,
            bottomPaddingPx: 40,
            minReceiptHeightPx: 380,
            preset: ReceiptLengthPreset.short,
          );
        }
        return const PrintTailPaddingPolicy(
          bottomFeedLines: 2,
          cutFeedLines: 1,
          minTrailingBlankLines: 2,
          bottomPaddingPx: 40,
          minReceiptHeightPx: 420,
          preset: ReceiptLengthPreset.short,
        );
      case ReceiptLengthPreset.long:
        if (isNarrow) {
          return const PrintTailPaddingPolicy(
            bottomFeedLines: 12,
            cutFeedLines: 9,
            minTrailingBlankLines: 12,
            bottomPaddingPx: 220,
            minReceiptHeightPx: 780,
            preset: ReceiptLengthPreset.long,
          );
        }
        return const PrintTailPaddingPolicy(
          bottomFeedLines: 10,
          cutFeedLines: 8,
          minTrailingBlankLines: 10,
          bottomPaddingPx: 240,
          minReceiptHeightPx: 850,
          preset: ReceiptLengthPreset.long,
        );
      case ReceiptLengthPreset.custom:
        return forPaperWidth(paperWidthMm, preset: ReceiptLengthPreset.normal);
      case ReceiptLengthPreset.normal:
        if (isNarrow) {
          return const PrintTailPaddingPolicy(
            bottomFeedLines: 6,
            cutFeedLines: 5,
            minTrailingBlankLines: 6,
            bottomPaddingPx: 90,
            minReceiptHeightPx: 520,
            preset: ReceiptLengthPreset.normal,
          );
        }
        return const PrintTailPaddingPolicy(
          bottomFeedLines: 5,
          cutFeedLines: 4,
          minTrailingBlankLines: 5,
          bottomPaddingPx: 100,
          minReceiptHeightPx: 560,
          preset: ReceiptLengthPreset.normal,
        );
    }
  }

  static PrintTailPaddingPolicy forProfile(
    PrinterProfile profile, {
    ReceiptLengthPreset? preset,
    String? documentType,
  }) {
    return forPaperWidth(
      profile.paperWidthMm,
      preset: preset ?? ReceiptLengthPreset.normal,
    );
  }

  static PrintTailPaddingPolicy forKitchenTicket({
    required int paperWidthMm,
    ReceiptLengthPreset preset = ReceiptLengthPreset.normal,
  }) {
    return forPaperWidth(paperWidthMm, preset: preset);
  }

  static PrintTailPaddingPolicy resolveFromPayload(Map<String, dynamic> payload) {
    final paperWidth = int.tryParse(
          payload['paper_width_mm']?.toString() ??
              payload['paperWidthMm']?.toString() ??
              '',
        ) ??
        80;
    final preset = ReceiptLengthPreset.parse(
      payload['receipt_length']?.toString() ??
          payload['receipt_length_preset']?.toString() ??
          payload['ticket_length']?.toString(),
    );
    final defaults = forPaperWidth(
      paperWidth,
      preset: preset == ReceiptLengthPreset.custom
          ? ReceiptLengthPreset.normal
          : preset,
    );

    int? parseInt(dynamic value) {
      if (value == null) return null;
      final parsed = int.tryParse(value.toString());
      if (parsed == null || parsed < 0) return null;
      return parsed;
    }

    final bottomFeed = parseInt(payload['bottom_feed_lines']) ??
        parseInt(payload['receipt_bottom_feed_lines']) ??
        parseInt(payload['kitchen_bottom_padding_lines']) ??
        parseInt(payload['receipt_bottom_padding_lines']);
    final cutFeed =
        parseInt(payload['cut_feed_lines']) ??
        parseInt(payload['receipt_cut_feed_lines']);
    final minTrailing = parseInt(payload['min_trailing_blank_lines']) ??
        parseInt(payload['receipt_min_trailing_blank_lines']);
    final bottomPad = parseInt(payload['bottom_padding_px']) ??
        parseInt(payload['raster_bottom_padding_px']) ??
        parseInt(payload['receipt_bottom_padding_px']);
    final minHeight = parseInt(payload['min_receipt_height_px']) ??
        parseInt(payload['receipt_min_receipt_height_px']);

    if (preset == ReceiptLengthPreset.custom) {
      return PrintTailPaddingPolicy(
        bottomFeedLines: bottomFeed ?? 0,
        cutFeedLines: cutFeed ?? 0,
        minTrailingBlankLines: minTrailing ?? bottomFeed ?? 0,
        bottomPaddingPx: bottomPad ?? 0,
        minReceiptHeightPx: minHeight ?? 0,
        preset: ReceiptLengthPreset.custom,
      );
    }

    return PrintTailPaddingPolicy(
      bottomFeedLines: bottomFeed ?? defaults.bottomFeedLines,
      cutFeedLines: cutFeed ?? defaults.cutFeedLines,
      minTrailingBlankLines: minTrailing ??
          (bottomFeed != null && bottomFeed >= defaults.minTrailingBlankLines
              ? bottomFeed
              : defaults.minTrailingBlankLines),
      bottomPaddingPx: bottomPad ?? defaults.bottomPaddingPx,
      minReceiptHeightPx: minHeight ?? defaults.minReceiptHeightPx,
      preset: preset,
    );
  }

  /// A/B physical minimum — all tail values zero.
  static const PrintTailPaddingPolicy abMinimumPhysicalTest =
      PrintTailPaddingPolicy(
    bottomFeedLines: 0,
    cutFeedLines: 0,
    minTrailingBlankLines: 0,
    bottomPaddingPx: 0,
    minReceiptHeightPx: 0,
    preset: ReceiptLengthPreset.custom,
  );

  /// A/B physical maximum — exaggerated tail for visible length difference.
  static const PrintTailPaddingPolicy abMaximumPhysicalTest =
      PrintTailPaddingPolicy(
    bottomFeedLines: 20,
    cutFeedLines: 16,
    minTrailingBlankLines: 20,
    bottomPaddingPx: 600,
    minReceiptHeightPx: 1400,
    preset: ReceiptLengthPreset.custom,
  );

  static Map<String, dynamic> abMinimumBridgeFields() => <String, dynamic>{
        ...abMinimumPhysicalTest.toBridgeFields(),
        'receipt_length_live_override': true,
        'receipt_length_source': 'ab_min_test',
        'policy_source': 'ab_min_test',
      };

  static Map<String, dynamic> abMaximumBridgeFields() => <String, dynamic>{
        ...abMaximumPhysicalTest.toBridgeFields(),
        'receipt_length_live_override': true,
        'receipt_length_source': 'ab_max_test',
        'policy_source': 'ab_max_test',
      };
}
