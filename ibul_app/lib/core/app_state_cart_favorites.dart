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

  void _noteCartMutation(String event, Product? product) {
    _cartRevision++;
    if (!kDebugMode) return;
    final ids = cart.map((item) => item.productId ?? item.name).join(',');
    debugPrint(
      '[CART_TRACE] $event product=${product?.productId ?? product?.name ?? '-'} '
      'instance=${identityHashCode(this)} count_after_add=${cart.length} ids=$ids',
    );
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
    _noteCartMutation('add', resolvedProduct);
    unawaited(_persistCartState());
    _syncPushInterests();
    notifyListeners();
  }

  void _removeFromCartImpl(Product product) {
    _cartState.remove(product);
    _clearCartAttention(product);
    _noteCartMutation('remove', product);
    unawaited(_persistCartState());
    _syncPushInterests();
    notifyListeners();
  }
}
