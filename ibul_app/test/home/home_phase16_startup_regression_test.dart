import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/home/deferred/deferred_home_hero_section.dart';
import 'package:ibul_app/screens/home/sections/home_section_hero_banner.dart';
import 'package:ibul_app/widgets/skeleton_loading.dart';

void main() {
  group('Phase 16 startup budget', () {
    test('production boot never eagerly loads the full home graph', () {
      const bootFiles = <String>[
        'lib/app/ibul_app_boot.dart',
        'lib/app/ibul_boot_controller.dart',
        'lib/app/app_bootstrap.dart',
        'lib/app/ibul_main_runner.dart',
        'lib/app/app_route_table.dart',
      ];
      for (final path in bootFiles) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('HomeScreenGate.prefetch')),
          reason: '$path must not pull the 185-part home graph into startup',
        );
        expect(
          source,
          isNot(contains('home_entry.loadLibrary')),
          reason: '$path must not load the deferred home entry at startup',
        );
      }
    });

    test('below-fold home sections stay behind HomeViewportSection', () {
      final source =
          File('lib/screens/home/home_initial_page.dart').readAsStringSync();
      expect(source, contains('HomeViewportSection('));
      // Bölümler gerçek viewport geometrisiyle açılmalı; zamanlayıcıyla değil.
      expect(source, isNot(contains('Future.delayed')));
      // Fold altındaki bölümler mount olamazsa scroll'u dinleyemez ve
      // "görünmeden biraz önce yükle" davranışı imkânsız hâle gelir.
      expect(source, contains('cacheExtent:'));
    });

    test('viewport loader measures the scrollable, not the window', () {
      final source =
          File('lib/screens/home/home_viewport_section.dart').readAsStringSync();
      expect(source, contains('getOffsetToReveal'));
      expect(source, contains('viewportDimension'));
      expect(
        source,
        isNot(contains('MediaQuery.sizeOf(context).height')),
        reason: 'pencere yüksekliği header/bottom-nav yüzünden yanlış viewport',
      );
    });

    test('a failed section chunk surfaces retry instead of a blank slot', () {
      final source =
          File('lib/screens/home/home_viewport_section.dart').readAsStringSync();
      expect(source, contains('HomeSectionError'));
      expect(source, contains('_retry'));
      expect(source, contains('_triggered = false'));
    });
  });

  group('Web boot error shell', () {
    test('fatal takeover is limited to the pre-first-frame window', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('isFlutterRuntimeUp'));
      expect(html, contains('flt-glass-pane'));
    });

    test('error filter also matches the fingerprinted entry bundle', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains(r'app\.[0-9a-f]{8,}\.js'));
    });
  });

  group('Hero first viewport', () {
    testWidgets('empty campaign list paints hero chrome, not an endless '
        'skeleton', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeferredHomeHeroSection(
              bannerImageUrls: <String>[],
              isLoading: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeHeroSlotPlaceholder), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsNothing);
    });

    testWidgets('skeleton is shown only while the banner fetch is in flight',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeferredHomeHeroSection(
              bannerImageUrls: <String>[],
              isLoading: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonLoading), findsWidgets);
      expect(find.byType(HomeHeroSlotPlaceholder), findsNothing);
    });

    test('qr fast-path clears hero loading so it cannot hang', () {
      final source =
          File('lib/screens/home/home_initial_page.dart').readAsStringSync();
      final qrIndex = source.indexOf('QrInitialParams.isQrPath');
      expect(qrIndex, greaterThan(0));
      expect(
        source.substring(qrIndex, qrIndex + 400),
        contains('_heroLoading = false'),
      );
    });
  });
}
