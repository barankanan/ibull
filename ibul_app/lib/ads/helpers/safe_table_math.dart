/// Tablo/pagination hesapları için güvenli sayı yardımcıları.
///
/// Flutter web release derlemelerinde (`-O4`, omit-implicit-checks) `dynamic`
/// kanaldan gelen yanlış tipte bir değer `int` alanlara sızabilir ve
/// aritmetik sonucu `NaN` olabilir. `NaN.ceil()` web'de
/// "Unsupported operation: NaN.ceil()" fırlatır ve LayoutBuilder içindeyse
/// kırmızı ErrorWidget olarak görünür. Bu yardımcılar UI hesaplarına giren
/// tüm değerleri sınırda doğrular (validate input at system boundaries).
class SafeTableMath {
  const SafeTableMath._();

  /// NaN/Infinity/negatif ve yanlış tip değerleri güvenli bir int'e çevirir.
  static int safeCount(dynamic value, {int fallback = 0}) {
    if (value is int) return value < 0 ? fallback : value;
    if (value is double) {
      if (value.isNaN || value.isInfinite || value < 0) return fallback;
      return value.floor();
    }
    if (value is num) {
      final asDouble = value.toDouble();
      if (asDouble.isNaN || asDouble.isInfinite || asDouble < 0) {
        return fallback;
      }
      return asDouble.floor();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed >= 0) return parsed;
      return fallback;
    }
    return fallback;
  }

  /// NaN/Infinity için güvenli ceil; bozuk girişte [fallback] döner.
  static int safeCeil(num value, {int fallback = 0}) {
    final asDouble = value.toDouble();
    if (asDouble.isNaN || asDouble.isInfinite) return fallback;
    return asDouble.ceil();
  }

  /// Pozitif ve sonlu bir double garanti eder.
  static double safePositiveDouble(num value, {double fallback = 0}) {
    final asDouble = value.toDouble();
    if (asDouble.isNaN || asDouble.isInfinite || asDouble < 0) return fallback;
    return asDouble;
  }

  /// Toplam kayıt ve sayfa boyutundan güvenli sayfa sayısı üretir.
  /// Sıfır/negatif/NaN girişlerde asla exception atmaz; en az 1 döner.
  static int safePageCount({
    required dynamic totalRowCount,
    required dynamic pageSize,
    int maxPages = 999999,
  }) {
    final total = safeCount(totalRowCount);
    final size = safeCount(pageSize);
    if (size <= 0) return 1;
    if (total <= 0) return 1;
    final pages = safeCeil(total / size, fallback: 1);
    if (pages < 1) return 1;
    return pages > maxPages ? maxPages : pages;
  }

  /// Kolon genişliği için güvenli değer; NaN/Infinity/negatifte [fallback].
  static double safeColumnWidth(
    num width, {
    double fallback = 120.0,
    double min = 24.0,
    double max = 2000.0,
  }) {
    final asDouble = width.toDouble();
    if (asDouble.isNaN || asDouble.isInfinite || asDouble <= 0) return fallback;
    if (asDouble < min) return min;
    if (asDouble > max) return max;
    return asDouble;
  }
}
