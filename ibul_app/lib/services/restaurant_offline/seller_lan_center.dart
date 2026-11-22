import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/runtime_config.dart';
import '../../core/secure_local_store.dart';
import 'lan_advertiser.dart';
import 'lan_center_discovery.dart';
import 'lan_interface.dart';
import 'lan_pairing_guard.dart';
import 'lan_staff_probe.dart';
import 'lan_station_printer.dart';
import 'lan_tls.dart';
import 'restaurant_center_access.dart';
import 'restaurant_lan_host.dart';
import 'restaurant_local_print_queue_service.dart';

enum SellerLanCenterState {
  running,
  alreadyRunning,
  needsConfirmation,
  noNetwork,
  notAllowed,
  failed,
}

class SellerLanCenterResult {
  const SellerLanCenterResult(
    this.state, {
    this.message = '',
    this.address,
    this.port = 0,
  });

  final SellerLanCenterState state;
  final String message;
  final String? address;
  final int port;

  bool get isRunning =>
      state == SellerLanCenterState.running ||
      state == SellerLanCenterState.alreadyRunning;
}

typedef LanEvidenceKeyRegistrar = Future<String?> Function({
  required String restaurantId,
  required String keyId,
  required String modulusHex,
  required String serverFingerprint,
  String? branchId,
});

/// Calls the owner-only registration function. A staff account, a missing
/// session or an unreachable cloud all end in an exception; the caller keeps
/// the branch it already knew.
Future<String?> registerEvidenceKeyWithCloud({
  required String restaurantId,
  required String keyId,
  required String modulusHex,
  required String serverFingerprint,
  String? branchId,
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser?.id != restaurantId) return null;
  final answer = await client
      .rpc(
        'register_restaurant_lan_print_evidence_key',
        params: <String, dynamic>{
          'p_restaurant_id': restaurantId,
          'p_key_id': keyId,
          'p_modulus_hex': modulusHex,
          'p_server_fingerprint': serverFingerprint,
          if (branchId != null && branchId.trim().isNotEmpty)
            'p_branch_id': branchId.trim(),
        },
      )
      .timeout(const Duration(seconds: 6));
  return answer?.toString();
}

/// Starts the restaurant's LAN center from the real seller app. It uses the
/// existing host, mTLS material and staff gate; it opens no second server and
/// accepts nobody by default.
///
/// The owner's tap on "start" is the operator confirmation. The listening
/// address is a private LAN interface only, never all interfaces.
class SellerLanCenter {
  SellerLanCenter._();

  static LanAdvertiser advertiser = PlatformLanAdvertiser();

  /// Registers the center's public evidence key with the cloud and returns
  /// the branch the key is bound to. Null in tests and wherever the cloud is
  /// not used. Only the public modulus is passed; the private key stays in
  /// the material directory.
  static LanEvidenceKeyRegistrar? evidenceKeyRegistrar =
      registerEvidenceKeyWithCloud;

  static String _branchKey(String restaurantId) =>
      'ibul.lan_center.branch.${restaurantId.trim()}';

