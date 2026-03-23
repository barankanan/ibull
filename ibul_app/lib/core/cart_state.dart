import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

class CartState extends ChangeNotifier {
  static final CartState _instance = CartState._internal();

  factory CartState() => _instance;

  CartState._internal();

  final List<Product> _cart = [];
  final Set<String> _cartKeys = <String>{};

  List<Product> get cart => List.unmodifiable(_cart);

  static String productKey(Product product) => '${product.brand}|${product.name}';

  bool isInCart(Product product) => _cartKeys.contains(productKey(product));

  void replaceCart(Iterable<Product> products, {bool notify = true}) {
    _cart
      ..clear()
      ..addAll(products);
    _rebuildKeys();
    if (notify) {
      notifyListeners();
    }
  }

  void addOrReplace(Product product) {
    final key = productKey(product);
    final index = _cart.indexWhere((item) => productKey(item) == key);
    if (index == -1) {
      _cart.add(product);
      _cartKeys.add(key);
    } else {
      _cart[index] = product;
      _cartKeys.add(key);
    }
    notifyListeners();
  }

  void updateProductServices(Product product, List<String> services) {
    final key = productKey(product);
    final index = _cart.indexWhere((item) => productKey(item) == key);
    if (index == -1) return;
    _cart[index] = _cart[index].copyWith(selectedServices: services);
    _cartKeys.add(key);
    notifyListeners();
  }

  void remove(Product product) {
    final key = productKey(product);
    final initialLength = _cart.length;
    _cart.removeWhere((item) => productKey(item) == key);
    if (_cart.length == initialLength) return;
    _cartKeys.remove(key);
    _rebuildKeys();
    notifyListeners();
  }

  void clear({bool notify = true}) {
    _cart.clear();
    _cartKeys.clear();
    if (notify) {
      notifyListeners();
    }
  }

  void _rebuildKeys() {
    _cartKeys
      ..clear()
      ..addAll(_cart.map(productKey));
  }
}
