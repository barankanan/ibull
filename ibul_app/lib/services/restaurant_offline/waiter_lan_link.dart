import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/secure_local_store.dart';
import 'lan_center_browser.dart';
import 'lan_center_discovery.dart';
import 'lan_pairing_guard.dart';
import 'lan_tls.dart';
import 'paired_lan_transport.dart';
import 'restaurant_lan_host.dart';

/// Where the pairing lives. The device key goes to the platform keystore
/// (Keychain / Keystore) only; a keystore that refuses it stops the pairing.
abstract class WaiterLinkStore {
  Future<Object?> readJson(String key);
  Future<void> writeJson(String key, Object? value);
  Future<String?> readSecret(String key);
  Future<bool> writeSecret(String key, String value);
}

class KeystoreWaiterLinkStore implements WaiterLinkStore {
  const KeystoreWaiterLinkStore();

  @override
  Future<Object?> readJson(String key) async =>
      await SecureLocalStore.instance.readJson(key);

  @override
  Future<void> writeJson(String key, Object? value) =>
      SecureLocalStore.instance.writeJson(key, value);

  @override
  Future<String?> readSecret(String key) =>
      SecureLocalStore.instance.readSecret(key);

  @override
  Future<bool> writeSecret(String key, String value) =>
      SecureLocalStore.instance.writeSecret(key, value);
}

enum WaiterLanLinkPhase {
  /// Not started (no signed-in restaurant staff on this device).
  off,
  searching,

  /// No center of this restaurant is announced on this network.
  noCenter,

  /// A center was found; this device has not been approved on it yet.
  centerFound,

  /// The request is on the operator's screen; both show [WaiterLanLink.matchCode].
  waitingApproval,
  paired,
  failed,
}

/// Keeps a signed-in waiter's phone attached to the restaurant's own computer
/// without the technical "Garson cihazı" form.
///
/// The person is the account that signed in; nothing is typed. The center is
/// found through its Bonjour announcement, the first connection is approved
/// by the operator of the center (both screens show the same six digits), and
/// from then on the stored device key and the pinned server certificate are
/// reused at every launch. The announcement alone is never trusted: a center
/// is used again only when it presents the certificate this device pinned.
class WaiterLanLink extends ChangeNotifier {
  WaiterLanLink({
    LanCenterBrowser? browser,
    WaiterLinkStore? store,
    Future<Directory> Function(String restaurantId)? certificateDirectory,
    Duration pollEvery = const Duration(milliseconds: 1500),
    Duration watchEvery = const Duration(seconds: 15),
    this.centerPort = lanOrderPort,
  }) : _browser = browser ?? LanCenterBrowser(),
       _store = store ?? const KeystoreWaiterLinkStore(),
       _certificateDirectory = certificateDirectory ?? _defaultDirectory,
       _pollEvery = pollEvery,
       _watchEvery = watchEvery;

  /// Port a center of this build listens on; an announcement on any other
  /// port is ignored.
  final int centerPort;

  static final WaiterLanLink instance = WaiterLanLink();

  /// Same record the diagnostic "Garson cihazı" screen reads and writes.
  static const String sessionKey = 'ibul_lan_waiter_session';

  final LanCenterBrowser _browser;
  final WaiterLinkStore _store;
  final Future<Directory> Function(String restaurantId) _certificateDirectory;
  final Duration _pollEvery;
  final Duration _watchEvery;

  String _restaurantId = '';
  String _staffId = '';
  String _staffName = '';

  WaiterLanLinkPhase _phase = WaiterLanLinkPhase.off;
  String _message = '';
  String _matchCode = '';
  bool _centerReachable = false;
  LanCenterRecord? _candidate;

  String _host = '';
  String _pin = '';
  String _keyPin = '';
  String _machine = '';
  int _seq = 0;
  LanClientCertificate? _certificate;

  Timer? _watch;
  int _pairingRun = 0;
  Future<void> _sendChain = Future<void>.value();

  WaiterLanLinkPhase get phase => _phase;
  String get message => _message;

