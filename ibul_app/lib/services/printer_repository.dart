import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/printer_model.dart';
import '../models/station_printer_model.dart';
import 'desktop_print_ports.dart';

export 'desktop_print_ports.dart' show ExpectedKitchenPrinterResolution;

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

  /// Convenience helper that persists an Ethernet/TCP ESC/POS printer.
  ///
  /// Stores ``connection_type='network'`` and a ``tcp:HOST:PORT``
  /// ``device_identifier`` so the dispatcher can detect this row as an
  /// Ethernet printer when resolving the role mapping.
  Future<PrinterModel> upsertEthernetPrinter({
    required String restaurantId,
    String? printerId,
    required String name,
    required String code,
    required String ipAddress,
    required int port,
    int paperWidthMm = PrinterModel.defaultPaperWidthMm,
    bool isActive = true,
    bool supportsCut = true,
    PrinterCharset charset = PrinterCharset.cp857,
    int? codePage,
    List<PrinterRole> assignedRoles = const [],
    String? printerProfileId,
  }) {
    final normalizedHost = ipAddress.trim();
    final normalizedPort = port > 0 ? port : PrinterModel.ethernetDefaultPort;
    return upsertPrinter(
      restaurantId: restaurantId,
      printerId: printerId,
      name: name,
      code: code,
      connectionType: PrinterModel.networkConnectionType,
      ipAddress: normalizedHost,
      port: normalizedPort,
      deviceIdentifier: PrinterModel.ethernetPrinterId(
        host: normalizedHost,
        port: normalizedPort,
      ),
      paperWidthMm: paperWidthMm,
      isActive: isActive,
      supportsCut: supportsCut,
      charset: charset,
      codePage: codePage,
      assignedRoles: assignedRoles,
      printerProfileId: printerProfileId,
    );
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

    try {
      final row = await _client
          .from('printers')
          .upsert(payload, onConflict: 'restaurant_id,code')
          .select()
          .single();
      return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (error, stackTrace) {
      if (_isDuplicatePrinterCodeError(error)) {
        final normalizedRestaurantId = restaurantId.trim();
        final normalizedCode = code.trim().toUpperCase();
        final existing = await _client
            .from('printers')
            .select()
            .eq('restaurant_id', normalizedRestaurantId)
            .eq('code', normalizedCode)
            .maybeSingle();
        if (existing != null) {
          final existingId = existing['id']?.toString().trim() ?? '';
          final updatePayload = Map<String, dynamic>.from(payload)
            ..remove('id');
          final updated = await _client
              .from('printers')
              .update(updatePayload)
              .eq('id', existingId)
              .select()
              .single();
          return PrinterModel.fromMap(
            Map<String, dynamic>.from(updated as Map),
          );
        }
      }
      _logPrinterSettings(
        'Error',
        'source=upsertPrinter restaurantId=$restaurantId printerId=${printerId ?? "-"} code=${code.trim().toUpperCase()}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool _isDuplicatePrinterCodeError(PostgrestException error) {
    final message = error.message.toLowerCase();
    final details = (error.details?.toString() ?? '').toLowerCase();
    return error.code == '23505' &&
        (message.contains('idx_printers_restaurant_code_unique') ||
            details.contains('idx_printers_restaurant_code_unique') ||
            message.contains('duplicate key') ||
            details.contains('duplicate key'));
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
    String? restaurantId,
    String? stationName,
    String? printerName,
  }) async {
    final normalizedPrinterId = printerId.trim();
    final normalizedStationId = stationId.trim();
    debugPrint(
      '[PrinterRoleSave] request '
      'seller_id=${restaurantId ?? '-'} store_id=- '
      'printer_id=$normalizedPrinterId printer_name=${printerName ?? '-'} '
      'role=station_mapping station_id=$normalizedStationId '
      'area_id=$normalizedStationId area_name=${stationName ?? '-'} '
      'rpc=station_printers.upsert',
    );
    if (normalizedStationId.isEmpty || normalizedPrinterId.isEmpty) {
      throw StateError('station_id ve printer_id zorunludur.');
    }
    try {
      if (isPrimary) {
        await _client
            .from('station_printers')
            .update({'is_primary': false})
            .eq('station_id', normalizedStationId);
      }

      await _client.from('station_printers').upsert({
        'station_id': normalizedStationId,
        'printer_id': normalizedPrinterId,
        'is_primary': isPrimary,
      }, onConflict: 'station_id,printer_id');
      debugPrint(
        '[PrinterRoleSave] success '
        'seller_id=${restaurantId ?? '-'} station_id=$normalizedStationId '
        'printer_id=$normalizedPrinterId rpc=station_printers.upsert',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[PrinterRoleSave] error '
        'seller_id=${restaurantId ?? '-'} station_id=$normalizedStationId '
        'printer_id=$normalizedPrinterId rpc=station_printers.upsert '
        'message=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
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

  @override
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({
    required String restaurantId,
    String? stationId,
    String? stationName,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedStationId = stationId?.trim() ?? '';
    final normalizedStationName = stationName?.trim().toLowerCase() ?? '';
    if (normalizedRestaurantId.isEmpty) {
      return null;
    }

    if (normalizedStationId.isNotEmpty || normalizedStationName.isNotEmpty) {
      final mappings = await fetchStationPrinterMappings(normalizedRestaurantId);
      final selectedMapping = _resolvePrimaryStationPrinterMappingByIdOrName(
        mappings,
        stationId: normalizedStationId,
        stationName: normalizedStationName,
      );
      if (selectedMapping != null) {
        final printer = await fetchPrinterById(selectedMapping.printerId);
        if (printer != null) {
          return _normalizeExpectedKitchenPrinter(
            source: 'station_mapping',
            printer: printer,
            stationId: selectedMapping.stationId,
            stationName:
                selectedMapping.stationName?.trim().isNotEmpty == true
                ? selectedMapping.stationName!.trim()
                : stationName?.trim(),
          );
        }
      }
    }

    final config = await _client
        .from('restaurant_print_station_configs')
        .select('kitchen_printer_id, kitchen_printer_name, role_mappings')
        .eq('restaurant_id', normalizedRestaurantId)
        .maybeSingle();
    if (config == null) {
      return null;
    }
    final configMap = Map<String, dynamic>.from(config as Map);
    final roleMappings = configMap['role_mappings'];
    if (roleMappings is Map) {
      final kitchenMapping = roleMappings['mutfak'];
      if (kitchenMapping is Map) {
        final mapping = Map<String, dynamic>.from(kitchenMapping);
        final recordId =
            (mapping['printerRecordId'] ??
                    mapping['printer_record_id'] ??
                    mapping['id'])
                ?.toString()
                .trim() ??
            '';
        if (recordId.isNotEmpty) {
          final printer = await fetchPrinterById(recordId);
          if (printer != null) {
            return _normalizeExpectedKitchenPrinter(
              source: 'mutfak_role_mapping',
              printer: printer,
              stationId: normalizedStationId.isEmpty ? null : normalizedStationId,
              stationName: stationName?.trim(),
            );
          }
        }
      }
    }

    final kitchenPrinterId =
        configMap['kitchen_printer_id']?.toString().trim() ?? '';
    if (kitchenPrinterId.isEmpty) {
      return null;
    }
    final printer = await fetchPrinterById(kitchenPrinterId);
    if (printer == null) {
      return null;
    }
    return _normalizeExpectedKitchenPrinter(
      source: 'mutfak_role_mapping',
      printer: printer,
      stationId: normalizedStationId.isEmpty ? null : normalizedStationId,
      stationName: stationName?.trim(),
    );
  }

  StationPrinterModel? _resolvePrimaryStationPrinterMappingByIdOrName(
    List<StationPrinterModel> mappings, {
    required String stationId,
    required String stationName,
  }) {
    if (stationId.isNotEmpty) {
      for (final mapping in mappings) {
        if (mapping.stationId == stationId && mapping.isPrimary) {
          return mapping;
        }
      }
      for (final mapping in mappings) {
        if (mapping.stationId == stationId) {
          return mapping;
        }
      }
    }
    if (stationName.isNotEmpty) {
      for (final mapping in mappings) {
        final candidateName = mapping.stationName?.trim().toLowerCase() ?? '';
        if (candidateName == stationName && mapping.isPrimary) {
          return mapping;
        }
      }
      for (final mapping in mappings) {
        final candidateName = mapping.stationName?.trim().toLowerCase() ?? '';
        if (candidateName == stationName) {
          return mapping;
        }
      }
    }
    return null;
  }

  StationPrinterModel? _resolvePrimaryStationPrinterMapping(
    List<StationPrinterModel> mappings,
    String stationId,
  ) {
    for (final mapping in mappings) {
      if (mapping.stationId == stationId && mapping.isPrimary) {
        return mapping;
      }
    }
    for (final mapping in mappings) {
      if (mapping.stationId == stationId) {
        return mapping;
      }
    }
    return null;
  }

  ExpectedKitchenPrinterResolution _normalizeExpectedKitchenPrinter({
    required String source,
    required PrinterModel printer,
    String? stationId,
    String? stationName,
  }) {
    final backend = _normalizeBackend(printer);
    final queue = (printer.deviceIdentifier ?? printer.name).trim();
    return ExpectedKitchenPrinterResolution(
      source: source,
      printer: printer,
      backend: backend,
      host: printer.ipAddress?.trim() ?? '',
      port: printer.port,
      queue: queue,
      stationId: stationId,
      stationName: stationName,
    );
  }

  String _normalizeBackend(PrinterModel printer) {
    if (printer.isEthernetConnection) {
      return 'tcp';
    }
    final queueFingerprint =
        '${printer.deviceIdentifier ?? ''} ${printer.name}'.toLowerCase();
    if (queueFingerprint.contains('cups')) {
      return 'cups';
    }
    return 'usb';
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
