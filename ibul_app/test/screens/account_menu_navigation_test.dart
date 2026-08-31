import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/site_info_routes.dart';
import 'package:ibul_app/features/ihiz/send/ihiz_package_send_page.dart';
import 'package:ibul_app/screens/account/account_menu_navigation.dart';
import 'package:ibul_app/screens/cart/cart_premium_banner.dart';
import 'package:ibul_app/screens/coming_soon/coming_soon_catalog.dart';
import 'package:ibul_app/screens/coming_soon/coming_soon_shelf_page.dart';
import 'package:ibul_app/screens/feature_coming_soon_page.dart';
import 'package:ibul_app/screens/legal/legal_document_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  Widget harness({required Widget home}) {
    return MaterialApp(
      home: home,
      onGenerateRoute: (settings) {
        if (settings.name == AccountMenuNavigation.becomeSellerPath) {
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: Text('BecomeSellerStub'),
            ),
          );
        }
        final sitePage = SiteInfoRoutes.pageForPath(settings.name ?? '');
        if (sitePage != null) {
          return MaterialPageRoute<void>(builder: (_) => sitePage);
        }
        return null;
      },
    );
  }

  testWidgets('premium opens honest coming-soon, not a fake subscribe flow',
      (tester) async {
    await tester.pumpWidget(
      harness(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AccountMenuNavigation.openPremium(context),
            child: const Text('open-premium'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-premium'));
    await tester.pumpAndSettle();

    expect(find.byType(FeatureComingSoonPage), findsOneWidget);
    expect(find.text('iBul Premium'), findsWidgets);
    expect(find.text('Yakında aktif olacak'), findsOneWidget);
    expect(find.textContaining('abonelik sayfası değil'), findsOneWidget);
  });

  testWidgets('store apply uses become-seller named route', (tester) async {
    await tester.pumpWidget(
      harness(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AccountMenuNavigation.openStoreApply(context),
            child: const Text('open-store'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-store'));
    await tester.pumpAndSettle();

    expect(find.text('BecomeSellerStub'), findsOneWidget);
  });

  testWidgets('help opens FAQ legal page', (tester) async {
    await tester.pumpWidget(
      harness(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AccountMenuNavigation.openHelp(context),
            child: const Text('open-help'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-help'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentPage), findsOneWidget);
  });

  testWidgets('fast send opens live İHIZ package page', (tester) async {
    await tester.pumpWidget(
      harness(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AccountMenuNavigation.openFastSend(context),
            child: const Text('open-send'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-send'));
    await tester.pumpAndSettle();

    expect(find.byType(IhizPackageSendPage), findsOneWidget);
    expect(find.text('Evden teslim al'), findsOneWidget);
  });

  testWidgets('cart premium CTA opens the Yakında shelf, not a subscribe flow',
      (tester) async {
    await tester.pumpWidget(harness(home: const Scaffold(body: CartPremiumBanner())));

    expect(find.text('Premium\'a Geç'), findsNothing);
    expect(find.text('Listeyi gör'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cart-premium-cta')));
    await tester.pumpAndSettle();

    expect(find.byType(ComingSoonShelfPage), findsOneWidget);
    expect(find.text('iBul Premium'), findsOneWidget);
    expect(find.text('Barkod Okut'), findsOneWidget);
  });

  testWidgets('barcode catalog item opens honest coming-soon', (tester) async {
    await tester.pumpWidget(
      harness(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => ComingSoonCatalog.open(
              context,
              ComingSoonCatalog.barcode,
            ),
            child: const Text('open-barcode'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-barcode'));
    await tester.pumpAndSettle();

    expect(find.byType(FeatureComingSoonPage), findsOneWidget);
    expect(find.text('Barkod Okut'), findsWidgets);
    expect(find.text('Beni haberdar et'), findsNothing);
  });

  testWidgets('coming-soon page has no fake waitlist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FeatureComingSoonPage(
          title: 'Test',
          description: 'Açıklama',
        ),
      ),
    );

    expect(find.text('Beni haberdar et'), findsNothing);
    expect(find.text('Yakında aktif olacak'), findsOneWidget);
  });
}
