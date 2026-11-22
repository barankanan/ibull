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

  group('a registered printer is not lost to a cloud hiccup', () {
    final saved = <Map<String, dynamic>>[
      <String, dynamic>{'id': 'p1', 'ip_address': '192.168.10.100', 'port': 9100},
    ];

    test('an empty answer without a live session keeps the last good rows', () async {
      await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', saved);
      // Signed-out / expired session: the server filters every row away and
      // answers "[]" with success.
      await PrinterRepository.rememberLastGoodRows(
        'printers',
        'rest-1',
        const <Object>[],
        emptyIsAuthoritative: false,
      );
      final rows = await PrinterRepository.lastGoodRowsWhenUnreachable(
        'printers',
        'rest-1',
        refused,
      );
      expect(rows!.single['id'], 'p1');
    });

    test('an empty answer from a signed-in session is believed', () async {
      await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', saved);
      await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', const <Object>[]);
      final rows = await PrinterRepository.lastGoodRowsWhenUnreachable(
        'printers',
        'rest-1',
        refused,
      );
      expect(rows, isEmpty);
    });

    test('a newer non-empty answer always replaces the copy', () async {
      await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', saved);
      await PrinterRepository.rememberLastGoodRows(
        'printers',
        'rest-1',
        <Map<String, dynamic>>[
          <String, dynamic>{'id': 'p2'},
        ],
        emptyIsAuthoritative: false,
      );
      final rows = await PrinterRepository.lastGoodRowsWhenUnreachable(
        'printers',
        'rest-1',
        refused,
      );
      expect(rows!.single['id'], 'p2');
    });

    test('a gateway failure of the cloud counts as unreachable', () async {
      await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', saved);
      for (final outage in const <PostgrestException>[
        PostgrestException(message: 'Bad Gateway', code: '502'),
        PostgrestException(message: 'Service Unavailable', code: '503'),
        PostgrestException(message: 'upstream request timeout', code: '504'),
      ]) {
        final rows = await PrinterRepository.lastGoodRowsWhenUnreachable(
          'printers',
          'rest-1',
          outage,
        );
        expect(rows!.single['id'], 'p1', reason: outage.message);
      }
    });

    test('refusals and bad requests are still not papered over', () {
      for (final answer in const <PostgrestException>[
        PostgrestException(message: 'permission denied', code: '42501'),
        PostgrestException(message: 'JWT expired', code: 'PGRST301'),
        PostgrestException(message: 'Bad Request', code: '400'),
        PostgrestException(message: 'Not Found', code: '404'),
      ]) {
        expect(
          PrinterRepository.isCloudUnreachableError(answer),
          isFalse,
          reason: answer.message,
        );
      }
    });

    test('the saved rows survive an app restart and an update', () async {
      await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', saved);
      await PrinterRepository.rememberLastGoodRows('stations', 'rest-1', <Map<String, dynamic>>[
        <String, dynamic>{'id': 's1', 'name': 'Ocak'},
      ]);
      // A new process (restart, reboot or a newer build with the same bundle
      // id) reads the same preferences file; nothing is keyed by app version.
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(
        prefs.getKeys(),
        containsAll(<String>[
          PrinterRepository.lastGoodRowsKey('printers', 'rest-1'),
          PrinterRepository.lastGoodRowsKey('stations', 'rest-1'),
        ]),
      );
      expect(
        prefs.getKeys().every((key) => !RegExp(r'\d+\.\d+\.\d+').hasMatch(key)),
        isTrue,
      );
    });
  });
}
