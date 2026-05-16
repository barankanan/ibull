import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';

void main() {
  test('buildBridgeOperatorSetupStatus marks ready when bridge is healthy', () {
    final status = buildBridgeOperatorSetupStatus(
      bridgeReachable: true,
      bridgeHealthy: true,
      livePrinterCount: 6,
      bridgeHealth: const <String, dynamic>{'ok': true},
    );

    expect(status['status'], 'ready');
    expect(status['ok'], isTrue);
    expect(status['livePrinterCount'], 6);
    expect(status['message'], contains('6 yazıcı'));
  });

  test('buildBridgeOperatorSetupStatus marks bridge_not_running when unreachable', () {
    final status = buildBridgeOperatorSetupStatus(
      bridgeReachable: false,
      bridgeHealthy: false,
      livePrinterCount: 0,
    );

    expect(status['status'], 'bridge_not_running');
    expect(status['ok'], isFalse);
  });

  test('PrinterSetupSnapshot live vs stale splits saved_record printers', () {
    const snapshot = PrinterSetupSnapshot(
      os: DesktopPrinterOs.windows,
      bridgeReachable: true,
      bridgeHealthy: true,
      printers: <UnifiedPrinterModel>[
        UnifiedPrinterModel(
          id: 'windows:POS-80',
          displayName: 'POS-80',
          queueName: 'POS-80',
          backend: DesktopPrinterBackend.windowsSpool,
          os: DesktopPrinterOs.windows,
          isAvailable: true,
          canPrint: true,
          raw: <String, dynamic>{'source': 'usb_scan'},
        ),
        UnifiedPrinterModel(
          id: 'saved-mac-1',
          displayName: 'STMicroelectronics_POS58_Printer_USB',
          queueName: 'STMicroelectronics_POS58_Printer_USB',
          backend: DesktopPrinterBackend.windowsSpool,
          os: DesktopPrinterOs.windows,
          isAvailable: false,
          canPrint: false,
          raw: <String, dynamic>{'source': 'saved_record'},
        ),
      ],
      steps: <PrinterSetupStepStatus>[],
    );

    expect(snapshot.livePrinterCount, 1);
    expect(snapshot.stalePrinters.length, 1);
    expect(snapshot.livePrinters.first.id, 'windows:POS-80');
    expect(snapshot.operatorSetupStatusKey, 'ready');
  });
}
