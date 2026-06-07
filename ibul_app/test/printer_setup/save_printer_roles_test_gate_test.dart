import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('savePrinterRoles rejects when requireSuccessfulRoleTests and no tests', () async {
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => _FakePrintService(
        discoveredPrinters: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'windows:POS-58',
            'name': 'POS-58',
            'queue': 'POS-58',
            'backend': 'windows-spool',
            'ready': true,
            'statusLevel': 'ready',
            'recommended': true,
          },
        ],
      ),
    );

    final result = await orchestrator.savePrinterRoles(
      restaurantId: 'restaurant-1',
      receiptPrinterId: 'windows:POS-58',
      kitchenPrinterId: 'windows:POS-58',
      requireSuccessfulRoleTests: true,
    );

    expect(result.ok, isFalse);
    expect(result.status, 'test_required');
    expect(result.message, contains('test fişi'));
  });
}

class _FakePrintService extends LocalPrintService {
  _FakePrintService({required this.discoveredPrinters});

  final List<Map<String, dynamic>> discoveredPrinters;

  @override
  Future<LocalPrintHealthStatus> checkAvailability({Duration? timeout}) async =>
      LocalPrintHealthStatus(
        isAvailable: true,
        reason: 'ok',
        url: Uri.parse('http://127.0.0.1:3001/health'),
        durationMs: 1,
        statusCode: 200,
      );

  @override
  Future<Map<String, dynamic>?> health({bool useCache = true}) async =>
      const <String, dynamic>{'ok': true};

  @override
  Future<Map<String, dynamic>?> printers({bool useCache = true}) async =>
      <String, dynamic>{
        'ok': true,
        'count': discoveredPrinters.length,
        'printers': discoveredPrinters,
      };
}

class _FakeStationService implements PrintStationServicePort {
  @override
  Future<String> invalidateRoleMappingCacheState({
    required String restaurantId,
    Map<String, dynamic>? roleMappings,
    String source = 'print_station_service',
  }) async => 'mock_token';

  @override
  Future<String?> readRoleMappingCacheToken(String restaurantId) async => 'mock_token';

  @override
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async => null;

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async =>
      null;

  @override
  Future<bool> isThisDevicePrintStation() async => false;

  @override
  String currentPlatformLabel() => 'windows';

  @override
  String currentDeviceName() => 'test-device';

  @override
  String normalizeStationPlatform(String? value) => 'windows';

  @override
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
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> saveStationConfiguration({
    required String restaurantId,
    required String deviceName,
    required String platformName,
    required String receiptPrinterId,
    required String receiptPrinterName,
    required String kitchenPrinterId,
    required String kitchenPrinterName,
    Map<String, dynamic>? roleMappings,
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async =>
      null;

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async =>
      true;

  @override
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(
    String restaurantId,
  ) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async =>
      true;

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => false;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => false;
}

class _FakePrinterRepo implements PrinterRepositoryPort {
  @override
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async => null;

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async =>
      const <PrinterModel>[];

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async => null;

  @override
  Future<PrinterModel?> getPrinterByRecordId(String printerRecordId) async =>
      null;

  @override
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePrinter(String printerId) async {}

  @override
  Future<void> updateAssignedRoles(
    String printerId,
    List<PrinterRole> roles,
  ) async {}

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId) async =>
      const <dynamic>[];

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(
    String restaurantId,
  ) async {}

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {}

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {}
}
