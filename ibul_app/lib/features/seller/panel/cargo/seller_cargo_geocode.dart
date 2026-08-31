import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'seller_cargo_geo_data.dart';
import 'seller_cargo_geocode_queries.dart';
import 'seller_cargo_geocode_suggestion.dart';

abstract final class SellerCargoGeocode {
  static Future<List<SellerCargoGeocodeSuggestion>> fetchAddressSuggestions(
    String query,
  ) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'tr',
      'limit': '12',
      'q': query,
    });

    final response = await http
        .get(uri, headers: SellerCargoGeocodeQueries.headers())
        .timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) {
      return const <SellerCargoGeocodeSuggestion>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <SellerCargoGeocodeSuggestion>[];

    final suggestions = <SellerCargoGeocodeSuggestion>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final lat = double.tryParse((item['lat'] ?? '').toString());
      final lng = double.tryParse((item['lon'] ?? '').toString());
      if (lat == null || lng == null) continue;

      final address = item['address'];
      final addressMap = address is Map
          ? Map<String, dynamic>.from(address)
          : <String, dynamic>{};
      final province = SellerCargoGeocodeQueries.extractProvinceFromAddress(addressMap) ?? '';
      final district = SellerCargoGeocodeQueries.extractDistrictFromAddress(addressMap) ?? '';

      suggestions.add(
        SellerCargoGeocodeSuggestion(
          label: (item['display_name'] ?? '').toString(),
          lat: lat,
          lng: lng,
          province: province,
          district: district,
          category: (item['category'] ?? '').toString(),
          placeType: (item['type'] ?? '').toString(),
          addressType: (item['addresstype'] ?? '').toString(),
        ),
      );
    }
    return suggestions;
  }

  static int scoreSuggestion(
    SellerCargoGeocodeSuggestion suggestion, {
    required String detail,
    required String selectedProvince,
    required String selectedDistrict,
  }) {
    final normalizedDetail = SellerCargoGeocodeQueries.normalizeAddressQueryText(
      detail,
    ).toLowerCase();
    final streetToken = SellerCargoGeocodeQueries.extractStreetToken(normalizedDetail);
    final label = SellerCargoGeocodeQueries.normalizeAddressQueryText(
      suggestion.label,
    ).toLowerCase();
    final category = suggestion.category.toLowerCase();
    final placeType = suggestion.placeType.toLowerCase();
    final addressType = suggestion.addressType.toLowerCase();
    var score = 0;

    if (streetToken != null && streetToken.isNotEmpty) {
      if (label.contains(streetToken)) score += 44;
      if (!label.contains(streetToken) &&
          (addressType == 'road' || category == 'highway')) {
        score += 8;
      }
    }

    final detailTokens = normalizedDetail
        .split(' ')
        .where((e) => e.length > 2)
        .toSet();
    var matches = 0;
    for (final token in detailTokens) {
      if (label.contains(token)) matches++;
    }
    score += matches * 4;

    if (label.contains('sokak') || label.contains('cadde')) score += 20;
    if (addressType == 'road' || category == 'highway') score += 24;
    if (placeType == 'residential') score += 12;

    final districtKey = normalizeLocationText(selectedDistrict);
    final provinceKey = normalizeLocationText(selectedProvince);
    final suggestionDistrictKey = normalizeLocationText(
      suggestion.district,
    );
    final suggestionProvinceKey = normalizeLocationText(
      suggestion.province,
    );

    if (districtKey.isNotEmpty &&
        (label.contains(selectedDistrict.toLowerCase()) ||
            suggestionDistrictKey == districtKey ||
            suggestionDistrictKey.contains(districtKey) ||
            districtKey.contains(suggestionDistrictKey))) {
      score += 10;
    }
    if (provinceKey.isNotEmpty &&
        (label.contains(selectedProvince.toLowerCase()) ||
            suggestionProvinceKey == provinceKey ||
            suggestionProvinceKey.contains(provinceKey) ||
            provinceKey.contains(suggestionProvinceKey))) {
      score += 6;
    }

    if (category == 'tourism' ||
        category == 'amenity' ||
        placeType == 'museum' ||
        placeType == 'attraction') {
      score -= 12;
    }

    return score;
  }

  static String normalizeLocationText(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    normalized = normalized
        .replaceAll(RegExp(r'\bil[iı]\b'), ' ')
        .replaceAll(RegExp(r'\bilce(si)?\b'), ' ')
        .replaceAll(RegExp(r'\bdistrict\b'), ' ')
        .replaceAll(RegExp(r'\bprovince\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  static String? matchProvinceOption(String rawProvince) {
    final normalizedRaw = normalizeLocationText(rawProvince);
    if (normalizedRaw.isEmpty) return null;

    for (final option in SellerCargoGeoData.provinces) {
      final normalizedOption = normalizeLocationText(option);
      if (normalizedOption == normalizedRaw ||
          normalizedRaw.contains(normalizedOption) ||
          normalizedOption.contains(normalizedRaw)) {
        return option;
      }
    }
    return null;
  }

  static String? matchDistrictOption(String rawDistrict, String province) {
    final normalizedRaw = normalizeLocationText(rawDistrict);
    if (normalizedRaw.isEmpty) return null;

    final options = SellerCargoGeoData.districtsFor(province);
    for (final option in options) {
      final normalizedOption = normalizeLocationText(option);
      if (normalizedOption == normalizedRaw ||
          normalizedRaw.contains(normalizedOption) ||
          normalizedOption.contains(normalizedRaw)) {
        return option;
      }
    }

    final splitParts = normalizedRaw
        .split(RegExp(r'[/,\-]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    for (final part in splitParts) {
      for (final option in options) {
        final normalizedOption = normalizeLocationText(option);
        if (normalizedOption == part ||
            part.contains(normalizedOption) ||
            normalizedOption.contains(part)) {
          return option;
        }
      }
    }
    return null;
  }

  static Future<SellerCargoGeocodeSuggestion?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'lat': lat.toString(),
      'lon': lng.toString(),
    });
    final response = await http
        .get(uri, headers: SellerCargoGeocodeQueries.headers())
        .timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map) return null;
    final label = (body['display_name'] ?? '').toString().trim();
    if (label.isEmpty) return null;
    final address = body['address'];
    final addressMap = address is Map
        ? Map<String, dynamic>.from(address)
        : <String, dynamic>{};
    return SellerCargoGeocodeSuggestion(
      label: label,
      lat: lat,
      lng: lng,
      province: SellerCargoGeocodeQueries.extractProvinceFromAddress(addressMap) ?? '',
      district: SellerCargoGeocodeQueries.extractDistrictFromAddress(addressMap) ?? '',
      category: '',
      placeType: '',
      addressType: '',
    );
  }

  static Future<SellerCargoGeocodeSuggestion?> resolveCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 7));
      final reverse = await reverseGeocode(
        lat: pos.latitude,
        lng: pos.longitude,
      ).timeout(const Duration(seconds: 7));
      if (reverse != null) return reverse;

      return SellerCargoGeocodeSuggestion(
        label: '',
        lat: pos.latitude,
        lng: pos.longitude,
        province: '',
        district: '',
        category: '',
        placeType: '',
        addressType: '',
      );
    } catch (_) {
      return null;
    }
  }

  static String mapCreateError(Object error) {
    final raw = error.toString();
    final lowered = raw.toLowerCase();
    if (lowered.contains('insufficient_wallet_balance') ||
        lowered.contains('yetersiz cüzdan') ||
        lowered.contains('yetersiz cuzdan') ||
        lowered.contains('yetersiz bakiye')) {
      return 'Kargo siparisi acmak icin satıcı cüzdan bakiyesi yetersiz. '
          'Lutfen "Bakiye Yukle" butonundan yukleme yapin.';
    }
    if (raw.contains('42P17') ||
        lowered.contains('infinite recursion detected in policy')) {
      return 'Siparis eklenemedi: Backend RLS policy hatasi (42P17). '
          'Lutfen SUPABASE_FIX_IHIZ_POLICY_RECURSION.sql scriptini calistirin.';
    }
    return 'Siparis eklenemedi: $error';
  }
}
