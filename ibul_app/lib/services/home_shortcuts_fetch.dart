import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/runtime_config.dart';

/// Mobil ana sayfa kısayol ayarları (`app_categories`): başlık, görsel,
/// aktiflik ve sıra. Hedefler `HomeMobileShortcutRegistry` ile sınırlıdır.
class HomeShortcutsFetch {
  HomeShortcutsFetch._();

  static const Duration requestTimeout = Duration(seconds: 3);
  static List<Map<String, dynamic>>? _cache;
  static Future<List<Map<String, dynamic>>>? _inFlight;

  static List<Map<String, dynamic>> readCachedSync() => _cache ?? const [];

  static void invalidate() {
    _cache = null;
    _inFlight = null;
  }

  static Future<List<Map<String, dynamic>>> fetch() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  static Future<List<Map<String, dynamic>>> _load() async {
    if (!AppRuntimeConfig.hasSupabaseConfig) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('app_categories')
          .select()
          .timeout(requestTimeout);
      final list = sortShortcutRows(
        (rows as List).whereType<Map>().map(Map<String, dynamic>.from),
      );
      _cache = list;
      return list;
    } catch (error) {
      debugPrint('[HomeShortcutsFetch] load failed: $error');
      return const [];
    }
  }

  /// `sort_order` varsa ona, yoksa `id` sırasına göre sıralar.
  static List<Map<String, dynamic>> sortShortcutRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final list = rows.toList();
    int orderOf(Map<String, dynamic> row) =>
        (row['sort_order'] as num?)?.toInt() ??
        (row['id'] as num?)?.toInt() ??
        1 << 30;
    list.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    return list;
  }
}
