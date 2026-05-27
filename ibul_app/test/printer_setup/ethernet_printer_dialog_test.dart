import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/screens/seller/printer_ethernet_dialog.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    required _RecordingEthernetOrchestrator orchestrator,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddEthernetPrinterScreen(
          restaurantId: 'rest-1',
          orchestrator: orchestrator,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ethernet dialog starts with empty IP and expected hints', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    await pumpDialog(tester, orchestrator: orchestrator);

    final ipField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_ip_field')),
    );
    final portField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_port_field')),
    );
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_name_field')),
    );

    expect(ipField.controller?.text, '');
    expect(portField.controller?.text, '9100');
    expect(nameField.controller?.text, '');
    expect(find.text('Değer giriniz'), findsOneWidget);
    expect(find.text('Örn: 192.168.1.100'), findsOneWidget);
    expect(find.text('NETUM ZJ-8360 Ethernet'), findsOneWidget);
  });

  testWidgets('empty IP validation appears once', (tester) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    await pumpDialog(tester, orchestrator: orchestrator);

    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(find.text('IP adresi boş olamaz.'), findsOneWidget);
    expect(orchestrator.callCount, 0);
  });

  testWidgets('connection test dispatches explicit ethernet tcp payload', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    await pumpDialog(tester, orchestrator: orchestrator);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(find.text('IP adresi boş olamaz.'), findsNothing);
    expect(orchestrator.callCount, 1);
    expect(orchestrator.lastSkipSetupSnapshot, isTrue);
    expect(orchestrator.lastTargetHost, '192.168.1.100');
    expect(orchestrator.lastTargetPort, 9100);
    expect(orchestrator.lastTestMode, 'ethernet_connection');
    expect(
      orchestrator.lastExplicitPrinter?.backend,
      DesktopPrinterBackend.tcp,
    );
    expect(orchestrator.lastExplicitPrinter?.raw['host'], '192.168.1.100');
    expect(orchestrator.lastExplicitPrinter?.raw['port'], 9100);
    expect(
      orchestrator.lastExplicitPrinter?.raw['displayName'],
      'Ethernet Yazıcı 192.168.1.100',
    );
    expect(
      orchestrator.lastExplicitPrinter?.raw['source'],
      'ethernet_dialog_form',
    );
    expect(orchestrator.lastExtraBody?['backend'], 'tcp');
    expect(orchestrator.lastExtraBody?['transportType'], 'ethernet');
    expect(orchestrator.lastExtraBody?['transport_type'], 'ethernet');
    expect(orchestrator.lastExtraBody?['host'], '192.168.1.100');
    expect(orchestrator.lastExtraBody?['ip_address'], '192.168.1.100');
    expect(orchestrator.lastExtraBody?['port'], 9100);
    expect(
      orchestrator.lastExtraBody?['displayName'],
      'Ethernet Yazıcı 192.168.1.100',
    );
    expect(orchestrator.lastExtraBody?['source'], 'ethernet_dialog_form');
    expect(orchestrator.lastExtraBody?['printer_id'], 'tcp:192.168.1.100:9100');
    expect(find.text('Ethernet yazıcıya bağlantı başarılı.'), findsOneWidget);
  });

  testWidgets('print test dispatches explicit ethernet tcp payload', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    await pumpDialog(tester, orchestrator: orchestrator);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Test Fişi Gönder'));
    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pumpAndSettle();

    expect(orchestrator.callCount, 1);
    expect(orchestrator.lastSkipSetupSnapshot, isTrue);
    expect(orchestrator.lastTargetHost, '192.168.1.100');
    expect(orchestrator.lastTargetPort, 9100);
    expect(orchestrator.lastTestMode, 'ethernet_test');
    expect(
      orchestrator.lastExplicitPrinter?.backend,
      DesktopPrinterBackend.tcp,
    );
    expect(
      orchestrator.lastExplicitPrinter?.raw['source'],
      'ethernet_dialog_form',
    );
    expect(orchestrator.lastExtraBody?['backend'], 'tcp');
    expect(orchestrator.lastExtraBody?['transportType'], 'ethernet');
    expect(orchestrator.lastExtraBody?['host'], '192.168.1.100');
    expect(orchestrator.lastExtraBody?['port'], 9100);
    expect(orchestrator.lastExtraBody?['printer_role'], 'adisyon');
    expect(orchestrator.lastExtraBody?['source'], 'ethernet_dialog_form');
  });
}

