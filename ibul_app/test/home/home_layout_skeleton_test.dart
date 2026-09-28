import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/web_home_boot_shell.dart';
import 'package:ibul_app/widgets/skeleton_loading.dart';

void main() {
  group('Home layout skeleton and ads', () {
    test('responsive entry routes desktop to HomeScreenCore', () {
      final entry = File(
        'lib/screens/home_screen_deferred_entry.dart',
      ).readAsStringSync();
      expect(entry, contains('ResponsiveHomeScreen'));
      expect(entry, contains('HomeScreenCore'));
      expect(entry, contains('desktopBreakpoint = IbulChrome.web'));
    });

    test('responsive entry uses HomeScreenCore on mobile viewports too', () {
      final entry = File(
        'lib/screens/home_screen_deferred_entry.dart',
      ).readAsStringSync();
      expect(entry, contains('HomeScreenCore('));
      expect(entry, isNot(contains('legacy_home.HomeScreen')));
      expect(entry, contains('mobileDesignActive: !isDesktop'));
    });

    test('desktop hero row always rendered on web', () {
      final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('if (isWeb)'));
      expect(core, contains('IbulHeroCampaignRow'));
      expect(core, contains('IbulMobileHomeChrome'));
      expect(
        core,
        isNot(contains('_isLoadingHero || _heroBannerUrls.isNotEmpty')),
      );
    });

    test('deferred sections support suppressSkeleton after products load', () {
      final rail = File(
        'lib/screens/home/deferred/deferred_home_full_rail_section.dart',
      ).readAsStringSync();
      final sponsored = File(
        'lib/screens/home/deferred/deferred_home_sponsored_section.dart',
      ).readAsStringSync();
      expect(rail, contains('suppressSkeleton'));
      expect(rail, contains('maxSkeletonDuration'));
      expect(sponsored, contains('suppressSkeleton'));
      expect(sponsored, contains('_shouldShowSkeleton'));
    });

    test('full rail paints cards as soon as products exist', () {
      final section = File(
        'lib/screens/home/sections/home_section_full_rail.dart',
      ).readAsStringSync();
      expect(section, contains('isLoading && products.isEmpty'));
      expect(section, contains('HomeProductRailSkeleton()'));
      expect(section, contains('_HomeProductHorizontalRail'));
      expect(section, contains('HomeProductRailGroups.build'));
      expect(section, contains('ProductCard('));
      expect(section, isNot(contains('deferred as product_card')));
    });

    test('hero fetch logs raw active rendered counts', () {
      final fetch = File(
        'lib/services/home_hero_banners_fetch.dart',
      ).readAsStringSync();
      expect(fetch, contains('HomeAdsDiagnostics.heroRaw'));
      expect(fetch, contains('HomeAdsDiagnostics.heroActive'));
      expect(fetch, contains('HomeAdsDiagnostics.heroRendered'));
      expect(fetch, contains('HomeAdsDiagnostics.heroHidden'));
    });

    test('hero fetch has no demo asset fallback', () {
      final fetch = File(
        'lib/services/home_hero_banners_fetch.dart',
      ).readAsStringSync();
      expect(fetch, isNot(contains('Black Friday')));
      expect(fetch, isNot(contains('assets/images/banners')));
    });

    test('home core passes suppressSkeleton when products ready', () {
      final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('_suppressBelowFoldSkeleton'));
      expect(core, contains('suppressSkeleton: _suppressBelowFoldSkeleton'));
      expect(core, contains('HomeSkeletonDiagnostics.hide'));
    });

    test('skeleton diagnostics logging exists', () {
      final diagnostics = File(
        'lib/core/home_data_diagnostics.dart',
      ).readAsStringSync();
      expect(diagnostics, contains('HomeSkeletonDiagnostics'));
      expect(diagnostics, contains('[HomeSkeleton] show'));
      expect(diagnostics, contains('[HomeSection] state='));
    });
    test('sponsored lists suppresses skeleton when products ready', () {
      final sponsored = File(
        'lib/widgets/sponsored_product_lists_section.dart',
      ).readAsStringSync();
      expect(sponsored, contains('suppressSkeleton'));
      expect(sponsored, contains('products_loaded'));
      expect(sponsored, contains('SizedBox.shrink()'));
    });

    test('sponsored service logs filter pipeline', () {
      final service = File(
        'lib/ads/services/home_sponsored_content_service.dart',
      ).readAsStringSync();
      expect(service, contains('sponsoredAfterDateFilter'));
      expect(service, contains('sponsoredAfterPlacementFilter'));
      expect(service, contains('sponsoredHidden'));
    });

    test('web boot shell uses storefront card skeleton not stacked bars', () {
      final shell = File(
        'lib/screens/web_home_boot_shell.dart',
      ).readAsStringSync();
      expect(shell, contains('HomeStorefrontSkeleton()'));
      expect(shell, isNot(contains('height: 44')));
      expect(shell, isNot(contains('height: 160')));
    });

    test('deferred full rail placeholder is a product-card rail', () {
      final rail = File(
        'lib/screens/home/deferred/deferred_home_full_rail_section.dart',
      ).readAsStringSync();
      expect(rail, contains('HomeProductRailSkeleton()'));
      expect(rail, isNot(contains('height: 312')));
    });

    testWidgets('WebHomeShell paints product card placeholders', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: WebHomeShell()));
      await tester.pump();

      expect(find.byType(HomeStorefrontSkeleton), findsOneWidget);
      expect(find.byType(ProductCardSkeleton), findsWidgets);
    });

    testWidgets(
      'product rail skeleton is a row of cards, not a full-width bar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeProductRailSkeleton())),
        );
        await tester.pump();

        expect(find.byType(ProductCardSkeleton), findsNWidgets(5));
      },
    );
  });
}
