import 'package:flutter/foundation.dart';

/// Masks email for release-safe auth logs.
String maskEmail(String? email) {
  final trimmed = email?.trim() ?? '';
  if (trimmed.isEmpty) return '(empty)';
  final at = trimmed.indexOf('@');
  if (at <= 0) return '****';
  final local = trimmed.substring(0, at);
  final domain = trimmed.substring(at + 1);
  final maskedLocal =
      local.length <= 2 ? '**' : '${local.substring(0, 1)}***';
  final dot = domain.lastIndexOf('.');
  final maskedDomain = dot > 0 ? '***${domain.substring(dot)}' : '***';
  return '$maskedLocal@$maskedDomain';
}

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
