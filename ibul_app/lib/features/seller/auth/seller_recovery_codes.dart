class SellerRecoveryCodes {
  const SellerRecoveryCodes._();

  static const codeCount = 5;
  static final _codePattern = RegExp(
    r'^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$',
  );

  static String normalizeIdentifier(String value) {
    return value.trim().toLowerCase();
  }

  static String normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizeCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static bool looksLikeCode(String value) {
    return _codePattern.hasMatch(normalizeCode(value));
  }

  static bool looksLikeEmail(String value) {
    final text = normalizeIdentifier(value);
    return text.contains('@') && text.contains('.');
  }

  static bool looksLikePhone(String value) {
    final digits = normalizePhone(value);
    return digits.length >= 10 && digits.length <= 15;
  }
}
