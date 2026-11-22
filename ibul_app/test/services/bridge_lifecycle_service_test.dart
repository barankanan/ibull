import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/screens/seller/printer_test_dialog.dart';
import 'package:ibul_app/services/bridge_lifecycle_service.dart';

Future<List<BridgeStatus>> _run(BridgeLifecycleService service) =>
    service.ensureRunning().toList();

UnifiedPrinterModel _printer(String id, DesktopPrinterBackend backend, {String? record}) =>
    UnifiedPrinterModel(
      id: id,
      displayName: id,
      queueName: id,
      backend: backend,
      os: DesktopPrinterOs.macos,
      isAvailable: true,
      canPrint: true,
      statusLevel: 'ready',
      statusMessage: 'ok',
      printerRecordId: record,
      raw: <String, dynamic>{'id': id},
    );

void main() {
  group('BridgeLifecycleService', () {
    test('an isolated build never starts a LaunchAgent, even when the bridge is down', () async {
      var started = 0;
      final service = BridgeLifecycleService(
        bridgeUri: Uri.parse('http://127.0.0.1:18771'),
        client: MockClient((_) async => http.Response('', 503)),
        isolatedDesktop: true,
        startAgent: () async => started++,
      );
      final statuses = await _run(service);
      expect(started, 0);
      expect(statuses.last, BridgeStatus.unavailable);
      expect(statuses, isNot(contains(BridgeStatus.starting)));
    });

    test('an isolated build reports ready from its own bridge address', () async {
      final seen = <Uri>[];
      final service = BridgeLifecycleService(
        bridgeUri: Uri.parse('http://127.0.0.1:18771'),
        client: MockClient((request) async {
          seen.add(request.url);
          return http.Response('{"ok":true}', 200);
        }),
        isolatedDesktop: true,
      );
      expect(await _run(service), contains(BridgeStatus.ready));
      expect(seen.single.port, 18771);
      expect(seen.single.path, '/health');
    });

    test('a normal build still tries to start its own agent when the bridge is down', () async {
      var started = 0;
      final service = BridgeLifecycleService(
        bridgeUri: Uri.parse('http://127.0.0.1:3001'),
        client: MockClient((_) async => http.Response('', 503)),
        isolatedDesktop: false,
        startAgent: () async => started++,
      );
      await _run(service);
      expect(started, 1);
    });
  });

  group('firstSavedTestPrinter', () {
    test('a saved Ethernet printer outranks a bridge-discovered USB device', () {
      final usb = _printer('usb:1', DesktopPrinterBackend.usbDirect);
      final saved = _printer('tcp:192.168.10.100:9100', DesktopPrinterBackend.tcp, record: 'rec-1');
      expect(firstSavedTestPrinter(<UnifiedPrinterModel>[usb, saved]), same(saved));
    });

    test('only discovered devices means no saved target', () {
      final usb = _printer('usb:1', DesktopPrinterBackend.usbDirect);
      final cups = _printer('cups:1', DesktopPrinterBackend.cups, record: '  ');
      expect(firstSavedTestPrinter(<UnifiedPrinterModel>[usb, cups]), isNull);
      expect(firstSavedTestPrinter(const <UnifiedPrinterModel>[]), isNull);
    });
  });
}
