import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/secure_local_store.dart';
import '../../models/desktop_printer_setup_models.dart';
import '../bridge_print_dispatch_verification.dart';
import '../local_print_service.dart';
import '../desktop_print_orchestrator.dart';
import 'restaurant_offline_models.dart';

class RestaurantLocalPrintQueueService {
  RestaurantLocalPrintQueueService({
    SecureLocalStore? store,
    DesktopPrintOrchestrator? printOrchestrator,
    this.writeHook,
  }) : _store = store ?? SecureLocalStore.instance,
       _printOrchestrator = printOrchestrator;

  final SecureLocalStore _store;
  final Future<void> Function()? writeHook;
  final Map<String, int> lastStageMicros = <String, int>{};
  DesktopPrintOrchestrator? _printOrchestrator;
  static final Map<String, List<RestaurantLocalPrintJobRecord>> _memory =
      <String, List<RestaurantLocalPrintJobRecord>>{};
  Future<void>? _tail;

  DesktopPrintOrchestrator get _orchestrator =>
      _printOrchestrator ??= DesktopPrintOrchestrator();

  static String storageKey(String restaurantId) =>
      'restaurant_offline_print_queue_v1_${restaurantId.trim()}';

  Future<List<RestaurantLocalPrintJobRecord>> list(String restaurantId) {
    return _exclusive(() => _load(restaurantId));
  }

  Future<RestaurantLocalPrintJobRecord> enqueue({
    required RestaurantLocalPrintJobRecord job,
  }) {
    return _exclusive(() async {
      final id = job.restaurantId.trim();
      if (id.isEmpty || job.localJobId.trim().isEmpty) {
        throw StateError('Yerel yazdırma işi kaydedilemedi.');
      }
      final existing = await _load(id);
      final prior = existing.where((row) => row.localJobId == job.localJobId);
      if (prior.isNotEmpty) return prior.first;
      final next = <RestaurantLocalPrintJobRecord>[
        ...existing,
        job.copyWith(status: RestaurantLocalPrintJobStatus.queued),
      ];
      await _write(id, next);
      return next.last;
    });
  }

  /// One worker owns the job. A second claim returns null.
  Future<RestaurantLocalPrintJobRecord?> claim(
    String restaurantId,
    String localJobId,
  ) {
    return _exclusive(() async {
      final id = restaurantId.trim();
      final jobs = await _load(id);
      final index = jobs.indexWhere((row) => row.localJobId == localJobId);
      if (index < 0) return null;
      final job = jobs[index];
      if (job.status != RestaurantLocalPrintJobStatus.queued &&
          job.status != RestaurantLocalPrintJobStatus.created) {
        return null;
      }
      if (localPrintErrorIsUncertain(job.lastError)) {
        return null;
      }
      final claimed = job.copyWith(
        status: RestaurantLocalPrintJobStatus.dispatching,
      );
      final next = <RestaurantLocalPrintJobRecord>[...jobs];
      next[index] = claimed;
      await _write(id, next);
      return claimed;
    });
  }

