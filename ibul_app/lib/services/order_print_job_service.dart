import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mixed_service_order.dart';
import '../models/printer_model.dart';
import 'desktop_print_orchestrator.dart';
import 'kitchen_routing_service.dart';
import 'printer_event_log_service.dart';
import 'printer_repository.dart';

class OrderPrintJobDispatchResult {
  const OrderPrintJobDispatchResult({
    required this.orderId,
    required this.orderNumber,
    required this.printJobCount,
    required this.printJobIds,
    required this.raw,
    this.orderSavedAt = '',
    this.printJobCreatedAt = '',
    this.dispatchedJobCount = 0,
    this.failedJobCount = 0,
    this.traceId = '',
    this.pipelineStartedAt = '',
    this.printSystemEnabled = true,
    this.printSuppressedReason,
  });

  final String? orderId;
  final String? orderNumber;
  final int printJobCount;
  final List<String> printJobIds;
  final Map<String, dynamic> raw;
  final String orderSavedAt;
  final String printJobCreatedAt;
  final int dispatchedJobCount;
  final int failedJobCount;

  /// Unique trace ID for correlating logs across mobile → desktop → bridge.
  final String traceId;

  /// ISO-8601 timestamp when the pipeline started on the mobile device.
  final String pipelineStartedAt;
  final bool printSystemEnabled;
  final String? printSuppressedReason;
}

class OrderPrintJobRecoveryResult {
  const OrderPrintJobRecoveryResult({
    required this.pendingJobCount,
    required this.dispatchedJobCount,
    required this.failedJobCount,
    required this.attemptedJobIds,
  });

  final int pendingJobCount;
  final int dispatchedJobCount;
  final int failedJobCount;
  final List<String> attemptedJobIds;
}

class _KitchenPrintDispatchOutcome {
  const _KitchenPrintDispatchOutcome({
    required this.dispatchedJobCount,
    required this.failedJobCount,
    required this.failureMessages,
  });

  final int dispatchedJobCount;
  final int failedJobCount;
  final List<String> failureMessages;

  bool get hasFailures => failureMessages.isNotEmpty;
}

class OrderPrintJobService {
  OrderPrintJobService({
    SupabaseClient? client,
    KitchenRoutingService? routingService,
    PrinterRepository? printerRepository,
    DesktopPrintOrchestrator? printOrchestrator,
  }) : _clientOverride = client,
       _routingService = routingService ?? const KitchenRoutingService(),
       _printerRepositoryInstance = printerRepository,
       _printOrchestratorInstance = printOrchestrator;

  // Lazily resolve Supabase client so preview/widget tests can render without
  // initializing Supabase plugins.
  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;
  final KitchenRoutingService _routingService;
  PrinterRepository? _printerRepositoryInstance;
  PrinterRepository get _printerRepository =>
      _printerRepositoryInstance ??= PrinterRepository();
  DesktopPrintOrchestrator? _printOrchestratorInstance;
  DesktopPrintOrchestrator get _printOrchestrator =>
      _printOrchestratorInstance ??= DesktopPrintOrchestrator();
  final PrinterEventLogService _printerEventLogService =
      PrinterEventLogService();
  final Map<String, Map<String, dynamic>> _printerConfigCache =
      <String, Map<String, dynamic>>{};

