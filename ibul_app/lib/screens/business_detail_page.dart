import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../models/product_list_model.dart';
import '../models/db_product.dart';
import '../services/store_service.dart';
import '../services/supabase_service.dart';
import '../services/product_list_service.dart';
import '../services/push_notification_service.dart';
import '../utils/text_normalizer.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_sidebar.dart';
import '../services/coupon_service.dart';
import '../widgets/common/video_player_widget.dart';
import '../services/campaign_service.dart';
import 'chat_page.dart';
import 'list_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessDetailPage extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Product>? storeProducts;
  final bool forceTableSelection;
  final int? initialTableNumber;
  final String? initialProductQuery;

  const BusinessDetailPage({
    super.key,
    required this.business,
    this.storeProducts,
    this.forceTableSelection = false,
    this.initialTableNumber,
    this.initialProductQuery,
  });

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;
  bool _showProductReviews = true;
  bool _isFollowing = false;
  bool _isNotificationsEnabled = false;
  String _searchQuery = '';
  bool _isLoadingProducts = false;
  int _activeSellerReviewTab = 0;

  // Duyuru Banner için controller ve timer
  PageController? _announcementPageController;
  Timer? _announcementTimer;
  int _currentAnnouncementPage = 0;

  // Web Scroll Controller and Keys
  final ScrollController _webScrollController = ScrollController();
  final GlobalKey _flashProductsKey = GlobalKey();
  final GlobalKey _campaignsKey = GlobalKey();
  final GlobalKey _allProductsKey = GlobalKey();

  // Garson / Masa Sipariş state
  bool _diningPopupShown = false;
  bool _hasAutoOpenedDiningFlow = false;
  bool _isLoadingTables = false;
  List<int> _availableTableNumbers = <int>[];
  String _activeWebTab = 'Ana Sayfa';

  /// Satıcı panelinde yüklenen logo, duyuru banner'ları (Supabase'den)
  Map<String, dynamic>? _storePublicInfo;

  /// Mağaza kampanyaları (satıcı panelinden oluşturulanlar); boşsa kupon bölümü gizlenir
  List<StoreCampaign> _storeCampaigns = [];
  final ProductListService _productListService = ProductListService.instance;
  final AppState _appState = AppState();
  List<ProductList> _publicSellerLists = const [];
  bool _isLoadingPublicSellerLists = false;
  String _lastObservedProductListsSignature = '';

  late List<String> _categories;
  late List<Product> _allProducts;

  String _normalize(String s) {
    return TextNormalizer.normalize(s);
  }

  String _productListsSignature(Iterable<ProductList> lists) {
    return lists
        .map(
          (list) =>
              '${list.id}|${list.visibility.dbValue}|${list.updatedAt.toIso8601String()}|${list.productCount}',
        )
        .join('||');
  }

  void _handleAppStateChanged() {
    final nextSignature = _productListsSignature(_appState.productLists);
    if (nextSignature == _lastObservedProductListsSignature) {
      return;
    }
    _lastObservedProductListsSignature = nextSignature;
    unawaited(_loadPublicSellerLists());
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 2) {
      unawaited(_loadPublicSellerLists());
    }
  }

  Product _convertToProduct(DBProduct dbProduct) {
    List<String> images = [];
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        if (dbProduct.imageUrl.isNotEmpty) images.add(dbProduct.imageUrl);
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }

    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags
          .split('|')
          .map<String>((e) => e.toString().trim())
          .toList();
    }

    List<String>? attributes;
    if (dbProduct.attributes != null && dbProduct.attributes!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.attributes!);
        if (decoded is List) {
          attributes = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return Product(
      productId: dbProduct.id,
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
      attributes: attributes,
    );
  }

  Future<void> _fetchStoreProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final storeName = widget.business['name'].toString();
      List<Product> storeProducts = [];

      String? sellerId = widget.business['seller_id']?.toString();
      sellerId ??= await StoreService().getSellerIdByBusinessName(storeName);

      if (sellerId != null && sellerId.isNotEmpty) {
        try {
          final supaProducts = await StoreService().getProductsBySellerId(
            sellerId,
          );
          if (supaProducts.isNotEmpty) {
            storeProducts = supaProducts.map<Product>((map) {
              final data = Map<String, dynamic>.from(map);

              final images = <String>[];
              final mainImage = data['image_url']?.toString();
              if (mainImage != null && mainImage.isNotEmpty) {
                images.add(mainImage);
              }

              List<String>? attributes;
              final rawAttrs = data['attributes'];
              if (rawAttrs is List) {
                attributes = rawAttrs.map((e) => e.toString()).toList();
              } else if (rawAttrs is String && rawAttrs.isNotEmpty) {
                try {
                  final decoded = json.decode(rawAttrs);
                  if (decoded is List) {
                    attributes = decoded.map((e) => e.toString()).toList();
                  }
                } catch (_) {}
              }

              final rawPrice = data['price'];
              String priceStr;
              if (rawPrice is num) {
                priceStr = '₺${rawPrice.toStringAsFixed(0)}';
              } else {
                priceStr = rawPrice?.toString() ?? '';
              }

              return Product(
                name: data['name']?.toString() ?? '',
                brand: widget.business['name']?.toString() ?? '',
                price: priceStr,
                rating: 0,
                reviewCount: 0,
                tags: const [],
                images: images,
                store: storeName,
                category: widget.business['category']?.toString(),
                subCategory: data['sub_category']?.toString(),
                description: null,
                specifications: null,
                oldPrice: null,
                attributes: attributes,
              );
            }).toList();
          }
        } catch (e) {
          print('Supabase ürünleri yüklenirken hata: $e');
        }
      }

      if (storeProducts.isEmpty) {
        final paged = await SupabaseService.instance
            .getProductsByStoreNamePaged(storeName: storeName, limit: 60);
        storeProducts = paged.items.map(_convertToProduct).toList();

        if (storeProducts.isEmpty) {
          print('⚠️ DB\'de ürün bulunamadı, JSON\'dan manuel aranıyor...');
          try {
            final jsonString = await DefaultAssetBundle.of(
              context,
            ).loadString('assets/urunler.json');
            final List<dynamic> jsonList = json.decode(jsonString);

            final jsonProducts = jsonList
                .where((item) {
                  final itemStore = item['magaza']?.toString() ?? '';
                  return _normalize(itemStore) == _normalize(storeName) ||
                      itemStore.toLowerCase().contains(storeName.toLowerCase());
                })
                .map((item) {
                  List<String> images = [];
                  if (item['gorseller'] != null &&
                      (item['gorseller'] as List).isNotEmpty) {
                    images = (item['gorseller'] as List)
                        .map((e) => e.toString())
                        .toList();
                  }

                  List<String> tags = [];
                  if (item['etiketler'] != null) {
                    tags = (item['etiketler'] as List)
                        .map((e) => e.toString())
                        .toList();
                  }

                  return Product(
                    name: item['isim'],
                    brand: item['marka'] ?? '',
                    price: "${item['fiyat']} TL",
                    oldPrice: item['eski_fiyat'] != null
                        ? "${item['eski_fiyat']} TL"
                        : null,
                    rating: (item['puan'] as num).toDouble(),
                    reviewCount: item['degerlendirme'] ?? 0,
                    images: images,
                    tags: tags,
                    store: item['magaza'],
                    category: item['kategori'],
                    subCategory: item['alt_kategori'],
                    description: item['aciklama'],
                    specifications: item['ozellikler'] != null
                        ? json.encode(item['ozellikler'])
                        : null,
                  );
                })
                .toList();

            if (jsonProducts.isNotEmpty) {
              storeProducts = jsonProducts;
              print(
                '✅ JSON\'dan ${storeProducts.length} ürün bulundu ve yüklendi.',
              );
            } else {
              print('❌ JSON\'da da bu mağaza için ürün bulunamadı.');
            }
          } catch (e) {
            print('Error loading JSON fallback: $e');
          }
        }
      }

      print('✅ Sonuç: ${storeProducts.length} ürün listelenecek.');

      if (mounted) {
        setState(() {
          if (storeProducts.isNotEmpty) {
            _allProducts = storeProducts;
          } else {
            _allProducts = [];
          }
          _categories = _extractCategories();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      print('Error fetching store products: $e');
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _allProducts;
    final query = _searchQuery.toLowerCase();
    return _allProducts.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _lastObservedProductListsSignature = _productListsSignature(
      _appState.productLists,
    );
    _appState.addListener(_handleAppStateChanged);
    _tabController.addListener(_handleTabChanged);
    _isFollowing = _appState.isFollowingStore(widget.business);
    _searchQuery = widget.initialProductQuery?.trim().toLowerCase() ?? '';

    // Duyuru banner controller - initState'te viewportFraction belirtmeden başlat
    _announcementPageController = PageController();
    _startAnnouncementAutoScroll();

    if (widget.storeProducts != null && widget.storeProducts!.isNotEmpty) {
      _allProducts = widget.storeProducts!;
    } else {
      _allProducts = [];
    }
    _categories = _extractCategories();
    _loadNotificationPreference();
    _fetchStoreProducts();
    _loadStoreTables();
    _loadStorePublicInfo();
    _loadStoreCampaigns();
    _loadPublicSellerLists();

    // QR ile zorunlu masa seçiminde kategoriye bakmadan sipariş akışını aç.
    // Normal akışta sadece yemek/restoran mağazalarında garson popup'ı göster.
    final category =
        widget.business['category']?.toString().toLowerCase() ?? '';
    final isFoodCategory =
        category.contains('yemek') ||
        category.contains('restoran') ||
        category.contains('kafe') ||
        category.contains('cafe');
    if (widget.forceTableSelection || isFoodCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_diningPopupShown) {
          _diningPopupShown = true;
          if (widget.forceTableSelection) {
            _openForcedDiningFlowWhenReady();
          } else {
            _showDiningModePopup(context);
          }
        }
      });
    }
  }

  String get _storeNotificationPreferenceKey {
    final identifiers = [
      widget.business['id']?.toString().trim() ?? '',
      widget.business['seller_id']?.toString().trim() ?? '',
      widget.business['name']?.toString().trim().toLowerCase() ?? '',
    ].where((value) => value.isNotEmpty);
    final rawIdentifier = identifiers.isNotEmpty ? identifiers.first : 'store';
    final safeIdentifier = rawIdentifier.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'business_notification_test_$safeIdentifier';
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_storeNotificationPreferenceKey) ?? false;
    if (!mounted) return;
    setState(() {
      _isNotificationsEnabled = enabled;
    });
  }

  Future<void> _persistNotificationPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storeNotificationPreferenceKey, enabled);
  }

  Future<void> _handleNotificationBellTap() async {
    final storeName =
        widget.business['name']?.toString().trim().isNotEmpty == true
        ? widget.business['name'].toString().trim()
        : 'Mağaza';
    final productQuery = widget.initialProductQuery?.trim();
    final body = productQuery != null && productQuery.isNotEmpty
        ? "'$productQuery' için test bildirimi 3 saniye sonra gelecek. $storeName mağazasını bildirimden açabilirsin."
        : '$storeName için test bildirimi 3 saniye sonra gelecek.';

    try {
      if (!_isNotificationsEnabled) {
        setState(() {
          _isNotificationsEnabled = true;
        });
        await _persistNotificationPreference(true);
      }

      final notificationShown = await PushNotificationService.instance
          .showNearbyStoreNotificationAfterDelay(
            storeName: storeName,
            body: body,
            initialStoreProductQuery: productQuery,
            delaySeconds: 3,
          );

      if (!notificationShown) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sistem bildirimi kapalı. iPhone Ayarlar > Bildirimler > Ibul App içinden izin ver.',
            ),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test bildirimi 3 saniye sonra gelecek.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bildirim gösterilemedi: $error'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleFollowStore() {
    setState(() {
      AppState().toggleFollowStore(widget.business);
      _isFollowing = !_isFollowing;
    });
  }

  Future<void> _openForcedDiningFlowWhenReady() async {
    if (_hasAutoOpenedDiningFlow) return;
    _hasAutoOpenedDiningFlow = true;

    final initialTable = widget.initialTableNumber;
    if (initialTable != null && initialTable > 0) {
      _showFoodOrderDialog(context, initialTable);
      return;
    }

    // Masa numarası QR'dan gelmediyse kısa süre masa listesinin yüklenmesini bekle.
    var attempts = 0;
    while (mounted && attempts < 15 && _isLoadingTables) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      attempts++;
    }
    if (!mounted) return;

    _showTableSelection(context);
  }

  Future<void> _loadStoreTables() async {
    final businessName = widget.business['name']?.toString() ?? '';
    String? sellerId = widget.business['seller_id']?.toString();
    if ((sellerId ?? '').trim().isEmpty && businessName.isNotEmpty) {
      sellerId = await StoreService().getSellerIdByBusinessName(businessName);
    }

    if ((sellerId ?? '').trim().isEmpty) {
      if (mounted) {
        setState(() => _availableTableNumbers = <int>[]);
      }
      return;
    }

    setState(() => _isLoadingTables = true);
    try {
      final numbers = await StoreService().getActiveTableNumbers(sellerId!);
      if (!mounted) return;
      setState(() {
        _availableTableNumbers = numbers;
      });
    } catch (_) {
      // Keep default fallback behavior if table system is not configured yet.
    } finally {
      if (mounted) {
        setState(() => _isLoadingTables = false);
      }
    }
  }

  Future<void> _loadStoreCampaigns() async {
    final name = widget.business['name']?.toString();
    if (name == null || name.isEmpty) return;
    try {
      final campaigns = await CampaignService().getStoreCampaignsByBusinessName(
        name,
      );
      if (mounted) setState(() => _storeCampaigns = campaigns);
    } catch (_) {}
  }

  Future<void> _loadStorePublicInfo() async {
    final name = widget.business['name']?.toString();
    if (name == null || name.isEmpty) return;
    try {
      final info = await StoreService().getStorePublicInfoByBusinessName(name);
      if (mounted) setState(() => _storePublicInfo = info);
    } catch (_) {}
  }

  bool _matchesLocalSellerPublicList(
    ProductList list, {
    required String sellerId,
    required String businessName,
    required bool isViewingOwnStore,
  }) {
    if (!list.isPublic) return false;

    if (isViewingOwnStore) {
      return true;
    }

    final normalizedSellerId = sellerId.trim();
    final normalizedBusinessName = _normalize(businessName);
    final listSellerId = (list.sellerId ?? '').trim();
    final listStoreName = list.storeName?.trim() ?? '';
    final ownerUserId = (list.ownerUserId ?? '').trim();

    if (normalizedSellerId.isNotEmpty &&
        (ownerUserId == normalizedSellerId ||
            listSellerId == normalizedSellerId)) {
      return true;
    }

    if (normalizedBusinessName.isNotEmpty &&
        listStoreName.isNotEmpty &&
        _normalize(listStoreName) == normalizedBusinessName) {
      return true;
    }

    if (list.products.isEmpty) return false;

    return list.products.any((product) {
      final productSellerId = (product.sellerId ?? '').trim();
      if (normalizedSellerId.isNotEmpty &&
          productSellerId == normalizedSellerId) {
        return true;
      }

      final productStore = product.store?.trim() ?? '';
      return normalizedBusinessName.isNotEmpty &&
          productStore.isNotEmpty &&
          _normalize(productStore) == normalizedBusinessName;
    });
  }

  String _sellerPublicListMatchReason(
    ProductList list, {
    required SellerProfilePublicListsFetchResult remoteResult,
    required String sellerId,
    required String businessName,
    required bool isViewingOwnStore,
    required bool cameFromLocal,
  }) {
    final reasons = <String>[];
    if (remoteResult.ownerScopedIds.contains(list.id)) {
      reasons.add('owner_user_id');
    }
    if (remoteResult.directScopedIds.contains(list.id)) {
      reasons.add('product_lists.seller_id/store_name');
    }
    if (remoteResult.itemScopedIds.contains(list.id)) {
      reasons.add('product_list_items.seller_id/store_name');
    }
    if (cameFromLocal && isViewingOwnStore) {
      reasons.add('local_public_self_store');
    }

    final normalizedSellerId = sellerId.trim();
    final normalizedBusinessName = _normalize(businessName);
    if (normalizedSellerId.isNotEmpty &&
        (list.ownerUserId ?? '').trim() == normalizedSellerId) {
      reasons.add('list.owner_user_id==seller_id');
    }
    if (normalizedSellerId.isNotEmpty &&
        (list.sellerId ?? '').trim() == normalizedSellerId) {
      reasons.add('list.seller_id==seller_id');
    }
    if (normalizedBusinessName.isNotEmpty &&
        (list.storeName ?? '').trim().isNotEmpty &&
        _normalize(list.storeName!) == normalizedBusinessName) {
      reasons.add('list.store_name==business_name');
    }
    if (list.products.any(
      (product) =>
          normalizedSellerId.isNotEmpty &&
          (product.sellerId ?? '').trim() == normalizedSellerId,
    )) {
      reasons.add('item.product.sellerId==seller_id');
    }
    if (list.products.any(
      (product) =>
          normalizedBusinessName.isNotEmpty &&
          (product.store ?? '').trim().isNotEmpty &&
          _normalize(product.store!) == normalizedBusinessName,
    )) {
      reasons.add('item.product.store==business_name');
    }

    return reasons.isEmpty ? 'no-match-signal' : reasons.join(', ');
  }

  void _debugLogPublicSellerLists({
    required String sellerId,
    required String currentUserId,
    required String businessName,
    required SellerProfilePublicListsFetchResult remoteResult,
    required List<ProductList> localLists,
    required List<ProductList> mergedLists,
    required bool isViewingOwnStore,
  }) {
    if (!kDebugMode) return;

    final remoteIds = remoteResult.lists.map((list) => list.id).toSet();
    final localIds = localLists.map((list) => list.id).toSet();

    debugPrint('[SellerProfile][Listeler] sellerId=$sellerId');
    debugPrint('[SellerProfile][Listeler] currentUserId=$currentUserId');
    debugPrint('[SellerProfile][Listeler] businessName=$businessName');
    debugPrint(
      '[SellerProfile][Listeler] fetched remote lists count=${remoteResult.lists.length} '
      '(owner=${remoteResult.ownerScopedCount}, direct=${remoteResult.directScopedCount}, items=${remoteResult.itemScopedCount})',
    );
    debugPrint(
      '[SellerProfile][Listeler] fetched local lists count=${localLists.length}',
    );
    debugPrint(
      '[SellerProfile][Listeler] public list count=${mergedLists.where((list) => list.isPublic).length}',
    );

    for (final list in mergedLists) {
      final source = remoteIds.contains(list.id) && localIds.contains(list.id)
          ? 'remote+local'
          : remoteIds.contains(list.id)
          ? 'remote'
          : 'local';
      final matchReason = _sellerPublicListMatchReason(
        list,
        remoteResult: remoteResult,
        sellerId: sellerId,
        businessName: businessName,
        isViewingOwnStore: isViewingOwnStore,
        cameFromLocal: localIds.contains(list.id),
      );
      debugPrint(
        '[SellerProfile][Listeler] list=${list.id} owner_user_id=${list.ownerUserId} '
        'seller_id=${list.sellerId} store_name=${list.storeName} '
        'is_public=${list.isPublic} source=$source matched_reason=$matchReason',
      );
    }
  }

  Future<void> _loadPublicSellerLists() async {
    final businessName = widget.business['name']?.toString().trim() ?? '';
    var sellerId = widget.business['seller_id']?.toString().trim() ?? '';
    if (sellerId.isEmpty && businessName.isNotEmpty) {
      sellerId =
          await StoreService().getSellerIdByBusinessName(businessName) ?? '';
    }
    final currentStoreProfile = await StoreService().getStoreProfile();
    final currentStoreName =
        currentStoreProfile?['storeName']?.toString().trim() ?? '';
    final currentUserId = _productListService.currentUserId?.trim() ?? '';
    final isViewingOwnStore =
        (currentUserId.isNotEmpty &&
            sellerId.isNotEmpty &&
            currentUserId == sellerId) ||
        currentStoreName.isNotEmpty &&
            businessName.isNotEmpty &&
            _normalize(currentStoreName) == _normalize(businessName);

    if (!mounted) return;
    setState(() => _isLoadingPublicSellerLists = true);

    try {
      final remoteResult = await _productListService
          .getPublicListsForSellerProfile(
            sellerId: isViewingOwnStore && currentUserId.isNotEmpty
                ? currentUserId
                : sellerId,
            businessName: businessName,
          );
      final localLists = _appState.productLists
          .where(
            (list) => _matchesLocalSellerPublicList(
              list,
              sellerId: sellerId,
              businessName: businessName,
              isViewingOwnStore: isViewingOwnStore,
            ),
          )
          .toList(growable: false);
      final mergedById = <String, ProductList>{};
      for (final list in remoteResult.lists) {
        mergedById[list.id] = list;
      }
      for (final list in localLists) {
        mergedById[list.id] = list;
      }
      final mergedLists = mergedById.values.toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _debugLogPublicSellerLists(
        sellerId: sellerId,
        currentUserId: currentUserId,
        businessName: businessName,
        remoteResult: remoteResult,
        localLists: localLists,
        mergedLists: mergedLists,
        isViewingOwnStore: isViewingOwnStore,
      );
      if (!mounted) return;
      setState(() {
        _publicSellerLists = mergedLists
            .where((list) => list.isPublic)
            .toList(growable: false);
        _isLoadingPublicSellerLists = false;
      });
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          '[SellerProfile][Listeler] public list load failed for '
          'sellerId=$sellerId businessName=$businessName',
        );
      }
      if (!mounted) return;
      setState(() {
        _publicSellerLists = const [];
        _isLoadingPublicSellerLists = false;
      });
    }
  }

  String _sellerListCover(ProductList list) {
    final iconUrl = list.iconUrl?.trim() ?? '';
    if (iconUrl.isNotEmpty) return iconUrl;
    if (list.products.isNotEmpty && list.products.first.images.isNotEmpty) {
      return list.products.first.images.first;
    }
    return '';
  }

  void _openSellerPublicList(ProductList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ListDetailPage(listData: AppState().productListToMap(list)),
      ),
    );
  }

  Widget _buildSellerPublicListsSection({required bool isWeb}) {
    if (_isLoadingPublicSellerLists) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isWeb ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 18 : 14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_publicSellerLists.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listeler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bu mağazanın herkese açık yayınladığı listeleri buradan inceleyebilirsiniz.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: _publicSellerLists
                .map(
                  (list) => SizedBox(
                    width: 280,
                    child: _buildSellerPublicListCard(list, isWeb: true),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listeler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Satıcının herkese açık yayınladığı listeler burada görünür.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _publicSellerLists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 220,
                  child: _buildSellerPublicListCard(
                    _publicSellerLists[index],
                    isWeb: false,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerPublicListCard(ProductList list, {required bool isWeb}) {
    final coverImage = _sellerListCover(list);
    final category = (list.category ?? '').trim();
    final description = (list.description ?? '').trim();

    return InkWell(
      onTap: () => _openSellerPublicList(list),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: isWeb ? 150 : 122,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              clipBehavior: Clip.antiAlias,
              child: coverImage.isNotEmpty
                  ? Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildSellerPublicListPlaceholder(),
                    )
                  : _buildSellerPublicListPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          list.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isWeb ? 16 : 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Açık',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description.isEmpty
                        ? 'Bu listede seçili ürünler sergileniyor.'
                        : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSellerPublicListMetaChip(
                        Icons.inventory_2_outlined,
                        '${list.productCount} ürün',
                      ),
                      if (category.isNotEmpty)
                        _buildSellerPublicListMetaChip(
                          Icons.category_outlined,
                          category,
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

  Widget _buildSellerPublicListMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerPublicListPlaceholder() {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      child: const Icon(
        Icons.collections_bookmark_outlined,
        color: Color(0xFF64748B),
        size: 34,
      ),
    );
  }

  void _startAnnouncementAutoScroll() {
    _announcementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_announcementPageController?.hasClients ?? false) {
        final bannerUrls =
            (_storePublicInfo?['banners'] as List<dynamic>?)?.length ?? 0;
        final bannerPaths = _getStoreBannerPaths(
          widget.business['name'].toString(),
        );
        final totalBanners = 1 + bannerUrls + bannerPaths.length;

        _currentAnnouncementPage =
            (_currentAnnouncementPage + 1) % totalBanners;
        _announcementPageController?.animateToPage(
          _currentAnnouncementPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  List<String> _extractCategories() {
    final categorySet = <String>{};

    // "Tümü" her zaman ilk sırada
    final categories = ['Tümü'];

    // Ürünlerden benzersiz kategorileri topla
    for (var product in _allProducts) {
      if (product.subCategory != null && product.subCategory!.isNotEmpty) {
        categorySet.add(product.subCategory!);
      } else if (product.category != null && product.category!.isNotEmpty) {
        categorySet.add(product.category!);
      }
    }

    // Alfabetik sırala ve listeye ekle
    categories.addAll(categorySet.toList()..sort());

    return categories;
  }

  @override
  void dispose() {
    _appState.removeListener(_handleAppStateChanged);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _webScrollController.dispose();
    _announcementTimer?.cancel();
    _announcementPageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    if (isWeb) {
      return _buildWebLayout();
    }

    final businessName = widget.business['name'] ?? 'Mağaza';
    final businessRating = widget.business['rating']?.toString() ?? '8.2';
    final businessFollowers =
        widget.business['followers']?.toString() ?? '9.8B Takipçi';

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              backgroundColor: AppColors.primary,
              pinned: true,
              floating: false,
              expandedHeight: 200.0, // Reduced height to decrease gap
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.primary,
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).padding.top +
                        45, // Slightly reduced top padding
                    left: 16,
                    right: 16,
                    bottom: 48, // Adjusted bottom padding
                  ),
                  child: Column(
                    children: [
                      // Business Info Row
                      Row(
                        children: [
                          // Logo (Supabase veya asset)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildStoreLogoWidget(businessName, 40),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Name & Rating
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        businessName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        businessRating,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  businessFollowers,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Follow Button & Bell Icon
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _handleNotificationBellTap,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _isNotificationsEnabled
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    _isNotificationsEnabled
                                        ? Icons.notifications_active
                                        : Icons.notifications_none,
                                    color: _isNotificationsEnabled
                                        ? Colors.amber.shade700
                                        : Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: _toggleFollowStore,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing
                                        ? AppColors.primary
                                        : Colors.white,
                                    foregroundColor: _isFollowing
                                        ? Colors.white
                                        : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: _isFollowing
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    elevation: 0,
                                    overlayColor: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  child: Text(
                                    _isFollowing
                                        ? 'Takip Ediliyor'
                                        : 'Takip Et',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8), // Reduced spacing from 12 to 8
                      // Search Bar & Actions Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 36, // Smaller vertically
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                onChanged: (value) => setState(
                                  () => _searchQuery = value.toLowerCase(),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Mağazada Ara',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ), // Centered vertically
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 13),
                                textAlignVertical: TextAlignVertical.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Chat Button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChatPage(seller: widget.business),
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Share Button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.share_outlined,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppColors.primary, // Keep purple background
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Ana Sayfa'),
                      Tab(text: 'Tüm Ürünler'),
                      Tab(text: 'Listeler'),
                      Tab(text: 'Satıcı'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAnaSayfaTab(),
            _buildTumUrunlerTab(),
            _buildListelerTab(),
            _buildSaticiTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    final businessName = widget.business['name'] ?? 'Mağaza';
    final businessRating = widget.business['rating']?.toString() ?? '8.2';
    final businessFollowers =
        widget.business['followers']?.toString() ?? '9.8B Takipçi';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        controller: _webScrollController,
        child: Column(
          children: [
            // 1. Üst Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      // Logo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: _buildStoreLogoWidget(businessName, 60),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name & Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                businessName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27AE60),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  businessRating,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Text(
                                'Satıcı Profili',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Follow Button & Count
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _handleNotificationBellTap,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _isNotificationsEnabled
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    _isNotificationsEnabled
                                        ? Icons.notifications_active
                                        : Icons.notifications_none,
                                    color: _isNotificationsEnabled
                                        ? Colors.amber.shade700
                                        : Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _toggleFollowStore,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? AppColors.primary
                                      : Colors.white,
                                  foregroundColor: _isFollowing
                                      ? Colors.white
                                      : AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: BorderSide(
                                      color: _isFollowing
                                          ? Colors.white
                                          : AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  overlayColor: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                                child: Text(
                                  _isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            businessFollowers,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Navigation Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  height: 60,
                  child: Row(
                    children: [
                      _buildWebNavLink(
                        'Ana Sayfa',
                        _activeWebTab == 'Ana Sayfa',
                        onTap: () {
                          setState(() => _activeWebTab = 'Ana Sayfa');
                          _webScrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      _buildWebNavLink(
                        'Tüm Ürünler',
                        _activeWebTab == 'Tüm Ürünler',
                        onTap: () {
                          setState(() => _activeWebTab = 'Tüm Ürünler');
                          // Wait for layout to settle if switching tabs
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (_allProductsKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                _allProductsKey.currentContext!,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                alignment: 0.0,
                              );
                            }
                          });
                        },
                      ),
                      _buildWebNavLink(
                        'Listeler',
                        _activeWebTab == 'Listeler',
                        onTap: () {
                          setState(() => _activeWebTab = 'Listeler');
                          unawaited(_loadPublicSellerLists());
                          _webScrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      _buildWebNavLink(
                        'Satıcı',
                        _activeWebTab == 'Satıcı',
                        onTap: () {
                          setState(() => _activeWebTab = 'Satıcı');
                          _webScrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      const Spacer(),
                      // Search Bar
                      Container(
                        width: 300,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Mağazada ara',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey,
                            ), // Sola eklendi, screenshotta sağda ama standart UI
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Main Content
            if (_activeWebTab == 'Satıcı')
              _buildWebSellerTab()
            else if (_activeWebTab == 'Listeler')
              _buildWebListelerTab()
            else if (_activeWebTab == 'Tüm Ürünler')
              _buildWebAllProductsTab()
            else
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ana sayfada soldaki filtre alanı kaldırıldı, içerik tam genişlikte
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            _buildDuyurularSection(),

                            const SizedBox(height: 40),

                            // Mağaza Kuponları - Sadece satıcı panelinden oluşturulan kampanyalar varsa
                            if (_storeCampaigns.isNotEmpty) ...[
                              Text(
                                'Mağaza Kuponları',
                                key: _campaignsKey,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final c in _storeCampaigns) ...[
                                      _buildStoreCampaignCard(c),
                                      const SizedBox(width: 16),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],

                            // Öne Çıkan Ürünler Grid
                            Text(
                              'Öne Çıkan Ürünler',
                              key: _allProductsKey,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // _buildCategoryList(), // Removed as requested
                            // const SizedBox(height: 24),
                            _buildProductGrid(), // Reusing existing grid, responsive logic inside handles sizing
                            const SizedBox(height: 40),

                            // Footer Features Banner
                            _buildWebFeaturesBanner(),
                            const SizedBox(height: 40),
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

  Widget _buildWebFeaturesBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFE5D9F2), // Light purple background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFeatureItem(
            Icons.local_shipping_outlined,
            'Ücretsiz Kargo',
            '150 TL üzeri',
          ),
          _buildDivider(),
          _buildFeatureItem(
            Icons.verified_user_outlined,
            'Güvenli Ödeme',
            '256-bit SSL',
          ),
          _buildDivider(),
          _buildFeatureItem(Icons.refresh, '14 Gün İade', 'Koşulsuz iade'),
          _buildDivider(),
          _buildFeatureItem(
            Icons.headset_mic_outlined,
            '7/24 Destek',
            'Canlı yardım',
          ),
          _buildDivider(),
          _buildFeatureItem(
            Icons.verified_outlined,
            'Orijinal Ürün',
            'Garantili',
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.5),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6200EE), size: 32),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebNavLink(String title, bool isActive, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withOpacity(0.12),
          hoverColor: AppColors.primary.withOpacity(0.08),
          focusColor: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              border: isActive
                  ? Border(
                      bottom: BorderSide(color: AppColors.primary, width: 3),
                    )
                  : null,
            ),
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? AppColors.primary : Colors.black87,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCampaignDuration(StoreCampaign c) {
    final end = c.endDate;
    final now = DateTime.now();
    if (end.isBefore(now)) return 'Süresi doldu';
    final diff = end.difference(now);
    if (diff.inDays > 0) return '${diff.inDays} gün geçerli';
    if (diff.inHours > 0) return '${diff.inHours} saat geçerli';
    return 'Bugün sona eriyor';
  }

  Widget _buildStoreCampaignCard(StoreCampaign c) {
    final code = c.couponCode ?? '-';
    final title = c.discountType == 'percent'
        ? '%${c.discountValue.toInt()} İndirim'
        : '${c.discountValue.toInt()} TL İndirim';
    final subtitle = c.minCartAmount > 0
        ? '${c.minCartAmount.toInt()} TL ve üzeri alışverişlerde'
        : (c.description ?? 'Tüm ürünlerde geçerli');
    return _buildStoreCouponCard(
      title,
      subtitle,
      _formatCampaignDuration(c),
      code,
      c.discountValue,
      c.discountType == 'percent',
    );
  }

  Widget _buildStoreCouponCard(
    String title,
    String subtitle,
    String duration,
    String code,
    double amount,
    bool isPercentage,
  ) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_offer,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              // Add to coupons
              final coupon = CouponModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                description: subtitle,
                code: code,
                discountAmount: amount,
                isPercentage: isPercentage,
                minPrice: 100.0,
                expiryDate: duration, // Using duration string as requested
                color: Colors.orange.shade50,
                iconColor: Colors.orange,
              );
              CouponService().addCoupon(coupon);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$title" kuponu hesabınıza eklendi!'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Kullan'),
          ),
        ],
      ),
    );
  }

  List<String> _getStoreBannerPaths(String storeName) {
    final name = _normalize(storeName); // Normalize edilmiş isim kullanıyoruz
    String prefix = '';
    int count = 0;

    if (name.contains('teknosa')) {
      prefix = 'teknosa';
      count = 2;
    } else if (name.contains('arcelik')) {
      // _normalize 'ç' yi 'c' yapar
      prefix = 'arcelik';
      count = 2;
    } else if (name.contains('lc waikiki')) {
      prefix = 'lc-waikiki';
      count = 2;
    } else if (name.contains('destina')) {
      prefix = 'destina';
      count = 2;
    } else {
      return [];
    }

    return List.generate(count, (index) {
      return 'assets/images/banners/$prefix-duyuru-${index + 1}.png';
    });
  }

  Widget _buildStoreLogoWidget(String businessName, double size) {
    final logoUrl = _storePublicInfo?['logoUrl'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _storeLogoLetter(businessName, size),
      );
    }
    if (StoreLogoHelper.hasLogo(businessName)) {
      return Image.asset(
        StoreLogoHelper.getStoreLogo(businessName)!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return _storeLogoLetter(businessName, size);
  }

  Widget _storeLogoLetter(String businessName, double size) {
    return Center(
      child: Text(
        businessName.isNotEmpty
            ? businessName.substring(0, 1).toUpperCase()
            : '?',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  /// Duyurular alanı: önce Supabase'deki banners, yoksa asset. Tam genişlik, sola hizalı (kayma düzeltmesi).
  Widget _buildDuyurularSection() {
    final bannerUrls =
        (_storePublicInfo?['banners'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        <String>[];
    final assetBannerPaths = _getStoreBannerPaths(
      widget.business['name']?.toString() ?? '',
    );
    final hasBanners = bannerUrls.isNotEmpty || assetBannerPaths.isNotEmpty;
    if (!hasBanners) return const SizedBox.shrink();

    final count = bannerUrls.isNotEmpty
        ? bannerUrls.length
        : assetBannerPaths.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DUYURULAR',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200, // Daha kompakt bir yükseklik
          width: double.infinity,
          child: PageView.builder(
            itemCount: count,
            controller: _announcementPageController ?? PageController(),
            padEnds: false,
            itemBuilder: (context, index) {
              if (bannerUrls.isNotEmpty) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    bannerUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                );
              }
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                  image: DecorationImage(
                    image: AssetImage(assetBannerPaths[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // WEB ALL PRODUCTS TAB (NEW)
  Widget _buildWebAllProductsTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.business['name']?.toString().toUpperCase() ?? 'MAĞAZA',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${_allProducts.length}+ Ürün",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 250,
                  child: FilterSidebar(
                    categories: _categories,
                    selectedCategoryIndex: _selectedCategoryIndex,
                    onCategorySelected: (index) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                    priceRange: const RangeValues(0, 10000),
                    onPriceRangeChanged: (range) {},
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWebCategoryBar(),
                      const SizedBox(height: 16),
                      _buildProductGrid(
                        aspectRatioOverride: 0.60,
                      ), // Aspect ratio düşürüldü (0.68 -> 0.60) kart boyu uzadı
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WEB SELLER TAB
  Widget _buildWebSellerTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Başarı Rozetleri (Web)
            const Text(
              'Başarı Rozetleri',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: _getSellerBadges(widget.business['name'] ?? 'Mağaza')
                  .map(
                    (widget) => Padding(
                      padding: const EdgeInsets.only(right: 40),
                      child: Transform.scale(
                        scale: 1.2,
                        child: widget,
                      ), // Web için biraz büyüt
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 40),

            // 2. Satıcı Videoları (Web)
            if (_storePublicInfo != null &&
                _storePublicInfo!['sellerVideos'] != null &&
                (_storePublicInfo!['sellerVideos'] as List).isNotEmpty) ...[
              const Text(
                'Satıcı Videoları',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250, // Web için daha büyük
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: (_storePublicInfo!['sellerVideos'] as List).length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 24),
                  itemBuilder: (context, index) {
                    final url =
                        (_storePublicInfo!['sellerVideos'] as List)[index]
                            .toString();
                    return Container(
                      width: 180, // Web için daha geniş
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: VideoPlayerWidget(videoUrl: url),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],

            const Text(
              "Satıcı Özeti",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Web için Satıcı Özeti Grid
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: _getSellerSummaryData().map((item) {
                return _buildSellerSummaryCard(
                  icon: item['icon'],
                  title: item['title'],
                  value: item['value'],
                  isWeb: true,
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            _buildSellerPublicListsSection(isWeb: true),
            if (_publicSellerLists.isNotEmpty ||
                _isLoadingPublicSellerLists) ...[
              const SizedBox(height: 40),
            ],
            const Text(
              "Müşteri Değerlendirmeleri",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _activeSellerReviewTab = 0;
                            });
                          },
                          child: _buildReviewTabItem(
                            "Ürün Değerlendirmeleri",
                            _activeSellerReviewTab == 0,
                          ),
                        ),
                        const SizedBox(width: 32),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _activeSellerReviewTab = 1;
                            });
                          },
                          child: _buildReviewTabItem(
                            "Satıcı Değerlendirmeleri",
                            _activeSellerReviewTab == 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "4.4",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: List.generate(5, (index) {
                              if (index < 4) {
                                return const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFC107),
                                  size: 24,
                                );
                              } else {
                                return const Icon(
                                  Icons.star_half,
                                  color: Color(0xFFFFC107),
                                  size: 24,
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "1062767 Değerlendirme",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Yorum Yayınlama Kriterleri",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
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
            ),
            const SizedBox(height: 32),
            const Text(
              "Fotoğraflı Değerlendirmeler",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                      image: const DecorationImage(
                        image: NetworkImage("https://picsum.photos/200"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            if (_activeSellerReviewTab == 0)
              _buildReviewsList()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _sellerReviewCards()
                    .map((review) => _buildSellerReviewCard(review))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebListelerTab() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _buildListelerTabContent(isWeb: true),
      ),
    );
  }

  Widget _buildSellerStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    Color? borderColor,
    required Color iconColor,
    bool showInfoIcon = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: [
          if (borderColor == null)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (showInfoIcon) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTabItem(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isActive ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          color: isActive ? AppColors.primary : Colors.black87,
        ),
      ),
    );
  }

  // ANA SAYFA TAB
  Widget _buildAnaSayfaTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Duyurular - Otomatik Kayan Banner'lar
          _buildAnnouncementBanners(),
          const SizedBox(height: 20),

          // Popüler Ürünler
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Popüler Ürünler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildProductGrid(),
          const SizedBox(height: 24),
          // Alt kategori bölümü - dinamik başlık
          if (_categories.length > 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _categories[1],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildProductGrid(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // Kategori ikonları için yardımcı metot
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('telefon')) return Icons.phone_iphone;
    if (cat.contains('bilgisayar') ||
        cat.contains('laptop') ||
        cat.contains('tablet'))
      return Icons.laptop;
    if (cat.contains('televizyon') || cat.contains('tv')) return Icons.tv;
    if (cat.contains('beyaz eşya')) return Icons.kitchen;
    if (cat.contains('küçük ev')) return Icons.coffee_maker;
    if (cat.contains('aksesuar')) return Icons.headphones;
    if (cat.contains('giyim') || cat.contains('moda')) return Icons.checkroom;
    if (cat.contains('spor')) return Icons.fitness_center;
    if (cat.contains('kozmetik') || cat.contains('bakım')) return Icons.face;
    if (cat.contains('oyun') || cat.contains('gaming'))
      return Icons.sports_esports;
    return Icons.grid_view; // Varsayılan ikon
  }

  // Kategori Listesi Widget'ı - Yatay Bar Tasarımı
  Widget _buildCategoryList({EdgeInsetsGeometry? padding}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      height: isMobile ? 44 : 50,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 2),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.where((c) => c != 'Tümü').length,
        itemBuilder: (context, index) {
          final categoryList = _categories.where((c) => c != 'Tümü').toList();
          final category = categoryList[index];
          final originalIndex = _categories.indexOf(category);
          final isSelected = _selectedCategoryIndex == originalIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = originalIndex;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 16,
                vertical: isMobile ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // TÜM ÜRÜNLER TAB
  Widget _buildTumUrunlerTab() {
    return SingleChildScrollView(
      // Scrollable yapıldı
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Kategori Bar'ları (Yatay chip tasarımı)
          _buildCategoryList(
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 16),
          // Products Grid
          _buildProductGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // SATICI TAB
  Widget _buildSaticiTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Rozetler - Gelişmiş Tasarım
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Başarı Rozetleri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _getSellerBadges(
                    widget.business['name'] ?? 'Mağaza',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Satıcı Videoları
          if (_storePublicInfo != null &&
              _storePublicInfo!['sellerVideos'] != null &&
              (_storePublicInfo!['sellerVideos'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Satıcı Videoları',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180, // Yükseklik azaltıldı: 220 -> 180
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          (_storePublicInfo!['sellerVideos'] as List).length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final url =
                            (_storePublicInfo!['sellerVideos'] as List)[index]
                                .toString();
                        return Container(
                          width: 130, // Genişlik azaltıldı: 160 -> 130
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: VideoPlayerWidget(videoUrl: url),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

          // Kargo Süresi, Satıcı Konumu, Cevap Verme Hızı, Kurumsal Fatura vb. (Yatay Scroll)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Satıcı Özeti',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140, // Yükseklik kart tasarımına göre ayarlandı
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _getSellerSummaryData().length,
                    itemBuilder: (context, index) {
                      final item = _getSellerSummaryData()[index];
                      return _buildSellerSummaryCard(
                        icon: item['icon'],
                        title: item['title'],
                        value: item['value'],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSellerPublicListsSection(isWeb: false),
          if (_publicSellerLists.isNotEmpty || _isLoadingPublicSellerLists)
            const SizedBox(height: 24),

          // Satıcı Puanlaması
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSellerRatingSummaryCard(),
          ),
          const SizedBox(height: 24),

          // Gelen Fotoğraflar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                _buildReviewPhotoStrip(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Ürün/Satıcı Değerlendirmeleri Butonları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showProductReviews = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showProductReviews
                          ? AppColors.primary
                          : Colors.white,
                      foregroundColor: _showProductReviews
                          ? Colors.white
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      elevation: 0,
                      overlayColor: AppColors.primary.withOpacity(0.12),
                    ),
                    child: const Text(
                      'Ürün Değerlendirmeleri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        setState(() => _showProductReviews = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showProductReviews
                          ? AppColors.primary
                          : Colors.white,
                      foregroundColor: !_showProductReviews
                          ? Colors.white
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      elevation: 0,
                      overlayColor: AppColors.primary.withOpacity(0.12),
                    ),
                    child: const Text(
                      'Satıcı Değerlendirmeleri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Değerlendirmeler Listesi
          _buildReviewsList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildListelerTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: _buildListelerTabContent(isWeb: false),
      ),
    );
  }

  Widget _buildListelerTabContent({required bool isWeb}) {
    if (_isLoadingPublicSellerLists) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isWeb ? 24 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 18 : 14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_publicSellerLists.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isWeb ? 28 : 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 18 : 14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listeler',
              style: TextStyle(
                fontSize: isWeb ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bu satıcının herkese açık listesi henüz görünmüyor.',
              style: TextStyle(
                fontSize: isWeb ? 14 : 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (isWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listeler',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bu satıcının herkese açık yayınladığı listeler burada yer alır.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 18,
            runSpacing: 18,
            children: _publicSellerLists
                .map(
                  (list) => SizedBox(
                    width: 280,
                    child: _buildSellerPublicListCard(list, isWeb: true),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Listeler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bu satıcının herkese açık yayınladığı listeler burada yer alır.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _publicSellerLists
              .map(
                (list) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSellerPublicListCard(list, isWeb: false),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  // Product Grid Widget
  Widget _buildProductGrid({double? aspectRatioOverride}) {
    if (_isLoadingProducts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 0.62;
    double crossAxisSpacing = 12;
    double mainAxisSpacing = 12;
    double horizontalPadding = 12;

    if (screenWidth < 360) {
      crossAxisCount = 2;
      childAspectRatio = 0.60;
      crossAxisSpacing = 8;
      mainAxisSpacing = 10;
      horizontalPadding = 8;
    } else if (screenWidth >= 600) {
      crossAxisCount = 4;
      childAspectRatio = 0.72;
      crossAxisSpacing = 16;
      mainAxisSpacing = 16;
      horizontalPadding = 12;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.62;
      crossAxisSpacing = 12;
      mainAxisSpacing = 12;
      horizontalPadding = 12;
    }

    // Override aspect ratio if provided (e.g., Tüm Ürünler dikey azaltma)
    if (aspectRatioOverride != null) {
      childAspectRatio = aspectRatioOverride;
    }

    // Kategori filtresi uygula
    List<Product> displayProducts = _filteredProducts;

    if (_selectedCategoryIndex > 0 &&
        _selectedCategoryIndex < _categories.length) {
      final selectedCategory = _categories[_selectedCategoryIndex];
      displayProducts = _filteredProducts.where((product) {
        return (product.subCategory == selectedCategory) ||
            (product.category == selectedCategory);
      }).toList();
    }

    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _allProducts.isEmpty
                  ? 'Bu mağazada henüz ürün bulunmuyor'
                  : 'Bu kategoride ürün bulunamadı',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    String businessCategory = widget.business['category']?.toString() ?? '';
    businessCategory = businessCategory.toLowerCase().trim();

    bool isFoodSeller =
        businessCategory.contains('yemek') ||
        businessCategory.contains('restoran') ||
        businessCategory.contains('kafe') ||
        businessCategory.contains('cafe');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        final normalized = product.tags.isEmpty
            ? product.copyWith(tags: ['Ücretsiz Kargo'])
            : product;
        return ProductCard(
          product: normalized,
          forceFoodOrderButton: isFoodSeller,
        );
      },
    );
  }

  // Badge Widget (Rozetler için)
  Widget _buildBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Modern Badge Widget (Gelişmiş Rozetler için)
  Widget _buildModernBadge({
    required IconData icon,
    required String label,
    required Color color,
    required List<Color> gradient,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Satıcıya özel rozetleri getir
  List<Widget> _getSellerBadges(String businessName) {
    final badges = <Map<String, dynamic>>[];

    // Teknosa için özel rozetler
    if (businessName.toLowerCase().contains('teknosa')) {
      badges.addAll([
        {
          'icon': Icons.verified_user,
          'label': 'Güvenilir',
          'color': Colors.blue,
        },
        {'icon': Icons.bolt, 'label': 'Hızlı Teslimat', 'color': Colors.orange},
        {
          'icon': Icons.workspace_premium,
          'label': 'Premium',
          'color': Colors.amber,
        },
        {
          'icon': Icons.local_shipping,
          'label': 'Ücretsiz Kargo',
          'color': Colors.green,
        },
      ]);
    }
    // Arçelik için özel rozetler
    else if (businessName.toLowerCase().contains('arçelik') ||
        businessName.toLowerCase().contains('arcelik')) {
      badges.addAll([
        {'icon': Icons.star, 'label': 'Yüksek Puan', 'color': Colors.amber},
        {
          'icon': Icons.verified,
          'label': 'Onaylı Satıcı',
          'color': Colors.blue,
        },
        {
          'icon': Icons.support_agent,
          'label': 'Destek 7/24',
          'color': Colors.purple,
        },
        {
          'icon': Icons.thumb_up,
          'label': 'Tavsiye Edilen',
          'color': Colors.green,
        },
      ]);
    }
    // Beko için özel rozetler
    else if (businessName.toLowerCase().contains('beko')) {
      badges.addAll([
        {'icon': Icons.eco, 'label': 'Çevre Dostu', 'color': Colors.green},
        {'icon': Icons.shield, 'label': 'Garantili', 'color': Colors.blue},
        {
          'icon': Icons.local_shipping,
          'label': 'Hızlı Kargo',
          'color': Colors.orange,
        },
        {
          'icon': Icons.chat_bubble,
          'label': 'Hızlı Yanıt',
          'color': Colors.purple,
        },
      ]);
    }
    // Vestel için özel rozetler
    else if (businessName.toLowerCase().contains('vestel')) {
      badges.addAll([
        {'icon': Icons.inventory, 'label': 'Bol Stok', 'color': Colors.blue},
        {'icon': Icons.discount, 'label': 'İndirimli', 'color': Colors.red},
        {
          'icon': Icons.rocket_launch,
          'label': 'Aynı Gün Kargo',
          'color': Colors.orange,
        },
        {
          'icon': Icons.verified_user,
          'label': 'Güvenli',
          'color': Colors.green,
        },
      ]);
    }
    // Diğer satıcılar için varsayılan rozetler
    else {
      badges.addAll([
        {'icon': Icons.verified, 'label': 'Güvenilir', 'color': Colors.blue},
        {
          'icon': Icons.rocket_launch,
          'label': 'Hızlı Kargo',
          'color': Colors.orange,
        },
        {'icon': Icons.star, 'label': 'Yüksek Puan', 'color': Colors.amber},
        {
          'icon': Icons.local_shipping,
          'label': 'Ücretsiz Kargo',
          'color': Colors.green,
        },
      ]);
    }

    return badges
        .map(
          (badge) => _buildModernBadge(
            icon: badge['icon'] as IconData,
            label: badge['label'] as String,
            color: badge['color'] as Color,
            gradient: [], // Kullanılmıyor artık
          ),
        )
        .toList();
  }

  // Satıcı Özeti Verileri (Tek kaynak)
  List<Map<String, dynamic>> _getSellerSummaryData() {
    return [
      {
        'icon': Icons.calendar_today,
        'title': "İBUL'daki Süresi",
        'value': '1 Yıl',
      },
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'Kargo Süresi',
        'value': '5 Saat',
      },
      {
        'icon': Icons.location_on,
        'title': 'Satıcı Konumu',
        'value': 'Hatay / Antakya',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Cevap Verme Hızı',
        'value': '1 Saat',
      },
      {
        'icon': Icons.receipt_long,
        'title': 'Kurumsal Fatura',
        'value': 'Uygun',
      },
    ];
  }

  // Yeni Satıcı Özeti Kartı (Başlık üstte, Değer altta)
  Widget _buildSellerSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    bool isWeb = false,
  }) {
    return Container(
      width: isWeb ? 200 : 140, // Web'de daha geniş
      margin: EdgeInsets.only(right: isWeb ? 24 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Arka plan beyaz
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200), // Hafif gri çerçeve
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Info Card Widget (Kargo/Konum/Cevap için) - ARTIK KULLANILMIYOR AMA ESKİ KOD HATASI VERMESİN DİYE TUTUYORUM
  Widget _buildInfoCard(IconData icon, String title, String subtitle) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: isSmallScreen ? 22 : 28),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Rating Bar Widget (Puanlama için)
  Widget _buildRatingBar(String label, int count, double percentage) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 35,
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Reviews List Widget
  Widget _buildReviewsList() {
    return AnimatedBuilder(
      animation: AppState(),
      builder: (context, _) {
        final reviews = _showProductReviews
            ? _productReviewCards()
            : _sellerReviewCards();
        if (reviews.isEmpty) {
          return _buildEmptyReviewState(
            _showProductReviews
                ? 'Ürün değerlendirmesi henüz yok'
                : 'Satıcı değerlendirmesi henüz yok',
            _showProductReviews
                ? 'Bu mağazanın ürünleri için gerçek kullanıcı yorumu geldiğinde burada gösterilecek.'
                : 'Bu mağaza için gerçek satıcı değerlendirmesi geldiğinde burada gösterilecek.',
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final images = _reviewImages(review);
            final rating = _reviewRating(review);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _reviewAuthor(review),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        review['date']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reviewMessage(review),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, imageIndex) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 64,
                              child: _reviewImage(images[imageIndex]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(5, (starIndex) {
                          if (starIndex < rating.floor()) {
                            return const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            );
                          } else if (starIndex < rating) {
                            return const Icon(
                              Icons.star_half,
                              color: Colors.amber,
                              size: 16,
                            );
                          }
                          return const Icon(
                            Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSellerRatingSummaryCard() {
    return AnimatedBuilder(
      animation: AppState(),
      builder: (context, _) {
        final reviews = _sellerReviewCards();
        final starCounts = _starCounts(reviews);
        final total = reviews.length;
        final average = total == 0
            ? 0.0
            : reviews
                      .map((item) => _reviewRating(item))
                      .fold<double>(0, (a, b) => a + b) /
                  total;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Satıcı Puanlaması',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _storeInitials(widget.business['name']?.toString()),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((star) {
                        final count = starCounts[star] ?? 0;
                        final ratio = total == 0 ? 0.0 : count / total;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildRatingBar('$star Yıldız', count, ratio),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$total Kişi',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < average.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 22,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewPhotoStrip() {
    return AnimatedBuilder(
      animation: AppState(),
      builder: (context, _) {
        final reviews = _showProductReviews
            ? _productReviewCards()
            : _sellerReviewCards();
        final images = _collectReviewImages(reviews, limit: 12);
        if (images.isEmpty) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _showProductReviews
                  ? 'Henüz ürün fotoğrafı paylaşılmadı'
                  : 'Henüz satıcı değerlendirme fotoğrafı yok',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(width: 100, child: _reviewImage(images[index])),
              );
            },
          ),
        );
      },
    );
  }

  String _storeInitials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) {
      final value = parts.first;
      return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  String _reviewAuthor(Map<String, dynamic> review) {
    return review['name']?.toString() ??
        review['userName']?.toString() ??
        'Kullanıcı';
  }

  String _reviewMessage(Map<String, dynamic> review) {
    return review['text']?.toString() ?? review['reviewText']?.toString() ?? '';
  }

  double _reviewRating(Map<String, dynamic> review) {
    return (review['rating'] as num?)?.toDouble() ?? 0.0;
  }

  List<String> _reviewImages(Map<String, dynamic> review) {
    return ((review['imageUrls'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  Map<int, int> _starCounts(List<Map<String, dynamic>> reviews) {
    final starCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final review in reviews) {
      final rating = _reviewRating(review);
      if (rating <= 0) continue;
      final rounded = rating.round();
      final bounded = rounded < 1
          ? 1
          : rounded > 5
          ? 5
          : rounded;
      starCounts[bounded] = (starCounts[bounded] ?? 0) + 1;
    }
    return starCounts;
  }

  List<String> _collectReviewImages(
    List<Map<String, dynamic>> reviews, {
    int limit = 12,
  }) {
    final images = <String>[];
    for (final review in reviews) {
      for (final image in _reviewImages(review)) {
        if (image.trim().isEmpty) continue;
        images.add(image);
        if (images.length >= limit) return images;
      }
    }
    return images;
  }

  // WEB: Kategori Barı (Tümü + çıkarılan kategoriler)
  Widget _buildWebCategoryBar() {
    final categories = _categories; // 'Tümü' + benzersiz alt kategoriler
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(categories.length, (i) {
            final isSelected = _selectedCategoryIndex == i;
            final label = categories[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = i;
                  });
                },
                splashColor: AppColors.primary.withOpacity(0.12),
                hoverColor: AppColors.primary.withOpacity(0.08),
                focusColor: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSellerReviewsTab() {
    return AnimatedBuilder(
      animation: AppState(),
      builder: (context, _) {
        final sellerReviews = _sellerReviewCards();
        final total = sellerReviews.length;
        final average = total == 0
            ? 0.0
            : sellerReviews
                      .map((e) => _reviewRating(e))
                      .fold<double>(0, (a, b) => a + b) /
                  total;
        final starCounts = _starCounts(sellerReviews);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text(
                          average.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < average.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$total Değerlendirme',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [5, 4, 3, 2, 1].map((star) {
                          final count = starCounts[star] ?? 0;
                          final ratio = total == 0 ? 0.0 : count / total;
                          return _buildSellerRatingBar(star, ratio);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Değerlendirmeler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              if (sellerReviews.isEmpty)
                _buildEmptyReviewState(
                  'Satıcı değerlendirmesi henüz yok',
                  'Bu mağaza için gerçek satıcı değerlendirmesi geldiğinde burada gösterilecek.',
                )
              else
                ...sellerReviews.map(
                  (review) => _buildSellerReviewCard(review),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebSellerReviewsTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Satıcı Değerlendirmeleri',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildSellerReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerRatingBar(int star, double percentage) {
    return Row(
      children: [
        Text(
          '$star',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.star, size: 12, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerReviewCard(Map<String, dynamic> review) {
    final author = _reviewAuthor(review);
    final message = _reviewMessage(review);
    final images = _reviewImages(review);
    final rating = _reviewRating(review);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Text(
                      author.isNotEmpty ? author[0].toUpperCase() : 'K',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                review['date']?.toString() ?? '-',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.black87)),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      child: _reviewImage(images[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _productReviewCards() {
    final dynamicReviews = AppState().getProductReviewsForStore(
      storeName: widget.business['name']?.toString() ?? '',
    );
    if (dynamicReviews.isNotEmpty) {
      return dynamicReviews.map((review) {
        final createdAt = DateTime.tryParse(
          review['createdAt']?.toString() ?? '',
        );
        return {
          'name': review['userName']?.toString() ?? 'Kullanıcı',
          'date': createdAt != null
              ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
              : '-',
          'text': review['comment']?.toString() ?? '',
          'rating': (review['rating'] as num?)?.toDouble() ?? 0.0,
          'imageUrls': ((review['imageUrls'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
        };
      }).toList();
    }

    return [];
  }

  List<Map<String, dynamic>> _sellerReviewCards() {
    final dynamicReviews = AppState().getSellerReviewsFor(
      sellerId: widget.business['seller_id']?.toString(),
      storeName: widget.business['name']?.toString(),
    );
    if (dynamicReviews.isNotEmpty) {
      return dynamicReviews.map((review) {
        final createdAt = DateTime.tryParse(
          review['createdAt']?.toString() ?? '',
        );
        return {
          'userName': review['userName']?.toString() ?? 'Kullanıcı',
          'name': review['userName']?.toString() ?? 'Kullanıcı',
          'date': createdAt != null
              ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
              : '-',
          'reviewText': review['comment']?.toString() ?? '',
          'text': review['comment']?.toString() ?? '',
          'rating': (review['rating'] as num?)?.toDouble() ?? 0.0,
          'imageUrls': ((review['imageUrls'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
        };
      }).toList();
    }
    return [];
  }

  Widget _buildEmptyReviewState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 42, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewImage(String url) {
    if (url.startsWith('data:image/')) {
      return Image.memory(
        UriData.parse(url).contentAsBytes(),
        fit: BoxFit.cover,
      );
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _reviewFallback(),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _reviewFallback(),
    );
  }

  Widget _reviewFallback() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }

  // Duyurular - Otomatik Kayan Banner Widget'ı
  Widget _buildAnnouncementBanners() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Eğer controller viewportFraction olmadan oluşturulduysa, yeniden oluştur
    if (_announcementPageController?.viewportFraction == 1.0) {
      _announcementPageController?.dispose();
      _announcementPageController = PageController(
        viewportFraction: isMobile ? 0.92 : 0.85,
      );
    }

    final bannerUrls =
        (_storePublicInfo?['banners'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        <String>[];
    final bannerPaths = _getStoreBannerPaths(
      widget.business['name'].toString(),
    );

    final allBanners = [
      ...bannerUrls.map((url) => {'type': 'url', 'url': url}),
      ...bannerPaths.map((path) => {'type': 'image', 'imagePath': path}),
      // Renkli gradient banner (en sonda - 3. sırada)
      {
        'type': 'gradient',
        'title': 'İlkbahar Kampanyası',
        'subtitle': 'Tüm ürünlerde %20 indirim',
        'color': const Color(0xFFFF6B6B),
        'icon': Icons.local_offer,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Duyurular',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isMobile ? 80 : 100,
          child: PageView.builder(
            controller: _announcementPageController,
            itemCount: allBanners.length,
            onPageChanged: (index) {
              setState(() {
                _currentAnnouncementPage = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = allBanners[index];
              final isGradient = banner['type'] == 'gradient';
              final isUrl = banner['type'] == 'url';

              if (isUrl) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    banner['url'] as String,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                );
              }
              if (isGradient) {
                // Renkli gradient banner
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        banner['color'] as Color,
                        (banner['color'] as Color).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (banner['color'] as Color).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 20,
                      vertical: isMobile ? 12 : 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            banner['icon'] as IconData,
                            color: Colors.white,
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                banner['title'] as String,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                banner['subtitle'] as String,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: isMobile ? 11 : 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Görsel banner
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                    image: DecorationImage(
                      image: AssetImage(banner['imagePath'] as String),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  // ─── GARSON / MASA SİPARİŞ AKIŞI ───────────────────────────────────────

  void _showDiningModePopup(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isDismissible: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Header with Logo Left, Title Right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.business['name']?.toString() ?? 'Mağaza',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nasıl sipariş vermek istersiniz?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Buttons side-by-side again, but using Column inside for compact look or keep Row inside?
                // User asked for side-by-side buttons (2 ye ayır alt alta alma)
                // And I should use the new design (Icon Left, Text Right) inside the button?
                // Wait, space might be tight for side-by-side with Icon Left + Text Right.
                // Let's try to fit them or revert inner button design to Top-Bottom if space is tight?
                // The user said: "ikon sola gelsin . yazılar sağına gelsin" AND "(Mekandayım ve Online sipariş) yan yana 2 button olarak olsunn"
                // I will try to fit Icon Left + Text Right in a side-by-side layout.
                // It might need smaller font or icon.
                Row(
                  children: [
                    Expanded(
                      child: _diningModeButton(
                        icon: Icons.table_restaurant_outlined,
                        label: 'Mekandayım',
                        subtitle: 'Masaya sipariş', // Shortened slightly
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _showTableSelection(ctx);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _diningModeButton(
                        icon: Icons.delivery_dining_outlined,
                        label: 'Online Sipariş',
                        subtitle: 'Adrese teslimat',
                        color: Colors.orange,
                        onTap: () => Navigator.pop(sheetCtx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _diningModeButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 10,
        ), // Reduced horizontal padding
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        // Changed to Column for inner content if space is tight? No, user explicitly asked for Icon Left.
        // Let's use Row but maybe vertical layout if screen is very small?
        // Or just use flexible.
        child: Column(
          // Reverting to Column because side-by-side + icon-left-text-right is too wide for mobile screens usually.
          // BUT user asked "ikon sola gelsin . yazılar sağına gelsin".
          // Let's try Row but with Expanded text.
          crossAxisAlignment: CrossAxisAlignment.start, // Align to start
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28), // Slightly smaller icon
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13, // Smaller font
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.7),
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTableSelection(BuildContext ctx) async {
    // Masa listesi hâlâ yükleniyorsa bekle (max 3 sn).
    var waited = 0;
    while (_isLoadingTables && mounted && waited < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    // Hâlâ boşsa bir kez daha yüklemeyi dene.
    if (mounted && _availableTableNumbers.isEmpty && !_isLoadingTables) {
      await _loadStoreTables();
    }
    if (!mounted) return;

    final tableNumbers = _availableTableNumbers;

    showDialog(
      context: ctx,
      builder: (dlgCtx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.table_restaurant_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Masa Seçiniz',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dlgCtx),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Oturduğunuz masayı seçin',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 20),
                if (tableNumbers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aktif masa bulunamadı.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                    itemCount: tableNumbers.length,
                    itemBuilder: (_, i) {
                      final tableNum = tableNumbers[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(dlgCtx);
                          _showFoodOrderDialog(ctx, tableNum);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.table_restaurant_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$tableNum',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFoodOrderDialog(BuildContext ctx, int tableNumber) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dlgCtx) => _FoodOrderDialog(
        business: widget.business,
        products: _allProducts,
        tableNumber: tableNumber,
      ),
    );
  }
}

// ─── FOOD ORDER DIALOG ──────────────────────────────────────────────────────

class _FoodOrderDialog extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Product> products;
  final int tableNumber;

  const _FoodOrderDialog({
    required this.business,
    required this.products,
    required this.tableNumber,
  });

  @override
  State<_FoodOrderDialog> createState() => _FoodOrderDialogState();
}

class _FoodOrderDialogState extends State<_FoodOrderDialog> {
  final StoreService _storeService = StoreService();
  final Map<String, Map<String, dynamic>> _cart = {};
  List<Product> _products = <Product>[];
  bool _isSending = false;
  bool _isLoadingProducts = false;
  String? _productsError;
  String _selectedSubCat = 'Tümü';

  @override
  void initState() {
    super.initState();
    _products = List<Product>.from(widget.products);
    if (_products.isEmpty) {
      unawaited(_loadProductsForDialog());
    }
  }

  int _totalItems() =>
      _cart.values.fold(0, (sum, v) => sum + (v['quantity'] as int));

  List<String> _subCategories() {
    final cats =
        _products
            .map((p) => p.subCategory ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['Tümü', ...cats];
  }

  List<Product> _filteredProducts() {
    if (_selectedSubCat == 'Tümü') return _products;
    return _products.where((p) => p.subCategory == _selectedSubCat).toList();
  }

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice is num) {
      final isInt = rawPrice == rawPrice.roundToDouble();
      final value = rawPrice.toStringAsFixed(isInt ? 0 : 2);
      return '$value TL';
    }
    final text = rawPrice?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    if (text.contains('TL') || text.contains('₺')) return text;
    return '$text TL';
  }

  Product _convertDbProductToDialogProduct(DBProduct dbProduct) {
    final images = <String>[];
    if ((dbProduct.imageUrl).trim().isNotEmpty) {
      images.add(dbProduct.imageUrl.trim());
    }
    if ((dbProduct.imageUrls ?? '').trim().isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          for (final item in decoded) {
            final value = item?.toString().trim() ?? '';
            if (value.isNotEmpty && !images.contains(value)) {
              images.add(value);
            }
          }
        }
      } catch (_) {}
    }

    List<String>? attributes;
    final rawAttrs = dbProduct.attributes;
    if ((rawAttrs ?? '').trim().isNotEmpty) {
      try {
        final decoded = json.decode(rawAttrs!);
        if (decoded is List) {
          attributes = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return Product(
      productId: dbProduct.id,
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: _formatPrice(dbProduct.price),
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: const [],
      images: images,
      store: dbProduct.store ?? widget.business['name']?.toString() ?? '',
      sellerId: dbProduct.sellerId,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
      attributes: attributes,
    );
  }

  Future<List<Product>> _loadProductsFromLocalJson(String businessName) async {
    try {
      final normalizedTarget = TextNormalizer.normalize(businessName);
      final jsonString = await rootBundle.loadString('assets/urunler.json');
      final list = List<dynamic>.from(json.decode(jsonString) as List);
      return list
          .where((item) {
            if (item is! Map) return false;
            final storeName = item['magaza']?.toString() ?? '';
            final normalizedStore = TextNormalizer.normalize(storeName);
            return normalizedStore == normalizedTarget ||
                normalizedStore.contains(normalizedTarget) ||
                normalizedTarget.contains(normalizedStore);
          })
          .map<Product>((item) {
            final map = Map<String, dynamic>.from(item as Map);
            final images = <String>[];
            final rawImages = map['gorseller'];
            if (rawImages is List) {
              for (final image in rawImages) {
                final value = image?.toString().trim() ?? '';
                if (value.isNotEmpty) images.add(value);
              }
            }

            final tags = <String>[];
            final rawTags = map['etiketler'];
            if (rawTags is List) {
              for (final tag in rawTags) {
                final value = tag?.toString().trim() ?? '';
                if (value.isNotEmpty) tags.add(value);
              }
            }

            final priceText = map['fiyat']?.toString() ?? '';
            return Product(
              name: map['isim']?.toString() ?? '',
              brand: map['marka']?.toString() ?? '',
              price: _formatPrice(priceText),
              rating: (map['puan'] as num?)?.toDouble() ?? 0,
              reviewCount: (map['degerlendirme'] as num?)?.toInt() ?? 0,
              tags: tags,
              images: images,
              store: map['magaza']?.toString() ?? businessName,
              category: map['kategori']?.toString(),
              subCategory: map['alt_kategori']?.toString(),
              description: map['aciklama']?.toString(),
              specifications: map['ozellikler'] != null
                  ? json.encode(map['ozellikler'])
                  : null,
            );
          })
          .where((p) => p.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <Product>[];
    }
  }

  Future<void> _loadProductsForDialog() async {
    if (_isLoadingProducts) return;
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final businessName = widget.business['name']?.toString() ?? '';
      var sellerId = widget.business['seller_id']?.toString();
      if ((sellerId ?? '').trim().isEmpty && businessName.isNotEmpty) {
        sellerId = await _storeService.getSellerIdByBusinessName(businessName);
      }
      if ((sellerId ?? '').trim().isEmpty) {
        throw Exception('Satıcı bulunamadı.');
      }

      final rows = await _storeService.getProductsBySellerId(sellerId!);
      var loadedProducts = rows
          .map<Product>((raw) {
            final data = Map<String, dynamic>.from(raw);
            final images = <String>[];
            final mainImage = data['image_url']?.toString().trim() ?? '';
            if (mainImage.isNotEmpty) {
              images.add(mainImage);
            }
            final extraImages = data['image_urls'];
            if (extraImages is List) {
              for (final image in extraImages) {
                final value = image?.toString().trim() ?? '';
                if (value.isNotEmpty && !images.contains(value)) {
                  images.add(value);
                }
              }
            }

            List<String>? attributes;
            final rawAttrs = data['attributes'];
            if (rawAttrs is List) {
              attributes = rawAttrs.map((e) => e.toString()).toList();
            } else if (rawAttrs is String && rawAttrs.isNotEmpty) {
              try {
                final decoded = json.decode(rawAttrs);
                if (decoded is List) {
                  attributes = decoded.map((e) => e.toString()).toList();
                }
              } catch (_) {}
            }

            return Product(
              name: data['name']?.toString() ?? '',
              brand: widget.business['name']?.toString() ?? '',
              price: _formatPrice(data['price']),
              rating: 0,
              reviewCount: 0,
              tags: const [],
              images: images,
              store: widget.business['name']?.toString() ?? '',
              category: widget.business['category']?.toString(),
              subCategory: data['sub_category']?.toString(),
              description: null,
              specifications: null,
              oldPrice: null,
              attributes: attributes,
            );
          })
          .where((product) => product.name.trim().isNotEmpty)
          .toList();

      if (loadedProducts.isEmpty && businessName.isNotEmpty) {
        final paged = await SupabaseService.instance
            .getProductsByStoreNamePaged(storeName: businessName, limit: 120);
        loadedProducts = paged.items
            .map(_convertDbProductToDialogProduct)
            .toList(growable: false);
      }

      if (loadedProducts.isEmpty && businessName.isNotEmpty) {
        loadedProducts = await _loadProductsFromLocalJson(businessName);
      }

      if (!mounted) return;
      setState(() {
        _products = loadedProducts;
        _isLoadingProducts = false;
        _productsError = loadedProducts.isEmpty
            ? 'Ürünler bulunamadı. Tekrar deneyin.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _productsError = 'Ürünler yüklenemedi. Tekrar deneyin.';
      });
    }
  }

  void _showItemSettings(Product product) {
    final existing = _cart[product.name];
    int qty = existing?['quantity'] ?? 1;
    final gramajCtrl = TextEditingController(text: existing?['gramaj'] ?? '');
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    final productAttrs = product.attributes ?? [];
    final selectedAttrs = <String>{
      ...((existing?['selectedAttrs'] as List?)?.cast<String>() ?? []),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      product.price,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Adet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _qtyButton(Icons.remove, () {
                          if (qty > 1) setSheet(() => qty--);
                        }),
                        Container(
                          width: 48,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _qtyButton(Icons.add, () => setSheet(() => qty++)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gramaj (isteğe bağlı)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: gramajCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Örn: 250g',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                    if (productAttrs.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Özellikler',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: productAttrs.map((attr) {
                          final isSelected = selectedAttrs.contains(attr);
                          return GestureDetector(
                            onTap: () => setSheet(() {
                              if (isSelected) {
                                selectedAttrs.remove(attr);
                              } else {
                                selectedAttrs.add(attr);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    attr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Açıklama / Not (isteğe bağlı)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Örn: Az tuzlu, yanında ketçap',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          setState(() {
                            _cart[product.name] = {
                              'quantity': qty,
                              'gramaj': gramajCtrl.text.trim(),
                              'notes': notesCtrl.text.trim(),
                              'price': product.price,
                              'name': product.name,
                              'selectedAttrs': selectedAttrs.toList(),
                            };
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Onayla',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }

  Future<void> _sendOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final businessName = widget.business['name']?.toString() ?? '';
      String? sellerId = widget.business['seller_id']?.toString();
      sellerId ??= await StoreService().getSellerIdByBusinessName(businessName);

      if (sellerId == null || sellerId.isEmpty)
        throw Exception('Satıcı bulunamadı.');

      final items = _cart.values
          .map(
            (v) => {
              'name': v['name'],
              'price': v['price'],
              'quantity': v['quantity'],
              'gramaj': v['gramaj'],
              'notes': v['notes'],
              'attributes': v['selectedAttrs'] ?? [],
            },
          )
          .toList();

      final inserted = await StoreService().submitTableOrder(
        sellerId: sellerId,
        tableNumber: widget.tableNumber,
        items: items,
      );

      final orderId =
          inserted['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final createdAt =
          inserted['created_at']?.toString() ??
          DateTime.now().toIso8601String();
      final status = inserted['status']?.toString() ?? 'new';

      AppState().addFoodOrder({
        'id': orderId,
        'businessName': businessName,
        'tableNumber': widget.tableNumber,
        'orderType': 'garson',
        'status': status,
        'createdAt': createdAt,
        'items': items,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Masa ${widget.tableNumber} siparişiniz gönderildi! Garson kısa sürede gelecek.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts();
    final subCats = _subCategories();
    final isWeb = MediaQuery.of(context).size.width > 800;

    return Dialog(
      backgroundColor: const Color(0xFFF8F9FA),
      surfaceTintColor: Colors.transparent,
      insetPadding: isWeb
          ? const EdgeInsets.symmetric(horizontal: 80, vertical: 40)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: isWeb ? 700 : double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.table_restaurant_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Masa ${widget.tableNumber} — Sipariş',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.business['name']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_totalItems() > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_totalItems()} ürün',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Subcategory filter bar
            if (subCats.length > 1)
              Container(
                height: 44,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: subCats.length,
                  itemBuilder: (_, i) {
                    final cat = subCats[i];
                    final isSelected = _selectedSubCat == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSubCat = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Product list
            Expanded(
              child: _isLoadingProducts && _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Ürünler yükleniyor...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _productsError ?? 'Bu kategoride ürün bulunamadı.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (_productsError != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadProductsForDialog,
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (_, i) {
                        final product = filteredProducts[i];
                        final inCart = _cart.containsKey(product.name);
                        final cartItem = _cart[product.name];
                        final selectedAttrs =
                            (cartItem?['selectedAttrs'] as List?)
                                ?.cast<String>() ??
                            [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: inCart
                                  ? AppColors.primary.withOpacity(0.4)
                                  : Colors.grey.shade100,
                              width: inCart ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: product.images.isNotEmpty
                                    ? Image.network(
                                        product.images.first,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            _imgFallback(),
                                      )
                                    : _imgFallback(),
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
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (product.subCategory != null &&
                                        product.subCategory!.isNotEmpty)
                                      Text(
                                        product.subCategory!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    const SizedBox(height: 3),
                                    Text(
                                      product.price,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (inCart) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${cartItem!['quantity']}x${cartItem['gramaj'] != '' ? ' · ${cartItem['gramaj']}' : ''}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          ...selectedAttrs.map(
                                            (a) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                a,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (!inCart) {
                                        setState(() {
                                          _cart[product.name] = {
                                            'quantity': 1,
                                            'gramaj': '',
                                            'notes': '',
                                            'price': product.price,
                                            'name': product.name,
                                            'selectedAttrs': <String>[],
                                          };
                                        });
                                      } else {
                                        setState(
                                          () => _cart.remove(product.name),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: inCart
                                            ? Colors.red.shade50
                                            : AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        inCart ? 'Çıkar' : 'Ekle',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: inCart
                                              ? Colors.red
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _showItemSettings(product),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.tune,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Cart bar + Garson Gönder
            if (_cart.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _cart.entries.map((e) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              '${e.value['quantity']}x ${e.key}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendOrder,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.notifications_active_outlined,
                                size: 20,
                              ),
                        label: Text(
                          _isSending ? 'Gönderiliyor...' : 'Garson Gönder',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.fastfood_outlined, color: Colors.grey, size: 24),
  );
}
