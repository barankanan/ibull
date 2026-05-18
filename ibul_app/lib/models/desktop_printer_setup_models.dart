import 'dart:convert';

import 'windows_printer_classification.dart';

enum DesktopPrinterBackend {
  usbDirect('usb-direct'),
  cups('cups'),
  windowsSpool('windows-spool');

  const DesktopPrinterBackend(this.value);

  final String value;

  static DesktopPrinterBackend fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'usb':
      case 'usb-direct':
        return DesktopPrinterBackend.usbDirect;
      case 'windows':
      case 'windows-spool':
        return DesktopPrinterBackend.windowsSpool;
      case 'cups':
      default:
        return DesktopPrinterBackend.cups;
    }
  }
}

enum DesktopPrinterOs {
  macos('macos'),
  windows('windows');

  const DesktopPrinterOs(this.value);

  final String value;

  static DesktopPrinterOs fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'windows':
        return DesktopPrinterOs.windows;
      case 'macos':
      default:
        return DesktopPrinterOs.macos;
    }
  }
}

enum PrinterSetupRole {
  adisyon('adisyon'),
  mutfak('mutfak');

  const PrinterSetupRole(this.value);

  final String value;

  String get label {
    switch (this) {
      case PrinterSetupRole.adisyon:
        return 'Adisyon Yazicisi';
      case PrinterSetupRole.mutfak:
        return 'Mutfak Yazicisi';
    }
  }
}

