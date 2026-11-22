import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/printer_model.dart';

/// Whether a registered printer answers on the network right now.
///
/// This is deliberately separate from the registration itself: a printer
/// that does not answer stays registered, keeps its station assignments and
/// is used again as soon as it answers. Nothing here ever removes a record.
enum RegisteredPrinterLink {
  /// Not checked yet in this session.
  unknown,

  /// A check is running.
  checking,

  /// The printer's port accepted a connection.
  reachable,

  /// The printer did not answer.
  unreachable,

  /// Not a network printer: reachability is not probed (USB / system queue).
  notProbed,
}

class RegisteredPrinterStatus {
  const RegisteredPrinterStatus({
    required this.link,
    this.lastReachableAt,
    this.checkedAt,
  });

  static const RegisteredPrinterStatus unknown = RegisteredPrinterStatus(
    link: RegisteredPrinterLink.unknown,
  );

  final RegisteredPrinterLink link;

  /// The last moment the printer answered on this computer (kept across
  /// restarts).
  final DateTime? lastReachableAt;
  final DateTime? checkedAt;

  /// The registration line shown next to a saved printer.
  String get label {
    switch (link) {
      case RegisteredPrinterLink.unknown:
        return 'Kayıtlı';
      case RegisteredPrinterLink.checking:
        return 'Kayıtlı · bağlanıyor';
      case RegisteredPrinterLink.reachable:
        return 'Kayıtlı · bağlı';
      case RegisteredPrinterLink.unreachable:
        return 'Kayıtlı fakat ulaşılamıyor';
      case RegisteredPrinterLink.notProbed:
        return 'Kayıtlı';
    }
  }

  /// "Baskıya hazır" needs all three: the print service is open, the printer
  /// is switched on in the settings, and it answers. A reachable port alone
  /// (or a ping) is never called ready.
  bool readyToPrint({required bool serviceOpen, required bool printerActive}) =>
      serviceOpen && printerActive && link == RegisteredPrinterLink.reachable;
}

/// What the operator should do about a registered printer that stopped
/// answering. Never "add the printer again".
const String unreachablePrinterAdvice =
    'Yazıcı kaydı ve alan eşleştirmeleri duruyor; yeniden eklemeniz gerekmez. '
    'Yazıcının açık ve aynı ağda olduğunu kontrol edin. Bağlantı gelince '
    'kendiliğinden kullanılır. Adresi sık değişiyorsa modemde bu yazıcı için '
    'DHCP rezervasyonu (sabit IP) tanımlayın.';

/// The one-glance state of the printer setup for Sistem > Yazıcı Merkezi.
class PrinterCenterSummary {
  const PrinterCenterSummary({
    required this.registered,
    required this.connected,
    required this.unreachableNames,
    required this.uncheckedCount,
    required this.totalStations,
    required this.assignedStations,
    required this.unassignedStationNames,
  });

  final int registered;
  final int connected;
  final List<String> unreachableNames;
  final int uncheckedCount;
  final int totalStations;
  final int assignedStations;
  final List<String> unassignedStationNames;

  String get registeredLabel =>
      registered == 0 ? 'Yazıcı eklenmedi' : '$registered yazıcı';

  String get connectedLabel {
    if (registered == 0) return '—';
    if (uncheckedCount == registered) return 'Kontrol edilmedi';
    return '$connected / $registered bağlı';
  }

  String get unreachableLabel =>
      unreachableNames.isEmpty ? 'Yok' : unreachableNames.join(', ');

  String get stationLabel {
    if (totalStations == 0) return 'Alan tanımlı değil';
    if (unassignedStationNames.isEmpty) {
      return '$assignedStations / $totalStations alan eşleşti';
    }
    return '$assignedStations / $totalStations alan eşleşti · eşleşmeyen: '
        '${unassignedStationNames.join(', ')}';
  }
}

PrinterCenterSummary buildPrinterCenterSummary({
  required List<PrinterModel> printers,
  required Map<String, RegisteredPrinterStatus> statuses,
  required Map<String, String> stationNamesById,
  required Set<String> assignedStationIds,
}) {
  var connected = 0;
  var unchecked = 0;
  final unreachable = <String>[];
  for (final printer in printers) {
    final link = statuses[printer.id]?.link ?? RegisteredPrinterLink.unknown;
    switch (link) {
      case RegisteredPrinterLink.reachable:
        connected++;
      case RegisteredPrinterLink.unreachable:
        unreachable.add(printer.name);
      case RegisteredPrinterLink.unknown:
      case RegisteredPrinterLink.checking:
      case RegisteredPrinterLink.notProbed:
        unchecked++;
    }
  }
  final unassigned = <String>[
    for (final entry in stationNamesById.entries)
      if (!assignedStationIds.contains(entry.key)) entry.value,
  ];
  return PrinterCenterSummary(
    registered: printers.length,
    connected: connected,
    unreachableNames: unreachable,
    uncheckedCount: unchecked,
    totalStations: stationNamesById.length,
    assignedStations: stationNamesById.length - unassigned.length,
    unassignedStationNames: unassigned,
  );
}

