import 'package:flutter/foundation.dart';

import 'web_boot_trace_stub.dart'
    if (dart.library.html) 'web_boot_trace_web.dart' as impl;
import 'web_perf_trace.dart';

/// Boot stages for deferred home module loading (web production diagnostics).
abstract final class WebBootTraceStage {
  static const appScriptStarted = 'app_script_started';
  static const shellStarted = 'shell_started';
  static const loadLibraryStarted = 'load_library_started';
  static const loadLibraryCompleted = 'load_library_completed';
  static const deferredFactoryStarted = 'deferred_factory_started';
  static const deferredFactoryCompleted = 'deferred_factory_completed';
  static const deferredFactoryError = 'deferred_factory_error';
  static const homeCoreWidgetCreated = 'home_core_widget_created';
  static const homeCoreFirstBuildStarted = 'home_core_first_build_started';
  static const homeCoreFirstFrameRendered = 'home_core_first_frame_rendered';
  static const homescreenWidgetCreated = 'homescreen_widget_created';
  static const homescreenFirstBuildStarted = 'homescreen_first_build_started';
  static const homescreenFirstFrameRendered = 'homescreen_first_frame_rendered';
  static const bootComplete = 'boot_complete';
  static const timeoutTriggered = 'timeout_triggered';
  static const errorCaught = 'error_caught';
  static const completed = 'completed';
}

/// Latest boot attempt id — shared with section traces on web.
String? currentWebBootAttemptId;

/// Stages that mean global boot succeeded (HTML watchdog must stop).
const Set<String> webBootTerminalSuccessStages = {
  WebBootTraceStage.homeCoreFirstFrameRendered,
  WebBootTraceStage.homescreenFirstFrameRendered,
  WebBootTraceStage.bootComplete,
  WebBootTraceStage.completed,
};

/// Immutable snapshot written to localStorage and shown in the debug panel.
class WebBootTraceSnapshot {
  const WebBootTraceSnapshot({
    required this.module,
    required this.stage,
    required this.elapsedSeconds,
    required this.retryCount,
    this.bootAttemptId,
    this.lastError,
    this.timestamp,
    this.userAgent,
    this.moduleLoaded = false,
    this.factoryCompleted = false,
    this.firstFrameRendered = false,
    this.bootComplete = false,
    this.lastSectionTimeout,
    this.globalErrorReason,
  });

  final String module;
  final String stage;
  final int elapsedSeconds;
  final int retryCount;
  final String? bootAttemptId;
  final String? lastError;
  final String? timestamp;
  final String? userAgent;
  final bool moduleLoaded;
  final bool factoryCompleted;
  final bool firstFrameRendered;
  final bool bootComplete;
  final String? lastSectionTimeout;
  final String? globalErrorReason;

  WebBootTraceSnapshot copyWith({
    String? module,
    String? stage,
    int? elapsedSeconds,
    int? retryCount,
    String? bootAttemptId,
    String? lastError,
    String? timestamp,
    String? userAgent,
    bool? moduleLoaded,
    bool? factoryCompleted,
    bool? firstFrameRendered,
    bool? bootComplete,
    String? lastSectionTimeout,
    String? globalErrorReason,
    bool clearError = false,
  }) {
    return WebBootTraceSnapshot(
      module: module ?? this.module,
      stage: stage ?? this.stage,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      retryCount: retryCount ?? this.retryCount,
      bootAttemptId: bootAttemptId ?? this.bootAttemptId,
      lastError: clearError ? null : (lastError ?? this.lastError),
      timestamp: timestamp ?? this.timestamp,
      userAgent: userAgent ?? this.userAgent,
      moduleLoaded: moduleLoaded ?? this.moduleLoaded,
      factoryCompleted: factoryCompleted ?? this.factoryCompleted,
      firstFrameRendered: firstFrameRendered ?? this.firstFrameRendered,
      bootComplete: bootComplete ?? this.bootComplete,
      lastSectionTimeout: lastSectionTimeout ?? this.lastSectionTimeout,
      globalErrorReason: globalErrorReason ?? this.globalErrorReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'module': module,
        'stage': stage,
        'elapsedSeconds': elapsedSeconds,
        'retryCount': retryCount,
        if (bootAttemptId != null) 'bootAttemptId': bootAttemptId,
        'lastError': lastError,
        'timestamp': timestamp,
        'userAgent': userAgent,
        'moduleLoaded': moduleLoaded,
        'factoryCompleted': factoryCompleted,
        'firstFrameRendered': firstFrameRendered,
        'bootComplete': bootComplete,
        if (lastSectionTimeout != null) 'lastSectionTimeout': lastSectionTimeout,
        if (globalErrorReason != null) 'globalErrorReason': globalErrorReason,
      };
}

/// Tracks deferred module boot stages; persists to `ibul_web_boot_trace_v1` on web.
class WebBootTraceNotifier extends ChangeNotifier {
  /// Active boot trace for section-level events (lazy sections, timeouts).
  static WebBootTraceNotifier? active;

