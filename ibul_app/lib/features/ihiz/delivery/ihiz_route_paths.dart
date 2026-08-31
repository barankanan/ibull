class IhizRoutePaths {
  const IhizRoutePaths._();

  static const landing = '/ihiz';
  static const trackPrefix = '/ihiz/track/';

  static final RegExp trackingCodePattern = RegExp(
    r'^IHZ-[A-Z0-9]{6}$',
    caseSensitive: false,
  );

  static const trackingAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String normalizeTrackingCode(String? raw) {
    final compact = (raw ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return '';
    if (compact.startsWith('IHZ-')) return compact;
    if (compact.startsWith('IHZ') && compact.length == 9) {
      return 'IHZ-${compact.substring(3)}';
    }
    if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(compact)) {
      return 'IHZ-$compact';
    }
    return compact;
  }

  static bool isValidTrackingCode(String? raw) {
    final normalized = normalizeTrackingCode(raw);
    return trackingCodePattern.hasMatch(normalized);
  }

  static String track(String code) {
    final normalized = normalizeTrackingCode(code);
    return '$trackPrefix$normalized';
  }

  static String? trackingCodeFromPath(String? path) {
    final raw = (path ?? '').split('?').first.trim();
    if (!raw.startsWith(trackPrefix)) return null;
    final rest = raw.substring(trackPrefix.length);
    if (rest.isEmpty) return '';
    final code = Uri.decodeComponent(rest.split('/').first);
    return normalizeTrackingCode(code);
  }

  static bool isTrackPath(String? path) {
    final raw = (path ?? '').split('?').first.trim();
    return raw.startsWith(trackPrefix);
  }
}
