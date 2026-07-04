import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../features/seller/panel/widgets/seller_lists_dashboard_widgets.dart';
import '../../models/product_model.dart';
import '../../models/product_list_model.dart';
import '../../models/seller_product.dart';
import '../../services/store_service.dart';
import '../../ads/enums/ad_enums.dart';
import '../../ads/presentation/pages/campaign_wizard_page.dart';

class SellerCollectionsManagementContent extends StatefulWidget {
  const SellerCollectionsManagementContent({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<SellerCollectionsManagementContent> createState() =>
      _SellerCollectionsManagementContentState();
}

class _SellerCollectionsManagementContentState
    extends State<SellerCollectionsManagementContent> {
  final AppState _appState = AppState();
  final StoreService _storeService = StoreService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoadingProducts = false;
  String? _sellerProductsError;
  List<SellerProduct> _sellerProducts = const <SellerProduct>[];

  @override
  void initState() {
    super.initState();
    _appState.addListener(_handleAppStateChanged);
    _loadSellerProducts();
  }

  @override
  void dispose() {
    _appState.removeListener(_handleAppStateChanged);
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSellerProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
      _sellerProductsError = null;
    });
    try {
      final products = await _storeService.getSellerProductsSnapshot();
      if (!mounted) return;
      setState(() {
        _sellerProducts = products;
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sellerProductsError = error.toString();
        _isLoadingProducts = false;
      });
    }
  }

