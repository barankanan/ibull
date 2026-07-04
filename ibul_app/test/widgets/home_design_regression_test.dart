import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/home_product_preview.dart';
import 'package:ibul_app/widgets/home_product_preview_card.dart';

void main() {
  group('Home design regression', () {
    test('deferred entry loads lean HomeScreenCore with staged sections', () {
      final entry =
          File('lib/screens/home_screen_deferred_entry.dart').readAsStringSync();
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      final legacy =
          File('lib/screens/home_screen_legacy_full.dart').readAsStringSync();

      expect(entry, contains('home_screen_core.dart'));
      expect(entry, contains('HomeScreenCore('));
      expect(entry, isNot(contains('home_screen_legacy_full.dart')));

      expect(core, contains('web_header.dart'));
      expect(core, contains('custom_header.dart'));
      expect(core, contains('AppAnimatedIndexedStack'));
      expect(core, contains('HomeLazyRoutes.mapTab'));
      expect(core, contains('kPreviewBatchSize = 8'));

      expect(legacy, contains('web_header.dart'));
      expect(legacy, contains('custom_header.dart'));
    });

    test('CustomHeader source keeps bell, search and camera layout', () {
      final header = File('lib/widgets/custom_header.dart').readAsStringSync();
      expect(header, contains('Icons.notifications_none_rounded'));
      expect(header, contains('Icons.camera_alt_outlined'));
      expect(header, contains('Marka, ürün veya kategori ara...'));
    });

    test('legacy web home uses bounded max width layout', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('BoxConstraints(maxWidth: 1400)'));
      expect(core, contains('WebStickyFooterScrollView'));
    });

    testWidgets('HomeProductPreviewCard shows quick view eye icon', (tester) async {
      const preview = HomeProductPreview(
        id: 'p1',
        name: 'Test Ürün',
        imageUrl: 'https://example.com/img.jpg',
        price: 99.99,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HomeProductPreviewCard(preview: preview),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeProductPreviewCard quick view opens sheet', (tester) async {
      const preview = HomeProductPreview(
        id: 'p1',
        name: 'Test Ürün Adı',
        imageUrl: 'https://example.com/img.jpg',
        price: 99.99,
        brand: 'Marka',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HomeProductPreviewCard(preview: preview),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Test Ürün Adı'), findsWidgets);
    });
  });
}
