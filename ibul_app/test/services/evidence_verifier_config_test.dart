import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_sync_service.dart';

void main() {
  Uri? resolve(String configured, {Uri? isolated}) =>
      RestaurantOfflineSyncService.resolveEvidenceVerifierUri(
        isolated: isolated,
        configured: configured,
      );

  test('a build without the setting has no verifier: printed orders stay local', () {
    expect(resolve(''), isNull);
    expect(resolve('   '), isNull);
  });

  test('the deployed verifier must be https', () {
    expect(
      resolve('https://example.supabase.co/functions/v1/verify-lan-print-evidence'),
      Uri.parse('https://example.supabase.co/functions/v1/verify-lan-print-evidence'),
    );
    expect(resolve('http://example.supabase.co/functions/v1/verify-lan-print-evidence'), isNull);
    expect(resolve('ftp://example.com/x'), isNull);
    expect(resolve('not a url'), isNull);
  });

  test('plain http is accepted only for a verifier on this machine', () {
    expect(resolve('http://127.0.0.1:18790/'), Uri.parse('http://127.0.0.1:18790/'));
    expect(resolve('http://localhost:18790/'), Uri.parse('http://localhost:18790/'));
    expect(resolve('http://192.168.10.5:18790/'), isNull);
  });

  test('a test verifier takes precedence over the build setting', () {
    final isolated = Uri.parse('http://127.0.0.1:1/');
    expect(resolve('https://example.com/v', isolated: isolated), isolated);
  });
}
