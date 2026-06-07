// Orchestrator-level integration tests for Ethernet / TCP printers.
//
// Verifies that a saved ``tcp:HOST:PORT`` printer:
//   - is synthesized into a ``UnifiedPrinterModel`` with ``backend=tcp``,
//   - is selected by both Adisyon and Mutfak role mappings even though it
//     is NOT in the bridge's live discovery output (Ethernet printers
//     don't show up on USB / CUPS scans),
//   - emits a bridge payload that contains ``host`` and ``port`` so the
//     local print bridge can route the job directly over TCP.
//
// These tests do NOT spin up the real bridge or hit the network; they use
// the same fake collaborators as the existing stale-printer tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PrinterModel _ethernetRow({
  String id = 'eth-printer-1',
  String name = 'NETUM ZJ-8360 Ethernet',
  String host = '192.168.1.100',
  int port = 9100,
  List<PrinterRole> assignedRoles = const <PrinterRole>[
    PrinterRole.receipt,
    PrinterRole.kitchen,
  ],
}) {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': id,
    'restaurant_id': 'restaurant-1',
    'name': name,
    'code': 'eth_${host.replaceAll('.', '_')}_$port',
    'connection_type': PrinterModel.networkConnectionType,
    'ip_address': host,
    'port': port,
    'device_identifier': PrinterModel.ethernetPrinterId(host: host, port: port),
    'paper_width_mm': 80,
    'is_active': true,
    'supports_cut': true,
    'charset': 'cp857',
    'assigned_roles': assignedRoles.map((r) => r.value).toList(),
    'created_at': DateTime(2026, 5, 1).toIso8601String(),
    'updated_at': DateTime(2026, 5, 1).toIso8601String(),
  });
}

PrinterModel _usbRow({
  String id = 'db-receipt',
  String name = 'POS-58',
  String deviceIdentifier = 'POS58_USB',
}) {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': id,
    'restaurant_id': 'restaurant-1',
    'name': name,
    'code': 'usb_receipt',
    'connection_type': PrinterModel.usbConnectionType,
    'device_identifier': deviceIdentifier,
    'paper_width_mm': 58,
    'is_active': true,
    'supports_cut': false,
    'charset': 'cp857',
    'assigned_roles': const <String>['receipt'],
    'created_at': DateTime(2026, 5, 1).toIso8601String(),
    'updated_at': DateTime(2026, 5, 1).toIso8601String(),
  });
}

DesktopPrintOrchestrator _orchestrator(PrinterModel ethernet) {
  return DesktopPrintOrchestrator(
    printerRepository: _FakeRepo(saved: <PrinterModel>[ethernet]),
    printStationService: _FakeStationService(),
    printServiceFactory: () => _FakeLocalPrintService(
      availability: LocalPrintHealthStatus(
        isAvailable: true,
        reason: 'ok',
        url: Uri.parse('http://127.0.0.1:3001/health'),
        durationMs: 5,
        statusCode: 200,
      ),
    ),
  );
}

