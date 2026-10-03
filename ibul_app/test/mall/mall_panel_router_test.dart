import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/features/mall/management/mall_management_location.dart';
import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/pages/mall_management_page.dart';
import 'package:ibul_app/features/mall/management/widgets/mall_panel_kit.dart';

import 'mall_fakes.dart';

String kpiValue(WidgetTester tester, String label) {
  final card = find.ancestor(of: find.text(label), matching: find.byType(MallKpiCard));
  return tester.widget<MallKpiCard>(card.first).value;
}

/// Uses the production route patterns + page factory so a regression to
/// nested routes (one stale `:mallId` page under every section) fails here.
GoRouter _router(FakeMallRepository repository, FakeMallOperations operations, String initial) {
  return GoRouter(
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
}

Future<GoRouter> _pump(WidgetTester tester, FakeMallStore store, FakeMallRepository repository, String initial) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _router(repository, FakeMallOperations(store), initial);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('dashboard is fresh after adding a floor and going back to Genel Bakış', (tester) async {
    final store = FakeMallStore()
      ..floors.addAll(const [
        MallFloor(id: 'f-1', mallId: 'm1', name: 'Otopark', sortOrder: -1, levelNumber: -1),
        MallFloor(id: 'f0', mallId: 'm1', name: 'Zemin Kat', sortOrder: 0, levelNumber: 0),
      ]);
    final repository = FakeMallRepository(store);
    final router = await _pump(tester, store, repository, '/avm/yonetim/m1');
    expect(kpiValue(tester, 'Kat'), '2');

    router.go('/avm/yonetim/m1/katlar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kat Ekle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mall-floor-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 • 1. Kat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.floors, hasLength(3));

    router.go('/avm/yonetim/m1');
    await tester.pumpAndSettle();
    expect(find.byType(MallManagementShell), findsOneWidget);
    expect(kpiValue(tester, 'Kat'), '3');
    expect(find.byKey(const ValueKey('mall-check-En az 1 kat-done')), findsOneWidget);
  });

  testWidgets('changes made outside the panel appear when returning to the overview', (tester) async {
    final store = FakeMallStore()..hoursReady = false;
    final repository = FakeMallRepository(store);
    final router = await _pump(tester, store, repository, '/avm/yonetim/m1');
    expect(find.byKey(const ValueKey('mall-check-Çalışma saatleri-todo')), findsOneWidget);

    router.go('/avm/yonetim/m1/bilgiler');
    await tester.pumpAndSettle();
    store.hoursReady = true;
    router.go('/avm/yonetim/m1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mall-check-Çalışma saatleri-done')), findsOneWidget);
  });

  testWidgets('Çıkış Yap signs out and lands on /avm', (tester) async {
    final store = FakeMallStore();
    final repository = FakeMallRepository(store);
    final router = await _pump(tester, store, repository, '/avm/yonetim/m1/magazalar');
    await tester.tap(find.byKey(const ValueKey('mall-account-menu')));
    await tester.pumpAndSettle();
    expect(find.text('AVM Değiştir'), findsNothing);
    expect(find.text('Hesabım'), findsNothing);
    await tester.tap(find.text('Çıkış Yap').last);
    await tester.pumpAndSettle();
    expect(repository.signedOut, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/avm');
    expect(find.text('AVM hub'), findsOneWidget);
  });
}
