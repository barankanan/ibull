import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_model.dart';
import '../models/turkish_encoding_calibration.dart';

class PrinterEncodingProfile {
  const PrinterEncodingProfile({
    required this.printerId,
    required this.encoding,
    required this.codePage,
    required this.verifiedAt,
    this.candidateId,
    this.printerName,
    this.codepageCommand,
    this.escRValue,
    this.printMode = kTurkishPrintModeText,
    this.codepageLabel,
  });

  final String printerId;
  final String encoding;
  final int codePage;
  final DateTime verifiedAt;
  final String? candidateId;
  final String? printerName;
  final String? codepageCommand;
  final int? escRValue;
  final String printMode;
  final String? codepageLabel;

  bool get isGuaranteeMode => printMode == kTurkishPrintModeGuarantee;

  String get effectiveCodepageCommand =>
      codepageCommand?.trim().isNotEmpty == true
      ? codepageCommand!.trim()
      : 'ESC t $codePage';

  String? get effectiveEscRCommand =>
      escRValue == null ? null : 'ESC R $escRValue';

  bool get isVerified => encoding.trim().isNotEmpty && codePage >= 0;

  PrinterEncodingSelection toSelection() {
    return PrinterEncodingSelection.normalize(
      charset: PrinterCharset.fromValue(encoding),
      codePage: codePage,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'printer_id': printerId,
    'encoding': encoding,
    'code_page': codePage,
    'codepage': codePage,
    'codepage_command': effectiveCodepageCommand,
    if (escRValue != null) 'esc_r_value': escRValue,
    if (codepageLabel != null) 'codepage_label': codepageLabel,
    'print_mode': printMode,
    'verified_at': verifiedAt.toIso8601String(),
    if (candidateId != null) 'candidate_id': candidateId,
    if (printerName != null) 'printer_name': printerName,
  };

  static PrinterEncodingProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final printerId = json['printer_id']?.toString().trim() ?? '';
    final encoding = json['encoding']?.toString().trim() ?? '';
    final codePage = PrinterEncodingSelection.tryParseCodePage(
      json['code_page']?.toString() ?? json['codepage']?.toString(),
    );
    if (printerId.isEmpty || encoding.isEmpty || codePage == null) {
      return null;
    }
    final escR = PrinterEncodingSelection.tryParseCodePage(
      json['esc_r_value']?.toString() ?? json['esc_r']?.toString(),
    );
    return PrinterEncodingProfile(
      printerId: printerId,
      encoding: encoding,
      codePage: codePage,
      verifiedAt:
          DateTime.tryParse(json['verified_at']?.toString() ?? '') ??
          DateTime.now(),
      candidateId: json['candidate_id']?.toString(),
      printerName: json['printer_name']?.toString(),
      codepageCommand: json['codepage_command']?.toString(),
      escRValue: escR,
      printMode: json['print_mode']?.toString() ?? kTurkishPrintModeText,
      codepageLabel: json['codepage_label']?.toString(),
    );
  }
}

/// Persists per-printer Turkish encoding profiles in SharedPreferences.
/// Survives app restarts; used for debug bridge and packaged bridge builds alike.
class PrinterEncodingProfileStore {
  static const String _prefix = 'ibul_printer_encoding_profile_v1_';

  String _key(String restaurantId, String printerId) =>
      '$_prefix${restaurantId.trim()}::${printerId.trim()}';

  Future<PrinterEncodingProfile?> load({
    required String restaurantId,
    required String printerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(restaurantId, printerId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PrinterEncodingProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String restaurantId,
    required PrinterEncodingProfile profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(restaurantId, profile.printerId),
      jsonEncode(profile.toJson()),
    );
  }

  Future<void> saveFromCandidate({
    required String restaurantId,
    required String printerId,
    required TurkishEncodingCandidate candidate,
    String? printerName,
  }) async {
    await save(
      restaurantId: restaurantId,
      profile: PrinterEncodingProfile(
        printerId: printerId.trim(),
        encoding: candidate.encoding,
        codePage: candidate.codePage,
        verifiedAt: DateTime.now(),
        candidateId: candidate.id,
        printerName: printerName?.trim(),
        codepageCommand: candidate.codepageCommand,
        escRValue: candidate.escRValue,
        printMode: candidate.printMode,
        codepageLabel: candidate.label,
      ),
    );
  }

  Future<void> clear({
    required String restaurantId,
    required String printerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(restaurantId, printerId));
  }
}
