import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/seller/auth/seller_recovery_codes.dart';

class SellerRecoveryService {
  SellerRecoveryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> sendEmailReset(String email) async {
    final target = SellerRecoveryCodes.normalizeIdentifier(email);
    if (!SellerRecoveryCodes.looksLikeEmail(target)) {
      throw Exception('Geçerli bir e-posta girin');
    }
    await _client.auth.resetPasswordForEmail(target);
  }

  Future<void> sendPhoneOtp(String phone) async {
    final digits = SellerRecoveryCodes.normalizePhone(phone);
    if (!SellerRecoveryCodes.looksLikePhone(digits)) {
      throw Exception('Geçerli bir telefon numarası girin');
    }
    await _client.auth.signInWithOtp(
      phone: _toE164(digits),
      shouldCreateUser: false,
    );
  }

  Future<void> verifyPhoneOtpAndSetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 6) {
      throw Exception('Şifre en az 6 karakter olmalıdır');
    }
    final digits = SellerRecoveryCodes.normalizePhone(phone);
    await _client.auth.verifyOTP(
      phone: _toE164(digits),
      token: otp.trim(),
      type: OtpType.sms,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword.trim()));
    await _client.auth.signOut();
  }

  Future<void> resetWithStoreCode({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 6) {
      throw Exception('Şifre en az 6 karakter olmalıdır');
    }
    final normalizedCode = SellerRecoveryCodes.normalizeCode(code);
    if (!SellerRecoveryCodes.looksLikeCode(normalizedCode)) {
      throw Exception('Kod biçimi geçersiz. Örnek: ABCD-EFGH');
    }
    try {
      final raw = await _client.rpc(
        'seller_reset_password_with_recovery_code',
        params: {
          'p_identifier': identifier.trim(),
          'p_code': normalizedCode,
          'p_new_password': newPassword.trim(),
        },
      );
      if (raw is Map && raw['ok'] == false) {
        throw Exception('Kod doğrulanamadı');
      }
    } on PostgrestException catch (error) {
      throw Exception(_mapResetError(error.message));
    }
  }

  Future<List<String>> issueStoreCodes(String storeId) async {
    final raw = await _client.rpc(
      'admin_issue_store_recovery_codes',
      params: {'p_store_id': storeId},
    );
    if (raw is! Map) {
      throw Exception('Kodlar üretilemedi');
    }
    final codes = raw['codes'];
    if (codes is! List) {
      throw Exception('Kodlar üretilemedi');
    }
    return codes.map((item) => item.toString()).toList(growable: false);
  }

  String _toE164(String digits) {
    if (digits.startsWith('90') && digits.length >= 12) {
      return '+$digits';
    }
    if (digits.startsWith('0') && digits.length == 11) {
      return '+90${digits.substring(1)}';
    }
    if (digits.length == 10) {
      return '+90$digits';
    }
    if (digits.startsWith('+')) return digits;
    return '+$digits';
  }

  String _mapResetError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('too many attempts')) {
      return 'Çok fazla deneme. 15 dakika sonra tekrar deneyin.';
    }
    if (lower.contains('password too short')) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    if (lower.contains('auth user missing')) {
      return 'Bu mağazanın Auth hesabı bulunamadı.';
    }
    if (lower.contains('could not find the function') ||
        lower.contains('pgrst202')) {
      return 'Kurtarma RPC henüz veritabanında yok. SUPABASE_FIX_SELLER_STORE_RECOVERY.sql dosyasını çalıştırın.';
    }
    return 'E-posta/telefon veya kod eşleşmedi.';
  }
}
