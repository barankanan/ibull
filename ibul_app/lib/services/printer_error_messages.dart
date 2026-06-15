import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

import '../widgets/bridge_error_dialog.dart';

enum PrinterErrorSeverity { info, warning, error }

class PrinterErrorPresentation {
  const PrinterErrorPresentation({
    required this.code,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.secondaryActionLabel,
    this.severity = PrinterErrorSeverity.error,
    this.canRetry = true,
    this.canClearQueue = false,
    this.canOpenLogs = false,
    this.canDownloadInstaller = false,
  });

  final String code;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final String? secondaryActionLabel;
  final PrinterErrorSeverity severity;
  final bool canRetry;
  final bool canClearQueue;
  final bool canOpenLogs;
  final bool canDownloadInstaller;
}

/// Structured Ethernet setup diagnostics returned by bridge TCP probe /
/// network preflight and rendered in the operator dialog.
class EthernetConnectionDiagnostic {
  const EthernetConnectionDiagnostic({
    required this.ok,
    required this.errorCode,
    required this.title,
    required this.message,
    this.technicalDetail,
    this.host = '',
    this.port = 9100,
    this.localIps = const <String>[],
    this.sameSubnet,
    this.reachable,
    this.portOpen,
    this.guidanceSteps = const <String>[],
    this.networkHint = '',
  });

  final bool ok;
  final String errorCode;
  final String title;
  final String message;
  final String? technicalDetail;
  final String host;
  final int port;
  final List<String> localIps;
  final bool? sameSubnet;
  final bool? reachable;
  final bool? portOpen;
  final List<String> guidanceSteps;
  final String networkHint;

  String get primaryLocalIp =>
      localIps.isNotEmpty ? localIps.first : 'Algılanamadı';

  String get connectionStatusLabel {
    if (ok) return 'Hazır';
    if (errorCode == 'not_tested') return 'Test edilmedi';
    return 'Bağlantı doğrulanmadı';
  }

  bool get hasNetworkMismatch =>
      sameSubnet == false || errorCode == 'network_mismatch';
}

/// Shown when the operator tries to print before a successful connection test.
const String ethernetPrintBlockedWithoutConnectionMessage =
    'Önce bağlantıyı doğrulayın. Yazıcıya ulaşılamadığı için test fişi gönderilemez.';

/// Operator help steps shown inside the Ethernet setup dialog.
List<String> ethernetPrinterIpHelpSteps() {
  return const <String>[
    'Yazıcının IP adresini self-test fişinden öğrenin: FEED tuşuna 3–5 saniye '
        'basılı tutarak ağ bilgisi fişi alın.',
    'Yazıcıyı modeme veya switch\'e Ethernet kablosu ile bağlayın; '
        'bilgisayarla aynı LAN/Wi‑Fi ağında olmalıdır.',
    'Mümkünse router yönetim panelinden yazıcı için DHCP reservation '
        '(sabit IP) tanımlayın — IP değişince yazdırma kesilmez.',
    'Sunucu portu çoğu ESC/POS yazıcıda 9100\'dür; self-test fişindeki '
        'değeri kullanın.',
    '"Otomatik Tara" ile aynı ağdaki yazıcıları bulabilir; bulunamazsa '
        'self-test fişindeki IP\'yi manuel girin.',
  ];
}

/// A TCP printer discovered during an automatic subnet scan.
class EthernetDiscoveredDevice {
  const EthernetDiscoveredDevice({
    required this.host,
    required this.port,
    this.reachable = false,
    this.portOpen = false,
    this.sameSubnet,
    this.subnet,
    this.networkHint = '',
  });

  final String host;
  final int port;
  final bool reachable;
  final bool portOpen;
  final bool? sameSubnet;
  final String? subnet;
  final String networkHint;

  String get endpointLabel => '$host:$port';

  String get reachabilityLabel {
    if (reachable && portOpen) return 'Ulaşılabilir';
    if (portOpen) return 'Port açık';
    return 'Yanıt yok';
  }

