import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../../../models/seller_product.dart';
import '../../../services/store_service.dart';
import 'product_detail_dialog.dart';

class ProductApprovalPage extends StatefulWidget {
  const ProductApprovalPage({super.key});

  @override
  State<ProductApprovalPage> createState() => _ProductApprovalPageState();
}

class _ProductApprovalPageState extends State<ProductApprovalPage> {
  final StoreService _storeService = StoreService();
  late Future<List<SellerProduct>> _pendingProductsFuture;

  @override
  void initState() {
    super.initState();
    _pendingProductsFuture = _storeService.fetchPendingProducts();
  }

  Future<void> _reloadPendingProducts() async {
    final future = _storeService.fetchPendingProducts();
    if (!mounted) return;
    setState(() {
      _pendingProductsFuture = future;
    });
    await future;
  }

  void _showProductDetail(SellerProduct product) {
    showDialog(
      context: context,
      builder: (context) => ProductDetailDialog(
        product: product,
        onApprove: () async {
          await _approveProduct(product.id);
          if (mounted) Navigator.pop(context);
        },
        onReject: () async {
          // Close detail dialog first
          Navigator.pop(context);
          // Then show rejection reason dialog
          _showRejectionDialog(product.id);
        },
      ),
    );
  }

  Future<void> _showRejectionDialog(String productId) async {
    final reasonController = TextEditingController();
    String? selectedReason;
    final List<String> rejectionReasons = [
      'Hatalı ürün',
      'Hatalı açıklama',
      'Hatalı başlık',
      'Kalitesiz görsel',
      'Hatalı video',
      'Yetersiz açıklama',
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ürünü Reddet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reddetme sebebini seçiniz:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...rejectionReasons.map(
                    (reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Özel mesaj (Opsiyonel):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ek açıklama giriniz...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () async {
                        final fullReason = reasonController.text.isNotEmpty
                            ? '$selectedReason: ${reasonController.text}'
                            : selectedReason!;

                        await _rejectProduct(productId, fullReason);
                        if (mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reddet'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ürün Onay Listesi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Mağazaların yayınlanmayı bekleyen ürünleri',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Yenile',
                    onPressed: _reloadPendingProducts,
                    icon: const Icon(Icons.refresh),
                  ),
                  FutureBuilder<List<SellerProduct>>(
                    future: _pendingProductsFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bekleyen: $count',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Ürün',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Marka / Mağaza',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Kategori',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Fiyat',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Durum',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'İşlem',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List Content
        Expanded(
          child: FutureBuilder<List<SellerProduct>>(
            future: _pendingProductsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data!;
              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Harika! Onay bekleyen ürün yok.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: products.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildProductRow(products[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(SellerProduct product) {
    // Determine display image
    String? displayImage = product.imageUrl;
    if ((displayImage == null || displayImage.isEmpty) &&
        product.imageUrls.isNotEmpty) {
      displayImage = product.imageUrls.first;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          // Product
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade100,
                    child: (displayImage != null && displayImage.isNotEmpty)
                        ? OptimizedImage(imageUrlOrPath: 
                            displayImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported,
                                size: 20,
                                color: Colors.grey,
                              );
                            },
                          )
                        : const Icon(Icons.image, size: 20, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Brand / Store
          Expanded(
            flex: 2,
            child: Text(
              product.storeName ?? product.brand,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),

          // Category
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.mainCategory,
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  product.subCategory,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // Price
          Expanded(
            flex: 1,
            child: Text(
              '₺${product.price}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF111827),
              ),
            ),
          ),

          // Status
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.status == 'Düzenlendi' ? 'Düzenlendi' : 'Yeni',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Actions
          Expanded(
            flex: 2,
            child: Row(
              children: [
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () => _showProductDetail(product),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('İncele', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveProduct(String productId) async {
    try {
      await _storeService.approveProduct(productId);
      await _reloadPendingProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün onaylandı ve yayına alındı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectProduct(String productId, String reason) async {
    try {
      await _storeService.rejectProduct(productId, reason);
      await _reloadPendingProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün reddedildi'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
