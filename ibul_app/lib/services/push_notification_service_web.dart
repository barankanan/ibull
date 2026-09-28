/// Web stub. The real service pulls Firebase, local notifications, and the
/// timezone database into the initial JS compile. Web already no-ops both
/// entry points (`kIsWeb` early return), so the home chunk must not load them.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  Future<String?> getFcmTokenSafely() async => null;

  Future<void> syncUserInterests({
    required List<String> searchHistory,
    required List<String> favoriteTerms,
    required List<String> cartTerms,
    required List<String> savedListTerms,
  }) async {}
}
