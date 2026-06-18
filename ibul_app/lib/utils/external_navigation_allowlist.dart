/// Allowlist validation for [ExternalNavigation.openUrl].
bool isAllowedExternalNavigationUrl(String url, {bool allowGeoScheme = false}) {
  final normalized = url.trim();
  if (normalized.isEmpty) return false;

  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;

  final scheme = uri.scheme.toLowerCase();
  const blockedSchemes = <String>{
    'javascript',
    'file',
    'data',
    'ftp',
    'intent',
    'vbscript',
    'jar',
  };
  if (blockedSchemes.contains(scheme)) return false;

  if (scheme == 'geo') {
    if (!allowGeoScheme) return false;
    return _isValidGeoUri(uri);
  }

  if (scheme == 'https') {
    return _isAllowedHttpsMapsUri(uri);
  }

  if (scheme == 'http') {
    return _isAllowedHttpMapsUri(uri);
  }

  return false;
}

bool _isAllowedHttpsMapsUri(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'maps.google.com' || host == 'maps.apple.com') {
    return true;
  }
  if (host == 'www.google.com') {
    return uri.path.startsWith('/maps');
  }
  return false;
}

bool _isAllowedHttpMapsUri(Uri uri) {
  // Apple Maps links from [buildAppleMapsNavigationUrl] use http.
  return uri.host.toLowerCase() == 'maps.apple.com';
}

bool _isValidGeoUri(Uri uri) {
  final payload = uri.path.isNotEmpty
      ? uri.path
      : (uri.hasQuery ? uri.query : uri.toString().replaceFirst('geo:', ''));
  final coordinatePart = payload.split('?').first.trim();
  if (coordinatePart.isEmpty) return false;

  final parts = coordinatePart.split(',');
  if (parts.length < 2) return false;

  final latitude = double.tryParse(parts[0].trim());
  final longitude = double.tryParse(parts[1].trim());
  if (latitude == null || longitude == null) return false;

  return latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
