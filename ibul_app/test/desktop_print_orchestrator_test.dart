import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/station_printer_model.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/desktop_print_ports.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:ibul_app/services/macos_admin_release_models.dart';
import 'package:ibul_app/services/macos_usb_permission_recovery_service.dart';
import 'package:ibul_app/services/printer_event_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('savePrinterRoles persists normalized local role mappings', () async {
    final fakeRepo = _FakePrinterRepository();
    final fakeStation = _FakePrintStationService(saveShouldThrow: true);
    final fakePrint = _FakeLocalPrintService(
      discoveredPrinters: <Map<String, dynamic>>[
        _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
      ],
    );

    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: fakeRepo,
      printStationService: fakeStation,
      printServiceFactory: () => fakePrint,
    );

    await fakeRepo.upsertPrinter(
      restaurantId: 'rest-1',
      printerId: 'db-receipt',
      name: 'POS58 USB',
      code: 'ADISYON_POS58_USB',
      connectionType: PrinterModel.usbConnectionType,
      deviceIdentifier: 'POS58_USB',
      assignedRoles: const <PrinterRole>[PrinterRole.receipt],
    );
    await fakeRepo.upsertPrinter(
      restaurantId: 'rest-1',
      printerId: 'db-kitchen',
      name: 'Mutfak Yazici',
      code: 'MUTFAK_KITCHEN_QUEUE',
      connectionType: PrinterModel.usbConnectionType,
      deviceIdentifier: 'Kitchen_Queue',
      assignedRoles: const <PrinterRole>[PrinterRole.kitchen],
    );

    final result = await orchestrator.savePrinterRoles(
      restaurantId: 'rest-1',
      receiptPrinterId: 'db-receipt',
      kitchenPrinterId: 'db-kitchen',
    );

    expect(result.ok, isTrue);
    expect(result.localSaved, isTrue);
    expect(result.cloudSaved, isFalse);
    expect(result.message, 'Yerel kayıt yapıldı, bulut senkronu bekliyor.');

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'rest-1',
    );
    // Stale test state must be cleared after role mapping save.
    expect(snapshot.localConfig?.receiptTest, isNull);
    expect(snapshot.localConfig?.kitchenTest, isNull);
    expect(snapshot.selectedReceiptPrinterId, 'usb:receipt');
    expect(snapshot.selectedKitchenPrinterId, 'cups:kitchen');
    expect(snapshot.localConfig?.receiptSelection?.printer.id, 'usb:receipt');
    expect(
      snapshot.localConfig?.receiptSelection?.printer.printerRecordId,
      'db-receipt',
    );
    expect(
      snapshot.localConfig?.receiptSelection?.printer.queueName,
      'POS58_USB',
    );
    expect(
      snapshot.localConfig?.receiptSelection?.printer.backend.value,
      'usb-direct',
    );
    expect(snapshot.localConfig?.kitchenSelection?.printer.id, 'cups:kitchen');
    expect(
      snapshot.localConfig?.kitchenSelection?.printer.printerRecordId,
      'db-kitchen',
    );
    expect(
      snapshot.localConfig?.kitchenSelection?.printer.queueName,
      'Kitchen_Queue',
    );
    final savedPrinters = await fakeRepo.fetchPrinters('rest-1');
    expect(savedPrinters.length, 2);
    expect(
      savedPrinters.any(
        (printer) =>
            printer.assignedRoles.contains(PrinterRole.receipt) &&
            printer.deviceIdentifier == 'usb-1234:5678',
      ),
      isTrue,
    );
  });

  test(
    'printTestReceipt uses shared role mapping and stores success',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-2',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-2',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );

      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-2',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      final result = await orchestrator.printTestReceipt(
        restaurantId: 'rest-2',
        role: PrinterSetupRole.adisyon,
      );

      expect(result.ok, isTrue);
      expect(result.status, 'ready');
      expect(fakePrint.lastPrintTestPrinterId, 'usb:receipt');

      final directResult = await orchestrator.printTestReceipt(
        restaurantId: 'rest-2',
        role: PrinterSetupRole.adisyon,
        printerId: 'db-receipt',
      );
      expect(directResult.ok, isTrue);
      expect(fakePrint.lastPrintTestPrinterId, 'usb:receipt');

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-2',
      );
      expect(snapshot.localConfig?.receiptTest?.success, isTrue);
      expect(snapshot.localConfig?.receiptTest?.printerId, 'usb:receipt');
      expect(snapshot.localConfig?.receiptTest?.printerRecordId, 'db-receipt');
    },
  );

  test(
    'printTestReceipt sends canonical printer payload to bridge test route',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-test-payload',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );

      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-test-payload',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-receipt',
      );

      final result = await orchestrator.printTestReceipt(
        restaurantId: 'rest-test-payload',
        role: PrinterSetupRole.adisyon,
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastPrintTestPrinterId, 'usb:receipt');
      expect(fakePrint.lastPrintTestPrinter?['id'], 'usb:receipt');
      expect(fakePrint.lastPrintTestPrinter?['backend'], 'usb-direct');
      expect(fakePrint.lastPrintTestPrinter?['vendorId'], '0x1234');
      expect(fakePrint.lastPrintTestPrinter?['productId'], '0x5678');
    },
  );

  test(
    'printBridgeTest skips snapshot fallback for explicit ethernet printer',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _cupsPrinter('cups:selected', 'POS-58', 'POS58_QUEUE'),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );
      final ethernetPrinter = UnifiedPrinterModel(
        id: 'tcp:192.168.1.100:9100',
        displayName: 'NETUM ZJ-8360 Ethernet',
        queueName: 'NETUM ZJ-8360 Ethernet',
        backend: DesktopPrinterBackend.tcp,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        statusLevel: 'ready',
        statusMessage: 'Ethernet yazıcı hazır.',
        raw: const <String, dynamic>{
          'id': 'tcp:192.168.1.100:9100',
          'name': 'NETUM ZJ-8360 Ethernet',
          'backend': 'tcp',
          'transportType': 'ethernet',
          'transport_type': 'ethernet',
          'host': '192.168.1.100',
          'ip_address': '192.168.1.100',
          'port': 9100,
          'paper_width_mm': 80,
          'auto_cut': true,
        },
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-ethernet',
        printerId: ethernetPrinter.id,
        printerName: ethernetPrinter.displayName,
        explicitPrinter: ethernetPrinter,
        skipSetupSnapshot: true,
        targetHost: '192.168.1.100',
        targetPort: 9100,
        testMode: 'ethernet_test',
        extraBody: const <String, dynamic>{
          'backend': 'tcp',
          'transportType': 'ethernet',
          'transport_type': 'ethernet',
          'host': '192.168.1.100',
          'ip_address': '192.168.1.100',
          'port': 9100,
          'printer_role': 'mutfak',
        },
      );

      expect(result.ok, isTrue);
      expect(fakeRepo.fetchPrintersCallCount, 0);
      expect(fakePrint.lastPrintTestPrinterId, 'tcp:192.168.1.100:9100');
      expect(fakePrint.lastPrintTestPrinter?['backend'], 'tcp');
      expect(fakePrint.lastPrintTestPrinter?['transportType'], 'ethernet');
      expect(fakePrint.lastPrintTestPrinter?['host'], '192.168.1.100');
      expect(fakePrint.lastPrintTestPrinter?['port'], 9100);
      expect(fakePrint.lastPrintTestTargetHost, '192.168.1.100');
      expect(fakePrint.lastPrintTestTargetPort, 9100);
      expect(fakePrint.lastPrintTestExtraBody?['backend'], 'tcp');
      expect(fakePrint.lastPrintTestExtraBody?['transportType'], 'ethernet');
      expect(fakePrint.lastPrintTestExtraBody?['host'], '192.168.1.100');
      expect(fakePrint.lastPrintTestExtraBody?['port'], 9100);
      expect(fakePrint.lastPrintTestExtraBody?['printer_role'], 'mutfak');
    },
  );

  test(
    'printTestReceipt uses ethernet test dispatch for tcp role printer',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _cupsPrinter('cups:selected', 'POS-58', 'POS58_QUEUE'),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );
      final ethernetPrinter = UnifiedPrinterModel(
        id: 'tcp:192.168.1.100:9100',
        displayName: 'pos-80',
        queueName: 'pos-80',
        backend: DesktopPrinterBackend.tcp,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        printerRecordId: 'db-kitchen',
        raw: const <String, dynamic>{
          'id': 'tcp:192.168.1.100:9100',
          'name': 'pos-80',
          'displayName': 'pos-80',
          'backend': 'tcp',
          'transportType': 'ethernet',
          'transport_type': 'ethernet',
          'host': '192.168.1.100',
          'ip_address': '192.168.1.100',
          'port': 9100,
          'paper_width_mm': 80,
          'auto_cut': true,
        },
      );

      final result = await orchestrator.printTestReceipt(
        restaurantId: 'rest-role-ethernet',
        role: PrinterSetupRole.mutfak,
        printerId: 'db-kitchen',
        explicitLivePrinter: ethernetPrinter,
        testSource: 'role_test',
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastPrintTestPrinterId, 'tcp:192.168.1.100:9100');
      expect(fakePrint.lastPrintTestPrinter?['backend'], 'tcp');
      expect(fakePrint.lastPrintTestPrinter?['transportType'], 'ethernet');
      expect(fakePrint.lastPrintTestTargetHost, '192.168.1.100');
      expect(fakePrint.lastPrintTestTargetPort, 9100);
      expect(fakePrint.lastPrintTestExtraBody?['document_type'], 'kitchen');
      expect(fakePrint.lastPrintTestExtraBody?['printer_role'], 'mutfak');
      expect(fakePrint.lastPrintTestExtraBody?['test_source'], 'role_test');
    },
  );

  test(
    'printPhysicalToPrinter keeps kitchen tcp mapping on payload without POS-58 fallback',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _cupsPrinter('cups:selected', 'POS-58', 'POS58_QUEUE'),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );
      final ethernetPrinter = UnifiedPrinterModel(
        id: 'tcp:192.168.1.100:9100',
        displayName: 'pos-80',
        queueName: 'pos-80',
        backend: DesktopPrinterBackend.tcp,
        os: DesktopPrinterOs.macos,
        isAvailable: true,
        canPrint: true,
        printerRecordId: 'db-kitchen',
        raw: const <String, dynamic>{
          'id': 'tcp:192.168.1.100:9100',
          'name': 'pos-80',
          'backend': 'tcp',
          'transportType': 'ethernet',
          'transport_type': 'ethernet',
          'host': '192.168.1.100',
          'ip_address': '192.168.1.100',
          'port': 9100,
        },
      );

      final result = await orchestrator.printPhysicalToPrinter(
        ethernetPrinter,
        PrintPayload(
          body: <String, dynamic>{
            'document_type': 'kitchen',
            'job_type': 'kitchen',
            'table_no': '12',
          },
          documentType: 'kitchen',
        ),
        restaurantId: 'rest-kitchen-ethernet',
        flowType: 'kitchen_test',
      );

      expect(result.ok, isTrue);
      expect(
        fakePrint.lastKitchenPayload?['printer_id'],
        'tcp:192.168.1.100:9100',
      );
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['backend'],
        'tcp',
      );
      expect(fakePrint.lastKitchenPayload?['backend'], 'tcp');
      expect(fakePrint.lastKitchenPayload?['printer_backend'], 'tcp');
      expect(fakePrint.lastKitchenPayload?['selected_printer_backend'], 'tcp');
      expect(
        fakePrint.lastKitchenPayload?['selected_printer_host'],
        '192.168.1.100',
      );
      expect(fakePrint.lastKitchenPayload?['selected_printer_port'], 9100);
      expect(fakePrint.lastKitchenPayload?['selected_printer_queue'], '');
      expect(fakePrint.lastKitchenPayload?['transportType'], 'ethernet');
      expect(fakePrint.lastKitchenPayload?['transport_type'], 'ethernet');
      expect(fakePrint.lastKitchenPayload?['printer_target_host'], isNull);
      expect(fakePrint.lastKitchenPayload?['target_host'], isNull);
      expect(fakePrint.lastKitchenPayload?['host'], '192.168.1.100');
      expect(fakePrint.lastKitchenPayload?['ip_address'], '192.168.1.100');
      expect(fakePrint.lastKitchenPayload?['port'], 9100);
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['host'],
        '192.168.1.100',
      );
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['port'],
        9100,
      );
      expect(fakePrint.lastKitchenPayload?['printer_name'], 'pos-80');
    },
  );

  test(
    'printPhysicalToPrinter removes stale usb and cups keys from kitchen tcp payload',
    () async {
      final fakePrint = _FakeLocalPrintService();
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _tcpKitchenPrinter(),
        PrintPayload(
          body: <String, dynamic>{
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
            'queue': 'POS58_QUEUE',
            'queueName': 'POS58_QUEUE',
            'printer_queue': 'POS58_QUEUE',
            'deviceIdentifier': 'usb-old',
            'device_identifier': 'usb-old',
            'printer_device_identifier': 'usb-old',
            'vendorId': '0x1234',
            'productId': '0x5678',
            'target_host': '127.0.0.1',
            'target_port': 515,
          },
          documentType: 'kitchen',
        ),
        restaurantId: 'rest-kitchen-stale-cleanup',
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastKitchenPayload?['queue'], isNull);
      expect(fakePrint.lastKitchenPayload?['queueName'], isNull);
      expect(fakePrint.lastKitchenPayload?['printer_queue'], isNull);
      expect(fakePrint.lastKitchenPayload?['deviceIdentifier'], isNull);
      expect(fakePrint.lastKitchenPayload?['device_identifier'], isNull);
      expect(
        fakePrint.lastKitchenPayload?['printer_device_identifier'],
        isNull,
      );
      expect(fakePrint.lastKitchenPayload?['vendorId'], isNull);
      expect(fakePrint.lastKitchenPayload?['productId'], isNull);
      expect(fakePrint.lastKitchenPayload?['target_host'], isNull);
      expect(fakePrint.lastKitchenPayload?['target_port'], isNull);
      expect(fakePrint.lastKitchenPayload?['host'], '192.168.1.100');
      expect(fakePrint.lastKitchenPayload?['port'], 9100);
      final printerPayload =
          fakePrint.lastKitchenPayload?['printer'] as Map<String, dynamic>;
      expect(printerPayload['backend'], 'tcp');
      expect(printerPayload['queue'], isNull);
      expect(printerPayload['queueName'], isNull);
      expect(printerPayload['deviceIdentifier'], isNull);
      expect(printerPayload['device_identifier'], isNull);
      expect(printerPayload['vendorId'], isNull);
      expect(printerPayload['productId'], isNull);
    },
  );

  test(
    'printPhysicalToPrinter fails kitchen tcp dispatch when bridge reports POS58 cups target',
    () async {
      final fakePrint = _FakeLocalPrintService(
        kitchenResponse: const <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'actual_queue': 'POS58_QUEUE',
          'actual_printer_name': 'POS-58',
        },
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _tcpKitchenPrinter(),
        PrintPayload.fromQueuedJob(<String, dynamic>{
          'document_type': 'kitchen',
          'printer_role': 'mutfak',
          'items': const <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Kebap', 'quantity': 1},
          ],
        }),
        restaurantId: 'rest-kitchen-tcp-mismatch',
      );

      expect(result.ok, isFalse);
      expect(result.status, 'kitchen_dispatch_route_mismatch');
      expect(
        result.message,
        'Ethernet mutfak yazıcısı seçili ama fiziksel dispatch POS58/CUPS/USB\'ye sapıyor.',
      );
    },
  );

  test(
    'printPhysicalToPrinter accepts kitchen tcp dispatch when bridge reports same host and port',
    () async {
      final fakePrint = _FakeLocalPrintService(
        kitchenResponse: const <String, dynamic>{
          'ok': true,
          'actual_backend': 'tcp',
          'actual_host': '192.168.1.100',
          'actual_port': 9100,
          'actual_queue': '',
        },
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _tcpKitchenPrinter(),
        PrintPayload.fromQueuedJob(<String, dynamic>{
          'document_type': 'kitchen',
          'printer_role': 'mutfak',
          'items': const <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Pilav', 'quantity': 1},
          ],
        }),
        restaurantId: 'rest-kitchen-tcp-match',
      );

      expect(result.ok, isTrue);
      expect(result.status, isNot('kitchen_dispatch_route_mismatch'));
    },
  );

  test(
    'printPhysicalToPrinter prefers nested tcp printer payload over stale top-level cups fields',
    () async {
      final fakePrint = _FakeLocalPrintService(
        kitchenResponse: const <String, dynamic>{
          'ok': true,
          'actual_backend': 'tcp',
          'actual_host': '192.168.1.100',
          'actual_port': 9100,
          'actual_queue': '',
        },
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _tcpKitchenPrinter(),
        PrintPayload(
          body: <String, dynamic>{
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
            'backend': 'cups',
            'printer_backend': 'cups',
            'selected_printer_backend': 'cups',
            'queue': 'STMicroelectronics_POS58_Printer_USB',
            'printer_queue': 'STMicroelectronics_POS58_Printer_USB',
            'deviceIdentifier': 'usb-stale',
            'printer': <String, dynamic>{
              'id': 'tcp:192.168.1.100:9100',
              'backend': 'tcp',
              'transportType': 'ethernet',
              'host': '192.168.1.100',
              'ip_address': '192.168.1.100',
              'port': 9100,
            },
          },
          documentType: 'kitchen',
        ),
        restaurantId: 'rest-kitchen-stale-top-level',
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastKitchenPayload?['backend'], 'tcp');
      expect(fakePrint.lastKitchenPayload?['printer_backend'], 'tcp');
      expect(fakePrint.lastKitchenPayload?['selected_printer_backend'], 'tcp');
      expect(fakePrint.lastKitchenPayload?['queue'], isNull);
      expect(fakePrint.lastKitchenPayload?['printer_queue'], isNull);
      expect(fakePrint.lastKitchenPayload?['deviceIdentifier'], isNull);
      final printerPayload =
          fakePrint.lastKitchenPayload?['printer'] as Map<String, dynamic>;
      expect(printerPayload['backend'], 'tcp');
      expect(printerPayload['host'], '192.168.1.100');
      expect(printerPayload['port'], 9100);
    },
  );

  test(
    'printPhysicalToPrinter skips strict kitchen guard for cups printer',
    () async {
      final fakePrint = _FakeLocalPrintService(
        kitchenResponse: const <String, dynamic>{
          'ok': true,
          'actual_backend': 'usb-direct',
          'actual_queue': 'POS58_QUEUE',
        },
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _cupsKitchenPrinter(),
        PrintPayload(
          body: <String, dynamic>{
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
          },
          documentType: 'kitchen',
        ),
        restaurantId: 'rest-kitchen-cups-skip',
      );

      expect(result.ok, isTrue);
      expect(result.status, isNot('kitchen_dispatch_route_mismatch'));
    },
  );

  test(
    'printPhysicalToPrinter skips strict kitchen guard for usb printer',
    () async {
      final fakePrint = _FakeLocalPrintService();
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _usbKitchenPrinter(),
        PrintPayload(
          body: <String, dynamic>{
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
          },
          documentType: 'kitchen',
        ),
        restaurantId: 'rest-kitchen-usb-skip',
      );

      expect(result.ok, isTrue);
      expect(result.status, isNot('kitchen_dispatch_route_mismatch'));
    },
  );

  test(
    'printPhysicalToPrinter does not run strict kitchen guard for receipt path',
    () async {
      final fakePrint = _FakeLocalPrintService(
        receiptResponse: const <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'actual_queue': 'POS58_QUEUE',
        },
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: _FakePrinterRepository(),
        printStationService: _FakePrintStationService(),
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        _tcpKitchenPrinter(),
        PrintPayload(
          body: <String, dynamic>{
            'document_type': 'receipt',
            'printer_role': 'adisyon',
            'table_no': '12',
          },
          documentType: 'receipt',
        ),
        restaurantId: 'rest-receipt-guard-skip',
      );

      expect(result.ok, isTrue);
      expect(result.status, isNot('kitchen_dispatch_route_mismatch'));
      expect(fakePrint.lastReceiptPayload, isNotNull);
    },
  );

  test(
    'savePrinterRoles stores db ids remotely and bridge-compatible canonical role mappings',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-remote-shape',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-remote-shape',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );

      final result = await orchestrator.savePrinterRoles(
        restaurantId: 'rest-remote-shape',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      expect(result.ok, isTrue);
      expect(fakeStation.savedConfig?['adisyon_printer_id'], 'db-receipt');
      expect(fakeStation.savedConfig?['kitchen_printer_id'], 'db-kitchen');

      final roleMappings =
          fakeStation.savedConfig?['role_mappings'] as Map<String, dynamic>;
      final receiptRole = roleMappings['adisyon'] as Map<String, dynamic>;
      final kitchenRole = roleMappings['mutfak'] as Map<String, dynamic>;

      expect(receiptRole['id'], 'usb:receipt');
      expect(receiptRole['name'], 'POS58 USB');
      expect(receiptRole['displayName'], 'POS58 USB');
      expect(receiptRole['queue'], 'POS58_USB');
      expect(receiptRole['queueName'], 'POS58_USB');
      expect(receiptRole['printerRecordId'], 'db-receipt');
      expect(receiptRole['printer_record_id'], 'db-receipt');
      expect(receiptRole['deviceIdentifier'], 'usb-1234:5678');
      expect(receiptRole['backend'], 'usb-direct');

      expect(kitchenRole['id'], 'cups:kitchen');
      expect(kitchenRole['name'], 'Mutfak Yazici');
      expect(kitchenRole['queue'], 'Kitchen_Queue');
      expect(kitchenRole['printerRecordId'], 'db-kitchen');
      expect(kitchenRole['deviceIdentifier'], 'Kitchen_Queue');
      expect(kitchenRole['backend'], 'cups');
    },
  );

  test(
    'successful receipt test does not promote a working printer as mutfak fallback',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final testResult = await orchestrator.printTestReceipt(
        restaurantId: 'rest-working-fallback',
        role: PrinterSetupRole.adisyon,
        printerId: 'usb:receipt',
        testSource: 'wizard_test',
      );

      expect(testResult.ok, isTrue);

      final resolvedKitchen = await orchestrator.resolvePrinterForRole(
        restaurantId: 'rest-working-fallback',
        role: PrinterSetupRole.mutfak,
      );
      expect(resolvedKitchen, isNull);

      final prepared = await orchestrator.prepareQueuedPrintPayload(
        restaurantId: 'rest-working-fallback',
        jobRecord: <String, dynamic>{
          'id': 'job-working-fallback',
          'job_type': 'kitchen',
        },
        payload: <String, dynamic>{
          'document_type': 'kitchen',
          'table_no': '12',
        },
      );

      expect(prepared.printer, isNull);
      expect(prepared.resolutionSource, 'unresolved');
      expect(prepared.payload['printer_id'], isNull);
      expect(prepared.payload['printer_device_identifier'], isNull);
      expect(prepared.payload['printer_backend'], isNull);
    },
  );

  test(
    'printBridgeTest promotes bridge-selected printer and assignWorkingPrinterToRoles uses canonical ids',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final testResult = await orchestrator.printBridgeTest(
        restaurantId: 'rest-generic-test',
      );
      expect(testResult.ok, isTrue);
      expect(testResult.printer?.id, 'usb:receipt');

      final assignResult = await orchestrator.assignWorkingPrinterToRoles(
        restaurantId: 'rest-generic-test',
      );
      expect(assignResult.ok, isTrue);

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-generic-test',
      );
      final recordId =
          snapshot.localConfig?.receiptSelection?.printer.printerRecordId;
      expect(recordId, isNotNull);
      expect(recordId, isNot('usb-0x1234-0x5678'));
      expect(snapshot.localConfig?.receiptSelection?.printer.id, 'usb:receipt');
      expect(snapshot.localConfig?.kitchenSelection?.printer.id, 'usb:receipt');
      expect(
        snapshot.localConfig?.kitchenSelection?.printer.printerRecordId,
        recordId,
      );
      expect(fakeStation.savedConfig?['adisyon_printer_id'], recordId);
      expect(fakeStation.savedConfig?['kitchen_printer_id'], recordId);
    },
  );

  test(
    'printBridgeTest stores a successful discovered printer as an active db record even before role mapping',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-auto-save-printer',
      );

      expect(result.ok, isTrue);
      final savedPrinters = await fakeRepo.fetchPrinters(
        'rest-auto-save-printer',
      );
      expect(savedPrinters, hasLength(1));
      expect(savedPrinters.first.name, 'POS58 USB');
      expect(savedPrinters.first.isActive, isTrue);
      expect(savedPrinters.first.testPrintStatus, 'ok');
      expect(savedPrinters.first.assignedRoles, isEmpty);
      expect(savedPrinters.first.deviceIdentifier, 'usb-1234:5678');
    },
  );

  test(
    'printBridgeTest uses same printer-aware bridge test path and does not promote failed responses',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
        printTestResponses: <Object>[
          <String, dynamic>{
            'ok': false,
            'message': 'USB yazıcıya erişilemedi.',
            'printer': _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          },
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-bridge-failure',
        printerId: 'usb:receipt',
      );

      expect(result.ok, isFalse);
      expect(result.status, 'test_failed');
      expect(result.message, 'USB yazıcıya erişilemedi.');
      expect(fakePrint.lastPrintTestPrinter?['id'], 'usb:receipt');
      expect(fakePrint.lastPrintTestPrinter?['backend'], 'usb-direct');

      final assignResult = await orchestrator.assignWorkingPrinterToRoles(
        restaurantId: 'rest-bridge-failure',
      );
      expect(assignResult.ok, isFalse);
    },
  );

  test(
    'printBridgeTest returns warning success when CUPS accepts the job without physical confirmation',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _cupsPrinter('cups:receipt', 'POS58 CUPS', 'POS58_CUPS'),
        ],
        printTestResponses: <Object>[
          <String, dynamic>{
            'ok': true,
            'actual_backend': 'cups',
            'selected_backend': 'cups',
            'queue_status': 'completed',
            'physical_confirmation': false,
            'confirmation_status': 'cups_accepted_unverified',
            'warning':
                'CUPS işi kabul etti; fiziksel baskı macOS tarafından doğrulanamadı',
            'physical_confirmation_message':
                'CUPS işi kabul etti ama fiziksel baskı doğrulanamadı. Yazıcı kuyruğunu ve macOS yazıcı durumunu kontrol edin.',
            'printer': _cupsPrinter('cups:receipt', 'POS58 CUPS', 'POS58_CUPS'),
          },
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-cups-unconfirmed',
        printerId: 'cups:receipt',
      );

      expect(result.ok, isTrue);
      expect(result.status, 'ready_unverified');
      expect(
        result.message,
        'Test işi yazıcı kuyruğuna gönderildi. Fiziksel baskıyı kontrol edin.',
      );
      expect(result.raw?['confirmation_status'], 'cups_accepted_unverified');
      expect(
        result.raw?['warning'],
        'CUPS işi kabul etti; fiziksel baskı macOS tarafından doğrulanamadı',
      );
    },
  );

  test(
    'printTestReceipt returns ok=false when LocalPrintService.printTest throws',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
        printTestResponses: <Object>[Exception('bridge exploded')],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-test-exception',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );

      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-test-exception',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-receipt',
      );

      final result = await orchestrator.printTestReceipt(
        restaurantId: 'rest-test-exception',
        role: PrinterSetupRole.adisyon,
      );

      expect(result.ok, isFalse);
      expect(result.status, 'test_failed');
      expect(result.message, 'Test basarisiz');
    },
  );

  test(
    'printBridgeTest returns a clear disabled message when bridge rejects the request because print system is off',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
        printTestResponses: <Object>[
          const LocalPrintServiceException(
            'Baskı sistemi şu anda kapalı. Yazıcı Ayarları > Baskı Sistemi > Aç butonunu kullanın.',
            statusCode: 503,
          ),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-disabled-message',
      );

      expect(result.ok, isFalse);
      expect(result.status, 'test_failed');
      expect(
        result.message,
        'Baskı sistemi kapalı. Test göndermek için sistemi açın.',
      );
    },
  );

  test(
    'printBridgeTest shows queue stuck message and job ids (structured error)',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _cupsPrinter(
            'cups:pos58',
            'POS58 CUPS',
            'STMicroelectronics_POS58_Printer_USB',
          ),
        ],
        printTestResponses: <Object>[
          const LocalPrintServiceException(
            'CUPS işi kabul etti ama kuyruk ilerlemiyor.',
            statusCode: 409,
            details: <String, dynamic>{
              'ok': false,
              'errorCode': 'cups_queue_stuck',
              'suggested_action': 'clear_queue',
              'queue_status': 'stuck',
              'queue_message': 'Yazıcının kullanılabilir olması bekleniyor.',
              'active_job_ids': <String>[
                'STMicroelectronics_POS58_Printer_USB-179',
                'STMicroelectronics_POS58_Printer_USB-180',
              ],
              'lp_command':
                  'lp -d STMicroelectronics_POS58_Printer_USB -o raw ...',
              'lp_output':
                  'request id is STMicroelectronics_POS58_Printer_USB-179',
            },
          ),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-queue-stuck',
      );

      expect(result.ok, isFalse);
      expect(result.status, 'test_failed');
      expect(
        result.message,
        'CUPS yazıcı işi kabul etti ama yazıcıya aktaramıyor. USB kablo, kağıt, kapak ve CUPS sürücü/raw ayarını kontrol edin.\n'
        'Bekleyen işler: STMicroelectronics_POS58_Printer_USB-179, STMicroelectronics_POS58_Printer_USB-180',
      );
      expect(result.raw?['errorCode'], 'cups_queue_stuck');
      expect(result.raw?['suggested_action'], 'clear_queue');
      expect(result.raw?['lp_command'], isNotNull);
    },
  );

  test('printBridgeTest shows duplicate test suppressed message', () async {
    final fakeRepo = _FakePrinterRepository();
    final fakeStation = _FakePrintStationService();
    final fakePrint = _FakeLocalPrintService(
      discoveredPrinters: <Map<String, dynamic>>[
        _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
      ],
      printTestResponses: <Object>[
        const LocalPrintServiceException(
          'Test çok sık gönderildi.',
          statusCode: 429,
          details: <String, dynamic>{
            'ok': false,
            'errorCode': 'duplicate_test_suppressed',
            'cooldown_seconds': 5,
          },
        ),
      ],
    );

    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: fakeRepo,
      printStationService: fakeStation,
      printServiceFactory: () => fakePrint,
    );

    final result = await orchestrator.printBridgeTest(
      restaurantId: 'rest-duplicate-guard',
    );

    expect(result.ok, isFalse);
    expect(result.status, 'test_failed');
    expect(
      result.message,
      'Aynı test kısa süre önce gönderildi. Lütfen birkaç saniye bekleyin.',
    );
    expect(result.raw?['errorCode'], 'duplicate_test_suppressed');
  });

  test(
    'printBridgeTest does not dispatch when print system is disabled',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService(
        localQueueStatus: <String, dynamic>{
          'ok': true,
          'queue': <String, dynamic>{'print_system_enabled': false},
        },
      );
      final fakePrint = _FakeLocalPrintService(
        queueStatusPayload: <String, dynamic>{
          'ok': true,
          'queue': <String, dynamic>{'print_system_enabled': false},
        },
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printBridgeTest(
        restaurantId: 'rest-disabled-guard',
      );

      expect(result.ok, isFalse);
      expect(result.status, 'print_system_disabled');
      expect(
        result.message,
        'Baskı sistemi kapalı. Yazdırmak için Yazıcı Merkezi’nden sistemi açın.',
      );
      expect(result.raw?['errorCode'], 'print_system_disabled');
      expect(fakePrint.printTestCallCount, 0);
    },
  );

  test('runtime log failures do not break test printing', () async {
    final fakeRepo = _FakePrinterRepository();
    final fakeStation = _FakePrintStationService();
    final fakePrint = _FakeLocalPrintService(
      discoveredPrinters: <Map<String, dynamic>>[
        _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
      ],
    );

    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: fakeRepo,
      printStationService: fakeStation,
      printServiceFactory: () => fakePrint,
      eventLogService: _ThrowingPrinterEventLogService(),
    );

    await fakeRepo.upsertPrinter(
      restaurantId: 'rest-log-failure',
      printerId: 'db-receipt',
      name: 'POS58 USB',
      code: 'ADISYON_POS58_USB',
      connectionType: PrinterModel.usbConnectionType,
      deviceIdentifier: 'POS58_USB',
    );

    await orchestrator.savePrinterRoles(
      restaurantId: 'rest-log-failure',
      receiptPrinterId: 'db-receipt',
      kitchenPrinterId: 'db-receipt',
    );

    final result = await orchestrator.printTestReceipt(
      restaurantId: 'rest-log-failure',
      role: PrinterSetupRole.adisyon,
    );

    expect(result.ok, isTrue);
    expect(fakePrint.lastPrintTestPrinter?['backend'], 'usb-direct');
  });

  test(
    'loadSetupSnapshot merges saved-only db printers into the canonical catalog',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-catalog-merge',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-catalog-merge',
        printerId: 'db-saved-only',
        name: 'Arka Ofis Yazici',
        code: 'ARKA_OFIS',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'BACKOFFICE_QUEUE',
      );

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-catalog-merge',
      );

      final livePrinter = snapshot.printers.firstWhere(
        (printer) => printer.id == 'usb:receipt',
      );
      final savedOnlyPrinter = snapshot.printers.firstWhere(
        (printer) => printer.printerRecordId == 'db-saved-only',
      );

      expect(livePrinter.printerRecordId, 'db-receipt');
      expect(savedOnlyPrinter.id, 'db-saved-only');
      expect(savedOnlyPrinter.displayName, 'Arka Ofis Yazici');
      expect(savedOnlyPrinter.queueName, 'BACKOFFICE_QUEUE');
      expect(savedOnlyPrinter.canPrint, isFalse);
      expect(savedOnlyPrinter.raw['source'], 'saved_record');
    },
  );

  test('savePrinterRoles keeps local config when printer sync fails', () async {
    final fakeRepo = _FakePrinterRepository(upsertShouldThrow: true);
    final fakeStation = _FakePrintStationService(saveShouldThrow: true);
    final fakePrint = _FakeLocalPrintService(
      discoveredPrinters: <Map<String, dynamic>>[
        _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
      ],
    );

    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: fakeRepo,
      printStationService: fakeStation,
      printServiceFactory: () => fakePrint,
    );

    final result = await orchestrator.savePrinterRoles(
      restaurantId: 'rest-3',
      receiptPrinterId: 'usb:receipt',
      kitchenPrinterId: 'cups:kitchen',
    );

    expect(result.ok, isTrue);
    expect(result.localSaved, isTrue);
    expect(result.cloudSaved, isFalse);
    expect(result.status, 'local_saved_only');

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'rest-3',
    );
    expect(
      snapshot.localConfig?.receiptSelection?.printer.queueName,
      'POS58_USB',
    );
    expect(
      snapshot.localConfig?.kitchenSelection?.printer.queueName,
      'Kitchen_Queue',
    );
  });

  test(
    'prepareQueuedPrintPayload injects normalized role printer for receipt jobs',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-4',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-4',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );

      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-4',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      final resolution = await orchestrator.prepareQueuedPrintPayload(
        restaurantId: 'rest-4',
        jobRecord: <String, dynamic>{
          'id': 'job-1',
          'job_type': 'receipt',
          'printer_role': 'adisyon',
        },
        payload: <String, dynamic>{'job_type': 'receipt', 'table_no': '12'},
      );

      expect(resolution.printer?.id, 'usb:receipt');
      expect(resolution.printer?.printerRecordId, isNotNull);
      expect(resolution.payload['printer_role'], 'adisyon');
      expect(resolution.payload['printer_record_id'], isNotNull);
      expect(resolution.payload['printer_name'], 'POS58 USB');
      expect(resolution.payload.containsKey('printer_queue'), isFalse);
      expect(resolution.payload['printer_device_identifier'], 'usb-1234:5678');
      expect(resolution.payload['printer'], isA<Map<String, dynamic>>());
    },
  );

  test(
    'prepareQueuedPrintPayload prefers role mapping over stale embedded printer payload',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-6',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-6',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );

      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-6',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      final resolution = await orchestrator.prepareQueuedPrintPayload(
        restaurantId: 'rest-6',
        jobRecord: <String, dynamic>{
          'id': 'job-2',
          'job_type': 'receipt',
          'printer_role': 'adisyon',
        },
        payload: <String, dynamic>{
          'job_type': 'receipt',
          'printer': <String, dynamic>{
            'id': 'usb:stale',
            'name': 'Eski Yazici',
            'queue': 'STALE_QUEUE',
            'backend': 'cups',
            'os': 'macos',
            'ready': true,
            'statusLevel': 'ready',
          },
        },
      );

      expect(resolution.printer?.id, 'usb:receipt');
      expect(resolution.resolutionSource, 'role_selection');
      expect(resolution.payload.containsKey('printer_queue'), isFalse);
      expect(resolution.payload['printer_name'], 'POS58 USB');
    },
  );

  test(
    'savePrinterRoles preserves matching POS58 cups selection for legacy cups records',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakeRecovery = _FakeMacosUsbPermissionRecoveryService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          _cupsPrinter(
            'cups:pos58',
            'STMicroelectronics POS58 Printer USB',
            'STMicroelectronics_POS58_Printer_USB',
          ),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
        usbPermissionRecoveryService: fakeRecovery,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-pos58',
        printerId: 'db-receipt',
        name: 'STMicroelectronics POS58 Printer USB',
        code: 'ADISYON_STMICRO_POS58',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'STMicroelectronics_POS58_Printer_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-pos58',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );

      final result = await orchestrator.savePrinterRoles(
        restaurantId: 'rest-pos58',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      expect(result.ok, isTrue);
      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-pos58',
      );
      expect(
        snapshot.localConfig?.receiptSelection?.printer.backend,
        DesktopPrinterBackend.cups,
      );
      expect(snapshot.localConfig?.receiptSelection?.printer.id, 'cups:pos58');
      expect(
        snapshot.localConfig?.receiptSelection?.printer.queueName,
        'STMicroelectronics_POS58_Printer_USB',
      );

      final savedPrinters = await fakeRepo.fetchPrinters('rest-pos58');
      final savedReceipt = savedPrinters.firstWhere(
        (printer) => printer.id == 'db-receipt',
      );
      expect(
        savedReceipt.deviceIdentifier,
        'STMicroelectronics_POS58_Printer_USB',
      );
    },
  );

  test(
    'printPhysicalToPrinter requires USB direct transport for usb printers',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
        ],
        receiptResponse: <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'selected_backend': 'cups',
          'transport_output': 'cups',
        },
        kitchenResponse: <String, dynamic>{
          'ok': true,
          'transport_output': 'USB direct',
        },
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          os: DesktopPrinterOs.macos,
        ),
        PrintPayload.testForRole(PrinterSetupRole.adisyon),
      );

      expect(result.ok, isFalse);
      expect(
        result.message,
        'CUPS tamamlandı ama USB termal yazıcı fiziksel çıktı vermedi.',
      );
      expect(fakePrint.lastReceiptPayload?['printer_backend'], 'usb-direct');
      expect(fakePrint.lastReceiptPayload?['printer_queue'], isNull);
      expect(
        fakePrint.lastReceiptPayload?['printer_device_identifier'],
        'usb-0416:5011',
      );
    },
  );

  test(
    'printPhysicalToPrinter preserves explicit CUPS transport for POS58 cups printers',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          _cupsPrinter(
            'cups:pos58',
            'STMicroelectronics POS58 Printer USB',
            'STMicroelectronics_POS58_Printer_USB',
          ),
        ],
        receiptResponse: <String, dynamic>{
          'ok': true,
          'actual_backend': 'usb-direct',
          'selected_backend': 'usb-direct',
          'transport_output': 'USB direct',
        },
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
          ..._cupsPrinter(
            'cups:pos58',
            'STMicroelectronics POS58 Printer USB',
            'STMicroelectronics_POS58_Printer_USB',
          ),
          'vendorId': '0x0416',
          'productId': '0x5011',
        }, os: DesktopPrinterOs.macos),
        PrintPayload.testForRole(PrinterSetupRole.adisyon),
        restaurantId: 'rest-cups-pos58',
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastReceiptPayload?['printer_backend'], 'cups');
      expect(
        fakePrint.lastReceiptPayload?['printer_queue'],
        'STMicroelectronics_POS58_Printer_USB',
      );
    },
  );

  test(
    'printPhysicalToPrinter keeps selected POS58 usb-direct backend on macOS',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 Printer USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          _cupsPrinter(
            'cups:pos58',
            'STMicroelectronics POS58 Printer USB',
            'STMicroelectronics_POS58_Printer_USB',
          ),
        ],
        receiptResponse: <String, dynamic>{
          'ok': true,
          'actual_backend': 'usb-direct',
          'selected_backend': 'usb-direct',
          'transport_output': 'USB direct',
        },
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
          ..._usbPrinter(
            'usb:pos58',
            'POS58 Printer USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          'printerRecordId': 'db-pos58',
        }, os: DesktopPrinterOs.macos),
        PrintPayload.testForRole(PrinterSetupRole.adisyon),
        restaurantId: 'rest-cups-fallback',
      );

      expect(result.ok, isTrue);
      expect(result.printer?.backend, DesktopPrinterBackend.usbDirect);
      expect(fakePrint.lastReceiptPayload?['printer_backend'], 'usb-direct');
      expect(fakePrint.lastReceiptPayload?['printer_queue'], isNull);
      expect(
        fakePrint.lastReceiptPayload?['printer_device_identifier'],
        'usb-0416:5011',
      );
      expect(fakePrint.lastReceiptPayload?['used_fallback'], isNot(true));
      expect(fakePrint.lastReceiptPayload?['fallback_reason'], isNull);
    },
  );

  test(
    'printPhysicalToPrinter keeps CUPS accepted jobs successful with warning metadata',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _cupsPrinter('cups:receipt', 'POS58 CUPS', 'POS58_CUPS'),
        ],
        receiptResponse: <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'selected_backend': 'cups',
          'queue_status': 'completed',
          'physical_confirmation': false,
          'confirmation_status': 'cups_accepted_unverified',
          'warning':
              'CUPS işi kabul etti; fiziksel baskı macOS tarafından doğrulanamadı',
          'transport_output': 'request id is POS58_CUPS-42 (1 file(s))',
        },
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(
          _cupsPrinter('cups:receipt', 'POS58 CUPS', 'POS58_CUPS'),
          os: DesktopPrinterOs.macos,
        ),
        PrintPayload.testForRole(PrinterSetupRole.adisyon),
        restaurantId: 'rest-cups-warning',
      );

      expect(result.ok, isTrue);
      expect(result.status, 'ready_warning');
      expect(
        result.message,
        'CUPS işi kabul etti; fiziksel baskı macOS tarafından doğrulanamadı',
      );
      expect(result.raw?['confirmation_status'], 'cups_accepted_unverified');
    },
  );

  test(
    'printPhysicalToPrinter recommends CUPS instead of retrying locked POS58 usb-direct backend',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakeRecovery = _FakeMacosUsbPermissionRecoveryService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
        ],
        receiptResponses: <Object>[
          const LocalPrintServiceException(
            'Cannot claim USB interface: [Errno 13] Access denied. If CUPS is holding the device, restart it: sudo killall -USR1 cupsd',
            details: <String, dynamic>{
              'errorCode': 'usb_interface_claim_denied',
              'operator_message':
                  'Bu yazıcı macOS tarafından tutuluyor. Adisyon için CUPS yolunu kullanmanız önerilir.',
            },
          ),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
        usbPermissionRecoveryService: fakeRecovery,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          os: DesktopPrinterOs.macos,
        ),
        PrintPayload.testForRole(PrinterSetupRole.adisyon),
        restaurantId: 'rest-retry',
      );

      expect(result.ok, isFalse);
      expect(
        result.message,
        contains('Adisyon için CUPS yolunu kullanmanız önerilir'),
      );
      expect(fakeRecovery.requestCount, 0);
      expect(fakeRecovery.releaseCount, 0);
      expect(fakeRecovery.instructionsCount, 0);
      expect(fakePrint.printReceiptCallCount, 1);
      expect(fakePrint.releaseUsbPrintersCallCount, 0);
    },
  );

  test(
    'printPhysicalToPrinter does not attempt admin release for locked POS58 usb-direct backend',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakeRecovery = _FakeMacosUsbPermissionRecoveryService(
        releaseResults: <AdminCupsReleaseResult>[
          const AdminCupsReleaseResult(
            ok: false,
            message: 'Yönetici izni verilmedi.',
            error: 'user_cancelled',
          ),
          const AdminCupsReleaseResult(
            ok: true,
            message: 'CUPS yeniden başlatıldı.',
          ),
        ],
      );
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
        ],
        receiptResponses: <Object>[
          const LocalPrintServiceException(
            'Cannot claim USB interface: [Errno 13] Access denied',
            details: <String, dynamic>{
              'errorCode': 'usb_interface_claim_denied',
              'operator_message':
                  'Bu yazıcı macOS tarafından tutuluyor. Adisyon için CUPS yolunu kullanmanız önerilir.',
            },
          ),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
        usbPermissionRecoveryService: fakeRecovery,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          os: DesktopPrinterOs.macos,
        ),
        PrintPayload.testForRole(PrinterSetupRole.adisyon),
        restaurantId: 'rest-retry-cancel',
      );

      expect(result.ok, isFalse);
      expect(
        result.message,
        contains('Adisyon için CUPS yolunu kullanmanız önerilir'),
      );
      expect(fakeRecovery.requestCount, 0);
      expect(fakeRecovery.retryPromptCount, 0);
      expect(fakeRecovery.releaseCount, 0);
      expect(fakePrint.printReceiptCallCount, 1);
    },
  );

  test(
    'ethernet kitchen print uses raster image mode with 80mm profile metadata',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService();
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        const UnifiedPrinterModel(
          id: 'tcp:192.168.1.100:9100',
          displayName: 'pos-80',
          queueName: 'pos-80',
          backend: DesktopPrinterBackend.tcp,
          os: DesktopPrinterOs.macos,
          isAvailable: true,
          canPrint: true,
          raw: <String, dynamic>{
            'backend': 'tcp',
            'transportType': 'ethernet',
            'host': '192.168.1.100',
            'ip_address': '192.168.1.100',
            'port': 9100,
            'paper_width_mm': 80,
            'auto_cut': true,
          },
        ),
        PrintPayload(
          documentType: 'kitchen',
          body: <String, dynamic>{
            'document_type': 'kitchen',
            'printer_role': 'mutfak',
            'items': const <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Çorba', 'quantity': 1},
            ],
          },
        ),
        restaurantId: 'rest-kitchen-render',
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastKitchenPayload?['render_mode'], 'image');
      expect(fakePrint.lastKitchenPayload?['paper_width_mm'], 80);
      expect(
        fakePrint.lastKitchenPayload?['printer_profile'],
        'generic_80mm_escpos',
      );
      expect(fakePrint.lastKitchenPayload?['raster_width_px'], 576);
      expect(fakePrint.lastKitchenPayload?['host'], '192.168.1.100');
      expect(fakePrint.lastKitchenPayload?['port'], 9100);
    },
  );

  test(
    'macOS POS-58 receipt print uses 58mm safe raster profile metadata',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      final result = await orchestrator.printPhysicalToPrinter(
        UnifiedPrinterModel.fromBridgeMap(
          _usbPrinter(
            'usb:pos58',
            'POS58 USB',
            'POS58_USB',
            vendorId: '0x0416',
            productId: '0x5011',
          ),
          os: DesktopPrinterOs.macos,
        ),
        PrintPayload(
          documentType: 'receipt',
          body: <String, dynamic>{
            'document_type': 'receipt',
            'printer_role': 'adisyon',
            'items': const <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Çay', 'qty': 1, 'total': 20},
            ],
          },
        ),
        restaurantId: 'rest-pos58-render',
      );

      expect(result.ok, isTrue);
      expect(fakePrint.lastReceiptPayload?['render_mode'], 'image');
      expect(fakePrint.lastReceiptPayload?['paper_width_mm'], 58);
      expect(fakePrint.lastReceiptPayload?['printer_profile'], 'pos58');
      expect(fakePrint.lastReceiptPayload?['raster_width_px'], 384);
      expect(fakePrint.lastReceiptPayload?['auto_cut'], isFalse);
    },
  );

  test(
    'prepareQueuedPrintPayload keeps canonical role printer when bridge scan is temporarily empty',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-7',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-7',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-receipt',
      );

      final orchestratorWithoutBridge = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => _FakeLocalPrintService(
          discoveredPrinters: <Map<String, dynamic>>[],
        ),
      );

      final resolution = await orchestratorWithoutBridge
          .prepareQueuedPrintPayload(
            restaurantId: 'rest-7',
            jobRecord: <String, dynamic>{
              'id': 'job-3',
              'job_type': 'receipt',
              'printer_role': 'adisyon',
            },
            payload: <String, dynamic>{'job_type': 'receipt', 'table_no': '12'},
          );

      expect(resolution.printer, isNotNull);
      expect(resolution.printer?.printerRecordId, 'db-receipt');
      expect(resolution.printer?.raw['source'], 'saved_record');
      expect(resolution.resolutionSource, 'role_selection');
      expect(resolution.payload['printer_record_id'], 'db-receipt');
      expect(resolution.payload['printer_backend'], 'usb-direct');
      expect(resolution.payload['printer_queue'], isNull);
      expect(resolution.payload['printer_device_identifier'], 'usb-1234:5678');
    },
  );

  test('loadSetupSnapshot keeps bridge usable when queue is ready', () async {
    final fakeRepo = _FakePrinterRepository();
    final fakeStation = _FakePrintStationService();
    final fakePrint = _FakeLocalPrintService(
      discoveredPrinters: <Map<String, dynamic>>[
        _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
      ],
      healthPayload: <String, dynamic>{
        'ok': true,
        'printer': <String, dynamic>{'ok': false, 'details': 'stale'},
      },
      setupStatusPayload: <String, dynamic>{
        'status': 'running_unhealthy',
        'health': <String, dynamic>{
          'ok': true,
          'printer': <String, dynamic>{'ok': false, 'details': 'stale'},
        },
      },
    );

    final orchestrator = DesktopPrintOrchestrator(
      printerRepository: fakeRepo,
      printStationService: fakeStation,
      printServiceFactory: () => fakePrint,
    );

    final snapshot = await orchestrator.loadSetupSnapshot(
      restaurantId: 'rest-5',
    );

    expect(snapshot.bridgeReachable, isTrue);
    expect(snapshot.bridgeHealthy, isTrue);
    expect(snapshot.bridgeHealth?['ok'], isTrue);
  });

  test(
    'loadSetupSnapshot keeps saved canonical printers visible when printer is missing from live scan',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-stale',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-stale',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );
      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-stale',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      fakePrint.discoveredPrinters
        ..clear()
        ..add(
          _usbPrinter(
            'usb:new',
            'Yeni USB',
            'NEW_USB',
            vendorId: '0x9999',
            productId: '0x8888',
          ),
        );

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-stale',
        forceRefresh: true,
      );

      expect(snapshot.printers, hasLength(3));
      expect(snapshot.printers.first.id, 'usb:new');
      expect(
        snapshot.printers.map((printer) => printer.printerRecordId),
        containsAll(<String?>['db-receipt', 'db-kitchen']),
      );
      expect(
        snapshot.printers
            .where((printer) => printer.raw['source'] == 'saved_record')
            .map((printer) => printer.id),
        containsAll(<String>['db-receipt', 'db-kitchen']),
      );
      expect(snapshot.selectedReceiptPrinterId, 'db-receipt');
      expect(snapshot.selectedKitchenPrinterId, 'db-kitchen');
      expect(
        snapshot.localConfig?.receiptSelection?.printer.raw['source'],
        'saved_record',
      );
      expect(
        snapshot.localConfig?.kitchenSelection?.printer.raw['source'],
        'saved_record',
      );
    },
  );

  test(
    'deletePrinter clears persisted role mappings and station mappings',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-delete',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-delete',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );
      fakeRepo.stationMappings.add(
        StationPrinterModel(
          id: 'mapping-1',
          stationId: 'station-1',
          stationName: 'Mutfak',
          printerId: 'db-receipt',
          printerName: 'POS58 USB',
          printerCode: 'ADISYON_POS58_USB',
          isPrimary: true,
          createdAt: DateTime.now(),
        ),
      );
      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-delete',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      final result = await orchestrator.deletePrinter(
        restaurantId: 'rest-delete',
        printerId: 'db-receipt',
        force: true,
      );

      expect(result.ok, isTrue);
      expect(await fakeRepo.fetchPrinterById('db-receipt'), isNull);
      expect(fakeRepo.stationMappings, isEmpty);
      expect(fakeStation.savedConfig?['role_mappings'], isEmpty);
      expect(fakeStation.savedConfig?['adisyon_printer_id'], isNull);
      expect(fakeStation.savedConfig?['kitchen_printer_id'], isNull);

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-delete',
        forceRefresh: true,
      );
      expect(snapshot.selectedReceiptPrinterId, isNull);
      expect(snapshot.selectedKitchenPrinterId, isNull);
    },
  );

  test(
    'hardResetPrinters clears local config, db records, and role mappings',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-reset',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-reset',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );
      fakeRepo.stationMappings.add(
        StationPrinterModel(
          id: 'mapping-1',
          stationId: 'station-1',
          stationName: 'Mutfak',
          printerId: 'db-kitchen',
          printerName: 'Mutfak Yazici',
          printerCode: 'MUTFAK_KITCHEN_QUEUE',
          isPrimary: true,
          createdAt: DateTime.now(),
        ),
      );
      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-reset',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen',
      );

      final result = await orchestrator.hardResetPrinters(
        restaurantId: 'rest-reset',
      );

      expect(result.ok, isTrue);
      expect(await fakeRepo.fetchPrinters('rest-reset'), isEmpty);
      expect(fakeRepo.stationMappings, isEmpty);
      expect(fakeStation.savedConfig?['role_mappings'], isEmpty);
      expect(fakeStation.savedConfig?['adisyon_printer_id'], isNull);
      expect(fakeStation.savedConfig?['kitchen_printer_id'], isNull);

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-reset',
        forceRefresh: true,
      );
      expect(snapshot.printers, hasLength(2));
      expect(snapshot.selectedReceiptPrinterId, isNull);
      expect(snapshot.selectedKitchenPrinterId, isNull);
      expect(snapshot.localConfig?.receiptSelection, isNull);
      expect(snapshot.localConfig?.kitchenSelection, isNull);
    },
  );

  test(
    'resolvePrinterForRole falls back to remote role mappings when local config is absent',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-remote',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-remote',
        printerId: 'db-kitchen',
        name: 'Mutfak Yazici',
        code: 'MUTFAK_KITCHEN_QUEUE',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'Kitchen_Queue',
      );

      fakeStation.savedConfig = <String, dynamic>{
        'restaurant_id': 'rest-remote',
        'adisyon_printer_id': 'db-receipt',
        'kitchen_printer_id': 'db-kitchen',
        'role_mappings': <String, dynamic>{
          'adisyon': <String, dynamic>{
            'id': 'usb:receipt',
            'displayName': 'POS58 USB',
            'queueName': 'POS58_USB',
            'backend': 'usb-direct',
            'os': 'macos',
            'isAvailable': true,
            'canPrint': true,
            'printerRecordId': 'db-receipt',
          },
          'mutfak': <String, dynamic>{
            'id': 'cups:kitchen',
            'displayName': 'Mutfak Yazici',
            'queueName': 'Kitchen_Queue',
            'backend': 'cups',
            'os': 'macos',
            'isAvailable': true,
            'canPrint': true,
            'printerRecordId': 'db-kitchen',
          },
        },
        'updated_at': DateTime.now().toIso8601String(),
      };

      final snapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-remote',
      );
      expect(snapshot.localConfig?.receiptSelection?.printer.id, 'usb:receipt');
      expect(snapshot.selectedReceiptPrinterId, 'usb:receipt');
      expect(snapshot.selectedKitchenPrinterId, 'cups:kitchen');

      final resolved = await orchestrator.resolvePrinterForRole(
        restaurantId: 'rest-remote',
        role: PrinterSetupRole.adisyon,
      );

      expect(resolved, isNotNull);
      expect(resolved?.id, 'usb:receipt');
      expect(resolved?.printerRecordId, 'db-receipt');
    },
  );

  test(
    'prepareQueuedPrintPayload injects remote receipt printer when only remote config exists',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
          _cupsPrinter('cups:kitchen', 'Mutfak Yazici', 'Kitchen_Queue'),
        ],
      );

      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-queued-remote',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );

      fakeStation.savedConfig = <String, dynamic>{
        'restaurant_id': 'rest-queued-remote',
        'adisyon_printer_id': 'db-receipt',
        'role_mappings': <String, dynamic>{
          'adisyon': <String, dynamic>{
            'id': 'usb:receipt',
            'displayName': 'POS58 USB',
            'queueName': 'POS58_USB',
            'backend': 'usb-direct',
            'os': 'macos',
            'isAvailable': true,
            'canPrint': true,
            'printerRecordId': 'db-receipt',
          },
        },
        'updated_at': DateTime.now().toIso8601String(),
      };

      final resolution = await orchestrator.prepareQueuedPrintPayload(
        restaurantId: 'rest-queued-remote',
        jobRecord: <String, dynamic>{
          'id': 'job-remote-1',
          'job_type': 'receipt',
          'printer_role': 'adisyon',
        },
        payload: <String, dynamic>{'job_type': 'receipt', 'table_no': '7'},
      );

      expect(resolution.printer?.id, 'usb:receipt');
      expect(resolution.printer?.printerRecordId, 'db-receipt');
      expect(resolution.payload['printer_id'], 'usb:receipt');
      expect(resolution.payload['printer_record_id'], 'db-receipt');
      expect(resolution.payload['printer_role'], 'adisyon');
    },
  );

  test(
    'prepareQueuedPrintPayload prefers station ethernet printer over kitchen role mapping',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-station-priority',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-station-priority',
        printerId: 'db-kitchen-role',
        name: 'POS58 Kitchen',
        code: 'MUTFAK_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_KITCHEN_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-station-priority',
        printerId: 'db-kitchen-ethernet',
        name: '80mm new',
        code: 'MUTF_ETHERNET',
        connectionType: PrinterModel.networkConnectionType,
        ipAddress: '192.168.1.100',
        port: 9100,
        deviceIdentifier: 'tcp:192.168.1.100:9100',
        supportsCut: true,
      );
      fakeRepo.stationMappings.add(
        StationPrinterModel(
          id: 'map-ocak',
          stationId: 'station-ocak',
          printerId: 'db-kitchen-ethernet',
          isPrimary: true,
          createdAt: DateTime(2026, 5, 27),
          stationName: 'Ocak',
          printerName: '80mm new',
        ),
      );

      await orchestrator.savePrinterRoles(
        restaurantId: 'rest-station-priority',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen-role',
      );

      final resolution = await orchestrator.prepareQueuedPrintPayload(
        restaurantId: 'rest-station-priority',
        jobRecord: <String, dynamic>{
          'id': 'job-station-priority',
          'job_type': 'kitchen',
          'order_id': 'order-1',
          'station_id': 'station-ocak',
        },
        payload: <String, dynamic>{
          'document_type': 'kitchen',
          'station_id': 'station-ocak',
          'station_name': 'Ocak',
          'table_no': '12',
        },
      );

      expect(resolution.resolutionSource, 'station_mapping');
      expect(resolution.printer?.backend, DesktopPrinterBackend.tcp);
      expect(resolution.printer?.id, 'tcp:192.168.1.100:9100');
      expect(resolution.payload['printer_id'], 'tcp:192.168.1.100:9100');
      expect(resolution.payload['printer_backend'], 'tcp');
      expect(
        (resolution.payload['printer']
            as Map<String, dynamic>)['transportType'],
        'ethernet',
      );
      expect(
        (resolution.payload['printer'] as Map<String, dynamic>)['host'],
        '192.168.1.100',
      );
      expect(
        (resolution.payload['printer'] as Map<String, dynamic>)['port'],
        9100,
      );
    },
  );

  test(
    'resolvePrinterForRole does not fall back to working printer for mutfak when role mapping is missing',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-no-kitchen-fallback',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );

      final testResult = await orchestrator.printTestReceipt(
        restaurantId: 'rest-no-kitchen-fallback',
        role: PrinterSetupRole.adisyon,
        printerId: 'db-receipt',
      );
      expect(testResult.ok, isTrue);

      final resolved = await orchestrator.resolvePrinterForRole(
        restaurantId: 'rest-no-kitchen-fallback',
        role: PrinterSetupRole.mutfak,
      );
      expect(resolved, isNull);
    },
  );

  test(
    'savePrinterRoles persists ethernet role mapping metadata and kitchen print sends tcp payload',
    () async {
      final fakeRepo = _FakePrinterRepository();
      final fakeStation = _FakePrintStationService();
      final fakePrint = _FakeLocalPrintService(
        discoveredPrinters: <Map<String, dynamic>>[
          _usbPrinter('usb:receipt', 'POS58 USB', 'POS58_USB'),
        ],
      );
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: fakeRepo,
        printStationService: fakeStation,
        printServiceFactory: () => fakePrint,
      );

      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-ethernet-payload',
        printerId: 'db-receipt',
        name: 'POS58 USB',
        code: 'ADISYON_POS58_USB',
        connectionType: PrinterModel.usbConnectionType,
        deviceIdentifier: 'POS58_USB',
      );
      await fakeRepo.upsertPrinter(
        restaurantId: 'rest-ethernet-payload',
        printerId: 'db-kitchen-ethernet',
        name: '80mm new',
        code: 'MUTF_ETHERNET',
        connectionType: PrinterModel.networkConnectionType,
        ipAddress: '192.168.1.100',
        port: 9100,
        deviceIdentifier: 'tcp:192.168.1.100:9100',
        supportsCut: true,
      );

      final saveResult = await orchestrator.savePrinterRoles(
        restaurantId: 'rest-ethernet-payload',
        receiptPrinterId: 'db-receipt',
        kitchenPrinterId: 'db-kitchen-ethernet',
      );
      expect(saveResult.ok, isTrue);
      final reloadedSnapshot = await orchestrator.loadSetupSnapshot(
        restaurantId: 'rest-ethernet-payload',
        forceRefresh: true,
        minimal: true,
      );
      expect(
        reloadedSnapshot.localConfig?.kitchenSelection?.printer.id,
        'tcp:192.168.1.100:9100',
      );
      expect(
        reloadedSnapshot.localConfig?.kitchenSelection?.printer.backend,
        DesktopPrinterBackend.tcp,
      );

      final roleMappings =
          fakeStation.savedConfig?['role_mappings'] as Map<String, dynamic>;
      final kitchenRole = roleMappings['mutfak'] as Map<String, dynamic>;
      expect(kitchenRole['id'], 'tcp:192.168.1.100:9100');
      expect(kitchenRole['backend'], 'tcp');
      expect(kitchenRole['transportType'], 'ethernet');
      expect(kitchenRole['transport_type'], 'ethernet');
      expect(kitchenRole['host'], '192.168.1.100');
      expect(kitchenRole['ip_address'], '192.168.1.100');
      expect(kitchenRole['port'], 9100);
      expect(kitchenRole['printerRecordId'], 'db-kitchen-ethernet');

      final kitchenPrinter = await orchestrator.resolvePrinterForRole(
        restaurantId: 'rest-ethernet-payload',
        role: PrinterSetupRole.mutfak,
      );
      expect(kitchenPrinter?.backend, DesktopPrinterBackend.tcp);

      final printResult = await orchestrator.printPhysicalToPrinter(
        kitchenPrinter!,
        PrintPayload.fromQueuedJob(<String, dynamic>{
          'document_type': 'kitchen',
          'printer_role': 'mutfak',
          'table_no': '9',
          'items': const <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Kebap', 'quantity': 1},
          ],
        }),
        restaurantId: 'rest-ethernet-payload',
        flowName: 'kitchen_order',
        flowType: 'kitchen_order',
      );

      expect(printResult.ok, isTrue);
      expect(
        fakePrint.lastKitchenPayload?['printer_id'],
        'tcp:192.168.1.100:9100',
      );
      expect(fakePrint.lastKitchenPayload?['printer_backend'], 'tcp');
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['backend'],
        'tcp',
      );
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['transportType'],
        'ethernet',
      );
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['host'],
        '192.168.1.100',
      );
      expect(
        (fakePrint.lastKitchenPayload?['printer']
            as Map<String, dynamic>)['port'],
        9100,
      );
    },
  );

  test(
    'saveSingleRoleSelection writes remote mapping and preserves other role',
    () async {
      final printerRepo = _FakePrinterRepository();
      await printerRepo.upsertPrinter(
        restaurantId: 'rest-single',
        printerId: 'db-receipt',
        name: 'Receipt Printer',
        code: 'RCP',
        connectionType: PrinterModel.usbConnectionType,
        ipAddress: PrinterModel.localDefaultHost,
        port: PrinterModel.localDefaultPort,
        deviceIdentifier: 'RECEIPT_QUEUE',
        isActive: true,
      );
      await printerRepo.upsertPrinter(
        restaurantId: 'rest-single',
        printerId: 'db-kitchen',
        name: 'Kitchen Printer',
        code: 'KTC',
        connectionType: PrinterModel.localConnectionType,
        ipAddress: PrinterModel.localDefaultHost,
        port: PrinterModel.localDefaultPort,
        deviceIdentifier: 'KITCHEN_QUEUE',
        isActive: true,
      );

      final stationService = _FakePrintStationService();
      // Seed remote config with existing kitchen mapping.
      stationService.savedConfig = <String, dynamic>{
        'restaurant_id': 'rest-single',
        'kitchen_printer_id': 'db-kitchen',
        'kitchen_printer_name': 'Kitchen Printer',
        'print_system_enabled': true,
      };
      final orchestrator = DesktopPrintOrchestrator(
        printerRepository: printerRepo,
        printStationService: stationService,
        printServiceFactory: () =>
            _FakeLocalPrintService(discoveredPrinters: const []),
      );
      final result = await orchestrator.saveSingleRoleSelection(
        restaurantId: 'rest-single',
        role: PrinterSetupRole.adisyon,
        printerRecordId: 'db-receipt',
      );
      expect(result.ok, isTrue);

      // Remote should update only receipt, preserving kitchen.
      expect(stationService.savedConfig?['adisyon_printer_id'], 'db-receipt');
      expect(stationService.savedConfig?['kitchen_printer_id'], 'db-kitchen');
      // Role mappings payload should exist.
      expect(stationService.savedConfig?['role_mappings'], isNotNull);
    },
  );
}

