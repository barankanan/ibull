import '../models/imported_product.dart';

/// Kaynak site adaptörleri için temel soyut sınıf
abstract class ProductSourceAdapter {
  const ProductSourceAdapter();

  /// Bu adaptörün hedef URL'yi destekleyip desteklemediğini kontrol eder.
  bool canHandle(Uri uri);

  /// Adaptörün adı (Örn: "JSON-LD (Schema.org)", "Trendyol", "Shopify")
  String get adapterName;

  /// Adaptör önceliği (Daha yüksek öncelik önce çalışır)
  int get priority => 10;

  /// HTML ve kaynak verisini analiz edip standart ürün modellerine dönüştürür.
  Future<List<ImportedProductData>> parse({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  });
}
