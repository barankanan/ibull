import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/platform_capabilities.dart';
import '../../core/runtime_diagnostic_logger.dart';
import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../desktop_print_orchestrator.dart';
import 'restaurant_offline_models.dart';

/// Tracks internet, Supabase reachability, and local print bridge status
/// for restaurant-only offline mode.
class RestaurantConnectivityService with ChangeNotifier {
  RestaurantConnectivityService({
    Connectivity? connectivity,
    DesktopPrintOrchestrator? printOrchestrator,
    Future<bool> Function()? bridgeReachabilityProbe,
    Duration supabaseProbeTimeout = const Duration(seconds: 3),
  }) : _connectivity = connectivity ?? Connectivity(),
       _printOrchestrator = printOrchestrator,
       _bridgeReachabilityProbe = bridgeReachabilityProbe,
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
  final Duration _supabaseProbeTimeout;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  bool _hasNetwork = true;
  bool _supabaseReachable = true;
  bool _bridgeReachable = false;
  bool _isSyncing = false;
  DateTime? _lastRefreshAt;
  int _supabaseFailureStreak = 0;
  bool _loggedBridgeSkip = false;
  @visibleForTesting
  bool debugSkipNetworkProbes = false;

  bool get hasNetwork => _hasNetwork;
  bool get supabaseReachable => _supabaseReachable;
  bool get bridgeReachable => _bridgeReachable;
  bool get isSyncing => _isSyncing;
  DateTime? get lastRefreshAt => _lastRefreshAt;

  RestaurantConnectivityMode get mode {
    if (_isSyncing) return RestaurantConnectivityMode.syncing;
    if (!_hasNetwork) {
      return _bridgeReachable
          ? RestaurantConnectivityMode.offlineLocalMode
          : RestaurantConnectivityMode.offlineLocalMode;
    }
    if (!_supabaseReachable) {
      return RestaurantConnectivityMode.supabaseUnreachable;
    }
    if (!_bridgeReachable) {
      return RestaurantConnectivityMode.bridgeUnreachable;
    }
    return RestaurantConnectivityMode.online;
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
      _supabaseFailureStreak = 0;
    } else {
      final probeOk = await _probeSupabase();
      if (probeOk) {
        _supabaseFailureStreak = 0;
        _supabaseReachable = true;
      } else {
        _supabaseFailureStreak++;
        // Avoid flipping to offline/local mode on a single transient timeout.
        _supabaseReachable = _supabaseFailureStreak < 2;
      }
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
    bool? syncing,
  }) {
    if (hasNetwork != null) _hasNetwork = hasNetwork;
    if (supabaseReachable != null) _supabaseReachable = supabaseReachable;
    if (bridgeReachable != null) _bridgeReachable = bridgeReachable;
    if (syncing != null) _isSyncing = syncing;
    notifyListeners();
  }

  Future<bool> _probeSupabase() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) {
        return true;
      }
      final refreshed = await auth.refreshSession().timeout(_supabaseProbeTimeout);
      return refreshed.session != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