  WebBootTraceNotifier({required String module})
      : _bootAttemptId = 'boot_${DateTime.now().millisecondsSinceEpoch}',
        _snapshot = WebBootTraceSnapshot(
          module: module,
          stage: WebBootTraceStage.shellStarted,
          elapsedSeconds: 0,
          retryCount: 0,
        ) {
    currentWebBootAttemptId = _bootAttemptId;
    active = this;
    _startedAt = DateTime.now();
    impl.clearWebBootTrace();
    _snapshot = _snapshot.copyWith(bootAttemptId: _bootAttemptId);
    _persist();
  }

  final String _bootAttemptId;
  late DateTime _startedAt;
  WebBootTraceSnapshot _snapshot;
  bool _complete = false;
  bool _loggedFirstBuild = false;

  String get bootAttemptId => _bootAttemptId;

  WebBootTraceSnapshot get snapshot => _snapshot;
  bool get isComplete => _complete;

  int get elapsedSeconds =>
      DateTime.now().difference(_startedAt).inSeconds;

  void setStage(String stage, {String? detail}) {
    if (_complete && stage != WebBootTraceStage.completed) return;
    if (_snapshot.stage == stage && detail == null) {
      _refreshElapsed();
      return;
    }
    var moduleLoaded = _snapshot.moduleLoaded;
    var factoryCompleted = _snapshot.factoryCompleted;
    if (stage == WebBootTraceStage.loadLibraryCompleted) {
      moduleLoaded = true;
    }
    if (stage == WebBootTraceStage.deferredFactoryCompleted ||
        stage == WebBootTraceStage.homeCoreWidgetCreated) {
      factoryCompleted = true;
    }
    _snapshot = _snapshot.copyWith(
      stage: stage,
      elapsedSeconds: elapsedSeconds,
      timestamp: DateTime.now().toIso8601String(),
      moduleLoaded: moduleLoaded,
      factoryCompleted: factoryCompleted,
    );
    _persist(detail: detail);
    notifyListeners();
    if (kIsWeb) {
      // ignore: avoid_print
      print('[WebBootTrace][$stage] elapsed=${elapsedSeconds}s module=${_snapshot.module}');
    }
    if (webBootTerminalSuccessStages.contains(stage)) {
      _cancelGlobalWatchdog();
    }
  }

  void setError(String error) {
    _snapshot = _snapshot.copyWith(
      lastError: error,
      elapsedSeconds: elapsedSeconds,
      timestamp: DateTime.now().toIso8601String(),
    );
    _persist();
    notifyListeners();
  }

  void incrementRetry() {
    _snapshot = _snapshot.copyWith(
      retryCount: _snapshot.retryCount + 1,
      clearError: true,
      elapsedSeconds: elapsedSeconds,
      timestamp: DateTime.now().toIso8601String(),
    );
    _startedAt = DateTime.now();
    _persist();
    notifyListeners();
  }

  void markFirstBuildOnce() {
    if (_loggedFirstBuild) return;
    _loggedFirstBuild = true;
    setStage(WebBootTraceStage.homeCoreFirstBuildStarted);
  }

  void markComplete() {
    if (_complete) return;
    setStage(WebBootTraceStage.homeCoreFirstFrameRendered);
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeFirstFrame);
    WebPerfTrace.instance.markBootComplete();
    _snapshot = _snapshot.copyWith(
      stage: WebBootTraceStage.bootComplete,
      elapsedSeconds: elapsedSeconds,
      timestamp: DateTime.now().toIso8601String(),
      firstFrameRendered: true,
      bootComplete: true,
      moduleLoaded: true,
      factoryCompleted: true,
    );
    _persist();
    _complete = true;
    setStage(WebBootTraceStage.completed);
    _cancelGlobalWatchdog();
    notifyListeners();
  }

  void noteSectionTimeout(String sectionName) {
    // Section timeouts must never flip global boot into failure.
    _snapshot = _snapshot.copyWith(
      lastSectionTimeout: sectionName,
      elapsedSeconds: elapsedSeconds,
      timestamp: DateTime.now().toIso8601String(),
    );
    _persist();
    notifyListeners();
  }

  void _cancelGlobalWatchdog() {
    impl.cancelHomeBootWatchdog();
  }

  void _refreshElapsed() {
    final next = elapsedSeconds;
    if (next == _snapshot.elapsedSeconds) return;
    _snapshot = _snapshot.copyWith(
      elapsedSeconds: next,
      timestamp: DateTime.now().toIso8601String(),
    );
    _persist();
    notifyListeners();
  }

  void tickElapsed() => _refreshElapsed();

  void _persist({String? detail}) {
    impl.persistWebBootTrace(
      _snapshot,
      startedAtMs: _startedAt.millisecondsSinceEpoch,
      detail: detail,
    );
  }
}

String? readWebBootTraceJson() => impl.readWebBootTraceJson();

void clearWebBootTrace() => impl.clearWebBootTrace();
