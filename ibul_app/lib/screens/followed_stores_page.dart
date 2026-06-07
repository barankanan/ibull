import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../services/database_helper.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import 'business_detail_page.dart';
import 'product_detail_page.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';

class FollowedStoresPage extends StatefulWidget {
  const FollowedStoresPage({super.key});

  @override
  State<FollowedStoresPage> createState() => _FollowedStoresPageState();
}

class _FollowedStoresPageState extends State<FollowedStoresPage> {
  Future<Map<String, List<DBProduct>>>? _storePreviewFuture;
  String _storePreviewSignature = '';
  bool _isRefreshingFollows = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshFollowedStores());
    });
  }

  Future<void> _refreshFollowedStores() async {
    if (_isRefreshingFollows) return;
    _isRefreshingFollows = true;
    final appState = AppState();
    await appState.refreshFollowedStoresFromServer();
    if (!mounted) return;
    setState(() {
      _storePreviewFuture = null;
      _storePreviewSignature = '';
      _isRefreshingFollows = false;
    });
  }

  Future<Map<String, List<DBProduct>>> _getStorePreviewFuture(
    List<Map<String, dynamic>> followedStores,
  ) {
    final signature = _buildStorePreviewSignature(followedStores);
    if (_storePreviewFuture != null && signature == _storePreviewSignature) {
      return _storePreviewFuture!;
    }

    _storePreviewSignature = signature;
    if (followedStores.isEmpty) {
      _storePreviewFuture = Future.value(const <String, List<DBProduct>>{});
      return _storePreviewFuture!;
    }

    final sellerIds = followedStores
        .map(_sellerIdOfStore)
        .where((sellerId) => sellerId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final storeNames = followedStores
        .map(_storeNameOfStore)
        .where((storeName) => storeName.isNotEmpty)
        .toSet()
        .toList(growable: false);

    _storePreviewFuture = DatabaseHelper.instance.getProductsPreviewByStores(
      sellerIds: sellerIds,
      storeNames: storeNames,
      perStoreLimit: 5,
    );
    return _storePreviewFuture!;
  }

  String _buildStorePreviewSignature(List<Map<String, dynamic>> stores) {
    final keys = stores.map(_previewKeyForStore).toList(growable: false)..sort();
    return keys.join('||');
  }

  String _sellerIdOfStore(Map<String, dynamic> store) {
    return (store['seller_id'] ?? store['sellerId'] ?? '').toString().trim();
  }

  String _storeNameOfStore(Map<String, dynamic> store) {
    return (store['name'] ?? store['business_name'] ?? '').toString().trim();
  }

  String _normalizeStoreKey(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('i̇', 'i');
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  String _previewKeyForStore(Map<String, dynamic> store) {
    final sellerId = _sellerIdOfStore(store);
    if (sellerId.isNotEmpty) return sellerId;
    return _normalizeStoreKey(_storeNameOfStore(store));
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView();
    }

    return _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}, activeMenu: 'account'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 40,
                                horizontal: 24,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 280,
                                    child: AccountSidebar(
                                      activePage: 'Takip Ettiklerim',
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    child: Consumer<AppState>(
                                      builder: (context, appState, child) {
                                        final followedStores =
                                            appState.followedStores;
                                        final previewFuture =
                                            _getStorePreviewFuture(
                                              followedStores,
                                            );
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Takip Ettiğim Mağazalar',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            if (followedStores.isEmpty)
                                              _buildEmptyState()
                                            else
                                              FutureBuilder<
                                                Map<String, List<DBProduct>>
                                              >(
                                                future: previewFuture,
                                                builder: (
                                                  context,
                                                  snapshot,
                                                ) {
                                                  final previews =
                                                      snapshot.data ??
                                                      const <String,
                                                        List<DBProduct>>{};
                                                  return ListView.separated(
                                                    shrinkWrap: true,
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount:
                                                        followedStores.length,
                                                    separatorBuilder:
                                                        (context, index) =>
                                                            const SizedBox(
                                                              height: 16,
                                                            ),
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      final store =
                                                          followedStores[index];
                                                      return _buildStoreCard(
                                                        store,
                                                        previewProducts:
                                                            previews[_previewKeyForStore(
                                                                  store,
                                                                )] ??
                                                            const <DBProduct>[],
                                                        isLoadingProducts:
                                                            snapshot.connectionState ==
                                                            ConnectionState.waiting,
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const WebFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
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
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final followedStores = appState.followedStores;
          final previewFuture = _getStorePreviewFuture(followedStores);
          return followedStores.isEmpty
              ? _buildEmptyState()
              : FutureBuilder<Map<String, List<DBProduct>>>(
                  future: previewFuture,
                  builder: (context, snapshot) {
                    final previews =
                        snapshot.data ?? const <String, List<DBProduct>>{};
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: followedStores.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final store = followedStores[index];
                        return _buildStoreCard(
                          store,
                          previewProducts:
                              previews[_previewKeyForStore(store)] ??
                              const <DBProduct>[],
                          isLoadingProducts:
                              snapshot.connectionState ==
                              ConnectionState.waiting,
                        );
                      },
                    );
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
                  color: Colors.grey.withValues(alpha: 0.1),
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

  Widget _buildStoreCard(
    Map<String, dynamic> store, {
    required List<DBProduct> previewProducts,
    required bool isLoadingProducts,
  }) {
    final storeName = store['name'] ?? 'Mağaza';
    final storeRating = store['rating']?.toString() ?? '9.0';
    final storeFollowers = store['followers']?.toString() ?? '0 Takipçi';
    final logoPath = StoreLogoHelper.getStoreLogo(storeName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 14,
                              color: Colors.green[700],
                            ),
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
                        builder: (context) =>
                            BusinessDetailPage(business: store),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.deepPurple,
                    ), // Custom purple border
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                  child: isLoadingProducts
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : previewProducts.isEmpty
                      ? Center(
                          child: Text(
                            'Ürün bulunamadı',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: previewProducts.length > 5
                              ? 5
                              : previewProducts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final product = previewProducts[index];
                            return _buildProductThumbnail(product);
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
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.image_not_supported, color: Colors.grey[300]),
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
