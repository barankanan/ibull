import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Central gate for location permission and current-position reads.
///
/// Geolocator throws if [Geolocator.requestPermission] is invoked while another
/// request is still in flight. Map tab (IndexedStack) and pushed MapPage routes
/// can start location init at the same time, so permission + position reads are
/// serialized here.
class LocationAccessService {
  LocationAccessService._();

  static final LocationAccessService instance = LocationAccessService._();

  Future<LocationPermission>? _permissionRequestFuture;

  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> ensurePermission({bool requestIfDenied = true}) async {
    var permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.denied || !requestIfDenied) {
      return permission;
    }

    _permissionRequestFuture ??= Geolocator.requestPermission().whenComplete(() {
      _permissionRequestFuture = null;
    });
    return _permissionRequestFuture!;
  }

  Future<Position?> getCurrentPosition({
    LocationSettings? locationSettings,
    bool requestPermissionIfNeeded = true,
  }) async {
    if (!await isLocationServiceEnabled()) {
      return null;
    }

    if (requestPermissionIfNeeded) {
      final permission = await ensurePermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    } else {
      final permission = await checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    final settings = locationSettings ?? _defaultLocationSettings();
    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  LocationSettings _defaultLocationSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 12),
    );
  }
}
