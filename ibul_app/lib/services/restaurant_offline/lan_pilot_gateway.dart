import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lan_pilot_contract.dart';

/// Loopback client for the Python bridge SQLite pilot.
///
/// The bridge stays on 127.0.0.1. This client refuses any other host.
class LanPilotGateway {
  LanPilotGateway({
    this.host = '127.0.0.1',
    this.port = 3001,
    this.timeout = const Duration(seconds: 3),
  });

  static LanPilotGateway current = LanPilotGateway();

  final String host;
  final int port;
  final Duration timeout;
  int? printerPort;

  Future<Map<String, dynamic>> submit({
    required String restaurantId,
    required String localOrderId,
    required int tableNumber,
    required String tableLabel,
    required String waiterName,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    if (host != '127.0.0.1' && host != 'localhost') {
      throw StateError(LanPilotContract.bridgeClosedMessage);
    }
    final printer = printerPort;
    final deliver = printer != null && printer > 0;
    final body = <String, dynamic>{
      'restaurant_id': restaurantId,
      'local_order_id': localOrderId,
      'table_number': tableNumber,
      'table_label': tableLabel,
      'waiter_name': waiterName,
      'notes': notes,
      'items': [
        for (final item in items)
          <String, dynamic>{
            'name': item['name'],
            'quantity': item['quantity'],
            'unit_price': item['price'] ?? item['unit_price'],
            'station_id': item['station_id'] ?? '',
          },
      ],
      'deliver_print': deliver,
      'printer': <String, dynamic>{
        'host': '127.0.0.1',
        'port': deliver ? printer : 0,
      },
    };
    try {
      final saved = await _post('/lan/v1/orders', body);
      if (saved['saved'] != true) {
        final reason = saved['error']?.toString().trim() ?? '';
        throw StateError(
          reason.isEmpty
              ? LanPilotContract.notSentMessage
              : '$reason ${LanPilotContract.notSentMessage}',
        );
      }
      return saved;
    } on TimeoutException {
      final found = await query(localOrderId);
      if (found != null) {
        return <String, dynamic>{
          'ok': true,
          'saved': true,
          'duplicate': true,
          'recovered': true,
          'local_order_id': localOrderId,
          'print_status': _printStatus(found),
          'print_job_id': _printJobId(found),
          'printed': _printStatus(found) == 'sent',
        };
      }
      throw StateError(LanPilotContract.notSentMessage);
    } on SocketException {
      throw StateError(LanPilotContract.bridgeClosedMessage);
    }
  }

  Future<Map<String, dynamic>?> query(String localOrderId) async {
    final client = HttpClient();
    try {
      final request = await client
          .get(host, port, '/lan/v1/orders?local_order_id=$localOrderId')
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode == 404) return null;
      if (response.statusCode >= 300) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.post(host, port, path).timeout(timeout);
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join();
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (decoded is! Map) {
        throw StateError(LanPilotContract.notSentMessage);
      }
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }

  String _printStatus(Map<String, dynamic> found) {
    final jobs = found['print_jobs'];
    if (jobs is List && jobs.isNotEmpty && jobs.first is Map) {
      return jobs.first['status']?.toString() ?? 'queued';
    }
    return found['print_status']?.toString() ?? 'queued';
  }

  String _printJobId(Map<String, dynamic> found) {
    final jobs = found['print_jobs'];
    if (jobs is List && jobs.isNotEmpty && jobs.first is Map) {
      return jobs.first['id']?.toString() ?? '';
    }
    return '';
  }
}
