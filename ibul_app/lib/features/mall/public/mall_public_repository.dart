import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MallPublicFloor {
  const MallPublicFloor({required this.id, required this.name, this.levelNumber, this.planUrl});

  final String id;
  final String name;
  final int? levelNumber;
  final String? planUrl;

  factory MallPublicFloor.fromMap(Map<String, dynamic> map) => MallPublicFloor(
        id: map['id'].toString(),
        name: map['name']?.toString() ?? '',
        levelNumber: (map['level_number'] as num?)?.toInt(),
        planUrl: _text(map['plan_url']),
      );
}

class MallPublicStore {
  const MallPublicStore({
    required this.unitCode,
    required this.floorId,
    required this.storeName,
    this.storeId,
    this.category,
    this.logoUrl,
    this.mapX,
    this.mapY,
  });

  final String unitCode;
  final String floorId;
  final String storeName;
  final String? storeId;
  final String? category;
  final String? logoUrl;
  final double? mapX;
  final double? mapY;

  bool get isPlaced => mapX != null && mapY != null;

  factory MallPublicStore.fromMap(Map<String, dynamic> map) => MallPublicStore(
        unitCode: map['unit_code']?.toString() ?? '',
        floorId: map['floor_id']?.toString() ?? '',
        storeName: map['store_name']?.toString() ?? '',
        storeId: _text(map['store_id']),
        category: _text(map['category']),
        logoUrl: _text(map['logo_url']),
        mapX: (map['map_x'] as num?)?.toDouble(),
        mapY: (map['map_y'] as num?)?.toDouble(),
      );
}

class MallPublicCampaign {
  const MallPublicCampaign({required this.title, this.description, this.imageUrl, this.endsAt});

  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime? endsAt;

  factory MallPublicCampaign.fromMap(Map<String, dynamic> map) => MallPublicCampaign(
        title: map['title']?.toString() ?? '',
        description: _text(map['description']),
        imageUrl: _text(map['image_url']),
        endsAt: DateTime.tryParse(map['ends_at']?.toString() ?? '')?.toLocal(),
      );
}

