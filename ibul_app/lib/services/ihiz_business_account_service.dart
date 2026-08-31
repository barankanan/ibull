import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/ihiz/delivery/ihiz_business_serial.dart';
import 'auth_service.dart';

class IhizBusinessAccountService {
  IhizBusinessAccountService({SupabaseClient? client})
    : _injectedClient = client;

  static final IhizBusinessAccountService instance =
      IhizBusinessAccountService();

  final SupabaseClient? _injectedClient;

  SupabaseClient get _client =>
      _injectedClient ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> ownedStores() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await _client
          .from('stores')
          .select('seller_id, business_name, city, district, phone')
          .eq('seller_id', uid);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      debugPrint('IHIZ owned stores warn: $error');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> currentAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('ihiz_business_accounts')
          .select()
          .eq('seller_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (error) {
      debugPrint('IHIZ business account warn: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>> apply({
    required String storeId,
    required String businessName,
    required String contactName,
    required String contactPhone,
    required String contactEmail,
    required bool hasOwnCouriers,
    int? courierCount,
    required String deliveryRegion,
    String? notes,
  }) async {
    final response = await _client.rpc(
      'apply_ihiz_business_account',
      params: {
        'p_store_id': storeId,
        'p_business_name': businessName.trim(),
        'p_contact_name': contactName.trim(),
        'p_contact_phone': contactPhone.trim(),
        'p_contact_email': contactEmail.trim(),
        'p_has_own_couriers': hasOwnCouriers,
        'p_courier_count': courierCount,
        'p_delivery_region': deliveryRegion.trim(),
        'p_notes': notes?.trim(),
      },
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('İşletme başvurusu kaydedilemedi.');
  }

  Future<Map<String, dynamic>> activate(String storeId) async {
    final response = await _client.rpc(
      'activate_ihiz_business_account',
      params: {'p_store_id': storeId},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('İşletme hesabı etkinleştirilemedi.');
  }

  Future<List<Map<String, dynamic>>> approvedCouriers() async {
    try {
      final response = await _client.rpc(
        'list_ihiz_approved_couriers_directory',
        params: const <String, dynamic>{},
      );
      if (response is List) {
        return response
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
    } catch (error) {
      debugPrint('IHIZ approved couriers warn: $error');
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> storeCouriers(String storeId) async {
    try {
      final rows = await _client
          .from('ihiz_store_couriers')
          .select('id, store_id, courier_user_id, is_active, is_selected')
          .eq('store_id', storeId);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      debugPrint('IHIZ store couriers warn: $error');
      return const [];
    }
  }

  Future<void> setStoreCourier({
    required String storeId,
    required String courierUserId,
    required bool selected,
    bool active = true,
  }) async {
    if (!selected) {
      await _client
          .from('ihiz_store_couriers')
          .delete()
          .eq('store_id', storeId)
          .eq('courier_user_id', courierUserId);
      return;
    }
    await _client.from('ihiz_store_couriers').upsert({
      'store_id': storeId,
      'courier_user_id': courierUserId,
      'is_selected': true,
      'is_active': active,
    }, onConflict: 'store_id,courier_user_id');
  }

  Future<Map<String, dynamic>> lookupBySerial(String serial) async {
    final code = IhizBusinessSerial.normalize(serial);
    if (!IhizBusinessSerial.isValid(code)) {
      return const {'found': false, 'error': 'not_found'};
    }
    final response = await _client.rpc(
      'lookup_store_by_business_serial',
      params: {'p_serial': code},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return const {'found': false, 'error': 'not_found'};
  }

  Future<Map<String, dynamic>> linkBySerial(String serial) async {
    final code = IhizBusinessSerial.normalize(serial);
    final response = await _client.rpc(
      'link_ihiz_business_by_serial',
      params: {'p_serial': code},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('İşletme bağlanamadı.');
  }

  Future<Map<String, dynamic>> signInAndLink({
    required String serial,
    required String email,
    required String password,
    AuthService? auth,
  }) async {
    await (auth ?? AuthService()).signInWithEmailPassword(
      email,
      password,
      authArea: 'ihiz_business',
    );
    return linkBySerial(serial);
  }

  Future<Map<String, dynamic>> ensureSerial({String? storeId}) async {
    // Always send {} (never a JSON null body). PostgREST treats jsonEncode(null)
    // as a jsonb-argument function and returns PGRST202.
    final response = await _client.rpc(
      'ensure_store_business_serial_no',
      params: <String, dynamic>{
        if (storeId != null && storeId.trim().isNotEmpty)
          'p_store_id': storeId.trim(),
      },
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('İşletme seri numarası alınamadı.');
  }

  Future<Map<String, dynamic>> listOps({String? storeId}) async {
    final response = await _client.rpc(
      'list_ihiz_business_ops',
      params: {
        if (storeId != null && storeId.trim().isNotEmpty)
          'p_store_id': storeId.trim(),
      },
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return const {'ok': false, 'stores': []};
  }

  static String describeError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('store_forbidden')) {
      return 'Bu işletme bu hesaba ait değil.';
    }
    if (raw.contains('auth_required')) {
      return 'Giriş yapmanız gerekiyor.';
    }
    if (raw.contains('rate_limited')) {
      return 'Çok fazla deneme. Lütfen sonra tekrar deneyin.';
    }
    if (raw.contains('not_found')) {
      return 'Bu seri numarasıyla işletme bulunamadı.';
    }
    if (raw.contains('pgrst202') ||
        raw.contains('schema cache') ||
        raw.contains('could not find the function')) {
      return 'İHIZ işletme kaydı henüz hazır değil. Lütfen daha sonra tekrar deneyin.';
    }
    if (raw.contains('invalid login') ||
        raw.contains('invalid_credentials') ||
        (raw.contains('email') && raw.contains('password'))) {
      return 'E-posta veya şifre hatalı.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
