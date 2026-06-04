import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/print_job_model.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/station_model.dart';
import 'package:ibul_app/models/station_printer_model.dart';
import 'package:ibul_app/screens/seller/kitchen_print_management_page.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/print_job_repository.dart';
import 'package:ibul_app/services/print_station_service.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:ibul_app/services/station_repository.dart';
import 'package:ibul_app/services/store_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  testWidgets(
    'Yazici Merkezi tabinda Baski Sistemi karti her zaman render edilir ve kapali durumu gosterir',
    (tester) async {
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: false,
        remoteEnabled: false,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
      );

      expect(find.text('Baskı Sistemi'), findsOneWidget);
      expect(find.text('Baskı Sistemini Aç'), findsOneWidget);
    },
  );

  testWidgets(
    'Aç butonu local ve remote durumu gunceller ve queue status print_system_disabled durumundan cikar',
    (tester) async {
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: false,
        remoteEnabled: false,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
      );

      await tester.tap(find.text('Baskı Sistemini Aç'));
      await tester.pumpAndSettle();

      expect(stationService.toggleCalls, isNotEmpty);
      expect(stationService.toggleCalls.last, isTrue);
      expect(find.text('Baskı sistemi açıldı'), findsOneWidget);
    },
  );

  testWidgets(
    'Sistem kapaliyken Yazicilar tabindaki Test butonu net kapali mesaji gosterir',
    (tester) async {
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: false,
        remoteEnabled: false,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
      );

      await tester.tap(find.text('Yazıcılar'));
      await _settle(tester);

      await tester.tap(find.text('Test'));
      await _settle(tester);

      expect(
        find.textContaining('Baskı sistemi kapalı. Test göndermek için sistemi açın.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Baskı sistemi açıkken Kapat butonu görünür ve toggle servisi çağrılır',
    (tester) async {
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: true,
        remoteEnabled: true,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
      );

      expect(find.text('Baskı Sistemini Kapat'), findsOneWidget);

      await tester.tap(find.text('Baskı Sistemini Kapat'));
      await tester.pumpAndSettle();

      expect(stationService.toggleCalls, isNotEmpty);
      expect(stationService.toggleCalls.last, isFalse);
      expect(find.text('Baskı sistemi kapatıldı'), findsOneWidget);
    },
  );

  testWidgets(
    'Toggle başarısız olursa rollback yapar ve gerçek hatayı gösterir',
    (tester) async {
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: false,
        remoteEnabled: false,
        failNextToggle: true,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
      );

      await tester.tap(find.text('Baskı Sistemini Aç'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bridge toggle rejected'), findsWidgets);
      expect(find.text('Baskı Sistemini Aç'), findsOneWidget);
    },
  );

  testWidgets(
    'Test dialog testten gecince yazici canonical kayda eklenir ve Yazicilar/Eslestirme listelerinde gorunur',
    (tester) async {
      final printerRepository = _FakeKitchenPrinterRepository();
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: true,
        remoteEnabled: true,
      );
      final orchestrator = _FakeTestOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
        printerRepository: printerRepository,
      );

      await tester.tap(find.text('Yazıcılar'));
      await _settle(tester);

      await tester.tap(find.text('Test'));
      await _settle(tester);

      expect(find.text('Test Fişi Gönder'), findsOneWidget);

      // Dialog action
      await tester.tap(find.widgetWithText(FilledButton, 'Test Gönder'));
      await _settle(tester);
      await tester.tap(find.text('Kapat'));
      await _settle(tester);

      await tester.tap(find.text('Eşleştirme'));
      await _settle(tester);

      // Dropdown should list the saved printer.
      await tester.tap(
        find.byKey(const ValueKey<String>('role-receipt-none')),
      );
      await _settle(tester);
      expect(find.text('USB Test Yazıcısı'), findsWidgets);
    },
  );

  testWidgets(
    'Bridge yazici goruyor ama DB bos ise "Yerel yazici bulundu ama kayitli degil" karti gosterilir',
    (tester) async {
      final printerRepository = _FakeKitchenPrinterRepository();
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: true,
        remoteEnabled: true,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
        printerRepository: printerRepository,
      );

      // Default tab is Print Station.
      expect(find.text('Yerel yazıcı bulundu ama kayıtlı değil'), findsOneWidget);
      expect(find.text('Yazıcıyı Kaydet'), findsOneWidget);
      expect(find.text('Kaydet ve İkisi İçin Kullan'), findsOneWidget);
    },
  );

  testWidgets(
    'Legacy bridge id role mapping varsa aktif yazici gosterilmez ve onar karti gorunur',
    (tester) async {
      final printerRepository = _FakeKitchenPrinterRepository();
      final stationService = _FakeKitchenPrintStationService(
        localEnabled: true,
        remoteEnabled: true,
      );
      final orchestrator = _FakeKitchenPrintOrchestrator(stationService);
      orchestrator.injectLegacyLocalConfig = true;

      await _pumpPage(
        tester,
        stationService: stationService,
        orchestrator: orchestrator,
        printerRepository: printerRepository,
      );

      expect(find.text('Bu eşleştirme eski formatta'), findsOneWidget);
      // Active printer rows should not resolve to a DB UUID, so mapping CTA is visible.
      expect(find.text('Yazıcı Eşleştir'), findsWidgets);
      expect(find.text('Onar ve eşleştir'), findsOneWidget);
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Avoid pumpAndSettle timeouts due to background async tasks.
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeKitchenPrintStationService stationService,
  required _FakeKitchenPrintOrchestrator orchestrator,
  PrinterRepository? printerRepository,
}) async {
  tester.view.physicalSize = const Size(1600, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: KitchenPrintManagementPage(
        restaurantId: 'restaurant-1',
        stationRepository: _FakeStationRepository(),
        printerRepository: printerRepository ?? _FakeKitchenPrinterRepository(),
        printJobRepository: _FakePrintJobRepository(),
        orderPrintJobService: _FakeOrderPrintJobService(),
        storeService: _FakeStoreService(),
        printStationService: stationService,
        printOrchestrator: orchestrator,
      ),
    ),
  );
  await _settle(tester);
}

