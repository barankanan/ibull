import '../models/imported_product.dart';
import 'amazon_product_adapter.dart';
import 'ciceksepeti_product_adapter.dart';
import 'general_html_product_adapter.dart';
import 'hepsiburada_product_adapter.dart';
import 'json_ld_product_adapter.dart';
import 'n11_product_adapter.dart';
import 'open_graph_product_adapter.dart';
import 'product_source_adapter.dart';
import 'shopify_product_adapter.dart';
import 'trendyol_product_adapter.dart';

/// Kaynak adaptörlerini yöneten ve analiz akışını orkestre eden merkezi kayıt defteri
class AdapterRegistry {
  AdapterRegistry({List<ProductSourceAdapter>? adapters})
      : _adapters = adapters ??
            [
              const TrendyolProductAdapter(),
              const HepsiburadaProductAdapter(),
              const AmazonProductAdapter(),
              const N11ProductAdapter(),
              const CiceksepetiProductAdapter(),
              const ShopifyProductAdapter(),
              const JsonLdProductAdapter(),
              const OpenGraphProductAdapter(),
              const GeneralHtmlProductAdapter(),
            ] {
    _adapters.sort((a, b) => b.priority.compareTo(a.priority));
  }

  final List<ProductSourceAdapter> _adapters;

  List<ProductSourceAdapter> get adapters => List.unmodifiable(_adapters);

  /// URL için uygun adaptörleri bulur ve veriyi ayrıştırır
  Future<List<ImportedProductData>> parseProductPage({
    required Uri uri,
    required String html,
    Map<String, dynamic>? meta,
  }) async {
    final matchingAdapters = _adapters.where((a) => a.canHandle(uri)).toList();

    for (final adapter in matchingAdapters) {
      try {
        final products = await adapter.parse(uri: uri, html: html, meta: meta);
        if (products.isNotEmpty && products.any((p) => p.name.isNotEmpty)) {
          // Eğer bulunan ürünün görseli yoksa veya açıklaması eksikse, OpenGraph/JSON-LD ile zenginleştir
          return _enrichProducts(products, uri, html, meta);
        }
      } catch (_) {
        // Bu adaptör başarısız olursa sıradakine geç
        continue;
      }
    }

    return const [];
  }

  /// Eksik alanları diğer genel kaynaklardan tamamlar
  Future<List<ImportedProductData>> _enrichProducts(
    List<ImportedProductData> products,
    Uri uri,
    String html,
    Map<String, dynamic>? meta,
  ) async {
    // Eğer görsel veya fiyat eksikse OpenGraph'tan tamamlamayı dene
    final ogAdapter = _adapters.whereType<OpenGraphProductAdapter>().firstOrNull;
    if (ogAdapter != null) {
      try {
        final ogProducts = await ogAdapter.parse(uri: uri, html: html, meta: meta);
        if (ogProducts.isNotEmpty) {
          final og = ogProducts.first;
          return products.map((p) {
            final images = List<String>.from(p.imageUrls);
            if (images.isEmpty && og.imageUrls.isNotEmpty) {
              images.addAll(og.imageUrls);
            }
            final price = p.price > 0 ? p.price : og.price;
            final brand = p.brand.isNotEmpty ? p.brand : og.brand;
            final desc = p.description.isNotEmpty ? p.description : og.description;

            return p.copyWith(
              imageUrls: images,
              price: price,
              brand: brand,
              description: desc,
            );
          }).toList();
        }
      } catch (_) {}
    }

    return products;
  }
}
