import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class PrinterEventLogEntry {
  const PrinterEventLogEntry({
    required this.timestamp,
    required this.restaurantId,
    required this.event,
    required this.message,
    this.level = 'info',
    this.jobId,
    this.role,
    this.printerId,
    this.queueName,
    this.backend,
    this.details = const <String, dynamic>{},
  });

  final String timestamp;
  final String restaurantId;
  final String event;
  final String message;
  final String level;
  final String? jobId;
  final String? role;
  final String? printerId;
  final String? queueName;
  final String? backend;
  final Map<String, dynamic> details;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp,
      'restaurantId': restaurantId,
      'event': event,
      'message': message,
      'level': level,
      'jobId': jobId,
      'role': role,
      'printerId': printerId,
      'queueName': queueName,
      'backend': backend,
      'details': details,
    };
  }

  factory PrinterEventLogEntry.fromJson(Map<String, dynamic> json) {
    return PrinterEventLogEntry(
      timestamp: json['timestamp']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      level: json['level']?.toString() ?? 'info',
      jobId: json['jobId']?.toString(),
      role: json['role']?.toString(),
      printerId: json['printerId']?.toString(),
      queueName: json['queueName']?.toString(),
      backend: json['backend']?.toString(),
      details: json['details'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['details'] as Map<String, dynamic>)
          : (json['details'] is Map
                ? Map<String, dynamic>.from(json['details'] as Map)
                : const <String, dynamic>{}),
    );
  }
}

class PrinterEventLogService {
  static const String _storageKey = 'ibul_printer_event_log_v1';
  static const int _maxEntries = 200;
  static int _refreshTick = 0;
  static final StreamController<int> _changes =
      StreamController<int>.broadcast();

  void _emitRefresh() {
    _refreshTick += 1;
    if (!_changes.isClosed) {
      _changes.add(_refreshTick);
    }
  }

