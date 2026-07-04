import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_store_profile_dashboard_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final completion = buildStoreProfileCompletion(
    storeName: 'Test Mağaza',
    phone: '+90 555 111 2233',
    email: 'test@magaza.com',
    address: 'Örnek Mah. No:1',
    city: 'İstanbul',
    district: 'Kadıköy',
    description: 'Açıklama',
    website: '',
    coverUrl: null,
    logoUrl: null,
  );

  group('store profile layout', () {
    testWidgets('hero renders store name and upload actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerStoreProfileHero(
              storeName: 'Test Mağaza',
              slogan: 'Kaliteli ürünler',
              isStoreOpen: true,
              completionPercent: completion.percent,
              coverUrl: null,
              logoUrl: null,
              onPickCover: () {},
              onPickLogo: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Mağaza'), findsOneWidget);
      expect(find.text('Kaliteli ürünler'), findsOneWidget);
      expect(find.text('Kapak Yükle'), findsOneWidget);
      expect(find.text('Logo'), findsOneWidget);
    });

    testWidgets('section cards and completion card render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const StoreProfileSectionCard(
                    title: 'Mağaza Bilgileri',
                    subtitle: 'Temel bilgiler',
                    icon: Icons.storefront_rounded,
                    child: Text('form'),
                  ),
                  const SizedBox(height: 12),
                  StoreProfileCompletionCard(snapshot: completion),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Mağaza Bilgileri'), findsOneWidget);
      expect(find.text('Profil Tamamlanma'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('sticky action bar renders save and revert buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreProfileStickyActionBar(
              isLoading: false,
              onSave: () {},
              onRevert: () {},
            ),
          ),
        ),
      );

      expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
      expect(find.text('Değişiklikleri Geri Al'), findsOneWidget);
    });

    testWidgets('media section header toggles label', (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreProfileMediaSectionHeader(
              expanded: expanded,
              onTap: () => expanded = !expanded,
            ),
          ),
        ),
      );

      expect(find.text('Medya ve İçerikler'), findsOneWidget);
    });

    testWidgets('narrow layout does not overflow hero and action bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: SellerStoreProfileHero(
                        storeName: 'Uzun Mağaza Adı Örneği',
                        slogan: 'Slogan',
                        isStoreOpen: false,
                        completionPercent: 40,
                        coverUrl: null,
                        logoUrl: null,
                        onPickCover: () {},
                        onPickLogo: () {},
                        compact: true,
                      ),
                    ),
                  ),
                  StoreProfileStickyActionBar(
                    isLoading: false,
                    onSave: () {},
                    onRevert: () {},
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
