import 'package:latlong2/latlong.dart';

import '../../seller/panel/cargo/seller_cargo_geocode.dart';
import '../../vehicle/domain/vehicle_delivery_geocode.dart';
import '../../../core/turkiye_location_data.dart';

enum MallLocationSource {
  city,
  district,
  addressSearch,
  manualMap,
  currentLocation,
}

class MallMapFocus {
  const MallMapFocus({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;
}

class MallGeocodeHit {
  const MallGeocodeHit({
    required this.latitude,
    required this.longitude,
    this.label = '',
    this.city,
    this.district,
    this.street,
  });

  final double latitude;
  final double longitude;
  final String label;
  final String? city;
  final String? district;
  final String? street;
}

abstract class MallGeocodeClient {
  Future<MallGeocodeHit?> search(String query);
  Future<List<MallGeocodeHit>> suggest(String query);
  Future<MallGeocodeHit?> reverse(double latitude, double longitude);
}

class NominatimMallGeocodeClient implements MallGeocodeClient {
  const NominatimMallGeocodeClient();

  @override
  Future<MallGeocodeHit?> search(String query) async {
    final point = await VehicleDeliveryGeocode.lookup(query);
    if (point == null) return null;
    return MallGeocodeHit(
      latitude: point.latitude,
      longitude: point.longitude,
      label: query,
    );
  }

  @override
  Future<List<MallGeocodeHit>> suggest(String query) async {
    try {
      final rows = await SellerCargoGeocode.fetchAddressSuggestions(query);
      return [
        for (final row in rows)
          MallGeocodeHit(
            latitude: row.lat,
            longitude: row.lng,
            label: row.label,
            city: row.province,
            district: row.district,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<MallGeocodeHit?> reverse(double latitude, double longitude) async {
    final resolved = await VehicleDeliveryGeocode.reverse(
      LatLng(latitude, longitude),
    );
    if (resolved == null) return null;
    final street = [
      resolved.neighborhood,
      resolved.street,
    ].where((part) => (part ?? '').trim().isNotEmpty).join(' ');
    return MallGeocodeHit(
      latitude: latitude,
      longitude: longitude,
      label: street,
      city: resolved.city,
      district: resolved.district,
      street: street.isEmpty ? null : street,
    );
  }
}

class MallLocationSync {
  const MallLocationSync._();

  static const geocodeMiss =
      'Adres otomatik olarak bulunamadı. Haritadan konumu elle seçebilirsiniz.';

  static String searchQuery({
    required String address,
    required String district,
    required String city,
  }) {
    return [address, district, city, 'Türkiye']
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  static String placeQuery({required String district, required String city}) {
    return [district, city, 'Türkiye']
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  static bool shouldSearchAddress({
    required MallLocationSource? source,
    required String snapshot,
    required String current,
  }) {
    final text = current.trim();
    if (text.length < 8) return false;
    if (source != MallLocationSource.manualMap &&
        source != MallLocationSource.currentLocation) {
      return true;
    }
    final base = snapshot.trim();
    if (base.isEmpty) return true;
    return (text.length - base.length).abs() >= 12;
  }

  static String? matchOption(String? raw, List<String> options) {
    final folded = foldTr(raw ?? '');
    if (folded.isEmpty) return null;
    for (final option in options) {
      final candidate = foldTr(option);
      if (candidate == folded || folded.contains(candidate)) return option;
    }
    return null;
  }

  static String foldTr(String value) {
    var text = value.trim().toLowerCase();
    text = text.replaceAll('i̇', 'i').replaceAll('ı', 'i');
    return text
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  static List<String> districtsFor(String province) {
    if (!TurkiyeLocationData.provinces.contains(province)) return const [];
    return TurkiyeLocationData.districtsForProvince(province);
  }
}

class MallGeocodeGate {
  int _generation = 0;

  int begin() => ++_generation;

  bool isCurrent(int id) => id == _generation;
}
