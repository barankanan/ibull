import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

/// Global uygulama state'i - favoriler ve sepet
/// Provider pattern ile yönetilmektedir.
class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // Favorilere eklenen ürünler
  final List<Product> _favorites = [];
  
  // Sepete eklenen ürünler
  final List<Product> _cart = [];
  
  // Takip edilen mağazalar
  final List<Map<String, dynamic>> _followedStores = [];

  // Kullanıcının oluşturduğu listeler
  final List<Map<String, dynamic>> _userLists = [
    {
      'id': 1,
      'name': 'Elektronik Ürünleri',
      'coverImage': 'assets/products/iphone15_mavi_256gb.png',
      'logo': 'assets/products/iphone15_mavi_256gb.png',
      'memberCount': 1245,
      'description': 'En yeni teknoloji ürünleri ve akıllı cihazlar',
      'itemCount': 5,
      'products': [
        Product(
          name: 'iPhone 15 Pro Max',
          brand: 'Apple',
          price: '54.999 TL',
          rating: 4.8,
          reviewCount: 1245,
          tags: const ['Ücretsiz Kargo', 'Yeni Sezon'],
          images: const ['assets/products/iphone15_mavi_256gb.png'],
          store: 'Apple Store',
          category: 'Elektronik',
          subCategory: 'Telefon',
        ),
        Product(
          name: 'MacBook Pro M3',
          brand: 'Apple',
          price: '84.999 TL',
          rating: 4.9,
          reviewCount: 856,
          tags: const ['Ücretsiz Kargo', 'Önerilen'],
          images: const ['assets/products/macbook_pro_m3_space_black.jpg'],
          store: 'Apple Store',
          category: 'Elektronik',
          subCategory: 'Bilgisayar',
        ),
        Product(
          name: 'Samsung Galaxy S24 Ultra',
          brand: 'Samsung',
          price: '49.999 TL',
          rating: 4.7,
          reviewCount: 923,
          tags: const ['Kısıtlı Stok', 'Önerilen'],
          images: const ['assets/products/s24_siyah_512gb.png'],
          store: 'Samsung Store',
          category: 'Elektronik',
          subCategory: 'Telefon',
        ),
        Product(
          name: 'Sony WH-1000XM5',
          brand: 'Sony',
          price: '12.499 TL',
          rating: 4.8,
          reviewCount: 645,
          tags: const ['Yeni Sezon', 'Önerilen'],
          images: const ['assets/products/sony_xm5.jpg'],
          store: 'Teknosa',
          category: 'Elektronik',
          subCategory: 'Ses Sistemi',
        ),
        Product(
          name: 'Canon EOS R6 Mark II',
          brand: 'Canon',
          price: '89.999 TL',
          rating: 4.9,
          reviewCount: 234,
          tags: const ['Profesyonel', 'Yeni'],
          images: const ['assets/products/canon_r6.jpeg'],
          store: 'Canon',
          category: 'Elektronik',
          subCategory: 'Kamera',
        ),
      ],
    },
    {
      'id': 2,
      'name': 'Kişisel Bakım Ürünleri',
      'coverImage': 'assets/products/Urban Care Biotin & Kafein Tonik.jpeg',
      'logo': 'assets/products/Urban Care Biotin & Kafein Tonik.jpeg',
      'memberCount': 892,
      'description': 'Saç bakımı ve kişisel bakım ürünleri',
      'itemCount': 3,
      'products': [
        Product(
          name: 'Urban Care Biotin & Kafein Tonik',
          brand: 'Urban Care',
          price: '159,90 TL',
          rating: 4.6,
          reviewCount: 789,
          tags: const ['Doğal İçerik', 'Önerilen'],
          images: const ['assets/products/Urban Care Biotin & Kafein Tonik.jpeg'],
          store: 'Rossmann',
          category: 'Kişisel Bakım',
          subCategory: 'Saç Bakımı',
        ),
        Product(
          name: 'Urban Care Argan Oil Şampuan',
          brand: 'Urban Care',
          price: '129,90 TL',
          rating: 4.5,
          reviewCount: 654,
          tags: const ['Argan Yağı', 'Doğal'],
          images: const ['assets/products/Urban Care Argan Oil Şampuan.jpeg'],
          store: 'Rossmann',
          category: 'Kişisel Bakım',
          subCategory: 'Saç Bakımı',
        ),
        Product(
          name: 'Dior Sauvage EDT',
          brand: 'Dior',
          price: '3.499 TL',
          rating: 4.9,
          reviewCount: 1523,
          tags: const ['Lüks', 'Erkek Parfümü'],
          images: const ['assets/products/Dior Sauvage EDT.jpeg'],
          store: 'Sephora',
          category: 'Kişisel Bakım',
          subCategory: 'Parfüm',
        ),
      ],
    },
    {
      'id': 3,
      'name': 'Ev & Yaşam',
      'coverImage': 'assets/products/Nutella 750g.jpeg',
      'logo': 'assets/products/Nutella 750g.jpeg',
      'memberCount': 567,
      'description': 'Ev dekorasyon, kitap ve gıda ürünleri',
      'itemCount': 3,
      'products': [
        Product(
          name: 'Ikea Billy Kitaplık',
          brand: 'Ikea',
          price: '2.499 TL',
          rating: 4.7,
          reviewCount: 432,
          tags: const ['Modern', 'Pratik'],
          images: const ['assets/products/Ikea Billy Kitaplık.jpeg'],
          store: 'Ikea',
          category: 'Ev & Yaşam',
          subCategory: 'Mobilya',
        ),
        Product(
          name: 'Haruki Murakami 1Q84',
          brand: 'Can Yayınları',
          price: '285 TL',
          rating: 4.8,
          reviewCount: 1876,
          tags: const ['Bestseller', 'Klasik'],
          images: const ['assets/products/Haruki Murakami 1Q84.jpeg'],
          store: 'D&R',
          category: 'Kitap & Medya',
          subCategory: 'Roman',
        ),
        Product(
          name: 'Nutella 750g',
          brand: 'Ferrero',
          price: '189,90 TL',
          rating: 4.9,
          reviewCount: 2341,
          tags: const ['Hızlı Kargo', 'İndirimli'],
          images: const ['assets/products/Nutella 750g.jpeg'],
          store: 'Migros',
          category: 'Süpermarket',
          subCategory: 'Gıda',
        ),
      ],
    },
  ];
  
  // Hızlı teslimat seçenekleri (product hashCode -> bool)
  final Map<int, bool> _fastDelivery = {};

  // Dinleyiciler için notifier (Geriye uyumluluk için tutuluyor)
  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> followedStoresNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

  List<Product> get favorites => List.unmodifiable(_favorites);
  List<Product> get cart => List.unmodifiable(_cart);
  List<Map<String, dynamic>> get followedStores => List.unmodifiable(_followedStores);
  List<Map<String, dynamic>> get userLists => List.unmodifiable(_userLists);

  void addProductToUserList(int listId, Product product) {
    final index = _userLists.indexWhere((list) => list['id'] == listId);
    if (index != -1) {
      final list = Map<String, dynamic>.from(_userLists[index]);
      final products = List<Product>.from(list['products'] ?? []);
      
      // Check if product already exists in the list
      if (!products.any((p) => p.name == product.name)) {
        products.add(product);
        list['products'] = products;
        list['itemCount'] = products.length;
        
        // Update list in the main list
        _userLists[index] = list;
        notifyListeners();
      }
    }
  }

  void createUserList(String name, String description) {
    _userLists.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': name,
      'coverImage': 'assets/products/iphone15_mavi_256gb.png', // Default image
      'logo': 'assets/products/iphone15_mavi_256gb.png', // Default logo
      'memberCount': 1,
      'description': description.isEmpty ? 'Yeni liste' : description,
      'itemCount': 0,
      'products': <Product>[],
    });
    notifyListeners();
  }

  // Favori işlemleri
  bool isFavorite(Product product) {
    return _favorites.any((p) => p.name == product.name && p.brand == product.brand);
  }

  void toggleFavorite(Product product) {
    if (isFavorite(product)) {
      _favorites.removeWhere((p) => p.name == product.name && p.brand == product.brand);
    } else {
      _favorites.add(product);
    }
    notifyListeners();
  }

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
  }

  void updateProductServices(Product product, List<String> services) {
    int index = _cart.indexWhere((p) => p.name == product.name && p.brand == product.brand);
    if (index != -1) {
      _cart[index] = _cart[index].copyWith(selectedServices: services);
      _updateCartNotifiers();
    }
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((p) => p.name == product.name && p.brand == product.brand);
    _updateCartNotifiers();
  }

  void clearCart() {
    _cart.clear();
    _fastDelivery.clear();
    _updateCartNotifiers();
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
  
  // Mağaza takip işlemleri
  bool isFollowingStore(Map<String, dynamic> store) {
    return _followedStores.any((s) => s['id'] == store['id']);
  }
  
  void toggleFollowStore(Map<String, dynamic> store) {
    if (isFollowingStore(store)) {
      _followedStores.removeWhere((s) => s['id'] == store['id']);
    } else {
      _followedStores.add(store);
    }
    followedStoresNotifier.value = List.from(_followedStores);
    notifyListeners();
  }
}
