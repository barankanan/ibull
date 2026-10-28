import 'dart:convert';

import '../models/product_model.dart';
import '../models/product_pricing.dart';

/// Public site origin. Firebase `web.app` hosts the same build, but indexed
/// URLs stay on the production domain.
const String kPublicSiteOrigin = 'https://ibul.com.tr';
const String kPublicSiteName = 'İBUL';

const String kHomeTitle = 'İBUL | Alışveriş, Mağazalar ve Daha Fazlası';
const String kHomeDescription =
    'İBUL ile alışveriş yapın, mağazaları keşfedin ve yakındaki satıcılara ulaşın.';

String publicCanonicalUrl(String path) {
  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized == '/') return '$kPublicSiteOrigin/';
  return '$kPublicSiteOrigin$normalized';
}

String productSeoTitle(String name) => '${name.trim()} | $kPublicSiteName';

String categorySeoTitle(String name) =>
    '${name.trim()} Ürünleri | $kPublicSiteName';

String storeSeoTitle(String name) => '${name.trim()} Mağazası | $kPublicSiteName';

String mallSeoTitle(String name) =>
    '${name.trim()} Mağazaları ve Bilgileri | $kPublicSiteName';

String blogSeoTitle(String name) => '${name.trim()} | $kPublicSiteName';

String clipMetaDescription(String? raw, {String fallback = kHomeDescription}) {
  final text = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  final value = text.isEmpty ? fallback : text;
  if (value.length <= 160) return value;
  return '${value.substring(0, 157).trimRight()}...';
}

/// Genuine ratings only. Missing or zero review counts are omitted.
bool hasGenuineProductRating(Product product) =>
    product.reviewCount > 0 && product.rating > 0 && product.rating <= 5;

/// Matches the product page: a known stock of zero is out of stock.
/// Unknown stock is omitted so the markup does not invent availability.
String? productAvailabilityUrl(Product product) {
  final stock = product.stock;
  if (stock == null) return null;
  if (stock > 0) return 'https://schema.org/InStock';
  return 'https://schema.org/OutOfStock';
}

List<String> productHttpImages(Product product) {
  final urls = <String>[
    ...product.images,
    if ((product.thumbnailPublicUrl ?? '').trim().isNotEmpty)
      product.thumbnailPublicUrl!,
  ];
  final seen = <String>{};
  final http = <String>[];
  for (final raw in urls) {
    final url = raw.trim();
    if (!url.startsWith('https://') && !url.startsWith('http://')) continue;
    if (seen.add(url)) http.add(url);
  }
  return http;
}

String homeJsonLd() {
  return jsonEncode({
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        'name': kPublicSiteName,
        'url': '$kPublicSiteOrigin/',
        'logo': '$kPublicSiteOrigin/favicon.png',
      },
      {
        '@type': 'WebSite',
        'name': kPublicSiteName,
        'url': '$kPublicSiteOrigin/',
        'description': kHomeDescription,
        'publisher': {'@type': 'Organization', 'name': kPublicSiteName},
      },
    ],
  });
}

String productJsonLd(Product product, {required String canonicalPath}) {
  final url = publicCanonicalUrl(canonicalPath);
  final price = ProductPriceCalculator.parsePriceValue(product.price);
  final images = productHttpImages(product);
  final availability = productAvailabilityUrl(product);
  final offer = <String, Object?>{
    '@type': 'Offer',
    'url': url,
    'priceCurrency': 'TRY',
    if (price > 0) 'price': price.toStringAsFixed(2),
    if (availability != null) 'availability': availability,
  };
  final data = <String, Object?>{
    '@context': 'https://schema.org',
    '@type': 'Product',
    'name': product.name,
    'url': url,
    if (images.isNotEmpty) 'image': images,
    if ((product.shortDescription ?? product.description ?? '').trim().isNotEmpty)
      'description': clipMetaDescription(
        product.shortDescription ?? product.description,
        fallback: product.name,
      ),
    if (product.brand.trim().isNotEmpty)
      'brand': {'@type': 'Brand', 'name': product.brand.trim()},
    if (price > 0) 'offers': offer,
    if (hasGenuineProductRating(product))
      'aggregateRating': {
        '@type': 'AggregateRating',
        'ratingValue': product.rating,
        'reviewCount': product.reviewCount,
      },
  };
  return jsonEncode(data);
}

