import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/coupon/domain/coupon_models.dart';
import '../../../features/mall/public/mall_public_repository.dart';
import '../../../features/vehicle/models/vehicle_listing.dart';
import '../../../models/db_category.dart';
import '../../../models/product_model.dart';
import '../../../services/supabase_service.dart';
import '../home_discovery_loader.dart';

class MobileNearbyStore {
  const MobileNearbyStore({
    required this.id,
    required this.name,
    this.category,
    this.logoUrl,
    this.contextLine,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String? category;
  final String? logoUrl;
  final String? contextLine;
  final double? distanceKm;
}

class MobileHomeMall {
  const MobileHomeMall({
    required this.id,
    required this.name,
    this.place,
    this.logoUrl,
    this.storeCount,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String? place;
  final String? logoUrl;
  final int? storeCount;
  final double? distanceKm;
}

class MobileHomeBundle {
  const MobileHomeBundle({
    this.categories = const [],
    this.categoryTree = const [],
    this.products = const [],
    this.stores = const [],
    this.malls = const [],
    this.vehicles = const [],
    this.deals = const [],
  });

  final List<DBCategory> categories;
  final List<CategoryWithSubcategories> categoryTree;
  final List<Product> products;
  final List<MobileNearbyStore> stores;
  final List<MobileHomeMall> malls;
  final List<VehicleListing> vehicles;
  final List<DailyDealProduct> deals;

  static const empty = MobileHomeBundle();
}

abstract class MobileHomeGateway {
  Future<MobileHomeBundle> load();
}

class LiveMobileHomeGateway implements MobileHomeGateway {
  LiveMobileHomeGateway({
    MallPublicRepository? malls,
  }) : _malls = malls ?? MallPublicRepository();

  final MallPublicRepository _malls;

  @override
  Future<MobileHomeBundle> load() async {
    final results = await Future.wait<Object?>([
      _categories(),
      _products(),
      _places(),
      _vehicles(),
    ]);
    final places = results[2]! as _Places;
    final tree = results[0]! as List<CategoryWithSubcategories>;
    return MobileHomeBundle(
      categories: [for (final node in tree) node.mainCategory],
      categoryTree: tree,
      products: results[1]! as List<Product>,
      stores: places.stores,
      malls: places.malls,
      vehicles: results[3]! as List<VehicleListing>,
      deals: const [],
    );
  }

  Future<List<CategoryWithSubcategories>> _categories() async {
    try {
      final tree = await SupabaseService.instance
          .getCategoriesWithSubsStrict()
          .timeout(const Duration(seconds: 8));
      return [
        for (final node in tree)
          if (node.mainCategory.isActive && node.mainCategory.name.trim().isNotEmpty) node,
      ];
    } catch (error) {
      debugPrint('[MobileHome] categories failed: $error');
      return const [];
    }
  }

  Future<List<Product>> _products() async {
    try {
      final report = await SupabaseService.instance
          .fetchInitialHomeProductsReport()
          .timeout(const Duration(seconds: 8));
      return [
        for (final product in report.products.take(8))
          Product.fromDBProduct(product),
      ];
    } catch (error) {
      debugPrint('[MobileHome] products failed: $error');
      return const [];
    }
  }

  Future<List<VehicleListing>> _vehicles() async {
    try {
      final listings = await HomeDiscoveryLoader.loadVehicles()
          .timeout(const Duration(seconds: 8));
      return listings.take(8).toList(growable: false);
    } catch (error) {
      debugPrint('[MobileHome] vehicles failed: $error');
      return const [];
    }
  }

  Future<_Places> _places() async {
    final position = await HomeDiscoveryLoader.resolvePosition();
    final directory = await _directory();
    final located = await _locatedStores();
    final pins = await _pins();
    final seen = <String>{};
    final stores = <MobileNearbyStore>[];
    for (final hit in directory) {
      if (hit.storeId.isEmpty || !seen.add(hit.storeId)) continue;
      final floor = hit.floorName.trim();
      final contextLine = floor.isEmpty ? hit.mallName : '${hit.mallName} • $floor';
      stores.add(MobileNearbyStore(
        id: hit.storeId,
        name: hit.storeName,
        category: hit.category,
        contextLine: contextLine,
        distanceKm: _km(position, hit.latitude, hit.longitude),
      ));
    }
    for (final row in located) {
      final id = row['seller_id']?.toString() ?? '';
      final name = row['business_name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty || !seen.add(id)) continue;
      final lat = (row['store_lat'] as num?)?.toDouble();
      final lng = (row['store_lng'] as num?)?.toDouble();
      stores.add(MobileNearbyStore(
        id: id,
        name: name,
        category: _text(row['category']),
        logoUrl: _text(row['logo_url']),
        distanceKm: _km(position, lat, lng),
      ));
    }
    stores.sort(_byDistance);
    final malls = [
      for (final pin in pins)
        MobileHomeMall(
          id: pin.id,
          name: pin.name,
          place: [pin.city, pin.district]
              .whereType<String>()
              .where((part) => part.trim().isNotEmpty)
              .join(' • '),
          logoUrl: pin.logoUrl,
          storeCount: pin.storeCount,
          distanceKm: _km(position, pin.latitude, pin.longitude),
        ),
    ]..sort((a, b) {
        final ad = a.distanceKm;
        final bd = b.distanceKm;
        if (ad == null && bd == null) return a.name.compareTo(b.name);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return _Places(
      stores: stores.take(12).toList(growable: false),
      malls: malls.take(6).toList(growable: false),
    );
  }

  Future<List<MallStoreSearchHit>> _directory() async {
    try {
      return await _malls.storeDirectory().timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[MobileHome] mall stores failed: $error');
      return const [];
    }
  }

  Future<List<MallMapPin>> _pins() async {
    try {
      return await _malls.activePins().timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[MobileHome] malls failed: $error');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _locatedStores() async {
    try {
      final rows = await Supabase.instance.client
          .from('stores')
          .select('seller_id, business_name, category, logo_url, store_lat, store_lng')
          .not('store_lat', 'is', null)
          .not('store_lng', 'is', null)
          .limit(24)
          .timeout(const Duration(seconds: 8));
      return [
        for (final row in rows as List)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    } catch (error) {
      debugPrint('[MobileHome] stores failed: $error');
      return const [];
    }
  }
}

class _Places {
  const _Places({required this.stores, required this.malls});

  final List<MobileNearbyStore> stores;
  final List<MobileHomeMall> malls;
}

int _byDistance(MobileNearbyStore a, MobileNearbyStore b) {
  final ad = a.distanceKm;
  final bd = b.distanceKm;
  if (ad == null && bd == null) return a.name.compareTo(b.name);
  if (ad == null) return 1;
  if (bd == null) return -1;
  return ad.compareTo(bd);
}

double? _km(Position? origin, double? lat, double? lng) {
  if (origin == null || lat == null || lng == null) return null;
  const r = 6371.0;
  final dLat = _rad(lat - origin.latitude);
  final dLon = _rad(lng - origin.longitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(origin.latitude)) * math.cos(_rad(lat)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180;

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String mobileDistanceLabel(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
