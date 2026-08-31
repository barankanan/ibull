import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/site_info_routes.dart';
import 'package:ibul_app/screens/feature_coming_soon_page.dart';
import 'package:ibul_app/screens/legal/legal_document.dart';
import 'package:ibul_app/screens/legal/legal_document_page.dart';
import 'package:ibul_app/screens/legal/public_tracking_lookup_page.dart';
import 'package:ibul_app/widgets/web_footer.dart';

void main() {
  testWidgets('privacy policy page renders body copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentPage(documentId: LegalDocumentId.privacy),
      ),
    );

    expect(find.text('Gizlilik Politikası'), findsWidgets);
    expect(find.textContaining('Kart numarası'), findsOneWidget);
  });

  testWidgets('footer gizlilik link opens legal page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 80),
                Text('HOME_PAGE'),
                WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Gizlilik Politikası').last, 200);
    await tester.tap(find.text('Gizlilik Politikası').last);
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentPage), findsOneWidget);
    expect(find.textContaining('Kart numarası'), findsOneWidget);
  });

  testWidgets('kariyer footer link is honest coming soon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 80),
                WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Kariyer').last, 200);
    await tester.tap(find.text('Kariyer').last);
    await tester.pumpAndSettle();

    expect(find.byType(FeatureComingSoonPage), findsOneWidget);
    expect(find.text('Yakında aktif olacak'), findsOneWidget);
  });

  testWidgets('site info routes map legal and lookup pages', (tester) async {
    expect(
      SiteInfoRoutes.pageForPath(SiteInfoRoutes.privacy),
      isA<LegalDocumentPage>(),
    );
    expect(
      SiteInfoRoutes.pageForPath(SiteInfoRoutes.shipmentLookup),
      isA<PublicTrackingLookupPage>(),
    );
    expect(
      SiteInfoRoutes.pageForPath(SiteInfoRoutes.career),
      isA<FeatureComingSoonPage>(),
    );

    await tester.pumpWidget(
      const MaterialApp(home: PublicTrackingLookupPage()),
    );
    expect(find.text('Gönderi kodu ile takip'), findsOneWidget);
    await tester.tap(find.text('Takip et'));
    await tester.pump();
    expect(find.textContaining('Geçerli bir İHIZ kodu'), findsOneWidget);
  });
}
