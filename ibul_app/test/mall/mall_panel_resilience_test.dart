import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/features/mall/management/mall_management_location.dart';
import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/models/mall_profile.dart';
import 'package:ibul_app/features/mall/management/pages/mall_management_page.dart';
import 'package:ibul_app/features/mall/public/mall_map_layer.dart';

import 'mall_fakes.dart';

Future<GoRouter> _pump(WidgetTester tester, FakeMallStore store, FakeMallRepository repository, String initial) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final operations = FakeMallOperations(store);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/avm', builder: (_, _) => const Scaffold(body: Text('AVM hub'))),
      for (final pattern in mallPanelRoutePatterns)
        GoRoute(
          path: pattern,
          pageBuilder: (context, state) => mallPanelPage(
            state,
            MallManagementShell(
              key: ValueKey(state.pathParameters['mallId']),
              location: MallManagementLocation.parse(state.uri.path)!,
              repository: repository,
              operations: operations,
            ),
          ),
        ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

FakeMallStore _storeWithFloors() => FakeMallStore()
  ..floors.addAll(const [
    MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
    MallFloor(id: 'f1', mallId: 'm1', name: '1. Kat', sortOrder: 1, levelNumber: 1),
    MallFloor(id: 'f2', mallId: 'm1', name: '2. Kat', sortOrder: 2, levelNumber: 2),
  ]);

void main() {
  testWidgets('a failing store-links query only breaks Mağazalar', (tester) async {
    final store = _storeWithFloors()..failing.add('links');
    final router = await _pump(tester, store, FakeMallRepository(store), '/avm/yonetim/m1');
    expect(find.text('AVM bilgileri yüklenemedi.'), findsNothing);
    expect(find.text('Primall new'), findsWidgets);

    router.go('/avm/yonetim/m1/katlar');
    await tester.pumpAndSettle();
    expect(find.text('2. Kat'), findsWidgets);
    expect(find.byKey(const ValueKey('mall-section-error-katlar')), findsNothing);

    router.go('/avm/yonetim/m1/magazalar');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-section-error-magazalar')), findsOneWidget);
    expect(find.textContaining('42703'), findsNothing);

    router.go('/avm/yonetim/m1/kampanyalar');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-section-error-kampanyalar')), findsNothing);

    store.failing.clear();
    router.go('/avm/yonetim/m1/magazalar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar Dene').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-section-error-magazalar')), findsNothing);
  });

  testWidgets('missing summary RPC falls back to row counts and blocks publish', (tester) async {
    final store = _storeWithFloors()..failing.add('summary');
    await _pump(tester, store, FakeMallRepository(store), '/avm/yonetim/m1');
    expect(find.byKey(const ValueKey('mall-publication-unavailable')), findsOneWidget);
    final publish = find.byKey(const ValueKey('mall-publish-button'));
    if (publish.evaluate().isNotEmpty) {
      final button = tester.widget<ButtonStyleButton>(
        find.descendant(of: publish, matching: find.bySubtype<ButtonStyleButton>()).first,
      );
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('core failure shows a retryable panel error', (tester) async {
    final store = _storeWithFloors()..failing.add('core');
    await _pump(tester, store, FakeMallRepository(store), '/avm/yonetim/m1');
    expect(find.text('AVM bilgileri yüklenemedi.'), findsOneWidget);
    expect(find.textContaining('42703'), findsNothing);

    store.failing.clear();
    await tester.tap(find.byKey(const ValueKey('mall-core-retry')));
    await tester.pumpAndSettle();
    expect(find.text('AVM bilgileri yüklenemedi.'), findsNothing);
    expect(find.text('Primall new'), findsWidgets);
  });

  testWidgets('sidebar card has only identity and Çıkış Yap; switcher needs 2+ malls', (tester) async {
    final store = _storeWithFloors();
    await _pump(tester, store, FakeMallRepository(store, memberships: const [
      MallMembership(mallId: 'm1', role: 'mall_manager', mall: testMall),
    ]), '/avm/yonetim/m1');
    expect(find.text('Hesabım'), findsNothing);
    expect(find.text('AVM Değiştir'), findsNothing);
    expect(find.text('AVM Yöneticisi'), findsWidgets);
    expect(find.byKey(const ValueKey('mall-sidebar-signout')), findsOneWidget);
    expect(find.byKey(const ValueKey('mall-switcher')), findsNothing);
  });

  testWidgets('header switcher lists every mall when the manager has two', (tester) async {
    final store = _storeWithFloors();
    final router = await _pump(tester, store, FakeMallRepository(store, memberships: const [
      MallMembership(mallId: 'm1', role: 'mall_manager', mall: testMall),
      MallMembership(
        mallId: 'm2',
        role: 'mall_manager',
        mall: MallProfile(
          id: 'm2',
          name: 'Primall Awm İskenderun',
          city: 'Hatay',
          district: 'İskenderun',
          addressText: '',
          status: 'draft',
          isVerified: false,
        ),
      ),
    ]), '/avm/yonetim/m1');
    await tester.tap(find.byKey(const ValueKey('mall-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primall Awm İskenderun').last);
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/avm/yonetim/m2');
  });

  test('opening hours parse into open / closed', () {
    final noon = DateTime(2026, 10, 3, 12);
    expect(mallOpenAt('08:00 - 22:00', noon), isTrue);
    expect(mallOpenAt('08:00 - 22:00', DateTime(2026, 10, 3, 23)), isFalse);
    expect(mallOpenAt('22:00 - 02:00', DateTime(2026, 10, 3, 1)), isTrue);
    expect(mallOpenAt('22:00 - 02:00', noon), isFalse);
    expect(mallOpenAt('Her gün açık', noon), isNull);
    expect(mallOpenAt(null, noon), isNull);
  });
}
