import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/cart_state.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../models/product_pricing.dart';
import '../services/store_service.dart';
import '../utils/dynamic_value_helpers.dart';
import 'business_detail_page.dart';
import 'checkout_page.dart';
import 'product_detail_page.dart';
import '../widgets/web_header.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppState _appState = AppState();
  bool _isMobileLayout = true;
  int _activeTabIndex = 0;
  final Map<int, bool> _dynamicSelections = {};
  final Map<int, int> _dynamicQuantities = {};
  final ScrollController _couponScrollController = ScrollController();
  String _selectedDeliveryMode = 'fast';

  // Kupon değişkenleri
  final Map<int, Map<String, dynamic>> _appliedCoupons = {};

  final List<Map<String, dynamic>> _availableCoupons = [];

  final Map<String, Map<String, String>> _storeHeaderIdentityCache = {};
  final Map<String, Map<String, dynamic>?> _storePublicInfoByGroupKey = {};
  final Set<String> _storePublicInfoLoadingKeys = {};
  final StoreService _storeService = StoreService();

  static const String _softFontFamily = 'Poppins';

  List<Product> _effectiveCartProducts() => _appState.cart;

  TextStyle _softTextStyle({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = const Color(0xFF18181B),
    double? height,
    double letterSpacing = -0.1,
  }) {
    return TextStyle(
      fontFamily: _softFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  double _screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  bool _isNarrowPhone(BuildContext context) => _screenWidth(context) < 380;

  bool _isVeryNarrowPhone(BuildContext context) => _screenWidth(context) < 350;

  String _cartStoreBusinessName(Map<String, dynamic> store) {
    final businessName = store['businessName']?.toString().trim() ?? '';
    if (businessName.isNotEmpty) return businessName;
    return store['storeName']?.toString().trim() ?? '';
  }

  String _storeGroupKey(String storeName, String sellerId) =>
      '$storeName::$sellerId';

  String _storeGroupKeyFromStore(Map<String, dynamic> store) =>
      _storeGroupKey(
        store['storeName']?.toString() ?? '',
        store['sellerId']?.toString() ?? '',
      );

  void _applyStoreHeaderIdentity(Map<String, dynamic> store) {
    final cached = _storeHeaderIdentityCache[_storeGroupKeyFromStore(store)];
    if (cached == null) return;
    final logoUrl = cached['logoUrl']?.trim() ?? '';
    final sellerId = cached['sellerId']?.trim() ?? '';
    final businessName = cached['businessName']?.trim() ?? '';
    if (logoUrl.isNotEmpty) store['logoUrl'] = logoUrl;
    if (sellerId.isNotEmpty) store['sellerId'] = sellerId;
    if (businessName.isNotEmpty) store['businessName'] = businessName;
  }

  void _persistStoreHeaderIdentity({
    required String groupKey,
    String? sellerId,
    String? businessName,
    String? logoUrl,
  }) {
    final previous = _storeHeaderIdentityCache[groupKey] ?? const {};
    final merged = <String, String>{
      'sellerId': (sellerId ?? previous['sellerId'] ?? '').trim(),
      'businessName': (businessName ?? previous['businessName'] ?? '').trim(),
      'logoUrl': (logoUrl ?? previous['logoUrl'] ?? '').trim(),
    };
    _storeHeaderIdentityCache[groupKey] = merged;
  }

  /// BusinessDetailPage._loadStorePublicInfo ile aynı kaynak: business name → logoUrl.
  void _loadCartStorePublicInfo(Map<String, dynamic> store) {
    _applyStoreHeaderIdentity(store);
    final groupKey = _storeGroupKeyFromStore(store);
    if (_storePublicInfoByGroupKey.containsKey(groupKey) ||
        _storePublicInfoLoadingKeys.contains(groupKey)) {
      return;
    }

    final name = _cartStoreBusinessName(store);
    if (name.isEmpty) {
      _storePublicInfoByGroupKey[groupKey] = null;
      return;
    }

    _storePublicInfoLoadingKeys.add(groupKey);
    _storeService.getStorePublicInfoByBusinessName(name).then((info) async {
      if (!mounted) return;
      var sellerId = store['sellerId']?.toString().trim() ?? '';
      if (sellerId.isEmpty) {
        sellerId = await _storeService.getSellerIdByBusinessName(name) ?? '';
      }
      _persistStoreHeaderIdentity(
        groupKey: groupKey,
        sellerId: sellerId.isNotEmpty ? sellerId : null,
        businessName: name,
        logoUrl: info?['logoUrl']?.toString(),
      );
      setState(() {
        _storePublicInfoLoadingKeys.remove(groupKey);
        _storePublicInfoByGroupKey[groupKey] = info;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _storePublicInfoLoadingKeys.remove(groupKey);
        _storePublicInfoByGroupKey[groupKey] = null;
      });
    });
  }

  String? _resolvedStoreLogo(Map<String, dynamic> store) {
    _applyStoreHeaderIdentity(store);
    final groupKey = _storeGroupKeyFromStore(store);
    final logoUrl = _storePublicInfoByGroupKey[groupKey]?['logoUrl'] as String?;
    if (logoUrl != null && logoUrl.trim().isNotEmpty) return logoUrl.trim();

    final mapLogo = store['logoUrl']?.toString().trim();
    if (mapLogo != null && mapLogo.isNotEmpty) return mapLogo;

    final name = _cartStoreBusinessName(store);
    if (name.isNotEmpty) {
      final assetLogo = StoreLogoHelper.getStoreLogo(name);
      if (assetLogo != null) return assetLogo;
    }
    return null;
  }

  Widget _storeLogoLetter(String businessName, double size) {
    return Center(
      child: Text(
        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'M',
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Map<String, dynamic> _businessMapFromStore(Map<String, dynamic> store) {
    _applyStoreHeaderIdentity(store);
    final businessName = _cartStoreBusinessName(store);
    final sellerId = store['sellerId']?.toString() ?? '';
    final logo = _resolvedStoreLogo(store);
    final isAssetLogo = logo != null && logo.startsWith('assets/');
    final isRemoteLogo = logo != null && !isAssetLogo;
    return {
      'seller_id': sellerId,
      'name': businessName,
      'business_name': businessName,
      'logo_url': isRemoteLogo ? logo : null,
      'logo': isAssetLogo ? logo : null,
      'category': store['category']?.toString() ?? '',
    };
  }

  void _openStoreFromCart(Map<String, dynamic> store) {
    final storeName = store['storeName']?.toString().trim() ?? '';
    final sellerId = store['sellerId']?.toString().trim() ?? '';
    if (storeName.isEmpty && sellerId.isEmpty) return;

    final products = (store['products'] as List?)
            ?.map((entry) => (entry as Map<String, dynamic>)['productObject'])
            .whereType<Product>()
            .toList(growable: false) ??
        const <Product>[];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessDetailPage(
          business: _businessMapFromStore(store),
          storeProducts: products.isEmpty ? null : products,
        ),
      ),
    );
  }

  Widget _buildStoreLogoAvatar(
    Map<String, dynamic> store, {
    required bool isNarrow,
  }) {
    final size = isNarrow ? 40.0 : 44.0;
    final groupKey = _storeGroupKeyFromStore(store);
    final businessName = _cartStoreBusinessName(store);
    _loadCartStorePublicInfo(store);

    final logo = _resolvedStoreLogo(store);
    final isLoading = _storePublicInfoLoadingKeys.contains(groupKey) &&
        (logo == null || logo.isEmpty);

    Widget logoWidget;
    if (logo != null && logo.startsWith('assets/')) {
      logoWidget = Image.asset(
        logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (logo != null && logo.isNotEmpty) {
      logoWidget = OptimizedImage(
        imageUrlOrPath: logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _storeLogoLetter(businessName, size),
      );
    } else if (isLoading) {
      logoWidget = Center(
        child: Icon(
          Icons.storefront_outlined,
          size: isNarrow ? 16 : 18,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      );
    } else {
      logoWidget = _storeLogoLetter(businessName, size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoWidget,
    );
  }

  void _showMobileSummarySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMobileSummarySection(),
                const SizedBox(height: 12),
                _buildMobileTrustBanner(),
              ],
            ),
          ),
        );
      },
    );
  }

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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kazanılan kuponları seçerek indirim sağlayabilirsiniz.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: _availableCoupons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final coupon = _availableCoupons[index];
                        final bool isApplied =
                            _appliedCoupons[productHashCode]?['id'] ==
                            coupon['id'];
                        final bool isApplicable =
                            productPrice >= (coupon['minPrice'] as double);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isApplied
                                  ? AppColors.primary
                                  : Colors.grey.shade200,
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
                                            _appliedCoupons.remove(
                                              productHashCode,
                                            );
                                          } else {
                                            _appliedCoupons[productHashCode] =
                                                coupon;
                                          }
                                        });
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isApplied
                                                  ? 'Kupon kaldırıldı'
                                                  : '${coupon['title']} uygulandı',
                                            ),
                                            backgroundColor: isApplied
                                                ? Colors.grey
                                                : AppColors.primary,
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isApplied
                                      ? Colors.grey
                                      : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
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

  // Seçili parçaları gösteren popup
  void _showPartsPopup(BuildContext context, List<dynamic> parts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.build, color: Color(0xFF7C4DFF)),
            const SizedBox(width: 8),
            const Text('Seçili Parçalar'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: parts.length,
            itemBuilder: (context, index) {
              final part = parts[index];
              return ListTile(
                leading: part.images != null && part.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          part.images[0],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[200],
                              child: Icon(Icons.image, color: Colors.grey[400]),
                            );
                          },
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
                title: Text(
                  part.name ?? 'Parça',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  part.price ?? '0 TL',
                  style: const TextStyle(color: Color(0xFF7C4DFF)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Sepetteki ürünler
  bool _isFoodProduct(Product product) =>
      CartState.tabKindForProduct(product) == CartTabKind.food;

  bool _isMarketProduct(Product product) =>
      CartState.tabKindForProduct(product) == CartTabKind.market;

  List<Map<String, dynamic>> _storesForTabIndex(int index) {
    switch (index) {
      case 1:
        return marketItems;
      case 2:
        return foodItems;
      default:
        return cartItems;
    }
  }

  Iterable<Map<String, dynamic>> _effectiveStoreGroups() sync* {
    if (_isMobileLayout) {
      yield* _storesForTabIndex(_activeTabIndex);
      return;
    }
    yield* cartItems;
    yield* marketItems;
    yield* foodItems;
  }

  int _countItemsInStores(Iterable<Map<String, dynamic>> stores) {
    var count = 0;
    for (final store in stores) {
      for (final product in store['products'] as List) {
        count += product['quantity'] as int;
      }
    }
    return count;
  }

  List<Map<String, dynamic>> _selectedProductsInStores(
    Iterable<Map<String, dynamic>> stores,
  ) {
    final products = <Map<String, dynamic>>[];
    for (final store in stores) {
      for (final product in store['products']) {
        if (product['isSelected'] == true) {
          products.add(product as Map<String, dynamic>);
        }
      }
    }
    return products;
  }

  double _totalPriceInStores(Iterable<Map<String, dynamic>> stores) {
    var total = 0.0;
    for (final store in stores) {
      for (final product in store['products']) {
        if (product['isSelected'] != true) continue;
        var itemTotal =
            (product['price'] as double) * (product['quantity'] as int);

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
    return total;
  }

  double _parseProductPrice(Product product) {
    try {
      final priceStr = product.price
          .replaceAll('₺', '')
          .replaceAll('TL', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .replaceAll(' ', '')
          .trim();
      return double.parse(priceStr);
    } catch (_) {
      return 0.0;
    }
  }

  Map<String, String?> _extractProductMetadata(Product product) {
    String? color;
    String? storage;
    String? watt;
    String? shippingInfo;
    String? feature;
    String? firstSpec;

    if (product.brand.contains('Uf') || product.name.contains('CT-23')) {
      firstSpec = 'Güç: 2300W';
    } else if (product.brand.contains('Haylou') ||
        product.name.contains('Solar')) {
      firstSpec = 'Ekran: 1.43" AMOLED';
    } else if (product.brand.contains('Apple') ||
        product.name.contains('iPhone')) {
      firstSpec = '6.1" Super Retina XDR';
    }

    for (final tag in product.tags) {
      final lowerTag = tag.toLowerCase();
      if (tag.contains('Renk') ||
          lowerTag.contains('siyah') ||
          lowerTag.contains('beyaz') ||
          lowerTag.contains('kırmızı') ||
          lowerTag.contains('mavi') ||
          lowerTag.contains('yeşil') ||
          lowerTag.contains('turuncu') ||
          lowerTag.contains('gümüş')) {
        color = tag.replaceAll('Renk:', '').trim();
      } else if (tag.contains('GB') ||
          tag.contains('gb') ||
          tag.contains('Tb') ||
          tag.contains('TB')) {
        storage = tag;
      } else if (tag.contains('W') ||
          tag.contains('w') ||
          lowerTag.contains('watt')) {
        watt = tag;
      } else if (lowerTag.contains('kargo') || lowerTag.contains('teslim')) {
        shippingInfo = tag;
      } else if (!lowerTag.contains('indirim') &&
          !lowerTag.contains('kupon') &&
          !tag.contains('%')) {
        feature ??= tag;
      }
    }

    return {
      'color': color,
      'storage': storage,
      'watt': watt,
      'shippingInfo': shippingInfo,
      'feature': feature,
      'firstSpec': firstSpec,
    };
  }

  String _deliveryLabelForProduct(Product product) {
    if (_selectedDeliveryMode == 'fast' || _appState.hasFastDelivery(product)) {
      return '35-45 dk içinde kapında';
    }
    if (_isMarketProduct(product)) {
      return 'Bugün teslim';
    }
    return 'Yarın teslim';
  }

  IconData _deliveryIconForProduct(Product product) {
    if (_appState.hasFastDelivery(product)) {
      return Icons.electric_bike_outlined;
    }
    return Icons.local_shipping_outlined;
  }

  String _campaignLabelForProduct(Product product) {
    final discountTag = product.tags.firstWhere(
      (tag) =>
          tag.contains('%') ||
          tag.toLowerCase().contains('indirim') ||
          tag.toLowerCase().contains('kupon'),
      orElse: () => '',
    );

    if (discountTag.isNotEmpty) {
      return discountTag;
    }

    final price = _parseProductPrice(product);
    final hasCoupon = _availableCoupons.any(
      (coupon) => price >= (coupon['minPrice'] as double),
    );
    return hasCoupon ? 'Kampanyalı' : 'Avantajlı';
  }

  Map<String, dynamic> _mapProductToStoreItem(Product product) {
    final productPrice = _parseProductPrice(product);
    final metadata = _extractProductMetadata(product);

    final int quantity = _dynamicQuantities[product.hashCode] ?? 1;

    // Hızlı kargo bilgisini services listesine ekle
    List<String> displayServices = List.from(product.selectedServices);
    if (_appState.hasFastDelivery(product)) {
      displayServices.add('Hızlı Kargo');
    }

    return {
      'storeName': product.store ?? product.brand,
      'sellerId': product.sellerId,
      'storeRating': product.rating,
      'deliveryType': _deliveryLabelForProduct(product),
      'deliveryIcon': _deliveryIconForProduct(product),
      'products': [
        {
          'id': product.hashCode,
          'productKey': product.hashCode,
          'productId': product.productId,
          'name': product.name,
          'brand': product.brand,
          'sellerId': product.sellerId,
          'category': product.category,
          'price': productPrice,
          'quantity': quantity,
          'isSecondHand':
              product.name.toLowerCase().contains('2.el') ||
              product.name.toLowerCase().contains('hasarlı') ||
              product.name.toLowerCase().contains('kırık'),
          'hasDiscount':
              product.tags.any(
                (tag) =>
                    tag.toLowerCase().contains('indirim') ||
                    tag.toLowerCase().contains('kupon'),
              ) ||
              _availableCoupons.any(
                (c) => productPrice >= (c['minPrice'] as double),
              ),
          'discountText': _appliedCoupons.containsKey(product.hashCode)
              ? _appliedCoupons[product.hashCode]!['code']
              : (product.tags.any(
                      (tag) =>
                          tag.toLowerCase().contains('indirim') ||
                          tag.toLowerCase().contains('kupon'),
                    )
                    ? 'Kupon Gör'
                    : 'Kupon Var'),
          'appliedCoupon': _appliedCoupons[product.hashCode],
          'discount':
              product.tags
                  .firstWhere((tag) => tag.contains('%'), orElse: () => '')
                  .isNotEmpty
              ? product.tags.firstWhere((tag) => tag.contains('%'))
              : null,
          'image': product.images.isNotEmpty ? product.images[0] : null,
          'isSelected': _dynamicSelections[product.hashCode] ?? true,
          'color': metadata['color'],
          'storage': metadata['storage'],
          'watt': metadata['watt'],
          'shippingInfo': metadata['shippingInfo'],
          'feature': metadata['feature'],
          'firstSpec': metadata['firstSpec'],
          'productObject': product, // Ürün sayfasına gitmek için
          'isDynamic': true,
          'services': displayServices,
          'selectedParts': product.selectedParts, // Seçili parçalar
          'storeName': product.store ?? product.brand,
          'rating': product.rating,
          'deliveryText': _deliveryLabelForProduct(product),
          'deliveryIcon': _deliveryIconForProduct(product),
          'campaignLabel': _campaignLabelForProduct(product),
          'stockText': 'Stokta',
        },
      ],
    };
  }

  List<Map<String, dynamic>> _groupProductsByStore(Iterable<Product> products) {
    final Map<String, Map<String, dynamic>> groupedStores = {};

    for (final product in products) {
      final mappedItem = _mapProductToStoreItem(product);
      final storeName = mappedItem['storeName']?.toString() ?? '';
      final sellerId = mappedItem['sellerId']?.toString() ?? '';
      final key = '$storeName::$sellerId';
      final productMap = Map<String, dynamic>.from(
        (mappedItem['products'] as List).first as Map<String, dynamic>,
      );
      final identity = _storeHeaderIdentityCache[key];
      final businessName = () {
        final cachedName = identity?['businessName']?.trim() ?? '';
        if (cachedName.isNotEmpty) return cachedName;
        final productStore = product.store?.trim() ?? '';
        if (productStore.isNotEmpty) return productStore;
        return storeName;
      }();

      groupedStores.putIfAbsent(
        key,
        () => {
          'storeName': storeName,
          'businessName': businessName,
          'sellerId': (identity?['sellerId']?.trim().isNotEmpty ?? false)
              ? identity!['sellerId']!.trim()
              : sellerId,
          'logoUrl': identity?['logoUrl'] ?? '',
          'storeRating': mappedItem['storeRating'],
          'deliveryType': mappedItem['deliveryType'],
          'deliveryIcon': mappedItem['deliveryIcon'],
          'category': product.category,
          'products': <Map<String, dynamic>>[],
        },
      );

      final store = groupedStores[key]!;
      _applyStoreHeaderIdentity(store);
      (store['products'] as List<Map<String, dynamic>>).add(productMap);

      final currentRating = (store['storeRating'] as num?)?.toDouble() ?? 0;
      final incomingRating =
          (mappedItem['storeRating'] as num?)?.toDouble() ?? 0;
      if (incomingRating > currentRating) {
        store['storeRating'] = incomingRating;
      }

      if (productMap['deliveryText'] == '35-45 dk içinde kapında') {
        store['deliveryType'] = productMap['deliveryText'];
        store['deliveryIcon'] = productMap['deliveryIcon'];
      }
    }

    return groupedStores.values.toList();
  }

  List<Map<String, dynamic>> get cartItems {
    final effectiveCart = _effectiveCartProducts();
    final cartHashes = effectiveCart
        .map((product) => product.hashCode)
        .toSet();
    _dynamicSelections.removeWhere((key, value) => !cartHashes.contains(key));
    _dynamicQuantities.removeWhere((key, value) => !cartHashes.contains(key));

    final products = effectiveCart
        .where((p) => !_isFoodProduct(p) && !_isMarketProduct(p))
        .toList();

    return _groupProductsByStore(products);
  }

  List<Map<String, dynamic>> get marketItems {
    final products = _effectiveCartProducts().where(_isMarketProduct).toList();
    return _groupProductsByStore(products);
  }

  List<Map<String, dynamic>> get foodItems {
    final products = _effectiveCartProducts().where(_isFoodProduct).toList();
    return _groupProductsByStore(products);
  }

  void _syncTabControllerWithAppState() {
    if (!mounted || !_isMobileLayout) return;

    final desiredTab = _appState.selectedCartTabIndex.clamp(0, 2);
    if (_activeTabIndex == desiredTab && _tabController.index == desiredTab) {
      return;
    }

    _activeTabIndex = desiredTab;
    if (_tabController.index != desiredTab) {
      _tabController.index = desiredTab;
    }
  }

  void _onCartTabInteraction() {
    if (_tabController.indexIsChanging) return;
    _activeTabIndex = _tabController.index;
    _appState.setSelectedCartTabIndex(_tabController.index);
  }

  Widget _buildCartTabLabel(String label, int count) {
    final isVeryNarrow = _isVeryNarrowPhone(context);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 3),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: isVeryNarrow ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _activeTabIndex = _appState.selectedCartTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _activeTabIndex,
    );
    _tabController.addListener(_onCartTabInteraction);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onCartTabInteraction);
    _tabController.dispose();
    _couponScrollController.dispose();
    super.dispose();
  }

  void _toggleProductSelection(
    List<Map<String, dynamic>> items,
    int storeIndex,
    int productIndex,
  ) {
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

  void _updateQuantity(
    List<Map<String, dynamic>> items,
    int storeIndex,
    int productIndex,
    int change,
  ) {
    setState(() {
      int currentQuantity =
          items[storeIndex]['products'][productIndex]['quantity'];
      int newQuantity = currentQuantity + change;
      if (newQuantity > 0) {
        items[storeIndex]['products'][productIndex]['quantity'] = newQuantity;
        final Map<String, dynamic> productMap =
            items[storeIndex]['products'][productIndex] as Map<String, dynamic>;
        if (productMap['isDynamic'] == true &&
            productMap['productKey'] is int) {
          _dynamicQuantities[productMap['productKey'] as int] = newQuantity;
        }
      }
    });
  }

  void _deleteProduct(
    List<Map<String, dynamic>> items,
    int storeIndex,
    int productIndex,
  ) {
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
                const Icon(
                  Icons.electric_bike,
                  color: AppColors.primary,
                  size: 28,
                ),
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
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
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

  int get scopedProductCount {
    if (_isMobileLayout) {
      return _appState.cartCountForTab(_activeTabIndex);
    }
    return _appState.cart.length;
  }

  int get totalItems => _countItemsInStores(_effectiveStoreGroups());

  double get totalPrice => _totalPriceInStores(_effectiveStoreGroups());

  double get deliveryFee {
    if (selectedProducts.isEmpty) return 0;
    return _selectedDeliveryMode == 'fast' ? 28 : 0;
  }

  double get serviceFee {
    return selectedProducts.isEmpty ? 0 : 5;
  }

  double get payableTotal {
    return totalPrice + deliveryFee + serviceFee;
  }

  String get deliveryModeTitle {
    return _selectedDeliveryMode == 'fast' ? 'Hızlı Teslimat' : 'Kargo';
  }

  String get deliveryModeSubtitle {
    return _selectedDeliveryMode == 'fast'
        ? '35-45 dk içinde kapında'
        : 'Yarın teslim';
  }

  String get deliveryModeFeeLabel {
    return _selectedDeliveryMode == 'fast'
        ? _formatPrice(deliveryFee)
        : 'Ücretsiz';
  }

  String get deliveryModeEtaLabel {
    return _selectedDeliveryMode == 'fast' ? '35 dk' : '1-2 gün';
  }

  void _showDeliveryModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Teslimat tipini seç',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _buildDeliveryOptionTile(
                  mode: 'fast',
                  icon: Icons.electric_bike_outlined,
                  title: 'Hızlı Teslimat',
                  subtitle: 'Kurye ücreti: 28 TL • Teslimat süresi: 35 dk',
                ),
                const SizedBox(height: 10),
                _buildDeliveryOptionTile(
                  mode: 'cargo',
                  icon: Icons.local_shipping_outlined,
                  title: 'Kargo',
                  subtitle: 'Ücretsiz kargo • Teslimat süresi: Yarın teslim',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliveryOptionTile({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedDeliveryMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDeliveryMode = mode;
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4EEFF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off_outlined,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get selectedProducts =>
      _selectedProductsInStores(_effectiveStoreGroups());

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
    context.watch<AppState>();

    final isWeb = MediaQuery.of(context).size.width >= 900;
    _isMobileLayout = !isWeb;
    if (_isMobileLayout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncTabControllerWithAppState();
      });
    }

    if (isWeb) {
      return _buildWebView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(child: _buildMobileLayout()),
      bottomNavigationBar: _buildMobileBottomBar(),
    );
  }

  Widget _buildMobileLayout() {
    final isNarrow = _isNarrowPhone(context);
    final isVeryNarrow = _isVeryNarrowPhone(context);

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 16,
            vertical: isNarrow ? 12 : 16,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      isNarrow ? 'Alışveriş\nSepetim' : 'Alışveriş Sepetim',
                      style: _softTextStyle(
                        size: isVeryNarrow ? 18 : 22,
                        weight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 12,
                          vertical: isNarrow ? 7 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EBFF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '$scopedProductCount Ürün',
                          style: _softTextStyle(
                            size: isNarrow ? 13 : 14,
                            weight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.primary,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: _softTextStyle(
              size: isVeryNarrow ? 11 : 12.5,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
            unselectedLabelStyle: _softTextStyle(
              size: isVeryNarrow ? 11 : 12.5,
              weight: FontWeight.w600,
              color: AppColors.primary,
            ),
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            tabs: [
              Container(
                height: isNarrow ? 30 : 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildCartTabLabel(
                  'Alışveriş',
                  _appState.cartCountForTab(0),
                ),
              ),
              Container(
                height: isNarrow ? 30 : 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildCartTabLabel(
                  'Market',
                  _appState.cartCountForTab(1),
                ),
              ),
              Container(
                height: isNarrow ? 30 : 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildCartTabLabel(
                  'Yemek',
                  _appState.cartCountForTab(2),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isNarrow ? 12 : 16),
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
      ],
    );
  }

  Widget _buildShoppingCart() {
    return _buildMobileCartList(
      stores: cartItems,
      category: 'shopping',
      emptyTitle: 'Sepetinde henüz alışveriş ürünü yok',
      emptyIcon: Icons.shopping_bag_outlined,
    );
  }

  Widget _buildMarketCart() {
    return _buildMobileCartList(
      stores: marketItems,
      category: 'market',
      emptyTitle: 'Sepetinde henüz market ürünü yok',
      emptyIcon: Icons.local_grocery_store_outlined,
    );
  }

  Widget _buildFoodCart() {
    final stores = foodItems;
    final orders = _appState.foodOrders;
    if (stores.isEmpty && orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.restaurant_menu_outlined,
                size: 40,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text(
                'Henüz yemek siparişin yok',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        _isNarrowPhone(context) ? 12 : 16,
        0,
        _isNarrowPhone(context) ? 12 : 16,
        200,
      ),
      children: [
        for (int i = 0; i < stores.length; i++)
          _buildStoreCard(stores[i], stores, i, 'food'),
        if (stores.isNotEmpty) const SizedBox(height: 12),
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Geçmiş yemek siparişlerin',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final order in orders) _buildFoodOrderCard(order),
        ],
      ],
    );
  }

  Widget _buildMobileCartList({
    required List<Map<String, dynamic>> stores,
    required String category,
    required String emptyTitle,
    required IconData emptyIcon,
  }) {
    if (stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 44, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                emptyTitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        _isNarrowPhone(context) ? 12 : 16,
        0,
        _isNarrowPhone(context) ? 12 : 16,
        200,
      ),
      children: [
        for (int i = 0; i < stores.length; i++)
          _buildStoreCard(stores[i], stores, i, category),
        const SizedBox(height: 12),
        _buildMobileTrustBanner(),
      ],
    );
  }

  String _foodOrderItemTitle(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final selectedSizeName = item['selectedSizeName']?.toString().trim() ?? '';
    if (selectedSizeName.isNotEmpty) {
      return '$name - $selectedSizeName';
    }
    final grams = (item['selectedWeightGrams'] as num?)?.toInt();
    if (grams != null && grams > 0) {
      return '$name - ${ProductPriceCalculator.formatWeight(grams)}';
    }
    final gramaj = item['gramaj']?.toString().trim() ?? '';
    if (gramaj.isNotEmpty) {
      return '$name - $gramaj';
    }
    return name;
  }

  String? _foodOrderItemPrice(Map<String, dynamic> item) {
    final lineTotal = (item['calculatedLineTotal'] as num?)?.toDouble();
    if (lineTotal != null && lineTotal > 0) {
      return ProductPriceCalculator.formatCurrency(lineTotal);
    }
    final priceText = item['price']?.toString().trim() ?? '';
    return priceText.isEmpty ? null : priceText;
  }

  // ignore: unused_element
  Widget _buildMobileDeliverySelector() {
    final isNarrow = _isNarrowPhone(context);
    final isFast = _selectedDeliveryMode == 'fast';
    return Container(
      padding: EdgeInsets.all(isNarrow ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isNarrow ? 48 : 52,
                height: isNarrow ? 48 : 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isFast
                      ? Icons.electric_bike_outlined
                      : Icons.local_shipping_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deliveryModeTitle,
                            style: _softTextStyle(
                              size: isNarrow ? 15 : 16,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showDeliveryInfo(context),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.grey,
                            size: 18,
                          ),
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deliveryModeSubtitle,
                      style: _softTextStyle(
                        size: isNarrow ? 12.5 : 13,
                        weight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoPill(
                          icon: Icons.payments_outlined,
                          text: 'Kurye ücreti: $deliveryModeFeeLabel',
                          backgroundColor: const Color(0xFFF5F3FF),
                          foregroundColor: AppColors.primary,
                          compact: isNarrow,
                        ),
                        _buildInfoPill(
                          icon: Icons.schedule_outlined,
                          text: 'Teslimat: $deliveryModeEtaLabel',
                          backgroundColor: const Color(0xFFEAF7EE),
                          foregroundColor: const Color(0xFF169A45),
                          compact: isNarrow,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _showDeliveryModePicker,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 12 : 14,
                  vertical: 12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Değiştir',
                    style: _softTextStyle(
                      size: isNarrow ? 13 : 14,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodOrderCard(Map<String, dynamic> order) {
    final items = (order['items'] as List?) ?? [];
    final type = order['orderType']?.toString() ?? 'garson';
    final isOnline = type == 'online';
    final rawStatus = order['status']?.toString();

    String statusText;
    Color statusColor;

    if (isOnline) {
      statusText = 'Online sipariş';
      statusColor = Colors.blue;
    } else {
      final status = rawStatus ?? 'new';
      if (status == 'preparing') {
        statusText = 'Hazırlanıyor';
        statusColor = Colors.orange;
      } else if (status == 'done') {
        statusText = 'Teslim edildi';
        statusColor = Colors.green;
      } else {
        statusText = 'Garsona gönderildi';
        statusColor = Colors.orange;
      }
    }
    final tableNumber = order['tableNumber'];
    final createdAt = order['createdAt']?.toString();

    return GestureDetector(
      onTap: () => _showFoodOrderDetails(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restaurant_menu_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['businessName']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (tableNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Masa $tableNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (createdAt != null && createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                createdAt,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map<Widget>((raw) {
                final item = raw as Map<String, dynamic>;
                final attrs =
                    (item['attributes'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    [];
                final quantity = item['quantity'] ?? 1;
                final notes = item['notes']?.toString();
                final priceText = _foodOrderItemPrice(item);
                final subtitleParts = <String>[
                  if ((item['selectedSizeName']?.toString().trim() ?? '').isNotEmpty)
                    item['selectedSizeName'].toString().trim(),
                  if (attrs.isNotEmpty) attrs.join(' • '),
                  if (notes != null && notes.isNotEmpty) notes,
                ];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'x$quantity',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _foodOrderItemTitle(item),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (priceText != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitleParts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitleParts.join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(
    Map<String, dynamic> store,
    List<Map<String, dynamic>> items,
    int storeIndex,
    String category,
  ) {
    final isNarrow = _isNarrowPhone(context);
    final productCount = (store['products'] as List).length;
    _applyStoreHeaderIdentity(store);
    final storeName = store['storeName']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openStoreFromCart(store),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
            padding: EdgeInsets.fromLTRB(
              isNarrow ? 10 : 12,
              isNarrow ? 10 : 12,
              isNarrow ? 10 : 12,
              8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildStoreLogoAvatar(store, isNarrow: isNarrow),
                SizedBox(width: isNarrow ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        storeName,
                        style: _softTextStyle(
                          size: isNarrow ? 14.5 : 15,
                          weight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 15,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ((store['storeRating'] as num?)?.toDouble() ?? 0)
                                .toStringAsFixed(1),
                            style: _softTextStyle(
                              size: isNarrow ? 12 : 12.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 8 : 9,
                              vertical: isNarrow ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EBFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$productCount Ürün',
                              style: _softTextStyle(
                                size: isNarrow ? 11 : 11.5,
                                weight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              ],
            ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
          ...store['products'].asMap().entries.map<Widget>((entry) {
            int productIndex = entry.key;
            var product = entry.value;
            return _buildProductCard(product, items, storeIndex, productIndex);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> items,
    int storeIndex,
    int productIndex,
  ) {
    final isNarrow = _isNarrowPhone(context);
    final isVeryNarrow = _isVeryNarrowPhone(context);
    final checkboxSize = isNarrow ? 17.0 : 18.0;
    final imageSize = isNarrow ? 56.0 : 64.0;
    final columnGap = isNarrow ? 6.0 : 8.0;
    final checkboxTop = (imageSize - checkboxSize) / 2;
    final productObject = product['productObject'];
    final productPrice = product['price'] as double;
    double discountedPrice = productPrice;
    final coupon = product['appliedCoupon'];

    if (coupon != null) {
      if (coupon['isPercentage'] == true) {
        discountedPrice -= productPrice * (coupon['discountAmount'] / 100);
      } else {
        discountedPrice -= coupon['discountAmount'];
      }
    }

    final specs = <String>[
      if ((product['firstSpec'] ?? '').toString().isNotEmpty)
        product['firstSpec'].toString().replaceFirst('Ekran: ', ''),
      if ((product['storage'] ?? '').toString().isNotEmpty)
        product['storage'].toString(),
      if ((product['color'] ?? '').toString().isNotEmpty)
        product['color'].toString(),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 10 : 12,
        11,
        isNarrow ? 10 : 12,
        11,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    _toggleProductSelection(items, storeIndex, productIndex),
                child: Container(
                  width: checkboxSize,
                  height: checkboxSize,
                  margin: EdgeInsets.only(top: checkboxTop),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: product['isSelected']
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: product['isSelected']
                          ? AppColors.primary
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: product['isSelected']
                      ? const Icon(Icons.check, color: Colors.white, size: 10)
                      : null,
                ),
              ),
              SizedBox(width: columnGap),
              GestureDetector(
                onTap: () {
                  if (productObject != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailPage(product: productObject),
                      ),
                    );
                  }
                },
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        product['image'] != null &&
                            product['image'].toString().isNotEmpty
                        ? (product['image'].toString().startsWith('http')
                              ? OptimizedImage(
                                  imageUrlOrPath: product['image'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.grey,
                                        size: 30,
                                      ),
                                    );
                                  },
                                )
                              : Image.asset(
                                  product['image'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.grey,
                                        size: 30,
                                      ),
                                    );
                                  },
                                ))
                        : const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(width: columnGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (productObject != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductDetailPage(
                                      product: productObject,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: _softTextStyle(
                                    size: isVeryNarrow ? 13 : 14.5,
                                    weight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  specs.join(' • '),
                                  style: _softTextStyle(
                                    size: isVeryNarrow ? 10 : 11,
                                    weight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _deleteProduct(items, storeIndex, productIndex),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6, top: 1),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: isNarrow ? 4 : 5,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildInfoPill(
                              icon: Icons.circle,
                              text: product['stockText'] ?? 'Stokta',
                              backgroundColor: const Color(0xFFEAF7EE),
                              foregroundColor: const Color(0xFF16A34A),
                              iconSize: 7,
                              compact: isNarrow,
                            ),
                            if ((product['campaignLabel'] ?? '')
                                .toString()
                                .isNotEmpty)
                              _buildInfoPill(
                                icon: Icons.local_offer_outlined,
                                text: product['campaignLabel'],
                                backgroundColor: const Color(0xFFFFF1F2),
                                foregroundColor: const Color(0xFFBE123C),
                                compact: isNarrow,
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: double.infinity,
                          child: _buildInfoPill(
                            icon:
                                product['deliveryIcon'] ??
                                Icons.local_shipping_outlined,
                            text: product['deliveryText'] ?? 'Yarın teslim',
                            backgroundColor: const Color(0xFFF1EBFF),
                            foregroundColor: AppColors.primary,
                            compact: isNarrow,
                            multiline: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (coupon != null)
                    Text(
                      _formatPrice(productPrice),
                      style: _softTextStyle(
                        size: 10.5,
                        weight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ).copyWith(decoration: TextDecoration.lineThrough),
                    ),
                  Text(
                    _formatPrice(discountedPrice),
                    style: _softTextStyle(
                      size: isVeryNarrow ? 15.5 : 17,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      height: 1.0,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (productObject != null) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _appState.toggleFastDelivery(productObject);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 6 : 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _appState.hasFastDelivery(productObject)
                          ? const Color(0xFFFFF0E8)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: _appState.hasFastDelivery(productObject)
                              ? Colors.deepOrange
                              : Colors.grey.shade600,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _appState.hasFastDelivery(productObject)
                              ? 'Hızlı'
                              : 'Hızlı ekle',
                          style: _softTextStyle(
                            size: isVeryNarrow ? 9.5 : 10,
                            weight: FontWeight.w700,
                            color: _appState.hasFastDelivery(productObject)
                                ? Colors.deepOrange
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isNarrow ? 6 : 8),
              ],
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F1F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _updateQuantity(
                        items,
                        storeIndex,
                        productIndex,
                        -1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 8 : 9,
                          vertical: 6,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: isNarrow ? 15 : 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Container(
                      constraints: BoxConstraints(
                        minWidth: isNarrow ? 14 : 18,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${product['quantity']}',
                        style: _softTextStyle(
                          size: isNarrow ? 12.5 : 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _updateQuantity(
                        items,
                        storeIndex,
                        productIndex,
                        1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 8 : 9,
                          vertical: 6,
                        ),
                        child: Icon(
                          Icons.add,
                          size: isNarrow ? 17 : 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((product['hasDiscount'] || product['appliedCoupon'] != null) &&
              product['isSecondHand'] != true) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                if (product['productKey'] is int &&
                    product['price'] is double) {
                  _showCouponBottomSheet(
                    product['productKey'] as int,
                    product['price'] as double,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: coupon != null
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  coupon != null ? 'Kupon Uygulandı' : 'Kupon Ekle',
                  style: _softTextStyle(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
          if ((product['selectedParts'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _showPartsPopup(
                context,
                product['selectedParts'] as List<dynamic>,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_outlined, size: 13, color: Colors.black54),
                    SizedBox(width: 5),
                    Text(
                      'Seçili parçaları gör',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
    double iconSize = 14,
    bool compact = false,
    bool multiline = false,
  }) {
    final fontSize = compact ? 9.5 : 10.5;
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: foregroundColor,
      height: multiline ? 1.2 : 1.0,
    );

    return Container(
      width: multiline ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(multiline ? 12 : 999),
      ),
      child: Row(
        mainAxisSize: multiline ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: foregroundColor),
          const SizedBox(width: 4),
          if (multiline)
            Expanded(
              child: Text(
                text,
                style: textStyle,
                softWrap: true,
                maxLines: 2,
              ),
            )
          else
            Text(
              text,
              style: textStyle,
              softWrap: false,
              maxLines: 1,
            ),
        ],
      ),
    );
  }

  Widget _buildMobileSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Sepet Özeti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'İndirim Kodu Ekle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Ara Toplam', _formatPrice(totalPrice)),
              const SizedBox(height: 12),
              _buildSummaryRow(
                _selectedDeliveryMode == 'fast' ? 'Kurye Ücreti' : 'Kargo',
                deliveryModeFeeLabel,
                valueColor: _selectedDeliveryMode == 'fast'
                    ? Colors.black87
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow('Hizmet Bedeli', _formatPrice(serviceFee)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),
              _buildSummaryRow(
                'Toplam',
                _formatPrice(payableTotal),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 17 : 15,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 15,
            fontWeight: FontWeight.w800,
            color: valueColor ?? (isTotal ? AppColors.primary : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTrustBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: const [
          Icon(Icons.verified_user_outlined, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Güvenli ödeme ve hızlı teslimat ile siparişin korunur',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    final isNarrow = _isNarrowPhone(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 14 : 18,
          8,
          isNarrow ? 14 : 18,
          isNarrow ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Toplam',
                            style: _softTextStyle(
                              size: isNarrow ? 13 : 14,
                              weight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: _showMobileSummarySheet,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(payableTotal),
                        style: _softTextStyle(
                          size: isNarrow ? 17 : 19,
                          weight: FontWeight.w800,
                          color: selectedProducts.isEmpty
                              ? Colors.grey.shade500
                              : AppColors.primary,
                        ),
                      ),
                      Text(
                        selectedProducts.isEmpty
                            ? 'Ürün seçiniz'
                            : '$deliveryModeTitle • $deliveryModeEtaLabel',
                        style: _softTextStyle(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: isNarrow ? 156 : 172,
                  height: isNarrow ? 46 : 48,
                  child: ElevatedButton(
                    onPressed: selectedProducts.isNotEmpty
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutPage(
                                  totalPrice: payableTotal,
                                  selectedProducts: selectedProducts,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 10 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Sepeti Onayla',
                            style: _softTextStyle(
                              size: isNarrow ? 13 : 14,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WEB LAYOUT METHODS
  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}, activeMenu: 'cart'),
          Expanded(
            child: WebStickyFooterScrollView(
              child: _buildWebContent(),
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
                'Sepetim (${_appState.cart.length} Ürün)',
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
                        if (cartItems.isEmpty &&
                            marketItems.isEmpty &&
                            foodItems.isEmpty &&
                            _appState.foodOrders.isEmpty)
                          _buildEmptyCartMessage(),

                        ...cartItems.asMap().entries.map(
                          (entry) => _buildWebStoreCard(
                            entry.value,
                            cartItems,
                            entry.key,
                            'shopping',
                          ),
                        ),
                        if (marketItems.isNotEmpty)
                          ...marketItems.asMap().entries.map(
                            (entry) => _buildWebStoreCard(
                              entry.value,
                              marketItems,
                              entry.key,
                              'market',
                            ),
                          ),
                        if (foodItems.isNotEmpty)
                          ...foodItems.asMap().entries.map(
                            (entry) => _buildWebStoreCard(
                              entry.value,
                              foodItems,
                              entry.key,
                              'food',
                            ),
                          ),
                        if (_appState.foodOrders.isNotEmpty)
                          _buildWebFoodOrdersSection(_appState.foodOrders),
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
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sepetin şu an boş',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
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
          content: Text(
            '${coupon['title']} kuponu $appliedCount ürüne uygulandı!',
          ),
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
    if (_availableCoupons.isEmpty) {
      return const SizedBox.shrink();
    }
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
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
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
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
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
                            child: Icon(
                              Icons.local_offer,
                              color: coupon['iconColor'],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  coupon['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  coupon['description'],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
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

  Widget _buildWebStoreCard(
    Map<String, dynamic> store,
    List<Map<String, dynamic>> items,
    int storeIndex,
    String category,
  ) {
    final bool isFood = category == 'food';
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    readString(store['storeRating'], fallback: '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
          // Info Banner (Shipping / Food)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: isFood ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
            child: Row(
              children: [
                Icon(
                  isFood ? Icons.restaurant_menu : Icons.check_circle,
                  size: 14,
                  color: isFood ? Colors.deepOrange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  isFood ? 'Yemek siparişi' : 'Kargo Bedava!',
                  style: TextStyle(
                    color: isFood ? Colors.deepOrange : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Products
          ...store['products'].asMap().entries.map((entry) {
            return _buildWebProductRow(
              entry.value,
              items,
              storeIndex,
              entry.key,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWebFoodOrdersSection(List<Map<String, dynamic>> orders) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.restaurant_menu_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Yemek Siparişlerin',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: orders
                .map((order) => _buildFoodOrderCard(order))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showFoodOrderDetails(Map<String, dynamic> order) {
    final editableItems = ((order['items'] as List?) ?? [])
        .whereType<Map>()
        .map<Map<String, dynamic>>((raw) => Map<String, dynamic>.from(raw))
        .toList();
    final type = order['orderType']?.toString() ?? 'garson';
    final isOnline = type == 'online';
    final rawStatus = order['status']?.toString();
    String statusText;
    Color statusColor;
    if (isOnline) {
      statusText = 'Online sipariş';
      statusColor = Colors.blue;
    } else {
      final status = rawStatus ?? 'new';
      if (status == 'preparing') {
        statusText = 'Hazırlanıyor';
        statusColor = Colors.orange;
      } else if (status == 'done') {
        statusText = 'Teslim edildi';
        statusColor = Colors.green;
      } else {
        statusText = 'Garsona gönderildi';
        statusColor = Colors.orange;
      }
    }
    final tableNumber = order['tableNumber'];
    final createdAt = order['createdAt']?.toString();
    final businessName = order['businessName']?.toString() ?? '';
    final id = order['id']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setSheet) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.restaurant_menu_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  businessName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (tableNumber != null)
                                      Text(
                                        'Masa $tableNumber',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    if (createdAt != null &&
                                        createdAt.isNotEmpty) ...[
                                      if (tableNumber != null)
                                        const SizedBox(width: 8),
                                      Text(
                                        createdAt,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (id != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              _appState.removeFoodOrder(id);
                              Navigator.pop(sheetCtx);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Siparişi listeden sil',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      if (id != null) const SizedBox(height: 4),
                      const Text(
                        'Sipariş Detayı',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: editableItems.asMap().entries.map<Widget>((
                          entry,
                        ) {
                          final index = entry.key;
                          final item = entry.value;
                          final attrs =
                              (item['attributes'] as List?)
                                  ?.whereType<String>()
                                  .toList() ??
                              [];
                          final quantity = (item['quantity'] ?? 1) as int;
                          final notes = item['notes']?.toString();
                          final price = _foodOrderItemPrice(item);
                          final subtitleParts = <String>[
                            if (attrs.isNotEmpty) attrs.join(' • '),
                            if (notes != null && notes.isNotEmpty) notes,
                          ];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (quantity > 1) {
                                              setSheet(() {
                                                editableItems[index]['quantity'] =
                                                    quantity - 1;
                                              });
                                            }
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.remove,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'x$quantity',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            setSheet(() {
                                              editableItems[index]['quantity'] =
                                                  quantity + 1;
                                            });
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _foodOrderItemTitle(item),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (price != null && price.isNotEmpty)
                                      Text(
                                        price,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                  ],
                                ),
                                if (subtitleParts.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      subtitleParts.join(' • '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (!isOnline && id != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _appState.updateFoodOrder(
                                id,
                                items: editableItems,
                                status: 'preparing',
                              );
                              Navigator.pop(sheetCtx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Siparişi Gönder',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWebProductRow(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> items,
    int storeIndex,
    int productIndex,
  ) {
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
              onTap: () =>
                  _toggleProductSelection(items, storeIndex, productIndex),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: product['isSelected']
                        ? AppColors.primary
                        : Colors.grey.shade400,
                  ),
                  color: product['isSelected']
                      ? AppColors.primary
                      : Colors.transparent,
                ),
                child: product['isSelected']
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Image
          GestureDetector(
            onTap: () {
              if (product['productObject'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailPage(product: product['productObject']),
                  ),
                );
              }
            },
            child: Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    product['image'] != null &&
                        product['image'].toString().isNotEmpty
                    ? (product['image'].toString().startsWith('http')
                          ? OptimizedImage(
                              imageUrlOrPath: product['image'],
                              fit: BoxFit.contain,
                            )
                          : Image.asset(product['image'], fit: BoxFit.contain))
                    : const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (product['productObject'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailPage(
                            product: product['productObject'],
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    product['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (product['shippingInfo'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product['shippingInfo'],
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
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
                    onPressed: () =>
                        _deleteProduct(items, storeIndex, productIndex),
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
                          onPressed: () => _updateQuantity(
                            items,
                            storeIndex,
                            productIndex,
                            -1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        Text(
                          '${product['quantity']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _updateQuantity(
                            items,
                            storeIndex,
                            productIndex,
                            1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (coupon != null)
                        Text(
                          'Kazancın: ${_formatPrice(originalPrice - price)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  );
                },
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
            color: Colors.purple.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.diamond_outlined,
                  color: Colors.white,
                  size: 24,
                ),
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
              color: Colors.white.withValues(alpha: 0.95),
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
          const Text(
            'Sepet Özeti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ara Toplam', style: TextStyle(color: Colors.grey)),
              Text(
                _formatPrice(totalPrice),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kargo Tutarı', style: TextStyle(color: Colors.grey)),
              Row(
                children: [
                  Text(
                    '59,99 TL',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Bedava',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Toplam',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                _formatPrice(totalPrice),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'İndirim Kodu Gir',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: totalPrice > 0
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckoutPage(
                          totalPrice: totalPrice,
                          selectedProducts: selectedProducts,
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              totalPrice > 0 ? 'Sepeti Onayla' : 'Ürün Seçiniz',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
