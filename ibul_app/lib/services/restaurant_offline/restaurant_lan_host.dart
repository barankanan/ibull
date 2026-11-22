import 'offline_catalog_pricing.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/secure_local_store.dart';
import 'lan_authority_seal.dart';
import 'lan_center_status.dart';
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

/// One order can print on several stations. The order is only "failed" when
/// every station definitely failed. If one station may have printed
/// (forwarded or uncertain) and another failed, the order is uncertain: a
/// reprint of the failed station is for the operator to decide, never an
/// automatic repeat of the whole order. Unknown statuses are uncertain.
String combineStationPrintStatuses(List<String> statuses) {
  if (statuses.isEmpty) return 'not_sent';
  if (statuses.every((status) => status == 'forwarded')) return 'forwarded';
  if (statuses.every((status) => status == 'failed')) return 'failed';
  return 'uncertain';
}

/// Read-only, secret-free view of a paired device for the operator screen.
class LanDeviceInfo {
  const LanDeviceInfo({
    required this.deviceId,
    required this.staffId,
    required this.pairedAt,
    required this.revoked,
    this.deviceName,
    this.platform,
    this.branchId,
    this.lastSeenAt,
    this.expiresAt,
  });

  final String deviceId;
  final String staffId;
  final DateTime pairedAt;
  final bool revoked;
  final String? deviceName;
  final String? platform;
  final String? branchId;
  final DateTime? lastSeenAt;
  final DateTime? expiresAt;
}

class RestaurantLanDevice {
  const RestaurantLanDevice({
    required this.deviceId,
    required this.pairedAt,
    required this.staffId,
    this.branchId,
    this.staffBranchId,
    this.revoked = false,
    this.staffVerified = false,
    this.verifiedAt,
    this.expiresAt,
    this.authoritySeal,
    this.staffEpoch,
    this.deviceName,
    this.platform,
    this.lastSeenAt,
  });

  final String deviceId;
  final DateTime pairedAt;
  final String staffId;
  final String? branchId;

  /// Branch the staff membership is limited to (verified with the cloud);
  /// null or empty means all branches.
  final String? staffBranchId;
  final bool revoked;
  final bool staffVerified;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;

  /// HMAC over the verified authority (see [authorityCanonical]). A record
  /// whose seal does not verify grants nothing while the cloud is away.
  final String? authoritySeal;

  /// Server `credential_epoch` of the staff account when this device was last
  /// verified online. It moves when the staff member is deactivated,
  /// re-activated, deleted, re-linked or gets a new password; a different
  /// value later means the old pairing is no longer trusted.
  final int? staffEpoch;

  /// Display-only facts the phone reported when it paired (never grant
  /// anything). Absent on records written before these fields existed.
  final String? deviceName;
  final String? platform;

  /// Last authenticated request. Moves at most about once a minute.
  final DateTime? lastSeenAt;

  /// Fields that grant offline access. `manageOrders` is implied: only a
  /// membership holding it is ever stored as verified.
  String authorityCanonical(String restaurantId) => <String>[
    restaurantId,
    deviceId,
    staffId,
    branchId ?? '',
    staffBranchId ?? '',
    verifiedAt?.toUtc().toIso8601String() ?? '',
    expiresAt?.toUtc().toIso8601String() ?? '',
    'manageOrders',
    // Always part of the seal: seals written before the epoch existed no
    // longer verify. Accepted behaviour: such a device is renewed at the next
    // online check, and with the cloud away its old seal is refused.
    'epoch:${staffEpoch ?? ''}',
  ].map(jsonEncode).join('|');

