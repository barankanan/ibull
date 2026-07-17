import 'package:shared_preferences/shared_preferences.dart';

/// Persists dismiss state for the seller-panel desktop app promo banner.
class SellerDesktopAppBannerPrefs {
  SellerDesktopAppBannerPrefs._();

  static const String hideBannerKey = 'hide_seller_desktop_app_banner_v1';

  static Future<bool> isBannerHidden() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hideBannerKey) ?? false;
  }

  static Future<void> setBannerHidden(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hideBannerKey, hidden);
  }
}
