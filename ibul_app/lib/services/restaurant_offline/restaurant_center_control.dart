import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/runtime_config.dart';
import '../bridge_manager.dart';
import '../print_agent_macos.dart';
import '../print_service_start_gate.dart';
import 'lan_interface.dart';
import 'lan_staff_probe.dart';
import 'restaurant_center_access.dart';
import 'restaurant_lan_host.dart';
import 'seller_lan_center.dart';

class RestaurantCenterStart {
  const RestaurantCenterStart({
    required this.access,
    this.bridgeOk = false,
    this.bridgeMessage = '',
    this.center,
    this.heldOldJobs = 0,
  });

  final RestaurantCenterAccess access;
  final bool bridgeOk;
  final String bridgeMessage;
  final SellerLanCenterResult? center;

  /// Print jobs that were already waiting when the center was started. They
  /// are held for the operator instead of printing by themselves.
  final int heldOldJobs;

  bool get centerRunning => center?.isRunning ?? false;

  /// One line for the operator: the first thing that did not come up.
  String get message {
    if (!access.allowed) return access.message;
    if (!bridgeOk && bridgeMessage.trim().isNotEmpty) return bridgeMessage;
    if (!centerRunning) return center?.message ?? '';
    return 'Yazıcı merkezi başlatıldı.';
  }
}

/// The one place the restaurant printer center is switched on and off on a
/// macOS or Windows computer. The center is two services: the local order
/// center (LAN) and the kitchen print bridge.
///
/// Every launch begins with both off, whatever was chosen in an earlier
/// session. [start] is the operator's "Başlat" in Sistem > Yazıcı Merkezi and
/// is the only thing that opens [PrintServiceStartGate]; every other start
/// path (wizard, quick setup, test dialog, hub) is refused while it is
/// closed. [stop] is "Durdur".
class RestaurantCenterControl {
  RestaurantCenterControl._();

  static const String heldJobNote = PrintServiceStartGate.heldJobNote;

  @visibleForTesting
  static Future<bool> Function() startBridge = _ensureBridge;

  /// Holds print jobs created before [before]; returns how many.
  @visibleForTesting
  static Future<int> Function(String restaurantId, DateTime before)
  holdJobsWaitingSince = _holdWaitingJobsInCloud;

  /// Tells the bridge which jobs are old and warms it up, so the first order
  /// after "Başlat" is not slowed by fonts and renderers loading.
  @visibleForTesting
  static Future<void> Function(DateTime since) prepareBridge = _prepareBridge;

  static Future<void> _prepareBridge(DateTime since) async {
    final base = AppRuntimeConfig.localPrintBridgeUri();
    final client = http.Client();
    try {
      await client
          .post(
            base.replace(path: '/configure/print-station'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'print_jobs_not_before': since.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 3));
      final watch = Stopwatch()..start();
      await client
          .get(base.replace(path: '/warmup'))
          .timeout(const Duration(seconds: 15));
      debugPrint(
        '[RestaurantCenter] bridge warm in ${watch.elapsedMilliseconds}ms',
      );
    } finally {
      client.close();
    }
  }

  /// Closes the print service on this computer without cutting a ticket that
  /// is being printed.
  @visibleForTesting
  static Future<void> Function() closePrintService = _closeLocalPrintService;

  static String _lastBridgeMessage = '';

  static Future<bool> _ensureBridge() async {
    final result = await BridgeManager.ensureReady();
    _lastBridgeMessage = result.message;
    return result.ok;
  }

  static Future<int> _holdWaitingJobsInCloud(
    String restaurantId,
    DateTime before,
  ) async {
    final rows = await Supabase.instance.client
        .from('print_jobs')
        .update(<String, dynamic>{
          'status': 'paused_by_operator',
          'last_error': heldJobNote,
        })
        .eq('restaurant_id', restaurantId)
        .eq('status', 'pending')
        .lt('created_at', before.toUtc().toIso8601String())
        .select('id')
        .timeout(const Duration(seconds: 6));
    return rows.length;
  }

  /// Order matters: printing is switched off first, then the bridge is asked
  /// to leave once the ticket in progress is done, and only then does macOS
  /// take the port back (otherwise a status check would wake it again).
  static Future<void> _closeLocalPrintService() async {
    if (kIsWeb) return;
    // A test build never starts or stops a bridge it does not own.
    if (AppRuntimeConfig.isolatedDesktop ||
        AppRuntimeConfig.printStartDisabled) {
      return;
    }
    final base = AppRuntimeConfig.localPrintBridgeUri();
    final client = http.Client();
    var mayRelease = true;
    try {
      const json = <String, String>{'Content-Type': 'application/json'};
      await client
          .post(
            base.replace(path: '/configure/print-station'),
            headers: json,
            body: '{"print_system_enabled": false}',
          )
          .timeout(const Duration(seconds: 3));
      // The bridge answers only after the ticket in progress is done, then
      // exits by itself. An older bridge has no stop request: it stays up
      // with printing off rather than being killed in the middle of a ticket.
      final answer = await client
          .post(
            base.replace(path: '/shutdown'),
            headers: json,
            body: '{}',
          )
          .timeout(const Duration(seconds: 35));
      mayRelease = answer.statusCode == 200;
    } on TimeoutException {
      mayRelease = false;
    } catch (_) {
      // Nothing answers: the service is not running.
    } finally {
      client.close();
    }
    if (mayRelease && Platform.isMacOS) {
      final plist = await PrintAgentMac.resolvePlist();
      if (plist != null && plist.trim().isNotEmpty) {
        final agent = await PrintAgentMac.status(plist);
        if (agent.isEnabled) await PrintAgentMac.unregister(plist);
      }
    }
  }

