import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/features/mall/management/mall_management_location.dart';
import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/models/mall_store_link.dart';
import 'package:ibul_app/features/mall/management/pages/mall_management_page.dart';
import 'package:ibul_app/features/mall/management/widgets/mall_store_application_dialog.dart';
import 'package:ibul_app/features/mall/public/mall_public_repository.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_code_card.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_link_repository.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_requests_view.dart';

import 'mall_fakes.dart';

FakeMallStore primall() => FakeMallStore()
  ..floors.addAll(const [
    MallFloor(id: 'f-1', mallId: 'm1', name: 'B1 / Otopark', sortOrder: -1, levelNumber: -1),
    MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
    MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
  ]);

Future<SellerMallFile?> fakePick(String type) async =>
    SellerMallFile(type: type, name: '$type.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]), mime: 'application/pdf');

Future<void> _wide(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Seller side: card → AVM'ye Başvur → Primall → 1. Kat / 105 / 80 m² → belge → gönder.
Future<void> applyAsSeller(WidgetTester tester, FakeSellerPortal seller) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: SellerMallCodeCard(repository: seller, pickFile: fakePick))),
  ));
  await tester.pumpAndSettle();
  expect(find.text('IBL-7LXD6N'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('seller-mall-apply')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('seller-apply-query')), 'Primall');
  await tester.tap(find.byKey(const ValueKey('seller-apply-search')));
  await tester.pumpAndSettle();
  expect(find.text('Hatay / İskenderun'), findsOneWidget);
  expect(find.text('Doğrulandı'), findsOneWidget);
  expect(find.textContaining('m1'), findsNothing);
  await tester.tap(find.text('Seç'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('seller-apply-floor')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1. Kat').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('seller-apply-unit')), '105');
  await tester.enterText(find.byKey(const ValueKey('seller-apply-area')), '80');
  await tester.tap(find.byKey(const ValueKey('seller-apply-next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('seller-apply-send')));
  await tester.pumpAndSettle();
  expect(find.textContaining('kira sözleşmesi veya yer tahsis'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('seller-apply-pick-lease_contract')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('seller-apply-send')));
  await tester.pumpAndSettle();
  expect(find.text('Başvurunuz Primall new yönetimine gönderildi.'), findsOneWidget);
}

Widget _panel(FakeMallStore store, String path) {
  final router = GoRouter(initialLocation: path, routes: [
    for (final pattern in mallPanelRoutePatterns)
      GoRoute(
        path: pattern,
        pageBuilder: (context, state) => mallPanelPage(
          state,
          MallManagementShell(
            key: ValueKey(state.pathParameters['mallId']),
            location: MallManagementLocation.parse(state.uri.path)!,
            repository: FakeMallRepository(store),
            operations: FakeMallOperations(store),
          ),
        ),
      ),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('store applies, AVM approves, both sides see the active link', (tester) async {
    await _wide(tester);
    final store = primall();
    final seller = FakeSellerPortal(store);
    await applyAsSeller(tester, seller);
    final link = store.links.single;
    expect([link.requestSource, link.status, link.unitCode, link.floorName], ['store', 'pending', '105', '1. Kat']);
    expect(seller.lastDraft!.areaM2, 80);
    expect(store.units, isEmpty, reason: 'no store number is created before the AVM approves');

    await tester.pumpWidget(_panel(store, '/avm/yonetim/m1/magazalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelen Başvurular (1)'));
    await tester.pumpAndSettle();
    expect(find.text('1. Kat • 105 • 80 m²'), findsOneWidget);
    expect(find.text('Talep eden: Teknosa'), findsOneWidget);
    expect(find.text('AVM kira sözleşmesi'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('mall-review-${link.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Mağaza Başvurusu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mall-review-approve')));
    await tester.pumpAndSettle();
    expect(store.links.single.status, 'approved');
    expect(store.units.single.unitCode, '105');
    expect(store.units.single.occupancy, 'occupied');
    expect(store.units.single.areaM2, 80);

    await tester.tap(find.text('Aktif Mağazalar').last);
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('mall-store-row-${store.units.single.id}'));
    expect(find.descendant(of: row, matching: find.text('105')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Teknosa')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Aktif')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SellerMallRequestsView(repository: seller))));
    await tester.pumpAndSettle();
    expect(find.text('AVM Bağlantıları'), findsOneWidget);
    expect(find.text('Primall new'), findsOneWidget);
    expect(find.byKey(ValueKey('seller-mall-status-${link.id}')), findsOneWidget);
    expect(find.text('Onaylandı'), findsOneWidget);
  });

  testWidgets('pending application reads "Başvuru inceleniyor" and cannot be self-approved', (tester) async {
    await _wide(tester);
    final store = primall();
    final seller = FakeSellerPortal(store);
    await applyAsSeller(tester, seller);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SellerMallRequestsView(repository: seller))));
    await tester.pumpAndSettle();
    expect(find.text('Başvurularım'), findsOneWidget);
    expect(find.text('Başvuru inceleniyor'), findsOneWidget);
    expect(find.text('Onayla'), findsNothing);
    expect(find.text('Başvuruyu Geri Çek'), findsOneWidget);
  });

  testWidgets('AVM invitation is answered by the store, then listed under Gönderilen Davetler', (tester) async {
    await _wide(tester);
    final store = primall();
    final ops = FakeMallOperations(store, candidates: const [
      MallBranchCandidate(branchId: 'b-teknosa', branchCode: 'IBL-7LXD6N', branchName: 'Teknosa', storeName: 'Teknosa', isVerified: true),
    ]);
    await ops.requestStoreLink(mallId: 'm1', branchId: 'b-teknosa', floorId: 'f1', unitCode: '105', areaM2: 80);
    expect(store.links.single.requestSource, 'mall');

    await tester.pumpWidget(_panel(store, '/avm/yonetim/m1/magazalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gönderilen Davetler (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Mağaza onayı bekleniyor'), findsOneWidget);
    expect(find.text('Daveti Geri Çek'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SellerMallRequestsView(repository: FakeSellerPortal(store)))));
    await tester.pumpAndSettle();
    expect(find.text('Yanıt bekleyen AVM davetleri'), findsOneWidget);
    expect(find.text('Primall new mağazanızı şu konuma eklemek istiyor:'), findsOneWidget);
    expect(find.text('Onayla'), findsOneWidget);
  });

  testWidgets('documents open only through a signed URL', (tester) async {
    final store = primall();
    final ops = FakeMallOperations(store);
    final opened = <Uri>[];
    const link = MallStoreLink(
      id: 'l1',
      status: 'pending',
      requestSource: 'store',
      unitId: '',
      unitCode: '105',
      floorName: '1. Kat',
      storeName: 'Teknosa',
      branchCode: 'IBL-7LXD6N',
      documents: [MallLinkDocument(type: 'lease_contract', path: 'seller-1/mall-links/l1/kira.pdf', name: 'kira.pdf', mime: 'application/pdf')],
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showMallStoreApplicationDialog(context, link: link, operations: ops, openDocument: (url) async => opened.add(url)),
          child: const Text('aç'),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görüntüle'));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'signed.example');
    expect(opened.single.query, contains('token'));

    await tester.tap(find.byKey(const ValueKey('mall-review-info')));
    await tester.pumpAndSettle();
    expect(find.text('Mağazaya iletilecek mesajı yazın.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mall-review-message')), 'İmzalı sayfayı ekleyin.');
    await tester.tap(find.byKey(const ValueKey('mall-review-info')));
    await tester.pumpAndSettle();
    expect(ops.infoRequests['l1'], 'İmzalı sayfayı ekleyin.');
  });

  test('map pin carries the approved store count', () {
    final pin = MallMapPin.fromMap({
      'id': 'm1', 'name': 'Primall new', 'city': 'Hatay', 'district': 'İskenderun',
      'latitude': 36.57, 'longitude': 36.16, 'store_count': 1,
    })!;
    expect(pin.storeCount, 1);
    expect(pin.locationLabel, 'Hatay / İskenderun');
    expect(MallMapPin.fromMap({'id': 'x', 'name': 'y', 'latitude': null, 'longitude': 1}), isNull);
  });
}
