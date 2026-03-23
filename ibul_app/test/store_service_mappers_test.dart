import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store_service_mappers.dart';

void main() {
  test('storeToCamelCase maps store fields for UI', () {
    final mapped = StoreServiceMappers.storeToCamelCase({
      'business_name': 'Teknosa',
      'website': 'https://teknosa.com',
      'support_phone': '555',
      'store_lat': 39.9,
      'store_lng': 32.8,
      'seller_videos': ['video.mp4'],
    });

    expect(mapped['storeName'], 'Teknosa');
    expect(mapped['storeUrl'], 'https://teknosa.com');
    expect(mapped['supportPhone'], '555');
    expect(mapped['storeLat'], 39.9);
    expect(mapped['sellerVideos'], ['video.mp4']);
  });

  test('storeToSnakeCase maps UI fields for persistence', () {
    final mapped = StoreServiceMappers.storeToSnakeCase({
      'storeName': 'Teknosa',
      'supportPhone': '555',
      'storeLat': 39.9,
      'storeLng': 32.8,
      'sellerVideos': ['video.mp4'],
    });

    expect(mapped['business_name'], 'Teknosa');
    expect(mapped['support_phone'], '555');
    expect(mapped['store_lat'], 39.9);
    expect(mapped['store_lng'], 32.8);
    expect(mapped['seller_videos'], ['video.mp4']);
  });
}
