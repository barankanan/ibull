import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/ihiz/send/ihiz_package_send_validator.dart';

class IhizDeliveryService {
  IhizDeliveryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final IhizDeliveryService instance = IhizDeliveryService();

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> ensureTaskForOrder(String orderId) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;
    try {
      final response = await _client.rpc(
        'ensure_ihiz_delivery_task_for_order',
        params: {'p_order_id': id},
      );
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (error) {
      debugPrint('IHIZ ensure delivery task warn: $error');
    }
    return null;
  }

  Future<Map<String, dynamic>> createPackageDelivery(
    IhizPackageSendInput input,
  ) async {
    final invalid = IhizPackageSendValidator.validate(input);
    if (invalid != null) {
      throw Exception(invalid);
    }
    final response = await _client.rpc(
      'create_ihiz_package_delivery',
      params: {
        'p_pickup_name': input.pickupName.trim(),
        'p_pickup_phone': input.pickupPhone.trim(),
        'p_pickup_address': input.pickupAddress.trim(),
        'p_pickup_city': input.pickupCity.trim(),
        'p_pickup_district': input.pickupDistrict.trim(),
        'p_pickup_lat': input.pickupLat,
        'p_pickup_lng': input.pickupLng,
        'p_dropoff_name': input.dropoffName.trim(),
        'p_dropoff_phone': input.dropoffPhone.trim(),
        'p_dropoff_address': input.dropoffAddress.trim(),
        'p_dropoff_city': input.dropoffCity.trim(),
        'p_dropoff_district': input.dropoffDistrict.trim(),
        'p_dropoff_lat': input.dropoffLat,
        'p_dropoff_lng': input.dropoffLng,
        'p_package_size': input.packageSize,
        'p_package_weight': input.packageWeight,
        'p_notes': input.notes?.trim(),
      },
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Paket gönderimi oluşturulamadı.');
  }

  Future<bool> claimTask(String taskId) async {
    try {
      final response = await _client.rpc(
        'claim_ihiz_delivery_task',
        params: {'p_task_id': taskId},
      );
      if (response is Map) {
        return response['ok'] == true;
      }
    } catch (error) {
      debugPrint('IHIZ claim task warn: $error');
    }
    return false;
  }

  Future<void> advanceTask(String taskId, String nextStatus) async {
    try {
      await _client.rpc(
        'advance_ihiz_delivery_task',
        params: {
          'p_task_id': taskId,
          'p_next_status': nextStatus,
        },
      );
    } catch (error) {
      debugPrint('IHIZ advance task warn: $error');
    }
  }

  Future<void> updateCourierLocation({
    required String taskId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _client.rpc(
        'update_ihiz_courier_location',
        params: {
          'p_task_id': taskId,
          'p_lat': lat,
          'p_lng': lng,
        },
      );
    } catch (error) {
      debugPrint('IHIZ courier location warn: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPoolTasks() async {
    try {
      final rows = await _client
          .from('ihiz_delivery_tasks')
          .select(
            'id, order_id, seller_id, store_id, tracking_code, status, source_type, pickup_name, pickup_phone, pickup_address, pickup_city, pickup_district, pickup_lat, pickup_lng, dropoff_name, dropoff_phone, dropoff_address, dropoff_city, dropoff_district, dropoff_lat, dropoff_lng, assigned_courier_id, created_by_user_id, created_at, package_size',
          )
          .inFilter('status', const [
            'created',
            'preparing',
            'ready_for_pickup',
            'courier_assigned',
            'courier_picked_up',
            'in_transit',
          ])
          .order('created_at');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      debugPrint('IHIZ pool tasks warn: $error');
      return const [];
    }
  }

  Future<String?> findTaskIdForOrder(String orderId) async {
    try {
      final row = await _client
          .from('ihiz_delivery_tasks')
          .select('id')
          .eq('order_id', orderId)
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }
}
