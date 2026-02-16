import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/database_helper.dart';
import '../../models/db_product.dart';
import 'advanced_filter_drawer.dart';

class SearchOverlay extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onClose;
  final bool showFilters;

  const SearchOverlay({
    super.key,
    required this.onSearch,
    this.onClose,
    this.showFilters = false,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  List<DBProduct> _recentProducts = [];
  bool _isLoading = true;
  late bool _showFilters;

  @override
  void initState() {
    super.initState();
    _showFilters = widget.showFilters;
    _loadRecentProducts();
  }

  Future<void> _loadRecentProducts() async {
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      // Take first 3 products as "recent" for now
      if (mounted) {
        setState(() {
          _recentProducts = products.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading recent products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: History & Popular
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Geçmiş aramaların', 'Temizle'),
                                const SizedBox(height: 16),
                                _buildHistoryItem('iphone 15'),
                                _buildHistoryItem('apple watch'),
                                _buildHistoryItem('boy aynası'),
                                _buildHistoryItem('kablosuz kulaklık'),
                                
                                const SizedBox(height: 32),
                                _buildSectionHeader('Popüler aramalar', null),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildPopularTag('lego'),
                                    _buildPopularTag('iphone 15 pro'),
                                    _buildPopularTag('stanley'),
                                    _buildPopularTag('airfryer'),
                                    _buildPopularTag('dyson'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Divider
                          Container(
                            width: 1,
                            height: 300,
                            color: Colors.grey.shade200,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          
                          Expanded(
                            flex: 2,
                            child: _showFilters
                                ? SizedBox(
                                    height: 260,
                                    child: AdvancedFilterDrawer(
                                      compact: true,
                                      onClose: () {
                                        setState(() {
                                          _showFilters = false;
                                        });
                                      },
                                      onApply: () {
                                        if (widget.onClose != null) {
                                          widget.onClose!();
                                        }
                                      },
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Son gezdiğin ürünler',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _isLoading
                                          ? const Center(child: CircularProgressIndicator())
                                          : Column(
                                              children: _recentProducts.map((product) {
                                                return _buildRecentProductItem(
                                                  product.name,
                                                  product.price,
                                                  product.imageUrl,
                                                  isDiscounted: true,
                                                );
                                              }).toList(),
                                            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(String text) {
    return InkWell(
      onTap: () => widget.onSearch(text),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.history, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularTag(String text) {
    return InkWell(
      onTap: () => widget.onSearch(text),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProductItem(String title, String price, String imageUrl, {bool isDiscounted = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: imageUrl.startsWith('http')
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDiscounted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary, // Mor renk
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Yakın Lokasyon', // Metin değişti
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price.contains('TL') ? price : '$price TL',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Icon(Icons.add_shopping_cart, size: 18, color: Colors.black87),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
