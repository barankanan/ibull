import 'package:shared_preferences/shared_preferences.dart';

/// Garson anında baskı (RPC öncesi) için yerel günlük mutfak sıra numarası.
class KitchenDailyOrderNoStore {
  KitchenDailyOrderNoStore._();

  static String _key(String restaurantId, String dayKey) =>
      'kitchen_daily_order_no_v1_${restaurantId.trim()}_$dayKey';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<int> nextForRestaurant(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return 1;
    final prefs = await SharedPreferences.getInstance();
    final day = _todayKey();
    final key = _key(id, day);
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    return next;
  }
}
