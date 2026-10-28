import '../models/imported_product.dart';

/// Gerçek varyasyon kombinasyonlarını yöneten ve İBUL veritabanı modeline dönüştüren servis
class ProductVariationCombiner {
  const ProductVariationCombiner();

  /// Kaynaktan gelen gerçek varyasyon kombinasyonlarını İBUL ürün formatına dönüştürür.
  /// Kaynakta gerçekten bulunan kombinasyonlar korunur; olmayan kombinasyonlar uydurulmaz.
  List<Map<String, dynamic>> toDbVariants(
    List<ImportedProductVariant> variants, {
    double basePrice = 0.0,
  }) {
    final List<Map<String, dynamic>> dbVariants = [];

    for (final variant in variants) {
      final double diff = variant.price - basePrice;

      final map = <String, dynamic>{
        'id': variant.id,
        'title': variant.combinationTitle,
        'color': variant.color,
        'colorHex': variant.colorHex,
        'size': variant.size,
        'ram': variant.ram,
        'storage': variant.storage,
        'sku': variant.sku,
        'barcode': variant.barcode,
        'stock': variant.stock ?? 0,
        if (variant.stock == null) 'stock_unknown': true,
        'stock_quantity': variant.stock,
        'in_stock': variant.inStockStatus,
        'price': variant.price,
        'discountPrice': variant.discountPrice,
        'priceDifference': diff,
        'imageUrl': variant.imageUrl,
        'imagePath': variant.imageUrl, // StoreService.addProduct & product selector uyumu
        'specValues': variant.specValues,
      };

      // Null veya boş string alanları temizle (ancak 'stock_quantity' alanını null olsa bile şema gereği koru)
      map.removeWhere((key, value) {
        if (key == 'stock_quantity') return false;
        return value == null || (value is String && value.trim().isEmpty);
      });

      dbVariants.add(map);
    }

    return dbVariants;
  }

  /// Veritabanı formatındaki varyantları ImportedProductVariant listesine geri dönüştürür
  List<ImportedProductVariant> fromDbVariants(List<dynamic> rawList, {double basePrice = 0.0}) {
    final List<ImportedProductVariant> list = [];

    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is Map) {
        final title = item['title']?.toString() ??
            item['combinationTitle']?.toString() ??
            'Varyasyon ${i + 1}';
        final price = (item['price'] as num?)?.toDouble() ??
            (basePrice + ((item['priceDifference'] as num?)?.toDouble() ?? 0.0));

        final bool isUnknown = item['stock_unknown'] == true;
        final int? stockVal = isUnknown ? null : ((item['stock_quantity'] ?? item['stock']) as num?)?.toInt();

        final rawInStock = item['in_stock'];
        bool? inStockParsed;
        if (rawInStock is bool) {
          inStockParsed = rawInStock;
        } else if (rawInStock is String) {
          if (rawInStock == 'in_stock') {
            inStockParsed = true;
          } else if (rawInStock == 'out_of_stock') {
            inStockParsed = false;
          }
        }

        list.add(ImportedProductVariant(
          id: item['id']?.toString() ?? 'variant_$i',
          combinationTitle: title,
          color: item['color']?.toString(),
          colorHex: item['colorHex']?.toString(),
          size: item['size']?.toString(),
          ram: item['ram']?.toString(),
          storage: item['storage']?.toString(),
          sku: item['sku']?.toString(),
          barcode: item['barcode']?.toString(),
          price: price,
          discountPrice: (item['discountPrice'] as num?)?.toDouble(),
          stock: stockVal,
          inStock: inStockParsed,
          imageUrl: item['imageUrl']?.toString() ?? item['imagePath']?.toString(),
          specValues: item['specValues'] is Map
              ? Map<String, String>.from(item['specValues'])
              : const {},
        ));
      }
    }

    return list;
  }

  /// Ham seçeneklerden gerçek kombinasyon listesini filtreler veya doğrular
  List<ImportedProductVariant> validateExistingCombinations({
    required List<ImportedProductVariant> detectedVariants,
    required Map<String, List<String>> declaredOptions,
    required double basePrice,
  }) {
    // Yalnızca kaynakta gerçekten mevcut varyasyonlar tutulur
    final List<ImportedProductVariant> validated = [];
    final Set<String> seenCombinations = {};

    for (final v in detectedVariants) {
      final key = '${v.color ?? ''}_${v.size ?? ''}_${v.storage ?? ''}_${v.ram ?? ''}_${v.combinationTitle}'.toLowerCase();
      if (seenCombinations.add(key)) {
        validated.add(v);
      }
    }

    return validated;
  }
}
