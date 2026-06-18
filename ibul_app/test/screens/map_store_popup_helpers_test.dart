import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/achievements/helpers/seller_badge_public_display.dart';
import 'package:ibul_app/features/seller/achievements/models/seller_badge_models.dart';
import 'package:ibul_app/features/seller/achievements/services/seller_badge_progress_resolver.dart';
import 'package:ibul_app/features/seller/achievements/widgets/seller_badge_map_popup_row.dart';
import 'package:ibul_app/features/seller/achievements/widgets/seller_badge_widgets.dart';
import 'package:ibul_app/services/store/store_mapping_helpers.dart';

void main() {
  group('map popup description/address separation', () {
    test('resolveMapStoreBio uses description, not address', () {
      expect(
        resolveMapStoreBio({
          'description': 'Mağaza açıklaması',
          'address': 'hatay arsuz hökemdayn. mahallesi',
        }),
        'Mağaza açıklaması',
      );
    });

    test('empty description does not fall back to address', () {
      expect(
        resolveMapStoreBio({
          'description': '',
          'address': 'hatay arsuz hökemdayn. mahallesi',
        }),
        isEmpty,
      );
    });

    test('formatMapStoreAddress builds compact address line', () {
      expect(
        formatMapStoreAddress(
          address: 'Hökemdayn Mah.',
          district: 'Arsuz',
          city: 'Hatay',
        ),
        'Hökemdayn Mah., Arsuz, Hatay',
      );
    });
  });

  group('map navigation urls', () {
    test('google maps route url uses origin when available', () {
      expect(
        buildGoogleMapsNavigationUrl(
          latitude: 36.2025,
          longitude: 36.1605,
          originLatitude: 36.21,
          originLongitude: 36.17,
        ),
        contains('origin=36.21,36.17'),
      );
      expect(
        buildGoogleMapsNavigationUrl(
          latitude: 36.2025,
          longitude: 36.1605,
          originLatitude: 36.21,
          originLongitude: 36.17,
        ),
        contains('destination=36.2025,36.1605'),
      );
    });

    test('google maps search url is used without origin', () {
      expect(
        buildGoogleMapsNavigationUrl(
          latitude: 36.2025,
          longitude: 36.1605,
        ),
        'https://www.google.com/maps/search/?api=1&query=36.2025,36.1605',
      );
    });

    test('apple maps directions url uses destination coordinates', () {
      expect(
        buildAppleMapsNavigationUrl(
          latitude: 36.2025,
          longitude: 36.1605,
          directions: true,
        ),
        'http://maps.apple.com/?daddr=36.2025,36.1605',
      );
    });
  });

  group('map store select', () {
    test('includes description column by default', () {
      expect(
        mapStoreSelect(includeBrandVerified: false),
        contains(mapStoreDescriptionColumn),
      );
    });

    test('can omit description column for fallback queries', () {
      expect(
        mapStoreSelect(
          includeBrandVerified: false,
          includeDescription: false,
        ),
        isNot(contains(mapStoreDescriptionColumn)),
      );
    });
  });

  group('map popup header layout', () {
    testWidgets('places badges to the right of store info', (tester) async {
      final progress = SellerBadgeProgressResolver.resolveById(
        'popular_store',
        const SellerBadgeStoreMetrics(
          followerCount: 300,
          productCount: 1,
          profileComplete: true,
          hasLogo: true,
          hasDescription: true,
          hasCategory: true,
          hasContactInfo: true,
        ),
      );
      expect(progress, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 55, height: 55),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Destina'),
                        SizedBox(height: 8),
                        Text('1 Takipçi'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  MapStorePopupHeaderTrailing(
                    badges: [progress!],
                    onClose: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final badgeDx = tester.getTopLeft(find.byType(SellerBadgeMapPopupRow)).dx;
      final nameDx = tester.getTopLeft(find.text('Destina')).dx;
      expect(badgeDx, greaterThan(nameDx));
    });

    testWidgets('header trailing omits badge space when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapStorePopupHeaderTrailing(
              badges: const [],
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byType(SellerBadgeMapPopupRow), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('header trailing keeps max two badges', (tester) async {
      const metrics = SellerBadgeStoreMetrics(
        followerCount: 1200,
        productCount: 10,
        completedOrderCount: 60,
        positiveReviewCount: 50,
        averageRating: 4.8,
        profileComplete: true,
        hasLogo: true,
        hasDescription: true,
        hasCategory: true,
        hasContactInfo: true,
        hasRegionInfo: true,
        isBrandVerified: true,
      );
      final badges = SellerBadgePublicDisplay.mapPopupBadges(metrics);
      expect(badges.length, lessThanOrEqualTo(2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapStorePopupHeaderTrailing(
              badges: badges,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byType(SellerBadgeIcon), findsNWidgets(badges.length));
    });
  });
}
