import 'dart:convert';

import 'package:http/http.dart' as http;

class LocalPrintBridgeException implements Exception {
  const LocalPrintBridgeException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'LocalPrintBridgeException(statusCode: $statusCode, message: $message)';
}

class LocalPrintReceiptItem {
  const LocalPrintReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  final String name;
  final num qty;
  final num price;
  final num total;

  Map<String, Object> toJson() => {
    'name': name,
    'qty': qty,
    'price': _asMoney(price),
    'total': _asMoney(total),
  };
}

class LocalPrintReceiptPayload {
  const LocalPrintReceiptPayload({
    required this.storeName,
    required this.branch,
    required this.phone,
    required this.tableNo,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    this.footerNote = 'Tesekkur ederiz',
    this.currency = 'TRY',
  });

  final String storeName;
  final String branch;
  final String phone;
  final String tableNo;
  final DateTime dateTime;
  final List<LocalPrintReceiptItem> items;
  final num subtotal;
  final num discount;
  final num grandTotal;
  final String footerNote;
  final String currency;

  Map<String, Object> toJson() => {
    'store_name': storeName,
    'branch': branch,
    'phone': phone,
    'table_no': tableNo,
    'datetime': dateTime.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    'subtotal': _asMoney(subtotal),
    'discount': _asMoney(discount),
    'grand_total': _asMoney(grandTotal),
    'currency': currency,
    'footer_note': footerNote,
  };
}

class LocalPrintBridgeService {
  LocalPrintBridgeService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      baseUri = baseUri ?? Uri.parse('http://127.0.0.1:19001');

  final http.Client _client;
  final Uri baseUri;

  Future<Map<String, dynamic>> health() async {
    final response = await _client.get(_uri('/health'));
    final body = _decodeJson(response);
    if (response.statusCode != 200) {
      throw LocalPrintBridgeException(
        body['error']?.toString() ?? 'Local print bridge health check failed.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> printTest() async {
    return _post('/print/test');
  }

  Future<Map<String, dynamic>> printReceipt(
    LocalPrintReceiptPayload payload,
  ) async {
    return _post('/print/receipt', body: payload.toJson());
  }

  void dispose() {
    _client.close();
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, Object>? body,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
    final jsonBody = _decodeJson(response);
    if (response.statusCode != 200) {
      throw LocalPrintBridgeException(
        jsonBody['error']?.toString() ?? 'Local print bridge request failed.',
        statusCode: response.statusCode,
      );
    }
    return jsonBody;
  }

  Uri _uri(String path) => baseUri.replace(path: path);

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const LocalPrintBridgeException(
      'Unexpected JSON response from local print bridge.',
    );
  }
}

String _asMoney(num value) => value.toStringAsFixed(2);
