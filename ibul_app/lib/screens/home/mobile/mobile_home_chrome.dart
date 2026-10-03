import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../../../core/route_observer.dart';
import '../../../models/db_category.dart';
import '../../../screens/home_lazy_routes.dart';
import '../../../screens/notifications_page.dart'
    deferred as notifications_page;
import '../../../services/auth_service.dart';
import '../../../services/order_service.dart' deferred as order_service;
import '../../../widgets/search_overlay.dart' deferred as search_overlay;

const mobileHomeCanvas = Color(0xFFF7F7FA);
const mobileHomeInk = Color(0xFF111827);
const mobileHomeMuted = Color(0xFF6B7280);
const mobileHomeLine = Color(0xFFE6E7EE);

class MobileHomeTopBar extends StatefulWidget {
  const MobileHomeTopBar({super.key});

  @override
  State<MobileHomeTopBar> createState() => _MobileHomeTopBarState();
}

class _MobileHomeTopBarState extends State<MobileHomeTopBar> {
  final _auth = AuthService();
  var _unread = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUnread());
  }

  Future<void> _loadUnread() async {
    final userId = _auth.currentUser?.id.trim() ?? '';
    if (userId.isEmpty) return;
    try {
      await order_service.loadLibrary();
      if (!mounted) return;
      final rows = await order_service.OrderService.instance
          .getUserNotifications(userId);
      if (!mounted) return;
      setState(() {
        _unread = rows.where((row) => row['read_at'] == null).length;
      });
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await notifications_page.loadLibrary();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => notifications_page.NotificationsPage(),
      ),
    );
    await _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    return _IconBadge(
      key: const ValueKey('mobile-home-notifications'),
      icon: Icons.notifications_none_rounded,
      count: _unread,
      onTap: _openNotifications,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        icon: Badge(
          isLabelVisible: count > 0,
          alignment: Alignment.topRight,
          offset: const Offset(4, -4),
          backgroundColor: const Color(0xFFE11D48),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
          label: Text(count > 9 ? '9+' : '$count'),
          child: Icon(icon, color: mobileHomeInk, size: 23),
        ),
      ),
    );
  }
}

