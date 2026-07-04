import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/platform_capabilities.dart';

void main() {
  tearDown(PlatformCapabilities.resetOverridesForTests);

  group('PlatformCapabilities', () {
    test('iOS is mobile native and skips the local print bridge', () {
      PlatformCapabilities.debugIsWebOverride = false;
      PlatformCapabilities.debugPlatformOverride = TargetPlatform.iOS;

      expect(PlatformCapabilities.isMobileNative, isTrue);
      expect(PlatformCapabilities.supportsLocalPrintBridge, isFalse);
      expect(PlatformCapabilities.shouldSkipLocalPrintBridge, isTrue);
    });

    test('Android is mobile native and skips the local print bridge', () {
      PlatformCapabilities.debugIsWebOverride = false;
      PlatformCapabilities.debugPlatformOverride = TargetPlatform.android;

      expect(PlatformCapabilities.isMobileNative, isTrue);
      expect(PlatformCapabilities.shouldSkipLocalPrintBridge, isTrue);
    });

    test('macOS desktop supports the local print bridge', () {
      PlatformCapabilities.debugIsWebOverride = false;
      PlatformCapabilities.debugPlatformOverride = TargetPlatform.macOS;

      expect(PlatformCapabilities.isMobileNative, isFalse);
      expect(PlatformCapabilities.supportsLocalPrintBridge, isTrue);
      expect(PlatformCapabilities.shouldSkipLocalPrintBridge, isFalse);
    });

    test('Windows desktop supports the local print bridge', () {
      PlatformCapabilities.debugIsWebOverride = false;
      PlatformCapabilities.debugPlatformOverride = TargetPlatform.windows;

      expect(PlatformCapabilities.supportsLocalPrintBridge, isTrue);
    });

    test('web skips the local print bridge and is not mobile native', () {
      PlatformCapabilities.debugIsWebOverride = true;
      PlatformCapabilities.debugPlatformOverride = TargetPlatform.iOS;

      expect(PlatformCapabilities.isMobileNative, isFalse);
      expect(PlatformCapabilities.supportsLocalPrintBridge, isFalse);
      expect(PlatformCapabilities.shouldSkipLocalPrintBridge, isTrue);
    });
  });
}
