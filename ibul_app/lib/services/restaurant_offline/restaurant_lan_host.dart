import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/secure_local_store.dart';
import 'print_evidence.dart';
import 'restaurant_local_cache_service.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_local_print_queue_service.dart';
import 'restaurant_offline_models.dart';
import 'lan_center_discovery.dart';
import 'lan_channel.dart';
import 'lan_pairing_guard.dart';
import 'lan_pilot_contract.dart';
import 'lan_pilot_gateway.dart';
import 'lan_cert_material.dart';
import 'lan_tls.dart';
import '../local_print_barrier.dart';
import '../staff_login_policy.dart';
export 'restaurant_lan_client.dart';

typedef LanPhysicalPrint = Future<void> Function(RestaurantLocalOrderRecord order);

/// The print bridge address belongs to the desktop that runs the Python
/// bridge. A phone or tablet must not open that bridge on its own loopback.
bool deviceMayRunLocalPrintBridge(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class RestaurantLanDevice {
  const RestaurantLanDevice({
    required this.deviceId,
    required this.pairedAt,
    required this.staffId,
    this.branchId,
    this.revoked = false,
    this.staffVerified = false,
    this.verifiedAt,
    this.expiresAt,
  });

  final String deviceId;
  final DateTime pairedAt;
  final String staffId;
  final String? branchId;
  final bool revoked;
  final bool staffVerified;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;

  RestaurantLanDevice copy({
    bool? revoked,
    bool? staffVerified,
    DateTime? verifiedAt,
    DateTime? expiresAt,
    bool clearVerification = false,
  }) {
    return RestaurantLanDevice(
      deviceId: deviceId,
      pairedAt: pairedAt,
      staffId: staffId,
      branchId: branchId,
      revoked: revoked ?? this.revoked,
      staffVerified: clearVerification ? false : staffVerified ?? this.staffVerified,
      verifiedAt: clearVerification ? null : verifiedAt ?? this.verifiedAt,
      expiresAt: clearVerification ? null : expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'device_id': deviceId,
    'paired_at': pairedAt.toUtc().toIso8601String(),
    'staff_id': staffId,
    if (branchId != null) 'branch_id': branchId,
    'revoked': revoked,
    'staff_verified': staffVerified,
    if (verifiedAt != null) 'verified_at': verifiedAt!.toUtc().toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
  };

  factory RestaurantLanDevice.fromJson(Map<String, dynamic> json) {
    return RestaurantLanDevice(
      deviceId: json['device_id']?.toString() ?? '',
      pairedAt: DateTime.tryParse(json['paired_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      staffId: json['staff_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      revoked: json['revoked'] == true,
      staffVerified: json['staff_verified'] == true,
      verifiedAt: DateTime.tryParse(json['verified_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

/// Enrollment records stay on the owner machine. Tests use the memory store.
abstract class LanEnrollmentStore {
  Future<dynamic> readJson(String key);
  Future<void> writeJson(String key, dynamic value);
}

class SecureLanEnrollmentStore implements LanEnrollmentStore {
  SecureLanEnrollmentStore([SecureLocalStore? store])
      : _store = store ?? SecureLocalStore.instance;

  final SecureLocalStore _store;

  @override
  Future<dynamic> readJson(String key) => _store.readJson(key);

  @override
  Future<void> writeJson(String key, dynamic value) =>
      _store.writeJson(key, value);
}

class MemoryLanEnrollmentStore implements LanEnrollmentStore {
  final Map<String, dynamic> _values = <String, dynamic>{};

  @override
  Future<dynamic> readJson(String key) async => _values[key];

  @override
  Future<void> writeJson(String key, dynamic value) async {
    _values[key] = jsonDecode(jsonEncode(value));
  }
}

class _LanBodyRejected implements Exception {
  const _LanBodyRejected();
}

class RestaurantLanHost {
  RestaurantLanHost({
    required this.restaurantId,
    RestaurantLocalOrderQueueService? orders,
    RestaurantLocalPrintQueueService? printQueue,
    RestaurantLocalCacheService? cache,
    this.onPhysicalPrint,
    this.enablePhysicalPrint = false,
    this.stationsOverride,
    this.tablesOverride,
    this.productsOverride,
    this.branchId,
    this.operatorFingerprint,
    this.certificateDirectory,
    this.machineId,
    this.printBridgeUri,
    this.staffStillAuthorized,
    LanEnrollmentStore? deviceStore,
    this.deviceGrantTtl = const Duration(minutes: 15),
    DateTime Function()? clock,
    Random? random,
  }) : _orders = orders ??
           RestaurantLocalOrderQueueService(
             journalDirectory: (certificateDirectory?.trim().isNotEmpty ?? false)
                 ? Directory(certificateDirectory!.trim())
                 : null,
           ),
       _printQueue = printQueue,
       _cache = cache ?? RestaurantLocalCacheService(),
       _deviceStore = deviceStore ?? SecureLanEnrollmentStore(),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final String restaurantId;
  final LanPhysicalPrint? onPhysicalPrint;
  final bool enablePhysicalPrint;
  final List<Map<String, dynamic>>? stationsOverride;
  final List<Map<String, dynamic>>? tablesOverride;
  final List<Map<String, dynamic>>? productsOverride;
  final String? branchId;
  final String? operatorFingerprint;
  final String? certificateDirectory;
  final String? machineId;
  final Uri? printBridgeUri;
  final Map<String, int> lastStageMicros = <String, int>{};
  final Future<StaffProbe> Function(String staffId)? staffStillAuthorized;
  final LanEnrollmentStore _deviceStore;
  final Duration deviceGrantTtl;
  final RestaurantLocalOrderQueueService _orders;
  final RestaurantLocalPrintQueueService? _printQueue;
  final RestaurantLocalCacheService _cache;
  final DateTime Function() _clock;
  final Random _random;

  HttpServer? _server;
  HttpServer? _browserServer;
  String? boundAddress;
  String? _code;
  DateTime? _codeExpires;
  String? _browserCode;
  DateTime? _browserCodeExpires;
  final Map<String, _BrowserGrant> _browserGrants = <String, _BrowserGrant>{};
  LanAuthorityLock? _authorityLock;
  final Map<String, PairingAttemptGuard> _pairingAttempts =
      <String, PairingAttemptGuard>{};
  final Map<String, RestaurantLanDevice> _devices = <String, RestaurantLanDevice>{};
  final Map<String, int> _inboundSeq = <String, int>{};
  final Map<String, List<DateTime>> _orderTimes = <String, List<DateTime>>{};

  bool get listening => _server != null;
  int get port => _server?.port ?? 0;
  int get browserPort => _browserServer?.port ?? 0;
  int get deviceCount =>
      _devices.values.where((device) => !device.revoked).length;
  List<RestaurantLanDevice> get devices => _devices.values.toList(growable: false);

  Future<void> start({
    required SecurityContext securityContext,
    InternetAddress? address,
    int port = 0,
  }) async {
    final selected = address ?? InternetAddress.loopbackIPv4;
    final listen = decideLanListen(selected);
    if (!listen.allowed) {
      throw StateError(listen.error ?? 'LAN adresi reddedildi.');
    }
    if (_server != null) return;
    final directory = certificateDirectory?.trim() ?? '';
    if (directory.isNotEmpty) {
      final lock = LanAuthorityLock(
        File('$directory/authority-$restaurantId.lock'),
      );
      if (!await lock.acquire()) {
        throw StateError(
          'Bu restoranda başka bir sipariş otoritesi çalışıyor.',
        );
      }
      _authorityLock = lock;
    }
    await _loadDevices();
    _server = await HttpServer.bindSecure(
      selected,
      port,
      securityContext,
      requestClientCertificate: true,
    );
    boundAddress = selected.address;
    _server!.idleTimeout = const Duration(seconds: 12);
    _server!.listen(_handle, onError: (_, _) {});
    RestaurantLanHostRegistry.current = this;
  }

  /// Development-only browser entry. The seller app does not call this.
  /// Native waiters keep the mTLS port.
  Future<void> startBrowserGate({
    required SecurityContext securityContext,
    InternetAddress? address,
    int port = 0,
  }) async {
    if (_browserServer != null) return;
    final selected = address ?? InternetAddress.loopbackIPv4;
    final listen = decideLanListen(selected);
    if (!listen.allowed) {
      throw StateError(listen.error ?? 'LAN adresi reddedildi.');
    }
    _browserServer = await HttpServer.bindSecure(
      selected,
      port,
      securityContext,
      requestClientCertificate: false,
    );
    _browserServer!.listen(_handleBrowser, onError: (_, _) {});
  }

  Future<void> stop() async {
    final server = _server;
    final browser = _browserServer;
    _server = null;
    _browserServer = null;
    if (identical(RestaurantLanHostRegistry.current, this)) {
      RestaurantLanHostRegistry.current = null;
    }
    await server?.close(force: true);
    await browser?.close(force: true);
    await _authorityLock?.release();
    _authorityLock = null;
    boundAddress = null;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path == '/lan/discover' && request.method == 'GET') {
        final fingerprint = await _announcedFingerprint();
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'service': 'ibul-lan',
          'pairing_required': true,
          'restaurant_id': restaurantId,
          'machine_id': machineId ?? '',
          'listen_address': boundAddress,
          'port': port,
          if (fingerprint.isNotEmpty) 'fingerprint': fingerprint,
        });
        return;
      }
      if (path == '/lan/pair/issue' && request.method == 'POST') {
        final fingerprint = _fingerprint(request);
        if (!_operatorConsole(request) ||
            fingerprint == null ||
            operatorFingerprint == null ||
            fingerprint != operatorFingerprint) {
          await _send(request, 403, <String, Object?>{
            'ok': false,
            'error': 'Eşleştirme yalnız bu bilgisayardaki işletme sertifikasıyla açılır.',
          });
          return;
        }
        _code = newPairingSecret(_random);
        _codeExpires = _clock().add(PairingAttemptGuard.codeTtl);
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'code': _code,
          'expires_at': _codeExpires!.toUtc().toIso8601String(),
        });
        return;
      }
      if (path == '/lan/browser/issue' && request.method == 'POST') {
        final fingerprint = _fingerprint(request);
        if (!_operatorConsole(request) ||
            fingerprint == null ||
            operatorFingerprint == null ||
            fingerprint != operatorFingerprint) {
          await _send(request, 403, <String, Object?>{
            'ok': false,
            'error': 'Tarayıcı eşleştirmesi yalnız bu bilgisayardan açılır.',
          });
          return;
        }
        _browserCode = newPairingSecret(_random);
        _browserCodeExpires = _clock().add(PairingAttemptGuard.codeTtl);
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'code': _browserCode,
          'expires_at': _browserCodeExpires!.toUtc().toIso8601String(),
          'browser_port': browserPort,
        });
        return;
      }
      if (path == '/lan/pair/redeem' && request.method == 'POST') {
        final body = await _readBody(request);
        final client = (request.connectionInfo?.remoteAddress.address ?? '').trim();
        final guard = _pairingAttempts.putIfAbsent(client, PairingAttemptGuard.new);
        if (!guard.allow(_clock())) {
          await _send(request, 429, <String, Object?>{
            'ok': false,
            'error': 'Çok fazla eşleştirme denemesi. Kısa süre bekleyin.',
          });
          return;
        }
        final presentedFingerprint = _fingerprint(request);
        final staffId = body['staff_id']?.toString().trim() ?? '';
        final presented = body['code']?.toString().trim() ?? '';
        final csr = body['csr']?.toString() ?? '';
        final requestedRestaurant = body['restaurant_id']?.toString().trim() ?? '';
        final expires = _codeExpires;
        final fresh = expires != null && _clock().isBefore(expires);
        final code = _code ?? '';
        final revoked = presentedFingerprint != null &&
            _devices[presentedFingerprint]?.revoked == true;
        final wrongRestaurant = requestedRestaurant.isNotEmpty &&
            requestedRestaurant != restaurantId;
        final csrLooksValid = csr.length >= 32 &&
            csr.length <= 8192 &&
            csr.contains('BEGIN CERTIFICATE REQUEST') &&
            csr.contains('END CERTIFICATE REQUEST');
        if (!fresh ||
            code.isEmpty ||
            !pairingSecretMatches(code, presented) ||
            staffId.isEmpty ||
            !csrLooksValid ||
            revoked ||
            wrongRestaurant ||
            certificateDirectory == null) {
          guard.recordFailure(_clock());
          await _send(request, revoked || wrongRestaurant ? 403 : 401, <String, Object?>{
            'ok': false,
            'error': revoked
                ? 'Cihaz iptal edildi.'
                : wrongRestaurant
                    ? 'Bu cihazın restoran yetkisi yok.'
                    : 'Eşleştirme kodu geçersiz veya süresi doldu.',
          });
          return;
        }
        guard.recordSuccess();
        final requestedBranch = body['branch_id']?.toString().trim() ?? '';
        if (branchId != null &&
            branchId!.isNotEmpty &&
            requestedBranch.isNotEmpty &&
            requestedBranch != branchId) {
          await _send(request, 403, <String, Object?>{
            'ok': false,
            'error': 'Bu cihazın şube yetkisi yok.',
          });
          return;
        }
        _code = null;
        _codeExpires = null;
        final signed = await _signCsr(csr);
        if (signed == null || _devices[signed.fingerprint]?.revoked == true) {
          await _send(request, 401, <String, Object?>{
            'ok': false,
            'error': 'Cihaz sertifikası doğrulanamadı.',
          });
          return;
        }
        _devices[signed.fingerprint] = RestaurantLanDevice(
          deviceId: signed.fingerprint,
          pairedAt: _clock(),
          staffId: staffId,
          branchId: branchId,
        );
        _inboundSeq[signed.fingerprint] = 0;
        await _persistDevices();
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'restaurant_id': restaurantId,
          'staff_id': staffId,
          'certificate': signed.certificate,
        });
        return;
      }
      if (path == '/lan/revoke' && request.method == 'POST') {
        final fingerprint = _fingerprint(request);
        if (!_operatorConsole(request) ||
            fingerprint == null ||
            fingerprint != operatorFingerprint) {
          await _send(request, 403, <String, Object?>{'ok': false});
          return;
        }
        final body = await _readBody(request);
        final deviceId = body['device_id']?.toString().trim() ?? '';
        final current = _devices[deviceId];
        if (current != null) {
          _devices[deviceId] = current.copy(revoked: true);
          await _persistDevices();
        }
        for (final grant in _browserGrants.values) {
          if (grant.deviceId == deviceId) grant.revoked = true;
        }
        await _send(request, 200, <String, Object?>{'ok': true});
        return;
      }
      final fingerprint = _fingerprint(request);
      final paired = fingerprint == null ? null : _devices[fingerprint];
      if (fingerprint == null || paired == null || paired.revoked) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': 'Cihaz eşleşmesi yok veya iptal edildi.',
        });
        return;
      }
      final staffError = await _staffGrantError(paired, fingerprint);
      if (staffError != null) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': staffError,
        });
        return;
      }
      final envelope = await _readBody(request);
      final seq = envelope['seq'];
      final inner = envelope['body'];
      if (seq is! int || seq <= (_inboundSeq[fingerprint] ?? 0) || inner is! Map) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': 'Tekrarlanan veya sırasız istek reddedildi.',
        });
        return;
      }
      final body = Map<String, dynamic>.from(inner);
      final staffId = body['staff_id']?.toString().trim() ?? '';
      if (staffId.isEmpty || staffId != paired.staffId) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': 'Personel yetkisi doğrulanamadı.',
        });
        return;
      }
      _inboundSeq[fingerprint] = seq;
      await _persistDevices();
      final deviceId = fingerprint;
      if ((path == '/lan/tables' || path == '/lan/products') && request.method == 'POST') {
        if (path == '/lan/tables') {
          final tables = (tablesOverride ?? (await _cache.read(restaurantId))?.tables)
              ?.map(stripLanSecrets)
              .toList(growable: false);
          if (tables == null) {
            await _send(request, 409, <String, Object?>{
              'ok': false,
              'error': 'Ana bilgisayarda masa listesi yok.',
            });
            return;
          }
          await _send(request, 200, <String, Object?>{'ok': true, 'tables': tables});
          return;
        }
        final products = (productsOverride ?? (await _cache.read(restaurantId))?.products)
            ?.map(stripLanSecrets)
            .toList(growable: false);
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'products': products ?? const <Map<String, dynamic>>[],
        });
        return;
      }
      if (path == '/lan/floor' && request.method == 'POST') {
        final rows = await _orders.list(restaurantId);
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'orders': <Map<String, Object?>>[
            for (final order in rows)
              <String, Object?>{
                'local_order_id': order.localOrderId,
                'table_number': order.tableNumber,
                'table_name': order.tableName,
                'items': order.items,
                'total': order.total,
                'print_status': order.printStatus,
                'sync_status': order.syncStatus.name,
              },
          ],
        });
        return;
      }
      if (path == '/lan/orders' && request.method == 'POST') {
        final remote = request.connectionInfo?.remoteAddress.address ?? '';
        if (!_allowOrder(remote)) {
          await _send(request, 429, <String, Object?>{
            'ok': false,
            'saved': false,
            'error': 'Çok fazla sipariş denemesi. Kısa süre bekleyin.',
          });
          return;
        }
        await _orders.transaction(
          () => _acceptOrder(request, body, deviceId),
        );
        return;
      }
      if (path == '/lan/payments' || path == '/lan/close' || path == '/lan/transfer') {
        await _send(request, 403, <String, Object?>{
          'ok': false,
          'saved': false,
          'error': 'Ödeme, hesap kapatma ve masa aktarımı yerel ağda kapalı.',
        });
        return;
      }
      await _send(request, 404, <String, Object?>{'ok': false, 'saved': false});
    } on _LanBodyRejected {
      await _send(request, 413, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'İstek çok büyük. Sipariş kaydedilmedi.',
      });
    } on TimeoutException {
      await _send(request, 408, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'İstek zaman aşımına uğradı. Sipariş kaydedilmedi.',
      });
    } catch (error) {
      await _send(request, 500, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Yerel sunucu isteği tamamlayamadı.',
      });
    }
  }

  Future<void> _acceptOrder(
    HttpRequest request,
    Map<String, dynamic> body,
    String deviceId,
  ) async {
    final saveWatch = Stopwatch()..start();
    final requestedRestaurant = body['restaurant_id']?.toString().trim() ?? '';
    if (requestedRestaurant.isNotEmpty && requestedRestaurant != restaurantId) {
      await _send(request, 403, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Bu cihazın restoran yetkisi yok.',
      });
      return;
    }
    final requestedBranch = body['branch_id']?.toString().trim() ?? '';
    if (branchId != null &&
        branchId!.isNotEmpty &&
        requestedBranch.isNotEmpty &&
        requestedBranch != branchId) {
      await _send(request, 403, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Bu cihazın şube yetkisi yok.',
      });
      return;
    }
    final stationId = body['station_id']?.toString().trim() ?? '';
    final cache = stationsOverride == null || productsOverride == null
        ? await _cache.read(restaurantId)
        : null;
    final allowed = (stationsOverride ?? cache?.stations ?? const <Map<String, dynamic>>[])
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (allowed.isNotEmpty && stationId.isNotEmpty && !allowed.contains(stationId)) {
      await _send(request, 403, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Bu istasyon bu cihaza açık değil.',
      });
      return;
    }
    final catalog = productsOverride ?? cache?.products ?? const <Map<String, dynamic>>[];
    final priced = _pricedItems(_items(body['items']), catalog, stationId);
    if (priced.error != null) {
      await _send(request, 409, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': priced.error,
      });
      return;
    }
    final revision = body['revision']?.toString().trim().isNotEmpty == true
        ? body['revision'].toString().trim()
        : '1';
    final revisionNumber = int.tryParse(revision);
    if (revisionNumber == null || revisionNumber < 1) {
      await _send(request, 400, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Sipariş revizyonu geçersiz.',
      });
      return;
    }
    final now = _clock();
    var order = RestaurantLocalOrderRecord(
      localOrderId: body['local_order_id']?.toString().trim() ?? '',
      restaurantId: restaurantId,
      tableId: body['table_number']?.toString() ?? '',
      tableName: body['table_name']?.toString() ?? '',
      tableNumber: int.tryParse(body['table_number']?.toString() ?? '') ?? 0,
      waiterId: deviceId,
      waiterName: body['waiter_name']?.toString() ?? '',
      items: priced.items,
      notes: body['notes']?.toString() ?? '',
      total: priced.total,
      stationGroups: <Map<String, dynamic>>[
        <String, dynamic>{'station_id': stationId, 'revision': revision},
      ],
      printStatus: 'pending',
      syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
      createdAt: now,
      updatedAt: now,
    );
    if (order.localOrderId.isEmpty) {
      await _send(request, 400, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Sipariş kimliği yok. Kayıt yazılmadı.',
      });
      return;
    }
    final before = await _orders.list(restaurantId);
    RestaurantLocalOrderRecord? previous;
    for (final row in before) {
      if (row.localOrderId == order.localOrderId) previous = row;
    }
    if (previous != null) {
      final previousRevision = int.tryParse(_revisionOf(previous)) ?? 1;
      if (revisionNumber == previousRevision) {
        if (_contentKey(previous) != _contentKey(order)) {
          await _send(request, 409, <String, Object?>{
            'ok': false,
            'saved': false,
            'conflict': true,
            'error': 'Aynı sipariş kimliği farklı içerikle geldi. Üzerine yazılmadı.',
          });
          return;
        }
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'saved': true,
          'duplicate': true,
          'printed': false,
          'local_order_id': order.localOrderId,
        });
        return;
      }
      if (revisionNumber < previousRevision) {
        await _send(request, 409, <String, Object?>{
          'ok': false,
          'saved': false,
          'conflict': true,
          'error': 'Eski revizyon mevcut siparişin üzerine yazılamaz.',
        });
        return;
      }
      final merged = <Map<String, dynamic>>[
        ...previous.items.map(Map<String, dynamic>.from),
      ];
      for (final item in order.items) {
        final key = _lineKey(item);
        if (!merged.any((row) => _lineKey(row) == key)) merged.add(item);
      }
      order = RestaurantLocalOrderRecord(
        localOrderId: previous.localOrderId,
        restaurantId: previous.restaurantId,
        tableId: previous.tableId,
        tableName: previous.tableName,
        tableNumber: previous.tableNumber,
        waiterId: previous.waiterId,
        waiterName: previous.waiterName,
        items: merged,
        notes: order.notes.isNotEmpty ? order.notes : previous.notes,
        total: merged.fold<double>(0, (sum, item) {
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
          return sum + price * qty;
        }),
        stationGroups: <Map<String, dynamic>>[
          ...previous.stationGroups,
          <String, dynamic>{'station_id': stationId, 'revision': revision},
        ],
        printStatus: previous.printStatus,
        syncStatus: previous.syncStatus,
        createdAt: previous.createdAt,
        updatedAt: now,
        remoteOrderId: previous.remoteOrderId,
        syncError: previous.syncError,
      );
      await _orders.update(restaurantId: restaurantId, order: order);
      final updated = await _orders.list(restaurantId);
      if (!updated.any((row) => row.localOrderId == order.localOrderId)) {
        await _send(request, 500, <String, Object?>{
          'ok': false,
          'saved': false,
          'error': 'Sipariş kalıcı kaydedilemedi.',
        });
        return;
      }
      await _send(request, 200, <String, Object?>{
        'ok': true,
        'saved': true,
        'duplicate': false,
        'printed': false,
        'print_status': previous.printStatus,
        'revision': revision,
        'local_order_id': order.localOrderId,
      });
      return;
    }
    if (LanPilotMode.enabled) {
      try {
        final saved = await LanPilotGateway.current.submit(
          restaurantId: restaurantId,
          localOrderId: order.localOrderId,
          tableNumber: order.tableNumber,
          tableLabel: order.tableName,
          waiterName: order.waiterName,
          notes: order.notes,
          items: order.items,
        );
        await _send(request, 200, <String, Object?>{
          'ok': saved['ok'] == true,
          'saved': saved['saved'] == true,
          'duplicate': saved['duplicate'] == true,
          'printed': saved['printed'] == true,
          'print_status': saved['print_status'],
          'local_order_id': order.localOrderId,
        });
      } catch (error) {
        await _send(request, 503, <String, Object?>{
          'ok': false,
          'saved': false,
          'error': error.toString(),
        });
      }
      return;
    }
    await _orders.enqueue(order: order);
    lastStageMicros['local_save'] = saveWatch.elapsedMicroseconds;
    saveWatch.reset();
    try {
      await _enqueueStationJobs(order, revision);
      await _requireDurablePrintJobs(order, revision);
    } catch (error) {
      await _orders.remove(
        restaurantId: restaurantId,
        localOrderId: order.localOrderId,
      );
      await _send(request, 500, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Sipariş kaydı baskı işiyle birlikte tamamlanamadı.',
      });
      return;
    }
    lastStageMicros['print_queue'] = saveWatch.elapsedMicroseconds;
    if (!RestaurantLanHostRegistry.ordersAccepted.isClosed) {
      RestaurantLanHostRegistry.ordersAccepted.add(order);
    }
    final bridgeStatus = await _deliverStationJobs(order, revision);
    final after = await _orders.list(restaurantId);
    if (!after.any((row) => row.localOrderId == order.localOrderId)) {
      await _send(request, 500, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Sipariş kalıcı kaydedilemedi.',
      });
      return;
    }
    var printStatus = bridgeStatus ?? 'not_sent';
    if (bridgeStatus != null) {
      await _orders.update(
        restaurantId: restaurantId,
        order: order.copyWith(printStatus: bridgeStatus, updatedAt: _clock()),
      );
      rememberLocalTicketBarrier(
        restaurantId: restaurantId,
        tableNumber: order.tableNumber,
        items: order.items,
        printStatus: bridgeStatus,
        orderKey: order.localOrderId,
        revision: revision,
      );
    } else if (enablePhysicalPrint &&
        stationId.isNotEmpty &&
        onPhysicalPrint != null) {
      printStatus = 'uncertain';
      try {
        await onPhysicalPrint!(order);
        printStatus = 'forwarded';
      } catch (_) {}
      await _orders.update(
        restaurantId: restaurantId,
        order: order.copyWith(printStatus: printStatus, updatedAt: _clock()),
      );
      rememberLocalTicketBarrier(
        restaurantId: restaurantId,
        tableNumber: order.tableNumber,
        items: order.items,
        printStatus: printStatus,
        orderKey: order.localOrderId,
        revision: revision,
      );
    }
    await _send(request, 200, <String, Object?>{
      'ok': true,
      'saved': true,
      'duplicate': false,
      'printed': false,
      'print_status': printStatus,
      'local_order_id': order.localOrderId,
    });
  }

  bool _operatorConsole(HttpRequest request) {
    if (_isLoopback(request)) return true;
    final remote = request.connectionInfo?.remoteAddress.address ?? '';
    final bound = boundAddress ?? '';
    return bound.isNotEmpty && remote == bound;
  }

  bool _isLoopback(HttpRequest request) {
    final address = request.connectionInfo?.remoteAddress.address ?? '';
    return address == '127.0.0.1' || address == '::1' || address == '::ffff:127.0.0.1';
  }

  Future<String> _announcedFingerprint() async {
    final directory = certificateDirectory?.trim() ?? '';
    if (directory.isEmpty) return '';
    try {
      return await LanTlsMaterial.certificateFingerprint('$directory/server.pem');
    } catch (_) {
      return '';
    }
  }

  bool _allowOrder(String remote) {
    final now = _clock();
    final rows = _orderTimes.putIfAbsent(remote, () => <DateTime>[]);
    rows.removeWhere((time) => now.difference(time) > const Duration(minutes: 1));
    if (rows.length >= 30) return false;
    rows.add(now);
    return true;
  }

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    if (request.contentLength > lanMaxBodyBytes) {
      throw const _LanBodyRejected();
    }
    final bytes = await request
        .fold<List<int>>(<int>[], (previous, chunk) {
          final next = <int>[...previous, ...chunk];
          if (next.length > lanMaxBodyBytes) throw const _LanBodyRejected();
          return next;
        })
        .timeout(const Duration(seconds: 8));
    if (bytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  _PricedItems _pricedItems(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> catalog,
    String requestStationId,
  ) {
    if (items.isEmpty) {
      return const _PricedItems(items: <Map<String, dynamic>>[], total: 0, error: 'Sipariş kalemi yok.');
    }
    final priced = <Map<String, dynamic>>[];
    var total = 0.0;
    for (final item in items) {
      final name = item['name']?.toString().trim() ?? '';
      final productId = item['product_id']?.toString().trim() ?? '';
      Map<String, dynamic>? product;
      for (final row in catalog) {
        final rowId = row['id']?.toString().trim() ?? '';
        final rowName = row['name']?.toString().trim() ?? '';
        if (productId.isNotEmpty && rowId == productId) {
          product = row;
          break;
        }
        if (name.isNotEmpty && rowName == name) {
          product = row;
          break;
        }
      }
      if (product == null) {
        return _PricedItems(
          items: const <Map<String, dynamic>>[],
          total: 0,
          error: 'Ürün yerel katalogda yok: $name',
        );
      }
      final catalogPrice = product['price'];
      if (catalogPrice is! num) {
        return const _PricedItems(
          items: <Map<String, dynamic>>[],
          total: 0,
          error: 'Ürün fiyatı yerel katalogda doğrulanamadı.',
        );
      }
      final offered = item['price'];
      if (offered is num && (offered - catalogPrice).abs() > 0.009) {
        return const _PricedItems(
          items: <Map<String, dynamic>>[],
          total: 0,
          error: 'Ürün fiyatı yerel katalogla uyuşmuyor.',
        );
      }
      final productStation = product['station_id']?.toString().trim() ?? '';
      final itemStation = item['station_id']?.toString().trim() ?? '';
      if (itemStation.isNotEmpty &&
          productStation.isNotEmpty &&
          itemStation != productStation) {
        return const _PricedItems(
          items: <Map<String, dynamic>>[],
          total: 0,
          error: 'Ürün bu istasyona ait değil.',
        );
      }
      final station = itemStation.isNotEmpty
          ? itemStation
          : (productStation.isNotEmpty ? productStation : requestStationId);
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
      if (qty <= 0) {
        return const _PricedItems(
          items: <Map<String, dynamic>>[],
          total: 0,
          error: 'Ürün adedi geçersiz.',
        );
      }
      final copy = Map<String, dynamic>.from(item);
      copy['price'] = catalogPrice;
      copy['line_total'] = double.parse(
        (catalogPrice.toDouble() * qty).toStringAsFixed(2),
      );
      if (station.isNotEmpty) copy['station_id'] = station;
      total += catalogPrice.toDouble() * qty;
      priced.add(copy);
    }
    return _PricedItems(items: priced, total: total);
  }

  String _contentKey(RestaurantLocalOrderRecord order) {
    final lines = order.items.map(_lineKey).toList()..sort();
    return '${order.tableNumber}|${order.notes}|${lines.join(';')}';
  }

  String _lineKey(Map<String, dynamic> item) {
    final name = item['name']?.toString().trim() ?? '';
    final qty = item['quantity']?.toString() ?? '1';
    final station = item['station_id']?.toString().trim() ?? '';
    return '$name|$qty|$station';
  }

  String _revisionOf(RestaurantLocalOrderRecord order) {
    for (final group in order.stationGroups) {
      final value = group['revision']?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '1';
  }

  List<Map<String, dynamic>> _items(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> _send(
    HttpRequest request,
    int status,
    Map<String, Object?> body,
  ) async {
    final bytes = utf8.encode(jsonEncode(body));
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  }

  Future<String?> _staffGrantError(
    RestaurantLanDevice paired,
    String fingerprint,
  ) async {
    final probe = staffStillAuthorized;
    if (probe == null) {
      return 'Personel doğrulaması yok.';
    }
    StaffProbe result;
    try {
      result = await probe(paired.staffId);
    } catch (error) {
      result = StaffProbe(
        staffProbeErrorIsUnreachable(error)
            ? StaffProbeKind.unreachable
            : StaffProbeKind.rejected,
        reason: staffProbeErrorIsUnreachable(error)
            ? 'Personel sunucusuna ulaşılamadı.'
            : 'Personel yetkisi doğrulanamadı.',
      );
    }
    final now = _clock();
    if (result.kind == StaffProbeKind.rejected) {
      _devices[fingerprint] = paired.copy(revoked: true);
      await _persistDevices();
      return result.reason.isEmpty
          ? 'Personel yetkisi iptal edildi.'
          : result.reason;
    }
    if (result.kind == StaffProbeKind.unreachable) {
      return _offlineStaffGrant(paired, now);
    }
    if (paired.verifiedAt != null && now.isBefore(paired.verifiedAt!)) {
      return 'Cihaz saati geri alındı. Yetki uzatılmadı.';
    }
    _devices[fingerprint] = paired.copy(
      staffVerified: true,
      verifiedAt: now,
      expiresAt: now.add(deviceGrantTtl),
    );
    await _persistDevices();
    return null;
  }

  String? _offlineStaffGrant(RestaurantLanDevice paired, DateTime now) {
    if (!paired.staffVerified ||
        paired.verifiedAt == null ||
        paired.expiresAt == null) {
      return 'Personel daha önce doğrulanmadı.';
    }
    if (now.isBefore(paired.verifiedAt!)) {
      return 'Cihaz saati geri alındı. Yetki uzatılmadı.';
    }
    if (!now.isBefore(paired.expiresAt!)) {
      return 'Kayıtlı personel yetkisinin süresi doldu.';
    }
    return null;
  }

  Future<void> _requireDurablePrintJobs(
    RestaurantLocalOrderRecord order,
    String revision,
  ) async {
    final queue = _printQueue;
    if (queue == null) return;
    final stations = <String>{
      for (final item in order.items)
        if ((item['station_id']?.toString().trim() ?? '').isNotEmpty)
          item['station_id'].toString().trim(),
    };
    if (stations.isEmpty) return;
    final jobs = await queue.list(restaurantId);
    for (final station in stations) {
      final jobId = '${order.localOrderId}|$revision|$station|new_order';
      if (!jobs.any((job) => job.localJobId == jobId)) {
        throw StateError('Mutfak baskı işi kalıcı kuyrukta yok.');
      }
    }
  }

  Future<void> _enqueueStationJobs(
    RestaurantLocalOrderRecord order,
    String revision,
  ) async {
    final queue = _printQueue;
    if (queue == null) return;
    final stations = <String>{
      for (final item in order.items)
        if ((item['station_id']?.toString().trim() ?? '').isNotEmpty)
          item['station_id'].toString().trim(),
    };
    for (final station in stations) {
      await queue.enqueue(
        job: RestaurantLocalPrintJobRecord(
          localJobId: '${order.localOrderId}|$revision|$station|new_order',
          restaurantId: restaurantId,
          localOrderId: order.localOrderId,
          tableId: order.tableId,
          tableName: order.tableName,
          documentType: 'kitchen',
          role: 'mutfak',
          station: station,
          printerSnapshot: const <String, dynamic>{},
          payloadSnapshot: <String, dynamic>{
            'local_order_id': order.localOrderId,
            'revision': revision,
            'station_id': station,
            'job_type': 'new_order',
            'items': <Map<String, dynamic>>[
              for (final item in order.items)
                if (item['station_id']?.toString().trim() == station)
                  <String, dynamic>{
                    'name': item['name'] ?? item['product_name'] ?? 'Ürün',
                    'quantity': item['quantity'] ?? 1,
                    'station_id': station,
                    'note': item['note'] ?? item['notes'] ?? '',
                  },
            ],
          },
          status: RestaurantLocalPrintJobStatus.queued,
          attempts: 0,
          createdAt: _clock(),
        ),
      );
    }
  }

  Future<String?> _deliverStationJobs(
    RestaurantLocalOrderRecord order,
    String revision,
  ) async {
    final queue = _printQueue;
    final bridge = printBridgeUri;
    if (queue == null || bridge == null) return null;
    final stations = <String>{
      for (final item in order.items)
        if ((item['station_id']?.toString().trim() ?? '').isNotEmpty)
          item['station_id'].toString().trim(),
    };
    final statuses = <String>[];
    for (final station in stations) {
      final jobId = '${order.localOrderId}|$revision|$station|new_order';
      final jobs = await queue.list(restaurantId);
      final match = jobs.where((row) => row.localJobId == jobId);
      if (match.isEmpty) continue;
      final delivered = await queue.deliverToBridge(
        job: match.first,
        bridgeBase: bridge,
      );
      lastStageMicros['bridge_request'] =
          queue.lastStageMicros['bridge_request'] ?? 0;
      lastStageMicros['bridge_response'] =
          queue.lastStageMicros['bridge_response'] ?? 0;
      statuses.add(delivered.status.name);
    }
    if (statuses.isEmpty) return 'not_sent';
    if (statuses.any((status) => status == 'uncertain')) return 'uncertain';
    if (statuses.every((status) => status == 'forwarded')) return 'forwarded';
    if (statuses.any((status) => status == 'failed')) return 'failed';
    return statuses.first;
  }

  Future<String?> evidenceForOrder({
    required String localOrderId,
    required String outcome,
    required String revision,
    required String eventId,
    required Iterable<Map<String, dynamic>> items,
    String jobType = 'new_order',
  }) async {
    final directory = certificateDirectory?.trim() ?? '';
    if (directory.isEmpty || localOrderId.trim().isEmpty) return null;
    final identity = await LanTlsMaterial.evidenceIdentity(Directory(directory));
    final fingerprint = await LanTlsMaterial.certificateFingerprint(
      '$directory/server.pem',
    );
    if (identity.id.isEmpty || fingerprint.isEmpty) return null;
    final payload = lanPrintEvidenceCanonical(
      restaurantId: restaurantId,
      branchId: branchId ?? '',
      localOrderId: localOrderId,
      jobType: jobType,
      outcome: outcome,
      revision: revision,
      eventId: eventId,
      keyId: identity.id,
      serverFingerprint: fingerprint,
      items: items,
    );
    final process = await Process.start(lanOpenSslExecutable(), <String>[
      'dgst',
      '-sha256',
      '-sign',
      identity.path,
    ]);
    process.stdin.add(utf8.encode(payload));
    await process.stdin.close();
    final signature = await process.stdout.fold<List<int>>(
      <int>[],
      (previous, chunk) => previous..addAll(chunk),
    );
    final exitCode = await process.exitCode;
    if (exitCode != 0 || signature.isEmpty) return null;
    return 'v2.$outcome.$revision.$eventId.${identity.id}.${_hex(signature)}';
  }

  String _hex(List<int> bytes) {
    const alphabet = '0123456789abcdef';
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer
        ..write(alphabet[(byte >> 4) & 0xf])
        ..write(alphabet[byte & 0xf]);
    }
    return buffer.toString();
  }

  bool get lanIdentityVerified => listening && restaurantId.trim().isNotEmpty;

  /// Operator send from the Garson screen on this computer.
  ///
  /// Remote devices still enter through the TLS listener. Both paths write
  /// only when the Python bridge confirms the SQLite transaction.
  Future<Map<String, dynamic>> submitOperatorOrder({
    required String localOrderId,
    required int tableNumber,
    required String tableLabel,
    required String waiterName,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    if (!LanPilotMode.enabled) {
      throw StateError(LanPilotContract.notSentMessage);
    }
    if (!listening) {
      throw StateError(LanPilotContract.bridgeClosedMessage);
    }
    if (localOrderId.trim().isEmpty) {
      throw StateError(LanPilotContract.notSentMessage);
    }
    final catalog = productsOverride ??
        (await _cache.read(restaurantId))?.products ??
        const <Map<String, dynamic>>[];
    if (catalog.isEmpty) {
      throw StateError(LanPilotContract.menuMissingMessage);
    }
    final priced = _pricedItems(items, catalog, '');
    if (priced.error != null) {
      throw StateError(
        '${priced.error} ${LanPilotContract.notSentMessage}',
      );
    }
    return LanPilotGateway.current.submit(
      restaurantId: restaurantId,
      localOrderId: localOrderId.trim(),
      tableNumber: tableNumber,
      tableLabel: tableLabel,
      waiterName: waiterName,
      notes: notes,
      items: priced.items,
    );
  }

  Future<void> _handleBrowser(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final origin = request.headers.value('origin') ?? '';
      if (request.method == 'OPTIONS') {
        if (!_browserOriginAllowed(origin)) {
          await _send(request, 403, <String, Object?>{'ok': false});
          return;
        }
        _stampBrowserCors(request, origin);
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }
      if (path == '/lan/browser/app' && request.method == 'GET') {
        final html = utf8.encode(_browserAppHtml);
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.html;
        request.response.contentLength = html.length;
        request.response.add(html);
        await request.response.close();
        return;
      }
      if (!_browserOriginAllowed(origin)) {
        await _send(request, 403, <String, Object?>{
          'ok': false,
          'error': 'Bu origin kabul edilmedi.',
        });
        return;
      }
      _stampBrowserCors(request, origin);
      if (path == '/lan/browser/pair' && request.method == 'POST') {
        await _pairBrowser(request, origin);
        return;
      }
      final grant = _browserGrantFor(request);
      if (grant == null) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': 'Tarayıcı oturumu yok veya süresi doldu.',
        });
        return;
      }
      final envelope = await _readBody(request);
      final seq = envelope['seq'];
      final inner = envelope['body'];
      if (seq is! int || seq <= grant.seq || inner is! Map) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': 'Tekrarlanan veya sırasız istek reddedildi.',
        });
        return;
      }
      grant.seq = seq;
      final body = Map<String, dynamic>.from(inner);
      if ((body['staff_id']?.toString().trim() ?? '') != grant.staffId) {
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': 'Personel yetkisi doğrulanamadı.',
        });
        return;
      }
      if (path == '/lan/browser/tables' && request.method == 'POST') {
        final tables = (tablesOverride ?? (await _cache.read(restaurantId))?.tables)
            ?.map(stripLanSecrets)
            .toList(growable: false);
        await _send(request, tables == null ? 409 : 200, <String, Object?>{
          'ok': tables != null,
          if (tables != null) 'tables': tables,
          if (tables == null) 'error': 'Ana bilgisayarda masa listesi yok.',
        });
        return;
      }
      if (path == '/lan/browser/floor' && request.method == 'POST') {
        final rows = await _orders.list(restaurantId);
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'orders': <Map<String, Object?>>[
            for (final order in rows)
              <String, Object?>{
                'local_order_id': order.localOrderId,
                'table_number': order.tableNumber,
                'table_name': order.tableName,
                'total': order.total,
                'print_status': order.printStatus,
                'items': order.items,
              },
          ],
        });
        return;
      }
      if (path == '/lan/browser/orders' && request.method == 'POST') {
        await _orders.transaction(
          () => _acceptOrder(request, body, grant.deviceId),
        );
        return;
      }
      await _send(request, 404, <String, Object?>{'ok': false});
    } on _LanBodyRejected {
      await _send(request, 413, <String, Object?>{'ok': false, 'saved': false});
    } catch (_) {
      await _send(request, 500, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': 'Tarayıcı isteği tamamlanamadı.',
      });
    }
  }

  Future<void> _pairBrowser(HttpRequest request, String origin) async {
    final client = (request.connectionInfo?.remoteAddress.address ?? '').trim();
    final guard = _pairingAttempts.putIfAbsent('browser:$client', PairingAttemptGuard.new);
    if (!guard.allow(_clock())) {
      await _send(request, 429, <String, Object?>{
        'ok': false,
        'error': 'Çok fazla eşleştirme denemesi. Kısa süre bekleyin.',
      });
      return;
    }
    final body = await _readBody(request);
    final code = body['code']?.toString().trim() ?? '';
    final staffId = body['staff_id']?.toString().trim() ?? '';
    final expired = _browserCodeExpires == null || !_clock().isBefore(_browserCodeExpires!);
    if (_browserCode == null ||
        expired ||
        code.isEmpty ||
        code != _browserCode ||
        staffId.isEmpty) {
      guard.recordFailure(_clock());
      await _send(request, 401, <String, Object?>{
        'ok': false,
        'error': 'Eşleştirme kodu geçersiz veya süresi doldu.',
      });
      return;
    }
    final staffError = staffStillAuthorized == null
        ? 'Personel doğrulaması yok.'
        : await _staffGrantError(
            RestaurantLanDevice(
              deviceId: 'browser-pending',
              pairedAt: _clock(),
              staffId: staffId,
            ),
            'browser-pending',
          );
    if (staffError != null) {
      guard.recordFailure(_clock());
      await _send(request, 401, <String, Object?>{'ok': false, 'error': staffError});
      return;
    }
    guard.recordSuccess();
    _devices.remove('browser-pending');
    _browserCode = null;
    _browserCodeExpires = null;
    final token = newPairingSecret(_random);
    final deviceId = 'browser-${token.substring(0, 12)}';
    final expires = _clock().add(const Duration(hours: 8));
    _browserGrants[token] = _BrowserGrant(
      token: token,
      staffId: staffId,
      origin: origin,
      expiresAt: expires,
      deviceId: deviceId,
    );
    _devices[deviceId] = RestaurantLanDevice(
      deviceId: deviceId,
      pairedAt: _clock(),
      staffId: staffId,
      branchId: branchId,
    );
    await _send(request, 200, <String, Object?>{
      'ok': true,
      'token': token,
      'device_id': deviceId,
      'expires_at': expires.toUtc().toIso8601String(),
      'restaurant_id': restaurantId,
    });
  }

  _BrowserGrant? _browserGrantFor(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!header.startsWith('Bearer ')) return null;
    final token = header.substring(7).trim();
    final grant = _browserGrants[token];
    if (grant == null || grant.revoked || !_clock().isBefore(grant.expiresAt)) {
      return null;
    }
    final origin = request.headers.value('origin') ?? '';
    if (origin != grant.origin) return null;
    return grant;
  }

  bool _browserOriginAllowed(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost');
  }

  void _stampBrowserCors(HttpRequest request, String origin) {
    request.response.headers.set('Access-Control-Allow-Origin', origin);
    request.response.headers.set('Vary', 'Origin');
    request.response.headers.set('Access-Control-Allow-Headers', 'authorization, content-type');
    request.response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  }

  String? _fingerprint(HttpRequest request) {
    final fingerprint = LanTlsMaterial.fingerprintOf(request.certificate);
    if (fingerprint.isEmpty) return null;
    return fingerprint;
  }

  Future<({String certificate, String fingerprint})?> _signCsr(String csr) async {
    final root = certificateDirectory;
    if (root == null || root.isEmpty) return null;
    final id = _random.nextInt(1 << 30);
    final csrFile = File('$root/pending-$id.csr');
    final outFile = File('$root/pending-$id.pem');
    try {
      await csrFile.writeAsString(csr);
      final result = await Process.run(lanOpenSslExecutable(), <String>[
        'x509',
        '-req',
        '-in',
        csrFile.path,
        '-CA',
        '$root/ca.pem',
        '-CAkey',
        '$root/ca.key',
        '-CAcreateserial',
        '-out',
        outFile.path,
        '-days',
        '825',
      ]);
      if (result.exitCode != 0 || !outFile.existsSync()) {
        final dartCert = await signCsrWithDartCa(
          directory: Directory(root),
          csrPem: csr,
        );
        if (dartCert == null || dartCert.trim().isEmpty) return null;
        return (certificate: dartCert, fingerprint: certificateSha256Hex(dartCert));
      }
      final certificate = await outFile.readAsString();
      final fingerprint = await LanTlsMaterial.certificateFingerprint(outFile.path);
      if (certificate.trim().isEmpty || fingerprint.isEmpty) return null;
      return (certificate: certificate, fingerprint: fingerprint);
    } catch (_) {
      return null;
    } finally {
      if (csrFile.existsSync()) await csrFile.delete();
      if (outFile.existsSync()) await outFile.delete();
    }
  }

  String get _deviceKey => 'lan_device_enrollment_v1_$restaurantId';

  Future<void> _loadDevices() async {
    final raw = await _deviceStore.readJson(_deviceKey);
    final rows = raw is Map ? raw['devices'] : null;
    if (rows is! List) return;
    for (final row in rows.whereType<Map>()) {
      final json = Map<String, dynamic>.from(row);
      final device = RestaurantLanDevice.fromJson(json);
      if (device.deviceId.isEmpty) continue;
      _devices[device.deviceId] = legacySha1DeviceId(device.deviceId)
          ? device.copy(revoked: true)
          : device;
      _inboundSeq[device.deviceId] = (json['last_seq'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> _persistDevices() async {
    await _deviceStore.writeJson(_deviceKey, <String, dynamic>{
      'devices': _devices.values
          .map((device) {
            final json = device.toJson();
            json['last_seq'] = _inboundSeq[device.deviceId] ?? 0;
            return json;
          })
          .toList(growable: false),
    });
  }
}

abstract class RestaurantLanOrderTransport {
  Future<bool> submit(RestaurantLocalOrderRecord order);
}

class RestaurantLanPairing {
  static RestaurantLanOrderTransport? transport;
}

class RestaurantLanHostRegistry {
  static RestaurantLanHost? current;

  /// Accepted floor orders. The seller screen listens here; the cloud does not.
  static final StreamController<RestaurantLocalOrderRecord> ordersAccepted =
      StreamController<RestaurantLocalOrderRecord>.broadcast();
}

class _BrowserGrant {
  _BrowserGrant({
    required this.token,
    required this.staffId,
    required this.origin,
    required this.expiresAt,
    required this.deviceId,
  });

  final String token;
  final String staffId;
  final String origin;
  final DateTime expiresAt;
  final String deviceId;
  int seq = 0;
  bool revoked = false;
}

const String _browserAppHtml = '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>İBUL garson</title>
<style>
body { font-family: sans-serif; margin: 24px; color: #111827; }
button { margin-right: 8px; }
#status { font-weight: 700; }
</style>
</head>
<body>
<p id="status">Eşleştirme bekleniyor</p>
<label>Kod <input id="code" autocomplete="off"></label>
<label>Personel <input id="staff" value="staff-a"></label>
<button id="pair" type="button">Eşleştir</button>
<button id="order" type="button">Çorba gönder</button>
<pre id="out"></pre>
<script>
const out = document.getElementById('out');
const status = document.getElementById('status');
let token = sessionStorage.getItem('ibul_browser_token') || '';
let seq = Number(sessionStorage.getItem('ibul_browser_seq') || '0');
function show(value) { out.textContent = JSON.stringify(value, null, 2); }
async function post(path, body, auth) {
  seq += 1;
  sessionStorage.setItem('ibul_browser_seq', String(seq));
  const headers = {'content-type': 'application/json'};
  if (auth) headers.authorization = 'Bearer ' + token;
  const response = await fetch(path, {
    method: 'POST',
    headers: headers,
    body: JSON.stringify(auth ? {seq: seq, body: body} : body)
  });
  const json = await response.json();
  json.status = response.status;
  return json;
}
document.getElementById('pair').onclick = async () => {
  const json = await post('/lan/browser/pair', {
    code: document.getElementById('code').value.trim(),
    staff_id: document.getElementById('staff').value.trim()
  }, false);
  if (json.token) {
    token = json.token;
    sessionStorage.setItem('ibul_browser_token', token);
    status.textContent = 'Çevrimdışı — Yerel sistem aktif';
    show(await post('/lan/browser/tables', {staff_id: document.getElementById('staff').value.trim()}, true));
  } else {
    status.textContent = 'Eşleştirme olmadı';
    show(json);
  }
};
document.getElementById('order').onclick = async () => {
  const json = await post('/lan/browser/orders', {
    staff_id: document.getElementById('staff').value.trim(),
    local_order_id: 'browser-bahce-3',
    table_number: 3,
    table_name: 'Bahçe 3',
    station_id: 'ocak',
    revision: '1',
    items: [{name: 'Çorba', quantity: 1, price: 40}]
  }, true);
  status.textContent = json.saved ? 'Sipariş kaydedildi' : 'Sipariş kaydedilmedi';
  show(json);
};
</script>
</body>
</html>
''';

class _PricedItems {
  const _PricedItems({
    required this.items,
    required this.total,
    this.error,
  });

  final List<Map<String, dynamic>> items;
  final double total;
  final String? error;
}