  factory EthernetDiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return EthernetDiscoveredDevice(
      host: json['host']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 9100,
      reachable: json['reachable'] == true,
      portOpen: json['port_open'] == true || json['portOpen'] == true,
      sameSubnet: json['same_subnet'] is bool
          ? json['same_subnet'] as bool
          : (json['sameSubnet'] is bool ? json['sameSubnet'] as bool : null),
      subnet: json['subnet']?.toString(),
      networkHint: json['suggested_message']?.toString().trim() ?? '',
    );
  }
}

/// Result of bridge `/printer/tcp/scan`.
class EthernetScanResult {
  const EthernetScanResult({
    required this.ok,
    this.localIps = const <String>[],
    this.subnets = const <String>[],
    this.devices = const <EthernetDiscoveredDevice>[],
    this.port = 9100,
    this.scanDurationMs,
    this.errorCode,
    this.message = '',
    this.noDeviceReason = '',
    this.mismatchGuidance = '',
    this.suggestedPrinterIp = '',
    this.suggestedTargetSubnet = '',
  });

  final bool ok;
  final List<String> localIps;
  final List<String> subnets;
  final List<EthernetDiscoveredDevice> devices;
  final int port;
  final int? scanDurationMs;
  final String? errorCode;
  final String message;
  final String noDeviceReason;
  final String mismatchGuidance;
  final String suggestedPrinterIp;
  final String suggestedTargetSubnet;

  String get primarySubnet =>
      subnets.isNotEmpty ? subnets.first : 'Algılanamadı';

  String get primaryLocalIp =>
      localIps.isNotEmpty ? localIps.first : 'Algılanamadı';
}

EthernetScanResult parseEthernetScanResult(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return const EthernetScanResult(
      ok: false,
      errorCode: 'empty_response',
      message: 'Ağ taraması yanıt vermedi.',
    );
  }
  final devicesRaw = raw['devices'];
  final devices = devicesRaw is List
      ? devicesRaw
            .whereType<Map>()
            .map(
              (item) => EthernetDiscoveredDevice.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((device) => device.host.isNotEmpty)
            .toList()
      : const <EthernetDiscoveredDevice>[];
  final localIpsRaw = raw['local_ips'] ?? raw['localIps'];
  final localIps = localIpsRaw is List
      ? localIpsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : const <String>[];
  final subnetsRaw = raw['subnets'];
  final subnets = subnetsRaw is List
      ? subnetsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : const <String>[];
  return EthernetScanResult(
    ok: raw['ok'] == true,
    localIps: localIps,
    subnets: subnets,
    devices: devices,
    port: int.tryParse(raw['port']?.toString() ?? '') ?? 9100,
    scanDurationMs: int.tryParse(raw['scan_duration_ms']?.toString() ?? ''),
    errorCode: raw['errorCode']?.toString() ?? raw['error_code']?.toString(),
    message:
        raw['suggested_message']?.toString().trim() ??
        raw['error']?.toString().trim() ??
        raw['message']?.toString().trim() ??
        '',
    noDeviceReason: raw['no_device_reason']?.toString().trim() ?? '',
    mismatchGuidance: raw['mismatch_guidance']?.toString().trim() ?? '',
    suggestedPrinterIp: raw['suggested_printer_ip']?.toString().trim() ?? '',
    suggestedTargetSubnet:
        raw['suggested_target_subnet']?.toString().trim() ?? '',
  );
}

/// Operator-facing plan to move a printer onto the business LAN subnet.
class EthernetNetworkCompatibilityPlan {
  const EthernetNetworkCompatibilityPlan({
    required this.localIps,
    required this.scannedSubnets,
    required this.printerHost,
    required this.port,
    required this.sameSubnet,
    required this.suggestedTargetSubnet,
    required this.suggestedPrinterIp,
    required this.suggestedGateway,
    required this.subnetMask,
    required this.mismatchGuidance,
    this.networkState = 'unknown',
  });

  final List<String> localIps;
  final List<String> scannedSubnets;
  final String printerHost;
  final int port;
  final bool? sameSubnet;
  final String suggestedTargetSubnet;
  final String suggestedPrinterIp;
  final String suggestedGateway;
  final String subnetMask;
  final String mismatchGuidance;
  final String networkState;

