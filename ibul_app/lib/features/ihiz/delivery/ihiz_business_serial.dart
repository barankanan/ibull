import 'ihiz_route_paths.dart';

class IhizBusinessSerial {
  const IhizBusinessSerial._();

  static const prefix = 'ISL-';
  static const alphabet = IhizRoutePaths.trackingAlphabet;
  static final RegExp pattern = RegExp(
    r'^ISL-[A-Z0-9]{6}$',
    caseSensitive: false,
  );

  static String normalize(String? raw) {
    final compact = (raw ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return '';
    if (compact.startsWith(prefix)) return compact;
    if (compact.startsWith('ISL') && compact.length == 9) {
      return '$prefix${compact.substring(3)}';
    }
    if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(compact)) {
      return '$prefix$compact';
    }
    return compact;
  }

  static bool isValid(String? raw) {
    final normalized = normalize(raw);
    if (!pattern.hasMatch(normalized)) return false;
    final body = normalized.substring(prefix.length);
    return body.split('').every(alphabet.contains);
  }

  static bool canLink({
    required String storeSellerId,
    required String authUserId,
  }) {
    final store = storeSellerId.trim();
    final user = authUserId.trim();
    return store.isNotEmpty && store == user;
  }
}
