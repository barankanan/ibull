import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// Open Graph ve Standart Meta Etiketleri Adaptörü
class OpenGraphProductAdapter extends ProductSourceAdapter {
  const OpenGraphProductAdapter();

  @override
  String get adapterName => 'Open Graph / Meta Tags';

  @override
  int get priority => 15;

  @override
  bool canHandle(Uri uri) => true;

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    final document = html_parser.parse(html);
    final metaTags = document.querySelectorAll('meta');

    final Map<String, String> metaMap = {};

    for (final tag in metaTags) {
      final property = tag.attributes['property']?.toLowerCase() ??
          tag.attributes['name']?.toLowerCase() ??
          tag.attributes['itemprop']?.toLowerCase();
      final content = tag.attributes['content'];

      if (property != null && content != null && content.trim().isNotEmpty) {
        metaMap[property] = content.trim();
      }
    }

    // Başlık
    final title = metaMap['og:title'] ??
        metaMap['twitter:title'] ??
        document.querySelector('title')?.text ??
        '';
    final sanitizedTitle = ProductImportSecurity.sanitizeText(title);
    if (sanitizedTitle.isEmpty) return const [];

    // Açıklama
    final desc = metaMap['og:description'] ??
        metaMap['description'] ??
        metaMap['twitter:description'] ??
        '';
    final sanitizedDesc = ProductImportSecurity.sanitizeText(desc);

    // Görsel
    final List<String> images = [];
    final ogImage = metaMap['og:image'] ??
        metaMap['og:image:secure_url'] ??
        metaMap['twitter:image'];
    if (ogImage != null && ogImage.isNotEmpty) {
      images.add(ogImage);
    }

    // Fiyat
    final priceStr = metaMap['product:price:amount'] ??
        metaMap['og:price:amount'] ??
        metaMap['price'] ??
        metaMap['priceamount'];
    final price = ProductImportSecurity.parsePrice(priceStr) ?? 0.0;

    // Para Birimi
    final currencyStr = metaMap['product:price:currency'] ??
        metaMap['og:price:currency'] ??
        metaMap['currency'] ??
        'TRY';
    final currency = ProductImportSecurity.parseCurrency(currencyStr);

    // Marka
    final brand = metaMap['product:brand'] ??
        metaMap['og:brand'] ??
        metaMap['brand'] ??
        '';

    // SKU (Kaynakta yoksa uydurulmaz, boş bırakılır)
    final sku = metaMap['product:retailer_item_id'] ??
        metaMap['product:sku'] ??
        metaMap['sku'] ??
        '';

    final product = ImportedProductData(
      id: 'og_${DateTime.now().millisecondsSinceEpoch}_${sku.hashCode.abs()}',
      sourceUrl: uri.toString(),
      adapterName: adapterName,
      name: sanitizedTitle,
      brand: brand,
      sku: sku,
      price: price,
      currency: currency,
      originalCurrency: currency,
      mainCategory: '',
      subCategory: '',
      description: sanitizedDesc,
      imageUrls: images,
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