  bool get hasMismatch =>
      sameSubnet == false || networkState == 'network_mismatch';

  String get primaryLocalIp =>
      localIps.isNotEmpty ? localIps.first : 'Algılanamadı';

  String get primaryScannedSubnet =>
      scannedSubnets.isNotEmpty
          ? scannedSubnets.first
          : suggestedTargetSubnet;

  String get sameSubnetLabel {
    if (sameSubnet == true) return 'Evet';
    if (sameSubnet == false) return 'Hayır — farklı ağ';
    return 'Henüz kontrol edilmedi';
  }

  factory EthernetNetworkCompatibilityPlan.fromContext({
    required List<String> localIps,
    required String printerHost,
    int port = 9100,
    Map<String, dynamic>? bridgePayload,
  }) {
    final payload = bridgePayload ?? const <String, dynamic>{};
    final mergedLocalIps = _mergeStringList(
      localIps,
      payload['local_ips'] ?? payload['localIps'],
    );
    final scannedSubnets = _mergeStringList(
      const <String>[],
      payload['scanned_subnets'] ??
          payload['subnets'] ??
          payload['scannedSubnets'],
    );
    final suggestions = suggestEthernetNetworkSettings(
      mergedLocalIps,
      printerHost: printerHost,
      port: port,
    );
    final sameSubnet = payload['same_subnet'] is bool
        ? payload['same_subnet'] as bool
        : suggestions.sameSubnet;
    final mismatchGuidance =
        payload['mismatch_guidance']?.toString().trim().isNotEmpty == true
        ? payload['mismatch_guidance'].toString().trim()
        : (sameSubnet == false
              ? formatDifferentSubnetWarning(
                  localIps: mergedLocalIps,
                  printerHost: printerHost,
                )
              : '');
    final networkState =
        payload['network_state']?.toString().trim().isNotEmpty == true
        ? payload['network_state'].toString().trim()
        : (sameSubnet == false ? 'network_mismatch' : 'ok');

    return EthernetNetworkCompatibilityPlan(
      localIps: mergedLocalIps,
      scannedSubnets: scannedSubnets.isNotEmpty
          ? scannedSubnets
          : suggestions.scannedSubnets,
      printerHost: printerHost,
      port: port,
      sameSubnet: sameSubnet,
      suggestedTargetSubnet:
          payload['suggested_target_subnet']?.toString().trim().isNotEmpty ==
              true
          ? payload['suggested_target_subnet'].toString().trim()
          : suggestions.suggestedTargetSubnet,
      suggestedPrinterIp:
          payload['suggested_printer_ip']?.toString().trim().isNotEmpty == true
          ? payload['suggested_printer_ip'].toString().trim()
          : suggestions.suggestedPrinterIp,
      suggestedGateway:
          payload['suggested_gateway']?.toString().trim().isNotEmpty == true
          ? payload['suggested_gateway'].toString().trim()
          : suggestions.suggestedGateway,
      subnetMask:
          payload['subnet_mask']?.toString().trim().isNotEmpty == true
          ? payload['subnet_mask'].toString().trim()
          : suggestions.subnetMask,
      mismatchGuidance: mismatchGuidance,
      networkState: networkState,
    );
  }
}

EthernetNetworkCompatibilityPlan suggestEthernetNetworkSettings(
  List<String> localIps, {
  required String printerHost,
  int port = 9100,
}) {
  final primaryLocal = localIps.isNotEmpty ? localIps.first : '';
  final parts = primaryLocal.split('.');
  final scannedSubnets = <String>[];
  var suggestedTargetSubnet = '';
  var suggestedPrinterIp = '';
  var suggestedGateway = '';
  const subnetMask = '255.255.255.0';
  if (parts.length == 4) {
    suggestedTargetSubnet = '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
    scannedSubnets.add(suggestedTargetSubnet);
    suggestedPrinterIp = '${parts[0]}.${parts[1]}.${parts[2]}.100';
    suggestedGateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
  }
  final sameSubnet = printerHost.trim().isEmpty
      ? null
      : ipv4SameSubnet(printerHost, localIps);
  final mismatchGuidance = sameSubnet == false
      ? formatDifferentSubnetWarning(
          localIps: localIps,
          printerHost: printerHost,
        )
      : '';
  return EthernetNetworkCompatibilityPlan(
    localIps: localIps,
    scannedSubnets: scannedSubnets,
    printerHost: printerHost,
    port: port,
    sameSubnet: sameSubnet,
    suggestedTargetSubnet: suggestedTargetSubnet,
    suggestedPrinterIp: suggestedPrinterIp,
    suggestedGateway: suggestedGateway,
    subnetMask: subnetMask,
    mismatchGuidance: mismatchGuidance,
    networkState: sameSubnet == false ? 'network_mismatch' : 'ok',
  );
}

