import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  Product product() => Product(
        name: 'Notify Slice Product',
        brand: 'iBul',
        price: '10',
        productId: 'notify-slice-1',
        rating: 0,
        reviewCount: 0,
        tags: const <String>[],
        images: const <String>[],
      );

  test('AppState no longer forwards cart, favorite, or review listeners', () {
    final source = File('lib/core/app_state.dart').readAsStringSync();
    expect(source, contains('_cartState.addListener(_handleCartStateChanged)'));
    expect(
      source,
      isNot(contains('_favoriteState.addListener(notifyListeners)')),
    );
    expect(
      source,
      isNot(contains('_reviewState.addListener(notifyListeners)')),
    );
    expect(
      source,
      isNot(contains('cartCountNotifier.value = _cartState.cart.length;\n    notifyListeners();')),
    );
  });

  test('cart and favorite mutations notify feature states, not AppState',
      () async {
    final app = AppState();
    final cart = CartState();
    final favorites = FavoriteState();

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    cart.clear();
    favorites.clear();
    await Future<void>.delayed(Duration.zero);

    var appTicks = 0;
    var cartTicks = 0;
    var favoriteTicks = 0;
    void onApp() => appTicks++;
    void onCart() => cartTicks++;
    void onFav() => favoriteTicks++;
    app.addListener(onApp);
    cart.addListener(onCart);
    favorites.addListener(onFav);
    addTearDown(() {
      app.removeListener(onApp);
      cart.removeListener(onCart);
      favorites.removeListener(onFav);
    });

    final item = product();
    app.toggleFavorite(item);
    await Future<void>.delayed(Duration.zero);
    expect(favoriteTicks, greaterThan(0));
    expect(appTicks, 0);
    expect(favorites.isFavorite(item), isTrue);

    final beforeBadge = app.cartCountNotifier.value;
    cart.addOrReplace(item);
    await Future<void>.delayed(Duration.zero);
    expect(cartTicks, greaterThan(0));
    expect(appTicks, 0);
    expect(app.cartCountNotifier.value, beforeBadge + 1);
    expect(cart.isInCart(item), isTrue);

    app.toggleFavorite(item);
    cart.remove(item);
    await Future<void>.delayed(Duration.zero);
    expect(favorites.isFavorite(item), isFalse);
    expect(cart.isInCart(item), isFalse);
    expect(app.cartCountNotifier.value, beforeBadge);
    expect(appTicks, 0);
  });
}
