import 'dart:math';

import 'ihiz_delivery_status.dart';
import 'ihiz_route_paths.dart';

/// Pure contracts for IHIZ delivery OS. Mirrors SQL without talking to the DB.
class IhizDeliveryInvariants {
  const IhizDeliveryInvariants._();

  static const trackingAlphabet = IhizRoutePaths.trackingAlphabet;

  static String generateTrackingCode({
    required Set<String> existing,
    Random? random,
  }) {
    final rnd = random ?? Random.secure();
    for (var attempt = 0; attempt < 64; attempt++) {
      final buffer = StringBuffer('IHZ-');
      for (var i = 0; i < 6; i++) {
        buffer.write(trackingAlphabet[rnd.nextInt(trackingAlphabet.length)]);
      }
      final code = buffer.toString();
      if (!existing.contains(code)) return code;
    }
    throw StateError('tracking_code_collision');
  }

  static bool tryCreateTaskForOrder({
    required Map<String, String> tasksByOrderId,
    required String orderId,
    required String taskId,
  }) {
    final id = orderId.trim();
    if (id.isEmpty) return false;
    if (tasksByOrderId.containsKey(id)) return false;
    tasksByOrderId[id] = taskId;
    return true;
  }

  static String? claimTask({
    required Map<String, String?> assignedCourierByTaskId,
    required String taskId,
    required String courierId,
  }) {
    if (!assignedCourierByTaskId.containsKey(taskId)) return 'not_found';
    if (assignedCourierByTaskId[taskId] != null) return 'already_claimed';
    assignedCourierByTaskId[taskId] = courierId;
    return null;
  }

  static bool courierCanSeeTask({
    required String courierId,
    required String? assignedCourierId,
    required bool isApprovedCourier,
    required String status,
    required String? storeId,
    required Set<String> selectedStoreCourierIds,
  }) {
    if (assignedCourierId == courierId) return true;
    if (!isApprovedCourier) return false;
    if (assignedCourierId != null) return false;
    const pool = {
      IhizDeliveryStatus.created,
      IhizDeliveryStatus.preparing,
      IhizDeliveryStatus.readyForPickup,
    };
    if (!pool.contains(status)) return false;
    if ((storeId ?? '').isEmpty) return true;
    if (selectedStoreCourierIds.isEmpty) return true;
    return selectedStoreCourierIds.contains(courierId);
  }

  static bool canCreateFromIbulOrder({
    required bool orderValid,
    required bool ihizDelivery,
    required bool businessActive,
    required bool hasDropoff,
  }) {
    return orderValid && ihizDelivery && businessActive && hasDropoff;
  }

  static List<Map<String, dynamic>> publicTrackingProjection({
    required String trackingCode,
    required String status,
    required List<Map<String, dynamic>> events,
    double? courierLat,
    double? courierLng,
    String? packageMediaUrl,
  }) {
    final live = IhizDeliveryStatus.isLive(status);
    return [
      {
        'found': true,
        'tracking_code': trackingCode,
        'status': status,
        'events': events,
        'package_media_url': packageMediaUrl,
        'live': live
            ? {
                'courier_lat': courierLat,
                'courier_lng': courierLng,
              }
            : null,
      },
    ];
  }
}
