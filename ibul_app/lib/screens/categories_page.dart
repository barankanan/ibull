import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../core/mobile_category_catalog.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import 'search_results_page.dart';
import 'market_list_page.dart';
import 'category_products_page.dart';
import '../widgets/custom_header.dart'; // CustomHeader eklendi

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  static const Set<String> _hiddenMobileCategories = {'Yakın Lokasyon'};
  int _selectedIndex = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  List<MobileCategoryNode> _categoryTree = const [];
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final categories = await _dbHelper.getCategoriesWithSubs();
      if (!mounted) return;
      setState(() {
        _categoryTree = buildMobileCategoryTree(
          categories,
          includeUnmatchedMainCategories: false,
          includeMissingDefaultCategories: true,
          excludedNames: _hiddenMobileCategories,
        );
        if (_selectedIndex >= _categoryTree.length) {
          _selectedIndex = 0;
        }
      });
    } catch (e) {
      debugPrint('Kategori agaci yuklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _categoryTree = buildMobileCategoryTree(
          const [],
          includeUnmatchedMainCategories: false,
          includeMissingDefaultCategories: true,
          excludedNames: _hiddenMobileCategories,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSubCategoryImage(MobileCategoryNode category) {
    final fallback = Icon(
      iconDataForCategoryName(category.iconName),
      color: Colors.grey[600],
      size: 30,
    );

    if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
      return OptimizedImage(imageUrlOrPath: 
        category.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildAssetFallback(category.fallbackAssetPath, fallback),
      );
    }

    return _buildAssetFallback(category.fallbackAssetPath, fallback);
  }

  Widget _buildCategoryBarImage(MobileCategoryNode category) {
    final fallback = Icon(
      iconDataForCategoryName(category.iconName),
      color: Colors.white,
      size: 26,
    );

    if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
      return OptimizedImage(imageUrlOrPath: 
        category.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildAssetFallback(category.fallbackAssetPath, fallback),
      );
    }

    return _buildAssetFallback(category.fallbackAssetPath, fallback);
  }

  Widget _buildAssetFallback(String? assetPath, Widget fallback) {
    if (assetPath == null || assetPath.isEmpty) {
      return fallback;
    }

    return Image.asset(
      assetPath,
      package: 'ibul_app',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
  
  Product _convertToProduct(DBProduct dbProduct) {
    // Görselleri parse et
    List<String> images = [];
    
    // imageUrls JSON array ise decode et
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // JSON decode başarısız olursa imageUrl kullan
        if (dbProduct.imageUrl.isNotEmpty) {
          images.add(dbProduct.imageUrl);
        }
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }
    
    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags.split('|').map<String>((e) => e.toString().trim()).toList();
    }

    return Product(
      productId: dbProduct.id,
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
    );
  }
  
  // Mappings for specific icons or dummy images could be added here
  // For now we will use generic icons or text avatars

  void _onSearch(String query) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchResultsPage(query: query),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Custom Header Entegrasyonu
                CustomHeader(
                  onSearch: _onSearch,
                ),
                const Divider(height: 1),
                _buildTopCategoryBar(),
                const Divider(height: 1),
                Expanded(
                  child: _buildBodyContent(),
                ),
              ],
            ),
            if (_isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.72),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoryBar() {
    if (_categoryTree.isEmpty) {
      return const SizedBox(height: 132);
    }

    return SizedBox(
      height: 132,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryTree.length,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        cacheExtent: 300,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index;
          final category = _categoryTree[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
            },
            child: Container(
              width: 94,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2.5)
                          : null,
                    ),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildCategoryBarImage(category),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isSelected ? 1 : 0,
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
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

  Widget _buildBodyContent() {
    // Smooth transition
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _getContentForIndex(_selectedIndex),
    );
  }

  Widget _getContentForIndex(int index) {
    if (_categoryTree.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = index.clamp(0, _categoryTree.length - 1);
    final category = _categoryTree[safeIndex];
    return _buildUnifiedGridView(category);
  }

  Widget _buildUnifiedGridView(MobileCategoryNode category) {
    final items = category.subCategories;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          category.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text('Bu kategori için henüz alt kategori bulunmuyor.'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
            itemBuilder: (context, i) {
              final subCategory = items[i];
              return GestureDetector(
                onTap: () {
                  _showCategoryProducts(category.name, subCategory.name);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 62,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildSubCategoryImage(subCategory),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subCategory.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
  
  Future<void> _showCategoryProducts(String category, String subCategory) async {
    // Yakın Lokasyon - Market için özel sayfa
    if (category == "Yakın Lokasyon" && subCategory == "Market") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MarketListPage()),
      );
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final page = await _dbHelper.getCategoryProductsPaged(
        category: category,
        subCategory: subCategory == "HEPSİ" ? null : subCategory,
        limit: 120,
      );
      if (!mounted) return;

      final products = page.items
          .map((dbProduct) => _convertToProduct(dbProduct))
          .toList(growable: false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryProductsPage(
            category: category,
            subCategory: subCategory,
            products: products,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Kategori ürünleri yüklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
