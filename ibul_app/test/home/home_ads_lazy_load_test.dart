import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/home_sponsored_banner.dart';
import 'package:ibul_app/widgets/skeleton_loading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home ads lazy load UI', () {
    testWidgets('hero ad placeholder sabit aspect ratio render edilir', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeSponsoredBanner(
              width: 360,
              height: 120,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoading), findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 120);
      expect(sizedBox.width, 360);
    });

    testWidgets('ad image error kaliteli placeholder gösterir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeSponsoredBanner(
              width: 300,
              height: 100,
              imageUrl: '',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('Sponsorlu'), findsOneWidget);
    });

    testWidgets('loading banner layout shift yapmaz', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HomeSponsoredBanner(
                  width: 300,
                  height: HomeSponsoredBannerDimensions.mobileMaxHeight,
                  isLoading: true,
                ),
                const SizedBox(height: 8),
                HomeSponsoredBanner(
                  width: 300,
                  height: HomeSponsoredBannerDimensions.mobileMaxHeight,
                  imageUrl: 'https://invalid.example/banner.jpg',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HomeSponsoredBanner), findsNWidgets(2));
      final boxes = tester.renderObjectList(find.byType(SizedBox));
      expect(boxes.length, greaterThan(1));
    });

    test('HomeSponsoredBannerDimensions desktop/mobile boyutları', () {
      final mobile = HomeSponsoredBannerDimensions.resolve(
        availableWidth: 360,
        screenWidth: 390,
      );
      expect(mobile.height, lessThanOrEqualTo(
        HomeSponsoredBannerDimensions.mobileMaxHeight,
      ));

      final desktop = HomeSponsoredBannerDimensions.resolve(
        availableWidth: 1200,
        screenWidth: 1400,
      );
      expect(desktop.width, lessThanOrEqualTo(
        HomeSponsoredBannerDimensions.desktopBannerMaxWidth,
      ));
    });
  });
}
