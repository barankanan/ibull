import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/home_navigation.dart';
import '../core/ibul_chrome.dart';
import '../screens/notifications_page.dart' deferred as notifications_page;
import '../core/route_observer.dart';
import 'web_header_menu_items.dart';
import 'marketplace_content_frame.dart';
import 'search_overlay.dart' deferred as search_overlay;
import '../screens/home_lazy_routes.dart';
import 'web_category_bar.dart';

class WebHeader extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onCategorySelected;
  final String? selectedCategory;
  final String? initialQuery;
  final String? activeMenu;
  final bool showBackButton;
  final bool showCategories;

  const WebHeader({
    super.key,
    required this.onSearch,
    this.onCategorySelected,
    this.selectedCategory,
    this.initialQuery,
    this.activeMenu,
    this.showBackButton = false,
    this.showCategories = true,
  });

  @override
  State<WebHeader> createState() => _WebHeaderState();
}

class _WebHeaderState extends State<WebHeader> with RouteAware {
  final ScrollController _categoryScrollController = ScrollController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _queryNotifier = ValueNotifier('');
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _queryNotifier.value = widget.initialQuery!;
    }
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    _queryNotifier.value = _searchController.text;
    _refreshOverlayEntry();
  }

  @override
  void didUpdateWidget(covariant WebHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery ?? '';
    final previousQuery = oldWidget.initialQuery ?? '';
    if (nextQuery != previousQuery && _searchController.text != nextQuery) {
      _searchController.text = nextQuery;
      _queryNotifier.value = nextQuery;
    }
  }

  void _onFocusChange() {
    setState(() {});
    _refreshOverlayEntry();
    if (_searchFocusNode.hasFocus) {
      _showOverlay();
    } else {
      // Delay to allow tap on overlay items
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  final GlobalKey _searchKey = GlobalKey();

  Future<void> _openNotifications() async {
    await notifications_page.loadLibrary();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => notifications_page.NotificationsPage(),
      ),
    );
  }

  Future<void> _showOverlay({bool showFilters = false}) async {
    await search_overlay.loadLibrary();
    if (!mounted) return;
    if (_overlayEntry != null) {
      _hideOverlay();
    }

    final RenderBox renderBox =
        _searchKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50), // Height of bar (48) + spacing (2)
          child: IgnorePointer(
            ignoring: !_shouldOverlayReceivePointers,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: search_overlay.SearchOverlay(
                queryListenable: _queryNotifier,
                onClose: _hideOverlay,
                onSearch: (query) => _submitSearch(query),
                onProductTap: (product) {
                  context.read<AppState>().addRecentlyViewedProduct(product);
                  _searchFocusNode.unfocus();
                  _hideOverlay();
                  HomeLazyRoutes.openProductDetail(context, product);
                },
                showFilters: showFilters,
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  bool get _shouldOverlayReceivePointers {
    final isCurrentRoute = _route?.isCurrent ?? true;
    return mounted && isCurrentRoute && _searchFocusNode.hasFocus;
  }

  void _refreshOverlayEntry() {
    _overlayEntry?.markNeedsBuild();
  }

  void _submitSearch([String? rawValue]) {
    final query = (rawValue ?? _searchController.text).trim();
    if (query.isEmpty) return;

    context.read<AppState>().addSearchHistory(query);
    _searchController.text = query;
    _queryNotifier.value = query;
    _searchFocusNode.unfocus();
    _hideOverlay();
    Future.microtask(() {
      if (!mounted) return;
      try {
        widget.onSearch(query);
      } catch (error, stackTrace) {
        debugPrint('WebHeader search submit failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) {
      return;
    }
    if (_route != null) {
      routeObserver.unsubscribe(this);
    }
    _route = route;
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _refreshOverlayEntry();
    _searchFocusNode.unfocus();
    _hideOverlay();
  }

  @override
  void deactivate() {
    _refreshOverlayEntry();
    _searchFocusNode.unfocus();
    _hideOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _categoryScrollController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _queryNotifier.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Üst Bar (Logo, Arama, Menüler)
        Container(
          decoration: IbulChrome.headerBarDecoration,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: MarketplaceContentFrame(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;
                final links = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLocation(),
                    const SizedBox(width: 16),
                    WebHeaderMenuItems(activeMenu: widget.activeMenu),
                  ],
                );
                final logo = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showBackButton) ...[
                      _buildBackButton(),
                      const SizedBox(width: 4),
                    ],
                    _buildLogo(),
                  ],
                );
                if (compact) {
                  return Column(
                    children: [
                      Row(children: [logo, const Spacer(), links]),
                      const SizedBox(height: 12),
                      _buildSearchBar(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    logo,
                    const SizedBox(width: 24),
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 16),
                    links,
                  ],
                );
              },
            ),
          ),
        ),

        // Kategori Menüsü (Alt Bar)
        if (widget.showCategories) WebCategoryBar(
          selectedCategory: widget.selectedCategory,
          onCategorySelected: widget.onCategorySelected,
        ),
      ],
    );
  }

  void _openMarketplaceHome() {
    if (widget.onCategorySelected != null) {
      widget.onCategorySelected!('Ana Sayfa');
      return;
    }
    HomeNavigation.openHome(context);
  }

  void _onHeaderBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    _openMarketplaceHome();
  }

  Widget _buildBackButton() {
    return Tooltip(
      message: 'Geri',
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: AppColors.primary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: _onHeaderBack,
      ),
    );
  }

  Widget _buildLogo() {
    return Tooltip(
      message: 'Ana sayfaya git',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        container: true,
        label: 'Ana sayfaya git',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openMarketplaceHome,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      AppAssets.ibulLogo,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'İ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'iBul',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                      letterSpacing: 0.2,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Tooltip(
          message: 'Bildirimler',
          child: InkWell(
            onTap: () {
              unawaited(_openNotifications());
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              key: _searchKey,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchFocusNode.hasFocus
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.grey, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      textAlign: TextAlign.start,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSubmitted: _submitSearch,
                      decoration: const InputDecoration(
                        hintText: 'Ürün, kategori veya marka ara...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Semantics(
                    button: true,
                    label: 'Kamera',
                    child: InkWell(
                      onTap: () {
                        _searchFocusNode.unfocus();
                        _hideOverlay();
                        // HomeLazyRoutes: deferred chunk'tan açılır (bkz.
                        // custom_header.dart'taki aynı desen). Push aynı.
                        HomeLazyRoutes.openCamera(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Semantics(
                    button: true,
                    label: 'Ara',
                    child: InkWell(
                      onTap: () => _submitSearch(),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'ARA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
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
    );
  }

  Widget _buildLocation() {
    return InkWell(
      onTap: () {
        // Navigate to MapPage (deferred)
        HomeLazyRoutes.openMap(context);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map, color: AppColors.primary, size: 24),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Konum',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Text(
                    'Harita',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


}

class _NotificationsPopup extends StatefulWidget {
  final VoidCallback onClose;

  const _NotificationsPopup({required this.onClose});

  @override
  State<_NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<_NotificationsPopup> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bildirimler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Kapat',
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Bildirim', Icons.notifications),
                    _buildTabButton(1, 'İzleme', Icons.visibility_outlined),
                    _buildTabButton(2, 'Mesaj', Icons.chat_bubble_outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            SizedBox(height: 260, child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isActive = _activeTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.primary : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildNotificationsTab();
      case 1:
        return _buildWatchlistTab();
      case 2:
        return _buildMessagesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNotificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNotificationItem(
          title: 'Sepetine bıraktığın ürün düştü',
          subtitle: 'Takip ettiğin Dyson süpürgenin fiyatı %10 indi.',
          time: '5 dk önce',
          isNew: true,
        ),
        const SizedBox(height: 12),
        _buildNotificationItem(
          title: 'Siparişin kargoya verildi',
          subtitle: 'Apple AirPods Max siparişin yola çıktı.',
          time: 'Dün',
          isNew: false,
        ),
      ],
    );
  }

  Widget _buildWatchlistTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWatchItem(
          title: 'iPhone 15 Pro 256 GB',
          tag: 'Fiyat izlemesi',
          status: 'Fiyat değişmedi',
        ),
        const SizedBox(height: 12),
        _buildWatchItem(
          title: 'Kablosuz dik süpürge',
          tag: 'Stok izlemesi',
          status: 'Stokta 3 mağaza var',
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMessageItem(
          sender: 'Teknosa',
          preview:
              'Merhaba, ürünle ilgili sorunu yardımcı olmak için buradayız.',
          time: '2 sa önce',
        ),
        const SizedBox(height: 12),
        _buildMessageItem(
          sender: 'Baran K***',
          preview: 'İlgin için teşekkürler, ürünü hala satıyorum.',
          time: 'Dün',
        ),
      ],
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String subtitle,
    required String time,
    required bool isNew,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              if (isNew) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Yeni',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWatchItem({
    required String title,
    required String tag,
    required String status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.visibility_outlined,
            size: 18,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem({
    required String sender,
    required String preview,
    required String time,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade200,
          child: Text(
            sender.isNotEmpty ? sender[0] : '?',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sender,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
