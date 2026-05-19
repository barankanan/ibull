import 'desktop_printer_setup_models.dart';

/// Windows spooler queue classification for operator UI (mirrors bridge profile).
class WindowsPrinterClassification {
  const WindowsPrinterClassification._();

  static final List<RegExp> _virtualGenericPatterns = <RegExp>[
    RegExp(r'\bfax\b', caseSensitive: false),
    RegExp(r'microsoft\s+print\s+to\s+pdf', caseSensitive: false),
    RegExp(r'\bpdf\b', caseSensitive: false),
    RegExp(r'onenote', caseSensitive: false),
    RegExp(r'\bxps\b', caseSensitive: false),
    RegExp(r'generic\s*/\s*text', caseSensitive: false),
    RegExp(r'generic\s+text\s+only', caseSensitive: false),
    RegExp(r'send\s+to\s+onenote', caseSensitive: false),
  ];

  static final List<RegExp> _genericTextPatterns = <RegExp>[
    RegExp(r'generic\s*/\s*text', caseSensitive: false),
    RegExp(r'generic\s+text\s+only', caseSensitive: false),
  ];

  static final List<RegExp> _posCandidatePatterns = <RegExp>[
    RegExp(r'\bpos\b', caseSensitive: false),
    RegExp(r'pos-', caseSensitive: false),
    RegExp(r'pos58', caseSensitive: false),
    RegExp(r'thermal', caseSensitive: false),
    RegExp(r'receipt', caseSensitive: false),
    RegExp(r'escpos', caseSensitive: false),
    RegExp(r'\b58\b', caseSensitive: false),
    RegExp(r'\b80\b', caseSensitive: false),
    RegExp(r'xp-', caseSensitive: false),
    RegExp(r'zj-', caseSensitive: false),
    RegExp(r'gp-', caseSensitive: false),
    RegExp(r'stmicroelectronics', caseSensitive: false),
  ];

  static WindowsPrinterProfile profileFor({
    required String name,
    String? driverName,
    String? portName,
    String? bridgeStatusLevel,
    String? bridgeStatusMessage,
    String? bridgeOperatorTier,
    String? bridgeWarningCode,
  }) {
    if (bridgeOperatorTier != null && bridgeOperatorTier.trim().isNotEmpty) {
      return WindowsPrinterProfile(
        operatorTier: bridgeOperatorTier.trim(),
        warningCode: bridgeWarningCode,
        isPosCandidate: bridgeOperatorTier == 'pos_candidate',
        recommended: bridgeOperatorTier == 'pos_candidate',
        statusLevel: bridgeStatusLevel ?? 'warning',
        statusMessage: bridgeStatusMessage ?? '',
        selectionWarning: _selectionWarningFor(bridgeWarningCode, name),
      );
    }

    final haystack =
        '${name.toLowerCase()} ${driverName?.toLowerCase() ?? ''} ${portName?.toLowerCase() ?? ''}';
    final baseLevel = bridgeStatusLevel ?? 'ready';
    final baseMessage = bridgeStatusMessage ?? 'Yazıcı hazır.';

    if (_matchesAny(_genericTextPatterns, haystack)) {
      return WindowsPrinterProfile(
        operatorTier: 'not_recommended',
        warningCode: 'generic_text_only',
        isPosCandidate: false,
        recommended: false,
        statusLevel: 'warning',
        statusMessage:
            'Bu hedef ESC/POS termal baskı için güvenilir değildir. '
            'Gerçek POS58 sürücüsü ve doğru USB portu kurulumu önerilir.',
        selectionWarning:
            'Generic / Text Only seçildi: Windows sınama sayfası anlamsız '
            'spool metinleri basabilir. POS58 driver kurun.',
      );
    }

    if (_matchesAny(_virtualGenericPatterns, haystack)) {
      return WindowsPrinterProfile(
        operatorTier: 'not_recommended',
        warningCode: 'not_recommended_target',
        isPosCandidate: false,
        recommended: false,
        statusLevel: 'warning',
        statusMessage:
            "'$name' sanal veya genel bir Windows hedefidir; "
            'adisyon/mutfak termal baskı için uygun değildir.',
        selectionWarning:
            'Fax, PDF, XPS, OneNote veya Generic hedefleri termal fiş için kullanılamaz.',
      );
    }

    if (_matchesAny(_posCandidatePatterns, haystack)) {
      return WindowsPrinterProfile(
        operatorTier: 'pos_candidate',
        warningCode: null,
        isPosCandidate: true,
        recommended: true,
        statusLevel: baseLevel == 'error' ? 'error' : 'ready',
        statusMessage: baseMessage,
      );
    }

    if (baseLevel == 'ready') {
      return WindowsPrinterProfile(
        operatorTier: 'normal',
        warningCode: 'verify_with_test_print',
        isPosCandidate: false,
        recommended: false,
        statusLevel: 'warning',
        statusMessage:
            'Windows yazıcıyı çevrimiçi görüyor; termal/POS uyumluluğu için '
            'test fişi ile doğrulayın.',
      );
    }

    return WindowsPrinterProfile(
      operatorTier: 'normal',
      warningCode: null,
      isPosCandidate: false,
      recommended: false,
      statusLevel: baseLevel,
      statusMessage: baseMessage,
    );
  }

