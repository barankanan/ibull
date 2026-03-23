import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/route_observer.dart';
import '../screens/camera_page.dart';
import '../screens/notifications_page.dart';
import '../screens/product_detail_page.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'search_overlay.dart';

const bool _kDebugHeaderOverlayTint = true;

class CustomHeader extends StatefulWidget {
  final ValueChanged<String> onSearch;

  const CustomHeader({super.key, required this.onSearch});

  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader> with RouteAware {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _queryNotifier = ValueNotifier('');
  final AuthService _authService = AuthService();
  OverlayEntry? _overlayEntry;
  final GlobalKey _searchKey = GlobalKey();
  int _unreadNotificationCount = 0;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchTextChanged);
    _loadUnreadNotificationCount();
  }

  void _onSearchTextChanged() {
    _queryNotifier.value = _searchController.text;
    _refreshOverlayEntry();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _hideOverlay();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _queryNotifier.dispose();
    super.dispose();
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

  void _onFocusChange() {
    _refreshOverlayEntry();
    if (mounted) {
      setState(() {});
    }
    if (_searchFocusNode.hasFocus) {
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    if (_searchKey.currentContext == null) return;

    final renderBox =
        _searchKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final searchLeft = renderBox.localToGlobal(Offset.zero).dx;
    final mediaQuery = MediaQuery.of(context);
    final safeLeft = mediaQuery.padding.left;
    final safeRight = mediaQuery.padding.right;
    final overlayWidth = mediaQuery.size.width - safeLeft - safeRight;
    final overlayOffsetX = safeLeft - searchLeft;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: overlayWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(overlayOffsetX, size.height + 4),
          child: IgnorePointer(
            ignoring: !_shouldOverlayReceivePointers,
            child: ColoredBox(
              color: _kDebugHeaderOverlayTint
                  ? const Color(0x44FF0000)
                  : Colors.transparent,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: SearchOverlay(
                  queryListenable: _queryNotifier,
                  onClose: _hideOverlay,
                  onSearch: (query) {
                    final trimmed = query.trim();
                    if (trimmed.isEmpty) return;
                    context.read<AppState>().addSearchHistory(trimmed);
                    _searchController.text = trimmed;
                    _searchFocusNode.unfocus();
                    _hideOverlay();
                    Future.microtask(() {
                      if (!mounted) return;
                      try {
                        widget.onSearch(trimmed);
                      } catch (error, stackTrace) {
                        debugPrint('CustomHeader search submit failed: $error');
                        debugPrintStack(stackTrace: stackTrace);
                      }
                    });
                  },
                  onProductTap: (product) {
                    context.read<AppState>().addRecentlyViewedProduct(product);
                    _searchFocusNode.unfocus();
                    _hideOverlay();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(product: product),
                      ),
                    );
                  },
                ),
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

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    context.read<AppState>().addSearchHistory(query);
    _searchFocusNode.unfocus();
    _hideOverlay();
    Future.microtask(() {
      if (!mounted) return;
      try {
        widget.onSearch(query);
      } catch (error, stackTrace) {
        debugPrint('CustomHeader search button failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  void _clearSearchField() {
    _searchController.clear();
    _queryNotifier.value = '';
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _closeSearchOverlay() {
    _searchFocusNode.unfocus();
    _hideOverlay();
  }

  Future<void> _loadUnreadNotificationCount() async {
    final currentUserId = _authService.currentUser?.id.trim() ?? '';
    if (currentUserId.isEmpty) {
      if (!mounted) return;
      setState(() => _unreadNotificationCount = 0);
      return;
    }

    try {
      final notifications = await OrderService.instance.getUserNotifications(
        currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = notifications
            .where((notification) => notification['read_at'] == null)
            .length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotificationCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _searchController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildActionButton(
              icon: Icons.notifications_none_rounded,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
                if (!mounted) return;
                await _loadUnreadNotificationCount();
              },
              tooltip: 'Bildirimler',
              borderless: true,
              iconColor: AppColors.primary,
              badgeCount: _unreadNotificationCount,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CompositedTransformTarget(
                link: _layerLink,
                child: AnimatedContainer(
                  key: _searchKey,
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : const Color(0xFFD8DCE6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _searchFocusNode.hasFocus
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: _searchFocusNode.hasFocus ? 12 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (_searchFocusNode.hasFocus) {
                            _closeSearchOverlay();
                            return;
                          }
                          _searchFocusNode.requestFocus();
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submitSearch(),
                          decoration: InputDecoration(
                            hintText: 'Marka, ürün veya kategori ara...',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasText)
                        InkWell(
                          onTap: _clearSearchField,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFF6A7280),
                            ),
                          ),
                        )
                      else if (_searchFocusNode.hasFocus)
                        InkWell(
                          onTap: _closeSearchOverlay,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 16,
                              color: Color(0xFF6A7280),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildActionButton(
              icon: Icons.camera_alt_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraPage()),
                );
              },
              tooltip: 'Kamera',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool filled = false,
    bool borderless = false,
    Color? iconColor,
    int badgeCount = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: borderless
                ? Colors.transparent
                : (filled ? AppColors.primary : Colors.white),
            shape: BoxShape.circle,
            border: borderless || filled
                ? null
                : Border.all(color: const Color(0xFFDADDE6)),
            boxShadow: borderless
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: filled ? 0.14 : 0.05,
                      ),
                      blurRadius: filled ? 10 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              icon,
              color:
                  iconColor ??
                  (filled ? Colors.white : const Color(0xFF545E70)),
              size: 22,
            ),
            onPressed: onPressed,
            tooltip: tooltip,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
