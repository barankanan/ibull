import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// ÇiçekSepeti (ciceksepeti.com) Ürün Adaptörü
class CiceksepetiProductAdapter implements ProductSourceAdapter {
  const CiceksepetiProductAdapter();

  @override
  String get adapterName => 'ÇiçekSepeti';

  @override
  int get priority => 85;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'ciceksepeti.com' || host.endsWith('.ciceksepeti.com');
  }

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    // 1. Bot koruması kontrolü
    if (html.contains('ShieldSquare') ||
        html.contains('Radware') ||
        html.contains('Lütfen bekleyiniz...') && html.contains('captcha')) {
      throw Exception(
        'ÇiçekSepeti bot koruması (WAF) tespit edildi. Sayfa erişimi kısıtlandı. Kesintisiz aktarım için ÇiçekSepeti Pazaryeri API entegrasyonu önerilir.',
      );
    }

    final document = html_parser.parse(html);

    // 2. Başlık
    final titleElem = document.querySelector('.js-product-title, h1.product__info__title, .product-title h1');
    final title = ProductImportSecurity.sanitizeText(titleElem?.text);
    if (title.isEmpty) {
      return const [];
    }

    // 3. Fiyat
    double price = 0.0;
    double? discountPrice;
    final priceElem = document.querySelector('.js-price-integer, .product__info__price, .price--now');
    if (priceElem != null) {
      price = ProductImportSecurity.parsePrice(priceElem.text) ?? 0.0;
    }
    final oldPriceElem = document.querySelector('.js-old-price, .price--old, .product__info__old-price');
    if (oldPriceElem != null) {
      final old = ProductImportSecurity.parsePrice(oldPriceElem.text);
      if (old != null && old > price) {
        discountPrice = price;
        price = old;
      }
    }

    // 4. Marka
    String brand = '';
    final brandElem = document.querySelector('.product__info__brand, .brand a');
    if (brandElem != null) {
      brand = ProductImportSecurity.sanitizeText(brandElem.text);
    }

    // 5. Görseller
    final List<String> images = [];
    final imgElements = document.querySelectorAll('.js-product-image, .product__gallery__item img, .product-slider img');
    for (final img in imgElements) {
      final src = img.attributes['data-src'] ?? img.attributes['src'];
      if (src != null && src.isNotEmpty && src.startsWith('http') && !images.contains(src)) {
        images.add(src);
      }
    }

    // 6. Teknik Özellikler
    final Map<String, dynamic> specifications = {};
    final attrItems = document.querySelectorAll('.product__attributes__item, .attributes-table tr');
    for (final item in attrItems) {
      final titleSpan = item.querySelector('.product__attributes__item-title, th');
      final valSpan = item.querySelector('.product__attributes__item-description, td');
      if (titleSpan != null && valSpan != null) {
        final k = ProductImportSecurity.sanitizeText(titleSpan.text);
        final v = ProductImportSecurity.sanitizeText(valSpan.text);
        if (k.isNotEmpty && v.isNotEmpty) {
          specifications[k] = v;
        }
      }
    }

    // 7. Initial State JS Objesi Kontrolü
    final scripts = document.querySelectorAll('script');
    for (final s in scripts) {
      final text = s.text;
      if (text.contains('ProductDetail') || text.contains('productModel')) {
        try {
          final match = RegExp(r'productDetail\s*=\s*(\{.+?\});', dotAll: true).firstMatch(text);
          if (match != null) {
            final jsonStr = match.group(1);
            if (jsonStr != null) {
              final Map<String, dynamic> model = jsonDecode(jsonStr);
              if (brand.isEmpty && model['brandName'] != null) {
                brand = model['brandName'].toString();
              }
            }
          }
        } catch (_) {}
      }
    }

    // 8. SKU (Ürün Kodu)
    String sku = '';
    final codeElem = document.querySelector('.product__info__code, .product-code');
    if (codeElem != null) {
      sku = ProductImportSecurity.sanitizeText(codeElem.text).replaceAll(RegExp(r'^(Ürün Kodu|Kod):\s*', caseSensitive: false), '').trim();
    }
    if (sku.isEmpty) {
      final match = RegExp(r'-kc(\d+)', caseSensitive: false).firstMatch(uri.path);
      if (match != null) {
        sku = 'CS-${match.group(1)}';
      }
    }

    // 9. Stok
    int? stock;
    if (html.contains('Tükendi') || html.contains('Stokta Yok') || html.contains('outOfStock')) {
      stock = 0;
    }

    final product = ImportedProductData(
      id: 'cs_${DateTime.now().millisecondsSinceEpoch}_${sku.hashCode.abs()}',
      sourceUrl: uri.toString(),
      sourceId: sku.isNotEmpty ? sku : null,
      adapterName: adapterName,
      name: title,
      brand: brand,
      sku: sku,
      price: price,
      discountPrice: discountPrice,
      currency: 'TRY',
      originalCurrency: 'TRY',
      stock: stock,
      mainCategory: '',
      subCategory: '',
      description: specifications.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
      imageUrls: images,
      specifications: specifications,
      capturedAt: DateTime.now(),
      quality: const ProductQualityReport(
        score: 0,
        level: ProductQualityLevel.low,
        completeFields: [],
        missingFields: [],
        warningMessages: [],
      ),
    );

    return [product];
  }
}