  /// The branch this center was last registered under.
  static Future<String?> rememberedBranch(String restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_branchKey(restaurantId))?.trim() ?? '';
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _rememberBranch(String restaurantId, String branchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_branchKey(restaurantId), branchId.trim());
    } catch (_) {}
  }

  /// Registers this center's public evidence key and returns the branch the
  /// server bound it to (null when no registrar is set, e.g. in tests). Throws
  /// when the cloud is unreachable or refuses.
  static Future<String?> _registerEvidenceKey({
    required String restaurantId,
    required Directory directory,
    required String requested,
  }) async {
    final registrar = evidenceKeyRegistrar;
    if (registrar == null) return null;
    final identity = await LanTlsMaterial.evidenceIdentity(directory);
    final fingerprint = await LanTlsMaterial.certificateFingerprint(
      '${directory.path}/server.pem',
    );
    final registered = await registrar(
      restaurantId: restaurantId,
      keyId: identity.id,
      modulusHex: identity.modulusHex,
      serverFingerprint: fingerprint,
      branchId: requested.isNotEmpty ? requested : null,
    );
    final answer = registered?.trim() ?? '';
    if (answer.isEmpty) return null;
    await _rememberBranch(restaurantId, answer);
    return answer;
  }

  /// Registration is a start-up step AND a reconnect step: a center started
  /// (or restarted) while the cloud was away has an unregistered key, and
  /// printed offline orders cannot be accepted until it is registered. Called
  /// by the app lifecycle on every offline-to-online change. Returns true when
  /// the server confirmed the key; the center's branch is filled in then.
  static Future<bool> ensureEvidenceKeyRegistered({
    required String restaurantId,
  }) async {
    final host = RestaurantLanHostRegistry.current;
    final id = restaurantId.trim();
    final directory = host?.certificateDirectory?.trim() ?? '';
    if (host == null || !host.listening || host.restaurantId != id || directory.isEmpty) {
      return false;
    }
    try {
      final branch = await _registerEvidenceKey(
        restaurantId: id,
        directory: Directory(directory),
        requested: host.branchId?.trim() ?? '',
      );
      if (branch == null) return false;
      if ((host.branchId ?? '').trim().isEmpty) host.branchId = branch;
      return true;
    } catch (error) {
      debugPrint('[SellerLanCenter] evidence key registration retry failed: $error');
      return false;
    }
  }

  /// The branch the center runs under. With the cloud reachable the owner's
  /// session registers the evidence key and the server answers with the
  /// branch; offline, or for an account that may not register, the branch
  /// from the last registration is used. The branch only labels evidence;
  /// whether evidence is accepted is decided by the server.
  static Future<String?> _resolveBranch({
    required String restaurantId,
    required Directory directory,
    String? requested,
  }) async {
    final wanted = requested?.trim() ?? '';
    var branch = wanted.isNotEmpty ? wanted : await rememberedBranch(restaurantId);
    try {
      final answer = await _registerEvidenceKey(
        restaurantId: restaurantId,
        directory: directory,
        requested: wanted,
      );
      if (answer != null) branch = answer;
    } catch (error) {
      debugPrint('[SellerLanCenter] evidence key not registered: $error');
    }
    return branch;
  }

  /// Decides whether this account may run a center for the business. Every
  /// start and every reopen asks it. Null only in tests.
  static Future<RestaurantCenterAccess> Function(String restaurantId)?
      accessReader = readRestaurantCenterAccess;

  static Future<RestaurantCenterAccess> checkAccess(String restaurantId) async {
    final reader = accessReader;
    if (reader == null) return RestaurantCenterAccess.granted;
    try {
      return await reader(restaurantId.trim());
    } catch (error) {
      debugPrint('[SellerLanCenter] access check failed: $error');
      return const RestaurantCenterAccess(
        RestaurantCenterDenial.noVerifiedAccount,
      );
    }
  }

  // One start at a time: the app-level launcher and the Garson page can both
  // ask while the first start is still binding the port.
  static Future<SellerLanCenterResult>? _startInFlight;

  static Future<SellerLanCenterResult> start({
    required String restaurantId,
    required LanStaffMembershipReader readMembership,
    String? branchId,
    required bool operatorConfirmed,
    Directory? materialDirectory,
    List<LanInterfaceChoice>? interfaces,
    LanEnrollmentStore? deviceStore,
    int? port,
    String instanceName = 'IBUL Merkez',
  }) {
    final running = _startInFlight;
    if (running != null) return running;
    final future = _startUnguarded(
      restaurantId: restaurantId,
      readMembership: readMembership,
      branchId: branchId,
      operatorConfirmed: operatorConfirmed,
      materialDirectory: materialDirectory,
      interfaces: interfaces,
      deviceStore: deviceStore,
      port: port,
      instanceName: instanceName,
    );
    _startInFlight = future;
    return future.whenComplete(() => _startInFlight = null);
  }

  static Future<SellerLanCenterResult> _startUnguarded({
    required String restaurantId,
    required LanStaffMembershipReader readMembership,
    String? branchId,
    required bool operatorConfirmed,
    Directory? materialDirectory,
    List<LanInterfaceChoice>? interfaces,
    LanEnrollmentStore? deviceStore,
    int? port,
    String instanceName = 'IBUL Merkez',
  }) async {
    final current = RestaurantLanHostRegistry.current;
    if (current != null && current.listening) {
      return SellerLanCenterResult(
        SellerLanCenterState.alreadyRunning,
        message: 'Yerel merkez zaten açık.',
        address: current.boundAddress,
        port: current.port,
      );
    }
    final id = restaurantId.trim();
    if (id.isEmpty) {
      return const SellerLanCenterResult(
        SellerLanCenterState.failed,
        message: 'İşletme kimliği yok. Önce giriş yapın.',
      );
    }
    final access = await checkAccess(id);
    if (!access.allowed) {
      return SellerLanCenterResult(
        SellerLanCenterState.notAllowed,
        message: access.message,
      );
    }
    try {
      final directory = materialDirectory ??
          Directory(
            lanMaterialDirectory(
              operatingSystem: Platform.operatingSystem,
              environment: Platform.environment,
              restaurantId: id,
            ),
          );
      final choices = interfaces ?? await _currentInterfaces();
      final store = LanBindStore(directory);
      final check = checkSavedLanAddress(
        saved: await store.read(),
        current: choices,
      );
      final LanInterfaceChoice? chosen;
      if (check.state == LanSavedAddressState.ready) {
        chosen = check.selection;
      } else {
        chosen = preferredTrustedLanInterface(choices);
      }
      if (chosen == null) {
        return const SellerLanCenterResult(
          SellerLanCenterState.noNetwork,
          message: 'Güvenilir yerel ağ bağlantısı yok. Wi-Fi veya Ethernet\'e bağlanın.',
        );
      }
      final machineId = await lanMachineId(directory);
      final decision = decideAuthorityStart(
        interfaceSelected: true,
        operatorConfirmed: operatorConfirmed,
        localMachineId: machineId,
        restaurantId: id,
      );
      if (!decision.allow) {
        return SellerLanCenterResult(
          SellerLanCenterState.needsConfirmation,
          message: decision.message ?? 'Onay gerekli.',
        );
      }
      if (check.state != LanSavedAddressState.ready) {
        await store.write(
          LanInterfaceSelection(name: chosen.name, address: chosen.address),
        );
      }
      final material = await LanTlsMaterial.open(directory);
      await LanTlsMaterial.ensureServerAddress(directory, chosen.address);
      final opened = await LanTlsMaterial.open(directory);
      final listenPort = port ?? lanOrderPort;
      final centerBranch = await _resolveBranch(
        restaurantId: id,
        directory: opened.directory,
        requested: branchId,
      );
      RestaurantLanHost? hostRef;
      final stationPrinter = deviceMayRunLocalPrintBridge(defaultTargetPlatform)
          ? lanStationPrinterResolver(restaurantId: id)
          : null;
      final host = RestaurantLanHost(
        restaurantId: id,
        branchId: centerBranch,
        machineId: machineId,
        operatorFingerprint: opened.operatorFingerprint,
        certificateDirectory: opened.directory.path,
        // The kitchen ticket is handed to this computer's own print bridge at
        // acceptance, so an order taken with the internet down still prints
        // once, and the result is recorded as a fact (forwarded, failed or
        // uncertain). A phone or tablet never runs a bridge.
        printQueue: deviceMayRunLocalPrintBridge(defaultTargetPlatform)
            ? RestaurantLocalPrintQueueService()
            : null,
        printBridgeUri: deviceMayRunLocalPrintBridge(defaultTargetPlatform)
            ? AppRuntimeConfig.localPrintBridgeUri()
            : null,
        // Each station's ticket goes to the printer saved for that station on
        // this computer, not to whatever the bridge printed to last.
        stationPrinter: stationPrinter,
        staffStillAuthorized: lanStaffProbe(
          readMembership,
          restaurantId: id,
          centerBranchId: () => hostRef?.branchId ?? centerBranch,
        ),
        deviceStore: deviceStore ?? SecureLanEnrollmentStore(SecureLocalStore.instance),
      );
      hostRef = host;
      await host.start(
        securityContext: opened.serverContext,
        address: InternetAddress(chosen.address),
        port: listenPort,
      );
      await advertiser.start(
        instanceName: instanceName,
        port: host.port,
        restaurantId: id,
        machineId: machineId,
        fingerprint: material.serverFingerprint,
      );
      _restart = (choices) => start(
        restaurantId: id,
        readMembership: readMembership,
        branchId: branchId,
        operatorConfirmed: true,
        materialDirectory: materialDirectory,
        interfaces: choices,
        deviceStore: deviceStore,
        port: port,
        instanceName: instanceName,
      );
      _ensureNetworkWatcher();
      // The operator made this computer the center: remember it so the next
      // launch reopens it without another question.
      await markOwned(id, true);
      // Learn each station's saved printer now, while the setup is readable,
      // so the first order after an internet cut is not the first lookup.
      if (stationPrinter != null) {
        unawaited(warmLanStationPrinters(id, stationPrinter));
      }
      return SellerLanCenterResult(
        SellerLanCenterState.running,
        message: 'Yerel merkez açıldı.',
        address: chosen.address,
        port: host.port,
      );
    } catch (error) {
      debugPrint('[SellerLanCenter] start failed: $error');
      return SellerLanCenterResult(
        SellerLanCenterState.failed,
        message: 'Yerel merkez açılamadı: $error',
      );
    }
  }

  /// [byOperator] is false when the app only shuts down; the center is then
  /// reopened on the next launch. An operator stop forgets the ownership.
  static Future<void> stop({bool byOperator = true}) async {
    _restart = null;
    _networkTimer?.cancel();
    _networkTimer = null;
    _staleStrikes = 0;
    await advertiser.stop();
    final host = RestaurantLanHostRegistry.current;
    if (host != null) {
      if (byOperator) await markOwned(host.restaurantId, false);
      await host.stop();
    }
  }

  // The hub follows the machine's network: when the address it listens on is
  // gone (hotspot -> office Wi-Fi) it is reopened on the new one through the
  // normal start path. Keys and enrollments are the same files, so phones
  // find it again by Bonjour without a new pairing.
  static Timer? _networkTimer;
  static Future<SellerLanCenterResult> Function(List<LanInterfaceChoice>)?
      _restart;
  static int _staleStrikes = 0;
  static bool _rebinding = false;
  static Duration networkCheckInterval = const Duration(seconds: 10);
  static Future<List<LanInterfaceChoice>> Function() networkInterfaces =
      _currentInterfaces;

  static void _ensureNetworkWatcher() {
    _networkTimer?.cancel();
    _networkTimer = Timer.periodic(
      networkCheckInterval,
      (_) => unawaited(followNetworkOnce()),
    );
  }

  /// One check. Two stale readings in a row are needed (a sleeping or
  /// switching interface may be missing for a moment). Returns true when the
  /// hub was reopened on a new address.
  @visibleForTesting
  static Future<bool> followNetworkOnce() async {
    final restart = _restart;
    if (restart == null || _rebinding || _startInFlight != null) return false;
    final host = RestaurantLanHostRegistry.current;
    final List<LanInterfaceChoice> choices;
    try {
      choices = await networkInterfaces();
    } catch (_) {
      return false;
    }
    final LanInterfaceChoice? target;
    if (host == null || !host.listening) {
      // A rebind that failed halfway: try again on the best address.
      target = preferredTrustedLanInterface(choices);
    } else {
      final decision = decideLanRebind(
        boundAddress: host.boundAddress,
        current: choices,
      );
      target = decision.target;
    }
    if (target == null) {
      _staleStrikes = 0;
      return false;
    }
    if (host != null && host.listening && ++_staleStrikes < 2) return false;
    _rebinding = true;
    try {
      if (host != null) {
        await advertiser.stop();
        await host.stop();
      }
      final result = await restart(<LanInterfaceChoice>[target]);
      if (result.isRunning) _staleStrikes = 0;
      return result.isRunning;
    } catch (error) {
      debugPrint('[SellerLanCenter] rebind failed: $error');
      return false;
    } finally {
      _rebinding = false;
    }
  }

  static String _ownedKey(String restaurantId) =>
      'ibul.lan_center.owned.${restaurantId.trim()}';

  static Future<void> markOwned(String restaurantId, bool owned) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (owned) {
        await prefs.setBool(_ownedKey(restaurantId), true);
      } else {
        await prefs.remove(_ownedKey(restaurantId));
      }
    } catch (_) {
      // Without the mark the center simply stays manual.
    }
  }

  static Future<bool> isOwned(String restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_ownedKey(restaurantId)) == true;
    } catch (_) {
      return false;
    }
  }

  /// Reopens a center this computer already owns, without asking again. It
  /// never makes a computer the center for the first time, and it does not
  /// move the center to a new address: both stay an operator decision.
  /// Returns null when the operator never started a center here (the default)
  /// or stopped it; a business or account that may not run one is refused.
  static Future<SellerLanCenterResult?> resumeOwned({
    required String restaurantId,
    required LanStaffMembershipReader readMembership,
    String? branchId,
    Directory? materialDirectory,
    List<LanInterfaceChoice>? interfaces,
    LanEnrollmentStore? deviceStore,
    int? port,
  }) async {
    final id = restaurantId.trim();
    if (id.isEmpty || !await isOwned(id)) return null;
    final access = await checkAccess(id);
    if (!access.allowed) {
      return SellerLanCenterResult(
        SellerLanCenterState.notAllowed,
        message: access.message,
      );
    }
    final current = RestaurantLanHostRegistry.current;
    final choices = interfaces ?? await _currentInterfaces();
    final directory = materialDirectory ??
        Directory(
          lanMaterialDirectory(
            operatingSystem: Platform.operatingSystem,
            environment: Platform.environment,
            restaurantId: id,
          ),
        );
    final check = checkSavedLanAddress(
      saved: await LanBindStore(directory).read(),
      current: choices,
    );
    final action = sellerLanCenterAction(
      alreadyListening: current != null && current.listening,
      centerEnabled: true,
      savedAddressReady: check.state == LanSavedAddressState.ready,
      otherMachineAnswers: false,
    );
    if (action == SellerLanCenterAction.needsChoice) {
      return const SellerLanCenterResult(
        SellerLanCenterState.needsConfirmation,
        message:
            'Yerel ağ adresi değişti. Yerel merkezi Sistem bölümünden yeniden başlatın.',
      );
    }
    return start(
      restaurantId: id,
      readMembership: readMembership,
      branchId: branchId,
      operatorConfirmed: true,
      materialDirectory: materialDirectory,
      interfaces: interfaces,
      deviceStore: deviceStore,
      port: port,
    );
  }

  static Future<List<LanInterfaceChoice>> _currentInterfaces() async {
    final raw = <LanRawInterfaceAddress>[];
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        raw.add(LanRawInterfaceAddress(name: interface.name, address: address));
      }
    }
    return trustedLanInterfaces(raw);
  }
}