  Future<void> appendRuntime({
    required String restaurantId,
    required String event,
    required String flowName,
    required String source,
    String? role,
    String? documentType,
    String? bridgePrinterId,
    String? printerRecordId,
    String? printerName,
    String? backend,
    String? transport,
    String? queue,
    String? deviceIdentifier,
    String? storeId,
    String? tableId,
    String? printJobId,
    bool usedFallback = false,
    String? fallbackReason,
    String? errorMessage,
    String level = 'info',
    Map<String, dynamic>? details,
  }) async {
    try {
      String normalize(String? value) {
        final trimmed = value?.trim() ?? '';
        return trimmed.isEmpty ? '-' : trimmed;
      }

      final normalizedRestaurantId = normalize(restaurantId);
      final normalizedEvent = normalize(event);
      final normalizedFlow = normalize(flowName);
      final normalizedSource = normalize(source);
      final normalizedRole = normalize(role);
      final normalizedDocument = normalize(documentType);
      final normalizedBridgeId = normalize(bridgePrinterId);
      final normalizedRecordId = normalize(printerRecordId);
      final normalizedPrinterName = normalize(printerName);
      final normalizedBackend = normalize(backend ?? transport);
      final normalizedQueue = normalize(queue);
      final normalizedDevice = normalize(deviceIdentifier);
      final normalizedStoreId = normalize(storeId);
      final normalizedTableId = normalize(tableId);
      final normalizedJobId = normalize(printJobId);
      final normalizedFallbackReason = normalize(fallbackReason);
      final normalizedError = normalize(errorMessage);
      final runtimeMessage =
          '[PRINTER_RUNTIME] '
          'event=$normalizedEvent '
          'flow=$normalizedFlow '
          'source=$normalizedSource '
          'restaurant=$normalizedRestaurantId '
          'store=$normalizedStoreId '
          'table=$normalizedTableId '
          'role=$normalizedRole '
          'document=$normalizedDocument '
          'bridge_id=$normalizedBridgeId '
          'record_id=$normalizedRecordId '
          'name=$normalizedPrinterName '
          'backend=$normalizedBackend '
          'queue=$normalizedQueue '
          'device=$normalizedDevice '
          'job=$normalizedJobId '
          'fallback=${usedFallback ? 'true' : 'false'} '
          'fallback_reason=$normalizedFallbackReason '
          'error=$normalizedError';
      debugPrint(runtimeMessage);
      final runtimeDetails = <String, dynamic>{
        'flow_name': normalizedFlow,
        'source': normalizedSource,
        'role': normalizedRole,
        'document_type': normalizedDocument,
        'bridge_printer_id': normalizedBridgeId,
        'printer_record_id': normalizedRecordId,
        'printer_name': normalizedPrinterName,
        'backend': normalizedBackend,
        'transport': normalizedBackend,
        'queue': normalizedQueue,
        'device_identifier': normalizedDevice,
        'restaurant_id': normalizedRestaurantId,
        'store_id': normalizedStoreId,
        'table_id': normalizedTableId,
        'print_job_id': normalizedJobId,
        'used_fallback': usedFallback,
        'fallback_reason': normalizedFallbackReason,
        'error_message': normalizedError,
        if (details != null) ...details,
      };
      await append(
        restaurantId: restaurantId,
        event: event,
        message: runtimeMessage,
        level: level,
        jobId: printJobId,
        role: role,
        printerId: printerRecordId ?? bridgePrinterId,
        queueName: queue ?? deviceIdentifier,
        backend: backend ?? transport,
        details: runtimeDetails,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[PrinterEventLogService] appendRuntime failed '
        'event=$event restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
    }
  }

  Future<void> append({
    required String restaurantId,
    required String event,
    required String message,
    String level = 'info',
    String? jobId,
    String? role,
    String? printerId,
    String? queueName,
    String? backend,
    Map<String, dynamic>? details,
  }) async {
    try {
      final entry = PrinterEventLogEntry(
        timestamp: DateTime.now().toIso8601String(),
        restaurantId: restaurantId.trim(),
        event: event.trim(),
        message: message.trim(),
        level: level.trim().isEmpty ? 'info' : level.trim(),
        jobId: jobId?.trim().isEmpty ?? true ? null : jobId!.trim(),
        role: role?.trim().isEmpty ?? true ? null : role!.trim(),
        printerId: printerId?.trim().isEmpty ?? true ? null : printerId!.trim(),
        queueName: queueName?.trim().isEmpty ?? true ? null : queueName!.trim(),
        backend: backend?.trim().isEmpty ?? true ? null : backend!.trim(),
        details: details ?? const <String, dynamic>{},
      );

      final prefs = await SharedPreferences.getInstance();
      final current = await _readAll(prefs);
      current.add(entry);
      final trimmed = current.length <= _maxEntries
          ? current
          : current.sublist(current.length - _maxEntries);
      await prefs.setString(
        _storageKey,
        jsonEncode(
          trimmed.map((item) => item.toJson()).toList(growable: false),
        ),
      );
      _emitRefresh();
    } catch (error, stackTrace) {
      debugPrint(
        '[PrinterEventLogService] append failed '
        'event=$event restaurantId=$restaurantId error=$error',
      );
      debugPrint('$stackTrace');
    }
  }

  Future<List<PrinterEventLogEntry>> readRecent(
    String restaurantId, {
    int limit = 100,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _readAll(prefs);
    final filtered = entries
        .where((entry) => entry.restaurantId == restaurantId.trim())
        .toList(growable: false);
    if (filtered.length <= limit) {
      return filtered.reversed.toList(growable: false);
    }
    return filtered
        .sublist(filtered.length - limit)
        .reversed
        .toList(growable: false);
  }

  Stream<List<PrinterEventLogEntry>> watchRecent(
    String restaurantId, {
    int limit = 100,
  }) async* {
    yield await readRecent(restaurantId, limit: limit);
    yield* _changes.stream.asyncMap(
      (_) => readRecent(restaurantId, limit: limit),
    );
  }

  Future<void> clearRestaurantLogs(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _readAll(prefs);
    final beforeCount = entries.length;
    entries.removeWhere((entry) => entry.restaurantId == restaurantId.trim());
    await prefs.setString(
      _storageKey,
      jsonEncode(entries.map((item) => item.toJson()).toList(growable: false)),
    );
    debugPrint(
      '[PrinterEventLogService] Cleared restaurant logs: '
      'restaurantId=$restaurantId beforeCount=$beforeCount afterCount=${entries.length}',
    );
    _emitRefresh();
    await Future<void>.delayed(Duration.zero);
    _emitRefresh();
  }

  Future<List<PrinterEventLogEntry>> _readAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <PrinterEventLogEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <PrinterEventLogEntry>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                PrinterEventLogEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: true);
    } catch (_) {
      return <PrinterEventLogEntry>[];
    }
  }
}