Future<void> _saveRoleMapping(
  String restaurantId,
  PrinterSetupRole role,
  UnifiedPrinterModel printer,
) async {
  final localConfig = PrinterSetupLocalConfig(
    restaurantId: restaurantId,
    os: DesktopPrinterOs.macos,
    receiptSelection: role == PrinterSetupRole.adisyon
        ? PrinterRoleSelection(role: role, printer: printer)
        : null,
    kitchenSelection: role == PrinterSetupRole.mutfak
        ? PrinterRoleSelection(role: role, printer: printer)
        : null,
  );
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'ibul_unified_printer_setup_v1_$restaurantId',
    localConfig.encode(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Ethernet printer role mapping (adisyon / mutfak)', () {
    test(
      'Adisyon role resolves the saved Ethernet printer with backend=tcp',
      () async {
        final ethernet = _ethernetRow();
        final orchestrator = _orchestrator(ethernet);

        final unifiedSelection = UnifiedPrinterModel(
          id: PrinterModel.ethernetPrinterId(host: '192.168.1.100', port: 9100),
          displayName: ethernet.name,
          queueName: ethernet.name,
          backend: DesktopPrinterBackend.tcp,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          printerRecordId: ethernet.id,
          raw: const <String, dynamic>{
            'backend': 'tcp',
            'transportType': 'ethernet',
            'host': '192.168.1.100',
            'port': 9100,
          },
        );
        await _saveRoleMapping(
          'restaurant-1',
          PrinterSetupRole.adisyon,
          unifiedSelection,
        );

        final resolved = await orchestrator.resolvePrinterForRole(
          restaurantId: 'restaurant-1',
          role: PrinterSetupRole.adisyon,
        );

        expect(resolved, isNotNull);
        expect(resolved!.backend, DesktopPrinterBackend.tcp);
        expect(
          resolved.raw['host'] ??
              resolved.raw['ip_address'] ??
              resolved.raw['ipAddress'],
          '192.168.1.100',
        );
        expect(resolved.raw['port'], 9100);
      },
    );

    test(
      'Mutfak role resolves the saved Ethernet printer with backend=tcp',
      () async {
        final ethernet = _ethernetRow();
        final orchestrator = _orchestrator(ethernet);

        final unifiedSelection = UnifiedPrinterModel(
          id: PrinterModel.ethernetPrinterId(host: '192.168.1.100', port: 9100),
          displayName: ethernet.name,
          queueName: ethernet.name,
          backend: DesktopPrinterBackend.tcp,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          printerRecordId: ethernet.id,
          raw: const <String, dynamic>{
            'backend': 'tcp',
            'transportType': 'ethernet',
            'host': '192.168.1.100',
            'port': 9100,
          },
        );
        await _saveRoleMapping(
          'restaurant-1',
          PrinterSetupRole.mutfak,
          unifiedSelection,
        );

        final resolved = await orchestrator.resolvePrinterForRole(
          restaurantId: 'restaurant-1',
          role: PrinterSetupRole.mutfak,
        );

        expect(resolved, isNotNull);
        expect(resolved!.backend, DesktopPrinterBackend.tcp);
      },
    );

    test(
      'queued kitchen payload synthesizes tcp metadata from printer_id and preserves ethernet dispatch',
      () async {
        final ethernet = _ethernetRow();
        final orchestrator = _orchestrator(ethernet);

        final resolution = await orchestrator.prepareQueuedPrintPayload(
          restaurantId: 'restaurant-1',
          jobRecord: <String, dynamic>{
            'id': 'job-tcp-synth',
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
          },
          payload: <String, dynamic>{
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
            'printer_id': 'tcp:192.168.1.100:9100',
            'printer_name': 'pos-80',
            'station_name': 'Ocak',
          },
        );

        expect(resolution.printer, isNotNull);
        expect(resolution.printer!.backend, DesktopPrinterBackend.tcp);
        expect(resolution.payload['backend'], 'tcp');
        expect(resolution.payload['transportType'], 'ethernet');
        expect(resolution.payload['host'], '192.168.1.100');
        expect(resolution.payload['port'], 9100);
        expect(resolution.payload['paper_width_mm'], 80);
        expect(
          resolution.payload['printer_profile'],
          'generic_80mm_escpos',
        );
        expect(resolution.payload['render_mode'], 'image');
        expect(resolution.payload['raster_width_px'], 576);
      },
    );

    test(
      'direct test printer does not mutate saved receipt or kitchen role mapping',
      () async {
        final ethernet = _ethernetRow();
        final receipt = _usbRow();
        final fakePrint = _FakeLocalPrintService(
          availability: LocalPrintHealthStatus(
            isAvailable: true,
            reason: 'ok',
            url: Uri.parse('http://127.0.0.1:3001/health'),
            durationMs: 5,
            statusCode: 200,
          ),
          discoveredPrinters: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'usb:pos58',
              'name': 'POS-58',
              'queue': 'POS-58',
              'backend': 'usb-direct',
              'vendorId': '0x0416',
              'productId': '0x5011',
            },
          ],
        );
        final orchestrator = DesktopPrintOrchestrator(
          printerRepository: _FakeRepo(
            saved: <PrinterModel>[receipt, ethernet],
          ),
          printStationService: _FakeStationService(),
          printServiceFactory: () => fakePrint,
        );

        final receiptSelection = UnifiedPrinterModel(
          id: 'usb:pos58',
          displayName: 'POS-58',
          queueName: 'POS-58',
          backend: DesktopPrinterBackend.usbDirect,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          printerRecordId: 'db-receipt',
          raw: const <String, dynamic>{
            'backend': 'usb-direct',
            'vendorId': '0x0416',
            'productId': '0x5011',
          },
        );
        final kitchenSelection = UnifiedPrinterModel(
          id: 'tcp:192.168.1.100:9100',
          displayName: ethernet.name,
          queueName: ethernet.name,
          backend: DesktopPrinterBackend.tcp,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          printerRecordId: ethernet.id,
          raw: const <String, dynamic>{
            'backend': 'tcp',
            'transportType': 'ethernet',
            'host': '192.168.1.100',
            'port': 9100,
          },
        );

        final localConfig = PrinterSetupLocalConfig(
          restaurantId: 'restaurant-1',
          os: DesktopPrinterOs.macos,
          receiptSelection: PrinterRoleSelection(
            role: PrinterSetupRole.adisyon,
            printer: receiptSelection,
          ),
          kitchenSelection: PrinterRoleSelection(
            role: PrinterSetupRole.mutfak,
            printer: kitchenSelection,
          ),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'ibul_unified_printer_setup_v1_restaurant-1',
          localConfig.encode(),
        );

        final result = await orchestrator.printTestReceipt(
          restaurantId: 'restaurant-1',
          role: PrinterSetupRole.adisyon,
          explicitLivePrinter: kitchenSelection,
          testSource: 'direct_test',
        );

        expect(result.ok, isTrue);
        final snapshot = await orchestrator.loadSetupSnapshot(
          restaurantId: 'restaurant-1',
          forceRefresh: true,
        );
        expect(snapshot.localConfig?.receiptSelection?.printer.id, 'usb:pos58');
        expect(
          snapshot.localConfig?.kitchenSelection?.printer.id,
          'tcp:192.168.1.100:9100',
        );
        expect(
          snapshot.localConfig?.receiptTest?.printerId,
          'tcp:192.168.1.100:9100',
        );
      },
    );
  });
}

