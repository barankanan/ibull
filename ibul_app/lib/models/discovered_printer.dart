import 'desktop_printer_setup_models.dart';
import 'printer_model.dart';

enum DiscoveredPrinterBackend {
  ethernetTcp('ethernet_tcp'),
  usbDirect('usb_direct'),
  cups('cups'),
  windowsSpooler('windows_spooler');

  const DiscoveredPrinterBackend(this.value);

  final String value;

  String get label {
    switch (this) {
      case DiscoveredPrinterBackend.ethernetTcp:
        return 'Ethernet TCP';
      case DiscoveredPrinterBackend.usbDirect:
        return 'USB Direct';
      case DiscoveredPrinterBackend.cups:
        return 'CUPS';
      case DiscoveredPrinterBackend.windowsSpooler:
        return 'Windows';
    }
  }

  static DiscoveredPrinterBackend fromBridgeRaw(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'usb':
      case 'usb-direct':
      case 'usb_direct':
        return DiscoveredPrinterBackend.usbDirect;
      case 'windows':
      case 'windows-spool':
      case 'windows_spooler':
      case 'windows-spooler':
        return DiscoveredPrinterBackend.windowsSpooler;
      case 'tcp':
      case 'network-tcp':
      case 'ethernet':
      case 'network':
      case 'ethernet_tcp':
        return DiscoveredPrinterBackend.ethernetTcp;
      case 'cups':
      default:
        return DiscoveredPrinterBackend.cups;
    }
  }

  DesktopPrinterBackend toDesktopBackend() {
    switch (this) {
      case DiscoveredPrinterBackend.ethernetTcp:
        return DesktopPrinterBackend.tcp;
      case DiscoveredPrinterBackend.usbDirect:
        return DesktopPrinterBackend.usbDirect;
      case DiscoveredPrinterBackend.cups:
        return DesktopPrinterBackend.cups;
      case DiscoveredPrinterBackend.windowsSpooler:
        return DesktopPrinterBackend.windowsSpool;
    }
  }
}

enum DiscoveredPrinterSource {
  bridge('bridge'),
  savedRegistry('saved_registry'),
  manual('manual'),
  scan('scan');

  const DiscoveredPrinterSource(this.value);

  final String value;

  String get label {
    switch (this) {
      case DiscoveredPrinterSource.bridge:
        return 'Canlı bulundu';
      case DiscoveredPrinterSource.savedRegistry:
        return 'Kayıtlı yazıcı';
      case DiscoveredPrinterSource.manual:
        return 'Manuel Ethernet';
      case DiscoveredPrinterSource.scan:
        return 'Ağ taraması';
    }
  }

  static DiscoveredPrinterSource fromRaw(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'saved_registry':
      case 'saved_record':
      case 'ethernet_saved_record':
        return DiscoveredPrinterSource.savedRegistry;
      case 'manual':
        return DiscoveredPrinterSource.manual;
      case 'scan':
      case 'usb_scan':
        return DiscoveredPrinterSource.scan;
      case 'bridge':
      default:
        return DiscoveredPrinterSource.bridge;
    }
  }

  bool get isPersistedRegistry =>
      this == DiscoveredPrinterSource.savedRegistry ||
      this == DiscoveredPrinterSource.manual;
}

/// Normalized printer discovery record shared by bridge scan and DB registry.
class DiscoveredPrinter {
  const DiscoveredPrinter({
    required this.backend,
    required this.deviceId,
    required this.displayName,
    this.ip = '',
    this.port = 9100,
    this.queueName = '',
    this.vendorId,
    this.productId,
    this.isOnline = true,
    required this.source,
    this.rawBridgeId = '',
    this.dbPrinterId,
    this.isStaleSavedMapping = false,
    this.isDuplicateCandidate = false,
    this.configuredIp = '',
    this.lastSeenIp = '',
    this.ipMismatchWarning = '',
    this.statusMessage = '',
  });

  final DiscoveredPrinterBackend backend;
  final String deviceId;
  final String displayName;
  final String ip;
  final int port;
  final String queueName;
  final String? vendorId;
  final String? productId;
  final bool isOnline;
  final DiscoveredPrinterSource source;
  final String rawBridgeId;
  final String? dbPrinterId;
  final bool isStaleSavedMapping;
  final bool isDuplicateCandidate;
  final String configuredIp;
  final String lastSeenIp;
  final String ipMismatchWarning;
  final String statusMessage;

  String get backendLabel => backend.label;
  String get sourceLabel => source.label;

  String get endpointLabel {
    if (backend == DiscoveredPrinterBackend.ethernetTcp &&
        ip.trim().isNotEmpty) {
      return '$ip:$port';
    }
    if (queueName.trim().isNotEmpty) {
      return queueName.trim();
    }
    return deviceId;
  }

  bool get hasIpMismatch => ipMismatchWarning.trim().isNotEmpty;

