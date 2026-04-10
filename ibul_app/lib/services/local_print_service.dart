import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:http/http.dart' as http;

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

  Future<Map<String, dynamic>?> health() {
    return _send(
      section: 'Health',
      branch: 'health',
      method: 'GET',
      path: '/health',
    );
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
      _log(
        'Health',
        'checkFail routeUrl=$url durationMs=${watch.elapsedMilliseconds} '
            'statusCode=- timeoutMs=${timeout.inMilliseconds} '
            'failureReason=connection_error',
        error: error,
        stackTrace: stackTrace,
      );
      return LocalPrintHealthStatus(
        isAvailable: false,
        reason: 'connection_error',
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

  Future<void> printTest() async {
    await _send(
      section: 'Receipt',
      branch: 'print_test',
      method: 'POST',
      path: '/print/test',
    );
  }

  Future<void> printReceipt(Map<String, dynamic> payload) async {
    await _send(
      section: 'Receipt',
      branch: 'print_receipt',
      method: 'POST',
      path: '/print/receipt',
      body: payload,
    );
  }

  Future<void> printKitchen(
    Map<String, dynamic> payload, {
    String path = '/print/kitchen',
  }) async {
    await _send(
      section: 'Kitchen',
      branch: 'print_kitchen',
      method: 'POST',
      path: path,
      body: payload,
    );
  }

  void dispose() {
    _client.close();
  }

  Future<Map<String, dynamic>?> _send({
    required String section,
    required String branch,
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
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
    if (effectiveSection == 'Kitchen') {
      _log(
        'Kitchen',
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
      );
    }
    _log(
      effectiveSection,
      'requestStart requestType=$requestType branch=$branch routeUrl=$url method=$method '
      'timeoutMs=${_timeout.inMilliseconds} payloadBytes=$payloadBytes '
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
      response = await request.timeout(_timeout);
    } on TimeoutException catch (error, stackTrace) {
      _log(
        effectiveSection,
        'requestFail requestType=$requestType branch=$branch routeUrl=$url method=$method '
        'timeoutMs=${_timeout.inMilliseconds} durationMs=${watch.elapsedMilliseconds} '
        'itemCount=$itemCount serviceCount=$serviceCount plateCount=$plateCount tableNo=$tableNo',
        error: error,
        stackTrace: stackTrace,
      );
      throw LocalPrintServiceException(
        'Yazici servisi zaman asimina ugradi.',
        details: error,
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
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        responseOk == false) {
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
      );
    }
    return jsonBody;
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
