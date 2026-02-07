import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'compare_features_page.dart';

/// Ürün parçaları seçim sayfası - hasarlı 2. el ürünler için
class PartsSelectionPage extends StatefulWidget {
  final String productName;
  final String productImage;

  const PartsSelectionPage({
    super.key,
    required this.productName,
    required this.productImage,
  });

  @override
  State<PartsSelectionPage> createState() => _PartsSelectionPageState();
}

class _PartsSelectionPageState extends State<PartsSelectionPage> {
  // Track favorite parts by index
  final Set<int> _favoriteParts = {};
  
  // Track selected parts for comparison (max 2)
  final Set<int> _selectedForComparison = {};
  
  // Dummy parts data
  final List<Map<String, dynamic>> _parts = [
    {
      'name': 'Apple iPhone 12 uyumlu Lcd Ekran dok...',
      'image': 'https://via.placeholder.com/200x300.png?text=LCD+Screen',
      'price': '800 TL',
      'rating': 4.0,
      'reviews': 4,
      'badge': 'Ücretsiz Kargo',
      'stores': 3,
    },
    {
      'name': 'Kahverengi Ceket',
      'image': 'https://via.placeholder.com/200x300.png?text=Back+Cover',
      'price': '599 TL',
      'rating': 4.0,
      'reviews': 4,
      'badge': 'Ücretsiz Kargo',
      'stores': 3,
    },
    {
      'name': 'Mavi Kot Ceket',
      'image': 'https://via.placeholder.com/200x300.png?text=Battery',
      'price': '200 TL',
      'rating': 4.0,
      'reviews': 4,
      'badge': 'Ücretsiz Kargo',
      'stores': 3,
    },
    {
      'name': 'Kamera Modülü',
      'image': 'https://via.placeholder.com/200x300.png?text=Camera',
      'price': '450 TL',
      'rating': 4.5,
      'reviews': 8,
      'badge': 'Ücretsiz Kargo',
      'stores': 5,
    },
    {
      'name': 'Şarj Soketi',
      'image': 'https://via.placeholder.com/200x300.png?text=Charging+Port',
      'price': '150 TL',
      'rating': 4.0,
      'reviews': 3,
      'badge': 'Ücretsiz Kargo',
      'stores': 4,
    },
    {
      'name': 'Hoparlör',
      'image': 'https://via.placeholder.com/200x300.png?text=Speaker',
      'price': '120 TL',
      'rating': 3.5,
      'reviews': 2,
      'badge': 'Ücretsiz Kargo',
      'stores': 2,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Product Info Section
          _buildProductInfo(),
          
          // Filter/Sort Buttons
          _buildFilterSection(),
          
          // Parts Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _parts.length,
              itemBuilder: (context, index) {
                return _buildPartCard(_parts[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 8,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Parça Seç',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.productImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.phone_iphone, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoBadge(Icons.screen_share, 'Ekran'),
                const SizedBox(height: 4),
                _buildInfoBadge(Icons.share, 'Paylaş'),
                const SizedBox(height: 4),
                _buildInfoBadge(Icons.copy, 'Kopyala'),
              ],
            ),
          ),
          
          // Alarm Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alarm, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(Icons.filter_list, 'Filtrele'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedForComparison.length == 2) {
                  // Navigate to comparison page
                  final selectedParts = _selectedForComparison.map((i) => _parts[i]).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CompareFeaturesPage(products: selectedParts),
                    ),
                  );
                }
              },
              child: _buildFilterButton(
                Icons.compare_arrows,
                _selectedForComparison.isEmpty
                    ? 'Karşılaştır'
                    : 'Karşılaştır (${_selectedForComparison.length})',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton(Icons.arrow_downward, 'Sırala'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartCard(Map<String, dynamic> part, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectedForComparison.contains(index)
              ? AppColors.primary
              : Colors.grey.shade200,
          width: _selectedForComparison.contains(index) ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.network(
                      part['image'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 30, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // Selection button (top-left)
              Positioned(
                top: 4,
                left: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedForComparison.contains(index)) {
                        _selectedForComparison.remove(index);
                      } else {
                        if (_selectedForComparison.length < 2) {
                          _selectedForComparison.add(index);
                        }
                      }
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _selectedForComparison.contains(index)
                          ? Colors.green
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedForComparison.contains(index)
                            ? Colors.green
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _selectedForComparison.contains(index)
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ),
              ),
              // Favorite button (top-right)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_favoriteParts.contains(index)) {
                        _favoriteParts.remove(index);
                      } else {
                        _favoriteParts.add(index);
                      }
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _favoriteParts.contains(index)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping, color: Colors.white, size: 8),
                              const SizedBox(width: 2),
                              Text(
                                part['badge'],
                                style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, Colors.blue.shade300],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.store, color: Colors.white, size: 8),
                              const SizedBox(width: 2),
                              Text(
                                '${part['stores']}',
                                style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    part['name'],
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),

                  // Rating
                  Row(
                    children: [
                      ...List.generate(
                        4,
                        (index) => Icon(
                          index < part['rating'].floor() ? Icons.star : Icons.star_border,
                          color: Colors.orange,
                          size: 10,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.photo_library, color: AppColors.primary, size: 9),
                      const SizedBox(width: 1),
                      Text(
                        '(${part['reviews']})',
                        style: const TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Price
                  Text(
                    part['price'],
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 4),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 26,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Parçayı Ekle',
                        style: TextStyle(fontSize: 9, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
