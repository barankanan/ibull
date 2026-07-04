import 'package:flutter/foundation.dart';

/// Lightweight boot-step profiler for web freeze diagnosis.
/// Logs in debug and release so production Chrome console shows freeze point.
class WebBootStepProfiler {
  WebBootStepProfiler._();

  static final Map<String, int> _startsMs = <String, int>{};

  static void start(String step) {
    _startsMs[step] = DateTime.now().millisecondsSinceEpoch;
    _log(step: step, phase: 'start');
  }

  static void done(String step, {String? detail}) {
    final started = _startsMs.remove(step);
    final elapsed = started == null
        ? null
        : DateTime.now().millisecondsSinceEpoch - started;
    final suffix = detail == null || detail.isEmpty ? '' : ' detail=$detail';
    if (elapsed != null) {
      _log(step: step, phase: 'done', ms: elapsed, suffix: suffix);
    } else {
      _log(step: step, phase: 'done', suffix: suffix);
    }
  }

  static void error(String step, Object error) {
    _startsMs.remove(step);
    _log(step: step, phase: 'error', suffix: ' error=$error');
  }

  static void slow(String step, int ms, {String? detail}) {
    final suffix = detail == null || detail.isEmpty ? '' : ' detail=$detail';
    _log(step: step, phase: 'slow', ms: ms, suffix: suffix);
  }

  static void _log({
    required String step,
    required String phase,
    int? ms,
    String suffix = '',
  }) {
    final msPart = ms == null ? '' : ' ms=$ms';
    final message = '[WebBootStep] step=$step $phase$msPart$suffix';
    if (kIsWeb) {
      // ignore: avoid_print
      print(message);
      return;
    }
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
