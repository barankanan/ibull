import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../order_print_job_service.dart';
import 'print_evidence.dart';
import 'restaurant_connectivity_service.dart';
import '../print_service_start_gate.dart';
import 'restaurant_lan_host.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_offline_models.dart';

/// V1 sync skeleton: marks pending orders and attempts Supabase replay when online.
class RestaurantOfflineSyncService {
  RestaurantOfflineSyncService({
    RestaurantLocalOrderQueueService? orderQueue,
    OrderPrintJobService? orderPrintJobService,
    RestaurantConnectivityService? connectivityService,
    this.isolatedPostgrestUri,
    this.isolatedAccessToken,
    this.isolatedEvidenceVerifierUri,
  }) : _orderQueue = orderQueue ?? RestaurantLocalOrderQueueService(),
       _orderPrintJobService = orderPrintJobService ?? OrderPrintJobService(),
       _connectivity =
           connectivityService ?? RestaurantConnectivityService.instance;

  final RestaurantLocalOrderQueueService _orderQueue;
  final OrderPrintJobService _orderPrintJobService;
  final RestaurantConnectivityService _connectivity;

  /// Isolated PostgREST only. Production keeps [OrderPrintJobService].
  final Uri? isolatedPostgrestUri;
  final String? isolatedAccessToken;

  /// Local WebCrypto verifier. It is not the production Edge deployment.
  final Uri? isolatedEvidenceVerifierUri;

  /// Address of the deployed print-evidence verifier
  /// (`verify-lan-print-evidence`). It is a build setting: a build without it
  /// keeps printed offline orders on the device instead of sending them
  /// without proof.
  static const String configuredEvidenceVerifierUrl = String.fromEnvironment(
    'IBUL_LAN_EVIDENCE_VERIFIER_URL',
  );

