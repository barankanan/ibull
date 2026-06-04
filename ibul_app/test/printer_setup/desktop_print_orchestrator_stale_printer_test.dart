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

  test(
    'resolvePrinterForRole returns null when role mapping is stale and not discoverable',
    () async {
      final fakePrinterId = 'printer-record-1';
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepo(
          printerByRecordId: PrinterModel.fromMap(<String, dynamic>{
            'id': fakePrinterId,
            'restaurant_id': 'restaurant-1',
            'name': 'Old Printer',
            'code': 'OLD_PRINTER',
            'connection_type': 'usb',
            'ip_address': '127.0.0.1',
            'port': 3001,
            'device_identifier': 'Thermal58',
            'paper_width_mm': 58,
            'is_active': true,
            'supports_cut': false,
            'charset': 'cp857',
            'assigned_roles': const <String>['receipt'],
            'created_at': DateTime(2026, 5, 1).toIso8601String(),
            'updated_at': DateTime(2026, 5, 1).toIso8601String(),
          }),
        ),
        printStationService: _FakeStationService(),
        printServiceFactory: () => _FakeLocalPrintService(
          availability: LocalPrintHealthStatus(
            isAvailable: true,
            reason: 'ok',
            url: Uri.parse('http://127.0.0.1:3001/health'),
            durationMs: 5,
            statusCode: 200,
          ),
          printers: const <Map<String, dynamic>>[],
        ),
      );

      // Seed local role mapping pointing to a printer that is not present in live scan.
      final localConfig = PrinterSetupLocalConfig(
        restaurantId: 'restaurant-1',
        os: DesktopPrinterOs.macos,
        receiptSelection: PrinterRoleSelection(
          role: PrinterSetupRole.adisyon,
          printer: UnifiedPrinterModel(
            id: 'cups:Thermal58',
            displayName: 'Thermal58',
            queueName: 'Thermal58',
            backend: DesktopPrinterBackend.cups,
            os: DesktopPrinterOs.macos,
            isAvailable: true,
            canPrint: true,
            printerRecordId: fakePrinterId,
            raw: const <String, dynamic>{'source': 'saved_record'},
          ),
        ),
      );
      await _saveLocalConfig(orchestrator, localConfig);

      final resolved = await orchestrator.resolvePrinterForRole(
        restaurantId: 'restaurant-1',
        role: PrinterSetupRole.adisyon,
      );

      // Printer exists in DB but cannot be resolved to a live bridge printer → must return null.
      expect(resolved, isNull);
    },
  );

  test(
    'resolvePrinterForRole does NOT fall back to working printer when explicit role mapping exists but is stale',
    () async {
      final fakePrinterId = 'printer-record-1';
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepo(
          printerByRecordId: PrinterModel.fromMap(<String, dynamic>{
            'id': fakePrinterId,
            'restaurant_id': 'restaurant-1',
            'name': 'Old Printer',
            'code': 'OLD_PRINTER',
            'connection_type': 'usb',
            'ip_address': '127.0.0.1',
            'port': 3001,
            'device_identifier': 'Thermal58',
            'paper_width_mm': 58,
            'is_active': true,
            'supports_cut': false,
            'charset': 'cp857',
            'assigned_roles': const <String>['receipt'],
            'created_at': DateTime(2026, 5, 1).toIso8601String(),
            'updated_at': DateTime(2026, 5, 1).toIso8601String(),
          }),
        ),
        printStationService: _FakeStationService(),
        printServiceFactory: () => _FakeLocalPrintService(
          availability: LocalPrintHealthStatus(
            isAvailable: true,
            reason: 'ok',
            url: Uri.parse('http://127.0.0.1:3001/health'),
            durationMs: 5,
            statusCode: 200,
          ),
          printers: const <Map<String, dynamic>>[],
        ),
      );

      // Seed a working printer (canonical) but keep the role mapping stale.
      await orchestrator.saveWorkingPrinter(
        'restaurant-1',
        const UnifiedPrinterModel(
          id: 'usb-direct:pos58',
          displayName: 'POS58',
          queueName: 'POS58',
          backend: DesktopPrinterBackend.usbDirect,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          vendorId: '0x0416',
          productId: '0x5011',
          raw: <String, dynamic>{'source': 'usb_scan'},
        ),
      );

      // Seed local role mapping pointing to a printer that is not present in live scan.
      final localConfig = PrinterSetupLocalConfig(
        restaurantId: 'restaurant-1',
        os: DesktopPrinterOs.macos,
        receiptSelection: PrinterRoleSelection(
          role: PrinterSetupRole.adisyon,
          printer: UnifiedPrinterModel(
            id: 'cups:Thermal58',
            displayName: 'Thermal58',
            queueName: 'Thermal58',
            backend: DesktopPrinterBackend.cups,
            os: DesktopPrinterOs.macos,
            isAvailable: true,
            canPrint: true,
            printerRecordId: fakePrinterId,
            raw: const <String, dynamic>{'source': 'saved_record'},
          ),
        ),
      );
      await _saveLocalConfig(orchestrator, localConfig);

      final resolved = await orchestrator.resolvePrinterForRole(
        restaurantId: 'restaurant-1',
        role: PrinterSetupRole.adisyon,
      );

      // Even though a working printer exists, explicit role mapping is stale → no fallback.
      expect(resolved, isNull);
    },
  );
}

