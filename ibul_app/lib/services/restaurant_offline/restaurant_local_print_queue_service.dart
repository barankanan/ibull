import '../../core/secure_local_store.dart';
import '../../models/desktop_printer_setup_models.dart';
import '../bridge_print_dispatch_verification.dart';
import '../desktop_print_orchestrator.dart';
import 'restaurant_offline_models.dart';

class RestaurantLocalPrintQueueService {
  RestaurantLocalPrintQueueService({
    SecureLocalStore? store,
    DesktopPrintOrchestrator? printOrchestrator,
  }) : _store = store ?? SecureLocalStore.instance,
       _printOrchestrator = printOrchestrator;

  final SecureLocalStore _store;
  DesktopPrintOrchestrator? _printOrchestrator;
  static final Map<String, List<RestaurantLocalPrintJobRecord>> _memory =
      <String, List<RestaurantLocalPrintJobRecord>>{};

  DesktopPrintOrchestrator get _orchestrator =>
      _printOrchestrator ??= DesktopPrintOrchestrator();

  static String storageKey(String restaurantId) =>
      'restaurant_offline_print_queue_v1_${restaurantId.trim()}';

  Future<List<RestaurantLocalPrintJobRecord>> list(String restaurantId) async {
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

  Future<RestaurantLocalPrintJobRecord> enqueue({
    required RestaurantLocalPrintJobRecord job,
  }) async {
    final id = job.restaurantId.trim();
    if (id.isEmpty || job.localJobId.trim().isEmpty) {
      throw StateError('Yerel yazdırma işi kaydedilemedi.');
    }
    final existing = await list(id);
    if (existing.any((row) => row.localJobId == job.localJobId)) {
      return job;
    }
    final next = <RestaurantLocalPrintJobRecord>[
      ...existing,
      job.copyWith(status: RestaurantLocalPrintJobStatus.queued),
    ];
    await _persist(id, next);
    return job;
  }

  Future<RestaurantLocalPrintJobRecord> dispatchJob({
    required RestaurantLocalPrintJobRecord job,
    required bool bridgeReachable,
  }) async {
    if (!bridgeReachable) {
      final failed = job.copyWith(
        status: RestaurantLocalPrintJobStatus.failed,
        attempts: job.attempts + 1,
        lastError: 'Yazıcı köprüsü çalışmıyor. Yerel yazdırma yapılamaz.',
      );
      await update(job.restaurantId, failed);
      return failed;
    }

    final dispatching = job.copyWith(
      status: RestaurantLocalPrintJobStatus.dispatching,
      attempts: job.attempts + 1,
    );
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

    final failed = dispatching.copyWith(
      status: RestaurantLocalPrintJobStatus.failed,
      lastError: verification.message.isNotEmpty
          ? verification.message
          : BridgePrintDispatchVerification.dispatchNotDeliveredMessage,
    );
    await update(job.restaurantId, failed);
    return failed;
  }

  Future<void> update(
    String restaurantId,
    RestaurantLocalPrintJobRecord job,
  ) async {
    final id = restaurantId.trim();
    final jobs = await list(id);
    final next = jobs
        .map((row) => row.localJobId == job.localJobId ? job : row)
        .toList(growable: false);
    await _persist(id, next);
  }

  Future<void> _persist(
    String restaurantId,
    List<RestaurantLocalPrintJobRecord> jobs,
  ) async {
    _memory[restaurantId] = jobs;
    await _store.writeJson(storageKey(restaurantId), <String, dynamic>{
      'version': restaurantOfflinePrintQueueVersion,
      'restaurant_id': restaurantId,
      'jobs': jobs.map((job) => job.toJson()).toList(),
    });
  }

  void clearMemoryForTests() {
    _memory.clear();
  }

  static void clearAllMemoryForTests() {
    _memory.clear();
  }
}

List<Map<String, dynamic>> _readMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
