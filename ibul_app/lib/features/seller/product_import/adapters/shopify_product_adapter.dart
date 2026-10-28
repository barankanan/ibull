import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// Shopify E-ticaret Siteleri Adaptörü
class ShopifyProductAdapter extends ProductSourceAdapter {
  const ShopifyProductAdapter();

  @override
  String get adapterName => 'Shopify Adaptörü';

  @override
  int get priority => 40;

  @override
  bool canHandle(Uri uri) {
    // URL yolunda /products/ geçiyorsa veya genel Shopify mağazasıysa
    return uri.path.contains('/products/');
  }

  /// Shopify ürün URL'sini doğrudan REST JSON (.js) endpoint'ine dönüştürür.
  /// Bu endpoint Cloudflare HTML challenge sayfalarını tamamen baypas eder.
  static Uri buildEndpointUri(Uri uri) {
    var path = uri.path;
    if (!path.endsWith('.js')) {
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      path = '$path.js';
    }
    return Uri(
      scheme: uri.scheme.isNotEmpty ? uri.scheme : 'https',
      userInfo: uri.userInfo.isNotEmpty ? uri.userInfo : null,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    final productJson = _extractShopifyJson(html);
    if (productJson != null) {
      final product = _mapShopifyProduct(uri, productJson);
      if (product != null) return [product];
    }
    return const [];
  }

  Map<String, dynamic>? _extractShopifyJson(String html) {
    final trimmed = html.trim();

    // 0. Doğrudan JSON string kontrolü (.js endpoint'i veya doğrudan API yanıtı)
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('product') && decoded['product'] is Map) {
            return Map<String, dynamic>.from(decoded['product']);
          }
          if (decoded.containsKey('title') &&
              (decoded.containsKey('variants') || decoded.containsKey('id') || decoded.containsKey('price'))) {
            return decoded;
          }
        }
      } catch (_) {}
    }

    final document = html_parser.parse(html);

    // 1. Script tag with id containing ProductJson
    final scripts = document.querySelectorAll('script');
    for (final s in scripts) {
      final id = s.attributes['id']?.toLowerCase() ?? '';
      if (id.contains('productjson') || id.contains('product-json')) {
        try {
          final decoded = jsonDecode(s.text);
          if (decoded is Map<String, dynamic> && decoded.containsKey('variants')) {
            return decoded;
          }
        } catch (_) {}
      }
    }

    // 2. Inline regex pattern: var meta = {"product":{...}} veya ShopifyAnalytics
    final match = RegExp(r'var\s+meta\s*=\s*(\{.+?\});', dotAll: true).firstMatch(html);
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

  ImportedProductData? _mapShopifyProduct(Uri uri, Map<String, dynamic> data) {
    final name = ProductImportSecurity.sanitizeText(data['title']?.toString() ?? data['name']?.toString());
    if (name.isEmpty) return null;

    final brand = data['vendor']?.toString() ?? '';
    final description = ProductImportSecurity.sanitizeText(data['description']?.toString() ?? data['body_html']?.toString());

    // Görseller
    final List<String> images = [];
    final rawImages = data['images'];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is String) {
          images.add(_normalizeUrl(img));
        } else if (img is Map && img['src'] != null) {
          images.add(_normalizeUrl(img['src'].toString()));
        }
      }
    }

    // Seçenekler (Options)
    final Map<String, List<String>> variantOptions = {};
    if (data['options'] is List) {
      for (final opt in data['options']) {
        if (opt is Map && opt['name'] != null && opt['values'] is List) {
          variantOptions[opt['name'].toString()] = List<String>.from(opt['values']);
        } else if (opt is String) {
          variantOptions[opt] = [];
        }
      }
    }

    // Gerçek Varyasyonlar (Variants)
    final List<ImportedProductVariant> variants = [];
    double basePrice = 0.0;
    double? discountPrice;
    String baseSku = '';
    String? baseBarcode;

    final rawVariants = data['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      for (int i = 0; i < rawVariants.length; i++) {
        final v = rawVariants[i];
        if (v is Map) {
          final vTitle = v['title']?.toString() ?? 'Varyasyon ${i + 1}';
          final vSku = v['sku']?.toString();
          final vBarcode = v['barcode']?.toString();
          final vPrice = parseShopifyPrice(v['price']) ?? 0.0;
          final vComparePrice = parseShopifyPrice(v['compare_at_price']);
          
          int? vStock;
          if (v['inventory_quantity'] is num) {
            vStock = (v['inventory_quantity'] as num).toInt();
          } else if (v['available'] == false) {
            vStock = 0;
          } else {
            vStock = null; // Bilinmiyor
          }

          final bool? vAvailable = v['available'] as bool?;

          double variantNormalPrice = vPrice;
          double? variantDiscountPrice;
          if (vComparePrice != null && vComparePrice > vPrice) {
            variantNormalPrice = vComparePrice;
            variantDiscountPrice = vPrice;
          }

          if (i == 0) {
            basePrice = variantNormalPrice;
            discountPrice = variantDiscountPrice;
            if (vSku != null && vSku.isNotEmpty) baseSku = vSku;
            baseBarcode = vBarcode;
          }

          String? vImg;
          final featImg = v['featured_image'];
          if (featImg is Map && featImg['src'] != null) {
            vImg = _normalizeUrl(featImg['src'].toString());
          } else if (featImg is String && featImg.isNotEmpty) {
            vImg = _normalizeUrl(featImg);
          }

          // Seçenekleri ayrıştır (option1, option2, option3)
          String? color;
          String? size;
          final opt1 = v['option1']?.toString();
          final opt2 = v['option2']?.toString();
          final opt3 = v['option3']?.toString();

          final optKeys = variantOptions.keys.toList();
          if (optKeys.isNotEmpty && opt1 != null) {
            final key = optKeys[0].toLowerCase();
            if (key.contains('renk') || key.contains('color')) color = opt1;
            if (key.contains('beden') || key.contains('size')) size = opt1;
          }
          if (optKeys.length > 1 && opt2 != null) {
            final key = optKeys[1].toLowerCase();
            if (key.contains('renk') || key.contains('color')) color = opt2;
            if (key.contains('beden') || key.contains('size')) size = opt2;
          }
          if (optKeys.length > 2 && opt3 != null) {
            final key = optKeys[2].toLowerCase();
            if (key.contains('renk') || key.contains('color')) color = opt3;
            if (key.contains('beden') || key.contains('size')) size = opt3;
          }

          variants.add(ImportedProductVariant(
            id: 'shopify_v_$i',
            combinationTitle: vTitle,
            color: color,
            size: size,
            sku: vSku,
            barcode: vBarcode,
            price: variantNormalPrice,
            discountPrice: variantDiscountPrice,
            stock: vStock,
            inStock: vAvailable,
            imageUrl: vImg ?? (images.isNotEmpty ? images.first : null),
          ));
        }
      }
    } else {
      basePrice = parseShopifyPrice(data['price']) ?? 0.0;
    }

    final int? rootStock = variants.isNotEmpty && variants.every((v) => v.stock != null)
        ? variants.fold<int>(0, (sum, v) => sum + (v.stock ?? 0))
        : null;

    final bool? rootInStock = variants.isNotEmpty
        ? variants.any((v) => v.inStock == true || (v.stock != null && v.stock! > 0))
        : (data['available'] as bool?);

    return ImportedProductData(
      id: 'shopify_${DateTime.now().millisecondsSinceEpoch}_${baseSku.hashCode.abs()}',
      sourceUrl: uri.toString(),
      sourceId: data['id']?.toString(),
      adapterName: adapterName,
      name: name,
      brand: brand,
      sku: baseSku,
      barcode: baseBarcode,
      price: basePrice,
      discountPrice: discountPrice,
      currency: 'TRY',
      originalCurrency: 'TRY',
      stock: rootStock,
      inStock: rootInStock,
      mainCategory: data['type']?.toString() ?? '',
      subCategory: '',
      description: description,
      imageUrls: images,
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

  String _normalizeUrl(String url) {
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  /// Shopify fiyatını güvenli bir şekilde ayrıştırır.
  /// Shopify Ajax API (/products/*.js) fiyatları kuruş/cent cinsinden tamsayı döner (örn: 289900 -> 2899.00).
  /// HTML ProductJson içindeki "7500.00" gibi ondalıklı dizgiler normal değer olarak değerlendirilir.
  static double? parseShopifyPrice(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      return raw / 100.0;
    }
    if (raw is double) {
      return raw;
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    // "7500.00", "7.500,00" gibi ondalık veya virgüllü değerler
    if (str.contains('.') || str.contains(',')) {
      return ProductImportSecurity.parsePrice(str);
    }

    // Saf tamsayı metinleri (örn: "289900") cent olarak ele alınır
    final intVal = int.tryParse(str);
    if (intVal != null) {
      return intVal / 100.0;
    }

    return ProductImportSecurity.parsePrice(str);
  }
}
