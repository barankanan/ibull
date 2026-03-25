part of 'app_state.dart';

extension _AppStateCartFavoritesDomain on AppState {
  void _toggleFavoriteImpl(Product product) {
    _favoriteState.toggleFavorite(product);

    final payload = favorites.map((p) => p.toJson()).toList();
    unawaited(_persistUserCollection('favorites', payload));
    _syncPushInterests();
  }

  void _addToCartImpl(Product product) {
    final resolvedProduct = product.copyWith(
      productId: (product.productId ?? '').trim().isEmpty
          ? null
          : product.productId,
    );
    _cartState.addOrReplace(resolvedProduct);
    _clearCartAttention(resolvedProduct);
    _persistCartState();
    _syncPushInterests();
  }

  void _removeFromCartImpl(Product product) {
    _cartState.remove(product);
    _clearCartAttention(product);
    _persistCartState();
    _syncPushInterests();
  }
}