  String? _normalizeCategory(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  Future<void> _showCreateCollectionDialog([ProductList? existingList]) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return SellerListEditDialog(
          existingList: existingList,
          storeService: _storeService,
          picker: _picker,
          onPersist:
              ({
                required String name,
                required String description,
                required ProductListVisibility visibility,
                required String? coverUrl,
                required bool isCreate,
                String? listId,
              }) async {
                if (isCreate) {
                  _appState.createProductList(
                    name,
                    description: description,
                    visibility: visibility,
                    coverImageUrl: coverUrl,
                  );
                } else if (listId != null) {
                  await _appState.updateProductListDetails(
                    listId,
                    name: name,
                    description: description,
                    iconUrl: coverUrl,
                  );
                  _appState.updateProductListVisibility(listId, visibility);
                }
              },
        );
      },
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingList == null
                ? 'Liste oluşturuldu. Artık reklamlarda seçilebilir.'
                : 'Liste güncellendi.',
          ),
        ),
      );
    }
  }

  Future<void> _openBoostWizard(ProductList list) async {
    if (!mounted) return;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CampaignWizardPage(
          sellerId: _storeService.currentUserId ?? '',
          initialCampaignType: AdCampaignType.collectionBoost,
          initialCollectionId: list.id,
          initialCollectionTitle: list.name,
          initialCollectionImageUrl: list.iconUrl,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liste reklam akisi acildi ve kampanya kaydedildi.'),
        ),
      );
    }
  }

  Future<void> _deleteCollection(ProductList list) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Liste silinsin mi?'),
          content: Text(
            '"${list.name}" listesini silerseniz reklam secimlerinde de kalkar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (approved != true) return;
    try {
      await _appState.deleteProductList(list.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste silindi.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Liste silinemedi. Bağlantınızı kontrol edip tekrar deneyin.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = _appState.productLists;
    final publicLists = lists.where((list) => list.isPublic).length;
    final campaignReady = lists.where((list) => list.productCount > 0).length;
    final productsSubtitle = _isLoadingProducts
        ? 'Ürünler yükleniyor...'
        : _sellerProductsError != null
        ? 'Ürünler yüklenemedi'
        : 'Mağaza ürünleri';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerListsHeader(
          totalLists: lists.length,
          onCreateList: _showCreateCollectionDialog,
          onRefresh: _loadSellerProducts,
        ),
        const SizedBox(height: SellerListsDashboardTokens.pageGap),
        if (_sellerProductsError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: SellerListsDashboardTokens.pageGap),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Listeler yüklenemedi. Ürün verisi alınamadı.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
                TextButton(onPressed: _loadSellerProducts, child: const Text('Yeniden dene')),
              ],
            ),
          ),
        SellerListMetricGrid(
          metrics: buildSellerListMetrics(
            totalLists: lists.length,
            addableProducts: _sellerProducts.length,
            publicLists: publicLists,
            campaignReadyLists: campaignReady,
            productsSubtitle: productsSubtitle,
          ),
        ),
        const SizedBox(height: SellerListsDashboardTokens.pageGap),
        if (lists.isEmpty)
          ListsEmptyState(onCreateList: _showCreateCollectionDialog)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 760
                  ? 2
                  : 1;
              const spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
                  crossAxisCount;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: lists
                    .map(
                      (list) => SizedBox(
                        width: itemWidth,
                        child: SellerListCard(
                          list: list,
                          onAddProducts: () => _showManageProductsDialog(list),
                          onEdit: () => _showCreateCollectionDialog(list),
                          onDelete: () => _deleteCollection(list),
                          onBoost: () => _openBoostWizard(list),
                          onRemoveProduct: (product) =>
                              _removeProductFromList(list, product),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
      ],
    );

    if (widget.embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Listeler')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    );
  }

  Future<void> _showManageProductsDialog(ProductList list) async {
    if (_isLoadingProducts) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Urunler hala yukleniyor.')));
      return;
    }
    if (_sellerProductsError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Urunler yuklenemedi: $_sellerProductsError')),
      );
      return;
    }
    if (_sellerProducts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Once urun eklemelisiniz.')));
      return;
    }

    final selectedIds = <String>{
      ...list.products
          .map((product) => _productIdentity(product))
          .where((value) => value.isNotEmpty),
      ...list.productIds.where((value) => value.isNotEmpty),
    };
    var selectedCategory = _normalizeCategory(list.category);

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 680,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${list.name} listesine urun ekle',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedCategory == null
                            ? 'Ilk sectiginiz urun bu listenin kategorisini belirler. Sonrasinda sadece ayni kategoride urun ekleyebilirsiniz.'
                            : 'Bu liste "$selectedCategory" kategorisine kilitli. Sectiklerinizi kaldirarak listeden de cikarabilirsiniz.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _sellerProducts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final product = _sellerProducts[index];
                            final identity = _productIdentityFromSeller(
                              product,
                            );
                            final selected = selectedIds.contains(identity);
                            final productCategory =
                                _normalizeCategory(product.mainCategory) ??
                                _normalizeCategory(product.subCategory);
                            final categoryMismatch =
                                !selected &&
                                selectedCategory != null &&
                                productCategory != null &&
                                selectedCategory!.toLowerCase() !=
                                    productCategory.toLowerCase();
                            return InkWell(
                              onTap: categoryMismatch
                                  ? null
                                  : () {
                                      setModalState(() {
                                        if (selected) {
                                          selectedIds.remove(identity);
                                          if (selectedIds.isEmpty &&
                                              list.products.isEmpty) {
                                            selectedCategory = null;
                                          }
                                        } else {
                                          selectedIds.add(identity);
                                          selectedCategory ??= productCategory;
                                        }
                                      });
                                    },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: categoryMismatch
                                      ? const Color(0xFFF8FAFC)
                                      : selected
                                      ? const Color(0xFFEEF2FF)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: categoryMismatch
                                        ? const Color(0xFFE2E8F0)
                                        : selected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _productThumbnail(product),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${product.mainCategory.isNotEmpty ? product.mainCategory : 'Kategori'} • ${product.displayPrice}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          if (categoryMismatch)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Bu listeye eklenemez: kategori farkli',
                                                style: TextStyle(
                                                  color: Color(0xFFB45309),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: selected,
                                      onChanged: categoryMismatch
                                          ? null
                                          : (_) {
                                              setModalState(() {
                                                if (selected) {
                                                  selectedIds.remove(identity);
                                                  if (selectedIds.isEmpty &&
                                                      list.products.isEmpty) {
                                                    selectedCategory = null;
                                                  }
                                                } else {
                                                  selectedIds.add(identity);
                                                  selectedCategory ??=
                                                      productCategory;
                                                }
                                              });
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Vazgec'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () {
                              _applyProductSelectionToList(list, selectedIds);
                              Navigator.of(dialogContext).pop(true);
                            },
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Listeyi guncelle'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste urunleri guncellendi.')),
      );
    }
  }

  void _applyProductSelectionToList(ProductList list, Set<String> selectedIds) {
    final existingIds = <String>{
      ...list.products.map(_productIdentity).where((value) => value.isNotEmpty),
      ...list.productIds.where((value) => value.isNotEmpty),
    };

    for (final sellerProduct in _sellerProducts) {
      final identity = _productIdentityFromSeller(sellerProduct);
      final shouldExist = selectedIds.contains(identity);
      final exists = existingIds.contains(identity);
      if (shouldExist && !exists) {
        _appState.addToProductList(list.id, _toProduct(sellerProduct));
      } else if (!shouldExist && exists) {
        _appState.removeFromProductList(list.id, identity);
      }
    }
  }

  void _removeProductFromList(ProductList list, Product product) {
    _appState.removeFromProductList(list.id, _productIdentity(product));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} listeden cikarildi.')),
    );
  }

  String _productIdentity(Product product) {
    final productId = product.productId?.trim() ?? '';
    if (productId.isNotEmpty) return 'id:$productId';
    final brand = product.brand.trim().toLowerCase();
    final name = product.name.trim().toLowerCase();
    final store = (product.store ?? '').trim().toLowerCase();
    return '$brand|$name|$store';
  }

  String _productIdentityFromSeller(SellerProduct product) {
    final id = product.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    final brand = product.brand.trim().toLowerCase();
    final name = product.name.trim().toLowerCase();
    final store = (product.storeName ?? '').trim().toLowerCase();
    return '$brand|$name|$store';
  }

  Product _toProduct(SellerProduct product) {
    final images = <String>{
      if ((product.imageUrl ?? '').trim().isNotEmpty) product.imageUrl!.trim(),
      ...product.imageUrls.where((value) => value.trim().isNotEmpty),
    }.toList(growable: false);

    return Product(
      productId: product.id,
      name: product.name,
      brand: product.brand,
      price: product.displayPrice,
      oldPrice: product.hasDiscount ? product.originalPrice : null,
      rating: 0,
      reviewCount: 0,
      tags: product.attributes,
      images: images,
      store: product.storeName,
      sellerId: _storeService.currentUserId,
      category: product.mainCategory,
      subCategory: product.subCategory,
      description: product.description,
      videoUrl: product.videoUrl,
      videoPath: product.videoPath,
      videoPublicUrl: product.videoPublicUrl,
      thumbnailPath: product.thumbnailPath,
      thumbnailPublicUrl: product.thumbnailPublicUrl,
      videoDurationSeconds: product.videoDurationSeconds,
      videoSizeBytes: product.videoSizeBytes,
      thumbnailSizeBytes: product.thumbnailSizeBytes,
      videoStatus: product.videoStatus,
      variants: product.variants,
      accessories: product.accessories,
      additionalInfo: product.additionalInfo,
      faq: product.faq,
    );
  }

  Widget _productThumbnail(SellerProduct product) {
    final imageUrl = (product.imageUrl ?? '').trim();
    if (imageUrl.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        color: const Color(0xFFE2E8F0),
        child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B)),
      );
    }

    return OptimizedImage(
      imageUrlOrPath: imageUrl,
      width: 58,
      height: 58,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          width: 58,
          height: 58,
          color: const Color(0xFFE2E8F0),
          child: const Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF64748B),
          ),
        );
      },
    );
  }
}
