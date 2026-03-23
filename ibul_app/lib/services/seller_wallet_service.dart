import 'package:supabase_flutter/supabase_flutter.dart';

class SellerWalletService {
  SellerWalletService._();
  static final SellerWalletService instance = SellerWalletService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getWalletBalance({
    required String sellerId,
  }) async {
    final response = await _supabase.rpc(
      'wallet_get_seller_balance',
      params: {'p_seller_id': sellerId},
    );
    return _asMap(response);
  }

  Future<Map<String, dynamic>> topUp({
    required String sellerId,
    required double amount,
    required String idempotencyKey,
    String? note,
  }) async {
    final response = await _supabase.rpc(
      'wallet_topup_seller',
      params: {
        'p_seller_id': sellerId,
        'p_amount': amount,
        'p_idempotency_key': idempotencyKey,
        'p_metadata': {
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        },
      },
    );
    return _asMap(response);
  }

  Future<Map<String, dynamic>> captureHold({
    required String holdId,
    required String idempotencyKey,
    double? amount,
    String? reason,
  }) async {
    final response = await _supabase.rpc(
      'wallet_capture_seller_delivery',
      params: {
        'p_hold_id': holdId,
        'p_amount': amount,
        'p_idempotency_key': idempotencyKey,
        'p_reason': reason,
      },
    );
    return _asMap(response);
  }

  Future<Map<String, dynamic>> releaseHold({
    required String holdId,
    required String idempotencyKey,
    String? reason,
  }) async {
    final response = await _supabase.rpc(
      'wallet_release_seller_delivery',
      params: {
        'p_hold_id': holdId,
        'p_idempotency_key': idempotencyKey,
        'p_reason': reason,
      },
    );
    return _asMap(response);
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map) {
      return response.map((key, value) => MapEntry(key.toString(), value));
    }
    return {'ok': false, 'error': 'invalid_wallet_response'};
  }
}
