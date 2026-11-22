/// What the operator reads when a cloud call failed. A network failure is
/// one calm sentence; the raw socket text (address, port, request URL) is
/// never shown. Other errors keep their own message without the Dart
/// exception prefix.
const String cloudUnreachableOperatorText =
    'Bulut erişilemiyor. Son doğrulanmış ekran korunuyor.';

bool isCloudUnreachableError(Object? error) {
  final text = (error?.toString() ?? '').toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('connection refused') ||
      text.contains('connection closed') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('timeoutexception') ||
      text.contains('bulut erişilemiyor');
}

String cloudErrorTextForOperator(
  Object? error, {
  String fallback = 'İşlem tamamlanamadı.',
}) {
  if (isCloudUnreachableError(error)) return cloudUnreachableOperatorText;
  final text = (error?.toString() ?? '')
      .replaceFirst(RegExp(r'^[A-Za-z]*(Exception|Error):\s*'), '')
      .trim();
  return text.isEmpty ? fallback : text;
}
