import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/screens/seller/printer_system_setup_wizard.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> goToStep(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> pumpWizard(
    WidgetTester tester, {
    required _FakeOrchestrator orchestrator,
    required _FakeLocalPrintService service,
    String platformOverride = 'macos',
  }) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PrinterSystemSetupWizard(
          restaurantId: 'restaurant-1',
          printOrchestrator: orchestrator,
          printerRepository: _FakePrinterRepository(),
          localPrintServiceFactory: () => service,
          detectedPlatformOverride: platformOverride,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Bridge unreachable shows offline message', (tester) async {
    await pumpWizard(
      tester,
      orchestrator: _FakeOrchestrator.offline(),
      service: _FakeLocalPrintService(),
    );
    expect(find.textContaining('Yazıcı servisine ulaşılamadı'), findsWidgets);
  });

  testWidgets('Printers empty shows not found message', (tester) async {
    await pumpWizard(
      tester,
      orchestrator: _FakeOrchestrator.withPrinters(const []),
      service: _FakeLocalPrintService(),
    );
    await goToStep(tester, 'Yazıcı Tespiti');
    expect(find.textContaining('Henüz seçilebilir yazıcı bulunamadı'), findsOneWidget);
  });

  testWidgets('Duplicate CUPS/USB shows warning + badges', (tester) async {
    final printers = <UnifiedPrinterModel>[
      UnifiedPrinterModel(
        id: 'cups:STMicroelectronics_POS58_Printer_USB',
        displayName: 'STMicroelectronics_POS58_Printer_USB',
        queueName: 'STMicroelectronics_POS58_Printer_USB',
        backend: DesktopPrinterBackend.cups,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        raw: const <String, dynamic>{'source': 'cups'},
      ),
      UnifiedPrinterModel(
        id: 'usb-direct:pos58',
        displayName: 'POS58 Printer USB',
        queueName: 'POS58 Printer USB',
        backend: DesktopPrinterBackend.usbDirect,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        vendorId: '0x0416',
        productId: '0x5011',
        raw: const <String, dynamic>{'source': 'usb_scan'},
      ),
    ];
    await pumpWizard(
      tester,
      orchestrator: _FakeOrchestrator.withPrinters(printers),
      service: _FakeLocalPrintService(),
    );

    await goToStep(tester, 'Yazıcı Tespiti');
    expect(find.textContaining('birden fazla bağlantı yöntemiyle'), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
    expect(find.text('Alternatif'), findsOneWidget);
  });

  testWidgets('When CUPS queue stuck, USB becomes recommended', (tester) async {
    final printers = <UnifiedPrinterModel>[
      UnifiedPrinterModel(
        id: 'cups:STMicroelectronics_POS58_Printer_USB',
        displayName: 'STMicroelectronics_POS58_Printer_USB',
        queueName: 'STMicroelectronics_POS58_Printer_USB',
        backend: DesktopPrinterBackend.cups,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        raw: const <String, dynamic>{'source': 'cups'},
      ),
      UnifiedPrinterModel(
        id: 'usb-direct:pos58',
        displayName: 'POS58 Printer USB',
        queueName: 'POS58 Printer USB',
        backend: DesktopPrinterBackend.usbDirect,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        vendorId: '0x0416',
        productId: '0x5011',
        raw: const <String, dynamic>{'source': 'usb_scan'},
      ),
    ];
    final orchestrator = _FakeOrchestrator._(
      snapshot: PrinterSetupSnapshot(
        os: DesktopPrinterOs.macos,
        bridgeReachable: true,
        bridgeHealthy: true,
        printers: printers,
        steps: const <PrinterSetupStepStatus>[],
        queueStatus: const <String, dynamic>{
          'queue': <String, dynamic>{
            'enabled': true,
            'ready': true,
            'runtime': <String, dynamic>{'status': 'cups_queue_stuck'},
            'queue_status': 'stuck',
          },
        },
        setupStatus: const <String, dynamic>{'status': 'ready', 'message': 'ok'},
        prerequisites: const <String, dynamic>{'checks': <Map<String, dynamic>>[]},
      ),
    );
    await pumpWizard(
      tester,
      orchestrator: orchestrator,
      service: _FakeLocalPrintService(),
    );
    await goToStep(tester, 'Yazıcı Tespiti');
    expect(find.text('Queue takılmış'), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
  });

  testWidgets('Structured error shows queue clear button', (tester) async {
    await pumpWizard(
      tester,
      orchestrator: _FakeOrchestrator.testFailsStructured(),
      service: _FakeLocalPrintService(),
    );

    await goToStep(tester, 'Test Fişi');

    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Dialog should appear with clear queue action.
    expect(find.text('Kuyruğu Temizle'), findsOneWidget);
  });

  testWidgets('Windows platform shows installer CTA', (tester) async {
    await pumpWizard(
      tester,
      orchestrator: _FakeOrchestrator.offline(),
      service: _FakeLocalPrintService(),
      platformOverride: 'windows',
    );

    await goToStep(tester, 'Bridge Kurulumu');

    expect(
      find.text('Windows Yazıcı Kurulum Uygulamasını İndir'),
      findsOneWidget,
    );
  });

  testWidgets('Test success marks wizard ready', (tester) async {
    await pumpWizard(
      tester,
      orchestrator: _FakeOrchestrator.withPrinters(const [
        UnifiedPrinterModel(
          id: 'cups:Thermal58',
          displayName: 'Thermal58',
          queueName: 'Thermal58',
          backend: DesktopPrinterBackend.cups,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          raw: <String, dynamic>{'source': 'cups'},
        ),
      ]),
      service: _FakeLocalPrintService(),
    );

    await goToStep(tester, 'Test Fişi');
    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hazır'), findsWidgets);
  });

  testWidgets('Role save failure shows error', (tester) async {
    final orchestrator = _FakeOrchestrator.saveFails();
    await pumpWizard(
      tester,
      orchestrator: orchestrator,
      service: _FakeLocalPrintService(),
    );

    await goToStep(tester, 'Test Fişi');
    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hazır'), findsWidgets);

    // Prefer direct jump to last step (requires _testPassed=true).
    await goToStep(tester, 'Rol Atama');
    if (find.widgetWithText(FilledButton, 'Kurulumu Tamamla').evaluate().isEmpty) {
      final next = find.widgetWithText(FilledButton, 'Devam Et');
      expect(next, findsWidgets);
      await tester.ensureVisible(next.first);
      await tester.tap(next.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    // Complete setup -> should fail.
    final complete = find.widgetWithText(FilledButton, 'Kurulumu Tamamla');
    expect(complete, findsWidgets);
    final button = tester.widget<FilledButton>(complete.first);
    expect(button.onPressed, isNotNull);
    // Gesture hit-testing can be flaky inside Stepper controls in widget tests.
    // Calling the handler directly keeps the test focused on behavior.
    button.onPressed!.call();
    await tester.pumpAndSettle();
    expect(orchestrator.saveCallCount, 1);
    // When save fails, wizard must not pop (still on wizard UI).
    expect(find.text('Kurulumu Tamamla'), findsWidgets);
  });
}

class _FakePrinterRepository implements PrinterRepositoryPort {
  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async {
    return const <PrinterModel>[];
  }

  @override
  Stream<List<PrinterModel>> watchPrinters(String restaurantId) {
    return const Stream<List<PrinterModel>>.empty();
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async => null;

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async => null;

  @override
  Future<void> deletePrinter(String printerId) async {}

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {}

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {}

  @override
  Future<void> updateAssignedRoles(String printerId, List<PrinterRole> roles) async {}

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId) async {
    return const <dynamic>[];
  }

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {}

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(String restaurantId) async {}
}

class _FakeLocalPrintService extends LocalPrintService {
  _FakeLocalPrintService() : super(baseUri: Uri.parse('http://127.0.0.1:3001'));

  @override
  Future<Map<String, dynamic>?> driverHelp() async {
    return const <String, dynamic>{
      'step': 'driver_help',
      'message': 'ok',
      'actionRequired': 'none',
      'helpTitle': 'help',
      'helpSteps': <String>[],
    };
  }
}

class _FakeOrchestrator extends DesktopPrintOrchestrator {
  _FakeOrchestrator._({
    required this.snapshot,
    this.testResult,
    this.saveResult,
  }) : super(
          printerRepository: _FakePrinterRepository(),
          printStationService: _NoopPrintStationService(),
          printServiceFactory: () => _FakeLocalPrintService(),
        );

  final PrinterSetupSnapshot snapshot;
  final PrinterActionResult? testResult;
  final PrinterActionResult? saveResult;
  int saveCallCount = 0;

  static _FakeOrchestrator offline() {
    return _FakeOrchestrator._(
      snapshot: const PrinterSetupSnapshot(
        os: DesktopPrinterOs.macos,
        bridgeReachable: false,
        bridgeHealthy: false,
        printers: <UnifiedPrinterModel>[],
        steps: <PrinterSetupStepStatus>[],
        discoveryWarning: 'Bridge calismiyor',
      ),
    );
  }

  static _FakeOrchestrator withPrinters(List<UnifiedPrinterModel> printers) {
    return _FakeOrchestrator._(
      snapshot: PrinterSetupSnapshot(
        os: DesktopPrinterOs.macos,
        bridgeReachable: true,
        bridgeHealthy: true,
        printers: printers,
        steps: const <PrinterSetupStepStatus>[],
        queueStatus: const <String, dynamic>{
          'queue': <String, dynamic>{
            'enabled': true,
            'ready': true,
            'runtime': <String, dynamic>{'status': 'ready'},
          },
        },
        setupStatus: const <String, dynamic>{'status': 'ready', 'message': 'ok'},
        prerequisites: const <String, dynamic>{'checks': <Map<String, dynamic>>[]},
      ),
    );
  }

  static _FakeOrchestrator testFailsStructured() {
    final printers = <UnifiedPrinterModel>[
      const UnifiedPrinterModel(
        id: 'cups:Thermal58',
        displayName: 'Thermal58',
        queueName: 'Thermal58',
        backend: DesktopPrinterBackend.cups,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        raw: <String, dynamic>{'source': 'cups'},
      ),
    ];
    return _FakeOrchestrator._(
      snapshot: PrinterSetupSnapshot(
        os: DesktopPrinterOs.macos,
        bridgeReachable: true,
        bridgeHealthy: true,
        printers: printers,
        steps: const <PrinterSetupStepStatus>[],
        queueStatus: const <String, dynamic>{
          'queue': <String, dynamic>{
            'enabled': true,
            'ready': true,
            'runtime': <String, dynamic>{'status': 'cups_queue_stuck'},
          },
        },
        setupStatus: const <String, dynamic>{'status': 'ready', 'message': 'ok'},
        prerequisites: const <String, dynamic>{'checks': <Map<String, dynamic>>[]},
      ),
      testResult: const PrinterActionResult(
        ok: false,
        status: 'test_failed',
        message: 'Queue stuck',
        raw: <String, dynamic>{
          'errorCode': 'cups_queue_stuck',
          'error': 'Queue stuck',
          'suggested_action': 'clear_queue',
          'active_job_ids': <String>['1'],
          'queue_status': 'stuck',
        },
      ),
    );
  }

  static _FakeOrchestrator saveFails() {
    final printers = <UnifiedPrinterModel>[
      const UnifiedPrinterModel(
        id: 'cups:Thermal58',
        displayName: 'Thermal58',
        queueName: 'Thermal58',
        backend: DesktopPrinterBackend.cups,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        raw: <String, dynamic>{'source': 'cups'},
      ),
    ];
    final localConfig = PrinterSetupLocalConfig(
      restaurantId: 'restaurant-1',
      os: DesktopPrinterOs.macos,
      receiptSelection: PrinterRoleSelection(
        role: PrinterSetupRole.adisyon,
        printer: printers.first,
      ),
      kitchenSelection: PrinterRoleSelection(
        role: PrinterSetupRole.mutfak,
        printer: printers.first,
      ),
    );
    return _FakeOrchestrator._(
      snapshot: PrinterSetupSnapshot(
        os: DesktopPrinterOs.macos,
        bridgeReachable: true,
        bridgeHealthy: true,
        printers: printers,
        steps: const <PrinterSetupStepStatus>[],
        localConfig: localConfig,
        queueStatus: const <String, dynamic>{
          'queue': <String, dynamic>{
            'enabled': true,
            'ready': true,
            'runtime': <String, dynamic>{'status': 'ready'},
          },
        },
        setupStatus: const <String, dynamic>{'status': 'ready', 'message': 'ok'},
        prerequisites: const <String, dynamic>{'checks': <Map<String, dynamic>>[]},
      ),
      testResult: const PrinterActionResult(ok: true, status: 'ready', message: 'ok'),
      saveResult: const PrinterActionResult(
        ok: false,
        status: 'role_save_failed',
        message: 'Rol atamaları kaydedilemedi.',
      ),
    );
  }

  @override
  Future<PrinterSetupSnapshot> loadSetupSnapshot({
    required String restaurantId,
    bool forceRefresh = false,
    String flowName = 'setup_snapshot',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    return snapshot;
  }

  @override
  Future<PrinterActionResult> printTestReceipt({
    required String restaurantId,
    PrinterSetupRole? role,
    String? printerId,
    String testSource = 'role_test',
    String flowName = 'role_test',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    return testResult ??
        const PrinterActionResult(ok: true, status: 'ready', message: 'ok');
  }

  @override
  Future<PrinterActionResult> savePrinterRoles({
    required String restaurantId,
    required String receiptPrinterId,
    required String kitchenPrinterId,
    Session? session,
    bool markThisDeviceAsPrintStation = false,
    String? stationPlatform,
    String flowName = 'role_mapping_save',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    saveCallCount += 1;
    return saveResult ??
        const PrinterActionResult(ok: true, status: 'saved', message: 'ok');
  }
}

class _NoopPrintStationService implements PrintStationServicePort {
  @override
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async => const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async => const <String, dynamic>{};

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => false;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => false;

  @override
  Future<bool> isThisDevicePrintStation() async => false;

  @override
  String currentPlatformLabel() => 'macos';

  @override
  String currentDeviceName() => 'test-device';

  @override
  String normalizeStationPlatform(String? value) => value ?? 'macos';

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
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(String restaurantId) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<bool> resumePausedPrintJob({required String restaurantId, required String jobId}) async => true;

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async =>
      true;

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}
}