  /// The verifier this run uses: the test one when given, else the build's.
  @visibleForTesting
  static Uri? resolveEvidenceVerifierUri({
    Uri? isolated,
    String configured = configuredEvidenceVerifierUrl,
  }) {
    if (isolated != null) return isolated;
    final text = configured.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final local = uri.host == '127.0.0.1' || uri.host == 'localhost';
    // Evidence and the caller's token travel on this connection.
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) return null;
    return uri;
  }

  Uri? get _evidenceVerifierUri =>
      resolveEvidenceVerifierUri(isolated: isolatedEvidenceVerifierUri);

  /// The caller's own session token; the verifier checks it with the server.
  String get _verifierAccessToken {
    final isolated = isolatedAccessToken?.trim() ?? '';
    if (isolated.isNotEmpty) return isolated;
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    } catch (_) {
      return '';
    }
  }

  // Shared by every instance: the banner, the reconnect listener and the
  // app-level lifecycle each create their own service object.
  static final Set<String> _syncInFlight = <String>{};

  Future<int> pendingCount(String restaurantId) =>
      _orderQueue.pendingSyncCount(restaurantId);

  Future<List<RestaurantLocalOrderRecord>> pendingOrders(String restaurantId) =>
      _orderQueue.pendingSyncOrders(restaurantId);

  /// Oturum yoksa gönderim denenmez: siparişler `pendingSync` kalır, "hata aldı" diye
  /// işaretlenmez ve oturum açılınca kaldığı yerden gider. Supabase başlatılmamışsa
  /// (birim testi) koruma devre dışıdır.
  static bool defaultHasCloudSession() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return true;
    }
  }

  @visibleForTesting
  bool Function() hasCloudSession = defaultHasCloudSession;

  /// Elle tetiklenen eşitleme ([forceRetry]) hata almış siparişleri bekleme süresi dolmadan
  /// da dener.
  Future<int> syncPendingOrders({
    required String restaurantId,
    int limit = 10,
    bool forceRetry = false,
  }) async {
    if (isolatedPostgrestUri == null) {
      await _connectivity.refresh();
      if (!_connectivity.hasNetwork || !_connectivity.supabaseReachable) {
        return 0;
      }
      if (!hasCloudSession()) {
        debugPrint('[RestaurantOfflineSync] oturum yok; gönderim bekletildi.');
        return 0;
      }
    }

    final allPending = await _orderQueue.pendingSyncOrders(restaurantId);
    final pending = selectOrdersForSync(
      allPending,
      now: DateTime.now(),
      limit: limit,
      retryAfter: forceRetry ? Duration.zero : orderSyncRetryAfterDefault,
    );
    if (pending.isEmpty) return 0;

    _connectivity.setSyncing(true);
    var syncedCount = 0;
    try {
      for (final order in pending) {
        if (_syncInFlight.contains(order.localOrderId)) continue;
        _syncInFlight.add(order.localOrderId);
        try {
          final host = RestaurantLanHostRegistry.current;
          final plan = planLanOrderSync(
            listeningHost:
                host != null &&
                host.listening &&
                host.restaurantId == restaurantId,
            printStatus: order.printStatus,
            fromEarlierSession: PrintServiceStartGate.jobIsFromBefore(
              order.createdAt.toUtc().toIso8601String(),
            ),
          );
          if (plan.action != 'sync') {
            await _orderQueue.update(
              restaurantId: restaurantId,
              order: order.copyWith(
                syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
                syncError: plan.reason,
                updatedAt: DateTime.now(),
              ),
            );
            continue;
          }
          String? evidence = plan.evidence;
          if (evidence == 'uncertain' && order.printStatus != 'uncertain') {
            // Keep the identity and the record; only make the print state
            // honest so a retry after a crash sends the same evidence.
            await _orderQueue.update(
              restaurantId: restaurantId,
              order: order.copyWith(
                printStatus: 'uncertain',
                updatedAt: DateTime.now(),
              ),
            );
          }
          if (evidence != null && (host?.branchId ?? '').trim().isEmpty) {
            // Evidence is bound to the center's branch. A center that has not
            // registered with the cloud yet has none, and its evidence could
            // only come back "unverified", which queues the ticket again.
            await _orderQueue.update(
              restaurantId: restaurantId,
              order: order.copyWith(
                syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
                syncError:
                    'Yerel merkez buluta kaydedilmedi. İşletme sahibi internet varken paneli açınca gönderilecek.',
                updatedAt: DateTime.now(),
              ),
            );
            continue;
          }
          if (evidence != null) {
            evidence = await host?.evidenceForOrder(
              localOrderId: order.localOrderId,
              outcome: plan.evidence!,
              revision: '1',
              eventId: '${order.localOrderId}|1|${plan.evidence}',
              items: order.items,
            );
            if (evidence == null) {
              await _orderQueue.update(
                restaurantId: restaurantId,
                order: order.copyWith(
                  syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
                  syncError:
                      'Yerel baskı kanıtı imzalanamadı. Kanıtsız gönderilmedi.',
                  updatedAt: DateTime.now(),
                ),
              );
              continue;
            }
          }
          final params = createTableOrderRpcParams(
            restaurantId: order.restaurantId,
            tableNumber: order.tableNumber,
            items: order.items,
            waiterId: _cloudUserId(order.waiterId),
            waiterName: order.waiterName.isEmpty ? null : order.waiterName,
            notes: order.notes.isEmpty ? null : order.notes,
            jobType: 'new_order',
            localOrderId: order.localOrderId,
            localPrintEvidence: evidence,
          );
          final OrderPrintJobDispatchResult result;
          if (plan.evidence != null &&
              plan.evidence != 'failed' &&
              _evidenceVerifierUri == null &&
              isolatedPostgrestUri == null) {
            await _orderQueue.update(
              restaurantId: restaurantId,
              order: order.copyWith(
                syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
                syncError:
                    'Baskı kanıtı doğrulayıcısı yok. Fiş buluta kanıtsız gönderilmedi.',
                updatedAt: DateTime.now(),
              ),
            );
            continue;
          }
          if (evidence != null && _evidenceVerifierUri != null) {
            result = await _postEvidenceVerifier(params, host?.branchId ?? '');
          } else if (isolatedPostgrestUri != null) {
            result = await _postIsolatedOrder(params);
          } else {
            result = await _orderPrintJobService.dispatchNewOrder(
              restaurantId: order.restaurantId,
              tableNumber: order.tableNumber,
              items: order.items,
              waiterId: _cloudUserId(order.waiterId),
              waiterName: order.waiterName.isEmpty ? null : order.waiterName,
              notes: order.notes.isEmpty ? null : order.notes,
              jobType: 'new_order',
              garsonDesktopFastKitchen: true,
              skipOfflineFallback: true,
              localOrderId: order.localOrderId,
              suppressPhysicalPrint:
                  plan.evidence == 'forwarded' || plan.evidence == 'uncertain',
              localPrintStatus: order.printStatus,
              localPrintEvidence: null,
            );
          }
          final remoteOrderId = result.orderId ?? '';
          if (remoteOrderId.isEmpty) {
            await _orderQueue.update(
              restaurantId: restaurantId,
              order: order.copyWith(
                syncStatus: RestaurantLocalOrderSyncStatus.syncFailed,
                syncError: 'Supabase sipariş kimliği alınamadı.',
                updatedAt: DateTime.now(),
              ),
            );
            continue;
          }
          await _orderQueue.markSynced(
            restaurantId: restaurantId,
            localOrderId: order.localOrderId,
            remoteOrderId: remoteOrderId,
          );
          syncedCount++;
        } catch (error, stackTrace) {
          debugPrint(
            '[RestaurantOfflineSync] failed localOrder=${order.localOrderId} error=$error',
          );
          try {
            debugPrintStack(stackTrace: stackTrace);
          } catch (_) {}
          final conflict = lanSyncErrorIsConflict(error.toString());
          await _orderQueue.update(
            restaurantId: restaurantId,
            order: order.copyWith(
              syncStatus: conflict
                  ? RestaurantLocalOrderSyncStatus.conflict
                  : RestaurantLocalOrderSyncStatus.syncFailed,
              syncError: error.toString(),
              updatedAt: DateTime.now(),
            ),
          );
        } finally {
          _syncInFlight.remove(order.localOrderId);
        }
      }
    } finally {
      _connectivity.setSyncing(false);
    }
    return syncedCount;
  }

  void clearSyncInFlightForTests() {
    _syncInFlight.clear();
  }

  Future<OrderPrintJobDispatchResult> _postEvidenceVerifier(
    Map<String, dynamic> params,
    String branchId,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(_evidenceVerifierUri!);
      request.headers.contentType = ContentType.json;
      final token = _verifierAccessToken;
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.add(
        utf8.encode(
          jsonEncode(<String, dynamic>{...params, 'branch_id': branchId}),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 400) throw StateError(text);
      final decoded = jsonDecode(text);
      final body = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      return OrderPrintJobDispatchResult(
        orderId: body?['order_id']?.toString(),
        orderNumber: body?['order_number']?.toString(),
        printJobCount: 0,
        printJobIds: const <String>[],
        raw: body ?? const <String, dynamic>{},
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<OrderPrintJobDispatchResult> _postIsolatedOrder(
    Map<String, dynamic> params,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        isolatedPostgrestUri!.replace(
          path: '/rpc/create_table_order_with_print_jobs',
        ),
      );
      request.headers.contentType = ContentType.json;
      final token = isolatedAccessToken?.trim() ?? '';
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.add(utf8.encode(jsonEncode(params)));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 400) {
        throw StateError(text);
      }
      final decoded = jsonDecode(text);
      final body = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      return OrderPrintJobDispatchResult(
        orderId: body?['order_id']?.toString(),
        orderNumber: body?['order_number']?.toString(),
        printJobCount: 0,
        printJobIds: const <String>[],
        raw: body ?? const <String, dynamic>{},
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// Hata almış siparişin yeniden denenmeden önce beklediği süre.
/// Varsayılan 0: yanıtı kaybolan bir gönderim hemen yeniden denenebilir (aynı yerel kimlik,
/// sunucu tekrar kaydı yapmaz). Sıralama zaten en eski denenen hatalıyı sona alır; döngüyü
/// `RestaurantOfflineLifecycle` ilerleme olmayınca keser. Seçici gerekirse süre verebilir.
const Duration orderSyncRetryAfterDefault = Duration.zero;
const Duration orderSyncRetryAfter = Duration(seconds: 30);

/// Bu turda gönderilecek siparişler.
/// - Hiç denenmemişler (`pendingSync`/`localOnly`) önce, en eski oluşturulan önce.
/// - Sonra hata almışlar, EN ESKİ denenen önce; bekleme süresi dolmamışlar atlanır.
/// Böylece sürekli hata veren eski siparişler kuyruğun başını tutup yenileri aç bırakmaz.
List<RestaurantLocalOrderRecord> selectOrdersForSync(
  List<RestaurantLocalOrderRecord> pending, {
  required DateTime now,
  int limit = 10,
  Duration retryAfter = orderSyncRetryAfter,
}) {
  final fresh =
      pending
          .where(
            (o) => o.syncStatus != RestaurantLocalOrderSyncStatus.syncFailed,
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final failed =
      pending
          .where(
            (o) =>
                o.syncStatus == RestaurantLocalOrderSyncStatus.syncFailed &&
                !o.updatedAt.isAfter(now.subtract(retryAfter)),
          )
          .toList()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  return <RestaurantLocalOrderRecord>[
    ...fresh,
    ...failed,
  ].take(limit).toList(growable: false);
}

class LanOrderSyncPlan {
  const LanOrderSyncPlan({required this.action, this.evidence, this.reason});

  final String action;
  final String? evidence;
  final String? reason;
}

final _cloudUserIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String? _cloudUserId(String value) {
  final text = value.trim();
  if (!_cloudUserIdPattern.hasMatch(text)) return null;
  return text;
}

/// The listening owner host is the only sync identity. Every local order is
/// sent with signed evidence; an order is never sent without it, so the cloud
/// cannot repeat a ticket that may already exist. `printed` is never treated
/// as a device acknowledgement.
LanOrderSyncPlan planLanOrderSync({
  required bool listeningHost,
  required String printStatus,
  bool fromEarlierSession = false,
}) {
  if (!listeningHost) {
    return const LanOrderSyncPlan(
      action: 'hold',
      reason: 'Senkronizasyon yalnız açık yerel sunucudan yapılır.',
    );
  }
  final status = printStatus.trim();
  // Only a recorded fact lets the cloud print: `failed` (a printer refused)
  // and `not_sent` (nothing was handed to any printer). Every other status,
  // including `pending` (the center may have stopped between the printer
  // write and the status update) and anything unknown, may already be on
  // paper, so it goes up as `uncertain` and is held for the operator.
  final evidence = switch (status) {
    'printed' || 'forwarded' => 'forwarded',
    // An order taken before this session's "Başlat" whose ticket never came
    // out is not printed by the cloud on its own a session later: it goes up
    // held, and the operator decides.
    'failed' || 'not_sent' => fromEarlierSession ? 'uncertain' : 'failed',
    _ => 'uncertain',
  };
  return LanOrderSyncPlan(action: 'sync', evidence: evidence);
}

bool lanSyncErrorIsConflict(String text) {
  final lower = text.toLowerCase();
  return lower.contains('farklı içerik') ||
      lower.contains('doğrulanamadı') ||
      lower.contains('çakış');
}
