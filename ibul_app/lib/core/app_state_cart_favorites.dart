part of 'app_state.dart';

extension _AppStateCartFavoritesDomain on AppState {
  void _toggleFavoriteImpl(Product product) {
    _favoriteState.toggleFavorite(product);

    final payload = favorites.map((p) => p.toJson()).toList();
    unawaited(_persistUserCollection('favorites', payload));
    _syncPushInterests();
    notifyListeners();
  }

  Future<String?> addToCartValidated(
    Product product, {
    bool variantSelectionComplete = true,
  }) async {
    final key = CartState.productKey(product);
    if (_cartAddInFlightKeys.contains(key)) {
      return null;
    }
    _cartAddInFlightKeys.add(key);
    try {
      final validation = await CartValidationService.instance.validateForAdd(
        product,
        variantSelectionComplete: variantSelectionComplete,
      );
      if (!validation.allowed) {
        return validation.message;
      }
      _addToCartImpl(validation.product ?? product);
      return null;
    } finally {
      _cartAddInFlightKeys.remove(key);
    }
  }

  void _addToCartImpl(Product product) {
    final resolvedProduct = product.copyWith(
      productId: (product.productId ?? '').trim().isEmpty
          ? null
          : product.productId,
      cartQuantity: product.cartQuantity ?? 1,
    );
    _cartState.addOrReplace(resolvedProduct);
    _selectedCartTabIndex = CartState.tabIndexForProduct(resolvedProduct);
    _clearCartAttention(resolvedProduct);
    unawaited(_persistCartState());
    _syncPushInterests();
    notifyListeners();
  }

  void _removeFromCartImpl(Product product) {
    _cartState.remove(product);
    _clearCartAttention(product);
    unawaited(_persistCartState());
    _syncPushInterests();
    notifyListeners();
  }
}