Map<String, dynamic> _usbPrinter(
  String id,
  String name,
  String queue, {
  String vendorId = '0x1234',
  String productId = '0x5678',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'queue': queue,
    'backend': 'usb-direct',
    'vendorId': vendorId,
    'productId': productId,
    'statusLevel': 'ready',
    'ready': true,
    'statusMessage': 'Hazir',
  };
}

UnifiedPrinterModel _tcpKitchenPrinter() {
  return const UnifiedPrinterModel(
    id: 'tcp:192.168.1.100:9100',
    displayName: 'pos-80',
    queueName: 'pos-80',
    backend: DesktopPrinterBackend.tcp,
    os: DesktopPrinterOs.macos,
    isAvailable: true,
    canPrint: true,
    printerRecordId: 'db-kitchen',
    raw: <String, dynamic>{
      'id': 'tcp:192.168.1.100:9100',
      'name': 'pos-80',
      'backend': 'tcp',
      'transportType': 'ethernet',
      'transport_type': 'ethernet',
      'host': '192.168.1.100',
      'ip_address': '192.168.1.100',
      'port': 9100,
      'paper_width_mm': 80,
      'auto_cut': true,
    },
  );
}

UnifiedPrinterModel _cupsKitchenPrinter() {
  return const UnifiedPrinterModel(
    id: 'cups:kitchen',
    displayName: 'Kitchen CUPS',
    queueName: 'Kitchen_Queue',
    backend: DesktopPrinterBackend.cups,
    os: DesktopPrinterOs.macos,
    isAvailable: true,
    canPrint: true,
    printerRecordId: 'db-kitchen-cups',
    raw: <String, dynamic>{
      'id': 'cups:kitchen',
      'name': 'Kitchen CUPS',
      'queue': 'Kitchen_Queue',
      'backend': 'cups',
    },
  );
}

