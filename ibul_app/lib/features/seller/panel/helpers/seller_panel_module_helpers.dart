import 'package:flutter/material.dart';

import '../models/seller_panel_types.dart';

bool isSellerFoodStoreCategory(String? category) {
  final normalized = (category ?? '').trim().toLowerCase();
  return normalized.contains('yemek') ||
      normalized.contains('restoran') ||
      normalized.contains('restaurant') ||
      normalized.contains('food');
}

List<SellerModule> visibleSellerModules(
  String? storeCategory, {
  bool garsonOnly = false,
}) {
  if (garsonOnly) {
    return <SellerModule>[SellerModule.garson];
  }
  return <SellerModule>[
    SellerModule.dashboard,
    SellerModule.products,
    SellerModule.collections,
    SellerModule.orders,
    if (isSellerFoodStoreCategory(storeCategory)) SellerModule.garson,
    if (isSellerFoodStoreCategory(storeCategory)) SellerModule.system,
    SellerModule.store,
    SellerModule.team,
    SellerModule.campaigns,
    SellerModule.finance,
    SellerModule.reviews,
    SellerModule.support,
  ];
}

String sellerModuleLabel(SellerModule module) {
  switch (module) {
    case SellerModule.dashboard:
      return 'Genel Bakış';
    case SellerModule.products:
      return 'Ürünlerim';
    case SellerModule.collections:
      return 'Listeler';
    case SellerModule.orders:
      return 'Siparişler';
    case SellerModule.garson:
      return 'Garson';
    case SellerModule.system:
      return 'Sistem';
    case SellerModule.store:
      return 'Mağaza Profili';
    case SellerModule.team:
      return 'Alt Yöneticiler';
    case SellerModule.campaigns:
      return 'Reklam';
    case SellerModule.finance:
      return 'Finans';
    case SellerModule.reviews:
      return 'Yorumlar, Değerlendirmeler, Şikayetler';
    case SellerModule.support:
      return 'Destek';
  }
}

/// Profil yenilemesinde sekme sıfırlanmasın; yalnızca görünür olmayan modüllerde dashboard.
SellerModule resolveSellerModuleAfterProfileReload({
  required SellerModule currentModule,
  required String? storeCategory,
  required bool garsonOnly,
}) {
  if (garsonOnly) return SellerModule.garson;
  if (isSellerFoodStoreCategory(storeCategory)) return currentModule;
  if (currentModule != SellerModule.garson &&
      currentModule != SellerModule.system) {
    return currentModule;
  }
  final visible = visibleSellerModules(storeCategory, garsonOnly: false);
  if (visible.contains(currentModule)) return currentModule;
  return SellerModule.dashboard;
}

IconData sellerModuleIcon(SellerModule module) {
  switch (module) {
    case SellerModule.dashboard:
      return Icons.dashboard_outlined;
    case SellerModule.products:
      return Icons.inventory_2_outlined;
    case SellerModule.collections:
      return Icons.collections_bookmark_outlined;
    case SellerModule.orders:
      return Icons.shopping_bag_outlined;
    case SellerModule.garson:
      return Icons.table_restaurant_outlined;
    case SellerModule.system:
      return Icons.settings_suggest_outlined;
    case SellerModule.store:
      return Icons.store_outlined;
    case SellerModule.team:
      return Icons.people_outline;
    case SellerModule.campaigns:
      return Icons.ads_click_outlined;
    case SellerModule.finance:
      return Icons.account_balance_wallet_outlined;
    case SellerModule.reviews:
      return Icons.rate_review_outlined;
    case SellerModule.support:
      return Icons.support_agent_outlined;
  }
}
