import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../core/constants.dart';
import '../core/store_logo_helper.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../services/database_helper.dart';
import '../widgets/address_bar.dart';
import 'business_detail_page.dart';
import 'dart:convert';

class MarketListPage extends StatefulWidget {
  const MarketListPage({super.key});

  @override
  State<MarketListPage> createState() => _MarketListPageState();
}

class _MarketListPageState extends State<MarketListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<DBProduct> _allProducts = [];
  bool _isLoading = true;

  // Market Kategorileri (Screenshot'a göre)
  final List<Map<String, dynamic>> _marketCategories = [
    {'name': 'Donmuş Gıda', 'icon': '🍕', 'color': Color(0xFFE3F2FD)},
    {'name': 'Manav', 'icon': '🥦', 'color': Color(0xFFE8F5E9)},
    {'name': 'Fırın', 'icon': '🥖', 'color': Color(0xFFFFF3E0)},
    {'name': 'Bakliyat', 'icon': '🫘', 'color': Color(0xFFF3E5F5)},
    {'name': 'Temizlik & Kişisel', 'icon': '🧼', 'color': Color(0xFFE0F7FA)},
    {'name': 'Sos & Baharat', 'icon': '🌶️', 'color': Color(0xFFFFEBEE)},
    {'name': 'Bebek', 'icon': '👶', 'color': Color(0xFFF3E5F5)},
    {'name': 'Kırtasiye', 'icon': '✏️', 'color': Color(0xFFE1F5FE)},
    {'name': 'İçecek', 'icon': '🥤', 'color': Color(0xFFECEFF1)},
    {'name': 'Et & Tavuk', 'icon': '🥩', 'color': Color(0xFFFFEBEE)},
    {'name': 'Kahvaltılık', 'icon': '🧀', 'color': Color(0xFFFFF8E1)},
    {'name': 'Abur Cubur', 'icon': '🍿', 'color': Color(0xFFFFF3E0)},
  ];

  // Market Verileri (Screenshot'a göre)
  final List<Map<String, dynamic>> _markets = [
    {
      'name': 'A101',
      'logo': 'assets/logos/a101.png', // Logo helper handle edecek
      'distance': '100m Uzaklıkta',
      'deliveryTime': '10 Dk İçerisinde Teslim',
      'rating': 4.5,
      'isOpen': true,
      'hasBadge': true,
      'cameraCount': 12,
      'color': Colors.teal, // Logo fallback rengi
    },
    {
      'name': 'ŞOK',
      'logo': 'assets/logos/sok.png',
      'distance': '350m Uzaklıkta',
      'deliveryTime': '10 Dk İçerisinde Teslim',
      'rating': 4.5, 
      'isOpen': true,
      'hasBadge': false,
      'cameraCount': 0,
      'color': Colors.yellow[700],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _allProducts = await _dbHelper.getAllProducts();
    } catch (e) {
      print('Ürünler yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
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
      } catch (e) {
        if (dbProduct.imageUrl.isNotEmpty) images.add(dbProduct.imageUrl);
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }
    
    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags.split('|').map<String>((e) => e.toString().trim()).toList();
    }

    return Product(
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
    );
  }

  void _showMarketProducts(String market) {
    final filteredProducts = _allProducts.where((product) {
      return product.store?.toLowerCase() == market.toLowerCase();
    }).toList();
    
    final products = filteredProducts.map((dbProduct) => _convertToProduct(dbProduct)).toList();

    final business = {
      'name': market,
      'logo': StoreLogoHelper.getStoreLogo(market),
      'followerCount': '1.2M', // Dummy
      'rating': 4.5, // Dummy
    };
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessDetailPage(
          business: business,
          storeProducts: products,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (Back, Search, Filter)
            _buildHeader(),
            
            // 2. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address Bar
                    const AddressBar(),
                    
                    const SizedBox(height: 16),
                    
                    // Banner Slider
                    _buildBannerSlider(),
                    
                    const SizedBox(height: 24),
                    
                    // Categories Grid
                    _buildCategoriesGrid(),
                    
                    const SizedBox(height: 24),
                    
                    // Marketler Section
                    _buildMarketList(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // Back Button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          // Search Bar
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Market ürünleri ara',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.mic, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter Button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 20),
              onPressed: () {},
              padding: EdgeInsets.zero,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    return CarouselSlider(
      options: CarouselOptions(
        height: 110,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        viewportFraction: 0.9,
        enlargeCenterPage: true,
        aspectRatio: 2.5,
      ),
      items: [
        'assets/images/market_banner.png', // Placeholder
      ].map((imagePath) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF4A4E69), // Dark blue-ish bg like screenshot
              ),
              child: Stack(
                children: [
                  // Background Pattern/Image
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4A4E69), Color(0xFF22223B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Text Content
                  Positioned(
                    right: 20,
                    top: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'SÜPER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'HIZLI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'SÜPER İNDİRİM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Left Image (Placeholder illustration)
                  Positioned(
                    left: 20,
                    bottom: 0,
                    top: 10,
                    child: Icon(Icons.shopping_cart, size: 80, color: Colors.white.withOpacity(0.2)),
                  ),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _marketCategories.length,
        itemBuilder: (context, index) {
          final category = _marketCategories[index];
          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: category['color'] ?? Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    // Yemek sayfasında shadow yok, burada da kaldırdık
                  ),
                  child: Center(
                    child: Text(
                      category['icon'],
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category['name'],
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMarketList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Marketler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'sponsorlu',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _markets.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildMarketCard(_markets[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCard(Map<String, dynamic> market) {
    return GestureDetector(
      onTap: () => _showMarketProducts(market['name']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: market['color'] ?? Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: StoreLogoHelper.hasLogo(market['name'])
                  ? Image.asset(
                      StoreLogoHelper.getStoreLogo(market['name'])!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          market['name'][0],
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      },
                    )
                  : Text(
                      market['name'][0],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            // Right: Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name + Badges + Open/Closed
                  Row(
                    children: [
                      Text(
                        market['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (market['hasBadge'] == true)
                        const Icon(Icons.verified, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_shipping, size: 16, color: AppColors.primary),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: market['isOpen'] ? Colors.green : Colors.red,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          market['isOpen'] ? 'AÇIK' : 'KAPALI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: market['isOpen'] ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: Distance
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        market['distance'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Row 3: Delivery Time
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        market['deliveryTime'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 4: Buttons
                  Row(
                    children: [
                      // Start Shopping Button
                      Expanded(
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Alışverişe Başla',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Rating Badge
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              market['rating'].toString(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Camera Badge
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt, size: 14, color: AppColors.primary),
                            if (market['cameraCount'] > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '+${market['cameraCount']}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
