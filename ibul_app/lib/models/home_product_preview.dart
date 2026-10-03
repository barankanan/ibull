import '../models/db_product.dart';
import 'product_pricing.dart';

/// Minimal home-grid DTO — first paint only; detail page loads full product.
class HomeProductPreview {
  const HomeProductPreview({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.discountPrice,
    this.storeName,
    this.brand,
  });

  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final double? discountPrice;
  final String? storeName;
  final String? brand;

  /// `price` is products.price (list). `discountPrice` is products.discount_price.
  double get displayPrice => ProductPriceCalculator.resolveSellerPrice(
        listPrice: price,
        discountPrice: discountPrice,
      ).current;

  bool get hasDiscount => ProductPriceCalculator.resolveSellerPrice(
        listPrice: price,
        discountPrice: discountPrice,
      ).hasDiscount;

  factory HomeProductPreview.fromDbProduct(DBProduct product) {
    final list = ProductPriceCalculator.parsePriceValue(product.price);
    final sale = ProductPriceCalculator.parsePriceValue(product.oldPrice);
    return HomeProductPreview(
      id: product.id ?? '',
      name: product.name,
      imageUrl: product.imageUrl,
      price: list,
      discountPrice: sale > 0 ? sale : null,
      storeName: product.store,
      brand: product.brand.isNotEmpty ? product.brand : null,
    );
  }
}
