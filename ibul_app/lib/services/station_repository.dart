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
    final rows = await _client
        .from('stations')
        .update({'is_active': isActive})
        .eq('id', stationId)
        .select('id');
    // A policy that filters the row out answers with no error and no row.
    if ((rows as List).isEmpty) {
      throw const PostgrestException(
        message: 'Alan güncellenemedi: bu hesabın yetkisi yok.',
        code: '42501',
      );
    }
  }
}

/// What the operator is told when a preparation-area save is rejected. The
/// raw exception text is kept in the message so a schema problem is
/// recognisable instead of looking like "nothing happened".
String stationSaveErrorMessage(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case 'PGRST204':
        return 'Hazırlama alanı kaydedilemedi: veritabanında gerekli sütun '
            'yok (${error.message}). Şema güncellemesi gerekli.';
      case '23505':
        return 'Bu kod bu restoranda zaten kullanılıyor. Farklı bir kod girin.';
      case '42501':
        return 'Hazırlama alanı kaydedilemedi: bu işlem için yetkiniz yok.';
      default:
        return 'Hazırlama alanı kaydedilemedi: ${error.message}';
    }
  }
  return 'Hazırlama alanı kaydedilemedi: $error';
}

/// Shown instead of "Kayıtlı hazırlama alanı bulunamadı" when loading itself
/// failed, so a broken stream is not mistaken for an empty list.
String stationLoadErrorMessage(Object error) {
  final detail = error is PostgrestException ? error.message : '$error';
  return 'Hazırlama alanları yüklenemedi: $detail';
}
