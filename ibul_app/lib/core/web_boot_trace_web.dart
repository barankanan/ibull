import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'web_boot_trace.dart';

const _storageKey = 'ibul_web_boot_trace_v1';

bool _isReleaseBuild() => const bool.fromEnvironment('dart.vm.product');

bool _isBootTerminalSuccess(String? stage, Map<String, dynamic> patch) {
  if (patch['bootComplete'] == true) return true;
  if (stage == null || stage.isEmpty) return false;
  return webBootTerminalSuccessStages.contains(stage) ||
      stage == WebBootTraceStage.timeoutTriggered ||
      stage == WebBootTraceStage.errorCaught;
}

void persistWebBootTrace(
  WebBootTraceSnapshot snapshot, {
  required int startedAtMs,
  String? detail,
}) {
  try {
    final payload = <String, dynamic>{
      ...snapshot.toJson(),
      if (detail != null && detail.isNotEmpty) 'detail': detail,
      'userAgent': html.window.navigator.userAgent,
    };
    final persistToStorage = !_isReleaseBuild() ||
        _isBootTerminalSuccess(snapshot.stage, payload) ||
        (snapshot.lastError != null && snapshot.lastError!.isNotEmpty);
    if (persistToStorage) {
      html.window.localStorage[_storageKey] = jsonEncode(payload);
    }

    final update = (html.window as dynamic).__ibulUpdateHomeBootTrace;
    if (update != null) {
      update(<String, dynamic>{
        'bootAttemptId': snapshot.bootAttemptId,
        'module': snapshot.module,
        'stage': snapshot.stage,
        'elapsedSeconds': snapshot.elapsedSeconds,
        'retryCount': snapshot.retryCount,
        'lastError': snapshot.lastError,
        'startedAtMs': startedAtMs,
        'moduleLoaded': snapshot.moduleLoaded,
        'factoryCompleted': snapshot.factoryCompleted,
        'firstFrameRendered': snapshot.firstFrameRendered,
        'bootComplete': snapshot.bootComplete,
        'lastSectionTimeout': snapshot.lastSectionTimeout,
        'globalErrorReason': snapshot.globalErrorReason,
      });
    }

    if (_isBootTerminalSuccess(snapshot.stage, payload)) {
      cancelHomeBootWatchdog();
    }
  } catch (_) {}
}

void cancelHomeBootWatchdog() {
  try {
    final cancel = (html.window as dynamic).__ibulCancelHomeBootWatchdog;
    if (cancel != null) {
      cancel();
    }
  } catch (_) {}
}

String? readWebBootTraceJson() {
  try {
    return html.window.localStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void clearWebBootTrace() {
  try {
    html.window.localStorage.remove(_storageKey);
  } catch (_) {}
}
