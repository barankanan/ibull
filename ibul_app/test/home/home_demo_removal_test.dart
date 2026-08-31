import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home demo removal and real ads', () {
    test('mobile home does not render hair_care DynamicBrandLayoutsSection', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, isNot(contains('_DynamicBrandLayoutsSection(')));
      expect(core, contains('HomeCategoryCardSections'));
      expect(core, isNot(contains('_hairCareLayoutsForHome.isNotEmpty')));
    });

    test('mobile home loads HomeFeatureAdService category cards', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('HomeFeatureAdService'));
      expect(core, contains('_fetchHomeFeatureAds'));
      expect(core, contains('HomeAdsDiagnostics.demoDisabled'));
      expect(core, isNot(contains('_loadHairCareLayoutConfig(),')));
    });

    test('desktop core renders real feature ads and hero fetch', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('_fetchHomeFeatureAds'));
      expect(core, contains('HomeCategoryCardSections'));
      expect(core, contains('IbulHeroCampaignRow'));
      expect(core, contains('HomeHeroBannersFetch'));
    });

    test('home hides ad slot when no active ad, no fake fallback', () {
      final fetch =
          File('lib/services/home_hero_banners_fetch.dart').readAsStringSync();
      final cards =
          File('lib/widgets/home_category_card_section.dart').readAsStringSync();
      expect(fetch, isNot(contains('Black Friday')));
      expect(fetch, isNot(contains('assets/images/banners')));
      expect(cards, contains('if (groups.isEmpty)'));
      expect(cards, contains('SizedBox.shrink()'));
    });

    test('products loaded suppresses below-fold skeleton', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('_suppressBelowFoldSkeleton'));
      expect(core, contains('suppressSkeleton: _suppressBelowFoldSkeleton'));
      expect(core, contains('HomeSkeletonDiagnostics.hide'));
    });

    test('sponsored empty does not keep deferred skeleton when suppressed', () {
      final sponsored = File(
        'lib/screens/home/deferred/deferred_home_sponsored_section.dart',
      ).readAsStringSync();
      expect(sponsored, contains('suppressSkeleton'));
      expect(sponsored, contains('SizedBox.shrink'));
    });

    test('Hatay Yemekleri not in production home render path', () {
      final lib = Directory('lib/screens');
      var inHomePath = false;
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (!entity.path.contains('home')) continue;
        final content = entity.readAsStringSync();
        if (content.contains('Hatay Yemekleri')) {
          inHomePath = true;
          break;
        }
      }
      expect(inHomePath, isFalse);
    });

    test('Black Friday and Mega Discount not in home screens', () {
      final content =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(content, isNot(contains('Black Friday')));
      expect(content, isNot(contains('Mega Discount')));
      expect(content, isNot(contains('reallygreatsite')));
    });

    test('responsive routing uses HomeScreenCore on all viewports', () {
      final entry =
          File('lib/screens/home_screen_deferred_entry.dart').readAsStringSync();
      expect(entry, contains('HomeScreenCore('));
      expect(entry, isNot(contains('legacy_home.HomeScreen')));
      expect(entry, contains('legacyDemoSectionDisabled: true'));
    });
  });
}
