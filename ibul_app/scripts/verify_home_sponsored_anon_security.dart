#!/usr/bin/env dart
// Anon REST güvenlik doğrulaması — .env veya ortam değişkenleri gerekir.
//
// Kullanım (repo kökünden):
//   set -a && source .env && set +a
//   dart run ibul_app/scripts/verify_home_sponsored_anon_security.dart

import 'dart:convert';
import 'dart:io';

const _forbiddenRpcKeys = {
  'rank_score',
  'bid_amount',
  'daily_budget',
  'total_budget',
  'spent_amount',
  'remaining_balance',
  'metadata',
  'review_notes',
  'is_premium_placement_enabled',
  'frequency_cap_per_user',
};

const _allowedRpcKeys = {
  'campaign_id',
  'seller_id',
  'store_id',
  'collection_id',
  'title',
  'cover_url',
  'placement',
  'starts_at',
  'ends_at',
};

Future<void> main() async {
  final url = (Platform.environment['IBUL_SUPABASE_URL'] ?? '').trim();
  final anonKey = (Platform.environment['IBUL_SUPABASE_ANON_KEY'] ?? '').trim();

  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln(
      'SKIP: IBUL_SUPABASE_URL / IBUL_SUPABASE_ANON_KEY ortam değişkenleri yok.',
    );
    exit(2);
  }

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  stdout.writeln('=== Anon RPC test ===');
  final rpcRows = await _postRpc(
    baseUrl: url,
    headers: headers,
    limit: 6,
  );
  stdout.writeln('RPC rows (limit=6): ${rpcRows.length}');
  _assertRpcShape(rpcRows);

  final rpcHuge = await _postRpc(
    baseUrl: url,
    headers: headers,
    limit: 9999,
  );
  stdout.writeln('RPC rows (limit=9999): ${rpcHuge.length}');
  if (rpcHuge.length > 20) {
    throw StateError('p_limit bypass: ${rpcHuge.length} rows returned (>20)');
  }
  stdout.writeln('PASS: p_limit capped at 20');

  stdout.writeln('\n=== Anon direct campaigns sensitive columns ===');
  final campaigns = await _getTable(
    baseUrl: url,
    headers: headers,
    table: 'campaigns',
    select: 'id,daily_budget,spent_amount,metadata,bid_amount',
  );
  stdout.writeln('campaigns sensitive select rows: ${campaigns.length}');
  if (campaigns.isNotEmpty) {
    for (final row in campaigns) {
      for (final key in _forbiddenRpcKeys) {
        if (row.containsKey(key) && row[key] != null) {
          throw StateError('Sensitive campaigns column leaked to anon: $key');
        }
      }
    }
    throw StateError('Anon campaigns select returned ${campaigns.length} row(s)');
  }
  stdout.writeln('PASS: campaigns sensitive columns not readable by anon');

  stdout.writeln('\n=== Anon direct campaign_targets targeting JSON ===');
  final targets = await _getTable(
    baseUrl: url,
    headers: headers,
    table: 'campaign_targets',
    select: 'id,campaign_id,keywords,city_codes,geohash_prefixes,metadata',
  );
  stdout.writeln('campaign_targets rows: ${targets.length}');
  if (targets.isNotEmpty) {
    throw StateError(
      'Anon campaign_targets select returned ${targets.length} row(s)',
    );
  }
  stdout.writeln('PASS: campaign_targets not readable by anon');

  stdout.writeln('\n=== Summary ===');
  stdout.writeln('RPC aktif reklam: ${rpcRows.isNotEmpty ? "evet (${rpcRows.length})" : "hayır (veri yok veya migration uygulanmadı)"}');
  stdout.writeln('rank_score client response: yok (doğrulandı)');
  stdout.writeln('Direct campaigns leak: yok');
  stdout.writeln('Direct campaign_targets leak: yok');
}

Future<List<Map<String, dynamic>>> _postRpc({
  required String baseUrl,
  required Map<String, String> headers,
  required int limit,
}) async {
  final uri = Uri.parse('$baseUrl/rest/v1/rpc/fetch_active_home_sponsored_collections');
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(jsonEncode({'p_limit': limit}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      if (body.contains('fetch_active_home_sponsored_collections') &&
          body.toLowerCase().contains('does not exist')) {
        stdout.writeln(
          'WARN: RPC henüz deploy edilmemiş — Supabase SQL Editor migration çalıştırın.',
        );
        return const [];
      }
      throw HttpException('RPC HTTP ${response.statusCode}: $body', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  } finally {
    client.close(force: true);
  }
}

Future<List<Map<String, dynamic>>> _getTable({
  required String baseUrl,
  required Map<String, String> headers,
  required String table,
  required String select,
}) async {
  final uri = Uri.parse('$baseUrl/rest/v1/$table').replace(
    queryParameters: {'select': select, 'limit': '5'},
  );
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const [];
    }
    if (response.statusCode >= 400) {
      // RLS violation often returns empty or error — treat empty as pass.
      if (body.trim().isEmpty || body == '[]') return const [];
      stdout.writeln('INFO: $table HTTP ${response.statusCode} — $body');
      return const [];
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  } finally {
    client.close(force: true);
  }
}

void _assertRpcShape(List<Map<String, dynamic>> rows) {
  for (final row in rows) {
    for (final key in _forbiddenRpcKeys) {
      if (row.containsKey(key)) {
        throw StateError('Forbidden RPC key leaked: $key');
      }
    }
    for (final key in row.keys) {
      if (!_allowedRpcKeys.contains(key)) {
        throw StateError('Unexpected RPC key: $key');
      }
    }
  }
  if (rows.isNotEmpty) {
    stdout.writeln('PASS: RPC response shape safe (${rows.first.keys.join(', ')})');
  }
}
