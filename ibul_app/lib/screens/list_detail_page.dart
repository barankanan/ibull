import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import 'map_page.dart';

/// Liste detay sayfası - ürünler, değerlendirmeler, yakın lokasyon ve videolar
class ListDetailPage extends StatefulWidget {
  final Map<String, dynamic> listData;

  const ListDetailPage({super.key, required this.listData});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Liste ürünlerini al
  List<Product> _getListProducts() {
    // Eğer listData içinde products varsa onları kullan
    if (widget.listData.containsKey('products') && widget.listData['products'] is List) {
      return (widget.listData['products'] as List).cast<Product>();
    }
    
    // Yoksa boş liste döndür
    return [];
  }

  Widget _buildFavoriteBadge(Product product) {
    final isFavorite = _appState.isFavorite(product);

    return GestureDetector(
      onTap: () {
        setState(() {
          _appState.toggleFavorite(product);
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
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.red : AppColors.primary,
          size: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedTabIndex == 0 ? 'Listelerim' :
          _selectedTabIndex == 1 ? 'Değerlendirmeler' :
          _selectedTabIndex == 2 ? 'Yakın Lokasyon' : 'Videolar',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Tab Buttons
          _buildTabButtons(),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildReviewsTab(),
                _buildLocationTab(),
                _buildVideosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final coverImage = widget.listData['coverImage'] as String;
    final logo = widget.listData['logo'] as String;
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Cover image with logo
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverImage.startsWith('http')
                    ? Image.network(
                        coverImage,
                        width: double.infinity,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 80,
                          color: Colors.grey[200],
                          child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                        ),
                      )
                    : Image.asset(
                        coverImage,
                        width: double.infinity,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 80,
                          color: Colors.grey[200],
                          child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                        ),
                      ),
              ),
              Positioned(
                left: 12,
                bottom: -20,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: logo.startsWith('http')
                        ? Image.network(
                            logo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.list, color: Colors.grey[400]),
                          )
                        : Image.asset(
                            logo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.list, color: Colors.grey[400]),
                          ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // List name and follow button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.listData['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.listData['memberCount']} Kişi üye',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 18),
                    color: Colors.black87,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    ),
                    child: const Text(
                      'Takip et',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Description
          Text(
            widget.listData['description'],
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(0, 'ürünler'),
            const SizedBox(width: 8),
            _buildTabButton(1, 'Değerlendirmeler'),
            const SizedBox(width: 8),
            _buildTabButton(2, 'Yakın Lokasyon'),
            const SizedBox(width: 8),
            _buildTabButton(3, 'Videolar'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    final products = _getListProducts();
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Bu listede henüz ürün yok',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 6,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductCardNew(products[index]);
      },
    );
  }

  Widget _buildProductCardNew(Product product) {
    final image = product.images.isNotEmpty ? product.images.first : '';
    final badge = product.tags.isNotEmpty ? product.tags.first : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image
          Stack(
            children: [
              Container(
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: image.isNotEmpty
                        ? (image.startsWith('http')
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 75,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.image, size: 25, color: Colors.grey),
                              )
                            : Image.asset(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 75,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.image, size: 25, color: Colors.grey),
                              ))
                        : const Icon(Icons.image, size: 25, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: _buildFavoriteBadge(product),
              ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badges
                if (badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (badge.isNotEmpty) const SizedBox(height: 3),

                // Title
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Rating
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(
                      4,
                      (index) => Icon(
                        index < product.rating.floor() ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 7,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '(${product.reviewCount})',
                        style: const TextStyle(fontSize: 6, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Price
                Text(
                  product.price,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gelen Fotoğraflar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    image: const DecorationImage(
                      image: NetworkImage('https://via.placeholder.com/80x80.png?text=User'),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildReviewCard(),
          _buildReviewCard(),
          _buildReviewCard(),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Baran K***',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '16/01/2024',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Muhteşem paketleme çok ilgili davranıldı, Ürün 4 saat sonra elime ulaştı\n\nİçerisinde Hediyelerle birlikte geldi. Tüm sorularıma anında yanıt aldım Herkese tavsiye ettiğim bir ürün İHİZ yaptığı kurye özelliği ile ayrı bir hizmet atmış Dert Çok memnun kaldım',
            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Sol: Rating ve chat
              Row(
                children: [
                  const Text(
                    '5.0',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 13)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Sağ: Ürün görseli ve sayısı
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.network(
                      'https://via.placeholder.com/50x50.png?text=P',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(+5)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    final products = _getListProducts();
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Yakında ürün bulunamadı',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 6,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildLocationProductCard(products[index]);
      },
    );
  }

  Widget _buildLocationProductCard(Product product) {
    final image = product.images.isNotEmpty ? product.images.first : '';
    final badge = product.tags.isNotEmpty ? product.tags.first : '';

    return GestureDetector(
      onTap: () {
        // Harita sayfasına git ve ürünü ara
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image with map icon
          Stack(
            children: [
              Container(
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: image.isNotEmpty
                        ? (image.startsWith('http')
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 75,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.image, size: 25, color: Colors.grey),
                              )
                            : Image.asset(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 75,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.image, size: 25, color: Colors.grey),
                              ))
                        : const Icon(Icons.image, size: 25, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: 20,
                  height: 20,
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
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 12),
                ),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: _buildFavoriteBadge(product),
              ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badges
                if (badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (badge.isNotEmpty) const SizedBox(height: 3),

                // Title
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Rating
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(
                      4,
                      (index) => Icon(
                        index < product.rating.floor() ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 7,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '(${product.reviewCount})',
                        style: const TextStyle(fontSize: 6, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Price
                Text(
                  product.price,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildVideosTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return _buildVideoProductCard(index);
      },
    );
  }

  Widget _buildVideoProductCard(int index) {
    final product = Product(
      name: 'Siyah Deri Ceket',
      brand: '${widget.listData['name'] ?? 'Liste'} - Video ${index + 1}',
      price: '800 TL',
      rating: 4,
      reviewCount: 4,
      tags: const ['Ücretsiz Kargo', 'Video'],
      images: const ['https://via.placeholder.com/200x300.png?text=Video'],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video thumbnail with play button
          Stack(
            children: [
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Image.network(
                    'https://via.placeholder.com/200x300.png?text=Video',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.videocam, size: 30, color: Colors.grey),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _buildFavoriteBadge(product),
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
                          child: const Row(
                            children: [
                              Icon(Icons.local_shipping, color: Colors.white, size: 8),
                              SizedBox(width: 2),
                              Text(
                                'Ücretsiz Kargo',
                                style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600),
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
                          child: const Row(
                            children: [
                              Icon(Icons.store, color: Colors.white, size: 8),
                              SizedBox(width: 2),
                              Text(
                                '3',
                                style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  const Text(
                    'Siyah Deri Ceket',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),

                  // Rating
                  Row(
                    children: [
                      ...List.generate(
                        4,
                        (index) => const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 10,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.photo_library, color: AppColors.primary, size: 9),
                      const SizedBox(width: 1),
                      const Text(
                        '(4)',
                        style: TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Price
                  const Text(
                    '800 TL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
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
                        'Sepete Ekle',
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
