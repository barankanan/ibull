import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/runtime_config.dart';
import '../local_print_service.dart';
import '../print_service_start_gate.dart';
import '../print_station_service.dart';
import 'lan_staff_probe.dart';
import 'restaurant_center_access.dart';
import 'restaurant_center_control.dart';
import 'restaurant_connectivity_service.dart';

/// What one complete "Başlat" ended with.
class RestaurantCenterOpen {
  const RestaurantCenterOpen({
    required this.ok,
    this.message = '',
    this.centerNotice,
    this.heldOldJobs = 0,
    this.savedOnThisComputerOnly = false,
  });

  /// The print service is up and printing is switched on.
  final bool ok;

  /// Why it did not open (empty when [ok]).
  final String message;

  /// The print service opened but the local order center did not: its reason.
  final String? centerNotice;

  /// Jobs that waited from before this start; they never print by themselves.
  final int heldOldJobs;

  /// The cloud was away: the choice is applied here and owed to the cloud.
  final bool savedOnThisComputerOnly;
}

/// The complete "Başlat" of the restaurant printer center, and the opt-in
/// that repeats it when İBUL Satıcı opens.
///
/// There is one sequence. The switch in Sistem > Yazıcı Merkezi and the launch
/// both call [open]; nothing else brings the print bridge or the LAN center
/// up. [open] goes through [RestaurantCenterControl.start], so the access
/// check, the "jobs from before this start are held" limit and the
/// single-bridge / single-center guards are the same in both cases.
///
/// The preference is remembered on this computer, per restaurant. It is off
/// until someone who may manage the printer settings switches it on. "Durdur"
/// still closes the center for the rest of the session: the launch start runs
/// at most once per run of the app.
class RestaurantCenterAutoStart {
  RestaurantCenterAutoStart._();

  static const String _prefix = 'ibul.printer_center.auto_start.';

  static String preferenceKey(String restaurantId) =>
      '$_prefix${restaurantId.trim()}';

  static Future<bool> isEnabled(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(preferenceKey(id)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(String restaurantId, bool enabled) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      await prefs.setBool(preferenceKey(id), true);
    } else {
      await prefs.remove(preferenceKey(id));
    }
  }

  /// The operator's own "Başlat" / "Durdur" is the choice for the next
  /// launches: started stays started until the operator stops it, and a
  /// stopped center does not come back by itself. Closing the app, a start
  /// that failed and a print service that died are not operator choices and
  /// never reach this.
  static Future<bool> rememberOperatorChoice(
    String restaurantId, {
    required bool started,
  }) async {
    try {
      await setEnabled(restaurantId, started);
      return true;
    } catch (error) {
      debugPrint('[RestaurantCenter] choice not remembered: $error');
      return false;
    }
  }

  // ---- seams (the real services by default) ----

  @visibleForTesting
  static Future<RestaurantCenterStart> Function(String restaurantId)
  startCenter = _startCenter;

  /// Switches printing on in the bridge and records it in the cloud.
  @visibleForTesting
  static Future<bool> Function(
    String restaurantId,
    bool? previousEnabled,
    PrintStationService? service,
  )
  savePrintSystemOn = _savePrintSystemOn;

  /// Switches printing on in the print service of this computer only.
  @visibleForTesting
  static Future<void> Function() switchOnThisComputer = _switchOnThisComputer;

  @visibleForTesting
  static Future<bool> Function() cloudAnswers = _cloudAnswers;

  /// Records the choice in the cloud later (the internet was away).
  @visibleForTesting
  static void Function(String restaurantId) oweCloudOn = _oweCloudOn;

  @visibleForTesting
  static Future<void> Function() stopCenter = RestaurantCenterControl.stop;

  @visibleForTesting
  static Future<void> Function() closePrintService =
      RestaurantCenterControl.closePrintServiceSafely;

  /// True once nothing answers on the print service port any more.
  @visibleForTesting
  static Future<bool> Function() printServiceGone = _printServiceGone;

  @visibleForTesting
  static bool Function() hostsCenter = restaurantCenterDesktopHost;

  static Future<RestaurantCenterStart> _startCenter(String restaurantId) {
    return RestaurantCenterControl.start(
      restaurantId: restaurantId,
      readMembership: lanStaffAuthorityReader(
        (fn, params) => Supabase.instance.client.rpc(fn, params: params),
        restaurantId,
      ),
    );
  }

  static Future<bool> _savePrintSystemOn(
    String restaurantId,
    bool? previousEnabled,
    PrintStationService? service,
  ) {
    return (service ?? PrintStationService()).setPrintSystemEnabled(
      restaurantId: restaurantId,
      enabled: true,
      previousEnabled: previousEnabled,
    );
  }

