/// Pure fallback workflow for closing a table's active orders.
///
/// This module is deliberately free of Supabase / Flutter imports so the
/// algorithm can be unit-tested without mocking the DB client.
///
/// The [StoreTableService._closeTableClientSide] method delegates to
/// [runCloseTableFallbackWorkflow], injecting the real Supabase operations
/// as callbacks. Tests inject simple in-memory lambdas instead.
/// Statuses that indicate an order has been fully closed.
/// Must stay in sync with [garsonTerminalOrderStatuses] in
/// garson_active_orders_fetch.dart.
const Set<String> closeTableTerminalStatuses = <String>{
  'closed',
  'paid',
  'cancelled',
  'canceled',
  'completed',
  'complete',
  'archived',
  'payment_completed',
  'completed_payment',
};

bool isTerminalCloseStatus(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  return s.isNotEmpty && closeTableTerminalStatuses.contains(s);
}

/// Result of a single per-order close attempt.
enum PerOrderCloseResult { deleted, markedClosed, failed }

/// Runs the 3-step fallback close workflow for a set of order IDs:
///
///   Step 1 — [bulkDelete]: try to delete all orders at once.
///             On any exception, log and proceed to Step 2.
///
///   Step 2 — [deleteById] / [markClosed]: for each surviving order,
///             try DELETE; if that fails try UPDATE status='closed'.
///             Errors at this level are captured but do not abort the loop.
///
///   Step 3 — [verifyByIds]: fetch current rows for the target IDs.
///             Any row that still has a non-terminal status causes the
///             function to throw so the caller can roll back local state.
///
/// All callbacks are `async` and may throw — the function handles exceptions
/// according to the semantics above.
Future<void> runCloseTableFallbackWorkflow({
  /// Primary-key IDs of the orders to close.
  required List<String> orderIds,

  /// Attempts a bulk DELETE (e.g. DELETE WHERE seller_id = X AND table = Y).
  /// Throw on failure; the exception is caught and logged internally.
  required Future<void> Function() bulkDelete,

  /// Attempts a DELETE for a single order row (DELETE WHERE id = orderId).
  /// Throw on failure; the fallback tries [markClosed] next.
  required Future<void> Function(String orderId) deleteById,

  /// Marks a single order as closed via UPDATE status='closed'.
  /// Throw on failure; the exception is logged but does not abort the loop.
  required Future<void> Function(String orderId) markClosed,

  /// Fetches the current DB state for the given IDs.
  /// Returns the rows that still exist (deleted rows are simply absent).
  /// Each row is a Map<String, dynamic> and must contain a 'status' key.
  required Future<List<Map<String, dynamic>>> Function(List<String> ids)
      verifyByIds,

  /// Optional sink for structured log messages (used in tests to assert
  /// that the right code paths were taken).
  void Function(CloseTableWorkflowEvent event)? onEvent,
}) async {
  if (orderIds.isEmpty) return;

  // ── Step 1: bulk DELETE ──────────────────────────────────────────────────
  bool bulkDeleteOk = false;
  try {
    await bulkDelete();
    bulkDeleteOk = true;
    onEvent?.call(
      CloseTableWorkflowEvent(
        phase: CloseTablePhase.bulkDelete,
        result: CloseTablePhaseResult.success,
      ),
    );
  } catch (err) {
    onEvent?.call(
      CloseTableWorkflowEvent(
        phase: CloseTablePhase.bulkDelete,
        result: CloseTablePhaseResult.failed,
        error: err,
      ),
    );
  }

  // ── Step 2: per-order fallback (only when bulk DELETE failed) ────────────
  if (!bulkDeleteOk) {
    for (final id in orderIds) {
      try {
        await deleteById(id);
        onEvent?.call(
          CloseTableWorkflowEvent(
            phase: CloseTablePhase.perOrderDelete,
            result: CloseTablePhaseResult.success,
            orderId: id,
          ),
        );
      } catch (deleteErr) {
        onEvent?.call(
          CloseTableWorkflowEvent(
            phase: CloseTablePhase.perOrderDelete,
            result: CloseTablePhaseResult.failed,
            orderId: id,
            error: deleteErr,
          ),
        );
        // Fallback: mark as closed via UPDATE
        try {
          await markClosed(id);
          onEvent?.call(
            CloseTableWorkflowEvent(
              phase: CloseTablePhase.perOrderMarkClosed,
              result: CloseTablePhaseResult.success,
              orderId: id,
            ),
          );
        } catch (markErr) {
          onEvent?.call(
            CloseTableWorkflowEvent(
              phase: CloseTablePhase.perOrderMarkClosed,
              result: CloseTablePhaseResult.failed,
              orderId: id,
              error: markErr,
            ),
          );
        }
      }
    }
  }

  // ── Step 3: ID-based verification ────────────────────────────────────────
  final remaining = await verifyByIds(orderIds);
  final stillActive = remaining
      .where((row) => !isTerminalCloseStatus(row['status']?.toString()))
      .toList(growable: false);

  onEvent?.call(
    CloseTableWorkflowEvent(
      phase: CloseTablePhase.verify,
      result: stillActive.isEmpty
          ? CloseTablePhaseResult.success
          : CloseTablePhaseResult.failed,
      remainingActiveCount: stillActive.length,
    ),
  );

  if (stillActive.isNotEmpty) {
    throw CloseTableVerificationException(
      'Masa kapatılamadı: ${stillActive.length} sipariş hâlâ aktif. '
      'Veritabanı silme/güncelleme engellenmiş olabilir.',
      activeCount: stillActive.length,
      activeIds: stillActive
          .map((r) => r['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

// ─── Structured event model ───────────────────────────────────────────────

enum CloseTablePhase {
  bulkDelete,
  perOrderDelete,
  perOrderMarkClosed,
  verify,
}

enum CloseTablePhaseResult { success, failed }

class CloseTableWorkflowEvent {
  const CloseTableWorkflowEvent({
    required this.phase,
    required this.result,
    this.orderId,
    this.error,
    this.remainingActiveCount,
  });

  final CloseTablePhase phase;
  final CloseTablePhaseResult result;
  final String? orderId;
  final Object? error;
  final int? remainingActiveCount;

  bool get isSuccess => result == CloseTablePhaseResult.success;

  @override
  String toString() =>
      'CloseTableWorkflowEvent(phase=$phase, result=$result, '
      'orderId=$orderId, remainingActive=$remainingActiveCount)';
}

class CloseTableVerificationException implements Exception {
  const CloseTableVerificationException(
    this.message, {
    required this.activeCount,
    required this.activeIds,
  });

  final String message;
  final int activeCount;
  final List<String> activeIds;

  @override
  String toString() => 'CloseTableVerificationException: $message '
      '(active=$activeCount ids=$activeIds)';
}
