import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/public/mall_map_layer.dart';
import 'package:ibul_app/features/mall/public/mall_public_format.dart';
import 'package:ibul_app/features/mall/public/mall_public_page.dart';
import 'package:ibul_app/features/mall/public/mall_public_repository.dart';

class _PendingPublic extends MallPublicRepository {
  @override
  Future<MallPublicDetail?> detail(String mallId) => Completer<MallPublicDetail?>().future;
}

class _FakePublic extends MallPublicRepository {
  _FakePublic({this.row, this.pins = const []});

  final Map<String, dynamic>? row;
  final List<MallMapPin> pins;

  @override
  Future<MallPublicDetail?> detail(String mallId) async => row == null ? null : MallPublicDetail.fromMap(row!);

  @override
  Future<List<MallMapPin>> activePins() async => pins;

  @override
  Future<List<MallStoreSearchHit>> storeDirectory() async => const [];

  @override
  Future<Set<String>> hiddenStoreIds() async => const {};
}

final _row = <String, dynamic>{
  'preview': false,
  'mall': {
    'id': 'm1',
    'name': 'Primall new',
    'city': 'Hatay',
    'district': 'İskenderun',
    'opening_hours': '08:00 - 22:00',
    'is_verified': true,
  },
  'floors': [
    {'id': 'f-1', 'name': 'Otopark', 'level_number': -1},
    {'id': 'f1', 'name': '1.kat', 'level_number': 1},
  ],
  'stores': [
    {'unit_code': '105', 'floor_id': 'f1', 'store_id': 's1', 'store_name': 'Teknosa', 'category': 'Elektronik'},
  ],
  'campaigns': <Object>[],
};

const _pin = MallMapPin(id: 'm1', name: 'Primall new', latitude: 36.58, longitude: 36.17, city: 'Hatay');

