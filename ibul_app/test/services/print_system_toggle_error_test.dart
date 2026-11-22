import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:ibul_app/services/print_station_service.dart';

void main() {
  const down = LocalPrintServiceException(
    'Yazici servisine baglanilamadi.',
    details: 'ClientException: Connection refused, uri=http://127.0.0.1:3001/configure/print-station',
    errorCode: 'bridge_unreachable',
  );

  test('a bridge that does not answer is named, without the raw socket text', () {
    final text = printSystemToggleErrorMessage(
      down,
      printStartDisabled: false,
      bridgeUri: Uri.parse('http://127.0.0.1:3001'),
    );
    expect(text, contains('Yazıcı köprüsü çalışmıyor (127.0.0.1:3001)'));
    expect(text, contains('değiştirilmedi'));
    expect(text, isNot(contains('Connection refused')));
    expect(text, isNot(contains('ClientException')));
  });

  test('a build with printing switched off says so', () {
    final text = printSystemToggleErrorMessage(down, printStartDisabled: true);
    expect(text, startsWith(AppRuntimeConfig.printStartDisabledMessage));
  });

  test('other failures keep their own message', () {
    expect(
      printSystemToggleErrorMessage(Exception('Bulut ayarı güncellenemedi.')),
      'Bulut ayarı güncellenemedi.',
    );
    expect(printSystemToggleErrorMessage(Exception('')), 'Baskı sistemi güncellenemedi.');
  });
}