/// What a customer sees for an active mall. `preview` is true only when a
/// member/admin opens a mall that is not published yet.
class MallPublicDetail {
  const MallPublicDetail({
    required this.id,
    required this.name,
    required this.preview,
    required this.floors,
    required this.stores,
    required this.campaigns,
    this.city,
    this.district,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
    this.logoUrl,
    this.coverUrl,
    this.latitude,
    this.longitude,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final bool preview;
  final List<MallPublicFloor> floors;
  final List<MallPublicStore> stores;
  final List<MallPublicCampaign> campaigns;
  final String? city;
  final String? district;
  final String? address;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? logoUrl;
  final String? coverUrl;
  final double? latitude;
  final double? longitude;
  final bool isVerified;

  String get locationLabel => [?district, ?city].join(', ');

  List<MallPublicStore> storesOn(String floorId) =>
      stores.where((store) => store.floorId == floorId).toList();

  factory MallPublicDetail.fromMap(Map<String, dynamic> map) {
    final mall = Map<String, dynamic>.from(map['mall'] as Map);
    List<Map<String, dynamic>> rows(String key) =>
        (map[key] as List? ?? const []).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    final floors = rows('floors').map(MallPublicFloor.fromMap).toList()
      ..sort((a, b) => (a.levelNumber ?? 1 << 20).compareTo(b.levelNumber ?? 1 << 20));
    return MallPublicDetail(
      id: mall['id'].toString(),
      name: mall['name']?.toString() ?? '',
      preview: map['preview'] == true,
      floors: floors,
      stores: uniqueMallStores(rows('stores').map(MallPublicStore.fromMap)),
      campaigns: rows('campaigns').map(MallPublicCampaign.fromMap).toList(),
      city: _text(mall['city']),
      district: _text(mall['district']),
      address: _text(mall['address_text']),
      phone: _text(mall['phone']),
      website: _text(mall['website']),
      openingHours: _text(mall['opening_hours']),
      logoUrl: _text(mall['logo_url']),
      coverUrl: _text(mall['cover_url']),
      latitude: (mall['latitude'] as num?)?.toDouble(),
      longitude: (mall['longitude'] as num?)?.toDouble(),
      isVerified: mall['is_verified'] == true,
    );
  }
}

/// Active malls with coordinates, for the customer map.
class MallMapPin {
  const MallMapPin({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.city,
    this.district,
    this.logoUrl,
    this.openingHours,
    this.storeCount,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? city;
  final String? district;
  final String? logoUrl;
  final String? openingHours;

  /// Approved stores; null when only the fallback query was available.
  final int? storeCount;

  String get locationLabel => [?city, ?district].join(' / ');

  static MallMapPin? fromMap(Map<String, dynamic> row) {
    final lat = row['latitude'];
    final lng = row['longitude'];
    if (lat is! num || lng is! num) return null;
    return MallMapPin(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? '',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      city: _text(row['city']),
      district: _text(row['district']),
      logoUrl: _text(row['logo_url']),
      openingHours: _text(row['opening_hours']),
      storeCount: row['store_count'] is num ? (row['store_count'] as num).toInt() : null,
    );
  }
}

class MallPublicRepository {
  MallPublicRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  /// Null when the mall does not exist or is not published (and the caller is
  /// not one of its members).
  Future<MallPublicDetail?> detail(String mallId) async {
    final row = await _db.rpc('public_mall_detail', params: {'p_mall_id': mallId});
    if (row is! Map) return null;
    return MallPublicDetail.fromMap(Map<String, dynamic>.from(row));
  }

  /// Active malls with a location; `public_mall_map_pins` adds the store count.
  Future<List<MallMapPin>> activePins() async {
    List<dynamic> rows;
    try {
      final result = await _db.rpc('public_mall_map_pins');
      rows = result is List ? result : const [];
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      debugPrint('[MALL][MAP] public_mall_map_pins missing, falling back to malls');
      rows = await _db
          .from('malls')
          .select('id,name,city,district,logo_url,opening_hours,latitude,longitude')
          .eq('status', 'active')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(500);
    }
    final pins = [
      for (final row in rows)
        if (row is Map) ?MallMapPin.fromMap(Map<String, dynamic>.from(row)),
    ];
    debugPrint('[MALL][MAP] active pins=${pins.length}');
    return pins;
  }

  /// Approved mall-contained stores for search / distance. Empty when the RPC
  /// is not on this database yet.
  Future<List<MallStoreSearchHit>> storeDirectory() async {
    try {
      final result = await _db.rpc('public_mall_store_directory');
      if (result is! List) return const [];
      return [
        for (final row in result)
          if (row is Map) ?MallStoreSearchHit.fromMap(Map<String, dynamic>.from(row)),
      ];
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      debugPrint('[MALL][MAP] public_mall_store_directory missing');
      return const [];
    }
  }

  Future<Set<String>> hiddenStoreIds() async {
    try {
      final result = await _db.rpc('public_map_hidden_store_ids');
      if (result is! List) return const {};
      return {for (final id in result) id.toString()};
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      debugPrint('[MALL][MAP] public_map_hidden_store_ids missing');
      return const {};
    }
  }

}

/// One approved store inside an active mall. Distance uses the mall pin.
class MallStoreSearchHit {
  const MallStoreSearchHit({
    required this.storeId,
    required this.storeName,
    required this.mallId,
    required this.mallName,
    required this.latitude,
    required this.longitude,
    required this.floorName,
    required this.unitCode,
    this.floorId,
    this.city,
    this.district,
    this.category,
  });

  final String storeId;
  final String storeName;
  final String mallId;
  final String mallName;
  final double latitude;
  final double longitude;
  final String floorName;
  final String unitCode;
  final String? floorId;
  final String? city;
  final String? district;
  final String? category;

  String get placeLabel => '$mallName • $floorName • $unitCode';
  String get locationLabel => [?city, ?district].join(' / ');

  static MallStoreSearchHit? fromMap(Map<String, dynamic> row) {
    final lat = row['latitude'];
    final lng = row['longitude'];
    if (lat is! num || lng is! num) return null;
    return MallStoreSearchHit(
      storeId: row['store_id']?.toString() ?? '',
      storeName: row['store_name']?.toString() ?? '',
      mallId: row['mall_id']?.toString() ?? '',
      mallName: row['mall_name']?.toString() ?? '',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      floorName: row['floor_name']?.toString() ?? '',
      unitCode: row['unit_code']?.toString() ?? '',
      floorId: _text(row['floor_id']),
      city: _text(row['city']),
      district: _text(row['district']),
      category: _text(row['category']),
    );
  }
}

/// Current occupancy only: one row per physical branch (or store) + unit.
List<MallPublicStore> uniqueMallStores(Iterable<MallPublicStore> stores) {
  final seen = <String>{};
  return [
    for (final store in stores)
      if (seen.add('${store.storeId ?? store.storeName}|${store.floorId}|${store.unitCode}')) store,
  ];
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
