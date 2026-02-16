import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/constants.dart';
import '../core/app_state.dart';
import 'checkout_page.dart';
import 'product_detail_page.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppState _appState = AppState();
  final Map<int, bool> _dynamicSelections = {};
  final Map<int, int> _dynamicQuantities = {};
  final ScrollController _couponScrollController = ScrollController();
  
  // Kupon değişkenleri
  final Map<int, Map<String, dynamic>> _appliedCoupons = {};
  
  final List<Map<String, dynamic>> _availableCoupons = [
    {
      'id': 'c1',
      'code': 'YAZ20',
      'title': 'Yaz Fırsatı',
      'description': '20 TL İndirim',
      'discountAmount': 20.0,
      'isPercentage': false,
      'minPrice': 100.0,
      'color': Colors.orange.shade100,
      'iconColor': Colors.orange,
    },
    {
      'id': 'c2',
      'code': 'TEKNO10',
      'title': 'Teknoloji',
      'description': '%10 İndirim',
      'discountAmount': 10.0,
      'isPercentage': true,
      'minPrice': 500.0,
      'color': Colors.blue.shade100,
      'iconColor': Colors.blue,
    },
    {
      'id': 'c3',
      'code': 'HOSGELDIN',
      'title': 'Hoş Geldin',
      'description': '50 TL İndirim',
      'discountAmount': 50.0,
      'isPercentage': false,
      'minPrice': 250.0,
      'color': Colors.purple.shade100,
      'iconColor': Colors.purple,
    },
    {
      'id': 'c4',
      'code': 'KARGO',
      'title': 'Bedava Kargo',
      'description': 'Kargo Bedava',
      'discountAmount': 20.0, // Assuming kargo is approx 20
      'isPercentage': false,
      'minPrice': 50.0,
      'color': Colors.green.shade100,
      'iconColor': Colors.green,
    },
    {
      'id': 'c5',
      'code': 'BAHAR',
      'title': 'Bahar İndirimi',
      'description': '%5 İndirim',
      'discountAmount': 5.0,
      'isPercentage': true,
      'minPrice': 150.0,
      'color': Colors.pink.shade100,
      'iconColor': Colors.pink,
    },
  ];

  void _showCouponBottomSheet(int productHashCode, double productPrice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kuponlarım',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kazanılan kuponları seçerek indirim sağlayabilirsiniz.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: _availableCoupons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final coupon = _availableCoupons[index];
                        final bool isApplied = _appliedCoupons[productHashCode]?['id'] == coupon['id'];
                        final bool isApplicable = productPrice >= (coupon['minPrice'] as double);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isApplied ? AppColors.primary : Colors.grey.shade200,
                              width: isApplied ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: coupon['color'],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.local_offer,
                                  color: coupon['iconColor'],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coupon['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      coupon['description'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Min. Sepet Tutarı: ${coupon['minPrice']} TL',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: isApplicable
                                    ? () {
                                        setState(() {
                                          if (isApplied) {
                                            _appliedCoupons.remove(productHashCode);
                                          } else {
                                            _appliedCoupons[productHashCode] = coupon;
                                          }
                                        });
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isApplied 
                                              ? 'Kupon kaldırıldı' 
                                              : '${coupon['title']} uygulandı'),
                                            backgroundColor: isApplied ? Colors.grey : AppColors.primary,
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isApplied ? Colors.grey : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Text(isApplied ? 'Kaldır' : 'Uygula'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Sepetteki ürünler
  List<Map<String, dynamic>> get cartItems {
    // Sepette olmayan ürünlerin seçim bilgilerini temizle
    final cartHashes = _appState.cart.map((product) => product.hashCode).toSet();
    _dynamicSelections.removeWhere((key, value) => !cartHashes.contains(key));
    _dynamicQuantities.removeWhere((key, value) => !cartHashes.contains(key));

    return _appState.cart.map((product) {
      // Fiyatı düzgün parse et
      double productPrice = 0.0;
      try {
        String priceStr = product.price
            .replaceAll('₺', '')
            .replaceAll('TL', '')
            .replaceAll('.', '')
            .replaceAll(',', '.')
            .replaceAll(' ', '')
            .trim();
        productPrice = double.parse(priceStr);
      } catch (e) {
        productPrice = 0.0;
      }

      // Ürün özelliklerini tags'den çıkar
      String? color;
      String? storage;
      String? watt;
      String? shippingInfo;
      String? feature;
      String? firstSpec; // İlk özellik
      
      // Ürün özelliğini belirle (Ürün Özellikleri butonundaki ilk satır)
      if (product.brand.contains('Uf') || product.name.contains('CT-23')) {
        firstSpec = 'Güç: 2300W';
      } else if (product.brand.contains('Haylou') || product.name.contains('Solar')) {
        firstSpec = 'Ekran: 1.43" AMOLED';
      } else if (product.brand.contains('Apple') || product.name.contains('iPhone')) {
        firstSpec = 'Ekran: 6.1" Super Retina XDR';
      }
      
      for (var tag in product.tags) {
        if (tag.contains('Renk') || tag.toLowerCase().contains('siyah') || 
            tag.toLowerCase().contains('beyaz') || tag.toLowerCase().contains('kırmızı') ||
            tag.toLowerCase().contains('mavi') || tag.toLowerCase().contains('yeşil')) {
          color = tag;
        } else if (tag.contains('GB') || tag.contains('gb') || tag.contains('Gb')) {
          storage = tag;
        } else if (tag.contains('W') || tag.contains('w') || tag.toLowerCase().contains('watt')) {
          watt = tag;
        } else if (tag.toLowerCase().contains('kargo')) {
          shippingInfo = tag;
        } else if (tag.toLowerCase().contains('dijital')) {
          feature = tag;
        }
      }
      
      // Eğer kargo bilgisi yoksa ve özellik yoksa, ilk tag'i kullan
      if (shippingInfo == null && feature == null && product.tags.isNotEmpty) {
        for (var tag in product.tags) {
          if (!tag.contains('%') && !tag.toLowerCase().contains('indirim') && !tag.toLowerCase().contains('kupon')) {
            feature = tag;
            break;
          }
        }
      }

      final int quantity = _dynamicQuantities[product.hashCode] ?? 1;

      // Hızlı kargo bilgisini services listesine ekle
      List<String> displayServices = List.from(product.selectedServices);
      if (_appState.hasFastDelivery(product)) {
        displayServices.add('Hızlı Kargo');
      }

      return {
        'storeName': product.brand,
        'storeRating': product.rating.toString(),
        'deliveryType': '8 Ağustos\'ta Kargoda!',
        'deliveryIcon': Icons.local_shipping,
        'products': [
          {
            'id': product.hashCode,
            'productKey': product.hashCode,
            'name': product.name,
            'price': productPrice,
            'quantity': quantity,
            'hasDiscount': product.tags.any((tag) => tag.toLowerCase().contains('indirim') || tag.toLowerCase().contains('kupon')) ||
                           _availableCoupons.any((c) => productPrice >= (c['minPrice'] as double)),
            'discountText': _appliedCoupons.containsKey(product.hashCode) 
                ? _appliedCoupons[product.hashCode]!['code'] 
                : (product.tags.any((tag) => tag.toLowerCase().contains('indirim') || tag.toLowerCase().contains('kupon')) ? 'Kupon Gör' : 'Kupon Var'),
            'appliedCoupon': _appliedCoupons[product.hashCode],
            'discount': product.tags.firstWhere((tag) => tag.contains('%'), orElse: () => '').isNotEmpty 
                ? product.tags.firstWhere((tag) => tag.contains('%')) 
                : null,
            'image': product.images.isNotEmpty ? product.images[0] : null,
            'isSelected': _dynamicSelections[product.hashCode] ?? false,
            'color': color,
            'storage': storage,
            'watt': watt,
            'shippingInfo': shippingInfo,
            'feature': feature,
            'firstSpec': firstSpec,
            'productObject': product, // Ürün sayfasına gitmek için
            'isDynamic': true,
            'services': displayServices,
          }
        ]
      };
    }).toList();
  }

  // Market ürünleri
  final List<Map<String, dynamic>> marketItems = [];

  // Yemek ürünleri
  final List<Map<String, dynamic>> foodItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _couponScrollController.dispose();
    super.dispose();
  }

  void _toggleProductSelection(List<Map<String, dynamic>> items, int storeIndex, int productIndex) {
    final Map<String, dynamic> productMap =
        items[storeIndex]['products'][productIndex] as Map<String, dynamic>;
    final bool current = productMap['isSelected'] == true;
    final bool updated = !current;
    
    if (current == updated) return; // No change needed
    
    setState(() {
      productMap['isSelected'] = updated;

      if (productMap['isDynamic'] == true && productMap['productKey'] is int) {
        _dynamicSelections[productMap['productKey'] as int] = updated;
      }
    });
  }

  void _updateQuantity(List<Map<String, dynamic>> items, int storeIndex, int productIndex, int change) {
    setState(() {
      int currentQuantity = items[storeIndex]['products'][productIndex]['quantity'];
      int newQuantity = currentQuantity + change;
      if (newQuantity > 0) {
        items[storeIndex]['products'][productIndex]['quantity'] = newQuantity;
        final Map<String, dynamic> productMap =
            items[storeIndex]['products'][productIndex] as Map<String, dynamic>;
        if (productMap['isDynamic'] == true && productMap['productKey'] is int) {
          _dynamicQuantities[productMap['productKey'] as int] = newQuantity;
        }
      }
    });
  }

  void _deleteProduct(List<Map<String, dynamic>> items, int storeIndex, int productIndex) {
    setState(() {
      final Map<String, dynamic> productMap =
          items[storeIndex]['products'][productIndex] as Map<String, dynamic>;
      if (productMap['isDynamic'] == true && productMap['productKey'] is int) {
        _dynamicSelections.remove(productMap['productKey'] as int);
        _dynamicQuantities.remove(productMap['productKey'] as int);
        if (productMap['productObject'] != null) {
          _appState.removeFromCart(productMap['productObject']);
        }
      }
      items[storeIndex]['products'].removeAt(productIndex);
      if (items[storeIndex]['products'].isEmpty) {
        items.removeAt(storeIndex);
      }
    });
  }

  void _clearCart() {
    setState(() {
      _dynamicSelections.clear();
      _dynamicQuantities.clear();
      _appState.clearCart();
    });
  }

  void _showDeliveryInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.electric_bike, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Kurye Dağıtım',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Kurye dağıtım sizin lokasyonunuza yakın ürünleri siz gitmeden size hızlı ve güvenli şekilde getirmeyi amaçlayan bir İHİZ projesidir.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Siz sipariş verdikten sonra bizimle anlaşmalı kuryeler sizin ürününüzü mağazadan teslim alarak saater içinde size teslim etmekle yükümlüdür , bütün operasyon sürecini İZLE bölümünden takip edebilir, Ürünüzün durumunu ve yerini görebilirsiniz',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'İADE durumunda ürünü inceleyip aynı gün iade edebilirsiniz',
              style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ücretlendirme',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yol mesafesine bağlıdır, KM başına 5TL kuryenin ihlalsizlik yaptığını düşünüyorsanız lütfen şikayete ediniz',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'İADELER ücretlendirmeli olabilir',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get totalItems {
    int count = _appState.cart.length;
    for (var store in marketItems) {
      for (var product in store['products']) {
        count += product['quantity'] as int;
      }
    }
    for (var store in foodItems) {
      for (var product in store['products']) {
        count += product['quantity'] as int;
      }
    }
    return count;
  }

  double get totalPrice {
    double total = 0;
    for (var store in cartItems) {
      for (var product in store['products']) {
        if (product['isSelected'] == true) {
          double itemTotal = (product['price'] as double) * (product['quantity'] as int);
          
          // Kupon indirimi uygula
          if (product['appliedCoupon'] != null) {
            final coupon = product['appliedCoupon'];
            if (coupon['isPercentage'] == true) {
              itemTotal -= itemTotal * (coupon['discountAmount'] / 100);
            } else {
              itemTotal -= coupon['discountAmount'];
            }
          }
          
          total += itemTotal > 0 ? itemTotal : 0;
        }
      }
    }
    for (var store in marketItems) {
      for (var product in store['products']) {
        if (product['isSelected'] == true) {
          total += (product['price'] as double) * (product['quantity'] as int);
        }
      }
    }
    for (var store in foodItems) {
      for (var product in store['products']) {
        if (product['isSelected'] == true) {
          total += (product['price'] as double) * (product['quantity'] as int);
        }
      }
    }
    return total;
  }

  List<Map<String, dynamic>> get selectedProducts {
    List<Map<String, dynamic>> products = [];
    for (var store in cartItems) {
      for (var product in store['products']) {
        if (product['isSelected'] == true) {
          products.add(product);
        }
      }
    }
    for (var store in marketItems) {
      for (var product in store['products']) {
        if (product['isSelected'] == true) {
          products.add(product);
        }
      }
    }
    for (var store in foodItems) {
      for (var product in store['products']) {
        if (product['isSelected'] == true) {
          products.add(product);
        }
      }
    }
    return products;
  }

  // Fiyat formatı: 1.234,56 TL veya 1.234 TL
  String _formatPrice(double price) {
    String priceStr = price.toStringAsFixed(2);
    List<String> parts = priceStr.split('.');
    String wholePart = parts[0];
    String decimalPart = parts[1];
    
    // Binlik ayracı olarak nokta ekle
    final buffer = StringBuffer();
    for (int i = 0; i < wholePart.length; i++) {
      if (i > 0 && (wholePart.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(wholePart[i]);
    }
    
    // Kuruş kısmı 00 ise gösterme
    if (decimalPart == "00") {
      return '${buffer.toString()} TL';
    } else {
      return '${buffer.toString()},$decimalPart TL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 900;
    
    if (isWeb) {
      return _buildWebView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: _buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Alışveriş Sepetim ($totalItems Ürün)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (_appState.cart.isNotEmpty)
                TextButton(
                  onPressed: _clearCart,
                  child: const Text(
                    'Sepeti Boşalt',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.primary,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            tabs: [
              Container(
                height: 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Tab(text: 'Alışveriş'),
              ),
              Container(
                height: 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Tab(text: 'Market'),
              ),
              Container(
                height: 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Tab(text: 'Yemek'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildShoppingCart(),
              _buildMarketCart(),
              _buildFoodCart(),
            ],
          ),
        ),
        // Bottom Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Toplam',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _formatPrice(totalPrice),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text(
                      'Kargo Bedava',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CheckoutPage(
                      totalPrice: totalPrice,
                      selectedProducts: selectedProducts,
                    )),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Sepeti Onayla',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShoppingCart() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final store = cartItems[index];
        return _buildStoreCard(store, cartItems, index, 'shopping');
      },
    );
  }

  Widget _buildMarketCart() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: marketItems.length,
      itemBuilder: (context, index) {
        final store = marketItems[index];
        return _buildStoreCard(store, marketItems, index, 'market');
      },
    );
  }

  Widget _buildFoodCart() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: foodItems.length,
      itemBuilder: (context, index) {
        final store = foodItems[index];
        return _buildStoreCard(store, foodItems, index, 'food');
      },
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store, List<Map<String, dynamic>> items, int storeIndex, String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          // Store Header
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Store Name
                Text(
                  store['storeName'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                // Rating Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Text(
                    store['storeRating'],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                // Delivery Info
                Icon(
                  store['deliveryIcon'],
                  color: AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  store['deliveryType'],
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showDeliveryInfo(context),
                  child: const Icon(Icons.info_outline, size: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Products
          ...store['products'].asMap().entries.map<Widget>((entry) {
            int productIndex = entry.key;
            var product = entry.value;
            return _buildProductCard(product, items, storeIndex, productIndex);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, List<Map<String, dynamic>> items, int storeIndex, int productIndex) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => _toggleProductSelection(items, storeIndex, productIndex),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: product['isSelected'] ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: product['isSelected'] ? AppColors.primary : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: product['isSelected']
                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Product Image (Tall) - Tıklanabilir
          GestureDetector(
            onTap: () {
              if (product['productObject'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailPage(product: product['productObject']),
                  ),
                );
              }
            },
            child: Container(
              width: 60,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product['image'] != null && product['image'].toString().isNotEmpty
                    ? (product['image'].toString().startsWith('http')
                        ? Image.network(
                            product['image'],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 30),
                              );
                            },
                          )
                        : Image.asset(
                            product['image'],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 30),
                              );
                            },
                          ))
                    : const Center(
                        child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 30),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand & Name - Tıklanabilir
                GestureDetector(
                  onTap: () {
                    if (product['productObject'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailPage(product: product['productObject']),
                        ),
                      );
                    }
                  },
                  child: Text(
                    '${product['name'].split(' ')[0]}  ${product['name']}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // İlk özellik (Ürün Özellikleri'nden)
                if (product['firstSpec'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    product['firstSpec'],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ],
                if (product['description'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product['description'],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                // Attributes
                Row(
                  children: [
                    if (product['color'] != null) ...[
                      Text(
                        'Renk : ',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      Text(
                        product['color'],
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (product['watt'] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Watt : ',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      Text(
                        product['watt'],
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (product['storage'] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Depolama : ',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      Text(
                        product['storage'],
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (product['size'] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Beden : ',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      Text(
                        product['size'],
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Price, Delete, Coupon, Quantity
                Row(
                  children: [
                    if (product['appliedCoupon'] != null) ...[
                      Text(
                        _formatPrice(product['price']),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Builder(
                        builder: (context) {
                          double price = product['price'];
                          final coupon = product['appliedCoupon'];
                          if (coupon['isPercentage'] == true) {
                            price -= price * (coupon['discountAmount'] / 100);
                          } else {
                            price -= coupon['discountAmount'];
                          }
                          return Text(
                            _formatPrice(price),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          );
                        }
                      ),
                    ] else
                      Text(
                        _formatPrice(product['price']),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Delete Button
                    InkWell(
                      onTap: () => _deleteProduct(items, storeIndex, productIndex),
                      child: Icon(Icons.delete_outline, color: Colors.grey.shade600, size: 16),
                    ),
                  ],
                ),
                // Kargo veya özellik bilgisi
                if (product['shippingInfo'] != null || product['feature'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          product['shippingInfo'] != null ? Icons.local_shipping : Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product['shippingInfo'] ?? product['feature'] ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // Discount Badge
                if (product['discount'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer, color: Colors.red.shade300, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          product['discount'],
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Services (e.g. Warranty)
                if (product['services'] != null && (product['services'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (product['services'] as List).map<Widget>((service) {
                        IconData icon = Icons.verified_user_outlined;
                        if (service.toString() == 'Hızlı Kargo') {
                          icon = Icons.flash_on;
                        }
                        return Row(
                          children: [
                            Icon(icon, color: AppColors.primary, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              service.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                // Coupon Button & Quantity
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Fast Delivery Toggle
                    if (product['productObject'] != null)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _appState.toggleFastDelivery(product['productObject']);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _appState.hasFastDelivery(product['productObject'])
                                    ? 'Hızlı Teslimat eklendi'
                                    : 'Hızlı Teslimat kaldırıldı',
                              ),
                              duration: const Duration(milliseconds: 800),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            gradient: _appState.hasFastDelivery(product['productObject'])
                                ? LinearGradient(
                                    colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                                  )
                                : null,
                            color: _appState.hasFastDelivery(product['productObject'])
                                ? null
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _appState.hasFastDelivery(product['productObject'])
                                  ? Colors.transparent
                                  : Colors.grey.shade400,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                color: _appState.hasFastDelivery(product['productObject'])
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hızlı Teslimat',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _appState.hasFastDelivery(product['productObject'])
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Quantity and Coupon Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Coupon Button
                        if (product['hasDiscount'] || product['appliedCoupon'] != null)
                          GestureDetector(
                            onTap: () {
                              if (product['productKey'] is int && product['price'] is double) {
                                _showCouponBottomSheet(product['productKey'] as int, product['price'] as double);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: product['appliedCoupon'] != null ? AppColors.primary.withOpacity(0.1) : null,
                                border: Border.all(color: AppColors.primary, width: 1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    product['appliedCoupon'] != null ? Icons.check_circle : Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                    size: 14
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product['discountText'] ?? 'Kupon Gör',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (product['hasDiscount']) const SizedBox(width: 8),
                        // Quantity Controls
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _updateQuantity(items, storeIndex, productIndex, -1),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.remove, color: Colors.white, size: 14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${product['quantity']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _updateQuantity(items, storeIndex, productIndex, 1),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.add, color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WEB LAYOUT METHODS
  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(
            onSearch: (q) {},
            activeMenu: 'cart',
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildWebContent(),
                  const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sepetim ($totalItems Ürün)',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN (Products)
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _buildWebCouponSection(),
                        const SizedBox(height: 24),
                        if (cartItems.isEmpty && marketItems.isEmpty && foodItems.isEmpty)
                          _buildEmptyCartMessage(),
                          
                        ...cartItems.asMap().entries.map((entry) => _buildWebStoreCard(entry.value, cartItems, entry.key, 'shopping')),
                        if (marketItems.isNotEmpty) ...marketItems.asMap().entries.map((entry) => _buildWebStoreCard(entry.value, marketItems, entry.key, 'market')),
                        if (foodItems.isNotEmpty) ...foodItems.asMap().entries.map((entry) => _buildWebStoreCard(entry.value, foodItems, entry.key, 'food')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // RIGHT COLUMN (Summary)
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildWebBanner(),
                        const SizedBox(height: 16),
                        _buildWebSummaryCard(),
                        const SizedBox(height: 16),
                        _buildWebInfoCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyCartMessage() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Sepetin şu an boş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alışverişe başlamak için ana sayfaya gidebilirsin.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _applyCouponToCart(Map<String, dynamic> coupon) {
    int appliedCount = 0;
    setState(() {
      for (var product in _appState.cart) {
        double productPrice = 0.0;
        try {
          String priceStr = product.price
              .replaceAll('₺', '')
              .replaceAll('TL', '')
              .replaceAll('.', '')
              .replaceAll(',', '.')
              .replaceAll(' ', '')
              .trim();
          productPrice = double.parse(priceStr);
        } catch (e) {
          productPrice = 0.0;
        }

        if (productPrice >= (coupon['minPrice'] as double)) {
           _appliedCoupons[product.hashCode] = coupon;
           appliedCount++;
        }
      }
    });

    if (appliedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${coupon['title']} kuponu $appliedCount ürüne uygulandı!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sepetinizde bu kupon için uygun ürün bulunamadı.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildWebCouponSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İndirim Kuponlarım',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Horizontal list of coupons
          SizedBox(
            height: 100,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: Scrollbar(
                controller: _couponScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.separated(
                  controller: _couponScrollController,
                  padding: const EdgeInsets.only(bottom: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableCoupons.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final coupon = _availableCoupons[index];
                    return Container(
                      width: 300,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: coupon['color'],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.local_offer, color: coupon['iconColor'], size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  coupon['title'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  coupon['description'],
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _applyCouponToCart(coupon),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('Kullan'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStoreCard(Map<String, dynamic> store, List<Map<String, dynamic>> items, int storeIndex, String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Store Checkbox (Simplified for now, assumes all selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Satıcı: ',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Text(
                  store['storeName'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    store['storeRating'],
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
          // Free Shipping Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: const Color(0xFFE8F5E9), // Light green
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Kargo Bedava!',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          // Products
          ...store['products'].asMap().entries.map((entry) {
            return _buildWebProductRow(entry.value, items, storeIndex, entry.key);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWebProductRow(Map<String, dynamic> product, List<Map<String, dynamic>> items, int storeIndex, int productIndex) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: GestureDetector(
              onTap: () => _toggleProductSelection(items, storeIndex, productIndex),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: product['isSelected'] ? AppColors.primary : Colors.grey.shade400,
                  ),
                  color: product['isSelected'] ? AppColors.primary : Colors.transparent,
                ),
                child: product['isSelected'] ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Image
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product['image'] != null && product['image'].toString().isNotEmpty
                  ? (product['image'].toString().startsWith('http')
                      ? Image.network(product['image'], fit: BoxFit.contain)
                      : Image.asset(product['image'], fit: BoxFit.contain))
                  : const Icon(Icons.image_not_supported),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (product['shippingInfo'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          product['shippingInfo'],
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Quantity & Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  // Delete
                  IconButton(
                    onPressed: () => _deleteProduct(items, storeIndex, productIndex),
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  ),
                  // Quantity
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () => _updateQuantity(items, storeIndex, productIndex, -1),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        Text('${product['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                          onPressed: () => _updateQuantity(items, storeIndex, productIndex, 1),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                   double price = product['price'];
                   double originalPrice = price;
                   final coupon = product['appliedCoupon'];
                   if (coupon != null) {
                      if (coupon['isPercentage'] == true) {
                        price -= price * (coupon['discountAmount'] / 100);
                      } else {
                        price -= coupon['discountAmount'];
                      }
                   }
                   
                   return Column(
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       if (coupon != null)
                         Text(
                          _formatPrice(originalPrice),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                       Text(
                        _formatPrice(price),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                       if (coupon != null)
                         Text(
                          'Kazancın: ${_formatPrice(originalPrice - price)}',
                          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                     ],
                   );
                }
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'İBul Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Premium ayrıcalıkları ile tasarruf et',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple.shade700,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Premium\'a Geç',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sepet Özeti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ara Toplam', style: TextStyle(color: Colors.grey)),
              Text(_formatPrice(totalPrice), style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kargo Tutarı', style: TextStyle(color: Colors.grey)),
              Row(
                children: [
                  Text('59,99 TL', style: TextStyle(color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Text('Bedava', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_formatPrice(totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text('İndirim Kodu Gir', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: totalPrice > 0 ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CheckoutPage(
                  totalPrice: totalPrice,
                  selectedProducts: selectedProducts,
                )),
              );
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(totalPrice > 0 ? 'Sepeti Onayla' : 'Ürün Seçiniz', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildWebInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'En yakın gel al noktasını seç, siparişini sana uygun zamanda güvenle teslim al',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
