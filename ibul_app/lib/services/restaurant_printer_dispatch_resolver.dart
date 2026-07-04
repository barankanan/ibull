import '../models/desktop_printer_setup_models.dart';
import '../models/discovered_printer.dart';
import '../models/printer_model.dart';
import '../models/printer_profile.dart';
import 'bridge_print_dispatch_verification.dart';

/// Shared production/test printer resolution result.
class RestaurantPrinterDispatchResolution {
  const RestaurantPrinterDispatchResolution({
    required this.ok,
    required this.resolutionSource,
    this.role,
    this.stationId,
    this.stationName,
    this.printer,
    this.printerSnapshot = const <String, dynamic>{},
    this.errorMessage,
    this.warnings = const <String>[],
    this.backend,
    this.deviceId = '',
    this.ip = '',
    this.port = 0,
    this.queueName = '',
    this.printerRecordId,
    this.printerProfileId,
    this.paperWidthMm,
    this.rasterWidthPx,
    this.charsPerLine,
  });

  final bool ok;
  final String resolutionSource;
  final PrinterSetupRole? role;
  final String? stationId;
  final String? stationName;
  final UnifiedPrinterModel? printer;
  final Map<String, dynamic> printerSnapshot;
  final String? errorMessage;
  final List<String> warnings;
  final DesktopPrinterBackend? backend;
  final String deviceId;
  final String ip;
  final int port;
  final String queueName;
  final String? printerRecordId;
  final String? printerProfileId;
  final int? paperWidthMm;
  final int? rasterWidthPx;
  final int? charsPerLine;

  static const String missingRolePrinterMessage =
      'Bu rol için yazıcı seçilmemiş. Yazıcı Ayarları\'ndan rol atayın.';

  static const String backendMismatchMessage =
      'Seçili yazıcı farklı bağlantı yoluna düştü. USB/Ethernet ayarını kontrol edin.';

  static const String bridgeOfflineMessage =
      'Bridge çalışmıyor. Yazıcı köprüsünü başlatın.';

  static const String tcpUnreachableMessage =
      'Yazıcıya bağlanılamadı. IP adresini ve kabloyu kontrol edin.';

  static const String dispatchNotDeliveredMessage =
      BridgePrintDispatchVerification.dispatchNotDeliveredMessage;

  static const String cupsUnverifiedMessage =
      BridgePrintDispatchVerification.cupsUnverifiedMessage;

  static const String stationMissingPrinterMessage =
      BridgePrintDispatchVerification.stationMissingPrinterMessage;
}

/// Builds printer snapshots and validates dispatch targets for restaurant flows.
class RestaurantPrinterDispatchResolver {
  const RestaurantPrinterDispatchResolver._();

  static Map<String, dynamic> buildPrinterSnapshot(
    UnifiedPrinterModel printer, {
    PrinterSetupRole? role,
    String? stationId,
    String? stationName,
    String documentType = 'kitchen',
  }) {
    final discovered = DiscoveredPrinter.fromUnifiedPrinter(printer);
    final host = _readHost(printer);
    final port = _readPort(printer);
    final profile = _profileForPrinter(printer);
    return <String, dynamic>{
      'printer_id': printer.printerRecordId ?? printer.id,
      'printer_record_id': printer.printerRecordId,
      'printer_name': printer.displayName,
      'printer_queue': printer.queueName,
      'printer_device_identifier': discovered.deviceId,
      'backend': printer.backend.value,
      'discovered_backend': discovered.backend.value,
      'transport_type': _transportType(printer),
      'transportType': _transportType(printer),
      if (host.isNotEmpty) ...<String, dynamic>{
        'host': host,
        'ip_address': host,
        'ipAddress': host,
        'target_host': host,
      },
      if (port > 0) ...<String, dynamic>{
        'port': port,
        'target_port': port,
      },
      if (role != null) 'printer_role': role.value,
      if (role != null) 'role': role.value,
      'document_type': documentType,
      if (stationId != null && stationId.trim().isNotEmpty)
        'station_id': stationId.trim(),
      if (stationName != null && stationName.trim().isNotEmpty)
        'station_name': stationName.trim(),
      if (profile != null) ...PrinterProfile.bridgeProfileFields(profile),
      if (profile != null) 'chars_per_line': profile.charsPerLine,
      'device_id': discovered.deviceId,
      'queue_name': printer.queueName,
    };
  }