class _FakeKitchenPrintStationService extends PrintStationService {
  _FakeKitchenPrintStationService({
    required this.localEnabled,
    required this.remoteEnabled,
    this.failNextToggle = false,
  });

  bool localEnabled;
  bool remoteEnabled;
  bool failNextToggle;
  final List<bool> toggleCalls = <bool>[];

  @override
  Future<bool> isThisDevicePrintStation() async => true;

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async {
    return <String, dynamic>{
      'restaurant_id': restaurantId,
      'print_system_enabled': remoteEnabled,
      'device_platform': 'macos',
      'last_seen_at': DateTime(2026, 5, 6, 10, 0).toIso8601String(),
      'bridge_status': localEnabled ? 'running' : 'print_system_disabled',
    };
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
    toggleCalls.add(enabled);
    if (failNextToggle) {
      failNextToggle = false;
      throw Exception('Bridge toggle rejected');
    }
    localEnabled = enabled;
    remoteEnabled = enabled;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async {
    remoteEnabled = fields['print_system_enabled'] == true;
    return <String, dynamic>{
      'restaurant_id': restaurantId,
      'print_system_enabled': remoteEnabled,
      'device_platform': 'macos',
      'last_seen_at': DateTime(2026, 5, 6, 10, 0).toIso8601String(),
      'bridge_status': localEnabled ? 'running' : 'print_system_disabled',
    };
  }

  @override
  bool isStationOnline(Map<String, dynamic>? config) => true;

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => localEnabled;

  @override
  String normalizeStationPlatform(String? value) => 'macos';
}

class _FakeKitchenPrintOrchestrator extends DesktopPrintOrchestrator {
  _FakeKitchenPrintOrchestrator(this.stationService)
    : super(printStationService: stationService);

  final _FakeKitchenPrintStationService stationService;
  bool injectLegacyLocalConfig = false;

  @override
  Future<PrinterSetupSnapshot> loadSetupSnapshot({
    required String restaurantId,
    bool forceRefresh = false,
    bool minimal = false,
    String flowName = 'setup_snapshot',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final localCfg = injectLegacyLocalConfig
        ? PrinterSetupLocalConfig(
            restaurantId: restaurantId,
            os: DesktopPrinterOs.macos,
            receiptSelection: PrinterRoleSelection(
              role: PrinterSetupRole.adisyon,
              printer: UnifiedPrinterModel(
                id: 'usb:printer-1',
                displayName: 'USB Test Yazıcısı',
                queueName: 'USB_TEST',
                backend: DesktopPrinterBackend.usbDirect,
                os: DesktopPrinterOs.macos,
                isAvailable: true,
                canPrint: true,
                printerRecordId: null,
                raw: const <String, dynamic>{'source': 'usb_scan'},
              ),
            ),
            kitchenSelection: PrinterRoleSelection(
              role: PrinterSetupRole.mutfak,
              printer: UnifiedPrinterModel(
                id: 'cups:printer-1',
                displayName: 'CUPS Test Yazıcısı',
                queueName: 'CUPS_TEST',
                backend: DesktopPrinterBackend.cups,
                os: DesktopPrinterOs.macos,
                isAvailable: true,
                canPrint: true,
                printerRecordId: null,
                raw: const <String, dynamic>{'source': 'usb_scan'},
              ),
            ),
          )
        : null;
    return PrinterSetupSnapshot(
      os: DesktopPrinterOs.macos,
      bridgeReachable: true,
      bridgeHealthy: stationService.localEnabled,
      bridgeHealth: <String, dynamic>{
        'ok': stationService.localEnabled,
        'printer': <String, dynamic>{'ok': stationService.localEnabled},
      },
      printers: <UnifiedPrinterModel>[
        UnifiedPrinterModel(
          id: 'usb:printer-1',
          displayName: 'USB Test Yazıcısı',
          queueName: 'USB_TEST',
          backend: DesktopPrinterBackend.usbDirect,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          raw: const <String, dynamic>{'source': 'usb_scan'},
        ),
      ],
      steps: const <PrinterSetupStepStatus>[],
      remoteConfig: <String, dynamic>{
        'restaurant_id': restaurantId,
        'print_system_enabled': stationService.remoteEnabled,
        'device_platform': 'macos',
        'last_seen_at': DateTime(2026, 5, 6, 10, 0).toIso8601String(),
        'bridge_status': stationService.localEnabled
            ? 'running'
            : 'print_system_disabled',
      },
      queueStatus: <String, dynamic>{
        'queue': <String, dynamic>{
          'enabled': true,
          'ready': stationService.localEnabled,
          'print_system_enabled': stationService.localEnabled,
          'runtime': <String, dynamic>{
            'status': stationService.localEnabled
                ? 'polling'
                : 'print_system_disabled',
            'running': stationService.localEnabled,
            'lastError': null,
          },
        },
      },
      setupStatus: <String, dynamic>{
        'status': stationService.localEnabled ? 'ready' : 'setup_required',
      },
      prerequisites: const <String, dynamic>{'checks': <Map<String, dynamic>>[]},
      discoveryWarning: null,
      bridgeStatusLabel: stationService.localEnabled ? 'Hazir' : 'Kapali',
      localConfig: localCfg,
    );
  }
}

class _FakeTestOrchestrator extends _FakeKitchenPrintOrchestrator {
  _FakeTestOrchestrator(super.stationService);

