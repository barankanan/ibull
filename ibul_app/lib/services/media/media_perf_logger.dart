import 'package:flutter/foundation.dart';

/// Debug modda okunabilir performans logları üretir.
class MediaPerfLogger {
  const MediaPerfLogger._();

  static void logDuration(
    String label,
    Duration duration, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (!kDebugMode) return;
    final ms = duration.inMilliseconds;
    final detail = extra.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    if (detail.isEmpty) {
      debugPrint('[MediaPerf] $label: ${ms}ms');
      return;
    }
    debugPrint('[MediaPerf] $label: ${ms}ms ($detail)');
  }

  static void logInfo(String label, {Map<String, Object?> extra = const {}}) {
    if (!kDebugMode) return;
    final detail = extra.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    if (detail.isEmpty) {
      debugPrint('[MediaPerf] $label');
      return;
    }
    debugPrint('[MediaPerf] $label ($detail)');
  }
}
