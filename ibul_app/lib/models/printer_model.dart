/// Roles a printer can be assigned to.
enum PrinterRole {
  receipt, // Adisyon
  kitchen, // Mutfak / Ocak
  bakery, // Fırın
  bar, // Bar
  general; // Genel

  String get label {
    switch (this) {
      case receipt:
        return 'Adisyon';
      case kitchen:
        return 'Ocak';
      case bakery:
        return 'Fırın';
      case bar:
        return 'Bar';
      case general:
        return 'Genel';
    }
  }

  String get value {
    switch (this) {
      case receipt:
        return 'receipt';
      case kitchen:
        return 'kitchen';
      case bakery:
        return 'bakery';
      case bar:
        return 'bar';
      case general:
        return 'general';
    }
  }

  static PrinterRole fromValue(String v) {
    switch (v.trim().toLowerCase()) {
      case 'receipt':
        return receipt;
      case 'kitchen':
        return kitchen;
      case 'bakery':
        return bakery;
      case 'bar':
        return bar;
      default:
        return general;
    }
  }
}

/// Charset options supported by most ESC/POS thermal printers.
enum PrinterCharset {
  utf8,
  cp857, // Turkish
  cp1254, // Windows Turkish
  iso88599, // ISO-8859-9 / Latin-5 Turkish
  cp437; // IBM PC (US ASCII extended)

  String get label {
    switch (this) {
      case utf8:
        return 'UTF-8';
      case cp857:
        return 'CP857 (Türkçe)';
      case cp1254:
        return 'CP1254 (Win Türkçe)';
      case iso88599:
        return 'ISO-8859-9 (Latin-5)';
      case cp437:
        return 'CP437 (IBM ASCII)';
    }
  }

  String get value {
    switch (this) {
      case utf8:
        return 'utf8';
      case cp857:
        return 'cp857';
      case cp1254:
        return 'cp1254';
      case iso88599:
        return 'iso-8859-9';
      case cp437:
        return 'cp437';
    }
  }

  static PrinterCharset fromValue(String v) {
    switch (v.trim().toLowerCase()) {
      case 'cp857':
        return cp857;
      case 'cp1254':
        return cp1254;
      case 'iso88599':
      case 'iso-8859-9':
      case 'iso_8859_9':
      case 'latin5':
        return iso88599;
      case 'cp437':
        return cp437;
      default:
        return utf8;
    }
  }
}

class PrinterEncodingSelection {
  const PrinterEncodingSelection({
    required this.charset,
    required this.codePage,
    this.warning,
  });

  static const int defaultTurkishCodePage = 13;
  static const List<int> _commonTurkishCodePages = <int>[13, 9, 17, 19, 21];

  final PrinterCharset charset;
  final int? codePage;
  final String? warning;

  String get encoding => charset.value;
  bool get fallbackApplied => warning != null && warning!.isNotEmpty;

  Map<String, dynamic> toPayload({String prefix = ''}) {
    final normalizedPrefix = prefix.isEmpty ? '' : '${prefix}_';
    return <String, dynamic>{
      '${normalizedPrefix}encoding': encoding,
      '${normalizedPrefix}code_page': codePage,
    };
  }

