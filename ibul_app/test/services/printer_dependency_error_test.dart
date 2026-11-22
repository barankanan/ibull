import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

void main() {
  test('a missing bridge dependency is not shown as a dead bridge', () {
    final shown = presentPrinterErrorCode('dependency_missing');
    expect(shown.code, 'dependency_missing');
    expect(shown.title, contains('bileşen eksik'));
    expect(shown.message, contains('Pillow'));
    // The bridge is alive and the printer link is fine; saying otherwise is
    // exactly the confusion this code exists to remove.
    expect(shown.title, isNot(contains('çalışmıyor')));
    expect(shown.message, contains('bağlantı sorun değil'));
    expect(shown.canRetry, isFalse);
  });

  test('render failures are named, not "unexpected error"', () {
    for (final code in <String>['render_failed', 'kitchen_render_failed']) {
      final shown = presentPrinterErrorCode(code);
      expect(shown.title, 'Fiş hazırlanamadı', reason: code);
      expect(shown.message, isNot(contains('Beklenmeyen')), reason: code);
    }
  });

  test('a real bridge outage still reads as an outage', () {
    final shown = presentPrinterErrorCode('bridge_unreachable');
    expect(shown.title, 'Yazıcı servisi çalışmıyor');
  });
}
