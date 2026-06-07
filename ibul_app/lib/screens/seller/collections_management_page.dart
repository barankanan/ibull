import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../models/product_model.dart';
import '../../models/product_list_model.dart';
import '../../models/seller_product.dart';
import '../../services/store_service.dart';
import '../../utils/xfile_image_provider.dart';
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
  bool _isCreating = false;
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
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    nameController.text = existingList?.name ?? '';
    descriptionController.text = existingList?.description ?? '';
    var visibility = existingList?.visibility ?? ProductListVisibility.private;
    XFile? selectedCover;
    var coverImageUrl = existingList?.iconUrl;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickCover() async {
              final picked = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 88,
              );
              if (picked == null || !dialogContext.mounted) return;
              setModalState(() => selectedCover = picked);
            }

            Future<void> submit() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Liste adi girmelisiniz.')),
                );
                return;
              }

              setModalState(() => _isCreating = true);
              try {
                String? resolvedCoverUrl = coverImageUrl;
                if (selectedCover != null) {
                  resolvedCoverUrl = await _storeService.uploadStoreImage(
                    selectedCover!,
                    'product-list-covers',
                  );
                }

                if (existingList == null) {
                  _appState.createProductList(
                    name,
                    description: descriptionController.text.trim(),
                    visibility: visibility,
                    coverImageUrl: resolvedCoverUrl,
                  );
                } else {
                  await _appState.updateProductListDetails(
                    existingList.id,
                    name: name,
                    description: descriptionController.text.trim(),
                    iconUrl: resolvedCoverUrl,
                  );
                  _appState.updateProductListVisibility(
                    existingList.id,
                    visibility,
                  );
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      existingList == null
                          ? 'Liste olusturulamadi: $error'
                          : 'Liste guncellenemedi: $error',
                    ),
                  ),
                );
              } finally {
                if (dialogContext.mounted) {
                  setModalState(() => _isCreating = false);
                }
              }
            }

            return AlertDialog(
              title: Text(
                existingList == null ? 'Yeni liste' : 'Listeyi duzenle',
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _isCreating ? null : pickCover,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 132,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: selectedCover != null
                              ? Image(
                                  image: xFileImageProvider(selectedCover!),
                                  fit: BoxFit.cover,
                                )
                              : (coverImageUrl ?? '').trim().isNotEmpty
                              ? OptimizedImage(
                                  imageUrlOrPath: coverImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return _buildCoverPlaceholder();
                                  },
                                )
                              : _buildCoverPlaceholder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _isCreating ? null : pickCover,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        existingList == null
                            ? 'Liste gorseli ekle'
                            : 'Liste gorselini degistir',
                      ),
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Liste adi',
                        hintText: 'Ornek: Yaz Firsatlari',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Aciklama',
                        hintText: 'Listenizi kisaca anlatin',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ProductListVisibility>(
                      initialValue: visibility,
                      decoration: const InputDecoration(
                        labelText: 'Gorunurluk',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductListVisibility.private,
                          child: Text('Ozel'),
                        ),
                        DropdownMenuItem(
                          value: ProductListVisibility.public,
                          child: Text('Herkese acik'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => visibility = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isCreating
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgec'),
                ),
                FilledButton.icon(
                  onPressed: _isCreating ? null : submit,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    _isCreating
                        ? (existingList == null
                              ? 'Olusturuluyor...'
                              : 'Guncelleniyor...')
                        : (existingList == null ? 'Liste olustur' : 'Kaydet'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingList == null
                ? 'Liste olusturuldu. Artik reklamlarda secilebilir.'
                : 'Liste guncellendi.',
          ),
        ),
      );
    }
  }

  Widget _buildCoverPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.collections_bookmark_outlined,
          color: Color(0xFF64748B),
          size: 34,
        ),
        SizedBox(height: 8),
        Text(
          'Kapak gorseli secin',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Listeler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Urunlerinizi listeler halinde gruplayin. Olusturdugunuz listeler reklam kampanyalarinda secilebilir.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showCreateCollectionDialog,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: const Text('Liste olustur'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildProductsSummaryCard(),
        const SizedBox(height: 16),
        if (lists.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.collections_bookmark_outlined,
                    color: Color(0xFF4F46E5),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Henuz listeniz yok',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ilk listenizi olusturun, sonra reklam verirken dogrudan secin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _showCreateCollectionDialog,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ilk listeyi olustur'),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 760
                  ? 2
                  : 1;
              final spacing = 16.0;
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
                        child: _buildCollectionCard(list),
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

  Widget _buildProductsSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF4F46E5),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Listeye eklenebilir urunler',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoadingProducts
                      ? 'Urunler yukleniyor...'
                      : _sellerProductsError != null
                      ? 'Urunler yuklenemedi, tekrar deneyin.'
                      : '${_sellerProducts.length} urun listelere eklenmeye hazir.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isLoadingProducts ? null : _loadSellerProducts,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(ProductList list) {
    final productCount = list.productIds.isNotEmpty
        ? list.productIds.length
        : list.products.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 104,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF8FAFC),
                ),
                clipBehavior: Clip.antiAlias,
                child: (list.iconUrl ?? '').trim().isNotEmpty
                    ? OptimizedImage(
                        imageUrlOrPath: list.iconUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return _buildCoverPlaceholder();
                        },
                      )
                    : _buildCoverPlaceholder(),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: FilledButton.icon(
                  onPressed: productCount == 0
                      ? null
                      : () => _openBoostWizard(list),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.campaign_outlined, size: 16),
                  label: const Text('ÖNE ÇIKAR'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  list.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: list.isPublic
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  list.isPublic ? 'Acik' : 'Ozel',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: list.isPublic
                        ? const Color(0xFF166534)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (list.description ?? '').trim().isEmpty
                ? 'Aciklama eklenmedi.'
                : list.description!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CollectionMetaChip(
                icon: Icons.inventory_2_outlined,
                label: '$productCount urun',
              ),
              if ((list.category ?? '').trim().isNotEmpty)
                _CollectionMetaChip(
                  icon: Icons.category_outlined,
                  label: list.category!,
                ),
              _CollectionMetaChip(
                icon: Icons.schedule_outlined,
                label:
                    'Guncel: ${list.updatedAt.day.toString().padLeft(2, '0')}.${list.updatedAt.month.toString().padLeft(2, '0')}.${list.updatedAt.year}',
              ),
            ],
          ),
          if (list.products.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: list.products
                  .take(4)
                  .map(
                    (product) => _RemovableProductChip(
                      label: product.name,
                      onRemove: () => _removeProductFromList(list, product),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                height: 36,
                child: FilledButton.icon(
                  onPressed: () => _showManageProductsDialog(list),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('Urun ekle'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: () => _showCreateCollectionDialog(list),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Duzenle'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteCollection(list),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Sil'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _CollectionMetaChip extends StatelessWidget {
  const _CollectionMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableProductChip extends StatelessWidget {
  const _RemovableProductChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
