import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

/// Emits a single-line structured perf log for manual device testing.
///
/// Example:
/// `[PrintPerf][receipt_test] {"tap_at":"...","total_ms":420,"bridge_request_ms":120}`
void logPrintPerf(String flow, Map<String, Object?> fields) {
  final body = <String, dynamic>{};
  for (final entry in fields.entries) {
    final value = entry.value;
    if (value == null) continue;
    body[entry.key] = value;
  }
  final encoded = jsonEncode(body);
  debugPrint('[PrintPerf][$flow] $encoded');
}
