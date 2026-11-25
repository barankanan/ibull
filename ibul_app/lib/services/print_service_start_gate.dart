import 'package:flutter/foundation.dart';

/// Whether this run of the app may start the print service.
///
/// It lives in memory only, so every launch begins closed for a restaurant.
/// It opens when the operator presses "Başlat" in Sistem > Yazıcı Merkezi
/// (after the business and the account were checked) and closes again on
/// "Durdur". The operator's last choice is remembered on this computer by
/// `RestaurantCenterAutoStart`; a launch after "Başlat" runs that same
/// checked start once, a launch after "Durdur" stays closed.
///
/// Businesses that are known not to be restaurants are not held back; their
/// other printing works as before.
class PrintServiceStartGate {
  PrintServiceStartGate._();

  static const String closedMessage =
      'Yazıcı merkezi kapalı. Sistem > Yazıcı Merkezi bölümünden başlatın.';

  static const String heldJobNote =
      'Yazıcı merkezi kapalıyken bekledi. Yazdırmak için kuyruktan başlatın.';

  static bool _enforced = false;
  static bool _restaurantRules = true;

  /// True between the operator's "Başlat" and "Durdur" in this run.
  static final ValueNotifier<bool> operatorStarted = ValueNotifier<bool>(false);

  /// Called once by the seller desktop app at launch. Until the business is
  /// known, it is treated like a restaurant: closed.
  static void enforce() {
    _enforced = true;
    _restaurantRules = true;
    _startedAt = null;
    operatorStarted.value = false;
  }

  static void noteBusiness({required bool restaurantRules}) {
    _restaurantRules = restaurantRules;
  }

  static bool get restaurantRules => _enforced && _restaurantRules;

  static bool get open => !restaurantRules || operatorStarted.value;

  /// Null when starting is allowed, otherwise the text for the operator.
  static String? refusal() => open ? null : closedMessage;

  static DateTime? _startedAt;

  /// The moment of this session's "Başlat". Print jobs created before it
  /// belong to an earlier session.
  static DateTime? get startedAt => _startedAt;

  static void grant([DateTime? at]) {
    if (!operatorStarted.value || _startedAt == null) {
      _startedAt = (at ?? DateTime.now()).toUtc();
    }
    operatorStarted.value = true;
  }

  static void revoke() {
    _startedAt = null;
    operatorStarted.value = false;
  }

  /// True for a print job that waited from before this session's "Başlat" on
  /// a restaurant computer. Such a job is never printed by itself: with the
  /// cloud away at start it could not be marked as held, and it must not slip
  /// out when the cloud returns. A job whose time cannot be read counts as
  /// old; holding costs one tap, a wrong print cannot be undone.
  static bool jobIsFromBefore(Object? createdAt) {
    if (!restaurantRules) return false;
    final limit = _startedAt;
    if (limit == null) return true;
    final created = DateTime.tryParse(createdAt?.toString() ?? '');
    return created == null || created.toUtc().isBefore(limit);
  }

  @visibleForTesting
  static void resetForTests() {
    _enforced = false;
    _restaurantRules = true;
    _startedAt = null;
    operatorStarted.value = false;
  }
}