  static Future<void> _switchOnThisComputer() async {
    final service = LocalPrintService();
    try {
      final answer = await service.configurePrintStationStrict(
        <String, dynamic>{'print_system_enabled': true},
      );
      if (answer == null || answer['ok'] != true) {
        throw Exception('Yazıcı servisi bu bilgisayarda açılamadı.');
      }
    } finally {
      service.dispose();
    }
  }

  static Future<bool> _cloudAnswers() async {
    final connectivity = RestaurantConnectivityService.instance;
    try {
      await connectivity.refresh(priorCloudFailure: true);
    } catch (_) {}
    return connectivity.hasNetwork && connectivity.supabaseReachable;
  }

  static void _oweCloudOn(String restaurantId) {
    RestaurantCenterControl.oweCloudSetting(restaurantId, () async {
      final patched = await PrintStationService().patchStationConfiguration(
        restaurantId: restaurantId,
        fields: <String, dynamic>{
          'print_system_enabled': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      if (patched == null) throw Exception('not saved');
    });
  }

  static Future<bool> _printServicePortAnswers() async {
    try {
      final uri = AppRuntimeConfig.localPrintBridgeUri();
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        uri.port,
        timeout: const Duration(milliseconds: 600),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _printServiceGone() async {
    for (var i = 0; i < 20; i++) {
      if (!await _printServicePortAnswers()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  // ---- the one start sequence ----

  static Future<RestaurantCenterOpen>? _opening;

  /// The operator's "Başlat", complete: access check, old jobs held, print
  /// bridge, LAN center, printing switched on. A start that does not finish
  /// leaves nothing half open. Concurrent calls share one run, so two bridges
  /// or two centers cannot be started.
  static Future<RestaurantCenterOpen> open({
    required String restaurantId,
    bool? previousEnabled,
    PrintStationService? service,
  }) {
    final running = _opening;
    if (running != null) return running;
    final run = _open(restaurantId.trim(), previousEnabled, service);
    _opening = run;
    return run.whenComplete(() {
      if (identical(_opening, run)) _opening = null;
    });
  }

  static Future<RestaurantCenterOpen> _open(
    String restaurantId,
    bool? previousEnabled,
    PrintStationService? service,
  ) async {
    try {
      final started = await startCenter(restaurantId);
      if (!started.access.allowed) {
        // Nothing was started: a refused start opens no gate.
        return RestaurantCenterOpen(ok: false, message: started.message);
      }
      if (!started.bridgeOk) {
        throw Exception(
          started.message.trim().isEmpty
              ? 'Yazıcı servisi başlatılamadı.'
              : started.message,
        );
      }
      var savedOnThisComputerOnly = false;
      try {
        final saved = await savePrintSystemOn(
          restaurantId,
          previousEnabled,
          service,
        );
        if (!saved) throw Exception('Baskı sistemi güncellenemedi.');
      } catch (_) {
        // During an internet cut the center must still start on this
        // computer; the cloud record follows when the internet returns.
        if (await cloudAnswers()) rethrow;
        await switchOnThisComputer();
        oweCloudOn(restaurantId);
        savedOnThisComputerOnly = true;
      }
      return RestaurantCenterOpen(
        ok: true,
        centerNotice: started.centerRunning ? null : started.message,
        heldOldJobs: started.heldOldJobs,
        savedOnThisComputerOnly: savedOnThisComputerOnly,
      );
    } catch (error) {
      // Orders must not be accepted by a center that cannot print them.
      await stopCenter();
      await closePrintService();
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      return RestaurantCenterOpen(
        ok: false,
        message: text.isEmpty ? 'Yazıcı servisi başlatılamadı.' : text,
      );
    }
  }

  // ---- launch ----

  static Future<RestaurantCenterOpen?>? _launch;

  /// The result of this run's launch start, for the screen to show. Null:
  /// not attempted (preference off, not a center computer, already started).
  static final ValueNotifier<RestaurantCenterOpen?> lastLaunch =
      ValueNotifier<RestaurantCenterOpen?>(null);

  /// Called when İBUL Satıcı has a signed-in restaurant. Runs at most once
  /// per run of the app, whoever calls first (the session start or the
  /// desktop printing bootstrap); later callers get the same answer.
  ///
  /// Returns null when nothing was attempted, so the caller keeps the
  /// behaviour it always had (every launch begins closed).
  static Future<RestaurantCenterOpen?> openAtLaunch(String restaurantId) {
    final running = _launch;
    if (running != null) return running;
    final run = _openAtLaunch(restaurantId.trim());
    _launch = run;
    // "Nothing attempted" is not this run's launch start: the first caller
    // can come before the restaurant is known (another id, a business not
    // resolved yet). It must not use up the one start for the caller that
    // does know. An attempted start, good or bad, stays the answer.
    return run.then((result) {
      if (result == null && identical(_launch, run)) _launch = null;
      return result;
    });
  }

  static Future<RestaurantCenterOpen?> _openAtLaunch(String id) async {
    if (id.isEmpty || !hostsCenter()) return null;
    if (!PrintServiceStartGate.restaurantRules) return null;
    if (RestaurantCenterControl.startedThisSession) return null;
    if (!await isEnabled(id)) return null;
    // A print service left over from an earlier session is closed first (it
    // finishes the ticket it may be printing), and its port must be free
    // before the new one is started: never two services, never a start that
    // is "ready" only because the old one had not exited yet.
    await closePrintService();
    if (!await printServiceGone()) {
      const result = RestaurantCenterOpen(
        ok: false,
        message:
            'Önceki yazıcı servisi kapanmadı. Sistem > Yazıcı Merkezi bölümünden başlatın.',
      );
      lastLaunch.value = result;
      return result;
    }
    // The operator may have pressed "Başlat" while the old service closed.
    if (RestaurantCenterControl.startedThisSession) return null;
    final result = await open(restaurantId: id);
    debugPrint(
      '[RestaurantCenter] launch start ok=${result.ok} '
      'held=${result.heldOldJobs} message=${result.message}',
    );
    lastLaunch.value = result;
    return result;
  }

  // ---- a print service that died ----

  static int _reviveAttempts = 0;
  static DateTime? _lastReviveAt;
  static Future<bool>? _reviving;

  /// How many times in a row the service is brought back before the operator
  /// is left to press "Başlat": a service that keeps dying is not restarted
  /// forever.
  static const int maxReviveAttempts = 5;

  @visibleForTesting
  static Future<bool> Function() reviveBridge =
      RestaurantCenterControl.reviveBridge;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static Duration _reviveWait(int attempts) =>
      Duration(seconds: 30 * (1 << (attempts > 4 ? 4 : attempts)));

  /// The print service answered again; the next failure starts from zero.
  static void notePrintServiceAnswers() {
    _reviveAttempts = 0;
    _lastReviveAt = null;
  }

  /// Called when the print service does not answer. Between "Başlat" and
  /// "Durdur" on the restaurant's center computer that is an unexpected stop
  /// and the service is started again (30 s, 1, 2, 4, 8 minutes apart, then
  /// no more). After "Durdur", or on any other device, nothing is started.
  static Future<bool> printServiceStoppedAnswering() {
    final running = _reviving;
    if (running != null) return running;
    if (!hostsCenter() ||
        !PrintServiceStartGate.restaurantRules ||
        !RestaurantCenterControl.startedThisSession ||
        _opening != null ||
        _reviveAttempts >= maxReviveAttempts) {
      return Future<bool>.value(false);
    }
    final last = _lastReviveAt;
    if (last != null && clock().difference(last) < _reviveWait(_reviveAttempts - 1)) {
      return Future<bool>.value(false);
    }
    _reviveAttempts += 1;
    _lastReviveAt = clock();
    final run = () async {
      try {
        final ok = await reviveBridge();
        debugPrint(
          '[RestaurantCenter] print service revive '
          'attempt=$_reviveAttempts ok=$ok',
        );
        return ok;
      } catch (error) {
        debugPrint('[RestaurantCenter] print service revive failed: $error');
        return false;
      }
    }();
    _reviving = run;
    return run.whenComplete(() {
      if (identical(_reviving, run)) _reviving = null;
    });
  }

  @visibleForTesting
  static void resetForTests() {
    _reviveAttempts = 0;
    _lastReviveAt = null;
    _reviving = null;
    reviveBridge = RestaurantCenterControl.reviveBridge;
    clock = DateTime.now;
    _opening = null;
    _launch = null;
    lastLaunch.value = null;
    startCenter = _startCenter;
    savePrintSystemOn = _savePrintSystemOn;
    switchOnThisComputer = _switchOnThisComputer;
    cloudAnswers = _cloudAnswers;
    oweCloudOn = _oweCloudOn;
    stopCenter = RestaurantCenterControl.stop;
    closePrintService = RestaurantCenterControl.closePrintServiceSafely;
    printServiceGone = _printServiceGone;
    hostsCenter = restaurantCenterDesktopHost;
  }
}
