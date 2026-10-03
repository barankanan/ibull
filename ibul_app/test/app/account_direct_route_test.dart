import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/account_sections.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/screens/ibul_not_found_page.dart';
import 'package:ibul_app/widgets/deferred_module_screen.dart';

void main() {
  GoRouter router({
    required String initialLocation,
    required bool authenticated,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) => ibulGoRouterRedirect(
        path: state.uri.path,
        includeAuthRoutes: true,
        authenticated: authenticated,
      ),
      errorBuilder: (context, state) => IbulNotFoundPage(path: state.uri.path),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) => Scaffold(
            body: Text('login:${state.uri.queryParameters['next']}'),
          ),
        ),
        GoRoute(
          path: '/hesabim',
          builder: (context, state) => const Scaffold(body: Text('Hesabım')),
        ),
        GoRoute(
          path: '/hesabim/:section',
          builder: (_, state) {
            final section = AccountSections.fromPath(
              '/hesabim/${state.pathParameters['section']}',
            );
            return Scaffold(
              body: Text(AccountSections.labelOf(section!)),
            );
          },
        ),
      ],
    );
  }

  Future<void> pump(
    WidgetTester tester,
    GoRouter goRouter,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: goRouter));
    await tester.pumpAndSettle();
  }

  testWidgets('A logged out /hesabim redirects to login with next', (
    tester,
  ) async {
    final goRouter = router(initialLocation: '/hesabim', authenticated: false);
    addTearDown(goRouter.dispose);
    await pump(tester, goRouter);

    expect(goRouter.routeInformationProvider.value.uri.path, '/login');
    expect(
      goRouter.routeInformationProvider.value.uri.queryParameters['next'],
      '/hesabim',
    );
    expect(find.text('login:/hesabim'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('B logged in /hesabim shows the account page', (tester) async {
    final goRouter = router(initialLocation: '/hesabim', authenticated: true);
    addTearDown(goRouter.dispose);
    await pump(tester, goRouter);

    expect(goRouter.routeInformationProvider.value.uri.path, '/hesabim');
    expect(find.text('Hesabım'), findsOneWidget);
  });

  testWidgets('C logged in /hesabim/siparisler shows Siparişlerim', (
    tester,
  ) async {
    final goRouter = router(
      initialLocation: '/hesabim/siparisler',
      authenticated: true,
    );
    addTearDown(goRouter.dispose);
    await pump(tester, goRouter);

    expect(find.text('Siparişlerim'), findsOneWidget);
  });

  testWidgets('D logged in /hesabim/favoriler shows Favorilerim', (
    tester,
  ) async {
    final goRouter = router(
      initialLocation: '/hesabim/favoriler',
      authenticated: true,
    );
    addTearDown(goRouter.dispose);
    await pump(tester, goRouter);

    expect(find.text('Favorilerim'), findsOneWidget);
  });

  testWidgets('E logged in /hesabim/kiralamalar shows Kiralamalarım', (
    tester,
  ) async {
    final goRouter = router(
      initialLocation: '/hesabim/kiralamalar',
      authenticated: true,
    );
    addTearDown(goRouter.dispose);
    await pump(tester, goRouter);

    expect(find.text('Kiralamalarım'), findsOneWidget);
  });

  testWidgets('F unknown route shows the not-found page', (tester) async {
    final goRouter = router(
      initialLocation: '/bu-sayfa-yok',
      authenticated: false,
    );
    addTearDown(goRouter.dispose);
    await pump(tester, goRouter);

    expect(find.text('Sayfa bulunamadı'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('G deferred direct route paints loading then the page', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredModuleScreen(
          moduleName: 'account_direct',
          loadLibrary: () => pending.future,
          loading: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          builder: () => const Scaffold(body: Text('Hesabım')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Hesabım'), findsNothing);

    pending.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Hesabım'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('G direct routes remove the HTML boot loader', () {
    final deferred = File(
      'lib/widgets/deferred_module_screen.dart',
    ).readAsStringSync();
    final deferredInit = deferred.split('void initState()')[1].split(
      'void dispose()',
    )[0];
    expect(deferredInit, contains('_revealHtmlShell()'));

    final notFound = File(
      'lib/screens/ibul_not_found_page.dart',
    ).readAsStringSync();
    expect(notFound, contains('dismissWebBootLoader()'));
  });
}
