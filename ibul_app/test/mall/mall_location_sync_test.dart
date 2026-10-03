import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/turkiye_location_data.dart';
import 'package:ibul_app/features/mall/widgets/mall_location_picker.dart';
import 'package:ibul_app/features/mall/widgets/mall_location_sync.dart';

void main() {
  test('Hatay districts include İskenderun and drop when the city changes', () {
    final hatay = MallLocationSync.districtsFor('Hatay');
    expect(hatay, contains('İskenderun'));
    expect(hatay, contains('Antakya'));
    expect(MallLocationSync.districtsFor('Adana'), isNot(contains('İskenderun')));
    expect(TurkiyeLocationData.provinces, hasLength(81));
  });

  test('address query, manual pin lock, and stale geocode gate', () {
    expect(
      MallLocationSync.searchQuery(
        address: 'Numune Mah. İbrahim Karaoğlanoğlu Cad. No:29',
        district: 'İskenderun',
        city: 'Hatay',
      ),
      'Numune Mah. İbrahim Karaoğlanoğlu Cad. No:29, İskenderun, Hatay, Türkiye',
    );
    expect(
      MallLocationSync.shouldSearchAddress(
        source: MallLocationSource.manualMap,
        snapshot: 'Numune Mah. Cad. No:29',
        current: 'Numune Mah. Cad. No:29 A',
      ),
      isFalse,
    );
    expect(
      MallLocationSync.shouldSearchAddress(
        source: MallLocationSource.district,
        snapshot: '',
        current: 'Numune Mah. İbrahim Karaoğlanoğlu Cad. No:29',
      ),
      isTrue,
    );
    final gate = MallGeocodeGate();
    final first = gate.begin();
    final second = gate.begin();
    expect(gate.isCurrent(first), isFalse);
    expect(gate.isCurrent(second), isTrue);
  });

  testWidgets('city and district focus the map and a failed search keeps manual pin', (
    tester,
  ) async {
    final geo = _FakeGeo();
    final city = TextEditingController();
    final district = TextEditingController();
    final address = TextEditingController();
    double? lat;
    double? lng;
    MallMapFocus? focus;
    addTearDown(() {
      city.dispose();
      district.dispose();
      address.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MallLocationEditor(
              city: city,
              district: district,
              address: address,
              latitude: lat,
              longitude: lng,
              geocode: geo,
              onCamera: (value) => focus = value,
              onPoint: (nextLat, nextLng) {
                lat = nextLat;
                lng = nextLng;
              },
              onClearPoint: () {
                lat = null;
                lng = null;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Hat');
    await tester.pump();
    await tester.tap(find.text('Hatay').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(district.text, isEmpty);
    expect(geo.searches.any((query) => query.contains('Hatay')), isTrue);
    expect(focus?.zoom, 10);

    await tester.enterText(find.byType(TextField).at(1), 'İskender');
    await tester.pump();
    await tester.tap(find.text('İskenderun').last);
    await tester.pump();
    expect(geo.searches.last, contains('İskenderun'));
    expect(focus?.zoom, 13);
    expect(focus?.latitude, closeTo(36.58, 0.01));

    await tester.enterText(find.byType(TextField).at(0), 'Ada');
    await tester.pump();
    await tester.tap(find.text('Adana').last);
    await tester.pump();
    expect(district.text, isEmpty);
    expect(lat, isNull);

    await tester.enterText(find.byType(TextField).at(2), 'Bulunamayan adres satırı 29');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(MallLocationSync.geocodeMiss), findsOneWidget);

    geo.pinOnSearch = true;
    await tester.enterText(
      find.byType(TextField).at(2),
      'Numune Mah. İbrahim Karaoğlanoğlu Cad. No:29',
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(lat, isNotNull);
    expect(lng, isNotNull);
    expect(focus?.zoom, 17);
  });
}

class _FakeGeo implements MallGeocodeClient {
  final searches = <String>[];
  var pinOnSearch = false;

  @override
  Future<MallGeocodeHit?> reverse(double latitude, double longitude) async {
    return MallGeocodeHit(
      latitude: latitude,
      longitude: longitude,
      city: 'Hatay',
      district: 'İskenderun',
      street: 'Numune Mah. Cad. No:29',
    );
  }

  @override
  Future<MallGeocodeHit?> search(String query) async {
    searches.add(query);
    if (query.startsWith('Bulunamayan')) return null;
    if (query.contains('İskenderun')) {
      return const MallGeocodeHit(latitude: 36.58, longitude: 36.17, label: 'İskenderun');
    }
    if (query.contains('Hatay')) {
      return const MallGeocodeHit(latitude: 36.2, longitude: 36.16, label: 'Hatay');
    }
    if (query.contains('Adana')) {
      return const MallGeocodeHit(latitude: 37.0, longitude: 35.32, label: 'Adana');
    }
    if (pinOnSearch) {
      return MallGeocodeHit(latitude: 36.59, longitude: 36.18, label: query);
    }
    return null;
  }

  @override
  Future<List<MallGeocodeHit>> suggest(String query) async {
    final hit = await search(query);
    if (hit == null || !pinOnSearch) return const [];
    return [hit];
  }
}
