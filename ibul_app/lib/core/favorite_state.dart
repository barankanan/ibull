import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

class FavoriteState extends ChangeNotifier {
  static final FavoriteState _instance = FavoriteState._internal();

  factory FavoriteState() => _instance;

  FavoriteState._internal();

  final List<Product> _favorites = [];
  final Set<String> _favoriteKeys = <String>{};

  List<Product> get favorites => List.unmodifiable(_favorites);

  static String productKey(Product product) =>
      '${product.brand}|${product.name}';

  bool isFavorite(Product product) =>
      _favoriteKeys.contains(productKey(product));

  void replaceFavorites(Iterable<Product> products, {bool notify = true}) {
    _favorites
      ..clear()
      ..addAll(products);
    _rebuildKeys();
    if (notify) {
      notifyListeners();
    }
  }

  void toggleFavorite(Product product) {
    final key = productKey(product);
    if (_favoriteKeys.contains(key)) {
      _favorites.removeWhere((item) => productKey(item) == key);
      _favoriteKeys.remove(key);
    } else {
      _favorites.add(product);
      _favoriteKeys.add(key);
    }
    notifyListeners();
  }

  void clear({bool notify = true}) {
    _favorites.clear();
    _favoriteKeys.clear();
    if (notify) {
      notifyListeners();
    }
  }

  void _rebuildKeys() {
    _favoriteKeys
      ..clear()
      ..addAll(_favorites.map(productKey));
  }
}
