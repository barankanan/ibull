import 'dart:convert';

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'json_ld_product_adapter.dart';
import 'product_source_adapter.dart';

/// Hepsiburada Ürün Sayfası Adaptörü
class HepsiburadaProductAdapter extends ProductSourceAdapter {
  const HepsiburadaProductAdapter();

  @override
  String get adapterName => 'Hepsiburada Adaptörü';

  @override
  int get priority => 50;

  @override
  bool canHandle(Uri uri) {
    return uri.host.toLowerCase().contains('hepsiburada.com');
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

    final state = _extractHepsiburadaState(html);
    if (state != null) {
      final product = _mapHepsiburadaProduct(uri, state);
      if (product != null) return [product];
    }

    // Yedek: JSON-LD
    const jsonLdAdapter = JsonLdProductAdapter();
    final jsonLdResults = await jsonLdAdapter.parse(uri: uri, html: html, meta: meta);
    if (jsonLdResults.isNotEmpty) {
      return jsonLdResults.map((p) => p.copyWith(adapterName: adapterName)).toList();
    }

    // Sayfada ürün verisi bulunamadıysa bot engelleme veya geçersiz sayfa nedeniyle net hata fırlat
    throw Exception('Erişim kısıtlaması nedeniyle bu mağaza için satıcı API anahtarı gereklidir');
  }

  Map<String, dynamic>? _extractHepsiburadaState(String html) {
    final match = RegExp(
      r'window\.__PRODUCT_DETAIL_APP_INITIAL_STATE__\s*=\s*(\{.+?\});',
      dotAll: true,
    ).firstMatch(html);

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
    return null;
  }

  ImportedProductData? _mapHepsiburadaProduct(Uri uri, Map<String, dynamic> data) {
    final name = ProductImportSecurity.sanitizeText(data['name']?.toString() ?? data['title']?.toString());
    if (name.isEmpty) return null;

    final brand = data['brand']?['name']?.toString() ?? data['brand']?.toString() ?? '';
    final sku = data['sku']?.toString() ?? data['productNo']?.toString() ?? '';
    final barcode = data['barcode']?.toString();

    // Fiyat
    double price = 0.0;
    double? discountPrice;
    final priceObj = data['price'] ?? data['currentPrice'];
    if (priceObj is Map) {
      price = ProductImportSecurity.parsePrice(priceObj['value'] ?? priceObj['amount']) ?? 0.0;
      final original = ProductImportSecurity.parsePrice(priceObj['originalPrice']);
      if (original != null && original > price) {
        discountPrice = price;
        price = original;
      }
    } else {
      price = ProductImportSecurity.parsePrice(priceObj) ?? 0.0;
    }

    // Görseller
    final List<String> images = [];
    final rawImages = data['images'] ?? data['pictures'];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is String) {
          images.add(img);
        } else if (img is Map && img['url'] != null) {
          images.add(img['url'].toString());
        }
      }
    }

    // Açıklama
    final description = ProductImportSecurity.sanitizeText(data['description']?.toString());

    // Kategori
    String category = '';
    String subCategory = '';
    final catList = data['categories'] ?? data['breadcrumb'];
    if (catList is List && catList.isNotEmpty) {
      final first = catList.first;
      category = (first is Map ? first['name'] : first)?.toString() ?? '';
      if (catList.length > 1) {
        final second = catList[1];
        subCategory = (second is Map ? second['name'] : second)?.toString() ?? '';
      }
    }

    // Teknik Özellikler
    final Map<String, dynamic> specifications = {};
    final techSpecs = data['technicalSpecifications'] ?? data['attributes'];
    if (techSpecs is List) {
      for (final spec in techSpecs) {
        if (spec is Map) {
          final k = spec['name']?.toString() ?? spec['key']?.toString();
          final v = spec['value']?.toString();
          if (k != null && v != null) {
            specifications[k.trim()] = v.trim();
          }
        }
      }
    }

    // Varyasyonlar
    final List<ImportedProductVariant> variants = [];
    final Map<String, List<String>> variantOptions = {};

    final rawVariants = data['variants'];
    if (rawVariants is List) {
      for (int i = 0; i < rawVariants.length; i++) {
        final v = rawVariants[i];
        if (v is Map) {
          final vTitle = v['title']?.toString() ?? 'Varyasyon ${i + 1}';
          final vSku = v['sku']?.toString();
          final vBar = v['barcode']?.toString();
          final vPrice = ProductImportSecurity.parsePrice(v['price']?['value'] ?? v['price']) ?? price;
          final int? vStock = (v['stock'] as num?)?.toInt() ?? (v['stockQuantity'] as num?)?.toInt();
          final inStock = v['inStock'] == true || (vStock != null && vStock > 0);

          variants.add(ImportedProductVariant(
            id: 'hb_v_$i',
            combinationTitle: vTitle,
            sku: vSku,
            barcode: vBar,
            price: vPrice,
            stock: vStock,
            inStock: inStock,
          ));
        }
      }
    }

    final int? rootStock = (data['stock'] as num?)?.toInt() ??
        (data['stockQuantity'] as num?)?.toInt() ??
        (variants.isNotEmpty && variants.every((v) => v.stock != null)
            ? variants.fold<int>(0, (sum, v) => sum + (v.stock ?? 0))
            : null);

    final bool? rootInStock = (data['inStock'] as bool?) ??
        (variants.isNotEmpty ? variants.any((v) => v.inStock == true || (v.stock != null && v.stock! > 0)) : null);

    return ImportedProductData(
      id: 'hb_${DateTime.now().millisecondsSinceEpoch}_${sku.hashCode.abs()}',
      sourceUrl: uri.toString(),
      sourceId: data['productId']?.toString(),
      adapterName: adapterName,
      name: name,
      brand: brand,
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
}