  static int? tryParseCodePage(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  static PrinterEncodingSelection normalize({
    required PrinterCharset charset,
    int? codePage,
  }) {
    final normalizedCodePage = codePage != null && codePage >= 0
        ? codePage
        : null;

    if (charset == PrinterCharset.utf8) {
      return const PrinterEncodingSelection(
        charset: PrinterCharset.cp857,
        codePage: defaultTurkishCodePage,
        warning:
            'UTF-8 raw ESC/POS üzerinde güvenilir değil. Yazıcı profili CP857 + codepage 13 olarak korumaya alındı.',
      );
    }

    if (normalizedCodePage != null) {
      return PrinterEncodingSelection(
        charset: charset,
        codePage: normalizedCodePage,
      );
    }

    if (charset == PrinterCharset.cp857) {
      return const PrinterEncodingSelection(
        charset: PrinterCharset.cp857,
        codePage: defaultTurkishCodePage,
      );
    }

    if (charset == PrinterCharset.cp437) {
      return const PrinterEncodingSelection(
        charset: PrinterCharset.cp437,
        codePage: 0,
      );
    }

    return const PrinterEncodingSelection(
      charset: PrinterCharset.cp857,
      codePage: defaultTurkishCodePage,
      warning:
          'Seçilen encoding için açık bir codepage belirtilmedi. Yanlış karakter basımını önlemek için CP857 + codepage 13 kullanıldı.',
    );
  }

  static List<int> buildTurkishDiagnosticCodePages({int? preferredCodePage}) {
    final ordered = <int>[
      if (preferredCodePage != null && preferredCodePage >= 0)
        preferredCodePage,
      ..._commonTurkishCodePages,
    ];
    final seen = <int>{};
    return ordered.where((value) => seen.add(value)).toList(growable: false);
  }
}

class PrinterModel {
  const PrinterModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.code,
    required this.connectionType,
    this.ipAddress,
    this.port,
    this.deviceIdentifier,
    required this.paperWidthMm,
    required this.isActive,
    required this.createdAt,
    this.supportsCut = false,
    this.charset = PrinterCharset.cp857,
    this.codePage,
    this.assignedRoles = const [],
    this.lastTestPrintAt,
    this.lastError,
    this.testPrintStatus,
    this.printerProfileId,
  });

  static const String localConnectionType = 'local';
  static const String networkConnectionType = 'network';
  static const String usbConnectionType = 'usb';
  static const String bluetoothConnectionType = 'bluetooth';
  static const String localDefaultHost = '127.0.0.1';
  static const int localDefaultPort = 3001;
  static const int defaultPaperWidthMm = 80;
  static const String localReceiptRoute = '/print/receipt';
  static const String localKitchenRoute = '/print/kitchen';

  final String id;
  final String restaurantId;
  final String name;
  final String code;
  final String connectionType;
  final String? ipAddress;
  final int? port;
  final String? deviceIdentifier;
  final int paperWidthMm;
  final bool isActive;
  final DateTime createdAt;

  // ── Extended fields ──
  final bool supportsCut;
  final PrinterCharset charset;
  final int? codePage;
  final List<PrinterRole> assignedRoles;
  final DateTime? lastTestPrintAt;
  final String? lastError;

  /// 'ok' | 'failed' | 'pending' | null
  final String? testPrintStatus;

  /// ID referencing a [PrinterProfile]. Null for legacy records.
  final String? printerProfileId;

  String get _normalizedConnectionType => connectionType.trim().toLowerCase();

  String get _normalizedHost => ipAddress?.trim().toLowerCase() ?? '';

  bool get isLocalConnection {
    if (_normalizedConnectionType == localConnectionType) {
      return true;
    }
    if (_normalizedConnectionType != networkConnectionType &&
        _normalizedConnectionType.isNotEmpty) {
      return false;
    }
    final isLoopbackHost =
        _normalizedHost == localDefaultHost || _normalizedHost == 'localhost';
    return isLoopbackHost && (port ?? localDefaultPort) == localDefaultPort;
  }

  String get formConnectionType {
    if (isLocalConnection) {
      return localConnectionType;
    }
    if (_normalizedConnectionType.isEmpty) {
      return networkConnectionType;
    }
    return _normalizedConnectionType;
  }

  String get connectionTypeLabel {
    switch (formConnectionType) {
      case localConnectionType:
        return 'Local';
      case usbConnectionType:
        return 'USB';
      case bluetoothConnectionType:
        return 'Bluetooth';
      case networkConnectionType:
      default:
        return 'Network';
    }
  }

  String get logicalType {
    return formConnectionType;
  }

  PrinterEncodingSelection get encodingSelection =>
      PrinterEncodingSelection.normalize(charset: charset, codePage: codePage);

  String get encoding => encodingSelection.encoding;
  int? get resolvedCodePage => encodingSelection.codePage;

  String get resolvedHost {
    final host = ipAddress?.trim() ?? '';
    if (host.isNotEmpty) {
      return host;
    }
    return isLocalConnection ? localDefaultHost : '';
  }

  int? get resolvedPort {
    if (port != null && port! > 0) {
      return port;
    }
    if (isLocalConnection) {
      return localDefaultPort;
    }
    if (resolvedHost.isNotEmpty &&
        formConnectionType == networkConnectionType) {
      return 9100;
    }
    return null;
  }

  String get suggestedLocalRoute {
    final fingerprint =
        '${name.trim().toLowerCase()} ${code.trim().toLowerCase()}';
    final isKitchenRoute =
        fingerprint.contains('mutfak') || fingerprint.contains('kitchen');
    return isKitchenRoute ? localKitchenRoute : localReceiptRoute;
  }

  String get listSubtitle {
    final parts = <String>[connectionTypeLabel];
    if (isLocalConnection) {
      parts.add(targetHost);
      final route = targetRoute;
      if (route.isNotEmpty) {
        parts.add(route);
      }
      return parts.join(' • ');
    }

    final host = targetHost;
    if (host != '-') {
      parts.add(host);
    }
    final device = deviceIdentifier?.trim() ?? '';
    if (device.isNotEmpty) {
      parts.add(device);
    }
    return parts.join(' • ');
  }

  String get targetHost {
    final host = resolvedHost;
    final currentPort = resolvedPort;
    if (host.isEmpty) {
      return '-';
    }
    if (currentPort == null) {
      return host;
    }
    return '$host:$currentPort';
  }

  String get targetRoute {
    final normalizedConnection = connectionType.trim().toLowerCase();
    final candidate = deviceIdentifier?.trim() ?? '';
    if (candidate.startsWith('/')) {
      return candidate;
    }
    if (isLocalConnection || normalizedConnection == localConnectionType) {
      return suggestedLocalRoute;
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // Print config contract validation
  // ---------------------------------------------------------------------------

  /// Validates this printer's configuration against the print config contract.
  ///
  /// Contract:
  ///   device_identifier — physical CUPS queue name or device path (e.g. "/dev/usb/lp0").
  ///                       Must NOT be used as an HTTP route override.
  ///   targetRoute       — HTTP path to the local print bridge endpoint.
  ///                       Computed from device_identifier only when connection is local.
  ///   ipAddress/port    — network destination, used by the dispatcher for base URI.
  ///   connection_type   — drives all of the above; "local" is virtual (stored as "network").
  PrintConfigValidation get configValidation {
    final warnings = <String>[];
    final errors = <String>[];
    final devId = deviceIdentifier?.trim() ?? '';

    // device_identifier starts with "/print/" → almost certainly an HTTP route
    // stored in the wrong field.  HTTP route overrides belong in
    // printer_target_route (payload key), not in device_identifier.
    if (devId.startsWith('/print/') && !isLocalConnection) {
      warnings.add(
        'device_identifier="$devId" looks like an HTTP print route '
        'but connection_type="$connectionType" is not local. '
        'HTTP route overrides belong in printer_target_route; '
        'device_identifier should be a CUPS queue name or physical device path '
        '(e.g. "YAZICI_1", "/dev/usb/lp0").',
      );
    }

    // Local connection without an explicit device_identifier/route set.
    if (isLocalConnection && devId.isEmpty) {
      warnings.add(
        'Local connection has no device_identifier set. '
        'HTTP route will fall back to heuristic '
        '(suggestedLocalRoute=$suggestedLocalRoute).',
      );
    }

    // Network printer with no IP address.
    if (formConnectionType == networkConnectionType &&
        !isLocalConnection &&
        (ipAddress?.trim() ?? '').isEmpty) {
      errors.add(
        'Network printer "$name" has no ip_address configured. '
        'The dispatcher will fall back to 127.0.0.1:3001.',
      );
    }

    return PrintConfigValidation(warnings: warnings, errors: errors);
  }

  factory PrinterModel.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['assigned_roles'];
    final roles = <PrinterRole>[];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        roles.add(PrinterRole.fromValue(r.toString()));
      }
    } else if (rawRoles is String && rawRoles.isNotEmpty) {
      for (final r in rawRoles.split(',')) {
        roles.add(PrinterRole.fromValue(r.trim()));
      }
    }
    return PrinterModel(
      id: map['id']?.toString() ?? '',
      restaurantId: map['restaurant_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      connectionType: map['connection_type']?.toString() ?? 'network',
      ipAddress: map['ip_address']?.toString(),
      port: (map['port'] as num?)?.toInt(),
      deviceIdentifier: map['device_identifier']?.toString(),
      paperWidthMm: (map['paper_width_mm'] as num?)?.toInt() ?? 80,
      isActive: map['is_active'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      supportsCut: map['supports_cut'] == true,
      charset: PrinterCharset.fromValue(map['charset']?.toString() ?? ''),
      codePage:
          (map['code_page'] as num?)?.toInt() ??
          (map['codepage'] as num?)?.toInt(),
      assignedRoles: roles,
      lastTestPrintAt: map['last_test_print_at'] != null
          ? DateTime.tryParse(map['last_test_print_at'].toString())
          : null,
      lastError: map['last_error']?.toString(),
      testPrintStatus: map['test_print_status']?.toString(),
      printerProfileId: map['printer_profile_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'name': name,
      'code': code,
      'connection_type': connectionType,
      'ip_address': ipAddress,
      'port': port,
      'device_identifier': deviceIdentifier,
      'paper_width_mm': paperWidthMm,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'supports_cut': supportsCut,
      'charset': charset.value,
      'code_page': codePage,
      'assigned_roles': assignedRoles.map((r) => r.value).toList(),
      'last_test_print_at': lastTestPrintAt?.toIso8601String(),
      'last_error': lastError,
      'test_print_status': testPrintStatus,
      'printer_profile_id': printerProfileId,
    };
  }

  // ---------------------------------------------------------------------------
  // Config normalization helpers (single source of truth for callers)
  // ---------------------------------------------------------------------------

  /// Resolves the HTTP route for this printer.
  ///
  /// For local connections:
  ///   1. device_identifier if it starts with '/' (explicit override)
  ///   2. suggestedLocalRoute (heuristic based on name/code)
  /// For non-local connections: always returns '' (no HTTP route; transport
  /// uses raw TCP/USB).
  ///
  /// NOTE: For HTTP route overrides in print_job payloads use printer_target_route,
  /// not device_identifier.
  String resolveHttpRoute() => targetRoute;

  /// Resolves the network base URI for this printer.
  Uri resolveBaseUri() => Uri(
    scheme: 'http',
    host: resolvedHost.isEmpty ? PrinterModel.localDefaultHost : resolvedHost,
    port: resolvedPort ?? PrinterModel.localDefaultPort,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrinterModel) return false;
    return id == other.id &&
        restaurantId == other.restaurantId &&
        name == other.name &&
        code == other.code &&
        connectionType == other.connectionType &&
        ipAddress == other.ipAddress &&
        port == other.port &&
        deviceIdentifier == other.deviceIdentifier &&
        paperWidthMm == other.paperWidthMm &&
        isActive == other.isActive &&
        createdAt == other.createdAt &&
        supportsCut == other.supportsCut &&
        charset == other.charset &&
        codePage == other.codePage &&
        _listEquals(assignedRoles, other.assignedRoles) &&
        lastTestPrintAt == other.lastTestPrintAt &&
        lastError == other.lastError &&
        testPrintStatus == other.testPrintStatus &&
        printerProfileId == other.printerProfileId;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    restaurantId,
    name,
    code,
    connectionType,
    ipAddress,
    port,
    deviceIdentifier,
    paperWidthMm,
    isActive,
    createdAt,
    supportsCut,
    charset,
    codePage,
    Object.hashAll(assignedRoles),
    lastTestPrintAt,
    lastError,
    testPrintStatus,
    printerProfileId,
  ]);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  PrinterModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? code,
    String? connectionType,
    String? ipAddress,
    int? port,
    String? deviceIdentifier,
    int? paperWidthMm,
    bool? isActive,
    DateTime? createdAt,
    bool? supportsCut,
    PrinterCharset? charset,
    int? codePage,
    List<PrinterRole>? assignedRoles,
    DateTime? lastTestPrintAt,
    String? lastError,
    String? testPrintStatus,
    String? printerProfileId,
  }) {
    return PrinterModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      code: code ?? this.code,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      supportsCut: supportsCut ?? this.supportsCut,
      charset: charset ?? this.charset,
      codePage: codePage ?? this.codePage,
      assignedRoles: assignedRoles ?? this.assignedRoles,
      lastTestPrintAt: lastTestPrintAt ?? this.lastTestPrintAt,
      lastError: lastError ?? this.lastError,
      testPrintStatus: testPrintStatus ?? this.testPrintStatus,
      printerProfileId: printerProfileId ?? this.printerProfileId,
    );
  }
}

