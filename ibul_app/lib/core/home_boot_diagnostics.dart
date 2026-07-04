import 'runtime_diagnostic_logger.dart';

/// Throttled release-safe home boot diagnostics — avoids log spam.
abstract final class HomeBootDiagnostics {
  static DateTime? _bootStarted;
  static int _buildCount = 0;
  static int _notifyCount = 0;
  static String? _lastBlockedStage;
  static int _lastWatchdogLogMs = 0;

  static void markInitState() {
    _bootStarted = DateTime.now();
    _buildCount = 0;
    RuntimeDiagnosticLogger.home('[HomeBoot] initState');
  }

  static void logPostFrameScheduled() {
    RuntimeDiagnosticLogger.home('[HomeBoot] postFrame scheduled');
  }

  static void logStageScheduled(String stage) {
    RuntimeDiagnosticLogger.home('[HomeBoot] stage $stage scheduled');
  }

  static void logStageCompleted(String stage) {
    RuntimeDiagnosticLogger.home('[HomeBoot] stage $stage completed');
  }

  static void logBuild({required int productCardCount, int imageScheduled = 0}) {
    _buildCount++;
    if (_buildCount <= 3 || _buildCount % 10 == 0) {
      RuntimeDiagnosticLogger.home(
        '[HomeBuild] build count=$_buildCount '
        'product card count=$productCardCount '
        'image scheduled count=$imageScheduled',
      );
    }
  }

  static void logProductsRequestStart() {
    RuntimeDiagnosticLogger.home('[HomeData] products request start');
  }

  static void logProductsRequestDone({required int count, required int ms}) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] products request done count=$count ms=$ms',
    );
  }

  static void logParseDone({required int count, required int ms}) {
    RuntimeDiagnosticLogger.home(
      '[HomeData] parse/map done count=$count ms=$ms',
    );
  }

  static void logSetState(String reason) {
    RuntimeDiagnosticLogger.home('[HomeData] setState reason=$reason');
  }

  static void logProviderNotify(String source) {
    _notifyCount++;
    if (_notifyCount <= 5 || _notifyCount % 20 == 0) {
      RuntimeDiagnosticLogger.home(
        '[Provider] notify count=$_notifyCount source=$source',
      );
    }
  }

  static void logWatchdogTick() {
    final started = _bootStarted;
    if (started == null) return;
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (ms - _lastWatchdogLogMs < 2000) return;
    _lastWatchdogLogMs = ms;
    RuntimeDiagnosticLogger.home('[HomeBoot] watchdog tick ms=$ms');
  }

  static void logBlockedStage(String stage) {
    if (_lastBlockedStage == stage) return;
    _lastBlockedStage = stage;
    final ms = _bootStarted == null
        ? 0
        : DateTime.now().difference(_bootStarted!).inMilliseconds;
    RuntimeDiagnosticLogger.home('[HomeBoot] blocked stage=$stage ms=$ms');
  }

  static int get buildCount => _buildCount;

  static void resetForTests() {
    _bootStarted = null;
    _buildCount = 0;
    _notifyCount = 0;
    _lastBlockedStage = null;
    _lastWatchdogLogMs = 0;
  }
}
