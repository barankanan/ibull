import 'printer_model.dart';

/// Primary line on calibration receipts.
const String kTurkishCalibrationPrimaryTestLine =
    'Türkçe: ığüşöç İĞÜŞÖÇ';

const String kTurkishCalibrationProductLine =
    'Ürün: Çiğ Köfte, Ciğer Şiş, Kuşbaşı, Kıyma Dürüm';

const String kTurkishCalibrationNoteLine =
    'Not: az pişmiş, soğansız, acısız';

const List<String> kTurkishCalibrationSampleLines = <String>[
  kTurkishCalibrationPrimaryTestLine,
  kTurkishCalibrationProductLine,
  kTurkishCalibrationNoteLine,
];

/// `text` = fast ESC/POS raw; `turkish_guarantee` = bundled-font raster.
const String kTurkishPrintModeText = 'text';
const String kTurkishPrintModeGuarantee = 'turkish_guarantee';

/// ESC/POS text-mode candidates for POS-58 / Zjiang Turkish calibration.
class TurkishEncodingCandidate {
  const TurkishEncodingCandidate({
    required this.id,
    required this.label,
    required this.encoding,
    required this.codePage,
    this.escRValue,
    this.printMode = kTurkishPrintModeText,
  });

  final String id;
  final String label;
  final String encoding;
  final int codePage;
  final int? escRValue;
  final String printMode;

  String get codepageCommand => 'ESC t $codePage';

  String? get escRCommand =>
      escRValue == null ? null : 'ESC R $escRValue';

  String formatOptionHeader(int index) {
    final safeEncoding = encoding.trim().isEmpty ? 'cp857' : encoding.trim();
    final escT = codePage >= 0 ? 'ESC t $codePage' : '-';
    final escRPart = escRValue == null ? '' : ' / ESC R $escRValue';
    return '[$index] $safeEncoding / $escT$escRPart';
  }

  List<String> formatReceiptBlock(int index) => <String>[
    formatOptionHeader(index),
    kTurkishCalibrationPrimaryTestLine,
    kTurkishCalibrationProductLine,
    kTurkishCalibrationNoteLine,
  ];

  /// Multi-line preview/label for wizard and calibration UI.
  String formatReceiptOptionLine(int index) => formatReceiptBlock(index).join('\n');

  PrinterEncodingSelection toSelection() {
    return PrinterEncodingSelection.normalize(
      charset: PrinterCharset.fromValue(encoding),
      codePage: codePage,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'encoding': encoding,
    'code_page': codePage,
    'codepage': codePage,
    'codepage_command': codepageCommand,
    if (escRValue != null) 'esc_r_value': escRValue,
    'print_mode': printMode,
  };

  static TurkishEncodingCandidate? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final encoding = json['encoding']?.toString().trim() ?? '';
    final codePage = PrinterEncodingSelection.tryParseCodePage(
      json['code_page']?.toString() ?? json['codepage']?.toString(),
    );
    if (encoding.isEmpty || codePage == null) return null;
    final escR = PrinterEncodingSelection.tryParseCodePage(
      json['esc_r_value']?.toString() ?? json['esc_r']?.toString(),
    );
    return TurkishEncodingCandidate(
      id: id,
      label: json['label']?.toString().trim().isNotEmpty == true
          ? json['label']!.toString().trim()
          : '$encoding / ESC t $codePage',
      encoding: encoding,
      codePage: codePage,
      escRValue: escR,
      printMode: json['print_mode']?.toString() ?? kTurkishPrintModeText,
    );
  }
}

List<TurkishEncodingCandidate> _buildCalibrationCandidates() {
  const groupA = <({String encoding, int codePage, String label})>[
    (encoding: 'cp857', codePage: 13, label: 'CP857 + ESC t 13'),
    (encoding: 'cp857', codePage: 29, label: 'CP857 + ESC t 29'),
    (encoding: 'cp857', codePage: 61, label: 'CP857 + ESC t 61'),
    (encoding: 'cp1254', codePage: 16, label: 'CP1254 + ESC t 16'),
    (encoding: 'cp1254', codePage: 21, label: 'CP1254 + ESC t 21'),
    (encoding: 'cp1254', codePage: 45, label: 'CP1254 + ESC t 45'),
    (encoding: 'iso-8859-9', codePage: 16, label: 'ISO-8859-9 + ESC t 16'),
    (encoding: 'iso-8859-9', codePage: 21, label: 'ISO-8859-9 + ESC t 21'),
    (encoding: 'cp850', codePage: 2, label: 'CP850 + ESC t 2'),
    (encoding: 'cp852', codePage: 18, label: 'CP852 + ESC t 18'),
  ];
  final candidates = <TurkishEncodingCandidate>[
    for (final entry in groupA)
      TurkishEncodingCandidate(
        id: '${entry.encoding.replaceAll('-', '')}_t${entry.codePage}',
        label: entry.label,
        encoding: entry.encoding,
        codePage: entry.codePage,
      ),
    for (final escR in const <int>[0, 12, 13])
      TurkishEncodingCandidate(
        id: 'cp857_t13_r$escR',
        label: 'CP857 + ESC t 13 + ESC R $escR',
        encoding: 'cp857',
        codePage: 13,
        escRValue: escR,
      ),
  ];
  return candidates;
}

final List<TurkishEncodingCandidate> kTurkishEncodingCalibrationCandidates =
    _buildCalibrationCandidates();

TurkishEncodingCandidate? turkishEncodingCandidateById(String? id) {
  final normalized = id?.trim() ?? '';
  if (normalized.isEmpty) return null;
  for (final candidate in kTurkishEncodingCalibrationCandidates) {
    if (candidate.id == normalized) return candidate;
  }
  return null;
}
