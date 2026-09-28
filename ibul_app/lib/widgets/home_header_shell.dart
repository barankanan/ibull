import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/home_navigation.dart';
import '../core/ibul_chrome.dart';
import '../screens/home_lazy_routes.dart';

/// Production İBUL web/mobile header — WebHeader görünümü, ağır route import yok.
class HomeHeaderShell extends StatefulWidget {
  const HomeHeaderShell({
    super.key,
    required this.onSearch,
    this.onCategorySelected,
    this.selectedCategory = 'Ana Sayfa',
  });

  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onCategorySelected;
  final String selectedCategory;

  static const _webCategories = [
    'Yakın Lokasyon',
    'Erkek',
    'Kadın',
    'Elektronik',
    'Ayakkabı & Çanta',
    'Saat & Aksesuar',
    'Ev & Yaşam',
    'Kırtasiye & Ofis',
    'Oto, Bahçe, Yapı Market',
    'Oyuncak, Müzik, Film',
    'Spor & Outdoor',
    'Kozmetik & Kişisel Bakım',
    'Pet Shop',
  ];

  @override
  State<HomeHeaderShell> createState() => _HomeHeaderShellState();
}

class _HomeHeaderShellState extends State<HomeHeaderShell> {
  final _searchController = TextEditingController();
  final _categoryScrollController = ScrollController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch([String? raw]) {
    final query = (raw ?? _searchController.text).trim();
    if (query.length < 3) return;
    _searchFocusNode.unfocus();
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = IbulChrome.isWebOf(context);
    return Column(
      children: [
        Container(
          decoration: IbulChrome.headerBarDecoration,
          padding: IbulChrome.headerPadding(isWeb: isWeb),
          child: isWeb ? _buildWebTopBar() : _buildMobileTopBar(),
        ),
        if (isWeb) _buildCategoryBar(),
      ],
    );
  }

  Widget _buildWebTopBar() {
    return Row(
      children: [
        _buildLogo(),
        const SizedBox(width: 48),
        Expanded(child: _buildSearchBar(showCamera: true)),
        const SizedBox(width: 32),
        _buildMapLink(),
        const SizedBox(width: 32),
        _buildMenuItems(),
      ],
    );
  }

  Widget _buildMobileTopBar() {
    return Column(
      children: [
        Row(
          children: [
            _buildLogo(compact: true),
            const Spacer(),
            IconButton(
              tooltip: 'Harita',
              icon: const Icon(Icons.map_outlined, color: AppColors.primary),
              onPressed: () => unawaited(HomeLazyRoutes.openMap(context)),
            ),
            IconButton(
              tooltip: 'Favorilerim',
              icon: const Icon(Icons.favorite_border, color: AppColors.primary),
              onPressed: () => unawaited(HomeLazyRoutes.openFavorites(context)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSearchBar(showCamera: true),
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

  Widget _buildLogo({bool compact = false}) {
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
                      width: compact ? 28 : 36,
                      height: compact ? 28 : 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: compact ? 28 : 36,
                        height: compact ? 28 : 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'İ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 14 : 18,
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
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                      letterSpacing: 0.2,
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

  Widget _buildSearchBar({required bool showCamera}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, color: Colors.grey, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
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
          if (showCamera) ...[
            Semantics(
              button: true,
              label: 'Kamera',
              child: InkWell(
                onTap: () => unawaited(HomeLazyRoutes.openCamera(context)),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Semantics(
            button: true,
            label: 'Ara',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () => _submitSearch(),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMapLink() {
    return Semantics(
      button: true,
      label: 'Harita',
      child: InkWell(
        onTap: () => unawaited(HomeLazyRoutes.openMap(context)),
        child: const Row(
          children: [
            Icon(Icons.map, color: AppColors.primary, size: 24),
            SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Konum',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
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
      ),
    );
  }

  Widget _buildMenuItems() {
    final appState = context.read<AppState>();
    return ValueListenableBuilder<int>(
      valueListenable: appState.cartCountNotifier,
      builder: (context, cartCount, _) {
        return Row(
          children: [
            _HeaderMenuItem(
              icon: Icons.person_outline,
              label: 'Hesabım',
              onTap: () => unawaited(HomeLazyRoutes.openAccount(context)),
            ),
            const SizedBox(width: 24),
            _HeaderMenuItem(
              icon: Icons.favorite_border,
              label: 'Favorilerim',
              onTap: () => unawaited(HomeLazyRoutes.openFavorites(context)),
            ),
            const SizedBox(width: 24),
            _HeaderMenuItem(
              icon: Icons.shopping_cart_outlined,
              label: 'Sepetim',
              badgeCount: cartCount > 0 ? cartCount : null,
              onTap: () => unawaited(HomeLazyRoutes.openCart(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: IbulChrome.categoryBarDecoration,
      child: Center(
        child: ConstrainedBox(
          constraints: IbulChrome.contentConstraints,
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: ListView.separated(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 24, right: 60),
                    itemCount: HomeHeaderShell._webCategories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 32),
                    itemBuilder: (context, index) {
                      final category = HomeHeaderShell._webCategories[index];
                      final isSelected = widget.selectedCategory == category;
                      return InkWell(
                        onTap: () {
                          if (category == 'Yakın Lokasyon') {
                            unawaited(HomeLazyRoutes.openMap(context));
                          } else {
                            widget.onCategorySelected?.call(category);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: isSelected
                                ? const Border(
                                    bottom: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  )
                                : null,
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[800],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMenuItem extends StatelessWidget {
  const _HeaderMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badgeCount == null ? label : '$label, $badgeCount ürün',
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        child: ExcludeSemantics(
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: Colors.black87, size: 20),
                  if (badgeCount != null)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
