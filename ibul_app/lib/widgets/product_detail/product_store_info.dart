import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/store_logo_helper.dart';
import '../../core/app_state.dart';
import '../../screens/business_detail_page.dart';
import '../../screens/chat_page.dart';

Widget _storeLetter(String storeName) {
  return Text(
    storeName.isNotEmpty ? storeName[0].toUpperCase() : 'T',
    style: const TextStyle(
      color: Color(0xFFFF6B35),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );
}

class ProductStoreInfo extends StatelessWidget {
  const ProductStoreInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final product = context.select<ProductDetailViewModel, dynamic>(
      (viewModel) => viewModel.initialProduct,
    );
    final storeName = context.select<ProductDetailViewModel, String>(
      (viewModel) => viewModel.storeName,
    );
    final storeLogoUrl = context.select<ProductDetailViewModel, String?>(
      (viewModel) => viewModel.storeLogoUrl,
    );
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // Create a business object that matches AppState structure
    final business = <String, dynamic>{
      'id': storeName, // Using name as ID for now
      'name': storeName,
      'logo': 'assets/images/teknosa_logo.png', // Placeholder or use helper
      'rating': '9.0',
      'followers': '',
      'verified': true,
    };

    final isFollowing = context.select<AppState, bool>(
      (appState) => appState.isFollowingStore(business),
    );

    return isMobile
        ? _buildMobileLayout(
            context,
            storeName,
            business,
            product,
            storeLogoUrl,
            isFollowing,
          )
        : _buildDesktopLayout(
            context,
            storeName,
            business,
            product,
            storeLogoUrl,
            isFollowing,
          );
  }

  // Mobil için kompakt yatay tasarım
  Widget _buildMobileLayout(
    BuildContext context,
    String storeName,
    Map<String, dynamic> business,
    dynamic product,
    String? storeLogoUrl,
    bool isFollowing,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Tek satır: Logo, İsim, Badge, Puan, Butonlar
          Row(
            children: [
              // Logo - kompakt
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BusinessDetailPage(business: business),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: _buildStoreLogo(
                    storeName: storeName,
                    storeLogoUrl: storeLogoUrl?.isNotEmpty == true
                        ? storeLogoUrl
                        : null,
                    padding: EdgeInsets.zero,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // İsim + Verified Badge
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BusinessDetailPage(business: business),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '9.8',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.verified, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Takip Et Butonu - Küçük
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () {
                    context.read<AppState>().toggleFollowStore(business);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isFollowing
                        ? Colors.grey
                        : const Color(0xFF673AB7),
                    backgroundColor: isFollowing ? Colors.grey.shade100 : null,
                    side: BorderSide(
                      color: isFollowing
                          ? Colors.grey.shade300
                          : const Color(0xFF673AB7),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isFollowing ? Colors.grey.shade600 : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Satıcıya Sor Butonu - Küçük
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          seller: {
                            'id': storeName,
                            'name': storeName,
                            'logo': storeName.isNotEmpty
                                ? storeName[0].toUpperCase()
                                : 'S',
                          },
                          product: {
                            'name': product.name,
                            'image': product.images.isNotEmpty
                                ? product.images[0]
                                : null,
                            'rating': product.rating.toString(),
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Satıcıya Sor',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Desktop için eski tasarım (değişmeden kalacak)
  Widget _buildDesktopLayout(
    BuildContext context,
    String storeName,
    Map<String, dynamic> business,
    dynamic product,
    String? storeLogoUrl,
    bool isFollowing,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessDetailPage(business: business),
                ),
              );
            },
            child: Row(
              children: [
                // Logo Area
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  alignment: Alignment.center,
                  child: _buildStoreLogo(
                    storeName: storeName,
                    storeLogoUrl: storeLogoUrl?.isNotEmpty == true
                        ? storeLogoUrl
                        : null,
                    padding: EdgeInsets.zero,
                    size: 48,
                    fallback: Text(
                      storeName.isNotEmpty ? storeName[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        color: Color(0xFF673AB7),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name & Verification
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              storeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '9.8',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mağaza Puanı',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<AppState>().toggleFollowStore(business);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isFollowing
                          ? Colors.grey
                          : const Color(0xFF673AB7),
                      backgroundColor: isFollowing
                          ? Colors.grey.shade100
                          : null,
                      side: BorderSide(
                        color: isFollowing
                            ? Colors.grey.shade300
                            : const Color(0xFF673AB7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isFollowing ? Colors.grey.shade600 : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            seller: {
                              'id': storeName,
                              'name': storeName,
                              'logo': storeName.isNotEmpty
                                  ? storeName[0].toUpperCase()
                                  : 'S',
                            },
                            product: {
                              'name': product.name,
                              'image': product.images.isNotEmpty
                                  ? product.images[0]
                                  : null,
                              'rating': product.rating.toString(),
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF673AB7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Satıcıya Sor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreLogo({
    required String storeName,
    required String? storeLogoUrl,
    required EdgeInsets padding,
    double size = 32,
    Widget? fallback,
  }) {
    final letterFallback = fallback ?? _storeLetter(storeName);

    if (storeLogoUrl != null && storeLogoUrl.isNotEmpty) {
      return Padding(
        padding: padding,
        child: OptimizedImage(
          imageUrlOrPath: storeLogoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => letterFallback,
        ),
      );
    }

    final assetLogoPath = StoreLogoHelper.getStoreLogo(storeName);
    if (assetLogoPath != null) {
      return Padding(
        padding: padding,
        child: Image.asset(
          assetLogoPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Padding(padding: padding, child: letterFallback);
  }
}
