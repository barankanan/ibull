import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/screens/seller/printer_ethernet_dialog.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    required _RecordingEthernetOrchestrator orchestrator,
    _FakeEthernetLocalPrintService? localService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddEthernetPrinterScreen(
          restaurantId: 'rest-1',
          orchestrator: orchestrator,
          localPrintService: localService,
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
    expect(find.text('IP adresi giriniz'), findsOneWidget);
    expect(find.text('Yazıcı adı giriniz'), findsOneWidget);
    expect(portField.decoration?.hintText, 'Port');
    expect(find.byKey(const Key('ethernet_auto_scan_button')), findsOneWidget);
    expect(find.text('Otomatik Tara'), findsOneWidget);
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
    final localService = _FakeEthernetLocalPrintService();
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(find.text('IP adresi boş olamaz.'), findsNothing);
    expect(localService.probeCallCount, 1);
    expect(localService.lastProbeHost, '192.168.1.100');
    expect(localService.lastProbePort, 9100);
    
    final printerPayload = localService.lastProbePrinter;
    expect(printerPayload?['backend'], 'tcp');
    expect(printerPayload?['transportType'], 'ethernet');
    expect(printerPayload?['transport_type'], 'ethernet');
    expect(printerPayload?['host'], '192.168.1.100');
    expect(printerPayload?['ip_address'], '192.168.1.100');
    expect(printerPayload?['port'], 9100);
    expect(printerPayload?['displayName'], 'Ethernet Yazıcı 192.168.1.100');
    expect(printerPayload?['source'], 'ethernet_dialog_form');
    expect(printerPayload?['printer_id'], 'tcp:192.168.1.100:9100');
    expect(find.text('Bağlantı başarılı'), findsOneWidget);
    expect(find.text('Kayıt durumu: Hazır'), findsOneWidget);
  });

  testWidgets('connection timeout shows friendly diagnostic card', (tester) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      probeResult: <String, dynamic>{
        'ok': false,
        'errorCode': 'tcp_timeout',
        'error': '192.168.1.100:9100 zaman aşımı',
        'local_ips': <String>['192.168.1.34'],
        'same_subnet': true,
        'reachable': false,
        'port_open': false,
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(find.text('Yazıcıya ulaşılamadı'), findsOneWidget);
    expect(find.textContaining('192.168.1.100:9100'), findsOneWidget);
    expect(find.text('Kayıt durumu: Bağlantı bekleniyor'), findsOneWidget);
    expect(find.textContaining('LocalPrintServiceException'), findsNothing);
  });

  testWidgets('failed connection keeps print disabled and skips bridge print', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      probeResult: <String, dynamic>{
        'ok': false,
        'errorCode': 'tcp_timeout',
        'error': '192.168.1.100:9100 zaman aşımı',
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
        'reachable': false,
        'port_open': false,
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(find.text('Yazıcıya ulaşılamadı'), findsOneWidget);
    final printButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Test Fişi Gönder'),
    );
    expect(printButton.onPressed, isNull);
    expect(orchestrator.callCount, 0);
    expect(find.textContaining('POS-58 adisyon profili'), findsNothing);
    expect(find.textContaining('receipt_profile_invalid'), findsNothing);
  });

  testWidgets('print test requires successful connection test first', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService();
    await pumpDialog(
      tester,
      orchestrator: orchestrator,
      localService: localService,
    );

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    final printButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Test Fişi Gönder'),
    );
    expect(printButton.onPressed, isNull);
  });

  Future<void> runSuccessfulConnectionTest(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();
  }

  testWidgets('print test dispatches explicit ethernet tcp payload', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService();
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await runSuccessfulConnectionTest(tester);

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
  testWidgets('print test keeps pos80 profile metadata (not pos58)', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService();
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await runSuccessfulConnectionTest(tester);
    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.50',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Test Fişi Gönder'));
    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pumpAndSettle();

    expect(orchestrator.lastExtraBody?['printer_profile'], 'pos80');
    expect(orchestrator.lastExtraBody?['paper_width_mm'], 80);
    expect(orchestrator.lastExtraBody?['raster_width_px'], 576);
    expect(orchestrator.lastExtraBody?['printer_profile'], isNot('pos58'));
    expect(orchestrator.lastExtraBody?['chars_per_line'], 48);
  });

  testWidgets('pos58 selection sends pos58 metadata on print test', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService();
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.ensureVisible(find.byKey(const Key('ethernet_profile_pos58')));
    await tester.tap(find.byKey(const Key('ethernet_profile_pos58')));
    await tester.pumpAndSettle();
    await runSuccessfulConnectionTest(tester);
    await tester.ensureVisible(find.text('Test Fişi Gönder'));
    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pumpAndSettle();

    expect(orchestrator.lastExtraBody?['printer_profile'], 'pos58');
    expect(orchestrator.lastExtraBody?['paper_width_mm'], 58);
    expect(orchestrator.lastExtraBody?['raster_width_px'], 384);
    expect(orchestrator.lastExtraBody?['chars_per_line'], 32);
  });

  testWidgets('generic profile selection updates dispatch payload', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService();
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.ensureVisible(
      find.byKey(const Key('ethernet_profile_generic_80mm_escpos')),
    );
    await tester.tap(find.byKey(const Key('ethernet_profile_generic_80mm_escpos')));
    await tester.pumpAndSettle();
    await runSuccessfulConnectionTest(tester);
    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '10.0.0.20',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test Fişi Gönder'));
    await tester.tap(find.text('Test Fişi Gönder'));
    await tester.pumpAndSettle();

    expect(orchestrator.lastExtraBody?['printer_profile'], 'generic_80mm_escpos');
    expect(orchestrator.lastExtraBody?['paper_width_mm'], 80);
    expect(orchestrator.lastExtraBody?['raster_width_px'], 576);
  });

  testWidgets('failed connection shows only network diagnostic card', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      probeResult: <String, dynamic>{
        'ok': false,
        'errorCode': 'tcp_timeout',
        'error': '192.168.1.100:9100 zaman aşımı',
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(find.text('Yazıcıya ulaşılamadı'), findsOneWidget);
    expect(find.text('Test fişi gönderildi'), findsNothing);
    expect(find.textContaining('POS-58 adisyon profili'), findsNothing);
  });

  testWidgets('auto scan lists discovered printers and fills form on select', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      scanResult: <String, dynamic>{
        'ok': true,
        'local_ips': <String>['192.168.10.158'],
        'subnets': <String>['192.168.10.0/24'],
        'port': 9100,
        'devices': <Map<String, dynamic>>[
          <String, dynamic>{
            'host': '192.168.10.100',
            'port': 9100,
            'reachable': true,
            'port_open': true,
            'same_subnet': true,
          },
        ],
        'suggested_message': '1 yazıcı bulundu.',
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.ensureVisible(find.byKey(const Key('ethernet_auto_scan_button')));
    await tester.tap(find.byKey(const Key('ethernet_auto_scan_button')));
    await tester.pumpAndSettle();

    expect(localService.scanCallCount, 1);
    expect(find.text('IP: 192.168.10.100 · Port: 9100'), findsOneWidget);
    expect(find.text('Ulaşılabilir'), findsOneWidget);
    // Yeni kart UX: varsayılan ad + profil seçimi + hızlı ad şablonları.
    final deviceNameField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_device_name_192.168.10.100')),
    );
    expect(deviceNameField.controller?.text, 'POS Yazıcı - 100');
    expect(
      find.byKey(const Key('ethernet_device_profile_192.168.10.100')),
      findsOneWidget,
    );
    expect(find.text('Kasa Yazıcısı'), findsOneWidget);
    expect(find.text('Mutfak Yazıcısı'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ethernet_select_192.168.10.100')));
    await tester.pumpAndSettle();

    final ipField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_ip_field')),
    );
    final portField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_port_field')),
    );
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('ethernet_name_field')),
    );
    expect(ipField.controller?.text, '192.168.10.100');
    expect(portField.controller?.text, '9100');
    // Karttaki düzenlenebilir ad forma aktarılır.
    expect(nameField.controller?.text, 'POS Yazıcı - 100');
  });

  testWidgets('different subnet warning is shown for manual IP entry', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      preflightResult: <String, dynamic>{
        'ok': true,
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
        'network_state': 'network_mismatch',
        'suggested_printer_ip': '192.168.10.100',
        'suggested_target_subnet': '192.168.10.0/24',
        'suggested_message':
            'Bilgisayarınız 192.168.10.x ağında, yazıcı 192.168.1.x ağında. '
            'Bu cihazlar aynı ağda değil. Yazıcı IP\'sini işletme ağına alın.',
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ağ Uyumluluk Durumu'), findsOneWidget);
    expect(
      find.textContaining('Bilgisayarınız 192.168.10.x ağında'),
      findsOneWidget,
    );
    expect(find.textContaining('işletme ağına alın'), findsOneWidget);
    expect(find.text('Yazıcı IP\'sini İşletme Ağına Taşı'), findsOneWidget);
    expect(find.textContaining('sudo ifconfig'), findsNothing);

    await tester.ensureVisible(
      find.text('Yazıcı IP\'sini İşletme Ağına Taşı'),
    );
    await tester.tap(find.text('Yazıcı IP\'sini İşletme Ağına Taşı'));
    await tester.pumpAndSettle();
    expect(find.textContaining('192.168.10.100'), findsWidgets);
  });

  testWidgets('auto scan empty result explains different subnet manual IP', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      scanResult: <String, dynamic>{
        'ok': true,
        'local_ips': <String>['192.168.10.158'],
        'subnets': <String>['192.168.10.0/24'],
        'devices': <Map<String, dynamic>>[],
        'no_device_reason': 'printer_on_different_subnet',
        'suggested_printer_ip': '192.168.10.100',
        'suggested_target_subnet': '192.168.10.0/24',
        'suggested_message':
            'Aynı ağda port 9100 açık cihaz bulunamadı. '
            'Self-test fişindeki IP farklı ağdaysa otomatik tarama bulamaz.',
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.tap(find.byKey(const Key('ethernet_auto_scan_button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Self-test fişindeki IP farklı ağdaysa'),
      findsOneWidget,
    );
    expect(find.text('192.168.1.100:9100'), findsNothing);
  });

  testWidgets('technical alias commands stay in advanced section only', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      preflightResult: <String, dynamic>{
        'ok': true,
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.pumpAndSettle();

    final migrationTitle = find.text('Yazıcı IP\'sini İşletme Ağına Taşı');
    await tester.ensureVisible(migrationTitle);
    await tester.tap(migrationTitle);
    await tester.pumpAndSettle();
    expect(find.textContaining('sudo ifconfig'), findsNothing);

    final technicalTitle = find.text('Gelişmiş / Teknik Servis');
    await tester.ensureVisible(technicalTitle);
    await tester.tap(technicalTitle);
    await tester.pumpAndSettle();
    expect(find.textContaining('sudo ifconfig en0 alias'), findsOneWidget);
  });

  testWidgets('network mismatch keeps save enabled with warning status', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      probeResult: <String, dynamic>{
        'ok': false,
        'errorCode': 'network_mismatch',
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
        'reachable': false,
        'port_open': false,
      },
      preflightResult: <String, dynamic>{
        'ok': true,
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.enterText(
      find.byKey(const Key('ethernet_ip_field')),
      '192.168.1.100',
    );
    await tester.ensureVisible(find.text('Bağlantıyı Test Et'));
    await tester.tap(find.text('Bağlantıyı Test Et'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bağlantı bekleniyor'),
      findsOneWidget,
    );
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kaydet'),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('scan failure shows friendly message without exception text', (
    tester,
  ) async {
    final orchestrator = _RecordingEthernetOrchestrator();
    final localService = _FakeEthernetLocalPrintService(
      scanResult: <String, dynamic>{
        'ok': false,
        'errorCode': 'no_local_network',
        'error': 'Bilgisayarın yerel ağ IP adresi algılanamadı.',
      },
    );
    await pumpDialog(tester, orchestrator: orchestrator, localService: localService);

    await tester.tap(find.byKey(const Key('ethernet_auto_scan_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Bilgisayarın yerel ağ IP adresi algılanamadı.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });

}

class _FakeEthernetLocalPrintService extends LocalPrintService {
  _FakeEthernetLocalPrintService({
    this.probeResult,
    this.scanResult,
    this.preflightResult,
  }) : super(baseUri: Uri.parse('http://127.0.0.1:3001'));

  final Map<String, dynamic>? probeResult;
  final Map<String, dynamic>? scanResult;
  final Map<String, dynamic>? preflightResult;

  int probeCallCount = 0;
  int scanCallCount = 0;
  String? lastProbeHost;
  int? lastProbePort;
  Map<String, dynamic>? lastProbePrinter;
  int? lastScanPort;

  @override
  Future<Map<String, dynamic>?> fetchEthernetNetworkPreflight({
    required String host,
    required int port,
    Duration? timeout,
  }) async {
    return preflightResult ??
        <String, dynamic>{
          'ok': true,
          'local_ips': <String>['192.168.1.34'],
          'same_subnet': true,
          'suggested_message': '',
        };
  }

  @override
  Future<Map<String, dynamic>?> scanEthernetPrinters({
    int port = 9100,
    String? printerHost,
    Duration? timeout,
  }) async {
    scanCallCount++;
    lastScanPort = port;
    return scanResult ??
        <String, dynamic>{
          'ok': true,
          'local_ips': <String>['192.168.1.34'],
          'subnets': <String>['192.168.1.0/24'],
          'port': port,
          'devices': <Map<String, dynamic>>[],
          'suggested_message': 'Aynı ağda port 9100 açık cihaz bulunamadı.',
        };
  }

  @override
  Future<Map<String, dynamic>?> probeTcpPrinter({
    required String host,
    required int port,
    Map<String, dynamic>? printer,
    Duration? timeout,
  }) async {
    probeCallCount++;
    lastProbeHost = host;
    lastProbePort = port;
    lastProbePrinter = printer;
    return probeResult ??
        <String, dynamic>{
          'ok': true,
          'suggested_message': 'Mock ethernet baglanti basarili',
          'local_ips': <String>['192.168.1.34'],
          'same_subnet': true,
          'reachable': true,
          'port_open': true,
        };
  }
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
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async => null;

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
  Future<PrinterModel> repairPrinterProfileMetadata(String printerId) async {
    final printer = await fetchPrinterById(printerId);
    if (printer == null) {
      throw StateError('missing printer $printerId');
    }
    return printer;
  }

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
  Future<String> invalidateRoleMappingCacheState({Map<String, dynamic>? roleMappings, String source = 'print_station_service',
    required String restaurantId,
  }) async => 'mock_token';

  @override
  Future<String?> readRoleMappingCacheToken(String restaurantId) async => 'mock_token';

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