UnifiedPrinterModel _usbKitchenPrinter() {
  return const UnifiedPrinterModel(
    id: 'usb:kitchen',
    displayName: 'Kitchen USB',
    queueName: 'Kitchen_USB',
    backend: DesktopPrinterBackend.usbDirect,
    os: DesktopPrinterOs.macos,
    isAvailable: true,
    canPrint: true,
    printerRecordId: 'db-kitchen-usb',
    vendorId: '0x1111',
    productId: '0x2222',
    raw: <String, dynamic>{
      'id': 'usb:kitchen',
      'name': 'Kitchen USB',
      'queue': 'Kitchen_USB',
      'backend': 'usb-direct',
      'deviceIdentifier': 'usb-1111:2222',
      'device_identifier': 'usb-1111:2222',
      'vendorId': '0x1111',
      'productId': '0x2222',
    },
  );
}

Map<String, dynamic> _cupsPrinter(String id, String name, String queue) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'queue': queue,
    'backend': 'cups',
    'statusLevel': 'ready',
    'ready': true,
    'statusMessage': 'Hazir',
  };
}

class _FakePrinterRepository implements PrinterRepositoryPort {
  _FakePrinterRepository({this.upsertShouldThrow = false});

  final bool upsertShouldThrow;
  final List<PrinterModel> _printers = <PrinterModel>[];
  final List<StationPrinterModel> stationMappings = <StationPrinterModel>[];
  final Map<String, List<PrinterRole>> lastAssignedRoles =
      <String, List<PrinterRole>>{};
  int fetchPrintersCallCount = 0;

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async {
    fetchPrintersCallCount += 1;
    return List<PrinterModel>.from(_printers);
  }

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async {
    for (final printer in _printers) {
      if (printer.id == printerId) {
        return printer;
      }
    }
    return null;
  }

