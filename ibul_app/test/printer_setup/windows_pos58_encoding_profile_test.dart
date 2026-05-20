import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/turkish_encoding_calibration.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:ibul_app/services/printer_encoding_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  UnifiedPrinterModel pos58() => UnifiedPrinterModel.fromBridgeMap(
    <String, dynamic>{
      'id': 'windows:POS-58',
      'name': 'POS-58',
      'queue': 'POS-58',
      'backend': 'windows-spool',
      'ready': true,
    },
    os: DesktopPrinterOs.windows,
  );

  test('physical print injects saved encoding profile', () async {
    final store = PrinterEncodingProfileStore();
    await store.saveFromCandidate(
      restaurantId: 'restaurant-1',
      printerId: 'windows:POS-58',
      candidate: kTurkishEncodingCalibrationCandidates.first,
    );
    final capture = _EncodingCaptureService();
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => capture,
      encodingProfileStore: store,
    );

    final result = await orchestrator.printPhysicalToPrinter(
      pos58(),
      PrintPayload.testForRole(PrinterSetupRole.adisyon),
      restaurantId: 'restaurant-1',
      flowType: 'adisyon_test',
    );

    expect(result.ok, isTrue);
    expect(capture.lastReceiptBody?['render_mode'], 'text');
    expect(capture.lastReceiptBody?['encoding'], 'cp857');
    expect(capture.lastReceiptBody?['codepage'], 13);
    expect(capture.lastReceiptBody?['codepage_command'], 'ESC t 13');
    expect(capture.lastReceiptBody?['esc_t_value'], 13);
    expect(capture.lastReceiptBody?['encoding_profile_missing'], isFalse);
    expect(capture.lastReceiptBody?['printer_encoding'], 'cp857');
    expect(capture.lastReceiptBody?['printer_code_page'], 13);
    expect(capture.lastReceiptBody?['encoding_profile_verified'], isTrue);
  });

  test('turkish combined calibration sends all candidates on one ticket', () async {
    final capture = _EncodingCaptureService();
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => capture,
    );

    final result = await orchestrator.printTurkishEncodingCalibrationSheet(
      restaurantId: 'restaurant-1',
      printer: pos58(),
    );

    expect(result.ok, isTrue);
    expect(capture.lastCalibrationBody?['render_mode'], 'text');
    expect(capture.lastCalibrationBody?['combined'], isTrue);
    expect(capture.lastCalibrationBody?['calibration_mode'], 'combined');
    final candidates =
        capture.lastCalibrationBody?['candidates'] as List<dynamic>?;
    expect(candidates?.length, kTurkishEncodingCalibrationCandidates.length);
    final firstLines = candidates?.first['lines'] as List<dynamic>?;
    expect(firstLines?.first, contains('cp857'));
    expect((firstLines?.length ?? 0) >= 3, isTrue);
    expect(
      kTurkishCalibrationPrimaryTestLine,
      'Türkçe: ığüşöç İĞÜŞÖÇ',
    );
  });

  test('prepareQueuedPrintPayload applies encoding without image mode', () async {
    final store = PrinterEncodingProfileStore();
    await store.saveFromCandidate(
      restaurantId: 'restaurant-1',
      printerId: 'windows:POS-58',
      candidate: kTurkishEncodingCalibrationCandidates.first,
    );
    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: _FakePrinterRepo(),
      printStationService: _FakeStationService(),
      printServiceFactory: () => _Pos58ProbeService(),
      encodingProfileStore: store,
    );
    await orchestrator.savePrinterRoles(
      restaurantId: 'restaurant-1',
      receiptPrinterId: 'windows:POS-58',
      kitchenPrinterId: 'windows:POS-58',
    );

    final prepared = await orchestrator.prepareQueuedPrintPayload(
      restaurantId: 'restaurant-1',
      jobRecord: <String, dynamic>{'printer_role': 'adisyon'},
      payload: <String, dynamic>{
        'document_type': 'receipt',
        'render_mode': 'image',
        'store_name': 'Test',
        'table_no': '1',
        'items': const <Map<String, dynamic>>[],
      },
    );

    expect(prepared.payload['render_mode'], 'text');
    expect(prepared.payload['encoding'], 'cp857');
    expect(prepared.payload['codepage'], 13);
    expect(prepared.payload['codepage_command'], 'ESC t 13');
  });

  test('encoding profile round-trip includes codepage_command', () async {
    const candidate = TurkishEncodingCandidate(
      id: 'cp1254_t21',
      label: 'CP1254',
      encoding: 'cp1254',
      codePage: 21,
    );
    final store = PrinterEncodingProfileStore();
    await store.saveFromCandidate(
      restaurantId: 'restaurant-1',
      printerId: 'windows:POS-58',
      candidate: candidate,
      printerName: 'POS-58',
    );
    final loaded = await store.load(
      restaurantId: 'restaurant-1',
      printerId: 'windows:POS-58',
    );
    expect(loaded?.codepageCommand, 'ESC t 21');
    expect(loaded?.effectiveCodepageCommand, 'ESC t 21');
  });
}

class _EncodingCaptureService extends _Pos58ProbeService {
  Map<String, dynamic>? lastReceiptBody;
  Map<String, dynamic>? lastCalibrationBody;

  @override
  Future<Map<String, dynamic>?> printReceipt(
    Map<String, dynamic> payload,
  ) async {
    lastReceiptBody = Map<String, dynamic>.from(payload);
    return const <String, dynamic>{
      'ok': true,
      'queue_status': 'ready',
      'bytes_sent': 128,
      'physical_confirmation': true,
    };
  }

  @override
  Future<Map<String, dynamic>?> printTurkishEncodingCalibrationCombined({
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    required List<Map<String, dynamic>> candidates,
    String? testLine,
    Duration? timeout,
  }) async {
    lastCalibrationBody = <String, dynamic>{
      'render_mode': 'text',
      'combined': true,
      'calibration_mode': 'combined',
      'candidates': candidates,
      'test_line': testLine,
    };
    return const <String, dynamic>{'ok': true, 'queue_status': 'ready'};
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
        'printers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'windows:POS-58',
            'name': 'POS-58',
            'queue': 'POS-58',
            'backend': 'windows-spool',
            'ready': true,
          },
        ],
      };
}

class _FakePrinterRepo implements PrinterRepositoryPort {
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
  Future<void> updateAssignedRoles(
    String printerId,
    List<PrinterRole> roles,
  ) async {}

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(
    String restaurantId,
  ) async =>
      const <dynamic>[];

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
