import 'seller_panel_module_helpers.dart';

/// True when the store category qualifies for restaurant printer features.
bool canUseRestaurantPrinterSystem(String? category) {
  return isSellerFoodStoreCategory(category);
}

/// Printer auto-start / bridge scan should wait until category is known.
bool shouldDeferRestaurantPrinterUntilCategoryResolved(String? category) {
  return (category ?? '').trim().isEmpty;
}

const String restaurantPrinterIneligibleMessage =
    'Bu özellik yalnızca yemek/restoran işletmeleri içindir.';

const String restaurantPrinterCategoryPendingMessage =
    'Mağaza kategorisi yükleniyor…';
