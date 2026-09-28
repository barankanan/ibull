import '../../vehicle/domain/vehicle_category.dart';

/// Canonical store vertical. [stores.category] is the display label
/// (`Yemek`, `Galerici`, `Elektronik`). [stores.business_type] is the legal
/// company type and must not be used for dashboard routing.
enum StoreVertical { restaurant, ecommerce, gallery, realEstate, unknown }

/// Food-business check. Empty/unknown categories return false so restaurant
/// modules are never shown by accident.
bool isSellerFoodStoreCategory(String? category) {
  final normalized = (category ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  const keywords = <String>[
    'yemek',
    'restoran',
    'restaurant',
    'food',
    'kafe',
    'cafe',
    'kafeterya',
    'lokanta',
    'kebap',
    'kebab',
    'döner',
    'doner',
    'pide',
    'lahmacun',
    'pastane',
    'pastahane',
    'fast food',
    'fastfood',
    'yiyecek',
    'içecek',
    'mutfak',
    'büfe',
    'bufe',
    'pizza',
    'burger',
    'sushi',
    'steakhouse',
    'et lokantası',
    'balık',
    'balik',
    'tatlı',
    'tatli',
    'kahve',
    'coffee',
    'çay',
    'cay',
  ];
  return keywords.any((kw) => normalized.contains(kw));
}

bool isSellerRealEstateCategory(String? category) {
  final normalized = (category ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's');
  if (normalized.isEmpty) return false;
  const keywords = <String>[
    'emlak',
    'real estate',
    'real_estate',
    'realestate',
    'gayrimenkul',
  ];
  return keywords.any(normalized.contains);
}

/// Maps the stored category label to a vertical. Gallery is checked before
/// food so a future label cannot fall through to restaurant.
StoreVertical resolveStoreVertical(String? category) {
  if (isSellerVehicleGalleryCategory(category)) {
    return StoreVertical.gallery;
  }
  if (isSellerRealEstateCategory(category)) {
    return StoreVertical.realEstate;
  }
  if (isSellerFoodStoreCategory(category)) {
    return StoreVertical.restaurant;
  }
  if ((category ?? '').trim().isEmpty) {
    return StoreVertical.unknown;
  }
  return StoreVertical.ecommerce;
}

String? storeRecordCategory(Map<String, dynamic> business) {
  for (final key in ['store_category', 'business_category', 'category']) {
    final value = business[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'other') return value;
  }
  return business['category']?.toString();
}

bool isGalleryStoreRecord(Map<String, dynamic> business) {
  return resolveStoreVertical(storeRecordCategory(business)) ==
      StoreVertical.gallery;
}

/// Owned-store signals used by seller login. Auth itself stays category-free.
class SellerLoginAccess {
  const SellerLoginAccess._();

  static bool ownedStoreMarksUserAsSeller(Map<String, dynamic>? store) {
    return store != null && store.isNotEmpty;
  }

  static bool ownedStoreIsApproved(Map<String, dynamic>? store) {
    if (store == null) return false;
    return store['isVerified'] == true || store['is_verified'] == true;
  }

  static Map<String, dynamic>? pendingSellerUserPatch({
    required String? currentRole,
    required bool Function(String? role) isAdminRole,
  }) {
    if (isAdminRole(currentRole)) return null;
    return {'role': 'seller', 'is_seller_approved': false};
  }
}

/// Seller/admin dashboard route. Category never changes the auth route:
/// every approved seller lands on `/seller`; the panel then shows modules
/// for [StoreVertical].
class SellerDashboardResolver {
  const SellerDashboardResolver._();

  static const String sellerRoute = '/seller';
  static const String adminRoute = '/admin';
  static const String customerRoute = '/home';

  static String routeFor({
    required String resolvedRoleName,
    StoreVertical vertical = StoreVertical.unknown,
  }) {
    switch (resolvedRoleName) {
      case 'admin':
        return adminRoute;
      case 'waiter':
      case 'seller':
        return sellerRoute;
      case 'user':
        return customerRoute;
      default:
        return 'unresolved';
    }
  }

  static bool usesRestaurantModules(StoreVertical vertical) {
    return vertical == StoreVertical.restaurant;
  }

  static bool usesGalleryModules(StoreVertical vertical) {
    return vertical == StoreVertical.gallery;
  }
}
