import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home UI no demo data', () {
    test(
      'home_screen_core does not use HomeBannerDefaults or preview cards',
      () {
        final core = File(
          'lib/screens/home_screen_core.dart',
        ).readAsStringSync();
        expect(core, isNot(contains('HomeBannerDefaults')));
        expect(core, isNot(contains('HomeProductPreviewCard')));
        expect(core, isNot(contains('HomeProductPreviewSectionDto')));
        expect(core, isNot(contains('IbulNearbyProductsSection')));
        expect(core, contains('HomeUiDiagnostics.demoDataDisabled'));
        expect(core, contains('SupabaseService.instance'));
        expect(core, contains('DeferredHomeFullRailSection'));
        expect(core, contains('unawaited(_loadHomeVehicles())'));
        expect(core, contains('unawaited(_resolveHomeLocation())'));
        expect(core, isNot(contains('_loadHomeDiscovery')));
        expect(core, contains('_isLoadingNearby'));
        expect(core, contains('_isLoadingVehicles'));
      },
    );

    test('home discovery loader does not sequence vehicles behind GPS', () {
      final loader = File(
        'lib/screens/home/home_discovery_loader.dart',
      ).readAsStringSync();
      expect(loader, contains('loadVehicles()'));
      expect(loader, contains('resolvePosition()'));
      expect(loader, contains('[HomePerf][nearby]'));
      expect(loader, contains('[HomePerf][vehicles]'));
      expect(
        loader,
        isNot(contains('final vehicles = await _publicVehicles();')),
      );
    });

    test('hero banner section does not fallback to asset banners', () {
      final hero = File(
        'lib/screens/home/sections/home_section_hero_banner.dart',
      ).readAsStringSync();
      expect(hero, isNot(contains('HomeBannerDefaults')));
      expect(hero, isNot(contains('Image.asset')));
    });

    test('home hero fetch reads campaign_images only', () {
      final fetch = File(
        'lib/services/home_hero_banners_fetch.dart',
      ).readAsStringSync();
      expect(fetch, contains("from('campaign_images')"));
      expect(fetch, isNot(contains('assets/images/banners')));
    });

    test('full rail uses real ProductCard', () {
      final rail = File(
        'lib/screens/home/sections/home_section_full_rail.dart',
      ).readAsStringSync();
      expect(rail, contains('ProductCard('));
      expect(rail, isNot(contains('HomeProductPreviewCard')));
      expect(rail, isNot(contains('deferred as product_card')));
      expect(rail, contains('HomeUiDiagnostics.realProductCard'));
    });

    test('product detail has no Hatay Yemekleri hardcode', () {
      final lib = Directory('lib');
      var found = false;
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (content.contains('Hatay Yemekleri')) {
          found = true;
          break;
        }
      }
      expect(found, isFalse);
    });

    test('home_screen_core has non-empty body sections when revealed', () {
      final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('_buildHomeSections'));
      expect(core, contains('IbulOpportunityShortcutsSection'));
      expect(core, contains('IbulMobileHomeChrome'));
      expect(core, contains('IbulHeroCampaignRow'));
      expect(core, contains('DeferredHomeFullRailSection'));
      expect(core, contains('grouped: true'));
      final mobileChrome = File(
        'lib/screens/home/sections/ibul_mobile_home_chrome.dart',
      ).readAsStringSync();
      expect(mobileChrome, contains('FeatureMenu'));
    });
  });
}