void main() {
  testWidgets('public mall page lists approved stores on their floor', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: MallPublicPage(mallId: 'm1', repository: _FakePublic(row: _row))));
    await tester.pumpAndSettle();
    expect(find.text('Primall new'), findsWidgets);
    expect(find.text('Hatay • İskenderun'), findsOneWidget);
    expect(find.textContaining('08:00'), findsOneWidget);
    expect(find.text('Doğrulandı'), findsOneWidget);
    expect(find.text('2 kat • 1 mağaza'), findsOneWidget);
    expect(find.text('1. Kat · 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-tab-Genel')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-tab-Mağazalar')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-tab-Katlar')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-tab-Profil')), findsOneWidget);
    expect(find.text('Adres'), findsNothing);
    expect(find.text('Telefon'), findsNothing);
    expect(find.text('Yol tarifi'), findsNothing);
    expect(find.text('Teknosa'), findsOneWidget);
    expect(find.text('Elektronik • Mağaza No: 105'), findsOneWidget);
    expect(find.text('Teknosa — 105'), findsNothing);
    expect(find.textContaining('Otopark (0)'), findsNothing);
    expect(find.byKey(const ValueKey('mall-public-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-favorite')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-preview')), findsNothing);
    expect(find.byKey(const ValueKey('mall-public-store-search')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mall-public-favorite')));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('mall-public-floor-f-1')));
    await tester.tap(find.byKey(const ValueKey('mall-public-floor-f-1')));
    await tester.pumpAndSettle();
    expect(find.text('Bu katta henüz mağaza yok.'), findsOneWidget);
  });

  testWidgets('unpublished mall is not shown to customers', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MallPublicPage(mallId: 'm1', repository: _FakePublic())));
    await tester.pumpAndSettle();
    expect(find.text('AVM bulunamadı veya henüz yayında değil.'), findsOneWidget);
  });

  testWidgets('members see a preview banner for a draft mall', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MallPublicPage(mallId: 'm1', repository: _FakePublic(row: {..._row, 'preview': true})),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-public-preview')), findsOneWidget);
  });

  test('map search matches active malls case-insensitively', () async {
    final pins = MallMapPins(repository: _FakePublic(pins: const [_pin]));
    await pins.load();
    expect(pins.match('PRİMALL')?.id, 'm1');
    expect(pins.match('primall new')?.id, 'm1');
    expect(pins.match('x'), isNull);
    expect(pins.match('teknosa'), isNull);
  });

  test('duplicate approved rows collapse to one store', () {
    final detail = MallPublicDetail.fromMap({
      ..._row,
      'stores': [
        {'unit_code': '2', 'floor_id': 'f1', 'store_id': 's1', 'store_name': 'Teknosa', 'category': 'Elektronik'},
        {'unit_code': '2', 'floor_id': 'f1', 'store_id': 's1', 'store_name': 'Teknosa', 'category': 'Elektronik'},
      ],
    });
    expect(detail.stores, hasLength(1));
    expect(detail.stores.single.unitCode, '2');
  });

  testWidgets('back button is present', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MallPublicPage(mallId: 'm1', repository: _FakePublic(row: _row))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-public-back')), findsOneWidget);
    expect(find.text('AVM'), findsNothing);
    expect(find.text('Primall new'), findsWidgets);
  });

  testWidgets('loading uses skeleton instead of a full-screen spinner', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MallPublicPage(mallId: 'm1', repository: _PendingPublic())));
    await tester.pump();
    expect(find.byKey(const ValueKey('mall-public-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('floor labels stay presentation-only', () {
    expect(mallFloorPresentationLabel(const MallPublicFloor(id: 'a', name: 'Otopark -2', levelNumber: -2)), 'B2');
    expect(mallFloorPresentationLabel(const MallPublicFloor(id: 'b', name: 'otopark', levelNumber: -1)), 'B1 / Otopark');
    expect(mallFloorPresentationLabel(const MallPublicFloor(id: 'c', name: 'zemin kat', levelNumber: 0)), 'Zemin Kat');
    expect(mallFloorPresentationLabel(const MallPublicFloor(id: 'd', name: '1.kat', levelNumber: 1)), '1. Kat');
    expect(mallFloorChipLabel(const MallPublicFloor(id: 'c', name: 'zemin kat', levelNumber: 0)), 'Zemin');
    expect(mallPlaceLabel(MallPublicDetail.fromMap(_row)), 'Hatay • İskenderun');
    final hours = mallHoursPresentation('08:00 - 22:00', now: DateTime(2026, 10, 3, 16));
    expect(mallHoursCompactLine(hours!), 'Açık • 08:00 – 22:00');
    expect(mallCountLine(2, 1), '2 kat • 1 mağaza');
  });

  testWidgets('store card opens the existing store route', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(builder: (_) => Text('route ${settings.name}')),
      home: MallPublicPage(mallId: 'm1', repository: _FakePublic(row: _row)),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('mall-public-store-105')));
    await tester.tap(find.byKey(const ValueKey('mall-public-store-105')));
    await tester.pumpAndSettle();
    expect(find.text('route /magaza/s1'), findsOneWidget);
  });

  testWidgets('profile tab holds contact details off the general view', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final row = {
      ..._row,
      'mall': {
        ..._row['mall'] as Map<String, dynamic>,
        'address_text': 'İstiklal Cad. No:1',
        'phone': '0326 000 00 00',
        'website': 'https://primall.example',
        'latitude': 36.58,
        'longitude': 36.17,
      },
    };
    await tester.pumpWidget(MaterialApp(home: MallPublicPage(mallId: 'm1', repository: _FakePublic(row: row))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('İstiklal Cad. No:1'), findsNothing);
    expect(find.text('0326 000 00 00'), findsNothing);
    expect(find.text('Yol tarifi'), findsNothing);
    expect(find.byKey(const ValueKey('mall-public-action-directions')), findsNothing);
    expect(find.text('2 kat • 1 mağaza'), findsOneWidget);
    expect(find.text('Teknosa'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mall-public-tab-Mağazalar')));
    await tester.pumpAndSettle();
    expect(find.text('Teknosa'), findsOneWidget);
    expect(find.text('Elektronik • 1. Kat • Mağaza No: 105'), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-public-store-search')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mall-public-tab-Katlar')));
    await tester.pumpAndSettle();
    expect(find.text('1 mağaza'), findsOneWidget);
    expect(find.text('Mağaza yok'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mall-public-floor-row-f-1')));
    await tester.pumpAndSettle();
    expect(find.text('Bu katta henüz mağaza yok.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mall-public-tab-Profil')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-public-about')), findsOneWidget);
    expect(find.text('İletişim'), findsOneWidget);
    expect(find.text('İstiklal Cad. No:1'), findsOneWidget);
    expect(find.text('0326 000 00 00'), findsOneWidget);
    expect(find.text('08:00 – 22:00'), findsOneWidget);
    expect(find.text('https://primall.example'), findsOneWidget);
    expect(find.text('Yol tarifi'), findsOneWidget);
    expect(find.text('Teknosa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mall map card offers AVM\'yi Gör', (tester) async {
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(builder: (_) => Text('route ${settings.name}')),
      home: Builder(
        builder: (context) => TextButton(onPressed: () => showMallMapCard(context, _pin), child: const Text('open')),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('AVM • Hatay'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mall-map-open')));
    await tester.pumpAndSettle();
    expect(find.text('route /avm/profil/m1'), findsOneWidget);
  });
}
