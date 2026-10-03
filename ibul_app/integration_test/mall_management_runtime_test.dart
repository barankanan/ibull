// macOS runtime check for the AVM management panel without accounts: real
// widgets, the production GoRouter route patterns/page keys and sidebar
// navigation, in-memory RPC fakes. Backend rules are covered by
// supabase/manual_patches/20261010_mall_store_flow_flowtest.sql.
//   flutter test integration_test/mall_management_runtime_test.dart -d macos
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/features/mall/management/mall_management_location.dart';
import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/models/mall_store_link.dart';
import 'package:ibul_app/features/mall/management/pages/mall_management_page.dart';
import 'package:ibul_app/features/mall/management/widgets/mall_panel_kit.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_code_card.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_link_repository.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_requests_view.dart';

import '../test/mall/mall_fakes.dart';

var _shot = 0;

void _log(String line) => debugPrint('[MALL_PANEL_RT] $line');

const _teknosa = MallBranchCandidate(
  branchId: '65f9be3c-8f25-42ce-9f02-1801f5ecb362',
  branchCode: 'IBL-7LXD6N',
  branchName: 'Teknosa',
  storeName: 'Teknosa',
  category: 'Elektronik',
  city: 'Hatay',
  district: 'Arsuz',
  isVerified: true,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mall panel runtime', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f1', mallId: 'm1', name: '1.kat', sortOrder: 1, levelNumber: 1),
        MallFloor(id: 'f-1', mallId: 'm1', name: 'otopark', sortOrder: -1, levelNumber: -1),
        MallFloor(id: 'f0', mallId: 'm1', name: 'zemin kat', sortOrder: 0, levelNumber: 0),
      ]);
    final ops = FakeMallOperations(store, candidates: const [_teknosa]);
    final repo = FakeMallRepository(store);
    final router = GoRouter(
      initialLocation: '/avm/yonetim/m1',
      routes: [
        GoRoute(path: '/avm', builder: (_, _) => const Scaffold(body: Center(child: Text('AVM giriş')))),
        for (final pattern in mallPanelRoutePatterns)
          GoRoute(
            path: pattern,
            pageBuilder: (context, state) => mallPanelPage(
              state,
              MallManagementShell(
                key: ValueKey(state.pathParameters['mallId']),
                location: MallManagementLocation.parse(state.uri.path)!,
                repository: repo,
                operations: ops,
              ),
            ),
          ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    _log('window=${tester.view.physicalSize / tester.view.devicePixelRatio}');

    String kpi(String label) => tester
        .widget<MallKpiCard>(find.ancestor(of: find.text(label), matching: find.byType(MallKpiCard)).first)
        .value;
    Future<void> open(String label) async {
      await _revealMenu(tester, label);
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
      _log('opened $label path=${router.routerDelegate.currentConfiguration.uri.path}');
    }

    // A: dashboard counts come from the summary (3 floors, hours set).
    expect(kpi('Kat'), '3');
    expect(find.byKey(const ValueKey('mall-check-Çalışma saatleri-done')), findsOneWidget);
    _log('A dashboard floors=${kpi('Kat')} hours=done');
    await _shotNow(tester, 'A_overview');

    // B: add a floor, return to Genel Bakış → fresh count.
    await open('Katlar');
    await tester.tap(find.text('Kat Ekle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-floor-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 • 2. Kat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await _shotNow(tester, 'B_floors');
    await open('Genel Bakış');
    expect(kpi('Kat'), '4');
    _log('B after add floors=${kpi('Kat')}');

    // C: wizard — lowercase name search and store code both find Teknosa.
    await open('Mağazalar');
    await tester.tap(find.byKey(const ValueKey('mall-add-store')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mall-store-query')), 'teknosa');
    await tester.tap(find.byKey(const ValueKey('mall-store-search')));
    await tester.pumpAndSettle();
    expect(find.text('Teknosa'), findsOneWidget);
    await tester.tap(find.text('Mağaza Koduyla Bul'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-store-query')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mall-store-query')), 'ibl-7lxd6n');
    await tester.pumpAndSettle();
    await _shotNow(tester, 'C_code_typed');
    await tester.tap(find.byKey(const ValueKey('mall-store-search')));
    await tester.pumpAndSettle();
    expect(ops.lastQuery, 'IBL-7LXD6N');
    expect(find.text('Kod: IBL-7LXD6N'), findsOneWidget);
    await _shotNow(tester, 'C_wizard_find');
    await tester.tap(find.byKey(ValueKey('mall-request-${_teknosa.branchId}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-link-floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 • 1.kat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mall-link-unit-code')), '105');
    await tester.enterText(find.byKey(const ValueKey('mall-link-area')), '120');
    await _shotNow(tester, 'C_wizard_place');
    await tester.tap(find.byKey(const ValueKey('mall-wizard-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-wizard-send')));
    await tester.pumpAndSettle();

    // D: pending request with an auto-created reserved area.
    final unit = store.units.single;
    expect([unit.unitCode, unit.occupancy, store.links.single.status], ['105', 'reserved', 'pending']);
    expect(kpi('Gönderilen Davetler'), '1');
    _log('D link=${store.links.single.status} unit=${unit.unitCode}/${unit.occupancy}');
    await _shotNow(tester, 'D_stores_pending');

    // E: the store owner approves (server side), the panel shows it after reload.
    ops.approve(store.links.single.id);
    await open('Genel Bakış');
    expect(kpi('Aktif Mağaza'), '1');
    await open('Mağazalar');
    expect(kpi('Aktif Mağazalar'), '1');
    _log('E approved active=${kpi('Aktif Mağazalar')}');
    await _shotNow(tester, 'E_stores_active');

    // F: publish request → pending review (never active from the client).
    await open('Genel Bakış');
    await tester.ensureVisible(find.byKey(const ValueKey('mall-publish-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-publish-button')));
    await tester.pumpAndSettle();
    expect(store.status, 'pending_review');
    _log('F status=${store.status}');
    await _shotNow(tester, 'F_publish');

    // G: indoor map lists the approved store on its floor.
    await open('İç Mekan Haritası');
    await tester.tap(find.byKey(const ValueKey('mall-map-floor-f1')));
    await tester.pumpAndSettle();
    expect(find.text('105 • Teknosa'), findsOneWidget);
    await _shotNow(tester, 'G_map');

    // The remaining menus open without errors.
    for (final label in ['AVM Bilgileri', 'Kampanyalar', 'Reklam', 'İstatistikler', 'Yetkililer']) {
      await open(label);
      expect(find.byType(MallLoadError), findsNothing, reason: label);
      await _shotNow(tester, 'menu_$label');
    }

    // H: sidebar card is identity + Çıkış Yap only → /avm.
    expect(find.text('Hesabım'), findsNothing);
    expect(find.text('AVM Değiştir'), findsNothing);
    expect(find.byKey(const ValueKey('mall-switcher')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await _shotNow(tester, 'H_sidebar');
    await tester.tap(find.byKey(const ValueKey('mall-sidebar-signout')));
    await tester.pumpAndSettle();
    expect(repo.signedOut, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/avm');
    _log('H signedOut=${repo.signedOut} path=${router.routerDelegate.currentConfiguration.uri.path}');
    _log('RESULT ok');
  });

  testWidgets('remote 42703 on store links stays on Mağazalar', (tester) async {
    final store = FakeMallStore()
      ..floors.add(const MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0))
      ..failing.addAll(['links', 'summary']);
    final router = GoRouter(
      initialLocation: '/avm/yonetim/m1',
      routes: [
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
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('AVM bilgileri yüklenemedi.'), findsNothing);
    expect(find.byKey(const ValueKey('mall-publication-unavailable')), findsOneWidget);
    await _shotNow(tester, 'R_overview_fallback');
    for (final label in [
      'AVM Bilgileri', 'Katlar', 'Mağazalar', 'İç Mekan Haritası',
      'Kampanyalar', 'Reklam', 'İstatistikler', 'Yetkililer',
    ]) {
      await _revealMenu(tester, label);
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
      final storesError = find.byKey(const ValueKey('mall-section-error-magazalar')).evaluate().isNotEmpty;
      expect(storesError, label == 'Mağazalar', reason: label);
      expect(find.textContaining('42703'), findsNothing, reason: label);
      _log('R $label storesError=$storesError');
      if (label == 'Mağazalar') await _shotNow(tester, 'R_stores_error');
    }
    _log('RESULT isolated ok');
  });

  testWidgets('store applies to the mall, mall reviews and approves', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
        MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
      ]);
    final seller = FakeSellerPortal(store);
    Future<SellerMallFile?> pick(String type) async => SellerMallFile(
        type: type, name: '$type.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]), mime: 'application/pdf');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: SellerMallCodeCard(repository: seller, pickFile: pick))),
    ));
    await tester.pumpAndSettle();
    await _shotNow(tester, 'S1_seller_card');
    await tester.tap(find.byKey(const ValueKey('seller-mall-apply')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('seller-apply-query')), 'primall');
    await tester.tap(find.byKey(const ValueKey('seller-apply-search')));
    await tester.pumpAndSettle();
    expect(find.text('Doğrulandı'), findsOneWidget);
    expect(find.textContaining('m1'), findsNothing);
    await _shotNow(tester, 'S2_find_mall');
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seller-apply-floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Kat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('seller-apply-unit')), '105');
    await tester.enterText(find.byKey(const ValueKey('seller-apply-area')), '80');
    await _shotNow(tester, 'S3_place');
    await tester.tap(find.byKey(const ValueKey('seller-apply-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seller-apply-pick-lease_contract')));
    await tester.pumpAndSettle();
    await _shotNow(tester, 'S4_documents');
    await tester.tap(find.byKey(const ValueKey('seller-apply-send')));
    await tester.pumpAndSettle();
    expect(find.text('Başvurunuz Primall new yönetimine gönderildi.'), findsOneWidget);
    await _shotNow(tester, 'S5_sent');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SellerMallRequestsView(repository: seller))));
    await tester.pumpAndSettle();
    expect(find.text('Başvuru inceleniyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final link = store.links.single;
    _log('S seller applied source=${link.requestSource} status=${link.status} docs=${link.documents.length}');
    await _shotNow(tester, 'S5_seller_pending');

    final router = GoRouter(
      initialLocation: '/avm/yonetim/m1/magazalar',
      routes: [
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
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelen Başvurular (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Talep eden: Teknosa'), findsOneWidget);
    await _shotNow(tester, 'S6_incoming');
    await tester.tap(find.byKey(ValueKey('mall-review-${link.id}')));
    await tester.pumpAndSettle();
    await _shotNow(tester, 'S7_review');
    await tester.tap(find.byKey(const ValueKey('mall-review-approve')));
    await tester.pumpAndSettle();
    expect(store.links.single.status, 'approved');
    expect([store.units.single.unitCode, store.units.single.occupancy], ['105', 'occupied']);
    await tester.tap(find.text('Aktif Mağazalar').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('mall-store-floor-f1')), matching: find.text('Teknosa')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shotNow(tester, 'S8_active');

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SellerMallRequestsView(repository: seller))));
    await tester.pumpAndSettle();
    expect(find.text('Onaylandı'), findsOneWidget);
    await _shotNow(tester, 'S9_seller_approved');
    _log('RESULT application ok unit=${store.units.single.unitCode}/${store.units.single.occupancy}');
  });
}

/// The sidebar menu scrolls under the account card on short windows.
Future<void> _revealMenu(WidgetTester tester, String label) async {
  final sidebar = find.ancestor(of: find.text('Genel Bakış').first, matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.text(label).first, 80, scrollable: sidebar);
  await tester.pumpAndSettle();
}

Future<void> _shotNow(WidgetTester tester, String name) async {
  try {
    final view = RendererBinding.instance.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final dpr = tester.view.devicePixelRatio;
    final image = await layer.toImage(Offset.zero & (view.size * dpr), pixelRatio: 1 / dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${Directory.systemTemp.path}/mall_panel_${_shot++}_$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    _log('shot ${file.path}');
  } catch (error) {
    _log('shot failed $name $error');
  }
}
