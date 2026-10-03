import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/marketplace_paths.dart';
import '../../../features/vehicle/domain/vehicle_category.dart';
import '../../../models/db_category.dart';
import 'mobile_home_catalog.dart';
import 'mobile_home_chrome.dart';
import 'mobile_home_hero.dart';
import 'mobile_home_models.dart';
import 'mobile_home_places.dart';

class MobileHomeFeed extends StatefulWidget {
  const MobileHomeFeed({
    super.key,
    required this.bannerUrls,
    required this.heroLoading,
    required this.onSearch,
    required this.onOpenMap,
    required this.onOpenCategories,
    required this.onOpenCategory,
    this.onOpenCategoryNode,
    required this.onOpenVehicles,
    this.trailing,
    this.gateway,
    this.cacheExtent = 900,
  });

  final List<String> bannerUrls;
  final bool heroLoading;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenCategories;
  final ValueChanged<String> onOpenCategory;
  final ValueChanged<CategoryWithSubcategories>? onOpenCategoryNode;
  final VoidCallback onOpenVehicles;
  final Widget? trailing;
  final MobileHomeGateway? gateway;
  final double cacheExtent;

  @override
  State<MobileHomeFeed> createState() => _MobileHomeFeedState();
}

class _MobileHomeFeedState extends State<MobileHomeFeed> {
  final _productsKey = GlobalKey();
  final _storesKey = GlobalKey();
  final _dealsKey = GlobalKey();
  late final MobileHomeGateway _gateway =
      widget.gateway ?? LiveMobileHomeGateway();
  var _bundle = MobileHomeBundle.empty;
  var _loading = true;
  var _chip = 'Sana Özel';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bundle = await _gateway.load();
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _loading = false;
    });
  }

  void _reveal(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      alignment: 0.05,
    );
  }

  void _onChip(String label) {
    setState(() => _chip = label);
    if (label == 'Sana Özel') {
      _reveal(_productsKey);
      return;
    }
    if (label == 'Yakınımdakiler') {
      if (_bundle.stores.isEmpty) {
        widget.onOpenMap();
      } else {
        _reveal(_storesKey);
      }
      return;
    }
    if (label == 'Daha Fazla') {
      widget.onOpenCategories();
      return;
    }
    if (isVehicleHubShortcutTitle(label) || label == 'Araç') {
      widget.onOpenVehicles();
      return;
    }
    final node = _nodeNamed(label);
    if (node != null) {
      final openNode = widget.onOpenCategoryNode;
      if (openNode != null) {
        openNode(node);
        return;
      }
    }
    widget.onOpenCategory(label);
  }

  CategoryWithSubcategories? _nodeNamed(String name) {
    for (final node in _bundle.categoryTree) {
      if (node.mainCategory.name == name) return node;
    }
    return null;
  }

  void _onAction(String id) {
    if (id == 'malls') {
      widget.onOpenMap();
      return;
    }
    if (id == 'coupons') {
      final router = GoRouter.maybeOf(context);
      if (router != null) router.push(MarketplacePaths.coupons);
      return;
    }
    if (id == 'vehicles') {
      widget.onOpenVehicles();
      return;
    }
    if (id == 'deals') {
      if (_bundle.deals.isEmpty) {
        widget.onOpenCategories();
      } else {
        _reveal(_dealsKey);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: mobileHomeCanvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 0),
            child: SizedBox(
              key: const ValueKey('mobile-home-header'),
              height: 48,
              child: Row(
                children: [
                  const MobileHomeTopBar(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: MobileHomeSearchBar(onSearch: widget.onSearch),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              cacheExtent: widget.cacheExtent,
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                const SizedBox(height: 8),
                MobileHomeChips(
                  categories: _bundle.categories,
                  loading: _loading,
                  selected: _chip,
                  onSelect: _onChip,
                ),
                const SizedBox(height: 12),
                MobileHomeHero(
                  urls: widget.bannerUrls,
                  loading: widget.heroLoading,
                ),
                const SizedBox(height: 12),
                MobileHomeQuickActions(loading: _loading, onTap: _onAction),
                if (_loading)
                  const _FeedSkeleton()
                else ...[
                  KeyedSubtree(
                    key: _storesKey,
                    child: MobileHomeNearbyStores(
                      stores: _bundle.stores,
                      onSeeAll: widget.onOpenMap,
                    ),
                  ),
                  MobileHomeMalls(
                    malls: _bundle.malls,
                    onSeeAll: widget.onOpenMap,
                  ),
                  KeyedSubtree(
                    key: _productsKey,
                    child: MobileHomeProductRails(
                      products: _bundle.products,
                      onSeeAllFeatured: widget.onOpenCategories,
                    ),
                  ),
                  KeyedSubtree(
                    key: _dealsKey,
                    child: MobileHomeDeals(products: _bundle.products),
                  ),
                  MobileHomeCategoryRails(
                    products: _bundle.products,
                    onSeeAllCategory: _onChip,
                  ),
                  MobileHomeVehicles(
                    listings: _bundle.vehicles,
                    onSeeAll: widget.onOpenVehicles,
                  ),
                  const MobileHomeRecent(),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('mobile-home-feed-skeleton'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Block(height: 22, width: 140),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _Block(height: 180, width: 168),
                SizedBox(width: 10),
                _Block(height: 180, width: 168),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFE6E7EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(height: height, width: width ?? double.infinity),
    );
  }
}

Future<void> showMobileSubcategorySheet(
  BuildContext context,
  CategoryWithSubcategories node,
) async {
  final main = node.mainCategory;
  final mainId = main.id;
  if (mainId == null) return;
  final subs = [
    for (final sub in node.subCategories)
      if (sub.isActive && sub.id != null && sub.name.trim().isNotEmpty) sub,
  ];
  if (subs.isEmpty) {
    _openCategoryList(context, mainId: mainId, subId: '-', slug: main.name);
    return;
  }
  final picked = await showModalBottomSheet<DBCategory>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.55;
      return SafeArea(
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  main.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: subs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    key: ValueKey('mobile-subcategory-${subs[index].id}'),
                    title: Text(subs[index].name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, subs[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null || picked.id == null || !context.mounted) return;
  _openCategoryList(
    context,
    mainId: mainId,
    subId: '${picked.id}',
    slug: '${main.name}-${picked.name}',
  );
}

void _openCategoryList(
  BuildContext context, {
  required int mainId,
  required String subId,
  required String slug,
}) {
  final path = MarketplacePaths.category('$mainId', subId, slug: slug);
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(path);
    return;
  }
  Navigator.of(context).pushNamed(path);
}
