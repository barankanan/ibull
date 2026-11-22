import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/print_job_model.dart';
import 'package:ibul_app/services/printer_link_status.dart';

PrintJobModel _job(String status, String? error) => PrintJobModel.fromMap({
  'id': 'j1',
  'restaurant_id': 'r1',
  'job_type': 'new_order',
  'status': status,
  'last_error': error,
  'payload': <String, dynamic>{},
  'created_at': '2026-11-13T03:50:24Z',
});

void main() {
  test('a bridge timeout is uncertain, not a proven failure', () {
    final job = _job(
      'failed',
      'PRINT_OUTCOME_UNKNOWN: Yazıcı servisi yanıt vermedi.\nKod: client_timeout\nZaman aşımı: 4000 ms',
    );
    expect(job.operatorQueueBucket, 'uncertain');
  });

  test('a refused print stays a failure', () {
    final job = _job('failed', 'Baskı sistemi kapalı.');
    expect(job.operatorQueueBucket, 'failed');
    expect(_job('failed', null).operatorQueueBucket, 'failed');
  });

  test('the service permission is read from a healthy bridge answer', () {
    expect(
      printSystemEnabledFromHealth({
        'ok': true,
        'print_station': {'enabled': false, 'print_system_enabled': true},
      }),
      isTrue,
    );
    expect(
      printSystemEnabledFromHealth({
        'ok': true,
        'print_station': {'print_system_enabled': false},
      }),
      isFalse,
    );
    // No body at all is the only "unknown".
    expect(printSystemEnabledFromHealth(null), isNull);
  });
}