  @override
  Future<PrinterActionResult> printBridgeTest({
    required String restaurantId,
    covariant dynamic explicitPrinter,
    String? printerId,
    String? printerName,
    String? targetHost,
    Map<String, dynamic>? extraBody,
    int? targetPort,
    String? encoding,
    int? codePage,
    String renderMode = 'image',
    String testMode = 'escpos_short',
    bool skipSetupSnapshot = false,
    String flowName = 'generic_printer_test',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    final snapshot = await loadSetupSnapshot(
      restaurantId: restaurantId,
      forceRefresh: true,
    );
    final printer = snapshot.printers.first;
    return PrinterActionResult(
      ok: true,
      status: 'ready',
      message: 'OK',
      printer: printer,
      raw: const <String, dynamic>{
        'transport': 'usb-direct',
        'confirmation_status': 'cups_accepted_unverified',
      },
    );
  }
}

class _FakeKitchenPrinterRepository extends PrinterRepository {
  final List<PrinterModel> _printers = <PrinterModel>[];
  final StreamController<List<PrinterModel>> _controller =
      StreamController<List<PrinterModel>>.broadcast();

  @override
  Stream<List<PrinterModel>> watchPrinters(String restaurantId) {
    _controller.add(List<PrinterModel>.from(_printers));
    return _controller.stream;
  }

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async {
    return List<PrinterModel>.from(_printers);
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
    List<PrinterRole> assignedRoles = const [],
    String? printerProfileId,
  }) async {
    final id = printerId?.trim().isNotEmpty == true
        ? printerId!.trim()
        : 'db-${_printers.length + 1}';
    final model = PrinterModel(
      id: id,
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
      createdAt: DateTime(2026, 5, 6),
    );
    final idx = _printers.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _printers[idx] = model;
    } else {
      _printers.add(model);
    }
    _controller.add(List<PrinterModel>.from(_printers));
    return model;
  }

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
    String? transport,
    String? jobId,
    int? bytesSent,
    Map<String, dynamic>? raw,
  }) async {}

  @override
  Future<List<StationPrinterModel>> fetchStationPrinterMappings(
    String restaurantId,
  ) async {
    return const <StationPrinterModel>[];
  }

  @override
  Future<void> assignPrinterToStation({
    String? restaurantId,
    required String stationId,
    required String printerId,
    String? printerName,
    String? stationName,
    bool isPrimary = true,
  }) async {}

  @override
  Future<void> setPrinterActive(String printerId, bool isActive) async {}
}

class _FakeStationRepository extends StationRepository {
  @override
  Stream<List<StationModel>> watchStations(String restaurantId) {
    return const Stream<List<StationModel>>.empty();
  }

  @override
  Future<List<StationModel>> fetchStations(String restaurantId) async {
    return const <StationModel>[];
  }
}

class _FakeStoreService extends StoreService {
  @override
  Future<List<Map<String, dynamic>>> getMenuProductsBySellerId(
    String sellerId,
  ) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Stream<List<Map<String, dynamic>>> getTableOrdersStream(String sellerId) {
    return Stream<List<Map<String, dynamic>>>.value(
      const <Map<String, dynamic>>[],
    );
  }
}

class _FakePrintJobRepository extends PrintJobRepository {
  @override
  Stream<List<PrintJobModel>> watchJobs(String restaurantId, {String? status}) {
    return Stream<List<PrintJobModel>>.value(const <PrintJobModel>[]);
  }
}

class _FakeOrderPrintJobService extends OrderPrintJobService {
  @override
  Future<void> retryPrintJob({
    required String restaurantId,
    required String printJobId,
  }) async {}
}
