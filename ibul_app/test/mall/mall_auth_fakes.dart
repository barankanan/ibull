import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/features/mall/auth/mall_auth_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryMallSessionStorage implements MallSessionStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}

String fakeJwt(String userId) {
  String part(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': userId, 'exp': exp})}.sig';
}

/// Minimal GoTrue + PostgREST backend. Every account maps email -> user id;
/// requests are recorded with the bearer token's subject.
class FakeSupabaseBackend {
  FakeSupabaseBackend(this.accounts);

  final Map<String, String> accounts;
  final requests = <({String path, String query, String? bearerSub})>[];
  int logoutCalls = 0;

  late final http.Client httpClient = MockClient(_handle);

  SupabaseClient client() => SupabaseClient(
        'https://fake.supabase.test',
        'anon-key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );

  String? _subject(http.Request request) {
    final header = request.headers['Authorization'] ?? request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    final parts = header.substring(7).split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return (payload as Map)['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _session(String email, String id) => {
        'access_token': fakeJwt(id),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-$id',
        'user': {
          'id': id,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': email,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      };

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    requests.add((path: path, query: request.url.query, bearerSub: _subject(request)));
    const json = {'content-type': 'application/json'};
    if (path.endsWith('/auth/v1/token')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final email = body['email']?.toString() ?? '';
      final id = accounts[email];
      if (id == null || body['password'] != 'secret123') {
        return http.Response(
          jsonEncode({'code': 'invalid_credentials', 'msg': 'Invalid login credentials'}),
          400,
          headers: json,
        );
      }
      return http.Response(jsonEncode(_session(email, id)), 200, headers: json);
    }
    if (path.endsWith('/auth/v1/logout')) {
      logoutCalls++;
      return http.Response('', 204);
    }
    if (path.startsWith('/rest/v1/')) {
      return http.Response('[]', 200, headers: json, request: request);
    }
    return http.Response('{}', 404, headers: json);
  }
}
