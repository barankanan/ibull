import 'dart:convert';
import 'dart:io';

import 'lan_tls.dart';

/// Local restaurant client. Requests travel only over TLS with a pinned
/// server certificate. There is no bearer session token.
class RestaurantLanClient {
  RestaurantLanClient(
    this.baseUri, {
    required this.securityContext,
    required this.pinnedServerFingerprint,
    this.staffId,
  });

  final Uri baseUri;
  final SecurityContext securityContext;
  final String pinnedServerFingerprint;
  String? staffId;
  int seq = 0;

  Future<Map<String, dynamic>> get(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const <String, String>{},
  }) {
    return _send('POST', path, body: body, headers: headers);
  }

  Future<Map<String, dynamic>> postAuthorized(
    String path,
    Map<String, Object?> body,
  ) {
    final staff = staffId?.trim() ?? '';
    seq += 1;
    return post(path, <String, Object?>{
      'seq': seq,
      'body': <String, Object?>{
        ...body,
        'staff_id': staff,
      },
    });
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final client = HttpClient(context: securityContext);
    client.badCertificateCallback = (certificate, host, port) {
      return LanTlsMaterial.fingerprintOf(certificate) ==
          pinnedServerFingerprint;
    };
    try {
      final request = method == 'GET'
          ? await client.getUrl(baseUri.replace(path: path))
          : await client.postUrl(baseUri.replace(path: path));
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      final map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      map['status'] = response.statusCode;
      return map;
    } on SocketException {
      throw const SocketException(
        'Ana bilgisayar kapalı veya yerel ağa ulaşılamıyor.',
      );
    } on HandshakeException {
      throw const SocketException(
        'Yerel sunucunun sertifikası doğrulanamadı.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
