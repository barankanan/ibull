import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/printer_model.dart';
import '../models/station_printer_model.dart';
import 'desktop_print_ports.dart';

class PrinterRepository implements PrinterRepositoryPort {
  PrinterRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<PrinterModel>> watchPrinters(String restaurantId) {
    final backendPath =
        'printers?restaurant_id=eq.$restaurantId&order=created_at.asc';
    _logPrinterSettings(
      'Fetch',
      'source=watchPrinters sellerId=$restaurantId storeId=- backendPath=$backendPath',
    );
    return _client
        .from('printers')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true)
        .map((rows) {
          final printers = rows
              .map(
                (row) => PrinterModel.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList(growable: false);
          _logPrinterSettings(
            'Fetch',
            'source=watchPrintersStream sellerId=$restaurantId storeId=- '
                'backendPath=$backendPath printerCount=${printers.length}',
          );
          return printers;
        })
        .handleError((Object error, StackTrace stackTrace) {
          _logPrinterSettings(
            'Error',
            'source=watchPrintersStream sellerId=$restaurantId storeId=- backendPath=$backendPath',
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  @override
  Future<List<PrinterModel>> fetchPrinters(String restaurantId) async {
    final backendPath =
        'printers?restaurant_id=eq.$restaurantId&order=created_at.asc';
    _logPrinterSettings(
      'Fetch',
      'source=fetchPrinters sellerId=$restaurantId storeId=- backendPath=$backendPath',
    );
    try {
      final rows = await _client
          .from('printers')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('created_at', ascending: true);
      final printers = List<Map<String, dynamic>>.from(
        rows as List,
      ).map(PrinterModel.fromMap).toList(growable: false);
      _logPrinterSettings(
        'Fetch',
        'source=fetchPrinters sellerId=$restaurantId storeId=- '
            'backendPath=$backendPath printerCount=${printers.length}',
      );
      return printers;
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Error',
        'source=fetchPrinters sellerId=$restaurantId storeId=- backendPath=$backendPath',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
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
    bool supportsCut = false,
    PrinterCharset charset = PrinterCharset.cp857,
    int? codePage,
    List<PrinterRole> assignedRoles = const [],
    String? printerProfileId,
  }) async {
    final encodingSelection = PrinterEncodingSelection.normalize(
      charset: charset,
      codePage: codePage,
    );
    if (encodingSelection.fallbackApplied) {
      debugPrint(
        '[PrinterRepository] encoding_guard '
        'restaurantId=$restaurantId printerId=${printerId ?? "-"} '
        'requestedCharset=${charset.value} requestedCodePage=${codePage ?? "-"} '
        'effectiveEncoding=${encodingSelection.encoding} '
        'effectiveCodePage=${encodingSelection.codePage ?? "-"} '
        'warning=${encodingSelection.warning}',
      );
    }
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
      'supports_cut': supportsCut,
      'charset': encodingSelection.charset.value,
      'code_page': encodingSelection.codePage,
      'assigned_roles': assignedRoles.map((r) => r.value).toList(),
      if (printerProfileId != null && printerProfileId.isNotEmpty)
        'printer_profile_id': printerProfileId,
    };

    final row = await _client
        .from('printers')
        .upsert(payload)
        .select()
        .single();
    return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async {
    if (printerId.trim().isEmpty) return null;
    try {
      final row = await _client
          .from('printers')
          .select()
          .eq('id', printerId)
          .maybeSingle();
      if (row == null) return null;
      return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Error',
        'source=fetchPrinterById printerId=$printerId',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async {
    return fetchPrinterById(recordId);
  }

  @override
  Future<void> deletePrinter(String printerId) async {
    await _client.from('printers').delete().eq('id', printerId);
  }

  @override
  Future<void> deletePrintersForRestaurant(String restaurantId) async {
    await _client.from('printers').delete().eq('restaurant_id', restaurantId);
  }

  Future<void> setPrinterActive(String printerId, bool isActive) async {
    await _client
        .from('printers')
        .update({'is_active': isActive})
        .eq('id', printerId);
  }

  @override
  Future<void> recordTestPrintResult({
    required String printerId,
    required bool success,
    String? error,
  }) async {
    await _client
        .from('printers')
        .update({
          'last_test_print_at': DateTime.now().toIso8601String(),
          'last_error': success ? null : error,
          'test_print_status': success ? 'ok' : 'failed',
          if (success) 'is_active': true,
        })
        .eq('id', printerId);
  }

  @override
  Future<void> updateAssignedRoles(
    String printerId,
    List<PrinterRole> roles,
  ) async {
    await _client
        .from('printers')
        .update({'assigned_roles': roles.map((role) => role.value).toList()})
        .eq('id', printerId);
  }

  @override
  Future<List<StationPrinterModel>> fetchStationPrinterMappings(
    String restaurantId,
  ) async {
    const selectClause =
        'id, station_id, printer_id, is_primary, created_at, '
        'stations!inner(name, restaurant_id), '
        'printers!inner(name, code, restaurant_id)';
    final backendPath =
        'station_printers?select=$selectClause&stations.restaurant_id=eq.$restaurantId&order=created_at.asc';
    _logPrinterSettings(
      'Fetch',
      'source=fetchStationPrinterMappings sellerId=$restaurantId storeId=- backendPath=$backendPath',
    );
    try {
      final rows = await _client
          .from('station_printers')
          .select(selectClause)
          .eq('stations.restaurant_id', restaurantId)
          .order('created_at', ascending: true);
      final mappings =
          List<Map<String, dynamic>>.from(
              rows as List,
            ).map(StationPrinterModel.fromMap).toList(growable: false)
            ..sort((left, right) {
              final stationCompare = left.stationId.compareTo(right.stationId);
              if (stationCompare != 0) {
                return stationCompare;
              }
              if (left.isPrimary != right.isPrimary) {
                return left.isPrimary ? -1 : 1;
              }
              return left.createdAt.compareTo(right.createdAt);
            });
      _logPrinterSettings(
        'Fetch',
        'source=fetchStationPrinterMappings sellerId=$restaurantId storeId=- '
            'backendPath=$backendPath mappingCount=${mappings.length}',
      );
      return mappings;
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Error',
        'source=fetchStationPrinterMappings sellerId=$restaurantId storeId=- backendPath=$backendPath',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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

  @override
  Future<void> deleteStationPrinterMappingsForPrinter(String printerId) async {
    await _client.from('station_printers').delete().eq('printer_id', printerId);
  }

  @override
  Future<void> deleteStationPrinterMappingsForRestaurant(
    String restaurantId,
  ) async {
    final mappings = await fetchStationPrinterMappings(restaurantId);
    for (final mapping in mappings.whereType<StationPrinterModel>()) {
      await _client.from('station_printers').delete().eq('id', mapping.id);
    }
  }

  void _logPrinterSettings(
    String section,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint(
      '[PrinterSettings][$section] $message${error != null ? ' exception=$error' : ''}',
    );
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
