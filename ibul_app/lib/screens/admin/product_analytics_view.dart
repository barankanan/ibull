import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../../core/constants.dart';
import '../../models/db_product.dart';
import '../../services/database_helper.dart';

class ProductAnalyticsView extends StatefulWidget {
  const ProductAnalyticsView({super.key});

  @override
  State<ProductAnalyticsView> createState() => _ProductAnalyticsViewState();
}

class _ProductAnalyticsViewState extends State<ProductAnalyticsView> {
  String _analyticsMode = 'products'; // 'products' | 'stores'
  String _productListFilter = 'En Çok Satılan';
  
  // Pagination and Data
  List<DBProduct> _allProducts = [];
  List<DBProduct> _filteredProducts = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _itemsPerPage = 100;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      setState(() {
        _allProducts = products;
        _filterProducts();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error gracefully
      debugPrint('Error loading products: $e');
    }
  }

  void _filterProducts() {
    List<DBProduct> temp = List.from(_allProducts);
    
    // Apply Search
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((p) => 
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.category.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply Sorting based on filter (Mock sorting logic as some fields might be missing)
    if (_productListFilter == 'En Çok Satılan') {
      // Mock: sort by review count as proxy for sales
      temp.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    } else if (_productListFilter == 'En Çok Aratılan') {
      // Mock: sort by rating
      temp.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      // Default sort
      temp.sort((a, b) {
        final bNumericId = int.tryParse(b.id ?? '');
        final aNumericId = int.tryParse(a.id ?? '');
        if (bNumericId != null && aNumericId != null) {
          return bNumericId.compareTo(aNumericId);
        }
        return (b.id ?? '').compareTo(a.id ?? '');
      });
    }

    setState(() {
      _filteredProducts = temp;
      _currentPage = 1; // Reset to first page on filter change
    });
  }

  List<DBProduct> get _paginatedProducts {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredProducts.length) return [];
    return _filteredProducts.sublist(
      startIndex, 
      endIndex > _filteredProducts.length ? _filteredProducts.length : endIndex
    );
  }

