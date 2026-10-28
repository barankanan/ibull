import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// n11 (n11.com) Ürün Adaptörü
class N11ProductAdapter implements ProductSourceAdapter {
  const N11ProductAdapter();

  @override
  String get adapterName => 'n11';

  @override
  int get priority => 85;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'n11.com' || host.endsWith('.n11.com');
  }

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    // 1. Bot koruması ve Incapsula kontrolü
    if (html.contains('_Incapsula_Resource') ||
        html.contains('Request unsuccessful. Incapsula incident ID') ||
        html.contains('Access Denied') && html.contains('Incident ID')) {
      throw Exception(
        'n11 erişim kısıtlaması (Incapsula WAF) tespit edildi. Sayfa koruma nedeniyle engellendi. Kesintisiz veri aktarımı için n11 Satıcı API entegrasyonu önerilir.',
      );
    }

    final document = html_parser.parse(html);

    // 2. Başlık
    final titleElem = document.querySelector('h1.proName, .name-holder h1, h1.product-name');
    final title = ProductImportSecurity.sanitizeText(titleElem?.text);
    if (title.isEmpty) {
      return const [];
    }

    // 3. Fiyat
    double price = 0.0;
    double? discountPrice;
    final insPrice = document.querySelector('.newPrice ins, ins.price, .price-box .price');
    if (insPrice != null) {
      price = ProductImportSecurity.parsePrice(insPrice.text) ?? 0.0;
    }
    final delPrice = document.querySelector('.oldPrice del, del.price');
    if (delPrice != null) {
      final old = ProductImportSecurity.parsePrice(delPrice.text);
      if (old != null && old > price) {
        discountPrice = price;
        price = old;
      }
    }

    // 4. Marka ve Kategori
    String brand = '';
    final brandElem = document.querySelector('.brand-name, [itemprop="brand"]');
    if (brandElem != null) {
      brand = ProductImportSecurity.sanitizeText(brandElem.text);
    }

    // 5. Görseller
    final List<String> images = [];
    final imgElements = document.querySelectorAll('.thumb-slider img, .imgObj, #slider img');
    for (final img in imgElements) {
      final src = img.attributes['data-src'] ?? img.attributes['data-original'] ?? img.attributes['src'];
      if (src != null && src.isNotEmpty && src.startsWith('http') && !images.contains(src)) {
        images.add(src);
      }
    }

    // 6. Teknik Özellikler
    final Map<String, dynamic> specifications = {};
    final propItems = document.querySelectorAll('.unf-prop-list li, .unf-prop-context-item');
    for (final item in propItems) {
      final title = item.querySelector('.unf-prop-list-title, .prop-title');
      final val = item.querySelector('.unf-prop-list-prop, .prop-val');
      if (title != null && val != null) {
        final k = ProductImportSecurity.sanitizeText(title.text);
        final v = ProductImportSecurity.sanitizeText(val.text);
        if (k.isNotEmpty && v.isNotEmpty) {
          specifications[k] = v;
        }
      }
    }

    // 7. n11 catalogModel script tag kontrolü
    final scripts = document.querySelectorAll('script');
    for (final s in scripts) {
      final text = s.text;
      if (text.contains('catalogModel')) {
        try {
          final match = RegExp(r'catalogModel\s*=\s*(\{.+?\});', dotAll: true).firstMatch(text);
          if (match != null) {
            final jsonStr = match.group(1);
            if (jsonStr != null) {
              final Map<String, dynamic> model = jsonDecode(jsonStr);
              if (brand.isEmpty && model['brand'] != null) {
                brand = model['brand'].toString();
              }
            }
          }
        } catch (_) {}
      }
    }

    // 8. SKU (n11 ürün id)
    String sku = '';
    final skuMatch = RegExp(r'-p-(\d+)', caseSensitive: false).firstMatch(uri.path);
    if (skuMatch != null) {
      sku = 'N11-${skuMatch.group(1)}';
    }

    // 9. Stok: n11 sayfasında tükenmiş ibaresi yoksa stok bilinmiyor
    int? stock;
    if (html.contains('Tükendi') || html.contains('outOfStock') || html.contains('Stokta Yok')) {
      stock = 0;
    }

    final product = ImportedProductData(
      id: 'n11_${DateTime.now().millisecondsSinceEpoch}_${sku.hashCode.abs()}',
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
