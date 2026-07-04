import 'package:flutter/foundation.dart';

/// Central place to decide which platform-specific integrations may run.
///
/// The IBUL binary is multi-role (customer / seller / waiter / desktop). On the
/// mobile customer path (iOS/Android phones) restaurant-only integrations such
/// as the local print bridge (`http://127.0.0.1:3001`) must never run — there is
/// no bridge on a customer phone and probing it only adds latency + noisy
/// "connection refused" logs.
class PlatformCapabilities {
  PlatformCapabilities._();

  @visibleForTesting
  static TargetPlatform? debugPlatformOverride;

  @visibleForTesting
  static bool? debugIsWebOverride;

  static bool get _isWeb => debugIsWebOverride ?? kIsWeb;

  static TargetPlatform get _platform =>
      debugPlatformOverride ?? defaultTargetPlatform;

  /// True on native iOS/Android (the phones where the customer app ships).
  static bool get isMobileNative {
    if (_isWeb) return false;
    return _platform == TargetPlatform.iOS ||
        _platform == TargetPlatform.android;
  }

  /// Desktop / web builds are the only ones that can reach a bundled local
  /// print bridge. Mobile phones and browser tabs never can.
  static bool get supportsLocalPrintBridge {
    if (_isWeb) return false;
    return _platform == TargetPlatform.macOS ||
        _platform == TargetPlatform.windows ||
        _platform == TargetPlatform.linux;
  }

  /// The local print bridge / restaurant connectivity probes must be skipped
  /// entirely on mobile phones (customer app).
  static bool get shouldSkipLocalPrintBridge => !supportsLocalPrintBridge;

  @visibleForTesting
  static void resetOverridesForTests() {
    debugPlatformOverride = null;
    debugIsWebOverride = null;
  }
}
