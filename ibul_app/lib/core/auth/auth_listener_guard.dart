import 'package:flutter/foundation.dart';

import 'ibul_auth_context.dart';

/// Prevents re-entrant auth listener loops and duplicate user/context handling.
class AuthListenerGuard {
  bool _isHandling = false;
  String? _lastHandledAuthUserId;
  IbulAuthContext? _lastHandledContext;

  bool get isHandling => _isHandling;

  String? get lastHandledAuthUserId => _lastHandledAuthUserId;

  IbulAuthContext? get lastHandledContext => _lastHandledContext;

  /// Returns false when the event should be ignored.
  bool enter({required String? userId, required IbulAuthContext context}) {
    if (_isHandling) return false;
    if (userId != null &&
        userId == _lastHandledAuthUserId &&
        context == _lastHandledContext) {
      return false;
    }
    _isHandling = true;
    return true;
  }

  void leave({
    required String? userId,
    required IbulAuthContext context,
    required bool stateChanged,
  }) {
    _isHandling = false;
    if (stateChanged) {
      _lastHandledAuthUserId = userId;
      _lastHandledContext = context;
    }
  }

  @visibleForTesting
  void reset() {
    _isHandling = false;
    _lastHandledAuthUserId = null;
    _lastHandledContext = null;
  }
}
