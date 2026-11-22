import 'dart:async';

import 'package:flutter/foundation.dart';

import '../restaurant_offline/restaurant_connectivity_service.dart';

/// App-level lifecycle for the local order center and the waiting-order sync.
///
/// It starts when a seller session is established, not when the Garson page
/// opens. Rules:
/// * the center is only reopened on a computer the operator already made the
///   center ([resumeOwned] returns null otherwise), so an unauthorised device
///   never becomes a center by itself;
/// * starting twice for the same restaurant does nothing;
/// * waiting orders are sent when the cloud is reachable, once per
///   connectivity change, and never while a previous run is still going.
class RestaurantOfflineLifecycle {
  RestaurantOfflineLifecycle({
    required this.resumeCenter,
    required this.isCenterListening,
    required this.syncPending,
    required this.pendingCount,
    required this.connectivity,
    this.onReconnected,
    this.centerWait = const Duration(seconds: 1),
    this.centerWaitAttempts = 30,
  });

  /// Reopens an owned center; returns false when this computer owns none.
  final Future<bool> Function(String restaurantId) resumeCenter;
  final bool Function(String restaurantId) isCenterListening;
  final Future<int> Function(String restaurantId) syncPending;
  final Future<int> Function(String restaurantId) pendingCount;
  final RestaurantConnectivityService connectivity;

  /// Runs on every offline→online change, before waiting orders are sent: the
  /// center re-checks staff so a membership revoked during the outage closes.
  final Future<void> Function(String restaurantId)? onReconnected;
  final Duration centerWait;
  final int centerWaitAttempts;

  String? _restaurantId;
  bool _syncing = false;
  bool _lastOnline = false;
  bool _stopped = true;
  int starts = 0;

  String? get activeRestaurantId => _restaurantId;

  Future<void> ensureStarted(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    if (!_stopped && _restaurantId == id) return;
    if (!_stopped) _detach();
    _stopped = false;
    _restaurantId = id;
    starts++;
    debugPrint('[OfflineLifecycle] start #$starts restaurant=$id');
    connectivity.addListener(_onConnectivity);
    // A WAN cut raises no network event, so the app itself must keep checking
    // the cloud; it cannot depend on a screen having been opened.
    connectivity.startMonitoring();
    try {
      final resumed = await resumeCenter(id);
      debugPrint('[OfflineLifecycle] center resumed=$resumed');
    } catch (error) {
      debugPrint('[OfflineLifecycle] center resume failed: $error');
    }
    _lastOnline = _online;
    if (_online) unawaited(_reconnected());
  }

  bool get _online => connectivity.hasNetwork && connectivity.supabaseReachable;

  void _onConnectivity() {
    final online = _online;
    final cameBack = online && !_lastOnline;
    _lastOnline = online;
    if (cameBack) unawaited(_reconnected());
  }

  Future<void> _reconnected() async {
    final id = _restaurantId;
    if (id != null && !_stopped) {
      try {
        await onReconnected?.call(id);
      } catch (error) {
        debugPrint('[OfflineLifecycle] reconnect check failed: $error');
      }
    }
    await _syncIfPending();
  }

  /// The center accepted an order from a waiter device. With the cloud
  /// reachable it is sent right away instead of waiting for the next
  /// connectivity change; offline it simply stays in the queue.
  void localOrderAccepted(String restaurantId) {
    if (_stopped || _restaurantId != restaurantId.trim() || !_online) return;
    unawaited(_syncIfPending());
  }

  /// The restaurant this lifecycle is running for, if any.
  String? get restaurantId => _stopped ? null : _restaurantId;

  /// The operator started the center. Waiting orders are sent as soon as it
  /// is listening (the run below waits for that).
  void centerStarted(String restaurantId) => localOrderAccepted(restaurantId);

  bool _syncAgain = false;

  Future<void> _syncIfPending() async {
    final id = _restaurantId;
    if (id == null || _stopped) return;
    if (_syncing) {
      // An order that arrived during a run is picked up by one more run.
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      var waiting = await pendingCount(id);
      if (waiting == 0) return;
      // Syncing before the center is up marked waiting orders as failed.
      for (var i = 0; i < centerWaitAttempts; i++) {
        if (_stopped || _restaurantId != id) return;
        if (isCenterListening(id)) break;
        await Future<void>.delayed(centerWait);
      }
      // One run sends a limited batch. After a busy outage the rest must
      // not wait for the next order or the next reconnect, so runs repeat
      // while they keep reducing what is waiting.
      while (!_stopped && _restaurantId == id && _online) {
        await syncPending(id);
        final left = await pendingCount(id);
        if (left == 0 || left >= waiting) break;
        waiting = left;
      }
    } catch (error) {
      debugPrint('[OfflineLifecycle] sync failed: $error');
    } finally {
      _syncing = false;
    }
    if (_syncAgain) {
      _syncAgain = false;
      if (!_stopped && _online) unawaited(_syncIfPending());
    }
  }

  void _detach() => connectivity.removeListener(_onConnectivity);

  /// Sign-out: stop reacting. An operator-owned center stays marked owned so
  /// the next launch reopens it; the host itself is stopped by its owner.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _detach();
    _restaurantId = null;
  }
}
