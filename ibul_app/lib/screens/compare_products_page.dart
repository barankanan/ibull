import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../models/product_model.dart';
import '../widgets/web_header.dart';
import 'compare_features_page.dart';
import 'compare_reviews_page.dart';
import 'compare_images_page.dart';
import '../widgets/compare_page_helpers.dart';

class CompareProductsPage extends StatefulWidget {
  const CompareProductsPage({super.key});

  @override
  State<CompareProductsPage> createState() => _CompareProductsPageState();
}

class _CompareProductsPageState extends State<CompareProductsPage> {
  // Category -> List of products (mapped to UI structure)
  Map<String, List<Map<String, dynamic>>> _categories = {};

  @override
  void initState() {
    super.initState();
    // Load products after build to access Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  void _loadProducts() {
    final appState = Provider.of<AppState>(context, listen: false);
    _applyFavorites(appState.favorites);
  }

  void _applyFavorites(List<Product> favorites) {
    final Map<String, List<Map<String, dynamic>>> newCategories = {};

    for (final product in favorites) {
      final category = product.category ?? 'Diğer';
      newCategories.putIfAbsent(category, () => []);
      newCategories[category]!.add({
        'id': product.hashCode.toString(),
        'name': product.name,
        'image': compareProductImageUrl({
          'product': product,
          'image': product.images.isNotEmpty ? product.images.first : null,
        }),
        'selected': false,
        'product': product,
      });
    }

    if (!mounted) return;
    setState(() {
      _categories = newCategories;
    });
  }

  List<Map<String, dynamic>> get _selectedProducts {
    final selected = <Map<String, dynamic>>[];
    for (final products in _categories.values) {
      selected.addAll(products.where((p) => p['selected'] == true));
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (_categories.isEmpty && appState.favorites.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _applyFavorites(appState.favorites);
            }
          });
        }

        if (isWeb) {
          return _buildWebView(context);
        }

        return _buildMobileView(context);
      },
    );
  }

  Widget _buildWebView(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (_) {}, activeMenu: 'account'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.black87,
                                ),
                                tooltip: 'Geri',
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.compare_arrows,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Beğendiğimi karşılaştır',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Seçtiğin ürünleri detaylıca kıyasla',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_categories.isEmpty)
                                          Text(
                                            'Karşılaştırma yapabilmek için lütfen en az 2 ürün beğenin.',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        else
                                          ..._categories.entries.map(
                                            (entry) => _buildCategorySection(
                                              entry.key,
                                              entry.value,
                                              useWebGrid: true,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 320,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                  color: Colors.grey.shade50,
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seçilen Ürünler (${_selectedProducts.length})',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _selectedProducts.isEmpty
                                          ? Align(
                                              alignment: Alignment.topLeft,
                                              child: Text(
                                                'Karşılaştırmak için soldan ürün seçin',
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount:
                                                  _selectedProducts.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(height: 12),
                                              itemBuilder: (context, index) {
                                                final product =
                                                    _selectedProducts[index];
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey.shade100,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: product['image'] !=
                                                                null
                                                            ? OptimizedImage(
                                                                imageUrlOrPath:
                                                                    product[
                                                                        'image'],
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : const Icon(
                                                                Icons.image,
                                                                size: 20,
                                                                color: Colors
                                                                    .grey,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          product['name'],
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                        Icons.check_circle,
                                                        color:
                                                            AppColors.primary,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Divider(),
                                    const SizedBox(height: 16),
                                    if (_categories.isEmpty)
                                      const Text(
                                        'Karşılaştırma yapabilmek için lütfen en az 2 ürün beğenin.',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    else if (_selectedProducts.length < 2)
                                      const Text(
                                        'Lütfen karşılaştırmak için listeden 2 ürün seçin.',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    else ...[
                                      _buildActionButton(
                                        'Özellikleri Karşılaştır',
                                        onTap: () {
                                          _navigateToFeaturesCompare(context);
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildActionButton(
                                        'Yorumları Karşılaştır',
                                        onTap: () {
                                          _navigateTo(
                                            context,
                                            CompareReviewsPage(
                                              products: _selectedProducts,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildActionButton(
                                        'Görselleri Karşılaştır',
                                        onTap: () {
                                          _navigateTo(
                                            context,
                                            CompareImagesPage(
                                              products: _selectedProducts,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    openCompareRoute(context, page);
  }

  void _navigateToFeaturesCompare(BuildContext context) {
    final products = compareProductsFromMaps(_selectedProducts);
    if (compareMainCategoryMismatchForProducts(products) != null) {
      showCompareCategoryMismatchSnackBar(context);
      return;
    }
    _navigateTo(
      context,
      CompareFeaturesPage(products: _selectedProducts),
    );
  }

  Widget _buildMobileView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Beğendiğimi karşılaştır',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    width: double.infinity,
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yapay Zeka Sohbet;',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.psychology,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Yapay Zeka',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Hangi ürünlerin karşılaştırılmasını istersiniz ?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categories
                  ..._categories.entries.map((entry) {
                    return _buildCategorySection(entry.key, entry.value);
                  }),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_categories.isEmpty)
                   const Padding(
                     padding: EdgeInsets.only(bottom: 8.0),
                     child: Text(
                       'Karşılaştırma yapabilmek için lütfen en az 2 ürün beğenin.',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                     ),
                   )
                else if (_selectedProducts.length < 2)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Lütfen karşılaştırmak için listeden 2 ürün seçin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  )
                else ...[
                  _buildActionButton(
                    'Ürün özellikleri karşılaştır',
                    onTap: () => _navigateToFeaturesCompare(context),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'ürün yorumları karşılaştır',
                    onTap: () {
                      openCompareRoute(
                        context,
                        CompareReviewsPage(products: _selectedProducts),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'ürün görselleri karşılaştır',
                    onTap: () {
                      openCompareRoute(
                        context,
                        CompareImagesPage(products: _selectedProducts),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<Map<String, dynamic>> products, {
    bool useWebGrid = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (useWebGrid)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (var index = 0; index < products.length; index++)
                  _buildProductCard(
                    category,
                    products[index],
                    index,
                    compactGrid: true,
                  ),
              ],
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < products.length - 1 ? 12 : 0,
                    ),
                    child: _buildProductCard(category, product, index),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    String category,
    Map<String, dynamic> product,
    int index, {
    bool compactGrid = false,
  }) {
    final isSelected = product['selected'] as bool;
    final imagePath = product['image'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _categories[category]![index]['selected'] = !isSelected;
        });
      },
      child: Container(
        width: 100,
        height: compactGrid ? 140 : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                  child: imagePath != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          child: imagePath.startsWith('http')
                              ? OptimizedImage(
                                  imageUrlOrPath: imagePath,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 80,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image,
                                        size: 30,
                                        color: Colors.grey,
                                      ),
                                )
                              : Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 80,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image,
                                        size: 30,
                                        color: Colors.grey,
                                      ),
                                ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    product['name'],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
