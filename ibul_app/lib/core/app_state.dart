import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/user_identity.dart';
import 'cart_state.dart';
import 'favorite_state.dart';
import 'review_state.dart';
import '../services/auth_service.dart';
import '../services/product_list_service.dart';
import '../services/push_notification_service.dart';
import '../services/store_follow_service.dart';
import '../services/supabase_service.dart';
import '../models/product_model.dart';
import '../models/product_list_model.dart';
import '../models/product_list_price_change.dart';

/// Global uygulama state'i - favoriler ve sepet
/// Provider pattern ile yönetilmektedir.
part 'app_state_auth.dart';
part 'app_state_profile.dart';
part 'app_state_cart_favorites.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  final CartState _cartState = CartState();
  final FavoriteState _favoriteState = FavoriteState();
  final ReviewState _reviewState = ReviewState();
  final ProductListService _productListService = ProductListService.instance;
  Future<SharedPreferences>? _prefsFuture;
  bool _notifyScheduled = false;
  bool _pendingNotifyAfterBatch = false;
  int _batchedMutationDepth = 0;
  bool _startupHydrationScheduled = false;

  AppState._internal() {
    _initAuth();
    _loadLocalCollections(requestVersion: _authStateVersion);
    _scheduleStartupHydration();
    _cartState.addListener(_handleCartStateChanged);
    _favoriteState.addListener(notifyListeners);
    _reviewState.addListener(notifyListeners);
  }

  final AuthService _authService = AuthService();
  int _authStateVersion = 0;
  static const String _deviceFavoritesKey = 'device_cache_favorites_v1';
  static const String _deviceCartKey = 'device_cache_cart_v1';
  static const String _deviceAddressesKey = 'device_cache_addresses_v1';
  static const String _deviceSavedCardsKey = 'device_cache_saved_cards_v1';
  static const String _deviceFollowedStoresKey =
      'device_cache_followed_stores_v1';
  static const String _deviceCurrentDeliveryAddressKey =
      'device_cache_current_delivery_address_v1';

  // Kullanıcı bilgileri
  Map<String, dynamic>? _currentUser;

  Future<SharedPreferences> _getPrefs() =>
      _prefsFuture ??= SharedPreferences.getInstance();

  Future<T> _runBatchedAsync<T>(Future<T> Function() action) async {
    _batchedMutationDepth++;
    try {
      return await action();
    } finally {
      _batchedMutationDepth--;
      if (_batchedMutationDepth == 0 && _pendingNotifyAfterBatch) {
        _pendingNotifyAfterBatch = false;
        notifyListeners();
      }
    }
  }

  void _scheduleStartupHydration() {
    if (_startupHydrationScheduled) return;
    _startupHydrationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateStartupState());
    });
  }

  Future<void> _hydrateStartupState() async {
    try {
      await _runBatchedAsync(() async {
        await Future.wait<void>([
          _loadSearchHistory(),
          _loadPersistedProductQuestions(),
          _loadPersistedProductLists(),
        ]);
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AppState deferred startup hydration failed: $error');
      }
    }
  }

  @override
  void notifyListeners() {
    if (_batchedMutationDepth > 0) {
      _pendingNotifyAfterBatch = true;
      return;
    }
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Search History Persistence
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await _getPrefs();
      final history = prefs.getStringList('search_history');
      if (history != null) {
        _searchHistory.clear();
        _searchHistory.addAll(history);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading search history: $e');
      }
    }
  }

  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving search history: $e');
      }
    }
  }

  void _initAuth() {
    _authService.authStateChanges.listen((authState) async {
      final requestVersion = ++_authStateVersion;
      final user = authState.session?.user;
      if (user != null) {
        final profile = await _authService.getUserProfile();
        if (_isStaleAuthRequest(requestVersion)) return;
        _currentUser = UserIdentity.buildAuthUserMap(
          uid: user.id,
          email: user.email,
          profile: profile,
          userMetadata: Map<String, dynamic>.from(
            user.userMetadata ?? const {},
          ),
        );

        if (UserIdentity.isGuest(_currentUser)) {
          await _loadGuestData(requestVersion: requestVersion);
        } else {
          // Normal kullanıcı için verileri Firestore'dan yükle
          await _loadUserData(requestVersion: requestVersion);
          if (_isStaleAuthRequest(requestVersion)) return;
          _syncPushInterests();
        }
      } else {
        _currentUser = null;
        _clearUserData(); // Çıkış yapınca temizle
        await _loadGuestData(requestVersion: requestVersion);
      }
      if (_isStaleAuthRequest(requestVersion)) return;
      notifyListeners();
    });
  }

  bool _isStaleAuthRequest(int requestVersion) {
    return requestVersion != _authStateVersion;
  }

  String? get _cacheUserId => _currentUser?['uid']?.toString();

  String? _userCacheKey(String field) {
    final userId = _cacheUserId;
    if (userId == null || userId.isEmpty) return null;
    return 'user_cache_${userId}_$field';
  }

  Future<dynamic> _loadUserCachedField(String field) async {
    final key = _userCacheKey(field);
    if (key == null) return null;
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistUserCachedField(String field, dynamic value) async {
    final key = _userCacheKey(field);
    if (key == null) return;
    final prefs = await _getPrefs();
    await prefs.setString(key, jsonEncode(value));
  }

  String? _deviceCacheKey(String field) {
    switch (field) {
      case 'favorites':
        return _deviceFavoritesKey;
      case 'cart':
        return _deviceCartKey;
      case 'addresses':
        return _deviceAddressesKey;
      case 'savedCards':
        return _deviceSavedCardsKey;
      case 'followedStores':
        return _deviceFollowedStoresKey;
      default:
        return null;
    }
  }

  Future<dynamic> _loadDeviceCachedField(String field) async {
    final key = _deviceCacheKey(field);
    if (key == null) return null;
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistDeviceCachedField(String field, dynamic value) async {
    final key = _deviceCacheKey(field);
    if (key == null) return;
    final prefs = await _getPrefs();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<void> _persistCurrentDeliveryAddressLocal() async {
    final prefs = await _getPrefs();
    if ((_currentDeliveryAddress ?? '').trim().isEmpty) {
      await prefs.remove(_deviceCurrentDeliveryAddressKey);
      return;
    }
    await prefs.setString(
      _deviceCurrentDeliveryAddressKey,
      _currentDeliveryAddress!,
    );
  }

  Future<void> _persistAllCollectionsLocal() async {
    await Future.wait([
      _persistDeviceCachedField(
        'favorites',
        favorites.map((e) => e.toJson()).toList(growable: false),
      ),
      _persistDeviceCachedField(
        'cart',
        cart.map((e) => e.toJson()).toList(growable: false),
      ),
      _persistDeviceCachedField('addresses', _deliveryAddresses),
      _persistDeviceCachedField('savedCards', _savedCards),
      _persistDeviceCachedField('followedStores', _followedStores),
      _persistCurrentDeliveryAddressLocal(),
    ]);
  }

  Future<void> _loadLocalCollections({int? requestVersion}) =>
      _loadLocalCollectionsImpl(requestVersion: requestVersion);

  bool _hasMeaningfulData(dynamic value) {
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return value != null;
  }

  Future<dynamic> _resolveUserCollectionValue(
    String field,
    dynamic remoteValue, {
    int? requestVersion,
  }) async {
    if (_hasMeaningfulData(remoteValue)) {
      return remoteValue;
    }

    final userCached = await _loadUserCachedField(field);
    if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
      return null;
    }
    if (_hasMeaningfulData(userCached)) {
      return userCached;
    }

    final deviceCached = await _loadDeviceCachedField(field);
    if (requestVersion != null && _isStaleAuthRequest(requestVersion)) {
      return null;
    }
    if (_hasMeaningfulData(deviceCached)) {
      return deviceCached;
    }

    return remoteValue;
  }

  Future<void> _restoreCurrentDeliveryAddressFromLocal({
    int? requestVersion,
  }) async {
    final prefs = await _getPrefs();
    if (requestVersion != null && _isStaleAuthRequest(requestVersion)) return;

    final persistedCurrentAddress = prefs.getString(
      _deviceCurrentDeliveryAddressKey,
    );
    final normalizedPersisted = persistedCurrentAddress?.trim() ?? '';
    if (normalizedPersisted.isNotEmpty &&
        _deliveryAddresses.any(
          (address) => (address['detail'] ?? '').trim() == normalizedPersisted,
        )) {
      _currentDeliveryAddress = normalizedPersisted;
      return;
    }

    if (_deliveryAddresses.isNotEmpty) {
      _currentDeliveryAddress = _deliveryAddresses.first['detail'];
    } else {
      _currentDeliveryAddress = null;
    }
  }

  // Kullanıcı verilerini Firestore'dan yükle
  Future<void> _loadUserData({int? requestVersion}) =>
      _loadUserDataImpl(requestVersion: requestVersion);

  Future<void> loginWithGoogle() => _loginWithGoogleImpl();

  Future<void> logout() => _logoutImpl();

  Future<void> deleteAccount() => _deleteAccountImpl();

  Future<void> updateUserProfile({
    String? displayName,
    double? weight,
    double? height,
    String? gender,
    String? birthDate,
    String? style,
    String? phone,
    String? address,
  }) => _updateUserProfileImpl(
    displayName: displayName,
    weight: weight,
    height: height,
    gender: gender,
    birthDate: birthDate,
    style: style,
    phone: phone,
    address: address,
  );

  // Deprecated: used for mock login previously
  void login(String name, String email) {
    final uid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _currentUser = UserIdentity.buildAuthUserMap(
      uid: uid,
      email: email,
      profile: {'name': name},
    );

    // Load Guest Data explicitly for mock login
    _loadGuestData();
    notifyListeners();
  }

  final Set<String> _cartAttentionKeys = <String>{};
  String? _cartAttentionMessage;

  final List<Map<String, dynamic>> _foodOrders = [];

  // Takip edilen mağazalar
  final List<Map<String, dynamic>> _followedStores = [];

  // Seçili teslimat adresi
  String? _currentDeliveryAddress;
  String? get currentDeliveryAddress => _currentDeliveryAddress;

  void setCurrentDeliveryAddress(String address) =>
      _setCurrentDeliveryAddressImpl(address);

  // Kayıtlı Adresler (Varsayılan olarak boş, misafir için doldurulacak)
  final List<Map<String, String>> _deliveryAddresses = [];

  // Kayıtlı Kartlar
  final List<Map<String, String>> _savedCards = [];
  List<Map<String, String>> get savedCards => List.unmodifiable(_savedCards);

  final List<Map<String, dynamic>> _productQuestions = [];

  final List<Map<String, String>> _billingInfos = [];

  // Arama Geçmişi
  final List<String> _searchHistory = [];
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  Future<void> _loadPersistedProductQuestions() async {
    try {
      final prefs = await _getPrefs();
      final rawQuestions = prefs.getString('product_questions_v1');
      _productQuestions
        ..clear()
        ..addAll(_decodeStoredReviewList(rawQuestions));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading persisted questions: $e');
      }
    }
  }

  List<Map<String, dynamic>> _decodeStoredReviewList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistProductQuestions() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(
        'product_questions_v1',
        jsonEncode(_productQuestions),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving persisted questions: $e');
      }
    }
  }

  Future<void> _loadPersistedProductLists() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('product_lists_v1');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _productLists
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map(
                (e) => _decorateProductList(
                  ProductList.fromJson(Map<String, dynamic>.from(e)),
                ),
              )
              .toList(),
        );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading persisted product lists: $e');
      }
    }
  }

  Future<void> _persistProductLists() async {
    final preparedLists = _productLists.map(_decorateProductList).toList();
    _productLists
      ..clear()
      ..addAll(preparedLists);
    final encoded = jsonEncode(
      _productLists.map((list) => list.toJson()).toList(),
    );
    try {
      final prefs = await _getPrefs();
      await prefs.setString('product_lists_v1', encoded);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving persisted product lists: $e');
      }
    }

    try {
      await _authService.updateUserDataField(
        'product_lists',
        _productLists.map((list) => list.toJson()).toList(),
      );
    } catch (_) {
      // DB kolonu henüz yoksa local persist ile devam et.
    }

    unawaited(_syncAllProductListsToRemote());
  }

  Future<void> _syncAllProductListsToRemote() async {
    if (!isLoggedIn || _productLists.isEmpty) return;
    for (final list in _productLists) {
      try {
        await _productListService.upsertList(_decorateProductList(list));
      } catch (_) {}
    }
  }

  String _normalizeReviewKey(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  String _maskedDisplayName() {
    return UserIdentity.maskedDisplayNameOf(_currentUser);
  }

  void addSearchHistory(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    if (_searchHistory.contains(trimmedQuery)) {
      _searchHistory.remove(trimmedQuery);
    }
    _searchHistory.insert(0, trimmedQuery);
    if (_searchHistory.length > 10) {
      _searchHistory.removeLast();
    }
    _saveSearchHistory();
    notifyListeners();
    _syncPushInterests();
  }

  void removeSearchHistory(String query) {
    _searchHistory.remove(query);
    _saveSearchHistory();
    notifyListeners();
    _syncPushInterests();
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    _saveSearchHistory();
    notifyListeners();
    _syncPushInterests();
  }

  // Son Gezilen Ürünler
  final List<Product> _recentlyViewedProducts = [];
  List<Product> get recentlyViewedProducts =>
      List.unmodifiable(_recentlyViewedProducts);

  void addRecentlyViewedProduct(Product product) {
    if (_recentlyViewedProducts.any((p) => p.name == product.name)) {
      _recentlyViewedProducts.removeWhere((p) => p.name == product.name);
    }
    _recentlyViewedProducts.insert(0, product);
    if (_recentlyViewedProducts.length > 5) {
      _recentlyViewedProducts.removeLast();
    }
    notifyListeners();
  }

  // Misafir kullanıcı için varsayılan verileri yükle
  Future<void> _loadGuestData({int? requestVersion}) async {
    _clearUserData();
    await _loadLocalCollections(requestVersion: requestVersion);
    await _loadPersistedProductLists();
    if (requestVersion != null && _isStaleAuthRequest(requestVersion)) return;
  }

  // Normal kullanıcı için verileri temizle
  void _clearUserData() {
    _currentDeliveryAddress = null;
    _deliveryAddresses.clear();
    _savedCards.clear();
    _billingInfos.clear();
    _favoriteState.clear();
    _cartState.clear();
    _cartAttentionKeys.clear();
    _cartAttentionMessage = null;
    // NOTE: _foodOrders intentionally NOT cleared here.
    // Food orders are in-session records created by the QR restaurant flow.
    // Auth state changes fire during Supabase initialization even for anonymous
    // users, which would erase a freshly-placed table order and make the
    // active-order screen appear blank. Orders are only removed when the user
    // explicitly dismisses them or the app restarts.
    _followedStores.clear();
    _communityProductLists.clear();
    debugPrint('[AppState] _clearUserData called — cart/favorites cleared; food orders PRESERVED');
  }

  // Kullanıcının özel listeleri (ProductList modeli)
  final List<ProductList> _productLists = [];
  final List<ProductList> _communityProductLists = [];

  List<ProductList> get productLists => List.unmodifiable(_productLists);
  List<ProductList> get communityProductLists =>
      List.unmodifiable(_communityProductLists);

  ProductList? getProductListById(String listId) {
    try {
      return _productLists.firstWhere((list) => list.id == listId);
    } catch (_) {
      return null;
    }
  }

  ProductList? getCommunityProductListById(String listId) {
    try {
      return _communityProductLists.firstWhere((list) => list.id == listId);
    } catch (_) {
      return null;
    }
  }

  ProductList? getAnyProductListById(String listId) {
    return getProductListById(listId) ?? getCommunityProductListById(listId);
  }

  String _productIdentity(Product product) =>
      _productListService.productKey(product);

  String _currentDisplayName() {
    final displayName = _currentUser?['display_name']?.toString().trim();
    final name = _currentUser?['name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (name != null && name.isNotEmpty) return name;
    return 'İBUL Kullanıcısı';
  }

  String? _currentPhotoUrl() {
    final photo = _currentUser?['photo_url']?.toString().trim();
    if (photo != null && photo.isNotEmpty) return photo;
    return null;
  }

  String? _firstProductSellerId(ProductList list) {
    for (final product in list.products) {
      final sellerId = product.sellerId?.trim();
      if (sellerId != null && sellerId.isNotEmpty) {
        return sellerId;
      }
    }
    return null;
  }

  String? _firstProductStoreName(ProductList list) {
    for (final product in list.products) {
      final storeName = product.store?.trim();
      if (storeName != null && storeName.isNotEmpty) {
        return storeName;
      }
    }
    return null;
  }

  ProductList _withOwnerDefaults(ProductList list) {
    return list.copyWith(
      ownerUserId: list.ownerUserId ?? _cacheUserId,
      sellerId: list.sellerId ?? _firstProductSellerId(list),
      storeName: list.storeName ?? _firstProductStoreName(list),
      ownerDisplayName: list.ownerDisplayName ?? _currentDisplayName(),
      ownerPhotoUrl: list.ownerPhotoUrl ?? _currentPhotoUrl(),
      shareCode: list.shareCode.isEmpty
          ? _productListService.buildShareCode(list.id)
          : list.shareCode,
    );
  }

  void _handleCartStateChanged() {
    cartCountNotifier.value = _cartState.cart.length;
    notifyListeners();
  }

  Future<void> _resolveLegacyCartProductIds({int? requestVersion}) async {
    final cartItems = cart.toList(growable: false);
    final legacyItems = cartItems
        .where((product) => (product.productId ?? '').trim().isEmpty)
        .toList(growable: false);
    _cartAttentionKeys.clear();
    _cartAttentionMessage = null;
    if (legacyItems.isEmpty) return;

    final resolvedProducts = await SupabaseService.instance.resolveCartProducts(
      legacyItems,
    );
    if (requestVersion != null && _isStaleAuthRequest(requestVersion)) return;

    var didResolveAny = false;
    for (var index = 0; index < cartItems.length; index++) {
      final product = cartItems[index];
      if ((product.productId ?? '').trim().isNotEmpty) continue;
      final resolved =
          resolvedProducts[SupabaseService.instance.cartResolutionKey(product)];
      if (resolved != null && (resolved.productId ?? '').trim().isNotEmpty) {
        cartItems[index] = resolved;
        didResolveAny = true;
      } else {
        _cartAttentionKeys.add(_productIdentity(product));
      }
    }

    if (_cartAttentionKeys.isNotEmpty) {
      _cartAttentionMessage =
          'Bazi sepet urunleri artik kullanilamiyor. Lutfen yeniden ekleyin.';
    }

    if (didResolveAny || _cartAttentionKeys.isNotEmpty) {
      _cartState.replaceCart(cartItems, notify: false);
      _handleCartStateChanged();
      await _persistCartState();
    }
  }

  Future<void> _persistCartState() async {
    final payload = cart.map((product) => product.toJson()).toList();
    await _persistUserCollection('cart', payload);
  }

  void _clearCartAttention(Product product) {
    _cartAttentionKeys.remove(_productIdentity(product));
    if (_cartAttentionKeys.isEmpty) {
      _cartAttentionMessage = null;
    }
  }

  ProductList _decorateProductList(ProductList list) {
    final withOwner = _withOwnerDefaults(list);
    final firstImage =
        withOwner.products.isNotEmpty &&
            withOwner.products.first.images.isNotEmpty
        ? withOwner.products.first.images.first
        : null;
    final firstProduct = withOwner.products.isNotEmpty
        ? withOwner.products.first
        : null;
    return withOwner.copyWith(
      description: withOwner.description?.trim().isNotEmpty == true
          ? withOwner.description
          : '${withOwner.productCount} ürün',
      iconUrl: withOwner.iconUrl ?? firstImage,
      sellerId: withOwner.sellerId ?? firstProduct?.sellerId,
      storeName: withOwner.storeName ?? firstProduct?.store,
      category:
          _normalizeListCategory(withOwner.category) ??
          _normalizeListCategory(firstProduct?.category),
      subCategory:
          _normalizeListCategory(withOwner.subCategory) ??
          _normalizeListCategory(firstProduct?.subCategory),
    );
  }

  String? _normalizeListCategory(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String? productListCategoryMessage(String listId, Product product) {
    final list = getProductListById(listId);
    if (list == null) return 'Liste bulunamadi.';

    final listCategory =
        _normalizeListCategory(list.category) ??
        _normalizeListCategory(
          list.products.isNotEmpty ? list.products.first.category : null,
        );
    final productCategory =
        _normalizeListCategory(product.category) ??
        _normalizeListCategory(product.subCategory);

    if (listCategory == null || productCategory == null) {
      return null;
    }
    if (listCategory.toLowerCase() == productCategory.toLowerCase()) {
      return null;
    }

    return 'Bu liste sadece "$listCategory" kategorisindeki urunleri kabul ediyor.';
  }

  // Liste yönetimi
  bool addToProductList(String listId, Product product) {
    final listIndex = _productLists.indexWhere((l) => l.id == listId);
    if (listIndex != -1) {
      final list = _productLists[listIndex];
      final categoryMessage = productListCategoryMessage(listId, product);
      if (categoryMessage != null) {
        return false;
      }
      final productKey = _productIdentity(product);
      final alreadyExists =
          list.productIds.contains(productKey) ||
          list.products.any((p) => _productIdentity(p) == productKey);
      if (!alreadyExists) {
        final updatedList = list.copyWith(
          productIds: [...list.productIds, productKey],
          products: [...list.products, product],
          iconUrl:
              list.iconUrl ??
              (product.images.isNotEmpty ? product.images.first : null),
          sellerId: list.sellerId ?? product.sellerId ?? _cacheUserId,
          storeName: list.storeName ?? product.store,
          category:
              _normalizeListCategory(list.category) ??
              _normalizeListCategory(product.category) ??
              _normalizeListCategory(product.subCategory),
          subCategory:
              _normalizeListCategory(list.subCategory) ??
              _normalizeListCategory(product.subCategory),
          description: list.description?.trim().isNotEmpty == true
              ? list.description
              : '${list.productCount + 1} ürün',
          updatedAt: DateTime.now(),
        );
        _productLists[listIndex] = _decorateProductList(updatedList);
        notifyListeners();
        _persistProductLists();
        _syncPushInterests();
        unawaited(
          _productListService.notifyFollowersForNewProduct(
            list: _productLists[listIndex],
            product: product,
          ),
        );
      }
      return true;
    }
    return false;
  }

  void removeFromProductList(String listId, String productId) {
    final listIndex = _productLists.indexWhere((l) => l.id == listId);
    if (listIndex != -1) {
      final list = _productLists[listIndex];
      final remainingProducts = list.products
          .where((product) => _productIdentity(product) != productId)
          .toList();
      final updatedList = list.copyWith(
        productIds: list.productIds.where((id) => id != productId).toList(),
        products: remainingProducts,
        iconUrl:
            remainingProducts.isNotEmpty &&
                remainingProducts.first.images.isNotEmpty
            ? remainingProducts.first.images.first
            : list.iconUrl,
        sellerId: remainingProducts.isNotEmpty
            ? remainingProducts.first.sellerId ?? list.sellerId
            : list.sellerId,
        storeName: remainingProducts.isNotEmpty
            ? remainingProducts.first.store ?? list.storeName
            : list.storeName,
        category: remainingProducts.isNotEmpty
            ? _normalizeListCategory(remainingProducts.first.category) ??
                  _normalizeListCategory(remainingProducts.first.subCategory)
            : null,
        subCategory: remainingProducts.isNotEmpty
            ? _normalizeListCategory(remainingProducts.first.subCategory)
            : null,
        description:
            list.description?.trim().isNotEmpty == true &&
                list.description != '${list.productCount} ürün'
            ? list.description
            : '${remainingProducts.length} ürün',
        updatedAt: DateTime.now(),
      );
      _productLists[listIndex] = _decorateProductList(updatedList);
      notifyListeners();
      _persistProductLists();
      _syncPushInterests();
    }
  }

  String createProductList(
    String name, {
    ProductListVisibility visibility = ProductListVisibility.private,
    String? description,
    String? coverImageUrl,
  }) {
    final id = 'list_${DateTime.now().millisecondsSinceEpoch}';
    final newList = ProductList(
      id: id,
      name: name,
      description: description?.trim().isNotEmpty == true
          ? description!.trim()
          : '0 ürün',
      iconUrl: coverImageUrl?.trim().isNotEmpty == true
          ? coverImageUrl!.trim()
          : null,
      visibility: visibility,
      shareCode: _productListService.buildShareCode(name),
      sellerId: _cacheUserId,
      productIds: [],
      products: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _productLists.add(_decorateProductList(newList));
    notifyListeners();
    _persistProductLists();
    return id;
  }

  void deleteProductList(String listId) {
    _productLists.removeWhere((l) => l.id == listId);
    notifyListeners();
    _persistProductLists();
    _syncPushInterests();
    unawaited(_productListService.deleteList(listId));
  }

  void updateProductListVisibility(
    String listId,
    ProductListVisibility visibility,
  ) {
    final index = _productLists.indexWhere((list) => list.id == listId);
    if (index == -1) return;
    _productLists[index] = _decorateProductList(
      _productLists[index].copyWith(
        visibility: visibility,
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _persistProductLists();
    if (visibility == ProductListVisibility.public) {
      unawaited(refreshCommunityLists());
    }
  }

  Future<void> updateProductListDetails(
    String listId, {
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    final index = _productLists.indexWhere((list) => list.id == listId);
    if (index == -1) return;

    final current = _productLists[index];
    _productLists[index] = _decorateProductList(
      current.copyWith(
        name: name?.trim().isNotEmpty == true ? name!.trim() : current.name,
        description: description == null
            ? current.description
            : (description.trim().isEmpty
                  ? '${current.productCount} ürün'
                  : description.trim()),
        iconUrl: iconUrl?.trim().isNotEmpty == true
            ? iconUrl!.trim()
            : current.iconUrl,
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _persistProductLists();
  }

  Future<void> refreshCommunityLists() async {
    if (!isLoggedIn) {
      _communityProductLists.clear();
      notifyListeners();
      return;
    }
    try {
      final lists = await _productListService.getPublicLists();
      _communityProductLists
        ..clear()
        ..addAll(
          lists
              .where((list) => list.ownerUserId != _cacheUserId)
              .map(_decorateProductList),
        );
      notifyListeners();
    } catch (_) {}
  }

  bool isFollowingProductList(String listId) {
    final list = getCommunityProductListById(listId);
    return list?.isFollowing ?? false;
  }

  bool areProductListNotificationsEnabled(String listId) {
    final list = getCommunityProductListById(listId);
    return list?.followNotificationsEnabled ?? true;
  }

  Future<void> followProductList(
    String listId, {
    bool notificationsEnabled = true,
  }) async {
    await _productListService.followList(
      listId,
      notificationsEnabled: notificationsEnabled,
    );
    final index = _communityProductLists.indexWhere(
      (list) => list.id == listId,
    );
    if (index != -1) {
      final list = _communityProductLists[index];
      _communityProductLists[index] = list.copyWith(
        isFollowing: true,
        followNotificationsEnabled: notificationsEnabled,
        followerCount: list.followerCount + (list.isFollowing ? 0 : 1),
      );
      notifyListeners();
    }
  }

  Future<void> unfollowProductList(String listId) async {
    await _productListService.unfollowList(listId);
    final index = _communityProductLists.indexWhere(
      (list) => list.id == listId,
    );
    if (index != -1) {
      final list = _communityProductLists[index];
      _communityProductLists[index] = list.copyWith(
        isFollowing: false,
        followNotificationsEnabled: false,
        followerCount: max(0, list.followerCount - 1),
      );
      notifyListeners();
    }
  }

  Future<void> updateProductListFollowNotifications(
    String listId, {
    required bool enabled,
  }) async {
    if (!isFollowingProductList(listId)) {
      await followProductList(listId, notificationsEnabled: enabled);
      return;
    }
    await _productListService.updateFollowNotifications(
      listId,
      enabled: enabled,
    );
    final index = _communityProductLists.indexWhere(
      (list) => list.id == listId,
    );
    if (index != -1) {
      _communityProductLists[index] = _communityProductLists[index].copyWith(
        followNotificationsEnabled: enabled,
      );
      notifyListeners();
    }
  }

  Future<List<ProductListPriceChange>> getProductListPriceChanges(
    String listId,
  ) async {
    final list = getAnyProductListById(listId);
    if (list == null) return const [];
    try {
      return await _productListService.getPriceChanges(list);
    } catch (_) {
      return const [];
    }
  }

  bool isProductInList(String listId, String productId) {
    final list = getProductListById(listId);
    if (list == null) return false;
    return list.productIds.contains(productId);
  }

  // Kullanıcının oluşturduğu listeler (eski yapı - uyumluluk için)
  // Hızlı teslimat seçenekleri (product hashCode -> bool)
  final Map<int, bool> _fastDelivery = {};

  // Dinleyiciler için notifier (Geriye uyumluluk için tutuluyor)
  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> followedStoresNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  List<Product> get favorites => _favoriteState.favorites;
  List<Product> get cart => _cartState.cart;
  bool get cartNeedsAttention => _cartAttentionKeys.isNotEmpty;
  String? get cartAttentionMessage => _cartAttentionMessage;
  List<Product> get cartAttentionProducts => cart
      .where(
        (product) => _cartAttentionKeys.contains(_productIdentity(product)),
      )
      .toList(growable: false);
  List<Map<String, dynamic>> get foodOrders => List.unmodifiable(_foodOrders);
  List<Map<String, dynamic>> get followedStores =>
      List.unmodifiable(_followedStores);
  List<Map<String, dynamic>> get userLists =>
      List.unmodifiable(_productLists.map(_productListToLegacyMap).toList());
  List<Map<String, dynamic>> get communityUserLists => List.unmodifiable(
    _communityProductLists.map(_productListToLegacyMap).toList(),
  );
  List<Map<String, String>> get deliveryAddresses =>
      List.unmodifiable(_deliveryAddresses);
  List<Map<String, String>> get billingInfos =>
      List.unmodifiable(_billingInfos);
  List<Map<String, dynamic>> get productReviews => _reviewState.productReviews;
  List<Map<String, dynamic>> get sellerReviews => _reviewState.sellerReviews;
  List<Map<String, dynamic>> get productQuestions =>
      List.unmodifiable(_productQuestions);

  List<Map<String, dynamic>> get myProductReviews {
    final userId = _currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) return [];
    return _reviewState.getMyProductReviews(userId);
  }

  List<Map<String, dynamic>> get mySellerReviews {
    final userId = _currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) return [];
    return _reviewState.getMySellerReviews(userId);
  }

  List<Map<String, dynamic>> get myProductQuestions {
    final userId = _currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) return [];
    return _productQuestions
        .where((question) => question['userId']?.toString() == userId)
        .toList()
      ..sort(
        (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
          a['createdAt']?.toString() ?? '',
        ),
      );
  }

  Future<void> _persistUserCollection(String field, dynamic value) async {
    await _persistDeviceCachedField(field, value);
    try {
      await _persistUserCachedField(field, value);
      await _authService.updateUserDataField(field, value);
    } catch (e) {
      debugPrint('AppState persist warn ($field): $e');
    }
  }

  Future<void> ensureCartProductIdsResolved() async {
    await _resolveLegacyCartProductIds();
    notifyListeners();
  }

  // Adres İşlemleri
  Future<void> addDeliveryAddress(Map<String, String> address) async {
    _deliveryAddresses.add(address);
    _currentDeliveryAddress ??= address['detail'];
    notifyListeners();

    await Future.wait([
      _persistUserCollection('addresses', _deliveryAddresses),
      _persistCurrentDeliveryAddressLocal(),
    ]);
  }

  // Kart İşlemleri
  Future<void> addSavedCard(Map<String, String> card) async {
    _savedCards.insert(0, card); // En başa ekle
    notifyListeners();

    await _persistUserCollection('savedCards', _savedCards);
  }

  Future<void> updateSavedCard(int index, Map<String, String> card) async {
    if (index >= 0 && index < _savedCards.length) {
      _savedCards[index] = card;
      notifyListeners();

      await _persistUserCollection('savedCards', _savedCards);
    }
  }

  Future<void> removeSavedCard(int index) async {
    if (index >= 0 && index < _savedCards.length) {
      _savedCards.removeAt(index);
      notifyListeners();

      await _persistUserCollection('savedCards', _savedCards);
    }
  }

  Future<void> updateDeliveryAddress(
    int index,
    Map<String, String> address,
  ) async {
    if (index >= 0 && index < _deliveryAddresses.length) {
      final oldAddress = _deliveryAddresses[index];

      // Eğer güncellenen adres seçili adres ise, seçili adresi de güncelle
      if (oldAddress['detail'] == _currentDeliveryAddress) {
        _currentDeliveryAddress = address['detail'];
      }

      _deliveryAddresses[index] = address;
      notifyListeners();

      await Future.wait([
        _persistUserCollection('addresses', _deliveryAddresses),
        _persistCurrentDeliveryAddressLocal(),
      ]);
    }
  }

  Future<void> removeDeliveryAddress(int index) async {
    if (index >= 0 && index < _deliveryAddresses.length) {
      final removedAddress = _deliveryAddresses[index];
      _deliveryAddresses.removeAt(index);

      // Eğer silinen adres seçili adres ise
      if (removedAddress['detail'] == _currentDeliveryAddress) {
        if (_deliveryAddresses.isNotEmpty) {
          _currentDeliveryAddress = _deliveryAddresses.first['detail'];
        } else {
          _currentDeliveryAddress = null;
        }
      }

      notifyListeners();

      await Future.wait([
        _persistUserCollection('addresses', _deliveryAddresses),
        _persistCurrentDeliveryAddressLocal(),
      ]);
    }
  }

  void addBillingInfo(Map<String, String> info) {
    _billingInfos.add(info);
    notifyListeners();
    // Fatura bilgileri şimdilik Firestore'a kaydedilmiyor (istenirse eklenebilir)
  }

  void updateBillingInfo(int index, Map<String, String> info) {
    if (index >= 0 && index < _billingInfos.length) {
      _billingInfos[index] = info;
      notifyListeners();
    }
  }

  void removeBillingInfo(int index) {
    if (index >= 0 && index < _billingInfos.length) {
      _billingInfos.removeAt(index);
      notifyListeners();
    }
  }

  void addProductToUserList(int listId, Product product) {
    addToProductList(listId.toString(), product);
  }

  void createUserList(
    String name,
    String description, {
    ProductListVisibility visibility = ProductListVisibility.private,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final newList = ProductList(
      id: 'list_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      description: description.trim().isEmpty
          ? 'Yeni liste'
          : description.trim(),
      visibility: visibility,
      shareCode: _productListService.buildShareCode(trimmedName),
      sellerId: _cacheUserId,
      productIds: const [],
      products: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _productLists.insert(0, _decorateProductList(newList));
    notifyListeners();
    _persistProductLists();
  }

  Map<String, dynamic> _productListToLegacyMap(ProductList list) {
    final coverImage =
        list.products.isNotEmpty && list.products.first.images.isNotEmpty
        ? list.products.first.images.first
        : (list.iconUrl ?? '');
    return {
      'id': list.id,
      'name': list.name,
      'coverImage': coverImage,
      'logo': coverImage,
      'memberCount': 1,
      'visibility': list.visibility.dbValue,
      'visibilityLabel': list.visibility.label,
      'isPublic': list.isPublic,
      'shareCode': list.shareCode,
      'sellerId': list.sellerId,
      'storeName': list.storeName,
      'followerCount': list.followerCount,
      'isFollowing': list.isFollowing,
      'followNotificationsEnabled': list.followNotificationsEnabled,
      'ownerUserId': list.ownerUserId,
      'ownerDisplayName': list.ownerDisplayName,
      'ownerPhotoUrl': list.ownerPhotoUrl,
      'description': list.description?.trim().isNotEmpty == true
          ? list.description
          : '${list.productCount} ürün',
      'category': list.category,
      'subCategory': list.subCategory,
      'itemCount': list.productCount,
      'products': List<Product>.from(list.products),
      'productIds': List<String>.from(list.productIds),
      'createdAt': list.createdAt.toIso8601String(),
      'updatedAt': list.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> productListToMap(ProductList list) {
    return _productListToLegacyMap(list);
  }

  // Favori işlemleri
  bool isFavorite(Product product) {
    return _favoriteState.isFavorite(product);
  }

  void toggleFavorite(Product product) => _toggleFavoriteImpl(product);

  void _syncPushInterests() {
    final favoriteTerms = favorites.map((p) => p.name).toList();
    final cartTerms = cart.map((p) => p.name).toList();
    final savedTerms = _productLists
        .expand((list) {
          if (list.products.isNotEmpty) {
            return list.products.map((product) => product.name);
          }
          return list.productIds.map((productId) {
            final parts = productId.split('|');
            if (parts.length >= 2) {
              return parts[1].trim();
            }
            return productId;
          });
        })
        .where((term) => term.trim().isNotEmpty)
        .toList();
    PushNotificationService.instance
        .syncUserInterests(
          searchHistory: _searchHistory,
          favoriteTerms: favoriteTerms,
          cartTerms: cartTerms,
          savedListTerms: savedTerms,
        )
        .catchError((_) {});
  }

  // Sepet işlemleri
  bool isInCart(Product product) {
    return _cartState.isInCart(product);
  }

  void addToCart(Product product) => _addToCartImpl(product);

  void updateProductServices(Product product, List<String> services) {
    _cartState.updateProductServices(product, services);
    _persistCartState();
    _syncPushInterests();
  }

  void removeFromCart(Product product) => _removeFromCartImpl(product);

  void clearCart() {
    _cartState.clear();
    _cartAttentionKeys.clear();
    _cartAttentionMessage = null;
    _fastDelivery.clear();
    _persistCartState();
    _syncPushInterests();
  }

  void addFoodOrder(Map<String, dynamic> order) {
    _foodOrders.insert(0, order);
    notifyListeners();
  }

  void clearFoodOrders() {
    _foodOrders.clear();
    notifyListeners();
  }

  void removeFoodOrder(String id) {
    _foodOrders.removeWhere((o) => o['id']?.toString() == id);
    notifyListeners();
  }

  void updateFoodOrder(
    String id, {
    List<Map<String, dynamic>>? items,
    String? status,
  }) {
    final index = _foodOrders.indexWhere((o) => o['id']?.toString() == id);
    if (index == -1) return;

    final updated = Map<String, dynamic>.from(_foodOrders[index]);
    if (items != null) {
      updated['items'] = items;
    }
    if (status != null) {
      updated['status'] = status;
    }
    _foodOrders[index] = updated;
    notifyListeners();
  }

  // Hızlı teslimat işlemleri
  bool hasFastDelivery(Product product) {
    return _fastDelivery[product.hashCode] ?? false;
  }

  void setFastDelivery(Product product, bool enabled) {
    _fastDelivery[product.hashCode] = enabled;
    notifyListeners();
  }

  void toggleFastDelivery(Product product) {
    _fastDelivery[product.hashCode] = !hasFastDelivery(product);
    notifyListeners();
  }

  // Mağaza takip işlemleri (Supabase store_followers)
  bool isFollowingStore(Map<String, dynamic> store) {
    final sellerId = (store['seller_id'] ?? '').toString().trim();
    final storeId = (store['id'] ?? '').toString().trim();
    return _followedStores.any((followed) {
      final followedSellerId = (followed['seller_id'] ?? '').toString().trim();
      final followedId = (followed['id'] ?? '').toString().trim();
      if (sellerId.isNotEmpty &&
          (followedSellerId == sellerId || followedId == sellerId)) {
        return true;
      }
      if (storeId.isNotEmpty &&
          (followedId == storeId || followedSellerId == storeId)) {
        return true;
      }
      return false;
    });
  }

  Future<void> refreshFollowedStoresFromServer() async {
    if (!isLoggedIn) return;
    try {
      final rows = await StoreFollowService.instance.fetchFollowedStores();
      _followedStores
        ..clear()
        ..addAll(rows);
      followedStoresNotifier.value = List<Map<String, dynamic>>.from(
        _followedStores,
      );
      notifyListeners();
      await _persistUserCollection('followedStores', _followedStores);
    } catch (error) {
      debugPrint('AppState.refreshFollowedStoresFromServer: $error');
    }
  }

  Future<void> toggleFollowStore(Map<String, dynamic> store) async {
    if (!isLoggedIn) return;

    final storeId = await StoreFollowService.instance.resolveStoreId(
      sellerId: store['seller_id']?.toString(),
      businessName: store['name']?.toString() ?? store['business_name']?.toString(),
    );
    if (storeId == null || storeId.isEmpty) return;

    try {
      if (isFollowingStore(store)) {
        await StoreFollowService.instance.unfollowStore(storeId);
        _followedStores.removeWhere((followed) {
          final followedSellerId =
              (followed['seller_id'] ?? '').toString().trim();
          return followedSellerId == storeId ||
              (followed['id'] ?? '').toString().trim() == storeId;
        });
      } else {
        await StoreFollowService.instance.followStore(storeId);
        await refreshFollowedStoresFromServer();
        return;
      }

      followedStoresNotifier.value = List.from(_followedStores);
      notifyListeners();
      await _persistUserCollection('followedStores', _followedStores);
    } catch (error) {
      debugPrint('AppState.toggleFollowStore: $error');
    }
  }

  List<Map<String, dynamic>> getProductReviewsFor({
    required String productName,
    String? storeName,
  }) {
    return _reviewState.getProductReviewsFor(
      productName: productName,
      storeName: storeName,
    );
  }

  List<Map<String, dynamic>> getProductReviewsForStore({
    required String storeName,
  }) {
    return _reviewState.getProductReviewsForStore(storeName: storeName);
  }

  List<Map<String, dynamic>> getSellerReviewsFor({
    String? sellerId,
    String? storeName,
  }) {
    return _reviewState.getSellerReviewsFor(
      sellerId: sellerId,
      storeName: storeName,
    );
  }

  ProductRatingSummary getProductRatingSummary({
    required String productName,
    String? storeName,
    double fallbackRating = 0,
    int fallbackReviewCount = 0,
  }) {
    return _reviewState.getProductRatingSummary(
      productName: productName,
      storeName: storeName,
      fallbackRating: fallbackRating,
      fallbackReviewCount: fallbackReviewCount,
    );
  }

  List<Map<String, dynamic>> getProductQuestionsFor({
    required String productName,
    String? storeName,
  }) {
    final normalizedProduct = _normalizeReviewKey(productName);
    final normalizedStore = _normalizeReviewKey(storeName ?? '');
    return _productQuestions.where((question) {
      final qProduct = _normalizeReviewKey(
        question['productName']?.toString() ?? '',
      );
      final qStore = _normalizeReviewKey(
        question['storeName']?.toString() ?? '',
      );
      if (qProduct != normalizedProduct) return false;
      if (normalizedStore.isEmpty) return true;
      return qStore == normalizedStore;
    }).toList()..sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
  }

  List<Map<String, dynamic>> getSellerProductQuestions({
    String? sellerId,
    String? storeName,
    bool unansweredOnly = false,
  }) {
    final normalizedSellerId = (sellerId ?? '').trim();
    final normalizedStore = _normalizeReviewKey(storeName ?? '');
    return _productQuestions.where((question) {
      final qSellerId = question['sellerId']?.toString().trim() ?? '';
      final qStore = _normalizeReviewKey(
        question['storeName']?.toString() ?? '',
      );
      final matchesSeller =
          normalizedSellerId.isNotEmpty && qSellerId == normalizedSellerId;
      final matchesStore =
          normalizedStore.isNotEmpty && qStore == normalizedStore;
      if (!matchesSeller && !matchesStore) return false;
      if (!unansweredOnly) return true;
      return (question['answer']?.toString().trim().isEmpty ?? true);
    }).toList()..sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
  }

  Future<void> addProductReview({
    required String productName,
    required String storeName,
    required String sellerId,
    required String productImageUrl,
    required String productCode,
    required double rating,
    required String comment,
    required List<String> imageUrls,
  }) async {
    final userId = _currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('Yorum yapmak için giriş yapmanız gerekiyor.');
    }
    await _reviewState.addProductReview(
      productName: productName,
      storeName: storeName,
      sellerId: sellerId,
      productImageUrl: productImageUrl,
      productCode: productCode,
      rating: rating,
      comment: comment,
      imageUrls: imageUrls,
      userId: userId,
      userName: _maskedDisplayName(),
    );
  }

  Future<void> addSellerReview({
    required String storeName,
    required String sellerId,
    required double rating,
    required String comment,
    required List<String> imageUrls,
  }) async {
    final userId = _currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('Yorum yapmak için giriş yapmanız gerekiyor.');
    }
    await _reviewState.addSellerReview(
      storeName: storeName,
      sellerId: sellerId,
      rating: rating,
      comment: comment,
      imageUrls: imageUrls,
      userId: userId,
      userName: _maskedDisplayName(),
    );
  }

  Future<void> addProductQuestion({
    required String productName,
    required String storeName,
    required String sellerId,
    required String productImageUrl,
    required String question,
  }) async {
    _productQuestions.insert(0, {
      'id': 'pq_${DateTime.now().millisecondsSinceEpoch}',
      'userId': _currentUser?['uid']?.toString(),
      'userName': _maskedDisplayName(),
      'productName': productName,
      'storeName': storeName,
      'sellerId': sellerId,
      'productImageUrl': productImageUrl,
      'question': question.trim(),
      'answer': '',
      'likes': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'answeredAt': null,
    });
    notifyListeners();
    await _persistProductQuestions();
  }

  Future<void> answerProductQuestion({
    required String questionId,
    required String answer,
  }) async {
    final index = _productQuestions.indexWhere(
      (question) => question['id']?.toString() == questionId,
    );
    if (index == -1) return;
    final updated = Map<String, dynamic>.from(_productQuestions[index]);
    updated['answer'] = answer.trim();
    updated['answeredAt'] = DateTime.now().toIso8601String();
    _productQuestions[index] = updated;
    notifyListeners();
    await _persistProductQuestions();
  }
}
