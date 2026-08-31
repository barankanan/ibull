import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/core/qr_initial_params.dart';

const _deadHomeFiles = <String>[
  'lib/screens/home_screen.dart',
  'lib/screens/home_screen_sections.dart',
  'lib/screens/home_screen_legacy_full.dart',
  'lib/screens/home_screen_legacy_sections.dart',
];

void main() {
  test('dead HomeScreen copies are gone; live path is HomeScreenCore', () {
    for (final path in _deadHomeFiles) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    final entry =
        File('lib/screens/home_screen_deferred_entry.dart').readAsStringSync();
    expect(entry, contains('HomeScreenCore('));
    expect(entry, contains('home_screen_core.dart'));
    expect(entry, isNot(contains('home_screen.dart')));
    expect(entry, isNot(contains('home_screen_legacy_full.dart')));
  });

  test('three shells share IbulMaterialApp.router and GoRouter', () {
    final shell = File('lib/app/ibul_material_app.dart').readAsStringSync();
    expect(shell, contains('class IbulMaterialApp'));
    expect(shell, contains('MaterialApp.router'));
    expect(shell, contains('createIbulGoRouter'));
    expect(shell, isNot(contains('generateAppRoute')));
    expect(shell, isNot(contains('onGenerateRoute')));
    expect(shell, isNot(contains("part of 'seller_panel_page.dart'")));

    final customer = File('lib/app/customer_app.dart').readAsStringSync();
    expect(customer, contains('IbulMaterialApp('));
    expect(customer, contains('includeAuthRoutes: true'));
    expect(customer, isNot(contains('buildLaunchHome()')));

    final full = File('lib/app/full_app.dart').readAsStringSync();
    expect(full, contains('IbulMaterialApp('));
    expect(full, contains('includeAuthRoutes: false'));
    expect(full, isNot(contains('buildLaunchHome()')));

    final root = File('../lib/main.dart').readAsStringSync();
    expect(root, contains('IbulMaterialApp('));
    expect(root, contains('includeAuthRoutes: false'));
    expect(root, isNot(contains('buildLaunchHome()')));
    expect(root, isNot(contains('home_screen.dart')));
  });

  test('go_router factory keeps pageForAppRoute as the page table', () {
    final router = File('lib/app/ibul_go_router.dart').readAsStringSync();
    expect(router, contains('createIbulGoRouter'));
    expect(router, contains('pageForAppRoute'));
    expect(router, contains("path: '/ihiz/track/:code'"));
    expect(router, contains('SiteInfoRoutes.paths'));
    expect(router, contains('ibulGoRouterRedirect'));
    expect(router, contains("source: 'go_router:unknown'"));

    final table = File('lib/app/app_route_table.dart').readAsStringSync();
    expect(table, contains('pageForAppRoute'));
    expect(table, contains('generateAppRoute'));
  });

  test('IbulRouter bridges GoRouter and named Navigator fallback', () {
    final helper = File('lib/app/ibul_router.dart').readAsStringSync();
    expect(helper, contains('class IbulRouter'));
    expect(helper, contains('GoRouter.maybeOf'));
    expect(helper, contains('pushNamedAndRemoveUntil'));
    final homeNav = File('lib/core/home_navigation.dart').readAsStringSync();
    expect(homeNav, contains('IbulRouter.go'));
    expect(homeNav, contains('IbulRouter.push'));
  });

  test('auth routes redirect home when includeAuthRoutes is false', () {
    expect(
      ibulGoRouterRedirect(path: '/login', includeAuthRoutes: false),
      '/',
    );
    expect(
      ibulGoRouterRedirect(path: '/register', includeAuthRoutes: false),
      '/',
    );
    expect(
      ibulGoRouterRedirect(path: '/seller-login', includeAuthRoutes: false),
      '/',
    );
    expect(
      ibulGoRouterRedirect(path: '/login', includeAuthRoutes: true),
      isNull,
    );
  });

  test('QR exit redirect leaves /qr for /home', () {
    final previous = QrInitialParams.wasResetAfterQrExit;
    QrInitialParams.wasResetAfterQrExit = true;
    expect(
      ibulGoRouterRedirect(path: '/qr', includeAuthRoutes: true),
      '/home',
    );
    QrInitialParams.wasResetAfterQrExit = false;
    expect(
      ibulGoRouterRedirect(path: '/qr', includeAuthRoutes: true),
      isNull,
    );
    QrInitialParams.wasResetAfterQrExit = previous;
  });
}
