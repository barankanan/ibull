import 'dart:math' as math;

class VehicleDeliveryZoneQuote {
  const VehicleDeliveryZoneQuote({
    required this.label,
    required this.minKm,
    required this.maxKm,
    required this.fee,
    this.isAirport = false,
  });

  final String label;
  final double minKm;
  final double maxKm;
  final double fee;
  final bool isAirport;
}

/// Client-side preview only. Checkout uses `quote_vehicle_delivery_fee` RPC.
abstract final class VehicleDeliveryFeeCalculator {
  static double haversineKm({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    const earthKm = 6371.0;
    final dLat = _toRad(toLat - fromLat);
    final dLng = _toRad(toLng - fromLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(fromLat)) *
            math.cos(_toRad(toLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  static double quote({
    required List<VehicleDeliveryZoneQuote> zones,
    required double distanceKm,
    bool airport = false,
  }) {
    if (distanceKm < 0) throw ArgumentError('distanceKm must be >= 0');
    if (airport) {
      final airportZones = zones
          .where((z) => z.isAirport)
          .toList(growable: false);
      if (airportZones.isEmpty) {
        throw StateError('Airport delivery is not configured');
      }
      return airportZones.first.fee;
    }
    for (final zone in zones) {
      if (zone.isAirport) continue;
      if (distanceKm >= zone.minKm && distanceKm <= zone.maxKm) {
        return zone.fee;
      }
    }
    throw StateError(
      'No delivery zone covers ${distanceKm.toStringAsFixed(1)} km',
    );
  }

  static double? tryQuote({
    required List<VehicleDeliveryZoneQuote> zones,
    required double distanceKm,
    bool airport = false,
  }) {
    try {
      return quote(zones: zones, distanceKm: distanceKm, airport: airport);
    } catch (_) {
      return null;
    }
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

abstract final class VehicleDeliveryQuoteError {
  static const outOfZone = 'out_of_zone';
  static const locationRequired = 'location_required';
  static const zoneMissing = 'delivery_zone_missing';
  static const homeDisabled = 'home_delivery_disabled';
  static const mapDisabled = 'map_point_disabled';
  static const airportMissing = 'airport_zone_missing';
  static const galleryMissing = 'gallery_location_missing';

  static const _codes = {
    outOfZone,
    locationRequired,
    'missing_coordinates',
    'invalid_address',
    zoneMissing,
    homeDisabled,
    mapDisabled,
    airportMissing,
    galleryMissing,
    'delivery_disabled',
  };

  static String? codeOf(String? raw) {
    if (raw == null) return null;
    final text = raw.trim().replaceAll('"', '').replaceAll("'", '');
    for (final code in _codes) {
      if (text == code) return code;
    }
    for (final code in _codes) {
      if (text.contains(code)) return code;
    }
    return null;
  }

  static String message(String? code, {num? km}) {
    switch (codeOf(code) ?? code) {
      case outOfZone:
        return 'Bu adres teslimat bölgemizin dışında.';
      case locationRequired:
      case 'missing_coordinates':
      case 'invalid_address':
        return 'Teslim konumu belirlenemedi. Haritadan konum seçin.';
      case zoneMissing:
      case homeDisabled:
      case 'delivery_disabled':
        return 'Bu araç için adrese teslim hizmeti bulunmuyor.';
      case mapDisabled:
        return 'Bu araç için farklı teslim noktası kapalı.';
      case airportMissing:
        return 'Havalimanı teslimi bu galeri için tanımlı değil.';
      case galleryMissing:
        return 'Galeri konumu eksik. Lütfen galeriden teslim almayı seçin.';
      default:
        return 'Teslim ücreti hesaplanamadı.';
    }
  }

  /// UI must never render a raw RPC/enum code.
  static String sanitizeForUi(String? raw) {
    final code = codeOf(raw);
    if (code != null) return message(code);
    final text = (raw ?? '').trim();
    if (text.isEmpty || RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(text)) {
      return message(text.isEmpty ? null : text);
    }
    return text;
  }
}
