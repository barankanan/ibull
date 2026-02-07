import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../services/database_helper.dart';
import '../models/db_product.dart';
import '../models/product_model.dart'; // Added this import
import 'business_detail_page.dart';
import 'product_detail_page.dart';

class FollowedStoresPage extends StatefulWidget {
  const FollowedStoresPage({super.key});

  @override
  State<FollowedStoresPage> createState() => _FollowedStoresPageState();
}

class _FollowedStoresPageState extends State<FollowedStoresPage> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Takip Ettiklerim',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _appState.followedStoresNotifier,
        builder: (context, followedStores, child) {
          return followedStores.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: followedStores.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildStoreCard(followedStores[index]);
                  },
                );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.store_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz Takip Ettiğiniz Mağaza Yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Beğendiğiniz mağazaları takip ederek özel tekliflerden haberdar olun',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Mağazaları Keşfet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final storeName = store['name'] ?? 'Mağaza';
    final storeRating = store['rating']?.toString() ?? '9.0';
    final storeFollowers = store['followers']?.toString() ?? '12,7B Takipçi';
    final logoPath = StoreLogoHelper.getStoreLogo(storeName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[200]!),
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: logoPath != null
                        ? Image.asset(logoPath, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              storeName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              storeRating,
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
                      Text(
                        storeFollowers,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping, size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Hızlı Satıcı',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Button
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessDetailPage(business: store),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.deepPurple), // Custom purple border
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Mağazaya Git',
                    style: TextStyle(
                      color: Colors.deepPurple, // Custom purple text
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Divider(height: 1, color: Colors.grey[200]),
          
          // Products Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Satıcının Ürünleri',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Product List
                SizedBox(
                  height: 100,
                  child: FutureBuilder<List<DBProduct>>(
                    future: DatabaseHelper.instance.getProductsByStore(storeName),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      
                      final products = snapshot.data ?? [];
                      
                      if (products.isEmpty) {
                        return Center(
                          child: Text(
                            'Ürün bulunamadı',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        );
                      }
                      
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        itemCount: products.length > 5 ? 5 : products.length, // Limit to 5 items
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildProductThumbnail(product);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(DBProduct product) {
    return GestureDetector(
      onTap: () {
        final p = product.toProduct();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: p),
          ),
        );
      },
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              product.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.image_not_supported,
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to convert DBProduct to Product model
extension DBProductToDomain on DBProduct {
  Product toProduct() {
    return Product(
      name: name,
      brand: brand,
      price: price,
      rating: rating,
      reviewCount: reviewCount,
      tags: [], 
      images: [imageUrl],
      description: description,
      // Add other fields if necessary
    );
  }
}
