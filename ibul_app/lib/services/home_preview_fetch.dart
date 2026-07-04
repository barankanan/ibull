import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/runtime_config.dart';
import '../models/home_product_preview.dart';
import '../utils/product_visibility_helper.dart';

/// Minimal home preview fetch — avoids importing full [SupabaseService].
class HomePreviewFetch {
  HomePreviewFetch._();

  static const _statusFilter = ['Aktif', 'active'];

  static const List<String> _selectCandidates = [
    'id, name, brand, image_url, price, discount_price, status, '
        'approval_status, admin_approval_status, stores(business_name)',
    'id, name, brand, image_url, price, discount_price, status, '
        'approval_status, admin_approval_status',
    'id, name, image_url, price, discount_price, status, '
        'approval_status, admin_approval_status, stores(business_name)',
    'id, name, image_url, price, discount_price, status, '
        'approval_status, admin_approval_status',
  ];

  static const Duration requestTimeout = Duration(seconds: 5);

  static Future<HomePreviewFetchResult> fetch({int limit = 10}) async {
    if (!AppRuntimeConfig.hasSupabaseConfig) {
      return const HomePreviewFetchResult(
        previews: [],
        error: 'Supabase config eksik',
        detail: 'IBUL_SUPABASE_URL / IBUL_SUPABASE_ANON_KEY tanımlı değil',
        queryUsed: 'products (skipped — config missing)',
      );
    }

    final client = Supabase.instance.client;
    final started = DateTime.now().millisecondsSinceEpoch;
    final fetchLimit = (limit * 3).clamp(limit, 36);
    Object? lastError;
    String? lastSelect;

    for (final select in _selectCandidates) {
      lastSelect = select;
      try {
        final rows = await client
            .from('products')
            .select(select)
            .inFilter('status', _statusFilter)
            .order('created_at', ascending: false)
            .limit(fetchLimit)
            .timeout(requestTimeout);
        final list = (rows as List).cast<Map<String, dynamic>>();
        final visible = ProductVisibilityHelper.filterPublicProductMaps(list);
        final previews = visible
            .map(_mapRow)
            .whereType<HomeProductPreview>()
            .take(limit)
            .toList(growable: false);
        return HomePreviewFetchResult(
          previews: previews,
          rawCount: list.length,
          filteredCount: visible.length,
          ms: DateTime.now().millisecondsSinceEpoch - started,
          queryUsed:
              'products.select(...).inFilter(status,$_statusFilter).limit($fetchLimit)',
          selectFields: select,
          error: previews.isEmpty && visible.isEmpty && list.isNotEmpty
              ? 'Ürünler filtrelendi (onay durumu)'
              : previews.isEmpty && list.isEmpty
                  ? null
                  : previews.isEmpty
                      ? 'Görünür ürün bulunamadı'
                      : null,
        );
      } catch (error) {
        lastError = error;
        continue;
      }
    }

    return HomePreviewFetchResult(
      previews: const [],
      ms: DateTime.now().millisecondsSinceEpoch - started,
      error: 'Ürünler yüklenemedi',
      detail: lastError?.toString(),
      queryUsed:
          'products.select(...).inFilter(status,$_statusFilter).limit($fetchLimit)',
      selectFields: lastSelect,
    );
  }

  static HomeProductPreview? _mapRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || name == null || name.isEmpty) return null;

    final image = row['image_url']?.toString() ?? '';
    final price = _parseAmount(row['price']);
    final discount = _parseAmount(row['discount_price']);
    String? storeName;
    final stores = row['stores'];
    if (stores is Map) {
      storeName = stores['business_name']?.toString();
    }
    final brand = row['brand']?.toString();

    return HomeProductPreview(
      id: id,
      name: name,
      imageUrl: image,
      price: price,
      discountPrice:
          discount > 0 && discount < price ? discount : null,
      storeName: storeName,
      brand: brand != null && brand.isNotEmpty ? brand : null,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0;
    final raw = value.toString().replaceAll(' TL', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }
}

class HomePreviewFetchResult {
  const HomePreviewFetchResult({
    required this.previews,
    this.rawCount = 0,
    this.filteredCount = 0,
    this.ms = 0,
    this.error,
    this.detail,
    this.queryUsed,
    this.selectFields,
  });

  final List<HomeProductPreview> previews;
  final int rawCount;
  final int filteredCount;
  final int ms;
  final String? error;
  final String? detail;
  final String? queryUsed;
  final String? selectFields;
}
