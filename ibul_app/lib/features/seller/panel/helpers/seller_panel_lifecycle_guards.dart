import 'dart:async';

/// Whether an async seller-panel callback may still touch [State].
bool canApplySellerPanelAsyncUpdate({
  required bool mounted,
  int? requestId,
  int? activeRequestId,
}) {
  if (!mounted) return false;
  if (requestId == null || activeRequestId == null) return true;
  return requestId == activeRequestId;
}

/// Order ids that should receive the short "new order" highlight.
///
/// The first successful snapshot must not highlight every existing order.
List<String> sellerOrderIdsToHighlight({
  required bool hadPriorSnapshot,
  required Set<String> previousIds,
  required Iterable<String> incomingIds,
}) {
  if (!hadPriorSnapshot) return const <String>[];
  return incomingIds.where((id) => !previousIds.contains(id)).toList();
}

/// Single-timer highlight expiry scheduler (one timer regardless of order count).
class SellerOrderHighlightExpiryScheduler {
  SellerOrderHighlightExpiryScheduler({
    required this.highlightDuration,
    required this.onExpired,
  });

  final Duration highlightDuration;
  final void Function(List<String> expiredOrderIds) onExpired;

  final Map<String, DateTime> _expiryByOrderId = <String, DateTime>{};
  Timer? _cleanupTimer;

  int get scheduledExpiryCount => _expiryByOrderId.length;

  /// Active cleanup timers (0 or 1).
  int get activeTimerCount => _cleanupTimer == null ? 0 : 1;

  void schedule(String orderId) {
    if (orderId.isEmpty) return;
    _expiryByOrderId[orderId] = DateTime.now().add(highlightDuration);
    _rescheduleCleanupTimer();
  }

  void cancelOrder(String orderId) {
    if (_expiryByOrderId.remove(orderId) == null) return;
    if (_expiryByOrderId.isEmpty) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    } else {
      _rescheduleCleanupTimer();
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _expiryByOrderId.clear();
  }

  void _rescheduleCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    if (_expiryByOrderId.isEmpty) return;

    DateTime? nearest;
    for (final expiry in _expiryByOrderId.values) {
      if (nearest == null || expiry.isBefore(nearest)) {
        nearest = expiry;
      }
    }
    if (nearest == null) return;

    var delay = nearest.difference(DateTime.now());
    if (delay.isNegative) {
      delay = Duration.zero;
    }
    _cleanupTimer = Timer(delay, _onCleanupTick);
  }

  void _onCleanupTick() {
    _cleanupTimer = null;
    final now = DateTime.now();
    final expired = <String>[];
    for (final entry in _expiryByOrderId.entries) {
      if (!entry.value.isAfter(now)) {
        expired.add(entry.key);
      }
    }
    for (final id in expired) {
      _expiryByOrderId.remove(id);
    }
    if (expired.isNotEmpty) {
      onExpired(expired);
    }
    if (_expiryByOrderId.isNotEmpty) {
      _rescheduleCleanupTimer();
    }
  }
}
