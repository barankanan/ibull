import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_sidebar.dart'; // Filter Sidebar importu
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
  
  // Web Scroll Controller and Keys
  final ScrollController _webScrollController = ScrollController();
  final GlobalKey _flashProductsKey = GlobalKey();
  final GlobalKey _campaignsKey = GlobalKey();
  final GlobalKey _allProductsKey = GlobalKey();
  
  String _activeWebTab = 'Ana Sayfa'; // Web tab state

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
      
      print('🏪 Mağaza Detay: "$storeName" için ürün aranıyor...');
      print('📦 Toplam Ürün Sayısı (DB): ${allDbProducts.length}');
      
      var storeProducts = allDbProducts.where((p) {
         if (p.store == null) return false;
         final productStore = p.store!;
         final isMatch = _normalize(productStore) == _normalize(storeName) || 
                productStore.toLowerCase().contains(storeName.toLowerCase());
         return isMatch;
      }).map((dbP) => _convertToProduct(dbP)).toList();
      
      // Fallback to JSON if DB yields no results
      if (storeProducts.isEmpty) {
        print('⚠️ DB\'de ürün bulunamadı, JSON\'dan manuel aranıyor...');
        try {
          final jsonString = await DefaultAssetBundle.of(context).loadString('assets/urunler.json');
          final List<dynamic> jsonList = json.decode(jsonString);
          
          final jsonProducts = jsonList.where((item) {
             final itemStore = item['magaza']?.toString() ?? '';
             return _normalize(itemStore) == _normalize(storeName) || 
                    itemStore.toLowerCase().contains(storeName.toLowerCase());
          }).map((item) {
             // Manual mapping from JSON to Product
             List<String> images = [];
             if (item['gorseller'] != null && (item['gorseller'] as List).isNotEmpty) {
               images = (item['gorseller'] as List).map((e) => e.toString()).toList();
             }
             
             List<String> tags = [];
             if (item['etiketler'] != null) {
               tags = (item['etiketler'] as List).map((e) => e.toString()).toList();
             }

             return Product(
               name: item['isim'],
               brand: item['marka'] ?? '',
               price: "${item['fiyat']} TL",
               oldPrice: item['eski_fiyat'] != null ? "${item['eski_fiyat']} TL" : null,
               rating: (item['puan'] as num).toDouble(),
               reviewCount: item['degerlendirme'] ?? 0,
               images: images,
               tags: tags,
               store: item['magaza'],
               category: item['kategori'],
               subCategory: item['alt_kategori'],
               description: item['aciklama'],
               specifications: item['ozellikler'] != null ? json.encode(item['ozellikler']) : null,
             );
          }).toList();
          
          if (jsonProducts.isNotEmpty) {
             storeProducts = jsonProducts;
             print('✅ JSON\'dan ${storeProducts.length} ürün bulundu ve yüklendi.');
          } else {
             print('❌ JSON\'da da bu mağaza için ürün bulunamadı.');
          }
        } catch (e) {
          print('Error loading JSON fallback: $e');
        }
      }
      
      print('✅ Sonuç: ${storeProducts.length} ürün listelenecek.');
      
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
    _tabController = TabController(length: 4, vsync: this);
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
    _webScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    
    if (isWeb) {
      return _buildWebLayout();
    }

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
                      Tab(text: 'Satıcı Yorumları'),
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
            _buildSellerReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    final businessName = widget.business['name'] ?? 'Mağaza';
    final businessRating = widget.business['rating']?.toString() ?? '8.2';
    final businessFollowers = widget.business['followers']?.toString() ?? '9.8B Takipçi';
    final bannerPaths = _getStoreBannerPaths(businessName);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        controller: _webScrollController,
        child: Column(
          children: [
            // 1. Üst Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      // Logo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
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
                                      color: Color(0xFFF27A1A),
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name & Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                businessName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27AE60),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  businessRating,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Text(
                                'Satıcı Profili',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.info_outline, color: Colors.white, size: 14),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Follow Button & Count
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                AppState().toggleFollowStore(widget.business);
                                _isFollowing = !_isFollowing;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFF27A1A),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              _isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            businessFollowers,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 2. Navigation Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  height: 60,
                  child: Row(
                    children: [
                      _buildWebNavLink('Keşfet', _activeWebTab == 'Keşfet'),
                      _buildWebNavLink('Ana Sayfa', _activeWebTab == 'Ana Sayfa', onTap: () {
                        setState(() => _activeWebTab = 'Ana Sayfa');
                        _webScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                      }),
                      _buildWebNavLink('Tüm Ürünler', _activeWebTab == 'Tüm Ürünler', onTap: () {
                        setState(() => _activeWebTab = 'Tüm Ürünler');
                        // Wait for layout to settle if switching tabs
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (_allProductsKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              _allProductsKey.currentContext!, 
                              duration: const Duration(milliseconds: 500), 
                              curve: Curves.easeInOut,
                              alignment: 0.0,
                            );
                          }
                        });
                      }),
                      _buildWebNavLink('Duyurular', _activeWebTab == 'Duyurular', onTap: () {
                        setState(() => _activeWebTab = 'Duyurular');
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (_flashProductsKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              _flashProductsKey.currentContext!, 
                              duration: const Duration(milliseconds: 500), 
                              curve: Curves.easeInOut,
                              alignment: 0.0,
                            );
                          }
                        });
                      }),
                      _buildWebNavLink('Satıcı', _activeWebTab == 'Satıcı', onTap: () {
                         setState(() => _activeWebTab = 'Satıcı');
                         _webScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                      }),
                      _buildWebNavLink('Satıcı Yorumları', _activeWebTab == 'Satıcı Yorumları', onTap: () {
                         setState(() => _activeWebTab = 'Satıcı Yorumları');
                         _webScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                      }),
                      const Spacer(),
                      // Search Bar
                      Container(
                        width: 300,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Mağazada ara',
                            prefixIcon: Icon(Icons.search, color: Colors.grey), // Sola eklendi, screenshotta sağda ama standart UI
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 3. Main Content
            if (_activeWebTab == 'Satıcı')
              _buildWebSellerTab()
            else if (_activeWebTab == 'Satıcı Yorumları')
              _buildWebSellerReviewsTab()
            else if (_activeWebTab == 'Tüm Ürünler')
              _buildWebAllProductsTab()
            else
              Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sidebar (Filters)
                    SizedBox(
                      width: 250,
                      child: FilterSidebar(
                        categories: _categories,
                        selectedCategoryIndex: _selectedCategoryIndex,
                        onCategorySelected: (index) {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        priceRange: const RangeValues(0, 10000), // Dummy range
                        onPriceRangeChanged: (range) {},
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Main Content Area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DUYURULAR Section
                          if (bannerPaths.isNotEmpty) ...[
                             Text(
                              'DUYURULAR',
                              key: _flashProductsKey,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 250,
                              child: PageView.builder(
                                itemCount: bannerPaths.length,
                                controller: PageController(viewportFraction: 0.95),
                                padEnds: false,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[200],
                                      image: DecorationImage(
                                        image: AssetImage(bannerPaths[index]),
                                        fit: BoxFit.cover, // Resim oranını koruyarak doldur
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 40),
                          
                          // Kampanyalar
                          Text(
                            'Kampanyalar',
                            key: _campaignsKey,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildWebCampaignCard('%10 İndirim (Marka Kampanyası)', '1 gün 11 saat')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildWebCampaignCard('2. Ürüne %5 İndirim', '1 gün 11 saat')),
                            ],
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Öne Çıkan Ürünler Grid
                           Text(
                            'Öne Çıkan Ürünler',
                            key: _allProductsKey,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          // _buildCategoryList(), // Removed as requested
                          // const SizedBox(height: 24),
                          _buildProductGrid(), // Reusing existing grid, responsive logic inside handles sizing
                          const SizedBox(height: 40),
                          
                          // Footer Features Banner
                          _buildWebFeaturesBanner(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFeaturesBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFE5D9F2), // Light purple background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFeatureItem(Icons.local_shipping_outlined, 'Ücretsiz Kargo', '150 TL üzeri'),
          _buildDivider(),
          _buildFeatureItem(Icons.verified_user_outlined, 'Güvenli Ödeme', '256-bit SSL'),
          _buildDivider(),
          _buildFeatureItem(Icons.refresh, '14 Gün İade', 'Koşulsuz iade'),
          _buildDivider(),
          _buildFeatureItem(Icons.headset_mic_outlined, '7/24 Destek', 'Canlı yardım'),
          _buildDivider(),
          _buildFeatureItem(Icons.verified_outlined, 'Orijinal Ürün', 'Garantili'),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.5),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6200EE), size: 32),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebNavLink(String title, bool isActive, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              border: isActive ? const Border(bottom: BorderSide(color: Color(0xFFF27A1A), width: 3)) : null,
            ),
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? const Color(0xFFF27A1A) : Colors.black87,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebCampaignCard(String title, String timeLeft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD8B2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(timeLeft, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
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

  // WEB ALL PRODUCTS TAB (NEW)
  Widget _buildWebAllProductsTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Store Name & Count
            Row(
              children: [
                Text(
                  widget.business['name']?.toString().toUpperCase() ?? 'MAĞAZA',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${_allProducts.length}+ Ürün",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Kategori Barı (Mağaza içi mevcut kategorilerden)
            _buildWebCategoryBar(),
            const SizedBox(height: 16),
            
            // Product Grid - Full Width
            _buildProductGrid(aspectRatioOverride: 0.68),
          ],
        ),
      ),
    );
  }

  // WEB SELLER TAB
  Widget _buildWebSellerTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildSellerStatCard(
                    icon: Icons.calendar_today,
                    title: "Trendyol'daki Süresi",
                    value: "1 Yıl",
                    color: const Color(0xFFFFF1E6),
                    iconColor: const Color(0xFFF27A1A),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSellerStatCard(
                    icon: Icons.location_on,
                    title: "Konum",
                    value: "İstanbul",
                    color: Colors.white,
                    borderColor: Colors.grey.shade200,
                    iconColor: const Color(0xFFF27A1A),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSellerStatCard(
                    icon: Icons.receipt_long,
                    title: "Kurumsal Fatura",
                    value: "Uygun",
                    color: Colors.white,
                    borderColor: Colors.grey.shade200,
                    iconColor: const Color(0xFFF27A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Middle Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildSellerStatCard(
                    icon: Icons.local_shipping_outlined,
                    title: "Ortalama Kargolama Süresi",
                    value: "17 Saat",
                    color: Colors.white,
                    borderColor: Colors.grey.shade200,
                    iconColor: Colors.grey.shade700,
                    showInfoIcon: true,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSellerStatCard(
                    icon: Icons.chat_bubble_outline,
                    title: "Soru Cevaplama Süresi",
                    value: "1-2 Saat",
                    color: Colors.white,
                    borderColor: Colors.grey.shade200,
                    iconColor: Colors.grey.shade700,
                    showInfoIcon: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Review Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  _buildReviewTabItem("Ürün Değerlendirmeleri", true),
                  const SizedBox(width: 32),
                  _buildReviewTabItem("Satıcı Değerlendirmeleri", false),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Rating Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      "4.4",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: List.generate(5, (index) {
                        if (index < 4) {
                          return const Icon(Icons.star, color: Color(0xFFFFC107), size: 28);
                        } else {
                          return const Icon(Icons.star_half, color: Color(0xFFFFC107), size: 28);
                        }
                      }),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  ],
                ),
                Row(
                  children: [
                    Text("1062767 Değerlendirme", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("•", style: TextStyle(color: Colors.grey.shade400)),
                    ),
                    Text("295101 Yorum", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text("Yorum Yayınlama Kriterleri", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Rating Filters
            const Text(
              "Puana Göre Filtrele",
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildRatingFilterChip(5, "203.5B"),
                  _buildRatingFilterChip(4, "37B"),
                  _buildRatingFilterChip(3, "22.1B"),
                  _buildRatingFilterChip(2, "9749"),
                  _buildRatingFilterChip(1, "22.9B"),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Photo Reviews
            const Text(
              "Fotoğraflı Değerlendirmeler",
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                      image: const DecorationImage(
                        image: NetworkImage("https://picsum.photos/200"), // Placeholder
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            
            // Review List
            _buildReviewsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    Color? borderColor,
    required Color iconColor,
    bool showInfoIcon = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: [
          if (borderColor == null)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (showInfoIcon) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTabItem(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isActive ? const Color(0xFFF27A1A) : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          color: isActive ? const Color(0xFFF27A1A) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildRatingFilterChip(int stars, String count) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Row(
            children: List.generate(5, (index) {
              return Icon(
                Icons.star,
                size: 14,
                color: index < stars ? const Color(0xFFFFC107) : Colors.grey.shade300,
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            "($count)",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
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

  // Kategori ikonları için yardımcı metot
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('telefon')) return Icons.phone_iphone;
    if (cat.contains('bilgisayar') || cat.contains('laptop') || cat.contains('tablet')) return Icons.laptop;
    if (cat.contains('televizyon') || cat.contains('tv')) return Icons.tv;
    if (cat.contains('beyaz eşya')) return Icons.kitchen;
    if (cat.contains('küçük ev')) return Icons.coffee_maker;
    if (cat.contains('aksesuar')) return Icons.headphones;
    if (cat.contains('giyim') || cat.contains('moda')) return Icons.checkroom;
    if (cat.contains('spor')) return Icons.fitness_center;
    if (cat.contains('kozmetik') || cat.contains('bakım')) return Icons.face;
    if (cat.contains('oyun') || cat.contains('gaming')) return Icons.sports_esports;
    return Icons.grid_view; // Varsayılan ikon
  }

  // Kategori Listesi Widget'ı
  Widget _buildCategoryList({EdgeInsetsGeometry? padding}) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _categories.where((c) => c != 'Tümü').length,
        itemBuilder: (context, index) {
          final categoryList = _categories.where((c) => c != 'Tümü').toList();
          final category = categoryList[index];
          final originalIndex = _categories.indexOf(category);
          final isSelected = _selectedCategoryIndex == originalIndex;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = originalIndex;
              });
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.purple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: isSelected ? AppColors.primary : Colors.purple.shade400,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // TÜM ÜRÜNLER TAB
  Widget _buildTumUrunlerTab() {
    return SingleChildScrollView( // Scrollable yapıldı
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Kategori Kartları (Görseldeki gibi)
          _buildCategoryList(padding: const EdgeInsets.symmetric(horizontal: 16)),
          const SizedBox(height: 24),
          // Products Grid
          _buildProductGrid(),
          const SizedBox(height: 24),
        ],
      ),
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
  Widget _buildProductGrid({double? aspectRatioOverride}) {
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
      childAspectRatio = 0.58; // Home Page aspect ratio for Web
    } else {
      // 3lü görünüm için ayarlar
      crossAxisCount = 3;
      // Kart yüksekliğini artırmak için oranı düşürüyoruz (eski oran 0.55 idi, overflow yapıyordu)
      // 0.48 oranı ile dikeyde daha fazla yer açıyoruz
      childAspectRatio = 0.4; 
    }
    
    // Override aspect ratio if provided (e.g., Tüm Ürünler dikey azaltma)
    if (aspectRatioOverride != null) {
      childAspectRatio = aspectRatioOverride;
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
        crossAxisSpacing: 16, // Increased spacing to match Home Page
        mainAxisSpacing: 16, // Increased spacing to match Home Page
        childAspectRatio: childAspectRatio,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        final normalized = product.tags.isEmpty 
            ? product.copyWith(tags: ['Ücretsiz Kargo']) 
            : product;
        return ProductCard(product: normalized);
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

  // WEB: Kategori Barı (Tümü + çıkarılan kategoriler)
  Widget _buildWebCategoryBar() {
    final categories = _categories; // 'Tümü' + benzersiz alt kategoriler
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(categories.length, (i) {
            final isSelected = _selectedCategoryIndex == i;
            final label = categories[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = i;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // Seller Reviews Data
  final List<Map<String, dynamic>> _sellerReviews = [
    {
      'userName': 'Ahmet Y.',
      'date': '12/10/2023',
      'reviewText': 'Hızlı kargo ve özenli paketleme için teşekkürler.',
      'rating': 5.0,
    },
    {
      'userName': 'Mehmet K.',
      'date': '05/10/2023',
      'reviewText': 'Ürün anlatıldığı gibiydi, satıcı ilgili.',
      'rating': 4.0,
    },
    {
      'userName': 'Ayşe S.',
      'date': '01/10/2023',
      'reviewText': 'Kargo biraz gecikti ama ürün güzel.',
      'rating': 3.0,
    },
  ];

  Widget _buildSellerReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    const Text(
                      '4.5',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF27A1A),
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) => const Icon(Icons.star, color: Color(0xFFF27A1A), size: 16)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_sellerReviews.length} Değerlendirme',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildSellerRatingBar(5, 0.7),
                      _buildSellerRatingBar(4, 0.2),
                      _buildSellerRatingBar(3, 0.1),
                      _buildSellerRatingBar(2, 0.0),
                      _buildSellerRatingBar(1, 0.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Değerlendirmeler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ..._sellerReviews.map((review) => _buildSellerReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildWebSellerReviewsTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text(
              'Satıcı Değerlendirmeleri',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildSellerReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerRatingBar(int star, double percentage) {
    return Row(
      children: [
        Text('$star', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        const Icon(Icons.star, size: 12, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF27A1A)),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Text(review['userName'][0], style: const TextStyle(color: Colors.black87)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review['userName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review['rating'] ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              Text(review['date'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(review['reviewText'], style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}
