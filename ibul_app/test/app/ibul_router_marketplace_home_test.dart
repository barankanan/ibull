import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/ibul_router.dart';

void main() {
  setUp(() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  });

  GoRouter buildRouter({String initialLocation = '/'}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) {
        if (state.uri.path == '/home') return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home-root')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home-alias')),
        ),
        GoRoute(
          path: '/hesabim',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => IbulRouter.goMarketplaceHome(context),
              child: const Text('account-logo'),
            ),
          ),
        ),
        GoRoute(
          path: '/arac/:id',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => IbulRouter.goMarketplaceHome(context),
              child: const Text('vehicle-logo'),
            ),
          ),
        ),
      ],
    );
    IbulGoRouterBinding.instance = router;
    return router;
  }

  tearDown(() {
    IbulGoRouterBinding.instance = null;
    IbulRouter.debugUseRootRouter = false;
    GoRouter.optionURLReflectsImperativeAPIs = false;
  });

  testWidgets('account logo returns to canonical /', (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(router.state.uri.path, '/');

    IbulRouter.push(
      router.routerDelegate.navigatorKey.currentContext!,
      '/hesabim',
    );
    await tester.pumpAndSettle();
    expect(find.text('account-logo'), findsOneWidget);
    expect(router.state.uri.path, '/hesabim');

    await tester.tap(find.text('account-logo'));
    await tester.pumpAndSettle();

    expect(find.text('home-root'), findsOneWidget);
    expect(find.text('account-logo'), findsNothing);
    expect(router.state.uri.path, '/');
  });

  testWidgets('vehicle go-route logo goes to marketplace home', (tester) async {
    final router = buildRouter(initialLocation: '/arac/123');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('vehicle-logo'), findsOneWidget);
    expect(router.state.uri.path, '/arac/123');

    await tester.tap(find.text('vehicle-logo'));
    await tester.pumpAndSettle();

    expect(find.text('home-root'), findsOneWidget);
    expect(router.state.uri.path, '/');
  });

  testWidgets('legacy /home redirects to canonical /', (tester) async {
    final router = buildRouter(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('home-root'), findsOneWidget);
    expect(find.text('home-alias'), findsNothing);
    expect(router.state.uri.path, '/');
    expect(tester.takeException(), isNull);
  });
}