class _RecordingEthernetOrchestrator extends DesktopPrintOrchestrator {
  _RecordingEthernetOrchestrator()
    : super(
        printerRepository: _TestPrinterRepository(),
        printStationService: _TestPrintStationService(),
      );

  int callCount = 0;
  UnifiedPrinterModel? lastExplicitPrinter;
  bool lastSkipSetupSnapshot = false;
  String? lastTargetHost;
  int? lastTargetPort;
  String? lastTestMode;
  Map<String, dynamic>? lastExtraBody;

  @override
  Future<PrinterActionResult> printBridgeTest({
    required String restaurantId,
    String? printerId,
    String? printerName,
    UnifiedPrinterModel? explicitPrinter,
    bool skipSetupSnapshot = false,
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    Map<String, dynamic>? extraBody,
    String renderMode = 'image',
    String testMode = 'escpos_short',
    String flowName = 'generic_printer_test',
    String source = 'orchestrator',
    String? storeId,
    String? tableId,
    String? printJobId,
  }) async {
    callCount += 1;
    lastExplicitPrinter = explicitPrinter;
    lastSkipSetupSnapshot = skipSetupSnapshot;
    lastTargetHost = targetHost;
    lastTargetPort = targetPort;
    lastTestMode = testMode;
    lastExtraBody = extraBody == null
        ? null
        : Map<String, dynamic>.from(extraBody);
    return PrinterActionResult(
      ok: true,
      status: 'ready',
      message: 'Hazir',
      printer: explicitPrinter,
      raw: const <String, dynamic>{
        'ok': true,
        'actual_backend': 'tcp',
        'physical_confirmation': true,
        'bytes_sent': 12,
      },
    );
  }
}

class _TestPrinterRepository implements PrinterRepositoryPort {
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
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async =>
      const <PrinterModel>[];

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(
    String restaurantId,
  ) async => const <dynamic>[];

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
  }) async {
    return PrinterModel(
      id: printerId ?? 'printer-1',
      restaurantId: restaurantId,
      name: name,
      code: code,
      connectionType: connectionType,
      ipAddress: ipAddress,
      port: port,
      deviceIdentifier: deviceIdentifier,
      paperWidthMm: paperWidthMm,
      isActive: isActive,
      createdAt: DateTime.utc(2025, 1, 1),
      supportsCut: supportsCut,
      charset: charset,
      codePage: codePage,
      assignedRoles: assignedRoles,
      printerProfileId: printerProfileId,
    );
  }
}

class _TestPrintStationService implements PrintStationServicePort {
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
  }) async => <String, dynamic>{'ok': true};

  @override
  String currentDeviceName() => 'test-device';

  @override
  String currentPlatformLabel() => 'macos';

  @override
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async =>
      <String, dynamic>{'ok': true};

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> fetchPausedPrintJobs(
    String restaurantId,
  ) async => const <Map<String, dynamic>>[];

  @override
  Future<bool> isThisDevicePrintStation() async => false;

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => true;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => false;

  @override
  String normalizeStationPlatform(String? value) => 'macos';

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async => <String, dynamic>{...fields};

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async => true;

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
  }) async => <String, dynamic>{'ok': true};

  @override
  Future<bool> setPrintSystemEnabled({
    required String restaurantId,
    required bool enabled,
    bool? previousEnabled,
  }) async => true;

  @override
  Future<void> setThisDevicePrintStation(bool value) async {}
}
