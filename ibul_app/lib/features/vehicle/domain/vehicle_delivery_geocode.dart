import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class VehicleResolvedDelivery {
  const VehicleResolvedDelivery({
    this.point,
    this.city,
    this.district,
    this.neighborhood,
    this.street,
  });

  final LatLng? point;
  final String? city;
  final String? district;
  final String? neighborhood;
  final String? street;

  static VehicleResolvedDelivery? fromSaved(Map<String, String> row) {
    final lat = double.tryParse(
      (row['lat'] ?? row['latitude'] ?? '').trim(),
    );
    final lng = double.tryParse(
      (row['lng'] ?? row['longitude'] ?? '').trim(),
    );
    final city = (row['city'] ?? row['province'] ?? '').trim();
    final district = (row['district'] ?? '').trim();
    final neighborhood =
        (row['neighborhood'] ?? row['mahalle'] ?? '').trim();
    final street = (row['detail'] ?? row['mapAddress'] ?? '').trim();
    if (lat == null && lng == null && city.isEmpty && street.isEmpty) {
      return null;
    }
    return VehicleResolvedDelivery(
      point: lat != null && lng != null ? LatLng(lat, lng) : null,
      city: city.isEmpty ? null : city,
      district: district.isEmpty ? null : district,
      neighborhood: neighborhood.isEmpty ? null : neighborhood,
      street: street.isEmpty ? null : street,
    );
  }
}

/// Resolves a Turkish address to coordinates. Does not invent a location.
abstract final class VehicleDeliveryGeocode {
  static Map<String, String> get _headers => kIsWeb
      ? const <String, String>{}
      : const {
          'User-Agent': 'ibul-app-vehicle-rental/1.0',
          'Accept-Language': 'tr',
        };

  static Future<LatLng?> lookup(String query) async {
    final q = query.trim();
    if (q.length < 6) return null;
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'tr',
      'limit': '1',
      'q': q,
    });
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is! Map) return null;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (error, stack) {
      debugPrint('vehicle delivery geocode: $error\n$stack');
      return null;
    }
  }

  static Future<LatLng?> lookupParts({
    String city = '',
    String district = '',
    String neighborhood = '',
    String street = '',
  }) async {
    final queries = <String>[
      [street, neighborhood, district, city, 'Türkiye'].where(_filled).join(', '),
      [neighborhood, district, city, 'Türkiye'].where(_filled).join(', '),
      [district, city, 'Türkiye'].where(_filled).join(', '),
    ].where((q) => q.replaceAll('Türkiye', '').trim().length >= 6);
    for (final query in queries) {
      final found = await lookup(query);
      if (found != null) return found;
    }
    return null;
  }

  static Future<VehicleResolvedDelivery?> reverse(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'zoom': '18',
    });
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final address = decoded['address'];
      if (address is! Map) {
        return VehicleResolvedDelivery(point: point);
      }
      final city = _first(address, const [
        'province',
        'state',
        'city',
      ]);
      final district = _first(address, const [
        'town',
        'municipality',
        'county',
        'city_district',
      ]);
      final neighborhood = _first(address, const [
        'suburb',
        'neighbourhood',
        'quarter',
        'village',
      ]);
      final street = [
        address['road']?.toString(),
        address['house_number']?.toString(),
      ].where(_filled).join(' ');
      return VehicleResolvedDelivery(
        point: point,
        city: city,
        district: district,
        neighborhood: neighborhood,
        street: street.isEmpty ? null : street,
      );
    } catch (error, stack) {
      debugPrint('vehicle delivery reverse geocode: $error\n$stack');
      return VehicleResolvedDelivery(point: point);
    }
  }

  static bool _filled(String? value) => (value ?? '').trim().isNotEmpty;

  static String? _first(Map address, List<String> keys) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
