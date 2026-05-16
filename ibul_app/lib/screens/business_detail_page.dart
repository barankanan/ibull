import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../models/product_pricing.dart';
import '../models/product_list_model.dart';
import '../models/db_product.dart';
import '../services/store_service.dart';
import '../services/supabase_service.dart';
import '../services/product_list_service.dart';
import '../services/push_notification_service.dart';
import '../services/store_follow_service.dart';
import '../models/store_follow_state.dart';
import '../widgets/store_notifications_sheet.dart';
import '../screens/login_page.dart';
import '../utils/text_normalizer.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_sidebar.dart';
import '../services/coupon_service.dart';
import '../widgets/common/video_player_widget.dart';
import '../models/mixed_service_order.dart';
import '../models/seller_product.dart';
import '../widgets/restaurant_order/food_product_card.dart';
import '../widgets/restaurant_order/mixed_service_dialog.dart';
import '../widgets/restaurant_order/product_quick_view_dialog.dart';
import '../widgets/restaurant_order/weight_selector.dart';
import '../services/campaign_service.dart';
import '../core/qr_initial_params.dart';
import '../services/waiter_order_request_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';
import 'list_detail_page.dart';
import '../utils/table_labels.dart';

class BusinessDetailPage extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Product>? storeProducts;
  final bool forceTableSelection;
  final int? initialTableNumber;
  final String? initialProductQuery;

  /// Set to true when opened from [QrEntryScreen] via a zero-duration route
  /// transition. Reduces the dialog-open delay from 420 ms to 80 ms because
  /// there is no route animation to wait for.
  final bool fromQr;

  /// Doğrulanmamış masa QR: doğrudan [table_orders] / mutfak yazdırma yok;
  /// siparişler [WaiterOrderRequestService] ile garson onayına gider.
  final bool unverifiedQrTableFlow;

  const BusinessDetailPage({
    super.key,
    required this.business,
    this.storeProducts,
    this.forceTableSelection = false,
    this.initialTableNumber,
    this.initialProductQuery,
    this.fromQr = false,
    this.unverifiedQrTableFlow = false,
  });

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;
  bool _showProductReviews = true;
  StoreFollowState _followState = const StoreFollowState(loading: true);
  String? _storeId;
  int _unreadNotificationCount = 0;
  bool _followActionLoading = false;
  String _searchQuery = '';
  bool _isLoadingProducts = false;
  int _activeSellerReviewTab = 0;

  // Duyuru Banner için controller ve timer
  PageController? _announcementPageController;
  Timer? _announcementTimer;
  int _currentAnnouncementPage = 0;

  // Web Scroll Controller and Keys
  final ScrollController _webScrollController = ScrollController();
  final GlobalKey _campaignsKey = GlobalKey();
  final GlobalKey _allProductsKey = GlobalKey();

  // Garson / Masa Sipariş state
  bool _diningPopupShown = false;
  bool _hasAutoOpenedDiningFlow = false;
  bool _isLoadingTables = false;
  bool _pendingForceTableSelection = false;
  int? _pendingInitialQrTableNumber;

  /// Set to true the instant the user initiates back navigation from a
  /// QR-opened page. All async dining-flow continuations check this flag so
  /// they bail out instead of showing a dialog on a context that is already
  /// being disposed/replaced. This prevents the popup-re-open loop that
  /// occurs when the polling loop in [_openForcedDiningFlowWhenReady] or
  /// any other async gap resolves AFTER navigation has started.
  bool _isLeavingQrFlow = false;
  bool _isQrAutoFlowCancelled = false;
  bool _isNavigatingHomeFromQr = false;
  int _activeQrPopupToken = 0;
  String? _activeQrPopupName;
  bool _activeQrPopupUseRootNavigator = false;
  List<int> _availableTableNumbers = <int>[];
  Set<int> _occupiedTableNumbers = <int>{};
  List<Map<String, dynamic>> _storeTables = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _storeTableAreas = const <Map<String, dynamic>>[];
  String _customerAreaFilterKey = 'all';
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

  /// Completer that resolves once [_fetchStoreProducts] finishes (or fails).
  /// Passed to [_FoodOrderDialog] so it can await the SAME in-flight request
  /// instead of spawning a duplicate Supabase call.
  final Completer<List<Product>> _productCompleter = Completer<List<Product>>();

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
      pricingType: dbProduct.pricingType,
      portionPrice: dbProduct.portionPrice,
      pricePerKg: dbProduct.pricePerKg,
      defaultWeightGrams: dbProduct.defaultWeightGrams,
      minWeightGrams: dbProduct.minWeightGrams,
      weightStepGrams: dbProduct.weightStepGrams,
      maxWeightGrams: dbProduct.maxWeightGrams,
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
    final sw = Stopwatch()..start();
    debugPrint(
      '[BDP-Timing] ${sw.elapsedMilliseconds}ms — _fetchStoreProducts start',
    );
    setState(() => _isLoadingProducts = true);
    try {
      final storeName = widget.business['name'].toString();
      List<Product> storeProducts = [];

      String? sellerId = widget.business['seller_id']?.toString();
      sellerId ??= await StoreService().getSellerIdByBusinessName(storeName);

      if (sellerId != null && sellerId.isNotEmpty) {
        try {
          final supaProducts = await StoreService().getMenuProductsBySellerId(
            sellerId,
          );
          if (supaProducts.isNotEmpty) {
            storeProducts = supaProducts.map<Product>((map) {
              final data = Map<String, dynamic>.from(map);
              final product = Product.fromDBProduct({
                ...data,
                'brand':
                    data['brand']?.toString() ??
                    widget.business['name']?.toString() ??
                    '',
                'store': storeName,
                'category':
                    data['main_category']?.toString() ??
                    widget.business['category']?.toString(),
              });
              final rawPrice = data['price'];
              final formattedPrice = rawPrice is num
                  ? '₺${rawPrice.toStringAsFixed(0)}'
                  : rawPrice?.toString() ?? '';
              return product.copyWith(price: formattedPrice);
            }).toList();
          }
        } catch (e) {
          debugPrint('Supabase ürünleri yüklenirken hata: $e');
        }
      }

      if (storeProducts.isEmpty) {
        final paged = await SupabaseService.instance
            .getProductsByStoreNamePaged(storeName: storeName, limit: 60);
        storeProducts = paged.items.map(_convertToProduct).toList();

        if (storeProducts.isEmpty) {
          debugPrint('⚠️ DB\'de ürün bulunamadı, JSON\'dan manuel aranıyor...');
          try {
            if (!mounted) return;
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
              debugPrint(
                '✅ JSON\'dan ${storeProducts.length} ürün bulundu ve yüklendi.',
              );
            } else {
              debugPrint('❌ JSON\'da da bu mağaza için ürün bulunamadı.');
            }
          } catch (e) {
            debugPrint('Error loading JSON fallback: $e');
          }
        }
      }

      debugPrint('✅ Sonuç: ${storeProducts.length} ürün listelenecek.');
      debugPrint(
        '[BDP-Timing] ${sw.elapsedMilliseconds}ms — _fetchStoreProducts products ready (${storeProducts.length})',
      );

      if (!_productCompleter.isCompleted) {
        _productCompleter.complete(storeProducts);
      }
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
      debugPrint('Error fetching store products: $e');
      debugPrint(
        '[BDP-Timing] ${sw.elapsedMilliseconds}ms — _fetchStoreProducts ERROR: $e',
      );
      if (!_productCompleter.isCompleted) _productCompleter.complete([]);
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
    _pendingForceTableSelection = widget.forceTableSelection;
    _pendingInitialQrTableNumber = widget.initialTableNumber;
    debugPrint(
      '[BDP-Timing] initState — store: ${widget.business['name']} '
      'fromQr=${widget.fromQr} table=$_pendingInitialQrTableNumber',
    );
    // Log the first rendered frame so we can measure end-to-end QR→BDP time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[BDP-Timing] BusinessDetailPage first frame rendered (mounted=true)',
      );
    });
    _tabController = TabController(length: 4, vsync: this);
    _lastObservedProductListsSignature = _productListsSignature(
      _appState.productLists,
    );
    _appState.addListener(_handleAppStateChanged);
    _tabController.addListener(_handleTabChanged);
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
    unawaited(_loadStoreFollowState());
    _fetchStoreProducts();
    _loadStoreTables();
    _loadStorePublicInfo();

    if (widget.fromQr) {
      // QR path: defer non-critical fetches until after the first frame so
      // they don't compete with product loading and the order dialog.
      // Campaigns and seller lists are not needed for the ordering flow.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_shouldAbortQrAutoFlow(
          source: 'postFrame:deferred-loads',
          logLabel: 'postFrame callback blocked',
        )) {
          return;
        }
        unawaited(_loadStoreCampaigns());
        unawaited(_loadPublicSellerLists());
        debugPrint(
          '[BDP-Timing] QR: deferred campaigns + seller lists started after first frame',
        );
      });
    } else {
      _loadStoreCampaigns();
      _loadPublicSellerLists();
    }

    // QR ile zorunlu masa seçiminde kategoriye bakmadan sipariş akışını aç.
    // Normal akışta sadece yemek/restoran mağazalarında garson popup'ı göster.
    final category =
        widget.business['category']?.toString().toLowerCase() ?? '';
    final isFoodCategory =
        category.contains('yemek') ||
        category.contains('restoran') ||
        category.contains('kafe') ||
        category.contains('cafe');
    if (_pendingForceTableSelection || isFoodCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_shouldAbortQrAutoFlow(
          source: 'postFrame:dining-flow',
          logLabel: 'postFrame callback blocked',
        )) {
          return;
        }
        if (_diningPopupShown) {
          debugPrint(
            '[BDP/QR] postFrame callback blocked — dining flow already shown '
            '_diningPopupShown=$_diningPopupShown',
          );
          return;
        }
        _diningPopupShown = true;
        debugPrint(
          '[BDP/QR] postFrameCallback: opening dining flow '
          'forceTableSelection=$_pendingForceTableSelection '
          'fromQr=${widget.fromQr} '
          '_isLeavingQrFlow=$_isLeavingQrFlow',
        );
        if (_pendingForceTableSelection) {
          unawaited(_openForcedDiningFlowWhenReady());
        } else {
          _showDiningModePopup(context);
        }
      });
    }
  }

  Future<String?> _resolveStoreId() async {
    if (_storeId != null && _storeId!.isNotEmpty) return _storeId;
    final resolved = await StoreFollowService.instance.resolveStoreId(
      sellerId: widget.business['seller_id']?.toString(),
      businessName: widget.business['name']?.toString(),
    );
    _storeId = resolved;
    return resolved;
  }

  Future<void> _loadStoreFollowState() async {
    final storeId = await _resolveStoreId();
    if (!mounted) return;
    if (storeId == null || storeId.isEmpty) {
      setState(() {
        _followState = const StoreFollowState(
          loading: false,
          error: 'Mağaza bilgisi yüklenemedi.',
        );
      });
      return;
    }

    setState(() => _followState = _followState.copyWith(loading: true));
    final state = await StoreFollowService.instance.getStoreFollowState(storeId);
    final unread = _appState.isLoggedIn
        ? await StoreFollowService.instance.unreadStoreNotificationCount(storeId)
        : 0;
    if (!mounted) return;
    setState(() {
      _followState = state.copyWith(loading: false);
      _unreadNotificationCount = unread;
    });
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Giriş Yap'),
        content: const Text('Mağazayı takip etmek için giriş yapmanız gerekiyor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleNotificationBellTap() async {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final storeId = await _resolveStoreId();
    if (storeId == null || storeId.isEmpty) {
      _showSnack('Mağaza bilgisi yüklenemedi.');
      return;
    }

    if (!_followState.isFollowing) {
      _showSnack('Bildirimleri açmak için önce mağazayı takip etmelisin.');
      return;
    }

    final storeName = widget.business['name']?.toString().trim().isNotEmpty == true
        ? widget.business['name'].toString().trim()
        : 'Mağaza';

    if (!_followState.notificationsEnabled) {
      try {
        final permissionGranted =
            await PushNotificationService.instance.ensureNotificationPermission();
        if (!permissionGranted) {
          _showSnack(
            'Bildirim izni şu anda tamamlanamadı. Lütfen daha sonra tekrar deneyin.',
          );
          return;
        }

        final enabled = await StoreFollowService.instance.toggleStoreNotifications(
          storeId,
          enabled: true,
        );
        if (!mounted) return;
        setState(() {
          _followState = _followState.copyWith(notificationsEnabled: enabled);
        });
        _showSnack('Mağaza bildirimleri açıldı.');
      } catch (error) {
        _showSnack(PushNotificationService.friendlyErrorMessage(error));
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, __) => StoreNotificationsSheet(
          storeId: storeId,
          storeName: storeName,
          notificationsEnabled: _followState.notificationsEnabled,
          business: widget.business,
          onNotificationsChanged: (enabled) async {
            if (!mounted) return;
            setState(() {
              _followState = _followState.copyWith(
                notificationsEnabled: enabled,
              );
            });
            final unread = await StoreFollowService.instance
                .unreadStoreNotificationCount(storeId);
            if (mounted) {
              setState(() => _unreadNotificationCount = unread);
            }
          },
        ),
      ),
    );

    final unread =
        await StoreFollowService.instance.unreadStoreNotificationCount(storeId);
    if (mounted) {
      setState(() => _unreadNotificationCount = unread);
    }
  }

  Future<void> _toggleFollowStore() async {
    if (_followActionLoading || _followState.loading) return;

    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final storeId = await _resolveStoreId();
    if (storeId == null || storeId.isEmpty) {
      _showSnack('Mağaza bilgisi yüklenemedi.');
      return;
    }

    final previousState = _followState;
    final optimisticFollowing = !previousState.isFollowing;
    setState(() {
      _followActionLoading = true;
      _followState = previousState.copyWith(
        isFollowing: optimisticFollowing,
        followerCount: optimisticFollowing
            ? previousState.followerCount + 1
            : (previousState.followerCount > 0
                  ? previousState.followerCount - 1
                  : 0),
        notificationsEnabled:
            optimisticFollowing ? previousState.notificationsEnabled : false,
        clearError: true,
      );
    });

    try {
      final nextState = optimisticFollowing
          ? await StoreFollowService.instance.followStore(storeId)
          : await StoreFollowService.instance.unfollowStore(storeId);

      if (!mounted) return;
      setState(() {
        _followState = nextState.copyWith(loading: false);
        _followActionLoading = false;
        _unreadNotificationCount = optimisticFollowing
            ? _unreadNotificationCount
            : 0;
      });

      await _appState.refreshFollowedStoresFromServer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _followState = previousState.copyWith(loading: false);
        _followActionLoading = false;
      });
      _showSnack(StoreFollowService.userFriendlyError(error));
    }
  }

  String get _displayFollowerCount {
    if (_followState.followerCount > 0 || !_followState.loading) {
      return _followState.formattedFollowerCount;
    }
    final legacy = widget.business['followers']?.toString().trim() ?? '';
    if (legacy.isNotEmpty && !legacy.contains('9.8B') && !legacy.contains('10B')) {
      return legacy;
    }
    return _followState.formattedFollowerCount;
  }

  bool get _isFollowing => _followState.isFollowing;
  bool get _isNotificationsEnabled => _followState.notificationsEnabled;

  Widget _buildStoreNotificationBell({
    required double size,
    required double iconSize,
    required double borderRadius,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: _followState.loading ? null : _handleNotificationBellTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _isNotificationsEnabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            child: Icon(
              _isNotificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              color: _isNotificationsEnabled
                  ? Colors.amber.shade700
                  : Colors.white,
              size: iconSize,
            ),
          ),
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldAbortQrAutoFlow({
    required String source,
    required String logLabel,
  }) {
    final blocked =
        !mounted ||
        _isLeavingQrFlow ||
        _isQrAutoFlowCancelled ||
        _isNavigatingHomeFromQr;
    if (blocked) {
      debugPrint(
        '[BDP/QR] $logLabel — source=$source '
        'mounted=$mounted leaving=$_isLeavingQrFlow '
        'cancelled=$_isQrAutoFlowCancelled '
        'navigatingHome=$_isNavigatingHomeFromQr '
        'pendingForce=$_pendingForceTableSelection '
        'pendingTable=$_pendingInitialQrTableNumber '
        'activePopup=$_activeQrPopupName',
      );
    }
    return blocked;
  }

  bool _isQrPopupBlocked(String popupName) {
    return _shouldAbortQrAutoFlow(
      source: popupName,
      logLabel: 'popup BLOCKED by cancel',
    );
  }

  void _trackQrPopup<T>({
    required String popupName,
    required bool useRootNavigator,
    required Future<T?> future,
  }) {
    final token = ++_activeQrPopupToken;
    _activeQrPopupName = popupName;
    _activeQrPopupUseRootNavigator = useRootNavigator;
    debugPrint(
      '[BDP/QR] popup TRACKED — $popupName '
      'token=$token useRootNavigator=$useRootNavigator',
    );
    future.whenComplete(() {
      final wasCurrent = _activeQrPopupToken == token;
      debugPrint(
        '[BDP/QR] popup CLOSED — $popupName '
        'token=$token wasCurrent=$wasCurrent',
      );
      if (wasCurrent) {
        _activeQrPopupName = null;
        _activeQrPopupUseRootNavigator = false;
      }
    });
  }

  void _cancelQrAutoFlow({required String reason}) {
    final alreadyCancelled = _isQrAutoFlowCancelled && _isLeavingQrFlow;
    final previousPendingForce = _pendingForceTableSelection;
    final previousPendingTable = _pendingInitialQrTableNumber;
    _isLeavingQrFlow = true;
    _isQrAutoFlowCancelled = true;
    _hasAutoOpenedDiningFlow = true;
    _diningPopupShown = true;
    _pendingForceTableSelection = false;
    _pendingInitialQrTableNumber = null;
    debugPrint(
      '[BDP/QR] QR flow cancelled — reason=$reason '
      'alreadyCancelled=$alreadyCancelled '
      'pendingForce=$previousPendingForce '
      'pendingTable=$previousPendingTable '
      'activePopup=$_activeQrPopupName',
    );
  }

  Future<void> _closeQrPopupBeforeNavigation({required String reason}) async {
    final pageNavigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    for (var attempt = 1; attempt <= 4; attempt++) {
      final popupName = _activeQrPopupName;
      if (popupName == null) {
        debugPrint(
          '[BDP/QR] dialog close before navigation skipped — '
          'no tracked popup reason=$reason attempt=$attempt',
        );
        return;
      }

      final useRootNavigator = _activeQrPopupUseRootNavigator;
      debugPrint(
        '[BDP/QR] dialog close before navigation requested — '
        'popup=$popupName useRootNavigator=$useRootNavigator '
        'reason=$reason attempt=$attempt',
      );
      final navigator = useRootNavigator ? rootNavigator : pageNavigator;
      if (!navigator.canPop()) {
        debugPrint(
          '[BDP/QR] dialog close before navigation skipped — '
          'navigator.canPop=false popup=$popupName '
          'reason=$reason attempt=$attempt',
        );
        return;
      }

      final popped = await navigator.maybePop();
      await Future<void>.delayed(Duration.zero);
      debugPrint(
        '[BDP/QR] dialog close before navigation result — '
        'popup=$popupName popped=$popped '
        'remainingActive=$_activeQrPopupName attempt=$attempt',
      );
      if (!popped) {
        return;
      }
      if (_activeQrPopupName == null) {
        debugPrint(
          '[BDP/QR] dialog closed before navigation — '
          'popup=$popupName reason=$reason attempt=$attempt',
        );
        return;
      }
    }

    debugPrint(
      '[BDP/QR] dialog close before navigation stopped — '
      'activePopup=$_activeQrPopupName reason=$reason maxAttempts=4',
    );
  }

  Future<void> _navigateHomeFromQrBack({required String source}) async {
    if (_isNavigatingHomeFromQr) {
      debugPrint(
        '[BDP/QR] home navigation already in progress — source=$source',
      );
      return;
    }
    if (!mounted) {
      debugPrint(
        '[BDP/QR] home navigation aborted — widget not mounted '
        'source=$source',
      );
      return;
    }

    _isNavigatingHomeFromQr = true;
    debugPrint(
      '[BDP/QR] back from QR triggered — source=$source '
      'activePopup=$_activeQrPopupName pendingForce=$_pendingForceTableSelection '
      'pendingTable=$_pendingInitialQrTableNumber',
    );
    _cancelQrAutoFlow(reason: 'back:$source');
    QrInitialParams.reset(source: 'BusinessDetailPage.back:$source');
    await _closeQrPopupBeforeNavigation(reason: source);
    if (!mounted) {
      debugPrint(
        '[BDP/QR] home navigation aborted after popup close — '
        'widget not mounted source=$source',
      );
      return;
    }

    debugPrint(
      '[BDP/QR] home navigation triggered — source=$source '
      'rootNavigator=true route=/home',
    );
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _openForcedDiningFlowWhenReady() async {
    if (_shouldAbortQrAutoFlow(
      source: '_openForcedDiningFlowWhenReady:start',
      logLabel: 'forced dining flow blocked',
    )) {
      return;
    }
    if (!_pendingForceTableSelection) {
      debugPrint(
        '[BDP/QR] _openForcedDiningFlowWhenReady BLOCKED — '
        '_pendingForceTableSelection=false',
      );
      return;
    }
    // Guard 1: only auto-open once per page instance.
    if (_hasAutoOpenedDiningFlow) {
      debugPrint(
        '[BDP/QR] _openForcedDiningFlowWhenReady BLOCKED — _hasAutoOpenedDiningFlow already true',
      );
      return;
    }
    if (_shouldAbortQrAutoFlow(
      source: '_openForcedDiningFlowWhenReady:before-mark-opened',
      logLabel: 'forced dining flow blocked',
    )) {
      return;
    }
    _hasAutoOpenedDiningFlow = true;

    final initialTable = _pendingInitialQrTableNumber;
    debugPrint(
      '[BDP/QR] _openForcedDiningFlowWhenReady STARTED '
      'initialTableNumber=$initialTable fromQr=${widget.fromQr} '
      '_isLeavingQrFlow=$_isLeavingQrFlow',
    );
    debugPrint(
      '[BDP-Timing] _openForcedDiningFlowWhenReady → initialTableNumber=$initialTable fromQr=${widget.fromQr}',
    );
    debugPrint(
      '[QR-BDP] seller_id=${widget.business["seller_id"]}  name=${widget.business["name"]}',
    );

    // fromQr path: addPostFrameCallback in initState already ensures BDP has
    // rendered at least one frame before this method runs — no extra delay
    // needed. The previous 80 ms guard was conservative safety margin.
    // Non-QR path: wait for the slide-in page animation (~420 ms) before
    // attaching a bottom sheet on top of an animating page.
    if (!widget.fromQr) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (_shouldAbortQrAutoFlow(
        source: '_openForcedDiningFlowWhenReady:after-animation-wait',
        logLabel: 'forced dining flow blocked',
      )) {
        return;
      }
      if (!_pendingForceTableSelection) {
        debugPrint(
          '[BDP/QR] forced dining flow blocked — '
          'pendingForceTableSelection cleared after animation wait',
        );
        return;
      }
    }

    if (initialTable != null && initialTable > 0) {
      // ─── QR path: table number is already known ───────────────────────────
      // Go DIRECTLY to the "Masa X — Sipariş" dialog.
      if (_isQrPopupBlocked('food-order-dialog')) {
        return;
      }
      if (!mounted) return;
      debugPrint(
        '[QR-BDP] Table known ($initialTable) → opening food-order dialog directly.',
      );
      debugPrint(
        '[BDP-Timing] _showFoodOrderDialog called for table $initialTable',
      );
      _showFoodOrderDialog(
        context,
        initialTable,
        unverifiedQrTableFlow: widget.unverifiedQrTableFlow,
      );
      return;
    }

    // ─── QR path: no table number in the QR (show table grid) ────────────────
    debugPrint('[QR-BDP] No table in QR — waiting for store tables to load...');
    var attempts = 0;
    while (mounted && attempts < 20 && _isLoadingTables) {
      if (_shouldAbortQrAutoFlow(
        source: '_openForcedDiningFlowWhenReady:table-loading-loop',
        logLabel: 'async loop cancelled',
      )) {
        debugPrint('[BDP/QR] LOOP CANCELLED during loading tables');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      attempts++;
      if (_shouldAbortQrAutoFlow(
        source: '_openForcedDiningFlowWhenReady:table-loading-loop-after-delay',
        logLabel: 'async loop cancelled',
      )) {
        debugPrint('[BDP/QR] LOOP CANCELLED during loading tables');
        return;
      }
    }
    debugPrint(
      '[QR-BDP] Tables wait done. attempts=$attempts '
      'available=$_availableTableNumbers '
      '_isLeavingQrFlow=$_isLeavingQrFlow mounted=$mounted',
    );
    if (_shouldAbortQrAutoFlow(
      source: '_openForcedDiningFlowWhenReady:after-table-wait',
      logLabel: 'forced dining flow blocked',
    )) {
      return;
    }
    if (!_pendingForceTableSelection) {
      debugPrint(
        '[BDP/QR] forced dining flow blocked — '
        'pendingForceTableSelection cleared after table wait',
      );
      return;
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
      final service = StoreService();
      final results = await Future.wait([
        service.getActiveTableNumbers(sellerId!),
        service.getOccupiedTableNumbers(sellerId),
        // Best-effort: areas + tables (for customer area filtering).
        service.getStoreTables(sellerId: sellerId),
        service.getTableAreas(sellerId: sellerId),
      ]);
      if (!mounted) return;
      final tables = (results.length >= 3 && results[2] is List)
          ? List<Map<String, dynamic>>.from(results[2] as List)
          : const <Map<String, dynamic>>[];
      final areas = (results.length >= 4 && results[3] is List)
          ? List<Map<String, dynamic>>.from(results[3] as List)
          : const <Map<String, dynamic>>[];
      final resolvedAvailable = tables.isNotEmpty
          ? tables
                .map(
                  (t) =>
                      int.tryParse(t['table_number']?.toString() ?? '') ?? 0,
                )
                .where((n) => n > 0)
                .toList(growable: false)
          : (results[0] as List<int>);
      setState(() {
        _availableTableNumbers = resolvedAvailable;
        _occupiedTableNumbers = results[1] as Set<int>;
        _storeTables = tables;
        _storeTableAreas = areas;
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
                  ? OptimizedImage(
                      imageUrlOrPath: coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
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
    if (widget.fromQr ||
        _pendingForceTableSelection ||
        _pendingInitialQrTableNumber != null ||
        _activeQrPopupName != null) {
      _cancelQrAutoFlow(reason: 'dispose');
    }
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

    // ---------------------------------------------------------------------------
    // Unified back handler — used by BOTH mobile AppBar and web header.
    // When fromQr==true, QrEntryScreen used pushReplacement, so
    // BusinessDetailPage is the only route left in the stack.  Calling pop()
    // would remove the last route and leave a blank white screen.  Instead we
    // always navigate deterministically to the safe '/home' route.
    // ---------------------------------------------------------------------------
    void handleBack() {
      debugPrint(
        '[BDP] handleBack fired — fromQr=${widget.fromQr}, '
        'layout=${isWeb ? "web" : "mobile"}, handler=UI-back-button',
      );
      if (!mounted) {
        debugPrint('[BDP] handleBack: widget not mounted — aborting');
        return;
      }
      if (widget.fromQr) {
        debugPrint(
          '[BDP] QR back uses deterministic home navigation '
          'pop() NOT called',
        );
        unawaited(_navigateHomeFromQrBack(source: 'UI-back-button'));
      } else {
        debugPrint('[BDP] pop() called — fromQr=false');
        Navigator.pop(context);
      }
    }

    // PopScope intercepts the system/hardware back regardless of layout.
    // canPop=false blocks the automatic pop; onPopInvokedWithResult lets us
    // redirect to home for QR-opened pages.
    void onSystemBack(bool didPop, _) {
      debugPrint(
        '[BDP] PopScope.onPopInvokedWithResult — didPop=$didPop '
        'fromQr=${widget.fromQr}, layout=${isWeb ? "web" : "mobile"}',
      );
      if (!didPop && widget.fromQr) {
        debugPrint(
          '[BDP] leaving QR flow via system back — '
          'pop() NOT called → pushNamedAndRemoveUntil("/home")',
        );
        unawaited(_navigateHomeFromQrBack(source: 'system-back'));
      }
    }

    if (isWeb) {
      // Web layout is returned early.  It MUST also be wrapped in PopScope so
      // that system back on wide-screen devices (tablets, desktops) is handled
      // identically to the mobile path — without this wrapper, a hardware back
      // gesture pops the last route and produces a blank white screen.
      return PopScope(
        canPop: !widget.fromQr,
        onPopInvokedWithResult: onSystemBack,
        child: _buildWebLayout(handleBack: handleBack),
      );
    }

    final businessName = widget.business['name'] ?? 'Mağaza';
    final businessRating = widget.business['rating']?.toString() ?? '8.2';
    final businessFollowers = _displayFollowerCount;

    return PopScope(
      // canPop=false intercepts the system back gesture; onPopInvoked fires
      // so we can redirect it ourselves.
      canPop: !widget.fromQr,
      onPopInvokedWithResult: onSystemBack,
      child: Scaffold(
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
                  onPressed: handleBack,
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                _buildStoreNotificationBell(
                                  size: 28,
                                  iconSize: 18,
                                  borderRadius: 14,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    onPressed: (_followActionLoading ||
                                            _followState.loading)
                                        ? null
                                        : _toggleFollowStore,
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
                                      overlayColor: AppColors.primary
                                          .withValues(alpha: 0.12),
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

                        const SizedBox(
                          height: 8,
                        ), // Reduced spacing from 12 to 8
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
      ),
    );
  }

  Widget _buildWebLayout({required VoidCallback handleBack}) {
    final businessName = widget.business['name'] ?? 'Mağaza';
    final businessRating = widget.business['rating']?.toString() ?? '8.2';
    final businessFollowers = _displayFollowerCount;

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
                      // Back Button — delegates to the shared handleBack()
                      // passed from build(), which already checks fromQr and
                      // routes to '/' instead of pop() when needed.
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: handleBack,
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
                              _buildStoreNotificationBell(
                                size: 40,
                                iconSize: 22,
                                borderRadius: 20,
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: (_followActionLoading ||
                                        _followState.loading)
                                    ? null
                                    : _toggleFollowStore,
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
      color: Colors.white.withValues(alpha: 0.5),
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
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          hoverColor: AppColors.primary.withValues(alpha: 0.08),
          focusColor: AppColors.primary.withValues(alpha: 0.12),
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
      return OptimizedImage(
        imageUrlOrPath: logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _storeLogoLetter(businessName, size),
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
                  child: OptimizedImage(
                    imageUrlOrPath: bannerUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => Center(
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
                            color: Colors.black.withValues(alpha: 0.1),
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
                    color: Colors.black.withValues(alpha: 0.02),
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
                      image: DecorationImage(
                        image: ResizeImage.resizeIfNeeded(
                          200,
                          200,
                          const NetworkImage("https://picsum.photos/200"),
                        ),
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
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
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
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
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
            color: color.withValues(alpha: 0.15),
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
            color: Colors.black.withValues(alpha: 0.03),
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                splashColor: AppColors.primary.withValues(alpha: 0.12),
                hoverColor: AppColors.primary.withValues(alpha: 0.08),
                focusColor: AppColors.primary.withValues(alpha: 0.12),
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
                separatorBuilder: (_, _) => const SizedBox(width: 8),
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
      return OptimizedImage(
        imageUrlOrPath: url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _reviewFallback(),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _reviewFallback(),
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
                  child: OptimizedImage(
                    imageUrlOrPath: banner['url'] as String,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => Center(
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
                        (banner['color'] as Color).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (banner['color'] as Color).withValues(
                          alpha: 0.3,
                        ),
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
                            color: Colors.white.withValues(alpha: 0.2),
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
                                  color: Colors.white.withValues(alpha: 0.9),
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
                          color: Colors.white.withValues(alpha: 0.7),
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
                        color: Colors.black.withValues(alpha: 0.1),
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
    const popupName = 'dining-mode-bottom-sheet';
    debugPrint(
      '[BDP/QR] popup OPEN ATTEMPT — $popupName '
      'fromQr=${widget.fromQr} pendingForce=$_pendingForceTableSelection',
    );
    if (_isQrPopupBlocked(popupName)) {
      return;
    }

    final popupFuture = showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: false,
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
                        color: AppColors.primary.withValues(alpha: 0.1),
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
                          debugPrint(
                            '[BDP/QR] dining-mode-bottom-sheet action — '
                            'open table selection',
                          );
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
    debugPrint('[BDP/QR] popup OPENED — $popupName useRootNavigator=false');
    _trackQrPopup(
      popupName: popupName,
      useRootNavigator: false,
      future: popupFuture,
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
                          color: color.withValues(alpha: 0.7),
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
    const popupName = 'table-selection-dialog';
    debugPrint(
      '[BDP/QR] popup OPEN ATTEMPT — $popupName '
      'fromQr=${widget.fromQr} tablesLoading=$_isLoadingTables',
    );
    if (_isQrPopupBlocked(popupName)) {
      return;
    }

    // Masa listesi hâlâ yükleniyorsa bekle (max 3 sn).
    var waited = 0;
    while (_isLoadingTables && mounted && waited < 3000) {
      if (_shouldAbortQrAutoFlow(
        source: '_showTableSelection:tables-loading-loop',
        logLabel: 'async loop cancelled',
      )) {
        debugPrint('[BDP/QR] LOOP CANCELLED during table-selection loading');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
      if (_shouldAbortQrAutoFlow(
        source: '_showTableSelection:tables-loading-loop-after-delay',
        logLabel: 'async loop cancelled',
      )) {
        debugPrint('[BDP/QR] LOOP CANCELLED during table-selection loading');
        return;
      }
    }
    // Hâlâ boşsa bir kez daha yüklemeyi dene.
    if (mounted && _availableTableNumbers.isEmpty && !_isLoadingTables) {
      await _loadStoreTables();
      if (_shouldAbortQrAutoFlow(
        source: '_showTableSelection:after-loadStoreTables',
        logLabel: 'forced dining flow blocked',
      )) {
        return;
      }
    }
    // Guard after every async gap.
    if (_isQrPopupBlocked(popupName)) {
      debugPrint('[BDP/QR] _showTableSelection ABORTED after async wait');
      return;
    }

    final tableNumbers = _availableTableNumbers;
    final occupiedNumbers = _occupiedTableNumbers;
    if (!mounted) {
      debugPrint('[BDP/QR] _showTableSelection ABORTED — state not mounted');
      return;
    }

    final popupFuture = showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDialogState) {
            final areaOptions = <({String key, String label})>[
              (key: 'all', label: 'Tüm Alanlar'),
            ];

            if (_storeTableAreas.isNotEmpty) {
              for (final area in _storeTableAreas) {
                final id = area['id']?.toString().trim() ?? '';
                final name = area['name']?.toString().trim() ?? '';
                if (id.isEmpty || name.isEmpty) continue;
                areaOptions.add((key: 'id:$id', label: name));
              }
            } else {
              final seen = <String>{};
              for (final t in _storeTables) {
                final name = (t['area_name']?.toString().trim() ?? '');
                if (name.isEmpty) continue;
                final norm = name.toLowerCase();
                if (seen.add(norm)) {
                  areaOptions.add((key: 'name:$name', label: name));
                }
              }
            }

            final effectiveFilterKey =
                areaOptions.any((o) => o.key == _customerAreaFilterKey)
                    ? _customerAreaFilterKey
                    : 'all';

            final filteredTables =
                effectiveFilterKey == 'all' || _storeTables.isEmpty
                    ? tableNumbers
                    : tableNumbers.where((n) {
                        final row = _storeTables.firstWhere(
                          (t) =>
                              (int.tryParse(
                                    t['table_number']?.toString() ?? '',
                                  ) ??
                                  0) ==
                              n,
                          orElse: () => const <String, dynamic>{},
                        );
                        return matchesAreaFilter(
                          filterKey: effectiveFilterKey,
                          tableRow: row.isEmpty ? null : row,
                        );
                      }).toList(growable: false);

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
                if (areaOptions.length > 1) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Alan Seç',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: effectiveFilterKey,
                        items: areaOptions
                            .map(
                              (o) => DropdownMenuItem<String>(
                                value: o.key,
                                child: Text(
                                  o.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          final next = (value ?? 'all').trim();
                          if (next.isEmpty) return;
                          setDialogState(() => _customerAreaFilterKey = next);
                        },
                      ),
                    ),
                  ),
                ],
                if (occupiedNumbers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dolu masa',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Boş masa',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (filteredTables.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Bu alanda aktif masa bulunamadı.',
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
                          // Mobile: we show icon + (optional) area name + number.
                          // A perfect square tile overflows vertically, so we
                          // give each cell a bit more height.
                          childAspectRatio: 0.86,
                        ),
                    itemCount: filteredTables.length,
                    itemBuilder: (_, i) {
                      final tableNum = filteredTables[i];
                      final tableRow = _storeTables.isEmpty
                          ? null
                          : _storeTables.firstWhere(
                              (t) =>
                                  (int.tryParse(
                                        t['table_number']?.toString() ?? '',
                                      ) ??
                                      0) ==
                                  tableNum,
                              orElse: () => const <String, dynamic>{},
                            );
                      final resolvedRow =
                          (tableRow == null || tableRow.isEmpty) ? null : tableRow;
                      final areaName =
                          (resolvedRow?['area_name']?.toString() ?? '').trim();
                      final areaTableNo =
                          int.tryParse(
                            (resolvedRow?['area_table_number']?.toString() ?? '')
                                .trim(),
                          ) ??
                          0;
                      final displayNo = areaTableNo > 0 ? areaTableNo : tableNum;
                      final isOccupied = occupiedNumbers.contains(tableNum);
                      final bgColor = isOccupied
                          ? const Color(0xFFFEE2E2)
                          : AppColors.primary.withValues(alpha: 0.07);
                      final borderColor = isOccupied
                          ? const Color(0xFFFCA5A5)
                          : AppColors.primary.withValues(alpha: 0.25);
                      final iconColor = isOccupied
                          ? const Color(0xFFDC2626)
                          : AppColors.primary;
                      final textColor = isOccupied
                          ? const Color(0xFFDC2626)
                          : AppColors.primary;
                      return GestureDetector(
                        onTap: () {
                          if (isOccupied) {
                            ScaffoldMessenger.of(dlgCtx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Masa $tableNum şu anda dolu. Lütfen boş bir masa seçin.',
                                ),
                                backgroundColor: const Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          debugPrint(
                            '[BDP/QR] table-selection-dialog action — '
                            'table=$tableNum',
                          );
                          Navigator.pop(dlgCtx);
                          // Persist the area filter on the page state too.
                          if (mounted) {
                            setState(() => _customerAreaFilterKey = effectiveFilterKey);
                          }
                          _showFoodOrderDialog(
                            ctx,
                            tableNum,
                            unverifiedQrTableFlow: widget.unverifiedQrTableFlow,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOccupied
                                      ? Icons.do_not_disturb_alt_outlined
                                      : Icons.table_restaurant_outlined,
                                  color: iconColor,
                                  size: areaName.isNotEmpty ? 16 : 18,
                                ),
                                if (areaName.isNotEmpty)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      areaName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        height: 1.05,
                                        color: textColor.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                Text(
                                  '$displayNo',
                                  style: TextStyle(
                                    fontSize: areaName.isNotEmpty ? 11 : 12,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
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
      },
    );
    debugPrint(
      '[BDP/QR] popup OPENED — $popupName '
      'useRootNavigator=false tables=${tableNumbers.length}',
    );
    _trackQrPopup(
      popupName: popupName,
      useRootNavigator: false,
      future: popupFuture,
    );
  }

  Map<String, dynamic>? _storeTableRowByNumber(int tableNumber) {
    if (tableNumber <= 0 || _storeTables.isEmpty) return null;
    for (final row in _storeTables) {
      final n = int.tryParse(row['table_number']?.toString() ?? '') ?? 0;
      if (n == tableNumber) return row;
    }
    return null;
  }

  void _showFoodOrderDialog(
    BuildContext ctx,
    int tableNumber, {
    bool unverifiedQrTableFlow = false,
  }) {
    const popupName = 'food-order-dialog';
    debugPrint(
      '[BDP/QR] popup OPEN ATTEMPT — $popupName tableNumber=$tableNumber '
      'fromQr=${widget.fromQr}',
    );
    // Never auto-open a dialog if the user has already initiated back navigation.
    // This is the last-line guard for any async continuation that fires after
    // handleBack() has set _isLeavingQrFlow=true.
    if (_isQrPopupBlocked(popupName)) {
      return;
    }
    debugPrint(
      '[BDP/QR] popup OPENED via _showFoodOrderDialog '
      'tableNumber=$tableNumber _allProducts.length=${_allProducts.length}',
    );
    debugPrint(
      '[QR-BDP] _showFoodOrderDialog called. tableNumber=$tableNumber _allProducts.length=${_allProducts.length}',
    );
    debugPrint('[BDP-Timing] order sheet visible — tableNumber=$tableNumber');
    final popupFuture = showDialog<void>(
      context: ctx,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dlgCtx) => _FoodOrderDialog(
        business: widget.business,
        products: _allProducts,
        productsFuture: _productCompleter.future,
        tableNumber: tableNumber,
        tableRow: _storeTableRowByNumber(tableNumber),
        logoUrl: _storePublicInfo?['logoUrl'] as String?,
        unverifiedQrTableFlow: unverifiedQrTableFlow,
      ),
    );
    _trackQrPopup(
      popupName: popupName,
      useRootNavigator: false,
      future: popupFuture,
    );
  }
}

// ─── FOOD ORDER DIALOG ──────────────────────────────────────────────────────

class _FoodOrderDialog extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Product> products;

  /// Shared future that resolves when the page-level product fetch completes.
  /// The dialog awaits this instead of spawning its own duplicate request.
  final Future<List<Product>> productsFuture;
  final int tableNumber;
  final Map<String, dynamic>? tableRow;
  final String? logoUrl;
  final bool unverifiedQrTableFlow;

  const _FoodOrderDialog({
    required this.business,
    required this.products,
    required this.productsFuture,
    required this.tableNumber,
    this.tableRow,
    this.logoUrl,
    this.unverifiedQrTableFlow = false,
  });

  @override
  State<_FoodOrderDialog> createState() => _FoodOrderDialogState();
}

class _FoodOrderDialogState extends State<_FoodOrderDialog> {
  final StoreService _storeService = StoreService();
  final WaiterOrderRequestService _waiterRequests = WaiterOrderRequestService();
  final Map<String, Map<String, dynamic>> _cart = {};
  final List<Map<String, dynamic>> _mixedServiceCartItems = [];
  List<Product> _products = <Product>[];
  bool _isSending = false;
  bool _isCallingWaiter = false;
  bool _isLoadingProducts = false;
  bool _summaryExpanded = false;
  String? _productsError;
  String _selectedSubCat = 'Tümü';

  /// Seller ID resolved once and cached — avoids repeated lookups in
  /// _sendOrder and _loadProductsForDialog.
  String? _resolvedSellerId;

  @override
  void initState() {
    super.initState();
    _products = List<Product>.from(widget.products);
    if (_products.isEmpty) {
      // Await the SHARED page-level fetch instead of a duplicate Supabase call.
      _awaitSharedProductFuture();
    }
  }

  Future<void> _awaitSharedProductFuture() async {
    // Pre-resolve seller ID while waiting for products — reused by _sendOrder.
    _resolveSellerIdIfNeeded();
    final dlgWatch = Stopwatch()..start();
    debugPrint('[BDP-Timing] dialog awaiting productsFuture…');
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final loaded = await widget.productsFuture;
      debugPrint(
        '[BDP-Timing] dialog productsFuture resolved in ${dlgWatch.elapsedMilliseconds}ms — ${loaded.length} products',
      );
      if (!mounted) return;
      setState(() {
        _products = loaded;
        _isLoadingProducts = false;
        _productsError = loaded.isEmpty
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

  void _removeServiceCartItem(int index) {
    if (index < 0 || index >= _mixedServiceCartItems.length) return;
    setState(() {
      _mixedServiceCartItems.removeAt(index);
    });
  }

  int _totalItems() =>
      _cart.values.fold(0, (sum, v) => sum + (v['quantity'] as int)) +
      _mixedServiceCartItems.fold(
        0,
        (sum, v) => sum + ((v['quantity'] as num?)?.toInt() ?? 1),
      );

  Widget _buildDialogLogo() {
    final businessName = widget.business['name']?.toString() ?? '';
    final logoUrl = widget.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return OptimizedImage(
        imageUrlOrPath: logoUrl,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _dialogLogoFallback(businessName),
      );
    }
    if (StoreLogoHelper.hasLogo(businessName)) {
      return Image.asset(
        StoreLogoHelper.getStoreLogo(businessName)!,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
      );
    }
    return _dialogLogoFallback(businessName);
  }

  Widget _dialogLogoFallback(String businessName) {
    return Center(
      child: Icon(
        Icons.store_rounded,
        color: Colors.white.withValues(alpha: 0.90),
        size: 30,
      ),
    );
  }

  void _debugRestaurantPricing(Product product, {required String source}) {
    debugPrint(
      '[RestaurantPricing][$source] ${product.name} '
      'rawPrice=${product.price} '
      'resolvedPricingType=${product.resolvedPricingType.storageValue} '
      'pricingType=${product.pricingType} '
      'pricePerKg=${product.pricePerKg} '
      'effectivePricePerKg=${product.effectivePricePerKg} '
      'defaultWeightGrams=${product.defaultWeightGrams} '
      'minWeightGrams=${product.minWeightGrams} '
      'weightStepGrams=${product.weightStepGrams} '
      'maxWeightGrams=${product.maxWeightGrams} '
      'usesWeightSelector=${product.usesWeightSelector} '
      'displayPricing=${product.displayPricingText}',
    );
  }

  String _baseProductKey(Product product) {
    final productId = product.productId?.trim() ?? '';
    if (productId.isNotEmpty) return productId;
    return product.name.trim().isEmpty ? product.name : product.name.trim();
  }

  String _cartKeyForConfig(
    Product product, {
    int? selectedWeightGrams,
    double? selectedServiceAmount,
    String? selectedSizeName,
    List<String> selectedAttrs = const <String>[],
    String notes = '',
  }) {
    final baseKey = _baseProductKey(product);
    final normalizedSizeName = selectedSizeName?.trim() ?? '';
    if (!product.usesServiceControlStepper && normalizedSizeName.isEmpty) {
      return baseKey;
    }
    final normalizedAttrs = [...selectedAttrs]..sort();
    final selectionKey = product.usesWeightSelector
        ? (selectedWeightGrams ?? product.resolvedDefaultWeightGrams).toString()
        : ProductPriceCalculator.formatNumericAmount(
            selectedServiceAmount ?? product.resolvedDefaultServiceAmount,
          );
    return [
      baseKey,
      product.resolvedServiceControlType.storageValue,
      product.resolvedPricingType.storageValue,
      normalizedSizeName,
      selectionKey,
      normalizedAttrs.join(','),
      notes.trim().toLowerCase(),
    ].join('|');
  }

  List<MapEntry<String, Map<String, dynamic>>> _cartEntriesForProduct(
    Product product,
  ) {
    final baseKey = _baseProductKey(product);
    return _cart.entries
        .where((entry) => entry.value['baseProductKey'] == baseKey)
        .toList(growable: false);
  }

  MapEntry<String, Map<String, dynamic>>? _simpleCartEntryFor(Product product) {
    for (final entry in _cartEntriesForProduct(product)) {
      final attrs =
          (entry.value['selectedAttrs'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final notes = entry.value['notes']?.toString().trim() ?? '';
      if (attrs.isEmpty && notes.isEmpty) {
        return entry;
      }
    }
    return null;
  }

  Map<String, dynamic>? _cartItemFor(Product product) {
    if (product.usesServiceControlStepper) {
      return _simpleCartEntryFor(product)?.value;
    }
    final key = _cartKeyForConfig(
      product,
      selectedWeightGrams: product.usesWeightSelector
          ? product.resolvedDefaultWeightGrams
          : null,
    );
    return _cart[key];
  }

  int _quantityFor(Product product) {
    return _cartEntriesForProduct(product).fold<int>(
      0,
      (sum, entry) => sum + ((entry.value['quantity'] as int?) ?? 0),
    );
  }

  List<String> _selectedAttributesFor(Product product) =>
      (_cartItemFor(product)?['selectedAttrs'] as List?)?.cast<String>() ??
      const <String>[];

  String _cartLineSubtitle(Map<String, dynamic> item) {
    return _cartLineSubtitleWithOptions(item);
  }

  String _cartLineTitle(Map<String, dynamic> item) {
    final name = item['name']?.toString().trim() ?? '';
    final selectedSizeName = item['selectedSizeName']?.toString().trim() ?? '';
    if (selectedSizeName.isEmpty) {
      return name;
    }
    return '$name — $selectedSizeName';
  }

  String _cartLineSubtitleWithOptions(
    Map<String, dynamic> item, {
    bool includeSize = true,
  }) {
    final parts = <String>[];
    final selectedSizeName = item['selectedSizeName']?.toString().trim() ?? '';
    final amountLabel = item['amountLabel']?.toString().trim() ?? '';
    final weightGrams = (item['selectedWeightGrams'] as num?)?.toInt();
    final gramaj = item['gramaj']?.toString().trim() ?? '';
    final notes = item['notes']?.toString().trim() ?? '';
    final attrs =
        (item['selectedAttrs'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    if (includeSize && selectedSizeName.isNotEmpty) {
      parts.add(selectedSizeName);
    } else if (amountLabel.isNotEmpty && amountLabel != selectedSizeName) {
      parts.add(amountLabel);
    } else if (weightGrams != null && weightGrams > 0) {
      parts.add(ProductPriceCalculator.formatWeight(weightGrams));
    } else if (gramaj.isNotEmpty) {
      parts.add(gramaj);
    }
    if (attrs.isNotEmpty) {
      parts.add(attrs.join(', '));
    }
    if (notes.isNotEmpty) {
      parts.add(notes);
    }
    return parts.join(' · ');
  }

  String _mixedServiceGeneralNote(Map<String, dynamic> item) {
    return item['general_note']?.toString().trim().isNotEmpty == true
        ? item['general_note'].toString().trim()
        : item['note']?.toString().trim().isNotEmpty == true
        ? item['note'].toString().trim()
        : item['notes']?.toString().trim() ?? '';
  }

  Widget _buildMixedServiceSummaryCard(
    Map<String, dynamic> item,
    int itemIndex,
  ) {
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final title = item['name']?.toString().trim().isNotEmpty == true
        ? item['name'].toString().trim()
        : item['item_name']?.toString().trim().isNotEmpty == true
        ? item['item_name'].toString().trim()
        : 'Servis';
    final note = _mixedServiceGeneralNote(item);
    final detailEntries = MixedServiceOrder.childItemDisplayEntries(item);
    final lineTotal = MixedServiceOrder.itemLineTotal(item);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$quantity× $title',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Seçilen içerikler',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₺${lineTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _removeServiceCartItem(itemIndex),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          if (detailEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...detailEntries.map((entry) {
              if (entry.isGroupHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '- ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                              height: 1.25,
                            ),
                          ),
                          if (entry.detail?.isNotEmpty ?? false)
                            Text(
                              entry.detail!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Genel not: $note',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact summary row for a normal (non-mixed-service) cart item.
  Widget _buildCartItemSummaryRow(String cartKey, Map<String, dynamic> item) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final title = _cartLineTitle(item);
    final subtitle = _cartLineSubtitleWithOptions(item, includeSize: false);
    final lineTotal =
        (item['calculatedLineTotal'] as num?)?.toDouble() ??
        ((item['unitPriceSnapshot'] as num?)?.toDouble() ?? 0) * qty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$qty× $title',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          if (lineTotal > 0)
            Text(
              '₺${lineTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _cart.remove(cartKey)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 15,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOrderSummaryBar() {
    final cartList = _cart.entries.toList();
    final serviceList = _mixedServiceCartItems;
    final totalCount = cartList.length + serviceList.length;

    final allLabels = <String>[
      ...cartList.map(
        (e) => '${e.value['quantity']}× ${_cartLineTitle(e.value)}',
      ),
      ...serviceList.map(
        (e) =>
            '${(e['quantity'] as num?)?.toInt() ?? 1}× ${e['name'] ?? 'Servis'}',
      ),
    ];

    final previewLabels = allLabels.take(2).toList(growable: false);
    final remaining = totalCount - previewLabels.length;
    final total = _totalPrice();

    return GestureDetector(
      onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Sipariş Özeti',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                if (total > 0)
                  Text(
                    '₺${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _summaryExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (_summaryExpanded) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._cart.entries.map(
                        (e) => _buildCartItemSummaryRow(e.key, e.value),
                      ),
                      ..._mixedServiceCartItems.asMap().entries.map(
                        (e) => _buildMixedServiceSummaryCard(e.value, e.key),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...previewLabels.map(
                (label) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
              if (remaining > 0)
                Text(
                  '+$remaining ürün daha',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String? _selectionMetaFor(Product product) {
    final entries = _cartEntriesForProduct(product);
    if (entries.isEmpty) return null;
    final lines = entries
        .map((entry) {
          final item = entry.value;
          final qty = (item['quantity'] as int?) ?? 1;
          final subtitle = _cartLineSubtitle(item);
          if (subtitle.isEmpty) {
            return product.usesWeightSelector ? '$qty seçim' : '';
          }
          return qty > 1 ? '$subtitle x$qty' : subtitle;
        })
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return entries.length > 1 ? '${entries.length} seçim' : null;
    }
    if (lines.length <= 2) {
      return lines.join(' · ');
    }
    return '${lines.take(2).join(' · ')} +${lines.length - 2}';
  }

  Map<String, dynamic> _buildCartItem(
    Product product, {
    required int quantity,
    required List<String> selectedAttrs,
    required String notes,
    int? selectedWeightGrams,
    double? selectedServiceAmount,
    String? selectedSizeName,
  }) {
    final effectiveWeight = product.usesWeightSelector
        ? ProductPriceCalculator.clampWeightSelection(
            selectedWeightGrams ?? product.resolvedDefaultWeightGrams,
            minWeightGrams: product.minWeightGrams,
            weightStepGrams: product.weightStepGrams,
            maxWeightGrams: product.maxWeightGrams,
          )
        : null;
    final effectiveServiceAmount = product.usesPortionLikeStepper
        ? ProductPriceCalculator.clampPortionSelection(
            selectedServiceAmount ?? product.resolvedDefaultServiceAmount,
            type: product.resolvedServiceControlType,
            minPortion: product.minPortion,
            maxPortion: product.maxPortion,
            portionStep: product.portionStep,
          )
        : null;
    final unitPrice = ProductPriceCalculator.resolveServiceControlledUnitPrice(
      serviceControlType: product.resolvedServiceControlType,
      pricingType: product.resolvedPricingType,
      pricingMode: product.resolvedPricingMode,
      basePrice: product.basePrice ?? product.portionPrice,
      portionPrice: product.portionPrice,
      pricePerKg: product.effectivePricePerKg,
      sizeOptions: product.normalizedSizeOptions,
      selectedSizeName: selectedSizeName,
      fallbackPrice: product.effectivePortionPrice,
      selectedAmount: effectiveServiceAmount,
      selectedWeightGrams: effectiveWeight,
    );
    final lineTotal = unitPrice * quantity;
    final sortedAttrs = [...selectedAttrs]..sort();
    final normalizedSizeName = selectedSizeName?.trim() ?? '';
    final amountLabel = normalizedSizeName.isNotEmpty
        ? normalizedSizeName
        : product.usesServiceControlStepper
        ? ProductPriceCalculator.formatServiceAmountLabel(
            type: product.resolvedServiceControlType,
            amount: effectiveServiceAmount,
            grams: effectiveWeight,
          )
        : '';
    return {
      'baseProductKey': _baseProductKey(product),
      'productId': product.productId,
      'quantity': quantity,
      'gramaj': amountLabel,
      'amountLabel': amountLabel,
      'selectedSizeName': normalizedSizeName.isEmpty
          ? null
          : normalizedSizeName,
      'selectedSizePrice': normalizedSizeName.isEmpty ? null : unitPrice,
      'serviceControlType': product.resolvedServiceControlType.storageValue,
      'selectedServiceAmount': effectiveServiceAmount,
      'selectedWeightGrams': effectiveWeight,
      'notes': notes.trim(),
      'price': unitPrice,
      'name': product.name,
      'selectedAttrs': sortedAttrs,
      'unitPricingType': product.resolvedPricingType.storageValue,
      'unitPriceSnapshot': unitPrice,
      'calculatedLineTotal': lineTotal,
    };
  }

  void _setProductQuantity(Product product, int quantity) {
    final existing = _cartItemFor(product);
    final key = _cartKeyForConfig(
      product,
      selectedWeightGrams: (existing?['selectedWeightGrams'] as num?)?.toInt(),
      selectedServiceAmount: (existing?['selectedServiceAmount'] as num?)
          ?.toDouble(),
      selectedSizeName: existing?['selectedSizeName']?.toString(),
      selectedAttrs:
          (existing?['selectedAttrs'] as List?)?.cast<String>() ??
          const <String>[],
      notes: existing?['notes']?.toString() ?? '',
    );
    setState(() {
      if (quantity <= 0) {
        _cart.remove(key);
        return;
      }
      _cart[key] = _buildCartItem(
        product,
        quantity: quantity,
        selectedAttrs:
            (existing?['selectedAttrs'] as List?)?.cast<String>() ??
            const <String>[],
        notes: existing?['notes']?.toString() ?? '',
        selectedWeightGrams: (existing?['selectedWeightGrams'] as num?)
            ?.toInt(),
        selectedServiceAmount: (existing?['selectedServiceAmount'] as num?)
            ?.toDouble(),
        selectedSizeName: existing?['selectedSizeName']?.toString(),
      );
    });
  }

  void _setServiceControlAmount(Product product, double? nextAmount) {
    final existingEntry = _simpleCartEntryFor(product);
    final existing = existingEntry?.value;
    final currentWeight = (existing?['selectedWeightGrams'] as num?)?.toInt();
    final currentAmount = (existing?['selectedServiceAmount'] as num?)
        ?.toDouble();
    final shouldRemove = nextAmount == null || nextAmount <= 0;

    setState(() {
      if (existingEntry != null) {
        _cart.remove(existingEntry.key);
      }
      if (shouldRemove) return;

      _cart[_cartKeyForConfig(
        product,
        selectedWeightGrams: product.usesWeightSelector
            ? nextAmount.round()
            : currentWeight,
        selectedServiceAmount: product.usesPortionLikeStepper
            ? nextAmount
            : currentAmount,
      )] = _buildCartItem(
        product,
        quantity: 1,
        selectedAttrs: const <String>[],
        notes: '',
        selectedWeightGrams: product.usesWeightSelector
            ? nextAmount.round()
            : currentWeight,
        selectedServiceAmount: product.usesPortionLikeStepper
            ? nextAmount
            : currentAmount,
      );
    });
  }

  double? _serviceStepperValueFor(Product product) {
    final existing = _cartItemFor(product);
    if (existing == null) return null;
    if (product.usesWeightSelector) {
      final grams = (existing['selectedWeightGrams'] as num?)?.toInt();
      return grams == null || grams <= 0 ? null : grams.toDouble();
    }
    final amount = (existing['selectedServiceAmount'] as num?)?.toDouble();
    return amount == null || amount <= 0 ? null : amount;
  }

  String? _serviceStepperLabelFor(Product product) {
    final existing = _cartItemFor(product);
    if (existing == null) return null;
    final label = existing['amountLabel']?.toString().trim() ?? '';
    return label.isEmpty ? null : label;
  }

  void _addProductToCart(Product product) {
    if (product.usesServiceControlStepper) {
      _setServiceControlAmount(
        product,
        product.usesWeightSelector
            ? product.resolvedDefaultWeightGrams.toDouble()
            : product.resolvedDefaultServiceAmount,
      );
      return;
    }
    _setProductQuantity(product, 1);
  }

  void _incrementProductQuantity(Product product) {
    if (product.usesServiceControlStepper) {
      if (product.usesWeightSelector) {
        final current =
            _serviceStepperValueFor(product) ??
            product.resolvedDefaultWeightGrams.toDouble();
        _setServiceControlAmount(
          product,
          ProductPriceCalculator.clampWeightSelection(
            current.round() + product.resolvedWeightStepGrams,
            minWeightGrams: product.minWeightGrams,
            weightStepGrams: product.weightStepGrams,
            maxWeightGrams: product.maxWeightGrams,
          ).toDouble(),
        );
      } else {
        final current =
            _serviceStepperValueFor(product) ??
            product.resolvedDefaultServiceAmount;
        _setServiceControlAmount(
          product,
          ProductPriceCalculator.clampPortionSelection(
            current + product.resolvedPortionStepAmount,
            type: product.resolvedServiceControlType,
            minPortion: product.minPortion,
            maxPortion: product.maxPortion,
            portionStep: product.portionStep,
          ),
        );
      }
      return;
    }
    _setProductQuantity(
      product,
      ((_cartItemFor(product)?['quantity'] as int?) ?? 0) + 1,
    );
  }

  void _decrementProductQuantity(Product product) {
    if (product.usesServiceControlStepper) {
      if (product.usesWeightSelector) {
        final currentValue = _serviceStepperValueFor(product);
        if (currentValue == null) return;
        final min = ProductPriceCalculator.resolveMinWeightGrams(
          product.minWeightGrams,
        ).toDouble();
        if (currentValue <= min) {
          _setServiceControlAmount(product, null);
          return;
        }
        _setServiceControlAmount(
          product,
          ProductPriceCalculator.clampWeightSelection(
            currentValue.round() - product.resolvedWeightStepGrams,
            minWeightGrams: product.minWeightGrams,
            weightStepGrams: product.weightStepGrams,
            maxWeightGrams: product.maxWeightGrams,
          ).toDouble(),
        );
      } else {
        final currentValue = _serviceStepperValueFor(product);
        if (currentValue == null) return;
        final min = product.resolvedMinPortionAmount;
        if (currentValue <= min + 0.0001) {
          _setServiceControlAmount(product, null);
          return;
        }
        _setServiceControlAmount(
          product,
          ProductPriceCalculator.clampPortionSelection(
            currentValue - product.resolvedPortionStepAmount,
            type: product.resolvedServiceControlType,
            minPortion: product.minPortion,
            maxPortion: product.maxPortion,
            portionStep: product.portionStep,
          ),
        );
      }
      return;
    }
    _setProductQuantity(
      product,
      ((_cartItemFor(product)?['quantity'] as int?) ?? 0) - 1,
    );
  }

  Future<void> _showProductQuickView(Product product) async {
    _debugRestaurantPricing(product, source: 'quick_view_open');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (sheetContext) {
        return ProductQuickInfoSheet(product: product);
      },
    );
  }

  // ── Memoized category / filter results ──────────────────────────────────
  List<String>? _cachedSubCats;
  int _cachedSubCatsProductCount = -1;

  List<String> _subCategories() {
    if (_cachedSubCats != null &&
        _cachedSubCatsProductCount == _products.length) {
      return _cachedSubCats!;
    }
    final cats =
        _products
            .map((p) => p.subCategory ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    _cachedSubCats = ['Tümü', ...cats];
    _cachedSubCatsProductCount = _products.length;
    return _cachedSubCats!;
  }

  List<Product>? _cachedFiltered;
  String _cachedFilteredSubCat = '';
  int _cachedFilteredProductCount = -1;

  List<Product> _filteredProducts() {
    if (_cachedFiltered != null &&
        _cachedFilteredSubCat == _selectedSubCat &&
        _cachedFilteredProductCount == _products.length) {
      return _cachedFiltered!;
    }
    _cachedFiltered = _selectedSubCat == 'Tümü'
        ? _products
        : _products.where((p) => p.subCategory == _selectedSubCat).toList();
    _cachedFilteredSubCat = _selectedSubCat;
    _cachedFilteredProductCount = _products.length;
    return _cachedFiltered!;
  }

  /// Sum of all cart items × quantity. Used for the CTA label and summary row.
  double _totalPrice() {
    double total = 0;
    for (final entry in _cart.values) {
      final lineTotal = (entry['calculatedLineTotal'] as num?)?.toDouble();
      if (lineTotal != null && lineTotal > 0) {
        total += lineTotal;
        continue;
      }
      final unitPrice = (entry['unitPriceSnapshot'] as num?)?.toDouble();
      final quantity = (entry['quantity'] as int?) ?? 1;
      if (unitPrice != null && unitPrice > 0) {
        total += unitPrice * quantity;
        continue;
      }
      final raw = entry['price']?.toString() ?? '';
      final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
      final value = double.tryParse(cleaned) ?? 0;
      total += value * quantity;
    }
    for (final item in _mixedServiceCartItems) {
      total += MixedServiceOrder.itemLineTotal(item);
    }
    return total;
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
      pricingType: dbProduct.pricingType,
      portionPrice: dbProduct.portionPrice,
      pricePerKg: dbProduct.pricePerKg,
      defaultWeightGrams: dbProduct.defaultWeightGrams,
      minWeightGrams: dbProduct.minWeightGrams,
      weightStepGrams: dbProduct.weightStepGrams,
      maxWeightGrams: dbProduct.maxWeightGrams,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: const [],
      images: images,
      store: dbProduct.store ?? widget.business['name']?.toString() ?? '',
      sellerId: dbProduct.sellerId,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      shortDescription: dbProduct.description,
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
              pricingType:
                  map['pricing_type']?.toString() ??
                  map['pricingType']?.toString() ??
                  ProductPricingType.portion.storageValue,
              portionPrice:
                  (map['portion_price'] as num?)?.toDouble() ??
                  (map['portionPrice'] as num?)?.toDouble() ??
                  ProductPriceCalculator.parsePriceValue(priceText),
              pricePerKg:
                  (map['price_per_kg'] as num?)?.toDouble() ??
                  (map['pricePerKg'] as num?)?.toDouble(),
              serviceControlType:
                  map['service_control_type']?.toString() ??
                  map['serviceControlType']?.toString(),
              minPortion:
                  (map['min_portion'] as num?)?.toDouble() ??
                  (map['minPortion'] as num?)?.toDouble(),
              maxPortion:
                  (map['max_portion'] as num?)?.toDouble() ??
                  (map['maxPortion'] as num?)?.toDouble(),
              portionStep:
                  (map['portion_step'] as num?)?.toDouble() ??
                  (map['portionStep'] as num?)?.toDouble(),
              defaultWeightGrams:
                  (map['default_weight_grams'] as num?)?.toInt() ??
                  (map['defaultWeightGrams'] as num?)?.toInt(),
              minWeightGrams:
                  (map['min_weight_grams'] as num?)?.toInt() ??
                  (map['minWeightGrams'] as num?)?.toInt(),
              weightStepGrams:
                  (map['weight_step_grams'] as num?)?.toInt() ??
                  (map['weightStepGrams'] as num?)?.toInt(),
              maxWeightGrams:
                  (map['max_weight_grams'] as num?)?.toInt() ??
                  (map['maxWeightGrams'] as num?)?.toInt(),
              rating: (map['puan'] as num?)?.toDouble() ?? 0,
              reviewCount: (map['degerlendirme'] as num?)?.toInt() ?? 0,
              tags: tags,
              images: images,
              store: map['magaza']?.toString() ?? businessName,
              category: map['kategori']?.toString(),
              subCategory: map['alt_kategori']?.toString(),
              shortDescription: map['kisa_aciklama']?.toString(),
              description: map['aciklama']?.toString(),
              preparationTime:
                  map['hazirlanma_suresi']?.toString() ??
                  map['pisme_suresi']?.toString(),
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

  Future<void> _resolveSellerIdIfNeeded() async {
    if (_resolvedSellerId != null) return;
    final fromBusiness = widget.business['seller_id']?.toString();
    if ((fromBusiness ?? '').trim().isNotEmpty) {
      _resolvedSellerId = fromBusiness;
      return;
    }
    final businessName = widget.business['name']?.toString() ?? '';
    if (businessName.isNotEmpty) {
      _resolvedSellerId = await _storeService.getSellerIdByBusinessName(
        businessName,
      );
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
      await _resolveSellerIdIfNeeded();
      final sellerId = _resolvedSellerId;
      if ((sellerId ?? '').trim().isEmpty) {
        throw Exception('Satıcı bulunamadı.');
      }

      final rows = await _storeService.getMenuProductsBySellerId(sellerId!);
      var loadedProducts = rows
          .map<Product>((raw) {
            final data = Map<String, dynamic>.from(raw);
            final product = Product.fromDBProduct({
              ...data,
              'brand':
                  data['brand']?.toString() ??
                  widget.business['name']?.toString() ??
                  '',
              'store': widget.business['name']?.toString() ?? '',
              'category':
                  data['main_category']?.toString() ??
                  widget.business['category']?.toString(),
            });
            _debugRestaurantPricing(product, source: 'menu_fetch');
            return product.copyWith(price: _formatPrice(data['price']));
          })
          .where((product) => product.name.trim().isNotEmpty)
          .toList();

      debugPrint(
        '[Müşteri-Dialog] loaded ${loadedProducts.length} products from supabase',
      );
      for (final p in loadedProducts.take(10)) {
        debugPrint(
          '[Müşteri-Dialog] "${p.name}" isServiceTpl=${_isServiceTemplate(p)} '
          'type=${_productTypeFromProduct(p)} specs=${p.specifications != null ? "${p.specifications!.length}b" : "null"}',
        );
      }

      if (loadedProducts.isEmpty && businessName.isNotEmpty) {
        final paged = await SupabaseService.instance
            .getProductsByStoreNamePaged(storeName: businessName, limit: 120);
        loadedProducts = paged.items
            .map((item) {
              final product = _convertDbProductToDialogProduct(item);
              _debugRestaurantPricing(product, source: 'paged_fallback');
              return product;
            })
            .toList(growable: false);
      }

      if (loadedProducts.isEmpty && businessName.isNotEmpty) {
        loadedProducts = await _loadProductsFromLocalJson(businessName);
        for (final product in loadedProducts) {
          _debugRestaurantPricing(product, source: 'json_fallback');
        }
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

  Future<void> _showItemSettings(Product product) async {
    _debugRestaurantPricing(product, source: 'item_settings_open');
    final productCartEntries = _cartEntriesForProduct(product);
    final existing = product.usesWeightSelector
        ? (productCartEntries.isNotEmpty ? productCartEntries.last.value : null)
        : _cartItemFor(product);
    int qty = existing?['quantity'] ?? 1;
    double selectedServiceAmount =
        (existing?['selectedServiceAmount'] as num?)?.toDouble() ??
        product.resolvedDefaultServiceAmount;
    int selectedWeightGrams =
        (existing?['selectedWeightGrams'] as num?)?.toInt() ??
        product.resolvedDefaultWeightGrams;
    String? selectedSizeName =
        existing?['selectedSizeName']?.toString() ??
        product.defaultSizeOption?.name;
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    final productAttrs = product.attributes ?? [];
    final selectedAttrs = <String>{
      ...((existing?['selectedAttrs'] as List?)?.cast<String>() ?? []),
    };
    final actionLabel = existing == null ? 'Sepete Ekle' : 'Onayla';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final resolvedUnitPrice =
                ProductPriceCalculator.resolveServiceControlledUnitPrice(
                  serviceControlType: product.resolvedServiceControlType,
                  pricingType: product.resolvedPricingType,
                  pricingMode: product.resolvedPricingMode,
                  basePrice: product.basePrice ?? product.portionPrice,
                  portionPrice: product.portionPrice,
                  pricePerKg: product.effectivePricePerKg,
                  sizeOptions: product.normalizedSizeOptions,
                  selectedSizeName: selectedSizeName,
                  fallbackPrice: product.effectivePortionPrice,
                  selectedAmount: product.usesPortionLikeStepper
                      ? selectedServiceAmount
                      : null,
                  selectedWeightGrams: product.usesWeightSelector
                      ? selectedWeightGrams
                      : null,
                );
            final totalPrice = resolvedUnitPrice * qty;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.84,
                  minChildSize: 0.56,
                  maxChildSize: 0.96,
                  builder: (context, scrollController) {
                    return DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                20,
                              ),
                              children: [
                                Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'Secilen fiyat',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ProductPriceCalculator.formatCurrency(
                                        resolvedUnitPrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (product.hasSizeOptions) ...[
                                  const SizedBox(height: 22),
                                  const Text(
                                    'Boyut',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: product.normalizedSizeOptions
                                        .map((option) {
                                          final isSelected =
                                              selectedSizeName
                                                  ?.trim()
                                                  .toLowerCase() ==
                                              option.name.trim().toLowerCase();
                                          return ChoiceChip(
                                            label: Text(
                                              '${option.name} · ${ProductPriceCalculator.formatCurrency(option.price)}',
                                            ),
                                            selected: isSelected,
                                            onSelected: (_) {
                                              setSheet(() {
                                                selectedSizeName = option.name;
                                              });
                                            },
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                ],
                                if (product.usesWeightSelector) ...[
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _buildSelectionInfoBadge(
                                        label: 'Kg fiyatı',
                                        value:
                                            ProductPriceCalculator.formatPerKgLabel(
                                              product.effectivePricePerKg,
                                            ),
                                      ),
                                      _buildSelectionInfoBadge(
                                        label: 'Başlangıç gramajı',
                                        value:
                                            ProductPriceCalculator.formatWeight(
                                              product
                                                  .resolvedDefaultWeightGrams,
                                            ),
                                      ),
                                    ],
                                  ),
                                ] else if (product.displayWeightInfo !=
                                    null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    product.displayWeightInfo!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                if (!product.usesServiceControlStepper) ...[
                                  const Text(
                                    'Adet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _qtyButton(Icons.remove, () {
                                        if (qty > 1) {
                                          setSheet(() => qty--);
                                        }
                                      }),
                                      Container(
                                        width: 52,
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _qtyButton(
                                        Icons.add,
                                        () => setSheet(() => qty++),
                                      ),
                                    ],
                                  ),
                                ],
                                if (product.usesPortionLikeStepper) ...[
                                  const SizedBox(height: 22),
                                  const Text(
                                    'Servis Secimi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _qtyButton(Icons.remove, () {
                                        setSheet(() {
                                          selectedServiceAmount =
                                              ProductPriceCalculator.clampPortionSelection(
                                                selectedServiceAmount -
                                                    product
                                                        .resolvedPortionStepAmount,
                                                type: product
                                                    .resolvedServiceControlType,
                                                minPortion: product.minPortion,
                                                maxPortion: product.maxPortion,
                                                portionStep:
                                                    product.portionStep,
                                              );
                                        });
                                      }),
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 132,
                                        ),
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          ProductPriceCalculator.formatServiceAmountLabel(
                                            type: product
                                                .resolvedServiceControlType,
                                            amount: selectedServiceAmount,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _qtyButton(Icons.add, () {
                                        setSheet(() {
                                          selectedServiceAmount =
                                              ProductPriceCalculator.clampPortionSelection(
                                                selectedServiceAmount +
                                                    product
                                                        .resolvedPortionStepAmount,
                                                type: product
                                                    .resolvedServiceControlType,
                                                minPortion: product.minPortion,
                                                maxPortion: product.maxPortion,
                                                portionStep:
                                                    product.portionStep,
                                              );
                                        });
                                      }),
                                    ],
                                  ),
                                ],
                                if (product.usesWeightSelector) ...[
                                  const SizedBox(height: 22),
                                  WeightSelector(
                                    selectedGrams: selectedWeightGrams,
                                    minWeightGrams:
                                        ProductPriceCalculator.resolveMinWeightGrams(
                                          product.minWeightGrams,
                                        ),
                                    weightStepGrams:
                                        ProductPriceCalculator.resolveWeightStepGrams(
                                          product.weightStepGrams,
                                        ),
                                    maxWeightGrams:
                                        ProductPriceCalculator.resolveMaxWeightGrams(
                                          product.maxWeightGrams,
                                        ),
                                    presetOptions:
                                        ProductPriceCalculator.buildPresetWeightOptions(
                                          minWeightGrams:
                                              product.minWeightGrams,
                                          defaultWeightGrams:
                                              product.defaultWeightGrams,
                                          weightStepGrams:
                                              product.weightStepGrams,
                                          maxWeightGrams:
                                              product.maxWeightGrams,
                                        ),
                                    onChanged: (value) {
                                      setSheet(() {
                                        selectedWeightGrams = value;
                                      });
                                    },
                                  ),
                                ],
                                const SizedBox(height: 18),
                                const Text(
                                  'Açıklama / Not (isteğe bağlı)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: notesCtrl,
                                  minLines: 2,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: 'Örn: Az tuzlu, yanında ketçap',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                if (productAttrs.isNotEmpty) ...[
                                  const SizedBox(height: 22),
                                  const Text(
                                    'Özellikler',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: productAttrs.map((attr) {
                                      final isSelected = selectedAttrs.contains(
                                        attr,
                                      );
                                      return GestureDetector(
                                        onTap: () => setSheet(() {
                                          if (isSelected) {
                                            selectedAttrs.remove(attr);
                                          } else {
                                            selectedAttrs.add(attr);
                                          }
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              top: false,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final useVerticalLayout =
                                      constraints.maxWidth < 360;
                                  final totalInfo = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Canlı toplam',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ProductPriceCalculator.formatCurrency(
                                          totalPrice,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  );
                                  final actionButton = SizedBox(
                                    width: useVerticalLayout
                                        ? double.infinity
                                        : 180,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final trimmedNotes = notesCtrl.text
                                            .trim();
                                        final attrs = selectedAttrs.toList()
                                          ..sort();
                                        final key = _cartKeyForConfig(
                                          product,
                                          selectedWeightGrams:
                                              product.usesWeightSelector
                                              ? selectedWeightGrams
                                              : null,
                                          selectedServiceAmount:
                                              product.usesPortionLikeStepper
                                              ? selectedServiceAmount
                                              : null,
                                          selectedSizeName: selectedSizeName,
                                          selectedAttrs: attrs,
                                          notes: trimmedNotes,
                                        );
                                        final cartItem = _buildCartItem(
                                          product,
                                          quantity: qty,
                                          selectedAttrs: attrs,
                                          notes: trimmedNotes,
                                          selectedWeightGrams:
                                              product.usesWeightSelector
                                              ? selectedWeightGrams
                                              : null,
                                          selectedServiceAmount:
                                              product.usesPortionLikeStepper
                                              ? selectedServiceAmount
                                              : null,
                                          selectedSizeName: selectedSizeName,
                                        );
                                        Navigator.pop(sheetCtx);
                                        setState(() {
                                          _cart[key] = cartItem;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        actionLabel,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                  if (useVerticalLayout) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        totalInfo,
                                        const SizedBox(height: 14),
                                        actionButton,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: totalInfo),
                                      const SizedBox(width: 16),
                                      actionButton,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    notesCtrl.dispose();
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }

  Widget _buildSelectionInfoBadge({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ── Product type helpers (menu_template / service_template) ─────────────

  String _productTypeFromProduct(Product product) {
    return MixedServiceOrder.resolveProductKind(
      specifications: product.specifications,
      category: product.category,
      subCategory: product.subCategory,
    );
  }

  bool _isServiceTemplate(Product p) =>
      _productTypeFromProduct(p) ==
      MixedServiceOrder.serviceTemplateProductType;

  SellerProduct _toSellerProduct(Product p) {
    return SellerProduct(
      id: p.productId ?? '',
      name: p.name,
      brand: p.brand,
      mainCategory: p.category ?? '',
      subCategory: p.subCategory ?? '',
      price: ProductPriceCalculator.parsePriceValue(p.price),
      pricingType: p.pricingType,
      portionPrice: p.portionPrice,
      pricePerKg: p.pricePerKg,
      serviceControlType: p.serviceControlType,
      minPortion: p.minPortion,
      maxPortion: p.maxPortion,
      portionStep: p.portionStep,
      defaultWeightGrams: p.defaultWeightGrams,
      minWeightGrams: p.minWeightGrams,
      weightStepGrams: p.weightStepGrams,
      maxWeightGrams: p.maxWeightGrams,
      stock: 9999,
      sku: '',
      status: 'active',
      imageUrl: p.images.isNotEmpty ? p.images.first : null,
      specifications: p.specifications,
      attributes: p.attributes ?? const <String>[],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _openServiceTemplate(Product serviceProduct) async {
    debugPrint(
      '[ServiceDialog] opening for "${serviceProduct.name}" '
      'type=${_productTypeFromProduct(serviceProduct)}',
    );
    final allSellerProducts = _products.map(_toSellerProduct).toList();
    final serviceSellerProduct = _toSellerProduct(serviceProduct);
    final resolution = MixedServiceOrder.inspectTemplateSelectableProducts(
      serviceSellerProduct,
      availableProducts: allSellerProducts,
      debugContext: 'business_detail_page._openServiceTemplate',
    );
    final selectableProducts = resolution.selectableProducts;
    if (selectableProducts.isEmpty) {
      debugPrint(
        '[SERVICE_EMPTY] '
        'serviceId=${serviceSellerProduct.id} '
        'serviceName="${serviceSellerProduct.name}" '
        'templateItems=${resolution.templateItemsCount} '
        'matchedProducts=${resolution.matchedSelectableProductsCount} '
        'activeMatchedProducts=${resolution.activeMatchedProductsCount} '
        'finalSelectableCount=${resolution.selectableProducts.length}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu serviste seçilebilir aktif içerik bulunmuyor.'),
        ),
      );
      return;
    }
    final configured = await showMixedServiceDialog(
      context: context,
      products: selectableProducts,
      mode: MixedServiceDialogMode.edit,
      title: serviceProduct.name,
      subtitle: 'Servis içinden istediğiniz ürünleri seçin.',
      submitLabel: 'Sepete Ekle',
      headerImageUrl: serviceProduct.images.isNotEmpty
          ? serviceProduct.images.first
          : null,
      showItemNameField: false,
      noteHintText: 'Örn: Az pişmiş, soğansız, acısız, yanına lavaş ekleyin',
      initialItem: MixedServiceOrder.buildOrderItemFromTemplateProduct(
        serviceSellerProduct,
        availableProducts: allSellerProducts,
        preselectTemplateItems: false,
      ),
      availablePricingModes: const <String>[MixedServiceOrder.autoSumPriceMode],
    );
    if (configured == null || !mounted) return;
    setState(() {
      _mixedServiceCartItems.add(configured);
    });
  }

  Future<bool> _ensureCustomerLoggedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return true;
    if (!mounted) return false;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var signingIn = false;
    String? errorText;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Garsona göndermek için giriş'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Doğrulanmamış QR güvenlik modunda seçimleriniz '
                      'garson onayından sonra işlenir. Devam için oturum açın.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: signingIn
                      ? null
                      : () => Navigator.pop(dialogCtx, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: signingIn
                      ? null
                      : () async {
                          setLocal(() {
                            signingIn = true;
                            errorText = null;
                          });
                          try {
                            await Supabase.instance.client.auth
                                .signInWithPassword(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx, true);
                            }
                          } on AuthException catch (e) {
                            setLocal(() {
                              signingIn = false;
                              errorText = e.message;
                            });
                          } catch (e) {
                            setLocal(() {
                              signingIn = false;
                              errorText = e.toString();
                            });
                          }
                        },
                  child: signingIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Giriş yap'),
                ),
              ],
            );
          },
        );
      },
    );
    emailController.dispose();
    passwordController.dispose();
    return ok == true && Supabase.instance.client.auth.currentUser != null;
  }

  Future<void> _submitWaiterRequestToKitchen({
    required List<Map<String, dynamic>> items,
    String? customerNotes,
  }) async {
    if (!await _ensureCustomerLoggedIn()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devam etmek için giriş yapın.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    await _resolveSellerIdIfNeeded();
    final sellerId = _resolvedSellerId;
    if (sellerId == null || sellerId.isEmpty) {
      throw Exception('Satıcı bulunamadı.');
    }
    await _waiterRequests.submitRequest(
      sellerId: sellerId,
      tableNumber: widget.tableNumber,
      items: items,
      customerNotes: customerNotes,
      tableRow: widget.tableRow,
    );
  }

  Future<void> _callWaiter() async {
    if (_isCallingWaiter || _isSending) return;
    setState(() => _isCallingWaiter = true);
    try {
      await _resolveSellerIdIfNeeded();
      final sellerId = _resolvedSellerId;
      if (sellerId == null || sellerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Garson çağrılamadı. Lütfen tekrar deneyin.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (widget.unverifiedQrTableFlow) {
        await _submitWaiterRequestToKitchen(
          items: const [
            {
              'name': 'Garson Çağrıldı',
              'quantity': 1,
              'price': 0.0,
              'type': 'waiter_call',
            },
          ],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'İstek garsona iletildi (onay bekliyor). Masa ${widget.tableNumber}.',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      await _storeService.submitTableOrder(
        sellerId: sellerId,
        tableNumber: widget.tableNumber,
        items: const [
          {
            'name': 'Garson Çağrıldı',
            'quantity': 1,
            'price': 0.0,
            'type': 'waiter_call',
          },
        ],
        status: 'call_waiter',
        tableRow: widget.tableRow,
        placementSource: 'customer',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Garson çağrıldı! Masa ${widget.tableNumber} için garson yolda.',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Garson çağrılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCallingWaiter = false);
    }
  }

  Future<void> _sendOrder() async {
    if (_cart.isEmpty && _mixedServiceCartItems.isEmpty) return;
    debugPrint(
      '[Order] _sendOrder start — ${_cart.length} regular + ${_mixedServiceCartItems.length} service items, table=${widget.tableNumber}',
    );
    setState(() => _isSending = true);
    try {
      final businessName = widget.business['name']?.toString() ?? '';
      // Use cached sellerId — avoids a Supabase lookup at submit time.
      await _resolveSellerIdIfNeeded();
      final sellerId = _resolvedSellerId;

      if (sellerId == null || sellerId.isEmpty) {
        throw Exception('Satıcı bulunamadı.');
      }

      final items = [
        ..._cart.values.map(
          (v) => {
            'productId': v['productId'],
            'name': v['name'],
            'price': v['price'],
            'quantity': v['quantity'],
            'gramaj': v['gramaj'],
            'amountLabel': v['amountLabel'],
            'serviceControlType': v['serviceControlType'],
            'selectedServiceAmount': v['selectedServiceAmount'],
            'selectedWeightGrams': v['selectedWeightGrams'],
            'selectedSizeName': v['selectedSizeName'],
            'selectedSizePrice': v['selectedSizePrice'],
            'notes': v['notes'],
            'attributes': v['selectedAttrs'] ?? [],
            'unitPricingType': v['unitPricingType'],
            'unitPriceSnapshot': v['unitPriceSnapshot'],
            'calculatedLineTotal': v['calculatedLineTotal'],
          },
        ),
        ..._mixedServiceCartItems.map(
          (item) => Map<String, dynamic>.from(item),
        ),
      ];

      if (widget.unverifiedQrTableFlow) {
        await _submitWaiterRequestToKitchen(items: items);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Seçiminiz garson onayına gönderildi. Masa ${widget.tableNumber}.',
              ),
              backgroundColor: Colors.teal.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final inserted = await StoreService().submitTableOrder(
        sellerId: sellerId,
        tableNumber: widget.tableNumber,
        items: items,
        tableRow: widget.tableRow,
        placementSource: 'customer',
      );
      debugPrint('[Order] _sendOrder success — orderId=${inserted["id"]}');

      // Mutfak fişi müşteri gönderiminde tetiklenmez; garson panelinde
      // Garson "Siparişi Gönder" ile OrderPrintJobService.dispatchNewOrderFromTableOrder çalışır.

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
      debugPrint('[Order] addFoodOrder complete — orderId=$orderId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Siparişiniz masaya iletildi. Mutfak fişi garson onayından sonra yazdırılır.',
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        debugPrint('[Order] dialog popped — returning to BusinessDetailPage');
        debugPrint('[Order] post-order rebuild complete');
      }
    } catch (e) {
      debugPrint('[Order] _sendOrder error: $e');
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
    final hasAnyItems = _cart.isNotEmpty || _mixedServiceCartItems.isNotEmpty;

    return Dialog(
      backgroundColor: const Color(0xFFF7F7FC),
      surfaceTintColor: Colors.transparent,
      elevation: 28,
      insetPadding: isWeb
          ? const EdgeInsets.symmetric(horizontal: 80, vertical: 40)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isWeb ? 720 : double.infinity,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            // ── Premium header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    Color.lerp(
                      AppColors.primary,
                      const Color(0xFF5B1FBF),
                      0.55,
                    )!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Business logo badge
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildDialogLogo(),
                  ),
                  const SizedBox(width: 14),
                  // Title + sub
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.unverifiedQrTableFlow
                              ? 'Menü önizleme — Masa ${widget.tableNumber}'
                              : 'Masa ${widget.tableNumber}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.business['name']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.unverifiedQrTableFlow) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Text(
                              'QR doğrulanamadı. Doğrudan sipariş kapalı; '
                              'seçimleriniz garson onayından sonra işleme alınır.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cart badge + close stacked
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          debugPrint(
                            '[BDP/QR] popup CLOSED via X button '
                            'table=${widget.tableNumber}',
                          );
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      if (_totalItems() > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_totalItems()} ürün',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Subcategory filter bar ────────────────────────────────────
            if (subCats.length > 1)
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
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
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 0 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ── Product list ──────────────────────────────────────────────
            Expanded(
              child: _isLoadingProducts && _products.isEmpty
                  ? _buildMenuSkeleton()
                  : filteredProducts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Icon(
                                Icons.search_off_rounded,
                                size: 30,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _productsError ??
                                  'Bu kategoride ürün bulunamadı.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            if (_productsError != null) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _loadProductsForDialog,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Tekrar dene'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      itemCount: filteredProducts.length,
                      itemBuilder: (_, i) {
                        final product = filteredProducts[i];
                        final usesServiceStepper =
                            product.usesServiceControlStepper;
                        final isServiceTpl = _isServiceTemplate(product);
                        // TODO(debug): remove before production
                        debugPrint(
                          '[CUSTOMER_CARD] '
                          'name="${product.name}" '
                          'resolved_kind=${_productTypeFromProduct(product)} '
                          'button_mode=${isServiceTpl ? 'Seç' : 'Ekle'}',
                        );
                        return FoodProductCard(
                          product: product,
                          quantity: isServiceTpl
                              ? 0
                              : usesServiceStepper
                              ? (_serviceStepperValueFor(product) == null
                                    ? 0
                                    : 1)
                              : _quantityFor(product),
                          selectedAttributes: usesServiceStepper || isServiceTpl
                              ? const <String>[]
                              : _selectedAttributesFor(product),
                          selectionMeta: isServiceTpl
                              ? null
                              : _selectionMetaFor(product),
                          stepperValueLabel: usesServiceStepper && !isServiceTpl
                              ? _serviceStepperLabelFor(product)
                              : null,
                          addLabel: isServiceTpl
                              ? 'Seç'
                              : product.usesWeightSelector
                              ? ProductPriceCalculator.formatServiceAmountLabel(
                                  type: product.resolvedServiceControlType,
                                  grams: product.resolvedDefaultWeightGrams,
                                )
                              : product.usesPortionLikeStepper
                              ? ProductPriceCalculator.formatServiceAmountLabel(
                                  type: product.resolvedServiceControlType,
                                  amount: product.resolvedDefaultServiceAmount,
                                )
                              : 'Ekle',
                          onImageTap: () => _showProductQuickView(product),
                          onAdd: isServiceTpl
                              ? () => _openServiceTemplate(product)
                              : () => _addProductToCart(product),
                          onIncrement: isServiceTpl
                              ? null
                              : () => _incrementProductQuantity(product),
                          onDecrement: isServiceTpl
                              ? null
                              : () => _decrementProductQuantity(product),
                          onCustomize: isServiceTpl
                              ? null
                              : () => _showItemSettings(product),
                        );
                      },
                    ),
            ),

            // ── Action bar (always visible) ───────────────────────────────
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100, width: 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cart.isNotEmpty ||
                      _mixedServiceCartItems.isNotEmpty) ...[
                    _buildCompactOrderSummaryBar(),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSending || _isCallingWaiter
                          ? null
                          : _callWaiter,
                      icon: _isCallingWaiter
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.notifications_active_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _isCallingWaiter
                            ? 'Garson çağrılıyor...'
                            : widget.unverifiedQrTableFlow
                            ? 'Garson Çağır (onay bekler)'
                            : 'Garson Çağır',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: !hasAnyItems || _isSending ? null : _sendOrder,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.unverifiedQrTableFlow
                                  ? Icons.support_agent_rounded
                                  : Icons.send_rounded,
                              size: 19,
                            ),
                      label: Text(
                        _isSending
                            ? 'Gönderiliyor...'
                            : !hasAnyItems
                            ? widget.unverifiedQrTableFlow
                                  ? 'Ürün seçin veya garson çağırın'
                                  : 'Menüden ürün seçin'
                            : widget.unverifiedQrTableFlow
                            ? 'Garsona gönder (onay bekler) · ₺${_totalPrice().toStringAsFixed(0)}'
                            : _totalPrice() > 0
                            ? 'Masa ${widget.tableNumber} — Sipariş Ver · ₺${_totalPrice().toStringAsFixed(0)}'
                            : 'Masa ${widget.tableNumber} — Sipariş Ver',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !hasAnyItems
                            ? Colors.grey.shade200
                            : AppColors.primary,
                        foregroundColor: !hasAnyItems
                            ? Colors.grey.shade500
                            : Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: !hasAnyItems ? 0 : 5,
                        shadowColor: AppColors.primary.withValues(alpha: 0.38),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

  // ── Skeleton loader ──────────────────────────────────────────────────────

  Widget _buildMenuSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      itemCount: 5,
      itemBuilder: (_, _) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // image placeholder
          _shimmer(width: 64, height: 64, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: double.infinity, height: 13, radius: 6),
                const SizedBox(height: 6),
                _shimmer(width: 100, height: 11, radius: 5),
                const SizedBox(height: 8),
                _shimmer(width: 60, height: 13, radius: 5),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _shimmer(width: 58, height: 36, radius: 10),
        ],
      ),
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.9),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (_, value, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withValues(alpha: value),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      onEnd: () {
        /* TweenAnimationBuilder loops automatically via key cycling – stable */
      },
    );
  }
}