bool? ipv4SameSubnet(String host, List<String> localIps) {
  final hostText = host.trim();
  if (hostText.isEmpty || localIps.isEmpty) return null;
  if (!isValidEthernetIpv4(hostText)) return null;
  final targetPrefix = hostText.split('.').take(3).join('.');
  var matched = false;
  for (final localIp in localIps) {
    if (!isValidEthernetIpv4(localIp)) continue;
    matched = true;
    if (localIp.split('.').take(3).join('.') == targetPrefix) {
      return true;
    }
  }
  return matched ? false : null;
}

List<String> _mergeStringList(
  List<String> base,
  Object? extra,
) {
  if (extra is! List) return base;
  final merged = <String>[...base];
  for (final item in extra) {
    final text = item.toString().trim();
    if (text.isNotEmpty && !merged.contains(text)) {
      merged.add(text);
    }
  }
  return merged;
}

String ethernetScanNoDeviceMessage({
  required EthernetScanResult scanResult,
  String printerHost = '',
}) {
  if (scanResult.devices.isNotEmpty) {
    return scanResult.message;
  }
  if (scanResult.noDeviceReason == 'printer_on_different_subnet' ||
      (printerHost.isNotEmpty &&
          ipv4SameSubnet(printerHost, scanResult.localIps) == false)) {
    return 'Aynı ağda port 9100 açık cihaz bulunamadı. '
        'Self-test fişindeki IP farklı ağdaysa otomatik tarama bulamaz.';
  }
  if (scanResult.message.isNotEmpty) {
    return scanResult.message;
  }
  return 'Aynı ağda port 9100 açık cihaz bulunamadı. '
      'Self-test fişindeki IP farklı ağdaysa otomatik tarama bulamaz.';
}

List<String> ethernetPrinterMigrationOptions({
  required EthernetNetworkCompatibilityPlan plan,
}) {
  final targetIp = plan.suggestedPrinterIp;
  final targetSubnet = plan.suggestedTargetSubnet;
  return <String>[
    'Önerilen — Router\'dan IP sabitle: Modem/router yönetim panelinden '
        'yazıcı için DHCP reservation yapın. Yazıcı IP\'si değişmez, '
        'yazdırma kopmaz. Hedef: $targetIp ($targetSubnet).',
    'Üretici IP ayar aracıyla değiştir: NETUM / Zjiang / ESC/POS Printer '
        'Tool ile yazıcının IP\'sini $targetIp yapın. '
        'Alt ağ maskesi ${plan.subnetMask}, ağ geçidi ${plan.suggestedGateway}, '
        'port ${plan.port}.',
    'Teknik servis modu: Geçici ağ erişimi yalnızca kurulum içindir. '
        'Normal müşteriye önerilmez.',
  ];
}

List<String> ethernetTechnicalAliasCommands({
  required String printerHost,
  String interfaceName = 'en0',
}) {
  if (!isValidEthernetIpv4(printerHost)) return const <String>[];
  final prefix = printerHost.split('.').take(3).join('.');
  final aliasIp = '$prefix.50';
  return <String>[
    'sudo ifconfig $interfaceName alias $aliasIp netmask 255.255.255.0',
    'sudo ifconfig $interfaceName -alias $aliasIp',
  ];
}

const String ethernetUnverifiedSaveWarning =
    'Bağlantı doğrulanmadan aktif yazıcı olarak kullanılamaz. '
    'Yazıcı kaydedildi; bağlantıyı doğrulayınca aktif olur.';
