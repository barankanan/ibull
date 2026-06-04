import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/screens/seller/desktop_printer_setup_page.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Yazıcı Merkezi açılınca toggle mevcut statei gösterir', (
    tester,
  ) async {
    final stationService = _FakePrintStationService(
      localEnabled: false,
      remoteEnabled: false,
      includeReadyPrinter: true,
    );
    final orchestrator = _FakeDesktopPrintOrchestrator(stationService);

    await _pumpPage(
      tester,
      stationService: stationService,
      orchestrator: orchestrator,
    );

    expect(find.text('Baskı Sistemi'), findsOneWidget);
    expect(find.text('Kapalı'), findsWidgets);
    expect(find.text('Baskı Sistemini Aç'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
  });

  testWidgets('Toggle kapatinca local ve remote state kapaliya doner', (
    tester,
  ) async {
    final stationService = _FakePrintStationService(
      localEnabled: true,
      remoteEnabled: true,
      includeReadyPrinter: true,
    );
    final orchestrator = _FakeDesktopPrintOrchestrator(stationService);

    await _pumpPage(
      tester,
      stationService: stationService,
      orchestrator: orchestrator,
    );

    await tester.tap(find.text('Baskı Sistemini Kapat'));
    await tester.pumpAndSettle();

    expect(stationService.toggleCalls, <bool>[false]);
    expect(stationService.localEnabled, isFalse);
    expect(stationService.remoteEnabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(
      find.text(
        'Baskı sistemi kapatıldı. Siparişler alınır ancak fişler otomatik yazdırılmaz.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Toggle acinca local ve remote state aciga doner', (
    tester,
  ) async {
    final stationService = _FakePrintStationService(
      localEnabled: false,
      remoteEnabled: false,
      includeReadyPrinter: true,
    );
    final orchestrator = _FakeDesktopPrintOrchestrator(stationService);

    await _pumpPage(
      tester,
      stationService: stationService,
      orchestrator: orchestrator,
    );

    await tester.tap(find.text('Baskı Sistemini Aç'));
    await tester.pumpAndSettle();

    expect(stationService.toggleCalls, <bool>[true]);
    expect(stationService.localEnabled, isTrue);
    expect(stationService.remoteEnabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
      find.text('Baskı sistemi açıldı. Yeni siparişler otomatik yazdırılır.'),
      findsOneWidget,
    );
  });

  testWidgets('Endpoint hata verirse UI eski statee geri doner', (
    tester,
  ) async {
    final stationService = _FakePrintStationService(
      localEnabled: true,
      remoteEnabled: true,
      failNextToggle: true,
      includeReadyPrinter: true,
    );
    final orchestrator = _FakeDesktopPrintOrchestrator(stationService);

    await _pumpPage(
      tester,
      stationService: stationService,
      orchestrator: orchestrator,
    );

    await tester.tap(find.text('Baskı Sistemini Kapat'));
    await tester.pumpAndSettle();

    expect(stationService.toggleCalls, <bool>[false]);
    expect(stationService.localEnabled, isTrue);
    expect(stationService.remoteEnabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
      find.text(
        'Baskı sistemi güncellenemedi. Yerel bridge ve bulut ayarı eski duruma geri alındı.',
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('Sistem kapaliyken test butonu net kapali mesaji gosterir', (
    tester,
  ) async {
    final stationService = _FakePrintStationService(
      localEnabled: false,
      remoteEnabled: false,
      includeReadyPrinter: true,
    );
    final orchestrator = _FakeDesktopPrintOrchestrator(stationService);

    await _pumpPage(
      tester,
      stationService: stationService,
      orchestrator: orchestrator,
    );

    final receiptTestButton = find.text('Test Fişi Gönder').first;
    await tester.tap(receiptTestButton);
    await tester.pumpAndSettle();

    expect(orchestrator.receiptTestCallCount, 0);
    expect(find.textContaining('Baskı sistemi kapalı.'), findsWidgets);
    expect(find.text('Test basarisiz'), findsNothing);
  });

  testWidgets('Sistem acikken test butonlari normal akisla calisir', (
    tester,
  ) async {
    final stationService = _FakePrintStationService(
      localEnabled: true,
      remoteEnabled: true,
      includeReadyPrinter: true,
    );
    final orchestrator = _FakeDesktopPrintOrchestrator(stationService);

    await _pumpPage(
      tester,
      stationService: stationService,
      orchestrator: orchestrator,
    );

    final receiptTestButton = find.text('Test Fişi Gönder').first;
    await tester.tap(receiptTestButton);
    await tester.pumpAndSettle();

    expect(orchestrator.receiptTestCallCount, 1);
    expect(find.text('Adisyon test fişi gönderildi.'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakePrintStationService stationService,
  required _FakeDesktopPrintOrchestrator orchestrator,
}) async {
  tester.view.physicalSize = const Size(1600, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: DesktopPrinterSetupPage(
        restaurantIdOverride: 'restaurant-1',
        onRefreshRequested: () {},
        listenerTabOverride: const SizedBox.shrink(),
        guideTabOverride: const SizedBox.shrink(),
        printOrchestrator: orchestrator,
        printStationService: stationService,
        printerStreamBuilder: (_) =>
            Stream<List<PrinterModel>>.value(const <PrinterModel>[]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakePrintStationService implements PrintStationServicePort {
  _FakePrintStationService({
    required this.localEnabled,
    required this.remoteEnabled,
    this.failNextToggle = false,
    this.includeReadyPrinter = false,
  });

  bool localEnabled;
  bool remoteEnabled;
  bool failNextToggle;
  bool includeReadyPrinter;
  final List<bool> toggleCalls = <bool>[];
  int patchCalls = 0;

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
    return <String, dynamic>{'ok': true};
  }

  @override
  String currentDeviceName() => 'ibul-macos-device';

  @override
  String currentPlatformLabel() => 'macos';

  @override
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(
    String restaurantId,
  ) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async {
    return <String, dynamic>{
      'queue': <String, dynamic>{
        'enabled': true,
        'ready': true,
        'print_system_enabled': localEnabled,
      },
    };
  }

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async {
    return <String, dynamic>{
      'restaurant_id': restaurantId,
      'print_system_enabled': remoteEnabled,
      'updated_at': DateTime(2026, 5, 5).toIso8601String(),
    };
  }

  @override
  Future<bool> isThisDevicePrintStation() async => true;

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => true;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => true;

  @override
  String normalizeStationPlatform(String? value) => 'macos';

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async {
    patchCalls += 1;
    remoteEnabled = fields['print_system_enabled'] == true;
    return <String, dynamic>{
      'restaurant_id': restaurantId,
      'print_system_enabled': remoteEnabled,
    };
  }

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async {
    return true;
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
    return <String, dynamic>{'ok': true};
  }

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async {
    toggleCalls.add(enabled);
    if (failNextToggle) {
      failNextToggle = false;
      return false;
    }
    localEnabled = enabled;
    remoteEnabled = enabled;
    return true;
  }
}

class _FakeDesktopPrintOrchestrator extends DesktopPrintOrchestrator {
  _FakeDesktopPrintOrchestrator(this.stationService)
    : super(
        printerRepository: _FakePrinterRepository(),
        printStationService: stationService,
      );

  final _FakePrintStationService stationService;
  int receiptTestCallCount = 0;

  UnifiedPrinterModel get _printer => UnifiedPrinterModel(
    id: 'bridge-printer-1',
    displayName: 'USB Test Yazıcısı',
    queueName: 'USB Test Yazıcısı',
    backend: DesktopPrinterBackend.usbDirect,
    os: DesktopPrinterOs.macos,
    isAvailable: true,
    canPrint: true,
    printerRecordId: 'printer-record-1',
    raw: const <String, dynamic>{'source': 'usb_scan'},
  );

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
    final printer = _printer;
    final printers = stationService.includeReadyPrinter
        ? <UnifiedPrinterModel>[printer]
        : const <UnifiedPrinterModel>[];
    final roleSelection = PrinterRoleSelection(
      role: PrinterSetupRole.adisyon,
      printer: printer,
    );
    final kitchenSelection = PrinterRoleSelection(
      role: PrinterSetupRole.mutfak,
      printer: printer,
    );
    return PrinterSetupSnapshot(
      os: DesktopPrinterOs.macos,
      bridgeReachable: true,
      bridgeHealthy: true,
      bridgeHealth: const <String, dynamic>{
        'ok': true,
        'printer': <String, dynamic>{'ok': true},
      },
      printers: printers,
      steps: const <PrinterSetupStepStatus>[],
      localConfig: stationService.includeReadyPrinter
          ? PrinterSetupLocalConfig(
              restaurantId: restaurantId,
              os: DesktopPrinterOs.macos,
              receiptSelection: roleSelection,
              kitchenSelection: kitchenSelection,
            )
          : null,
      remoteConfig: <String, dynamic>{
        'restaurant_id': restaurantId,
        'print_system_enabled': stationService.remoteEnabled,
        'updated_at': DateTime(2026, 5, 5).toIso8601String(),
      },
      queueStatus: <String, dynamic>{
        'queue': <String, dynamic>{
          'enabled': true,
          'ready': true,
          'print_system_enabled': stationService.localEnabled,
        },
      },
      setupStatus: const <String, dynamic>{'status': 'ready'},
      prerequisites: const <String, dynamic>{
        'checks': <Map<String, dynamic>>[],
      },
      discoveryWarning: null,
      bridgeStatusLabel: 'Hazir',
    );
  }

  @override
  Future<PrinterActionResult> printTestReceipt({
    required String restaurantId,
    PrinterSetupRole? role,
    String? printerId,
    UnifiedPrinterModel? explicitLivePrinter,
    String testSource = 'role_test',
    String flowName = 'role_test',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    receiptTestCallCount += 1;
    return const PrinterActionResult(
      ok: true,
      status: 'ready',
      message: 'Hazir',
    );
  }
}

class _FakePrinterRepository implements PrinterRepositoryPort {
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
  Future<PrinterModel?> fetchPrinterById(String printerId) async => null;

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async {
    return const <PrinterModel>[];
  }

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId) async {
    return const <dynamic>[];
  }

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async => null;

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {}

  @override
  Future<void> updateAssignedRoles(
    String printerId,
    List<PrinterRole> roles,
  ) async {}

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
}
