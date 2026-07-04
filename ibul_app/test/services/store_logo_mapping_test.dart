import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('batch logo lookup queries stores.seller_id like single lookup', () {
    final storeService = File('lib/services/store_service.dart').readAsStringSync();
    expect(storeService.contains(".eq('seller_id', sellerId)"), isTrue);
    expect(storeService.contains(".inFilter('seller_id', missingIds)"), isTrue);
  });

  test('home category logos resolve sellerId then storeId fallback', () {
    final section =
        File('lib/widgets/home_category_card_section.dart').readAsStringSync();
    expect(section.contains('infoByLookupId[seller]'), isTrue);
    expect(section.contains('infoByLookupId[store]'), isTrue);
    expect(section.contains('ad.storeId'), isTrue);
  });

  test('store logo cache uses 10 minute TTL', () {
    final storeService = File('lib/services/store_service.dart').readAsStringSync();
    expect(storeService.contains('Duration(minutes: 10)'), isTrue);
  });
}
