import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/simple_memory_ttl_cache.dart';
import '../../features/vehicle/models/vehicle_commerce.dart';
import '../../features/vehicle/models/vehicle_listing.dart';
import '../../features/vehicle/services/vehicle_service.dart';
import '../../models/db_product.dart';
import '../../services/location_access_service.dart';
import 'home_discovery_resolver.dart';

class HomeDiscoverySnapshot {
  const HomeDiscoverySnapshot({
    required this.nearby,
    required this.vehicles,
  });

  final List<HomeDiscoveryItem> nearby;
  final List<VehicleListing> vehicles;

  static const empty = HomeDiscoverySnapshot(nearby: [], vehicles: []);
}

abstract final class HomePerfLog {
  static void nearby(String event, [int? ms]) {
    debugPrint(
      '[HomePerf][nearby] $event${ms == null ? '' : ' ${ms}ms'}',
    );
  }

  static void vehicles(String event, [int? ms]) {
    debugPrint(
      '[HomePerf][vehicles] $event${ms == null ? '' : ' ${ms}ms'}',
    );
  }
}

/// Loads home nearby + vehicle rails independently. Do not sequence GPS behind
/// the public vehicle query (or vice versa).
abstract final class HomeDiscoveryLoader {
  static const _vehicleTtl = Duration(seconds: 45);
  static const _distanceTtl = Duration(seconds: 60);

  static final SimpleMemoryTtlCache<List<VehicleListing>> _vehicleCache =
      SimpleMemoryTtlCache(defaultTtl: _vehicleTtl);
  static final SimpleMemoryTtlCache<Map<String, double>> _distanceCache =
      SimpleMemoryTtlCache(defaultTtl: _distanceTtl);
  static final SimpleMemoryTtlCache<Position> _positionCache =
      SimpleMemoryTtlCache(defaultTtl: _distanceTtl);

  static Future<List<VehicleListing>>? _vehiclesInFlight;
  static Future<Position?>? _positionInFlight;
  static final Map<String, double> _distanceMem = {};

  @visibleForTesting
  static Future<List<VehicleListing>> Function()? debugVehiclesQuery;
  @visibleForTesting
  static Future<Position?> Function()? debugPositionQuery;
  @visibleForTesting
  static Future<Map<String, double>> Function(Set<String> sellerIds, Position position)?
      debugStoreDistancesQuery;

  static void invalidateVehicles() {
    _vehicleCache.clear();
    _vehiclesInFlight = null;
  }

  static void invalidateLocation() {
    _positionCache.clear();
    _distanceCache.clear();
    _distanceMem.clear();
    _positionInFlight = null;
  }

  @visibleForTesting
  static void resetForTest() {
    invalidateVehicles();
    invalidateLocation();
    debugVehiclesQuery = null;
    debugPositionQuery = null;
    debugStoreDistancesQuery = null;
  }

  static Future<List<VehicleListing>> loadVehicles() {
    final cached = _vehicleCache.read('public');
    if (cached != null) {
      HomePerfLog.vehicles('query_ready', 0);
      return Future.value(
        HomeDiscoveryResolver.publicVehicles(cached),
      );
    }
    return _vehiclesInFlight ??= _loadVehiclesBody().whenComplete(() {
      _vehiclesInFlight = null;
    });
  }

  static Future<List<VehicleListing>> _loadVehiclesBody() async {
    final started = DateTime.now();
    HomePerfLog.vehicles('start');
    try {
      final query = debugVehiclesQuery ?? _publicVehicles;
      final vehicles = await query().timeout(const Duration(seconds: 8));
      _vehicleCache.write('public', vehicles);
      HomePerfLog.vehicles(
        'query_ready',
        DateTime.now().difference(started).inMilliseconds,
      );
      return HomeDiscoveryResolver.publicVehicles(vehicles);
    } catch (e, st) { print("Error loading vehicles: $e"); print(st);
      HomePerfLog.vehicles(
        'query_ready',
        DateTime.now().difference(started).inMilliseconds,
      );
      return const [];
    }
  }

  static Future<Position?> resolvePosition() {
    final cached = _positionCache.read('current');
    if (cached != null) return Future.value(cached);
    return _positionInFlight ??= _resolvePositionBody().whenComplete(() {
      _positionInFlight = null;
    });
  }

