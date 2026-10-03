import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class CompareState extends ChangeNotifier {
  static final CompareState _instance = CompareState._internal();
  factory CompareState() => _instance;
  CompareState._internal();

  final List<Product> _compareProducts = [];
  
  List<Product> get compareProducts => List.unmodifiable(_compareProducts);

  bool isCompared(Product product) =>
      _compareProducts.any((p) => p.productId == product.productId && p.productId != null);

  String? addProduct(Product product) {
    if (_compareProducts.length >= 4) {
      return 'En fazla 4 ürün karşılaştırabilirsiniz.';
    }

    if (_compareProducts.isNotEmpty) {
      final firstProduct = _compareProducts.first;
      final isFirstDigital = firstProduct.isDigital;
      final isNewDigital = product.isDigital;
      
      if (isFirstDigital != isNewDigital) {
        return 'Araç ve e-ticaret ürünleri aynı anda karşılaştırılamaz.';
      }
    }

    if (!_compareProducts.any((p) => p.productId == product.productId && p.productId != null)) {
      _compareProducts.add(product);
      notifyListeners();
    }
    return null; // Başarılı
  }

  void removeProduct(Product product) {
    _compareProducts.removeWhere((p) => p.productId == product.productId);
    notifyListeners();
  }

  String? toggleCompare(Product product) {
    if (isCompared(product)) {
      removeProduct(product);
      return null;
    } else {
      return addProduct(product);
    }
  }

  void clear() {
    _compareProducts.clear();
    notifyListeners();
  }
}
