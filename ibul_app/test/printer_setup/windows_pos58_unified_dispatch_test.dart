import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  UnifiedPrinterModel pos58Printer() =>
      UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'windows:POS-58',
        'name': 'POS-58',
        'queue': 'POS-58',
        'backend': 'windows-spool',
        'transportType': 'windows-spool',
        'ready': true,
        'statusLevel': 'ready',
      }, os: DesktopPrinterOs.windows);

  test('adisyon_test uses text/raw POS-58 payload on /print/receipt', () async {
    final capture = _Pos58PhysicalCaptureService();
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => capture,
    );
    final printer = pos58Printer();

    final result = await orchestrator.printPhysicalToPrinter(
      printer,
      PrintPayload.testForRole(PrinterSetupRole.adisyon),
      flowType: 'adisyon_test',
    );

    expect(result.ok, isTrue);
    expect(capture.lastReceiptBody?['printer_id'], 'windows:POS-58');
    expect(capture.lastReceiptBody?['printer_name'], 'POS-58');
    expect(capture.lastReceiptBody?['render_mode'], 'text');
    expect(capture.lastReceiptBody?['spool_mode'], 'RAW');
    expect(capture.lastReceiptBody?['flow_type'], 'adisyon_test');
    expect(capture.lastReceiptBody?['printer']?['backend'], 'windows-spool');
  });

  test('kitchen_test uses text/raw POS-58 payload on /print/kitchen', () async {
    final capture = _Pos58PhysicalCaptureService();
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => capture,
    );
    final printer = pos58Printer();

    final result = await orchestrator.printPhysicalToPrinter(
      printer,
      PrintPayload.testForRole(PrinterSetupRole.mutfak),
      flowType: 'kitchen_test',
    );

    expect(result.ok, isTrue);
    expect(capture.lastKitchenBody?['printer_id'], 'windows:POS-58');
    expect(capture.lastKitchenBody?['printer_name'], 'POS-58');
    expect(capture.lastKitchenBody?['render_mode'], 'text');
    expect(capture.lastKitchenBody?['spool_mode'], 'RAW');
    expect(capture.lastKitchenBody?['flow_type'], 'kitchen_test');
  });

  test('waiter_receipt payload defaults to text render for POS-58', () async {
    final capture = _Pos58PhysicalCaptureService();
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => capture,
    );
    final printer = pos58Printer();

    final result = await orchestrator.printPhysicalToPrinter(
      printer,
      PrintPayload(
        documentType: 'receipt',
        body: <String, dynamic>{
          'store_name': 'ibul',
          'table_no': '7',
          'items': const <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Corba', 'qty': 1, 'total': 10},
          ],
          'grand_total': 10,
          'render_mode': 'image',
        },
      ),
      flowType: 'waiter_receipt',
    );

    expect(result.ok, isTrue);
    expect(capture.lastReceiptBody?['render_mode'], 'text');
    expect(capture.lastReceiptBody?['spool_mode'], 'RAW');
    expect(capture.lastReceiptBody?['flow_type'], 'waiter_receipt');
  });

  test(
    'role_test with explicit live printer does not require printerRecordId',
    () async {
      final capture = _Pos58CaptureService();
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepo(),
        printStationService: _FakeStationService(),
        printServiceFactory: () => capture,
      );
      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'restaurant-1',
        forceRefresh: true,
      );
      final explicit = snapshot.livePrinters.firstWhere(
        (printer) => printer.id == 'windows:POS-58',
      );

      final result = await orchestrator.printTestReceipt(
        restaurantId: 'restaurant-1',
        role: PrinterSetupRole.adisyon,
        explicitLivePrinter: explicit,
        testSource: 'role_test',
      );

      expect(result.ok, isTrue);
      expect(capture.lastRenderMode, 'text');
    },
  );

  test(
    'prepareQueuedPrintPayload forces text mode for POS-58 receipt jobs',
    () async {
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepo(),
        printStationService: _FakeStationService(),
        printServiceFactory: () => _Pos58ProbeService(),
      );
      await orchestrator.savePrinterRoles(
        restaurantId: 'restaurant-1',
        receiptPrinterId: 'windows:POS-58',
        kitchenPrinterId: 'windows:POS-58',
      );

      final prepared = await orchestrator.prepareQueuedPrintPayload(
        restaurantId: 'restaurant-1',
        jobRecord: <String, dynamic>{'id': 'job-1', 'printer_role': 'adisyon'},
        payload: <String, dynamic>{
          'document_type': 'receipt',
          'printer_role': 'adisyon',
          'store_name': 'ibul',
          'table_no': '3',
          'items': const <Map<String, dynamic>>[],
          'render_mode': 'image',
        },
      );

      expect(prepared.printer?.id, 'windows:POS-58');
      expect(prepared.payload['render_mode'], 'text');
      expect(prepared.payload['spool_mode'], 'RAW');
    },
  );
}

