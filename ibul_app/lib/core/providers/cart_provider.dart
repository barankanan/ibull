import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';
import '../app_state.dart';

class CartProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AppState _appState = AppState();
  
  // Sepete eklenen ürünler
  final List<Product> _cart = [];
  List<Product> get cart => List.unmodifiable(_cart);
  
  // Hızlı teslimat seçenekleri (product hashCode -> bool)
  final Map<int, bool> _fastDelivery = {};
  
  // Sepet sayısı için notifier (AppState ile uyumluluk için)
  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  // Sepet işlemleri
  bool isInCart(Product product) {
    return _cart.any((p) => p.name == product.name && p.brand == product.brand);
  }

  Future<String?> addToCart(Product product) async {
    final error = await _appState.addToCart(product);
    if (error != null) {
      return error;
    }

    if (!isInCart(product)) {
      _cart.add(product);
      _updateCartNotifiers();
    } else {
      final index = _cart.indexWhere(
        (p) => p.name == product.name && p.brand == product.brand,
      );
      if (index != -1) {
        _cart[index] = product;
        _updateCartNotifiers();
      }
    }
    unawaited(
      _authService.updateUserDataField(
        'cart',
        _cart.map((p) => p.toJson()).toList(),
      ),
    );
    return null;
  }

  void updateProductServices(Product product, List<String> services) {
    int index = _cart.indexWhere((p) => p.name == product.name && p.brand == product.brand);
    if (index != -1) {
      _cart[index] = _cart[index].copyWith(selectedServices: services);
      _updateCartNotifiers();
      
      // Firestore'a kaydet
      _authService.updateUserDataField('cart', _cart.map((p) => p.toJson()).toList());
      _appState.updateProductServices(product, services);
    }
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((p) => p.name == product.name && p.brand == product.brand);
    _updateCartNotifiers();
    
    // Firestore'a kaydet
    _authService.updateUserDataField('cart', _cart.map((p) => p.toJson()).toList());
    _appState.removeFromCart(product);
  }

  void clearCart() {
    _cart.clear();
    _fastDelivery.clear();
    _updateCartNotifiers();
    
    // Firestore'a kaydet
    _authService.updateUserDataField('cart', []);
    _appState.clearCart();
  }

  void _updateCartNotifiers() {
    cartCountNotifier.value = _cart.length;
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
}
