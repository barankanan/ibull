import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/seller/domain/store_vertical.dart';
import '../../models/sub_admin.dart';
import 'offline_panel_identity.dart';
import 'restaurant_local_cache_service.dart';

enum RestaurantCenterDenial {
  none,
  notDesktop,
  noVerifiedAccount,
  unknownBusiness,
  notRestaurant,
  noRestaurantRecord,
  notAuthorised,
}

/// Whether this account may run the restaurant printer center (local order
/// center + kitchen print service) for one business on this device.
class RestaurantCenterAccess {
  const RestaurantCenterAccess(this.denial);

  static const RestaurantCenterAccess granted =
      RestaurantCenterAccess(RestaurantCenterDenial.none);

  final RestaurantCenterDenial denial;

  bool get allowed => denial == RestaurantCenterDenial.none;

  String get message {
    switch (denial) {
      case RestaurantCenterDenial.none:
        return '';
      case RestaurantCenterDenial.notDesktop:
        return 'Yazıcı merkezi yalnızca macOS veya Windows bilgisayarda çalışır. Bu cihaz merkeze bağlanır.';
      case RestaurantCenterDenial.noVerifiedAccount:
        return 'Hesap bu cihazda doğrulanmadı. İnternete bağlıyken giriş yapıp tekrar deneyin.';
      case RestaurantCenterDenial.unknownBusiness:
        return 'İşletme türü henüz doğrulanamadı. Biraz sonra tekrar deneyin.';
      case RestaurantCenterDenial.notRestaurant:
        return 'Yazıcı merkezi yalnızca restoran işletmeleri içindir.';
      case RestaurantCenterDenial.noRestaurantRecord:
        return 'Restoran kaydı bulunamadı. Önce masa, alan veya yazıcı tanımlayın.';
      case RestaurantCenterDenial.notAuthorised:
        return 'Yazıcı merkezini başlatma yetkiniz yok. İşletme sahibi veya yazıcı ayarı yetkisi olan personel başlatabilir.';
    }
  }
}

/// The rule itself. Every condition must hold; a category label alone is not
/// enough. Unknown or missing facts refuse.
RestaurantCenterAccess decideRestaurantCenterAccess({
  required bool desktopHost,
  required bool accountVerified,
  required StoreVertical vertical,
  required bool hasRestaurantRecord,
  required bool isOwner,
  required Set<String> permissions,
}) {
  RestaurantCenterAccess deny(RestaurantCenterDenial reason) =>
      RestaurantCenterAccess(reason);
  if (!desktopHost) return deny(RestaurantCenterDenial.notDesktop);
  if (!accountVerified) return deny(RestaurantCenterDenial.noVerifiedAccount);
  if (vertical == StoreVertical.unknown) {
    return deny(RestaurantCenterDenial.unknownBusiness);
  }
  if (vertical != StoreVertical.restaurant) {
    return deny(RestaurantCenterDenial.notRestaurant);
  }
  if (!hasRestaurantRecord) return deny(RestaurantCenterDenial.noRestaurantRecord);
  if (!isOwner &&
      !permissions.contains(SellerPermission.managePrintSettings.name)) {
    return deny(RestaurantCenterDenial.notAuthorised);
  }
  return RestaurantCenterAccess.granted;
}

bool restaurantCenterDesktopHost({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return false;
  final target = platform ?? defaultTargetPlatform;
  return target == TargetPlatform.macOS || target == TargetPlatform.windows;
}

String? _signedInUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

/// Reads the facts from what the seller panel verified against the cloud and
/// sealed on this device (business type, owner or staff, permissions) and
/// from the restaurant's own saved records. It needs no network, so a center
/// the operator started can come back during an internet cut, and an account
/// this device never verified is refused.
Future<RestaurantCenterAccess> readRestaurantCenterAccess(
  String restaurantId, {
  String? Function() currentUserId = _signedInUserId,
  OfflinePanelIdentityStore? identityStore,
  RestaurantLocalCacheService? cacheService,
  TargetPlatform? platform,
  bool? isWeb,
}) async {
  final id = restaurantId.trim();
  final desktop = restaurantCenterDesktopHost(platform: platform, isWeb: isWeb);
  OfflinePanelIdentity? identity;
  var hasRecord = false;
  if (desktop && id.isNotEmpty) {
    try {
      final userId = currentUserId()?.trim() ?? '';
      if (userId.isNotEmpty) {
        final read = await (identityStore ?? OfflinePanelIdentityStore())
            .readChecked(userId);
        final found = read.identity;
        if (read.integrity == OfflineIdentityIntegrity.ok &&
            found != null &&
            found.ownerId.trim() == id) {
          identity = found;
        }
      }
      if (identity != null) {
        final saved = await (cacheService ?? RestaurantLocalCacheService())
            .read(id);
        hasRecord = saved != null &&
            (saved.tables.isNotEmpty ||
                saved.stations.isNotEmpty ||
                saved.printers.isNotEmpty);
      }
    } catch (error) {
      debugPrint('[RestaurantCenterAccess] read failed: $error');
      identity = null;
    }
  }
  return decideRestaurantCenterAccess(
    desktopHost: desktop,
    accountVerified: identity != null,
    vertical: resolveStoreVertical(identity?.storeCategory),
    hasRestaurantRecord: hasRecord,
    isOwner: identity?.isOwner ?? false,
    permissions: identity?.permissions ?? const <String>{},
  );
}

/// The business type this device verified against the cloud and sealed, for
/// the moments the cloud cannot be asked (app opened during an internet cut).
/// Null when this device never verified this account for this business.
Future<String?> readVerifiedStoreCategory(
  String restaurantId, {
  String? Function() currentUserId = _signedInUserId,
  OfflinePanelIdentityStore? identityStore,
}) async {
  final id = restaurantId.trim();
  if (id.isEmpty) return null;
  try {
    final userId = currentUserId()?.trim() ?? '';
    if (userId.isEmpty) return null;
    final read =
        await (identityStore ?? OfflinePanelIdentityStore()).readChecked(userId);
    final found = read.identity;
    if (read.integrity != OfflineIdentityIntegrity.ok ||
        found == null ||
        found.ownerId.trim() != id) {
      return null;
    }
    final category = found.storeCategory.trim();
    return category.isEmpty ? null : category;
  } catch (error) {
    debugPrint('[RestaurantCenterAccess] category read failed: $error');
    return null;
  }
}

/// Whether opening the seller screen may bring the print bridge up by itself.
/// A restaurant's bridge belongs to the printer center and always waits for
/// the operator's "Başlat"; a business whose type is not known yet is treated
/// the same. Other businesses keep the start-up they always had.
bool bridgeStartsWithSellerScreen(StoreVertical vertical) {
  switch (vertical) {
    case StoreVertical.restaurant:
    case StoreVertical.unknown:
      return false;
    case StoreVertical.ecommerce:
    case StoreVertical.gallery:
    case StoreVertical.realEstate:
      return true;
  }
}