String formatDifferentSubnetWarning({
  required List<String> localIps,
  required String printerHost,
}) {
  if (localIps.isEmpty || !isValidEthernetIpv4(printerHost)) {
    return 'Yazıcı ile bilgisayar aynı ağda görünmüyor. '
        'Yazıcı IP\'sini işletme ağına alın.';
  }
  final localPrefix = localIps.first.split('.').take(3).join('.');
  final printerPrefix = printerHost.split('.').take(3).join('.');
  return 'Bilgisayarınız $localPrefix.x ağında, yazıcı $printerPrefix.x ağında. '
      'Bu cihazlar aynı ağda değil. Yazıcı IP\'sini işletme ağına alın.';
}

bool isValidEthernetIpv4(String host) {
  final trimmed = host.trim();
  if (trimmed.isEmpty) return false;
  final parts = trimmed.split('.');
  if (parts.length != 4) return false;
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return false;
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) return false;
  }
  return true;
}

String normalizeEthernetErrorCode(String? raw) {
  final code = (raw ?? '').trim();
  if (code.isEmpty) return 'unknown';
  switch (code) {
    case 'tcp_unreachable':
      return 'network_unreachable';
    case 'tcp_host_missing':
    case 'tcp_port_invalid':
      return 'invalid_ip';
    case 'network_mismatch':
      return 'network_mismatch';
    case 'client_timeout':
      return 'bridge_unreachable';
    default:
      return code;
  }
}

EthernetConnectionDiagnostic buildInvalidIpDiagnostic({
  required String host,
  required int port,
  String? detail,
}) {
  return EthernetConnectionDiagnostic(
    ok: false,
    errorCode: 'invalid_ip',
    title: 'Geçersiz IP adresi',
    message: '$host geçerli bir IPv4 adresi değil.\n'
        'Örnek: 192.168.1.100',
    technicalDetail: detail,
    host: host,
    port: port,
    reachable: false,
    portOpen: false,
    guidanceSteps: ethernetPrinterIpHelpSteps(),
  );
}

EthernetConnectionDiagnostic resolveEthernetConnectionProbeResult(
  Map<String, dynamic>? result, {
  required String host,
  required int port,
}) {
  if (result == null || result.isEmpty) {
    return EthernetConnectionDiagnostic(
      ok: false,
      errorCode: 'unknown',
      title: 'Bağlantı test edilemedi',
      message: 'Yazıcı servisinden yanıt alınamadı.',
      host: host,
      port: port,
      guidanceSteps: ethernetPrinterIpHelpSteps(),
    );
  }

  final localIpsRaw = result['local_ips'];
  final localIps = localIpsRaw is List
      ? localIpsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : const <String>[];
  final sameSubnet = result['same_subnet'] is bool
      ? result['same_subnet'] as bool
      : null;
  final networkHint = result['suggested_message']?.toString().trim() ?? '';
  final reachable = result['reachable'] is bool
      ? result['reachable'] as bool
      : null;
  final portOpen = result['port_open'] is bool
      ? result['port_open'] as bool
      : null;
  final technical = _buildProbeTechnicalDetail(result);

  if (result['ok'] == true) {
    final successMessage = networkHint.isNotEmpty
        ? networkHint
        : '$host:$port adresine erişim başarılı.';
    return EthernetConnectionDiagnostic(
      ok: true,
      errorCode: 'ready',
      title: 'Bağlantı başarılı',
      message: successMessage,
      technicalDetail: technical,
      host: host,
      port: port,
      localIps: localIps,
      sameSubnet: sameSubnet,
      reachable: reachable ?? true,
      portOpen: portOpen ?? true,
      guidanceSteps: const <String>[],
      networkHint: networkHint,
    );
  }

  final rawCode =
      result['errorCode']?.toString() ?? result['error_code']?.toString();
  final errorCode = normalizeEthernetErrorCode(rawCode);
  final presentation = presentPrinterErrorCode(errorCode);
  final bridgeError = result['error']?.toString().trim() ?? '';
  final message = _composeEthernetFailureMessage(
    host: host,
    port: port,
    presentation: presentation,
    networkHint: networkHint,
    bridgeError: bridgeError,
    sameSubnet: sameSubnet,
    localIps: localIps,
  );

  return EthernetConnectionDiagnostic(
    ok: false,
    errorCode: errorCode,
    title: presentation.title,
    message: message,
    technicalDetail: technical.isNotEmpty ? technical : bridgeError,
    host: host,
    port: port,
    localIps: localIps,
    sameSubnet: sameSubnet,
    reachable: reachable ?? false,
    portOpen: portOpen ?? false,
    guidanceSteps: ethernetPrinterIpHelpSteps(),
    networkHint: networkHint,
  );
}

