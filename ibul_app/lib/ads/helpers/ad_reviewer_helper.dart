import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin onay akışında UUID kolonlarına geçersiz string gönderilmesini engeller.
class AdReviewerHelper {
  const AdReviewerHelper._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isValidUuid(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    return _uuidPattern.hasMatch(trimmed);
  }

  static String? resolveReviewerId({SupabaseClient? client}) {
    final userId = (client ?? Supabase.instance.client).auth.currentUser?.id;
    return isValidUuid(userId) ? userId : null;
  }

  static Map<String, dynamic> adminSourceMetadata({String source = 'admin-panel'}) {
    return {'admin_source': source};
  }
}