  @override
  Future<List<dynamic>> fetchStationPrinterMappings(String restaurantId) async {
    return List<dynamic>.from(stationMappings);
  }

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async {
    return fetchPrinterById(recordId);
  }

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {
    final index = _printers.indexWhere((printer) => printer.id == printerId);
    if (index < 0) return;
    _printers[index] = _printers[index].copyWith(
      testPrintStatus: success ? 'ok' : 'failed',
      lastError: error,
      lastTestPrintAt: DateTime.now(),
    );
  }

  @override
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async {
    return null;
  }

  @override
  Future<void> updateAssignedRoles(
    String printerId,
    List<PrinterRole> roles,
  ) async {
    final index = _printers.indexWhere((printer) => printer.id == printerId);
    if (index < 0) return;
    _printers[index] = _printers[index].copyWith(assignedRoles: roles);
    lastAssignedRoles[printerId] = roles;
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
    if (upsertShouldThrow) {
      throw Exception('printer_sync_failed');
    }
    final model = PrinterModel(
      id: printerId ?? code.toLowerCase(),
      restaurantId: restaurantId,
      name: name,
      code: code,
      connectionType: connectionType,
      ipAddress: ipAddress,
      port: port,
      deviceIdentifier: deviceIdentifier,
      paperWidthMm: paperWidthMm,
      isActive: isActive,
      createdAt: DateTime.now(),
      supportsCut: supportsCut,
      charset: charset,
      codePage: codePage,
      assignedRoles: assignedRoles,
      printerProfileId: printerProfileId,
    );
    final index = _printers.indexWhere((printer) => printer.id == model.id);
    if (index >= 0) {
      _printers[index] = model;
    } else {
      _printers.add(model);
    }
    lastAssignedRoles[model.id] = assignedRoles;
    return model;
  }