  static RestaurantPrinterDispatchResolution fromPrinter({
    required UnifiedPrinterModel printer,
    required String resolutionSource,
    PrinterSetupRole? role,
    String? stationId,
    String? stationName,
    String documentType = 'kitchen',
    List<String> warnings = const <String>[],
  }) {
    final validationError = validatePrinterForDispatch(printer);
    if (validationError != null) {
      return RestaurantPrinterDispatchResolution(
        ok: false,
        resolutionSource: resolutionSource,
        role: role,
        stationId: stationId,
        stationName: stationName,
        printer: printer,
        errorMessage: validationError,
        warnings: warnings,
        backend: printer.backend,
        deviceId: DiscoveredPrinter.fromUnifiedPrinter(printer).deviceId,
        ip: _readHost(printer),
        port: _readPort(printer),
        queueName: printer.queueName,
        printerRecordId: printer.printerRecordId,
      );
    }
    final profile = _profileForPrinter(printer);
    final discovered = DiscoveredPrinter.fromUnifiedPrinter(printer);
    return RestaurantPrinterDispatchResolution(
      ok: true,
      resolutionSource: resolutionSource,
      role: role,
      stationId: stationId,
      stationName: stationName,
      printer: printer,
      printerSnapshot: buildPrinterSnapshot(
        printer,
        role: role,
        stationId: stationId,
        stationName: stationName,
        documentType: documentType,
      ),
      warnings: warnings,
      backend: printer.backend,
      deviceId: discovered.deviceId,
      ip: _readHost(printer),
      port: _readPort(printer),
      queueName: printer.queueName,
      printerRecordId: printer.printerRecordId,
      printerProfileId: profile?.id,
      paperWidthMm: profile?.paperWidthMm,
      rasterWidthPx: profile?.rasterWidthPx,
      charsPerLine: profile?.charsPerLine,
    );
  }

  static RestaurantPrinterDispatchResolution failure({
    required String resolutionSource,
    required String errorMessage,
    PrinterSetupRole? role,
    String? stationId,
    String? stationName,
    List<String> warnings = const <String>[],
  }) {
    return RestaurantPrinterDispatchResolution(
      ok: false,
      resolutionSource: resolutionSource,
      role: role,
      stationId: stationId,
      stationName: stationName,
      errorMessage: errorMessage,
      warnings: warnings,
    );
  }

  static String? validatePrinterForDispatch(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host = _readHost(printer);
      if (host.isEmpty) {
        return RestaurantPrinterDispatchResolution.tcpUnreachableMessage;
      }
      return null;
    }
    if (printer.backend == DesktopPrinterBackend.cups) {
      final explicitQueue =
          printer.raw['queue']?.toString().trim() ??
          printer.raw['printer_queue']?.toString().trim() ??
          '';
      if (explicitQueue.isEmpty) {
        return 'CUPS yazıcı kuyruk adı eksik. Yazıcıyı yeniden kaydedin.';
      }
      return null;
    }
    if (printer.backend == DesktopPrinterBackend.windowsSpool) {
      final explicitQueue =
          printer.raw['queue']?.toString().trim() ??
          printer.raw['printer']?.toString().trim() ??
          '';
      if (explicitQueue.isEmpty) {
        return 'Windows yazıcı adı eksik. Yazıcıyı yeniden kaydedin.';
      }
      return null;
    }
    return null;
  }

  static String _readHost(UnifiedPrinterModel printer) {
    return (printer.raw['host'] ??
            printer.raw['ip_address'] ??
            printer.raw['ipAddress'] ??
            printer.raw['configuredIp'])
        ?.toString()
        .trim() ??
        '';
  }

  static int _readPort(UnifiedPrinterModel printer) {
    final rawPort = printer.raw['port'] ?? printer.raw['tcp_port'];
    final parsed = int.tryParse(rawPort?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    if (_readHost(printer).isNotEmpty) {
      return PrinterModel.ethernetDefaultPort;
    }
    return 0;
  }

  static String _transportType(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.tcp) {
      return PrinterModel.ethernetBridgeTransport;
    }
    return printer.backend.value;
  }

  static PrinterProfile? _profileForPrinter(UnifiedPrinterModel printer) {
    final profileId = printer.raw['printer_profile_id']?.toString() ??
        printer.raw['printerProfileId']?.toString();
    final width = int.tryParse(
      printer.raw['paper_width_mm']?.toString() ??
          printer.raw['paperWidthMm']?.toString() ??
          '',
    );
    return PrinterProfile.resolveConsistentProfile(
      profileId: profileId,
      paperWidthMm: width,
      displayName: printer.displayName,
    );
  }
}

