import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show ChangeNotifier, debugPrint, debugPrintStack;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/desktop_printer_setup_models.dart';
import '../models/printer_model.dart';
import 'bridge_manager.dart';
import 'desktop_print_orchestrator.dart';
import 'kitchen_hub_payload_stamp.dart';
import 'kitchen_print_trace_log.dart';
import 'kitchen_product_mapping_cache_store.dart';
import 'local_print_service.dart';
import 'printer_event_log_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status types
// ─────────────────────────────────────────────────────────────────────────────

/// Current status of the local print bridge (app.py @ 127.0.0.1:3001).
enum BridgeStatus {
  /// durum bilinmiyor — henüz kontrol edilmedi.
  unknown,

  /// kontrol ediliyor.
  checking,

  /// hazır — 127.0.0.1:3001 yanıt veriyor.
  online,

  /// kapalı — servise ulaşılamıyor.
  offline,

  /// hata — beklenmedik yanıt / izin sorunu.
  error;

  bool get isOnline => this == online;
  bool get isOffline => this == offline;
  bool get isChecking => this == checking;
}

/// Realtime listener connection status.
enum ListenerStatus {
  /// Aktif — Supabase kanalı abone.
  active,

  /// Durduruldu — hub durduruldu veya henüz başlamadı.
  stopped,

  /// Hata — kanal bağlantısı koptu.
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// FailedPrintJob
// ─────────────────────────────────────────────────────────────────────────────

/// A failed print job stored locally for user visibility and retry.
class FailedPrintJob {
  const FailedPrintJob({
    required this.jobId,
    required this.description,
    required this.error,
    required this.failedAt,
    this.retryCount = 0,
  });

