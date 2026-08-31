import '../models/printer_model.dart';

/// Thrown when printer row was saved but `printers.print_size` column is missing.
///
/// Caller should keep the saved [printer] and show a clear migration message.
class PrinterPrintSizeMigrationRequiredException implements Exception {
  PrinterPrintSizeMigrationRequiredException(this.printer);

  final PrinterModel printer;

  @override
  String toString() =>
      'Baskı boyutu kalıcı olarak kaydedilemedi. Supabase\'de '
      'SUPABASE_PRINTER_PRINT_SIZE_SETTINGS.sql (veya '
      '20260810_printer_print_size_settings.sql) migration\'ını çalıştırın. '
      'Yazıcı kaydı diğer alanlarla kaydedildi.';
}

/// Per-printer print text size (mutfak / adisyon / test fişi).
enum PrintSizePreset {
  small,
  normal,
  large,
  xlarge;

  String get bridgeValue => switch (this) {
        PrintSizePreset.small => 'small',
        PrintSizePreset.normal => 'normal',
        PrintSizePreset.large => 'large',
        PrintSizePreset.xlarge => 'xlarge',
      };

  String get label => switch (this) {
        PrintSizePreset.small => 'Küçük',
        PrintSizePreset.normal => 'Normal',
        PrintSizePreset.large => 'Büyük',
        PrintSizePreset.xlarge => 'Çok Büyük',
      };

  /// Raster font multiplier. `normal` == current POS80 baseline sizes.
  double get textScale => switch (this) {
        PrintSizePreset.small => 0.85,
        PrintSizePreset.normal => 1.0,
        PrintSizePreset.large => 1.20,
        PrintSizePreset.xlarge => 1.40,
      };

  static PrintSizePreset parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'small':
      case 'kucuk':
      case 'küçük':
        return PrintSizePreset.small;
      case 'large':
      case 'buyuk':
      case 'büyük':
        return PrintSizePreset.large;
      case 'xlarge':
      case 'x-large':
      case 'cok_buyuk':
      case 'çok büyük':
      case 'cok buyuk':
        return PrintSizePreset.xlarge;
      default:
        return PrintSizePreset.normal;
    }
  }
}

class PrinterPrintSizeSettings {
  const PrinterPrintSizeSettings({
    this.preset = PrintSizePreset.normal,
  });

  static const PrinterPrintSizeSettings normal = PrinterPrintSizeSettings();

  final PrintSizePreset preset;

  factory PrinterPrintSizeSettings.fromPrinterModel(PrinterModel printer) {
    return PrinterPrintSizeSettings.fromMap(printer.toMap());
  }

  factory PrinterPrintSizeSettings.fromMap(Map<String, dynamic> map) {
    final fromPreset = map['print_size']?.toString() ??
        map['printSize']?.toString() ??
        map['print_font_size']?.toString();
    if (fromPreset != null && fromPreset.trim().isNotEmpty) {
      return PrinterPrintSizeSettings(preset: PrintSizePreset.parse(fromPreset));
    }
    final scaleRaw = map['print_text_scale'] ?? map['printTextScale'];
    if (scaleRaw != null) {
      final scale = scaleRaw is num
          ? scaleRaw.toDouble()
          : double.tryParse(scaleRaw.toString());
      if (scale != null) {
        return PrinterPrintSizeSettings(preset: _presetForScale(scale));
      }
    }
    return PrinterPrintSizeSettings.normal;
  }

  static PrintSizePreset _presetForScale(double scale) {
    if (scale <= 0.92) return PrintSizePreset.small;
    if (scale >= 1.30) return PrintSizePreset.xlarge;
    if (scale >= 1.10) return PrintSizePreset.large;
    return PrintSizePreset.normal;
  }

  PrinterPrintSizeSettings copyWith({PrintSizePreset? preset}) {
    return PrinterPrintSizeSettings(preset: preset ?? this.preset);
  }

  Map<String, dynamic> toDbFields() => <String, dynamic>{
        'print_size': preset.bridgeValue,
      };

  /// Fields stamped into bridge / nested printer payloads (no network).
  Map<String, dynamic> toBridgeFields() => <String, dynamic>{
        'print_size': preset.bridgeValue,
        'print_text_scale': preset.textScale,
        'printTextScale': preset.textScale,
      };

  Map<String, dynamic> toLiveBridgeFields() => <String, dynamic>{
        ...toBridgeFields(),
        'print_size_live_override': true,
        'print_size_source': 'live_form',
      };

  static PrinterPrintSizeSettings resolveForDispatch({
    required Map<String, dynamic> printerRaw,
    Map<String, dynamic>? payload,
    PrinterPrintSizeSettings? liveOverride,
  }) {
    if (liveOverride != null) return liveOverride;
    if (payload != null) {
      if (payload['print_size_live_override'] == true ||
          payload['print_size_source']?.toString() == 'live_form') {
        return PrinterPrintSizeSettings.fromMap(payload);
      }
      final payloadSize = payload['print_size'] ?? payload['printSize'];
      if (payloadSize != null && payloadSize.toString().trim().isNotEmpty) {
        return PrinterPrintSizeSettings.fromMap(payload);
      }
    }
    return PrinterPrintSizeSettings.fromMap(printerRaw);
  }
}