// ---------------------------------------------------------------------------
// Print Config Contract
// ---------------------------------------------------------------------------
//
// Field responsibility matrix:
//
// ┌──────────────────────────┬────────────────────────────────────────────────┐
// │ Field                    │ Responsibility                                 │
// ├──────────────────────────┼────────────────────────────────────────────────┤
// │ device_identifier        │ Physical device: CUPS queue name or device     │
// │ (DB column)              │ path (e.g. "/dev/usb/lp0"). MUST NOT be used   │
// │                          │ as an HTTP route. HTTP routes belong in        │
// │                          │ printer_target_route.                          │
// ├──────────────────────────┼────────────────────────────────────────────────┤
// │ printer_target_route     │ HTTP path override for the local print bridge  │
// │ (payload JSON key)       │ (e.g. "/print/kitchen", "/print/receipt").     │
// │                          │ Written into print_job.payload by the SQL RPC. │
// ├──────────────────────────┼────────────────────────────────────────────────┤
// │ ip_address / port        │ Network destination for the print bridge or    │
// │ (DB columns)             │ for direct TCP/IP printers.                    │
// ├──────────────────────────┼────────────────────────────────────────────────┤
// │ connection_type          │ Transport behaviour selector:                  │
// │ (DB column)              │   "network" → TCP/IP + optional local bridge   │
// │                          │   "usb"     → USB/device path                 │
// │                          │   "bluetooth" → BT                            │
// │                          │   "local"   → virtual alias; stored as        │
// │                          │               "network" with 127.0.0.1:3001   │
// └──────────────────────────┴────────────────────────────────────────────────┘

/// Result of validating a printer's configuration against the contract.
class PrintConfigValidation {
  const PrintConfigValidation({required this.warnings, required this.errors});

  /// Suspicious but potentially non-fatal issues.
  final List<String> warnings;

  /// Definite misconfigurations that will cause print failures.
  final List<String> errors;

  bool get isValid => errors.isEmpty;
  bool get hasSuspicions => warnings.isNotEmpty || errors.isNotEmpty;

  @override
  String toString() {
    if (!hasSuspicions) return 'PrintConfigValidation(ok)';
    final parts = <String>[];
    if (errors.isNotEmpty) parts.add('errors=[${errors.join("; ")}]');
    if (warnings.isNotEmpty) parts.add('warnings=[${warnings.join("; ")}]');
    return 'PrintConfigValidation(${parts.join(", ")})';
  }
}
