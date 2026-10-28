import 'package:flutter/foundation.dart';

import '../../../models/product_model.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/text_normalizer.dart';
import 'mobile_home_models.dart';

const mobileStorePreviewLimit = 8;
const mobileStorePreviewStoreCap = 12;
const mobileStorePreviewThumb = 56.0;
const mobileStorePreviewGap = 6.0;
const mobileStorePreviewBadge = 36.0;

class MobileStorePreviewFit {
  const MobileStorePreviewFit({required this.visible, required this.hidden});

  final int visible;
  final int hidden;

  static MobileStorePreviewFit measure({
    required double innerWidth,
    required int available,
    double thumb = mobileStorePreviewThumb,
    double gap = mobileStorePreviewGap,
    double badge = mobileStorePreviewBadge,
  }) {
    if (available <= 0 || innerWidth <= thumb) {
      return const MobileStorePreviewFit(visible: 0, hidden: 0);
    }
    final all = ((innerWidth + gap) / (thumb + gap)).floor();
    if (all >= available) {
      return MobileStorePreviewFit(visible: available, hidden: 0);
    }
    final room = innerWidth - badge - gap;
    final shown = room < thumb
        ? 1
        : ((room + gap) / (thumb + gap)).floor().clamp(1, available - 1);
    return MobileStorePreviewFit(visible: shown, hidden: available - shown);
  }
}

typedef MobileStorePreviewFetch = Future<Map<String, List<Product>>> Function(
  List<MobileNearbyStore> stores,
);

class MobileStorePreviewLoader {
  MobileStorePreviewLoader({MobileStorePreviewFetch? fetch}) : _fetch = fetch;

  final MobileStorePreviewFetch? _fetch;
  Future<Map<String, List<Product>>>? _flight;
  String? _flightKey;

  static final instance = MobileStorePreviewLoader();

  Future<Map<String, List<Product>>> load(List<MobileNearbyStore> stores) {
    final visible = stores
        .where((store) => store.id.trim().isNotEmpty || store.name.trim().isNotEmpty)
        .take(mobileStorePreviewStoreCap)
        .toList(growable: false);
    if (visible.isEmpty) return Future.value(const {});
    final key = visible.map((store) => '${store.id}|${store.name}').join(',');
    final current = _flight;
    if (current != null && _flightKey == key) return current;
    _flightKey = key;
    final future = _run(visible);
    _flight = future;
    return future.whenComplete(() {
      if (identical(_flight, future)) _flight = null;
    });
  }

  Future<Map<String, List<Product>>> _run(List<MobileNearbyStore> stores) async {
    MobileHomeQueryLog.storePreviewQueries++;
    final fetch = _fetch;
    if (fetch != null) return fetch(stores);
    return _fetchFromCatalog(stores);
  }

  static Future<Map<String, List<Product>>> _fetchFromCatalog(
    List<MobileNearbyStore> stores,
  ) async {
    try {
      final sellerIds = [
        for (final store in stores)
          if (store.id.trim().isNotEmpty) store.id.trim(),
      ];
      final storeNames = [
        for (final store in stores)
          if (store.name.trim().isNotEmpty) store.name.trim(),
      ];
      final rows = await SupabaseService.instance
          .getProductsPreviewByStores(
            sellerIds: sellerIds,
            storeNames: storeNames,
            perStoreLimit: mobileStorePreviewLimit,
          )
          .timeout(const Duration(seconds: 8));
      final products = <String, List<Product>>{};
      for (final store in stores) {
        final byId = rows[store.id] ?? const [];
        final byName = rows[store.name] ??
            rows[TextNormalizer.normalize(store.name)] ??
            const [];
        final chosen = byId.isNotEmpty ? byId : byName;
        products[store.id] = [
          for (final product in chosen.take(mobileStorePreviewLimit))
            Product.fromDBProduct(product),
        ];
      }
      return products;
    } catch (error) {
      debugPrint('[MobileHome] store previews failed: $error');
      return const {};
    }
  }
}
