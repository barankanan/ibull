import 'printer_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrinterProfile — Predefined hardware profiles for common ESC/POS printers
// ─────────────────────────────────────────────────────────────────────────────
//
// A profile bundles all hardware-specific settings so the wizard can
// auto-fill Step 3 (Özellikler) with sensible defaults.  The user can still
// override any value after selecting a profile.
//
// Backward compatibility: printerProfileId is nullable.  Printers that were
// created before profiles were introduced get fallback resolution via
// [PrinterProfile.fallbackFor].

class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.paperWidthMm,
    required this.rasterWidthPx,
    required this.charsPerLine,
    required this.charset,
    required this.codepage,
    required this.supportsCut,
    required this.suggestedTransport,
    required this.suggestedRoles,
  });

  // ── Identity ──
  final String id;
  final String label;
  final String description;

  // ── Hardware settings ──
  final int paperWidthMm;
  final int rasterWidthPx;
  final int charsPerLine;
  final PrinterCharset charset;
  String get encoding => charset.value;

  /// ESC/POS codepage index sent to the printer (null = don't send).
  final int? codepage;
  final bool supportsCut;

  // ── Heuristics ──
  /// Recommended connection_type for this profile.
  final String suggestedTransport;

  /// Roles this kind of printer is typically used for.
  final List<PrinterRole> suggestedRoles;

  // ─────────────────────────────────────────────────────────────────────────
  // Built-in profiles
  // ─────────────────────────────────────────────────────────────────────────

  static const standard58mm = PrinterProfile(
    id: 'standard_58mm',
    label: 'Standart 58mm ESC/POS',
    description: 'Çoğu masaüstü 58mm ESC/POS yazıcısı. Türkçe için CP857.',
    paperWidthMm: 58,
    rasterWidthPx: 384,
    charsPerLine: 32,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: false,
    suggestedTransport: PrinterModel.localConnectionType,
    suggestedRoles: [PrinterRole.kitchen],
  );

  static const standard80mm = PrinterProfile(
    id: 'standard_80mm',
    label: 'Standart 80mm ESC/POS',
    description:
        '80mm adisyon / kasa yazıcısı. Çoğunlukla otomatik kesici destekler.',
    paperWidthMm: 80,
    rasterWidthPx: 576,
    charsPerLine: 48,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: true,
    suggestedTransport: PrinterModel.localConnectionType,
    suggestedRoles: [PrinterRole.receipt],
  );

  static const usbPos58 = PrinterProfile(
    id: 'usb_pos58',
    label: 'USB POS58',
    description:
        'USB bağlantılı küçük 58mm POS yazıcısı. Doğrudan USB veya CUPS.',
    paperWidthMm: 58,
    rasterWidthPx: 384,
    charsPerLine: 32,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: false,
    suggestedTransport: PrinterModel.usbConnectionType,
    suggestedRoles: [PrinterRole.kitchen, PrinterRole.general],
  );

  static const pos58 = PrinterProfile(
    id: 'pos58',
    label: 'POS-58',
    description: '58mm POS yazıcısı için güvenli profil.',
    paperWidthMm: 58,
    rasterWidthPx: 384,
    charsPerLine: 32,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: false,
    suggestedTransport: PrinterModel.usbConnectionType,
    suggestedRoles: [PrinterRole.receipt, PrinterRole.kitchen],
  );

  static const pos80 = PrinterProfile(
    id: 'pos80',
    label: 'POS-80',
    description: '80mm / 576px ESC/POS yazıcılar için canonical profil.',
    paperWidthMm: 80,
    rasterWidthPx: 576,
    charsPerLine: 48,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: true,
    suggestedTransport: PrinterModel.networkConnectionType,
    suggestedRoles: [PrinterRole.receipt, PrinterRole.kitchen],
  );

  static const networkEscPos = PrinterProfile(
    id: 'network_escpos',
    label: 'Network ESC/POS',
    description:
        'Ethernet / Wi-Fi ile TCP 9100 üzerinden bağlanan ağ yazıcısı.',
    paperWidthMm: 80,
    rasterWidthPx: 576,
    charsPerLine: 48,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: true,
    suggestedTransport: PrinterModel.networkConnectionType,
    suggestedRoles: [PrinterRole.receipt],
  );

  static const generic80mmEscpos = PrinterProfile(
    id: 'generic_80mm_escpos',
    label: 'Generic 80mm ESC/POS',
    description: '80mm ESC/POS yazıcılar için güvenli genel profil.',
    paperWidthMm: 80,
    rasterWidthPx: 576,
    charsPerLine: 48,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: true,
    suggestedTransport: PrinterModel.networkConnectionType,
    suggestedRoles: [PrinterRole.receipt, PrinterRole.kitchen],
  );

  static const receipt80mm = PrinterProfile(
    id: 'receipt_80mm',
    label: 'Adisyon 80mm',
    description: 'Müşteri adisyonu için 80mm yazıcı. Türkçe karakter + kesici.',
    paperWidthMm: 80,
    rasterWidthPx: 576,
    charsPerLine: 48,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: true,
    suggestedTransport: PrinterModel.localConnectionType,
    suggestedRoles: [PrinterRole.receipt],
  );

  static const kitchen58mm = PrinterProfile(
    id: 'kitchen_58mm',
    label: 'Mutfak 58mm',
    description: 'Mutfak/ocak siparişleri için 58mm termal yazıcı.',
    paperWidthMm: 58,
    rasterWidthPx: 384,
    charsPerLine: 32,
    charset: PrinterCharset.cp857,
    codepage: 13,
    supportsCut: false,
    suggestedTransport: PrinterModel.localConnectionType,
    suggestedRoles: [PrinterRole.kitchen],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Registry
  // ─────────────────────────────────────────────────────────────────────────

  static const List<PrinterProfile> all = [
    standard58mm,
    standard80mm,
    usbPos58,
    pos58,
    pos80,
    networkEscPos,
    generic80mmEscpos,
    receipt80mm,
    kitchen58mm,
  ];

  static PrinterProfile? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Backward-compat fallback
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a sensible profile for printers that pre-date the profile system,
  /// based on their existing [paperWidthMm] and [connectionType].
  static PrinterProfile fallbackFor(PrinterModel printer) {
    final w = printer.paperWidthMm;
    final ct = printer.formConnectionType;
    if (ct == PrinterModel.networkConnectionType &&
        !printer.isLocalConnection) {
      return networkEscPos;
    }
    if (ct == PrinterModel.usbConnectionType) {
      return usbPos58;
    }
    if (w <= 58) return kitchen58mm;
    return standard80mm;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension convenience on PrinterModel
// ─────────────────────────────────────────────────────────────────────────────

extension PrinterModelProfileExt on PrinterModel {
  /// Resolved profile: explicit if set, otherwise fallback-derived.
  PrinterProfile get resolvedProfile =>
      PrinterProfile.byId(printerProfileId) ?? PrinterProfile.fallbackFor(this);
}
