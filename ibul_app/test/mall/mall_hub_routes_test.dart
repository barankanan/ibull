import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/ibul_go_router.dart';
import 'package:ibul_app/app/marketplace_paths.dart';
import 'package:ibul_app/features/mall/application/mall_auth_page.dart';
import 'package:ibul_app/features/mall/application/mall_hub_page.dart';
import 'package:ibul_app/features/mall/auth/mall_auth_session.dart';
import 'package:ibul_app/features/mall/models/mall_application.dart';

import 'mall_auth_fakes.dart';

void main() {
  test('landing routes split apply and AVM sign-in', () {
    expect(mallHubApplyRoute(), '/avm/basvuru');
    expect(mallHubSignInRoute(), '/avm/giris');
    expect(mallHubSignInRoute().contains('/login'), isFalse);
    expect(
      mallHubEntryTarget(loggedIn: false, hasMembership: false, hasApplication: false),
      '/avm/giris',
    );
    expect(
      mallHubEntryTarget(
        loggedIn: true,
        hasMembership: true,
        hasApplication: true,
        managementPath: '/avm/yonetim',
      ),
      '/avm/yonetim',
    );
    expect(
      mallHubEntryTarget(loggedIn: true, hasMembership: false, hasApplication: true),
      '/avm/basvuru',
    );
    expect(
      mallHubEntryTarget(loggedIn: true, hasMembership: false, hasApplication: false),
      isNull,
    );
    expect(mallHubApplyRoute().contains('/login'), isFalse);
  });

  test('AVM login destination follows membership and application state', () {
    expect(
      mallDestinationAfterLogin(
        hasActiveMembership: true,
        hasApplication: true,
      ),
      MarketplacePaths.mallManagement,
    );
    expect(MarketplacePaths.mallManagement, '/avm/yonetim');
    for (final status in [
      MallApplicationStatus.pendingReview,
      MallApplicationStatus.needsInfo,
      MallApplicationStatus.rejected,
      MallApplicationStatus.cancelled,
    ]) {
      expect(
        mallDestinationAfterLogin(
          hasActiveMembership: false,
          hasApplication: true,
        ),
        MarketplacePaths.mallApplication,
        reason: '$status',
      );
    }
    expect(
      mallDestinationAfterLogin(hasActiveMembership: false, hasApplication: false),
      isNull,
    );
    // The customer session never decides AVM access; MallAuthGate does.
    for (final customerSignedIn in [false, true]) {
      expect(
        ibulGoRouterRedirect(
          path: MarketplacePaths.mallManagement,
          includeAuthRoutes: true,
          authenticated: customerSignedIn,
        ),
        isNull,
      );
    }
    expect(
      ibulGoRouterRedirect(
        path: '/avm-yonetim/mall-1',
        includeAuthRoutes: true,
        authenticated: true,
      ),
      '/avm/yonetim/mall-1',
    );
  });

  testWidgets('AVM sign-in page stays off customer login', (tester) async {
    final session = MallAuthSession(storage: MemoryMallSessionStorage());
    final router = GoRouter(
      initialLocation: MarketplacePaths.mallLogin,
      routes: [
        GoRoute(
          path: MarketplacePaths.mallLogin,
          builder: (_, _) => MallAuthPage(session: session),
        ),
        GoRoute(
          path: MarketplacePaths.mallHub,
          builder: (_, _) => const Scaffold(body: Text('avm-landing')),
        ),
        GoRoute(
          path: MarketplacePaths.mallApplication,
          builder: (_, _) => const Scaffold(body: Text('avm-basvuru')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('customer-login')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('AVM Yönetici Girişi'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.text('AVM Girişi Yap'), findsOneWidget);
    expect(find.text('Bu giriş yalnızca AVM yönetim hesabınız içindir.'), findsOneWidget);
    expect(find.text('customer-login'), findsNothing);
    expect(router.state.uri.path, '/avm/giris');

    await tester.tap(find.text('AVM İşlemleri'));
    await tester.pumpAndSettle();
    expect(find.text('avm-landing'), findsOneWidget);
    expect(router.state.uri.path, MarketplacePaths.mallHub);
  });
}
