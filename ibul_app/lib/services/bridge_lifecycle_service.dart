import 'dart:async';
import 'dart:io' show Platform, Process, ProcessResult;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Status of the local print bridge.
enum BridgeStatus {
  /// Not yet checked.
  unknown,

  /// Bridge is reachable and healthy.
  ready,

  /// Bridge is being started or health is being polled.
  starting,

  /// Bridge could not be started or reached.
  unavailable,
}

/// User-facing label for each [BridgeStatus].
extension BridgeStatusLabel on BridgeStatus {
  String get label {
    switch (this) {
      case BridgeStatus.unknown:
        return 'Yazıcı servisi kontrol ediliyor…';
      case BridgeStatus.starting:
        return 'Yazıcı servisi hazırlanıyor…';
      case BridgeStatus.ready:
        return 'Yazıcı servisi hazır';
      case BridgeStatus.unavailable:
        return 'Yazıcı servisi başlatılamadı';
    }
  }
}

/// Manages the lifecycle of the local print bridge.
///
/// On macOS, attempts to start the bridge via launchctl when it is
/// unreachable. On other platforms it only performs health checks.
class BridgeLifecycleService {
  BridgeLifecycleService({
    Uri? bridgeUri,
    http.Client? client,
  })  : _bridgeUri = bridgeUri ?? Uri.parse('http://127.0.0.1:3001'),
        _client = client ?? http.Client();

  static const String _launchctlLabel = 'com.ibul.print-bridge';

  final Uri _bridgeUri;
  final http.Client _client;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks bridge health and, on macOS, attempts to start it when down.
  ///
  /// Emits [BridgeStatus] values as it progresses.
  /// The stream completes once a terminal status is reached.
  Stream<BridgeStatus> ensureRunning() async* {
    yield BridgeStatus.unknown;

    final isUp = await _checkHealth();
    if (isUp) {
      yield BridgeStatus.ready;
      return;
    }

    // Attempt auto-start on macOS (requires LaunchAgent to be installed).
    if (!kIsWeb && Platform.isMacOS) {
      yield BridgeStatus.starting;
      await _tryLaunchctlStart();
      // Poll for up to 8 s (16 × 500 ms).
      for (int i = 0; i < 16; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (await _checkHealth()) {
          yield BridgeStatus.ready;
          return;
        }
      }
    }

    yield BridgeStatus.unavailable;
  }

  /// One-shot health check. Returns true when the bridge is reachable.
  Future<bool> checkHealth() => _checkHealth();

  void dispose() => _client.close();

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<bool> _checkHealth() async {
    try {
      final response = await _client
          .get(_bridgeUri.replace(path: '/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Tries `launchctl kickstart` then `launchctl start` for the bridge agent.
  /// Silently ignores errors — the LaunchAgent handles the actual restart.
  Future<void> _tryLaunchctlStart() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      // Try modern kickstart first (macOS 10.10+).
      final uid = _getUid();
      if (uid != null) {
        final ProcessResult result = await Process.run(
          'launchctl',
          ['kickstart', '-k', 'user/$uid/$_launchctlLabel'],
        );
        if (result.exitCode == 0) return;
      }
      // Fallback: legacy launchctl start.
      await Process.run('launchctl', ['start', _launchctlLabel]);
    } catch (_) {
      // Sandbox or other restriction — LaunchAgent KeepAlive will handle it.
    }
  }

  /// Returns the current user's UID as a string, or null on failure.
  String? _getUid() {
    try {
      final result = Process.runSync('id', ['-u']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }
}
