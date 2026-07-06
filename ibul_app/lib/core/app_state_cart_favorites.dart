part of 'app_state.dart';

extension _AppStateCartFavoritesDomain on AppState {
  void _toggleFavoriteImpl(Product product) {
    _favoriteState.toggleFavorite(product);

    final payload = favorites.map((p) => p.toJson()).toList();
    unawaited(_persistUserCollection('favorites', payload));
    _syncPushInterests();
  }

  Future<String?> addToCartValidated(
    Product product, {
    bool variantSelectionComplete = true,
  }) async {
    final normalized = ProductCartIdentity.withCanonicalId(product);
    final canonicalId = ProductCartIdentity.resolve(normalized);
    CartAddDiagnostics.appStateAddStart(
      productId: product.productId?.trim() ?? '-',
      canonicalId: canonicalId,
    );

    final key = CartState.productKey(normalized);
    if (_cartAddInFlightKeys.contains(key)) {
      return null;
    }
    _cartAddInFlightKeys.add(key);
    try {
      final validation = await CartValidationService.instance.validateForAdd(
        normalized,
        variantSelectionComplete: variantSelectionComplete,
      );
      if (!validation.allowed) {
        return validation.message;
      }
      _addToCartImpl(validation.product ?? normalized);
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
    );
    _cartState.addOrReplace(resolvedProduct);
    _selectedCartTabIndex = CartState.tabIndexForProduct(resolvedProduct);
    _clearCartAttention(resolvedProduct);
    unawaited(_persistCartState());
    _syncPushInterests();
  }

  void _removeFromCartImpl(Product product) {
    _cartState.remove(product);
    _clearCartAttention(product);
    unawaited(_persistCartState());
    _syncPushInterests();
  }
}