  /// A reprint is a new job. The uncertain or failed job stays as it was.
  Future<RestaurantLocalPrintJobRecord> operatorReprint({
    required RestaurantLocalPrintJobRecord job,
    required String reprintToken,
  }) {
    final token = reprintToken.trim();
    if (token.isEmpty || token.contains('.') || token.contains('|')) {
      throw StateError('Yeniden baskı kimliği geçersiz.');
    }
    if (job.status != RestaurantLocalPrintJobStatus.failed &&
        job.status != RestaurantLocalPrintJobStatus.uncertain &&
        job.status != RestaurantLocalPrintJobStatus.forwarded &&
        job.status != RestaurantLocalPrintJobStatus.dispatching) {
      throw StateError('Bu iş yeniden basılamaz.');
    }
    return enqueue(
      job: RestaurantLocalPrintJobRecord(
        localJobId: '${job.localJobId}|reprint|$token',
        restaurantId: job.restaurantId,
        localOrderId: job.localOrderId,
        tableId: job.tableId,
        tableName: job.tableName,
        documentType: job.documentType,
        role: job.role,
        station: job.station,
        printerSnapshot: job.printerSnapshot,
        payloadSnapshot: <String, dynamic>{
          ...job.payloadSnapshot,
          'job_type': 'reprint',
          'manual_reprint_token': token,
        },
        status: RestaurantLocalPrintJobStatus.queued,
        attempts: 0,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Speaks the existing loopback bridge contract. An HTTP body is not a
  /// physical print acknowledgement.
  Future<RestaurantLocalPrintJobRecord> deliverToBridge({
    required RestaurantLocalPrintJobRecord job,
    required Uri bridgeBase,
    Duration timeout = LocalPrintService.ethernetPrintHttpTimeout,
  }) async {
    if (!_isLoopback(bridgeBase)) {
      final refused = job.copyWith(
        status: RestaurantLocalPrintJobStatus.failed,
        attempts: job.attempts + 1,
        lastError: 'Yazıcı köprüsü yalnız bu bilgisayardan kullanılır.',
      );
      await update(job.restaurantId, refused);
      return refused;
    }
    final noPrinter =
        job.printerSnapshot['resolution_error']?.toString().trim() ?? '';
    if (noPrinter.isNotEmpty) {
      // No printer is known for this station. Nothing is sent, so the
      // result is a definite failure, never "uncertain".
      final unrouted = job.copyWith(
        status: RestaurantLocalPrintJobStatus.failed,
        attempts: job.attempts + 1,
        lastError: noPrinter,
      );
      await update(job.restaurantId, unrouted);
      return unrouted;
    }
    final claimed = await claim(job.restaurantId, job.localJobId);
    if (claimed == null) {
      final current = (await list(job.restaurantId))
          .where((row) => row.localJobId == job.localJobId)
          .firstOrNull;
      if (current == null) {
        throw StateError('Yerel yazdırma işi kaydedilemedi.');
      }
      return current;
    }
    try {
      final health = await _bridgeSend(
        method: 'GET',
        uri: bridgeBase.replace(path: '/health'),
        timeout: timeout,
      );
      final service = health.body['service']?.toString();
      if (health.status != 200 ||
          health.body['ok'] != true ||
          service != 'ibul-local-print-bridge') {
        return _finish(
          claimed,
          RestaurantLocalPrintJobStatus.failed,
          'Yazıcı köprüsü doğrulanamadı.',
        );
      }
    } on TimeoutException {
      return _finish(
        claimed,
        RestaurantLocalPrintJobStatus.failed,
        'Yazıcı köprüsü yanıt vermiyor.',
      );
    } on SocketException catch (error) {
      return _finish(
        claimed,
        _socketFailed(error)
            ? RestaurantLocalPrintJobStatus.failed
            : RestaurantLocalPrintJobStatus.uncertain,
        _socketFailed(error)
            ? 'Yazıcı köprüsü çalışmıyor.'
            : 'Köprü yanıtı kayboldu.',
      );
    } on HttpException {
      return _finish(
        claimed,
        RestaurantLocalPrintJobStatus.uncertain,
        'Köprü yanıtı kayboldu.',
      );
    }
    try {
      final response = await _bridgeSend(
        method: 'POST',
        uri: bridgeBase.replace(path: '/print/kitchen'),
        body: _kitchenBody(claimed),
        timeout: timeout,
      );
      lastStageMicros['bridge_request'] = response.requestMicros;
      lastStageMicros['bridge_response'] = response.responseMicros;
      if (response.status == 200 && response.body['ok'] == true) {
        return _finish(
          claimed,
          RestaurantLocalPrintJobStatus.forwarded,
          'bridge_accepted_not_device_ack',
        );
      }
      // The bridge says whether bytes may already be on the printer. Only a
      // send that certainly did not start is "failed" (safe to send again);
      // anything else is "uncertain" and waits for the operator.
      if (bridgeAnswerIsUncertain(response.body)) {
        return _finish(
          claimed,
          RestaurantLocalPrintJobStatus.uncertain,
          'Yazıcıya gönderim sonucu belirsiz. Fiş kendiliğinden tekrar basılmaz.',
        );
      }
      return _finish(
        claimed,
        RestaurantLocalPrintJobStatus.failed,
        'Yazıcı köprüsü işi kabul etmedi.',
      );
    } on TimeoutException {
      return _finish(
        claimed,
        RestaurantLocalPrintJobStatus.uncertain,
        'Köprü yanıtı kayboldu.',
      );
    } on SocketException catch (error) {
      return _finish(
        claimed,
        _socketFailed(error)
            ? RestaurantLocalPrintJobStatus.failed
            : RestaurantLocalPrintJobStatus.uncertain,
        _socketFailed(error)
            ? 'Yazıcı köprüsü çalışmıyor.'
            : 'Köprü yanıtı kayboldu.',
      );
    } on HttpException {
      return _finish(
        claimed,
        RestaurantLocalPrintJobStatus.uncertain,
        'Köprü yanıtı kayboldu.',
      );
    }
  }

  Future<RestaurantLocalPrintJobRecord> _finish(
    RestaurantLocalPrintJobRecord job,
    RestaurantLocalPrintJobStatus status,
    String message,
  ) async {
    final next = job.copyWith(
      status: status,
      attempts: job.attempts + 1,
      lastError: message,
    );
    await update(job.restaurantId, next);
    return next;
  }

  Future<RestaurantLocalPrintJobRecord> dispatchJob({
    required RestaurantLocalPrintJobRecord job,
    required bool bridgeReachable,
  }) async {
    final claimed = await claim(job.restaurantId, job.localJobId);
    final current = claimed ??
        (await list(job.restaurantId))
            .where((row) => row.localJobId == job.localJobId)
            .firstOrNull;
    if (current == null) {
      throw StateError('Yerel yazdırma işi kaydedilemedi.');
    }
    if (claimed == null) return current;
    if (!bridgeReachable) {
      final failed = current.copyWith(
        status: RestaurantLocalPrintJobStatus.failed,
        attempts: current.attempts + 1,
        lastError: 'Yazıcı köprüsü çalışmıyor. Yerel yazdırma yapılamaz.',
      );
      await update(job.restaurantId, failed);
      return failed;
    }

    final dispatching = current.copyWith(attempts: current.attempts + 1);
    await update(job.restaurantId, dispatching);

    final printer = UnifiedPrinterModel.fromBridgeMap(
      Map<String, dynamic>.from(job.printerSnapshot),
      os: _orchestrator.detectOs(),
    );
    final physicalResult = await _orchestrator.printPhysicalToPrinter(
      printer,
      PrintPayload.fromQueuedJob(job.payloadSnapshot),
      restaurantId: job.restaurantId,
      flowName: job.documentType,
      flowType: job.documentType,
      source: 'restaurant_local_print_queue',
      tableId: job.tableId,
    );
    final verification = BridgePrintDispatchVerification.verify(
      response: physicalResult.raw,
      printer: printer,
    );
    if (verification.countsAsJobCompleted) {
      final printed = dispatching.copyWith(
        status: RestaurantLocalPrintJobStatus.printed,
        printedAt: DateTime.now(),
        lastError: null,
      );
      await update(job.restaurantId, printed);
      return printed;
    }
    final text = verification.message.toLowerCase();
    final uncertain = localPrintErrorIsUncertain(text);
    final held = dispatching.copyWith(
      status: uncertain
          ? RestaurantLocalPrintJobStatus.uncertain
          : RestaurantLocalPrintJobStatus.failed,
      lastError: verification.message.isNotEmpty
          ? verification.message
          : BridgePrintDispatchVerification.dispatchNotDeliveredMessage,
    );
    await update(job.restaurantId, held);
    return held;
  }

  /// A queued job whose last attempt already timed out must not be claimed
  /// again. The bytes may have reached the printer.
  Future<int> holdTimedOutJobs(String restaurantId) async {
    final jobs = await list(restaurantId);
    var held = 0;
    for (final job in jobs) {
      final open = job.status == RestaurantLocalPrintJobStatus.queued ||
          job.status == RestaurantLocalPrintJobStatus.retrying ||
          job.status == RestaurantLocalPrintJobStatus.dispatching;
      if (!open || !localPrintErrorIsUncertain(job.lastError)) continue;
      await update(
        restaurantId,
        job.copyWith(status: RestaurantLocalPrintJobStatus.uncertain),
      );
      held++;
    }
    return held;
  }

  Future<void> update(
    String restaurantId,
    RestaurantLocalPrintJobRecord job,
  ) {
    return _exclusive(() async {
      final id = restaurantId.trim();
      final jobs = await _load(id);
      final next = jobs
          .map((row) => row.localJobId == job.localJobId ? job : row)
          .toList(growable: false);
      await _write(id, next);
    });
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final previous = _tail ?? Future<void>.value();
    final gate = Completer<void>();
    _tail = gate.future;
    return previous.then((_) => action()).whenComplete(gate.complete);
  }

  Future<List<RestaurantLocalPrintJobRecord>> _load(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return const <RestaurantLocalPrintJobRecord>[];
    if (_memory.containsKey(id)) {
      return List<RestaurantLocalPrintJobRecord>.from(_memory[id]!);
    }
    final raw = await _store.readJson(storageKey(id));
    final rows = raw is Map ? raw['jobs'] : null;
    final parsed = _readMapList(rows)
        .map(RestaurantLocalPrintJobRecord.fromJson)
        .toList(growable: false);
    _memory[id] = parsed;
    return parsed;
  }

  Future<void> _write(
    String restaurantId,
    List<RestaurantLocalPrintJobRecord> jobs,
  ) async {
    final hook = writeHook;
    if (hook != null) await hook();
    await _store.writeJson(storageKey(restaurantId), <String, dynamic>{
      'version': restaurantOfflinePrintQueueVersion,
      'restaurant_id': restaurantId,
      'jobs': jobs.map((job) => job.toJson()).toList(),
    });
    _memory[restaurantId] = jobs;
  }

  void clearMemoryForTests() {
    _memory.clear();
  }

  static void clearAllMemoryForTests() {
    _memory.clear();
  }
}

/// True when a failed bridge answer says the ticket may be (partly) on paper.
/// An answer without the outcome fields (an older bridge, or a refusal made
/// before anything was sent such as "printing is switched off") is not.
bool bridgeAnswerIsUncertain(Map<String, dynamic> body) {
  if (body['retry_safe'] == true) return false;
  return body['write_may_have_started'] == true ||
      body['print_outcome']?.toString() == 'uncertain' ||
      body['errorCode']?.toString() == 'print_outcome_uncertain';
}

bool localPrintErrorIsUncertain(String? error) {
  final text = (error ?? '').toLowerCase();
  return text.contains('timeout') ||
      text.contains('client_timeout') ||
      text.contains('uncertain') ||
      text.contains('belirsiz') ||
      text.contains('print_outcome_unknown') ||
      text.contains('print_outcome_uncertain') ||
      text.contains('write_may_have_started');
}

bool _socketFailed(SocketException error) {
  final text = error.message.toLowerCase();
  return text.contains('connection refused') ||
      text.contains('failed host lookup') ||
      text.contains('errno = 61') ||
      text.contains('errno = 111');
}

bool _isLoopback(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

Map<String, dynamic> _kitchenBody(RestaurantLocalPrintJobRecord job) {
  final payload = job.payloadSnapshot;
  final items = payload['items'];
  return <String, dynamic>{
    ...lanPrinterTargetFields(job.printerSnapshot),
    'print_job_id': job.localJobId,
    'job_id': job.localJobId,
    'idempotency_key': job.localJobId,
    'logical_print_key': job.localJobId,
    'manual_reprint_token': payload['manual_reprint_token'],
    'restaurant_id': job.restaurantId,
    'local_order_id': job.localOrderId,
    'order_id': job.localOrderId,
    'revision': payload['revision'] ?? '1',
    'job_type': payload['job_type'] ?? 'new_order',
    'station_id': job.station,
    'station_name': payload['station_name'] ?? job.station,
    'table_no': job.tableId,
    'table_number': job.tableId,
    'table_name': job.tableName,
    'display_table_label': job.tableName,
    'title': 'MUTFAK SİPARİŞİ',
    'items': items is List ? items : const <Map<String, dynamic>>[],
  };
}

/// The printer target the bridge reads from a kitchen request. Only a
/// snapshot built from a saved printer (it names its transport) is passed
/// on; anything else leaves the bridge on its own default target.
Map<String, dynamic> lanPrinterTargetFields(Map<String, dynamic> snapshot) {
  final transport = snapshot['transport_type']?.toString().trim() ?? '';
  if (transport.isEmpty) return const <String, dynamic>{};
  const skipped = <String>{
    'role',
    'printer_role',
    'document_type',
    'station_id',
    'station_name',
    'resolution_error',
  };
  return <String, dynamic>{
    for (final entry in snapshot.entries)
      if (!skipped.contains(entry.key) && entry.value != null)
        entry.key: entry.value,
  };
}

class _BridgeHttpResult {
  const _BridgeHttpResult(
    this.status,
    this.body, {
    this.requestMicros = 0,
    this.responseMicros = 0,
  });

  final int status;
  final Map<String, dynamic> body;
  final int requestMicros;
  final int responseMicros;
}

Future<_BridgeHttpResult> _bridgeSend({
  required String method,
  required Uri uri,
  Map<String, dynamic>? body,
  required Duration timeout,
}) async {
  final client = HttpClient();
  try {
    final requestWatch = Stopwatch()..start();
    final request = await client.openUrl(method, uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      // The Python bridge reads Content-Length and rejects a chunked body
      // ("Request body is required"), which Dart sends when no length is set.
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final requestMicros = requestWatch.elapsedMicroseconds;
    final responseWatch = Stopwatch()..start();
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    return _BridgeHttpResult(
      response.statusCode,
      decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{},
      requestMicros: requestMicros,
      responseMicros: responseWatch.elapsedMicroseconds,
    );
  } finally {
    client.close(force: true);
  }
}

List<Map<String, dynamic>> _readMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
