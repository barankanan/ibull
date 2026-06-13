import 'package:flutter/foundation.dart';

/// Masks sensitive values before debug logging.
String maskSensitiveToken(String? value, {String emptyLabel = '(empty)'}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return emptyLabel;
  if (trimmed.length <= 4) return '****';
  return '${trimmed.substring(0, 2)}****${trimmed.substring(trimmed.length - 2)}';
}

void debugLogSensitive(
  String message, {
  Map<String, String?> sensitiveValues = const {},
}) {
  if (!kDebugMode) return;
  var rendered = message;
  for (final entry in sensitiveValues.entries) {
    rendered = rendered.replaceAll(
      entry.value ?? '',
      maskSensitiveToken(entry.value),
    );
  }
  debugPrint(rendered);
}
