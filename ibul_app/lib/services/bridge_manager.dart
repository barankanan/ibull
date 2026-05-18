import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// BridgeSetupResult
// ─────────────────────────────────────────────────────────────────────────────

class BridgeSetupResult {
  const BridgeSetupResult._({
    required this.success,
    this.printerName,
    this.paperWidthMm,
    this.transportType,
    this.errorMessage,
  });

  factory BridgeSetupResult.success({
    required String printerName,
    required int paperWidthMm,
    required String transportType,
  }) =>
      BridgeSetupResult._(
        success: true,
        printerName: printerName,
        paperWidthMm: paperWidthMm,
        transportType: transportType,
      );

  factory BridgeSetupResult.noPrinterFound() => const BridgeSetupResult._(
        success: false,
        errorMessage: 'no_printer_found',
      );

  factory BridgeSetupResult.error(String message) =>
      BridgeSetupResult._(success: false, errorMessage: message);

  final bool success;
  final String? printerName;
  final int? paperWidthMm;
  final String? transportType;
  final String? errorMessage;

  bool get noPrinterFound => errorMessage == 'no_printer_found';
}

// ─────────────────────────────────────────────────────────────────────────────
// LaunchAgentResult
// ─────────────────────────────────────────────────────────────────────────────

class LaunchAgentResult {
  const LaunchAgentResult({
    required this.success,
    this.alreadyInstalled = false,
    this.error,
  });

  final bool success;
  final bool alreadyInstalled;
  final String? error;
}

class BridgeStartResult {
  const BridgeStartResult({
    required this.ok,
    required this.status,
    required this.message,
    this.details = const <String, dynamic>{},
  });

  final bool ok;
  final String status;
  final String message;
  final Map<String, dynamic> details;