/// Answers "does this host:port accept a connection?" (true / false), or null
/// when it could not be asked (the print service is not running).
typedef PrinterPortProbe = Future<bool?> Function(String host, int port);

/// Checks the registered network printers at a controlled pace and remembers
/// when each one last answered.
///
/// It only opens and closes a connection; it never sends print data and
/// never changes a printer record. A printer that comes back is simply seen
/// as reachable again: no scan, no re-adding, no re-assignment.
class PrinterReachabilityMonitor extends ChangeNotifier {
  PrinterReachabilityMonitor({
    required this.restaurantId,
    required PrinterPortProbe probe,
    DateTime Function()? clock,
    this.retryDelay = const Duration(seconds: 2),
  }) : _probe = probe,
       _now = clock ?? DateTime.now;

  final String restaurantId;
  final PrinterPortProbe _probe;
  final DateTime Function() _now;

  /// Between two rounds. Long enough not to compete with real print jobs for
  /// the printer's single connection.
  static const Duration interval = Duration(seconds: 60);

  /// Pause before the second question after a first "no".
  final Duration retryDelay;

  Future<bool?> _ask(String host, int port) async {
    try {
      return await _probe(host, port);
    } catch (_) {
      return null;
    }
  }

  final Map<String, RegisteredPrinterStatus> _statuses =
      <String, RegisteredPrinterStatus>{};
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  bool _restored = false;

  Map<String, RegisteredPrinterStatus> get statuses =>
      Map<String, RegisteredPrinterStatus>.unmodifiable(_statuses);

  RegisteredPrinterStatus statusOf(String printerId) =>
      _statuses[printerId] ?? RegisteredPrinterStatus.unknown;

  static String storageKey(String restaurantId) =>
      'ibul.printer_center.last_reachable.${restaurantId.trim()}';

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(
        prefs.getString(storageKey(restaurantId)) ?? '{}',
      );
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final at = DateTime.tryParse(entry.value?.toString() ?? '');
        if (at == null) continue;
        _statuses.putIfAbsent(
          entry.key.toString(),
          () => RegisteredPrinterStatus(
            link: RegisteredPrinterLink.unknown,
            lastReachableAt: at,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey(restaurantId),
        jsonEncode(<String, String>{
          for (final entry in _statuses.entries)
            if (entry.value.lastReachableAt != null)
              entry.key: entry.value.lastReachableAt!.toUtc().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  /// One round over [printers]. Overlapping calls are dropped.
  Future<void> checkNow(List<PrinterModel> printers) async {
    if (_running || _disposed) return;
    _running = true;
    try {
      await _restore();
      for (final printer in printers) {
        if (_disposed) return;
        final previous = statusOf(printer.id);
        final host = printer.ipAddress?.trim() ?? '';
        if (!printer.isEthernetConnection || host.isEmpty) {
          _statuses[printer.id] = RegisteredPrinterStatus(
            link: RegisteredPrinterLink.notProbed,
            lastReachableAt: previous.lastReachableAt,
          );
          continue;
        }
        if (previous.link == RegisteredPrinterLink.unknown) {
          _statuses[printer.id] = RegisteredPrinterStatus(
            link: RegisteredPrinterLink.checking,
            lastReachableAt: previous.lastReachableAt,
          );
          _notify();
        }
        final port = printer.port ?? PrinterModel.ethernetDefaultPort;
        var answer = await _ask(host, port);
        if (answer == false) {
          // On a quiet network the first connection to a printer that is
          // there can fail (its address is not resolved yet). One "no" is
          // not shown as unreachable; it is asked a second time.
          await Future<void>.delayed(retryDelay);
          if (_disposed) return;
          answer = await _ask(host, port);
        }
        final now = _now();
        _statuses[printer.id] = RegisteredPrinterStatus(
          link: answer == null
              // Could not be asked: say nothing about the printer itself.
              ? RegisteredPrinterLink.unknown
              : (answer
                    ? RegisteredPrinterLink.reachable
                    : RegisteredPrinterLink.unreachable),
          lastReachableAt: answer == true ? now : previous.lastReachableAt,
          checkedAt: answer == null ? previous.checkedAt : now,
        );
        _notify();
      }
      await _persist();
    } finally {
      _running = false;
    }
  }

  /// Checks now and then every [interval] while the screen is open.
  void start(List<PrinterModel> Function() printers) {
    _timer?.cancel();
    unawaited(checkNow(printers()));
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow(printers())));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
