import 'package:shared_preferences/shared_preferences.dart';

/// Vitrin rozeti seçimi — Faz 1 local kalıcılık.
/// TODO: Supabase `seller_featured_badges` tablosu ile senkronize et.
class SellerFeaturedBadgeRepository {
  SellerFeaturedBadgeRepository._();
  static final SellerFeaturedBadgeRepository instance =
      SellerFeaturedBadgeRepository._();

  static const int maxProfileBadges = 4;
  static const int maxMapPopupBadges = 2;
  static const String _prefKeyPrefix = 'seller_featured_badges_';

  Future<List<String>> loadFeaturedBadgeIds(String sellerId) async {
    final normalized = sellerId.trim();
    if (normalized.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_prefKeyPrefix$normalized') ?? const [];
  }

  Future<void> saveFeaturedBadgeIds(
    String sellerId,
    List<String> badgeIds,
  ) async {
    final normalized = sellerId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_prefKeyPrefix$normalized',
      badgeIds.take(maxProfileBadges).toList(growable: false),
    );
    // TODO: Supabase RPC / seller_featured_badges upsert
  }
}