  Map<String, dynamic> toRawFields() {
    return <String, dynamic>{
      'discoveredBackend': backend.value,
      'discoveredSource': source.value,
      'deviceId': deviceId,
      'device_id': deviceId,
      'ip': ip,
      'port': port,
      'configuredIp': configuredIp,
      'lastSeenIp': lastSeenIp,
      'ipMismatchWarning': ipMismatchWarning,
      'backendLabel': backendLabel,
      'sourceLabel': sourceLabel,
      'isDuplicateCandidate': isDuplicateCandidate,
      'isStaleSavedMapping': isStaleSavedMapping,
      if (statusMessage.isNotEmpty) 'discoveredStatusMessage': statusMessage,
    };
  }

  static ({String ip, int port}) normalizeEthernetEndpoint({
    required String? ipAddress,
    int? port,
    String? deviceIdentifier,
  }) {
    var host = (ipAddress ?? '').trim();
    if (host.isEmpty && (deviceIdentifier ?? '').trim().startsWith('tcp:')) {
      final parts = deviceIdentifier!.trim().split(':');
      if (parts.length >= 2) {
        host = parts[1].trim();
      }
    }
    var resolvedPort = port ?? 0;
    if (resolvedPort <= 0 && (deviceIdentifier ?? '').trim().startsWith('tcp:')) {
      final parts = deviceIdentifier!.trim().split(':');
      if (parts.length >= 3) {
        resolvedPort = int.tryParse(parts[2].trim()) ?? 0;
      }
    }
    if (resolvedPort <= 0) {
      resolvedPort = PrinterModel.ethernetDefaultPort;
    }
    return (ip: host, port: resolvedPort);
  }

  /// Resolves host/port for Ethernet unified printers (DB + bridge snapshots).
  static ({String ip, int port}) endpointFromUnifiedPrinter(
    UnifiedPrinterModel printer,
  ) {
    final raw = printer.raw;
    return normalizeEthernetEndpoint(
      ipAddress: raw['ip']?.toString() ??
          raw['host']?.toString() ??
          raw['ip_address']?.toString() ??
          raw['ipAddress']?.toString(),
      port: int.tryParse(
        raw['port']?.toString() ?? raw['tcp_port']?.toString() ?? '',
      ),
      deviceIdentifier: raw['device_id']?.toString() ??
          raw['deviceId']?.toString() ??
          raw['device_identifier']?.toString() ??
          raw['deviceIdentifier']?.toString() ??
          printer.id,
    );
  }

  static String buildTcpDeviceId(String ip, int port) {
    return PrinterModel.ethernetPrinterId(
      host: ip.trim(),
      port: port > 0 ? port : PrinterModel.ethernetDefaultPort,
    );
  }

  factory DiscoveredPrinter.fromBridgeMap(Map<String, dynamic> printer) {
    final backend = DiscoveredPrinterBackend.fromBridgeRaw(
      printer['backend']?.toString(),
    );
    final rawId = printer['id']?.toString().trim() ?? '';
    final queue =
        printer['queue']?.toString().trim() ??
        printer['queueName']?.toString().trim() ??
        printer['name']?.toString().trim() ??
        '';
    final displayName =
        printer['name']?.toString().trim() ??
        printer['displayName']?.toString().trim() ??
        queue;
    final endpoint = normalizeEthernetEndpoint(
      ipAddress: printer['host']?.toString() ?? printer['ip_address']?.toString(),
      port: int.tryParse(printer['port']?.toString() ?? ''),
      deviceIdentifier: printer['deviceIdentifier']?.toString() ??
          printer['device_identifier']?.toString(),
    );
    final deviceId = backend == DiscoveredPrinterBackend.ethernetTcp &&
            endpoint.ip.isNotEmpty
        ? buildTcpDeviceId(endpoint.ip, endpoint.port)
        : rawId.isNotEmpty
        ? rawId
        : '${backend.value}:$queue';

    return DiscoveredPrinter(
      backend: backend,
      deviceId: deviceId,
      displayName: displayName.isEmpty ? deviceId : displayName,
      ip: endpoint.ip,
      port: endpoint.port,
      queueName: queue,
      vendorId: printer['vendorId']?.toString() ?? printer['vid']?.toString(),
      productId: printer['productId']?.toString() ?? printer['pid']?.toString(),
      isOnline: printer['ready'] != false && printer['status']?.toString() != 'offline',
      source: DiscoveredPrinterSource.fromRaw(
        printer['source']?.toString() ?? 'bridge',
      ),
      rawBridgeId: rawId,
      dbPrinterId: printer['printerRecordId']?.toString() ??
          printer['printer_record_id']?.toString(),
      statusMessage: printer['statusMessage']?.toString() ?? '',
    );
  }

