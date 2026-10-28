import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_source_adapter.dart';

/// JSON-LD (Schema.org / Product) yapılandırılmış veri adaptörü
class JsonLdProductAdapter extends ProductSourceAdapter {
  const JsonLdProductAdapter();

  @override
  String get adapterName => 'JSON-LD (Schema.org)';

  @override
  int get priority => 20;

  @override
  bool canHandle(Uri uri) => true; // Tüm sayfalarda JSON-LD bulunabilir

  @override
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    final document = html_parser.parse(html);
    final scriptTags = document.querySelectorAll('script[type="application/ld+json"]');

    final List<ImportedProductData> products = [];

    for (final script in scriptTags) {
      final content = script.text.trim();
      if (content.isEmpty) continue;

      try {
        final decoded = jsonDecode(content);
        final productObjects = _findProductObjects(decoded);

        for (final productObj in productObjects) {
          final product = _mapJsonLdToImportedProduct(uri, productObj);
          if (product != null) {
            products.add(product);
          }
        }
      } catch (_) {
        // Hatalı JSON-LD formatı atlanır
      }
    }

    return products;
  }

  /// JSON-LD ağacından Product tipindeki nesneleri çıkarır (nested veya @graph dahil)
  List<Map<String, dynamic>> _findProductObjects(dynamic data) {
    final List<Map<String, dynamic>> results = [];

    if (data is Map<String, dynamic>) {
      final type = data['@type'];
      if (_isProductType(type)) {
        results.add(data);
      }
      if (data.containsKey('@graph') && data['@graph'] is List) {
        for (final item in data['@graph']) {
          results.addAll(_findProductObjects(item));
        }
      }
    } else if (data is List) {
      for (final item in data) {
        results.addAll(_findProductObjects(item));
      }
    }

    return results;
  }

  bool _isProductType(dynamic type) {
    if (type == null) return false;
    if (type is String) {
      return type.toLowerCase() == 'product';
    }
    if (type is List) {
      return type.any((t) => t.toString().toLowerCase() == 'product');
    }
    return false;
  }

  ImportedProductData? _mapJsonLdToImportedProduct(Uri uri, Map<String, dynamic> data) {
    final name = ProductImportSecurity.sanitizeText(data['name']?.toString());
    if (name.isEmpty) return null;

    final description = ProductImportSecurity.sanitizeText(data['description']?.toString());

    // Marka
    String brand = '';
    final brandObj = data['brand'];
    if (brandObj is Map) {
      brand = brandObj['name']?.toString().trim() ?? '';
    } else if (brandObj is String) {
      brand = brandObj.trim();
    }

    // SKU & Barkod
    final sku = data['sku']?.toString().trim() ??
        data['productID']?.toString().trim() ??
        '';
    final barcode = data['gtin13']?.toString().trim() ??
        data['gtin']?.toString().trim() ??
        data['gtin8']?.toString().trim() ??
        data['isbn']?.toString().trim() ??
        data['mpn']?.toString().trim();

    // Görseller
    final List<String> imageUrls = [];
    final imageObj = data['image'];
    if (imageObj is String && imageObj.isNotEmpty) {
      imageUrls.add(imageObj);
    } else if (imageObj is List) {
      for (final img in imageObj) {
        if (img is String && img.isNotEmpty) {
          imageUrls.add(img);
        } else if (img is Map && img['url'] != null) {
          imageUrls.add(img['url'].toString());
        }
      }
    } else if (imageObj is Map && imageObj['url'] != null) {
      imageUrls.add(imageObj['url'].toString());
    }

    // Fiyat ve Teklifler (Offers)
    double price = 0.0;
    double? discountPrice;
    String currency = 'TRY';
    int? stock;
    bool? rootInStock;

    final List<ImportedProductVariant> variants = [];
    final offers = data['offers'];

    if (offers is Map) {
      currency = ProductImportSecurity.parseCurrency(offers['priceCurrency']?.toString());
      final rawPrice = ProductImportSecurity.parsePrice(offers['price']);
      if (rawPrice != null) {
        price = rawPrice;
      } else {
        final lowPrice = ProductImportSecurity.parsePrice(offers['lowPrice']);
        if (lowPrice != null) price = lowPrice;
      }

      // Stok
      final availability = offers['availability']?.toString().toLowerCase() ?? '';
      if (availability.contains('outofstock') || availability.contains('discontinued')) {
        stock = 0;
        rootInStock = false;
      } else if (availability.contains('instock')) {
        stock = null; // Stokta var fakat kesin adet Schema.org'da belirtilmez
        rootInStock = true;
      }

      // AggregateOffers içinde alt offers listesi olabilir (Varyasyonlar)
      if (offers['offers'] is List) {
        for (int i = 0; i < (offers['offers'] as List).length; i++) {
          final subOffer = (offers['offers'] as List)[i];
          if (subOffer is Map) {
            final vPrice = ProductImportSecurity.parsePrice(subOffer['price']) ?? price;
            final vSku = subOffer['sku']?.toString();
            final vBarcode = subOffer['gtin13']?.toString() ?? subOffer['gtin']?.toString();
            final vTitle = subOffer['name']?.toString() ?? 'Varyasyon ${i + 1}';
            final vAvail = subOffer['availability']?.toString().toLowerCase() ?? '';
            final bool? vInStock = vAvail.contains('outofstock') || vAvail.contains('discontinued')
                ? false
                : (vAvail.contains('instock') ? true : null);
            final int? vStock = vInStock == false ? 0 : null;

            variants.add(ImportedProductVariant(
              id: 'jsonld_v_$i',
              combinationTitle: vTitle,
              sku: vSku,
              barcode: vBarcode,
              price: vPrice,
              stock: vStock,
              inStock: vInStock,
            ));
          }
        }
      }
    } else if (offers is List) {
      // Offers listesi -> Her biri bir varyasyon olabilir
      for (int i = 0; i < offers.length; i++) {
        final off = offers[i];
        if (off is Map) {
          final offPrice = ProductImportSecurity.parsePrice(off['price']) ?? 0.0;
          if (i == 0) {
            price = offPrice;
            currency = ProductImportSecurity.parseCurrency(off['priceCurrency']?.toString());
          }
          final offSku = off['sku']?.toString();
          final offTitle = off['name']?.toString() ?? 'Varyasyon ${i + 1}';
          final offAvail = off['availability']?.toString().toLowerCase() ?? '';
          final bool? offInStock = offAvail.contains('outofstock') || offAvail.contains('discontinued')
              ? false
              : (offAvail.contains('instock') ? true : null);
          final int? offStock = offInStock == false ? 0 : null;

          variants.add(ImportedProductVariant(
            id: 'jsonld_v_$i',
            combinationTitle: offTitle,
            sku: offSku,
            barcode: off['gtin13']?.toString() ?? off['gtin']?.toString(),
            price: offPrice,
            stock: offStock,
            inStock: offInStock,
          ));
        }
      }
    }

    if (rootInStock == null && variants.isNotEmpty) {
      rootInStock = variants.any((v) => v.inStock == true || (v.stock != null && v.stock! > 0));
    }

    // Teknik Özellikler (additionalProperty)
    final Map<String, dynamic> specifications = {};
    if (data['additionalProperty'] is List) {
      for (final prop in data['additionalProperty']) {
        if (prop is Map && prop['name'] != null && prop['value'] != null) {
          specifications[prop['name'].toString().trim()] = prop['value'].toString().trim();
        }
      }
    }

    // Kategori
    final categoryString = data['category']?.toString().trim() ?? '';

    return ImportedProductData(
      id: 'jsonld_${DateTime.now().millisecondsSinceEpoch}_${sku.hashCode.abs()}',
      sourceUrl: uri.toString(),
      sourceId: data['productID']?.toString(),
      adapterName: adapterName,
      name: name,
      brand: brand,
      sku: sku,
      barcode: barcode,
      price: price,
      discountPrice: discountPrice,
      currency: currency,
      originalCurrency: currency,
      stock: stock,
      inStock: rootInStock,
      mainCategory: categoryString,
      subCategory: '',
      description: description,
      imageUrls: imageUrls,
      specifications: specifications,
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
