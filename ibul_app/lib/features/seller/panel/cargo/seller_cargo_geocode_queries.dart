import 'package:flutter/foundation.dart';

import 'seller_cargo_geo_data.dart';

abstract final class SellerCargoGeocodeQueries {
  static String normalizeAddressQueryText(String input) {
    var value = input.trim();
    value = value.replaceAll(RegExp(r'[.,;:_\-/#]'), ' ');
    value = value.replaceAll(RegExp(r'(\d+)\s*\.\s*'), r'$1 ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  static String removeHouseNumberFromQuery(String input) {
    var value = input;
    value = value.replaceAll(
      RegExp(r'\bno\s*\d+\w*', caseSensitive: false),
      '',
    );
    value = value.replaceAll(
      RegExp(r'\bnumara\s*\d+\w*', caseSensitive: false),
      '',
    );
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  static String? extractMahalleText(String input) {
    final match = RegExp(
      r'([\wçğıöşüÇĞİÖŞÜ\s]+mahallesi)',
      caseSensitive: false,
    ).firstMatch(input);
    return match?.group(1)?.trim();
  }

  static String? extractStreetToken(String input) {
    final normalized = normalizeAddressQueryText(input).toLowerCase();
    final match = RegExp(
      r'([a-z0-9çğıöşü]+)\s*(sokak|sokağı|cadde|caddesi|bulvar|bulvarı|blv)',
      caseSensitive: false,
    ).firstMatch(normalized);
    return match?.group(1)?.trim();
  }

  static String? extractStreetPhrase(String input) {
    final normalized = normalizeAddressQueryText(input).toLowerCase();
    final all = RegExp(
      r'([a-z0-9çğıöşü\s]{2,60}?\s(?:sokak|sokağı|cadde|caddesi|bulvar|bulvarı|blv))',
      caseSensitive: false,
    ).allMatches(normalized);
    if (all.isEmpty) return null;
    return (all.last.group(1) ?? '').trim();
  }

  static List<String> buildAddressQueries({
    required String detail,
    required String building,
    required String selectedDistrict,
    required String selectedProvince,
  }) {
    final normalizedDetail = normalizeAddressQueryText(detail);
    final detailWithoutNo = removeHouseNumberFromQuery(normalizedDetail);
    final mahalle = extractMahalleText(normalizedDetail);

    final freeText = <String>[
      detail,
      building,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final generic = <String>[
      freeText,
      <String>[
        detail,
        building,
        selectedDistrict,
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
      <String>[
        normalizedDetail,
        selectedDistrict,
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
      <String>[
        detailWithoutNo,
        selectedDistrict,
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
      <String>[
        mahalle ?? '',
        selectedDistrict,
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
      <String>[
        normalizedDetail.isNotEmpty ? normalizedDetail : detail,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
      <String>[
        detailWithoutNo,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
      <String>[
        mahalle ?? '',
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
    ];

    final deduped = <String>[];
    for (final query in generic) {
      final normalized = query.trim();
      if (normalized.length < 6) continue;
      if (!deduped.contains(normalized)) deduped.add(normalized);
    }
    return deduped;
  }

  static List<String> buildStreetFocusedQueries({
    required String normalizedDetail,
    required String building,
    required String selectedDistrict,
    required String selectedProvince,
  }) {
    final streetPhrase = extractStreetPhrase(normalizedDetail);
    if (streetPhrase == null || streetPhrase.isEmpty) return const <String>[];

    final mahalle = extractMahalleText(normalizedDetail);
    final districtCandidates = <String>{};
    if (selectedDistrict.trim().isNotEmpty) {
      districtCandidates.add(selectedDistrict.trim());
    }
    if (building.trim().isNotEmpty && building.trim().length <= 32) {
      districtCandidates.add(building.trim());
    }

    final normalizedDetailLower = normalizedDetail.toLowerCase();
    for (final district in SellerCargoGeoData.districtsFor(selectedProvince)) {
      if (normalizedDetailLower.contains(district.toLowerCase())) {
        districtCandidates.add(district);
      }
    }

    final queries = <String>[];
    for (final district in districtCandidates) {
      queries.add(
        <String>[
          streetPhrase,
          mahalle ?? '',
          district,
          selectedProvince,
          'Türkiye',
        ].where((e) => e.isNotEmpty).join(', '),
      );
      queries.add(
        <String>[
          streetPhrase,
          district,
          selectedProvince,
          'Türkiye',
        ].where((e) => e.isNotEmpty).join(', '),
      );
    }

    queries.add(
      <String>[
        streetPhrase,
        mahalle ?? '',
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
    );
    queries.add(
      <String>[
        streetPhrase,
        selectedProvince,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
    );

    final deduped = <String>[];
    for (final query in queries) {
      final normalized = query.trim();
      if (normalized.length < 6) continue;
      if (!deduped.contains(normalized)) deduped.add(normalized);
    }
    return deduped;
  }

  static Map<String, String> headers() {
    if (kIsWeb) {
      return const <String, String>{};
    }
    return const <String, String>{
      'User-Agent': 'ibul-seller-cargo-address/1.0',
      'Accept-Language': 'tr',
    };
  }

  static String? extractProvinceFromAddress(Map<String, dynamic> address) {
    final state = (address['state'] ?? '').toString().trim();
    if (state.isNotEmpty) return state;
    final city = (address['city'] ?? '').toString().trim();
    if (city.isNotEmpty) return city;
    final province = (address['province'] ?? '').toString().trim();
    if (province.isNotEmpty) return province;
    return null;
  }

  static String? extractDistrictFromAddress(Map<String, dynamic> address) {
    final cityDistrict = (address['city_district'] ?? '').toString().trim();
    if (cityDistrict.isNotEmpty) return cityDistrict;
    final county = (address['county'] ?? '').toString().trim();
    if (county.isNotEmpty) return county;
    final district = (address['district'] ?? '').toString().trim();
    if (district.isNotEmpty) return district;
    final town = (address['town'] ?? '').toString().trim();
    if (town.isNotEmpty) return town;
    return null;
  }
}