  RestaurantLanDevice copy({
    bool? revoked,
    bool? staffVerified,
    DateTime? verifiedAt,
    DateTime? expiresAt,
    String? staffBranchId,
    String? authoritySeal,
    int? staffEpoch,
    DateTime? lastSeenAt,
    bool clearVerification = false,
  }) {
    return RestaurantLanDevice(
      deviceId: deviceId,
      pairedAt: pairedAt,
      staffId: staffId,
      branchId: branchId,
      staffBranchId: staffBranchId ?? this.staffBranchId,
      revoked: revoked ?? this.revoked,
      staffVerified: clearVerification ? false : staffVerified ?? this.staffVerified,
      verifiedAt: clearVerification ? null : verifiedAt ?? this.verifiedAt,
      expiresAt: clearVerification ? null : expiresAt ?? this.expiresAt,
      authoritySeal: clearVerification ? null : authoritySeal ?? this.authoritySeal,
      staffEpoch: staffEpoch ?? this.staffEpoch,
      deviceName: deviceName,
      platform: platform,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'device_id': deviceId,
    'paired_at': pairedAt.toUtc().toIso8601String(),
    'staff_id': staffId,
    if (branchId != null) 'branch_id': branchId,
    if (staffBranchId != null) 'staff_branch_id': staffBranchId,
    'revoked': revoked,
    'staff_verified': staffVerified,
    if (verifiedAt != null) 'verified_at': verifiedAt!.toUtc().toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    if (authoritySeal != null) 'authority_seal': authoritySeal,
    if (staffEpoch != null) 'staff_epoch': staffEpoch,
    if (deviceName != null && deviceName!.isNotEmpty) 'device_name': deviceName,
    if (platform != null && platform!.isNotEmpty) 'platform': platform,
    if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toUtc().toIso8601String(),
  };

  factory RestaurantLanDevice.fromJson(Map<String, dynamic> json) {
    return RestaurantLanDevice(
      deviceId: json['device_id']?.toString() ?? '',
      pairedAt: DateTime.tryParse(json['paired_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      staffId: json['staff_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      staffBranchId: json['staff_branch_id']?.toString(),
      revoked: json['revoked'] == true,
      staffVerified: json['staff_verified'] == true,
      verifiedAt: DateTime.tryParse(json['verified_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      authoritySeal: json['authority_seal']?.toString(),
      staffEpoch: json['staff_epoch'] is int ? json['staff_epoch'] as int : null,
      deviceName: json['device_name']?.toString(),
      platform: json['platform']?.toString(),
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? ''),
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
    this.stationPrinter,
    this.staffStillAuthorized,
    LanEnrollmentStore? deviceStore,
    this.deviceGrantTtl = const Duration(hours: 12),
    LanAuthoritySealer? authoritySealer,
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
       _authoritySealer = authoritySealer ?? KeystoreLanAuthoritySealer(),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final String restaurantId;
  final LanPhysicalPrint? onPhysicalPrint;
  final bool enablePhysicalPrint;
  final List<Map<String, dynamic>>? stationsOverride;
  final List<Map<String, dynamic>>? tablesOverride;
  final List<Map<String, dynamic>>? productsOverride;
  /// The center's branch. It can become known after start (the evidence key
  /// is registered once the cloud is reachable), so it is not final.
  String? branchId;
  final String? operatorFingerprint;
  final String? certificateDirectory;
  final String? machineId;
  final Uri? printBridgeUri;
  /// Resolves the saved printer of one kitchen station on this computer
  /// (station mapping, else the kitchen role printer). The answer is stored
  /// with the print job so the ticket goes to that printer and a retry can
  /// never move to another one. A map with `resolution_error` means no
  /// printer is known for the station: nothing is sent for it.
  /// Null keeps the bridge's own default target.
  final Future<Map<String, dynamic>> Function(String stationId)? stationPrinter;
  final Map<String, int> lastStageMicros = <String, int>{};
  final Future<StaffProbe> Function(String staffId)? staffStillAuthorized;
  final LanEnrollmentStore _deviceStore;
  /// How long a cloud-verified staff authority is trusted while the cloud is
  /// unreachable. Never extended offline; renewed by every online check.
  final Duration deviceGrantTtl;
  final LanAuthoritySealer _authoritySealer;
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

  /// Bumped whenever the device list changes (pair, revoke, last-seen).
  final ValueNotifier<int> devicesRevision = ValueNotifier<int>(0);

  /// Safe view: no keys, seals, epochs or pairing codes.
  List<LanDeviceInfo> get deviceInfos => _devices.values
      .map(
        (d) => LanDeviceInfo(
          deviceId: d.deviceId,
          staffId: d.staffId,
          pairedAt: d.pairedAt,
          revoked: d.revoked,
          deviceName: d.deviceName,
          platform: d.platform,
          branchId: (d.staffBranchId?.trim().isNotEmpty ?? false)
              ? d.staffBranchId
              : d.branchId,
          lastSeenAt: d.lastSeenAt,
          expiresAt: d.expiresAt,
        ),
      )
      .toList(growable: false);

  /// Same effect as `POST /lan/revoke`: marks the device revoked, persists,
  /// and kills browser grants. Returns false for an unknown device.
  Future<bool> revokeDevice(String deviceId) async {
    final id = deviceId.trim();
    final current = _devices[id];
    if (current != null) {
      _devices[id] = current.copy(revoked: true);
      await _persistDevices();
    }
    for (final grant in _browserGrants.values) {
      if (grant.deviceId == id) grant.revoked = true;
    }
    return current != null;
  }

  /// Moves `lastSeenAt` at most once per [lastSeenGranularity]; the existing
  /// per-request persist then carries it, no extra disk write is added.
  static const Duration lastSeenGranularity = Duration(minutes: 1);
  void _touchDevice(String fingerprint) {
    final device = _devices[fingerprint];
    if (device == null) return;
    final now = _clock();
    final seen = device.lastSeenAt;
    if (seen != null && now.difference(seen) < lastSeenGranularity) return;
    _devices[fingerprint] = device.copy(lastSeenAt: now);
  }

  Future<void> start({
    required SecurityContext securityContext,
    InternetAddress? address,
    int port = 0,
  }) async {
    _stopping = false;
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
    await _orders.adoptJournal(restaurantId);
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

  /// One-time pairing code for the next waiter device. The owner screen on
  /// this computer calls it; the HTTP route above reuses it. A new code
  /// replaces the previous one and expires after [PairingAttemptGuard.codeTtl].
  ({String code, DateTime expiresAt}) issuePairingCode() {
    _code = newPairingSecret(_random);
    _codeExpires = _clock().add(PairingAttemptGuard.codeTtl);
    return (code: _code!, expiresAt: _codeExpires!);
  }

  /// The one thing a waiter device needs when it cannot find this center by
  /// itself (local-network search refused or not available): where the center
  /// is, which certificate it must present, and a fresh one-time code. Shown
  /// on this computer as a QR and as text; valid for two minutes, one use.
  Future<String?> issuePairingLink() async {
    final address = boundAddress?.trim() ?? '';
    final fingerprint = await _announcedFingerprint();
    final machine = machineId?.trim() ?? '';
    if (!listening || address.isEmpty || fingerprint.isEmpty || machine.isEmpty) {
      return null;
    }
    final issued = issuePairingCode();
    final base = Uri.parse(
      encodeLanQr(
        LanCenterRecord(
          host: address,
          port: port,
          restaurantId: restaurantId,
          machineId: machine,
          fingerprint: fingerprint,
        ),
      ),
    );
    return base.replace(
      queryParameters: <String, String>{
        ...base.queryParameters,
        'code': issued.code,
      },
    ).toString();
  }

  bool _stopping = false;

  /// True once shutdown began: new orders are refused, nothing is half saved.
  bool get stopping => _stopping;

  /// Stops the center. New orders are refused first (503, `saved: false`, so
  /// the waiter device keeps the order in its own queue), then the order that
  /// is being saved or printed right now is allowed to finish for up to
  /// [grace], and only then the sockets close. Saved orders and the print
  /// queue live on disk and are untouched.
  Future<void> stop({Duration grace = const Duration(seconds: 5)}) async {
    _stopping = true;
    final server = _server;
    final browser = _browserServer;
    if (server != null || browser != null) {
      try {
        await _orders.transaction(() async {}).timeout(grace);
      } catch (_) {
        // Grace ran out: the journal already holds whatever was accepted.
      }
    }
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

  Future<bool> _refusedWhileStopping(HttpRequest request) async {
    if (!_stopping) return false;
    request.response.headers.set(HttpHeaders.retryAfterHeader, '5');
    await _send(request, 503, <String, Object?>{
      'ok': false,
      'saved': false,
      'error': 'Yerel merkez kapanıyor. Sipariş cihazda bekliyor.',
    });
    return true;
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
        final issued = issuePairingCode();
        await _send(request, 200, <String, Object?>{
          'ok': true,
          'code': issued.code,
          'expires_at': issued.expiresAt.toUtc().toIso8601String(),
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
        final enrolled = await _enrollDevice(csr: csr, staffId: staffId);
        await _send(request, enrolled.status, enrolled.body);
        return;
      }
      if (path == '/lan/pair/request' && request.method == 'POST') {
        await _handlePairRequest(request);
        return;
      }
      if (path == '/lan/pair/status' && request.method == 'POST') {
        await _handlePairStatus(request);
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
        await revokeDevice(deviceId);
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
      _touchDevice(fingerprint);
      await _persistDevices();
      final deviceId = fingerprint;
      if ((path == '/lan/tables' || path == '/lan/products') && request.method == 'POST') {
        if (path == '/lan/tables') {
          final tables = _tablesForStaff(
            tablesOverride ?? (await _cache.read(restaurantId))?.tables,
            deviceId,
          )?.map(stripLanSecrets).toList(growable: false);
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
      if (path == '/lan/center/status' && request.method == 'POST') {
        final cache = await _cache.read(restaurantId);
        final tables = _tablesForStaff(
              tablesOverride ?? cache?.tables,
              deviceId,
            ) ??
            const <Map<String, dynamic>>[];
        final status = await buildLanCenterStatus(
          machineId: machineId ?? '',
          printBridgeUri: printBridgeUri,
          tables: tables,
          printers: cache?.printers ?? const <Map<String, dynamic>>[],
          stations: cache?.stations ?? const <Map<String, dynamic>>[],
          stationPrinters:
              cache?.stationPrinters ?? const <Map<String, dynamic>>[],
          orders: await _orders.list(restaurantId),
          printJobs: await _printQueue?.list(restaurantId),
          branchLimited:
              (_devices[deviceId]?.staffBranchId?.trim() ?? '').isNotEmpty,
        );
        await _send(request, 200, <String, Object?>{'ok': true, ...status});
        return;
      }
      if (path == '/lan/printers/scan' && request.method == 'POST') {
        await _handlePrinterScan(request, body, staffId);
        return;
      }
      if (path == '/lan/orders' && request.method == 'POST') {
        if (await _refusedWhileStopping(request)) return;
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
    final tableDenied = await _tableScopeError(
      deviceId,
      int.tryParse(body['table_number']?.toString() ?? ''),
    );
    if (tableDenied != null) {
      await _send(request, 403, <String, Object?>{
        'ok': false,
        'saved': false,
        'error': tableDenied,
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
    final priced = pricedOfflineItems(
      items: _items(body['items']),
      catalog: catalog,
      requestStationId: stationId,
    );
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
    final physicalAttempt =
        enablePhysicalPrint && stationId.isNotEmpty && onPhysicalPrint != null;
    if (bridgeStatus == null && !physicalAttempt) {
      // Nothing was handed to any printer. Record that as a definite fact so
      // the cloud sync can print it instead of guessing from "pending".
      await _orders.update(
        restaurantId: restaurantId,
        order: order.copyWith(printStatus: 'not_sent', updatedAt: _clock()),
      );
    }
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
    if (!RestaurantLanHostRegistry.ordersSettled.isClosed) {
      RestaurantLanHostRegistry.ordersSettled.add(order.localOrderId);
    }
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

  bool _printerScanRunning = false;

  /// A paired device asks this computer to look for network printers. The
  /// phone has no print bridge and may not scan the network itself; the
  /// search this computer's own bridge already offers is run here and the
  /// result goes back over the authenticated channel. Only a member who
  /// holds the printer-settings permission may ask, and the cloud must
  /// confirm it for this request.
  Future<void> _handlePrinterScan(
    HttpRequest request,
    Map<String, dynamic> body,
    String staffId,
  ) async {
    StaffProbe? probe;
    try {
      probe = await staffStillAuthorized?.call(staffId);
    } catch (_) {
      probe = null;
    }
    if (probe == null || probe.kind == StaffProbeKind.unreachable) {
      await _send(request, 503, <String, Object?>{
        'ok': false,
        'errorCode': 'authority_unverified',
        'error':
            'Yazıcı yönetimi yetkisi doğrulanamadı. Bu işlem için internet gerekir.',
      });
      return;
    }
    if (!probe.isActive || !probe.permissions.contains('managePrintSettings')) {
      await _send(request, 403, <String, Object?>{
        'ok': false,
        'errorCode': 'not_allowed',
        'error': 'Yazıcı taraması için yazıcı yönetimi yetkisi gerekir.',
      });
      return;
    }
    final bridge = printBridgeUri;
    if (bridge == null) {
      await _send(request, 503, <String, Object?>{
        'ok': false,
        'errorCode': 'bridge_unavailable',
        'error': 'Ana bilgisayarda yazıcı köprüsü yok.',
      });
      return;
    }
    final port = int.tryParse(body['port']?.toString() ?? '') ?? 9100;
    final hint = body['printer_host']?.toString().trim() ?? '';
    if (port < 1 || port > 65535 || (hint.isNotEmpty && !_privateIpv4(hint))) {
      await _send(request, 400, <String, Object?>{
        'ok': false,
        'errorCode': 'bad_request',
        'error': 'Tarama isteği geçersiz.',
      });
      return;
    }
    if (_printerScanRunning) {
      await _send(request, 429, <String, Object?>{
        'ok': false,
        'errorCode': 'scan_busy',
        'error': 'Başka bir tarama sürüyor. Bitince yeniden deneyin.',
      });
      return;
    }
    _printerScanRunning = true;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final bytes = utf8.encode(jsonEncode(<String, Object?>{
        'port': port,
        if (hint.isNotEmpty) 'printer_host': hint,
      }));
      final outgoing = await client.postUrl(
        bridge.replace(path: '/printer/tcp/scan'),
      );
      outgoing.headers.contentType = ContentType.json;
      // The bridge refuses a chunked body.
      outgoing.contentLength = bytes.length;
      outgoing.add(bytes);
      final response = await outgoing.close().timeout(
        const Duration(seconds: 40),
      );
      final text = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 10),
      );
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (decoded is! Map) {
        await _send(request, 502, <String, Object?>{
          'ok': false,
          'errorCode': 'scan_unavailable',
          'error': response.statusCode == 404
              ? 'Ana bilgisayardaki yazıcı köprüsü güncel değil; otomatik tarama desteklemiyor.'
              : 'Yazıcı köprüsü taramayı yanıtlamadı.',
        });
        return;
      }
      await _send(request, 200, <String, Object?>{
        'ok': true,
        'scan': Map<String, dynamic>.from(decoded),
      });
    } on TimeoutException {
      await _send(request, 504, <String, Object?>{
        'ok': false,
        'errorCode': 'scan_timeout',
        'error': 'Ağ taraması zamanında bitmedi.',
      });
    } on SocketException {
      await _send(request, 503, <String, Object?>{
        'ok': false,
        'errorCode': 'bridge_unreachable',
        'error':
            'Ana bilgisayarda yazıcı köprüsü çalışmıyor. Yazıcı Merkezi\'ni ana bilgisayardan başlatın.',
      });
    } catch (_) {
      await _send(request, 502, <String, Object?>{
        'ok': false,
        'errorCode': 'scan_failed',
        'error': 'Yazıcı köprüsü taramayı tamamlayamadı.',
      });
    } finally {
      _printerScanRunning = false;
      client.close(force: true);
    }
  }

  bool _privateIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final bytes = parts.map(int.tryParse).toList(growable: false);
    if (bytes.any((byte) => byte == null || byte < 0 || byte > 255)) return false;
    final a = bytes[0]!;
    final b = bytes[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  /// Signs the device's request and records the device. The staff member is
  /// checked with the cloud while it is likely reachable, so the device can
  /// work through a later outage: a rejection refuses the pairing, an
  /// unreachable cloud leaves it unverified (no offline authority yet).
  Future<({int status, Map<String, Object?> body})> _enrollDevice({
    required String csr,
    required String staffId,
    String? deviceName,
    String? platform,
  }) async {
    final signed = await _signCsr(csr);
    if (signed == null || _devices[signed.fingerprint]?.revoked == true) {
      return (
        status: 401,
        body: <String, Object?>{
          'ok': false,
          'error': 'Cihaz sertifikası doğrulanamadı.',
        },
      );
    }
    _devices[signed.fingerprint] = RestaurantLanDevice(
      deviceId: signed.fingerprint,
      pairedAt: _clock(),
      staffId: staffId,
      branchId: branchId,
      deviceName: deviceName,
      platform: platform,
    );
    _inboundSeq[signed.fingerprint] = 0;
    if (staffStillAuthorized != null) {
      final pairError = await _staffGrantError(
        _devices[signed.fingerprint]!,
        signed.fingerprint,
      );
      if (_devices[signed.fingerprint]?.revoked == true) {
        _devices.remove(signed.fingerprint);
        await _persistDevices();
        return (
          status: 403,
          body: <String, Object?>{
            'ok': false,
            'error': pairError ?? 'Personel yetkisi doğrulanamadı.',
          },
        );
      }
    }
    await _persistDevices();
    return (
      status: 200,
      body: <String, Object?>{
        'ok': true,
        'restaurant_id': restaurantId,
        'staff_id': staffId,
        'certificate': signed.certificate,
      },
    );
  }

  final Map<String, LanPairingRequest> _pairRequests =
      <String, LanPairingRequest>{};

  /// Pairing requests the operator has not answered yet.
  List<LanPairingRequest> get pendingPairingRequests {
    final now = _clock();
    return _pairRequests.values
        .where((row) =>
            row.state == LanPairingState.pending &&
            row.matchCode.isNotEmpty &&
            now.isBefore(row.expiresAt))
        .toList(growable: false);
  }

  void _dropOldPairRequests() {
    final now = _clock();
    _pairRequests.removeWhere(
      (_, row) => !now.isBefore(row.expiresAt.add(const Duration(minutes: 1))),
    );
  }

  /// A waiter device asks to be paired. Nothing is granted here: the request
  /// waits for the operator of this computer, who compares the six digits
  /// with the phone and approves. The device is not known yet, so the same
  /// attempt limit as the pairing code applies.
  Future<void> _handlePairRequest(HttpRequest request) async {
    final body = await _readBody(request);
    final client = (request.connectionInfo?.remoteAddress.address ?? '').trim();
    final guard = _pairingAttempts.putIfAbsent(client, PairingAttemptGuard.new);
    final now = _clock();
    if (!guard.allow(now)) {
      await _send(request, 429, <String, Object?>{
        'ok': false,
        'error': 'Çok fazla eşleştirme denemesi. Kısa süre bekleyin.',
      });
      return;
    }
    // Every request counts: an unknown device may not keep the operator's
    // screen busy.
    guard.recordFailure(now);
    _dropOldPairRequests();
    final staffId = body['staff_id']?.toString().trim() ?? '';
    final csr = body['csr']?.toString() ?? '';
    final commit = body['commit']?.toString().trim().toLowerCase() ?? '';
    final requestedRestaurant = body['restaurant_id']?.toString().trim() ?? '';
    final csrLooksValid = csr.length >= 32 &&
        csr.length <= 8192 &&
        csr.contains('BEGIN CERTIFICATE REQUEST') &&
        csr.contains('END CERTIFICATE REQUEST');
    if (requestedRestaurant != restaurantId) {
      await _send(request, 403, <String, Object?>{
        'ok': false,
        'error': 'Bu cihazın restoran yetkisi yok.',
      });
      return;
    }
    if (staffId.isEmpty ||
        staffId.length > 64 ||
        !csrLooksValid ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(commit) ||
        certificateDirectory == null) {
      await _send(request, 400, <String, Object?>{
        'ok': false,
        'error': 'Eşleştirme isteği geçersiz.',
      });
      return;
    }
    final waiting = _pairRequests.values
        .where((row) =>
            row.state == LanPairingState.pending && now.isBefore(row.expiresAt))
        .length;
    if (waiting >= 3) {
      await _send(request, 429, <String, Object?>{
        'ok': false,
        'error': 'Onay bekleyen başka cihazlar var. Biraz sonra yeniden deneyin.',
      });
      return;
    }
    String label(Object? raw) {
      final text = raw?.toString().replaceAll(RegExp(r'[\x00-\x1f]'), ' ').trim() ?? '';
      return text.length > 60 ? text.substring(0, 60) : text;
    }

    final pending = LanPairingRequest(
      id: newPairingSecret(_random),
      staffId: staffId,
      staffName: label(body['staff_name']),
      deviceName: label(body['device_name']),
      platform: label(body['platform']).toLowerCase(),
      csr: csr,
      commit: commit,
      hostNonce: newPairingSecret(_random),
      remoteAddress: client,
      expiresAt: now.add(PairingAttemptGuard.codeTtl),
    );
    _pairRequests[pending.id] = pending;
    await _send(request, 200, <String, Object?>{
      'ok': true,
      'request_id': pending.id,
      'host_nonce': pending.hostNonce,
      'expires_at': pending.expiresAt.toUtc().toIso8601String(),
    });
  }

  /// The device reveals its nonce (first call) and then waits for the
  /// operator's answer. The request is shown to the operator only after the
  /// reveal matches the commitment.
  Future<void> _handlePairStatus(HttpRequest request) async {
    final body = await _readBody(request);
    final id = body['request_id']?.toString().trim() ?? '';
    final nonce = body['nonce']?.toString().trim() ?? '';
    final pending = _pairRequests[id];
    final client = (request.connectionInfo?.remoteAddress.address ?? '').trim();
    if (pending == null || pending.remoteAddress != client) {
      await _send(request, 404, <String, Object?>{
        'ok': false,
        'state': 'expired',
        'error': 'Eşleştirme isteği bulunamadı veya süresi doldu.',
      });
      return;
    }
    if (pending.state == LanPairingState.pending &&
        !_clock().isBefore(pending.expiresAt)) {
      pending.state = LanPairingState.expired;
      pending.error = 'Eşleştirme isteğinin süresi doldu.';
    }
    if (pending.state == LanPairingState.pending && pending.matchCode.isEmpty) {
      if (nonce.isEmpty || lanPairingCommit(nonce) != pending.commit) {
        pending.state = LanPairingState.denied;
        pending.error = 'Eşleştirme doğrulanamadı.';
      } else {
        pending.matchCode = lanPairingMatchCode(
          serverFingerprint: await _announcedFingerprint(),
          csr: pending.csr,
          deviceNonce: nonce,
          hostNonce: pending.hostNonce,
        );
        if (!RestaurantLanHostRegistry.pairingRequests.isClosed) {
          RestaurantLanHostRegistry.pairingRequests.add(pending);
        }
      }
    }
    final certificate = pending.certificate;
    final approved = pending.state == LanPairingState.approved;
    if (approved && certificate != null) {
      // Handed over once; a second read finds nothing.
      _pairRequests.remove(id);
    }
    await _send(request, 200, <String, Object?>{
      'ok': pending.state == LanPairingState.pending || approved,
      'state': pending.state.name,
      if (approved && certificate != null) 'certificate': certificate,
      if (approved) 'restaurant_id': restaurantId,
      'error': ?pending.error,
    });
  }

  /// The operator of this computer accepted the device. Returns null on
  /// success, otherwise what to tell the operator (the staff member may be
  /// refused by the cloud).
  Future<String?> approvePairingRequest(String id) async {
    final pending = _pairRequests[id];
    if (pending == null || pending.state != LanPairingState.pending) {
      return 'Eşleştirme isteği artık geçerli değil.';
    }
    if (pending.matchCode.isEmpty || !_clock().isBefore(pending.expiresAt)) {
      pending.state = LanPairingState.expired;
      pending.error = 'Eşleştirme isteğinin süresi doldu.';
      return pending.error;
    }
    // Claimed before the cloud check, so two approvals cannot both enroll.
    pending.state = LanPairingState.approving;
    final enrolled = await _enrollDevice(
      csr: pending.csr,
      staffId: pending.staffId,
      deviceName: pending.deviceName,
      platform: pending.platform,
    );
    final certificate = enrolled.body['certificate']?.toString() ?? '';
    if (enrolled.status != 200 || certificate.isEmpty) {
      pending.state = LanPairingState.denied;
      pending.error =
          enrolled.body['error']?.toString() ?? 'Cihaz eşleştirilemedi.';
      return pending.error;
    }
    pending.certificate = certificate;
    pending.state = LanPairingState.approved;
    // The device now has a moment to collect its certificate.
    pending.expiresAt = _clock().add(PairingAttemptGuard.codeTtl);
    return null;
  }

  void denyPairingRequest(String id) {
    final pending = _pairRequests[id];
    if (pending == null || pending.state != LanPairingState.pending) return;
    pending.state = LanPairingState.denied;
    pending.error = 'Ana bilgisayar eşleştirmeyi reddetti.';
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
    // A changed epoch means the account was deactivated, re-activated,
    // re-linked or its password replaced since this device was paired: the
    // pairing is revoked for good and the device must pair again. A device
    // record that never saw an epoch just stores the server's value.
    final knownEpoch = paired.staffEpoch;
    final serverEpoch = result.credentialEpoch;
    if (knownEpoch != null && serverEpoch != null && knownEpoch != serverEpoch) {
      _devices[fingerprint] = paired.copy(revoked: true);
      await _persistDevices();
      return 'Personel hesabı değişti. Cihazı yeniden eşleştirin.';
    }
    final verified = paired.copy(
      staffEpoch: serverEpoch,
      staffVerified: true,
      verifiedAt: now,
      expiresAt: now.add(deviceGrantTtl),
      staffBranchId: result.branchId ?? '',
    );
    final seal = await _authoritySealer.sign(
      verified.authorityCanonical(restaurantId),
    );
    // No seal (keystore refused) still serves this online request but leaves
    // nothing to trust once the cloud is gone.
    _devices[fingerprint] = seal == null
        ? verified.copy(authoritySeal: '')
        : verified.copy(authoritySeal: seal);
    await _persistDevices();
    return null;
  }

  /// Same rule as the server's `restaurant_table_access`: a staff member
  /// limited to a branch may only use active tables of that branch. A table
  /// the center cannot find is refused for a limited member (fail closed).
  Future<String?> _tableScopeError(String deviceId, int? tableNumber) async {
    final staffBranch = _devices[deviceId]?.staffBranchId?.trim() ?? '';
    final tables = tablesOverride ?? (await _cache.read(restaurantId))?.tables;
    Map<String, dynamic>? table;
    if (tables != null && tableNumber != null) {
      for (final row in tables) {
        if (int.tryParse(row['table_number']?.toString() ?? '') == tableNumber) {
          table = row;
          break;
        }
      }
    }
    if (table != null && table['is_active'] == false) {
      return 'Bu masa kapalı. Bu masada işlem yetkiniz yok.';
    }
    if (staffBranch.isEmpty) return null;
    if (table == null) return 'Bu masada işlem yetkiniz yok.';
    final tableBranch = table['branch_id']?.toString().trim() ?? '';
    // A table without a branch (created before branches existed) stays inside
    // the store for every member, exactly as the server rule
    // restaurant_staff_branch_can_see_table does. Only a different branch is closed.
    if (tableBranch.isEmpty) return null;
    if (tableBranch != staffBranch) return 'Bu masada işlem yetkiniz yok.';
    return null;
  }

  List<Map<String, dynamic>>? _tablesForStaff(
    List<Map<String, dynamic>>? tables,
    String deviceId,
  ) {
    final staffBranch = _devices[deviceId]?.staffBranchId?.trim() ?? '';
    if (tables == null || staffBranch.isEmpty) return tables;
    return tables
        .where((row) => row['branch_id']?.toString().trim() == staffBranch)
        .toList(growable: false);
  }

  /// Cloud unreachable: only a sealed, unexpired authority from an earlier
  /// online check counts. Nothing here extends it, and role or job title play
  /// no part. A record that was edited, copied, or sealed without a keystore
  /// is refused.
  Future<String?> _offlineStaffGrant(
    RestaurantLanDevice paired,
    DateTime now,
  ) async {
    if (!paired.staffVerified ||
        paired.verifiedAt == null ||
        paired.expiresAt == null) {
      return 'Personel daha önce doğrulanmadı.';
    }
    final sealed = await _authoritySealer.verify(
      paired.authorityCanonical(restaurantId),
      paired.authoritySeal ?? '',
    );
    if (!sealed) {
      return 'Kayıtlı personel yetkisi doğrulanamadı. Bulut bağlantısı gerekli.';
    }
    if (now.isBefore(paired.verifiedAt!)) {
      return 'Cihaz saati geri alındı. Yetki uzatılmadı.';
    }
    if (!now.isBefore(paired.expiresAt!)) {
      return 'Kayıtlı personel yetkisinin süresi doldu.';
    }
    final staffBranch = paired.staffBranchId?.trim() ?? '';
    final center = branchId?.trim() ?? '';
    if (staffBranch.isNotEmpty && staffBranch != center) {
      return 'Bu personelin şubesi bu merkezin şubesi değil.';
    }
    return null;
  }

  /// Cloud came back: re-check every paired device now instead of waiting for
  /// its next request, so a membership revoked during the outage is closed at
  /// once. Returns how many devices were closed.
  Future<int> reverifyDevices() async {
    final probe = staffStillAuthorized;
    if (probe == null) return 0;
    var closed = 0;
    for (final entry in _devices.entries.toList()) {
      final device = entry.value;
      if (device.revoked || device.staffId.isEmpty) continue;
      final error = await _staffGrantError(device, entry.key);
      if (error != null && _devices[entry.key]?.revoked == true) {
        closed++;
        for (final grant in _browserGrants.values) {
          if (grant.deviceId == entry.key) grant.revoked = true;
        }
      }
    }
    return closed;
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
      final printer = await _stationPrinterSnapshot(station);
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
          printerSnapshot: printer,
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

  Future<Map<String, dynamic>> _stationPrinterSnapshot(String station) async {
    final resolve = stationPrinter;
    if (resolve == null) return const <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(
        await resolve(station).timeout(const Duration(seconds: 4)),
      );
    } catch (_) {
      // The order is still saved. The ticket is recorded as definitely not
      // sent instead of going to a printer nobody chose.
      return const <String, dynamic>{
        'resolution_error':
            'İstasyon yazıcısı belirlenemedi. Fiş gönderilmedi.',
      };
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
    return combineStationPrintStatuses(statuses);
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
    final signature = signSha256Rsa(
      await File(identity.path).readAsString(),
      utf8.encode(payload),
    );
    if (signature == null || signature.isEmpty) return null;
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
    final priced = pricedOfflineItems(
      items: items,
      catalog: catalog,
      requestStationId: '',
    );
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
      // A browser grant lasts hours; the staff check runs on every request so
      // a revoked or limited member stops at once, like a paired device.
      final browserDevice = _devices[grant.deviceId];
      final browserStaffError = browserDevice == null
          ? 'Cihaz eşleşmesi yok veya iptal edildi.'
          : browserDevice.revoked
              ? 'Cihaz eşleşmesi yok veya iptal edildi.'
              : await _staffGrantError(browserDevice, grant.deviceId);
      if (browserStaffError != null) {
        grant.revoked = true;
        await _send(request, 401, <String, Object?>{
          'ok': false,
          'error': browserStaffError,
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
        final tables = _tablesForStaff(
          tablesOverride ?? (await _cache.read(restaurantId))?.tables,
          grant.deviceId,
        )?.map(stripLanSecrets).toList(growable: false);
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
        if (await _refusedWhileStopping(request)) return;
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
    final verifiedPending = _devices.remove('browser-pending');
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
    var browserDevice = RestaurantLanDevice(
      deviceId: deviceId,
      pairedAt: _clock(),
      staffId: staffId,
      branchId: branchId,
      staffBranchId: verifiedPending?.staffBranchId,
      staffVerified: verifiedPending?.staffVerified ?? false,
      verifiedAt: verifiedPending?.verifiedAt,
      expiresAt: verifiedPending?.expiresAt,
    );
    if (browserDevice.staffVerified) {
      // The seal names the device, so the pending record's seal cannot carry
      // over to the real browser device.
      final seal = await _authoritySealer.sign(
        browserDevice.authorityCanonical(restaurantId),
      );
      browserDevice = browserDevice.copy(authoritySeal: seal ?? '');
    }
    _devices[deviceId] = browserDevice;
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
      // In process first: no external `openssl`, so the sandboxed app signs
      // device certificates too. The CA key never leaves this directory.
      final dartCert = await signCsrWithDartCa(
        directory: Directory(root),
        csrPem: csr,
      );
      if (dartCert != null && dartCert.trim().isNotEmpty) {
        return (certificate: dartCert, fingerprint: certificateSha256Hex(dartCert));
      }
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
      if (result.exitCode != 0 || !outFile.existsSync()) return null;
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
    devicesRevision.value++;
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

enum LanPairingState { pending, approving, approved, denied, expired }

/// A waiter device waiting for the operator of this computer.
class LanPairingRequest {
  LanPairingRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.deviceName,
    this.platform = '',
    required this.csr,
    required this.commit,
    required this.hostNonce,
    required this.remoteAddress,
    required this.expiresAt,
  });

  /// Known only to the device that asked; never shown.
  final String id;
  final String staffId;

  /// What the device says about itself. Shown to the operator as a hint; the
  /// staff member is checked with the cloud on approval.
  final String staffName;
  final String deviceName;
  final String platform;
  final String csr;
  final String commit;
  final String hostNonce;
  final String remoteAddress;
  DateTime expiresAt;

  /// The six digits to compare with the phone. Empty until the device has
  /// revealed its nonce.
  String matchCode = '';
  LanPairingState state = LanPairingState.pending;
  String? certificate;
  String? error;
}

abstract class RestaurantLanOrderTransport {
  Future<bool> submit(RestaurantLocalOrderRecord order);
}

class RestaurantLanPairing {
  static RestaurantLanOrderTransport? transport;

  /// Whether the paired center answered the last time this device asked.
  /// When it does not (the computer is off, another network) and the cloud
  /// is reachable, orders take the cloud route instead of waiting.
  static bool centerReachable = true;

  /// Asks the paired center again right now (set by the waiter link). Used
  /// when the cloud just failed and the last answer from the center is old.
  static Future<void> Function()? recheck;
}

class RestaurantLanHostRegistry {
  static RestaurantLanHost? current;

  /// Accepted floor orders. The seller screen listens here; the cloud does not.
  static final StreamController<RestaurantLocalOrderRecord> ordersAccepted =
      StreamController<RestaurantLocalOrderRecord>.broadcast();

  /// Local order ids whose ticket outcome is now recorded. Sending an order
  /// to the cloud waits for this: at "accepted" the ticket is still on its
  /// way, and it would go up as "uncertain" although it printed.
  static final StreamController<String> ordersSettled =
      StreamController<String>.broadcast();

  /// A device asked to be paired and proved its request; the operator's
  /// screen shows it for approval.
  static final StreamController<LanPairingRequest> pairingRequests =
      StreamController<LanPairingRequest>.broadcast();
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


