import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../services/store_service.dart';
import 'product_card.dart';

class DynamicBrandSection extends StatefulWidget {
  final Map<String, dynamic> layout;
  final List<DBProduct> allProducts;

  const DynamicBrandSection({
    super.key,
    required this.layout,
    required this.allProducts,
  });

  @override
  State<DynamicBrandSection> createState() => _DynamicBrandSectionState();
}

class _DynamicBrandSectionState extends State<DynamicBrandSection> {
  String? _selectedSellerId;
  List<String> _bannerUrls = [];
  List<DBProduct> _displayedProducts = [];
  List<Map<String, dynamic>> _stores = [];
  bool _isLoadingBanners = false;

  @override
  void initState() {
    super.initState();
    _parseLayout();
  }

  void _parseLayout() {
    final brandData = widget.layout['brand_name'];
    if (brandData != null && brandData.toString().startsWith('%5B')) {
      try {
        final decoded = Uri.decodeComponent(brandData);
        final List<dynamic> jsonList = json.decode(decoded);
        _stores = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    _updateBanners(null);
    _filterProducts();
  }

  Future<void> _updateBanners(String? sellerId) async {
    if (sellerId == null) {
      final adImageUrl = widget.layout['ad_image_url'] as String?;
      if (mounted) {
        setState(() {
          _bannerUrls = adImageUrl != null && adImageUrl.isNotEmpty
              ? adImageUrl
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
              : [];
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoadingBanners = true);

    try {
      final service = StoreService();
      final info = await service.getStorePublicInfoById(sellerId);

      if (mounted) {
        setState(() {
          if (info != null &&
              info['banners'] != null &&
              (info['banners'] as List).isNotEmpty) {
            _bannerUrls = (info['banners'] as List)
                .map((e) => e.toString())
                .toList();
          } else {
            final adImageUrl = widget.layout['ad_image_url'] as String?;
            _bannerUrls = adImageUrl != null && adImageUrl.isNotEmpty
                ? adImageUrl
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList()
                : [];
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingBanners = false);
    }
  }

  void _filterProducts() {
    final productIdsRaw = widget.layout['product_ids'] as List?;
    final productIds = productIdsRaw?.map((e) => e.toString()).toSet() ?? {};

    setState(() {
      _displayedProducts = widget.allProducts.where((p) {
        final pid = p.id;
        if (pid == null) return false;
        final matchesId = productIds.contains(pid);
        if (!matchesId) return false;

        if (_selectedSellerId == null) return true;

        final selectedStore = _stores.firstWhere(
          (s) => s['seller_id'] == _selectedSellerId,
          orElse: () => {},
        );
        final storeName = selectedStore['business_name'] as String?;

        if (storeName == null) return true;

        return (p.store?.toLowerCase() == storeName.toLowerCase());
      }).toList();
    });
  }

  void _onStoreTap(Map<String, dynamic> store) {
    final sellerId = store['seller_id'];

    if (_selectedSellerId == sellerId) {
      setState(() {
        _selectedSellerId = null;
      });
      _updateBanners(null);
      _filterProducts();
    } else {
      setState(() {
        _selectedSellerId = sellerId;
      });
      _updateBanners(sellerId);
      _filterProducts();
    }
  }

  Product _convertToProduct(DBProduct dbProduct) {
    List<String> images = [];
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        if (dbProduct.imageUrl.isNotEmpty) images.add(dbProduct.imageUrl);
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }

    return Product(
      name: dbProduct.name,
      price: dbProduct.price,
      oldPrice: dbProduct.oldPrice,
      images: images.isEmpty ? [] : images,
      category: dbProduct.category,
      brand: dbProduct.brand,
      description: dbProduct.description,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: dbProduct.tags.isNotEmpty
          ? List<String>.from(json.decode(dbProduct.tags))
          : [],
      subCategory: dbProduct.subCategory,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.layout['title'] as String?) ?? 'Özel Fırsatlar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_stores.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _stores.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final store = _stores[index];
                final isSelected = _selectedSellerId == store['seller_id'];

                return GestureDetector(
                  onTap: () => _onStoreTap(store),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8B5CF6)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            backgroundImage: store['logo_url'] != null
                                ? NetworkImage(store['logo_url'])
                                : null,
                            child: store['logo_url'] == null
                                ? Text(
                                    store['business_name']?[0] ?? '?',
                                    style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          store['business_name'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? const Color(0xFF8B5CF6)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (_isLoadingBanners)
          const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_bannerUrls.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _bannerUrls.length,
              itemBuilder: (context, index) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                    image: DecorationImage(
                      image: NetworkImage(_bannerUrls[index]),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    ),
                  ),
                );
              },
            ),
          ),
        if (_displayedProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Bu mağazaya ait ürün bulunamadı.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 312,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _displayedProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final dbProduct = _displayedProducts[index];
                return SizedBox(
                  width: 198,
                  child: ProductCard(product: _convertToProduct(dbProduct)),
                );
              },
            ),
          ),
      ],
    );
  }
}
