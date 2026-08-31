import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'mobile_ethernet_printer_service.dart';

/// Cached kitchen TCP endpoint for LAN hot path (no hardcoded IPs).
class LanKitchenTcpEndpoint {
  const LanKitchenTcpEndpoint({required this.host, required this.port});

  final String host;
  final int port;
}

/// Resolves and caches the restaurant's LAN Print Bridge (no hardcoded IPs).
///
/// Priority: warm memory cache → SharedPreferences → short subnet probe :3001.
/// Health is NOT re-checked on every print when the memory cache is warm.
class LanPrintBridgeLocator {
  LanPrintBridgeLocator({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const int bridgePort = 3001;
  static const String _cacheKeyPrefix = 'ibul_lan_print_bridge_v1_';
  static const String _kitchenTcpKeyPrefix = 'ibul_lan_kitchen_tcp_v1_';
  static const Duration connectTimeout = Duration(milliseconds: 200);
  static const Duration healthTimeout = Duration(milliseconds: 350);
  static const Duration discoverBudget = Duration(milliseconds: 450);
  static const Duration warmCacheTtl = Duration(seconds: 45);

  static final Map<String, Uri> _memoryCache = <String, Uri>{};
  static final Map<String, DateTime> _memoryCachedAt = <String, DateTime>{};
  static final Map<String, LanKitchenTcpEndpoint> _kitchenTcpMemory =
      <String, LanKitchenTcpEndpoint>{};

  static String _key(String restaurantId) =>
      '$_cacheKeyPrefix${restaurantId.trim()}';

  static String _kitchenKey(String restaurantId) =>
      '$_kitchenTcpKeyPrefix${restaurantId.trim()}';

  Future<Uri?> resolve(
    String restaurantId, {
    bool allowDiscover = true,
  }) async {
    final id = restaurantId.trim();
    if (id.isEmpty || kIsWeb) return null;

    final memory = _memoryCache[id];
    final memoryAt = _memoryCachedAt[id];
    if (memory != null &&
        memoryAt != null &&
        DateTime.now().difference(memoryAt) <= warmCacheTtl) {
      // Hot path: trust warm cache — no health round-trip.
      return memory;
    }

    if (memory != null && await _tcpOpen(memory.host, memory.hasPort ? memory.port : bridgePort)) {
      _memoryCachedAt[id] = DateTime.now();
      return memory;
    }

    final cached = await _readCache(id);
    if (cached != null &&
        await _tcpOpen(cached.host, cached.hasPort ? cached.port : bridgePort)) {
      _memoryCache[id] = cached;
      _memoryCachedAt[id] = DateTime.now();
      return cached;
    }

    if (!allowDiscover) return null;
    final discovered = await _discoverWithinBudget();
    if (discovered != null) {
      await remember(id, discovered);
      return discovered;
    }
    return null;
  }

  Future<void> remember(String restaurantId, Uri uri) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    final normalized = _normalizeBridgeUri(uri);
    if (normalized == null) return;
    _memoryCache[id] = normalized;
    _memoryCachedAt[id] = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(id), normalized.toString());
    } catch (e) {
      debugPrint('[LanPrintBridgeLocator] cache write failed: $e');
    }
  }

  /// Sync peek — hot path must not wait on SharedPreferences.
  static LanKitchenTcpEndpoint? peekKitchenTcpMemory(String restaurantId) {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    return _kitchenTcpMemory[id];
  }

  Future<LanKitchenTcpEndpoint?> readKitchenTcp(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    final memory = _kitchenTcpMemory[id];
    if (memory != null && memory.host.isNotEmpty) return memory;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kitchenKey(id))?.trim() ?? '';
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final host = decoded['host']?.toString().trim() ?? '';
      final port = int.tryParse(decoded['port']?.toString() ?? '') ?? 9100;
      if (host.isEmpty ||
          host == '127.0.0.1' ||
          host == 'localhost' ||
          host == '::1') {
        return null;
      }
      final endpoint = LanKitchenTcpEndpoint(host: host, port: port);
      _kitchenTcpMemory[id] = endpoint;
      return endpoint;
    } catch (_) {
      return null;
    }
  }

  Future<void> rememberKitchenTcp(
    String restaurantId, {
    required String host,
    required int port,
  }) async {
    final id = restaurantId.trim();
    final normalizedHost = host.trim();
    if (id.isEmpty || normalizedHost.isEmpty) return;
    if (normalizedHost == '127.0.0.1' ||
        normalizedHost == 'localhost' ||
        normalizedHost == '::1') {
      return;
    }
    final safePort = port > 0 ? port : 9100;
    final endpoint =
        LanKitchenTcpEndpoint(host: normalizedHost, port: safePort);
    _kitchenTcpMemory[id] = endpoint;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kitchenKey(id),
        jsonEncode(<String, dynamic>{
          'host': normalizedHost,
          'port': safePort,
        }),
      );
    } catch (e) {
      debugPrint('[LanPrintBridgeLocator] kitchen tcp cache write failed: $e');
    }
  }

  Future<void> clear(String restaurantId) async {
    final id = restaurantId.trim();
    _memoryCache.remove(id);
    _memoryCachedAt.remove(id);
    _kitchenTcpMemory.remove(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(id));
      await prefs.remove(_kitchenKey(id));
    } catch (_) {}
  }

  Future<Uri?> _readCache(String restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(restaurantId))?.trim() ?? '';
      if (raw.isEmpty) return null;
      return _normalizeBridgeUri(Uri.tryParse(raw));
    } catch (_) {
      return null;
    }
  }

  Uri? _normalizeBridgeUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
      return null;
    }
    return Uri(
      scheme: 'http',
      host: uri.host,
      port: uri.hasPort ? uri.port : bridgePort,
    );
  }

  Future<bool> _tcpOpen(String host, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: connectTimeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  Future<bool> _healthOk(Uri base) async {
    try {
      final url = base.replace(path: '/health');
      final response = await _client.get(url).timeout(healthTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      if (map['ok'] != true) return false;
      final service = map['service']?.toString() ?? '';
      return service.contains('ibul') && service.contains('print');
    } catch (_) {
      return false;
    }
  }

  Future<Uri?> _discoverWithinBudget() async {
    final deadline = DateTime.now().add(discoverBudget);
    String? localIp;
    try {
      for (final iface in await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      )) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          localIp = addr.address;
          break;
        }
        if (localIp != null) break;
      }
    } catch (_) {
      return null;
    }
    if (localIp == null) return null;

    final hosts = MobileEthernetScanMath.buildScanHosts(localIp);
    final prioritized = <String>[
      ...hosts.where((h) => h.endsWith('.1') || h.endsWith('.2')),
      ...hosts,
    ];
    final seen = <String>{};
    const concurrency = 24;
    var index = 0;
    while (index < prioritized.length && DateTime.now().isBefore(deadline)) {
      final batch = <Future<Uri?>>[];
      while (batch.length < concurrency && index < prioritized.length) {
        final host = prioritized[index++];
        if (!seen.add(host)) continue;
        batch.add(_probeHost(host));
      }
      final results = await Future.wait(batch);
      for (final uri in results) {
        if (uri != null) return uri;
      }
    }
    return null;
  }

  Future<Uri?> _probeHost(String host) async {
    if (!await _tcpOpen(host, bridgePort)) return null;
    final uri = Uri(scheme: 'http', host: host, port: bridgePort);
    if (await _healthOk(uri)) return uri;
    return null;
  }
}
