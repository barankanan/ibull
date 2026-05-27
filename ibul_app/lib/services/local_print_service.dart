import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/turkish_encoding_calibration.dart';

class LocalPrintHealthStatus {
  const LocalPrintHealthStatus({
    required this.isAvailable,
    required this.reason,
    required this.url,
    required this.durationMs,
    this.statusCode,
    this.details,
  });

  final bool isAvailable;
  final String reason;
  final Uri url;
  final int durationMs;
  final int? statusCode;
  final Object? details;
}

class LocalPrintServiceException implements Exception {
  const LocalPrintServiceException(
    this.message, {
    this.statusCode,
    this.details,
  });

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() {
    final buffer = StringBuffer('LocalPrintServiceException(')
      ..write('message: $message');
    if (statusCode != null) {
      buffer.write(', statusCode: $statusCode');
    }
    if (details != null) {
      buffer.write(', details: $details');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

class _BridgeResponseCacheEntry {
  const _BridgeResponseCacheEntry({
    required this.data,
    required this.fetchedAt,
  });

  final Map<String, dynamic>? data;
  final DateTime fetchedAt;
}

class LocalPrintService {
  LocalPrintService({http.Client? client, Uri? baseUri, Duration? timeout})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('http://127.0.0.1:3001'),
      _timeout = timeout ?? const Duration(seconds: 5) {
    _log(
      'Init',
      'baseUrl=$_baseUri timeoutMs=${_timeout.inMilliseconds} '
          'host=${_baseUri.host} port=${_baseUri.port}',
    );
  }

  final http.Client _client;
  final Uri _baseUri;
  final Duration _timeout;

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const Duration _bridgeStatusCacheTtl = Duration(seconds: 5);

  _BridgeResponseCacheEntry? _healthCache;
  _BridgeResponseCacheEntry? _printersCache;

  void invalidateBridgeStatusCache() {
    _healthCache = null;
    _printersCache = null;
  }

  bool _cacheFresh(_BridgeResponseCacheEntry? entry) {
    if (entry == null) return false;
    return DateTime.now().difference(entry.fetchedAt) <= _bridgeStatusCacheTtl;
  }

  Future<Map<String, dynamic>?> health({bool useCache = true}) async {
    if (useCache && _cacheFresh(_healthCache)) {
      return _healthCache!.data == null
          ? null
          : Map<String, dynamic>.from(_healthCache!.data!);
    }
    final result = await _sendSoftOk(
      section: 'Health',
      branch: 'health',
      method: 'GET',
      path: '/health',
    );
    _healthCache = _BridgeResponseCacheEntry(
      data: result == null ? null : Map<String, dynamic>.from(result),
      fetchedAt: DateTime.now(),
    );
    return result;
  }

  /// GET /warmup — full pipeline warm-up (fonts, USB, Pillow, renderers).
  /// Returns timing breakdown or null on failure.
  Future<Map<String, dynamic>?> warmup({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      return await _send(
        section: 'Warmup',
        branch: 'warmup',
        method: 'GET',
        path: '/warmup',
      );
    } catch (e) {
      debugPrint('[LocalPrintService] warmup failed: $e');
      return null;
    }
  }

  Future<LocalPrintHealthStatus> checkAvailability({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final url = _endpoint('/health');
    final watch = Stopwatch()..start();
    _log(
      'Health',
      'checkStart routeUrl=$url timeoutMs=${timeout.inMilliseconds}',
    );

    try {
      final response = await _client
          .get(url, headers: _headers)
          .timeout(timeout);
      final jsonBody = _tryDecodeJson(response.body);
      final responseOk = jsonBody?['ok'];
      final isAvailable =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseOk != false;
      if (isAvailable) {
        _log(
          'Health',
          'checkSuccess routeUrl=$url durationMs=${watch.elapsedMilliseconds} '
              'statusCode=${response.statusCode} timeoutMs=${timeout.inMilliseconds}',
        );
        return LocalPrintHealthStatus(
          isAvailable: true,
          reason: 'ok',
          url: url,
          durationMs: watch.elapsedMilliseconds,
          statusCode: response.statusCode,
        );
      }

      final message = _errorMessage(
        response,
        jsonBody,
        fallback: 'Local print health check returned an invalid response.',
      );
      _log(
        'Health',
        'checkFail routeUrl=$url durationMs=${watch.elapsedMilliseconds} '
            'statusCode=${response.statusCode} timeoutMs=${timeout.inMilliseconds} '
            'failureReason=server_error',
        error: message,
      );
      return LocalPrintHealthStatus(
        isAvailable: false,
        reason: 'server_error',
        url: url,
        durationMs: watch.elapsedMilliseconds,
        statusCode: response.statusCode,
        details: message,
      );
    } on TimeoutException catch (error, stackTrace) {
      _log(
        'Health',
        'checkFail routeUrl=$url durationMs=${watch.elapsedMilliseconds} '
            'statusCode=- timeoutMs=${timeout.inMilliseconds} failureReason=timeout',
        error: error,
        stackTrace: stackTrace,
      );
      return LocalPrintHealthStatus(
        isAvailable: false,
        reason: 'timeout',
        url: url,
        durationMs: watch.elapsedMilliseconds,
        details: error,
      );
    } on http.ClientException catch (error, stackTrace) {
      // On Flutter Web, every blocked request (connection refused, CORS,
      // Private Network Access) surfaces as a generic ClientException with
      // message "XMLHttpRequest error." — there is no further signal from the
      // browser.  Use a distinct reason so the UI can show a PNA/CORS hint.
      final failureReason = kIsWeb ? 'web_cors_blocked' : 'connection_error';
      _log(
        'Health',
        'checkFail routeUrl=$url durationMs=${watch.elapsedMilliseconds} '
            'statusCode=- timeoutMs=${timeout.inMilliseconds} '
            'failureReason=$failureReason webCorsLikely=$kIsWeb',
        error: error,
        stackTrace: stackTrace,
      );
      return LocalPrintHealthStatus(
        isAvailable: false,
        reason: failureReason,
        url: url,
        durationMs: watch.elapsedMilliseconds,
        details: error,
      );
    } catch (error, stackTrace) {
      _log(
        'Health',
        'checkFail routeUrl=$url durationMs=${watch.elapsedMilliseconds} '
            'statusCode=- timeoutMs=${timeout.inMilliseconds} '
            'failureReason=request_error',
        error: error,
        stackTrace: stackTrace,
      );
      return LocalPrintHealthStatus(
        isAvailable: false,
        reason: 'request_error',
        url: url,
        durationMs: watch.elapsedMilliseconds,
        details: error,
      );
    }
  }

  static const Duration defaultPrintTestTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>?> spoolSnapshot({
    required String printerName,
    Duration timeout = const Duration(seconds: 2),
  }) {
    final encodedName = Uri.encodeQueryComponent(printerName.trim());
    return _send(
      section: 'Setup',
      branch: 'spool_snapshot',
      method: 'GET',
      path: '/spool/snapshot?printer_name=$encodedName',
      timeout: timeout,
      requireOk: false,
    );
  }

  Future<Map<String, dynamic>?> printTest({
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    Map<String, dynamic>? extraBody,
    String renderMode = 'text',
    String testMode = 'escpos_short',
    Duration? timeout,
  }) {
    final backend =
        printer?['backend']?.toString() ??
        printer?['transportType']?.toString();
    final body = _mergePrintOptions(
      <String, dynamic>{
        if (printerId != null && printerId.trim().isNotEmpty)
          'printer_id': printerId.trim(),
        if (printerName != null && printerName.trim().isNotEmpty)
          'printer_name': printerName.trim(),
        if (printer != null && printer.isNotEmpty)
          'printer': Map<String, dynamic>.from(printer),
        'document_type': 'test',
        'test_mode': testMode,
        if (backend == 'windows-spool') 'spool_mode': 'RAW',
        if (extraBody != null) ...Map<String, dynamic>.from(extraBody),
      },
      targetHost: targetHost,
      targetPort: targetPort,
      encoding: encoding,
      codePage: codePage,
      renderMode: renderMode,
    );
    final embeddedPrinter = printer == null
        ? null
        : Map<String, dynamic>.from(printer);
    debugPrint(
      '[PRINT_TEST_REQUEST] '
      'printer_id=${body['printer_id'] ?? '-'} '
      'printer_name=${body['printer_name'] ?? '-'} '
      'embedded_printer=${embeddedPrinter == null ? '-' : jsonEncode(embeddedPrinter)} '
      'backend=${embeddedPrinter?['backend'] ?? body['printer_backend'] ?? '-'} '
      'queue=${embeddedPrinter?['queue'] ?? embeddedPrinter?['queueName'] ?? '-'} '
      'vendorId=${embeddedPrinter?['vendorId'] ?? '-'} '
      'productId=${embeddedPrinter?['productId'] ?? '-'} '
      'test_mode=${body['test_mode'] ?? '-'} '
      'render_mode=${body['render_mode'] ?? '-'} '
      'codePage=${body['codepage'] ?? '-'} '
      'document_type=${body['document_type'] ?? '-'} '
      'spool_mode=${body['spool_mode'] ?? '-'} '
      'transport=${backend ?? '-'}',
    );
    return _send(
      section: 'Receipt',
      branch: 'print_test',
      method: 'POST',
      path: '/print/test',
      body: body.isEmpty ? null : body,
      timeout: timeout ?? defaultPrintTestTimeout,
    );
  }

  Future<Map<String, dynamic>?> printAdvancedBitmapTest({
    String? targetHost,
    int? targetPort,
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    Duration? timeout,
  }) {
    final backend =
        printer?['backend']?.toString() ??
        printer?['transportType']?.toString();
    final body = _mergePrintOptions(
      <String, dynamic>{
        if (printerId != null && printerId.trim().isNotEmpty)
          'printer_id': printerId.trim(),
        if (printerName != null && printerName.trim().isNotEmpty)
          'printer_name': printerName.trim(),
        if (printer != null && printer.isNotEmpty)
          'printer': Map<String, dynamic>.from(printer),
        'document_type': 'test',
        'test_mode': 'bitmap',
        'render_mode': 'image',
        if (backend == 'windows-spool') 'spool_mode': 'RAW',
      },
      targetHost: targetHost,
      targetPort: targetPort,
      renderMode: 'image',
    );
    return _send(
      section: 'Receipt',
      branch: 'print_test_bitmap',
      method: 'POST',
      path: '/print/test',
      body: body,
      timeout: timeout ?? defaultPrintTestTimeout,
    );
  }

  Future<Map<String, dynamic>?> printTurkishDiagnostic({
    required String encoding,
    required List<int> codePages,
    String? targetHost,
    int? targetPort,
    String renderMode = 'image',
  }) {
    final body = _mergePrintOptions(
      <String, dynamic>{'encoding': encoding, 'codepages': codePages},
      targetHost: targetHost,
      targetPort: targetPort,
      encoding: encoding,
      renderMode: renderMode,
    );
    return _send(
      section: 'Receipt',
      branch: 'print_turkish_diagnostic',
      method: 'POST',
      path: '/print/test/turkish',
      body: body,
    );
  }

  Future<Map<String, dynamic>?> printTurkishEncodingCalibrationCombined({
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    required List<Map<String, dynamic>> candidates,
    String? testLine,
    Duration? timeout,
  }) {
    final backend =
        printer?['backend']?.toString() ??
        printer?['transportType']?.toString();
    final primaryLine = testLine ?? kTurkishCalibrationPrimaryTestLine;
    final body = _mergePrintOptions(
      <String, dynamic>{
        if (printerId != null && printerId.trim().isNotEmpty)
          'printer_id': printerId.trim(),
        if (printerName != null && printerName.trim().isNotEmpty)
          'printer_name': printerName.trim(),
        if (printer != null && printer.isNotEmpty)
          'printer': Map<String, dynamic>.from(printer),
        'encoding': 'cp857',
        'code_page': 13,
        'codepage': 13,
        'combined': true,
        'calibration_mode': 'combined',
        'candidates': candidates,
        'test_line': primaryLine,
        'render_mode': 'text',
        'test_mode': 'turkish_encoding',
        if (backend == 'windows-spool') 'spool_mode': 'RAW',
        'text_length': candidates
            .map((entry) => entry['line']?.toString() ?? '')
            .join()
            .length,
      },
      renderMode: 'text',
      encoding: 'cp857',
      codePage: 13,
    );
    return _send(
      section: 'Receipt',
      branch: 'print_turkish_encoding_calibration_combined',
      method: 'POST',
      path: '/print/test/turkish-encoding',
      body: body,
      timeout: timeout ?? defaultPrintTestTimeout,
    );
  }

  Future<Map<String, dynamic>?> printTurkishEncodingCalibration({
    String? printerId,
    String? printerName,
    Map<String, dynamic>? printer,
    required String encoding,
    required int codePage,
    required String label,
    List<String>? sampleLines,
    Duration? timeout,
  }) {
    final backend =
        printer?['backend']?.toString() ??
        printer?['transportType']?.toString();
    final body = _mergePrintOptions(
      <String, dynamic>{
        if (printerId != null && printerId.trim().isNotEmpty)
          'printer_id': printerId.trim(),
        if (printerName != null && printerName.trim().isNotEmpty)
          'printer_name': printerName.trim(),
        if (printer != null && printer.isNotEmpty)
          'printer': Map<String, dynamic>.from(printer),
        'encoding': encoding,
        'code_page': codePage,
        'codepage': codePage,
        'printer_encoding': encoding,
        'printer_code_page': codePage,
        'codepage_command': 'ESC t $codePage',
        'label': label,
        'sample_lines': sampleLines ?? kTurkishCalibrationSampleLinesFallback,
        'render_mode': 'text',
        'test_mode': 'turkish_encoding',
        if (backend == 'windows-spool') 'spool_mode': 'RAW',
        'text_length': (sampleLines ?? kTurkishCalibrationSampleLinesFallback)
            .join('\n')
            .length,
      },
      renderMode: 'text',
      encoding: encoding,
      codePage: codePage,
    );
    return _send(
      section: 'Receipt',
      branch: 'print_turkish_encoding_calibration',
      method: 'POST',
      path: '/print/test/turkish-encoding',
      body: body,
      timeout: timeout ?? defaultPrintTestTimeout,
    );
  }

  static const List<String> kTurkishCalibrationSampleLinesFallback =
      kTurkishCalibrationSampleLines;

  Future<Map<String, dynamic>?> printReceipt(
    Map<String, dynamic> payload,
  ) async {
    return _send(
      section: 'Receipt',
      branch: 'print_receipt',
      method: 'POST',
      path: '/print/receipt',
      body: payload,
    );
  }

  Future<Map<String, dynamic>?> printJob(Map<String, dynamic> payload) async {
    return _send(
      section: 'Print',
      branch: 'print_job',
      method: 'POST',
      path: '/print',
      body: payload,
    );
  }

  Future<Map<String, dynamic>?> printRawBase64({
    required String rawBase64,
    String? printerId,
    String? printerName,
    String? jobName,
  }) {
    return printJob(<String, dynamic>{
      'raw_base64': rawBase64,
      if (printerId != null && printerId.isNotEmpty) 'printer_id': printerId,
      if (printerName != null && printerName.isNotEmpty)
        'printer_name': printerName,
      if (jobName != null && jobName.isNotEmpty) 'job_name': jobName,
    });
  }

  Future<Map<String, dynamic>?> printDocument({
    required Map<String, dynamic> document,
    String? printerId,
    String? printerName,
    String? jobName,
  }) {
    return printJob(<String, dynamic>{
      'document': document,
      if (printerId != null && printerId.isNotEmpty) 'printer_id': printerId,
      if (printerName != null && printerName.isNotEmpty)
        'printer_name': printerName,
      if (jobName != null && jobName.isNotEmpty) 'job_name': jobName,
    });
  }

  Future<Map<String, dynamic>?> printers({bool useCache = true}) async {
    if (useCache && _cacheFresh(_printersCache)) {
      return _printersCache!.data == null
          ? null
          : Map<String, dynamic>.from(_printersCache!.data!);
    }
    final result = await _sendSoftOk(
      section: 'Printers',
      branch: 'printers',
      method: 'GET',
      path: '/printers',
    );
    _printersCache = _BridgeResponseCacheEntry(
      data: result == null ? null : Map<String, dynamic>.from(result),
      fetchedAt: DateTime.now(),
    );
    return result;
  }

  /// Calls GET /discover and returns discovered USB printer info.
  /// Returns null (does not throw) when the bridge is offline or pyusb
  /// is not installed.
  Future<Map<String, dynamic>?> discover() async {
    try {
      return await _send(
        section: 'Discover',
        branch: 'discover',
        method: 'GET',
        path: '/discover',
      );
    } on LocalPrintServiceException {
      return printers();
    }
  }

  /// POST /setup — tells the bridge to auto-discover and configure itself.
  ///
  /// Returns the parsed response body, or null on failure.
  Future<Map<String, dynamic>?> setup() async {
    try {
      return await _send(
        section: 'Setup',
        branch: 'setup',
        method: 'POST',
        path: '/setup',
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> setupStatus() async {
    return _sendSoftOk(
      section: 'Setup',
      branch: 'setup_status',
      method: 'GET',
      path: '/setup/status',
    );
  }

  Future<Map<String, dynamic>?> setupPrerequisites() async {
    return _sendSoftOk(
      section: 'Setup',
      branch: 'setup_prerequisites',
      method: 'GET',
      path: '/setup/prerequisites',
    );
  }

  Future<Map<String, dynamic>?> setupInstall() async {
    try {
      return await _send(
        section: 'Setup',
        branch: 'setup_install',
        method: 'POST',
        path: '/setup/install',
        body: const <String, dynamic>{},
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> setupStart() async {
    try {
      return await _send(
        section: 'Setup',
        branch: 'setup_start',
        method: 'POST',
        path: '/setup/start',
        body: const <String, dynamic>{},
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> enableAutostart() async {
    try {
      return await _send(
        section: 'Setup',
        branch: 'enable_autostart',
        method: 'POST',
        path: '/setup/enable-autostart',
        body: const <String, dynamic>{},
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> disableAutostart() async {
    try {
      return await _send(
        section: 'Setup',
        branch: 'disable_autostart',
        method: 'POST',
        path: '/setup/disable-autostart',
        body: const <String, dynamic>{},
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> driverHelp() async {
    try {
      return await _send(
        section: 'Setup',
        branch: 'driver_help',
        method: 'GET',
        path: '/setup/driver-help',
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  /// POST /configure — pushes a partial settings update to the bridge.
  ///
  /// [fields] should contain any subset of the bridge's semantic field names
  /// (e.g. ``{'transport_mode': 'cups', 'printer_queue': 'Canon_T20'}``).
  /// Returns true if the bridge accepted and applied the change.
  Future<bool> configure(Map<String, dynamic> fields) async {
    try {
      final result = await _send(
        section: 'Configure',
        branch: 'configure',
        method: 'POST',
        path: '/configure',
        body: fields,
      );
      return result?['ok'] == true;
    } on LocalPrintServiceException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> configurePrintStation(
    Map<String, dynamic> fields,
  ) async {
    try {
      return await configurePrintStationStrict(fields);
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> configurePrintStationStrict(
    Map<String, dynamic> fields,
  ) async {
    return await _send(
      section: 'Queue',
      branch: 'configure_print_station',
      method: 'POST',
      path: '/configure/print-station',
      body: fields,
    );
  }

  Future<Map<String, dynamic>?> queueStatus() async {
    try {
      return await _send(
        section: 'Queue',
        branch: 'queue_status',
        method: 'GET',
        path: '/queue/status',
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> clearCupsQueue({String? queue}) async {
    return _send(
      section: 'Queue',
      branch: 'queue_clear',
      method: 'POST',
      path: '/queue/clear',
      body: <String, dynamic>{
        if (queue != null && queue.trim().isNotEmpty) 'queue': queue.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> clearQueueAndRefresh({String? queue}) async {
    final clear = await clearCupsQueue(queue: queue);
    final status = await queueStatus();
    final healthInfo = await health();
    final printerInfo = await printers();
    return <String, dynamic>{
      'clear': clear,
      'queue_status': status,
      'health': healthInfo,
      'printers': printerInfo,
    };
  }

  Future<Map<String, dynamic>?> releaseUsbPrinters() {
    return _send(
      section: 'System',
      branch: 'release_usb_printers',
      method: 'POST',
      path: '/system/release-usb-printers',
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>?> printKitchen(
    Map<String, dynamic> payload, {
    String path = '/print/kitchen',
  }) async {
    final result = await _send(
      section: 'Kitchen',
      branch: 'print_kitchen',
      method: 'POST',
      path: path,
      body: payload,
    );
    if (result != null) {
      final writeStarted = result['printer_write_started_at'];
      final writeCompleted = result['printer_write_completed_at'];
      final transportMs = result['transport_ms'];
      if (writeStarted != null) {
        debugPrint(
          '[PrintPipeline] stage=bridge_write '
          'printer_write_started_at=$writeStarted '
          'printer_write_completed_at=$writeCompleted '
          'transport_ms=$transportMs',
        );
      }
    }
    return result;
  }

  void dispose() {
    _client.close();
  }

  Map<String, dynamic> _mergePrintOptions(
    Map<String, dynamic> body, {
    String? targetHost,
    int? targetPort,
    String? encoding,
    int? codePage,
    String? renderMode,
  }) {
    final merged = <String, dynamic>{...body};
    if (targetHost != null && targetHost.isNotEmpty) {
      merged['target_host'] = targetHost;
    }
    if (targetPort != null) {
      merged['target_port'] = targetPort;
    }
    if (encoding != null && encoding.trim().isNotEmpty) {
      merged['encoding'] = encoding.trim();
    }
    if (codePage != null) {
      merged['codepage'] = codePage;
    }
    if (renderMode != null && renderMode.trim().isNotEmpty) {
      merged['render_mode'] = renderMode.trim();
    }
    return merged;
  }

  /// Like [_send] but returns the JSON body even when `ok` is false.
  /// Used for operator setup endpoints that encode soft failures in the payload.
  Future<Map<String, dynamic>?> _sendSoftOk({
    required String section,
    required String branch,
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      return await _send(
        section: section,
        branch: branch,
        method: method,
        path: path,
        body: body,
        requireOk: false,
      );
    } on LocalPrintServiceException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _send({
    required String section,
    required String branch,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool requireOk = true,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final url = _endpoint(path);
    final watch = Stopwatch()..start();
    final encodedBody = body == null ? null : jsonEncode(body);
    final payloadBytes = encodedBody == null
        ? 0
        : utf8.encode(encodedBody).length;
    final requestType = _requestType(branch);
    final effectiveSection = _sectionForBranch(section, branch);
    final itemCount = _itemCount(body);
    final serviceCount = _serviceCount(body);
    final plateCount = _plateCount(body);
    final tableNo = body?['table_no']?.toString() ?? '-';
    if (branch == 'print_receipt') {
      debugPrint(
        '[RECEIPT_REQUEST_TABLE_LABEL] '
        'table_no=${body?['table_no'] ?? ''} '
        'table_number=${body?['table_number'] ?? ''} '
        'area_table_number=${body?['area_table_number'] ?? ''} '
        'table_area_name=${body?['table_area_name'] ?? ''} '
        'area_name=${body?['area_name'] ?? ''} '
        'display_table_label=${body?['display_table_label'] ?? ''} '
        'table_display_name=${body?['table_display_name'] ?? ''} '
        'table_name=${body?['table_name'] ?? ''}',
      );
    }
    if (effectiveSection == 'Kitchen') {
      _log(
        'Kitchen',
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
      );
    }
    _log(
      effectiveSection,
      'requestStart requestType=$requestType branch=$branch routeUrl=$url method=$method '
      'timeoutMs=${effectiveTimeout.inMilliseconds} payloadBytes=$payloadBytes '
      'payloadSummary=${_payloadSummary(body)} itemCount=$itemCount serviceCount=$serviceCount '
      'plateCount=$plateCount tableNo=$tableNo '
      'browserPreflightLikely=${kIsWeb && method == 'POST'}',
    );

    late final http.Response response;
    try {
      final request = switch (method) {
        'GET' => _client.get(url, headers: _headers),
        'POST' => _client.post(url, headers: _headers, body: encodedBody),
        _ => throw UnsupportedError('Unsupported local print method: $method'),
      };
      response = await request.timeout(effectiveTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _log(
        effectiveSection,
        'requestFail requestType=$requestType branch=$branch routeUrl=$url method=$method '
        'timeoutMs=${effectiveTimeout.inMilliseconds} durationMs=${watch.elapsedMilliseconds} '
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
        error: error,
        stackTrace: stackTrace,
      );
      final timeoutDetails = await _timeoutDetailsForBranch(
        branch: branch,
        body: body,
        timeoutMs: effectiveTimeout.inMilliseconds,
        error: error,
      );
      throw LocalPrintServiceException(
        'Yazici servisi zaman asimina ugradi.',
        details: timeoutDetails,
      );
    } on http.ClientException catch (error, stackTrace) {
      _log(
        effectiveSection,
        'requestFail requestType=$requestType branch=$branch routeUrl=$url method=$method '
        'timeoutMs=${_timeout.inMilliseconds} durationMs=${watch.elapsedMilliseconds} '
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
        error: error,
        stackTrace: stackTrace,
      );
      throw LocalPrintServiceException(
        'Yazici servisine baglanilamadi.',
        details: error,
      );
    } catch (error, stackTrace) {
      _log(
        effectiveSection,
        'requestFail requestType=$requestType branch=$branch routeUrl=$url method=$method '
        'timeoutMs=${_timeout.inMilliseconds} durationMs=${watch.elapsedMilliseconds} '
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
        error: error,
        stackTrace: stackTrace,
      );
      throw LocalPrintServiceException(
        'Yazici servisine istek gonderilemedi.',
        details: error,
      );
    }

    final jsonBody = _tryDecodeJson(response.body);
    final responseOk = jsonBody?['ok'];
    _log(
      effectiveSection,
      'requestSuccess requestType=$requestType branch=$branch routeUrl=$url method=$method '
      'durationMs=${watch.elapsedMilliseconds} responseStatus=${response.statusCode} '
      'responseOk=${responseOk ?? '-'} '
      'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo '
      'allowOrigin=${response.headers['access-control-allow-origin'] ?? '-'} '
      'allowPrivateNetwork=${response.headers['access-control-allow-private-network'] ?? '-'} '
      'postDispatched=${method == 'POST'}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(
        response,
        jsonBody,
        fallback:
            'Yazici servisi ${response.statusCode} durum kodu ile hata dondu.',
      );
      _log(
        effectiveSection,
        'requestFail requestType=$requestType branch=$branch routeUrl=$url method=$method '
        'durationMs=${watch.elapsedMilliseconds} responseStatus=${response.statusCode} '
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
        error: message,
      );
      throw LocalPrintServiceException(
        message,
        statusCode: response.statusCode,
        details: jsonBody,
      );
    }
    if (requireOk && responseOk != true) {
      final message = _errorMessage(
        response,
        jsonBody,
        fallback: 'Yazici servisi gecersiz yanit dondu.',
      );
      _log(
        effectiveSection,
        'requestFail requestType=$requestType branch=$branch routeUrl=$url method=$method '
        'durationMs=${watch.elapsedMilliseconds} responseStatus=${response.statusCode} '
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
        error: message,
      );
      throw LocalPrintServiceException(
        message,
        statusCode: response.statusCode,
        details: jsonBody,
      );
    }
    return jsonBody;
  }

  Future<Map<String, dynamic>> _timeoutDetailsForBranch({
    required String branch,
    required Map<String, dynamic>? body,
    required int timeoutMs,
    required TimeoutException error,
  }) async {
    final details = <String, dynamic>{
      'errorCode': 'client_timeout',
      'timeoutMs': timeoutMs,
      'exception': error.toString(),
    };
    if (branch != 'print_test' && branch != 'print_test_bitmap') {
      return details;
    }

    final printerName = _printerNameFromBody(body);
    details['printer_name'] = printerName;
    details['printer_id'] = body?['printer_id']?.toString();
    details['test_mode'] = body?['test_mode']?.toString() ?? 'escpos_short';
    details['render_mode'] = body?['render_mode']?.toString() ?? 'text';

    if (printerName == null || printerName.isEmpty) {
      return details;
    }

    try {
      final snapshot = await spoolSnapshot(printerName: printerName);
      if (snapshot != null && snapshot.isNotEmpty) {
        details['spool_snapshot'] = snapshot;
        if (snapshot['latest_job_id'] != null) {
          details['spool_latest_job_id'] = snapshot['latest_job_id'];
        }
        if (snapshot['active_job_ids'] is List) {
          details['spool_active_job_ids'] = snapshot['active_job_ids'];
        }
        if (snapshot['job_count'] != null) {
          details['spool_jobs_after_print'] = snapshot['job_count'];
        }
      }
    } catch (_) {
      details['spool_snapshot_error'] = 'spool_snapshot_unavailable';
    }

    return details;
  }

  String? _printerNameFromBody(Map<String, dynamic>? body) {
    if (body == null) return null;
    final embedded = body['printer'];
    if (embedded is Map) {
      final map = Map<String, dynamic>.from(embedded);
      final fromEmbedded =
          map['queue']?.toString() ??
          map['queueName']?.toString() ??
          map['name']?.toString();
      if (fromEmbedded != null && fromEmbedded.trim().isNotEmpty) {
        return fromEmbedded.trim();
      }
    }
    final direct =
        body['printer_name']?.toString() ?? body['printer_queue']?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    return null;
  }

  Uri _endpoint(String path) => _baseUri.replace(path: path);

  void _log(
    String section,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final renderedMessage =
        '$message${error != null ? ' exception=$error' : ''}';
    debugPrint('[LocalPrint][$section] $renderedMessage');
    if (error != null) {
      debugPrint('[LocalPrint][Error] section=$section $renderedMessage');
    }
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _payloadSummary(Map<String, dynamic>? body) {
    if (body == null) return 'none';
    final items = body['items'];
    final itemCount = items is List ? items.length : 0;
    final keys = body.keys.toList(growable: false)..sort();
    return 'keys=${keys.join(",")} items=$itemCount';
  }

  int _itemCount(Map<String, dynamic>? body) {
    final items = body?['items'];
    return items is List ? items.length : 0;
  }

  int _serviceCount(Map<String, dynamic>? body) {
    final items = body?['items'];
    if (items is! List) return 0;
    var count = 0;
    for (final item in items.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final plates = map['plates'];
      final children = map['service_children'];
      if ((plates is List && plates.isNotEmpty) ||
          (children is List && children.isNotEmpty)) {
        count += 1;
      }
    }
    return count;
  }

  int _plateCount(Map<String, dynamic>? body) {
    final items = body?['items'];
    if (items is! List) return 0;
    var count = 0;
    for (final item in items.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final plates = map['plates'];
      if (plates is List) {
        count += plates.length;
      }
    }
    return count;
  }

  String _requestType(String branch) {
    switch (branch) {
      case 'print_receipt':
        return 'receipt';
      case 'print_kitchen':
        return 'kitchen';
      case 'print_test':
        return 'test';
      case 'print_job':
        return 'job';
      default:
        return branch;
    }
  }

  String _sectionForBranch(String fallback, String branch) {
    switch (branch) {
      case 'print_receipt':
        return 'Receipt';
      case 'print_kitchen':
        return 'Kitchen';
      case 'print_test':
        return 'Test';
      case 'print_job':
        return 'Print';
      case 'printers':
        return 'Printers';
      default:
        return fallback;
    }
  }

  Map<String, dynamic>? _tryDecodeJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String _errorMessage(
    http.Response response,
    Map<String, dynamic>? jsonBody, {
    required String fallback,
  }) {
    final errorMessage = jsonBody?['error']?.toString().trim() ?? '';
    if (errorMessage.isNotEmpty) {
      return errorMessage;
    }

    final bodyText = response.body.trim();
    if (bodyText.isNotEmpty) {
      return bodyText;
    }

    return fallback;
  }
}
