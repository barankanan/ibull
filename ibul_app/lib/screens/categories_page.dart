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

  // Shared layout tokens — top bar + sub-category grid use the same rhythm.
  static const double _topBarHeight = 104;
  static const double _topItemWidth = 76;
  static const double _topIconSize = 52;
  static const double _topIconRadius = 16;
  static const double _topItemSpacing = 4;
  /// Two-line label slot: fontSize 11 × height 1.15 × 2 lines ≈ 25.3 → 26.
  static const double _topLabelHeight = 26;
  static const double _topBarPaddingV = 6;
  static const double _topIconLabelGap = 5;
  static const double _subGridSpacing = 8;
  static const double _subCardRadius = 12;
  static const double _subImageRadius = 8;
  static const double _pagePaddingH = 12;
  static const double _pagePaddingV = 10;

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
      backgroundColor: AppColors.background,
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
      return const SizedBox(height: _topBarHeight);
    }

    return Container(
      height: _topBarHeight,
      color: AppColors.background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryTree.length,
        padding: const EdgeInsets.symmetric(
          horizontal: _pagePaddingH,
          vertical: _topBarPaddingV,
        ),
        cacheExtent: 300,
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(width: _topItemSpacing),
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index;
          final category = _categoryTree[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
            },
            child: SizedBox(
              width: _topItemWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_topIconRadius + 4),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.14),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Container(
                      width: _topIconSize,
                      height: _topIconSize,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(_topIconRadius),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildCategoryBarImage(category),
                    ),
                  ),
                  const SizedBox(height: _topIconLabelGap),
                  SizedBox(
                    height: _topLabelHeight,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? AppColors.primary : AppColors.textDark,
                        height: 1.15,
                      ),
                      child: Text(
                        category.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        strutStyle: const StrutStyle(
                          fontSize: 11,
                          height: 1.15,
                          forceStrutHeight: true,
                        ),
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

  SliverGridDelegate _subCategoryGridDelegate(double maxWidth) {
    const aspectRatio = 0.78;
    if (maxWidth > 900) {
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 118,
        crossAxisSpacing: _subGridSpacing,
        mainAxisSpacing: _subGridSpacing,
        childAspectRatio: aspectRatio,
      );
    }

    final crossAxisCount = maxWidth >= 380 ? 4 : 3;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: _subGridSpacing,
      mainAxisSpacing: _subGridSpacing,
      childAspectRatio: aspectRatio,
    );
  }

  Widget _buildSubCategoryTile({
    required MobileCategoryNode subCategory,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_subCardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_subCardRadius),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_subImageRadius),
                    child: _buildSubCategoryImage(subCategory),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subCategory.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedGridView(MobileCategoryNode category) {
    final items = category.subCategories;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridDelegate = _subCategoryGridDelegate(constraints.maxWidth);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            _pagePaddingH,
            _pagePaddingV,
            _pagePaddingH,
            16,
          ),
          children: [
            Text(
              category.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(_subCardRadius),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Bu kategori için henüz alt kategori bulunmuyor.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: gridDelegate,
                itemBuilder: (context, i) {
                  final subCategory = items[i];
                  return _buildSubCategoryTile(
                    subCategory: subCategory,
                    onTap: () =>
                        _showCategoryProducts(category.name, subCategory.name),
                  );
                },
              ),
          ],
        );
      },
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