  @override
  Future<void> deletePrinter(String printerId) async {
    _printers.removeWhere((printer) => printer.id == printerId);
  }

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {
    _printers.clear();
  }

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {
    stationMappings.removeWhere((mapping) => mapping.printerId == printerId);
  }

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(
    String restaurantId,
  ) async {
    stationMappings.clear();
  }
}

class _FakePrintStationService implements PrintStationServicePort {
  _FakePrintStationService({
    this.saveShouldThrow = false,
    this.localQueueStatus,
  });

  final bool saveShouldThrow;
  final Map<String, dynamic>? localQueueStatus;
  bool printStation = false;
  Map<String, dynamic>? savedConfig;
  String? roleMappingCacheToken;

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
  Future<Map<String, dynamic>?> fetchLocalQueueStatus() async {
    return localQueueStatus ?? <String, dynamic>{'ok': true};
  }

  @override
  Future<String?> readRoleMappingCacheToken(String restaurantId) async {
    return roleMappingCacheToken;
  }

  @override
  Future<Map<String, dynamic>?> fetchStationConfig(String restaurantId) async {
    return savedConfig;
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
    savedConfig = <String, dynamic>{
      ...(savedConfig ?? <String, dynamic>{'restaurant_id': restaurantId}),
      'print_system_enabled': enabled,
    };
    return true;
  }