  /// Generates a short trace ID for pipeline log correlation.
  static String _generateTraceId() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    // 8-char hex is sufficient for human-readable log correlation.
    return ms
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(
          ms.toRadixString(16).length > 8 ? ms.toRadixString(16).length - 8 : 0,
        );
  }

  Future<OrderPrintJobDispatchResult> dispatchNewOrder({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
    String jobType = 'new_order',
  }) async {
    final traceId = _generateTraceId();
    final pipelineStartedAt = DateTime.now().toIso8601String();
    final pipelineWatch = Stopwatch()..start();
    final normalized = _routingService
        .normalizeItems(items)
        .map((item) => item.toPayloadMap())
        .toList(growable: false);

    if (normalized.isEmpty) {
      throw Exception('Print job oluşturmak için sipariş kalemi bulunamadı.');
    }

    debugPrint(
      '[PrintPipeline] trace=$traceId stage=order_save_started '
      'at=$pipelineStartedAt '
      'restaurantId=$restaurantId tableNo=$tableNumber',
    );

    _logKitchen(
      'Init',
      'trace=$traceId restaurantId=$restaurantId tableNo=$tableNumber jobType=$jobType '
          'itemCount=${normalized.length} waiterId=${_logValue(waiterId)} '
          'waiterName=${_logValue(waiterName)}',
    );

    final rpcWatch = Stopwatch()..start();
    final response = await _runCreateTableOrderWithPrintJobsRpc(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      normalized: normalized,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      traceId: traceId,
      jobType: jobType,
    );
    final rpcMs = rpcWatch.elapsedMilliseconds;

    final data = response is Map<String, dynamic>
        ? response
        : (response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{});
    final printJobIds = _extractPrintJobIds(data['print_job_ids']);
    final orderSavedAt = _textValue(
      data['order_saved_at'],
      fallback: DateTime.now().toIso8601String(),
    );
    final printJobCreatedAt = _textValue(
      data['print_job_created_at'],
      fallback: DateTime.now().toIso8601String(),
    );

    debugPrint(
      '[PrintPipeline] trace=$traceId stage=print_job_created '
      'at=$printJobCreatedAt '
      'order_saved_at=$orderSavedAt '
      'orderId=${_logValue(data['order_id'])} '
      'rpcMs=$rpcMs pipelineMs=${pipelineWatch.elapsedMilliseconds} '
      'printJobCount=${(data['print_job_count'] as num?)?.toInt() ?? 0} '
      'printJobIds=${printJobIds.isEmpty ? '-' : printJobIds.join(",")}',
    );

    _logKitchen(
      'Fetch',
      'trace=$traceId restaurantId=$restaurantId tableNo=$tableNumber '
          'orderId=${_logValue(data['order_id'])} orderNo=${_logValue(data['order_number'])} '
          'printJobCount=${(data['print_job_count'] as num?)?.toInt() ?? 0} '
          'printJobIds=${printJobIds.isEmpty ? '-' : printJobIds.join(",")} '
          'rpcMs=$rpcMs',
    );
    for (final printJobId in printJobIds) {
      _printerEventLogService
          .append(
            restaurantId: restaurantId,
            event: 'job_created',
            message: 'Print job oluşturuldu.',
            jobId: printJobId,
            role: 'mutfak',
            details: <String, dynamic>{
              'traceId': traceId,
              'tableNumber': tableNumber,
              'jobType': jobType,
            },
          )
          .ignore();
      _printerEventLogService
          .append(
            restaurantId: restaurantId,
            event: 'kitchen_job_queued',
            message: 'Mutfak print job kuyruğa alındı.',
            jobId: printJobId,
            role: 'mutfak',
            details: <String, dynamic>{
              'traceId': traceId,
              'tableNumber': tableNumber,
              'jobType': jobType,
            },
          )
          .ignore();
    }

    final printSystemEnabled = await _fetchPrintSystemEnabled(restaurantId);
    if (!printSystemEnabled && printJobIds.isNotEmpty) {
      await _pausePrintJobs(
        printJobIds,
        reason: 'Baskı sistemi kapalı. Fiş yazdırılmadı.',
      );
      // Do NOT broadcast jobs when printing is disabled; we want these to stay paused.
    } else if (!_canDirectDispatch && printJobIds.isNotEmpty) {
      // On mobile (iOS/Android), send a Supabase Realtime broadcast to
    // notify the desktop hub INSTANTLY about new print jobs.
    // This bypasses postgres_changes WAL latency (1-5s → <200ms).
      _broadcastPrintJobsReady(restaurantId, printJobIds).ignore();
    }

    final dispatchOutcome = await _dispatchCreatedPrintJobs(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      orderId: data['order_id']?.toString(),
      printJobIds: printJobIds,
      sourceItems: items,
    );

    if (dispatchOutcome.hasFailures) {
      throw Exception(dispatchOutcome.failureMessages.join(' | '));
    }

    return OrderPrintJobDispatchResult(
      orderId: data['order_id']?.toString(),
      orderNumber: data['order_number']?.toString(),
      printJobCount: (data['print_job_count'] as num?)?.toInt() ?? 0,
      printJobIds: printJobIds,
      raw: data,
      orderSavedAt: orderSavedAt,
      printJobCreatedAt: printJobCreatedAt,
      dispatchedJobCount: dispatchOutcome.dispatchedJobCount,
      failedJobCount: dispatchOutcome.failedJobCount,
      traceId: traceId,
      pipelineStartedAt: pipelineStartedAt,
      printSystemEnabled: printSystemEnabled,
      printSuppressedReason:
          printSystemEnabled ? null : 'print_system_disabled',
    );
  }

  Future<bool> _fetchPrintSystemEnabled(String restaurantId) async {
    try {
      final dynamic rows = await _client
          .from('restaurant_print_station_configs')
          .select('print_system_enabled')
          .eq('restaurant_id', restaurantId)
          .limit(1);
      final list = rows is List ? rows : const <dynamic>[];
      final first = list.isNotEmpty ? list.first : null;
      final map = first is Map ? Map<String, dynamic>.from(first) : null;
      final enabled = map?['print_system_enabled'];
      return enabled is bool ? enabled : true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _pausePrintJobs(
    List<String> jobIds, {
    required String reason,
  }) async {
    if (jobIds.isEmpty) return;
    try {
      await _client
          .from('print_jobs')
          .update({
            'status': 'paused_by_operator',
            'last_error': reason,
          })
          .inFilter('id', jobIds)
          .eq('status', 'pending');
    } catch (_) {
      // Best-effort: do not block order save flow.
    }
  }

  Future<OrderPrintJobDispatchResult> dispatchAddItem({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
  }) {
    return dispatchNewOrder(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      items: items,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      jobType: 'add_item',
    );
  }

  Future<OrderPrintJobDispatchResult> dispatchCancelItem({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
  }) {
    return dispatchNewOrder(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      items: items,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      jobType: 'cancel_item',
    );
  }

  Future<OrderPrintJobDispatchResult> dispatchReprint({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
  }) {
    return dispatchNewOrder(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      items: items,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      jobType: 'reprint',
    );
  }

  Future<void> retryPrintJob({
    required String restaurantId,
    required String printJobId,
  }) async {
    await _client
        .from('print_jobs')
        .update({'status': 'pending', 'last_error': null, 'printed_at': null})
        .eq('id', printJobId);

    final outcome = await _dispatchCreatedPrintJobs(
      restaurantId: restaurantId,
      tableNumber: 0,
      orderId: null,
      printJobIds: <String>[printJobId],
    );
    if (outcome.hasFailures) {
      throw Exception(outcome.failureMessages.join(' | '));
    }
  }

  Future<OrderPrintJobDispatchResult> dispatchNewOrderFromTableOrder({
    required String tableOrderId,
    String? waiterName,
  }) async {
    final row = await _client
        .from('table_orders')
        .select('id, seller_id, table_number, items')
        .eq('id', tableOrderId)
        .single();
    final map = Map<String, dynamic>.from(row as Map);
    final sellerId = map['seller_id']?.toString() ?? '';
    final tableNumber = (map['table_number'] as num?)?.toInt() ?? 0;
    final rawItems = map['items'] is List
        ? List<Map<String, dynamic>>.from(
            (map['items'] as List).whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          )
        : <Map<String, dynamic>>[];

    if (sellerId.isEmpty || tableNumber <= 0) {
      throw Exception('table_orders kaydı print routing için uygun değil.');
    }

    return dispatchNewOrder(
      restaurantId: sellerId,
      tableNumber: tableNumber,
      items: rawItems,
      waiterName: waiterName,
    );
  }

  String? safeUserDisplayName(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    final fromDisplayName = metadata?['display_name']?.toString().trim();
    if (fromDisplayName != null && fromDisplayName.isNotEmpty) {
      return fromDisplayName;
    }
    final fromName = metadata?['name']?.toString().trim();
    if (fromName != null && fromName.isNotEmpty) {
      return fromName;
    }
    return user.email;
  }

  void debugLogResult(OrderPrintJobDispatchResult result) {
    debugPrint(
      'OrderPrintJobService: order=${result.orderId} '
      'orderSavedAt=${result.orderSavedAt.isEmpty ? '-' : result.orderSavedAt} '
      'printJobCreatedAt=${result.printJobCreatedAt.isEmpty ? '-' : result.printJobCreatedAt} '
      'printJobs=${result.printJobCount} '
      'printJobIds=${result.printJobIds.isEmpty ? '-' : result.printJobIds.join(",")} '
      'printed=${result.dispatchedJobCount} '
      'failed=${result.failedJobCount}',
    );
  }

  Future<OrderPrintJobRecoveryResult> recoverPendingJobs({
    required String restaurantId,
    int limit = 20,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    if (normalizedRestaurantId.isEmpty || !_canDirectDispatch) {
      return const OrderPrintJobRecoveryResult(
        pendingJobCount: 0,
        dispatchedJobCount: 0,
        failedJobCount: 0,
        attemptedJobIds: <String>[],
      );
    }

    final rows = await _client
        .from('print_jobs')
        .select('id')
        .eq('restaurant_id', normalizedRestaurantId)
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(limit);
    final pendingJobIds = List<Map<String, dynamic>>.from(rows as List)
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (pendingJobIds.isEmpty) {
      return const OrderPrintJobRecoveryResult(
        pendingJobCount: 0,
        dispatchedJobCount: 0,
        failedJobCount: 0,
        attemptedJobIds: <String>[],
      );
    }

    _logKitchen(
      'Recovery',
      'restaurantId=$normalizedRestaurantId pendingJobCount=${pendingJobIds.length} '
          'jobIds=${pendingJobIds.join(",")}',
    );

    final outcome = await _dispatchCreatedPrintJobs(
      restaurantId: normalizedRestaurantId,
      tableNumber: 0,
      orderId: null,
      printJobIds: pendingJobIds,
    );

    return OrderPrintJobRecoveryResult(
      pendingJobCount: pendingJobIds.length,
      dispatchedJobCount: outcome.dispatchedJobCount,
      failedJobCount: outcome.failedJobCount,
      attemptedJobIds: pendingJobIds,
    );
  }

  Future<dynamic> _runCreateTableOrderWithPrintJobsRpc({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> normalized,
    required String? waiterId,
    required String? waiterName,
    required String? notes,
    required String traceId,
    required String jobType,
  }) async {
    try {
      return await _client.rpc(
        'create_table_order_with_print_jobs',
        params: {
          'p_restaurant_id': restaurantId,
          'p_table_number': tableNumber,
          'p_items': normalized,
          'p_waiter_id':
              (waiterId == null || waiterId.isEmpty) ? null : waiterId,
          'p_waiter_name': waiterName,
          'p_notes':
              '$traceId${notes != null && notes.isNotEmpty ? ' $notes' : ''}',
          'p_job_type': jobType,
          'p_order_type': 'table',
        },
      );
    } on PostgrestException catch (error) {
      throw Exception(_friendlyDispatchRpcError(error));
    }
  }

  String _friendlyDispatchRpcError(PostgrestException error) {
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    if (details.contains('column "table_number" of relation "orders" does not exist') ||
        details.contains('orders') && details.contains('table_number') && details.contains('does not exist')) {
      return 'Mutfak fişi oluşturulamadı. Supabase orders tablosunda table_number kolonu yok '
          'ama mutfak print RPC onu yazmaya çalışıyor. SQL patch uygulanmalı '
          '(create_table_order_with_print_jobs_impl).';
    }
    if (details.contains('missing from-clause entry for table \"v_item\"') ||
        details.contains('missing from-clause entry for table "v_item"')) {
      return 'Mutfak fişi oluşturulamadı. SQL mutfak payload fonksiyonunda v_item '
          'alias hatası var. (Supabase RPC: create_table_order_with_print_jobs)';
    }
    if (error.code == '42501' ||
        details.contains('permission denied') ||
        details.contains('bu restoran için işlem yetkiniz yok') ||
        details.contains('row-level security')) {
      return 'Mutfak fişi oluşturulamadı. Garson hesabının bu restoranda aktif '
          'yazdırma yetkisi yok. Supabase tarafında store_sub_admins kaydında '
          'email veya telefon eşleşmesi gerekli.';
    }
    return error.message;
  }

  Future<_KitchenPrintDispatchOutcome> _dispatchCreatedPrintJobs({
    required String restaurantId,
    required int tableNumber,
    required String? orderId,
    required List<String> printJobIds,
    List<Map<String, dynamic>>? sourceItems,
  }) async {
    if (printJobIds.isEmpty) {
      return const _KitchenPrintDispatchOutcome(
        dispatchedJobCount: 0,
        failedJobCount: 0,
        failureMessages: <String>[],
      );
    }

    // Desktop platforms (web, macOS, Windows, Linux) can reach the local bridge
    // at 127.0.0.1:3001 directly.  Mobile platforms (iOS, Android) cannot —
    // on mobile, pending jobs are expected to be picked up by DesktopPrintHub
    // on the restaurant's desktop computer via Supabase realtime INSERT events.
    if (!_canDirectDispatch) {
      _logKitchen(
        'Dispatch',
        'restaurantId=$restaurantId tableNo=$tableNumber '
            'orderId=${_logValue(orderId)} platform=mobile action=skip_local_dispatch '
            'printJobCount=${printJobIds.length}',
      );
      return const _KitchenPrintDispatchOutcome(
        dispatchedJobCount: 0,
        failedJobCount: 0,
        failureMessages: <String>[],
      );
    }

    final jobs = await _fetchPrintJobsByIds(printJobIds);
    final jobsById = <String, Map<String, dynamic>>{
      for (final job in jobs) job['id']?.toString() ?? '': job,
    };

    _logKitchen(
      'Fetch',
      'restaurantId=$restaurantId tableNo=$tableNumber '
          'orderId=${_logValue(orderId)} fetchedJobCount=${jobs.length}',
    );

    var dispatchedJobCount = 0;
    var failedJobCount = 0;
    final failureMessages = <String>[];

    for (final printJobId in printJobIds) {
      final job = jobsById[printJobId];
      if (job == null) {
        failedJobCount += 1;
        failureMessages.add('Print job bulunamadı: $printJobId');
        _logKitchen(
          'Error',
          'restaurantId=$restaurantId tableNo=$tableNumber '
              'orderId=${_logValue(orderId)} printJobId=$printJobId '
              'exception=print_job_missing',
        );
        continue;
      }

      final payload = await _payloadWithPrinterConfig(job);
      final area = _textValue(
        payload['station_name'] ?? payload['area_name'],
        fallback: 'Genel',
      );
      final printerId = _textValue(
        job['printer_id'] ?? payload['printer_id'],
        fallback: '-',
      );
      final printerName = _textValue(
        payload['printer_name'],
        fallback: 'Yerel Yazici',
      );
      final effectiveEncoding = _textValue(
        payload['printer_encoding'] ?? payload['encoding'],
        fallback: '-',
      );
      final effectiveCodePage = _textValue(
        payload['printer_code_page'] ??
            payload['printer_codepage'] ??
            payload['code_page'] ??
            payload['codepage'],
        fallback: '-',
      );

      // Validate payload config before dispatch so misconfigurations are
      // visible in logs rather than silently producing wrong behaviour.
      _warnPayloadConfig(payload, printJobId: printJobId);

      final itemCount = _payloadItems(payload).length;
      final tableNo = _resolveTableNo(
        payload,
        fallbackTableNumber: tableNumber,
      );
      final itemAreaMap = _itemAreaMapping(area, payload);

      _logKitchen(
        'Mapping',
        'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
            'printerId=$printerId printerName=$printerName itemCount=$itemCount '
            'jobType=${_textValue(job['job_type'] ?? payload['job_type'], fallback: '-')} '
            'printerRoles=${_printerRolesLog(payload)} '
            'itemAreaMap=$itemAreaMap '
            'encoding=$effectiveEncoding codePage=$effectiveCodePage',
      );

      // Atomically claim this job before attempting HTTP dispatch.
      // This prevents a race with DesktopPrintHub: if the hub has already
      // claimed the job (status ≠ 'pending'), skip direct dispatch here.
      final claimed = await _tryAtomicClaim(printJobId);
      if (!claimed) {
        _logKitchen(
          'Dispatch',
          'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'printerId=$printerId printerName=$printerName phase=skipped_hub_claimed',
        );
        dispatchedJobCount += 1; // hub owns it — count as dispatched
        continue;
      }

      final watch = Stopwatch()..start();
      var requestUrl = 'http://127.0.0.1:3001/print/kitchen';
      try {
        final kitchenPayload = _buildKitchenPayload(
          job: job,
          payload: payload,
          fallbackTableNumber: tableNumber,
          sourceItems: sourceItems,
        );
        final preparedPayload = await _printOrchestrator.prepareQueuedPrintPayload(
          restaurantId: restaurantId,
          jobRecord: job,
          payload: kitchenPayload,
        );
        final resolvedPrinter = preparedPayload.printer;
        final resolvedPayload = preparedPayload.payload;
        final requestPath = _resolvePrinterRoute(resolvedPayload);
        final baseUri = _resolvePrinterBaseUri(resolvedPayload);
        requestUrl = baseUri.replace(path: requestPath).toString();
        final builtItemCount = (kitchenPayload['items'] as List?)?.length ?? 0;
        _logKitchen(
          'Dispatch',
          'route=$requestPath orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'payloadItemCount=$builtItemCount '
              'sourceItemCount=${sourceItems?.length ?? 0} '
              'payloadJobItemCount=${_payloadItems(payload).length} '
              '${builtItemCount == 0 ? 'WARN=EMPTY_ITEMS_PAYLOAD' : 'items_ok'} '
              'phase=payload_built '
              'resolutionSource=${preparedPayload.resolutionSource} '
              'resolvedPrinter=${resolvedPrinter?.id ?? '-'} '
              'resolvedRecordId=${resolvedPrinter?.printerRecordId ?? '-'}',
        );
        if (resolvedPrinter == null) {
          failedJobCount += 1;
          failureMessages.add('$area/$printerName: printer_not_found');
          await _markPrintJobFailed(
            printJobId,
            requestUrl: requestUrl,
            error: 'printer_not_found',
          );
          continue;
        }
        final dispatchStartedAt = DateTime.now();
        await _markPrintJobPrinting(
          printJobId,
          dispatchStartedAt: dispatchStartedAt,
        );
        final physicalResult = await _printOrchestrator.printPhysicalToPrinter(
          resolvedPrinter,
          PrintPayload.fromQueuedJob(resolvedPayload),
          restaurantId: restaurantId,
        );
        if (!physicalResult.ok) {
          final failureMessage =
              physicalResult.technicalMessage ?? physicalResult.message;
          if (_isConnectionError(
            Exception(physicalResult.technicalMessage ?? physicalResult.message),
          )) {
            await _resetPrintJobToPending(
              printJobId,
              requestUrl: requestUrl,
              error: failureMessage,
            );
            dispatchedJobCount += 1;
            _logKitchen(
              'Dispatch',
              'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
                  'printerId=${resolvedPrinter.id} printerName=${resolvedPrinter.displayName} '
                  'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl '
                  'phase=reset_pending_for_hub error=$failureMessage',
            );
            continue;
          }
          failedJobCount += 1;
          failureMessages.add('$area/$printerName: $failureMessage');
          await _markPrintJobFailed(
            printJobId,
            requestUrl: requestUrl,
            error: failureMessage,
          );
          _logKitchen(
            'Error',
            'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
                'printerId=${resolvedPrinter.id} printerName=${resolvedPrinter.displayName} itemCount=$itemCount '
                'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl '
                'resolutionSource=${preparedPayload.resolutionSource}',
            error: Exception(failureMessage),
          );
          continue;
        }
        final bridgeResult = physicalResult.raw;
        await _markPrintJobCompleted(
          printJobId,
          completedAt: DateTime.now(),
          bridgeResult: bridgeResult,
        );
        dispatchedJobCount += 1;
        _logKitchen(
          'Dispatch',
          'route=$requestPath orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'printerId=$printerId printerName=$printerName itemCount=$itemCount '
              'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl phase=success',
        );
      } catch (error, stackTrace) {
        final failureMessage = _compactError(error);
        if (_isConnectionError(error)) {
          // Bridge unreachable from this device (e.g. garson on a tablet,
          // bridge running on the restaurant’s desktop). Reset to 'pending'
          // so DesktopPrintHub can dispatch it when the UPDATE listener fires.
          await _resetPrintJobToPending(
            printJobId,
            requestUrl: requestUrl,
            error: failureMessage,
          );
          dispatchedJobCount += 1; // pending for hub retry — not a hard failure
          _logKitchen(
            'Dispatch',
            'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
                'printerId=$printerId printerName=$printerName '
                'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl '
                'phase=reset_pending_for_hub error=$failureMessage',
          );
        } else {
          // Payload or HTTP-application error — mark as failed.
          failedJobCount += 1;
          failureMessages.add('$area/$printerName: $failureMessage');
          await _markPrintJobFailed(
            printJobId,
            requestUrl: requestUrl,
            error: failureMessage,
          );
          _logKitchen(
            'Error',
            'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
                'printerId=$printerId printerName=$printerName itemCount=$itemCount '
                'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    return _KitchenPrintDispatchOutcome(
      dispatchedJobCount: dispatchedJobCount,
      failedJobCount: failedJobCount,
      failureMessages: failureMessages,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPrintJobsByIds(
    List<String> printJobIds,
  ) async {
    if (printJobIds.isEmpty) return const <Map<String, dynamic>>[];
    final rows = await _client
        .from('print_jobs')
        .select(
          'id, restaurant_id, order_id, station_id, printer_id, job_type, payload, status',
        )
        .inFilter('id', printJobIds);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Future<void> _markPrintJobPrinting(
    String printJobId, {
    required DateTime dispatchStartedAt,
  }) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'printing',
          'last_error': null,
          'dispatch_started_at': dispatchStartedAt.toIso8601String(),
        })
        .eq('id', printJobId)
        .inFilter('status', ['claimed', 'pending']);
  }

  Future<void> _markPrintJobCompleted(
    String printJobId, {
    required DateTime completedAt,
    Map<String, dynamic>? bridgeResult,
  }) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'completed',
          'last_error': null,
          'printed_at': completedAt.toIso8601String(),
          'completed_at': completedAt.toIso8601String(),
          'printer_write_started_at': bridgeResult?['printer_write_started_at'],
          'printer_write_completed_at':
              bridgeResult?['printer_write_completed_at'],
        })
        .eq('id', printJobId);
  }

  Future<void> _markPrintJobFailed(
    String printJobId, {
    required String requestUrl,
    required String error,
  }) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'failed',
          'last_error': 'requestUrl=$requestUrl error=$error',
          'printed_at': null,
        })
        .eq('id', printJobId);
  }

  /// Atomically claim a print job for direct HTTP dispatch.
  ///
  /// Mirrors [DesktopPrintHub._claimJob]: flips `status: pending → claimed`
  /// in a single conditional UPDATE so only one process owns the job.
  /// Returns `true` when the claim succeeded (this process owns the job).
  Future<bool> _tryAtomicClaim(String printJobId) async {
    try {
      final now = DateTime.now();
      final rows = await _client
          .from('print_jobs')
          .update({
            'status': 'claimed',
            'last_error': null,
            'claimed_at': now.toIso8601String(),
          })
          .eq('id', printJobId)
          .eq('status', 'pending')
          .select('id');
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Print jobs are now always consumed by the centralized Print Station bridge.
  // The Seller Panel should only enqueue jobs; it must not assume the current
  // browser device can reach a locally-attached printer.
  bool get _canDirectDispatch => false;

  /// Returns `true` when [error] is a network/transport-level failure (not an
  /// HTTP-application or payload error). Jobs that fail with a connection error
  /// are reset to `pending` so [DesktopPrintHub] can recover them via its
  /// UPDATE realtime listener rather than being permanently marked `failed`.
  bool _isConnectionError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('connection refused') ||
        raw.contains('connection_error') ||
        raw.contains('connection reset') ||
        raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('timeout');
  }

  /// Reset a print job back to `pending` after a connection-level failure so
  /// that [DesktopPrintHub] can dispatch it when the UPDATE event fires.
  Future<void> _resetPrintJobToPending(
    String printJobId, {
    required String requestUrl,
    required String error,
  }) async {
    try {
      await _client
          .from('print_jobs')
          .update({
            'status': 'pending',
            'last_error':
                'direct_dispatch_failed requestUrl=$requestUrl error=$error — queued for hub retry',
          })
          .eq('id', printJobId);
    } catch (e) {
      debugPrint('[PrintJob] _resetPrintJobToPending failed: $e');
    }
  }

  Map<String, dynamic> _buildKitchenPayload({
    required Map<String, dynamic> job,
    required Map<String, dynamic> payload,
    required int fallbackTableNumber,
    List<Map<String, dynamic>>? sourceItems,
  }) {
    final orderId = _textValue(job['order_id'] ?? payload['order_id']);
    final tableNo = _resolveTableNo(
      payload,
      fallbackTableNumber: fallbackTableNumber,
    );
    final area = _textValue(
      payload['station_name'] ?? payload['area_name'],
      fallback: 'Genel',
    );
    final stationId = _textValue(job['station_id'] ?? payload['station_id']);

    // ── Item source selection ────────────────────────────────────────────────
    // ROOT-CAUSE FIX: when a print job has a non-null stationId, the SQL RPC
    // already pre-filtered the items for that station in the job payload.
    // Using sourceItems (Flutter draft) with station-matching is unreliable
    // because:
    //   1. The SQL may enrich station_id from the products table even when the
    //      Flutter-side draft item had station_id=null (stale or first-load).
    //   2. retryPrintJob() never passes sourceItems, so station-matching would
    //      always drop every payload item → empty kitchen ticket.
    //
    // Strategy:
    //   • stationId non-empty → use payload items (pre-filtered by SQL, correct).
    //   • stationId empty    → prefer sourceItems (richer: notes, amount_label,
    //     service children) then fall back to payload items.
    //
    // In both cases, if the chosen list produces zero items after processing,
    // we fall back to payload items as a safety net so the ticket is never
    // silently empty when data actually exists in the DB.

    final payloadItems = _payloadItems(payload);
    final hasSourceItems = sourceItems != null && sourceItems.isNotEmpty;
    final hasPayloadItems = payloadItems.isNotEmpty;

    final List<Map<String, dynamic>> rawItems;
    final String itemSourceLabel;
    if (stationId.isNotEmpty) {
      // Station-assigned job: trust the DB pre-grouping.
      if (hasPayloadItems) {
        rawItems = payloadItems;
        itemSourceLabel = 'print_job_payload_station';
      } else if (hasSourceItems) {
        rawItems = sourceItems;
        itemSourceLabel = 'source_items_station_fallback';
      } else {
        rawItems = const [];
        itemSourceLabel = 'empty_no_source';
      }
    } else {
      // Null-station job: prefer sourceItems for richer data.
      if (hasSourceItems) {
        rawItems = sourceItems;
        itemSourceLabel = 'source_items_null_station';
      } else {
        rawItems = payloadItems;
        itemSourceLabel = 'print_job_payload_null_station';
      }
    }

    final originalItemCount = rawItems.length;

    _logKitchen(
      'Payload',
      'buildStart orderId=$orderId tableNo=$tableNo area=$area '
          'stationId=${stationId.isEmpty ? '<null>' : stationId} '
          'originalItemCount=$originalItemCount itemSource=$itemSourceLabel '
          'hasSourceItems=$hasSourceItems hasPayloadItems=$hasPayloadItems',
    );

    final items = <Map<String, dynamic>>[];
    final serviceItemIds = <String>{};
    var droppedItemCount = 0;
    var plateCount = 0;

    // When the item source is pre-filtered payload items (stationId non-empty),
    // skip station-matching — the DB already did it correctly.
    final skipStationFilter =
        stationId.isNotEmpty && itemSourceLabel.startsWith('print_job_payload');

    // Build a name→sourceItem lookup for gramaj enrichment when using DB
    // payload items (which have no amount_label/gramaj stored).
    final sourceItemByName = <String, Map<String, dynamic>>{};
    if (skipStationFilter && sourceItems != null) {
      for (final si in sourceItems) {
        final siName = _textValue(
          si['name'] ?? si['item_name'] ?? si['product_name'],
          fallback: '',
        );
        if (siName.isNotEmpty) {
          sourceItemByName[siName.toLowerCase()] = si;
        }
      }
    }

    for (final rawItem in rawItems) {
      var normalized = _normalizeKitchenSourceItem(rawItem);
      // Enrich amount_label AND structured plate/child data from sourceItems
      // when using DB payload items (station-specific job, skipStationFilter=true).
      // DB payload stores only {order_item_id, product_name, quantity, item_note,
      // unit_price}.  Before the SQL fix is deployed and for older print jobs,
      // plates/service_children may be absent; we rebuild them from sourceItems.
      if (skipStationFilter && sourceItemByName.isNotEmpty) {
        final nameKey = _textValue(
          normalized['item_name'] ?? normalized['name'],
          fallback: '',
        ).toLowerCase();
        final match = sourceItemByName[nameKey];
        if (match != null) {
          final enriched = Map<String, dynamic>.from(normalized);
          // amount_label
          final sourceAmountLabel = _textValue(
            match['amount_label'] ?? match['gramaj'] ?? match['amountLabel'],
            fallback: '',
          );
          if (sourceAmountLabel.isNotEmpty &&
              _textValue(
                enriched['amount_label'] ?? enriched['gramaj'],
                fallback: '',
              ).isEmpty) {
            enriched['amount_label'] = sourceAmountLabel;
            enriched['gramaj'] = sourceAmountLabel;
          }
          // plates / service_children — rebuild from the source item's
          // child_items so the station ticket shows full plate details.
          final hasMissingStructure =
              (normalized['plates'] as List?)?.isEmpty ?? true;
          if (hasMissingStructure) {
            final normalizedSource = _normalizeKitchenSourceItem(match);
            final builtPlates = MixedServiceOrder.buildKitchenPlates(
              normalizedSource,
            );
            if (builtPlates.isNotEmpty) {
              enriched['plates'] = builtPlates;
            } else {
              final builtChildren =
                  MixedServiceOrder.buildKitchenServiceChildren(
                    normalizedSource,
                  );
              if (builtChildren.isNotEmpty) {
                enriched['service_children'] = builtChildren;
              }
            }
          }
          normalized = enriched;
        }
      }
      final itemId = _kitchenItemId(normalized);
      final itemName = _kitchenItemName(normalized);

      if (!skipStationFilter) {
        final parentMatches = _matchesStation(
          normalized['station_id'],
          stationId,
        );
        final children = MixedServiceOrder.normalizeChildItems(
          normalized['child_items'],
        );
        final hasMatchingChild = children.any(
          (child) => _matchesKitchenChildStation(
            childStationId: child['station_id'],
            targetStationId: stationId,
            parentMatches: parentMatches,
          ),
        );

        if (!parentMatches && !hasMatchingChild) {
          droppedItemCount += 1;
          _logKitchen(
            'Payload',
            'missingItems orderId=$orderId tableNo=$tableNo area=$area '
                'itemId=$itemId itemName=$itemName reason=station_mismatch '
                'targetStationId=$stationId itemStationId=${_textValue(normalized['station_id'], fallback: '-')} '
                'itemSource=$itemSourceLabel',
          );
          continue;
        }
      }

      final kitchenItem = _buildKitchenItemPayload(
        normalized,
        orderId: orderId,
        tableNo: tableNo,
        area: area,
        targetStationId: skipStationFilter ? '' : stationId,
      );
      if (kitchenItem == null) {
        droppedItemCount += 1;
        _logKitchen(
          'Payload',
          'missingItems orderId=$orderId tableNo=$tableNo area=$area '
              'itemId=$itemId itemName=$itemName reason=empty_after_filter '
              'itemSource=$itemSourceLabel',
        );
        continue;
      }

      final plates = kitchenItem['plates'];
      if (plates is List) {
        plateCount += plates.length;
      }
      if (_isKitchenServiceItem(kitchenItem)) {
        serviceItemIds.add(itemId);
      }
      items.add(kitchenItem);
    }

    // Safety-net fallback: if the chosen source produced zero printable items
    // but the DB payload has items, retry with payload items so the ticket is
    // never silently blank when data exists.
    if (items.isEmpty && !skipStationFilter && hasPayloadItems) {
      _logKitchen(
        'Payload',
        'emptyItemsFallback orderId=$orderId tableNo=$tableNo area=$area '
            'originalSource=$itemSourceLabel '
            'WARN=source_items_all_filtered retrying_with_print_job_payload '
            'payloadItemCount=${payloadItems.length}',
      );
      for (final rawItem in payloadItems) {
        final normalized = _normalizeKitchenSourceItem(rawItem);
        final itemId = _kitchenItemId(normalized);
        final itemName = _kitchenItemName(normalized);
        final kitchenItem = _buildKitchenItemPayload(
          normalized,
          orderId: orderId,
          tableNo: tableNo,
          area: area,
          targetStationId: '',
        );
        if (kitchenItem == null) {
          _logKitchen(
            'Payload',
            'emptyItemsFallback missingItem orderId=$orderId itemId=$itemId '
                'itemName=$itemName reason=null_after_rebuild',
          );
          continue;
        }
        final plates = kitchenItem['plates'];
        if (plates is List) {
          plateCount += plates.length;
        }
        if (_isKitchenServiceItem(kitchenItem)) {
          serviceItemIds.add(itemId);
        }
        items.add(kitchenItem);
      }
    }

    if (items.isEmpty) {
      _logKitchen(
        'Payload',
        'WARN_EMPTY_ITEMS orderId=$orderId tableNo=$tableNo area=$area '
            'originalItemCount=$originalItemCount droppedItemCount=$droppedItemCount '
            'itemSource=$itemSourceLabel stationId=${stationId.isEmpty ? '<null>' : stationId} '
            'payloadItemCount=${payloadItems.length} '
            'sourceItemCount=${sourceItems?.length ?? 0} '
            'ACTION=kitchen_ticket_will_print_with_no_items',
      );
    }

    _logKitchen(
      'Payload',
      'buildSuccess orderId=$orderId tableNo=$tableNo area=$area '
          'originalItemCount=$originalItemCount printedItemCount=${items.length} '
          'droppedItemCount=$droppedItemCount serviceItemIds=${serviceItemIds.isEmpty ? '-' : serviceItemIds.join(",")} '
          'plateCount=$plateCount itemSource=$itemSourceLabel',
    );

    return <String, dynamic>{
      'title': 'MUTFAK SIPARISI',
      'store_name': _textValue(
        payload['restaurant_name'] ?? payload['store_name'],
        fallback: 'Restoran',
      ),
      'order_id': orderId,
      'order_no': _textValue(
        payload['order_no'] ?? payload['order_number'],
        fallback: '-',
      ),
      'table_no': tableNo,
      'table_name': _textValue(
        payload['display_table_label'] ??
            payload['table_display_name'] ??
            payload['table_name'],
        fallback: 'Masa $fallbackTableNumber',
      ),
      'table_number': fallbackTableNumber,
      'display_table_label': _textValue(
        payload['display_table_label'] ??
            payload['table_display_name'] ??
            payload['table_name'],
        fallback: '',
      ),
      'table_display_name': _textValue(
        payload['table_display_name'] ??
            payload['display_table_label'] ??
            payload['table_name'],
        fallback: '',
      ),
      'table_area_name': _textValue(
        payload['table_area_name'] ?? payload['area_name'],
        fallback: '',
      ),
      'area_name': area,
      'waiter_name': _textValue(payload['waiter_name'], fallback: '-'),
      'job_type': _textValue(job['job_type'] ?? payload['job_type']),
      'datetime': _textValue(
        payload['created_at'],
        fallback: DateTime.now().toIso8601String(),
      ),
      'printer_id': _textValue(job['printer_id'] ?? payload['printer_id']),
      'printer_name': _textValue(payload['printer_name']),
      'printer_encoding': _textValue(
        payload['printer_encoding'] ?? payload['encoding'],
      ),
      'printer_code_page': _intValue(
        payload['printer_code_page'] ??
            payload['printer_codepage'] ??
            payload['code_page'] ??
            payload['codepage'],
        fallback: 13,
      ),
      'render_mode': 'image',
      'items': items,
    };
  }

  Map<String, dynamic> _normalizeKitchenSourceItem(Map<String, dynamic> item) {
    final normalized = MixedServiceOrder.normalizeOrderItem(<String, dynamic>{
      'product_id':
          item['product_id'] ?? item['order_item_id'] ?? item['productId'],
      'name': item['name'] ?? item['product_name'] ?? item['item_name'],
      'item_name': item['item_name'] ?? item['name'] ?? item['product_name'],
      'quantity': _intValue(item['quantity'], fallback: 1),
      'gramaj': item['gramaj'],
      'amount_label': item['amount_label'],
      'note': item['note'] ?? item['item_note'] ?? item['notes'],
      'notes': item['notes'] ?? item['item_note'] ?? item['note'],
      'general_note':
          item['general_note'] ??
          item['item_note'] ??
          item['note'] ??
          item['notes'],
      'station_id': item['station_id'] ?? item['stationId'],
      'item_type': item['item_type'],
      'product_type': item['product_type'] ?? item['source_product_type'],
      'child_items': item['child_items'],
      'service_round_count': item['service_round_count'] ?? item['plate_count'],
      'plate_count': item['plate_count'] ?? item['service_round_count'],
      'attributes': item['attributes'],
    });
    // Carry pre-built structured plates/service_children from DB-persisted
    // payload items.  normalizeOrderItem does not know these fields so we
    // layer them on top after normalisation.
    final preBuiltPlates = item['plates'];
    final preBuiltServiceChildren = item['service_children'];
    if ((preBuiltPlates is List && preBuiltPlates.isNotEmpty) ||
        (preBuiltServiceChildren is List &&
            preBuiltServiceChildren.isNotEmpty)) {
      final enriched = <String, dynamic>{...normalized};
      if (preBuiltPlates is List && preBuiltPlates.isNotEmpty) {
        enriched['plates'] = preBuiltPlates;
      }
      if (preBuiltServiceChildren is List &&
          preBuiltServiceChildren.isNotEmpty) {
        enriched['service_children'] = preBuiltServiceChildren;
      }
      return enriched;
    }
    return normalized;
  }

  Map<String, dynamic>? _buildKitchenItemPayload(
    Map<String, dynamic> item, {
    required String orderId,
    required String tableNo,
    required String area,
    required String targetStationId,
  }) {
    final itemId = _kitchenItemId(item);
    final itemName = _kitchenItemName(item);
    final parentMatches = _matchesStation(item['station_id'], targetStationId);
    final children = MixedServiceOrder.normalizeChildItems(item['child_items']);
    final filteredChildren = <Map<String, dynamic>>[];

    for (final child in children) {
      final matchesChild = _matchesKitchenChildStation(
        childStationId: child['station_id'],
        targetStationId: targetStationId,
        parentMatches: parentMatches,
      );
      if (!matchesChild) {
        _logKitchen(
          'Payload',
          'missingItems orderId=$orderId tableNo=$tableNo area=$area '
              'itemId=$itemId itemName=$itemName reason=child_station_mismatch '
              'childItemId=${_kitchenItemId(child)} childName=${_kitchenItemName(child)} '
              'targetStationId=${targetStationId.isEmpty ? '-' : targetStationId} '
              'childStationId=${_textValue(child['station_id'], fallback: '-')}',
        );
        continue;
      }
      filteredChildren.add(child);
    }

    if (targetStationId.isNotEmpty &&
        !parentMatches &&
        filteredChildren.isEmpty &&
        children.isNotEmpty) {
      return null;
    }

    final kitchenItem = <String, dynamic>{
      'id': itemId,
      'name': itemName,
      'quantity': _intValue(item['quantity'], fallback: 1),
    };
    final amountLabel = _textValue(
      item['amount_label'] ?? item['gramaj'],
      fallback: '',
    );
    final textNote = _textValue(
      item['general_note'] ?? item['note'] ?? item['notes'],
      fallback: '',
    );
    final attrs =
        (item['attributes'] as List?)
            ?.whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    // Merge note + attrs into a single "Not: ..." string.
    // The renderer prefixes with "Not: " so no label is needed here.
    final noteParts = <String>[if (textNote.isNotEmpty) textNote, ...attrs];
    final note = noteParts.join(', ');
    if (amountLabel.isNotEmpty) {
      kitchenItem['amount_label'] = amountLabel;
    }
    if (note.isNotEmpty) {
      kitchenItem['note'] = note;
    }

    if (filteredChildren.isEmpty) {
      // Use pre-built plates/service_children stored in the DB payload
      // (written by KitchenRoutingItem.toPayloadMap).  These survive reprints
      // because child_items is never persisted to the DB.
      final preBuiltPlates = item['plates'];
      if (preBuiltPlates is List && preBuiltPlates.isNotEmpty) {
        kitchenItem['plates'] = preBuiltPlates;
      } else {
        final preBuiltServiceChildren = item['service_children'];
        if (preBuiltServiceChildren is List &&
            preBuiltServiceChildren.isNotEmpty) {
          kitchenItem['service_children'] = preBuiltServiceChildren;
        }
      }
      return kitchenItem;
    }

    _logKitchen(
      'Payload',
      'serviceExpanded orderId=$orderId tableNo=$tableNo area=$area '
          'serviceItemIds=$itemId childCount=${filteredChildren.length}',
    );

    final itemWithFilteredChildren = <String, dynamic>{
      ...item,
      'child_items': filteredChildren,
      'service_round_count': MixedServiceOrder.normalizeServiceRoundCount(
        item['service_round_count'] ?? item['plate_count'],
        childItems: filteredChildren,
      ),
      'plate_count': MixedServiceOrder.normalizeServiceRoundCount(
        item['plate_count'] ?? item['service_round_count'],
        childItems: filteredChildren,
      ),
    };
    final grouped = MixedServiceOrder.groupChildItemsByRound(
      itemWithFilteredChildren,
    );
    final usesPlateGrouping = MixedServiceOrder.usesPlateGrouping(
      itemWithFilteredChildren,
    );

    if (usesPlateGrouping && grouped.isNotEmpty) {
      final rounds = grouped.keys.toList()..sort();
      final plates = rounds
          .map(
            (round) => <String, dynamic>{
              'label': 'Tabak $round',
              'items': grouped[round]!
                  .map(_buildKitchenChildPayload)
                  .toList(growable: false),
            },
          )
          .toList(growable: false);
      kitchenItem['plates'] = plates;
      _logKitchen(
        'Payload',
        'plateGrouped orderId=$orderId tableNo=$tableNo area=$area '
            'serviceItemIds=$itemId plateCount=${plates.length}',
      );
      return kitchenItem;
    }

    kitchenItem['service_children'] = filteredChildren
        .map(_buildKitchenChildPayload)
        .toList(growable: false);
    return kitchenItem;
  }

  Map<String, dynamic> _buildKitchenChildPayload(Map<String, dynamic> child) {
    final payload = <String, dynamic>{
      'id': _kitchenItemId(child),
      'name': _kitchenItemName(child),
      'quantity': _intValue(child['quantity'], fallback: 1),
    };
    final amountLabel = _textValue(
      child['amount_label'] ?? child['selected_option_label'],
      fallback: '',
    );
    final note = _textValue(child['note'] ?? child['notes'], fallback: '');
    final stationId = _textValue(child['station_id'], fallback: '');
    if (amountLabel.isNotEmpty) {
      payload['amount_label'] = amountLabel;
    }
    if (note.isNotEmpty) {
      payload['note'] = note;
    }
    if (stationId.isNotEmpty) {
      payload['station_id'] = stationId;
    }
    return payload;
  }

  bool _matchesStation(dynamic rawStationId, String targetStationId) {
    final stationId = _textValue(rawStationId, fallback: '');
    if (targetStationId.isEmpty) {
      return stationId.isEmpty;
    }
    return stationId == targetStationId;
  }

  bool _matchesKitchenChildStation({
    dynamic childStationId,
    required String targetStationId,
    required bool parentMatches,
  }) {
    final resolvedChildStationId = _textValue(childStationId, fallback: '');
    if (targetStationId.isEmpty) {
      return resolvedChildStationId.isEmpty;
    }
    if (resolvedChildStationId.isEmpty) {
      return parentMatches;
    }
    return resolvedChildStationId == targetStationId;
  }

  String _kitchenItemName(Map<String, dynamic> item) {
    return _textValue(
      item['item_name'] ?? item['product_name'] ?? item['name'],
      fallback: 'Urun',
    );
  }

  String _kitchenItemId(Map<String, dynamic> item) {
    return _textValue(
      item['order_item_id'] ??
          item['product_id'] ??
          item['linked_product_id'] ??
          item['seller_product_id'],
      fallback: _kitchenItemName(item),
    );
  }

  bool _isKitchenServiceItem(Map<String, dynamic> item) {
    final plates = item['plates'];
    if (plates is List && plates.isNotEmpty) {
      return true;
    }
    final children = item['service_children'];
    return children is List && children.isNotEmpty;
  }

  /// Validates the print-job payload against the print config contract and logs
  /// any suspicious or invalid configuration BEFORE the print is dispatched.
  ///
  /// This surfaces misconfigurations that would otherwise produce silent failures
  /// or wrong output (wrong route, wrong format, missing host, etc.).
  void _warnPayloadConfig(
    Map<String, dynamic> payload, {
    required String printJobId,
  }) {
    final printerName = _textValue(payload['printer_name'], fallback: '-');
    final printerRoles = _printerRolesLog(payload);
    final connectionType = _textValue(
      payload['printer_connection_type'] ?? payload['connection_type'],
      fallback: '-',
    );
    final deviceId = _textValue(
      payload['printer_device_identifier'] ?? payload['device_identifier'],
      fallback: '',
    );
    final targetRoute = _textValue(
      payload['printer_target_route'] ?? payload['target_route'],
      fallback: '',
    );
    final ipAddress = _textValue(
      payload['printer_ip_address'] ?? payload['ip_address'],
      fallback: '',
    );

    // deviceId starts with /print/ → it was stored in the wrong field.
    // printer_target_route is the correct field for HTTP route overrides.
    if (targetRoute.isEmpty && deviceId.startsWith('/print/')) {
      _logKitchen(
        'ConfigWarning',
        'DEVICE_ID_AS_ROUTE: printJobId=$printJobId printerName=$printerName '
            'printer_device_identifier="$deviceId" looks like an HTTP route but '
            'printer_target_route is absent. '
            'device_identifier must be a CUPS queue name or device path — '
            'HTTP route overrides go in printer_target_route.',
      );
    }

    // printer_target_route present but not starting with / → will be ignored.
    if (targetRoute.isNotEmpty && !targetRoute.startsWith('/')) {
      _logKitchen(
        'ConfigWarning',
        'INVALID_TARGET_ROUTE: printJobId=$printJobId printerName=$printerName '
            'printer_target_route="$targetRoute" does not start with "/". '
            'It will be ignored and /print/kitchen will be used.',
      );
    }

    // Network connection but no IP address → will silently fall back to loopback.
    if (connectionType == 'network' && ipAddress.isEmpty) {
      _logKitchen(
        'ConfigWarning',
        'MISSING_HOST: printJobId=$printJobId printerName=$printerName '
            'connection_type=network but printer_ip_address is absent. '
            'Dispatcher falls back to 127.0.0.1:3001.',
      );
    }

    final resolvedRoute = _resolvePrinterRoute(payload);
    final jobType = _textValue(payload['job_type'], fallback: '-');
    final receiptRole = printerRoles
        .split(',')
        .any((role) => role.trim().toLowerCase() == 'receipt');
    if (receiptRole && resolvedRoute != '/print/receipt') {
      _logKitchen(
        'ConfigWarning',
        'RECEIPT_PRINTER_ROUTE_MISMATCH: printJobId=$printJobId '
            'printerName=$printerName printerRoles=$printerRoles '
            'jobType=$jobType resolvedRoute=$resolvedRoute',
      );
    }
    if (!receiptRole && resolvedRoute == '/print/receipt') {
      _logKitchen(
        'ConfigWarning',
        'NON_RECEIPT_PRINTER_ON_RECEIPT_ROUTE: printJobId=$printJobId '
            'printerName=$printerName printerRoles=$printerRoles '
            'jobType=$jobType resolvedRoute=$resolvedRoute',
      );
    }
  }

  Uri _resolvePrinterBaseUri(Map<String, dynamic> payload) {
    final targetHost = _textValue(
      payload['printer_target_host'] ?? payload['target_host'],
      fallback: '',
    );
    if (targetHost.isNotEmpty) {
      return _uriFromTargetHost(targetHost);
    }

    final host = _textValue(
      payload['printer_ip_address'] ?? payload['ip_address'],
      fallback: '127.0.0.1',
    );
    final port = _intValue(
      payload['printer_port'] ?? payload['port'],
      fallback: 3001,
    );
    return Uri(scheme: 'http', host: host, port: port);
  }

  Uri _uriFromTargetHost(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return Uri.parse('http://127.0.0.1:3001');
    }
    if (normalized.contains('://')) {
      return Uri.parse(normalized);
    }
    return Uri.parse('http://$normalized');
  }

  String _resolvePrinterRoute(Map<String, dynamic> payload) {
    // CONTRACT: printer_target_route (or target_route) is the ONLY payload key
    // that may override the HTTP route to the local print bridge.
    //
    // device_identifier / printer_device_identifier is a physical/CUPS device
    // path (e.g. "YAZICI_1", "/dev/usb/lp0") — it is NOT an HTTP route and MUST
    // NOT be used for route resolution.  Treating it as a route accidentally sent
    // kitchen payloads to /print/receipt (wrong format) when device_identifier
    // was set to "/print/receipt" on a local printer.
    final explicitRoute = _textValue(
      payload['printer_target_route'] ?? payload['target_route'],
      fallback: '',
    );
    final printerRole = _textValue(
      payload['printer_role'],
      fallback: '',
    ).toLowerCase();
    final documentType = _textValue(
      payload['document_type'],
      fallback: '',
    ).toLowerCase();
    final jobType = _textValue(payload['job_type'], fallback: '');
    final normalizedJobType = jobType.toLowerCase();
    final wantsReceipt =
        printerRole == 'adisyon' ||
        printerRole == 'receipt' ||
        documentType == 'receipt' ||
        normalizedJobType == 'receipt' ||
        normalizedJobType == 'test_receipt';
    if (explicitRoute.startsWith('/')) {
      if (explicitRoute == '/print/receipt' && !wantsReceipt) {
        _logKitchen(
          'RouteWarning',
          'RECEIPT_ROUTE_BLOCKED: printer_target_route=$explicitRoute '
              'printerRole=${printerRole.isEmpty ? '-' : printerRole} '
              'documentType=${documentType.isEmpty ? '-' : documentType} '
              'jobType=${jobType.isEmpty ? '-' : jobType} '
              'printerRoles=${_printerRolesLog(payload)} '
              'forcing=/print/kitchen',
        );
        return '/print/kitchen';
      }
      _logKitchen(
        'RouteResolved',
        'route=$explicitRoute source=printer_target_route',
      );
      return explicitRoute;
    }

    // Warn if device_identifier looks like a print route — it will NOT be used
    // for routing, but this warning helps operators spot misconfigured printers.
    final deviceId = _textValue(
      payload['printer_device_identifier'] ?? payload['device_identifier'],
      fallback: '',
    );
    if (deviceId.startsWith('/print/')) {
      _logKitchen(
        'RouteWarning',
        'MISCONFIGURED: printer_device_identifier="$deviceId" looks like a '
            'print route but is NOT used for HTTP route resolution. '
            'device_identifier must be a CUPS queue name or device path. '
            'Set printer_target_route in the print_job payload to override the route. '
            'Defaulting to /print/kitchen.',
      );
    }

    // Default: kitchen dispatcher always targets /print/kitchen.
    if (wantsReceipt) {
      _logKitchen(
        'RouteResolved',
        'route=/print/receipt source=role_or_document_type '
            'printerRole=${printerRole.isEmpty ? '-' : printerRole} '
            'documentType=${documentType.isEmpty ? '-' : documentType} '
            'jobType=${jobType.isEmpty ? '-' : jobType}',
      );
      return '/print/receipt';
    }
    _logKitchen(
      'RouteResolved',
      'route=/print/kitchen source=default_kitchen_fallback '
          'printer_target_route=${_textValue(payload['printer_target_route'], fallback: '-')} '
          'printer_device_identifier=${deviceId.isEmpty ? '-' : deviceId}',
    );
    return '/print/kitchen';
  }

  String _resolveTableNo(
    Map<String, dynamic> payload, {
    required int fallbackTableNumber,
  }) {
    final direct = _textValue(
      payload['table_no'] ?? payload['table_number'],
      fallback: '',
    );
    if (direct.isNotEmpty && direct != '-') {
      return direct;
    }

    final tableName = _textValue(payload['table_name'], fallback: '');
    final matched = RegExp(r'(\d+)').firstMatch(tableName);
    if (matched != null) {
      return matched.group(1) ?? fallbackTableNumber.toString();
    }
    return fallbackTableNumber.toString();
  }

  List<Map<String, dynamic>> _payloadItems(Map<String, dynamic> payload) {
    final rawItems = payload['items'];
    if (rawItems is! List) return const <Map<String, dynamic>>[];
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic> _jobPayload(Map<String, dynamic> row) {
    final rawPayload = row['payload'];
    if (rawPayload is Map<String, dynamic>) {
      return rawPayload;
    }
    if (rawPayload is Map) {
      return Map<String, dynamic>.from(rawPayload);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _payloadWithPrinterConfig(
    Map<String, dynamic> row,
  ) async {
    final payload = Map<String, dynamic>.from(_jobPayload(row));
    final printerId = _textValue(
      row['printer_id'] ?? payload['printer_id'],
      fallback: '',
    );
    if (_hasPrinterEncoding(payload) && _hasPrinterRoles(payload)) {
      return payload;
    }
    if (printerId.isEmpty) {
      final selection = PrinterEncodingSelection.normalize(
        charset: PrinterCharset.cp857,
        codePage: null,
      );
      payload.addAll(<String, dynamic>{
        'printer_encoding': selection.encoding,
        'printer_code_page': selection.codePage,
        'printer_assigned_roles': const <String>[],
      });
      return payload;
    }

    final cached = _printerConfigCache[printerId];
    if (cached != null) {
      payload.addAll(cached);
      return payload;
    }

    final printer = await _printerRepository.fetchPrinterById(printerId);
    if (printer == null) {
      final selection = PrinterEncodingSelection.normalize(
        charset: PrinterCharset.cp857,
        codePage: null,
      );
      payload.addAll(<String, dynamic>{
        'printer_encoding': selection.encoding,
        'printer_code_page': selection.codePage,
        'printer_assigned_roles': const <String>[],
      });
      return payload;
    }

    final selection = printer.encodingSelection;
    final config = <String, dynamic>{
      'printer_encoding': selection.encoding,
      'printer_code_page': selection.codePage,
      'printer_charset': printer.charset.value,
      'printer_assigned_roles': printer.assignedRoles
          .map((role) => role.value)
          .toList(growable: false),
    };
    _printerConfigCache[printerId] = config;
    payload.addAll(config);
    if (selection.fallbackApplied) {
      _logKitchen(
        'EncodingGuard',
        'printerId=$printerId printerName=${printer.name} '
            'requestedCharset=${printer.charset.value} '
            'requestedCodePage=${printer.codePage ?? '-'} '
            'effectiveEncoding=${selection.encoding} '
            'effectiveCodePage=${selection.codePage ?? '-'} '
            'warning=${selection.warning}',
      );
    }
    return payload;
  }

  bool _hasPrinterEncoding(Map<String, dynamic> payload) {
    final encoding = _textValue(
      payload['printer_encoding'] ?? payload['encoding'],
      fallback: '',
    );
    final codePage = _textValue(
      payload['printer_code_page'] ??
          payload['printer_codepage'] ??
          payload['code_page'] ??
          payload['codepage'],
      fallback: '',
    );
    return encoding.isNotEmpty && codePage.isNotEmpty;
  }

  bool _hasPrinterRoles(Map<String, dynamic> payload) {
    return payload['printer_assigned_roles'] is List;
  }

  List<String> _extractPrintJobIds(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _itemAreaMapping(String area, Map<String, dynamic> payload) {
    final items = _payloadItems(payload);
    if (items.isEmpty) return '-';
    return items
        .map((item) {
          final name = _textValue(
            item['product_name'] ?? item['name'],
            fallback: 'Urun',
          );
          final quantity = _intValue(item['quantity'], fallback: 1);
          return '$name->$area(x$quantity)';
        })
        .join(', ');
  }

  String _compactError(Object error) {
    final rendered = error.toString().replaceFirst('Exception: ', '').trim();
    return rendered.isEmpty ? 'Bilinmeyen hata' : rendered;
  }

  String _printerRolesLog(Map<String, dynamic> payload) {
    final raw = payload['printer_assigned_roles'];
    if (raw is List) {
      final roles = raw
          .map((role) => role?.toString().trim() ?? '')
          .where((role) => role.isNotEmpty)
          .toList(growable: false);
      return roles.isEmpty ? '-' : roles.join(',');
    }
    return '-';
  }

  String _textValue(dynamic value, {String fallback = ''}) {
    final rendered = value?.toString().trim() ?? '';
    return rendered.isEmpty ? fallback : rendered;
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _logValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  void _logKitchen(
    String section,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint(
      '[KitchenPrint][$section] $message${error != null ? ' exception=$error' : ''}',
    );
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Broadcast print job IDs to the desktop hub via Supabase Realtime.
  ///
  /// This is the "fast lane" for mobile → desktop print notification.
  /// Supabase broadcast goes directly through the Realtime server without
  /// WAL polling, giving <200ms delivery vs 1-5s for postgres_changes.
  ///
  /// Fire-and-forget: failures are logged but never block the caller.
  Future<void> _broadcastPrintJobsReady(
    String restaurantId,
    List<String> printJobIds,
  ) async {
    RealtimeChannel? channel;
    try {
      final channelName = 'print_signal:$restaurantId';
      channel = _client.channel(channelName);

      // Subscribe → send → unsubscribe.  The subscribe handshake reuses the
      // existing Supabase WebSocket so it completes in <100ms.
      final subscribed = Completer<void>();
      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !subscribed.isCompleted) {
          subscribed.complete();
        }
        if (error != null && !subscribed.isCompleted) {
          subscribed.completeError(error);
        }
      });

      await subscribed.future.timeout(const Duration(seconds: 2));

      channel.sendBroadcastMessage(
        event: 'new_print_jobs',
        payload: {
          'job_ids': printJobIds,
          'restaurant_id': restaurantId,
          'sent_at': DateTime.now().toIso8601String(),
        },
      );

      debugPrint(
        '[OrderPrintJobService] broadcast sent: '
        '${printJobIds.length} job(s) to $channelName',
      );

      // Small delay to ensure message is flushed before cleanup.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('[OrderPrintJobService] broadcast failed (non-fatal): $e');
    } finally {
      if (channel != null) {
        try {
          _client.removeChannel(channel);
        } catch (_) {}
      }
    }
  }
}
