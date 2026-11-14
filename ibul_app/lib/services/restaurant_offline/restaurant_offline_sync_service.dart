import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../order_print_job_service.dart';
import 'print_evidence.dart';
import 'restaurant_connectivity_service.dart';
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
  final Set<String> _syncInFlight = <String>{};

  Future<int> pendingCount(String restaurantId) =>
      _orderQueue.pendingSyncCount(restaurantId);

  Future<List<RestaurantLocalOrderRecord>> pendingOrders(String restaurantId) =>
      _orderQueue.pendingSyncOrders(restaurantId);

  Future<int> syncPendingOrders({
    required String restaurantId,
    int limit = 10,
  }) async {
    if (isolatedPostgrestUri == null) {
      await _connectivity.refresh();
      if (!_connectivity.hasNetwork || !_connectivity.supabaseReachable) {
        return 0;
      }
    }

    final pending = await _orderQueue.pendingSyncOrders(restaurantId);
    if (pending.isEmpty) return 0;

    _connectivity.setSyncing(true);
    var syncedCount = 0;
    try {
      for (final order in pending.take(limit)) {
        if (_syncInFlight.contains(order.localOrderId)) continue;
        _syncInFlight.add(order.localOrderId);
        try {
          final host = RestaurantLanHostRegistry.current;
          final plan = planLanOrderSync(
            listeningHost: host != null &&
                host.listening &&
                host.restaurantId == restaurantId,
            printStatus: order.printStatus,
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
              isolatedEvidenceVerifierUri == null &&
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
          if (evidence != null && isolatedEvidenceVerifierUri != null) {
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
            suppressPhysicalPrint: plan.evidence == 'forwarded' ||
                plan.evidence == 'uncertain',
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
      final request = await client.postUrl(isolatedEvidenceVerifierUri!);
      request.headers.contentType = ContentType.json;
      final token = isolatedAccessToken?.trim() ?? '';
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.add(utf8.encode(jsonEncode(<String, dynamic>{
        ...params,
        'branch_id': branchId,
      })));
      final response = await request.close().timeout(const Duration(seconds: 8));
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
      final response = await request.close().timeout(const Duration(seconds: 8));
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

/// The listening owner host is the only sync identity. A forwarded or
/// uncertain local print is sent as evidence. `printed` is never treated as
/// a device acknowledgement.
LanOrderSyncPlan planLanOrderSync({
  required bool listeningHost,
  required String printStatus,
}) {
  if (!listeningHost) {
    return const LanOrderSyncPlan(
      action: 'hold',
      reason: 'Senkronizasyon yalnız açık yerel sunucudan yapılır.',
    );
  }
  final status = printStatus.trim();
  final evidence = switch (status) {
    'printed' || 'forwarded' => 'forwarded',
    'uncertain' => 'uncertain',
    'failed' => 'failed',
    _ => null,
  };
  return LanOrderSyncPlan(action: 'sync', evidence: evidence);
}

bool lanSyncErrorIsConflict(String text) {
  final lower = text.toLowerCase();
  return lower.contains('farklı içerik') ||
      lower.contains('doğrulanamadı') ||
      lower.contains('çakış');
}