class UnifiedPrinterModel {
  const UnifiedPrinterModel({
    required this.id,
    required this.displayName,
    required this.queueName,
    required this.backend,
    required this.os,
    required this.isAvailable,
    required this.canPrint,
    this.lastTestStatus,
    this.lastError,
    this.vendorId,
    this.productId,
    this.printerRecordId,
    this.statusLevel,
    this.statusMessage,
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final String displayName;
  final String queueName;
  final DesktopPrinterBackend backend;
  final DesktopPrinterOs os;
  final bool isAvailable;
  final bool canPrint;
  final String? lastTestStatus;
  final String? lastError;
  final String? vendorId;
  final String? productId;
  final String? printerRecordId;
  final String? statusLevel;
  final String? statusMessage;
  final Map<String, dynamic> raw;

  bool get prefersUsbDirect => backend == DesktopPrinterBackend.usbDirect;

  /// True when the printer came from a live bridge scan (/printers or /discover).
  bool get isLiveDiscovery => raw['source']?.toString() != 'saved_record';

  /// Saved DB mapping with no matching live bridge printer on this machine.
  bool get isStaleSavedMapping => !isLiveDiscovery;

  UnifiedPrinterModel copyWith({
    String? lastTestStatus,
    String? lastError,
    bool? isAvailable,
    bool? canPrint,
    String? printerRecordId,
  }) {
    return UnifiedPrinterModel(
      id: id,
      displayName: displayName,
      queueName: queueName,
      backend: backend,
      os: os,
      isAvailable: isAvailable ?? this.isAvailable,
      canPrint: canPrint ?? this.canPrint,
      lastTestStatus: lastTestStatus ?? this.lastTestStatus,
      lastError: lastError ?? this.lastError,
      vendorId: vendorId,
      productId: productId,
      printerRecordId: printerRecordId ?? this.printerRecordId,
      statusLevel: statusLevel,
      statusMessage: statusMessage,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'name': displayName,
      'queueName': queueName,
      'queue': queueName,
      'backend': backend.value,
      'transportType': backend.value,
      'os': os.value,
      'isAvailable': isAvailable,
      'canPrint': canPrint,
      'lastTestStatus': lastTestStatus,
      'lastError': lastError,
      'vendorId': vendorId,
      'productId': productId,
      'printerRecordId': printerRecordId,
      'printer_record_id': printerRecordId,
      'deviceIdentifier':
          raw['deviceIdentifier']?.toString() ??
          raw['device_identifier']?.toString(),
      'device_identifier':
          raw['device_identifier']?.toString() ??
          raw['deviceIdentifier']?.toString(),
      'statusLevel': statusLevel,
      'statusMessage': statusMessage,
      'raw': raw,
    };
  }

  factory UnifiedPrinterModel.fromJson(Map<String, dynamic> json) {
    return UnifiedPrinterModel(
      id: json['id']?.toString() ?? '',
      displayName:
          json['displayName']?.toString() ?? json['name']?.toString() ?? '',
      queueName:
          json['queueName']?.toString() ?? json['queue']?.toString() ?? '',
      backend: DesktopPrinterBackend.fromValue(json['backend']?.toString()),
      os: DesktopPrinterOs.fromValue(json['os']?.toString()),
      isAvailable: json['isAvailable'] == true,
      canPrint: json['canPrint'] == true,
      lastTestStatus: json['lastTestStatus']?.toString(),
      lastError: json['lastError']?.toString(),
      vendorId: json['vendorId']?.toString(),
      productId: json['productId']?.toString(),
      printerRecordId:
          json['printerRecordId']?.toString() ??
          json['printer_record_id']?.toString(),
      statusLevel: json['statusLevel']?.toString(),
      statusMessage: json['statusMessage']?.toString(),
      raw: json['raw'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['raw'] as Map<String, dynamic>)
          : (json['raw'] is Map
                ? Map<String, dynamic>.from(json['raw'] as Map)
                : const <String, dynamic>{}),
    );
  }

  factory UnifiedPrinterModel.fromBridgeMap(
    Map<String, dynamic> printer, {
    required DesktopPrinterOs os,
  }) {
    final normalizedRaw = <String, dynamic>{
      ...printer,
      'source': printer['source']?.toString() ?? 'usb_scan',
    };
    final backend = DesktopPrinterBackend.fromValue(
      normalizedRaw['backend']?.toString(),
    );
    final queueName =
        (normalizedRaw['queue']?.toString().trim().isNotEmpty ?? false)
        ? normalizedRaw['queue']!.toString().trim()
        : (normalizedRaw['name']?.toString().trim().isNotEmpty ?? false)
        ? normalizedRaw['name']!.toString().trim()
        : normalizedRaw['id']?.toString() ?? 'printer';
    var statusLevel =
        normalizedRaw['statusLevel']?.toString().trim().toLowerCase() ?? 'ready';
    var statusMessage = normalizedRaw['statusMessage']?.toString();
    final ready = normalizedRaw['ready'] != false;
    var isAvailable = statusLevel != 'error' && ready;
    var canPrint = os == DesktopPrinterOs.windows
        ? statusLevel == 'ready' && ready
        : ready && statusLevel != 'error';

    if (os == DesktopPrinterOs.windows) {
      final profile = WindowsPrinterClassification.profileFor(
        name: queueName,
        driverName: normalizedRaw['driverName']?.toString(),
        portName: normalizedRaw['portName']?.toString(),
        bridgeStatusLevel: statusLevel,
        bridgeStatusMessage: statusMessage,
        bridgeOperatorTier: normalizedRaw['operatorTier']?.toString(),
        bridgeWarningCode: normalizedRaw['warningCode']?.toString(),
      );
      normalizedRaw.addAll(profile.toRawFields());
      statusLevel = profile.statusLevel;
      statusMessage = profile.statusMessage;
      isAvailable = statusLevel != 'error';
      canPrint =
          profile.operatorTier == 'pos_candidate' && statusLevel == 'ready';
      if (profile.operatorTier == 'not_recommended') {
        canPrint = false;
      }
    }

    return UnifiedPrinterModel(
      id: normalizedRaw['id']?.toString() ?? '$backend:$queueName',
      displayName: normalizedRaw['name']?.toString() ?? queueName,
      queueName: queueName,
      backend: backend,
      os: os,
      isAvailable: isAvailable,
      canPrint: canPrint,
      lastTestStatus: normalizedRaw['lastTestStatus']?.toString(),
      lastError: normalizedRaw['lastError']?.toString(),
      vendorId:
          normalizedRaw['vendorId']?.toString() ??
          normalizedRaw['vid']?.toString(),
      productId:
          normalizedRaw['productId']?.toString() ??
          normalizedRaw['pid']?.toString(),
      printerRecordId:
          normalizedRaw['printerRecordId']?.toString() ??
          normalizedRaw['printer_record_id']?.toString(),
      statusLevel: statusLevel,
      statusMessage: statusMessage,
      raw: normalizedRaw,
    );
  }
}

class PrinterRoleSelection {
  const PrinterRoleSelection({required this.role, required this.printer});

  final PrinterSetupRole role;
  final UnifiedPrinterModel printer;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'role': role.value, 'printer': printer.toJson()};
  }

