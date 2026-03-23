import 'product_model.dart';

class ProductListPriceChange {
  const ProductListPriceChange({
    required this.product,
    required this.savedPrice,
    required this.currentPrice,
  });

  final Product product;
  final double savedPrice;
  final double currentPrice;

  double get delta => currentPrice - savedPrice;
  bool get hasDropped => delta < 0;
  bool get hasIncreased => delta > 0;
  double get percentageChange {
    if (savedPrice == 0) return 0;
    return (delta / savedPrice) * 100;
  }
}
