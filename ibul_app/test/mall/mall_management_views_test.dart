import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/management/mall_management_location.dart';
import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/models/mall_store_link.dart';
import 'package:ibul_app/features/mall/management/models/mall_unit.dart';
import 'package:ibul_app/features/mall/management/pages/mall_management_page.dart';
import 'package:ibul_app/features/mall/management/widgets/mall_indoor_map_view.dart';
import 'package:ibul_app/features/mall/management/widgets/mall_panel_kit.dart';
import 'package:ibul_app/features/mall/management/widgets/mall_stats_view.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_code_card.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_requests_view.dart';

import 'mall_fakes.dart';

const destina = MallBranchCandidate(
  branchId: 'b1',
  branchCode: 'IBL-7K4P9X',
  branchName: 'destina',
  storeName: 'destina',
  category: 'Giyim',
  city: 'Hatay',
  isVerified: true,
);

Future<void> pumpMallShell(
  WidgetTester tester,
  String section, {
  required FakeMallStore store,
  FakeMallOperations? operations,
  FakeMallRepository? repository,
  String role = 'mall_manager',
  String? floorId,
  Size size = const Size(1440, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: (settings) =>
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text('route ${settings.name}'))),
    home: MallManagementShell(
      key: UniqueKey(),
      location: MallManagementLocation(mallId: 'm1', section: section, floorId: floorId),
      repository: repository ?? FakeMallRepository(store, role: role),
      operations: operations ?? FakeMallOperations(store, candidates: const [destina]),
    ),
  ));
  await tester.pumpAndSettle();
}

String kpiValue(WidgetTester tester, String label) {
  final card = find.ancestor(of: find.text(label), matching: find.byType(MallKpiCard));
  return tester.widget<MallKpiCard>(card.first).value;
}

