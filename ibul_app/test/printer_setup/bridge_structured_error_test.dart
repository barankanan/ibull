import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/bridge_error_dialog.dart';

void main() {
  test('BridgeStructuredError.tryParse null when missing errorCode', () {
    expect(BridgeStructuredError.tryParse(null), isNull);
    expect(BridgeStructuredError.tryParse(const <String, dynamic>{}), isNull);
    expect(
      BridgeStructuredError.tryParse(const <String, dynamic>{'message': 'x'}),
      isNull,
    );
  });

  test('BridgeStructuredError.tryParse normalizes fields + canClearQueue', () {
    final parsed = BridgeStructuredError.tryParse(const <String, dynamic>{
      'errorCode': 'cups_queue_stuck',
      'error': 'Queue stuck',
      'suggested_action': 'clear_queue',
      'active_job_ids': ['12', '34'],
      'queue_status': 'stuck',
      'queue_message': 'Paused',
      'lp_command': 'lpstat -o',
      'lp_output': '...',
    });

    expect(parsed, isNotNull);
    expect(parsed!.errorCode, 'cups_queue_stuck');
    expect(parsed.message, 'Queue stuck');
    expect(parsed.suggestedAction, 'clear_queue');
    expect(parsed.canClearQueue, isTrue);
    expect(parsed.activeJobIds, ['12', '34']);
    expect(parsed.queueStatus, 'stuck');
    expect(parsed.queueMessage, 'Paused');
  });
}

