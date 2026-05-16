part of 'app_state.dart';

extension _AppStateAuthDomain on AppState {
  Future<void> _loadLocalCollectionsImpl({int? requestVersion}) async {
    await _runBatchedAsync(() async {
      try {
        final localFavorites = await _loadDeviceCachedField('favorites');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (localFavorites is List) {
          _favoriteState.replaceFavorites(
            localFavorites.whereType<Map>().map(
              (e) => Product.fromJson(Map<String, dynamic>.from(e)),
            ),
            notify: false,
          );
        }

        final localCart = await _loadDeviceCachedField('cart');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (localCart is List) {
          _cartState.replaceCart(
            localCart.whereType<Map>().map(
              (e) => Product.fromJson(Map<String, dynamic>.from(e)),
            ),
            notify: false,
          );
          await _resolveLegacyCartProductIds(requestVersion: requestVersion);
        }

        final localAddresses = await _loadDeviceCachedField('addresses');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (localAddresses is List) {
          _deliveryAddresses
            ..clear()
            ..addAll(
              localAddresses.whereType<Map>().map(
                (e) => Map<String, String>.from(e),
              ),
            );
        }

        final localCards = await _loadDeviceCachedField('savedCards');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (localCards is List) {
          _savedCards
            ..clear()
            ..addAll(
              localCards.whereType<Map>().map(
                (e) => Map<String, String>.from(e),
              ),
            );
        }

        final localFollowed = await _loadDeviceCachedField('followedStores');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (localFollowed is List) {
          _followedStores
            ..clear()
            ..addAll(
              localFollowed.whereType<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ),
            );
        }

        final prefs = await _getPrefs();
        final persistedCurrentAddress = prefs.getString(
          AppState._deviceCurrentDeliveryAddressKey,
        );
        if ((persistedCurrentAddress ?? '').trim().isNotEmpty) {
          _currentDeliveryAddress = persistedCurrentAddress!.trim();
        } else if (_deliveryAddresses.isNotEmpty) {
          _currentDeliveryAddress = _deliveryAddresses.first['detail'];
        }

        followedStoresNotifier.value = List<Map<String, dynamic>>.from(
          _followedStores,
        );
        _handleCartStateChanged();
      } catch (e) {
        debugPrint('AppState local collections load warn: $e');
      }
    });
  }

  Future<void> _loadUserDataImpl({int? requestVersion}) async {
    await _runBatchedAsync(() async {
      _clearUserData();

      try {
        final favoritesData = await _authService.getUserDataField('favorites');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        final resolvedFavorites = await _resolveUserCollectionValue(
          'favorites',
          favoritesData,
          requestVersion: requestVersion,
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (resolvedFavorites != null && resolvedFavorites is List) {
          _favoriteState.replaceFavorites(
            resolvedFavorites.map(
              (e) => Product.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
        }

        final cartData = await _authService.getUserDataField('cart');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        final resolvedCart = await _resolveUserCollectionValue(
          'cart',
          cartData,
          requestVersion: requestVersion,
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (resolvedCart != null && resolvedCart is List) {
          _cartState.replaceCart(
            resolvedCart.map(
              (e) => Product.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
          await _resolveLegacyCartProductIds(requestVersion: requestVersion);
          if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
            return;
          }
        }

        final addressesData = await _authService.getUserDataField('addresses');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        final resolvedAddresses = await _resolveUserCollectionValue(
          'addresses',
          addressesData,
          requestVersion: requestVersion,
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (resolvedAddresses != null && resolvedAddresses is List) {
          _deliveryAddresses.addAll(
            resolvedAddresses.map((e) => Map<String, String>.from(e)),
          );
        }

        final followedData = await _authService.getUserDataField(
          'followedStores',
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        final resolvedFollowed = await _resolveUserCollectionValue(
          'followedStores',
          followedData,
          requestVersion: requestVersion,
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (resolvedFollowed != null && resolvedFollowed is List) {
          _followedStores.addAll(
            resolvedFollowed.map((e) => Map<String, dynamic>.from(e)),
          );
        }
        unawaited(refreshFollowedStoresFromServer());

        final cardsData = await _authService.getUserDataField('savedCards');
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        final resolvedCards = await _resolveUserCollectionValue(
          'savedCards',
          cardsData,
          requestVersion: requestVersion,
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }
        if (resolvedCards != null && resolvedCards is List) {
          _savedCards.addAll(
            resolvedCards.map((e) => Map<String, String>.from(e)),
          );
        }

        await _restoreCurrentDeliveryAddressFromLocal(
          requestVersion: requestVersion,
        );
        if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
          return;
        }

        var productListsLoadedFromSocialTables = false;
        try {
          final remoteLists = await _productListService.getOwnedLists();
          if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
            return;
          }
          if (remoteLists.isNotEmpty) {
            _productLists
              ..clear()
              ..addAll(remoteLists.map(_decorateProductList));
            productListsLoadedFromSocialTables = true;
          }
        } catch (_) {}

        if (!productListsLoadedFromSocialTables) {
          final productListsData = await _authService.getUserDataField(
            'product_lists',
          );
          if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
            return;
          }
          if (productListsData != null && productListsData is List) {
            _productLists
              ..clear()
              ..addAll(
                productListsData
                    .whereType<Map>()
                    .map(
                      (e) => _decorateProductList(
                        ProductList.fromJson(Map<String, dynamic>.from(e)),
                      ),
                    )
                    .toList(),
              );
            unawaited(_syncAllProductListsToRemote());
          } else {
            await _loadPersistedProductLists();
            if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
              return;
            }
            unawaited(_syncAllProductListsToRemote());
          }
        }

        unawaited(refreshCommunityLists());

        notifyListeners();
        await Future.wait([
          _persistUserCachedField(
            'favorites',
            favorites.map((e) => e.toJson()).toList(),
          ),
          _persistUserCachedField('cart', cart.map((e) => e.toJson()).toList()),
          _persistUserCachedField('addresses', _deliveryAddresses),
          _persistUserCachedField('followedStores', _followedStores),
          _persistUserCachedField('savedCards', _savedCards),
          _persistAllCollectionsLocal(),
        ]);
      } catch (e) {
        debugPrint('Veri yükleme hatası: $e');
      }
    });
  }

  Future<void> _loginWithGoogleImpl() async {
    await _authService.signInWithGoogle();
  }

  Future<void> _logoutImpl() async {
    await _authService.signOut();
    _currentUser = null;
    _productLists.clear();
    _communityProductLists.clear();
    notifyListeners();
  }

  Future<void> _deleteAccountImpl() async {
    await _authService.deleteAccount();
    _currentUser = null;
    _productLists.clear();
    _communityProductLists.clear();
    notifyListeners();
  }
}
