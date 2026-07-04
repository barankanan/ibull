#!/usr/bin/env dart
// Anon RLS smoke — ürün görünürlüğü. Flutter bağımlılığı yok.
//
//   set -a && source ../.env && set +a
//   dart run scripts/smoke_product_rls_anon.dart

import 'dart:convert';
import 'dart:io';

const _approvedApprovalTokens = {
  'approved',
  'onaylandi',
  'onaylandı',
  'onayli',
  'onaylı',
};

const _activeStatusTokens = {'aktif', 'active'};

String _normalizeToken(String? value) {
  return (value?.trim().toLowerCase() ?? '')
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

bool _isApprovedApproval(String? value) {
  final raw = value?.trim().toLowerCase() ?? '';
  if (raw.isEmpty) return false;
  return _approvedApprovalTokens.contains(raw) ||
      _approvedApprovalTokens.contains(_normalizeToken(raw));
}

bool _isPublicVisibleRow(Map<String, dynamic> row) {
  final status = _normalizeToken(row['status']?.toString());
  if (!_activeStatusTokens.contains(status)) return false;
  return _isApprovedApproval(row['approval_status']?.toString()) ||
      _isApprovedApproval(row['admin_approval_status']?.toString());
}

Future<void> main() async {
  final url = (Platform.environment['IBUL_SUPABASE_URL'] ?? '').trim();
  final anonKey = (Platform.environment['IBUL_SUPABASE_ANON_KEY'] ?? '').trim();

  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln('SKIP: IBUL_SUPABASE_URL / IBUL_SUPABASE_ANON_KEY yok');
    exit(2);
  }

  var passed = 0;
  var failed = 0;
  void pass(String m) {
    passed++;
    stdout.writeln('PASS: $m');
  }

  void fail(String m) {
    failed++;
    stderr.writeln('FAIL: $m');
  }

  stdout.writeln('=== Product RLS Anon Smoke ===\n');
  final client = HttpClient();
  final headers = <String, String>{
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
  };

  try {
    final schemaProbe = await _get(
      client,
      '$url/rest/v1/products?select=id,status,approval_status,admin_approval_status&limit=1',
      headers,
    );
    if (schemaProbe.status == 400 &&
        schemaProbe.body.contains('approval_status')) {
      fail(
        'approval_status kolonu yok — önce SUPABASE_PUBLIC_PRODUCT_VISIBILITY_FIX.sql çalıştırın',
      );
      stdout.writeln('\n=== $passed geçti, $failed başarısız ===');
      exit(1);
    }

    final activeApproved = await _get(
      client,
      '$url/rest/v1/products?select=id,status,approval_status,admin_approval_status'
      '&status=eq.Aktif&approval_status=eq.approved&limit=3',
      headers,
    );
    if (activeApproved.status == 200) {
      final rows = (jsonDecode(activeApproved.body) as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (rows.every(_isPublicVisibleRow)) {
        pass(
          'Anon Aktif+approved okuyabiliyor (${rows.length} örnek)',
        );
      } else {
        fail('Aktif+approved sorgusu geçersiz satır döndü');
      }
    } else {
      fail('Aktif+approved okuma HTTP ${activeApproved.status}');
    }

    final activeSample = await _get(
      client,
      '$url/rest/v1/products?select=id,status,approval_status,admin_approval_status'
      '&status=eq.Aktif&limit=25',
      headers,
    );
    if (activeSample.status == 200) {
      final rows = (jsonDecode(activeSample.body) as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final leaks = rows.where((row) => !_isPublicVisibleRow(row)).toList();
      if (leaks.isEmpty) {
        pass('Anon Aktif listesinde onaysız ürün yok (${rows.length} örnek)');
      } else {
        fail(
          'Anon Aktif listesinde ${leaks.length} onaysız ürün sızıntısı '
          '(ör. id=${leaks.first['id']})',
        );
      }
    } else {
      fail('Aktif örnek listesi HTTP ${activeSample.status}');
    }

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Aktif + approval_status=null',
      query: 'status=eq.Aktif&approval_status=is.null&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Aktif + approval_status=pending_approval',
      query:
          'status=eq.Aktif&approval_status=eq.pending_approval&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Aktif + admin_approval_status=pending_approval',
      query:
          'status=eq.Aktif&admin_approval_status=eq.pending_approval&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Aktif + approval_status=rejected',
      query: 'status=eq.Aktif&approval_status=eq.rejected&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Pasif + approval_status=approved',
      query: 'status=eq.Pasif&approval_status=eq.approved&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Taslak + approval_status=approved',
      query: 'status=eq.Taslak&approval_status=eq.approved&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCannotReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Aktif + approval_status=rejected',
      query: 'status=eq.Aktif&approval_status=eq.rejected&limit=5',
      pass: pass,
      fail: fail,
    );

    await _expectAnonCanReadFiltered(
      client: client,
      url: url,
      headers: headers,
      label: 'Aktif + approval_status=approved',
      query: 'status=eq.Aktif&approval_status=eq.approved&limit=3',
      pass: pass,
      fail: fail,
    );

    final draft = await _get(
      client,
      '$url/rest/v1/products?select=id&status=eq.Taslak&limit=5',
      headers,
    );
    if (draft.status == 200) {
      final rows = jsonDecode(draft.body) as List;
      if (rows.isEmpty) {
        pass('Anon Taslak ürün göremiyor');
      } else {
        fail('Anon Taslak görebiliyor: ${rows.length} kayıt');
      }
    } else {
      pass('Anon Taslak erişimi kısıtlı (HTTP ${draft.status})');
    }

    final passive = await _get(
      client,
      '$url/rest/v1/products?select=id&status=eq.Pasif&limit=5',
      headers,
    );
    if (passive.status == 200) {
      final rows = jsonDecode(passive.body) as List;
      if (rows.isEmpty) {
        pass('Anon Pasif ürün göremiyor');
      } else {
        fail('Anon Pasif görebiliyor: ${rows.length}');
      }
    } else {
      pass('Anon Pasif erişimi kısıtlı');
    }

    final pendingApproval = await _get(
      client,
      '$url/rest/v1/products?select=id&status=eq.pending_approval&limit=5',
      headers,
    );
    if (pendingApproval.status == 200) {
      final rows = jsonDecode(pendingApproval.body) as List;
      if (rows.isEmpty) {
        pass('Anon pending_approval ürün göremiyor');
      } else {
        fail('Anon pending_approval görebiliyor: ${rows.length} kayıt');
      }
    } else {
      pass(
        'Anon pending_approval erişimi kısıtlı (HTTP ${pendingApproval.status})',
      );
    }

    final rejected = await _get(
      client,
      '$url/rest/v1/products?select=id&status=eq.rejected&limit=5',
      headers,
    );
    if (rejected.status == 200) {
      final rows = jsonDecode(rejected.body) as List;
      if (rows.isEmpty) {
        pass('Anon rejected ürün göremiyor');
      } else {
        fail('Anon rejected görebiliyor: ${rows.length}');
      }
    } else {
      pass('Anon rejected erişimi kısıtlı');
    }

    final patch = await _patch(
      client,
      '$url/rest/v1/products?id=eq.00000000-0000-0000-0000-000000000001',
      headers,
      '{"name":"rls-smoke"}',
      prefer: 'return=representation',
    );
    if (patch.status == 401 || patch.status == 403) {
      pass('Anon başka ürünü düzenleyemiyor (HTTP ${patch.status})');
    } else if (patch.status == 200 || patch.status == 204) {
      final rows = patch.body.trim().isEmpty
          ? <dynamic>[]
          : jsonDecode(patch.body) as List;
      if (rows.isEmpty) {
        pass('Anon PATCH 0 satır güncelledi (RLS veya kayıt yok)');
      } else {
        fail('Anon ürün güncelledi: ${rows.length} satır');
      }
    } else {
      pass('Anon PATCH engellendi (HTTP ${patch.status})');
    }
  } catch (e) {
    fail('RLS hata: $e');
  } finally {
    client.close();
  }

  stdout.writeln('\n=== $passed geçti, $failed başarısız ===');
  exit(failed > 0 ? 1 : 0);
}

Future<void> _expectAnonCanReadFiltered({
  required HttpClient client,
  required String url,
  required Map<String, String> headers,
  required String label,
  required String query,
  required void Function(String message) pass,
  required void Function(String message) fail,
}) async {
  final response = await _get(
    client,
    '$url/rest/v1/products?select=id,status,approval_status,admin_approval_status&$query',
    headers,
  );
  if (response.status == 200) {
    final rows = (jsonDecode(response.body) as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (rows.isEmpty) {
      fail('Anon $label okuyamıyor (0 kayıt — backfill/onay gerekebilir)');
    } else if (rows.every(_isPublicVisibleRow)) {
      pass('Anon $label okuyabiliyor (${rows.length} örnek)');
    } else {
      fail('Anon $label geçersiz satır döndü');
    }
  } else {
    fail('Anon $label okuma HTTP ${response.status}');
  }
}

Future<void> _expectAnonCannotReadFiltered({
  required HttpClient client,
  required String url,
  required Map<String, String> headers,
  required String label,
  required String query,
  required void Function(String message) pass,
  required void Function(String message) fail,
}) async {
  final response = await _get(
    client,
    '$url/rest/v1/products?select=id,status,approval_status,admin_approval_status&$query',
    headers,
  );
  if (response.status == 200) {
    final rows = jsonDecode(response.body) as List;
    if (rows.isEmpty) {
      pass('Anon $label göremiyor');
    } else {
      fail('Anon $label görebiliyor: ${rows.length} kayıt');
    }
  } else {
    pass('Anon $label erişimi kısıtlı (HTTP ${response.status})');
  }
}

Future<({int status, String body})> _get(
  HttpClient client,
  String url,
  Map<String, String> headers,
) async {
  final req = await client.getUrl(Uri.parse(url));
  headers.forEach(req.headers.set);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return (status: res.statusCode, body: body);
}

Future<({int status, String body})> _patch(
  HttpClient client,
  String url,
  Map<String, String> headers,
  String payload, {
  String prefer = 'return=minimal',
}) async {
  final req = await client.patchUrl(Uri.parse(url));
  headers.forEach(req.headers.set);
  req.headers.set('Prefer', prefer);
  req.headers.contentType = ContentType.json;
  req.write(payload);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  return (status: res.statusCode, body: body);
}
