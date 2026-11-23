import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:ibul_app/services/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('zaman aşımı bulut-erişilemez sayılır, böylece son iyi kayıt kullanılır', () {
    expect(
      PrinterRepository.isCloudUnreachableError(
        TimeoutException('x', PrinterRepository.cloudReadTimeout),
      ),
      isTrue,
    );
  });

  test('bulut okuma bütçesi kısa (adisyon internetsizde takılmaz)', () {
    expect(PrinterRepository.cloudReadTimeout.inSeconds, lessThanOrEqualTo(5));
  });

  // Bahçe 4, 2026-11-23: with the internet gone the single-printer read
  // neither answered nor failed, and the kitchen ticket of an order already
  // saved locally waited on it for close to a minute.
  test('yanıt vermeyen tek-yazıcı okuması süre dolunca son iyi kayda düşer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrinterRepository.lastGoodRowsKey('printers', 'r1'): jsonEncode(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'restaurant_id': 'r1',
            'name': 'aa',
            'ip_address': '192.168.10.100',
            'port': 9100,
          },
        ],
      ),
    });
    final watch = Stopwatch()..start();
    final printer = await PrinterRepository.printerByIdFrom(
      printerId: 'p1',
      read: () => Completer<dynamic>().future,
      timeout: const Duration(milliseconds: 80),
    );
    expect(watch.elapsedMilliseconds, lessThan(1500));
    expect(printer, isNotNull);
    expect(printer!.name, 'aa');
  });

  test('bulut "yok" derse son iyi kayıt uydurulmaz', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(
      await PrinterRepository.printerByIdFrom(
        printerId: 'p1',
        read: () async => null,
      ),
      isNull,
    );
  });
}
