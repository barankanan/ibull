String detectCardBrand(String cardNumber) {
  final digits = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 'Bilinmiyor';
  if (digits.startsWith('4')) return 'Visa';
  if (RegExp(r'^5[1-5]').hasMatch(digits) ||
      RegExp(r'^2[2-7]').hasMatch(digits)) {
    return 'Mastercard';
  }
  if (digits.startsWith('9792') || digits.startsWith('65')) return 'Troy';
  return 'Bilinmiyor';
}

String maskLast4(String last4) => '**** $last4';