  int get _totalPages {
    if (_filteredProducts.isEmpty) return 1;
    return (_filteredProducts.length / _itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Flexible(
          child: SingleChildScrollView(
            child: _analyticsMode == 'products' 
                ? _buildProductAnalyticsContent()
                : _buildStoreAnalyticsContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ürün Analitiği',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _analyticsMode == 'products'
                  ? 'Ürünlerin performans ve stok durumunu detaylı inceleyin.'
                  : 'Mağazaların satış performansını inceleyin.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _analyticsMode,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _analyticsMode = newValue;
                  });
                }
              },
              items: const [
                DropdownMenuItem(
                  value: 'products',
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Ürünler'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'stores',
                  child: Row(
                    children: [
                      Icon(Icons.store_mall_directory_outlined, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Mağazalar'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductAnalyticsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Özet Kartları
        _buildSummaryCards(),
        const SizedBox(height: 24),

        // 2. Grafikler Satırı (Kategori Dağılımı & İade Analizi)
        _buildChartsRow(),
        const SizedBox(height: 24),

        // 3. Detaylı Ürün Tablosu (Pagination included)
        _buildProductTableSection(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Wrap cards on smaller screens
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildDetailCardItem(Icons.shopping_bag, 'Toplam Satış', '₺1.2M', Colors.blue, width: (constraints.maxWidth - 16) / 2),
              _buildDetailCardItem(Icons.refresh, 'İade Oranı', '%4.2', Colors.red, width: (constraints.maxWidth - 16) / 2),
              _buildDetailCardItem(Icons.category, 'En Çok Satan', 'Teknoloji', Colors.purple, width: (constraints.maxWidth - 16) / 2),
              _buildDetailCardItem(Icons.trending_up, 'Büyüme', '%12', Colors.green, width: (constraints.maxWidth - 16) / 2),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildDetailCardItem(Icons.shopping_bag, 'Toplam Satış', '₺1.2M', Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildDetailCardItem(Icons.refresh, 'İade Oranı', '%4.2', Colors.red)),
            const SizedBox(width: 16),
            Expanded(child: _buildDetailCardItem(Icons.category, 'En Çok Satan', 'Teknoloji', Colors.purple)),
            const SizedBox(width: 16),
            Expanded(child: _buildDetailCardItem(Icons.trending_up, 'Büyüme', '%12', Colors.green)),
          ],
        );
      },
    );
  }

  Widget _buildDetailCardItem(IconData icon, String title, String value, Color color, {double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kategori Bazlı Satış Dağılımı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    _buildCategorySalesBar('Tüm Kategoriler', 1.0, Colors.grey.shade800),
                    const SizedBox(height: 12),
                    _buildCategorySalesBar('Teknoloji', 0.45, Colors.blue),
                    _buildCategorySalesBar('Ev & Yaşam', 0.25, Colors.orange),
                    _buildCategorySalesBar('Moda', 0.15, Colors.pink),
                    _buildCategorySalesBar('Kozmetik', 0.10, Colors.purple),
                    _buildCategorySalesBar('Diğer', 0.05, Colors.grey),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('En Çok İade Edilenler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    _buildReturnItem('Bluetooth Kulaklık', '%12 İade', 0.7, Colors.red),
                    _buildReturnItem('Akıllı Saat', '%8 İade', 0.5, Colors.orange),
                    _buildReturnItem('Spor Ayakkabı', '%5 İade', 0.3, Colors.yellow.shade700),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'İadelerin %60\'ı "Beden Uyumsuzluğu" nedeniyle gerçekleşiyor.',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol: Kategori Bazlı Satışlar
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kategori Bazlı Satış Dağılımı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    _buildCategorySalesBar('Tüm Kategoriler', 1.0, Colors.grey.shade800),
                    const SizedBox(height: 12),
                    _buildCategorySalesBar('Teknoloji', 0.45, Colors.blue),
                    _buildCategorySalesBar('Ev & Yaşam', 0.25, Colors.orange),
                    _buildCategorySalesBar('Moda', 0.15, Colors.pink),
                    _buildCategorySalesBar('Kozmetik', 0.10, Colors.purple),
                    _buildCategorySalesBar('Diğer', 0.05, Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Sağ: İade Analizi
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('En Çok İade Edilenler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    _buildReturnItem('Bluetooth Kulaklık', '%12 İade', 0.7, Colors.red),
                    _buildReturnItem('Akıllı Saat', '%8 İade', 0.5, Colors.orange),
                    _buildReturnItem('Spor Ayakkabı', '%5 İade', 0.3, Colors.yellow.shade700),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'İadelerin %60\'ı "Beden Uyumsuzluğu" nedeniyle gerçekleşiyor.',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
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
        );
      },
    );
  }

  Widget _buildCategorySalesBar(String label, double ratio, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              Text('%${(ratio * 100).toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItem(String label, String subLabel, double ratio, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_return_outlined, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(subLabel, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTableSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Search & Filter
              Row(
                children: [
                  Container(
                    width: 250,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _filterProducts();
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Ürün Ara...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _productListFilter,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827)),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _productListFilter = newValue;
                              _filterProducts();
                            });
                          }
                        },
                        items: <String>['En Çok Satılan', 'En Çok Aratılan', 'Sepette Çok Olan']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Export Button
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rapor indiriliyor... (Demo)'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Rapor İndir', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Ürün Adı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                Expanded(flex: 2, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                Expanded(flex: 1, child: Text('Fiyat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                Expanded(flex: 1, child: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                Expanded(flex: 1, child: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                SizedBox(width: 40), // Action button space
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Table Rows
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_filteredProducts.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Ürün bulunamadı.')))
          else
            ..._paginatedProducts.map((product) => _buildProductRow(product)),
            
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Pagination Controls
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildProductRow(DBProduct product) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade50)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: OptimizedImage(imageUrlOrPath: 
                    product.imageUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 32, 
                      height: 32, 
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, size: 16, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1F2937)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2, 
            child: Text(
              product.category, 
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)
            )
          ),
          Expanded(
            flex: 1, 
            child: Text(
              product.price, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))
            )
          ),
          Expanded(
            flex: 1, 
            child: Text(
              '${product.stock ?? 0}', 
              style: TextStyle(
                fontSize: 13, 
                color: (product.stock ?? 0) < 5 ? Colors.red : Colors.grey.shade600,
                fontWeight: (product.stock ?? 0) < 5 ? FontWeight.bold : FontWeight.normal,
              )
            )
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: product.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product.isActive ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: product.isActive ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.more_horiz, size: 18, color: Colors.grey),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Toplam $_filteredProducts ürün gösteriliyor',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        Row(
          children: [
            IconButton(
              onPressed: _currentPage > 1 
                  ? () => setState(() => _currentPage--) 
                  : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                disabledForegroundColor: Colors.grey.shade300,
              ),
            ),
            const SizedBox(width: 8),
            
            // Page Numbers
            ...List.generate(_totalPages, (index) {
              final page = index + 1;
              // Simple pagination logic: show first, last, and around current
              if (page == 1 || page == _totalPages || (page >= _currentPage - 1 && page <= _currentPage + 1)) {
                 return _buildPageButton(page);
              } else if (page == 2 && _currentPage > 3) {
                return const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...'));
              } else if (page == _totalPages - 1 && _currentPage < _totalPages - 2) {
                return const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...'));
              }
              return const SizedBox.shrink();
            }),

            const SizedBox(width: 8),
            IconButton(
              onPressed: _currentPage < _totalPages 
                  ? () => setState(() => _currentPage++) 
                  : null,
              icon: const Icon(Icons.chevron_right, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                disabledForegroundColor: Colors.grey.shade300,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageButton(int page) {
    final isSelected = page == _currentPage;
    return InkWell(
      onTap: () {
        setState(() {
          _currentPage = page;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreAnalyticsContent() {
    return const Center(child: Text('Mağaza Analitiği Hazırlanıyor...'));
  }
}
