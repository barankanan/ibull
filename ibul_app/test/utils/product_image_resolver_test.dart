import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/product_image_resolver.dart';

void main() {
  group('ProductImageResolver', () {
    test('prefers image_url then image_urls', () {
      expect(
        ProductImageResolver.primaryUrl(
          imageUrl: 'https://cdn/a.jpg',
          imageUrls: const ['https://cdn/b.jpg'],
        ),
        'https://cdn/a.jpg',
      );
      expect(
        ProductImageResolver.primaryUrl(
          imageUrls: const ['https://cdn/b.jpg'],
        ),
        'https://cdn/b.jpg',
      );
    });

    test('fromProductMap resolves primary image', () {
      expect(
        ProductImageResolver.fromProductMap({
          'image_url': '',
          'image_urls': ['https://cdn/c.jpg'],
        }),
        'https://cdn/c.jpg',
      );
    });
  });
}
