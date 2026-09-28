/// Client-side T.C. Kimlik No format + checksum.
/// This is not a government identity verification.
abstract final class TurkishNationalId {
  static final _digits = RegExp(r'^[1-9][0-9]{10}$');

  static String digitsOf(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  static bool isValid(String raw) {
    final value = digitsOf(raw);
    if (!_digits.hasMatch(value)) return false;
    final d = [for (var i = 0; i < 11; i++) int.parse(value[i])];
    var odd = 0;
    var even = 0;
    for (var i = 0; i < 9; i++) {
      if (i.isEven) {
        odd += d[i];
      } else {
        even += d[i];
      }
    }
    var tenth = ((odd * 7) - even) % 10;
    if (tenth < 0) tenth += 10;
    if (d[9] != tenth) return false;
    final eleventh = d.take(10).fold<int>(0, (sum, n) => sum + n) % 10;
    return d[10] == eleventh;
  }

  static String? validate(String raw) {
    final value = digitsOf(raw);
    if (value.isEmpty) return 'TC Kimlik No zorunludur.';
    if (value.length != 11) return 'TC Kimlik No 11 haneli olmalıdır.';
    if (!isValid(value)) {
      return 'TC Kimlik No checksum doğrulamasını geçmedi.';
    }
    return null;
  }

  static String mask(String raw) {
    final value = digitsOf(raw);
    if (value.length < 4) return '***********';
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  static String last4(String raw) {
    final value = digitsOf(raw);
    if (value.length < 4) return '';
    return value.substring(value.length - 4);
  }
}
