import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_ready.dart';
import 'package:ibul_app/core/home_navigation.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_exit_destination.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_logout_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    if (!appServicesReadyCompleter.isCompleted) {
      appServicesReadyCompleter.complete();
    }
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  Widget homeRouteBuilder(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final index = args is HomeRouteArgs ? args.initialIndex : -1;
    return Scaffold(body: Text('home-$index'));
  }

  group('SellerLogoutGuard', () {
    testWidgets('logout tap triggers performExit once', (tester) async {
      var exitCalls = 0;
      final guard = SellerLogoutGuard(
        performExit: () async {
          exitCalls++;
          return const SellerExitResult(
            restoredCustomerSession: false,
            hasSupabaseSession: false,
            customerSessionActive: false,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => guard.execute(context: context),
                child: const Text('logout'),
              );
            },
          ),
          routes: {
            HomeNavigation.routeName: homeRouteBuilder,
          },
        ),
      );

      await tester.tap(find.text('logout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(exitCalls, 1);
    });

    testWidgets('second logout tap while running is ignored', (tester) async {
      var exitCalls = 0;
      final completer = Completer<SellerExitResult>();
      final guard = SellerLogoutGuard(
        performExit: () async {
          exitCalls++;
          return completer.future;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => guard.execute(context: context),
                child: const Text('logout'),
              );
            },
          ),
          routes: {
            HomeNavigation.routeName: homeRouteBuilder,
          },
        ),
      );

      await tester.tap(find.text('logout'));
      await tester.pump();
      await tester.tap(find.text('logout'));
      await tester.pump();
      expect(exitCalls, 1);
      completer.complete(
        const SellerExitResult(
          restoredCustomerSession: false,
          hasSupabaseSession: false,
          customerSessionActive: false,
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('logout timeout does not freeze UI', (tester) async {
      final completer = Completer<SellerExitResult>();
      final guard = SellerLogoutGuard(performExit: () => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => guard.execute(context: context),
                child: const Text('logout'),
              );
            },
          ),
          routes: {
            HomeNavigation.routeName: homeRouteBuilder,
          },
        ),
      );

      await tester.tap(find.text('logout'));
      await tester.pump();
      completer.complete(
        const SellerExitResult(
          restoredCustomerSession: false,
          hasSupabaseSession: false,
          customerSessionActive: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('home-0'), findsOneWidget);
    });

    testWidgets(
      'logout with customer session navigates to account tab',
      (tester) async {
        final guard = SellerLogoutGuard(
          performExit: () async => const SellerExitResult(
            restoredCustomerSession: true,
            hasSupabaseSession: true,
            customerSessionActive: true,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => guard.execute(context: context),
                  child: const Text('logout'),
                );
              },
            ),
            routes: {
              HomeNavigation.routeName: homeRouteBuilder,
            },
          ),
        );

        await tester.tap(find.text('logout'));
        await tester.pumpAndSettle();
        expect(find.text('home-${SellerExitDestination.accountTabIndex}'), findsOneWidget);
      },
    );

    testWidgets('logout tap emits [SellerLogout] tap log', (tester) async {
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };

      try {
        final guard = SellerLogoutGuard(
          performExit: () async => const SellerExitResult(
            restoredCustomerSession: false,
            hasSupabaseSession: false,
            customerSessionActive: false,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => guard.execute(context: context),
                  child: const Text('logout'),
                );
              },
            ),
            routes: {
              HomeNavigation.routeName: homeRouteBuilder,
            },
          ),
        );

        await tester.tap(find.text('logout'));
        await tester.pumpAndSettle();
        expect(logs, contains('[SellerLogout] tap'));
        expect(logs, contains('[SellerLogout] start'));
      } finally {
        debugPrint = previousDebugPrint;
      }
    });

    testWidgets(
      'hanging stopLiveWork times out and logout still completes',
      (tester) async {
        final guard = SellerLogoutGuard(
          performExit: () async => const SellerExitResult(
            restoredCustomerSession: false,
            hasSupabaseSession: false,
            customerSessionActive: false,
          ),
        );
        final neverCompletes = Completer<void>();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => guard.execute(
                    context: context,
                    stopLiveWork: () => neverCompletes.future,
                  ),
                  child: const Text('logout'),
                );
              },
            ),
            routes: {
              HomeNavigation.routeName: homeRouteBuilder,
            },
          ),
        );

        await tester.tap(find.text('logout'));
        await tester.pump();
        // stopLiveWork askıda: timeout süresi kadar bekle, donma olmamalı.
        await tester.pump(
          SellerLogoutGuard.stopLiveWorkTimeout + const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
        expect(find.text('home-0'), findsOneWidget);
      },
    );

    testWidgets(
      'logout without customer session does not navigate to seller-login',
      (tester) async {
        final guard = SellerLogoutGuard(
          performExit: () async => const SellerExitResult(
            restoredCustomerSession: false,
            hasSupabaseSession: false,
            customerSessionActive: false,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => guard.execute(context: context),
                  child: const Text('logout'),
                );
              },
            ),
            routes: {
              HomeNavigation.routeName: homeRouteBuilder,
              SellerExitDestination.sellerLoginRoute: (_) =>
                  const Scaffold(body: Text('seller-login')),
            },
          ),
        );

        await tester.tap(find.text('logout'));
        await tester.pumpAndSettle();
        expect(find.text('home-0'), findsOneWidget);
        expect(find.text('seller-login'), findsNothing);
      },
    );
  });

  group('Çıkış Yap wiring (kaynak doğrulama)', () {
    test('tüm seller shell\'leri onLogoutTap → _handleSellerLogoutTap bağlar',
        () {
      final source =
          File('lib/screens/seller_panel_page.dart').readAsStringSync();
      // Desktop sidebar + tablet drawer doğrudan handler alır.
      expect(
        'onLogoutTap: _handleSellerLogoutTap'.allMatches(source).length,
        2,
        reason: 'Desktop ve tablet shell logout wiring eksik',
      );
      // Mobile drawer: önce drawer kapanır, sonra logout.
      expect(source.contains('unawaited(_handleSellerLogoutTap())'), isTrue);
      // Eski donan akış geri gelmesin.
      expect(source.contains('_exitSellerPanel'), isFalse);
      // Handler guard üzerinden çalışır.
      expect(
        source.contains('_sellerLogoutGuard.execute('),
        isTrue,
      );
    });

    test('kök uygulama /home route\'unu HomeRouteArgs ile çözer', () {
      final table = File('lib/app/app_route_table.dart').readAsStringSync();
      final shared = File('lib/app/shared_app_widgets.dart').readAsStringSync();
      final rootMain = File('../lib/main.dart');
      expect(table.contains("case '/home':"), isTrue);
      expect(shared.contains('HomeRouteArgs.from'), isTrue);
      if (rootMain.existsSync()) {
        expect(rootMain.readAsStringSync(), contains('IbulMaterialApp'));
      }
    });
  });
}
