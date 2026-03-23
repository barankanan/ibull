import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
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

  void addToCart(Product product) {
    if (!isInCart(product)) {
      _cart.add(product);
      _updateCartNotifiers();
    } else {
      // If already in cart, update it (e.g. for services)
      int index = _cart.indexWhere((p) => p.name == product.name && p.brand == product.brand);
      if (index != -1) {
        // Merge services if needed, or just replace
        _cart[index] = product;
        _updateCartNotifiers();
      }
    }
    // Firestore'a kaydet
    _authService.updateUserDataField('cart', _cart.map((p) => p.toJson()).toList());
  }

  void updateProductServices(Product product, List<String> services) {
    int index = _cart.indexWhere((p) => p.name == product.name && p.brand == product.brand);
    if (index != -1) {
      _cart[index] = _cart[index].copyWith(selectedServices: services);
      _updateCartNotifiers();
      
      // Firestore'a kaydet
      _authService.updateUserDataField('cart', _cart.map((p) => p.toJson()).toList());
    }
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((p) => p.name == product.name && p.brand == product.brand);
    _updateCartNotifiers();
    
    // Firestore'a kaydet
    _authService.updateUserDataField('cart', _cart.map((p) => p.toJson()).toList());
  }

  void clearCart() {
    _cart.clear();
    _fastDelivery.clear();
    _updateCartNotifiers();
    
    // Firestore'a kaydet
    _authService.updateUserDataField('cart', []);
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
