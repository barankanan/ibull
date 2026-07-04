import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/home_sponsored_banner.dart';

void main() {
  group('HomeSponsoredBannerDimensions', () {
    test('mobile width caps banner height at 120', () {
      final wide = HomeSponsoredBannerDimensions.resolve(
        availableWidth: 390,
        screenWidth: 390,
      );
      expect(wide.height, 65);
      expect(wide.width, 390);

      final capped = HomeSponsoredBannerDimensions.resolve(
        availableWidth: 800,
        screenWidth: 390,
      );
      expect(capped.height, 120);
      expect(capped.width, 720);
    });

    test('tablet width uses contain fit breakpoint', () {
      final size = HomeSponsoredBannerDimensions.resolve(
        availableWidth: 700,
        screenWidth: 768,
      );
      expect(size.height, lessThanOrEqualTo(180));
      expect(
        HomeSponsoredBannerDimensions.fitForScreen(768),
        BoxFit.contain,
      );
    });

    test('desktop width respects max height 220', () {
      final size = HomeSponsoredBannerDimensions.resolve(
        availableWidth: 1400,
        screenWidth: 1280,
      );
      expect(size.height, lessThanOrEqualTo(220));
      expect(size.width, lessThanOrEqualTo(1320));
    });

    test('mobile hero slot height is stable constant', () {
      expect(HomeSponsoredBannerDimensions.mobileHeroBannerHeight, 130);
    });
  });

  group('HomeSponsoredBanner layout stability', () {
    const width = 360.0;
    const height = 120.0;

    Future<void> pumpBanner(
      WidgetTester tester, {
      required Widget banner,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: banner),
          ),
        ),
      );
    }

    testWidgets('loading, loaded and empty states share exact size', (
      tester,
    ) async {
      for (final banner in [
        HomeSponsoredBanner(width: width, height: height, isLoading: true),
        HomeSponsoredBanner(width: width, height: height),
        HomeSponsoredBanner(
          width: width,
          height: height,
          imageUrl: 'https://cdn.example.com/banner.webp',
        ),
      ]) {
        await pumpBanner(tester, banner: banner);
        final box = tester.getSize(find.byType(HomeSponsoredBanner));
        expect(box.width, width);
        expect(box.height, height);
      }
    });

    testWidgets('Sponsorlu badge visible on banner widget', (tester) async {
      await pumpBanner(
        tester,
        banner: HomeSponsoredBanner(
          width: width,
          height: height,
          isLoading: true,
        ),
      );
      expect(find.text('Sponsorlu'), findsOneWidget);
    });

    testWidgets('state transition does not change outer size', (tester) async {
      await pumpBanner(
        tester,
        banner: HomeSponsoredBanner(
          width: width,
          height: height,
          isLoading: true,
        ),
      );
      final loadingSize = tester.getSize(find.byType(HomeSponsoredBanner));

      await pumpBanner(
        tester,
        banner: HomeSponsoredBanner(
          width: width,
          height: height,
          imageUrl: 'https://cdn.example.com/banner.webp',
        ),
      );
      final loadedSize = tester.getSize(find.byType(HomeSponsoredBanner));

      expect(loadedSize, loadingSize);
    });
  });
}
