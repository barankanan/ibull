import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

class AddressEditSheet extends StatefulWidget {
  final Map<String, String>? initialData;
  final String type;
  final FutureOr<void> Function(Map<String, String>) onSave;
  final VoidCallback onDelete;

  const AddressEditSheet({
    super.key,
    this.initialData,
    required this.type,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<AddressEditSheet> createState() => _AddressEditSheetState();
}

class _AddressEditSheetState extends State<AddressEditSheet> {
  final MapController _previewMapController = MapController();
  late TextEditingController _titleController;
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _phoneController;
  late TextEditingController _buildingController;
  late TextEditingController _detailController;

  String _addressType = 'Ev';
  String _selectedProvince = 'İstanbul';
  String _selectedDistrict = 'Kadıköy';

  bool _showProvinceOptions = false;
  bool _showDistrictOptions = false;

  double? _selectedLat;
  double? _selectedLng;
  LatLng? _previewCenter;
  bool _isAddressVerified = false;
  String? _verifiedAddressText;
  bool _isResolvingRegionCenter = false;

  Timer? _addressLookupDebounce;
  int _addressLookupRequestId = 0;
  bool _isSearchingAddress = false;
  List<_GeocodeSuggestion> _addressSuggestions = <_GeocodeSuggestion>[];

  static const List<String> _provinceOptions = <String>[
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Aksaray',
    'Amasya',
    'Ankara',
    'Antalya',
    'Ardahan',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bartın',
    'Batman',
    'Bayburt',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Düzce',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkari',
    'Hatay',
    'Iğdır',
    'Isparta',
    'İstanbul',
    'İzmir',
    'Kahramanmaraş',
    'Karabük',
    'Karaman',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırıkkale',
    'Kırklareli',
    'Kırşehir',
    'Kilis',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Mardin',
    'Mersin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Osmaniye',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Şanlıurfa',
    'Şırnak',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Uşak',
    'Van',
    'Yalova',
    'Yozgat',
    'Zonguldak',
  ];

  static const Map<String, List<String>> _districtsByProvince =
      <String, List<String>>{
        'İstanbul': <String>[
          'Adalar',
          'Arnavutköy',
          'Ataşehir',
          'Avcılar',
          'Bağcılar',
          'Bahçelievler',
          'Bakırköy',
          'Başakşehir',
          'Bayrampaşa',
          'Beşiktaş',
          'Beykoz',
          'Beylikdüzü',
          'Beyoğlu',
          'Büyükçekmece',
          'Çatalca',
          'Çekmeköy',
          'Esenler',
          'Esenyurt',
          'Eyüpsultan',
          'Fatih',
          'Gaziosmanpaşa',
          'Güngören',
          'Kadıköy',
          'Kağıthane',
          'Kartal',
          'Küçükçekmece',
          'Maltepe',
          'Pendik',
          'Sancaktepe',
          'Sarıyer',
          'Silivri',
          'Sultanbeyli',
          'Sultangazi',
          'Şile',
          'Şişli',
          'Tuzla',
          'Ümraniye',
          'Üsküdar',
          'Zeytinburnu',
        ],
        'Ankara': <String>[
          'Altındağ',
          'Ayaş',
          'Bala',
          'Beypazarı',
          'Çankaya',
          'Etimesgut',
          'Gölbaşı',
          'Kahramankazan',
          'Keçiören',
          'Mamak',
          'Polatlı',
          'Sincan',
          'Yenimahalle',
        ],
        'İzmir': <String>[
          'Aliağa',
          'Balçova',
          'Bayraklı',
          'Bornova',
          'Buca',
          'Çeşme',
          'Gaziemir',
          'Karabağlar',
          'Karşıyaka',
          'Konak',
          'Menemen',
          'Narlıdere',
          'Torbalı',
        ],
        'Bursa': <String>[
          'Gemlik',
          'Gürsu',
          'İnegöl',
          'Mudanya',
          'Nilüfer',
          'Osmangazi',
          'Yıldırım',
        ],
        'Antalya': <String>[
          'Aksu',
          'Alanya',
          'Döşemealtı',
          'Kepez',
          'Konyaaltı',
          'Kumluca',
          'Manavgat',
          'Muratpaşa',
          'Serik',
        ],
        'Adana': <String>[
          'Çukurova',
          'Sarıçam',
          'Seyhan',
          'Yüreğir',
          'Ceyhan',
          'Kozan',
        ],
        'Mersin': <String>[
          'Akdeniz',
          'Erdemli',
          'Mezitli',
          'Silifke',
          'Tarsus',
          'Toroslar',
          'Yenişehir',
        ],
        'Kocaeli': <String>[
          'Başiskele',
          'Çayırova',
          'Darıca',
          'Derince',
          'Gebze',
          'Gölcük',
          'İzmit',
          'Karamürsel',
          'Kartepe',
          'Körfez',
        ],
        'Konya': <String>[
          'Akşehir',
          'Beyşehir',
          'Ereğli',
          'Karatay',
          'Meram',
          'Selçuklu',
        ],
        'Gaziantep': <String>[
          'Araban',
          'İslahiye',
          'Nizip',
          'Nurdağı',
          'Oğuzeli',
          'Şahinbey',
          'Şehitkamil',
        ],
        'Hatay': <String>[
          'Antakya',
          'Arsuz',
          'Defne',
          'Dörtyol',
          'İskenderun',
          'Kırıkhan',
          'Samandağ',
        ],
      };

  static const Map<String, LatLng> _provinceCenters = <String, LatLng>{
    'İstanbul': LatLng(41.0082, 28.9784),
    'Ankara': LatLng(39.9334, 32.8597),
    'İzmir': LatLng(38.4237, 27.1428),
    'Bursa': LatLng(40.1828, 29.0663),
    'Antalya': LatLng(36.8969, 30.7133),
    'Adana': LatLng(37.0017, 35.3289),
    'Mersin': LatLng(36.8121, 34.6415),
    'Kocaeli': LatLng(40.7654, 29.9408),
    'Konya': LatLng(37.8746, 32.4932),
    'Gaziantep': LatLng(37.0662, 37.3833),
    'Hatay': LatLng(36.2021, 36.1606),
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialData?['title'] ?? '',
    );
    _detailController = TextEditingController(
      text: widget.initialData?['detail'] ?? '',
    );
    _nameController = TextEditingController(
      text: widget.initialData?['name'] ?? '',
    );
    _surnameController = TextEditingController(
      text: widget.initialData?['surname'] ?? '',
    );
    _phoneController = TextEditingController(
      text: _normalizeDigits(widget.initialData?['phone'] ?? ''),
    );
    _buildingController = TextEditingController(
      text: widget.initialData?['building'] ?? '',
    );
    _addressType =
        widget.initialData?['addressType'] ??
        widget.initialData?['title'] ??
        'Ev';

    _hydrateInitialLocationValues();
    _detailController.addListener(_onAddressDetailChanged);
  }

  @override
  void dispose() {
    _addressLookupDebounce?.cancel();
    _detailController.removeListener(_onAddressDetailChanged);

    _titleController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _buildingController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _hydrateInitialLocationValues() {
    final initial = widget.initialData;
    final rawProvince = (initial?['province'] ?? '').trim();
    final rawCity = (initial?['city'] ?? '').trim();
    final parsedCityParts = _splitCityValue(rawCity);

    final provinceCandidate = rawProvince.isNotEmpty
        ? rawProvince
        : (parsedCityParts.$1 ?? (rawCity.isNotEmpty ? rawCity : 'İstanbul'));

    _selectedProvince = _provinceOptions.contains(provinceCandidate)
        ? provinceCandidate
        : 'İstanbul';

    final rawDistrict = (initial?['district'] ?? '').trim();
    final districtCandidate = rawDistrict.isNotEmpty
        ? rawDistrict
        : (parsedCityParts.$2 ??
              _defaultDistrictForProvince(_selectedProvince));
    _selectedDistrict = districtCandidate;

    _selectedLat = _tryParseDouble(initial?['lat'] ?? initial?['latitude']);
    _selectedLng = _tryParseDouble(initial?['lng'] ?? initial?['longitude']);
    _verifiedAddressText = (initial?['mapAddress'] ?? '').trim();
    _isAddressVerified = _selectedLat != null && _selectedLng != null;
    _previewCenter = (_selectedLat != null && _selectedLng != null)
        ? LatLng(_selectedLat!, _selectedLng!)
        : (_provinceCenters[_selectedProvince] ?? const LatLng(39.0, 35.0));
  }

  (String?, String?) _splitCityValue(String cityValue) {
    final normalized = cityValue.trim();
    if (normalized.isEmpty) return (null, null);

    if (normalized.contains('/')) {
      final parts = normalized
          .split('/')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (parts.isNotEmpty) {
        return (
          parts.first,
          parts.length > 1 ? parts.sublist(1).join(' / ') : null,
        );
      }
    }

    if (normalized.contains(',')) {
      final parts = normalized
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (parts.isNotEmpty) {
        return (
          parts.first,
          parts.length > 1 ? parts.sublist(1).join(', ') : null,
        );
      }
    }

    return (normalized, null);
  }

  String _defaultDistrictForProvince(String province) {
    final options = _districtOptionsForProvince(province);
    return options.isNotEmpty ? options.first : 'Merkez';
  }

  List<String> _districtOptionsForProvince(String province) {
    final options = _districtsByProvince[province];
    if (options == null || options.isEmpty) {
      return <String>['Merkez'];
    }
    return List<String>.from(options);
  }

  String _normalizeDigits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  double? _tryParseDouble(String? value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.trim());
    return parsed;
  }

  void _setPreviewCenter(LatLng center, {double zoom = 12}) {
    _previewCenter = center;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _previewMapController.move(center, zoom);
      } catch (_) {
        // Harita henüz hazır değilse bir sonraki rebuild'de initialCenter uygulanır.
      }
    });
  }

  Future<void> _focusMapToSelectedRegion({
    bool clearPickedPoint = false,
  }) async {
    if (clearPickedPoint) {
      setState(() {
        _selectedLat = null;
        _selectedLng = null;
        _isAddressVerified = false;
      });
    }

    final provinceFallback =
        _provinceCenters[_selectedProvince] ?? const LatLng(39.0, 35.0);
    if (mounted) {
      setState(() {
        _isResolvingRegionCenter = true;
      });
    }
    _setPreviewCenter(provinceFallback, zoom: 10.8);

    try {
      final regionQuery = <String>[
        _selectedDistrict.trim(),
        _selectedProvince.trim(),
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', ');

      final items = await _fetchAddressSuggestionsForQuery(regionQuery);
      if (!mounted) return;
      if (items.isNotEmpty) {
        final center = LatLng(items.first.lat, items.first.lng);
        setState(() {
          _previewCenter = center;
        });
        _setPreviewCenter(center, zoom: 12.8);
      }
    } catch (_) {
      // Fallback merkezi zaten uygulandı.
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingRegionCenter = false;
        });
      }
    }
  }

  String _normalizeAddressQueryText(String input) {
    var value = input.trim();
    value = value.replaceAll(RegExp(r'[.,;:_\-/#]'), ' ');
    value = value.replaceAll(RegExp(r'(\d+)\s*\.\s*'), r'$1 ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  String _removeHouseNumberFromQuery(String input) {
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

  String? _extractMahalleText(String input) {
    final match = RegExp(
      r'([\wçğıöşüÇĞİÖŞÜ\s]+mahallesi)',
      caseSensitive: false,
    ).firstMatch(input);
    if (match == null) return null;
    return match.group(1)?.trim();
  }

  String? _extractStreetToken(String input) {
    final normalized = _normalizeAddressQueryText(input).toLowerCase();
    final match = RegExp(
      r'([a-z0-9çğıöşü]+)\s*(sokak|sokağı|cadde|caddesi|bulvar|bulvarı|blv)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    final token = (match.group(1) ?? '').trim();
    return token.isEmpty ? null : token;
  }

  String? _extractStreetPhrase(String input) {
    final normalized = _normalizeAddressQueryText(input).toLowerCase();
    final all = RegExp(
      r'([a-z0-9çğıöşü\s]{2,60}?\s(?:sokak|sokağı|cadde|caddesi|bulvar|bulvarı|blv))',
      caseSensitive: false,
    ).allMatches(normalized);
    if (all.isEmpty) return null;
    final phrase = (all.last.group(1) ?? '').trim();
    return phrase.isEmpty ? null : phrase;
  }

  List<String> _buildStreetFocusedQueries({required String normalizedDetail}) {
    final streetPhrase = _extractStreetPhrase(normalizedDetail);
    if (streetPhrase == null || streetPhrase.isEmpty) return const <String>[];

    final province = _selectedProvince.trim();
    final selectedDistrict = _selectedDistrict.trim();
    final buildingText = _buildingController.text.trim();
    final mahalle = _extractMahalleText(normalizedDetail);

    final districtCandidates = <String>{};
    if (selectedDistrict.isNotEmpty) districtCandidates.add(selectedDistrict);

    if (buildingText.isNotEmpty && buildingText.length <= 32) {
      districtCandidates.add(buildingText);
    }

    final normalizedDetailLower = normalizedDetail.toLowerCase();
    for (final district in _districtOptionsForProvince(_selectedProvince)) {
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
          province,
          'Türkiye',
        ].where((e) => e.isNotEmpty).join(', '),
      );
      queries.add(
        <String>[
          streetPhrase,
          district,
          province,
          'Türkiye',
        ].where((e) => e.isNotEmpty).join(', '),
      );
    }

    queries.add(
      <String>[
        streetPhrase,
        mahalle ?? '',
        province,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
    );
    queries.add(
      <String>[
        streetPhrase,
        province,
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', '),
    );

    final deduped = <String>[];
    for (final query in queries) {
      if (query.length < 6) continue;
      if (!deduped.contains(query)) deduped.add(query);
    }
    return deduped;
  }

  int _scoreSuggestion(
    _GeocodeSuggestion suggestion, {
    required String normalizedDetail,
    String? streetToken,
  }) {
    final label = _normalizeAddressQueryText(suggestion.label).toLowerCase();
    final category = suggestion.category.toLowerCase();
    final placeType = suggestion.placeType.toLowerCase();
    final addressType = suggestion.addressType.toLowerCase();
    var score = 0;

    if (streetToken != null && streetToken.isNotEmpty) {
      if (label.contains(streetToken)) score += 45;
      if (!label.contains(streetToken) &&
          (addressType == 'road' || category == 'highway')) {
        score += 8;
      }
    }

    if (normalizedDetail.isNotEmpty) {
      final detailTokens = normalizedDetail
          .toLowerCase()
          .split(' ')
          .where((e) => e.length > 2)
          .toSet();
      var tokenMatches = 0;
      for (final token in detailTokens) {
        if (label.contains(token)) tokenMatches++;
      }
      score += tokenMatches * 4;
    }

    if (label.contains('sokak') || label.contains('cadde')) score += 20;
    if (addressType == 'road' || category == 'highway') score += 26;
    if (placeType == 'residential') score += 12;

    if (label.contains(_selectedDistrict.toLowerCase())) score += 8;
    if (label.contains(_selectedProvince.toLowerCase())) score += 4;

    if (category == 'tourism' ||
        category == 'amenity' ||
        placeType == 'museum' ||
        placeType == 'attraction') {
      score -= 14;
    }

    return score;
  }

  void _onAddressDetailChanged() {
    final typed = _detailController.text.trim();
    if (typed.length < 6) {
      _addressLookupDebounce?.cancel();
      setState(() {
        _isSearchingAddress = false;
        _addressSuggestions = <_GeocodeSuggestion>[];
      });
      return;
    }

    _addressLookupDebounce?.cancel();
    _addressLookupDebounce = Timer(const Duration(milliseconds: 550), () {
      unawaited(_lookupAddressSuggestions());
    });
  }

  String _normalizeForMatch(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _removeProvinceDistrictTokens(String detail) {
    final normalizedDetail = _normalizeAddressQueryText(detail);
    var result = normalizedDetail;
    final provinceNeedle = _normalizeForMatch(_selectedProvince);
    final districtNeedle = _normalizeForMatch(_selectedDistrict);

    String stripToken(String source, String token) {
      if (token.isEmpty) return source;
      final parts = source
          .split(' ')
          .where((part) => _normalizeForMatch(part) != token)
          .toList(growable: false);
      return parts.join(' ').trim();
    }

    result = stripToken(result, provinceNeedle);
    result = stripToken(result, districtNeedle);
    return _normalizeAddressQueryText(result);
  }

  List<String> _buildAddressQueries() {
    final detail = _detailController.text.trim();
    final normalizedDetail = _normalizeAddressQueryText(detail);
    final cleanedDetail = _removeProvinceDistrictTokens(normalizedDetail);
    final detailWithoutNo = _removeHouseNumberFromQuery(normalizedDetail);
    final cleanedWithoutNo = _removeHouseNumberFromQuery(cleanedDetail);
    final mahalleText = _extractMahalleText(normalizedDetail);
    final cleanedMahalleText = _extractMahalleText(cleanedDetail);
    final building = _buildingController.text.trim();
    final district = _selectedDistrict.trim();
    final province = _selectedProvince.trim();

    final freeText = <String>[
      detail,
      building,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final regional = <String>[
      detail,
      building,
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final normalizedRegional = <String>[
      normalizedDetail,
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final cleanedRegional = <String>[
      cleanedDetail,
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final noHouseRegional = <String>[
      detailWithoutNo,
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final cleanedNoHouseRegional = <String>[
      cleanedWithoutNo,
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final mahalleRegional = <String>[
      mahalleText ?? '',
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final cleanedMahalleRegional = <String>[
      cleanedMahalleText ?? '',
      district,
      province,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final bare = <String>[
      normalizedDetail.isNotEmpty ? normalizedDetail : detail,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final cleanedBare = <String>[
      cleanedDetail.isNotEmpty ? cleanedDetail : detail,
      'Türkiye',
    ].where((e) => e.isNotEmpty).join(', ');

    final ordered = <String>[
      freeText,
      regional,
      normalizedRegional,
      cleanedRegional,
      noHouseRegional,
      cleanedNoHouseRegional,
      mahalleRegional,
      cleanedMahalleRegional,
      bare,
      cleanedBare,
    ];
    final deduped = <String>[];
    for (final query in ordered) {
      if (query.length < 6) continue;
      if (!deduped.contains(query)) {
        deduped.add(query);
      }
    }
    return deduped;
  }

  Map<String, String> _geocodeHeaders() {
    // Browser side'da User-Agent gibi başlıklar engellenebilir.
    if (kIsWeb) {
      return const <String, String>{};
    }
    return const <String, String>{
      'User-Agent': 'ibul-app-address-editor/1.0',
      'Accept-Language': 'tr',
    };
  }

  Future<List<_GeocodeSuggestion>> _fetchAddressSuggestionsForQuery(
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
        .get(uri, headers: _geocodeHeaders())
        .timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) return <_GeocodeSuggestion>[];

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return <_GeocodeSuggestion>[];

    final suggestions = <_GeocodeSuggestion>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final lat = double.tryParse((item['lat'] ?? '').toString());
      final lng = double.tryParse((item['lon'] ?? '').toString());
      if (lat == null || lng == null) continue;

      final address = item['address'];
      Map<String, dynamic> addressMap = <String, dynamic>{};
      if (address is Map) {
        addressMap = Map<String, dynamic>.from(address);
      }

      final province =
          _extractProvinceFromAddress(addressMap) ?? _selectedProvince;
      final district =
          _extractDistrictFromAddress(addressMap) ?? _selectedDistrict;

      suggestions.add(
        _GeocodeSuggestion(
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

  Future<void> _lookupAddressSuggestions() async {
    final normalizedDetail = _normalizeAddressQueryText(_detailController.text);
    final cleanedDetail = _removeProvinceDistrictTokens(normalizedDetail);
    final scoringBase = cleanedDetail.isNotEmpty
        ? cleanedDetail
        : normalizedDetail;
    final streetToken = _extractStreetToken(scoringBase);
    final streetQueries = _buildStreetFocusedQueries(
      normalizedDetail: scoringBase,
    );
    final genericQueries = _buildAddressQueries();
    final queries = <String>{
      ...streetQueries,
      ...genericQueries,
    }.toList(growable: false);
    if (queries.isEmpty) return;

    final requestId = ++_addressLookupRequestId;
    if (mounted) {
      setState(() {
        _isSearchingAddress = true;
      });
    }

    try {
      final suggestions = <_GeocodeSuggestion>[];
      final maxRequests = streetToken == null ? 4 : 6;
      final effectiveQueries = queries.take(maxRequests);
      for (final query in effectiveQueries) {
        final batch = await _fetchAddressSuggestionsForQuery(query);
        if (!mounted || requestId != _addressLookupRequestId) return;
        if (batch.isNotEmpty) {
          suggestions.addAll(batch);
        }
        if (suggestions.length >= 24) break;

        if (streetToken != null) {
          final hasStrongStreet = suggestions.any(
            (s) =>
                _scoreSuggestion(
                  s,
                  normalizedDetail: normalizedDetail,
                  streetToken: streetToken,
                ) >=
                70,
          );
          if (hasStrongStreet && suggestions.length >= 8) break;
        }
      }

      final deduped = <String, _GeocodeSuggestion>{};
      for (final suggestion in suggestions) {
        final key = [
          suggestion.lat.toStringAsFixed(6),
          suggestion.lng.toStringAsFixed(6),
          suggestion.label.toLowerCase(),
        ].join('_');
        deduped.putIfAbsent(key, () => suggestion);
      }
      final sorted = deduped.values.toList(growable: false)
        ..sort(
          (a, b) =>
              _scoreSuggestion(
                b,
                normalizedDetail: scoringBase,
                streetToken: streetToken,
              ).compareTo(
                _scoreSuggestion(
                  a,
                  normalizedDetail: scoringBase,
                  streetToken: streetToken,
                ),
              ),
        );

      setState(() {
        _isSearchingAddress = false;
        _addressSuggestions = sorted.take(8).toList(growable: false);
      });
    } catch (_) {
      if (!mounted || requestId != _addressLookupRequestId) return;
      setState(() {
        _isSearchingAddress = false;
        _addressSuggestions = <_GeocodeSuggestion>[];
      });
    }
  }

  String? _extractProvinceFromAddress(Map<String, dynamic> address) {
    final state = (address['state'] ?? '').toString().trim();
    if (state.isNotEmpty) return state;

    final city = (address['city'] ?? '').toString().trim();
    if (city.isNotEmpty) return city;

    final province = (address['province'] ?? '').toString().trim();
    if (province.isNotEmpty) return province;

    return null;
  }

  String? _extractDistrictFromAddress(Map<String, dynamic> address) {
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

  void _applySuggestion(_GeocodeSuggestion suggestion) {
    setState(() {
      _selectedLat = suggestion.lat;
      _selectedLng = suggestion.lng;
      _verifiedAddressText = suggestion.label;
      _isAddressVerified = true;

      if (_provinceOptions.contains(suggestion.province)) {
        _selectedProvince = suggestion.province;
      }

      if (suggestion.district.trim().isNotEmpty) {
        _selectedDistrict = suggestion.district.trim();
      }

      _addressSuggestions = <_GeocodeSuggestion>[];
      _showProvinceOptions = false;
      _showDistrictOptions = false;
    });
    _setPreviewCenter(LatLng(suggestion.lat, suggestion.lng), zoom: 15.2);
  }

  Future<void> _reverseGeocodeFromPoint({
    required double lat,
    required double lng,
    bool enrichDetailIfEmpty = false,
  }) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'addressdetails': '1',
        'lat': lat.toString(),
        'lon': lng.toString(),
      });

      final response = await http
          .get(uri, headers: _geocodeHeaders())
          .timeout(const Duration(seconds: 7));

      if (!mounted || response.statusCode != 200) return;

      final body = jsonDecode(response.body);
      if (body is! Map) return;

      final addressMap = body['address'] is Map
          ? Map<String, dynamic>.from(body['address'] as Map)
          : <String, dynamic>{};

      final province = _extractProvinceFromAddress(addressMap);
      final district = _extractDistrictFromAddress(addressMap);
      final label = (body['display_name'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        if (province != null && _provinceOptions.contains(province)) {
          _selectedProvince = province;
        }
        if (district != null && district.isNotEmpty) {
          _selectedDistrict = district;
        }
        if (label.isNotEmpty) {
          _verifiedAddressText = label;
        }
        _isAddressVerified = true;
      });

      if (enrichDetailIfEmpty &&
          _detailController.text.trim().isEmpty &&
          label.isNotEmpty) {
        _detailController.text = label;
      }
    } catch (_) {
      // Sessiz geç: koordinat zaten kullanıcı tarafından seçildi.
    }
  }

  Future<void> _openMapPicker() async {
    final fallbackCenter =
        _provinceCenters[_selectedProvince] ?? const LatLng(39.0, 35.0);
    final initialPoint = (_selectedLat != null && _selectedLng != null)
        ? LatLng(_selectedLat!, _selectedLng!)
        : fallbackCenter;

    final selected = await showDialog<LatLng>(
      context: context,
      builder: (context) => _AddressMapPickerDialog(initialPoint: initialPoint),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedLat = selected.latitude;
      _selectedLng = selected.longitude;
      _isAddressVerified = true;
      _addressSuggestions = <_GeocodeSuggestion>[];
    });
    _setPreviewCenter(
      LatLng(selected.latitude, selected.longitude),
      zoom: 15.2,
    );

    await _reverseGeocodeFromPoint(
      lat: selected.latitude,
      lng: selected.longitude,
      enrichDetailIfEmpty: true,
    );
  }

  Future<void> _chooseCustomDistrict() async {
    final controller = TextEditingController();
    final district = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('İlçe Gir'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'İlçe adını yazın'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Seç'),
            ),
          ],
        );
      },
    );

    final value = (district ?? '').trim();
    if (value.isEmpty || !mounted) return;

    setState(() {
      _selectedDistrict = value;
      _showDistrictOptions = false;
    });
    unawaited(_focusMapToSelectedRegion(clearPickedPoint: true));
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveAddress({required bool isAddress}) async {
    final title = _titleController.text.trim();
    final detail = _detailController.text.trim();
    final phone = _normalizeDigits(_phoneController.text);

    if (title.isEmpty || detail.isEmpty) {
      _showValidationError('Lütfen zorunlu alanları doldurun');
      return;
    }

    if (phone.length < 10 || phone.length > 11) {
      _showValidationError('Telefon numarası 10 veya 11 haneli olmalıdır');
      return;
    }

    if (isAddress) {
      if (_selectedProvince.trim().isEmpty ||
          _selectedDistrict.trim().isEmpty) {
        _showValidationError('Lütfen il ve ilçe seçin');
        return;
      }
      if (_selectedLat == null || _selectedLng == null) {
        _showValidationError(
          'İHIZ teslimatı için adresi haritadan doğrulamanız gerekir',
        );
        return;
      }
    }

    final lat = _selectedLat?.toStringAsFixed(6) ?? '';
    final lng = _selectedLng?.toStringAsFixed(6) ?? '';
    final hasLocation = lat.isNotEmpty && lng.isNotEmpty;

    final payload = <String, String>{
      'title': title,
      'name': _nameController.text.trim(),
      'surname': _surnameController.text.trim(),
      'phone': phone,
      'city': _selectedProvince,
      'province': _selectedProvince,
      'district': _selectedDistrict,
      'building': _buildingController.text.trim(),
      'detail': detail,
      'addressType': _addressType,
      'lat': lat,
      'lng': lng,
      'latitude': lat,
      'longitude': lng,
      'mapAddress': _verifiedAddressText?.trim() ?? '',
      'isMapVerified': hasLocation ? 'true' : 'false',
    };

    try {
      await widget.onSave(payload);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showValidationError('Adres kaydedilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;
    final isAddress = widget.type == 'Adres';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing
                      ? '${widget.type} Düzenle'
                      : 'Yeni ${widget.type} Ekle',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Ad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _surnameController,
                    decoration: InputDecoration(
                      labelText: 'Soyad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                labelText: 'Telefon Numarası',
                hintText: '05XXXXXXXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                prefixIcon: const Icon(
                  Icons.phone_android,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (isAddress) ...[
              const Text(
                'Ev Bilginiz',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTypeSelection('Ev', Icons.home)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTypeSelection('İş Yeri', Icons.work)),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: _buildSelectorButton(
                    label: 'İl',
                    value: _selectedProvince,
                    icon: Icons.location_city,
                    isOpen: _showProvinceOptions,
                    onTap: () {
                      setState(() {
                        _showProvinceOptions = !_showProvinceOptions;
                        _showDistrictOptions = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectorButton(
                    label: 'İlçe',
                    value: _selectedDistrict,
                    icon: Icons.map_outlined,
                    isOpen: _showDistrictOptions,
                    onTap: () {
                      setState(() {
                        _showDistrictOptions = !_showDistrictOptions;
                        _showProvinceOptions = false;
                      });
                    },
                  ),
                ),
              ],
            ),

            if (_showProvinceOptions)
              _buildInlineOptions(
                options: _provinceOptions,
                onSelected: (province) {
                  final nextDistricts = _districtOptionsForProvince(province);
                  setState(() {
                    _selectedProvince = province;
                    if (!nextDistricts.contains(_selectedDistrict)) {
                      _selectedDistrict = nextDistricts.isNotEmpty
                          ? nextDistricts.first
                          : 'Merkez';
                    }
                    _showProvinceOptions = false;
                  });
                  unawaited(_focusMapToSelectedRegion(clearPickedPoint: true));
                },
              ),

            if (_showDistrictOptions)
              _buildInlineOptions(
                options: <String>[
                  ..._effectiveDistrictOptions(),
                  'İlçe Yaz...',
                ],
                onSelected: (district) {
                  if (district == 'İlçe Yaz...') {
                    unawaited(_chooseCustomDistrict());
                    return;
                  }
                  setState(() {
                    _selectedDistrict = district;
                    _showDistrictOptions = false;
                  });
                  unawaited(_focusMapToSelectedRegion(clearPickedPoint: true));
                },
              ),

            const SizedBox(height: 16),

            TextField(
              controller: _buildingController,
              decoration: InputDecoration(
                labelText: 'Bina, Site, İş Yeri, Kurum İsmi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _detailController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Açık Adres (Mahalle, Sokak, Kapı No)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            if (_isSearchingAddress) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],

            if (_addressSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _addressSuggestions.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final suggestion = _addressSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        suggestion.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      onTap: () => _applySuggestion(suggestion),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),
            _buildMapPreviewCard(),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Bu Adrese İsim Ver (Örn: Evim, Ofisim)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                prefixIcon: const Icon(
                  Icons.bookmark_border,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                if (isEditing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onDelete();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Sil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (isEditing) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveAddress(isAddress: isAddress),
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(isEditing ? 'Güncelle' : 'Kaydet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<String> _effectiveDistrictOptions() {
    final options = _districtOptionsForProvince(_selectedProvince);
    if (_selectedDistrict.trim().isNotEmpty &&
        !options.contains(_selectedDistrict)) {
      return <String>[_selectedDistrict, ...options];
    }
    return options;
  }

  Widget _buildSelectorButton({
    required String label,
    required String value,
    required IconData icon,
    required bool isOpen,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOpen ? AppColors.primary : Colors.grey.shade400,
            width: isOpen ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineOptions({
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final value = options[index];
          return InkWell(
            onTap: () => onSelected(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapPreviewCard() {
    final hasPoint = _selectedLat != null && _selectedLng != null;
    final mapCenter = hasPoint
        ? LatLng(_selectedLat!, _selectedLng!)
        : (_previewCenter ??
              _provinceCenters[_selectedProvince] ??
              const LatLng(39.0, 35.0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isAddressVerified
              ? Colors.green.shade300
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isAddressVerified ? Icons.verified : Icons.gps_not_fixed,
                size: 18,
                color: _isAddressVerified
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isAddressVerified
                      ? 'Adres haritada doğrulandı'
                      : 'Adresi haritada doğrulayın',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _isAddressVerified
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Haritadan Seç'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          if (_isResolvingRegionCenter) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 6),
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                key: ValueKey<String>(
                  'preview_${_selectedProvince}_${_selectedDistrict}_${mapCenter.latitude.toStringAsFixed(4)}_${mapCenter.longitude.toStringAsFixed(4)}_${hasPoint ? 1 : 0}',
                ),
                mapController: _previewMapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: hasPoint ? 15.5 : 11,
                  onTap: (_, latLng) {
                    setState(() {
                      _selectedLat = latLng.latitude;
                      _selectedLng = latLng.longitude;
                      _isAddressVerified = true;
                      _addressSuggestions = <_GeocodeSuggestion>[];
                    });
                    _setPreviewCenter(
                      LatLng(latLng.latitude, latLng.longitude),
                      zoom: 15.2,
                    );
                    unawaited(
                      _reverseGeocodeFromPoint(
                        lat: latLng.latitude,
                        lng: latLng.longitude,
                        enrichDetailIfEmpty: true,
                      ),
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ibul.app',
                  ),
                  if (hasPoint)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 42,
                          height: 42,
                          point: LatLng(_selectedLat!, _selectedLng!),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (_verifiedAddressText != null &&
              _verifiedAddressText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _verifiedAddressText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
          if (hasPoint) ...[
            const SizedBox(height: 6),
            Text(
              'Konum: ${_selectedLat!.toStringAsFixed(5)}, ${_selectedLng!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelection(String label, IconData icon) {
    final isSelected = _addressType == label;
    return InkWell(
      onTap: () {
        setState(() {
          _addressType = label;
          if (_titleController.text.isEmpty ||
              _titleController.text == 'Ev' ||
              _titleController.text == 'İş Yeri') {
            _titleController.text = label;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeocodeSuggestion {
  final String label;
  final double lat;
  final double lng;
  final String province;
  final String district;
  final String category;
  final String placeType;
  final String addressType;

  const _GeocodeSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    required this.province,
    required this.district,
    required this.category,
    required this.placeType,
    required this.addressType,
  });
}

class _AddressMapPickerDialog extends StatefulWidget {
  final LatLng initialPoint;

  const _AddressMapPickerDialog({required this.initialPoint});

  @override
  State<_AddressMapPickerDialog> createState() =>
      _AddressMapPickerDialogState();
}

class _AddressMapPickerDialogState extends State<_AddressMapPickerDialog> {
  late LatLng _selectedPoint;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 620,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Haritadan Adres Seç',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 15,
                      onTap: (_, latLng) {
                        setState(() {
                          _selectedPoint = latLng;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ibul.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 46,
                            height: 46,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedPoint.latitude.toStringAsFixed(5)}, ${_selectedPoint.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _selectedPoint),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Bu Konumu Kullan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