  static BridgeStartResult started({
    required String message,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) {
    return BridgeStartResult(
      ok: true,
      status: 'started',
      message: message,
      details: details,
    );
  }

  static BridgeStartResult failed({
    required String message,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) {
    return BridgeStartResult(
      ok: false,
      status: 'failed',
      message: message,
      details: details,
    );
  }
}

typedef BridgeProgressCallback = void Function(String message);

// ─────────────────────────────────────────────────────────────────────────────
// BridgeManager
// ─────────────────────────────────────────────────────────────────────────────

/// Manages the local print bridge process lifecycle.
///
/// Responsibilities:
///   - Health-check the bridge (is it alive?)
///   - Start it if it is not running (macOS / Windows desktop only)
///   - Install the macOS LaunchAgent so it auto-starts on login
///   - Trigger POST /setup (one-shot auto-discover + configure)
class BridgeManager {
  static const String _baseUrl = 'http://127.0.0.1:3001';
  static const Duration _healthTimeout = Duration(milliseconds: 900);
  static const Duration _startPollInterval = Duration(milliseconds: 400);
  static const Duration _startMaxWait = Duration(milliseconds: 5000);

  static final http.Client _client = http.Client();
  static Future<BridgeStartResult>? _inFlightStart;

  // ── Health ──────────────────────────────────────────────────────────────────

  /// Suggested manual start command for Windows/macOS dev (flutter run -d windows).
  static Future<String> devStartCommandHint() async {
    final parent = await _findBridgeParentDir();
    if (parent == null) {
      return Platform.isWindows
          ? 'py -3 -m local_print_bridge'
          : 'python3 -m local_print_bridge';
    }
    final module = Platform.isWindows
        ? 'py -3 -m local_print_bridge'
        : 'python3 -m local_print_bridge';
    return 'cd "$parent"\n$module';
  }

  /// Returns true if the bridge is reachable right now.
  static Future<bool> isAlive({Duration? timeout}) async {
    if (kIsWeb) return false;
    try {
      final resp = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(timeout ?? _healthTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Ensure running ──────────────────────────────────────────────────────────

  /// Checks liveness. If the bridge is down, attempts to start it.
  /// Returns true once the bridge is reachable.
  static Future<bool> ensureRunning() async {
    final result = await ensureReady();
    return result.ok;
  }

  /// Full lifecycle control used by setup wizards.
  ///
  /// 1. Checks whether bridge is already reachable.
  /// 2. Verifies that an installable/runnable bridge target exists.
  /// 3. Starts it only when needed.
  /// 4. Waits briefly and re-checks health.
  ///
  /// This prevents duplicate concurrent starts and returns a structured result.
  static Future<BridgeStartResult> ensureReady({
    BridgeProgressCallback? onProgress,
  }) async {
    if (_inFlightStart != null) {
      return _inFlightStart!;
    }

    final future = _ensureReadyInternal(onProgress: onProgress);
    _inFlightStart = future;
    try {
      return await future;
    } finally {
      _inFlightStart = null;
    }
  }

  static Future<BridgeStartResult> _ensureReadyInternal({
    BridgeProgressCallback? onProgress,
  }) async {
    if (kIsWeb) {
      return BridgeStartResult.failed(
        message: 'Web üzerinde yerel yazıcı servisi otomatik başlatılamıyor.',
        details: const <String, dynamic>{'webUnsupported': true},
      );
    }
    if (!Platform.isMacOS && !Platform.isWindows) {
      return BridgeStartResult.failed(
        message: 'Bu platformda yazıcı servisi otomatik başlatılamıyor.',
        details: const <String, dynamic>{'platformUnsupported': true},
      );
    }

    onProgress?.call('Kurulum kontrol ediliyor...');

    if (await isAlive()) {
      return BridgeStartResult.started(
        message: 'Yazıcı servisi zaten çalışıyor.',
        details: const <String, dynamic>{'alreadyRunning': true},
      );
    }

    final install = await _resolveBridgeTarget();
    if (!install.installed || install.target == null) {
      return BridgeStartResult.failed(
        message: 'Yazıcı servisi kurulamadı veya bulunamadı.',
        details: <String, dynamic>{
          'installed': false,
          'reason': install.reason,
        },
      );
    }

    onProgress?.call('Başlatılıyor...');
    final started = await _startBridge(target: install.target!);
    if (!started) {
      return BridgeStartResult.failed(
        message: 'Yazıcı servisi başlatılamadı. Lütfen tekrar deneyin.',
        details: <String, dynamic>{
          'installed': true,
          'targetType': install.target!.kind,
          'target': install.target!.executable,
        },
      );
    }

    onProgress?.call('Hazırlanıyor...');
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final deadline = DateTime.now().add(_startMaxWait);
    while (DateTime.now().isBefore(deadline)) {
      if (await isAlive(timeout: const Duration(milliseconds: 700))) {
        return BridgeStartResult.started(
          message: 'Yazıcı servisi hazır.',
          details: <String, dynamic>{
            'installed': true,
            'targetType': install.target!.kind,
            'target': install.target!.executable,
          },
        );
      }
      await Future<void>.delayed(_startPollInterval);
    }

    return BridgeStartResult.failed(
      message: 'Yazıcı servisi başlatılamadı. Lütfen tekrar deneyin.',
      details: <String, dynamic>{
        'installed': true,
        'targetType': install.target!.kind,
        'target': install.target!.executable,
        'healthTimedOut': true,
      },
    );
  }

  // ── Auto-setup ──────────────────────────────────────────────────────────────

  /// Calls POST /setup on the bridge.
  ///
  /// The bridge discovers connected printers, picks the best one,
  /// updates its own .env, hot-reloads, and returns what it found.
  static Future<BridgeSetupResult> autoSetup() async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/setup'),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200 && body['ok'] == true) {
        final det = (body['detected'] as Map<String, dynamic>?) ?? {};
        return BridgeSetupResult.success(
          printerName: det['name'] as String? ?? 'Yazıcı',
          paperWidthMm: det['paper_width_mm'] as int? ?? 80,
          transportType: det['type'] as String? ?? 'usb',
        );
      }

      if (resp.statusCode == 404) return BridgeSetupResult.noPrinterFound();

      final msg = body['message'] as String? ?? body['error'] as String? ?? 'Bilinmeyen hata';
      return BridgeSetupResult.error(msg);
    } on TimeoutException {
      return BridgeSetupResult.error(
          'Zaman aşımı. Yazıcı servisi meşgul olabilir, lütfen tekrar deneyin.');
    } catch (e) {
      return BridgeSetupResult.error('Bağlantı hatası: $e');
    }
  }

  // ── Configure ───────────────────────────────────────────────────────────────

  /// Sends a partial settings update to the bridge (POST /configure).
  /// The bridge persists the change to .env and hot-reloads.
  static Future<bool> configure(Map<String, dynamic> fields) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/configure'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 8));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── LaunchAgent (macOS) ─────────────────────────────────────────────────────

  /// Installs (or re-installs) the macOS LaunchAgent that keeps the bridge
  /// running after login — entirely from Dart, zero terminal interaction.
  static Future<LaunchAgentResult> installLaunchAgent() async {
    if (!Platform.isMacOS) {
      return const LaunchAgentResult(success: true, alreadyInstalled: false);
    }

    final python = await _findPython();
    if (python == null) {
      return const LaunchAgentResult(
        success: false,
        error: 'Python bulunamadı. '
            'Homebrew kurulu ve python3 erişilebilir olmalı.',
      );
    }

    final bridgeParent = await _findBridgeParentDir();
    if (bridgeParent == null) {
      return const LaunchAgentResult(
        success: false,
        error: 'Yazıcı servisi klasörü bulunamadı.',
      );
    }

    try {
      final home = Platform.environment['HOME'] ?? '';
      final agentsDir = Directory('$home/Library/LaunchAgents');
      if (!agentsDir.existsSync()) agentsDir.createSync(recursive: true);

      const label = 'com.ibul.localprint';
      final plistPath = '${agentsDir.path}/$label.plist';

      File(plistPath).writeAsStringSync(_buildPlist(
        python: python,
        bridgeDir: bridgeParent,
        stdoutLog: '/tmp/ibul-local-print.log',
        stderrLog: '/tmp/ibul-local-print.error.log',
      ));

      final uid = await _getUid();
      // bootstrap is idempotent — harmless if the agent is already loaded.
      await Process.run('launchctl', ['bootstrap', 'gui/$uid', plistPath]);
      // kickstart -k stops any existing instance and immediately restarts it.
      await Process.run('launchctl', ['kickstart', '-k', 'gui/$uid/$label']);

      debugPrint('[BridgeManager] LaunchAgent installed: $plistPath');
      return const LaunchAgentResult(success: true);
    } catch (e) {
      return LaunchAgentResult(
          success: false, error: 'LaunchAgent kurulumu başarısız: $e');
    }
  }

  /// Returns true if the LaunchAgent plist is already on disk.
  static bool isLaunchAgentInstalled() {
    if (!Platform.isMacOS) return false;
    final home = Platform.environment['HOME'] ?? '';
    return File(
            '$home/Library/LaunchAgents/com.ibul.localprint.plist')
        .existsSync();
  }

  // ── Internals ────────────────────────────────────────────────────────────────

  static Future<bool> _startBridge({required _BridgeStartTarget target}) async {
    try {
      await Process.start(
        target.executable,
        target.arguments,
        workingDirectory: target.workingDirectory,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e) {
      debugPrint('[BridgeManager] Start failed: $e');
      return false;
    }
  }

  static Future<String?> _findPython() async {
    final candidates = <String>[
      if (Platform.isWindows) 'py',
      if (Platform.isWindows) 'python',
      if (Platform.isWindows) 'python3',
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/usr/bin/python3',
      'python3',
    ];
    for (final p in candidates) {
      try {
        final args = p == 'py' ? <String>['-3', '--version'] : <String>['--version'];
        final r = await Process.run(p, args);
        if (r.exitCode == 0) return p;
      } catch (_) {}
    }
    return null;
  }

  static Future<String?> _findBridgeParentDir() async {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      // Bundled inside .app Contents/Resources
      '$execDir/../Resources',
      '$execDir/Resources',
      // Development: running from the repo root
      Directory.current.path,
      Directory.current.parent.path,
      // Sibling of the executable (Windows / Linux dev)
      execDir,
      '$execDir/..',
    ];
    for (final dir in candidates) {
      final resolved = Directory(dir).absolute.path;
      if (Directory('$resolved/local_print_bridge').existsSync()) {
        return resolved;
      }
    }
    return null;
  }

  static Future<String> _getUid() async {
    final r = await Process.run('id', ['-u']);
    return (r.stdout as String).trim();
  }

  /// Packaged Windows installer locations (Inno Setup default).
  @visibleForTesting
  static List<String> windowsInstalledBridgeExeCandidates() {
    if (kIsWeb || !Platform.isWindows) {
      return const <String>[];
    }
    final programFiles =
        Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ??
        r'C:\Program Files (x86)';
    return <String>[
      '$programFiles\\IbulPrintBridge\\IbulPrintBridge.exe',
      '$programFilesX86\\IbulPrintBridge\\IbulPrintBridge.exe',
    ];
  }

  static Future<_BridgeResolveResult> _resolveBridgeTarget() async {
    if (Platform.isWindows) {
      for (final candidate in windowsInstalledBridgeExeCandidates()) {
        if (File(candidate).existsSync()) {
          return _BridgeResolveResult(
            installed: true,
            reason: 'windows_installer_exe',
            target: _BridgeStartTarget(
              kind: 'packaged_exe',
              executable: candidate,
              arguments: const <String>[],
              workingDirectory: File(candidate).parent.path,
            ),
          );
        }
      }
    }

    final parent = await _findBridgeParentDir();
    if (parent == null) {
      return const _BridgeResolveResult(
        installed: false,
        reason: 'bridge_directory_not_found',
      );
    }

    final binaryCandidates = <String>[
      '$parent/local_print_bridge/bin/ibul-local-print-bridge',
      '$parent/local_print_bridge/bin/ibul-local-print-bridge.exe',
      '$parent/local_print_bridge/ibul-local-print-bridge',
      '$parent/local_print_bridge/ibul-local-print-bridge.exe',
    ];

    for (final candidate in binaryCandidates) {
      if (File(candidate).existsSync()) {
        return _BridgeResolveResult(
          installed: true,
          reason: 'binary_found',
          target: _BridgeStartTarget(
            kind: 'binary',
            executable: candidate,
            arguments: const <String>[],
            workingDirectory: parent,
          ),
        );
      }
    }

    final python = await _findPython();
    if (python == null) {
      return const _BridgeResolveResult(
        installed: false,
        reason: 'python_not_found',
      );
    }

    final pythonArgs = python == 'py'
        ? const <String>['-3', '-m', 'local_print_bridge']
        : const <String>['-m', 'local_print_bridge'];

    return _BridgeResolveResult(
      installed: true,
      reason: 'python_module_target',
      target: _BridgeStartTarget(
        kind: 'python',
        executable: python,
        arguments: pythonArgs,
        workingDirectory: parent,
      ),
    );
  }

  static String _buildPlist({
    required String python,
    required String bridgeDir,
    required String stdoutLog,
    required String stderrLog,
  }) =>
      '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.ibul.localprint</string>
  <key>ProgramArguments</key>
  <array>
    <string>$python</string>
    <string>-m</string>
    <string>local_print_bridge</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$bridgeDir</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>$stdoutLog</string>
  <key>StandardErrorPath</key>
  <string>$stderrLog</string>
</dict>
</plist>''';
}

class _BridgeStartTarget {
  const _BridgeStartTarget({
    required this.kind,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String kind;
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

class _BridgeResolveResult {
  const _BridgeResolveResult({
    required this.installed,
    required this.reason,
    this.target,
  });

  final bool installed;
  final String reason;
  final _BridgeStartTarget? target;
}
