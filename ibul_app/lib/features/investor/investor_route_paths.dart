import 'package:flutter/foundation.dart';

class InvestorRoutePaths {
  const InvestorRoutePaths._();

  static const page = '/yatirimci';

  static bool isLaunchPath() {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    return _matches(uri.path) || _matches(uri.fragment);
  }

  static bool _matches(String raw) {
    final path = raw.split('?').first.trim();
    return path == page || path.endsWith(page);
  }
}
