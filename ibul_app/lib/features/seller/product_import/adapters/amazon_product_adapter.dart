import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// Amazon (amazon.com.tr / amazon.com) Ürün Adaptörü
class AmazonProductAdapter implements ProductSourceAdapter {
  const AmazonProductAdapter();

  @override
  String get adapterName => 'Amazon';

  @override
  int get priority => 85;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'amazon.com.tr' ||
        host.endsWith('.amazon.com.tr') ||
        host == 'amazon.com' ||
        host.endsWith('.amazon.com');
  }

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    // 1. Bot koruması ve CAPTCHA kontrolü
    if (html.contains('Robot olmadığınıza emin olun') ||
        html.contains('Type the characters you see in this image') ||
        html.contains('api-services-support@amazon.com') ||
        html.contains('automated access to Amazon data')) {
      throw Exception(
        'Amazon bot koruması (WAF/CAPTCHA) tespit edildi. Sayfa içeriği bot korumasıyla engellenmiştir. Güvenilir ve kesintisiz aktarım için resmi Amazon SP-API / PA-API yetkilendirmesi gereklidir.',
      );
    }

    final document = html_parser.parse(html);

    // 2. ASIN tespiti (Amazon standart ürün tanımlayıcısı)
    String asin = '';
    final asinMatch = RegExp(r'/dp/([A-Z0-9]{10})', caseSensitive: false).firstMatch(uri.path);
    if (asinMatch != null) {
      asin = asinMatch.group(1) ?? '';
    }
    if (asin.isEmpty) {
      final asinInput = document.querySelector('input#ASIN, input[name="ASIN"]');
      if (asinInput != null) {
        asin = asinInput.attributes['value']?.trim() ?? '';
      }
    }

    // 3. Başlık
    final titleElem = document.querySelector('#productTitle, #title, h1.a-size-large');
    final title = ProductImportSecurity.sanitizeText(titleElem?.text);
    if (title.isEmpty) {
      return const [];
    }

    // 4. Marka
    String brand = '';
    final byline = document.querySelector('#bylineInfo, a#bylineInfo');
    if (byline != null) {
      brand = ProductImportSecurity.sanitizeText(byline.text)
          .replaceAll(RegExp(r'^(Marka:|Ziyaret Et:)\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+Mağazası$', caseSensitive: false), '')
          .trim();
    }

    // 5. Fiyat
    double price = 0.0;
    double? discountPrice;
    final priceElem = document.querySelector('.apexPriceToPay .a-offscreen, #priceblock_ourprice, #priceblock_dealprice, .a-price .a-offscreen');
    if (priceElem != null) {
      price = ProductImportSecurity.parsePrice(priceElem.text) ?? 0.0;
    }

    final basisElem = document.querySelector('.basisPrice .a-offscreen, .a-text-price .a-offscreen');
    if (basisElem != null) {
      final basisPrice = ProductImportSecurity.parsePrice(basisElem.text);
      if (basisPrice != null && basisPrice > price) {
        discountPrice = price;
        price = basisPrice;
      }
    }

    // 6. Görseller
    final List<String> images = [];
    final landingImg = document.querySelector('#landingImage, #imgBlkFront');
    if (landingImg != null) {
      final dynImages = landingImg.attributes['data-a-dynamic-image'];
      if (dynImages != null && dynImages.trim().isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(dynImages);
          images.addAll(decoded.keys.where((k) => k.startsWith('http')));
        } catch (_) {}
      }
      if (images.isEmpty) {
        final src = landingImg.attributes['src'] ?? landingImg.attributes['data-old-hires'];
        if (src != null && src.isNotEmpty) images.add(src);
      }
    }

    // 7. Özellikler ve Açıklama
    final List<String> bullets = [];
    final bulletElements = document.querySelectorAll('#feature-bullets ul li span.a-list-item');
    for (final b in bulletElements) {
      final text = ProductImportSecurity.sanitizeText(b.text);
      if (text.isNotEmpty && !text.toLowerCase().contains('bu ürün')) {
        bullets.add(text);
      }
    }

    final Map<String, dynamic> specifications = {};
    for (int i = 0; i < bullets.length; i++) {
      specifications['Madde ${i + 1}'] = bullets[i];
    }

    // Teknik Özellik Tablosu
    final specRows = document.querySelectorAll('#productDetails_techSpec_section_1 tr, table.prodDetTable tr');
    for (final row in specRows) {
      final th = row.querySelector('th');
      final td = row.querySelector('td');
      if (th != null && td != null) {
        final k = ProductImportSecurity.sanitizeText(th.text);
        final v = ProductImportSecurity.sanitizeText(td.text);
        if (k.isNotEmpty && v.isNotEmpty) {
          specifications[k] = v;
        }
      }
    }

    // 8. Stok
    int? stock;
    final availElem = document.querySelector('#availability, #availability span');
    if (availElem != null) {
      final text = availElem.text.toLowerCase();
      if (text.contains('tükendi') || text.contains('şu anda mevcut değil') || text.contains('currently unavailable')) {
        stock = 0;
      } else if (text.contains('stokta')) {
        final qtyMatch = RegExp(r'sadece\s+(\d+)\s+adet', caseSensitive: false).firstMatch(text);
        if (qtyMatch != null) {
          stock = int.tryParse(qtyMatch.group(1) ?? '');
        } else {
          stock = null; // Stokta var fakat net sayı belirtilmemiş (Bilinmiyor)
        }
      }
    }

    final product = ImportedProductData(
      id: 'amazon_${DateTime.now().millisecondsSinceEpoch}_${asin.hashCode.abs()}',
      sourceUrl: uri.toString(),
      sourceId: asin.isNotEmpty ? asin : null,
      adapterName: adapterName,
      name: title,
      brand: brand,
      sku: asin,
      price: price,
      discountPrice: discountPrice,
      currency: 'TRY',
      originalCurrency: 'TRY',
      stock: stock,
      mainCategory: '',
      subCategory: '',
      description: bullets.join('\n\n'),
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
