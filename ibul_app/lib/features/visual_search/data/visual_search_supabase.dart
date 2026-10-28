import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class VisualSearchSupabase {
  static SupabaseClient? clientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String? currentUserId() => clientOrNull()?.auth.currentUser?.id;
}

/// Flip to true after `visual-search-analyze` is deployed.
abstract final class VisualSearchConfig {
  static bool useRemoteAnalyzer = false;
}
