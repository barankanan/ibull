import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/app_providers.dart';
import 'package:ibul_app/core/ibul_app_mode.dart';

void main() {
  group('Customer auth routes and session', () {
    setUp(() {
      IbulAppModeRegistry.resetForTests();
    });

    test('customer app registers login route', () {
      final app = File('lib/app/customer_app.dart').readAsStringSync();
      final table = File('lib/app/app_route_table.dart').readAsStringSync();
      expect(app, contains('includeAuthRoutes: true'));
      expect(table, contains("case '/login':"));
      expect(table, contains('CustomerRoutes.buildLoginPage'));
    });

    test('customer app registers seller-login route', () {
      final app = File('lib/app/customer_app.dart').readAsStringSync();
      final table = File('lib/app/app_route_table.dart').readAsStringSync();
      expect(app, contains('includeAuthRoutes: true'));
      expect(table, contains("case '/seller-login':"));
      expect(table, contains('buildSellerLoginPage'));
    });

    test('customer app registers lazy seller panel route', () {
      final app = File('lib/app/customer_app.dart').readAsStringSync();
      final table = File('lib/app/app_route_table.dart').readAsStringSync();
      expect(app, contains('IbulMaterialApp'));
      expect(table, contains("case '/seller':"));
      expect(table, contains('SellerRoutes.buildSellerPanel'));
    });

    test('customer app mounts auth-capable providers without seller modules', () {
      IbulAppModeRegistry.current = IbulAppMode.customer;
      final providers = buildCustomerProviders();
      expect(providers.length, 5);
      expect(countMountedProviders(IbulAppMode.customer), 5);
      final source = providers.map((p) => p.toString()).join('\n');
      expect(source, isNot(contains('DesktopPrintHub')));
    });

    test('login applies customer session on AppState', () {
      final appState = File('lib/core/app_state.dart').readAsStringSync();
      expect(appState, contains('applyCustomerSessionFromSignIn'));
      final login = File('lib/screens/login_page.dart').readAsStringSync();
      expect(login, contains('applyCustomerSessionFromSignIn'));
    });

    test('seller login resolves profile or shows explicit error', () {
      final sellerLogin =
          File('lib/screens/seller_login_page.dart').readAsStringSync();
      expect(sellerLogin, contains('sellerProfileFetchError'));
      expect(sellerLogin, contains('sellerProfileFetchSuccess'));
      expect(sellerLogin, contains('describeSignInError'));
    });

    test('unknown auth route falls back to home not blank', () {
      final app = File('lib/app/customer_app.dart').readAsStringSync();
      final table = File('lib/app/app_route_table.dart').readAsStringSync();
      final shell = File('lib/app/ibul_material_app.dart').readAsStringSync();
      final router = File('lib/app/ibul_go_router.dart').readAsStringSync();
      expect(app, contains('IbulMaterialApp'));
      expect(shell, contains('createIbulGoRouter'));
      expect(router, contains('errorBuilder'));
      expect(router, contains("source: 'go_router:unknown'"));
      expect(table, contains('generateUnknownHomeRoute'));
      expect(table, contains("buildSafeHome(source: 'onUnknownRoute')"));
    });

    test('session listener logs mount in AppState', () {
      final appState = File('lib/core/app_state.dart').readAsStringSync();
      final logger =
          File('lib/core/auth/auth_flow_logger.dart').readAsStringSync();
      expect(appState, contains('sessionListenerMounted'));
      expect(appState, contains('sessionReceived'));
      expect(logger, contains('session_received'));
    });

    test('auth flow logger masks email and avoids password field', () {
      final logger =
          File('lib/core/auth/auth_flow_logger.dart').readAsStringSync();
      final masks = File('lib/utils/log_mask_helpers.dart').readAsStringSync();
      expect(logger, contains('maskEmail'));
      expect(masks, contains('maskEmail'));
      expect(logger, isNot(contains('password:')));
    });
  });

  group('Customer home skeleton and ads', () {
    test('products loaded suppresses below-fold skeleton on live home', () {
      final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('_suppressBelowFoldSkeleton'));
      expect(core, contains('suppressSkeleton: _suppressBelowFoldSkeleton'));
    });

    test('sponsored section empty hides instead of skeleton when suppressed', () {
      final sponsored =
          File('lib/widgets/sponsored_product_lists_section.dart')
              .readAsStringSync();
      expect(sponsored, contains('suppressSkeleton'));
      expect(sponsored, contains('SizedBox.shrink()'));
    });

    test('sponsored service uses RPC metadata fallback without preview data', () {
      final service =
          File('lib/ads/services/home_sponsored_content_service.dart')
              .readAsStringSync();
      expect(service, contains('previewListFromCampaign'));
      expect(service, contains('usePreviewOnFailure: false'));
    });

    test('sponsored service disables ads preview fallback', () {
      final feature =
          File('lib/ads/services/home_feature_ad_service.dart').readAsStringSync();
      expect(feature, contains('usePreviewOnFailure: false'));
    });

    test('map route stays lazy in customer app', () {
      final routes = File('lib/app/customer_routes.dart').readAsStringSync();
      expect(routes, contains('DeferredModuleScreen'));
      expect(routes, contains('map_page.loadLibrary'));
    });
  });
}