String breadcrumbJsonLd(List<({String name, String path})> crumbs) {
  return jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    'itemListElement': [
      for (var i = 0; i < crumbs.length; i++)
        {
          '@type': 'ListItem',
          'position': i + 1,
          'name': crumbs[i].name,
          'item': publicCanonicalUrl(crumbs[i].path),
        },
    ],
  });
}

/// ShoppingCenter only when a real address exists. No placeholder locality.
String? mallJsonLd({
  required String name,
  required String canonicalPath,
  String? streetAddress,
  String? city,
  String? district,
  String? phone,
  String? imageUrl,
  double? latitude,
  double? longitude,
}) {
  final street = streetAddress?.trim() ?? '';
  final locality = city?.trim() ?? '';
  if (street.isEmpty && locality.isEmpty) return null;
  final image = imageUrl?.trim() ?? '';
  return jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'ShoppingCenter',
    'name': name,
    'url': publicCanonicalUrl(canonicalPath),
    if (image.startsWith('http')) 'image': image,
    if ((phone ?? '').trim().isNotEmpty) 'telephone': phone!.trim(),
    'address': {
      '@type': 'PostalAddress',
      if (street.isNotEmpty) 'streetAddress': street,
      if ((district ?? '').trim().isNotEmpty)
        'addressLocality': district!.trim(),
      if (locality.isNotEmpty) 'addressRegion': locality,
      'addressCountry': 'TR',
    },
    if (latitude != null && longitude != null)
      'geo': {
        '@type': 'GeoCoordinates',
        'latitude': latitude,
        'longitude': longitude,
      },
  });
}

/// Null when a required Merchant Center field is missing or not a public URL.
Map<String, String>? merchantFeedRow(
  Product product, {
  required String canonicalPath,
}) {
  final id = (product.productId ?? '').trim();
  final title = product.name.trim();
  final image = productHttpImages(product);
  final price = ProductPriceCalculator.parsePriceValue(product.price);
  final availability = productAvailabilityUrl(product);
  if (id.isEmpty || title.isEmpty || image.isEmpty || price <= 0) return null;
  if (availability == null) return null;
  if (product.brand.trim().isEmpty) return null;
  final link = publicCanonicalUrl(canonicalPath);
  return {
    'id': id,
    'title': title,
    'description': clipMetaDescription(
      product.shortDescription ?? product.description,
      fallback: title,
    ),
    'link': link,
    'image_link': image.first,
    'availability': availability.endsWith('InStock') ? 'in_stock' : 'out_of_stock',
    'price': '${price.toStringAsFixed(2)} TRY',
    'brand': product.brand.trim(),
    'condition': 'new',
  };
}

bool isPrivateCrawlPath(String path) {
  final normalized = path.split('?').first;
  const prefixes = [
    '/admin',
    '/hesabim',
    '/sepet',
    '/checkout',
    '/login',
    '/register',
    '/seller',
    '/favoriler',
    '/visual-search',
    '/qr',
    '/blog/yazar',
    '/blog/onizleme',
  ];
  for (final prefix in prefixes) {
    if (normalized == prefix || normalized.startsWith('$prefix/')) return true;
  }
  return false;
}

String sitemapUrlSet(List<String> urls) {
  final body = urls
      .map((url) => '<url><loc>${_xml(url)}</loc></url>')
      .join();
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
      '$body</urlset>\n';
}

String sitemapIndex(List<String> sitemapUrls) {
  final body = sitemapUrls
      .map((url) => '<sitemap><loc>${_xml(url)}</loc></sitemap>')
      .join();
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
      '$body</sitemapindex>\n';
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
