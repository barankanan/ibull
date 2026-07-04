import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StoreService exposes batch public info lookup', () {
    final source = File('lib/services/store_service.dart').readAsStringSync();

    expect(source.contains('getStorePublicInfoByIds'), isTrue);
    expect(source.contains(".inFilter('seller_id'"), isTrue);
    expect(source.contains('seller_id, logo_url, business_name'), isTrue);
  });

  test('HomeCategoryCardSection uses batch logo loader', () {
    final source =
        File('lib/widgets/home_category_card_section.dart').readAsStringSync();

    expect(source.contains('getStorePublicInfoByIds'), isTrue);
    expect(source.contains('getStorePublicInfoById(ad.sellerId)'), isFalse);
  });
}