/// Ethernet IP drift details for operator UX.
class EthernetIpDriftInfo {
  const EthernetIpDriftInfo({
    required this.printerRecordId,
    required this.displayName,
    required this.configuredIp,
    required this.lastSeenIp,
    required this.port,
    required this.deviceId,
  });

  final String printerRecordId;
  final String displayName;
  final String configuredIp;
  final String lastSeenIp;
  final int port;
  final String deviceId;

  bool get hasDrift =>
      configuredIp.trim().isNotEmpty &&
      lastSeenIp.trim().isNotEmpty &&
      configuredIp.trim() != lastSeenIp.trim();

  String get title =>
      'Bu yazıcının kayıtlı IP adresi ile bulunan IP adresi farklı görünüyor.';

  String get detail =>
      'Kayıtlı IP: $configuredIp\nBulunan IP: $lastSeenIp';

  static EthernetIpDriftInfo? fromLegacyMap(Map<String, dynamic> printer) {
    final recordId =
        printer['printerRecordId']?.toString() ??
        printer['printer_record_id']?.toString() ??
        '';
    if (recordId.trim().isEmpty) return null;
    final configured =
        printer['configuredIp']?.toString().trim() ??
        printer['ip']?.toString().trim() ??
        '';
    final lastSeen = printer['lastSeenIp']?.toString().trim() ?? '';
    if (configured.isEmpty || lastSeen.isEmpty || configured == lastSeen) {
      final warning = printer['ipMismatchWarning']?.toString().trim() ?? '';
      if (warning.isEmpty) return null;
    }
    final configuredIp = printer['configuredIp']?.toString().trim().isNotEmpty ==
            true
        ? printer['configuredIp'].toString().trim()
        : _parseConfiguredFromDeviceId(
            printer['device_identifier']?.toString() ??
                printer['deviceIdentifier']?.toString(),
          );
    final lastSeenIp = printer['lastSeenIp']?.toString().trim().isNotEmpty == true
        ? printer['lastSeenIp'].toString().trim()
        : printer['ip']?.toString().trim() ?? '';
    if (configuredIp.isEmpty || lastSeenIp.isEmpty || configuredIp == lastSeenIp) {
      return null;
    }
    final port =
        int.tryParse(printer['port']?.toString() ?? '') ??
        PrinterModel.ethernetDefaultPort;
    final deviceId =
        printer['device_id']?.toString() ??
        printer['deviceId']?.toString() ??
        DiscoveredPrinter.buildTcpDeviceId(configuredIp, port);
    return EthernetIpDriftInfo(
      printerRecordId: recordId,
      displayName: printer['name']?.toString() ?? recordId,
      configuredIp: configuredIp,
      lastSeenIp: lastSeenIp,
      port: port,
      deviceId: deviceId,
    );
  }

  static String _parseConfiguredFromDeviceId(String? deviceId) {
    final value = deviceId?.trim() ?? '';
    if (!value.startsWith('tcp:')) return '';
    final parts = value.split(':');
    if (parts.length >= 2) return parts[1].trim();
    return '';
  }
}
