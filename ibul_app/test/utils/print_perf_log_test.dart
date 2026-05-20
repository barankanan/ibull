import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/print_perf_log.dart';

void main() {
  test('logPrintPerf emits single-line JSON with required keys', () {
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = originalDebugPrint;
    });

    logPrintPerf(
      'receipt_test',
      <String, Object?>{
        'tap_at': '2026-05-20T10:00:00.000',
        'total_ms': 420,
        'bridge_request_ms': 120,
      },
    );

    expect(messages, hasLength(1));
    expect(messages.single, '[PrintPerf][receipt_test] {"tap_at":"2026-05-20T10:00:00.000","total_ms":420,"bridge_request_ms":120}');
  });
}
