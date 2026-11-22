import '../../models/desktop_printer_setup_models.dart';
import '../desktop_print_orchestrator.dart';
import '../restaurant_printer_dispatch_resolver.dart';
import 'restaurant_local_cache_service.dart';

/// What the LAN center stores with a kitchen print job for one station.
///
/// A resolved printer gives the bridge target (host/port or queue). An
/// unresolved station gives `resolution_error`: the job is then recorded as
/// definitely not sent instead of going to a printer nobody chose.
Map<String, dynamic> lanPrinterSnapshotFromResolution(
  RestaurantPrinterDispatchResolution resolution,
) {
  if (resolution.ok && resolution.printerSnapshot.isNotEmpty) {
    return <String, dynamic>{
      ...resolution.printerSnapshot,
      'resolution_source': resolution.resolutionSource,
    };
  }
  final message = resolution.errorMessage?.trim() ?? '';
  return <String, dynamic>{
    'resolution_error': message.isNotEmpty
        ? message
        : RestaurantPrinterDispatchResolution.stationMissingPrinterMessage,
  };
}

/// Resolves the saved printer of a kitchen station on the center computer,
/// with the same rules as the online kitchen path (station mapping, else the
/// kitchen role printer). Printer records come from the last good local copy
/// when the cloud is unreachable.
///
/// A resolved answer is reused for [ttl] so a busy service does not re-read
/// the printer setup for every order. A failure is never cached.
Future<Map<String, dynamic>> Function(String stationId) lanStationPrinterResolver({
  required String restaurantId,
  Future<RestaurantPrinterDispatchResolution> Function(String stationId)?
  resolve,
  Duration ttl = const Duration(seconds: 30),
  Duration lookupTimeout = const Duration(seconds: 3),
  DateTime Function()? clock,
}) {
  final now = clock ?? DateTime.now;
  final cached = <String, (DateTime, Map<String, dynamic>)>{};
  DesktopPrintOrchestrator? orchestrator;
  final lookup =
      resolve ??
      (String stationId) =>
          (orchestrator ??= DesktopPrintOrchestrator()).resolveProductionPrinter(
            restaurantId: restaurantId,
            role: PrinterSetupRole.mutfak,
            stationId: stationId,
            flowName: 'lan_order_station',
            source: 'restaurant_lan_host',
            minimalSnapshot: true,
          );
  return (String stationId) async {
    final station = stationId.trim();
    final hit = cached[station];
    if (hit != null && now().difference(hit.$1) < ttl) {
      return Map<String, dynamic>.from(hit.$2);
    }
    final Map<String, dynamic> snapshot;
    try {
      snapshot = lanPrinterSnapshotFromResolution(
        await lookup(station).timeout(lookupTimeout),
      );
    } catch (_) {
      // The printer setup could not be read in time (typically the cloud is
      // down and the read is still waiting). The printer this station last
      // resolved to is still the saved one; only a definite "no printer"
      // answer below forgets it.
      if (hit != null) return Map<String, dynamic>.from(hit.$2);
      rethrow;
    }
    if (snapshot['resolution_error'] == null) {
      cached[station] = (now(), snapshot);
    } else {
      cached.remove(station);
    }
    return snapshot;
  };
}

/// Resolves every cached station once. Failures are ignored: an order that
/// arrives later resolves its own station again.
Future<void> warmLanStationPrinters(
  String restaurantId,
  Future<Map<String, dynamic>> Function(String stationId) resolve, {
  RestaurantLocalCacheService? cache,
}) async {
  try {
    final snapshot = await (cache ?? RestaurantLocalCacheService()).read(
      restaurantId,
    );
    final stations = <String>{
      for (final row in snapshot?.stations ?? const <Map<String, dynamic>>[])
        if ((row['id']?.toString().trim() ?? '').isNotEmpty)
          row['id'].toString().trim(),
    };
    for (final station in stations) {
      try {
        await resolve(station);
      } catch (_) {}
    }
  } catch (_) {}
}
