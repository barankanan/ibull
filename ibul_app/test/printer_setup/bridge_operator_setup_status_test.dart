import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';

void main() {
  test('queue pending with live printers is not bridge_not_running', () {
    final key = bridgeOperatorSetupStatusKey(
      bridgeReachable: true,
      bridgeHealthy: false,
      livePrinterCount: 1,
      bridgeHealth: <String, dynamic>{
        'ok': true,
        'printer_queue': '',
        'default_queue': '',
        'printer': <String, dynamic>{
          'ok': false,
          'queue_pending': true,
        },
      },
    );
    expect(key, 'printer_selection_pending');
    expect(
      bridgeOperatorSetupMessage(
        bridgeReachable: true,
        bridgeHealthy: false,
        livePrinterCount: 1,
        bridgeHealth: <String, dynamic>{
          'ok': true,
          'printer_queue': '',
          'printer': <String, dynamic>{'ok': false, 'queue_pending': true},
        },
      ),
      contains('yazıcı seçimi bekleniyor'),
    );
  });

  test('unreachable bridge stays bridge_not_running', () {
    final key = bridgeOperatorSetupStatusKey(
      bridgeReachable: false,
      bridgeHealthy: false,
      livePrinterCount: 1,
      bridgeHealth: <String, dynamic>{'ok': true},
    );
    expect(key, 'bridge_not_running');
  });
}