  /// Six digits, shown on this device and on the center while it waits.
  String get matchCode => _matchCode;
  bool get paired => _phase == WaiterLanLinkPhase.paired;
  bool get centerReachable => paired && _centerReachable;
  String get restaurantId => _restaurantId;

  /// Saved address of the paired center and its machine id (display only;
  /// empty when nothing is saved). Never the pin, key or certificate.
  String get centerAddress => _host;
  String get centerMachineId => _machine;

  static Future<Directory> _defaultDirectory(String restaurantId) async {
    if (Platform.isIOS || Platform.isAndroid) {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}/ibul-lan-waiter/$restaurantId');
    }
    return Directory(
      lanMaterialDirectory(
        operatingSystem: Platform.operatingSystem,
        environment: Platform.environment,
        restaurantId: 'waiter-$restaurantId',
      ),
    );
  }

  String get _keyName => 'ibul_lan_waiter_key_$_restaurantId';

  /// Called once the signed-in account and its restaurant are known. The
  /// staff id is the authenticated user's id, never typed text.
  Future<void> start({
    required String restaurantId,
    required String staffId,
    String staffName = '',
  }) async {
    final restaurant = restaurantId.trim();
    final staff = staffId.trim();
    if (restaurant.isEmpty || staff.isEmpty) return;
    if (_phase != WaiterLanLinkPhase.off &&
        restaurant == _restaurantId &&
        staff == _staffId) {
      return;
    }
    stop();
    _restaurantId = restaurant;
    _staffId = staff;
    _staffName = staffName.trim();
    _set(WaiterLanLinkPhase.searching, '');
    await _restore();
    _watch = Timer.periodic(_watchEvery, (_) => unawaited(refresh()));
    await refresh();
  }

  /// Sign-out or another account: the phone stops sending for this person.
  /// The stored pairing stays, so the same person is attached again at the
  /// next sign-in without a new approval.
  void stop() {
    _watch?.cancel();
    _watch = null;
    _pairingRun += 1;
    _certificate = null;
    _candidate = null;
    _host = '';
    _pin = '';
    _keyPin = '';
    _machine = '';
    _seq = 0;
    _matchCode = '';
    _centerReachable = false;
    RestaurantLanPairing.transport = null;
    RestaurantLanPairing.centerReachable = true;
    RestaurantLanPairing.recheck = null;
    _restaurantId = '';
    _staffId = '';
    if (_phase != WaiterLanLinkPhase.off) {
      _set(WaiterLanLinkPhase.off, '');
    }
  }

  Future<void> _restore() async {
    final stored = await _store.readJson(sessionKey);
    if (stored is! Map) return;
    // A pairing belongs to one person in one restaurant. Somebody else who
    // signs in on this phone is approved separately.
    if (stored['restaurant_id']?.toString() != _restaurantId ||
        stored['staff_id']?.toString() != _staffId) {
      return;
    }
    final pin = LanTlsMaterial.normalizeFingerprint(
      stored['server_fingerprint']?.toString() ?? '',
    );
    final host = stored['host']?.toString().trim() ?? '';
    final machine = stored['machine_id']?.toString().trim() ?? '';
    if (pin.isEmpty || host.isEmpty || machine.isEmpty) return;
    final directory = await _certificateDirectory(_restaurantId);
    final savedKey = await _store.readSecret(_keyName);
    if (savedKey == null || !savedKey.contains('PRIVATE KEY')) return;
    try {
      if (!directory.existsSync()) directory.createSync(recursive: true);
      await File('${directory.path}/client.key').writeAsString(savedKey);
      _certificate = await LanClientCertificate.load(directory: directory);
    } catch (_) {
      _certificate = null;
    }
    if (_certificate == null) return;
    _host = host;
    _pin = pin;
    _keyPin = stored['server_key']?.toString().trim().toLowerCase() ?? '';
    _machine = machine;
    _seq = (stored['seq'] as num?)?.toInt() ?? 0;
    _bind();
    // Not known yet; the first check right after this decides.
    RestaurantLanPairing.centerReachable = false;
    _set(WaiterLanLinkPhase.paired, 'Ana bilgisayara bağlı.');
  }

  Future<void> _persist() async {
    await _store.writeJson(sessionKey, <String, Object?>{
      'host': _host,
      'server_fingerprint': _pin,
      'server_key': _keyPin,
      'staff_id': _staffId,
      'machine_id': _machine,
      'qr_accepted': false,
      'cert_dir': _certificate?.directory.path,
      'restaurant_id': _restaurantId,
      'seq': _seq,
    });
  }

  void _bind() {
    RestaurantLanPairing.transport = PairedLanTransport(_sendAuthorized);
    RestaurantLanPairing.recheck = refresh;
  }

  Uri? _uri(String host) {
    final text = host.trim();
    final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') return null;
    return uri;
  }

  RestaurantLanClient _anonymous(String host, String pin, {String keyPin = ''}) {
    return RestaurantLanClient(
      _uri(host)!,
      securityContext: SecurityContext(withTrustedRoots: false),
      pinnedServerFingerprint: LanTlsMaterial.normalizeFingerprint(pin),
      pinnedServerKey: keyPin,
      staffId: _staffId,
    );
  }

  /// One request at a time, in order: the center refuses a sequence number it
  /// has already seen. The number follows the clock, so it keeps rising after
  /// a restart even if the last save of it was lost.
  Future<Map<String, dynamic>> _sendAuthorized(
    String path,
    Map<String, Object?> body, {
    Duration? responseTimeout,
  }) {
    final done = Completer<Map<String, dynamic>>();
    _sendChain = _sendChain.then((_) async {
      try {
        done.complete(
          await _sendNow(path, body, responseTimeout: responseTimeout),
        );
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// What the screen says when a search cannot go through the center.
  static const String centerNeededForScan =
      'Yazıcı Merkezi\'ne ulaşılamıyor. Ağ taraması ana bilgisayar üzerinden '
      'yapılır: Yazıcı Merkezi\'ni ana bilgisayardan başlatın ve bu cihazı aynı '
      'Wi-Fi ağına bağlayın. Yazıcının IP adresini elle de girebilirsiniz.';

  /// Asks the restaurant's computer to look for network printers and returns
  /// its bridge's answer. This device never scans addresses itself. Throws a
  /// [StateError] with a sentence for the user when the center cannot do it.
  Future<Map<String, dynamic>> scanPrintersThroughCenter({
    int port = 9100,
    String printerHost = '',
  }) async {
    if (!paired) throw StateError(centerNeededForScan);
    final Map<String, dynamic> response;
    try {
      response = await _sendAuthorized(
        '/lan/printers/scan',
        <String, Object?>{
          'port': port,
          if (printerHost.trim().isNotEmpty) 'printer_host': printerHost.trim(),
        },
        responseTimeout: const Duration(seconds: 55),
      );
    } on SocketException {
      throw StateError(centerNeededForScan);
    }
    final scan = response['scan'];
    if (response['ok'] == true && scan is Map) {
      return Map<String, dynamic>.from(scan);
    }
    final reason = response['error']?.toString().trim() ?? '';
    throw StateError(
      '${reason.isEmpty ? 'Ana bilgisayar taramayı yapamadı.' : reason} '
      'Yazıcının IP adresini elle de girebilirsiniz.',
    );
  }

  /// Read-only picture of the restaurant computer: its print center, saved
  /// printers, station matches, sync queue and local orders. Throws when this
  /// device is not paired, the center cannot be reached in time, or it refuses.
  Future<Map<String, dynamic>> centerStatus() async {
    if (!paired) throw StateError('Ana bilgisayarla eşleşme yok.');
    final response = await _sendAuthorized(
      '/lan/center/status',
      const <String, Object?>{},
      responseTimeout: const Duration(seconds: 6),
    ).timeout(const Duration(seconds: 8));
    if (response['ok'] != true) {
      final reason = response['error']?.toString().trim() ?? '';
      throw StateError(
        reason.isEmpty ? 'Ana bilgisayar durumu vermedi.' : reason,
      );
    }
    return response;
  }

  Future<Map<String, dynamic>> _sendNow(
    String path,
    Map<String, Object?> body, {
    Duration? responseTimeout,
  }) async {
    final certificate = _certificate;
    final uri = _uri(_host);
    if (certificate == null || uri == null || _pin.isEmpty) {
      throw const SocketException(
        'Ana bilgisayar kapalı veya yerel ağa ulaşılamıyor.',
      );
    }
    final client = RestaurantLanClient(
      uri,
      securityContext: certificate.context,
      pinnedServerFingerprint: _pin,
      pinnedServerKey: _keyPin,
      staffId: _staffId,
    )..seq = max(_seq, DateTime.now().millisecondsSinceEpoch - 1);
    if (responseTimeout != null) client.responseTimeout = responseTimeout;
    try {
      final response = await client.postAuthorized(path, body);
      _seq = client.seq;
      _noteReachable(true);
      unawaited(_persist());
      return response;
    } on SocketException {
      _seq = client.seq;
      _noteReachable(false);
      // The address may have changed with the network; look for the same
      // center again without holding this order up.
      unawaited(refresh());
      rethrow;
    }
  }

  void _noteReachable(bool reachable) {
    if (!paired) return;
    RestaurantLanPairing.centerReachable = reachable;
    if (_centerReachable == reachable) return;
    _centerReachable = reachable;
    notifyListeners();
  }

  /// Re-checks the saved center, or looks for one when nothing is paired.
  /// Runs at start, on a timer and when the network changes. A caller that
  /// arrives while a check is running waits for that check.
  Future<void> refresh() {
    if (_phase == WaiterLanLinkPhase.off ||
        _phase == WaiterLanLinkPhase.waitingApproval ||
        _phase == WaiterLanLinkPhase.failed) {
      return Future<void>.value();
    }
    return _refreshing ??= _refreshNow().whenComplete(() => _refreshing = null);
  }

  Future<void>? _refreshing;

  Future<void> _refreshNow() async {
    try {
      if (paired) {
        await _checkSavedCenter();
      } else {
        await _search();
      }
    } catch (error) {
      debugPrint('[WaiterLanLink] refresh failed: $error');
    }
  }

  Future<bool> _answersAsSavedCenter(String host) async {
    if (_uri(host) == null) return false;
    try {
      final client = _anonymous(host, _pin, keyPin: _keyPin);
      final found = await client.get('/lan/discover');
      final same = found['service'] == 'ibul-lan' &&
          found['restaurant_id']?.toString() == _restaurantId &&
          found['machine_id']?.toString() == _machine;
      if (same) await _learnServerIdentity(client);
      return same;
    } on SocketException {
      return false;
    }
  }

  /// Remembers the paired center's public key, and follows its certificate
  /// when the center re-issued it for a new address. Only called after that
  /// server passed the pin check and answered as the saved machine.
  Future<void> _learnServerIdentity(RestaurantLanClient client) async {
    final key = client.seenServerKey;
    final fingerprint = client.seenServerFingerprint;
    var changed = false;
    if (_keyPin.isEmpty && key.isNotEmpty && fingerprint == _pin) {
      _keyPin = key;
      changed = true;
    }
    if (_keyPin.isNotEmpty &&
        key == _keyPin &&
        fingerprint.isNotEmpty &&
        fingerprint != _pin) {
      _pin = fingerprint;
      changed = true;
    }
    if (changed) await _persist();
  }

  Future<void> _checkSavedCenter() async {
    final run = _pairingRun;
    if (await _answersAsSavedCenter(_host)) {
      if (run == _pairingRun) _noteReachable(true);
      return;
    }
    // Another network or a new address: only the center that still holds the
    // pinned certificate and the saved machine id is accepted.
    final found = await _browser.browse();
    if (run != _pairingRun || !paired) return;
    final decision = chooseLanCenter(
      restaurantId: _restaurantId,
      found: found,
      trusted: SavedLanCenter(
        restaurantId: _restaurantId,
        machineId: _machine,
        fingerprint: _pin,
      ),
      fromQr: false,
    );
    final record = decision.record;
    if (decision.choice == LanCenterChoice.selected &&
        record != null &&
        record.httpsUri != _host &&
        await _answersAsSavedCenter(record.httpsUri)) {
      if (run != _pairingRun || !paired) return;
      _host = record.httpsUri;
      await _persist();
      _noteReachable(true);
      return;
    }
    // The center moved to another network and re-issued its certificate, so
    // its announced fingerprint is new. It is still the saved center only if
    // it proves the saved key in the TLS handshake and answers with the saved
    // machine id; an announcement alone is never trusted.
    if (_keyPin.isNotEmpty) {
      for (final row in found) {
        if (row.service != 'ibul-lan' ||
            row.restaurantId != _restaurantId ||
            row.machineId != _machine ||
            row.port != centerPort ||
            row.host.trim().isEmpty) {
          continue;
        }
        if (await _answersAsSavedCenter(row.httpsUri)) {
          if (run != _pairingRun || !paired) return;
          _host = row.httpsUri;
          await _persist();
          _noteReachable(true);
          return;
        }
      }
    }
    _noteReachable(false);
  }

  Future<void> _search() async {
    final run = _pairingRun;
    final found = await _browser.browse();
    if (run != _pairingRun || paired) return;
    if (_phase == WaiterLanLinkPhase.failed ||
        _phase == WaiterLanLinkPhase.waitingApproval) {
      return;
    }
    final own = found.where((row) {
      return row.service == 'ibul-lan' &&
          row.restaurantId == _restaurantId &&
          row.port == centerPort &&
          row.host.trim().isNotEmpty &&
          row.machineId.isNotEmpty &&
          row.fingerprint.isNotEmpty;
    }).toList(growable: false);
    final machines = own.map((row) => row.machineId).toSet();
    debugPrint(
      '[WaiterLanLink] announced=${found.length} thisRestaurant=${own.length} '
      'centers=${machines.length}',
    );
    if (machines.length == 1) {
      _candidate = own.first;
      _set(WaiterLanLinkPhase.centerFound, 'Ana bilgisayar bulundu.');
      return;
    }
    _candidate = null;
    _set(
      WaiterLanLinkPhase.noCenter,
      machines.isEmpty
          ? ''
          : 'Bu ağda birden fazla merkez görünüyor. Yalnız biri açık olmalı.',
    );
  }

  /// First connection. Asks the center found on this network to accept this
  /// device for the signed-in person and waits for the operator there.
  Future<void> requestPairing() async {
    final record = _candidate;
    if (record == null || _phase == WaiterLanLinkPhase.waitingApproval) return;
    final run = ++_pairingRun;
    _matchCode = '';
    _set(WaiterLanLinkPhase.waitingApproval, 'Ana bilgisayara bağlanılıyor…');
    bool current() => run == _pairingRun;
    void fail(String text) {
      if (!current()) return;
      _matchCode = '';
      _set(WaiterLanLinkPhase.failed, text);
    }

    try {
      final pin = LanTlsMaterial.normalizeFingerprint(record.fingerprint);
      final anonymous = _anonymous(record.httpsUri, pin);
      final announced = await anonymous.get('/lan/discover');
      if (announced['service'] != 'ibul-lan' ||
          announced['restaurant_id']?.toString() != _restaurantId ||
          announced['machine_id']?.toString() != record.machineId) {
        fail('Bulunan bilgisayar bu restoranın merkezi değil.');
        return;
      }
      final request = await _newDeviceRequest();
      if (request == null) {
        fail('Cihaz anahtarı güvenli saklanamadı. Eşleştirme durduruldu.');
        return;
      }
      if (!current()) return;
      final nonce = newPairingSecret(Random.secure());
      final asked = await anonymous.post('/lan/pair/request', <String, Object?>{
        'restaurant_id': _restaurantId,
        'staff_id': _staffId,
        'staff_name': _staffName,
        'device_name': _deviceName(),
        'platform': Platform.operatingSystem,
        'csr': request.csr,
        'commit': lanPairingCommit(nonce),
      });
      final requestId = asked['request_id']?.toString() ?? '';
      final hostNonce = asked['host_nonce']?.toString() ?? '';
      if (asked['ok'] != true || requestId.isEmpty || hostNonce.isEmpty) {
        fail(
          asked['error']?.toString() ??
              'Ana bilgisayar eşleştirme isteğini kabul etmedi.',
        );
        return;
      }
      if (!current()) return;
      _matchCode = lanPairingMatchCode(
        serverFingerprint: pin,
        csr: request.csr,
        deviceNonce: nonce,
        hostNonce: hostNonce,
      );
      _set(
        WaiterLanLinkPhase.waitingApproval,
        'Ana bilgisayarda aynı kod görünüyorsa orada Onayla\'ya basın.',
      );
      final deadline = DateTime.now().add(PairingAttemptGuard.codeTtl);
      while (current()) {
        final status = await anonymous.post('/lan/pair/status', <String, Object?>{
          'request_id': requestId,
          'nonce': nonce,
        });
        if (!current()) return;
        final state = status['state']?.toString() ?? '';
        final certificate = status['certificate']?.toString() ?? '';
        if (state == 'approved' && certificate.isNotEmpty) {
          if (!current()) return;
          if (!await _installCertificate(request, certificate, record, pin)) {
            fail('Cihaz sertifikası kurulamadı.');
          }
          return;
        }
        if (state != 'pending' && state != 'approving' && state != 'approved') {
          fail(
            status['error']?.toString() ??
                'Eşleştirme onaylanmadı. Yeniden deneyin.',
          );
          return;
        }
        if (DateTime.now().isAfter(deadline)) {
          fail('Ana bilgisayardan onay gelmedi. Yeniden deneyin.');
          return;
        }
        await Future<void>.delayed(_pollEvery);
      }
    } on SocketException {
      fail('Ana bilgisayara ulaşılamadı. Aynı Wi-Fi ağında olduğunuzdan emin olun.');
    } catch (error) {
      debugPrint('[WaiterLanLink] pairing failed: $error');
      fail('Eşleştirme tamamlanamadı. Yeniden deneyin.');
    }
  }

  /// Connection from the link (QR or text) the center shows on its own
  /// screen. Used when this device cannot search the local network. The link
  /// names the center's certificate and carries a one-time code, so no
  /// separate approval is needed; the center still checks the signed-in
  /// person with the cloud.
  Future<void> pairWithLink(String link) async {
    if (_phase == WaiterLanLinkPhase.off ||
        _phase == WaiterLanLinkPhase.waitingApproval ||
        paired) {
      return;
    }
    final run = ++_pairingRun;
    bool current() => run == _pairingRun;
    void fail(String text) {
      if (!current()) return;
      _matchCode = '';
      _set(WaiterLanLinkPhase.failed, text);
    }

    final uri = Uri.tryParse(link.trim());
    final record = decodeLanQr(link, expectedPort: centerPort);
    final code = uri?.queryParameters['code']?.trim() ?? '';
    if (record == null || code.isEmpty || record.port != centerPort) {
      fail('Bağlantı kodu bu uygulamanın ana bilgisayarına ait değil.');
      return;
    }
    if (record.restaurantId != _restaurantId) {
      fail('Bu kod başka bir işletmenin ana bilgisayarına ait.');
      return;
    }
    _matchCode = '';
    _set(WaiterLanLinkPhase.waitingApproval, 'Ana bilgisayara bağlanılıyor…');
    try {
      final pin = LanTlsMaterial.normalizeFingerprint(record.fingerprint);
      final anonymous = _anonymous(record.httpsUri, pin);
      final announced = await anonymous.get('/lan/discover');
      if (announced['service'] != 'ibul-lan' ||
          announced['restaurant_id']?.toString() != _restaurantId ||
          announced['machine_id']?.toString() != record.machineId) {
        fail('Bulunan bilgisayar bu restoranın merkezi değil.');
        return;
      }
      final request = await _newDeviceRequest();
      if (request == null) {
        fail('Cihaz anahtarı güvenli saklanamadı. Eşleştirme durduruldu.');
        return;
      }
      if (!current()) return;
      final redeemed = await anonymous.post('/lan/pair/redeem', <String, Object?>{
        'code': code,
        'restaurant_id': _restaurantId,
        'staff_id': _staffId,
        'csr': request.csr,
      });
      final certificate = redeemed['certificate']?.toString() ?? '';
      if (redeemed['ok'] != true || certificate.isEmpty) {
        fail(
          redeemed['error']?.toString() ??
              'Bağlantı kodu geçersiz veya süresi doldu.',
        );
        return;
      }
      if (!await _installCertificate(request, certificate, record, pin)) {
        fail('Cihaz sertifikası kurulamadı.');
      }
    } on SocketException {
      fail('Ana bilgisayara ulaşılamadı. Aynı Wi-Fi ağında olduğunuzdan emin olun.');
    } catch (error) {
      debugPrint('[WaiterLanLink] link pairing failed: $error');
      fail('Eşleştirme tamamlanamadı. Yeniden deneyin.');
    }
  }

  /// A fresh device key. The private key is handed to the keystore; when the
  /// keystore refuses it, the key file is removed and nothing is requested.
  Future<LanClientRequest?> _newDeviceRequest() async {
    final directory = await _certificateDirectory(_restaurantId);
    final request = await LanClientRequest.generate(
      directory: directory,
      commonName: 'ibul-waiter',
    );
    final keyFile = File('${request.directory.path}/client.key');
    final privateKey = await keyFile.readAsString();
    final stored = privateKey.contains('PRIVATE KEY') &&
        await _store.writeSecret(_keyName, privateKey);
    if (!stored) {
      if (keyFile.existsSync()) await keyFile.delete();
      return null;
    }
    return request;
  }

  Future<bool> _installCertificate(
    LanClientRequest request,
    String certificate,
    LanCenterRecord record,
    String pin,
  ) async {
    await File('${request.directory.path}/client.pem').writeAsString(certificate);
    final loaded = await LanClientCertificate.load(directory: request.directory);
    if (loaded == null) return false;
    _certificate = loaded;
    _host = record.httpsUri;
    _pin = pin;
    _keyPin = '';
    _machine = record.machineId;
    _seq = 0;
    _matchCode = '';
    await _persist();
    _bind();
    // Learn the center's key now, on the network where it was just approved,
    // so the pairing survives the center's next address change.
    try {
      await _answersAsSavedCenter(_host);
    } catch (_) {}
    _centerReachable = true;
    RestaurantLanPairing.centerReachable = true;
    _set(WaiterLanLinkPhase.paired, 'Ana bilgisayara bağlandı.');
    return true;
  }

  /// Leaves the waiting screen; the request on the center simply expires.
  void cancelPairing() {
    if (_phase != WaiterLanLinkPhase.waitingApproval &&
        _phase != WaiterLanLinkPhase.failed) {
      return;
    }
    _pairingRun += 1;
    _matchCode = '';
    _set(
      _candidate == null
          ? WaiterLanLinkPhase.noCenter
          : WaiterLanLinkPhase.centerFound,
      _candidate == null ? '' : 'Ana bilgisayar bulundu.',
    );
    unawaited(refresh());
  }

  String _deviceName() {
    if (Platform.isIOS) return 'iPhone / iPad';
    if (Platform.isAndroid) return 'Android cihaz';
    return Platform.operatingSystem;
  }

  void _set(WaiterLanLinkPhase phase, String message) {
    _phase = phase;
    _message = message;
    notifyListeners();
  }
}
