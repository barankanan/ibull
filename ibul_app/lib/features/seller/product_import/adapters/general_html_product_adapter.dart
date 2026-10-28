import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// Genel Semantik HTML Ürün Ayrıştırıcı (Fallback)
class GeneralHtmlProductAdapter extends ProductSourceAdapter {
  const GeneralHtmlProductAdapter();

  @override
  String get adapterName => 'Genel Semantik HTML';

  @override
  int get priority => 5; // En son fallback

  @override
  bool canHandle(Uri uri) => true;

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    final document = html_parser.parse(html);

    // 1. Ürün Başlığı (h1 veya .product-title)
    String title = '';
    final h1 = document.querySelector('h1') ??
        document.querySelector('.product-title') ??
        document.querySelector('.product-name') ??
        document.querySelector('[itemprop="name"]');
    if (h1 != null) {
      title = ProductImportSecurity.sanitizeText(h1.text);
    }
    if (title.isEmpty) {
      final docTitle = document.querySelector('title')?.text ?? '';
      title = ProductImportSecurity.sanitizeText(docTitle);
    }
    if (title.isEmpty) return const [];

    // 2. Fiyat
    double price = 0.0;
    final priceElement = document.querySelector('[itemprop="price"]') ??
        document.querySelector('.current-price') ??
        document.querySelector('.product-price') ??
        document.querySelector('.price') ??
        document.querySelector('.sale-price');
    if (priceElement != null) {
      final priceAttr = priceElement.attributes['content'] ?? priceElement.attributes['value'] ?? priceElement.text;
      price = ProductImportSecurity.parsePrice(priceAttr) ?? 0.0;
    }

    // Para Birimi
    final currencyElement = document.querySelector('[itemprop="priceCurrency"]');
    final currency = ProductImportSecurity.parseCurrency(currencyElement?.attributes['content'] ?? 'TRY');

    // 3. Marka
    String brand = '';
    final brandElem = document.querySelector('[itemprop="brand"]') ??
        document.querySelector('.product-brand') ??
        document.querySelector('.brand');
    if (brandElem != null) {
      brand = ProductImportSecurity.sanitizeText(brandElem.attributes['content'] ?? brandElem.text);
    }

    // 4. Görseller
    final List<String> images = [];
    final imgElements = document.querySelectorAll('.product-gallery img, .product-images img, [data-zoom-image], .gallery img, [itemprop="image"]');
    for (final img in imgElements) {
      final src = img.attributes['data-zoom-image'] ??
          img.attributes['data-src'] ??
          img.attributes['src'] ??
          img.attributes['content'];
      if (src != null && src.trim().isNotEmpty) {
        final fullUrl = _resolveUrl(uri, src.trim());
        if (!images.contains(fullUrl) && _isValidImageUrl(fullUrl)) {
          images.add(fullUrl);
        }
      }
    }

    // 5. Açıklama
    String description = '';
    final descElem = document.querySelector('[itemprop="description"]') ??
        document.querySelector('.product-description') ??
        document.querySelector('#description') ??
        document.querySelector('.description');
    if (descElem != null) {
      description = ProductImportSecurity.sanitizeText(descElem.text);
    }

    // 6. Teknik Özellik Tablosu
    final Map<String, dynamic> specifications = {};
    final specRows = document.querySelectorAll('table.specs tr, .product-specs tr, .specifications tr, dl.specs');
    for (final row in specRows) {
      final cells = row.querySelectorAll('th, td');
      if (cells.length >= 2) {
        final key = ProductImportSecurity.sanitizeText(cells[0].text);
        final val = ProductImportSecurity.sanitizeText(cells[1].text);
        if (key.isNotEmpty && val.isNotEmpty) {
          specifications[key] = val;
        }
      }
    }

    // 7. SKU (Kaynakta varsa DOM'dan oku, yoksa boş bırak; uydurma değer üretme)
    String sku = '';
    final skuElem = document.querySelector('[itemprop="sku"]') ??
        document.querySelector('.product-sku') ??
        document.querySelector('.sku') ??
        document.querySelector('#sku');
    if (skuElem != null) {
      sku = ProductImportSecurity.sanitizeText(skuElem.text).replaceAll(RegExp(r'^(SKU|Kod|Ürün Kodu):\s*', caseSensitive: false), '').trim();
    }

    final product = ImportedProductData(
      id: 'html_${DateTime.now().millisecondsSinceEpoch}_${uri.path.hashCode.abs()}',
      sourceUrl: uri.toString(),
      adapterName: adapterName,
      name: title,
      brand: brand,
      sku: sku,
      price: price,
      currency: currency,
      originalCurrency: currency,
      mainCategory: '',
      subCategory: '',
      description: description,
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

  String _resolveUrl(Uri base, String relative) {
    if (relative.startsWith('//')) return '${base.scheme}:$relative';
    if (relative.startsWith('http://') || relative.startsWith('https://')) return relative;
    return base.resolve(relative).toString();
  }

  bool _isValidImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.avif') ||
        lower.contains('cdn') ||
        lower.contains('images');
  }
}