// ── test doubles ──────────────────────────────────────────────────────────

class _FakeRepo implements PrinterRepositoryPort {
  @override
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async => null;

  _FakeRepo({required this.saved});
  final List<PrinterModel> saved;

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async =>
      List<PrinterModel>.unmodifiable(saved);

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async {
    for (final p in saved) {
      if (p.id == printerId) return p;
    }
    return null;
  }

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async {
    for (final p in saved) {
      if (p.id == recordId) return p;
    }
    return null;
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
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(
    String restaurantId,
  ) async {
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

class _FakeLocalPrintService extends LocalPrintService {
  _FakeLocalPrintService({
    required this.availability,
    this.discoveredPrinters = const <Map<String, dynamic>>[],
  }) : super(baseUri: Uri.parse('http://127.0.0.1:3001'));

  final LocalPrintHealthStatus availability;
  final List<Map<String, dynamic>> discoveredPrinters;
  String? lastPrintTestPrinterId;
  Map<String, dynamic>? lastPrintTestPrinter;

  @override
  Future<LocalPrintHealthStatus> checkAvailability({Duration? timeout}) async {
    return availability;
  }

  @override
  Future<Map<String, dynamic>?> health({bool useCache = true}) async {
    return const <String, dynamic>{
      'ok': true,
      'printer': <String, dynamic>{'ok': true},
    };
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
    return <String, dynamic>{
      'ok': true,
      'count': discoveredPrinters.length,
      'printers': discoveredPrinters,
    };
  }

  @override
  Future<Map<String, dynamic>?> discover() async {
    return <String, dynamic>{
      'ok': true,
      'printers': discoveredPrinters,
      'usb': discoveredPrinters,
      'cups': <Map<String, dynamic>>[],
      'windows': <Map<String, dynamic>>[],
    };
  }

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
    lastPrintTestPrinterId = printerId;
    lastPrintTestPrinter = printer == null
        ? null
        : Map<String, dynamic>.from(printer);
    return <String, dynamic>{
      'ok': true,
      'printer_id': printerId,
      'printer_name': printerName,
      'backend': printer?['backend'],
      'transport': printer?['transportType'] ?? printer?['transport_type'],
    };
  }
}
