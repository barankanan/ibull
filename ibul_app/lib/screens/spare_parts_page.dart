import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';

class SparePartsPage extends StatefulWidget {
  final dynamic product;
  final List<Product> initialSelectedParts; // Önceden seçili parçalar

  const SparePartsPage({
    super.key, 
    required this.product,
    this.initialSelectedParts = const [],
  });

  @override
  State<SparePartsPage> createState() => _SparePartsPageState();
}

class _SparePartsPageState extends State<SparePartsPage> {
  String _selectedFilter = 'Tümü';
  List<DBProduct> _allDBProducts = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Sepet yönetimi
  late List<Product> _selectedParts;
  late Set<String> _addedPartIds;
  late double _totalPrice;
  
  @override
  void initState() {
    super.initState();
    // Önceden seçili parçaları yükle
    _selectedParts = List.from(widget.initialSelectedParts);
    _addedPartIds = Set.from(widget.initialSelectedParts.map((p) => p.name));
    _totalPrice = _calculateTotalPrice();
    _loadProducts();
  }
  
  double _calculateTotalPrice() {
    double total = 0.0;
    for (var part in _selectedParts) {
      total += _parsePrice(part.price);
    }
    return total;
  }
  
  Future<void> _loadProducts() async {
    try {
      final products = await _dbHelper.getAllProducts();
      setState(() {
        _allDBProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Parça ekle
  void _addPart(Product product) {
    setState(() {
      _selectedParts.add(product);
      _addedPartIds.add(product.name); // Parça ID'sini ekle (isim kullanarak)
      // Fiyat hesapla (TL ve rakamları çıkar)
      double price = _parsePrice(product.price);
      _totalPrice += price;
    });
    
    // Bildirim göster - sadece "Parça eklendi" yazsın, buton olmasın
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Parça eklendi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF4CAF50),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  // Fiyat parse etme ("800 TL" -> 800.0)
  double _parsePrice(String priceString) {
    try {
      // "800 TL", "1.500 TL" gibi formatları handle et
      String cleanPrice = priceString
          .replaceAll('TL', '')
          .replaceAll('₺', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return double.parse(cleanPrice);
    } catch (e) {
      print('Error parsing price: $e');
      return 0.0;
    }
  }
  
  // Sepeti göster
  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Başlık
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Color(0xFF7C4DFF), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Seçilen Parçalar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Parça listesi
            Expanded(
              child: _selectedParts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Sepet Boş',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _selectedParts.length,
                      itemBuilder: (context, index) {
                        final part = _selectedParts[index];
                        return _buildCartItem(part, index);
                      },
                    ),
            ),
            
            // Toplam fiyat ve butonlar
            if (_selectedParts.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Toplam:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_totalPrice.toStringAsFixed(0)} TL',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedParts.clear();
                                _totalPrice = 0.0;
                              });
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF7C4DFF)),
                            ),
                            child: const Text('Sepeti Temizle'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Ana ürüne parçaları ekle ve geri dön
                              Navigator.pop(context); // Modalı kapat
                              Navigator.pop(context, {
                                'parts': _selectedParts,
                                'totalPrice': _totalPrice,
                              }); // Sayfa geri dön
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: const Color(0xFF7C4DFF),
                            ),
                            child: const Text('Parçaları Ekle'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Sepet item widget
  Widget _buildCartItem(Product part, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Görsel
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: part.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      part.images[0],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.image, size: 30, color: Colors.grey[400]);
                      },
                    ),
                  )
                : Icon(Icons.image, size: 30, color: Colors.grey[400]),
          ),
          const SizedBox(width: 12),
          
          // Bilgi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  part.price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ],
            ),
          ),
          
          // Sil butonu
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                double price = _parsePrice(part.price);
                _totalPrice -= price;
                _selectedParts.removeAt(index);
              });
              Navigator.pop(context);
              if (_selectedParts.isNotEmpty) {
                _showCart();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7C4DFF),
      body: SafeArea(
        child: Column(
          children: [
            // Mor header
            _buildHeader(),
            
            // Beyaz content area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildProductInfo(),
                    const SizedBox(height: 16),
                    _buildFilterChips(),
                    const SizedBox(height: 12),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildSparePartsGrid(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Parça Seç',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Telefon ikonu
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Icon(Icons.phone_iphone, size: 28),
          ),
          const SizedBox(width: 12),
          // Ürün bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Chip'ler
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip('📱 Ekran', const Color(0xFF7C4DFF)),
                    _buildInfoChip('🔋 Pil/Batarya', const Color(0xFF7C4DFF)),
                    _buildInfoChip('📷 Kaporta', const Color(0xFF7C4DFF)),
                  ],
                ),
              ],
            ),
          ),
          // Refresh ikonu
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('Tümü'),
          const SizedBox(width: 8),
          _buildFilterChip('Ekran'),
          const SizedBox(width: 8),
          _buildFilterChip('Pil/Batarya'),
          const SizedBox(width: 8),
          _buildFilterChip('Kamera'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C4DFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.filter_list,
              label: 'Filtrele',
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.compare_arrows,
              label: 'Karşılaştır',
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.sort,
              label: 'Sırala',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparePartsGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
      );
    }
    
    // Ürün adından cihaz modelini çıkar (iPhone 13)
    String deviceModel = _extractDeviceModel(widget.product.name);
    
    // DBProduct'ları Product'a dönüştür
    List<Product> allProducts = _allDBProducts
        .map((dbProduct) => Product.fromDBProduct(dbProduct))
        .toList();
    
    // Seçili filtreye göre kategorileri belirle
    String categoryFilter = '';
    if (_selectedFilter == 'Ekran') {
      categoryFilter = 'Ekran';
    } else if (_selectedFilter == 'Pil/Batarya') {
      categoryFilter = 'Pil';
    } else if (_selectedFilter == 'Kamera') {
      categoryFilter = 'Kamera';
    }
    
    // Filtreleme: Cihaz modeline uygun yedek parçaları bul
    List<Product> filteredProducts = allProducts.where((product) {
      // Ürün adında cihaz modeli geçmeli
      bool matchesDevice = product.name.toLowerCase().contains(deviceModel.toLowerCase());
      
      // Kategori filtresi varsa kontrol et
      if (_selectedFilter != 'Tümü' && categoryFilter.isNotEmpty) {
        bool matchesCategory = product.name.toLowerCase().contains(categoryFilter.toLowerCase()) ||
                              (product.category != null && product.category!.toLowerCase().contains(categoryFilter.toLowerCase())) ||
                              (product.subCategory != null && product.subCategory!.toLowerCase().contains(categoryFilter.toLowerCase()));
        return matchesDevice && matchesCategory;
      }
      
      return matchesDevice;
    }).toList();
    
    // Eğer hiç ürün yoksa "Parça Bulunamadı" göster
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Parça Bulunamadı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'Tümü' 
                ? 'Bu cihaz için henüz yedek parça eklenmemiş'
                : '$_selectedFilter kategorisinde parça bulunamadı',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }
  
  // Cihaz modelini çıkar (iPhone 13 Hasarlı -> iPhone 13)
  String _extractDeviceModel(String productName) {
    // "Hasarlı", "Kırık" gibi kelimeleri temizle
    String cleaned = productName
        .replaceAll('Hasarlı', '')
        .replaceAll('Kırık', '')
        .replaceAll('2.El', '')
        .trim();
    return cleaned;
  }
  
  // Gerçek Product model için kart
  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Favori butonu + Görsel
          Stack(
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: product.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.asset(
                          product.images[0],
                          width: double.infinity,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
                      ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge (eğer üründe varsa)
                  if (product.tags.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              product.tags[0],
                              style: const TextStyle(
                                fontSize: 6,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (product.tags.length > 1)
                            const SizedBox(width: 2),
                          if (product.tags.length > 1)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '+${product.tags.length - 1}',
                                style: const TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C4DFF),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 3),
                  
                  // Ürün adı
                  Flexible(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Rating
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        if (i < product.rating.floor()) {
                          return const Icon(Icons.star, color: Colors.amber, size: 8);
                        }
                        return Icon(Icons.star_border, color: Colors.grey[300], size: 8);
                      }),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '(${product.reviewCount})',
                          style: TextStyle(fontSize: 7, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  
                  // Fiyat
                  Text(
                    product.price,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Sepete Ekle butonu
                  SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: OutlinedButton(
                      onPressed: _addedPartIds.contains(product.name) 
                          ? null // Zaten eklenmişse tıklanamaz
                          : () => _addPart(product),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        side: BorderSide(
                          color: _addedPartIds.contains(product.name) 
                              ? Colors.green 
                              : const Color(0xFF7C4DFF), 
                          width: 1,
                        ),
                        backgroundColor: _addedPartIds.contains(product.name) 
                            ? Colors.green.withOpacity(0.1) 
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        _addedPartIds.contains(product.name) ? 'Eklendi' : 'Parçayı Ekle',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _addedPartIds.contains(product.name) 
                              ? Colors.green 
                              : const Color(0xFF7C4DFF),
                        ),
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
