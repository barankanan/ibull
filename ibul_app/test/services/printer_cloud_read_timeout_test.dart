import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_repository.dart';

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
}
