import 'package:flutter/material.dart';

import '../../app/ibul_router.dart';
import '../../app/marketplace_paths.dart';
import '../../app/site_info_routes.dart';
import '../../features/ihiz/send/ihiz_package_send_page.dart';
import '../coming_soon/coming_soon_catalog.dart';

/// Hesap menüsündeki hizmet kısayolları — canlı rota veya Yakında rafı.
abstract final class AccountMenuNavigation {
  static const becomeSellerPath = '/become-seller';
  static const sellerTitle = 'Satıcı Ol';
  static const sellerSubtitle = "İBUL'da mağaza açın ve ürünlerinizi satın.";
  static const mallTitle = 'AVM\'nizi İBUL\'a Ekleyin';
  static const mallHubTitle = 'AVM İşlemleri';

  static Future<void> openPremium(BuildContext context) {
    return ComingSoonCatalog.open(context, ComingSoonCatalog.premium);
  }

  static Future<void> openRepair(BuildContext context) {
    return ComingSoonCatalog.open(context, ComingSoonCatalog.repair);
  }

  static Future<void> openAssembly(BuildContext context) {
    return ComingSoonCatalog.open(context, ComingSoonCatalog.assembly);
  }

  static Future<void> openAppFeedback(BuildContext context) {
    return ComingSoonCatalog.open(context, ComingSoonCatalog.appFeedback);
  }

  static Future<void> openShelf(BuildContext context) {
    return ComingSoonCatalog.openShelf(context);
  }

  static Future<void> openNamed(BuildContext context, String routeName) {
    return IbulRouter.push(context, routeName);
  }

  static Future<void> openFastSend(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const IhizPackageSendPage(),
      ),
    );
  }

  static Future<void> openStoreApply(BuildContext context) {
    return openNamed(context, becomeSellerPath);
  }

  static Future<void> openMallApplication(BuildContext context) {
    return openNamed(context, MarketplacePaths.mallApplication);
  }

  static Future<void> openHelp(BuildContext context) {
    return openNamed(context, SiteInfoRoutes.faq);
  }
}
