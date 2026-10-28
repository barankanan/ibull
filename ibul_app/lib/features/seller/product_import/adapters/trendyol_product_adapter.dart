import 'dart:convert';

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'json_ld_product_adapter.dart';
import 'product_source_adapter.dart';

/// Trendyol Ürün Sayfası Adaptörü
class TrendyolProductAdapter extends ProductSourceAdapter {
  const TrendyolProductAdapter();

  @override
  String get adapterName => 'Trendyol Adaptörü';

  @override
  int get priority => 50; // Siteye özel adaptör genel adaptörlerden öncelikli

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('trendyol.com');
  }

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    final lowerHtml = html.toLowerCase();
    final bool isBotBlocked =
        (meta != null && (meta['statusCode'] == 403 || meta['statusCode'] == 429)) ||
        lowerHtml.contains('cf-ray') ||
        lowerHtml.contains('cloudflare') ||
        lowerHtml.contains('just a moment...') ||
        lowerHtml.contains('attention required! | cloudflare') ||
        lowerHtml.contains('challenge-platform') ||
        lowerHtml.contains('enable javascript and cookies to continue') ||
        lowerHtml.contains('please verify you are a human') ||
        lowerHtml.contains('access denied') ||
        lowerHtml.contains('erişim engellendi') ||
        lowerHtml.contains('403 forbidden') ||
        lowerHtml.contains('429 too many requests') ||
        lowerHtml.contains('shieldsquare') ||
        lowerHtml.contains('radware') ||
        lowerHtml.contains('perimeterx') ||
        lowerHtml.contains('px-captcha');

    if (isBotBlocked) {
      throw Exception('Erişim kısıtlaması nedeniyle bu mağaza için satıcı API anahtarı gereklidir');
    }

    // 1. Önce window.__INITIAL_STATE__ içinde zengin ürün nesnesi ara
    final productData = _extractInitialState(html);
    if (productData != null) {
      final parsed = _mapTrendyolProduct(uri, productData);
      if (parsed != null) return [parsed];
    }

    // 2. Yedek olarak sayfadaki JSON-LD verisini kullan
    const jsonLdAdapter = JsonLdProductAdapter();
    final jsonLdResults = await jsonLdAdapter.parse(uri: uri, html: html, meta: meta);
    if (jsonLdResults.isNotEmpty) {
      return jsonLdResults.map((p) => p.copyWith(adapterName: adapterName)).toList();
    }

    // Sayfada ürün verisi bulunamadıysa bot engelleme veya geçersiz sayfa nedeniyle net hata fırlat
    throw Exception('Erişim kısıtlaması nedeniyle bu mağaza için satıcı API anahtarı gereklidir');
  }

  Map<String, dynamic>? _extractInitialState(String html) {
    // script etiketi içinde __INITIAL_STATE__ arayalım
    final match = RegExp(r'window\.__INITIAL_STATE__\s*=\s*(\{.+?\});', dotAll: true).firstMatch(html);
    if (match != null) {
      final jsonStr = match.group(1);
      if (jsonStr != null) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map && decoded['product'] is Map) {
            return Map<String, dynamic>.from(decoded['product']);
          }
        } catch (_) {}
      }
    }

    // Alternatif: script id="__NEXT_DATA__" veya script id="product-detail"
    final nextDataMatch = RegExp(r'<script\s+id="__NEXT_DATA__"\s+type="application\/json">(.+?)<\/script>', dotAll: true).firstMatch(html);
    if (nextDataMatch != null) {
      final nextJson = nextDataMatch.group(1);
      if (nextJson != null) {
        try {
          final decoded = jsonDecode(nextJson);
          if (decoded is Map && decoded['props']?['pageProps']?['product'] is Map) {
            return Map<String, dynamic>.from(decoded['props']['pageProps']['product']);
          }
        } catch (_) {}
      }
    }

    return null;
  }

  ImportedProductData? _mapTrendyolProduct(Uri uri, Map<String, dynamic> data) {
    final name = ProductImportSecurity.sanitizeText(data['name']?.toString());
    if (name.isEmpty) return null;

    final brand = data['brand']?['name']?.toString().trim() ?? data['brand']?.toString().trim() ?? '';
    final modelCode = data['productCode']?.toString().trim() ?? data['modelCode']?.toString().trim();
    final barcode = data['barcode']?.toString().trim();
    final sku = data['id']?.toString().trim() ?? modelCode ?? '';

    // Fiyat
    double price = 0.0;
    double? discountPrice;
    final priceObj = data['price'];
    if (priceObj is Map) {
      price = ProductImportSecurity.parsePrice(priceObj['originalPrice'] ?? priceObj['sellingPrice']) ?? 0.0;
      final disc = ProductImportSecurity.parsePrice(priceObj['discountedPrice']);
      if (disc != null && disc < price && disc > 0) {
        discountPrice = disc;
      }
    }

    // Görseller
    final List<String> images = [];
    final rawImages = data['images'];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is String) {
          images.add(_normalizeTrendyolImageUrl(img));
        } else if (img is Map && img['url'] != null) {
          images.add(_normalizeTrendyolImageUrl(img['url'].toString()));
        }
      }
    }

    // Açıklama
    String description = '';
    final descList = data['contentDescriptions'];
    if (descList is List) {
      final buffer = StringBuffer();
      for (final item in descList) {
        if (item is Map && item['description'] != null) {
          buffer.writeln(ProductImportSecurity.sanitizeText(item['description'].toString()));
        } else if (item is String) {
          buffer.writeln(ProductImportSecurity.sanitizeText(item));
        }
      }
      description = buffer.toString().trim();
    }
    if (description.isEmpty && data['description'] != null) {
      description = ProductImportSecurity.sanitizeText(data['description'].toString());
    }

    // Kategori
    String category = '';
    String subCategory = '';
    final categoryHierarchy = data['categoryHierarchy'];
    if (categoryHierarchy is List && categoryHierarchy.isNotEmpty) {
      final first = categoryHierarchy.first;
      if (first is Map && first['name'] != null) {
        category = first['name'].toString().trim();
      }
      if (categoryHierarchy.length > 1) {
        final second = categoryHierarchy[1];
        if (second is Map && second['name'] != null) {
          subCategory = second['name'].toString().trim();
        }
      }
    }

    // Teknik Özellikler (attributes)
    final Map<String, dynamic> specifications = {};
    if (data['attributes'] is List) {
      for (final attr in data['attributes']) {
        if (attr is Map) {
          final key = attr['key']?['name']?.toString() ?? attr['name']?.toString();
          final val = attr['value']?['name']?.toString() ?? attr['value']?.toString();
          if (key != null && val != null) {
            specifications[key.trim()] = val.trim();
          }
        }
      }
    }

    // Gerçek Varyasyon Kombinasyonları
    final List<ImportedProductVariant> variants = [];
    final Map<String, List<String>> variantOptions = {};

    final rawVariants = data['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      for (int i = 0; i < rawVariants.length; i++) {
        final v = rawVariants[i];
        if (v is Map) {
          final vBar = v['barcode']?.toString().trim();
          final vSku = v['itemNumber']?.toString().trim();
          final vVal = v['attributeValue']?.toString().trim() ?? '';
          final vName = v['attributeName']?.toString().trim() ?? 'Seçenek';

          if (vName.isNotEmpty && vVal.isNotEmpty) {
            variantOptions.putIfAbsent(vName, () => []);
            if (!variantOptions[vName]!.contains(vVal)) {
              variantOptions[vName]!.add(vVal);
            }
          }

          double vPrice = price;
          double? vDiscount;
          if (v['price'] is Map) {
            final pOriginal = ProductImportSecurity.parsePrice(v['price']['originalPrice']);
            final pSelling = ProductImportSecurity.parsePrice(v['price']['sellingPrice'] ?? v['price']['discountedPrice']);
            if (pOriginal != null && pSelling != null && pOriginal > pSelling) {
              vPrice = pOriginal;
              vDiscount = pSelling;
            } else {
              vPrice = pSelling ?? pOriginal ?? price;
              vDiscount = null;
            }
          }

          final inStock = v['inStock'] == true;
          int? stockQty;
          if (v['stockQuantity'] is num) {
            stockQty = (v['stockQuantity'] as num).toInt();
          } else if (!inStock) {
            stockQty = 0;
          } else {
            stockQty = null; // Kaynakta net sayı yok, bilinmiyor
          }

          final isClothingSize = vName.toLowerCase().contains('beden') || vName.toLowerCase().contains('size');
          final isColor = vName.toLowerCase().contains('renk') || vName.toLowerCase().contains('color');

          variants.add(ImportedProductVariant(
            id: 'ty_v_$i',
            combinationTitle: vVal.isNotEmpty ? vVal : 'Varyasyon ${i + 1}',
            color: isColor ? vVal : null,
            size: isClothingSize ? vVal : null,
            sku: vSku,
            barcode: vBar,
            price: vPrice,
            discountPrice: vDiscount,
            stock: stockQty,
            inStock: inStock,
            imageUrl: images.isNotEmpty ? images.first : null,
          ));
        }
      }
    }

    int? rootStock;
    if (variants.isNotEmpty && variants.every((v) => v.stock != null)) {
      rootStock = variants.fold<int>(0, (sum, v) => sum + (v.stock ?? 0));
    }

    final bool? rootInStock = variants.isNotEmpty
        ? variants.any((v) => v.inStock == true || (v.stock != null && v.stock! > 0))
        : null;

    return ImportedProductData(
      id: 'ty_${DateTime.now().millisecondsSinceEpoch}_${sku.hashCode.abs()}',
      sourceUrl: uri.toString(),
      sourceId: data['id']?.toString(),
      adapterName: adapterName,
      name: name,
      brand: brand,
      modelCode: modelCode,
      sku: sku,
      barcode: barcode,
      price: price,
      discountPrice: discountPrice,
      currency: 'TRY',
      originalCurrency: 'TRY',
      stock: rootStock,
      inStock: rootInStock,
      mainCategory: category,
      subCategory: subCategory,
      description: description,
      imageUrls: images,
      specifications: specifications,
      variantOptions: variantOptions,
      realVariants: variants,
      capturedAt: DateTime.now(),
      quality: const ProductQualityReport(
        score: 0,
        level: ProductQualityLevel.low,
        completeFields: [],
        missingFields: [],
        warningMessages: [],
      ),
    );
  }

  String _normalizeTrendyolImageUrl(String url) {
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      return 'https://cdn.dsmcdn.com$url';
    }
    return url;
  }
}
