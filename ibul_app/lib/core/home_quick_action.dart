import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/products/models/product_filter_models.dart';
import '../features/vehicle/domain/vehicle_category.dart';
import '../features/vehicle/navigation/vehicle_routes.dart'
    deferred as vehicle_routes;
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../screens/category_products_page.dart'
    deferred as category_products_page;
import '../services/database_helper.dart';
import '../utils/text_normalizer.dart';
import 'constants.dart';

/// Ana sayfa hızlı kategori / fırsat kısayol türleri.
enum HomeQuickActionType {
  deals,
  discounts,
  bestSellers,
  newest,
  featured,
  gift,
  category,
  vehicle,
}

/// Ana sayfa üst kısayol butonu modeli.
class HomeQuickAction {
  const HomeQuickAction({
    required this.id,
    required this.title,
    required this.type,
    this.categorySlug,
    this.subCategoryName,
    this.filterType,
    this.searchQuery,
  });

  final String id;
  final String title;
  final HomeQuickActionType type;
  final String? categorySlug;
  final String? subCategoryName;
  final String? filterType;
  final String? searchQuery;
}

/// Ana sayfa varsayılan kısayol başlıkları → aksiyon eşlemesi.
abstract final class HomeQuickActionRegistry {
  static const _homeShortcuts = <String, HomeQuickAction>{
    'Süper Fırsat': HomeQuickAction(
      id: 'deals',
      title: 'Süper Fırsat',
      type: HomeQuickActionType.deals,
      filterType: 'deals',
    ),
    'İndirimler': HomeQuickAction(
      id: 'discounts',
      title: 'İndirimler',
      type: HomeQuickActionType.discounts,
      filterType: 'discounted',
    ),
    'Çok Satanlar': HomeQuickAction(
      id: 'best_sellers',
      title: 'Çok Satanlar',
      type: HomeQuickActionType.bestSellers,
      filterType: 'best_sellers',
    ),
    'Yeniler': HomeQuickAction(
      id: 'newest',
      title: 'Yeniler',
      type: HomeQuickActionType.newest,
      filterType: 'newest',
    ),
    'Özel Ürünler': HomeQuickAction(
      id: 'featured',
      title: 'Özel Ürünler',
      type: HomeQuickActionType.featured,
      filterType: 'featured',
    ),
    'Hediye': HomeQuickAction(
      id: 'gift',
      title: 'Hediye',
      type: HomeQuickActionType.gift,
      filterType: 'gift',
      searchQuery: 'hediye',
    ),
    'Elektronik': HomeQuickAction(
      id: 'elektronik',
      title: 'Elektronik',
      type: HomeQuickActionType.category,
      categorySlug: 'Elektronik',
    ),
    'Ev & Yaşam': HomeQuickAction(
      id: 'ev_yasam',
      title: 'Ev & Yaşam',
      type: HomeQuickActionType.category,
      categorySlug: 'Ev & Yaşam',
    ),
    'Moda': HomeQuickAction(
      id: 'moda',
      title: 'Moda',
      type: HomeQuickActionType.category,
      categorySlug: 'Giyim & Aksesuar',
    ),
    'Spor': HomeQuickAction(
      id: 'spor',
      title: 'Spor',
      type: HomeQuickActionType.category,
      categorySlug: 'Spor & Outdoor',
    ),
    'Kitap': HomeQuickAction(
      id: 'kitap',
      title: 'Kitap',
      type: HomeQuickActionType.category,
      categorySlug: 'Kitap & Hobi',
      subCategoryName: 'Kitap',
    ),
    'Araç': HomeQuickAction(
      id: 'arac',
      title: 'Araç',
      type: HomeQuickActionType.vehicle,
    ),
  };

  static HomeQuickAction? fromHomeShortcutTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    return _homeShortcuts[trimmed];
  }

  static bool isHomePageShortcut(String title) =>
      fromHomeShortcutTitle(title) != null;
}

/// Filtre uygulama — RLS/visibility sonrası client-side daraltma.
abstract final class HomeQuickActionFilter {
  static List<DBProduct> apply(
    HomeQuickAction action,
    List<DBProduct> products,
  ) {
    final active = products.where((product) => product.isActive).toList();
    switch (action.type) {
      case HomeQuickActionType.deals:
        return active.where(_isDealProduct).toList(growable: false);
      case HomeQuickActionType.discounts:
        return active.where(_isDiscounted).toList(growable: false);
      case HomeQuickActionType.bestSellers:
        return (List<DBProduct>.from(active)
              ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount)))
            .take(24)
            .toList(growable: false);
      case HomeQuickActionType.newest:
        return (List<DBProduct>.from(active)..sort((a, b) {
              final aDate = a.catalogUpdatedAt;
              final bDate = b.catalogUpdatedAt;
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            }))
            .take(24)
            .toList(growable: false);
      case HomeQuickActionType.featured:
        return active.where(_isFeaturedProduct).toList(growable: false);
      case HomeQuickActionType.gift:
        return active.where(_isGiftProduct).toList(growable: false);
      case HomeQuickActionType.category:
      case HomeQuickActionType.vehicle:
        return active;
    }
  }

  static bool isDiscounted(DBProduct product) => _isDiscounted(product);

  static bool isDealProduct(DBProduct product) => _isDealProduct(product);

  static bool _isDiscounted(DBProduct product) {
    final oldPrice = _parsePrice(product.oldPrice);
    final price = _parsePrice(product.price);
    return oldPrice > price && price > 0;
  }

  static bool _isDealProduct(DBProduct product) {
    if (_isDiscounted(product)) return true;
    final haystack = _tagHaystack(product);
    return haystack.contains('firsat') ||
        haystack.contains('kampanya') ||
        haystack.contains('indirim');
  }

  static bool _isFeaturedProduct(DBProduct product) {
    final haystack = _tagHaystack(product);
    if (haystack.contains('one cikan') || haystack.contains('ozel')) {
      return true;
    }
    return product.rating >= 4.5 && product.reviewCount >= 3;
  }

  static bool _isGiftProduct(DBProduct product) {
    final haystack = _tagHaystack(product);
    if (haystack.contains('hediye')) return true;
    final keywords = TextNormalizer.normalize(product.keywords ?? '');
    return keywords.contains('hediye');
  }

  static String _tagHaystack(DBProduct product) {
    return TextNormalizer.normalize(product.tags);
  }

  static double _parsePrice(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    return double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }
}

