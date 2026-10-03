import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/public/mall_map_layer.dart';
import 'package:ibul_app/features/mall/public/mall_public_repository.dart';
import 'package:ibul_app/features/mall/seller/seller_onboarding_location.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('new store asks AVM vs standalone', (tester) async {
    SellerOnboardingLocationKind? kind;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SellerOnboardingLocationStep(
          kind: kind,
          onKind: (value) => kind = value,
          standalone: const Text('standalone-map'),
          city: '',
          district: '',
          onPickCityDistrict: () {},
        ),
      ),
    ));
    expect(find.text('Mağazanız nerede?'), findsOneWidget);
    expect(find.text('Bağımsız adreste / cadde mağazası'), findsOneWidget);
    expect(find.text('AVM içerisinde'), findsOneWidget);
    expect(find.text('standalone-map'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('seller-location-standalone')));
    await tester.pump();
    expect(kind, SellerOnboardingLocationKind.standalone);
  });

  test('map viewport memory keeps camera and search', () {
    MapViewportMemory.remember(
      camera: const LatLng(36.57, 36.16),
      cameraZoom: 16,
      query: 'Teknosa',
      filterDistance: 5,
      filterCategories: const ['Elektronik'],
      filterOpenNow: true,
    );
    expect(MapViewportMemory.hasCamera, isTrue);
    expect(MapViewportMemory.center!.latitude, closeTo(36.57, 0.001));
    expect(MapViewportMemory.search, 'Teknosa');
    expect(MapViewportMemory.categories, ['Elektronik']);
  });

  test('mall store search hit uses mall coordinates', () {
    final hit = MallStoreSearchHit.fromMap({
      'store_id': 's1',
      'store_name': 'Teknosa',
      'mall_id': 'm1',
      'mall_name': 'Primall new',
      'city': 'Hatay',
      'district': 'İskenderun',
      'latitude': 36.57,
      'longitude': 36.16,
      'floor_name': '1. Kat',
      'unit_code': '105',
    })!;
    expect(hit.placeLabel, 'Primall new • 1. Kat • 105');
    expect(hit.locationLabel, 'Hatay / İskenderun');
  });
}