  factory PrinterRoleSelection.fromJson(Map<String, dynamic> json) {
    return PrinterRoleSelection(
      role: (json['role']?.toString() ?? '').trim().toLowerCase() == 'mutfak'
          ? PrinterSetupRole.mutfak
          : PrinterSetupRole.adisyon,
      printer: UnifiedPrinterModel.fromJson(
        json['printer'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['printer'] as Map<String, dynamic>)
            : Map<String, dynamic>.from(json['printer'] as Map),
      ),
    );
  }
}

class PrinterTestRecord {
  const PrinterTestRecord({
    required this.role,
    required this.printerId,
    this.printerRecordId,
    required this.success,
    required this.status,
    required this.message,
    required this.testedAt,
  });

  final PrinterSetupRole role;
  final String printerId;
  final String? printerRecordId;
  final bool success;
  final String status;
  final String message;
  final DateTime testedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role.value,
      'printerId': printerId,
      if (printerRecordId != null && printerRecordId!.isNotEmpty)
        'printerRecordId': printerRecordId,
      'success': success,
      'status': status,
      'message': message,
      'testedAt': testedAt.toIso8601String(),
    };
  }

  factory PrinterTestRecord.fromJson(Map<String, dynamic> json) {
    return PrinterTestRecord(
      role: (json['role']?.toString() ?? '').trim().toLowerCase() == 'mutfak'
          ? PrinterSetupRole.mutfak
          : PrinterSetupRole.adisyon,
      printerId: json['printerId']?.toString() ?? '',
      printerRecordId: json['printerRecordId']?.toString() ??
          json['printer_record_id']?.toString(),
      success: json['success'] == true,
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      testedAt:
          DateTime.tryParse(json['testedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PrinterSetupLocalConfig {
  const PrinterSetupLocalConfig({
    required this.restaurantId,
    required this.os,
    this.receiptSelection,
    this.kitchenSelection,
    this.receiptTest,
    this.kitchenTest,
    this.savedAt,
    this.lastCloudWarning,
    this.thisDeviceIsPrintStation = false,
  });

  final String restaurantId;
  final DesktopPrinterOs os;
  final PrinterRoleSelection? receiptSelection;
  final PrinterRoleSelection? kitchenSelection;
  final PrinterTestRecord? receiptTest;
  final PrinterTestRecord? kitchenTest;
  final DateTime? savedAt;
  final String? lastCloudWarning;
  final bool thisDeviceIsPrintStation;

  PrinterRoleSelection? selectionForRole(PrinterSetupRole role) {
    switch (role) {
      case PrinterSetupRole.adisyon:
        return receiptSelection;
      case PrinterSetupRole.mutfak:
        return kitchenSelection;
    }
  }

  PrinterTestRecord? testForRole(PrinterSetupRole role) {
    switch (role) {
      case PrinterSetupRole.adisyon:
        return receiptTest;
      case PrinterSetupRole.mutfak:
        return kitchenTest;
    }
  }

  PrinterSetupLocalConfig copyWith({
    PrinterRoleSelection? receiptSelection,
    PrinterRoleSelection? kitchenSelection,
    PrinterTestRecord? receiptTest,
    PrinterTestRecord? kitchenTest,
    DateTime? savedAt,
    String? lastCloudWarning,
    bool? thisDeviceIsPrintStation,
  }) {
    return PrinterSetupLocalConfig(
      restaurantId: restaurantId,
      os: os,
      receiptSelection: receiptSelection ?? this.receiptSelection,
      kitchenSelection: kitchenSelection ?? this.kitchenSelection,
      receiptTest: receiptTest ?? this.receiptTest,
      kitchenTest: kitchenTest ?? this.kitchenTest,
      savedAt: savedAt ?? this.savedAt,
      lastCloudWarning: lastCloudWarning ?? this.lastCloudWarning,
      thisDeviceIsPrintStation:
          thisDeviceIsPrintStation ?? this.thisDeviceIsPrintStation,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'restaurantId': restaurantId,
      'os': os.value,
      'receiptSelection': receiptSelection?.toJson(),
      'kitchenSelection': kitchenSelection?.toJson(),
      'receiptTest': receiptTest?.toJson(),
      'kitchenTest': kitchenTest?.toJson(),
      'savedAt': savedAt?.toIso8601String(),
      'lastCloudWarning': lastCloudWarning,
      'thisDeviceIsPrintStation': thisDeviceIsPrintStation,
    };
  }

  String encode() => jsonEncode(toJson());

  factory PrinterSetupLocalConfig.fromJson(Map<String, dynamic> json) {
    return PrinterSetupLocalConfig(
      restaurantId: json['restaurantId']?.toString() ?? '',
      os: DesktopPrinterOs.fromValue(json['os']?.toString()),
      receiptSelection: json['receiptSelection'] is Map
          ? PrinterRoleSelection.fromJson(
              Map<String, dynamic>.from(json['receiptSelection'] as Map),
            )
          : null,
      kitchenSelection: json['kitchenSelection'] is Map
          ? PrinterRoleSelection.fromJson(
              Map<String, dynamic>.from(json['kitchenSelection'] as Map),
            )
          : null,
      receiptTest: json['receiptTest'] is Map
          ? PrinterTestRecord.fromJson(
              Map<String, dynamic>.from(json['receiptTest'] as Map),
            )
          : null,
      kitchenTest: json['kitchenTest'] is Map
          ? PrinterTestRecord.fromJson(
              Map<String, dynamic>.from(json['kitchenTest'] as Map),
            )
          : null,
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? ''),
      lastCloudWarning: json['lastCloudWarning']?.toString(),
      thisDeviceIsPrintStation: json['thisDeviceIsPrintStation'] == true,
    );
  }

  factory PrinterSetupLocalConfig.decode(String raw) {
    return PrinterSetupLocalConfig.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}

class PrinterSetupStepStatus {
  const PrinterSetupStepStatus({
    required this.stepNumber,
    required this.label,
    required this.isReady,
    required this.statusKey,
  });

  final int stepNumber;
  final String label;
  final bool isReady;
  final String statusKey;
}

class PrinterSetupSnapshot {
  const PrinterSetupSnapshot({
    required this.os,
    required this.bridgeReachable,
    required this.bridgeHealthy,
    this.bridgeHealth,
    required this.printers,
    required this.steps,
    this.localConfig,
    this.remoteConfig,
    this.queueStatus,
    this.setupStatus,
    this.prerequisites,
    this.discoveryWarning,
    this.workingPrinter,
    this.bridgeStatusLabel = '',
  });

  final DesktopPrinterOs os;
  final bool bridgeReachable;
  final bool bridgeHealthy;
  final Map<String, dynamic>? bridgeHealth;
  final List<UnifiedPrinterModel> printers;
  final List<PrinterSetupStepStatus> steps;
  final PrinterSetupLocalConfig? localConfig;
  final Map<String, dynamic>? remoteConfig;
  final Map<String, dynamic>? queueStatus;
  final Map<String, dynamic>? setupStatus;
  final Map<String, dynamic>? prerequisites;
  final String? discoveryWarning;
  final UnifiedPrinterModel? workingPrinter;
  final String bridgeStatusLabel;

  bool get allRequiredValidationsPass =>
      steps.every((step) => step.isReady == true);

  String? get selectedReceiptPrinterId =>
      localConfig?.receiptSelection?.printer.id ??
      localConfig?.receiptSelection?.printer.printerRecordId;

  String? get selectedKitchenPrinterId =>
      localConfig?.kitchenSelection?.printer.id ??
      localConfig?.kitchenSelection?.printer.printerRecordId;

  String? get selectedReceiptPrinterRecordId =>
      localConfig?.receiptSelection?.printer.printerRecordId ??
      localConfig?.receiptSelection?.printer.id;

  String? get selectedKitchenPrinterRecordId =>
      localConfig?.kitchenSelection?.printer.printerRecordId ??
      localConfig?.kitchenSelection?.printer.id;

  List<UnifiedPrinterModel> get livePrinters =>
      printers.where((printer) => printer.isLiveDiscovery).toList(growable: false);

  List<UnifiedPrinterModel> get stalePrinters =>
      printers.where((printer) => printer.isStaleSavedMapping).toList(growable: false);

  int get livePrinterCount => livePrinters.length;

  /// Operator-facing setup status derived from /health + /printers (same as Yazıcı Merkezi).
  String get operatorSetupStatusKey => bridgeOperatorSetupStatusKey(
    bridgeReachable: bridgeReachable,
    bridgeHealthy: bridgeHealthy,
    livePrinterCount: livePrinterCount,
  );

  String get operatorSetupMessage => bridgeOperatorSetupMessage(
    bridgeReachable: bridgeReachable,
    bridgeHealthy: bridgeHealthy,
    livePrinterCount: livePrinterCount,
    bridgeHealth: bridgeHealth,
  );

  Map<String, dynamic> buildOperatorSetupStatus() {
    return buildBridgeOperatorSetupStatus(
      bridgeReachable: bridgeReachable,
      bridgeHealthy: bridgeHealthy,
      livePrinterCount: livePrinterCount,
      bridgeHealth: bridgeHealth,
    );
  }
}

/// Result of probing /health and /printers — single source for all printer UIs.
class BridgeRuntimeSnapshot {
  const BridgeRuntimeSnapshot({
    required this.reachable,
    required this.healthy,
    this.health,
    this.printersPayload,
    this.livePrinters = const <UnifiedPrinterModel>[],
    this.probeError,
  });

  final bool reachable;
  final bool healthy;
  final Map<String, dynamic>? health;
  final Map<String, dynamic>? printersPayload;
  final List<UnifiedPrinterModel> livePrinters;
  final String? probeError;

  int get livePrinterCount => livePrinters.length;
}

/// Bridge process identity from GET /health — helps spot stale bridge instances.
String formatBridgeProcessIdentity(Map<String, dynamic>? health) {
  if (health == null || health.isEmpty) return '';
  final build = health['build'];
  final buildMap = build is Map
      ? Map<String, dynamic>.from(build)
      : const <String, dynamic>{};
  final parts = <String>[
    if (_bridgeIdentityRead(buildMap['build_time']).isNotEmpty)
      'build_time=${_bridgeIdentityRead(buildMap['build_time'])}',
    if (_bridgeIdentityRead(buildMap['git_commit']).isNotEmpty)
      'commit=${_bridgeIdentityRead(buildMap['git_commit'])}',
    if (_bridgeIdentityRead(
      health['python_executable'] ?? buildMap['python_executable'],
    ).isNotEmpty)
      'python=${_bridgeIdentityRead(health['python_executable'] ?? buildMap['python_executable'])}',
    if (health['pillow_available'] != null)
      'pillow=${health['pillow_available'] == true}',
    if (_bridgeIdentityRead(health['pillow_import_error']).isNotEmpty)
      'pillow_error=${_bridgeIdentityRead(health['pillow_import_error'])}',
  ];
  return parts.join(' · ');
}

String _bridgeIdentityRead(Object? value) => value?.toString().trim() ?? '';

String bridgeOperatorSetupStatusKey({
  required bool bridgeReachable,
  required bool bridgeHealthy,
  int livePrinterCount = 0,
}) {
  if (!bridgeReachable) return 'bridge_not_running';
  if (bridgeHealthy || livePrinterCount > 0) return 'ready';
  return 'running_unhealthy';
}

/// True when a printer is eligible for role assignment or test print.
bool isSelectableLivePrinter(UnifiedPrinterModel printer) {
  if (!printer.isLiveDiscovery || !printer.isAvailable) return false;
  if (printer.os == DesktopPrinterOs.windows &&
      WindowsPrinterClassification.isNotRecommended(printer)) {
    return false;
  }
  return printer.canPrint;
}

String bridgeOperatorSetupMessage({
  required bool bridgeReachable,
  required bool bridgeHealthy,
  required int livePrinterCount,
  Map<String, dynamic>? bridgeHealth,
}) {
  if (!bridgeReachable) {
    return 'Yazıcı servisine ulaşılamadı. "Servisi Başlat" veya "Servisi Onar" ile yazıcı köprüsünü açın.';
  }
  if (livePrinterCount == 0) {
    return 'Yazıcı bulunamadı. Lütfen Windows\'ta yazıcı sürücüsünü kurun ve sınama sayfası basın.';
  }
  if (bridgeHealthy) {
    return 'Yazıcı servisi hazır. $livePrinterCount yazıcı bulundu.';
  }
  final details = bridgeHealth?['printer']?['details']?.toString().trim();
  if (details != null && details.isNotEmpty) {
    return 'Bridge yanıt veriyor ancak yazıcı doğrulaması tamamlanamadı: $details';
  }
  return 'Bridge yanıt veriyor ancak yazıcı doğrulaması tamamlanamadı.';
}

Map<String, dynamic> buildBridgeOperatorSetupStatus({
  required bool bridgeReachable,
  required bool bridgeHealthy,
  required int livePrinterCount,
  Map<String, dynamic>? bridgeHealth,
}) {
  final statusKey = bridgeOperatorSetupStatusKey(
    bridgeReachable: bridgeReachable,
    bridgeHealthy: bridgeHealthy,
    livePrinterCount: livePrinterCount,
  );
  final operatorOk = bridgeReachable && (bridgeHealthy || livePrinterCount > 0);
  return <String, dynamic>{
    'ok': operatorOk,
    'step': 'system_check',
    'status': statusKey,
    'message': bridgeOperatorSetupMessage(
      bridgeReachable: bridgeReachable,
      bridgeHealthy: bridgeHealthy,
      livePrinterCount: livePrinterCount,
      bridgeHealth: bridgeHealth,
    ),
    'errorCode': statusKey == 'ready' ? null : statusKey,
    'actionRequired': switch (statusKey) {
      'bridge_not_running' => 'start_bridge',
      'running_unhealthy' => 'detect_printer',
      _ => 'detect_printer',
    },
    'bridgeReachable': bridgeReachable,
    'bridgeHealthy': bridgeHealthy,
    'livePrinterCount': livePrinterCount,
    'checks': <Map<String, dynamic>>[
      <String, dynamic>{
        'label': 'Bridge çalışıyor',
        'ok': bridgeReachable,
        'status': bridgeReachable ? 'ready' : 'bridge_not_running',
        'message': bridgeReachable
            ? 'Yazıcı servisi açık (GET /health).'
            : 'Yazıcı servisi kapalı veya yanıt vermiyor.',
      },
      <String, dynamic>{
        'label': 'Bridge sağlıklı',
        'ok': bridgeHealthy,
        'status': bridgeHealthy ? 'ready' : 'running_unhealthy',
        'message': bridgeHealthy
            ? 'Sağlık kontrolü başarılı.'
            : 'Bridge yanıt veriyor ancak yazıcı hazır değil.',
      },
      <String, dynamic>{
        'label': 'Yazıcı listesi (/printers)',
        'ok': livePrinterCount > 0,
        'status': livePrinterCount > 0 ? 'ready' : 'setup_required',
        'message': livePrinterCount > 0
            ? '$livePrinterCount yazıcı bulundu.'
            : 'Yazıcı bulunamadı. Lütfen Windows\'ta yazıcı sürücüsünü kurun ve sınama sayfası basın.',
      },
    ],
  };
}

class PrinterActionResult {
  const PrinterActionResult({
    required this.ok,
    required this.status,
    required this.message,
    this.technicalMessage,
    this.printer,
    this.raw,
    this.localSaved = false,
    this.cloudSaved = false,
  });

  final bool ok;
  final String status;
  final String message;
  final String? technicalMessage;
  final UnifiedPrinterModel? printer;
  final Map<String, dynamic>? raw;
  final bool localSaved;
  final bool cloudSaved;
}
