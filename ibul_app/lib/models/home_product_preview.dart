import '../models/db_product.dart';

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

  double get displayPrice => discountPrice ?? price;

  bool get hasDiscount =>
      discountPrice != null && discountPrice! > 0 && discountPrice! < price;

  factory HomeProductPreview.fromDbProduct(DBProduct product) {
    final price = double.tryParse(product.price.replaceAll(',', '.')) ?? 0;
    final discount = product.oldPrice == null
        ? null
        : double.tryParse(product.oldPrice!.replaceAll(',', '.'));
    return HomeProductPreview(
      id: product.id ?? '',
      name: product.name,
      imageUrl: product.imageUrl,
      price: price,
      discountPrice: discount != null && discount > 0 && discount < price
          ? discount
          : null,
      storeName: product.store,
      brand: product.brand.isNotEmpty ? product.brand : null,
    );
  }
}