  factory DiscoveredPrinter.fromPrinterModel(PrinterModel printer) {
    final backend = printer.isEthernetConnection
        ? DiscoveredPrinterBackend.ethernetTcp
        : printer.formConnectionType == PrinterModel.usbConnectionType
        ? DiscoveredPrinterBackend.usbDirect
        : DiscoveredPrinterBackend.cups;
    final endpoint = normalizeEthernetEndpoint(
      ipAddress: printer.ipAddress,
      port: printer.port,
      deviceIdentifier: printer.deviceIdentifier,
    );
    final deviceId = backend == DiscoveredPrinterBackend.ethernetTcp
        ? buildTcpDeviceId(endpoint.ip, endpoint.port)
        : (printer.deviceIdentifier?.trim().isNotEmpty == true
              ? printer.deviceIdentifier!.trim()
              : printer.id);
    return DiscoveredPrinter(
      backend: backend,
      deviceId: deviceId,
      displayName: printer.name,
      ip: endpoint.ip,
      port: endpoint.port,
      queueName: printer.deviceIdentifier?.trim() ?? printer.name,
      isOnline: printer.isActive,
      source: DiscoveredPrinterSource.savedRegistry,
      dbPrinterId: printer.id,
      configuredIp: endpoint.ip,
      isStaleSavedMapping: true,
      statusMessage: printer.isActive
          ? 'Kayıtlı Ethernet yazıcı — bağlantı test edilmedi'
          : 'Kayıtlı yazıcı pasif',
    );
  }

  factory DiscoveredPrinter.fromUnifiedPrinter(UnifiedPrinterModel printer) {
    final raw = printer.raw;
    final backend = DiscoveredPrinterBackend.fromBridgeRaw(
      raw['discoveredBackend']?.toString() ?? printer.backend.value,
    );
    final source = DiscoveredPrinterSource.fromRaw(
      raw['discoveredSource']?.toString() ?? raw['source']?.toString(),
    );
    final endpoint = normalizeEthernetEndpoint(
      ipAddress: raw['ip']?.toString() ??
          raw['host']?.toString() ??
          raw['ip_address']?.toString(),
      port: int.tryParse(raw['port']?.toString() ?? ''),
      deviceIdentifier: raw['deviceId']?.toString() ??
          raw['device_id']?.toString() ??
          raw['deviceIdentifier']?.toString() ??
          raw['device_identifier']?.toString(),
    );
    final deviceId = (raw['deviceId']?.toString() ?? raw['device_id']?.toString())
            ?.trim()
            .isNotEmpty ==
        true
        ? (raw['deviceId'] ?? raw['device_id']).toString()
        : backend == DiscoveredPrinterBackend.ethernetTcp && endpoint.ip.isNotEmpty
        ? buildTcpDeviceId(endpoint.ip, endpoint.port)
        : printer.id;

    return DiscoveredPrinter(
      backend: backend,
      deviceId: deviceId,
      displayName: printer.displayName,
      ip: endpoint.ip,
      port: endpoint.port,
      queueName: printer.queueName,
      vendorId: printer.vendorId,
      productId: printer.productId,
      isOnline: printer.isAvailable,
      source: source,
      rawBridgeId: printer.id,
      dbPrinterId: printer.printerRecordId,
      isStaleSavedMapping: raw['isStaleSavedMapping'] == true ||
          printer.isStaleSavedMapping,
      isDuplicateCandidate: raw['isDuplicateCandidate'] == true,
      configuredIp: raw['configuredIp']?.toString() ?? endpoint.ip,
      lastSeenIp: raw['lastSeenIp']?.toString() ?? '',
      ipMismatchWarning: raw['ipMismatchWarning']?.toString() ?? '',
      statusMessage: raw['discoveredStatusMessage']?.toString() ??
          printer.statusMessage ??
          '',
    );
  }

  UnifiedPrinterModel toUnifiedPrinter({required DesktopPrinterOs os}) {
    final rawFields = <String, dynamic>{
      'id': rawBridgeId.isNotEmpty ? rawBridgeId : deviceId,
      'name': displayName,
      'queue': queueName.isNotEmpty ? queueName : displayName,
      'backend': backend.toDesktopBackend().value,
      'source': source.value,
      'deviceIdentifier': deviceId,
      'device_identifier': deviceId,
      if (ip.isNotEmpty) ...<String, dynamic>{
        'host': ip,
        'ip_address': ip,
        'ipAddress': ip,
        'port': port,
      },
      if (vendorId != null) 'vendorId': vendorId,
      if (productId != null) 'productId': productId,
      if (dbPrinterId != null) ...<String, dynamic>{
        'printerRecordId': dbPrinterId,
        'printer_record_id': dbPrinterId,
      },
      'isSavedOnly': isStaleSavedMapping,
      ...toRawFields(),
    };
    return UnifiedPrinterModel.fromBridgeMap(rawFields, os: os);
  }
}
