/// Client gate before a customer table request.
/// The server still measures distance. A missing or coarse fix is refused
/// here so the app does not present an unverified order as sent.
abstract final class CustomerTableProximity {
  static const double maxAccuracyMeters = 50;

  static String? rejection({
    required double? latitude,
    required double? longitude,
    required double? accuracyMeters,
  }) {
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return 'Konum doğrulanamadı. Sipariş gönderilmedi.';
    }
    if (accuracyMeters == null ||
        accuracyMeters <= 0 ||
        accuracyMeters > maxAccuracyMeters) {
      return 'Konum doğruluğu yetersiz. Sipariş gönderilmedi.';
    }
    return null;
  }
}
