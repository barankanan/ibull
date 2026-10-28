import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/public_seo.dart';
import 'package:ibul_app/models/product_model.dart';

Product _product({
  int? stock = 4,
  double rating = 0,
  int reviewCount = 0,
  String brand = 'Samsung',
  List<String> images = const ['https://cdn.example/p.jpg'],
}) {
  return Product(
    productId: 'p1',
    name: 'Samsung TV',
    brand: brand,
    price: '1000',
    rating: rating,
    reviewCount: reviewCount,
    tags: const [],
    images: images,
    stock: stock,
    shortDescription: 'Gerçek ürün açıklaması',
  );
}

void main() {
  test('canonical urls stay on ibul.com.tr', () {
    expect(publicCanonicalUrl('/urun/1'), 'https://ibul.com.tr/urun/1');
    expect(publicCanonicalUrl('/'), 'https://ibul.com.tr/');
    expect(kHomeTitle, 'İBUL | Alışveriş, Mağazalar ve Daha Fazlası');
    expect(productSeoTitle('Samsung TV'), 'Samsung TV | İBUL');
    expect(categorySeoTitle('Elektronik'), 'Elektronik Ürünleri | İBUL');
    expect(storeSeoTitle('Teknosa'), 'Teknosa Mağazası | İBUL');
    expect(mallSeoTitle('Forum'), 'Forum Mağazaları ve Bilgileri | İBUL');
    expect(isPrivateCrawlPath('/hesabim/siparisler'), isTrue);
    expect(isPrivateCrawlPath('/favoriler'), isTrue);
    expect(isPrivateCrawlPath('/urun/1'), isFalse);
  });

  test('product json-ld uses real price and omits empty ratings', () {
    final encoded = productJsonLd(
      _product(),
      canonicalPath: '/urun/p1/samsung-tv',
    );
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    expect(data['name'], 'Samsung TV');
    expect(data.containsKey('aggregateRating'), isFalse);
    final offer = data['offers'] as Map<String, dynamic>;
    expect(offer['price'], '1000.00');
    expect(offer['priceCurrency'], 'TRY');
    expect(offer['availability'], 'https://schema.org/InStock');
    expect(data['url'], 'https://ibul.com.tr/urun/p1/samsung-tv');
  });

  test('genuine rating is included and unknown stock is omitted', () {
    final rated = jsonDecode(productJsonLd(
      _product(rating: 4.5, reviewCount: 12, stock: null),
      canonicalPath: '/urun/p1',
    )) as Map<String, dynamic>;
    expect(rated['aggregateRating'], isNotNull);
    expect((rated['offers'] as Map)['availability'], isNull);
    final row = merchantFeedRow(
      _product(stock: 0),
      canonicalPath: '/urun/p1',
    );
    expect(row, isNotNull);
    expect(row!['availability'], 'out_of_stock');
    expect(row['condition'], 'new');
    expect(
      merchantFeedRow(
        _product(brand: '  ', images: const ['assets/local.png']),
        canonicalPath: '/urun/p1',
      ),
      isNull,
    );
  });

  test('mall schema requires a real address and sitemap stays absolute', () {
    expect(
      mallJsonLd(name: 'Forum', canonicalPath: '/avm/profil/1'),
      isNull,
    );
    final mall = jsonDecode(mallJsonLd(
      name: 'Forum',
      canonicalPath: '/avm/profil/1',
      streetAddress: 'Ataşehir',
      city: 'İstanbul',
    )!) as Map<String, dynamic>;
    expect(mall['@type'], 'ShoppingCenter');
    final xml = sitemapUrlSet(['https://ibul.com.tr/', 'https://ibul.com.tr/blog']);
    expect(xml, contains('https://ibul.com.tr/blog'));
    expect(xml, isNot(contains('web.app')));
    expect(
      sitemapIndex(['https://ibul.com.tr/sitemap-part-1.xml']),
      contains('sitemapindex'),
    );
  });
}
