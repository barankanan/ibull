import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/printer_model.dart';
import 'printer_print_size_settings.dart';
import 'printer_receipt_length_settings.dart';
import '../models/station_printer_model.dart';
import '../models/printer_profile.dart';
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
    final source = _client
        .from('printers')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true);
    // A registered printer must stay on screen while the cloud is away: every
    // list the server sends is kept as this device's last good copy, and a
    // connection failure shows that copy instead of an error. A refusal from
    // the server (denied, bad request) is still passed on.
    return source.transform(
      StreamTransformer<List<Map<String, dynamic>>, List<PrinterModel>>.fromHandlers(
        handleData: (rows, sink) {
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
          unawaited(
            rememberLastGoodRows(
              _printersCacheKind,
              restaurantId,
              rows,
              emptyIsAuthoritative: emptyAnswerIsAuthoritative(_client),
            ),
          );
          sink.add(printers);
        },
        handleError: (error, stackTrace, sink) {
          _logPrinterSettings(
            'Error',
            'source=watchPrintersStream sellerId=$restaurantId storeId=- backendPath=$backendPath',
            error: error,
            stackTrace: stackTrace,
          );
          unawaited(() async {
            final refused =
                error is PostgrestException && !isCloudOutageAnswer(error);
            final cached = refused
                ? null
                : await _lastGoodRows(_printersCacheKind, restaurantId);
            if (cached == null) {
              sink.addError(error, stackTrace);
              return;
            }
            sink.add(
              cached.map(PrinterModel.fromMap).toList(growable: false),
            );
          }());
        },
      ),
    );
  }

  /// İnternet yokken (LAN açık) bulut okuması süresiz beklemesin: süre dolunca
  /// mevcut "son iyi kayıt" geri dönüşü devreye girer. Zaman aşımı
  /// [isCloudUnreachableError] tarafından bulut-erişilemez sayılır.
  static const Duration cloudReadTimeout = Duration(seconds: 4);

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
          .order('created_at', ascending: true)
          .timeout(cloudReadTimeout);
      final printers = List<Map<String, dynamic>>.from(
        rows as List,
      ).map(PrinterModel.fromMap).toList(growable: false);
      _logPrinterSettings(
        'Fetch',
        'source=fetchPrinters sellerId=$restaurantId storeId=- '
            'backendPath=$backendPath printerCount=${printers.length}',
      );
      await rememberLastGoodRows(
        _printersCacheKind,
        restaurantId,
        rows,
        emptyIsAuthoritative: emptyAnswerIsAuthoritative(_client),
      );
      return printers;
    } catch (error, stackTrace) {
      // Without the cloud the kitchen ticket still needs its printer: the
      // list last read from the server is used. Any other failure (denied,
      // bad request) is not papered over.
      final cached = await lastGoodRowsWhenUnreachable(
        _printersCacheKind,
        restaurantId,
        error,
      );
      if (cached != null) {
        return cached.map(PrinterModel.fromMap).toList(growable: false);
      }
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
    PrinterReceiptLengthSettings? receiptLengthSettings,
    PrinterPrintSizeSettings? printSizeSettings,
  }) async {
    final normalizedHost = ipAddress.trim();
    final normalizedPort = port > 0 ? port : PrinterModel.ethernetDefaultPort;
    final deviceIdentifier = PrinterModel.ethernetPrinterId(
      host: normalizedHost,
      port: normalizedPort,
    );
    final canonicalProfileId = PrinterProfile.canonicalDatabaseId(
      printerProfileId,
    );
    var resolvedPrinterId = printerId?.trim();
    if (resolvedPrinterId == null || resolvedPrinterId.isEmpty) {
      final existingByDevice = await fetchEthernetPrinterByEndpoint(
        restaurantId: restaurantId,
        host: normalizedHost,
        port: normalizedPort,
      );
      resolvedPrinterId = existingByDevice?.id;
    }
    return upsertPrinter(
      restaurantId: restaurantId,
      printerId: resolvedPrinterId,
      name: name,
      code: code,
      connectionType: PrinterModel.networkConnectionType,
      ipAddress: normalizedHost,
      port: normalizedPort,
      deviceIdentifier: deviceIdentifier,
      paperWidthMm: paperWidthMm,
      isActive: isActive,
      supportsCut: supportsCut,
      charset: charset,
      codePage: codePage,
      assignedRoles: assignedRoles,
      printerProfileId: canonicalProfileId,
      receiptLengthSettings: receiptLengthSettings,
      printSizeSettings: printSizeSettings,
    );
  }

  Future<PrinterModel?> fetchEthernetPrinterByEndpoint({
    required String restaurantId,
    required String host,
    required int port,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedHost = host.trim();
    final normalizedPort = port > 0 ? port : PrinterModel.ethernetDefaultPort;
    if (normalizedRestaurantId.isEmpty || normalizedHost.isEmpty) {
      return null;
    }
    final deviceIdentifier = PrinterModel.ethernetPrinterId(
      host: normalizedHost,
      port: normalizedPort,
    );
    try {
      final row = await _client
          .from('printers')
          .select()
          .eq('restaurant_id', normalizedRestaurantId)
          .eq('device_identifier', deviceIdentifier)
          .maybeSingle();
      if (row == null) return null;
      return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Error',
        'source=fetchEthernetPrinterByEndpoint restaurantId=$normalizedRestaurantId '
            'deviceIdentifier=$deviceIdentifier',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Updates only the Ethernet IP/port while preserving printer UUID and roles.
  Future<PrinterModel> updateEthernetIpAddress({
    required String restaurantId,
    required String printerId,
    required String ipAddress,
    int? port,
  }) async {
    final existing = await fetchPrinterById(printerId);
    if (existing == null) {
      throw StateError('Printer not found: $printerId');
    }
    final normalizedPort =
        port ?? existing.port ?? PrinterModel.ethernetDefaultPort;
    return upsertEthernetPrinter(
      restaurantId: restaurantId,
      printerId: printerId,
      name: existing.name,
      code: existing.code,
      ipAddress: ipAddress.trim(),
      port: normalizedPort,
      paperWidthMm: existing.paperWidthMm,
      isActive: existing.isActive,
      supportsCut: existing.supportsCut,
      charset: existing.charset,
      codePage: existing.codePage,
      assignedRoles: existing.assignedRoles,
      printerProfileId: existing.printerProfileId,
    );
  }

  @override
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
    PrinterReceiptLengthSettings? receiptLengthSettings,
    PrinterPrintSizeSettings? printSizeSettings,
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
    final normalizedMetadata = PrinterProfile.normalizeSaveMetadata(
      profileId: printerProfileId,
      paperWidthMm: paperWidthMm,
      displayName: name,
    );
    final payload = <String, dynamic>{
      if (printerId != null && printerId.isNotEmpty) 'id': printerId,
      'restaurant_id': restaurantId,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'connection_type': connectionType,
      'ip_address': ipAddress,
      'port': port,
      'device_identifier': deviceIdentifier,
      'paper_width_mm': normalizedMetadata.paperWidthMm,
      'is_active': isActive,
      'supports_cut': supportsCut,
      'charset': encodingSelection.charset.value,
      'code_page': encodingSelection.codePage,
      'assigned_roles': assignedRoles.map((r) => r.value).toList(),
      'printer_profile_id': normalizedMetadata.profileId,
      ...?receiptLengthSettings?.toDbFields(),
      ...?printSizeSettings?.toDbFields(),
    };

    try {
      return await _upsertPrinterPayload(payload);
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
          try {
            final updated = await _client
                .from('printers')
                .update(updatePayload)
                .eq('id', existingId)
                .select()
                .single();
            return _printerWithRequestedPrintSize(
              PrinterModel.fromMap(Map<String, dynamic>.from(updated as Map)),
              printSizeSettings,
            );
          } on PostgrestException catch (updateError) {
            if (_isPrintSizeMigrationMissing(updateError) &&
                printSizeSettings != null) {
              final saved = await _upsertWithoutPrintSizeColumn(
                Map<String, dynamic>.from(updatePayload)..remove('id'),
                printSizeSettings: printSizeSettings,
                existingId: existingId,
              );
              throw PrinterPrintSizeMigrationRequiredException(saved);
            }
            rethrow;
          }
        }
      }
      if (deviceIdentifier != null &&
          deviceIdentifier.trim().isNotEmpty &&
          _isDuplicateDeviceIdentifierError(error)) {
        final existing = await fetchEthernetPrinterByEndpoint(
          restaurantId: restaurantId,
          host: ipAddress?.trim() ?? '',
          port: port ?? PrinterModel.ethernetDefaultPort,
        );
        if (existing != null) {
          final updatePayload = Map<String, dynamic>.from(payload)
            ..remove('id');
          try {
            final updated = await _client
                .from('printers')
                .update(updatePayload)
                .eq('id', existing.id)
                .select()
                .single();
            return _printerWithRequestedPrintSize(
              PrinterModel.fromMap(Map<String, dynamic>.from(updated as Map)),
              printSizeSettings,
            );
          } on PostgrestException catch (updateError) {
            if (_isPrintSizeMigrationMissing(updateError) &&
                printSizeSettings != null) {
              final saved = await _upsertWithoutPrintSizeColumn(
                updatePayload,
                printSizeSettings: printSizeSettings,
                existingId: existing.id,
              );
              throw PrinterPrintSizeMigrationRequiredException(saved);
            }
            rethrow;
          }
        }
      }
      if (_isPrintSizeMigrationMissing(error) && printSizeSettings != null) {
        // Printer kaydı bozulmasın: print_size hariç kaydet, migration uyarısı ver.
        _logPrinterSettings(
          'Error',
          'source=upsertPrinter print_size_column_missing '
              'restaurantId=$restaurantId printerId=${printerId ?? "-"} '
              'code=${code.trim().toUpperCase()} — retrying without print_size',
          error: error,
          stackTrace: stackTrace,
        );
        final saved = await _upsertWithoutPrintSizeColumn(
          payload,
          printSizeSettings: printSizeSettings,
        );
        throw PrinterPrintSizeMigrationRequiredException(saved);
      }
      _logPrinterSettings(
        'Error',
        'source=upsertPrinter restaurantId=$restaurantId printerId=${printerId ?? "-"} code=${code.trim().toUpperCase()}',
        error: error,
        stackTrace: stackTrace,
      );
      if (_isReceiptLengthMigrationMissing(error)) {
        throw StateError(
          'Fiş uzunluğu ayarları için veritabanı güncellemesi gerekli. '
          'SUPABASE_PRINTER_RECEIPT_LENGTH_SETTINGS.sql dosyasını çalıştırın.',
        );
      }
      rethrow;
    }
  }

  Future<PrinterModel> _upsertPrinterPayload(Map<String, dynamic> payload) async {
    final row = await _client
        .from('printers')
        .upsert(payload, onConflict: 'restaurant_id,code')
        .select()
        .single();
    return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<PrinterModel> _upsertWithoutPrintSizeColumn(
    Map<String, dynamic> payload, {
    required PrinterPrintSizeSettings printSizeSettings,
    String? existingId,
  }) async {
    final stripped = Map<String, dynamic>.from(payload)..remove('print_size');
    if (existingId != null && existingId.trim().isNotEmpty) {
      final updated = await _client
          .from('printers')
          .update(stripped)
          .eq('id', existingId)
          .select()
          .single();
      return _printerWithRequestedPrintSize(
        PrinterModel.fromMap(Map<String, dynamic>.from(updated as Map)),
        printSizeSettings,
      );
    }
    final saved = await _upsertPrinterPayload(stripped);
    return _printerWithRequestedPrintSize(saved, printSizeSettings);
  }

  PrinterModel _printerWithRequestedPrintSize(
    PrinterModel printer,
    PrinterPrintSizeSettings? printSizeSettings,
  ) {
    if (printSizeSettings == null) return printer;
    return printer.copyWith(printSize: printSizeSettings.preset.bridgeValue);
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

  bool _isDuplicateDeviceIdentifierError(PostgrestException error) {
    final message = error.message.toLowerCase();
    final details = (error.details?.toString() ?? '').toLowerCase();
    return error.code == '23505' &&
        (message.contains('device_identifier') ||
            details.contains('device_identifier'));
  }

  bool _isReceiptLengthMigrationMissing(PostgrestException error) {
    final combined =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return combined.contains('receipt_length_preset') ||
        combined.contains('receipt_bottom_feed_lines') ||
        combined.contains('receipt_bottom_padding_px') ||
        combined.contains('receipt_min_receipt_height_px');
  }

  bool _isPrintSizeMigrationMissing(PostgrestException error) {
    final combined =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return combined.contains('print_size');
  }

  @override
  Future<PrinterModel?> fetchPrinterById(String printerId) async {
    if (printerId.trim().isEmpty) return null;
    return printerByIdFrom(
      printerId: printerId,
      read: () => _client
          .from('printers')
          .select()
          .eq('id', printerId)
          .maybeSingle(),
      onError: (error, stackTrace) => _logPrinterSettings(
        'Error',
        'source=fetchPrinterById printerId=$printerId',
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// One printer row from [read], bounded by [timeout].
  ///
  /// With the internet gone but the socket still open, the read neither
  /// answers nor fails. Unbounded, it held the kitchen ticket of an order
  /// already saved locally (and the waiter's "Sipariş gönderiliyor" screen)
  /// for close to a minute. After [timeout] the row last read from the
  /// server on this device is used, exactly as for a refused connection.
  static Future<PrinterModel?> printerByIdFrom({
    required String printerId,
    required Future<dynamic> Function() read,
    Duration timeout = cloudReadTimeout,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      final row = await read().timeout(timeout);
      if (row == null) return null;
      return PrinterModel.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      if (isCloudUnreachableError(error)) {
        final cached = await _lastGoodPrinterById(printerId);
        if (cached != null) return cached;
      }
      return null;
    }
  }

  @override
  Future<PrinterModel?> getPrinterByRecordId(String recordId) async {
    return fetchPrinterById(recordId);
  }

  /// Normalizes inconsistent profile id / paper width on an existing printer row.
  @override
  Future<PrinterModel> repairPrinterProfileMetadata(String printerId) async {
    final existing = await fetchPrinterById(printerId);
    if (existing == null) {
      throw StateError('Yazıcı kaydı bulunamadı: $printerId');
    }
    final normalized = PrinterProfile.normalizeSaveMetadata(
      profileId: existing.printerProfileId,
      paperWidthMm: existing.paperWidthMm,
      displayName: existing.name,
    );
    final updated = await _client
        .from('printers')
        .update(<String, dynamic>{
          'printer_profile_id': normalized.profileId,
          'paper_width_mm': normalized.paperWidthMm,
        })
        .eq('id', printerId)
        .select()
        .single();
    return PrinterModel.fromMap(Map<String, dynamic>.from(updated as Map));
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
    String? statusOverride,
  }) async {
    await _client
        .from('printers')
        .update({
          'last_test_print_at': DateTime.now().toIso8601String(),
          'last_error': success ? null : error,
          'test_print_status':
              statusOverride ?? (success ? 'ok' : 'failed'),
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

  static const String _printersCacheKind = 'printers';
  static const String _stationPrintersCacheKind = 'station_printers';
  static const String stationConfigCacheKind = 'station_config';
  static const String stationsCacheKind = 'stations';

  static String lastGoodRowsKey(String kind, String restaurantId) =>
      'printer_repository_last_good_v1_${kind}_${restaurantId.trim()}';

  /// A printer from any restaurant's last successful list on this device.
  static Future<PrinterModel?> _lastGoodPrinterById(String printerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = lastGoodRowsKey(_printersCacheKind, '');
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(prefix)) continue;
        final decoded = jsonDecode(prefs.getString(key) ?? '[]');
        if (decoded is! List) continue;
        for (final row in decoded.whereType<Map>()) {
          if (row['id']?.toString() == printerId) {
            return PrinterModel.fromMap(Map<String, dynamic>.from(row));
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// The saved station -> printer assignments of [restaurantId], from the
  /// rows last read from the server on this device. No network.
  ///
  /// Null means "not known on this device yet" (either list was never read):
  /// a caller that must not guess then leaves the ticket to the path that
  /// reads the assignments.
  static Future<SavedStationPrinters?> lastGoodStationPrinters(
    String restaurantId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPrinters = prefs.getString(
        lastGoodRowsKey(_printersCacheKind, restaurantId),
      );
      final rawMappings = prefs.getString(
        lastGoodRowsKey(_stationPrintersCacheKind, restaurantId),
      );
      if (rawPrinters == null || rawMappings == null) return null;
      final printers = jsonDecode(rawPrinters);
      final mappings = jsonDecode(rawMappings);
      if (printers is! List || mappings is! List) return null;
      Map<String, dynamic>? stationConfig;
      try {
        final config = jsonDecode(
          prefs.getString(
                lastGoodRowsKey(stationConfigCacheKind, restaurantId),
              ) ??
              '[]',
        );
        if (config is List && config.isNotEmpty && config.first is Map) {
          stationConfig = Map<String, dynamic>.from(config.first as Map);
        }
      } catch (_) {}
      return SavedStationPrinters.fromRows(
        printerRows: printers.whereType<Map>().map(
          (row) => Map<String, dynamic>.from(row),
        ),
        mappingRows: mappings.whereType<Map>().map(
          (row) => Map<String, dynamic>.from(row),
        ),
        stationConfig: stationConfig,
      );
    } catch (_) {
      return null;
    }
  }

  /// True for failures that mean "the server could not be reached", as
  /// opposed to an answer from the server.
  static bool isCloudUnreachableError(Object error) {
    if (error is PostgrestException) return isCloudOutageAnswer(error);
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('timeoutexception') ||
        text.contains('timed out');
  }

  /// True when the server side answered, but the answer says the cloud itself
  /// is down (gateway / upstream failure) rather than "this request is
  /// refused". A registered printer must stay usable through such an outage,
  /// so these are read from the last good copy like a dropped connection.
  /// Permission and validation answers (401/403/4xx, PGRST codes) are not
  /// outages and are never papered over.
  static bool isCloudOutageAnswer(PostgrestException error) {
    final code = int.tryParse((error.code ?? '').trim());
    if (code != null && code >= 500 && code <= 599) return true;
    final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return text.contains('bad gateway') ||
        text.contains('service unavailable') ||
        text.contains('gateway timeout') ||
        text.contains('upstream connect error') ||
        text.contains('upstream request timeout');
  }

  /// Whether an EMPTY answer from the server may replace a non-empty last
  /// good copy. Without a live signed-in session the server filters every row
  /// away (RLS) and answers "[]" with success; that is not "the restaurant has
  /// no printers" and must not erase the copy the offline path depends on.
  static bool emptyAnswerIsAuthoritative(SupabaseClient client) {
    try {
      final session = client.auth.currentSession;
      return session != null && !session.isExpired;
    } catch (_) {
      return false;
    }
  }

  /// Keeps the rows of the last successful read on this device.
  ///
  /// [emptyIsAuthoritative] false keeps an existing non-empty copy when the
  /// answer is empty (see [emptyAnswerIsAuthoritative]).
  static Future<void> rememberLastGoodRows(
    String kind,
    String restaurantId,
    Object? rows, {
    bool emptyIsAuthoritative = true,
  }) async {
    if (rows is! List || restaurantId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = lastGoodRowsKey(kind, restaurantId);
      if (rows.isEmpty && !emptyIsAuthoritative) {
        final existing = prefs.getString(key);
        if (existing != null && existing.isNotEmpty && existing != '[]') {
          return;
        }
      }
      await prefs.setString(key, jsonEncode(rows));
    } catch (_) {
      // The cache is a convenience; a failed write must not fail the read.
    }
  }

  /// The last successfully read rows, only when [error] is a reachability
  /// failure and such rows exist. Null means "rethrow the error".
  static Future<List<Map<String, dynamic>>?> lastGoodRowsWhenUnreachable(
    String kind,
    String restaurantId,
    Object error,
  ) async {
    if (!isCloudUnreachableError(error)) return null;
    return _lastGoodRows(kind, restaurantId);
  }

  static Future<List<Map<String, dynamic>>?> _lastGoodRows(
    String kind,
    String restaurantId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(lastGoodRowsKey(kind, restaurantId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
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
          .order('created_at', ascending: true)
          .timeout(cloudReadTimeout);
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
      await rememberLastGoodRows(
        _stationPrintersCacheKind,
        restaurantId,
        rows,
        emptyIsAuthoritative: emptyAnswerIsAuthoritative(_client),
      );
      return mappings;
    } catch (error, stackTrace) {
      final cached = await lastGoodRowsWhenUnreachable(
        _stationPrintersCacheKind,
        restaurantId,
        error,
      );
      if (cached != null) {
        return cached.map(StationPrinterModel.fromMap).toList(growable: false);
      }
      // Unreachable and never read on this device: no station links are
      // known, so the ticket goes to the printer that holds the kitchen
      // role. Failing here left an offline order without any ticket.
      if (isCloudUnreachableError(error)) {
        return const <StationPrinterModel>[];
      }
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
      // Write the new assignment first. Demoting the others first left the
      // station with no primary printer when the write then failed.
      await _client.from('station_printers').upsert({
        'station_id': normalizedStationId,
        'printer_id': normalizedPrinterId,
        'is_primary': isPrimary,
      }, onConflict: 'station_id,printer_id');
      if (isPrimary) {
        await _client
            .from('station_printers')
            .update({'is_primary': false})
            .eq('station_id', normalizedStationId)
            .neq('printer_id', normalizedPrinterId);
      }
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

    Object? config;
    try {
      config = await _client
          .from('restaurant_print_station_configs')
          .select('kitchen_printer_id, kitchen_printer_name, role_mappings')
          .eq('restaurant_id', normalizedRestaurantId)
          .maybeSingle()
          .timeout(cloudReadTimeout);
    } catch (error) {
      final cached = await lastGoodRowsWhenUnreachable(
        stationConfigCacheKind,
        normalizedRestaurantId,
        error,
      );
      if (cached == null) rethrow;
      config = cached.isEmpty ? null : cached.first;
    }
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

/// Station -> saved printer, as assigned in Sistem > Yazıcı Merkezi.
class SavedStationPrinters {
  const SavedStationPrinters._(this._printerByStation, this.kitchenRolePrinter);

  factory SavedStationPrinters.fromRows({
    required Iterable<Map<String, dynamic>> printerRows,
    required Iterable<Map<String, dynamic>> mappingRows,
    Map<String, dynamic>? stationConfig,
  }) {
    final printers = <String, PrinterModel>{};
    for (final row in printerRows) {
      try {
        final printer = PrinterModel.fromMap(row);
        printers[printer.id] = printer;
      } catch (_) {}
    }
    final chosen = <String, PrinterModel?>{};
    final chosenIsPrimary = <String, bool>{};
    for (final row in mappingRows) {
      final station = row['station_id']?.toString().trim() ?? '';
      final printerId = row['printer_id']?.toString().trim() ?? '';
      if (station.isEmpty || printerId.isEmpty) continue;
      final primary = row['is_primary'] == true;
      if (chosen.containsKey(station) &&
          (chosenIsPrimary[station] == true || !primary)) {
        continue;
      }
      // The station IS assigned even when its printer record is missing:
      // such a station must not fall through to some other printer.
      chosen[station] = printers[printerId];
      chosenIsPrimary[station] = primary;
    }
    return SavedStationPrinters._(
      chosen,
      _kitchenRolePrinter(stationConfig, printers),
    );
  }

  /// The printer saved as the "Mutfak" role, matched to its record. It is the
  /// printer of a station that has no assignment of its own. Never "the
  /// printer that happened to print last".
  static PrinterModel? _kitchenRolePrinter(
    Map<String, dynamic>? config,
    Map<String, PrinterModel> printers,
  ) {
    if (config == null) return null;
    final ids = <String>{
      config['kitchen_printer_id']?.toString().trim() ?? '',
    };
    String device = '';
    final mappings = config['role_mappings'];
    final role = mappings is Map ? mappings['mutfak'] : null;
    if (role is Map) {
      ids.add(role['printerRecordId']?.toString().trim() ?? '');
      ids.add(role['printer_record_id']?.toString().trim() ?? '');
      device =
          (role['device_identifier'] ?? role['deviceIdentifier'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
    }
    for (final id in ids) {
      if (id.isNotEmpty && printers[id] != null) return printers[id];
    }
    if (device.isNotEmpty) {
      for (final printer in printers.values) {
        if ((printer.deviceIdentifier ?? '').trim().toLowerCase() == device) {
          return printer;
        }
      }
    }
    return null;
  }

  final Map<String, PrinterModel?> _printerByStation;

  /// See [_kitchenRolePrinter]. Null when no kitchen role printer is saved.
  final PrinterModel? kitchenRolePrinter;

  /// True when the station has an assignment (whether or not its printer
  /// record could be found).
  bool isAssigned(String stationId) =>
      _printerByStation.containsKey(stationId.trim());

  /// The assigned printer, or null (not assigned, or its record is missing).
  PrinterModel? printerFor(String stationId) =>
      _printerByStation[stationId.trim()];
}
