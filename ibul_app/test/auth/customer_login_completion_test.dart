import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/marketplace_paths.dart';
import 'package:ibul_app/core/auth/customer_login_completion.dart';

void main() {
  testWidgets('successful customer login pops a pushed login route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (loginContext) {
                      return Scaffold(
                        body: ElevatedButton(
                          onPressed: () {
                            CustomerLoginCompletion.finish(
                              loginContext,
                              sessionReady: true,
                            );
                          },
                          child: const Text('finish-login'),
                        ),
                      );
                    },
                  ),
                );
              },
              child: const Text('open-login'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-login'));
    await tester.pumpAndSettle();
    expect(find.text('finish-login'), findsOneWidget);

    await tester.tap(find.text('finish-login'));
    await tester.pumpAndSettle();
    expect(find.text('finish-login'), findsNothing);
    expect(find.text('open-login'), findsOneWidget);
  });

  testWidgets('login next=/avm returns to /avm instead of the application', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/baska',
      routes: [
        GoRoute(
          path: '/baska',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(
                '/login?next=${Uri.encodeComponent(MarketplacePaths.mallHub)}',
              ),
              child: const Text('open-login'),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => CustomerLoginCompletion.finish(
                context,
                sessionReady: true,
              ),
              child: const Text('finish-login'),
            ),
          ),
        ),
        GoRoute(
          path: MarketplacePaths.mallHub,
          builder: (_, _) => const Scaffold(body: Text('avm-hub')),
        ),
        GoRoute(
          path: MarketplacePaths.mallApplication,
          builder: (_, _) => const Scaffold(body: Text('avm-basvuru')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-login'));
    await tester.pumpAndSettle();
    expect(find.text('finish-login'), findsOneWidget);
    await tester.tap(find.text('finish-login'));
    await tester.pumpAndSettle();
    expect(find.text('avm-hub'), findsOneWidget);
    expect(find.text('avm-basvuru'), findsNothing);
    expect(router.state.uri.path, MarketplacePaths.mallHub);
  });
}
