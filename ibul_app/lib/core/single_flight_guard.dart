/// Guards against duplicate/overlapping work.
///
/// Combines two concerns used by the home product loader:
///  * an in-flight flag so a second call while one is running is skipped, and
///  * a debounce window so rapid retries (e.g. double-tapping "Tekrar dene")
///    are throttled.
class SingleFlightGuard {
  SingleFlightGuard({this.debounce = const Duration(seconds: 2)});

  final Duration debounce;
  bool _inFlight = false;
  DateTime? _lastStartedAt;

  bool get isInFlight => _inFlight;

  /// Returns true if a new run is allowed right now. When it returns true the
  /// guard is marked in-flight; the caller MUST call [finish] afterwards.
  bool tryBegin({DateTime? now}) {
    if (_inFlight) return false;
    final current = now ?? DateTime.now();
    final last = _lastStartedAt;
    if (last != null && current.difference(last) < debounce) {
      return false;
    }
    _inFlight = true;
    _lastStartedAt = current;
    return true;
  }

  /// Marks the guarded work as complete so a future run may begin.
  void finish() {
    _inFlight = false;
  }

  void reset() {
    _inFlight = false;
    _lastStartedAt = null;
  }
}