  /// True between "Başlat" and "Durdur" in this run of the app.
  static bool get startedThisSession =>
      PrintServiceStartGate.operatorStarted.value;

  /// The operator chose "Başlat". A business or account that may not run a
  /// center gets a refusal and nothing is started.
  static Future<RestaurantCenterStart> start({
    required String restaurantId,
    required LanStaffMembershipReader readMembership,
    @visibleForTesting Directory? materialDirectory,
    @visibleForTesting List<LanInterfaceChoice>? interfaces,
    @visibleForTesting LanEnrollmentStore? deviceStore,
    @visibleForTesting int? port,
  }) async {
    final id = restaurantId.trim();
    final access = await SellerLanCenter.checkAccess(id);
    if (!access.allowed) return RestaurantCenterStart(access: access);
    // Receipts that piled up while the center was off must not pour out of
    // the printer the moment it starts. Without the cloud nothing can be
    // fetched either, so a failed hold is retried when it comes back.
    // The limit is set before anything can print: both the hub and the bridge
    // refuse a job created before it, so an old job cannot slip out even when
    // marking it in the cloud fails or the cloud only returns later.
    var held = 0;
    final firstStart = !startedThisSession;
    PrintServiceStartGate.grant(DateTime.now());
    final since = PrintServiceStartGate.startedAt ?? DateTime.now().toUtc();
    if (firstStart) {
      try {
        held = await holdJobsWaitingSince(id, since);
        _owedHolds.remove(id);
      } catch (error) {
        debugPrint('[RestaurantCenter] old jobs not marked yet: $error');
        _owedHolds[id] = since;
      }
    }
    final bridgeOk = await _bridgeUp();
    if (bridgeOk) {
      try {
        await prepareBridge(since);
      } catch (error) {
        debugPrint('[RestaurantCenter] bridge prepare failed: $error');
      }
    }
    final center = await SellerLanCenter.start(
      restaurantId: id,
      readMembership: readMembership,
      operatorConfirmed: true,
      materialDirectory: materialDirectory,
      interfaces: interfaces,
      deviceStore: deviceStore,
      port: port,
    );
    return RestaurantCenterStart(
      access: access,
      bridgeOk: bridgeOk,
      bridgeMessage: bridgeOk ? '' : _lastBridgeMessage,
      center: center,
      heldOldJobs: held,
    );
  }

  static final Map<String, DateTime> _owedHolds = <String, DateTime>{};

  static final Map<String, Future<void> Function()> _owedCloudSettings =
      <String, Future<void> Function()>{};

  /// "Başlat" or "Durdur" was chosen during an internet cut. The choice is
  /// applied on this computer at once; [write] records it in the cloud when
  /// the internet returns. Only the latest choice is kept.
  static void oweCloudSetting(
    String restaurantId,
    Future<void> Function() write,
  ) {
    _owedCloudSettings[restaurantId.trim()] = write;
  }

  @visibleForTesting
  static bool owesCloudSetting(String restaurantId) =>
      _owedCloudSettings.containsKey(restaurantId.trim());

  /// Internet came back: hold the old jobs a start made offline could not,
  /// and record the on/off choice that could not be written then.
  static Future<void> holdOwedOldJobs(String restaurantId) async {
    final id = restaurantId.trim();
    final since = _owedHolds[id];
    if (since != null) {
      try {
        await holdJobsWaitingSince(id, since);
        _owedHolds.remove(id);
      } catch (error) {
        debugPrint('[RestaurantCenter] old jobs still not held: $error');
      }
    }
    final write = _owedCloudSettings[id];
    if (write != null) {
      try {
        await write();
        if (identical(_owedCloudSettings[id], write)) {
          _owedCloudSettings.remove(id);
        }
      } catch (error) {
        debugPrint('[RestaurantCenter] setting still not in the cloud: $error');
      }
    }
  }

  /// The operator chose "Durdur" (or the app is closing). The order center
  /// refuses new LAN orders with "not saved", lets the order being written
  /// finish, and closes. No other path can start the print service again
  /// until the next "Başlat". Saved orders and waiting print jobs stay.
  static Future<void> stop() async {
    PrintServiceStartGate.revoke();
    await SellerLanCenter.stop();
  }

  /// Closes the print service itself. Called after printing was switched off
  /// on "Durdur", when the app closes, and at launch on a restaurant computer
  /// so that nothing from an earlier session is still running.
  static Future<void> closePrintServiceSafely() async {
    try {
      await closePrintService();
    } catch (error) {
      debugPrint('[RestaurantCenter] print service close failed: $error');
    }
  }

  static Future<bool> _bridgeUp() async {
    try {
      return await startBridge();
    } catch (error) {
      debugPrint('[RestaurantCenter] bridge start failed: $error');
      _lastBridgeMessage = 'Yazıcı servisi başlatılamadı.';
      return false;
    }
  }

  @visibleForTesting
  static void resetForTests() {
    _owedHolds.clear();
    _owedCloudSettings.clear();
    _lastBridgeMessage = '';
    startBridge = _ensureBridge;
    holdJobsWaitingSince = _holdWaitingJobsInCloud;
    closePrintService = _closeLocalPrintService;
    prepareBridge = _prepareBridge;
  }
}