EthernetConnectionDiagnostic resolveEthernetConnectionException(
  Object error, {
  required String host,
  required int port,
}) {
  var errorCode = 'unknown';
  var technical = error.toString();
  if (error is Exception && error.toString().contains('Not found')) {
    errorCode = 'bridge_unreachable';
    technical =
        'Bridge /printer/tcp/probe endpoint bulunamadi (404). Bridge guncel mi?';
  }
  final presentation = presentPrinterErrorCode(errorCode);
  return EthernetConnectionDiagnostic(
    ok: false,
    errorCode: errorCode,
    title: presentation.title,
    message: presentation.message,
    technicalDetail: technical,
    host: host,
    port: port,
    guidanceSteps: ethernetPrinterIpHelpSteps(),
  );
}

String _composeEthernetFailureMessage({
  required String host,
  required int port,
  required PrinterErrorPresentation presentation,
  required String networkHint,
  required String bridgeError,
  required bool? sameSubnet,
  required List<String> localIps,
}) {
  final buffer = StringBuffer();

  switch (presentation.code) {
    case 'tcp_timeout':
      buffer.writeln('$host:$port adresinden yanıt alınamadı.');
      buffer.writeln(
        'Yazıcının açık, Ethernet kablosunun takılı ve bilgisayarla '
        'aynı ağda olduğundan emin olun.',
      );
      buffer.write(
        'IP adresini yazıcının test sayfasından kontrol edin.',
      );
      break;
    case 'tcp_refused':
      buffer.writeln('$host:$port adresine ulaşıldı ancak port kapalı.');
      buffer.write(
        'Yazıcı RAW/TCP (9100) modunda mı? Self-test fişindeki portu kontrol edin.',
      );
      break;
    case 'invalid_ip':
      buffer.write(presentation.message);
      break;
    case 'network_unreachable':
      buffer.writeln('$host:$port adresine ağ yolu bulunamadı.');
      buffer.write(
        'IP adresini ve bilgisayarın aynı LAN/Wi‑Fi ağında olduğunu doğrulayın.',
      );
      break;
    case 'network_mismatch':
      buffer.writeln('$host:$port adresine ulaşılamadı.');
      buffer.write(
        'Yazıcı ile bilgisayar farklı ağda. Yazıcı IP\'sini işletme ağına alın.',
      );
      break;
    default:
      if (bridgeError.isNotEmpty) {
        buffer.write(bridgeError);
      } else {
        buffer.write(presentation.message);
      }
  }

  if (sameSubnet == false && networkHint.isNotEmpty) {
    buffer.writeln();
    buffer.write(networkHint);
  } else if (sameSubnet == true && localIps.isNotEmpty) {
    buffer.writeln();
    buffer.write(
      'Bilgisayar IP: ${localIps.first} — yazıcı ile aynı ağ gibi görünüyor.',
    );
  }

  return buffer.toString().trim();
}

String _buildProbeTechnicalDetail(Map<String, dynamic> result) {
  final parts = <String>[
    if (result['errorCode'] != null) 'errorCode=${result['errorCode']}',
    if (result['error_code'] != null) 'error_code=${result['error_code']}',
    if (result['error'] != null) 'error=${result['error']}',
    if (result['target_host'] != null) 'target_host=${result['target_host']}',
    if (result['target_port'] != null) 'target_port=${result['target_port']}',
    if (result['reachable'] != null) 'reachable=${result['reachable']}',
    if (result['port_open'] != null) 'port_open=${result['port_open']}',
    if (result['same_subnet'] != null) 'same_subnet=${result['same_subnet']}',
    if (result['local_ips'] != null) 'local_ips=${result['local_ips']}',
    if (result['fallback_used'] == true) 'fallback_used=true',
  ];
  return parts.join('\n');
}

