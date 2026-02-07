import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'compare_features_page.dart';
import 'compare_reviews_page.dart';
import 'compare_images_page.dart';

class CompareProductsPage extends StatefulWidget {
  const CompareProductsPage({super.key});

  @override
  State<CompareProductsPage> createState() => _CompareProductsPageState();
}

class _CompareProductsPageState extends State<CompareProductsPage> {
  final Map<String, List<Map<String, dynamic>>> _categories = {
    'Isıtıcılar': [
      {
        'id': '1',
        'name': 'Ufo S/2400 W Duv..',
        'image': null,
        'selected': false,
      },
      {
        'id': '2',
        'name': 'Kumtel Ex-25-25..',
        'image': null,
        'selected': false,
      },
    ],
    'Bilgisayar': [
      {
        'id': '3',
        'name': 'Gamer oyuncu',
        'image': null,
        'selected': false,
      },
      {
        'id': '4',
        'name': 'Notebook bilgisay..',
        'image': null,
        'selected': false,
      },
      {
        'id': '5',
        'name': 'Dizüstü bilgisayar..',
        'image': null,
        'selected': false,
      },
    ],
    'Süpürge': [
      {
        'id': '6',
        'name': 'freelander bi 655..',
        'image': null,
        'selected': false,
      },
      {
        'id': '7',
        'name': 'korkmaz temprati..',
        'image': null,
        'selected': false,
      },
      {
        'id': '8',
        'name': 'fonton eco tr 87..',
        'image': null,
        'selected': false,
      },
      {
        'id': '9',
        'name': 'karaca clean slim..',
        'image': null,
        'selected': false,
      },
    ],
  };

  List<Map<String, dynamic>> get _selectedProducts {
    List<Map<String, dynamic>> selected = [];
    _categories.forEach((category, products) {
      selected.addAll(products.where((p) => p['selected'] == true));
    });
    return selected;
  }

  @override
  Widget build(BuildContext context) {
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
                                color: AppColors.primary.withOpacity(0.1),
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
                  }).toList(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          if (_selectedProducts.length >= 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    'Ürün özellikleri karşılaştır',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompareFeaturesPage(
                            products: _selectedProducts,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'ürün yorumları karşılaştır',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompareReviewsPage(
                            products: _selectedProducts,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    'ürün görselleri karşılaştır',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompareImagesPage(
                            products: _selectedProducts,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> products) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < products.length - 1 ? 12 : 0),
                  child: _buildProductCard(category, product, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(String category, Map<String, dynamic> product, int index) {
    final isSelected = product['selected'] as bool;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _categories[category]![index]['selected'] = !isSelected;
        });
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Image
            Stack(
              children: [
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Center(
                    child: product['image'] != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            child: Image.network(
                              product['image'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : const Icon(Icons.image, size: 30, color: Colors.grey),
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
                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
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
            // Name
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
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
