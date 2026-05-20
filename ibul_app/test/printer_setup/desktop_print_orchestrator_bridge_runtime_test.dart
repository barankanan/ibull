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

  test('setup/status ok:false does not mark bridge offline when /health and /printers work', () async {
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => _ProbeFakeService(
        availability: LocalPrintHealthStatus(
          isAvailable: true,
          reason: 'ok',
          url: Uri.parse('http://127.0.0.1:3001/health'),
          durationMs: 4,
          statusCode: 200,
        ),
        healthBody: const <String, dynamic>{'ok': true},
        setupStatusBody: const <String, dynamic>{
          'ok': false,
          'status': 'bridge_not_running',
          'errorCode': 'bridge_not_running',
        },
        printers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'windows:POS-80',
            'name': 'POS-80',
            'queue': 'POS-80',
            'backend': 'windows-spool',
            'ready': true,
            'statusLevel': 'ready',
          },
          <String, dynamic>{
            'id': 'windows:Receipt',
            'name': 'Receipt',
            'queue': 'Receipt',
            'backend': 'windows-spool',
            'ready': true,
            'statusLevel': 'ready',
          },
        ],
      ),
    );

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'restaurant-1',
      forceRefresh: true,
    );

    expect(snapshot.bridgeReachable, isTrue);
    expect(snapshot.bridgeHealthy, isTrue);
    expect(snapshot.livePrinterCount, 2);
    expect(snapshot.setupStatus?['status'], isNot('bridge_not_running'));
    expect(snapshot.operatorSetupStatusKey, 'printer_selection_pending');
  });

  test('stale Mac saved_record is not selectable for roles on Windows', () async {
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(
        saved: <PrinterModel>[
          PrinterModel.fromMap(<String, dynamic>{
            'id': 'mac-record-1',
            'restaurant_id': 'restaurant-1',
            'name': 'STMicroelectronics_POS58_Printer_USB',
            'code': 'POS58',
            'connection_type': 'usb',
            'device_identifier': 'STMicroelectronics_POS58_Printer_USB',
            'paper_width_mm': 58,
            'is_active': true,
            'supports_cut': false,
            'charset': 'cp857',
            'assigned_roles': const <String>['receipt', 'kitchen'],
            'created_at': DateTime(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime(2026, 1, 1).toIso8601String(),
          }),
        ],
      ),
      printStationService: _FakeStationService(),
      printServiceFactory: () => _ProbeFakeService(
        availability: LocalPrintHealthStatus(
          isAvailable: true,
          reason: 'ok',
          url: Uri.parse('http://127.0.0.1:3001/health'),
          durationMs: 4,
          statusCode: 200,
        ),
        healthBody: const <String, dynamic>{'ok': true},
        printers: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'windows:POS-80',
            'name': 'POS-80',
            'queue': 'POS-80',
            'backend': 'windows-spool',
            'ready': true,
            'statusLevel': 'ready',
          },
        ],
      ),
    );

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'restaurant-1',
      forceRefresh: true,
    );

    expect(snapshot.livePrinterCount, 1);
    expect(
      snapshot.livePrinters.any(
        (p) => p.displayName.contains('STMicroelectronics'),
      ),
      isFalse,
    );
    expect(snapshot.localConfig?.receiptSelection, isNull);
    for (final printer in snapshot.printers) {
      if (printer.displayName.contains('STMicroelectronics')) {
        expect(isSelectableLivePrinter(printer), isFalse);
        expect(printer.isStaleSavedMapping, isTrue);
      }
    }
  });

  test('isSelectableLivePrinter rejects stale saved_record', () {
    const stale = UnifiedPrinterModel(
      id: 'saved',
      displayName: 'STMicroelectronics_POS58_Printer_USB',
      queueName: 'STMicroelectronics_POS58_Printer_USB',
      backend: DesktopPrinterBackend.windowsSpool,
      os: DesktopPrinterOs.windows,
      isAvailable: false,
      canPrint: false,
      raw: <String, dynamic>{'source': 'saved_record'},
    );
    const live = UnifiedPrinterModel(
      id: 'windows:POS-80',
      displayName: 'POS-80',
      queueName: 'POS-80',
      backend: DesktopPrinterBackend.windowsSpool,
      os: DesktopPrinterOs.windows,
      isAvailable: true,
      canPrint: true,
      raw: <String, dynamic>{'source': 'usb_scan'},
    );

    expect(isSelectableLivePrinter(stale), isFalse);
    expect(isSelectableLivePrinter(live), isTrue);
  });

  test('minimal snapshot skips setup/status/prerequisites/queue/discover calls', () async {
    var factoryCalls = 0;
    final svc = _CountingProbeService(
      availability: LocalPrintHealthStatus(
        isAvailable: true,
        reason: 'ok',
        url: Uri.parse('http://127.0.0.1:3001/health'),
        durationMs: 1,
        statusCode: 200,
      ),
      healthBody: const <String, dynamic>{'ok': true},
      printers: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'windows:POS-58',
          'name': 'POS-58',
          'queue': 'POS-58',
          'backend': 'windows-spool',
          'ready': true,
          'statusLevel': 'ready',
        },
      ],
    );
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () {
        factoryCalls += 1;
        return svc;
      },
    );

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'restaurant-1',
      forceRefresh: true,
      minimal: true,
    );

    expect(snapshot.bridgeReachable, isTrue);
    expect(snapshot.bridgeHealthy, isTrue);
    expect(snapshot.livePrinterCount, 1);
    expect(factoryCalls, 1, reason: 'service instance should be reused');
    expect(svc.setupStatusCalls, 0);
    expect(svc.setupPrereqCalls, 0);
    expect(svc.discoverCalls, 0);
  });
}

class _ProbeFakeService extends LocalPrintService {
  _ProbeFakeService({
    required this.availability,
    required this.healthBody,
    required List<Map<String, dynamic>> printers,
    this.setupStatusBody,
  }) : _printers = printers,
       super(baseUri: Uri.parse('http://127.0.0.1:3001'));

  final LocalPrintHealthStatus availability;
  final Map<String, dynamic>? healthBody;
  final Map<String, dynamic>? setupStatusBody;
  final List<Map<String, dynamic>> _printers;

  @override
  Future<LocalPrintHealthStatus> checkAvailability({Duration? timeout}) async =>
      availability;

  @override
  Future<Map<String, dynamic>?> health({bool useCache = true}) async =>
      healthBody;

  @override
  Future<Map<String, dynamic>?> setupStatus() async => setupStatusBody;

  @override
  Future<Map<String, dynamic>?> setupPrerequisites() async => const <String, dynamic>{
    'ok': false,
    'checks': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>?> printers({bool useCache = true}) async =>
      <String, dynamic>{
    'ok': true,
    'count': _printers.length,
    'printers': _printers,
  };
}

class _CountingProbeService extends _ProbeFakeService {
  _CountingProbeService({
    required super.availability,
    required super.healthBody,
    required super.printers,
    super.setupStatusBody,
  });

  int setupStatusCalls = 0;
  int setupPrereqCalls = 0;
  int discoverCalls = 0;

  @override
  Future<Map<String, dynamic>?> setupStatus() async {
    setupStatusCalls += 1;
    return super.setupStatus();
  }

  @override
  Future<Map<String, dynamic>?> setupPrerequisites() async {
    setupPrereqCalls += 1;
    return super.setupPrerequisites();
  }

  @override
  Future<Map<String, dynamic>?> discover() async {
    discoverCalls += 1;
    return super.discover();
  }
}

class _FakeStationService implements PrintStationServicePort {
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
