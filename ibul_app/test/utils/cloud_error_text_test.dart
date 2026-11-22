import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/cloud_error_text.dart';

void main() {
  test('a network failure is one calm sentence without the raw socket text', () {
    for (final error in <Object>[
      'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 61), address = 127.0.0.1, port = 64549, uri=http://127.0.0.1:54321/rest/v1/table_orders',
      TimeoutException('Bulut erişilemiyor. Son doğrulanmış ekran korunuyor.'),
      Exception('Failed host lookup: example.supabase.co'),
    ]) {
      final text = cloudErrorTextForOperator(error);
      expect(text, cloudUnreachableOperatorText);
      expect(text, isNot(contains('uri=')));
      expect(text, isNot(contains('Timeout')));
    }
  });

  test('other errors keep their message, without the exception prefix', () {
    expect(
      cloudErrorTextForOperator(Exception('Bu masada işlem yetkiniz yok.')),
      'Bu masada işlem yetkiniz yok.',
    );
    expect(cloudErrorTextForOperator(StateError('Masa bulunamadı')), contains('Masa bulunamadı'));
    expect(cloudErrorTextForOperator(null, fallback: 'x'), 'x');
  });
}
