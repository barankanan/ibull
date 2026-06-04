import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/printer_model.dart';

class ExpectedKitchenPrinterResolution {
  const ExpectedKitchenPrinterResolution({
    required this.source,
    required this.printer,
    required this.backend,
    required this.host,
    required this.port,
    required this.queue,
    this.stationId,
    this.stationName,
  });

  final String source;
  final PrinterModel printer;
  final String backend;
  final String host;
  final int? port;
  final String queue;
  final String? stationId;
  final String? stationName;

  bool get isTcp => backend == 'tcp';

  Map<String, dynamic> toLogDetails() {
    return <String, dynamic>{
      'source': source,
      'station_id': stationId,
      'station_name': stationName,
      'printer_id': printer.id,
      'printer_name': printer.name,
      'backend': backend,
      'host': host,
      'port': port,
      'queue': queue,
    };
  }
}

abstract class PrinterRepositoryPort {
  Future<List<PrinterModel>> fetchPrinters(String restaurantId);

  Future<PrinterModel?> fetchPrinterById(String printerId);

  Future<PrinterModel?> getPrinterByRecordId(String recordId);

  Future<PrinterModel> upsertPrinter({
    required String restaurantId,
    String? printerId,
    required String name,
    required String code,
    required String connectionType,
    String? ipAddress,
    int? port,
    String? deviceIdentifier,
    int paperWidthMm = 80,
    bool isActive = true,
    bool supportsCut = false,
    PrinterCharset charset = PrinterCharset.cp857,
    int? codePage,
    List<PrinterRole> assignedRoles = const [],
    String? printerProfileId,
  });

  Future<void> updateAssignedRoles(String printerId, List<PrinterRole> roles);

  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId);

  Future<void> deletePrinter(String printerId);

  Future<void> deletePrintersForRestaurant(String restaurantId);

  Future<void> deleteStationPrinterMappingsForPrinter(String printerId);

  Future<void> deleteStationPrinterMappingsForRestaurant(String restaurantId);

  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  });

  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  });
}

abstract class PrintStationServicePort {
  Future<bool> isThisDevicePrintStation();

  Future<void> setThisDevicePrintStation(bool value);

  String currentPlatformLabel();

  String currentDeviceName();

  String normalizeStationPlatform(String? value);

  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId);

  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(String restaurantId);

  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  });

  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  });

  bool isStationOnline(Map<String, dynamic>? config);

  bool isLocalStationReady(Map<String, dynamic>? queueStatus);

  Future<Map<String, dynamic>?> saveStationConfiguration({
    required String restaurantId,
    required String deviceName,
    required String platformName,
    required String receiptPrinterId,
    required String receiptPrinterName,
    required String kitchenPrinterId,
    required String kitchenPrinterName,
    Map<String, dynamic>? roleMappings,
  });

  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  });

  Future<Map<String, dynamic>?> configureLocalBridgeAsPrintStation({
    required String restaurantId,
    required Session session,
    required String deviceName,
    required String platformName,
    required String receiptPrinterId,
    required String receiptPrinterName,
    required String kitchenPrinterId,
    required String kitchenPrinterName,
    String? bridgeTransportMode,
    String? bridgePrinterQueue,
    String? bridgeUsbVendorId,
    String? bridgeUsbProductId,
  });

  Future<Map<String, dynamic>?> fetchLocalQueueStatus();

  Future<String?> readRoleMappingCacheToken(String restaurantId);

  Future<String> invalidateRoleMappingCacheState({
    required String restaurantId,
    Map<String, dynamic>? roleMappings,
    String source = 'print_station_service',
  });
}