/// Kısayol navigasyonu — mevcut CategoryProductsPage route'unu kullanır.
abstract final class HomeQuickActionNavigator {
  HomeQuickActionNavigator._();

  static void logTap(HomeQuickAction action, {String? target}) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomeQuickAction][tap] '
      'id=${action.id} '
      'title=${action.title} '
      'type=${action.type.name} '
      'target=${target ?? '-'} '
      'categorySlug=${action.categorySlug ?? '-'} '
      'filterType=${action.filterType ?? '-'}',
    );
  }

  static Future<void> open(
    BuildContext context,
    HomeQuickAction action, {
    List<DBProduct>? seedProducts,
  }) async {
    logTap(action, target: 'loading');

    if (!context.mounted) return;

    if (action.type == HomeQuickActionType.vehicle ||
        isVehicleHubShortcutTitle(action.title)) {
      logTap(action, target: 'vehicle_hub');
      await vehicle_routes.loadLibrary();
      if (!context.mounted) return;
      await vehicle_routes.VehicleRoutes.openHub(context);
      return;
    }

    if (action.type == HomeQuickActionType.category) {
      await _openCategory(context, action);
      return;
    }

    await _openFilteredListing(context, action, seedProducts: seedProducts);
  }

  static Future<void> _openCategory(
    BuildContext context,
    HomeQuickAction action,
  ) async {
    final category = action.categorySlug?.trim() ?? '';
    if (category.isEmpty) {
      _showNotFound(context, action.title);
      return;
    }

    final subCategory = action.subCategoryName?.trim();
    logTap(action, target: 'category:$category');

    try {
      final page = await DatabaseHelper.instance.getCategoryProductsPaged(
        category: category,
        subCategory: subCategory,
        limit: 24,
      );
      if (!context.mounted) return;

      if (page.items.isEmpty) {
        _showNotFound(context, action.title);
        return;
      }

      await _pushCategoryProductsPage(
        context,
        category: category,
        subCategory: subCategory ?? 'HEPSİ',
        items: page.items,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      debugPrint('[HomeQuickAction] category load failed: $error');
      if (context.mounted) {
        _showNotFound(context, action.title);
      }
    }
  }

  static Future<void> _openFilteredListing(
    BuildContext context,
    HomeQuickAction action, {
    List<DBProduct>? seedProducts,
  }) async {
    logTap(action, target: 'filter:${action.filterType}');

    List<DBProduct> source = seedProducts ?? const [];
    if (source.isEmpty) {
      try {
        if (action.searchQuery != null &&
            action.searchQuery!.trim().isNotEmpty) {
          source = await DatabaseHelper.instance.searchProducts(
            action.searchQuery!.trim(),
          );
        } else {
          source = await DatabaseHelper.instance.getProductsPage(limit: 72);
        }
      } catch (error) {
        debugPrint('[HomeQuickAction] filter load failed: $error');
      }
    }

    final filtered = HomeQuickActionFilter.apply(action, source);
    if (!context.mounted) return;

    if (filtered.isEmpty) {
      _showNotFound(context, action.title);
      return;
    }

    await _pushCategoryProductsPage(
      context,
      category: action.title,
      subCategory: 'HEPSİ',
      items: filtered,
    );
  }

  static Future<void> _pushCategoryProductsPage(
    BuildContext context, {
    required String category,
    required String subCategory,
    required List<DBProduct> items,
    String? nextCursor,
  }) async {
    final products = items.map(Product.fromDBProduct).toList(growable: false);
    final meta = <String, ProductFilterMeta>{};
    for (final item in items) {
      final id = item.id?.trim();
      if (id == null || id.isEmpty) continue;
      meta[id] = ProductFilterMeta(stock: item.stock);
    }

    await category_products_page.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => category_products_page.CategoryProductsPage(
          category: category,
          subCategory: subCategory,
          products: products,
          productMeta: meta,
          initialNextCursor: nextCursor,
        ),
      ),
    );
  }

  static void _showNotFound(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('“$title” için ürün bulunamadı.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Web/mobil hızlı kısayol chip — pointer + semantics.
class HomeQuickActionChip extends StatelessWidget {
  const HomeQuickActionChip({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Tooltip(
        message: title,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: AppColors.primary.withValues(alpha: 0.06),
              splashColor: AppColors.primary.withValues(alpha: 0.12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