TargetPlatform _platform() {
  if (kIsWeb) return TargetPlatform.windows;
  return defaultTargetPlatform;
}

PrinterErrorPresentation presentPrinterError(BridgeStructuredError error) {
  return presentPrinterErrorCode(
    error.errorCode,
    platform: _platform(),
    canClearQueue: error.canClearQueue,
  );
}

PrinterErrorPresentation presentPrinterErrorCode(
  String code, {
  TargetPlatform? platform,
  bool canClearQueue = false,
}) {
  final normalized = normalizeEthernetErrorCode(code);
  final p = platform ?? _platform();
  final isWindows = p == TargetPlatform.windows;

  switch (normalized) {
    case 'bridge_unreachable':
    case 'bridge_not_running':
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Yazıcı servisi çalışmıyor',
        message: isWindows
            ? 'Yazıcı servisi kurulu değil veya çalışmıyor. Ibul Satıcı Windows uygulamasını indirip kurun, sonra tekrar deneyin.'
            : 'Yazıcı servisine ulaşılamadı. Servisi başlatın, sonra tekrar deneyin.',
        primaryActionLabel: isWindows ? 'Uygulamayı İndir' : 'Tekrar Dene',
        secondaryActionLabel: isWindows ? 'Logları Aç' : null,
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canOpenLogs: isWindows,
        canDownloadInstaller: isWindows,
      );
    case 'tcp_timeout':
      return const PrinterErrorPresentation(
        code: 'tcp_timeout',
        title: 'Yazıcıya ulaşılamadı',
        message:
            'Yazıcı belirtilen IP ve porttan yanıt vermedi. '
            'Açık olduğundan, kablonun takılı olduğundan ve aynı ağda '
            'olduğunuzdan emin olun.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Yardım',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    case 'tcp_refused':
      return const PrinterErrorPresentation(
        code: 'tcp_refused',
        title: 'Port kapalı',
        message:
            'Cihaza ulaşıldı ancak belirtilen port bağlantıyı reddetti. '
            'Port numarasını ve yazıcının RAW/TCP modunu kontrol edin.',
        primaryActionLabel: 'Tekrar Dene',
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
      );
    case 'invalid_ip':
      return const PrinterErrorPresentation(
        code: 'invalid_ip',
        title: 'Geçersiz IP adresi',
        message:
            'Girilen IP adresi geçerli bir IPv4 formatında değil. '
            'Örnek: 192.168.1.100',
        primaryActionLabel: 'Düzenle',
        severity: PrinterErrorSeverity.warning,
        canRetry: false,
      );
    case 'network_unreachable':
      return const PrinterErrorPresentation(
        code: 'network_unreachable',
        title: 'Ağ yolu bulunamadı',
        message:
            'Yazıcı IP adresine ulaşılamıyor. Bilgisayar ve yazıcı '
            'farklı ağda olabilir veya IP hatalı olabilir.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Yardım',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    case 'network_mismatch':
      return const PrinterErrorPresentation(
        code: 'network_mismatch',
        title: 'Ağ uyumsuzluğu',
        message:
            'Yazıcı ile bilgisayar aynı ağda değil. Yazıcı IP\'sini '
            'işletme ağına taşıyın; Mac/PC IP değiştirmeniz gerekmez.',
        primaryActionLabel: 'Yardım',
        secondaryActionLabel: 'Tekrar Dene',
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
      );
    case 'printer_not_found':
      return const PrinterErrorPresentation(
        code: 'printer_not_found',
        title: 'Yazıcı bulunamadı',
        message: 'Seçili yazıcı şu an bağlı değil. Kabloyu kontrol edip yeniden tarayın.',
        primaryActionLabel: 'Yeniden Tara',
        secondaryActionLabel: 'Tekrar Dene',
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
      );
    case 'cups_queue_stuck':
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Mac yazıcı kuyruğu takıldı',
        message: 'CUPS kuyruğu takılmış görünüyor. Kuyruğu temizleyip tekrar deneyin.',
        primaryActionLabel: 'Kuyruğu Temizle',
        secondaryActionLabel: 'Tekrar Dene',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canClearQueue: true,
      );
    case 'cups_queue_busy':
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Mac yazıcı kuyruğu meşgul',
        message: 'Yazıcı hâlâ önceki işi işliyor. Birkaç saniye bekleyin veya kuyruğu temizleyin.',
        primaryActionLabel: canClearQueue ? 'Kuyruğu Temizle' : 'Tekrar Dene',
        secondaryActionLabel: canClearQueue ? 'Tekrar Dene' : null,
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
        canClearQueue: canClearQueue,
      );
    case 'duplicate_printer':
      return const PrinterErrorPresentation(
        code: 'duplicate_printer',
        title: 'Aynı yazıcı birden fazla görünüyor',
        message: 'Bu yazıcı birden fazla bağlantı yöntemiyle görünüyor. Mac için genelde CUPS önerilir.',
        primaryActionLabel: 'Önerilen Seçeneği Kullan',
        secondaryActionLabel: 'Alternatifi Seç',
        severity: PrinterErrorSeverity.warning,
        canRetry: false,
      );
    case 'stale_printer':
      return const PrinterErrorPresentation(
        code: 'stale_printer',
        title: 'Kayıtlı yazıcı bağlı değil',
        message: 'Bu yazıcı daha önce kayıtlıydı ama şu an bağlı değil. Yazıcıyı bağlayıp yeniden tarayın.',
        primaryActionLabel: 'Yeniden Tara',
        secondaryActionLabel: 'Ayarları Aç',
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
      );
    case 'permission_denied':
      return const PrinterErrorPresentation(
        code: 'permission_denied',
        title: 'Erişim izni yok',
        message: 'Yazıcıya erişim izni yok. Uygulamayı yeniden başlatın veya sistem izinlerini kontrol edin.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    case 'windows_spooler_error':
      return const PrinterErrorPresentation(
        code: 'windows_spooler_error',
        title: 'Windows spooler yanıt vermiyor',
        message: 'Windows Yazdırma Biriktiricisi (Spooler) yanıt vermiyor. Hizmeti yeniden başlatın ve tekrar deneyin.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Logları Aç',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canOpenLogs: true,
      );
    case 'installer_missing':
      return PrinterErrorPresentation(
        code: 'installer_missing',
        title: 'Kurulum dosyası bulunamadı',
        message: kDebugMode
            ? 'Kurulum dosyası sunucuda bulunamadı. Lütfen deploy paketini kontrol edin.\n'
                  'Teknik: GitHub Release asset (IbulSellerSetup.exe) ve IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL.'
            : 'Kurulum dosyası şu an indirilemiyor. Lütfen daha sonra tekrar deneyin.',
        primaryActionLabel: kDebugMode ? 'Deploy Kontrolü' : 'Tekrar Dene',
        secondaryActionLabel: kDebugMode ? 'Tekrar Dene' : null,
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    case 'print_system_disabled':
      return const PrinterErrorPresentation(
        code: 'print_system_disabled',
        title: 'Baskı sistemi kapalı',
        message: 'Baskı sistemi kapalı. Test göndermek için sistemi açın.',
        primaryActionLabel: 'Baskı Sistemini Aç',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.warning,
        canRetry: false,
      );
    case 'role_save_failed':
      return const PrinterErrorPresentation(
        code: 'role_save_failed',
        title: 'Ayarlar kaydedilemedi',
        message: 'Test başarılı olabilir ama rol/ayar kaydı tamamlanamadı. Tekrar kaydetmeyi deneyin.',
        primaryActionLabel: 'Tekrar Kaydet',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    default:
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Yazdırma hatası',
        message: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canClearQueue: canClearQueue,
        canDownloadInstaller: isWindows,
      );
  }
}
