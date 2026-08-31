import 'package:supabase_flutter/supabase_flutter.dart';

class InvestorInquiryService {
  InvestorInquiryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final InvestorInquiryService instance = InvestorInquiryService();

  final SupabaseClient _client;

  Future<void> submit({
    required String fullName,
    String? company,
    required String email,
    String? phone,
    String? investorType,
    String? interestArea,
    String? message,
  }) async {
    try {
      final response = await _client.rpc(
        'submit_investor_inquiry',
        params: {
          'p_full_name': fullName.trim(),
          'p_company': company?.trim(),
          'p_email': email.trim(),
          'p_phone': phone?.trim(),
          'p_investor_type': investorType?.trim(),
          'p_interest_area': interestArea?.trim(),
          'p_message': message?.trim(),
        },
      );
      if (response is Map && response['ok'] == true) return;
      if (response == true) return;
      final error = response is Map ? response['error']?.toString() : null;
      throw _mappedError(error);
    } on PostgrestException catch (error) {
      throw Exception(
        error.message.trim().isEmpty
            ? 'Talebiniz kaydedilemedi. Lütfen tekrar deneyin.'
            : error.message,
      );
    }
  }

  Exception _mappedError(String? error) {
    if (error == 'rate_limited') {
      return Exception('Çok fazla deneme. Lütfen sonra tekrar deneyin.');
    }
    if (error == 'invalid_email') {
      return Exception('Geçerli bir e-posta girin.');
    }
    if (error == 'invalid_name') {
      return Exception('Ad soyad girin.');
    }
    return Exception('Talebiniz kaydedilemedi. Lütfen tekrar deneyin.');
  }
}
