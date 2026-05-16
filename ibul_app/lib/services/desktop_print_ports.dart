import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/printer_model.dart';

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
}
