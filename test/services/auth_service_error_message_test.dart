import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final service = AuthService();

  test('rejected API key is reported as configuration, not credentials', () {
    final message = service.describeSignInError(
      AuthApiException('Invalid API key', statusCode: '401'),
    );
    expect(message, contains('AUTH-CONFIG'));
    expect(message, isNot(contains('bilgilerinizi kontrol')));
  });

  test('wrong password keeps the credential message', () {
    final message = service.describeSignInError(
      AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      ),
    );
    expect(message, 'E-posta veya şifre hatalı.');
  });

  test('network and server faults are distinguished', () {
    expect(
      service.describeSignInError(
        AuthRetryableFetchException(message: 'x', statusCode: null),
      ),
      contains('AUTH-NETWORK'),
    );
    expect(
      service.describeSignInError(
        AuthApiException('boom', statusCode: '503'),
      ),
      contains('AUTH-SERVER'),
    );
  });

  test('deliberate login-flow messages are shown', () {
    expect(
      service.describeSignInError(
        Exception('Hesabınız pasif. İşletme sahibi erişiminizi yeniden açmalı.'),
      ),
      'Hesabınız pasif. İşletme sahibi erişiminizi yeniden açmalı.',
    );
  });
}