  @override
  Future<bool> resumePausedPrintJob({
    required String restaurantId,
    required String jobId,
  }) async {
    return true;
  }

  @override
  Future<bool> isThisDevicePrintStation() async => printStation;

  @override
  bool isStationOnline(Map<String, dynamic>? config) => false;

  @override
  bool isLocalStationReady(Map<String, dynamic>? queueStatus) => true;

  @override
  String normalizeStationPlatform(String? value) => 'macos';

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
    if (saveShouldThrow) {
      throw Exception('offline');
    }
    savedConfig = <String, dynamic>{
      'restaurant_id': restaurantId,
      'adisyon_printer_id': receiptPrinterId,
      'kitchen_printer_id': kitchenPrinterId,
      'role_mappings': roleMappings,
      'updated_at': DateTime.now().toIso8601String(),
    };
    return savedConfig;
  }

  @override
  Future<Map<String, dynamic>?> patchStationConfiguration({
    required String restaurantId,
    required Map<String, dynamic> fields,
  }) async {
    savedConfig = <String, dynamic>{
      ...(savedConfig ?? <String, dynamic>{'restaurant_id': restaurantId}),
      ...fields,
    };
    return savedConfig;
  }

  @override
  Future<String> invalidateRoleMappingCacheState({
    required String restaurantId,
    Map<String, dynamic>? roleMappings,
    String source = 'print_station_service',
  }) async {
    roleMappingCacheToken =
        '$restaurantId:${roleMappings?.length ?? 0}:$source:${DateTime.now().microsecondsSinceEpoch}';
    return roleMappingCacheToken!;
  }

  @override
  Future<void> setThisDevicePrintStation(bool value) async {
    printStation = value;
  }
}

