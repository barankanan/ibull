import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import '../widgets/product_card.dart';
import 'chat_page.dart';

class BusinessDetailPage extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Product>? storeProducts;

  const BusinessDetailPage({super.key, required this.business, this.storeProducts});

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;
  bool _showProductReviews = true;
  bool _isFollowing = false;
  bool _isNotificationsEnabled = false;
  String _searchQuery = '';
  bool _isLoadingProducts = false;

  late List<String> _categories;
  late List<Product> _allProducts;

  String _normalize(String s) {
    var t = s.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
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

  Future<void> _fetchStoreProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final dbHelper = DatabaseHelper.instance;
      final allDbProducts = await dbHelper.getAllProducts();
      final storeName = widget.business['name'].toString();
      
      final storeProducts = allDbProducts.where((p) {
         if (p.store == null) return false;
         // Normalize both for comparison
         return _normalize(p.store!) == _normalize(storeName) || 
                p.store!.toLowerCase().contains(storeName.toLowerCase());
      }).map((dbP) => _convertToProduct(dbP)).toList();
      
      if (mounted) {
        setState(() {
          if (storeProducts.isNotEmpty) {
            _allProducts = storeProducts;
          } else {
             // Fallback to dummy if empty
             _allProducts = [];
          }
          _categories = _extractCategories();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      print('Error fetching store products: $e');
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _allProducts;
    final query = _searchQuery.toLowerCase();
    return _allProducts.where((product) {
      return product.name.toLowerCase().contains(query) || 
             product.brand.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isFollowing = AppState().isFollowingStore(widget.business);
    
    if (widget.storeProducts != null && widget.storeProducts!.isNotEmpty) {
       _allProducts = widget.storeProducts!;
       _categories = _extractCategories();
    } else {
       _allProducts = [];
       _categories = ['Tümü'];
       _fetchStoreProducts();
    }
  }
  
  List<String> _extractCategories() {
    final categorySet = <String>{};
    
    // "Tümü" her zaman ilk sırada
    final categories = ['Tümü'];
    
    // Ürünlerden benzersiz kategorileri topla
    for (var product in _allProducts) {
      if (product.subCategory != null && product.subCategory!.isNotEmpty) {
        categorySet.add(product.subCategory!);
      } else if (product.category != null && product.category!.isNotEmpty) {
        categorySet.add(product.category!);
      }
    }
    
    // Alfabetik sırala ve listeye ekle
    categories.addAll(categorySet.toList()..sort());
    
    return categories;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.business['name'] ?? 'Mağaza';
    final businessRating = widget.business['rating']?.toString() ?? '8.2';
    final businessFollowers = widget.business['followers']?.toString() ?? '9.8B Takipçi';
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              backgroundColor: AppColors.primary,
              pinned: true,
              floating: false,
              expandedHeight: 200.0, // Reduced height to decrease gap
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.primary,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 45, // Slightly reduced top padding
                    left: 16,
                    right: 16,
                    bottom: 48, // Adjusted bottom padding
                  ),
                  child: Column(
                    children: [
                      // Business Info Row
                      Row(
                        children: [
                          // Logo (Smaller)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: ClipOval(
                              child: StoreLogoHelper.hasLogo(businessName)
                                  ? Image.asset(
                                      StoreLogoHelper.getStoreLogo(businessName)!,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Text(
                                        businessName.substring(0, 1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          
                          // Name & Rating
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        businessName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        businessRating,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  businessFollowers,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Follow Button & Bell Icon
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      AppState().toggleFollowStore(widget.business);
                                      _isFollowing = !_isFollowing;
                                      if (!_isFollowing) {
                                        _isNotificationsEnabled = false;
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing ? AppColors.primary : Colors.white,
                                    foregroundColor: _isFollowing ? Colors.white : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: _isFollowing ? Colors.white : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    _isFollowing ? 'Takiptesin' : 'Takip Et',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isFollowing) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isNotificationsEnabled = !_isNotificationsEnabled;
                                    });
                                    if (_isNotificationsEnabled) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Bildirimler açıldı'),
                                          duration: Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Icon(
                                    _isNotificationsEnabled ? Icons.notifications_active : Icons.notifications_none,
                                    color: _isNotificationsEnabled ? Colors.amber : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8), // Reduced spacing from 12 to 8
                      
                      // Search Bar & Actions Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 36, // Smaller vertically
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: 'Mağazada Ara',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0), // Centered vertically
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 13),
                                textAlignVertical: TextAlignVertical.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Chat Button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(seller: widget.business),
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Share Button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 18),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppColors.primary, // Keep purple background
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Ana Sayfa'),
                      Tab(text: 'Tüm Ürünler'),
                      Tab(text: 'Satıcı'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAnaSayfaTab(),
            _buildTumUrunlerTab(),
            _buildSaticiTab(),
          ],
        ),
      ),
    );
  }

  List<String> _getStoreBannerPaths(String storeName) {
    final name = _normalize(storeName); // Normalize edilmiş isim kullanıyoruz
    String prefix = '';
    int count = 0;

    if (name.contains('teknosa')) {
      prefix = 'teknosa';
      count = 2;
    } else if (name.contains('arcelik')) { // _normalize 'ç' yi 'c' yapar
      prefix = 'arcelik';
      count = 2;
    } else if (name.contains('lc waikiki')) {
      prefix = 'lc-waikiki';
      count = 2;
    } else if (name.contains('destina')) {
      prefix = 'destina';
      count = 2;
    } else {
      return [];
    }

    return List.generate(count, (index) {
      return 'assets/images/banners/$prefix-duyuru-${index + 1}.png';
    });
  }

  // ANA SAYFA TAB
  Widget _buildAnaSayfaTab() {
    final bannerPaths = _getStoreBannerPaths(widget.business['name'].toString());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // DUYURULAR Banner
          if (bannerPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DUYURULAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160, // Biraz yükseklik artırıldı
                    child: PageView.builder(
                      itemCount: bannerPaths.length,
                      controller: PageController(viewportFraction: 0.92), // Yanındakinin ucu görünsün
                      padEnds: false, // Sol baştan başlasın
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[200],
                            image: DecorationImage(
                              image: AssetImage(bannerPaths[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (bannerPaths.isNotEmpty) const SizedBox(height: 24),
          
          // Popüler Ürünler
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Popüler Ürünler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          _buildProductGrid(),
          const SizedBox(height: 24),
          // Telefonlar Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Telefonlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          _buildProductGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // TÜM ÜRÜNLER TAB
  Widget _buildTumUrunlerTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Category Filter Bar
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedCategoryIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Products Grid
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  // SATICI TAB
  Widget _buildSaticiTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Rozetler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rozetler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBadge(Icons.shield, 'Hızlı Kargo!', Colors.amber),
                      _buildBadge(Icons.chat_bubble, 'Hızlı Mesaj!', Colors.purple),
                      _buildBadge(Icons.message, 'Hızlı Mesaj!', Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Satıcı Videoları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Satıcı Videoları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.purple[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Kargo Süresi, Satıcı Konumu, Cevap Verme Hızı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(child: _buildInfoCard(Icons.local_shipping, 'Kargo Süresi', '5 Saat')),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(Icons.location_on, 'Satıcı Konumu', 'Hatay / Antakya')),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(Icons.chat, 'Cevap Verme Hızı', '1 Saat')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Satıcı Puanlaması
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Satıcı Puanlaması',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol taraf - Marka logosu
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            widget.business['name'] ?? 'Arçelik',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sağ taraf - Rating barları
                      Expanded(
                        child: Column(
                          children: [
                            _buildRatingBar('5 Yıldız', 310, 0.7),
                            const SizedBox(height: 8),
                            _buildRatingBar('4 Yıldız', 110, 0.3),
                            const SizedBox(height: 8),
                            _buildRatingBar('3 Yıldız', 80, 0.2),
                            const SizedBox(height: 8),
                            _buildRatingBar('2 Yıldız', 20, 0.05),
                            const SizedBox(height: 8),
                            _buildRatingBar('1 Yıldız', 60, 0.15),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Alt kısım - Toplam kişi ve ortalama puan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '580 Kişi',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            '4.2',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: List.generate(5, (index) {
                              if (index < 4) {
                                return const Icon(Icons.star, color: Colors.amber, size: 24);
                              } else {
                                return const Icon(Icons.star_half, color: Colors.amber, size: 24);
                              }
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Gelen Fotoğraflar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gelen Fotoğraflar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[300],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Ürün/Satıcı Değerlendirmeleri Butonları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showProductReviews = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showProductReviews ? AppColors.primary : Colors.white,
                      foregroundColor: _showProductReviews ? Colors.white : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Ürün Değerlendirmeleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showProductReviews = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showProductReviews ? AppColors.primary : Colors.white,
                      foregroundColor: !_showProductReviews ? Colors.white : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Satıcı Değerlendirmeleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Değerlendirmeler Listesi
          _buildReviewsList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Product Grid Widget
  Widget _buildProductGrid() {
    if (_isLoadingProducts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 0.55;
    
    // Responsive grid layout
    if (screenWidth < 360) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    } else if (screenWidth >= 600) {
      crossAxisCount = 4;
      childAspectRatio = 0.6;
    } else {
      // 3lü görünüm için ayarlar
      crossAxisCount = 3;
      // Kart yüksekliğini artırmak için oranı düşürüyoruz (eski oran 0.55 idi, overflow yapıyordu)
      // 0.48 oranı ile dikeyde daha fazla yer açıyoruz
      childAspectRatio = 0.48; 
    }
    
    // Kategori filtresi uygula
    List<Product> displayProducts = _filteredProducts;
    
    if (_selectedCategoryIndex > 0 && _selectedCategoryIndex < _categories.length) {
      final selectedCategory = _categories[_selectedCategoryIndex];
      displayProducts = _filteredProducts.where((product) {
        return (product.subCategory == selectedCategory) || 
               (product.category == selectedCategory);
      }).toList();
    }
    
    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _allProducts.isEmpty 
                  ? 'Bu mağazada henüz ürün bulunmuyor'
                  : 'Bu kategoride ürün bulunamadı',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        return ClipRect(
          child: ProductCard(
            product: product,
            compact: true,
          ),
        );
      },
    );
  }

  // Badge Widget (Rozetler için)
  Widget _buildBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
  
  // Info Card Widget (Kargo/Konum/Cevap için)
  Widget _buildInfoCard(IconData icon, String title, String subtitle) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: isSmallScreen ? 22 : 28),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // Rating Bar Widget (Puanlama için)
  Widget _buildRatingBar(String label, int count, double percentage) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 35,
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Reviews List Widget
  Widget _buildReviewsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reviews = [
          {'name': 'Süleyman K**', 'date': '10/12/2023', 'text': 'Satıcı Çok İlgili Ve Nazikti Kendisine Teşekkür Eder Ve Buradan Alışveriş Yapmanızı Tavsiye Ederimö', 'rating': 4.5},
          {'name': 'Gülşen K**', 'date': '10/12/2023', 'text': 'Hızlı Destekten Dolayı Teşekkür Ederim', 'rating': 3.0},
          {'name': 'Efe K**', 'date': '10/12/2023', 'text': 'Ürün Sorunsuz Geldi Hediye İçin Teşekkür Ederim', 'rating': 5.0},
          {'name': 'Ayşe M**', 'date': '09/12/2023', 'text': 'Çok memnun kaldım, teşekkürler', 'rating': 4.0},
          {'name': 'Mehmet Y**', 'date': '08/12/2023', 'text': 'Ürün kaliteli ve hızlı geldi', 'rating': 5.0},
        ];
        
        final review = reviews[index];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    review['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    review['date'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                review['text'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    (review['rating'] as double).toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(5, (starIndex) {
                      final rating = review['rating'] as double;
                      if (starIndex < rating.floor()) {
                        return const Icon(Icons.star, color: Colors.amber, size: 16);
                      } else if (starIndex < rating) {
                        return const Icon(Icons.star_half, color: Colors.amber, size: 16);
                      }
                      return const Icon(Icons.star_border, color: Colors.amber, size: 16);
                    }),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
