import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/external_navigation_allowlist.dart';
import 'package:ibul_app/services/store/store_mapping_helpers.dart';

void main() {
  group('isAllowedExternalNavigationUrl', () {
    test('rejects javascript scheme', () {
      expect(isAllowedExternalNavigationUrl('javascript:alert(1)'), isFalse);
    });

    test('rejects file scheme', () {
      expect(isAllowedExternalNavigationUrl('file:///etc/passwd'), isFalse);
    });

    test('rejects data and ftp schemes', () {
      expect(
        isAllowedExternalNavigationUrl('data:text/html,<script>'),
        isFalse,
      );
      expect(isAllowedExternalNavigationUrl('ftp://maps.google.com/'), isFalse);
    });

    test('accepts google maps https search url', () {
      expect(
        isAllowedExternalNavigationUrl(
          'https://www.google.com/maps/search/?api=1&query=36.0,35.0',
        ),
        isTrue,
      );
    });

    test('accepts apple maps https url', () {
      expect(
        isAllowedExternalNavigationUrl('https://maps.apple.com/?q=36.0,35.0'),
        isTrue,
      );
    });

    test('accepts apple maps http url from builder', () {
      expect(
        isAllowedExternalNavigationUrl(
          buildAppleMapsNavigationUrl(latitude: 36.0, longitude: 35.0),
        ),
        isTrue,
      );
    });

    test('accepts google maps dir url from builder', () {
      expect(
        isAllowedExternalNavigationUrl(
          buildGoogleMapsNavigationUrl(
            latitude: 36.2025,
            longitude: 36.1605,
            originLatitude: 36.21,
            originLongitude: 36.17,
          ),
        ),
        isTrue,
      );
    });

    test('rejects unrelated https hosts', () {
      expect(
        isAllowedExternalNavigationUrl('https://evil.com/maps/foo'),
        isFalse,
      );
      expect(
        isAllowedExternalNavigationUrl('https://www.google.com/'),
        isFalse,
      );
    });

    test('geo scheme allowed only when enabled and coordinates valid', () {
      expect(isAllowedExternalNavigationUrl('geo:36.0,35.0'), isFalse);
      expect(
        isAllowedExternalNavigationUrl('geo:36.0,35.0', allowGeoScheme: true),
        isTrue,
      );
      expect(
        isAllowedExternalNavigationUrl('geo:999,35.0', allowGeoScheme: true),
        isFalse,
      );
    });
  });
}
