import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/station_model.dart';

class StationRepository {
  StationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<StationModel>> watchStations(String restaurantId) {
    return _client
        .from('stations')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map(
                (row) => StationModel.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList(growable: false),
        );
  }

  Future<List<StationModel>> fetchStations(String restaurantId) async {
    final rows = await _client
        .from('stations')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(StationModel.fromMap).toList(growable: false);
  }

  Future<StationModel> upsertStation({
    required String restaurantId,
    String? stationId,
    required String name,
    required String code,
    String? color,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      if (stationId != null && stationId.isNotEmpty) 'id': stationId,
      'restaurant_id': restaurantId,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'color': color,
      'is_active': isActive,
    };
    final row = await _client
        .from('stations')
        .upsert(payload)
        .select()
        .single();
    return StationModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> setStationActive(String stationId, bool isActive) async {
    await _client
        .from('stations')
        .update({'is_active': isActive})
        .eq('id', stationId);
  }
}
