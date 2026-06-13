import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_list_model.dart';
import '../models/product_list_price_change.dart';
import '../models/product_model.dart';
import '../screens/map_page.dart';
import '../screens/photo_review_detail_page.dart';
import '../screens/product_detail_page.dart';
import '../ads/presentation/pages/campaign_wizard_page.dart';
import '../ads/enums/ad_enums.dart';
import '../services/store_service.dart';
import '../widgets/product_card.dart';
import '../widgets/web_header.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';

class ListDetailPage extends StatefulWidget {
  final Map<String, dynamic> listData;

  const ListDetailPage({super.key, required this.listData});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final AppState _appState = AppState();
  final StoreService _storeService = StoreService();
  int _selectedTabIndex = 0;
  late Future<List<ProductListPriceChange>> _priceChangesFuture;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_handleAppStateChanged);
    _priceChangesFuture = _loadPriceChanges();
  }

  @override
  void dispose() {
    _appState.removeListener(_handleAppStateChanged);
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (mounted) {
      _priceChangesFuture = _loadPriceChanges();
      setState(() {});
    }
  }

  Future<List<ProductListPriceChange>> _loadPriceChanges() {
    return _appState.getProductListPriceChanges(_listId);
  }

  String get _listId => widget.listData['id']?.toString() ?? '';

  ProductList? get _listModel => _appState.getAnyProductListById(_listId);

  Map<String, dynamic> get _resolvedListData {
    final model = _listModel;
    if (model != null) {
      return _appState.productListToMap(model);
    }
    return widget.listData;
  }

  bool get _isOwnedList {
    final ownerId = _resolvedListData['ownerUserId']?.toString();
    final currentUserId = _appState.currentUser?['uid']?.toString();
    return ownerId != null && ownerId.isNotEmpty && ownerId == currentUserId;
  }

  bool get _isFollowing =>
      _resolvedListData['isFollowing'] == true ||
      _appState.isFollowingProductList(_listId);

  List<Product> get _products {
    final raw = _resolvedListData['products'];
    if (raw is List<Product>) return raw;
    if (raw is List) {
      return raw.whereType<Product>().toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> get _listReviews {
    final names = _products
        .map((product) => product.name.toLowerCase())
        .toSet();
    return _appState.productReviews.where((review) {
      final productName = review['productName']?.toString().toLowerCase() ?? '';
      return names.contains(productName);
    }).toList()..sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
  }

  List<Map<String, dynamic>> get _photoReviews => _listReviews
      .where((review) => (review['imageUrls'] as List?)?.isNotEmpty == true)
      .toList();

  List<Product> get _videoProducts =>
      _products.where((product) => product.hasVideo).toList();

  List<Product> get _nearbyProducts => _products
      .where((product) => (product.store ?? '').trim().isNotEmpty)
      .toList();

  String get _coverImage {
    final cover = _resolvedListData['coverImage']?.toString() ?? '';
    if (cover.isNotEmpty) return cover;
    if (_products.isNotEmpty && _products.first.images.isNotEmpty) {
      return _products.first.images.first;
    }
    return '';
  }

  String get _logoImage {
    final logo = _resolvedListData['logo']?.toString() ?? '';
    if (logo.isNotEmpty) return logo;
    if (_products.isNotEmpty && _products.first.images.isNotEmpty) {
      return _products.first.images.first;
    }
    return '';
  }

  String get _description {
    final description =
        _resolvedListData['description']?.toString().trim() ?? '';
    if (description.isNotEmpty && description != '0 ürün') return description;
    if (_products.isEmpty) {
      return 'Ürünlerini tek yerde toplayıp değerlendirme, yakın lokasyon ve video içeriklerini buradan takip edebilirsin.';
    }
    return '${_products.length} ürün içeriyor';
  }

  String get _visibilityLabel =>
      _resolvedListData['visibilityLabel']?.toString() ?? 'Sadece Ben';

  Future<void> _openBoostWizard() async {
    final sellerId = _storeService.currentUserId?.trim() ?? '';
    if (sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liste reklamı için satıcı girişi gerekli.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CampaignWizardPage(
          sellerId: sellerId,
          initialCampaignType: AdCampaignType.collectionBoost,
          initialCollectionId: _listId,
          initialCollectionTitle: _resolvedListData['name']?.toString(),
          initialCollectionImageUrl: _coverImage.isEmpty ? null : _coverImage,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    return isWeb ? _buildWebView() : _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: Column(
        children: [
          WebHeader(onSearch: (_) {}),
          Expanded(
            child: WebStickyFooterScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1260),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 18,
                          ),
                          label: const Text('Listelerim'),
                        ),
                        const SizedBox(height: 12),
                        _buildHeaderCard(isWeb: true),
                        const SizedBox(height: 20),
                        _buildTabRow(isWeb: true),
                        const SizedBox(height: 24),
                        _buildTabContent(isWeb: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedTabIndex == 0
              ? 'Listelerim'
              : _selectedTabIndex == 1
              ? 'Değerlendirmeler'
              : _selectedTabIndex == 2
              ? 'Yakın Lokasyon'
              : _selectedTabIndex == 3
              ? 'Videolar'
              : 'Fiyat Takibi',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeaderCard(isWeb: false),
          _buildTabRow(isWeb: false),
          Expanded(child: _buildTabContent(isWeb: false)),
        ],
      ),
    );
  }

  Widget _buildHeaderCard({required bool isWeb}) {
    return Container(
      margin: EdgeInsets.fromLTRB(isWeb ? 0 : 16, 16, isWeb ? 0 : 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: isWeb ? 180 : 96,
                  width: double.infinity,
                  color: const Color(0xFFF1F0F8),
                  child: _coverImage.isEmpty
                      ? Icon(
                          Icons.image_outlined,
                          size: isWeb ? 56 : 34,
                          color: Colors.grey[400],
                        )
                      : _FlexibleImage(image: _coverImage, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -2,
                child: Container(
                  width: isWeb ? 72 : 50,
                  height: isWeb ? 72 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _logoImage.isEmpty
                        ? Icon(Icons.list_alt, color: Colors.grey[500])
                        : _FlexibleImage(image: _logoImage, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 18 : 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolvedListData['name']?.toString() ?? 'Listem',
                      style: TextStyle(
                        fontSize: isWeb ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_visibilityLabel • ${_resolvedListData['followerCount'] ?? 0} takipçi • ${_products.length} ürün',
                      style: TextStyle(
                        fontSize: isWeb ? 14 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _description,
                      style: TextStyle(
                        fontSize: isWeb ? 14 : 12,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  IconButton(
                    onPressed: _shareList,
                    icon: const Icon(Icons.share_outlined),
                    color: Colors.black87,
                  ),
                  if (_isOwnedList)
                    OutlinedButton.icon(
                      onPressed: _toggleVisibility,
                      icon: Icon(
                        _resolvedListData['isPublic'] == true
                            ? Icons.public
                            : Icons.lock_outline,
                        size: 18,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      label: Text(
                        _resolvedListData['isPublic'] == true
                            ? 'Herkese Açık'
                            : 'Özel Liste',
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (_isOwnedList) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _products.isEmpty ? null : _openBoostWizard,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('ÖNE ÇIKAR'),
                    ),
                  ] else
                    Column(
                      children: [
                        OutlinedButton(
                          onPressed: _toggleFollow,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(_isFollowing ? 'Takiptesin' : 'Takip et'),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _toggleFollowNotifications,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F0FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _appState.areProductListNotificationsEnabled(
                                        _listId,
                                      )
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_none_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _appState.areProductListNotificationsEnabled(
                                        _listId,
                                      )
                                      ? 'Bildirim Açık'
                                      : 'Bildirim Kapalı',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow({required bool isWeb}) {
    return Container(
      margin: EdgeInsets.fromLTRB(isWeb ? 0 : 16, 16, isWeb ? 0 : 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(0, 'Ürünler'),
            const SizedBox(width: 8),
            _buildTabButton(1, 'Değerlendirmeler'),
            const SizedBox(width: 8),
            _buildTabButton(2, 'Yakın Lokasyon'),
            const SizedBox(width: 8),
            _buildTabButton(3, 'Videolar'),
            const SizedBox(width: 8),
            _buildTabButton(4, 'Fiyat'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent({required bool isWeb}) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildProductsTab(isWeb: isWeb);
      case 1:
        return _buildReviewsTab(isWeb: isWeb);
      case 2:
        return _buildLocationTab(isWeb: isWeb);
      case 3:
        return _buildVideosTab(isWeb: isWeb);
      case 4:
        return _buildPriceTab(isWeb: isWeb);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProductsTab({required bool isWeb}) {
    if (_products.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Bu listede henüz ürün yok',
        subtitle:
            'Ürün sayfasından Listeye Ekle ile bu alana ürün ekleyebilirsin.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCrossAxisExtent = isWeb ? 230.0 : 220.0;
        final childAspectRatio = isWeb ? 0.72 : 0.62;

        return GridView.builder(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isWeb ? 0 : 16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: _products[index],
              margin: EdgeInsets.zero,
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsTab({required bool isWeb}) {
    if (_listReviews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.reviews_outlined,
        title: 'Bu listedeki ürünler için değerlendirme yok',
        subtitle: 'Liste içindeki ürünlere yapılan yorumlar burada görünür.',
      );
    }

    return ListView(
      padding: EdgeInsets.all(isWeb ? 0 : 16),
      children: [
        if (_photoReviews.isNotEmpty) ...[
          const Text(
            'Gelen Fotoğraflar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: isWeb ? 116 : 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoReviews.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final review = _photoReviews[index];
                final images = List<String>.from(
                  review['imageUrls'] ?? const [],
                );
                if (images.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _openReviewGallery(review, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(42),
                    child: SizedBox(
                      width: isWeb ? 116 : 84,
                      height: isWeb ? 116 : 84,
                      child: _FlexibleImage(
                        image: images.first,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        ..._listReviews.map(
          (review) => _ReviewCard(
            review: review,
            onOpenGallery: () => _openReviewGallery(review, 0),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationTab({required bool isWeb}) {
    if (_nearbyProducts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.location_on_outlined,
        title: 'Yakın lokasyonda gösterilecek mağaza yok',
        subtitle:
            'Liste içindeki ürünlerin satıcı mağazaları burada gösterilir.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isWeb ? 0 : 16),
      itemCount: _nearbyProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _nearbyProducts[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MapPage(product: product)),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9E6F5)),
            ),
            child: Row(
              children: [
                _ProductThumb(
                  image: product.images.isNotEmpty ? product.images.first : '',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.store ?? 'Mağaza',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.price,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Haritada Aç',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosTab({required bool isWeb}) {
    if (_videoProducts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.videocam_outlined,
        title: 'Bu listede video içeriği yok',
        subtitle: 'Ürünlere video eklendikçe burada gösterilecek.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWeb ? 0 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWeb ? 4 : 2,
        childAspectRatio: isWeb ? 0.78 : 0.74,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: _videoProducts.length,
      itemBuilder: (context, index) {
        final product = _videoProducts[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(product: product),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8E5F4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: _FlexibleImage(
                            image: product.images.isNotEmpty
                                ? product.images.first
                                : '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.52),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.price,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceTab({required bool isWeb}) {
    return FutureBuilder<List<ProductListPriceChange>>(
      future: _priceChangesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final changes = snapshot.data ?? const [];
        if (changes.isEmpty) {
          return _buildEmptyState(
            icon: Icons.price_change_outlined,
            title: 'Henüz fiyat değişimi yok',
            subtitle:
                'Bu sekmede listedeki ürünlerin fiyat düşüşlerini ve artışlarını takip edebilirsin.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(isWeb ? 0 : 16),
          itemCount: changes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = changes[index];
            final product = item.product;
            final trendColor = item.hasDropped
                ? const Color(0xFF0A8F5A)
                : const Color(0xFFD9485F);
            final trendIcon = item.hasDropped
                ? Icons.south_rounded
                : Icons.north_rounded;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAE6F4)),
              ),
              child: Row(
                children: [
                  _ProductThumb(
                    image: product.images.isNotEmpty
                        ? product.images.first
                        : '',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kaydedildiğinde: ${_formatPrice(item.savedPrice)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Şimdi: ${_formatPrice(item.currentPrice)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(trendIcon, size: 16, color: trendColor),
                            Text(
                              '${item.percentageChange.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: trendColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.delta > 0 ? '+' : '-'}${_formatPrice(item.delta.abs())}',
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 66, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareList() async {
    final shareCode = _resolvedListData['shareCode']?.toString().trim() ?? '';
    final message =
        'İBUL listesi: ${_resolvedListData['name']}\nPaylaşım kodu: $shareCode';
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Liste paylaşım bilgisi panoya kopyalandı.'),
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    final isPublic = _resolvedListData['isPublic'] == true;
    _appState.updateProductListVisibility(
      _listId,
      isPublic ? ProductListVisibility.private : ProductListVisibility.public,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPublic
              ? 'Liste tekrar özel yapıldı.'
              : 'Liste herkese açık hale getirildi.',
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isFollowing) {
      await _appState.unfollowProductList(_listId);
    } else {
      await _appState.followProductList(_listId);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleFollowNotifications() async {
    final nextValue = !_appState.areProductListNotificationsEnabled(_listId);
    await _appState.updateProductListFollowNotifications(
      _listId,
      enabled: nextValue,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue
              ? 'Bu liste için yeni ürün bildirimleri açıldı.'
              : 'Bu liste için bildirimler kapatıldı.',
        ),
      ),
    );
  }

  String _formatPrice(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.last;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final reverseIndex = whole.length - i;
      buffer.write(whole[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    if (decimal == '00') {
      return '${buffer.toString()} TL';
    }
    return '${buffer.toString()},$decimal TL';
  }

  void _openReviewGallery(Map<String, dynamic> review, int imageIndex) {
    final galleryItems = <Map<String, dynamic>>[];
    var initialIndex = 0;
    for (final currentReview in _photoReviews) {
      final images = List<String>.from(currentReview['imageUrls'] ?? const []);
      for (var index = 0; index < images.length; index++) {
        if (currentReview['id'] == review['id'] && index == imageIndex) {
          initialIndex = galleryItems.length;
        }
        galleryItems.add({
          'imageUrl': images[index],
          'userName': currentReview['userName'],
          'comment': currentReview['comment'],
          'rating': currentReview['rating'],
          'date': currentReview['createdAt'],
          'productName': currentReview['productName'],
        });
      }
    }
    if (galleryItems.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            PhotoReviewDetailPage(
              galleryItems: galleryItems,
              initialIndex: initialIndex,
            ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onOpenGallery});

  final Map<String, dynamic> review;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(review['imageUrls'] ?? const []);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E3F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review['userName']?.toString() ?? 'Kullanıcı',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                _formatDate(review['createdAt']?.toString()),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review['comment']?.toString() ?? '',
            style: const TextStyle(height: 1.5, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                (review['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                final rating = (review['rating'] as num?)?.toDouble() ?? 0;
                return Icon(
                  index < rating.round() ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF6B800),
                  size: 20,
                );
              }),
              const Spacer(),
              if (images.isNotEmpty)
                InkWell(
                  onTap: onOpenGallery,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD6D1E7)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _FlexibleImage(
                            image: images.first,
                            fit: BoxFit.cover,
                          ),
                          if (images.length > 1)
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '+${images.length - 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: image.isEmpty
            ? Icon(Icons.image_outlined, color: Colors.grey[400])
            : _FlexibleImage(image: image, fit: BoxFit.cover),
      ),
    );
  }
}

class _FlexibleImage extends StatelessWidget {
  const _FlexibleImage({required this.image, this.fit = BoxFit.cover});

  final String image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) {
      return const SizedBox.shrink();
    }
    if (image.startsWith('data:image/')) {
      final parts = image.split(',');
      final bytes = base64Decode(parts.last);
      return Image.memory(bytes, fit: fit);
    }
    if (image.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        image,
        fit: fit,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFF3F2F8),
          child: const Icon(Icons.image_outlined, color: Colors.grey),
        ),
      );
    }
    return Image.asset(
      image,
      fit: fit,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFF3F2F8),
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      ),
    );
  }
}
