import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/restaurant_offline_banner.dart';

void main() {
  group('Garson provider scope (web ProviderNotFound regresyonu)', () {
    testWidgets('non-food category passes child through without provider',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RestaurantOfflineReconnectListener(
              restaurantId: 'seller-test',
              storeCategory: 'elektronik',
              child: Text('garson-child'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('garson-child'), findsOneWidget);
    });

    test('reconnect listener no longer depends on Provider Consumer', () {
      final source = File('lib/widgets/restaurant_offline_banner.dart')
          .readAsStringSync();
      expect(source.contains('Consumer<RestaurantConnectivityService>'), isFalse);
      expect(
        source.contains('RestaurantConnectivityService.instance'),
        isTrue,
      );
    });

    test('seller panel guards DesktopPrintHub read (web provider yok)', () {
      final source =
          File('lib/screens/seller_panel_page.dart').readAsStringSync();
      expect(
        source.contains(
          '[GarsonPage] provider_missing name=DesktopPrintHub',
        ),
        isTrue,
      );
      expect(source.contains('on ProviderNotFoundException'), isTrue);
    });
  });

  group('Garson scroll mimarisi (tek ana scroll)', () {
    String sellerPanelSource() =>
        File('lib/screens/seller_panel_page.dart').readAsStringSync();

    String garsonModuleRegion() {
      final source = sellerPanelSource();
      final start = source.indexOf('GARSON MODÜLÜ');
      final end = source.indexOf('Widget _buildGarsonTopBar');
      expect(start, greaterThan(0), reason: 'Garson modülü bölümü bulunamadı');
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    test('garson module wraps body in a single page-level scroll view', () {
      final source = sellerPanelSource();
      expect(source.contains('_buildGarsonModuleBody('), isTrue);
      expect(source.contains('minBoardHeight'), isTrue);
      // Board artık bounded Expanded penceresine sıkışmıyor.
      expect(
        source.contains(
          'constraints: BoxConstraints(minHeight: minBoardHeight)',
        ),
        isTrue,
      );
    });

    test('garson module has single primary vertical scroll container', () {
      final region = garsonModuleRegion();
      // 1 dikey ana scroll (sayfa) + 1 yatay sayaç şeridi; masa grid'i için
      // ikinci bir dikey SingleChildScrollView KALMAMALI.
      expect(
        'SingleChildScrollView('.allMatches(region).length,
        2,
        reason:
            'Garson modülünde yalnız 1 dikey ana scroll + 1 yatay sayaç '
            'şeridi olmalı — grid için iç dikey scroll yasak',
      );
      expect(
        'scrollDirection: Axis.horizontal'.allMatches(region).length,
        1,
        reason: 'İkinci scroll yalnız yatay sayaç şeridi olabilir',
      );
      // Grid alanını bounded pencereye hapseden Expanded geri gelmesin.
      expect(region.contains('Expanded(\n          child: sellerId.isEmpty'),
          isFalse);
    });

    test('garson table grid is shrinkWrap + NeverScrollable', () {
      final source = sellerPanelSource();
      final start = source.indexOf('Widget _buildGarsonGroupedTableGrids(');
      expect(start, greaterThan(0));
      final end = source.indexOf('Widget _buildGarsonMobileBoardToolbar(');
      expect(end, greaterThan(start));
      final region = source.substring(start, end);
      expect(region.contains('GridView.builder('), isTrue);
      expect(region.contains('shrinkWrap: true'), isTrue);
      expect(
        region.contains('physics: const NeverScrollableScrollPhysics()'),
        isTrue,
      );
    });
  });
}