Future<void> _saveLocalConfig(
  DesktopPrintOrchestrator orchestrator,
  PrinterSetupLocalConfig config,
) async {
  // DesktopPrintOrchestrator persists local config in SharedPreferences.
  // Call a public API that writes local config: saveSingleRoleSelection requires snapshot + remote patch,
  // so we store it directly using SharedPreferences (same key scheme).
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'ibul_unified_printer_setup_v1_${config.restaurantId}',
    config.encode(),
  );
}

class _FakeLocalPrintService extends LocalPrintService {
  _FakeLocalPrintService({
    required this.availability,
    required List<Map<String, dynamic>> printers,
  }) : _printers = printers,
       super(baseUri: Uri.parse('http://127.0.0.1:3001'));

  final LocalPrintHealthStatus availability;
  final List<Map<String, dynamic>> _printers;

  @override
  Future<LocalPrintHealthStatus> checkAvailability({Duration? timeout}) async {
    return availability;
  }

  @override
  Future<Map<String, dynamic>?> health({bool useCache = true}) async {
    return const <String, dynamic>{'ok': true, 'printer': <String, dynamic>{'ok': true}};
  }

  @override
  Future<Map<String, dynamic>?> setupStatus() async {
    return const <String, dynamic>{'ok': true, 'status': 'ready'};
  }

  @override
  Future<Map<String, dynamic>?> setupPrerequisites() async {
    return const <String, dynamic>{
      'ok': true,
      'checks': <Map<String, dynamic>>[],
      'dependencies': <String, dynamic>{'cups': 'available'},
    };
  }

  @override
  Future<Map<String, dynamic>?> printers({bool useCache = true}) async {
    return <String, dynamic>{'ok': true, 'count': _printers.length, 'printers': _printers};
  }

  @override
  Future<Map<String, dynamic>?> discover() async {
    return <String, dynamic>{'ok': true, 'printers': _printers, 'usb': const [], 'cups': const [], 'windows': const []};
  }
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
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async {
    return const <String, dynamic>{
      'queue': <String, dynamic>{
        'enabled': true,
        'ready': true,
        'print_system_enabled': true,
      },
    };
  }

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async {
    return <String, dynamic>{
      'restaurant_id': restaurantId,
      'bridge_enabled': true,
      'print_system_enabled': true,
      'updated_at': DateTime(2026, 5, 1).toIso8601String(),
    };
  }

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => true;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => true;

  @override
  Future<bool> isThisDevicePrintStation() async => true;

  @override
  String currentPlatformLabel() => 'macos';

  @override
  String currentDeviceName() => 'ibul-macos-device';

  @override
  String normalizeStationPlatform(String? value) => 'macos';

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
  }) async {
    return const <String, dynamic>{'ok': true};
  }

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
  }) async {
    return const <String, dynamic>{'ok': true};
  }

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async {
    return <String, dynamic>{'ok': true, ...fields};
  }

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async {
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(String restaurantId) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async {
    return true;
  }

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}
}

class _FakePrinterRepo implements PrinterRepositoryPort {
  @override
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async => null;

  _FakePrinterRepo({this.printerByRecordId});
  final PrinterModel? printerByRecordId;

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async => const <PrinterModel>[];

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async {
    if (printerByRecordId != null && printerByRecordId!.id == recordId) {
      return printerByRecordId;
    }
    return null;
  }

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async {
    return await getPrinterByRecordId(printerId);
  }

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
    List<PrinterRole> assignedRoles = const <PrinterRole>[],
    String? printerProfileId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {}

  @override
  Future<void> updateAssignedRoles(String printerId, List<PrinterRole> roles) async {}

  @override
  Future<void> deletePrinter(String printerId) async {}

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {}

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId) async => const <dynamic>[];

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(String restaurantId) async {}
}

