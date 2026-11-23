import 'paired_lan_transport.dart';
import 'restaurant_lan_host.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_offline_models.dart';

class DeviceHeldForwardResult {
  const DeviceHeldForwardResult({
    this.delivered = 0,
    this.conflicts = 0,
    this.stale = 0,
    this.otherStaff = 0,
    this.stoppedBy,
  });

  final int delivered;
  final int conflicts;
  final int stale;
  final int otherStaff;

  /// Why the round ended early (center unreachable, pairing refused), or
  /// null when every waiting order was looked at.
  final String? stoppedBy;
}

/// Hands the orders a phone is holding ("Bu cihazda kayıtlı — mutfağa henüz
/// iletilmedi") to the order center once the center answers again.
///
/// Nothing new is stored: the orders are the rows of the phone's existing
/// local queue that the router marked [RestaurantLocalOrderRecord
/// .heldForCenter]. Each goes out through the same paired transport, under
/// its own send key, so the center answers a repeat with "already saved"
/// and prints nothing twice. One round runs at a time.
///
/// - Only the signed-in staff member's own orders are sent; the center binds
///   the request to the paired device and person.
/// - An order older than [maxAge] is not sent on its own: a ticket for a
///   table that ordered long ago must not appear in the kitchen unasked. It
///   stays visible on the phone and the waiter decides.
/// - A refused pairing or an unreachable center ends the round; nothing is
///   dropped and nothing is marked failed.
/// - "Same key, different content" cannot succeed later: the order is marked
///   as a conflict and left for a person.
class DeviceHeldOrderForwarder {
  static const Duration defaultMaxAge = Duration(minutes: 30);
  static bool _running = false;

  static Future<DeviceHeldForwardResult> forward({
    required String restaurantId,
    required String staffId,
    RestaurantLocalOrderQueueService? queue,
    RestaurantLanOrderTransport? transport,
    DateTime Function()? clock,
    Duration maxAge = defaultMaxAge,
  }) async {
    final rid = restaurantId.trim();
    final sender = transport ?? RestaurantLanPairing.transport;
    if (rid.isEmpty || sender == null || _running) {
      return const DeviceHeldForwardResult();
    }
    _running = true;
    try {
      final orders = queue ?? RestaurantLocalOrderQueueService();
      final now = (clock ?? DateTime.now)();
      final held =
          (await orders.list(rid)).where((o) => o.heldForCenter).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      var delivered = 0, conflicts = 0, stale = 0, otherStaff = 0;
      for (final order in held) {
        if (order.restaurantId.trim() != rid) continue;
        final owner = order.waiterId.trim();
        if (owner.isNotEmpty && owner != staffId.trim()) {
          otherStaff++;
          continue;
        }
        if (now.difference(order.createdAt) > maxAge) {
          stale++;
          continue;
        }
        bool saved;
        try {
          saved = await sender.submit(order);
        } catch (error) {
          return DeviceHeldForwardResult(
            delivered: delivered,
            conflicts: conflicts,
            stale: stale,
            otherStaff: otherStaff,
            stoppedBy: error.toString(),
          );
        }
        if (saved) {
          final printStatus = sender is PairedLanTransport
              ? sender.lastPrintStatus
              : null;
          await orders.update(
            restaurantId: rid,
            order: order.copyWith(
              heldForCenter: false,
              printStatus: printStatus,
              updatedAt: (clock ?? DateTime.now)(),
            ),
          );
          delivered++;
          continue;
        }
        if (sender is PairedLanTransport && sender.lastConflict) {
          await orders.update(
            restaurantId: rid,
            order: order.copyWith(
              heldForCenter: false,
              syncStatus: RestaurantLocalOrderSyncStatus.conflict,
              syncError:
                  'Ana bilgisayarda aynı sipariş kimliği farklı içerikle '
                  'kayıtlı. Otomatik gönderilmedi.',
              updatedAt: (clock ?? DateTime.now)(),
            ),
          );
          conflicts++;
          continue;
        }
        // Not saved for a passing reason (busy, restarting): later round.
        return DeviceHeldForwardResult(
          delivered: delivered,
          conflicts: conflicts,
          stale: stale,
          otherStaff: otherStaff,
          stoppedBy: 'center_not_saved',
        );
      }
      return DeviceHeldForwardResult(
        delivered: delivered,
        conflicts: conflicts,
        stale: stale,
        otherStaff: otherStaff,
      );
    } finally {
      _running = false;
    }
  }
}
