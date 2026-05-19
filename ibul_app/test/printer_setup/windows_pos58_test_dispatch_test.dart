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

  test('/printers exposes POS-58 as windows:POS-58 with queue POS-58', () async {
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => _Pos58ProbeService(),
    );

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'restaurant-1',
      forceRefresh: true,
    );

    final pos58 = snapshot.livePrinters.firstWhere(
      (printer) => printer.queueName == 'POS-58',
    );
    expect(pos58.id, 'windows:POS-58');
    expect(pos58.backend, DesktopPrinterBackend.windowsSpool);
    expect(pos58.canPrint, isTrue);
  });

  test('wizard_test sends POS-58 queue to bridge without role fallback', () async {
    final capture = _Pos58CaptureService();
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(
        saved: <PrinterModel>[
          PrinterModel.fromMap(<String, dynamic>{
            'id': 'mac-record-1',
            'restaurant_id': 'restaurant-1',
            'name': 'Generic / Text Only',
            'code': 'GENERIC',
            'connection_type': 'usb',
            'device_identifier': 'Generic / Text Only',
            'paper_width_mm': 58,
            'is_active': true,
            'supports_cut': false,
          }),
        ],
      ),
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
      printerId: 'windows:POS-58',
      explicitLivePrinter: explicit,
      testSource: 'wizard_test',
    );

    expect(result.ok, isTrue);
    expect(capture.lastPrinterId, 'windows:POS-58');
    expect(capture.lastPrinterName, 'POS-58');
    expect(capture.lastPrinter?['backend'], 'windows-spool');
    expect(capture.lastPrinter?['queue'], 'POS-58');
    expect(
      capture.lastPrinter?['name'],
      'POS-58',
    );
    expect(capture.lastRenderMode, 'text');
    expect(capture.lastTestMode, 'escpos_short');
  });

  test('Windows POS-58 with POS58 VID/PID stays on windows-spool', () {
    final printer = UnifiedPrinterModel.fromBridgeMap(
      <String, dynamic>{
        'id': 'windows:POS-58',
        'name': 'POS-58',
        'queue': 'POS-58',
        'backend': 'windows-spool',
        'vendorId': '0x0416',
        'productId': '0x5011',
        'statusLevel': 'ready',
        'ready': true,
        'operatorTier': 'pos_candidate',
        'isPosCandidate': true,
        'portName': 'USB002',
      },
      os: DesktopPrinterOs.windows,
    );

    expect(printer.backend, DesktopPrinterBackend.windowsSpool);
    expect(printer.queueName, 'POS-58');
  });
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
  Future<Map<String, dynamic>?> health() async => const <String, dynamic>{
    'ok': true,
  };

  @override
  Future<Map<String, dynamic>?> printers() async => const <String, dynamic>{
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
        'portName': 'USB002',
        'driverName': 'POS-58 11.3.0.1',
        'connectionType': 'usb',
      },
    ],
  };
}

class _FakePrinterRepo implements PrinterRepositoryPort {
  _FakePrinterRepo({this.saved = const <PrinterModel>[]});

  final List<PrinterModel> saved;

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async => saved;

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
  Future<void> updateAssignedRoles(String printerId, List<PrinterRole> roles) async {}

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId) async =>
      const <dynamic>[];

  @override
  Future<void> deletePrinter(String printerId) async {}

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(String restaurantId) async {}

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {}
}

class _FakeStationService implements PrintStationServicePort {
  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async =>
      null;

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
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(String restaurantId) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async =>
      true;

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async =>
      true;

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
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async =>
      null;

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
}

class _Pos58CaptureService extends _Pos58ProbeService {
  String? lastPrinterId;
  String? lastPrinterName;
  Map<String, dynamic>? lastPrinter;
  String? lastRenderMode;
  String? lastTestMode;

  @override
  Future<Map<String, dynamic>?> printTest({
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    String renderMode = 'text',
    String testMode = 'escpos_short',
    Duration? timeout,
  }) async {
    lastPrinterId = printerId;
    lastPrinterName = printerName;
    lastPrinter = printer == null ? null : Map<String, dynamic>.from(printer);
    lastRenderMode = renderMode;
    lastTestMode = testMode;
    return <String, dynamic>{
      'ok': true,
      'queue_status': 'ready',
      'selected_queue': printerName,
      'actual_backend': 'windows-spool',
      'bytes_sent': 256,
      'physical_confirmation': true,
    };
  }
}