  static Future<Position?> _resolvePositionBody() async {
    final started = DateTime.now();
    HomePerfLog.nearby('start');
    try {
      final position = debugPositionQuery != null
          ? await debugPositionQuery!()
          : await LocationAccessService.instance.getBestAvailablePosition().timeout(const Duration(seconds: 4));
      if (position != null) {
        _positionCache.write('current', position);
      }
      HomePerfLog.nearby(
        'location_ready',
        DateTime.now().difference(started).inMilliseconds,
      );
      return position;
    } catch (e, st) { print("Error loading vehicles: $e"); print(st);
      HomePerfLog.nearby(
        'location_ready',
        DateTime.now().difference(started).inMilliseconds,
      );
      return null;
    }
  }

  static Future<Map<String, double>> distancesFor({
    required Set<String> sellerIds,
    required Position position,
  }) async {
    final started = DateTime.now();
    final ids = sellerIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      HomePerfLog.nearby('query_ready', 0);
      return const {};
    }
    final missing = ids.where((id) => !_distanceMem.containsKey(id)).toSet();
    if (missing.isEmpty) {
      HomePerfLog.nearby('query_ready', 0);
      return {for (final id in ids) id: _distanceMem[id]!};
    }
    final cacheKey =
        '${position.latitude.toStringAsFixed(3)},${position.longitude.toStringAsFixed(3)}:${(missing.toList()..sort()).join(',')}';
    final cached = _distanceCache.read(cacheKey);
    if (cached != null) {
      _distanceMem.addAll(cached);
      HomePerfLog.nearby('query_ready', 0);
      return {for (final id in ids) if (_distanceMem[id] != null) id: _distanceMem[id]!};
    }
    try {
      final query = debugStoreDistancesQuery ?? _sellerDistances;
      final fresh = await query(missing, position);
      _distanceMem.addAll(fresh);
      _distanceCache.write(cacheKey, Map<String, double>.from(fresh));
      HomePerfLog.nearby(
        'query_ready',
        DateTime.now().difference(started).inMilliseconds,
      );
      return {for (final id in ids) if (_distanceMem[id] != null) id: _distanceMem[id]!};
    } catch (e, st) { print("Error loading vehicles: $e"); print(st);
      HomePerfLog.nearby(
        'query_ready',
        DateTime.now().difference(started).inMilliseconds,
      );
      return {for (final id in ids) if (_distanceMem[id] != null) id: _distanceMem[id]!};
    }
  }

  static List<HomeDiscoveryItem> nearbyItems({
    required List<DBProduct> products,
    required List<VehicleListing> vehicles,
    required Map<String, double> distanceBySeller,
  }) {
    final nearbyProducts = products
        .where((p) => p.sellerId != null && p.sellerId!.isNotEmpty)
        .toList(growable: false);
    return HomeDiscoveryResolver.nearby(
      products: nearbyProducts.isEmpty ? products : nearbyProducts,
      vehicles: vehicles,
      distanceBySeller: distanceBySeller,
    );
  }

  static Future<List<VehicleListing>> _publicVehicles() async {
    try {
      return await VehicleService.instance.listings.getHomeListings(
        limit: 24,
      );
    } catch (e, st) { print("Error loading vehicles: $e"); print(st);
      return const [];
    }
  }

  static Future<Map<String, double>> _sellerDistances(
    Set<String> sellerIds,
    Position position,
  ) async {
    if (sellerIds.isEmpty) return const {};
    final ids = sellerIds.take(80).toList(growable: false);
    final rows = await Supabase.instance.client
        .from('stores')
        .select('seller_id, store_lat, store_lng')
        .inFilter('seller_id', ids)
        .not('store_lat', 'is', null)
        .not('store_lng', 'is', null);
    final out = <String, double>{};
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['seller_id']?.toString() ?? '';
      final lat = (row['store_lat'] as num?)?.toDouble();
      final lng = (row['store_lng'] as num?)?.toDouble();
      if (id.isEmpty || lat == null || lng == null) continue;
      out[id] = _km(position.latitude, position.longitude, lat, lng);
    }
    return out;
  }

  static double _km(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