  static bool isNotRecommended(UnifiedPrinterModel printer) {
    final tier =
        printer.raw['operatorTier']?.toString() ??
        profileFor(
          name: printer.queueName,
          driverName: printer.raw['driverName']?.toString(),
          portName: printer.raw['portName']?.toString(),
        ).operatorTier;
    return tier == 'not_recommended';
  }

  static bool isPosCandidate(UnifiedPrinterModel printer) {
    if (printer.raw['isPosCandidate'] == true) return true;
    return profileFor(name: printer.queueName).isPosCandidate;
  }

  static String? selectionWarningFor(UnifiedPrinterModel printer) {
    final fromRaw = printer.raw['selectionWarning']?.toString();
    if (fromRaw != null && fromRaw.trim().isNotEmpty) return fromRaw.trim();
    return profileFor(name: printer.queueName).selectionWarning;
  }

  static List<String> windowsPosSetupGuideSteps() => const <String>[
    'Windows Ayarlar > Yazıcılar > Yazdırma tercihleri > Windows korumalı yazdırma modunu kapatın.',
    'POS58 için üretici sürücüsünü kurun (Generic / Text Only yerine).',
    'Yazıcıyı USB001/USB002 yerine sürücünün gösterdiği doğru porta bağlayın.',
    'Windows sınama sayfası anlamsız kod/karakter basıyorsa sürücü veya port yanlıştır.',
    'Kurulumdan sonra uygulamada canlı taramayı yenileyin ve test fişi gönderin.',
  ];

  static String formatTestFailureDetails(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = <String>[
      if (_read(raw['error']).isNotEmpty) 'Hata: ${_read(raw['error'])}',
      if (_read(raw['errorCode']).isNotEmpty) 'Kod: ${_read(raw['errorCode'])}',
      if (_read(raw['printer_name'] ?? raw['selected_queue']).isNotEmpty)
        'Windows yazıcı: ${_read(raw['printer_name'] ?? raw['selected_queue'])}',
      if (_read(raw['job_id'] ?? raw['queue_job_id'] ?? raw['spool_latest_job_id'])
          .isNotEmpty)
        'Spool işi: ${_read(raw['job_id'] ?? raw['queue_job_id'] ?? raw['spool_latest_job_id'])}',
      if (raw['spool_jobs_after_print'] != null)
        'Spooler iş sayısı: ${raw['spool_jobs_after_print']}',
      if (raw['spool_active_job_ids'] is List &&
          (raw['spool_active_job_ids'] as List).isNotEmpty)
        'Aktif spool işleri: ${(raw['spool_active_job_ids'] as List).join(', ')}',
      if (raw['timeoutMs'] != null) 'Zaman aşımı: ${raw['timeoutMs']} ms',
      if (_read(raw['queue_status']).isNotEmpty)
        'Kuyruk durumu: ${_read(raw['queue_status'])}',
      if (raw['bytes_sent'] != null) 'Gönderilen bayt: ${raw['bytes_sent']}',
      if (raw['queue_has_active_job'] == true)
        'Spooler kuyruğunda aktif iş var.',
      if (_read(raw['physical_confirmation_message']).isNotEmpty)
        _read(raw['physical_confirmation_message']),
      if (_read(raw['transport_output']).isNotEmpty)
        'Transport: ${_read(raw['transport_output'])}',
      if (raw['pillow_available'] != null)
        'Pillow: ${raw['pillow_available'] == true ? 'kurulu' : 'yok'}',
      if (_read(raw['python_executable']).isNotEmpty)
        'Python: ${_read(raw['python_executable'])}',
      if (_read(raw['import_error']).isNotEmpty)
        'Pillow import: ${_read(raw['import_error'])}',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join('\n');
  }

  static String? _selectionWarningFor(String? warningCode, String name) {
    switch (warningCode) {
      case 'generic_text_only':
        return 'Generic / Text Only seçildi: ESC/POS termal baskı için güvenilir değildir.';
      case 'not_recommended_target':
        return "'$name' termal fiş için önerilmez.";
      default:
        return null;
    }
  }

  static bool _matchesAny(List<RegExp> patterns, String haystack) {
    for (final pattern in patterns) {
      if (pattern.hasMatch(haystack)) return true;
    }
    return false;
  }

  static String _read(Object? value) => value?.toString().trim() ?? '';
}

class WindowsPrinterProfile {
  const WindowsPrinterProfile({
    required this.operatorTier,
    required this.warningCode,
    required this.isPosCandidate,
    required this.recommended,
    required this.statusLevel,
    required this.statusMessage,
    this.selectionWarning,
  });

  final String operatorTier;
  final String? warningCode;
  final bool isPosCandidate;
  final bool recommended;
  final String statusLevel;
  final String statusMessage;
  final String? selectionWarning;

  Map<String, dynamic> toRawFields() => <String, dynamic>{
    'operatorTier': operatorTier,
    if (warningCode != null) 'warningCode': warningCode,
    'isPosCandidate': isPosCandidate,
    'recommended': recommended,
    if (selectionWarning != null) 'selectionWarning': selectionWarning,
  };
}