class _Pos58PhysicalCaptureService extends _Pos58ProbeService {
  Map<String, dynamic>? lastReceiptBody;
  Map<String, dynamic>? lastKitchenBody;

  @override
  Future<Map<String, dynamic>?> printReceipt(
    Map<String, dynamic> payload,
  ) async {
    lastReceiptBody = Map<String, dynamic>.from(payload);
    return const <String, dynamic>{
      'ok': true,
      'queue_status': 'ready',
      'actual_backend': 'windows-spool',
      'bytes_sent': 512,
      'physical_confirmation': true,
      'render_mode': 'text',
    };
  }

  @override
  Future<Map<String, dynamic>?> printKitchen(
    Map<String, dynamic> payload, {
    String path = '/print/kitchen',
  }) async {
    lastKitchenBody = Map<String, dynamic>.from(payload);
    return const <String, dynamic>{
      'ok': true,
      'queue_status': 'ready',
      'actual_backend': 'windows-spool',
      'bytes_sent': 512,
      'physical_confirmation': true,
      'render_mode': 'text',
    };
  }
}

class _Pos58ProbeService extends LocalPrintService {
  _Pos58ProbeService() : super(baseUri: Uri.parse('http://127.0.0.1:3001'));

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
      const <String, dynamic>{
        'ok': true,
        'count': 1,
        'printers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'windows:POS-58',
            'name': 'POS-58',
            'queue': 'POS-58',
            'backend': 'windows-spool',
            'ready': true,
            'statusLevel': 'ready',
            'operatorTier': 'pos_candidate',
            'isPosCandidate': true,
          },
        ],
      };
}

class _Pos58CaptureService extends _Pos58ProbeService {
  String? lastRenderMode;

  @override
  Future<Map<String, dynamic>?> printTest({
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    Map<String, dynamic>? extraBody,
    String renderMode = 'text',
    String testMode = 'escpos_short',
    Duration? timeout,
  }) async {
    lastRenderMode = renderMode;
    return const <String, dynamic>{
      'ok': true,
      'queue_status': 'ready',
      'actual_backend': 'windows-spool',
      'bytes_sent': 256,
      'physical_confirmation': true,
    };
  }
}

class _FakePrinterRepo implements PrinterRepositoryPort {
  final List<PrinterModel> saved = <PrinterModel>[];

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async => saved;

  @override
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async => null;

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
  }) async {
    final newPrinter = PrinterModel(
      id: printerId ?? 'mock_printer_${DateTime.now().millisecondsSinceEpoch}',
      restaurantId: restaurantId,
      name: name,
      code: code,
      connectionType: connectionType,
      ipAddress: ipAddress,
      port: port,
      deviceIdentifier: deviceIdentifier,
      paperWidthMm: paperWidthMm,
      isActive: isActive,
      supportsCut: supportsCut,
      charset: charset,
      codePage: codePage,
      assignedRoles: assignedRoles,
      printerProfileId: printerProfileId,
      createdAt: DateTime.now(),
    );
    saved.add(newPrinter);
    return newPrinter;
  }

  @override
  Future<void> updateAssignedRoles(
    String printerId,
    List<PrinterRole> roles,
  ) async {}

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(
    String restaurantId,
  ) async => const <dynamic>[];

  @override
  Future<void> deletePrinter(String printerId) async {}

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(
    String restaurantId,
  ) async {}

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {}

  Future<void> updatePrinterStatus({
    required String printerId,
    required bool isActive,
  }) async {}
}

class _FakeStationService implements PrintStationServicePort {
  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async =>
      <String, dynamic>{};

  @override
  Future<String> invalidateRoleMappingCacheState({
    required String restaurantId,
    Map<String, dynamic>? roleMappings,
    String source = 'print_station_service',
  }) async => 'test_token';

  @override
  Future<String?> readRoleMappingCacheToken(String restaurantId) async => 'test_token';

  @override
  Future<bool> isThisDevicePrintStation() async => false;

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}

  @override
  String currentPlatformLabel() => 'windows';

  @override
  String currentDeviceName() => 'test-device';

  @override
  String normalizeStationPlatform(String? value) => 'windows';

  @override
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(
    String restaurantId,
  ) async => const <Map<String, dynamic>>[];

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async => true;

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async => true;

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => false;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => false;

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
  }) async => null;

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async => null;

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
  }) async => null;
}
