import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/product_visibility_helper.dart';

void main() {
  group('Home product visibility parity with store detail', () {
    test('public visible when approval columns absent (store menu projection)', () {
      final row = <String, dynamic>{
        'id': 'p1',
        'status': 'active',
        'name': 'Teknosa Phone',
      };
      expect(ProductVisibilityHelper.isPublicVisibleProductMap(row), isTrue);
    });

    test('public visible for Aktif status without approval keys', () {
      final row = <String, dynamic>{
        'id': 'p2',
        'status': 'Aktif',
        'seller_id': 'seller-1',
      };
      expect(ProductVisibilityHelper.isPublicVisibleProductMap(row), isTrue);
    });

    test('rejected when approval column present but empty', () {
      final row = <String, dynamic>{
        'id': 'p3',
        'status': 'active',
        'approval_status': '',
      };
      expect(ProductVisibilityHelper.isPublicVisibleProductMap(row), isFalse);
    });

    test('approved when explicit approval token present', () {
      final row = <String, dynamic>{
        'id': 'p4',
        'status': 'active',
        'approval_status': 'approved',
      };
      expect(ProductVisibilityHelper.isPublicVisibleProductMap(row), isTrue);
    });

    test('filterPublicProductMaps matches store menu helper usage', () {
      final rows = [
        {'id': '1', 'status': 'active'},
        {'id': '2', 'status': 'active', 'approval_status': ''},
        {'id': '3', 'status': 'draft'},
      ];
      final filtered = ProductVisibilityHelper.filterPublicProductMaps(rows);
      expect(filtered.map((r) => r['id']), ['1']);
    });

    test('home fetch prefers catalog projection without approval columns', () {
      final service =
          File('lib/services/supabase_service.dart').readAsStringSync();
      expect(service, contains('_homeProductCatalogSelectFields'));
      final catalogIdx = service.indexOf('_homeProductCatalogSelectFields');
      final cardIdx = service.indexOf('_homeProductCardSelectFields');
      expect(catalogIdx, greaterThan(-1));
      expect(cardIdx, greaterThan(-1));
      expect(catalogIdx, lessThan(cardIdx));
      expect(service, contains('approvalFilterRetry'));
    });

    test('home fetch retries when approval projection filters all rows', () {
      final service =
          File('lib/services/supabase_service.dart').readAsStringSync();
      expect(service, contains('_homeSelectIncludesApprovalColumns'));
      expect(service, contains('approvalFilteredEmptyReport'));
    });

    test('store menu fetch omits approval columns like home catalog select', () {
      final storeService =
          File('lib/services/store_service.dart').readAsStringSync();
      final menuBlock = storeService.substring(
        storeService.indexOf('getMenuProductsBySellerId'),
        storeService.indexOf('getSellerProductsForPrinterMapping'),
      );
      expect(menuBlock, isNot(contains('approval_status')));
      expect(menuBlock, contains('filterPublicProductMaps'));
    });

    test('home_screen_core uses fetchInitialHomeProductsReport not preview DTO', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('fetchInitialHomeProductsReport'));
      expect(core, isNot(contains('HomeProductPreviewSectionDto')));
      expect(core, isNot(contains('HomeProductPreviewCard')));
    });

    test('home does not render demo product identifiers', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, isNot(contains('Black Friday')));
      expect(core, isNot(contains('Mega Discount')));
      expect(core, isNot(contains('Günün Fırsatı')));
    });

    test('home ad section uses real Supabase ad services', () {
      final hero =
          File('lib/services/home_hero_banners_fetch.dart').readAsStringSync();
      final sponsored =
          File('lib/widgets/sponsored_product_lists_section.dart')
              .readAsStringSync();
      expect(hero, contains("from('campaign_images')"));
      expect(sponsored, contains('HomeSponsoredContentService'));
      expect(sponsored, contains('HomeAdsDiagnostics'));
    });
  });
}
