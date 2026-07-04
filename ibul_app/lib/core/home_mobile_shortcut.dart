import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/products/models/product_filter_models.dart';
import '../models/product_model.dart';
import '../screens/ai_chat_page.dart';
import '../screens/category_products_page.dart';
import '../screens/feature_coming_soon_page.dart';
import '../screens/lists_page.dart';
import '../screens/map_page.dart';
import '../screens/visual_search_selection_page.dart';
import '../services/database_helper.dart';

enum HomeMobileShortcutType {
  nearbyLocation,
  createList,
  visualSearch,
  productBreakdown,
  premium,
  personalized,
  fastFood,
  aiAssistant,
}

class HomeMobileShortcutAction {
  const HomeMobileShortcutAction({
    required this.id,
    required this.title,
    required this.type,
    this.categorySlug,
    this.enabled = true,
    this.requiresAuth = false,
  });

  final String id;
  final String title;
  final HomeMobileShortcutType type;
  final String? categorySlug;
  final bool enabled;
  final bool requiresAuth;
}

class HomeMobileShortcutCallbacks {
  const HomeMobileShortcutCallbacks({
    this.scrollToPersonalizedSection,
    this.showAddressSelection,
    this.switchToMapTab,
  });

  final VoidCallback? scrollToPersonalizedSection;
  final VoidCallback? showAddressSelection;
  final VoidCallback? switchToMapTab;
}

abstract final class HomeMobileShortcutRegistry {
  static const _byKey = <String, HomeMobileShortcutAction>{
    'yakin_lokasyon': HomeMobileShortcutAction(
      id: 'yakin_lokasyon',
      title: 'Yakın Lokasyon',
      type: HomeMobileShortcutType.nearbyLocation,
    ),
    'urun_listele': HomeMobileShortcutAction(
      id: 'urun_listele',
      title: 'Ürün Listele',
      type: HomeMobileShortcutType.createList,
    ),
    'gorsel_zeka': HomeMobileShortcutAction(
      id: 'gorsel_zeka',
      title: 'Görsel Zeka',
      type: HomeMobileShortcutType.visualSearch,
    ),
    'urun_parcala': HomeMobileShortcutAction(
      id: 'urun_parcala',
      title: 'Ürün Parçala',
      type: HomeMobileShortcutType.productBreakdown,
    ),
    'ibul_premium': HomeMobileShortcutAction(
      id: 'ibul_premium',
      title: 'İBUL Premium',
      type: HomeMobileShortcutType.premium,
    ),
    'bana_ozel': HomeMobileShortcutAction(
      id: 'bana_ozel',
      title: 'Bana Özel',
      type: HomeMobileShortcutType.personalized,
    ),
    'hizli_yemek': HomeMobileShortcutAction(
      id: 'hizli_yemek',
      title: 'Hızlı Yemek',
      type: HomeMobileShortcutType.fastFood,
      categorySlug: 'Yemek',
    ),
    'yapay_zeka': HomeMobileShortcutAction(
      id: 'yapay_zeka',
      title: 'Yapay Zeka',
      type: HomeMobileShortcutType.aiAssistant,
    ),
  };

  static HomeMobileShortcutAction? fromKey(String key) => _byKey[key.trim()];

  static HomeMobileShortcutAction? fromLabel(String label) {
    for (final action in _byKey.values) {
      if (action.title == label.trim()) return action;
    }
    return null;
  }
}

abstract final class HomeMobileShortcutNavigator {
  HomeMobileShortcutNavigator._();

  static void logTap(
    HomeMobileShortcutAction action, {
    required String target,
    bool enabled = true,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomeShortcut][tap] '
      'id=${action.id} '
      'title=${action.title} '
      'type=${action.type.name} '
      'target=$target '
      'enabled=$enabled',
    );
  }

  static Future<void> open(
    BuildContext context,
    HomeMobileShortcutAction action, {
    HomeMobileShortcutCallbacks callbacks = const HomeMobileShortcutCallbacks(),
    bool remoteEnabled = true,
  }) async {
    if (!remoteEnabled || !action.enabled) {
      logTap(action, target: 'comingSoon', enabled: false);
      await _openComingSoon(context, action);
      return;
    }

    switch (action.type) {
      case HomeMobileShortcutType.nearbyLocation:
        if (callbacks.switchToMapTab != null) {
          logTap(action, target: 'shellMapTab');
          callbacks.switchToMapTab!.call();
          callbacks.showAddressSelection?.call();
          return;
        }
        logTap(action, target: 'MapPage');
        callbacks.showAddressSelection?.call();
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const MapPage()),
        );
      case HomeMobileShortcutType.createList:
        logTap(action, target: 'ListsPage');
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const ListsPage()),
        );
      case HomeMobileShortcutType.visualSearch:
        logTap(action, target: 'VisualSearchSelectionPage');
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const VisualSearchSelectionPage(),
          ),
        );
      case HomeMobileShortcutType.productBreakdown:
        logTap(action, target: 'VisualSearchSelectionPage');
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const VisualSearchSelectionPage(),
          ),
        );
      case HomeMobileShortcutType.premium:
        logTap(action, target: 'FeatureComingSoonPage');
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const FeatureComingSoonPage(
              title: 'İBUL Premium',
              description:
                  'Premium üyelik ile öncelikli teslimat, özel kampanyalar '
                  've kişisel alışveriş deneyimi yakında sizinle.',
              icon: Icons.workspace_premium_rounded,
            ),
          ),
        );
      case HomeMobileShortcutType.personalized:
        logTap(action, target: 'scrollPersonalized');
        callbacks.scrollToPersonalizedSection?.call();
      case HomeMobileShortcutType.fastFood:
        logTap(action, target: 'category:Yemek');
        await _openCategory(context, category: action.categorySlug ?? 'Yemek');
      case HomeMobileShortcutType.aiAssistant:
        logTap(action, target: 'AIChatPage');
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const AIChatPage()),
        );
    }
  }

  static Future<void> _openComingSoon(
    BuildContext context,
    HomeMobileShortcutAction action,
  ) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => FeatureComingSoonPage(
          title: action.title,
          description: '${action.title} özelliği üzerinde çalışıyoruz. '
              'Yakında aktif olacak.',
        ),
      ),
    );
  }

  static Future<void> _openCategory(
    BuildContext context, {
    required String category,
  }) async {
    try {
      final page = await DatabaseHelper.instance.getCategoryProductsPaged(
        category: category,
        limit: 24,
      );
      if (!context.mounted) return;
      if (page.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('“$category” için ürün bulunamadı.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final products =
          page.items.map(Product.fromDBProduct).toList(growable: false);
      final meta = <String, ProductFilterMeta>{};
      for (final item in page.items) {
        final id = item.id?.trim();
        if (id == null || id.isEmpty) continue;
        meta[id] = ProductFilterMeta(stock: item.stock);
      }

      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => CategoryProductsPage(
            category: category,
            subCategory: 'HEPSİ',
            products: products,
            productMeta: meta,
            initialNextCursor: page.nextCursor,
          ),
        ),
      );
    } catch (error) {
      debugPrint('[HomeShortcut] category load failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori yüklenemedi. Lütfen tekrar deneyin.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
