import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/catalog_image_priority.dart';
import 'package:ibul_app/core/commerce_image_cache.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

void main() {
  test('catalog image policy keeps first rail/grid tiles eager', () {
    expect(
      CatalogImagePriority.forRailIndex(0),
      OptimizedImagePriority.high,
    );
    expect(
      CatalogImagePriority.forRailIndex(3),
      OptimizedImagePriority.high,
    );
    expect(
      CatalogImagePriority.forRailIndex(4),
      OptimizedImagePriority.lazy,
    );
    expect(
      CatalogImagePriority.forGridIndex(3, crossAxisCount: 2),
      OptimizedImagePriority.high,
    );
    expect(
      CatalogImagePriority.forGridIndex(4, crossAxisCount: 2),
      OptimizedImagePriority.lazy,
    );
  });

  test('product cards default to lazy decode so below-fold work is gated', () {
    final card = File('lib/widgets/product_card.dart').readAsStringSync();
    expect(
      card,
      contains('this.imagePriority = OptimizedImagePriority.lazy'),
    );
    expect(
      card,
      isNot(contains('this.imagePriority = OptimizedImagePriority.high')),
    );
  });

  test('home rails pass catalog image priority and tighter cacheExtent', () {
    final rail = File(
      'lib/screens/home/sections/home_section_full_rail.dart',
    ).readAsStringSync();
    expect(rail, contains('CatalogImagePriority.forRailIndex'));
    expect(rail, contains('cacheExtent: 280'));
  });

  test('boot configures a bounded commerce image cache', () {
    final bootstrap =
        File('lib/app/app_bootstrap.dart').readAsStringSync();
    expect(bootstrap, contains('CommerceImageCache.configure()'));
    expect(CommerceImageCache.maxLiveImages, 160);
    expect(CommerceImageCache.maxBytes, 64 * 1024 * 1024);
  });
}
