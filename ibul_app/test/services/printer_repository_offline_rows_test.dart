import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final refused = Exception(
    'ClientException with SocketException: Connection refused (errno = 61)',
  );

  test('the last successful rows come back only when the cloud is unreachable', () async {
    await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'p1', 'ip_address': '127.0.0.1', 'port': 19100},
    ]);
    final rows = await PrinterRepository.lastGoodRowsWhenUnreachable(
      'printers',
      'rest-1',
      refused,
    );
    expect(rows!.single['id'], 'p1');
  });

  test('a server answer such as a denial is never replaced by old rows', () async {
    await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'p1'},
    ]);
    expect(
      await PrinterRepository.lastGoodRowsWhenUnreachable(
        'printers',
        'rest-1',
        const PostgrestException(message: 'permission denied', code: '42501'),
      ),
      isNull,
    );
    expect(PrinterRepository.isCloudUnreachableError(StateError('bad state')), isFalse);
  });

  test('rows are kept per restaurant and per kind', () async {
    await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'p1'},
    ]);
    expect(
      await PrinterRepository.lastGoodRowsWhenUnreachable('printers', 'rest-2', refused),
      isNull,
    );
    expect(
      await PrinterRepository.lastGoodRowsWhenUnreachable('station_printers', 'rest-1', refused),
      isNull,
    );
  });
}
