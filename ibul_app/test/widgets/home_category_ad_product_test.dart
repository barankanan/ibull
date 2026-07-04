import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home category ad product render', () {
    test('ad section does not show category empty placeholder text', () {
      final source =
          File('lib/widgets/home_category_card_section.dart').readAsStringSync();
      expect(source, isNot(contains('Bu alanda şu an görüntülenecek ürün yok.')));
      expect(source, contains('fetchAdLinkedProductsReport'));
      expect(source, contains('orderAdLinkedProducts'));
    });

    test('supabase ad fetch prefers rpc with fallback', () {
      final source =
          File('lib/services/supabase_service.dart').readAsStringSync();
      expect(source, contains('get_ad_linked_products_by_ids'));
      expect(source, contains('fetchAdLinkedProductsReport'));
      expect(source, contains('_isMissingAdLinkedRpcSignature'));
      expect(source, contains('1-arg'));
      expect(source, contains('adLinkedDisplayRejectReason'));
    });

    test('home feature ad service uses per-campaign fetchAdLinkedProductsReport', () {
      final source =
          File('lib/ads/services/home_feature_ad_service.dart').readAsStringSync();
      expect(source, contains('fetchAdLinkedProductsReport'));
      expect(source, contains('home_page_groups_v2'));
      expect(source, isNot(contains('getProductsByIds(')));
    });
  });
}
