import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/print_job_payload_identity.dart';

const _printer = '3f2b6c1e-8a4d-4e0b-9c1a-5d7e2f9a1b23';
const _other = '9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c5d';

void main() {
  group('payloadForUnboundPrinterJob', () {
    test('a saved printer id leaves the reserved key and stays as record id', () {
      final out = payloadForUnboundPrinterJob({'printer_id': _printer, 'x': 1});
      expect(out.containsKey('printer_id'), isFalse);
      expect(out['printer_record_id'], _printer);
      expect(out['x'], 1);
    });

    test('a local queue id is kept apart, never as printer_id', () {
      final out = payloadForUnboundPrinterJob({'printer_id': 'cups:POS80'});
      expect(out.containsKey('printer_id'), isFalse);
      expect(out.containsKey('printer_record_id'), isFalse);
      expect(out['bridge_printer_id'], 'cups:POS80');
    });

    test('an existing record id wins and the input is not mutated', () {
      final input = {'printer_id': _other, 'printer_record_id': _printer};
      final out = payloadForUnboundPrinterJob(input);
      expect(out['printer_record_id'], _printer);
      expect(input['printer_id'], _other);
    });

    test('a payload without a printer is unchanged', () {
      expect(payloadForUnboundPrinterJob({'a': 'b'}), {'a': 'b'});
    });
  });

  group('printJobIdentityUpdate', () {
    test('null payload writes nothing', () {
      expect(printJobIdentityUpdate(null), isEmpty);
    });

    test('column and payload carry the same saved printer id', () {
      final out = printJobIdentityUpdate({'printer_id': _printer});
      expect(out['printer_id'], _printer);
      expect((out['payload'] as Map)['printer_id'], _printer);
      expect((out['payload'] as Map)['printer_record_id'], _printer);
    });

    test('the record id is canonical when the two disagree', () {
      final out = printJobIdentityUpdate({
        'printer_id': 'tcp:192.168.10.100:9100',
        'printer_record_id': _printer,
      });
      final payload = out['payload'] as Map;
      expect(out['printer_id'], _printer);
      expect(payload['printer_id'], _printer);
      expect(payload['bridge_printer_id'], 'tcp:192.168.10.100:9100');
    });

    test('without a saved printer the column is left alone', () {
      final out = printJobIdentityUpdate({'printer_id': 'cups:POS80'});
      expect(out.containsKey('printer_id'), isFalse);
      final payload = out['payload'] as Map;
      expect(payload.containsKey('printer_id'), isFalse);
      expect(payload['bridge_printer_id'], 'cups:POS80');
    });
  });
}