class _FakeLocalPrintService extends LocalPrintService {
  _FakeLocalPrintService({
    this.discoveredPrinters = const <Map<String, dynamic>>[],
    this.healthPayload,
    this.setupStatusPayload,
    this.queueStatusPayload,
    this.printTestResponses,
    this.receiptResponse,
    this.kitchenResponse,
    this.receiptResponses,
  });

  final List<Map<String, dynamic>> discoveredPrinters;
  final Map<String, dynamic>? healthPayload;
  final Map<String, dynamic>? setupStatusPayload;
  final Map<String, dynamic>? queueStatusPayload;
  final List<Object>? printTestResponses;
  final Map<String, dynamic>? receiptResponse;
  final Map<String, dynamic>? kitchenResponse;
  final List<Object>? receiptResponses;
  String? lastPrintTestPrinterId;
  String? lastPrintTestPrinterName;
  Map<String, dynamic>? lastPrintTestPrinter;
  Map<String, dynamic>? lastPrintTestExtraBody;
  String? lastPrintTestTargetHost;
  int? lastPrintTestTargetPort;
  Map<String, dynamic>? lastReceiptPayload;
  Map<String, dynamic>? lastKitchenPayload;
  int releaseUsbPrintersCallCount = 0;
  int printTestCallCount = 0;
  int printReceiptCallCount = 0;

