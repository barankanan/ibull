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

  /// Test seam: replaces the session lookup. Production leaves it null.
  @visibleForTesting
  Future<String> Function({required bool forceRefresh})? accessTokenProvider;

  /// Why the last run held its orders back for lack of a usable session
  /// (null when it did not). The banner shows it instead of a raw error.
  static final ValueNotifier<String?> authNotice = ValueNotifier<String?>(null);

  /// The caller's own session token, refreshed first when it is expired or
  /// about to be (after an internet cut the stored token is usually stale).
  /// Never returns something that is not a three-part JWT, so a non-token can
  /// never reach the server ("Expected 3 parts in JWT"). Throws
  /// [SyncAuthUnavailable] when no valid session can be had; the order then
  /// stays queued untouched.
  Future<String> _freshAccessToken({required bool forceRefresh}) async {
    final seam = accessTokenProvider;
    if (seam != null) return seam(forceRefresh: forceRefresh);
    final isolated = isolatedAccessToken?.trim() ?? '';
    if (isolated.isNotEmpty) return isolated;
    return defaultFreshAccessToken(forceRefresh: forceRefresh);
  }

  static Future<String> defaultFreshAccessToken({
    required bool forceRefresh,
  }) async {
    try {
      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;
      if (session == null) throw const SyncAuthUnavailable('oturum yok');
      final exp = session.expiresAt;
      final nearExpiry =
          session.isExpired ||
          (exp != null &&
              DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(
                DateTime.now().add(const Duration(seconds: 60)),
              ));
      if (forceRefresh || nearExpiry) {
        final refreshed = await auth.refreshSession().timeout(
          const Duration(seconds: 8),
        );
        session = refreshed.session ?? auth.currentSession;
      }
      final token = session?.accessToken ?? '';
      if (!looksLikeJwt(token)) {
        throw const SyncAuthUnavailable('geçerli oturum belirteci yok');
      }
      return token;
    } on SyncAuthUnavailable {
      rethrow;
    } catch (_) {
      throw const SyncAuthUnavailable('oturum yenilenemedi');
    }
  }

  @visibleForTesting
  static bool looksLikeJwt(String token) {
    final parts = token.trim().split('.');
    return parts.length == 3 && parts.every((p) => p.isNotEmpty);
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
    var authHold = false;
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
            waiterId: lanOrderWaiterRef(order),
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
              waiterId: lanOrderWaiterRef(order),
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
        } on SyncAuthUnavailable catch (hold) {
          // No usable session: nothing was sent and the order is NOT marked
          // failed. The rest of the batch would hit the same wall.
          authNotice.value =
              'Oturum doğrulanamadı (${hold.reason}). Siparişler cihazda bekliyor; '
              'internet ve oturum gelince kendiliğinden gönderilir.';
          authHold = true;
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
        if (authHold) break;
      }
      if (!authHold) authNotice.value = null;
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
    for (var attempt = 0; ; attempt++) {
      // A 401 is answered once with a forced refresh; a second one means the
      // server will not accept this session, which is an auth hold, not a
      // failed order.
      final token = await _freshAccessToken(forceRefresh: attempt > 0);
      final client = HttpClient();
      try {
        final request = await client.postUrl(_evidenceVerifierUri!);
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.add(
          utf8.encode(
            jsonEncode(<String, dynamic>{...params, 'branch_id': branchId}),
          ),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        final text = await utf8.decoder.bind(response).join();
        if (response.statusCode == 401) {
          if (attempt == 0) continue;
          throw const SyncAuthUnavailable('sunucu oturumu kabul etmedi');
        }
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

/// Geçerli oturum yok/yenilenemedi: sipariş gönderilmez, hata sayılmaz, kuyrukta kalır.
class SyncAuthUnavailable implements Exception {
  const SyncAuthUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'SyncAuthUnavailable($reason)';
}

/// Hata almış siparişin yeniden denenmeden önce beklediği süre.
/// Varsayılan 0: yanıtı kaybolan bir gönderim hemen yeniden denenebilir (aynı yerel kimlik,
/// sunucu tekrar kaydı yapmaz). Sıralama zaten en eski denenen hatalıyı sona alır; döngüyü
/// `RestaurantOfflineLifecycle` ilerleme olmayınca keser. Seçici gerekirse süre verebilir.
const Duration orderSyncRetryAfterDefault = Duration.zero;
const Duration orderSyncRetryAfter = Duration(seconds: 30);

/// Buluta HİÇBİR yolla (otomatik, toplu, elle) gönderilmeyecek yerel sipariş kimlikleri.
/// Kayıt silinmez ve değiştirilmez; yerelde görünür kalır.
///
/// `local-order-1793736854400492-1173607028`: 2026-11-03, masa 19, 320 TL, baskısı
/// belirsiz; oturumsuz gönderimde `PGRST301` almış ve bulutta karşılığı yok. Kayıt
/// Anahtar Zinciri kopyasından geri geldiği için yerel dosyadan ayırmak işe yaramıyor;
/// bu yüzden kimlik kodda sabit. Yaşa dayalı genel bir engel YOK: uzun süre çevrimdışı
/// kalmış geçerli siparişler gönderilir (sunucu aynı yerel kimliği ikinci kez yazmaz).
const Set<String> quarantinedLocalOrderIds = <String>{
  'local-order-1793736854400492-1173607028',
};

/// Bu turda gönderilecek siparişler.
/// - Karantinadaki kimlikler hiç seçilmez.
/// - Hiç denenmemişler (`pendingSync`/`localOnly`) önce, en eski oluşturulan önce.
/// - Sonra hata almışlar, EN ESKİ denenen önce; bekleme süresi dolmamışlar atlanır.
/// Böylece sürekli hata veren eski siparişler kuyruğun başını tutup yenileri aç bırakmaz.
List<RestaurantLocalOrderRecord> selectOrdersForSync(
  List<RestaurantLocalOrderRecord> pending, {
  required DateTime now,
  int limit = 10,
  Duration retryAfter = orderSyncRetryAfter,
  Set<String> quarantined = quarantinedLocalOrderIds,
  Set<String>? ticketsInFlight,
}) {
  final inFlight = ticketsInFlight ?? localTicketsInFlight;
  pending = pending
      .where((o) => !quarantined.contains(o.localOrderId))
      // The ticket of this order is being printed right now. Sent at this
      // moment it would go up as "uncertain" although it is about to print;
      // it is taken on the next round, with its real result. The mark lives
      // only while the print call runs, so no order is held back by it.
      .where((o) => !inFlight.contains(o.localOrderId))
      .toList(growable: false);
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

/// The staff id a cloud order is sent with. The center's verified staff id (the
/// paired device's account) wins; an order without one (older record, the
/// owner's own order) keeps its UUID waiter. The device fingerprint is never a
/// waiter, and a staff id that is not a UUID is dropped instead of replaced by
/// something else. `null` lets the server use the signed-in owner, as before.
String? lanOrderWaiterRef(RestaurantLocalOrderRecord order) {
  final staff = order.staffId.trim();
  if (staff.isNotEmpty) return _cloudUserId(staff);
  return _cloudUserId(order.waiterId);
}

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
