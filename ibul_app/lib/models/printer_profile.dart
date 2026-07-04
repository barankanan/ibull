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

  /// Profiles offered in the Ethernet add-printer form.
  static const List<PrinterProfile> ethernetSetupProfiles = [
    pos80,
    pos58,
    generic80mmEscpos,
  ];

  /// Canonical profile IDs accepted by Supabase `printers_printer_profile_id_check`.
  static const Set<String> databaseCanonicalProfileIds = {
    'standard_58mm',
    'standard_80mm',
    'usb_pos58',
    'network_escpos',
    'receipt_80mm',
    'kitchen_58mm',
    'pos58',
    'pos80',
    'generic_58mm_escpos',
    'generic_80mm_escpos',
  };

  /// Maps UI/profile aliases to the canonical DB value. Never send labels like
  /// `POS-80` to Supabase — only canonical ids such as `pos80`.
  static String? canonicalDatabaseId(String? profileId) {
    if (profileId == null || profileId.trim().isEmpty) return null;
    final trimmed = profileId.trim();
    final normalized = trimmed.toLowerCase();

    const aliasToCanonical = <String, String>{
      'pos-80': 'pos80',
      'pos-58': 'pos58',
      'pos80': 'pos80',
      'pos58': 'pos58',
      'generic 80mm esc/pos': 'generic_80mm_escpos',
      'generic_80mm_escpos': 'generic_80mm_escpos',
      'generic_58mm_escpos': 'generic_58mm_escpos',
    };
    final alias = aliasToCanonical[normalized];
    if (alias != null) return alias;

    final known = byId(trimmed);
    if (known != null) {
      if (databaseCanonicalProfileIds.contains(known.id)) {
        return known.id;
      }
      // Safe fallbacks for profiles not yet in DB constraint.
      if (known.paperWidthMm <= 58) return 'pos58';
      return 'pos80';
    }

    if (databaseCanonicalProfileIds.contains(trimmed)) {
      return trimmed;
    }
    return null;
  }

  /// Resolves the active profile for Ethernet setup/test/save payloads.
  /// Explicit selection wins; otherwise derive from paper width without
  /// forcing POS-58 for 80mm printers.
  static PrinterProfile resolveForEthernetSetup({
    String? explicitProfileId,
    required int paperWidthMm,
 }) {
    final explicit = byId(explicitProfileId);
    if (explicit != null) return explicit;
    return paperWidthMm <= 58 ? pos58 : pos80;
  }

  /// Bridge payload fields derived from a [PrinterProfile].
  ///
  /// Receipt tail length is intentionally excluded — it is stamped per printer
  /// via [PrinterReceiptLengthSettings] / orchestrator tail policy.
  static Map<String, dynamic> bridgeProfileFields(PrinterProfile profile) {
    return <String, dynamic>{
      'printer_profile': profile.id,
      'printer_profile_id': profile.id,
      'paper_width_mm': profile.paperWidthMm,
      'paperWidthMm': profile.paperWidthMm,
      'raster_width_px': profile.rasterWidthPx,
      'rasterWidthPx': profile.rasterWidthPx,
      'chars_per_line': profile.charsPerLine,
      'auto_cut': profile.supportsCut,
      'autoCut': profile.supportsCut,
    };
  }

  /// Resolves a single consistent profile when DB id, paper width, or display
  /// name disagree (e.g. `pos58` + `paper_width_mm=80`).
  static PrinterProfile resolveConsistentProfile({
    String? profileId,
    int? paperWidthMm,
    String? displayName,
  }) {
    final canonical = canonicalDatabaseId(profileId) ?? profileId?.trim();
    final known = canonical == null || canonical.isEmpty ? null : byId(canonical);

    var resolvedWidth = paperWidthMm ?? known?.paperWidthMm ?? 80;
    final nameHint = (displayName ?? '').toLowerCase();
    if (nameHint.contains('80mm') || nameHint.contains('80 mm')) {
      resolvedWidth = 80;
    } else if (nameHint.contains('58mm') || nameHint.contains('58 mm')) {
      resolvedWidth = 58;
    }

    if (known != null) {
      if (known.paperWidthMm <= 58 && resolvedWidth >= 80) {
        return pos80;
      }
      if (known.paperWidthMm >= 80 && resolvedWidth <= 58) {
        return pos58;
      }
      return known;
    }

    return resolvedWidth <= 58 ? pos58 : pos80;
  }

  /// Canonical save metadata — profile id and dimensions always agree.
  static ({String profileId, int paperWidthMm, int rasterWidthPx})
  normalizeSaveMetadata({
    String? profileId,
    required int paperWidthMm,
    String? displayName,
  }) {
    final profile = resolveConsistentProfile(
      profileId: profileId,
      paperWidthMm: paperWidthMm,
      displayName: displayName,
    );
    return (
      profileId: profile.id,
      paperWidthMm: profile.paperWidthMm,
      rasterWidthPx: profile.rasterWidthPx,
    );
  }

  /// Operator-facing hint when stored printer metadata would fail bridge validation.
  static String? inconsistencyMessage({
    required String? profileId,
    required int? paperWidthMm,
    int? rasterWidthPx,
    String? displayName,
  }) {
    if (!needsMetadataRepair(
      profileId: profileId,
      paperWidthMm: paperWidthMm,
      rasterWidthPx: rasterWidthPx,
      displayName: displayName,
    )) {
      return null;
    }
    final profile = resolveConsistentProfile(
      profileId: profileId,
      paperWidthMm: paperWidthMm,
      displayName: displayName,
    );
    return 'Bu yazıcının profil bilgisi tutarsız. '
        '${displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'Yazıcı'} '
        '80mm görünüyor ama ${profileId ?? 'POS-58'} olarak kayıtlı. '
        'Profili ${profile.label} olarak güncelleyin.';
  }

  /// True when stored profile id disagrees with paper width / raster metadata.
  static bool needsMetadataRepair({
    required String? profileId,
    required int? paperWidthMm,
    int? rasterWidthPx,
    String? displayName,
  }) {
    final normalized = normalizeSaveMetadata(
      profileId: profileId,
      paperWidthMm: paperWidthMm ?? 80,
      displayName: displayName,
    );
    final canonical = canonicalDatabaseId(profileId) ?? profileId?.trim() ?? '';
    if (canonical.isNotEmpty && canonical != normalized.profileId) {
      return true;
    }
    if (paperWidthMm != null && paperWidthMm != normalized.paperWidthMm) {
      return true;
    }
    if (rasterWidthPx != null && rasterWidthPx != normalized.rasterWidthPx) {
      return true;
    }
    return false;
  }

  /// Stamps consistent profile fields onto a bridge payload map (top-level or nested printer).
  static void stampConsistentProfileOnMap(
    Map<String, dynamic> payload, {
    String? profileId,
    int? paperWidthMm,
    String? displayName,
  }) {
    final resolvedProfileId = profileId ??
        payload['printer_profile_id']?.toString() ??
        payload['printer_profile']?.toString();
    final resolvedWidth = paperWidthMm ??
        int.tryParse(
          payload['paper_width_mm']?.toString() ??
              payload['paperWidthMm']?.toString() ??
              '',
        );
    final resolvedName =
        displayName ??
        payload['printer_name']?.toString() ??
        payload['displayName']?.toString() ??
        payload['name']?.toString();
    final profile = resolveConsistentProfile(
      profileId: resolvedProfileId,
      paperWidthMm: resolvedWidth,
      displayName: resolvedName,
    );
    payload.addAll(bridgeProfileFields(profile));
    payload['chars_per_line'] = profile.charsPerLine;
  }

  /// Normalizes profile id + dimensions on a full /print/test or dispatch body.
  static Map<String, dynamic> normalizeBridgePayload(
    Map<String, dynamic> payload,
  ) {
    final next = Map<String, dynamic>.from(payload);
    final embedded = next['printer'];
    if (embedded is Map) {
      final printerMap = Map<String, dynamic>.from(embedded);
      stampConsistentProfileOnMap(printerMap);
      next['printer'] = printerMap;
    }
    stampConsistentProfileOnMap(
      next,
      displayName: next['printer_name']?.toString(),
    );
    return next;
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
