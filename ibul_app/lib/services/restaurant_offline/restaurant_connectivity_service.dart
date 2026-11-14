import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/runtime_config.dart';

import '../../core/platform_capabilities.dart';
import '../../core/runtime_diagnostic_logger.dart';
import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../desktop_print_orchestrator.dart';
import 'restaurant_offline_models.dart';

/// Stops a dead cloud from stacking multi-second waits on every screen.
///
/// The first timed-out call still uses its own budget. Later calls fail
/// immediately until the backoff elapses, then one attempt is allowed.
class RestaurantCloudGate {
  RestaurantCloudGate._();

  static DateTime? _blockedUntil;
  static int _streak = 0;

  static bool get shouldFailFast {
    final until = _blockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void noteSuccess() {
    _streak = 0;
    _blockedUntil = null;
  }

  static void noteFailure() {
    _streak += 1;
    final shift = (_streak - 1).clamp(0, 3);
    final seconds = (4 * (1 << shift)).clamp(4, 32);
    _blockedUntil = DateTime.now().add(Duration(seconds: seconds));
  }

  @visibleForTesting
  static void resetForTests() {
    _streak = 0;
    _blockedUntil = null;
  }
}

/// Tracks internet, Supabase reachability, and local print bridge status
/// for restaurant-only offline mode.
class RestaurantConnectivityService with ChangeNotifier {
  RestaurantConnectivityService({
    Connectivity? connectivity,
    DesktopPrintOrchestrator? printOrchestrator,
    Future<bool> Function()? bridgeReachabilityProbe,
    Future<bool> Function()? supabaseReachabilityProbe,
    Duration supabaseProbeTimeout = const Duration(seconds: 3),
  }) : _connectivity = connectivity ?? Connectivity(),
       _printOrchestrator = printOrchestrator,
       _bridgeReachabilityProbe = bridgeReachabilityProbe,
       _supabaseReachabilityProbe = supabaseReachabilityProbe,
       _supabaseProbeTimeout = supabaseProbeTimeout {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      unawaited(refresh(networkResults: results));
    });
  }

  static RestaurantConnectivityService? _instance;
  static RestaurantConnectivityService get instance =>
      _instance ??= RestaurantConnectivityService();

  @visibleForTesting
  static void resetInstanceForTests() {
    _instance?.dispose();
    _instance = null;
  }

  final Connectivity _connectivity;
  final DesktopPrintOrchestrator? _printOrchestrator;
  final Future<bool> Function()? _bridgeReachabilityProbe;
  final Future<bool> Function()? _supabaseReachabilityProbe;
  final Duration _supabaseProbeTimeout;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  bool _hasNetwork = true;
  bool _supabaseReachable = true;
  bool _bridgeReachable = false;
  bool _lanHostReachable = false;
  bool _hasConflict = false;
  bool _isSyncing = false;
  DateTime? _lastRefreshAt;
  bool _loggedBridgeSkip = false;
  @visibleForTesting
  bool debugSkipNetworkProbes = false;

  bool get hasNetwork => _hasNetwork;
  bool get supabaseReachable => _supabaseReachable;
  bool get bridgeReachable => _bridgeReachable;
  bool get lanHostReachable => _lanHostReachable;
  bool get hasConflict => _hasConflict;
  bool get isSyncing => _isSyncing;
  DateTime? get lastRefreshAt => _lastRefreshAt;

  RestaurantConnectivityMode get mode {
    if (_isSyncing) return RestaurantConnectivityMode.syncing;
    if (_hasConflict) return RestaurantConnectivityMode.conflict;
    final cloudUp = _hasNetwork && _supabaseReachable;
    if (!cloudUp && _lanHostReachable) {
      return RestaurantConnectivityMode.offlineLocalMode;
    }
    if (!_hasNetwork) return RestaurantConnectivityMode.lanUnavailable;
    if (!_supabaseReachable) {
      return RestaurantConnectivityMode.supabaseUnreachable;
    }
    if (!_bridgeReachable) {
      return RestaurantConnectivityMode.bridgeUnreachable;
    }
    return RestaurantConnectivityMode.online;
  }

  /// The seller machine reports whether its own order host is listening.
  /// A tablet must not treat Wi-Fi alone as that host.
  void noteLanHost(bool reachable) {
    if (_lanHostReachable == reachable) return;
    _lanHostReachable = reachable;
    notifyListeners();
  }

  void noteConflict(bool value) {
    if (_hasConflict == value) return;
    _hasConflict = value;
    notifyListeners();
  }

  bool isOfflineRestaurantCapable({
    required String? storeCategory,
    required bool hasLocalCache,
  }) {
    if (!canUseRestaurantPrinterSystem(storeCategory)) return false;
    if (_hasNetwork && _supabaseReachable) return false;
    return hasLocalCache;
  }

  Future<void> refresh({List<ConnectivityResult>? networkResults}) async {
    if (debugSkipNetworkProbes) {
      _lastRefreshAt = DateTime.now();
      notifyListeners();
      return;
    }
    final results =
        networkResults ?? await _connectivity.checkConnectivity();
    _hasNetwork = results.any((result) => result != ConnectivityResult.none);

    if (!_hasNetwork) {
      _supabaseReachable = false;
    } else {
      final probeOk = await (_supabaseReachabilityProbe ?? _probeSupabase)();
      _supabaseReachable = probeOk;
    }

    // Mobile customer app (iOS/Android phones) has no local print bridge.
    // Probing http://127.0.0.1:3001/health only adds latency + "connection
    // refused" noise, so skip it entirely on unsupported platforms.
    if (PlatformCapabilities.shouldSkipLocalPrintBridge) {
      if (!_loggedBridgeSkip) {
        _loggedBridgeSkip = true;
        RuntimeDiagnosticLogger.localPrint(
          'skipped on mobile customer app (bridge probe disabled)',
        );
      }
      _bridgeReachable = false;
    } else if (_bridgeReachabilityProbe != null) {
      _bridgeReachable = await _bridgeReachabilityProbe();
    } else {
      _bridgeReachable =
          await (_printOrchestrator ?? DesktopPrintOrchestrator())
              .isLocalBridgeReachable(
        useCache: false,
      );
    }
    _lastRefreshAt = DateTime.now();
    notifyListeners();
  }

  void setSyncing(bool value) {
    if (_isSyncing == value) return;
    _isSyncing = value;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetConnectivity({
    bool? hasNetwork,
    bool? supabaseReachable,
    bool? bridgeReachable,
    bool? lanHostReachable,
    bool? conflict,
    bool? syncing,
  }) {
    if (hasNetwork != null) _hasNetwork = hasNetwork;
    if (supabaseReachable != null) _supabaseReachable = supabaseReachable;
    if (bridgeReachable != null) _bridgeReachable = bridgeReachable;
    if (lanHostReachable != null) _lanHostReachable = lanHostReachable;
    if (conflict != null) _hasConflict = conflict;
    if (syncing != null) _isSyncing = syncing;
    notifyListeners();
  }

  /// GoTrue health is a real internet check. A cached session or a Wi-Fi
  /// association is not treated as Supabase reachability.
  Future<bool> _probeSupabase() async {
    final base = AppRuntimeConfig.rawSupabaseUrl.trim();
    if (base.isEmpty) return false;
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    try {
      final response = await http
          .get(Uri.parse('$root/auth/v1/health'))
          .timeout(_supabaseProbeTimeout);
      final ok = response.statusCode >= 200 && response.statusCode < 500;
      if (ok) {
        RestaurantCloudGate.noteSuccess();
      } else {
        RestaurantCloudGate.noteFailure();
      }
      return ok;
    } catch (_) {
      RestaurantCloudGate.noteFailure();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