  @override
  Future<LocalPrintHealthStatus> checkAvailability({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    return LocalPrintHealthStatus(
      isAvailable: true,
      reason: 'ok',
      url: Uri.parse('http://127.0.0.1:3001/health'),
      durationMs: 1,
      statusCode: 200,
    );
  }

  @override
  Future<Map<String, dynamic>?> health({bool useCache = true}) async {
    return healthPayload ??
        <String, dynamic>{
          'ok': true,
          'printer': <String, dynamic>{'ok': true},
        };
  }

  @override
  Future<Map<String, dynamic>?> setupStatus() async {
    return setupStatusPayload ??
        <String, dynamic>{
          'status': 'ready',
          'health': <String, dynamic>{
            'ok': true,
            'printer': <String, dynamic>{'ok': true},
          },
        };
  }

  @override
  Future<Map<String, dynamic>?> setupPrerequisites() async {
    return <String, dynamic>{
      'dependencies': <String, dynamic>{'cups': 'available'},
    };
  }

  @override
  Future<Map<String, dynamic>?> printers({bool useCache = true}) async {
    return <String, dynamic>{'printers': discoveredPrinters};
  }

  @override
  Future<Map<String, dynamic>?> discover() async {
    return <String, dynamic>{'printers': discoveredPrinters};
  }

  @override
  Future<Map<String, dynamic>?> queueStatus() async {
    return queueStatusPayload ??
        <String, dynamic>{
          'ok': true,
          'queue': <String, dynamic>{'print_system_enabled': true},
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
    printTestCallCount += 1;
    lastPrintTestPrinterId = printerId;
    lastPrintTestPrinterName = printerName;
    lastPrintTestTargetHost = targetHost;
    lastPrintTestTargetPort = targetPort;
    lastPrintTestPrinter = printer == null
        ? null
        : Map<String, dynamic>.from(printer);
    lastPrintTestExtraBody = extraBody == null
        ? null
        : Map<String, dynamic>.from(extraBody);
    if (printTestResponses != null && printTestResponses!.isNotEmpty) {
      final next = printTestResponses!.removeAt(0);
      if (next is Exception) {
        throw next;
      }
      if (next is Error) {
        throw next;
      }
      return Map<String, dynamic>.from(next as Map);
    }
    Map<String, dynamic>? matchedPrinter;
    if (printerId != null && printerId.isNotEmpty) {
      for (final printer in discoveredPrinters) {
        if (printer['id']?.toString() == printerId) {
          matchedPrinter = Map<String, dynamic>.from(printer);
          break;
        }
      }
    }
    matchedPrinter ??= discoveredPrinters.isEmpty
        ? null
        : Map<String, dynamic>.from(discoveredPrinters.first);
    return <String, dynamic>{
      'ok': true,
      'printer_id': printerId ?? matchedPrinter?['id'],
      'printer': lastPrintTestPrinter ?? matchedPrinter,
      'transport_output': 'USB direct',
    };
  }

  @override
  Future<Map<String, dynamic>?> printReceipt(
    Map<String, dynamic> payload,
  ) async {
    printReceiptCallCount += 1;
    lastReceiptPayload = Map<String, dynamic>.from(payload);
    if (receiptResponses != null && receiptResponses!.isNotEmpty) {
      final next = receiptResponses!.removeAt(0);
      if (next is Exception) {
        throw next;
      }
      if (next is Error) {
        throw next;
      }
      return Map<String, dynamic>.from(next as Map);
    }
    return receiptResponse ??
        <String, dynamic>{'ok': true, 'transport_output': 'USB direct'};
  }

  @override
  Future<Map<String, dynamic>?> printKitchen(
    Map<String, dynamic> payload, {
    String path = '/print/kitchen',
  }) async {
    lastKitchenPayload = Map<String, dynamic>.from(payload);
    return kitchenResponse ??
        <String, dynamic>{'ok': true, 'transport_output': 'USB direct'};
  }

  @override
  Future<Map<String, dynamic>?> releaseUsbPrinters() async {
    releaseUsbPrintersCallCount += 1;
    return <String, dynamic>{'ok': true, 'released': true};
  }
}

class _ThrowingPrinterEventLogService extends PrinterEventLogService {
  @override
  Future<void> appendRuntime({
    required String restaurantId,
    required String event,
    required String flowName,
    required String source,
    String? role,
    String? documentType,
    String? bridgePrinterId,
    String? printerRecordId,
    String? printerName,
    String? backend,
    String? transport,
    String? queue,
    String? deviceIdentifier,
    String? storeId,
    String? tableId,
    String? printJobId,
    bool usedFallback = false,
    String? fallbackReason,
    String? errorMessage,
    String level = 'info',
    Map<String, dynamic>? details,
  }) async {
    throw Exception('runtime_log_failed');
  }
}

class _FakeMacosUsbPermissionRecoveryService
    extends MacosUsbPermissionRecoveryService {
  _FakeMacosUsbPermissionRecoveryService({
    List<AdminCupsReleaseResult>? releaseResults,
    List<bool>? retryDecisions,
  }) : _releaseResults = releaseResults ?? const <AdminCupsReleaseResult>[],
       _retryDecisions = retryDecisions ?? const <bool>[];

  int requestCount = 0;
  int releaseCount = 0;
  int instructionsCount = 0;
  int retryPromptCount = 0;
  final List<AdminCupsReleaseResult> _releaseResults;
  final List<bool> _retryDecisions;

  @override
  Future<bool> requestAdminUsbRelease({
    required bool hasConflictWarning,
  }) async {
    requestCount += 1;
    return true;
  }

  @override
  Future<AdminCupsReleaseResult> runAdminUsbRelease() async {
    releaseCount += 1;
    if (_releaseResults.isNotEmpty) {
      final index = releaseCount - 1;
      if (index < _releaseResults.length) {
        return _releaseResults[index];
      }
      return _releaseResults.last;
    }
    return const AdminCupsReleaseResult(
      ok: true,
      message: 'CUPS yeniden başlatıldı.',
    );
  }

  @override
  Future<bool> requestRetryAfterAdminCancelled({
    required bool hasConflictWarning,
  }) async {
    retryPromptCount += 1;
    final index = retryPromptCount - 1;
    if (index < _retryDecisions.length) {
      return _retryDecisions[index];
    }
    return true;
  }

  @override
  Future<void> showPostReleaseFailureInstructions({
    required bool hasConflictWarning,
  }) async {
    instructionsCount += 1;
  }
}