class MobileHomeSearchBar extends StatefulWidget {
  const MobileHomeSearchBar({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  State<MobileHomeSearchBar> createState() => _MobileHomeSearchBarState();
}

class _MobileHomeSearchBarState extends State<MobileHomeSearchBar>
    with RouteAware {
  final _link = LayerLink();
  final _focus = FocusNode();
  final _controller = TextEditingController();
  final _query = ValueNotifier('');
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlay;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _controller.addListener(() {
      _query.value = _controller.text;
      _overlay?.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _removeOverlay();
    _focus.dispose();
    _controller.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) return;
    if (_route != null) routeObserver.unsubscribe(this);
    _route = route;
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _focus.unfocus();
    _removeOverlay();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      unawaited(_showOverlay());
    } else {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!_focus.hasFocus) _removeOverlay();
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _showOverlay() async {
    await search_overlay.loadLibrary();
    if (!mounted || _overlay != null || _fieldKey.currentContext == null) {
      return;
    }
    final box = _fieldKey.currentContext!.findRenderObject()! as RenderBox;
    final left = box.localToGlobal(Offset.zero).dx;
    final safeLeft = MediaQuery.paddingOf(context).left;
    final width =
        MediaQuery.sizeOf(context).width -
        safeLeft -
        MediaQuery.paddingOf(context).right;
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(safeLeft - left, box.size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: search_overlay.SearchOverlay(
              queryListenable: _query,
              onClose: _removeOverlay,
              onSearch: _submit,
              onProductTap: (product) {
                context.read<AppState>().addRecentlyViewedProduct(product);
                _focus.unfocus();
                _removeOverlay();
                HomeLazyRoutes.openProductDetail(context, product);
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.length < 3) return;
    context.read<AppState>().addSearchHistory(query);
    _controller.text = query;
    _focus.unfocus();
    _removeOverlay();
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Container(
        key: _fieldKey,
        height: 48,
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focus.hasFocus ? AppColors.primary : mobileHomeLine,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: mobileHomeMuted, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('mobile-home-search'),
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: const InputDecoration(
                  hintText: 'Ürün, mağaza, kategori veya marka ara...',
                  hintStyle: TextStyle(
                    color: mobileHomeMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: mobileHomeInk,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('mobile-home-camera'),
              tooltip: 'Kamera',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onPressed: () => HomeLazyRoutes.openCamera(context),
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: mobileHomeInk,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileHomeChips extends StatelessWidget {
  const MobileHomeChips({
    super.key,
    required this.categories,
    required this.loading,
    required this.selected,
    required this.onSelect,
  });

  final List<DBCategory> categories;
  final bool loading;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        key: ValueKey('mobile-home-chip-skeleton'),
        height: 38,
        child: _BoneRow(widths: [88, 112, 72, 96]),
      );
    }
    const hidden = {'Yakınımdakiler', 'Yakın Lokasyon'};
    final labels = <String>[
      'Sana Özel',
      for (final category in categories.take(8))
        if (category.name.trim().isNotEmpty &&
            !hidden.contains(category.name.trim()))
          category.name.trim(),
      'Daha Fazla',
    ];
    return SizedBox(
      key: const ValueKey('mobile-home-chips'),
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          final active = label == selected;
          return Material(
            color: active ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: ValueKey('mobile-home-chip-$label'),
              onTap: () => onSelect(label),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppColors.primary : mobileHomeLine,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MobileHomeQuickActions extends StatelessWidget {
  const MobileHomeQuickActions({
    super.key,
    required this.onTap,
    this.loading = false,
  });

  final ValueChanged<String> onTap;
  final bool loading;

  static const actions = <_QuickAction>[
    _QuickAction(
      'Kuponlar',
      'coupons',
      Icons.local_offer_outlined,
      Color(0xFFF8F6FC),
    ),
    _QuickAction(
      'Araçlar',
      'vehicles',
      Icons.directions_car_outlined,
      Color(0xFFF7F8F7),
    ),
    _QuickAction(
      'Kampanyalar',
      'deals',
      Icons.campaign_outlined,
      Color(0xFFFBF8F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        key: ValueKey('mobile-home-quick-skeleton'),
        height: HomeQuickActionCard.height,
        child: _BoneRow(widths: [184, 184, 184]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: SizedBox(
        key: const ValueKey('mobile-home-quick-actions'),
        height: HomeQuickActionCard.height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: actions.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: HomeQuickActionCard.gap),
          itemBuilder: (context, index) {
            final action = actions[index];
            return HomeQuickActionCard(
              icon: action.icon,
              title: action.title,
              background: action.background,
              actionKey: ValueKey('mobile-home-action-${action.id}'),
              onTap: () => onTap(action.id),
            );
          },
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.title, this.id, this.icon, this.background);

  final String title;
  final String id;
  final IconData icon;
  final Color background;
}

class HomeQuickActionCard extends StatelessWidget {
  const HomeQuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.background = const Color(0xFFF8F6FC),
    this.actionKey,
  });

  static const double height = 56;
  static const double radius = 16;
  static const double gap = 10;
  static const double cardWidth = 184;

  final IconData icon;
  final String title;
  final Color background;
  final VoidCallback onTap;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: cardWidth,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFE7E5EF)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                      color: mobileHomeInk,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class MobileHomeTypography {
  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: mobileHomeInk,
  );

  static const sectionAction = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}

class MobileHomeSectionTitle extends StatelessWidget {
  const MobileHomeSectionTitle({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MobileHomeTypography.sectionTitle,
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Tümünü Gör',
                style: MobileHomeTypography.sectionAction,
              ),
            ),
        ],
      ),
    );
  }
}

class _BoneRow extends StatelessWidget {
  const _BoneRow({required this.widths});

  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final width in widths) ...[
          Container(
            width: width,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E7EE),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