void main() {
  testWidgets('overview reads KPIs and checklist from the server summary', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f-1', mallId: 'm1', name: 'Otopark', sortOrder: -1, levelNumber: -1),
        MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
        MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
      ]);
    await pumpMallShell(tester, 'ozet', store: store);
    for (final label in [
      'Genel Bakış', 'AVM Bilgileri', 'Katlar', 'Mağazalar', 'İç Mekan Haritası',
      'Kampanyalar', 'Reklam', 'İstatistikler', 'Yetkililer',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(kpiValue(tester, 'Kat'), '3');
    expect(kpiValue(tester, 'Mağaza Alanı'), '0');
    expect(kpiValue(tester, 'Aktif Mağaza'), '0');
    expect(kpiValue(tester, 'Boş Alan'), '0');
    expect(kpiValue(tester, 'Bekleyen Talep'), '0');
    expect(kpiValue(tester, 'Aktif Kampanya'), '0');
    expect(find.byKey(const ValueKey('mall-check-Çalışma saatleri-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-check-En az 1 kat-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-check-En az 1 mağaza-todo')), findsOneWidget);
    expect(find.textContaining('Henüz işlem yok'), findsOneWidget);
    expect(find.text('Kurulumda'), findsWidgets);
    expect(find.textContaining('haritada görünmüyor çünkü durumu "Kurulumda"'), findsOneWidget);
    final publish = tester.widget<MallPrimaryButton>(find.byKey(const ValueKey('mall-publish-button')));
    expect(publish.onPressed, isNull);
    expect(find.textContaining('En az 1 onaylı mağaza'), findsOneWidget);
  });

  testWidgets('publish request moves the mall to review', (tester) async {
    final store = FakeMallStore()
      ..floors.add(const MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1))
      ..units.add(const MallUnit(
          id: 'u1', mallId: 'm1', floorId: 'f1', unitCode: '102', unitType: 'store', occupancy: 'occupied', sortOrder: 0))
      ..links.add(const MallStoreLink(
          id: 'l1', status: 'approved', unitId: 'u1', unitCode: '102', floorId: 'f1',
          floorName: '1. Kat', storeName: 'destina', branchCode: 'IBL-7K4P9X', storeId: 's1'));
    await pumpMallShell(tester, 'ozet', store: store);
    await tester.ensureVisible(find.byKey(const ValueKey('mall-publish-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-publish-button')));
    await tester.pumpAndSettle();
    expect(store.status, 'pending_review');
    expect(find.text('Yayın onayı bekliyor'), findsWidgets);
    expect(find.text('Talebi Geri Çek'), findsOneWidget);
  });

  testWidgets('floor dialog picks a level, fills the name and sorts bottom to top', (tester) async {
    final store = FakeMallStore()
      ..floors.add(const MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1));
    await pumpMallShell(tester, 'katlar', store: store);
    await tester.tap(find.text('Kat Ekle').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Zemin Kat'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mall-floor-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('-1 • B1 / Otopark').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'B1'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mall-floor-name')), '');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Kat adı gerekli.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mall-floor-name')), 'Otopark');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    final added = store.floors.last;
    expect([added.name, added.levelNumber], ['Otopark', -1]);
    final first = tester.getTopLeft(find.byKey(ValueKey('mall-floor-${added.id}')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('mall-floor-f1')));
    expect(first.dx < second.dx || first.dy < second.dy, isTrue);
  });

  testWidgets('store wizard: find by name or code, place by floor + number, request', (tester) async {
    final store = FakeMallStore()
      ..floors.add(const MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1));
    final ops = FakeMallOperations(store, candidates: const [destina]);
    await pumpMallShell(tester, 'magazalar', store: store, operations: ops);
    expect(kpiValue(tester, 'Aktif Mağazalar'), '0');
    final summaryBefore = store.summaryCalls;

    await tester.tap(find.byKey(const ValueKey('mall-add-store')));
    await tester.pumpAndSettle();
    expect(find.text('Mağaza Bul'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mall-store-query')), 'DEST');
    await tester.tap(find.byKey(const ValueKey('mall-store-search')));
    await tester.pumpAndSettle();
    expect(find.text('destina'), findsOneWidget);
    expect(find.text('Giyim • Hatay'), findsOneWidget);
    expect(find.text('Kod: IBL-7K4P9X'), findsOneWidget);

    await tester.tap(find.text('Mağaza Koduyla Bul'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mall-store-query')), 'ibl 7k4p9x');
    await tester.tap(find.byKey(const ValueKey('mall-store-search')));
    await tester.pumpAndSettle();
    expect(ops.lastQuery, 'IBL-7K4P9X');
    await tester.tap(find.byKey(const ValueKey('mall-request-b1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mall-wizard-next')));
    await tester.pumpAndSettle();
    expect(find.text('Mağaza no gerekli.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mall-link-unit-code')), '105');
    await tester.enterText(find.byKey(const ValueKey('mall-link-area')), '120');
    await tester.enterText(find.byKey(const ValueKey('mall-link-note')), 'Köşe mağaza');
    await tester.tap(find.byKey(const ValueKey('mall-wizard-next')));
    await tester.pumpAndSettle();
    expect(find.text('1. Kat • Mağaza 105'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mall-wizard-send')));
    await tester.pumpAndSettle();

    final unit = store.units.single;
    expect([unit.unitCode, unit.occupancy, unit.floorId], ['105', 'reserved', 'f1']);
    expect([store.links.single.status, store.links.single.note], ['pending', 'Köşe mağaza']);
    expect(store.summaryCalls, greaterThan(summaryBefore));
    expect(kpiValue(tester, 'Gönderilen Davetler'), '1');
    expect(
      find.descendant(of: find.byKey(ValueKey('mall-store-row-${unit.id}')), matching: find.text('Mağaza onayı bekleniyor')),
      findsOneWidget,
    );
  });

  testWidgets('wizard refuses a number already used on another floor', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
        MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
      ])
      ..units.add(const MallUnit(
          id: 'u1', mallId: 'm1', floorId: 'f0', unitCode: '105', unitType: 'store', occupancy: 'vacant', sortOrder: 0));
    await pumpMallShell(tester, 'magazalar', store: store);
    await tester.tap(find.byKey(const ValueKey('mall-add-store')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mall-store-query')), 'destina');
    await tester.tap(find.byKey(const ValueKey('mall-store-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-request-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-link-floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 • 1. Kat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mall-link-unit-code')), '105');
    await tester.tap(find.byKey(const ValueKey('mall-wizard-next')));
    await tester.pumpAndSettle();
    expect(find.text('Mağaza 105 Zemin Kat katında kayıtlı.'), findsOneWidget);
    expect(store.links, isEmpty);
  });

  testWidgets('stores page groups by floor and shows approved stores as active', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
        MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
      ])
      ..units.addAll(const [
        MallUnit(id: 'u1', mallId: 'm1', floorId: 'f1', unitCode: '102', unitType: 'store', occupancy: 'occupied', sortOrder: 0),
        MallUnit(id: 'u2', mallId: 'm1', floorId: 'f0', unitCode: 'Z-1', unitType: 'store', occupancy: 'vacant', sortOrder: 0),
      ])
      ..links.add(const MallStoreLink(
          id: 'l1', status: 'approved', unitId: 'u1', unitCode: '102', floorId: 'f1',
          floorName: '1. Kat', storeName: 'destina', branchCode: 'IBL-7K4P9X', storeId: 's1'));
    await pumpMallShell(tester, 'magazalar', store: store);
    expect(kpiValue(tester, 'Aktif Mağazalar'), '1');
    expect(kpiValue(tester, 'Boş Alanlar'), '1');
    final zemin = tester.getTopLeft(find.byKey(const ValueKey('mall-store-floor-f0')));
    final birinci = tester.getTopLeft(find.byKey(const ValueKey('mall-store-floor-f1')));
    expect(zemin.dy, lessThan(birinci.dy));
    final row = find.byKey(const ValueKey('mall-store-row-u1'));
    expect(find.descendant(of: row, matching: find.text('destina')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Aktif')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Görüntüle')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('mall-store-row-u2')), matching: find.text('Boş')), findsOneWidget);
  });

  testWidgets('indoor map switches floors and shows the empty plan state', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
        MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
      ]);
    await pumpMallShell(tester, 'harita', store: store);
    expect(find.text(mallNoFloorPlanMessage), findsOneWidget);
    expect(find.text('Plan Yükle'), findsOneWidget);
    ChoiceChip chip(String id) => tester.widget<ChoiceChip>(find.byKey(ValueKey('mall-map-floor-$id')));
    expect(chip('f0').selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('mall-map-floor-f1')));
    await tester.pumpAndSettle();
    expect(chip('f1').selected, isTrue);
    expect(chip('f0').selected, isFalse);
  });

  testWidgets('campaigns, ads, stats and authorities pages open', (tester) async {
    final store = FakeMallStore();
    await pumpMallShell(tester, 'kampanyalar', store: store);
    expect(find.text('Kampanya Oluştur'), findsWidgets);
    expect(find.text('Taslak (0)'), findsOneWidget);

    await pumpMallShell(tester, 'reklam', store: store);
    expect(find.text('Reklam Oluştur'), findsWidgets);
    expect(find.text('Onay bekleyen (0)'), findsOneWidget);

    await pumpMallShell(tester, 'istatistikler', store: store);
    expect(find.text(mallStatsEmptyMessage), findsOneWidget);

    await pumpMallShell(tester, 'yetkililer', store: store);
    expect(find.text('Baran (siz)'), findsOneWidget);
    expect(find.text('yeni@x.com'), findsOneWidget);
  });

  testWidgets('roles: ad manager cannot add floors, store manager can add stores', (tester) async {
    final store = FakeMallStore()
      ..floors.add(const MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1));
    await pumpMallShell(tester, 'katlar', store: store, role: 'mall_ad_manager');
    expect(find.text('Kat Ekle'), findsNothing);
    await pumpMallShell(tester, 'yetkililer', store: store, role: 'mall_ad_manager');
    expect(find.text('Yetkili Ekle'), findsNothing);
    await pumpMallShell(tester, 'magazalar', store: store, role: 'mall_store_manager');
    expect(find.byKey(const ValueKey('mall-add-store')), findsOneWidget);
    await pumpMallShell(tester, 'ozet', store: store, role: 'mall_store_manager');
    expect(find.byKey(const ValueKey('mall-publish-button')), findsNothing);
  });

  testWidgets('mobile drawer has the account block with sign out', (tester) async {
    final store = FakeMallStore();
    final repository = FakeMallRepository(store);
    await pumpMallShell(tester, 'ozet', store: store, repository: repository, size: const Size(390, 844));
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('YÖNETİM'), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-sidebar-account')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('mall-sidebar-signout')));
    await tester.tap(find.byKey(const ValueKey('mall-sidebar-signout')));
    await tester.pumpAndSettle();
    expect(repository.signedOut, isTrue);
    expect(find.text('route /avm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selector explains when there is no managed mall and offers sign out', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MallSelectorPage(repository: FakeMallRepository(FakeMallStore()))));
    await tester.pumpAndSettle();
    expect(find.text(mallNoManagedMallMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-selector-signout')), findsOneWidget);
  });

  testWidgets('seller sees code card, full location and approves an AVM request', (tester) async {
    final links = FakeSellerLinks([
      const SellerMallRequest(
        id: 'l1',
        status: 'pending',
        mallName: 'Primall new',
        floorName: '1. Kat',
        unitCode: '105',
        city: 'Hatay',
        district: 'İskenderun',
        areaM2: 120,
        note: 'Köşe mağaza',
      ),
    ]);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SellerMallCodeCard(repository: links),
          Expanded(child: SellerMallRequestsView(repository: links)),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('IBL-7K4P9X'), findsOneWidget);
    expect(find.text('Hatay / İskenderun'), findsOneWidget);
    expect(find.text('1. Kat • 105 • 120 m²'), findsOneWidget);
    expect(find.text('Not: Köşe mağaza'), findsOneWidget);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(links.responses['l1'], isTrue);
    expect(find.text('Onaylandı'), findsOneWidget);
    expect(find.text('Onayla'), findsNothing);
  });
}