  final String jobId;
  final String description;
  final String error;
  final DateTime failedAt;
  final int retryCount;

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'description': description,
    'error': error,
    'failedAt': failedAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory FailedPrintJob.fromJson(Map<String, dynamic> json) => FailedPrintJob(
    jobId: json['jobId'] as String? ?? '',
    description: json['description'] as String? ?? '',
    error: json['error'] as String? ?? '',
    failedAt:
        DateTime.tryParse(json['failedAt'] as String? ?? '') ?? DateTime.now(),
    retryCount: json['retryCount'] as int? ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DesktopPrintHub
// ─────────────────────────────────────────────────────────────────────────────

/// Desktop print hub — single service that owns the print pipeline.
///
/// Responsibilities:
///   1. Periodic bridge health check (every 30 s, immediate on [start]).
///   2. Supabase realtime listener for INSERT events on `print_jobs`.
///   3. Atomic job claim (pending → claimed) to avoid duplicate dispatch.
///   4. Dispatch to local bridge via [LocalPrintService].
///   5. Mark jobs completed / failed in the DB.
///   6. Broadcast observable state to UI (status bar + setup screen).
///
/// Lifecycle:
///   ```dart
///   final hub = context.read<DesktopPrintHub>();
///   await hub.start(restaurantId);   // on login
///   await hub.stop();                // on logout
///   ```
class DesktopPrintHub extends ChangeNotifier {
  DesktopPrintHub();

  final DesktopPrintOrchestrator _printOrchestrator =
      DesktopPrintOrchestrator();
  final PrinterEventLogService _eventLogService = PrinterEventLogService();

  // ── Observable state ───────────────────────────────────────────────────────

  BridgeStatus _bridgeStatus = BridgeStatus.unknown;
  BridgeStatus get bridgeStatus => _bridgeStatus;

  ListenerStatus _listenerStatus = ListenerStatus.stopped;
  ListenerStatus get listenerStatus => _listenerStatus;

  /// Backward-compat getter used by status bar.
  bool get listenerActive => _listenerStatus == ListenerStatus.active;

  /// `true` once the LaunchAgent plist existence check has completed.
  bool _launchAgentCheckDone = false;
  bool get launchAgentCheckDone => _launchAgentCheckDone;

  bool _launchAgentInstalled = false;
  bool get launchAgentInstalled => _launchAgentInstalled;

  DateTime? _lastJobTime;
  DateTime? get lastJobTime => _lastJobTime;

  String? _lastJobError;
  String? get lastJobError => _lastJobError;

  String? _lastJobDescription;
  String? get lastJobDescription => _lastJobDescription;

  int _dispatchedCount = 0;
  int get dispatchedCount => _dispatchedCount;

  int _failedCount = 0;
  int get failedCount => _failedCount;

  String? _restaurantId;
  String? get restaurantId => _restaurantId;

  /// `true` when [start] has been called and a restaurant ID is set.
  bool get isRunning => _started && _restaurantId != null;

  final List<FailedPrintJob> _failedJobs = [];
  List<FailedPrintJob> get failedJobs => List.unmodifiable(_failedJobs);

  // ── Internal ───────────────────────────────────────────────────────────────

  /// In-memory dedup set: prevents re-dispatching the same job if the channel
  /// resubscribes and replays an event.
  final Set<String> _dispatchedJobIds = {};

  /// In-memory cache for printer encoding configs (printerId → config map).
  /// Avoids a DB round-trip per job when the same printer is used repeatedly.
  final Map<String, Map<String, dynamic>> _printerConfigCache = {};

  /// Reusable HTTP client for bridge dispatch.  Created once, reused across
  /// all dispatches to avoid per-job connection overhead.
  LocalPrintService? _reusablePrintService;
  Uri? _reusablePrintServiceBaseUri;

  RealtimeChannel? _channel;
  RealtimeChannel? _broadcastChannel;
  Timer? _healthTimer;
  Timer? _pendingSweepTimer;
  Timer? _channelWatchdogTimer;
  bool _started = false;
  bool _recoveringPendingJobs = false;

  /// Guard: if a sweep started but never finished within this window,
  /// auto-reset the flag so the next timer tick can run.
  DateTime? _sweepStartedAt;
  static const Duration _sweepHardTimeout = Duration(seconds: 2);

  /// Track when the last successful sweep completed for diagnostics.
  DateTime? _lastSweepCompletedAt;
  int _sweepRunCount = 0;

  /// Track consecutive channel errors to apply back-off on resubscribe.
  int _channelErrorCount = 0;
  Timer? _resubscribeTimer;
  DateTime? _lastChannelActivityAt;

  static const Duration _healthInterval = Duration(seconds: 30);
  static const Duration _healthTimeout = Duration(milliseconds: 1500);

  /// Aggressive sweep interval: 300ms ensures any missed realtime event is
  /// caught quickly.  Combined with realtime-first + broadcast delivery this
  /// gives a worst-case pickup latency of ~500ms (300ms timer + ~200ms query).
  static const Duration _pendingSweepInterval = Duration(milliseconds: 300);
  static const int _pendingSweepLimit = 50;
  static const int _maxPrintAttempts = 2;

  /// Dispatch HTTP timeout — USB printer write can take 2-5s for large
  /// raster tickets.  A too-short timeout causes a retry cascade: timed-out
  /// requests keep the USB write-lock busy while retries queue behind them,
  /// multiplying total latency instead of reducing it.
  static const Duration _dispatchTimeout = Duration(seconds: 10);
  static const int _maxStoredFailedJobs = 20;
  static const String _kFailedJobsKey = 'ibul_desktop_failed_print_jobs';

  /// Channel watchdog runs every 10s (inside health timer callback and a
  /// dedicated timer) to detect silent channel deaths quickly.
  static const Duration _channelWatchdogInterval = Duration(seconds: 10);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start the hub for [restaurantId].
  ///
  /// No-op if already running for the same ID.
  /// Restarts gracefully if called with a different ID.
  Future<void> start(String restaurantId) async {
    final trimmed = restaurantId.trim();
    if (trimmed.isEmpty) return;
    if (_started && _restaurantId == trimmed) return;
    await stop();
    _restaurantId = trimmed;
    _started = true;
    debugPrint('[PrintHub] start restaurantId=$_restaurantId');
    unawaited(KitchenProductMappingCacheStore.hydrateResolver(trimmed));
    // Restore previously-failed jobs from storage.
    await _loadPersistedState();
    // Kick off background checks (non-blocking).
    _checkLaunchAgentInstalled().ignore();
    _healthTimer = Timer.periodic(_healthInterval, (_) {
      checkBridge();
    });
    // Dedicated channel watchdog at 10s — detects silent channel deaths fast.
    _channelWatchdogTimer = Timer.periodic(
      _channelWatchdogInterval,
      (_) => _ensureChannelAlive(),
    );
    _pendingSweepTimer = Timer.periodic(
      _pendingSweepInterval,
      (_) => _guardedSweep(),
    );
    _subscribeToJobs(_restaurantId!);
    _subscribeToBroadcast(_restaurantId!);
    _recoverPendingJobs(reason: 'startup').ignore();
    _warmBridgeState().ignore();
  }

  /// If the sweep flag has been stuck for too long, force-reset it.
  /// Then run the sweep.
  void _guardedSweep() {
    if (_recoveringPendingJobs && _sweepStartedAt != null) {
      final elapsed = DateTime.now().difference(_sweepStartedAt!);
      if (elapsed > _sweepHardTimeout) {
        debugPrint(
          '[PrintHub] sweep guard: flag stuck for ${elapsed.inSeconds}s, '
          'force-resetting _recoveringPendingJobs',
        );
        _recoveringPendingJobs = false;
        _sweepStartedAt = null;
      }
    }
    // Log heartbeat every ~200 sweeps (~60s at 300ms interval) to confirm
    // the timer is alive without spamming.
    if (_sweepRunCount > 0 && _sweepRunCount % 200 == 0) {
      debugPrint(
        '[PrintHub] sweep heartbeat: sweepCount=$_sweepRunCount '
        'listener=$_listenerStatus '
        'lastSweep=${_lastSweepCompletedAt?.toIso8601String() ?? "never"} '
        'dispatched=$_dispatchedCount failed=$_failedCount',
      );
    }
    _recoverPendingJobs(reason: 'timer').ignore();
  }

  /// Verify that the realtime channel is still alive.  If not, resubscribe.
  void _ensureChannelAlive() {
    if (!_started || _restaurantId == null) return;
    if (_channel == null || _listenerStatus != ListenerStatus.active) {
      debugPrint(
        '[PrintHub] channel watchdog: status=$_listenerStatus — resubscribing',
      );
      _resubscribeChannel();
      return;
    }
    final lastActivity = _lastChannelActivityAt;
    if (lastActivity == null ||
        DateTime.now().difference(lastActivity) >= _channelWatchdogInterval) {
      debugPrint(
        '[PrintHub] channel watchdog: stale '
        'lastActivity=${lastActivity?.toIso8601String() ?? "never"} '
        '— sweeping pending jobs',
      );
      _recoverPendingJobs(reason: 'watchdog').ignore();
    }
  }

  /// Tear down the old channel and create a fresh subscription.
  void _resubscribeChannel() {
    if (!_started || _restaurantId == null) return;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    final oldChannel = _channel;
    _channel = null;
    if (oldChannel != null) {
      Supabase.instance.client.removeChannel(oldChannel).ignore();
    }
    _subscribeToJobs(_restaurantId!);
    // After resubscribe, immediately sweep to catch anything missed.
    _recoverPendingJobs(reason: 'resubscribe').ignore();
  }

  /// Stop the hub.  Call on logout or app disposal.
  Future<void> stop() async {
    _started = false;
    _restaurantId = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    _pendingSweepTimer?.cancel();
    _pendingSweepTimer = null;
    _channelWatchdogTimer?.cancel();
    _channelWatchdogTimer = null;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _recoveringPendingJobs = false;
    _sweepStartedAt = null;
    _channelErrorCount = 0;
    _printerConfigCache.clear();
    _reusablePrintService?.dispose();
    _reusablePrintService = null;
    _reusablePrintServiceBaseUri = null;
    _lastChannelActivityAt = null;
    if (_broadcastChannel != null) {
      try {
        await Supabase.instance.client.removeChannel(_broadcastChannel!);
      } catch (e) {
        debugPrint('[PrintHub] removeBroadcastChannel error: $e');
      }
      _broadcastChannel = null;
    }
    if (_channel != null) {
      try {
        await Supabase.instance.client.removeChannel(_channel!);
      } catch (e) {
        debugPrint('[PrintHub] removeChannel error: $e');
      }
      _channel = null;
    }
    if (_listenerStatus != ListenerStatus.stopped) {
      _listenerStatus = ListenerStatus.stopped;
      notifyListeners();
    }
    debugPrint('[PrintHub] stopped');
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _pendingSweepTimer?.cancel();
    _channelWatchdogTimer?.cancel();
    _resubscribeTimer?.cancel();
    _reusablePrintService?.dispose();
    _reusablePrintService = null;
    _reusablePrintServiceBaseUri = null;
    if (_channel != null) {
      try {
        Supabase.instance.client.removeChannel(_channel!);
      } catch (_) {}
    }
    if (_broadcastChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_broadcastChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  // ── Bridge health ──────────────────────────────────────────────────────────

  /// Manually re-check bridge health.
  Future<void> checkBridge() async {
    _setBridgeStatus(BridgeStatus.checking);
    final svc = LocalPrintService(timeout: _healthTimeout);
    try {
      final status = await svc.checkAvailability(timeout: _healthTimeout);
      _setBridgeStatus(
        status.isAvailable ? BridgeStatus.online : BridgeStatus.offline,
      );
    } on SocketException catch (_) {
      _setBridgeStatus(BridgeStatus.offline);
    } catch (_) {
      // Reachable but unexpected — permissions, config, etc.
      _setBridgeStatus(BridgeStatus.error);
    } finally {
      svc.dispose();
    }
  }

  /// Try to auto-start the local print bridge.
  ///
  /// On macOS: attempts to kickstart the LaunchAgent installed by the setup
  /// guide (`com.ibul.localprint`).  On other platforms: no-op.
  ///
  /// Returns `true` when the bridge is online after the attempt.
  Future<bool> tryStartBridge() async {
    debugPrint('[PrintHub] tryStartBridge');
    _setBridgeStatus(BridgeStatus.checking);
    try {
      await BridgeManager.ensureReady();
    } catch (e) {
      debugPrint('[PrintHub] tryStartBridge error: $e');
    }
    await checkBridge();
    return _bridgeStatus == BridgeStatus.online;
  }

  /// Send a test print to validate the end-to-end path.
  Future<void> testPrint() async {
    if ((_restaurantId ?? '').trim().isNotEmpty) {
      final result = await _printOrchestrator.printTestReceipt(
        restaurantId: _restaurantId!,
        role: PrinterSetupRole.adisyon,
      );
      _setLastJob(
        description: 'Test fişi ${result.printer?.displayName ?? ""}'.trim(),
        error: result.ok ? null : result.message,
      );
      if (!result.ok) {
        throw Exception(result.message);
      }
      return;
    }
    final svc = LocalPrintService();
    try {
      await svc.printTest();
      _setLastJob(description: 'Test fişi gönderildi', error: null);
    } catch (e) {
      _setLastJob(description: 'Test fişi', error: e.toString());
      rethrow;
    } finally {
      svc.dispose();
    }
  }

  // ── LaunchAgent detection ──────────────────────────────────────────────────

  /// Checks whether the com.ibul.localprint LaunchAgent plist is installed.
  /// Sets [launchAgentInstalled] and [launchAgentCheckDone] when complete.
  Future<void> _checkLaunchAgentInstalled() async {
    if (!Platform.isMacOS) {
      _launchAgentCheckDone = true;
      notifyListeners();
      return;
    }
    try {
      final home = Platform.environment['HOME'] ?? '';
      final plist = File(
        '$home/Library/LaunchAgents/com.ibul.localprint.plist',
      );
      _launchAgentInstalled = await plist.exists();
    } catch (e) {
      debugPrint('[PrintHub] checkLaunchAgentInstalled error: $e');
    } finally {
      _launchAgentCheckDone = true;
      notifyListeners();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFailedJobsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map(
              (e) =>
                  FailedPrintJob.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        _failedJobs
          ..clear()
          ..addAll(list);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PrintHub] _loadPersistedState error: $e');
    }
  }

  Future<void> _persistFailedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kFailedJobsKey,
        jsonEncode(_failedJobs.map((j) => j.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[PrintHub] _persistFailedJobs error: $e');
    }
  }

  void _addFailedJob(String jobId, String description, String error) {
    _failedJobs.removeWhere((j) => j.jobId == jobId);
    _failedJobs.insert(
      0,
      FailedPrintJob(
        jobId: jobId,
        description: description,
        error: error,
        failedAt: DateTime.now(),
      ),
    );
    if (_failedJobs.length > _maxStoredFailedJobs) {
      _failedJobs.removeRange(_maxStoredFailedJobs, _failedJobs.length);
    }
    _persistFailedJobs().ignore();
  }

  // ── Retry controls ─────────────────────────────────────────────────────────

  /// Manually retry a failed job by [jobId].
  ///
  /// Resets DB status to `pending`, then re-dispatches through the standard
  /// pipeline.  The job is optimistically removed from [failedJobs]; it will
  /// be re-added if it fails again.
  Future<void> retryJob(String jobId) async {
    debugPrint('[PrintHub] retryJob jobId=$jobId');
    _dispatchedJobIds.remove(jobId);
    try {
      await Supabase.instance.client
          .from('print_jobs')
          .update({'status': 'pending', 'last_error': null})
          .eq('id', jobId)
          .eq('status', 'failed');
    } catch (e) {
      debugPrint('[PrintHub] retryJob reset error: $e');
      return;
    }
    final job = await _fetchJob(jobId);
    if (job == null) return;
    _failedJobs.removeWhere((j) => j.jobId == jobId);
    notifyListeners();
    _persistFailedJobs().ignore();
    _dispatchJobAsync(job);
  }

  /// Clear all locally-stored failed jobs.  Does not affect the DB.
  Future<void> clearFailedJobs() async {
    if (_failedJobs.isEmpty) return;
    _failedJobs.clear();
    notifyListeners();
    await _persistFailedJobs();
  }

  // ── Realtime listener ──────────────────────────────────────────────────────

  void _subscribeToJobs(String restaurantId) {
    // Include a timestamp suffix so re-subscribes always get a fresh channel
    // name — Supabase SDK rejects duplicate channel names.
    final channelName =
        'desktop_print_jobs_${restaurantId}_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[PrintHub] subscribing channel=$channelName');
    final channel = Supabase.instance.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'print_jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) {
            _lastChannelActivityAt = DateTime.now();
            _onJobInserted(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        // Also listen for UPDATE events so jobs reset to 'pending' by a
        // failed direct-dispatch attempt (e.g. garson on a tablet) can be
        // recovered and dispatched here.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'print_jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) {
            _lastChannelActivityAt = DateTime.now();
            final record = Map<String, dynamic>.from(payload.newRecord);
            if (record['status']?.toString() == 'pending') {
              _onJobInserted(record);
            }
          },
        )
        .subscribe((status, [error]) {
          _lastChannelActivityAt = DateTime.now();
          final newStatus = status == RealtimeSubscribeStatus.subscribed
              ? ListenerStatus.active
              : (error != null ? ListenerStatus.error : ListenerStatus.stopped);
          if (_listenerStatus != newStatus) {
            _listenerStatus = newStatus;
            notifyListeners();
          }
          if (error != null) {
            debugPrint('[PrintHub] channel error status=$status error=$error');
            _channelErrorCount++;
            _recoverPendingJobs(reason: 'channel_error').ignore();
            // Schedule automatic resubscribe with exponential back-off
            // (1s, 2s, 4s … capped at 10s).  Aggressive to minimise downtime.
            final delay = Duration(
              seconds: (_channelErrorCount * 1).clamp(1, 10),
            );
            debugPrint(
              '[PrintHub] scheduling resubscribe in ${delay.inSeconds}s '
              '(errorCount=$_channelErrorCount)',
            );
            _resubscribeTimer?.cancel();
            _resubscribeTimer = Timer(delay, _resubscribeChannel);
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            _channelErrorCount = 0;
            _recoverPendingJobs(reason: 'subscribed').ignore();
          }
          debugPrint(
            '[PrintHub] channel status=$status listener=$_listenerStatus',
          );
        });
    _channel = channel;
  }

  /// Subscribe to a Supabase Realtime broadcast channel for instant
  /// mobile → desktop print notifications.
  ///
  /// This is MUCH faster than postgres_changes (which goes through WAL
  /// polling with 1-5s latency).  Broadcast messages go directly through
  /// the Realtime server with < 200ms latency.
  ///
  /// The mobile app sends a broadcast after the RPC creates print_jobs.
  /// This listener immediately fetches and dispatches those jobs.
  /// postgres_changes + sweep remain as reliable fallbacks.
  void _subscribeToBroadcast(String restaurantId) {
    final channelName = 'print_signal:$restaurantId';
    debugPrint('[PrintHub] subscribing broadcast channel=$channelName');
    final channel = Supabase.instance.client
        .channel(channelName)
        .onBroadcast(
          event: 'new_print_jobs',
          callback: (payload) {
            _lastChannelActivityAt = DateTime.now();
            final jobIds = payload['job_ids'];
            if (jobIds is! List || jobIds.isEmpty) return;
            debugPrint(
              '[PrintHub] broadcast received: ${jobIds.length} job(s) '
              'sentAt=${payload['sent_at'] ?? '-'}',
            );
            // Immediately fetch and dispatch the referenced jobs.
            _dispatchBroadcastJobs(
              List<String>.from(jobIds.map((e) => e.toString())),
            ).ignore();
          },
        )
        .subscribe((status, [error]) {
          debugPrint(
            '[PrintHub] broadcast channel status=$status error=$error',
          );
        });
    _broadcastChannel = channel;
  }

  /// Fetch print jobs by ID and dispatch them immediately.
  /// Called from broadcast listener for lowest-latency pickup.
  Future<void> _dispatchBroadcastJobs(List<String> jobIds) async {
    if (!_started || _restaurantId == null) return;
    for (final jobId in jobIds) {
      if (jobId.isEmpty || _dispatchedJobIds.contains(jobId)) continue;
      final job = await _fetchJob(jobId);
      if (job == null) continue;
      final status = job['status']?.toString() ?? '';
      if (status != 'pending' && status != 'claimed') continue;
      _dispatchJobAsync(job);
    }
  }

  void _onJobInserted(Map<String, dynamic> record) {
    final jobId = record['id']?.toString() ?? '';
    final status = record['status']?.toString() ?? '';
    if (jobId.isEmpty || status != 'pending') return;
    if (_dispatchedJobIds.contains(jobId)) {
      debugPrint('[PrintHub] dedup skip jobId=$jobId');
      return;
    }
    final now = DateTime.now();
    final trace = _resolveTraceId(record, fallbackJobId: jobId);
    final printJobCreatedAt = _readStageTimestamp(
      record,
      'print_job_created_at',
    );
    final receiveLagMs = printJobCreatedAt == null
        ? null
        : now.difference(printJobCreatedAt).inMilliseconds;
    debugPrint(
      '[PrintPipeline] trace=$trace stage=hub_job_received '
      'at=${now.toIso8601String()} jobId=$jobId '
      'B=${_formatLatencyMs(receiveLagMs)}',
    );
    _dispatchJobAsync(record);
  }

  // ── Dispatch pipeline ──────────────────────────────────────────────────────

  void _dispatchJobAsync(Map<String, dynamic> jobRecord) {
    // Fire-and-forget; exceptions are caught inside _executeDispatch.
    _executeDispatch(jobRecord).ignore();
  }

  Future<void> _recoverPendingJobs({required String reason}) async {
    final restaurantId = _restaurantId;
    if (!_started || restaurantId == null || restaurantId.isEmpty) return;
    if (_recoveringPendingJobs) {
      // Only log the skip once every few seconds to avoid spam.
      if (reason != 'timer') {
        debugPrint('[PrintHub] sweep skipped (busy) reason=$reason');
      }
      return;
    }
    _recoveringPendingJobs = true;
    _sweepStartedAt = DateTime.now();
    _sweepRunCount++;

    final sweepWatch = Stopwatch()..start();
    try {
      final rows = await Supabase.instance.client
          .from('print_jobs')
          .select(
            'id, restaurant_id, order_id, station_id, printer_id, '
            'job_type, payload, status, order_saved_at, '
            'print_job_created_at, hub_job_received_at, claimed_at, '
            'dispatch_started_at, printer_write_started_at, completed_at',
          )
          .eq('restaurant_id', restaurantId)
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(_pendingSweepLimit);

      final pendingJobs = List<Map<String, dynamic>>.from(
        rows as List,
      ).map((row) => Map<String, dynamic>.from(row)).toList(growable: false);

      if (pendingJobs.isEmpty) {
        _lastSweepCompletedAt = DateTime.now();
        return;
      }

      final lastActivity = _lastChannelActivityAt;
      final channelLooksStale =
          _listenerStatus == ListenerStatus.active &&
          (lastActivity == null ||
              DateTime.now().difference(lastActivity) >=
                  _channelWatchdogInterval);
      if (channelLooksStale && reason == 'watchdog') {
        debugPrint(
          '[PrintHub] watchdog detected stale realtime while '
          'pending jobs exist — resubscribing immediately',
        );
        _resubscribeChannel();
      }

      debugPrint(
        '[PrintHub] pending sweep reason=$reason count=${pendingJobs.length} '
        'queryMs=${sweepWatch.elapsedMilliseconds}',
      );
      debugPrint(
        '[PrintPipeline] stage=recover_pending_started '
        'at=${DateTime.now().toIso8601String()} '
        'reason=$reason count=${pendingJobs.length}',
      );

      for (final job in pendingJobs) {
        final jobId = job['id']?.toString() ?? '';
        if (jobId.isEmpty || _dispatchedJobIds.contains(jobId)) {
          continue;
        }
        _dispatchJobAsync(job);
      }
      _lastSweepCompletedAt = DateTime.now();
    } catch (e) {
      debugPrint(
        '[PrintHub] pending sweep error reason=$reason '
        'sweepMs=${sweepWatch.elapsedMilliseconds} error=$e',
      );
    } finally {
      _recoveringPendingJobs = false;
      _sweepStartedAt = null;
    }
  }

  Future<void> _executeDispatch(Map<String, dynamic> jobRecord) async {
    final dispatchWatch = Stopwatch()..start();
    final jobId = jobRecord['id']?.toString() ?? '';
    if (jobId.isEmpty) return;
    final hubJobReceivedAt = DateTime.now();
    final trace = _resolveTraceId(jobRecord, fallbackJobId: jobId);

    // ── Stage 1: Claim + Enrich in PARALLEL ──────────────────────────────
    // Both operations are independent DB calls.  Running them concurrently
    // saves 200-500ms vs. sequential execution.
    final hasFullPayload = jobRecord['payload'] != null;
    final claimedAt = DateTime.now();

    // Pre-compute payload map for parallel enrich
    final rawPayload = jobRecord['payload'];
    final payloadMap = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : <String, dynamic>{});
    final printerId = jobRecord['printer_id']?.toString();

    Map<String, dynamic>? fullJob;
    Map<String, dynamic> payload;

    if (hasFullPayload) {
      // Fast path: fire-and-forget claim + instant enrich.
      // The claim DB round-trip (200-500ms) no longer blocks dispatch.
      // This is safe because:
      //   - _dispatchedJobIds dedup prevents local re-dispatch
      //   - Only one desktop hub runs per restaurant
      //   - markCompleted at the end will update status regardless
      _dispatchedJobIds.add(jobId);
      _claimJob(
        jobId,
        hubJobReceivedAt: hubJobReceivedAt,
        claimedAt: claimedAt,
      ).ignore();
      payload = await _enrichPayloadWithPrinterConfig(
        payloadMap,
        printerId: printerId,
      );
      fullJob = jobRecord;
    } else {
      // Fallback: claim + fetch in one round-trip (legacy path).
      fullJob = await _claimAndFetchJob(
        jobId,
        hubJobReceivedAt: hubJobReceivedAt,
        claimedAt: claimedAt,
      );
      if (fullJob == null) {
        debugPrint(
          '[PrintHub] claim_failed jobId=$jobId '
          'claimMs=${dispatchWatch.elapsedMilliseconds}',
        );
        return;
      }
      // Enrich after fetch (sequential, can't parallelize here).
      final fetchedPayload = fullJob['payload'];
      payload = await _enrichPayloadWithPrinterConfig(
        fetchedPayload is Map<String, dynamic>
            ? fetchedPayload
            : (fetchedPayload is Map
                  ? Map<String, dynamic>.from(fetchedPayload)
                  : <String, dynamic>{}),
        printerId: fullJob['printer_id']?.toString(),
      );
    }
    _dispatchedJobIds.add(jobId);
    final claimMs = dispatchWatch.elapsedMilliseconds;
    debugPrint(
      '[PrintPipeline] trace=$trace stage=claimed '
      'at=${claimedAt.toIso8601String()} '
      'jobId=$jobId claimMs=$claimMs fastPath=$hasFullPayload',
    );

    // ── Stage 2: Payload already enriched — validate and resolve ─────────
    final enrichMs = dispatchWatch.elapsedMilliseconds;

    final jobRecordForStamp = fullJob ?? jobRecord;
    final isKitchenJob = _restaurantId != null &&
        isHubKitchenPrintJob(payload, jobRecordForStamp);
    if (isKitchenJob && _restaurantId != null) {
      await KitchenProductMappingCacheStore.ensureHydrated(_restaurantId!);
    }
    var kitchenPrintBodies = <Map<String, dynamic>>[payload];
    if (isKitchenJob) {
      kitchenPrintBodies = buildHubKitchenPrintRequests(
        restaurantId: _restaurantId!,
        payload: payload,
        jobStationId: jobRecordForStamp['station_id']?.toString(),
      );
      payload = kitchenPrintBodies.first;
    } else {
      kitchenTraceJsonLog('KitchenPrintPayload', 'HubStampSkipped', <String, Object?>{
        'reason': 'not_kitchen_job',
        'jobType': payload['job_type'] ?? jobRecordForStamp['job_type'] ?? '',
        'itemCount': payload['items'] is List ? (payload['items'] as List).length : 0,
      });
    }

    final tableNo = payload['table_no']?.toString() ?? '-';
    var area =
        payload['station_name']?.toString() ??
        payload['area_name']?.toString() ??
        'Genel';
    final preparedPayload = await _printOrchestrator.prepareQueuedPrintPayload(
      restaurantId: _restaurantId!,
      jobRecord: fullJob ?? jobRecordForStamp,
      payload: payload,
    );
    payload = preparedPayload.payload;
    final resolvedRole = payload['printer_role']?.toString() ?? '-';
    final resolvedPrinterId = preparedPayload.printer?.id ?? '-';
    final resolvedPrinterRecordId =
        preparedPayload.printer?.printerRecordId ??
        payload['printer_record_id']?.toString() ??
        '-';
    final resolvedPrinterQueue =
        preparedPayload.printer?.queueName ??
        payload['printer_queue']?.toString() ??
        '-';
    final resolvedPrinterBackend =
        preparedPayload.printer?.backend.value ??
        payload['printer']?['backend']?.toString() ??
        '-';
    _eventLogService
        .append(
          restaurantId: _restaurantId!,
          event: 'hub_consumed',
          message: 'Hub print job kaydını tüketti.',
          jobId: jobId,
          role: resolvedRole,
          printerId: resolvedPrinterRecordId != '-'
              ? resolvedPrinterRecordId
              : resolvedPrinterId,
          queueName: resolvedPrinterQueue != '-' ? resolvedPrinterQueue : null,
          backend: resolvedPrinterBackend != '-'
              ? resolvedPrinterBackend
              : null,
          details: <String, dynamic>{
            'tableNo': tableNo,
            'area': area,
            'resolutionSource': preparedPayload.resolutionSource,
          },
        )
        .ignore();
    if (resolvedRole == 'adisyon') {
      _eventLogService
          .append(
            restaurantId: _restaurantId!,
            event: 'hub_consumed_adisyon_job',
            message: 'Hub adisyon print job kaydını tüketti.',
            jobId: jobId,
            role: resolvedRole,
            printerId: resolvedPrinterRecordId != '-'
                ? resolvedPrinterRecordId
                : resolvedPrinterId,
            queueName: resolvedPrinterQueue != '-'
                ? resolvedPrinterQueue
                : null,
            backend: resolvedPrinterBackend != '-'
                ? resolvedPrinterBackend
                : null,
            details: <String, dynamic>{
              'tableNo': tableNo,
              'area': area,
              'resolutionSource': preparedPayload.resolutionSource,
            },
          )
          .ignore();
    }
    _eventLogService
        .append(
          restaurantId: _restaurantId!,
          event: 'printer_resolution',
          message: preparedPayload.printer != null
              ? 'Yazici cozumleme tamamlandi.'
              : 'Yazici cozumleme basarisiz oldu.',
          level: preparedPayload.printer != null ? 'info' : 'error',
          jobId: jobId,
          role: resolvedRole,
          printerId: resolvedPrinterRecordId != '-'
              ? resolvedPrinterRecordId
              : resolvedPrinterId,
          queueName: resolvedPrinterQueue != '-' ? resolvedPrinterQueue : null,
          backend: resolvedPrinterBackend != '-'
              ? resolvedPrinterBackend
              : null,
          details: <String, dynamic>{
            'resolutionSource': preparedPayload.resolutionSource,
            'bridgePrinterId': resolvedPrinterId,
            'payloadPrinterId': _readText(payload['printer_id']),
            'payloadPrinterQueue': _readText(payload['printer_queue']),
            'payloadDeviceIdentifier': _readText(
              payload['printer_device_identifier'],
            ),
          },
        )
        .ignore();
    if (preparedPayload.printer == null) {
      final err = 'Printer resolution failed';
      _eventLogService
          .append(
            restaurantId: _restaurantId!,
            event: 'printer_resolution_failed',
            message: err,
            level: 'error',
            jobId: jobId,
            role: resolvedRole,
            printerId: resolvedPrinterRecordId != '-'
                ? resolvedPrinterRecordId
                : resolvedPrinterId,
            queueName: resolvedPrinterQueue != '-'
                ? resolvedPrinterQueue
                : null,
            backend: resolvedPrinterBackend != '-'
                ? resolvedPrinterBackend
                : null,
            details: <String, dynamic>{
              'resolutionSource': preparedPayload.resolutionSource,
              'printerQueue': resolvedPrinterQueue,
            },
          )
          .ignore();
      await _markFailed(jobId, err);
      _failedCount++;
      final resolvedPrinterName =
          payload['printer_name']?.toString() ?? 'Yerel Yazici';
      final description = 'Masa $tableNo - $area - $resolvedPrinterName';
      _setLastJob(description: description, error: err);
      _addFailedJob(jobId, description, err);
      return;
    }
    if (resolvedRole != 'adisyon') {
      _eventLogService
          .append(
            restaurantId: _restaurantId!,
            event:
                preparedPayload.resolutionSource == 'legacy_printer' ||
                    preparedPayload.resolutionSource == 'payload' ||
                    preparedPayload.resolutionSource == 'payload_queue'
                ? 'mapped_area_printer_selected'
                : 'kitchen_role_fallback_selected',
            message:
                preparedPayload.resolutionSource == 'legacy_printer' ||
                    preparedPayload.resolutionSource == 'payload' ||
                    preparedPayload.resolutionSource == 'payload_queue'
                ? 'Alan/istasyon eşleştirmesinden yazıcı seçildi.'
                : 'Alan eşleştirmesi yok, mutfak rol yazıcısına fallback yapıldı.',
            jobId: jobId,
            role: resolvedRole,
            printerId: resolvedPrinterRecordId != '-'
                ? resolvedPrinterRecordId
                : resolvedPrinterId,
            queueName: resolvedPrinterQueue != '-'
                ? resolvedPrinterQueue
                : null,
            backend: resolvedPrinterBackend != '-'
                ? resolvedPrinterBackend
                : null,
            details: <String, dynamic>{
              'resolutionSource': preparedPayload.resolutionSource,
            },
          )
          .ignore();
    }
    final resolvedPrinterName =
        preparedPayload.printer?.displayName ??
        payload['printer_name']?.toString() ??
        'Yerel Yazici';
    final description = 'Masa $tableNo - $area - $resolvedPrinterName';

    if (payload.isEmpty) {
      await _markFailed(jobId, 'Bo\u015f payload');
      _failedCount++;
      _setLastJob(description: description, error: 'Bo\u015f payload');
      _addFailedJob(jobId, description, 'Bo\u015f payload');
      return;
    }

    final baseUri = _resolveBaseUri(payload);
    final route = _resolvePrinterRoute(payload);

    debugPrint(
      '[PrintHub] dispatch jobId=$jobId tableNo=$tableNo area=$area '
      'route=$route baseUri=$baseUri '
      'resolvedPrinter=$resolvedPrinterName '
      'jobType=${payload['job_type'] ?? '-'} '
      'printerRoles=${payload['printer_assigned_roles'] ?? const <String>[]} '
      'encoding=${payload['printer_encoding'] ?? payload['encoding'] ?? '-'} '
      'codePage=${payload['printer_code_page'] ?? payload['code_page'] ?? payload['codepage'] ?? '-'} '
      'claimMs=$claimMs enrichMs=$enrichMs',
    );

    _eventLogService
        .append(
          restaurantId: _restaurantId!,
          event: 'hub_physical_print_attempt',
          message: 'Fiziksel baski denemesi baslatildi.',
          jobId: jobId,
          role: resolvedRole,
          printerId: resolvedPrinterRecordId != '-'
              ? resolvedPrinterRecordId
              : resolvedPrinterId,
          queueName: resolvedPrinterQueue != '-' ? resolvedPrinterQueue : null,
          backend: resolvedPrinterBackend != '-'
              ? resolvedPrinterBackend
              : null,
          details: <String, dynamic>{
            'resolutionSource': preparedPayload.resolutionSource,
            'printer_device_identifier': _readText(
              payload['printer_device_identifier'],
            ),
            'printer_queue': _readText(payload['printer_queue']),
            'printer_name': _readText(payload['printer_name']),
            'route': route,
            'bridgePrinterId': resolvedPrinterId,
          },
        )
        .ignore();
    _eventLogService
        .append(
          restaurantId: _restaurantId!,
          event: 'hub_physical_print_method_called',
          message: 'Hub ortak fiziksel print metodunu çağırıyor.',
          jobId: jobId,
          role: resolvedRole,
          printerId: resolvedPrinterRecordId != '-'
              ? resolvedPrinterRecordId
              : resolvedPrinterId,
          queueName: resolvedPrinterQueue != '-' ? resolvedPrinterQueue : null,
          backend: resolvedPrinterBackend != '-'
              ? resolvedPrinterBackend
              : null,
          details: <String, dynamic>{
            'documentType': payload['document_type']?.toString() ?? '-',
          },
        )
        .ignore();

    // ── Stage 3: HTTP dispatch to bridge (reuse client) ──────────────────
    // Mark printing in background (non-blocking) to avoid an extra DB
    // round-trip on the critical path.
    final dispatchStartedAt = DateTime.now();
    _markPrinting(
      jobId,
      dispatchStartedAt: dispatchStartedAt,
      payload: payload,
    ).ignore();
    debugPrint(
      '[PrintPipeline] trace=$trace stage=dispatch_started '
      'at=${dispatchStartedAt.toIso8601String()} '
      'jobId=$jobId enrichMs=$enrichMs',
    );

    Object? finalError;
    Map<String, dynamic>? bridgeResult;
    try {
      final bodiesToPrint = isKitchenJob && resolvedRole != 'adisyon'
          ? kitchenPrintBodies
          : <Map<String, dynamic>>[payload];

      for (
        var stationIndex = 0;
        stationIndex < bodiesToPrint.length && finalError == null;
        stationIndex++
      ) {
        var printPayload = Map<String, dynamic>.from(bodiesToPrint[stationIndex]);
        _mergeHubPrinterDispatchFields(printPayload, payload);

        if (isKitchenJob && resolvedRole != 'adisyon' && _restaurantId != null) {
          printPayload = stampHubKitchenPrintPayload(
            restaurantId: _restaurantId!,
            payload: printPayload,
            jobStationId: jobRecordForStamp['station_id']?.toString(),
          );
          area =
              printPayload['station_name']?.toString() ??
              printPayload['area_name']?.toString() ??
              area;
          logKitchenFinalBeforeBridge(path: 'hub', payload: printPayload);
          if (stationIndex == 0) {
            logKitchenDispatchPath(
              path: 'hub',
              physicallyDispatched: true,
              reason:
                  'hub_physical_print_attempt jobId=$jobId split=${bodiesToPrint.length}',
              itemCount: printPayload['items'] is List
                  ? (printPayload['items'] as List).length
                  : 0,
              traceId: trace,
            );
          }
        }

        for (var attempt = 1; attempt <= _maxPrintAttempts; attempt++) {
          try {
            final physicalResult = await _printOrchestrator
                .printPhysicalToPrinter(
                  preparedPayload.printer!,
                  PrintPayload.fromQueuedJob(printPayload),
                  restaurantId: _restaurantId!,
                );
            bridgeResult = physicalResult.raw;
            if (!physicalResult.ok) {
              finalError =
                  physicalResult.technicalMessage ?? physicalResult.message;
              throw Exception(physicalResult.message);
            }
            finalError = null;
            break;
          } catch (e) {
            finalError = e;
            debugPrint(
              '[PrintHub] attempt $attempt/$_maxPrintAttempts failed '
              'jobId=$jobId stationIndex=$stationIndex error=$e',
            );
            if (attempt < _maxPrintAttempts) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
          }
        }
      }
      final totalMs = dispatchWatch.elapsedMilliseconds;
      if (finalError == null) {
        // Mark completed in background — don't block the success path.
        final completedAt = DateTime.now();
        final latencySummary = _buildLatencySummary(
          fullJob,
          hubJobReceivedAt: hubJobReceivedAt,
          claimedAt: claimedAt,
          dispatchStartedAt: dispatchStartedAt,
          bridgeResult: bridgeResult,
          completedAt: completedAt,
        );
        _markCompleted(
          jobId,
          completedAt: completedAt,
          bridgeResult: bridgeResult,
          payload: payload,
        ).ignore();
        _eventLogService
            .append(
              restaurantId: _restaurantId!,
              event: 'hub_physical_print_success',
              message: 'Fiziksel baskı başarıyla tamamlandı.',
              jobId: jobId,
              role: resolvedRole,
              printerId: resolvedPrinterRecordId != '-'
                  ? resolvedPrinterRecordId
                  : resolvedPrinterId,
              queueName: resolvedPrinterQueue != '-'
                  ? resolvedPrinterQueue
                  : null,
              backend: resolvedPrinterBackend != '-'
                  ? resolvedPrinterBackend
                  : null,
              details: <String, dynamic>{
                'bridgeResult': bridgeResult ?? const <String, dynamic>{},
              },
            )
            .ignore();
        _failedJobs.removeWhere((j) => j.jobId == jobId);
        _persistFailedJobs().ignore();
        _dispatchedCount++;
        _setLastJob(description: description, error: null);
        final enrichOnlyMs = (enrichMs - claimMs).clamp(0, enrichMs);
        final dispatchOnlyMs = (totalMs - enrichMs).clamp(0, totalMs);
        final bottleneck = _bottleneckStage(
          claimMs: claimMs,
          enrichMs: enrichOnlyMs,
          dispatchMs: dispatchOnlyMs,
        );
        debugPrint(
          '[PrintHub] completed jobId=$jobId '
          'claimMs=$claimMs enrichMs=$enrichMs totalMs=$totalMs',
        );
        debugPrint(
          '[PrintPipeline] trace=$trace stage=completed '
          'at=${completedAt.toIso8601String()} '
          'jobId=$jobId claimMs=$claimMs enrichMs=$enrichMs totalMs=$totalMs '
          'bottleneck=$bottleneck',
        );
        debugPrint(
          '[PrintPipeline] trace=$trace stage=latency_summary '
          'jobId=$jobId '
          'order_saved_at=${latencySummary.orderSavedAt ?? '-'} '
          'print_job_created_at=${latencySummary.printJobCreatedAt ?? '-'} '
          'hub_job_received_at=${latencySummary.hubJobReceivedAt ?? '-'} '
          'claimed_at=${latencySummary.claimedAt ?? '-'} '
          'dispatch_started_at=${latencySummary.dispatchStartedAt ?? '-'} '
          'printer_write_started_at=${latencySummary.printerWriteStartedAt ?? '-'} '
          'completed_at=${latencySummary.completedAt ?? '-'} '
          'A=${_formatLatencyMs(latencySummary.aMs)} '
          'B=${_formatLatencyMs(latencySummary.bMs)} '
          'C=${_formatLatencyMs(latencySummary.cMs)} '
          'D=${_formatLatencyMs(latencySummary.dMs)} '
          'E=${_formatLatencyMs(latencySummary.eMs)} '
          'F=${_formatLatencyMs(latencySummary.fMs)} '
          'pipeline_bottleneck=${latencySummary.bottleneck}',
        );
      } else {
        final err = _normalizedPrintFailure(finalError);
        await _markFailed(jobId, err);
        _eventLogService
            .append(
              restaurantId: _restaurantId!,
              event: 'hub_physical_print_failure',
              message: 'Fiziksel baskı başarısız oldu.',
              level: 'error',
              jobId: jobId,
              role: resolvedRole,
              printerId: resolvedPrinterRecordId != '-'
                  ? resolvedPrinterRecordId
                  : resolvedPrinterId,
              queueName: resolvedPrinterQueue != '-'
                  ? resolvedPrinterQueue
                  : null,
              backend: resolvedPrinterBackend != '-'
                  ? resolvedPrinterBackend
                  : null,
              details: <String, dynamic>{'error': err},
            )
            .ignore();
        _failedCount++;
        _setLastJob(description: description, error: err);
        _addFailedJob(jobId, description, err);
        debugPrint(
          '[PrintHub] all attempts exhausted jobId=$jobId '
          'claimMs=$claimMs enrichMs=$enrichMs totalMs=$totalMs error=$err',
        );
      }
    } catch (e, st) {
      final err = e.toString();
      await _markFailed(jobId, err);
      _eventLogService
          .append(
            restaurantId: _restaurantId!,
            event: 'hub_physical_print_failure',
            message: 'Fiziksel baskı bridge çağrısından önce hata verdi.',
            level: 'error',
            jobId: jobId,
            role: resolvedRole,
            printerId: resolvedPrinterRecordId != '-'
                ? resolvedPrinterRecordId
                : resolvedPrinterId,
            queueName: resolvedPrinterQueue != '-'
                ? resolvedPrinterQueue
                : null,
            backend: resolvedPrinterBackend != '-'
                ? resolvedPrinterBackend
                : null,
            details: <String, dynamic>{'error': err},
          )
          .ignore();
      _failedCount++;
      _setLastJob(description: description, error: err);
      _addFailedJob(jobId, description, err);
      debugPrint(
        '[PrintHub] dispatch unexpected error jobId=$jobId error=$err',
      );
      debugPrintStack(stackTrace: st);
    }
  }

  /// Returns a reusable [LocalPrintService] for the given base URI.
  /// Creates a new one only if the URI changed or none exists.
  /// Uses [_dispatchTimeout] (2s) since bridge is localhost.
  LocalPrintService _getOrCreatePrintService(Uri baseUri) {
    if (_reusablePrintService != null &&
        _reusablePrintServiceBaseUri == baseUri) {
      return _reusablePrintService!;
    }
    _reusablePrintService?.dispose();
    _reusablePrintService = LocalPrintService(
      baseUri: baseUri,
      timeout: _dispatchTimeout,
    );
    _reusablePrintServiceBaseUri = baseUri;
    return _reusablePrintService!;
  }

  void _mergeHubPrinterDispatchFields(
    Map<String, dynamic> target,
    Map<String, dynamic> prepared,
  ) {
    for (final key in <String>[
      'printer_id',
      'printer_name',
      'printer_queue',
      'printer_backend',
      'printer_device_identifier',
      'printer_encoding',
      'encoding',
      'printer_code_page',
      'printer_codepage',
      'code_page',
      'codepage',
      'printer_role',
      'document_type',
      'flow_type',
      'render_mode',
      'encoding_profile_verified',
      'turkish_print_mode',
    ]) {
      if (prepared.containsKey(key) && prepared[key] != null) {
        target[key] = prepared[key];
      }
    }
  }

  String _readText(Object? value) => value?.toString().trim() ?? '';

  // ── DB helpers ─────────────────────────────────────────────────────────────

  /// Fast claim: UPDATE only, no SELECT.  Returns true if the row was
  /// successfully claimed (status was still 'pending').
  Future<bool> _claimJob(
    String jobId, {
    DateTime? hubJobReceivedAt,
    DateTime? claimedAt,
  }) async {
    try {
      final now = claimedAt ?? DateTime.now();
      final rows = await Supabase.instance.client
          .from('print_jobs')
          .update({
            'status': 'claimed',
            'last_error': null,
            'hub_job_received_at': (hubJobReceivedAt ?? now).toIso8601String(),
            'claimed_at': now.toIso8601String(),
          })
          .eq('id', jobId)
          .eq('status', 'pending')
          .select('id');
      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('[PrintHub] claimJob error: $e');
      return false;
    }
  }

  /// Claim + fetch in one round-trip (fallback when payload is missing).
  Future<Map<String, dynamic>?> _claimAndFetchJob(
    String jobId, {
    DateTime? hubJobReceivedAt,
    DateTime? claimedAt,
  }) async {
    try {
      final now = claimedAt ?? DateTime.now();
      final rows = await Supabase.instance.client
          .from('print_jobs')
          .update({
            'status': 'claimed',
            'last_error': null,
            'hub_job_received_at': (hubJobReceivedAt ?? now).toIso8601String(),
            'claimed_at': now.toIso8601String(),
          })
          .eq('id', jobId)
          .eq('status', 'pending')
          .select(
            'id, restaurant_id, order_id, station_id, printer_id, '
            'job_type, payload, status',
          );
      final list = rows as List;
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list.first as Map);
    } catch (e) {
      debugPrint('[PrintHub] claimAndFetchJob error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchJob(String jobId) async {
    try {
      final row = await Supabase.instance.client
          .from('print_jobs')
          .select(
            'id, restaurant_id, order_id, station_id, printer_id, '
            'job_type, payload, status',
          )
          .eq('id', jobId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      debugPrint('[PrintHub] fetchJob error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _enrichPayloadWithPrinterConfig(
    Map<String, dynamic> payload, {
    String? printerId,
  }) async {
    final enriched = Map<String, dynamic>.from(payload);
    final hasEncoding =
        (enriched['printer_encoding'] ?? enriched['encoding']) != null;
    final hasCodePage =
        (enriched['printer_code_page'] ??
            enriched['printer_codepage'] ??
            enriched['code_page'] ??
            enriched['codepage']) !=
        null;
    final hasRoles = enriched['printer_assigned_roles'] is List;
    if (hasEncoding && hasCodePage && hasRoles) {
      return enriched;
    }

    final resolvedPrinterId =
        (printerId ?? enriched['printer_id']?.toString() ?? '').trim();
    if (resolvedPrinterId.isEmpty) {
      const fallback = PrinterEncodingSelection(
        charset: PrinterCharset.cp857,
        codePage: PrinterEncodingSelection.defaultTurkishCodePage,
      );
      enriched['printer_encoding'] = fallback.encoding;
      enriched['printer_code_page'] = fallback.codePage;
      enriched['printer_assigned_roles'] = const <String>[];
      return enriched;
    }

    try {
      // Check in-memory cache first to avoid a DB round-trip.
      final cached = _printerConfigCache[resolvedPrinterId];
      if (cached != null) {
        enriched.addAll(cached);
        return enriched;
      }

      final row = await Supabase.instance.client
          .from('printers')
          .select()
          .eq('id', resolvedPrinterId)
          .maybeSingle();
      if (row == null) {
        return enriched;
      }
      final printer = PrinterModel.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
      final selection = printer.encodingSelection;
      final configMap = <String, dynamic>{
        'printer_encoding': selection.encoding,
        'printer_code_page': selection.codePage,
        'printer_charset': printer.charset.value,
        'printer_assigned_roles': printer.assignedRoles
            .map((role) => role.value)
            .toList(growable: false),
      };
      _printerConfigCache[resolvedPrinterId] = configMap;
      enriched.addAll(configMap);
      if (selection.fallbackApplied) {
        debugPrint(
          '[PrintHub] encoding_guard '
          'printerId=$resolvedPrinterId printerName=${printer.name} '
          'requestedCharset=${printer.charset.value} '
          'requestedCodePage=${printer.codePage ?? '-'} '
          'effectiveEncoding=${selection.encoding} '
          'effectiveCodePage=${selection.codePage ?? '-'} '
          'warning=${selection.warning}',
        );
      }
    } catch (e) {
      debugPrint(
        '[PrintHub] enrichPayloadWithPrinterConfig error '
        'printerId=$resolvedPrinterId error=$e',
      );
    }
    return enriched;
  }

  Future<void> _markPrinting(
    String jobId, {
    required DateTime dispatchStartedAt,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await Supabase.instance.client
          .from('print_jobs')
          .update({
            'status': 'printing',
            'last_error': null,
            'dispatch_started_at': dispatchStartedAt.toIso8601String(),
            if (payload?['printer_record_id'] != null)
              'printer_id': payload!['printer_record_id'],
            ...?payload == null ? null : <String, dynamic>{'payload': payload},
          })
          .eq('id', jobId)
          .inFilter('status', ['claimed', 'pending']);
    } catch (e) {
      debugPrint('[PrintHub] markPrinting error: $e');
    }
  }

  Future<void> _markCompleted(
    String jobId, {
    required DateTime completedAt,
    Map<String, dynamic>? bridgeResult,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await Supabase.instance.client
          .from('print_jobs')
          .update({
            'status': 'completed',
            'last_error': null,
            'printed_at': completedAt.toIso8601String(),
            'completed_at': completedAt.toIso8601String(),
            if (payload?['printer_record_id'] != null)
              'printer_id': payload!['printer_record_id'],
            ...?payload == null ? null : <String, dynamic>{'payload': payload},
            'printer_write_started_at':
                bridgeResult?['printer_write_started_at'],
            'printer_write_completed_at':
                bridgeResult?['printer_write_completed_at'],
          })
          .eq('id', jobId);
    } catch (e) {
      debugPrint('[PrintHub] markCompleted error: $e');
    }
  }

  Future<void> _markFailed(String jobId, String error) async {
    try {
      await Supabase.instance.client
          .from('print_jobs')
          .update({'status': 'failed', 'last_error': error})
          .eq('id', jobId);
    } catch (e) {
      debugPrint('[PrintHub] markFailed error: $e');
    }
  }

  String _normalizedPrintFailure(Object? error) {
    final raw = error?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return 'Yazdırma başarısız oldu.';
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length).trim();
    }
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  // ── Route / URI resolution ─────────────────────────────────────────────────

  /// Resolves the bridge base URI.
  ///
  /// Priority:
  ///   1. `payload['printer_base_url']` — set by SQL RPC when printer has a
  ///      custom host/port (e.g. a network printer).
  ///   2. Default local bridge at 127.0.0.1:3001.
  Uri _resolveBaseUri(Map<String, dynamic> payload) {
    final stored = payload['printer_base_url']?.toString().trim() ?? '';
    if (stored.isNotEmpty) {
      try {
        return Uri.parse(stored);
      } catch (_) {}
    }
    return Uri.parse('http://127.0.0.1:3001');
  }

  /// Resolves the HTTP route to call on the bridge.
  ///
  /// Priority:
  ///   1. `payload['printer_http_route']` — set by SQL RPC.
  ///   2. Guess from station_name / job_type (adisyon/receipt → receipt endpoint).
  ///   3. Default: `/print/kitchen`.
  String _resolvePrinterRoute(Map<String, dynamic> payload) {
    final stored = payload['printer_http_route']?.toString().trim() ?? '';
    final documentType =
        payload['document_type']?.toString().trim().toLowerCase() ?? '';
    final jobType = payload['job_type']?.toString().trim().toLowerCase() ?? '';
    final printerRole =
        payload['printer_role']?.toString().trim().toLowerCase() ?? '';
    final wantsReceipt =
        printerRole == 'adisyon' ||
        printerRole == 'receipt' ||
        documentType == 'receipt' ||
        jobType == 'receipt' ||
        jobType == 'test_receipt';
    if (stored.isNotEmpty) {
      if (stored == '/print/receipt' && !wantsReceipt) {
        debugPrint(
          '[PrintHub] route_guard forcing kitchen route '
          'printerRole=${printerRole.isEmpty ? '-' : printerRole} '
          'documentType=${documentType.isEmpty ? '-' : documentType} '
          'jobType=${jobType.isEmpty ? '-' : jobType} stored=$stored',
        );
        return '/print/kitchen';
      }
      return stored;
    }
    final station = (payload['station_name']?.toString() ?? '').toLowerCase();
    if (station.contains('adisyon') ||
        station.contains('receipt') ||
        wantsReceipt) {
      return '/print/receipt';
    }
    return '/print/kitchen';
  }

  // ── Private state helpers ──────────────────────────────────────────────────

  void _setBridgeStatus(BridgeStatus status) {
    if (_bridgeStatus != status) {
      _bridgeStatus = status;
      notifyListeners();
    }
  }

  void _setLastJob({required String description, required String? error}) {
    _lastJobTime = DateTime.now();
    _lastJobDescription = description;
    _lastJobError = error;
    notifyListeners();
  }

  String _bottleneckStage({
    required int claimMs,
    required int enrichMs,
    required int dispatchMs,
  }) {
    final stages = <String, int>{
      'claim': claimMs,
      'enrich': enrichMs,
      'dispatch': dispatchMs,
    };
    var winner = 'dispatch';
    var winnerMs = -1;
    for (final entry in stages.entries) {
      if (entry.value > winnerMs) {
        winner = entry.key;
        winnerMs = entry.value;
      }
    }
    return '$winner:${winnerMs < 0 ? 0 : winnerMs}ms';
  }

  // ── Telemetry helpers ──────────────────────────────────────────────────────

  /// Resolve a human-readable trace ID from the job record.
  String _resolveTraceId(
    Map<String, dynamic> record, {
    required String fallbackJobId,
  }) {
    // Try to extract trace from notes field (mobile puts trace as prefix).
    final payload = record['payload'];
    if (payload is Map) {
      final notes = payload['notes']?.toString() ?? '';
      if (notes.length >= 8) {
        final candidate = notes.split(' ').first;
        if (candidate.length >= 8 && candidate.length <= 16) {
          return candidate;
        }
      }
    }
    // Fallback: first 8 chars of job ID.
    return fallbackJobId.length >= 8
        ? fallbackJobId.substring(0, 8)
        : fallbackJobId;
  }

  /// Read a stage timestamp from a job record map.
  DateTime? _readStageTimestamp(Map<String, dynamic> record, String key) {
    final raw = record[key];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  /// Format an optional latency value in milliseconds.
  String _formatLatencyMs(int? ms) => ms == null ? '-' : '${ms}ms';

  /// Builds a latency summary across all pipeline stages.
  _PipelineLatencySummary _buildLatencySummary(
    Map<String, dynamic> job, {
    required DateTime hubJobReceivedAt,
    required DateTime claimedAt,
    required DateTime dispatchStartedAt,
    Map<String, dynamic>? bridgeResult,
    required DateTime completedAt,
  }) {
    final orderSavedAt = _readStageTimestamp(job, 'order_saved_at');
    final printJobCreatedAt = _readStageTimestamp(job, 'print_job_created_at');
    final printerWriteStartedAt =
        _readStageTimestamp(bridgeResult ?? {}, 'printer_write_started_at') ??
        _readStageTimestamp(job, 'printer_write_started_at');

    int? diffMs(DateTime? a, DateTime? b) {
      if (a == null || b == null) return null;
      return b.difference(a).inMilliseconds;
    }

    return _PipelineLatencySummary(
      orderSavedAt: orderSavedAt?.toIso8601String(),
      printJobCreatedAt: printJobCreatedAt?.toIso8601String(),
      hubJobReceivedAt: hubJobReceivedAt.toIso8601String(),
      claimedAt: claimedAt.toIso8601String(),
      dispatchStartedAt: dispatchStartedAt.toIso8601String(),
      printerWriteStartedAt: printerWriteStartedAt?.toIso8601String(),
      completedAt: completedAt.toIso8601String(),
      aMs: diffMs(orderSavedAt, printJobCreatedAt),
      bMs: diffMs(printJobCreatedAt, hubJobReceivedAt),
      cMs: diffMs(hubJobReceivedAt, claimedAt),
      dMs: diffMs(claimedAt, dispatchStartedAt),
      eMs: diffMs(dispatchStartedAt, printerWriteStartedAt),
      fMs: diffMs(printerWriteStartedAt, completedAt),
      bottleneck: _pipelineBottleneck(
        aMs: diffMs(orderSavedAt, printJobCreatedAt),
        bMs: diffMs(printJobCreatedAt, hubJobReceivedAt),
        cMs: diffMs(hubJobReceivedAt, claimedAt),
        dMs: diffMs(claimedAt, dispatchStartedAt),
        eMs: diffMs(dispatchStartedAt, printerWriteStartedAt),
        fMs: diffMs(printerWriteStartedAt, completedAt),
      ),
    );
  }

  String _pipelineBottleneck({
    int? aMs,
    int? bMs,
    int? cMs,
    int? dMs,
    int? eMs,
    int? fMs,
  }) {
    final stages = <String, int?>{
      'A_rpc': aMs,
      'B_realtime': bMs,
      'C_claim': cMs,
      'D_enrich': dMs,
      'E_bridge': eMs,
      'F_print': fMs,
    };
    var winner = 'unknown';
    var winnerMs = -1;
    for (final entry in stages.entries) {
      if (entry.value != null && entry.value! > winnerMs) {
        winner = entry.key;
        winnerMs = entry.value!;
      }
    }
    return '$winner:${winnerMs < 0 ? 0 : winnerMs}ms';
  }

  // ── Warm-up helpers ────────────────────────────────────────────────────────

  /// Pre-warm the entire print pipeline on startup so the first real print
  /// has zero cold-start penalty.
  ///
  /// Steps:
  ///   1. Pre-create the reusable dispatch HTTP client (avoids TCP cold-start).
  ///   2. Call GET /warmup on bridge (warms fonts, USB, Pillow, renderers).
  ///   3. Pre-cache printer configs from DB (avoids per-job DB round-trip).
  ///   4. Fall back to health check if /warmup fails.
  Future<void> _warmBridgeState() async {
    final watch = Stopwatch()..start();

    // 1. Pre-create the dispatch HTTP client to the default bridge URI.
    //    This ensures the first real dispatch doesn't pay for client creation.
    final defaultUri = Uri.parse('http://127.0.0.1:3001');
    _getOrCreatePrintService(defaultUri);
    debugPrint(
      '[PrintHub] warm-up: dispatch HTTP client pre-created '
      '(${watch.elapsedMilliseconds}ms)',
    );

    // 2. Call /warmup on bridge — warms font cache, USB endpoint, Pillow.
    //    Uses the pre-created reusable client.
    final svc = _reusablePrintService;
    if (svc != null) {
      try {
        final result = await svc.warmup(timeout: const Duration(seconds: 5));
        if (result != null && result['ok'] == true) {
          _setBridgeStatus(BridgeStatus.online);
          final timings = result['timings'];
          debugPrint(
            '[PrintHub] warm-up: bridge pipeline ready '
            'fonts_loaded=${result['fonts_loaded']} '
            'usb_ok=${result['usb_ok']} '
            'pillow_ok=${result['pillow_ok']} '
            'timings=$timings '
            'total=${watch.elapsedMilliseconds}ms',
          );
        } else {
          // /warmup returned but not ok — fall back to health
          debugPrint(
            '[PrintHub] warm-up: /warmup returned non-ok, falling back to health',
          );
          await checkBridge();
        }
      } catch (e) {
        // /warmup not available (old bridge?) — fall back to health check
        debugPrint(
          '[PrintHub] warm-up: /warmup failed ($e), falling back to health',
        );
        await checkBridge();
      }
    } else {
      await checkBridge();
    }

    // 3. Pre-cache printer configs for this restaurant.
    await _warmPrinterConfigCache();

    debugPrint(
      '[PrintHub] warm-up complete: total=${watch.elapsedMilliseconds}ms '
      'bridge=$_bridgeStatus printerCache=${_printerConfigCache.length}',
    );
  }

  /// Fetch all active printers for the current restaurant and populate
  /// the in-memory config cache so [_enrichPayloadWithPrinterConfig] never
  /// needs a DB round-trip during dispatch.
  Future<void> _warmPrinterConfigCache() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('printers')
          .select()
          .eq('seller_id', restaurantId)
          .eq('is_active', true);
      final printers = rows as List;
      for (final row in printers) {
        final printer = PrinterModel.fromMap(
          Map<String, dynamic>.from(row as Map),
        );
        final selection = printer.encodingSelection;
        _printerConfigCache[printer.id] = <String, dynamic>{
          'printer_encoding': selection.encoding,
          'printer_code_page': selection.codePage,
          'printer_charset': printer.charset.value,
          'printer_assigned_roles': printer.assignedRoles
              .map((role) => role.value)
              .toList(growable: false),
        };
      }
      debugPrint(
        '[PrintHub] warm printer cache: ${_printerConfigCache.length} printers',
      );
    } catch (e) {
      debugPrint('[PrintHub] warmPrinterConfigCache error: $e');
    }
  }
}

/// Pipeline latency summary data class.
class _PipelineLatencySummary {
  const _PipelineLatencySummary({
    this.orderSavedAt,
    this.printJobCreatedAt,
    this.hubJobReceivedAt,
    this.claimedAt,
    this.dispatchStartedAt,
    this.printerWriteStartedAt,
    this.completedAt,
    this.aMs,
    this.bMs,
    this.cMs,
    this.dMs,
    this.eMs,
    this.fMs,
    this.bottleneck,
  });

  final String? orderSavedAt;
  final String? printJobCreatedAt;
  final String? hubJobReceivedAt;
  final String? claimedAt;
  final String? dispatchStartedAt;
  final String? printerWriteStartedAt;
  final String? completedAt;
  final int? aMs;
  final int? bMs;
  final int? cMs;
  final int? dMs;
  final int? eMs;
  final int? fMs;
  final String? bottleneck;
}
