import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/printer_model.dart';
import '../models/station_printer_model.dart';

class PrinterRepository {
  PrinterRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<PrinterModel>> watchPrinters(String restaurantId) {
    return _client
        .from('printers')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map(
                (row) => PrinterModel.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList(growable: false),
        );
  }

  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async {
    final rows = await _client
        .from('printers')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(PrinterModel.fromMap).toList(growable: false);
  }

  Future<PrinterModel> upsertPrinter({
    required String restaurantId,
    String? printerId,
    required String name,
    required String code,
    required String connectionType,
    String? ipAddress,
    int? port,
    String? deviceIdentifier,
    int paperWidthMm = 80,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      if (printerId != null && printerId.isNotEmpty) 'id': printerId,
      'restaurant_id': restaurantId,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'connection_type': connectionType,
      'ip_address': ipAddress,
      'port': port,
      'device_identifier': deviceIdentifier,
      'paper_width_mm': paperWidthMm,
      'is_active': isActive,
    };

    final row = await _client
        .from('printers')
        .upsert(payload)
        .select()
        .single();
    return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> setPrinterActive(String printerId, bool isActive) async {
    await _client
        .from('printers')
        .update({'is_active': isActive})
        .eq('id', printerId);
  }

  Future<List<StationPrinterModel>> fetchStationPrinterMappings(
    String restaurantId,
  ) async {
    final rows = await _client
        .from('station_printers')
        .select(
          'id, station_id, printer_id, is_primary, created_at, '
          'stations!inner(name, restaurant_id), '
          'printers!inner(name, code, restaurant_id)',
        )
        .eq('stations.restaurant_id', restaurantId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(StationPrinterModel.fromMap).toList(growable: false);
  }

  Future<void> assignPrinterToStation({
    required String stationId,
    required String printerId,
    bool isPrimary = true,
  }) async {
    if (isPrimary) {
      await _client
          .from('station_printers')
          .update({'is_primary': false})
          .eq('station_id', stationId);
    }

    await _client.from('station_printers').upsert({
      'station_id': stationId,
      'printer_id': printerId,
      'is_primary': isPrimary,
    }, onConflict: 'station_id,printer_id');
  }
}
