import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show
        debugPrint,
        debugPrintStack,
        defaultTargetPlatform,
        kIsWeb,
        TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/desktop_printer_setup_models.dart';
import '../models/mixed_service_order.dart';
import '../models/printer_model.dart';
import '../models/seller_product.dart';
import '../models/station_printer_model.dart';
import '../utils/kitchen_print_dedup.dart';
import 'desktop_print_orchestrator.dart';
import 'kitchen_daily_order_no_store.dart';
import 'kitchen_order_number_fields.dart';
import 'kitchen_print_trace_log.dart';
import 'kitchen_product_mapping_cache_store.dart';
import 'kitchen_routing_service.dart';
import 'printer_encoding_profile_store.dart';
import 'printer_event_log_service.dart';
import 'printer_repository.dart';
import '../utils/garson_product_selection.dart';
import '../utils/print_perf_log.dart';

class _KitchenStationPrintGroup {
  const _KitchenStationPrintGroup({
    required this.stationId,
    required this.stationName,
    required this.items,
  });

  final String stationId;
  final String stationName;
  final List<Map<String, dynamic>> items;
}

class _KitchenStationNamesResolveResult {
  const _KitchenStationNamesResolveResult({
    required this.namesById,
    this.fallbackReason = '',
  });

  final Map<String, String> namesById;
  final String fallbackReason;
}

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
    this.physicallyDispatched = false,
    this.bridgeRequestMs = 0,
    this.dispatchPath = '',
    this.handoffToHub = false,
    this.printerNotPrintedYet = false,
    this.printPendingReason,
    this.pendingForHubJobIds = const <String>[],
    this.printFailureMessage,
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
  final bool physicallyDispatched;
  final int bridgeRequestMs;
  final String dispatchPath;
  final bool handoffToHub;
  final bool printerNotPrintedYet;
  final String? printPendingReason;
  final List<String> pendingForHubJobIds;
  final String? printFailureMessage;
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

/// Parent garson flow'dan geçirilen önbellekli mutfak yazıcısı (POS-58).
class GarsonKitchenPrinterHint {
  const GarsonKitchenPrinterHint({
    required this.id,
    required this.name,
    required this.backend,
    required this.queue,
  });

  final String id;
  final String name;
  final String backend;
  final String queue;
}

/// Garson mutfak: fiziksel baskı RPC/DB beklemeden UI kalemlerinden üretilir.
class GarsonKitchenImmediateResult {
  const GarsonKitchenImmediateResult({
    this.physicallyDispatched = false,
    this.bridgeRequestMs = 0,
    this.payloadBuildMs = 0,
    this.printerResolveMs = 0,
    this.printerCacheResolveMs = 0,
    this.stationResolveMs = 0,
    this.fastPathDecisionMs = 0,
    this.directPrintStartedMs = 0,
    this.directPrintDoneMs = 0,
    this.totalToBridgeMs = 0,
    this.dispatchPath = '',
    this.fallbackReason = '',
    this.selectedPrinterId = '',
    this.error,
    this.traceId = '',
  });

  final bool physicallyDispatched;
  final int bridgeRequestMs;
  final int payloadBuildMs;
  final int printerResolveMs;
  final int printerCacheResolveMs;
  final int stationResolveMs;
  final int fastPathDecisionMs;
  final int directPrintStartedMs;
  final int directPrintDoneMs;
  final int totalToBridgeMs;
  final String dispatchPath;
  final String fallbackReason;
  final String selectedPrinterId;
  final String? error;
  final String traceId;

  bool get shouldFallbackLegacy =>
      !physicallyDispatched && fallbackReason.trim().isNotEmpty;
}

class _KitchenPrintDispatchOutcome {
  const _KitchenPrintDispatchOutcome({
    required this.dispatchedJobCount,
    required this.failedJobCount,
    required this.failureMessages,
    this.physicallyDispatched = false,
    this.bridgeRequestMs = 0,
    this.dispatchPath = '',
    this.handoffToHub = false,
    this.printerNotPrintedYet = false,
    this.pendingReason,
    this.pendingForHubJobIds = const <String>[],
  });

  final int dispatchedJobCount;
  final int failedJobCount;
  final List<String> failureMessages;
  final bool physicallyDispatched;
  final int bridgeRequestMs;
  final String dispatchPath;
  final bool handoffToHub;
  final bool printerNotPrintedYet;
  final String? pendingReason;
  final List<String> pendingForHubJobIds;

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
  static final Map<String, Map<String, String>> _stationNamesMemoryCache =
      <String, Map<String, String>>{};
  static final Map<String, Map<String, String>> _stationCodesMemoryCache =
      <String, Map<String, String>>{};
  static final Map<String, DateTime> _stationNamesMemoryCachedAt =
      <String, DateTime>{};
  static final Map<String, Map<String, ProductStationMapping>>
  _productStationMappingsByRestaurant =
      <String, Map<String, ProductStationMapping>>{};
  static const Duration _stationNamesCacheTtl = Duration(minutes: 30);

  Map<String, String> cachedStationNamesForRestaurant(String restaurantId) {
    return Map<String, String>.from(_readCachedStationNames(restaurantId));
  }

  Map<String, String> cachedStationCodesForRestaurant(String restaurantId) {
    return Map<String, String>.from(_readCachedStationCodes(restaurantId));
  }

  void invalidateStationCaches(String restaurantId) {
    final normalized = restaurantId.trim();
    if (normalized.isEmpty) return;
    _stationNamesMemoryCache.remove(normalized);
    _stationCodesMemoryCache.remove(normalized);
    _stationNamesMemoryCachedAt.remove(normalized);
    _logKitchen('StationCache', 'invalidated restaurantId=$normalized');
  }

  Map<String, ProductStationMapping> cachedProductStationMappingsForRestaurant(
    String restaurantId,
  ) {
    return Map<String, ProductStationMapping>.from(
      _productStationMappingsByRestaurant[restaurantId.trim()] ??
          const <String, ProductStationMapping>{},
    );
  }

  /// Ürün Eşleme önbelleği + servis belleği (garson / hub mutfak başlığı).
  Map<String, ProductStationMapping> mergedKitchenProductMappingsForRestaurant(
    String restaurantId, {
    Map<String, ProductStationMapping>? extra,
  }) {
    final id = restaurantId.trim();
    KitchenProductMappingCacheStore.applyMemoryToResolver(id);
    final merged = <String, ProductStationMapping>{
      ...?KitchenTicketHeaderResolver.productMappingsForRestaurant(id),
      ...cachedProductStationMappingsForRestaurant(id),
      if (extra != null) ...extra,
    };
    return merged;
  }

  /// Ürün listesinden mutfak routing önbelleğini doldurur (ağ yok).
  void registerKitchenProductStationMappings({
    required String restaurantId,
    required Iterable<SellerProduct> products,
  }) {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    final stationNames = KitchenTicketHeaderResolver.sanitizeStationNameMap(
      _readCachedStationNames(id),
    );
    final stationCodes = _readCachedStationCodes(id);
    final map = <String, ProductStationMapping>{};
    for (final product in products) {
      final stationId = product.stationId?.trim() ?? '';
      if (stationId.isEmpty) continue;
      var stationName =
          KitchenTicketHeaderResolver.sanitizeProductionStationName(
            product.stationName?.trim() ?? '',
          );
      if (stationName == kKitchenGeneralStationLabel) {
        stationName = stationNames[stationId] ?? kKitchenGeneralStationLabel;
      }
      final stationCode = product.stationCode?.trim().isNotEmpty == true
          ? product.stationCode!.trim().toUpperCase()
          : (stationCodes[stationId] ?? '');
      map[product.id] = ProductStationMapping(
        stationId: stationId,
        stationName: stationName,
        stationCode: stationCode,
      );
      productStationMappingLog(
        'loaded',
        extra: {
          'productId': product.id,
          'productName': product.name,
          'stationId': stationId,
          'stationName': stationName,
          'stationCode': stationCode,
          'header': map[product.id]!.headerLabel,
          'source': product.stationName?.trim().isNotEmpty == true
              ? 'product_row'
              : 'station_cache',
        },
      );
    }
    _productStationMappingsByRestaurant[id] = map;
    final productNamesById = <String, String>{
      for (final product in products) product.id: product.name,
    };
    KitchenTicketHeaderResolver.registerRestaurantProductStationMappings(
      id,
      map,
      productNamesByProductId: productNamesById,
    );
    unawaited(
      KitchenProductMappingCacheStore.persistMappings(
        restaurantId: id,
        mappingsByProductId: map,
        productNamesByProductId: productNamesById,
      ),
    );
    KitchenTicketHeaderResolver.registerRestaurantStationCaches(
      restaurantId: id,
      stationNamesById: stationNames,
      stationCodesById: stationCodes,
    );
  }

  void registerKitchenProductStationMappingsFromMap({
    required String restaurantId,
    required Map<String, ProductStationMapping> mappings,
    Map<String, String>? productNamesByProductId,
  }) {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    final copy = Map<String, ProductStationMapping>.from(mappings);
    _productStationMappingsByRestaurant[id] = copy;
    KitchenTicketHeaderResolver.registerRestaurantProductStationMappings(
      id,
      copy,
      productNamesByProductId: productNamesByProductId,
    );
    if (productNamesByProductId != null && productNamesByProductId.isNotEmpty) {
      unawaited(
        KitchenProductMappingCacheStore.persistMappings(
          restaurantId: id,
          mappingsByProductId: copy,
          productNamesByProductId: productNamesByProductId,
        ),
      );
    }
  }

  /// Garson açılışında arka planda doldurulur; baskı anında DB beklenmez.
  Future<void> prefetchStationNamesCache(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    if (_readCachedStationNames(id).isEmpty) {
      await _fetchStationNamesById(id);
    }
  }

  Future<void> prefetchKitchenStationContext({
    required String restaurantId,
    Iterable<SellerProduct>? products,
  }) async {
    await prefetchStationNamesCache(restaurantId);
    if (products != null) {
      registerKitchenProductStationMappings(
        restaurantId: restaurantId,
        products: products,
      );
    }
  }

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

  void _logGarsonKitchenFastPathDecision({
    required int tableNumber,
    required bool canUseLocalPrintFastPath,
    required bool bridgeAvailable,
    required String cachedKitchenPrinterId,
    required String cachedKitchenPrinterName,
    required String selectedPrinterId,
    required String fallbackReason,
  }) {
    final body = <String, dynamic>{
      'table': tableNumber,
      'canUseLocalPrintFastPath': canUseLocalPrintFastPath,
      'bridgeAvailable': bridgeAvailable,
      'cachedKitchenPrinterId': cachedKitchenPrinterId,
      'cachedKitchenPrinterName': cachedKitchenPrinterName,
      'selectedPrinterId': selectedPrinterId,
      'fallback_reason': fallbackReason.isEmpty ? 'none' : fallbackReason,
    };
    debugPrint('[GarsonKitchenFastPath][Decision] ${jsonEncode(body)}');
  }

  /// Mutfak fişini [items] üzerinden hemen basar; table_orders / print_jobs RPC beklemez.
  Future<GarsonKitchenImmediateResult> dispatchGarsonKitchenImmediateFromItems({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    GarsonKitchenPrinterHint? printerHint,
    bool canUseLocalPrintFastPath = false,
    Map<String, String>? productStationIdByProductId,
    Map<String, ProductStationMapping>? productStationByProductId,
    String? tableAreaName,
  }) async {
    final traceId = _generateTraceId();
    final pipelineWatch = Stopwatch()..start();
    final decisionWatch = Stopwatch()..start();
    final cachedId = printerHint?.id.trim() ?? '';
    final cachedName = printerHint?.name.trim() ?? '';

    if (!_canDirectDispatch) {
      final fastPathDecisionMs = decisionWatch.elapsedMilliseconds;
      _logGarsonKitchenFastPathDecision(
        tableNumber: tableNumber,
        canUseLocalPrintFastPath: canUseLocalPrintFastPath,
        bridgeAvailable: false,
        cachedKitchenPrinterId: cachedId,
        cachedKitchenPrinterName: cachedName,
        selectedPrinterId: '',
        fallbackReason: 'direct_print_disabled',
      );
      logKitchenDispatchPath(
        path: 'legacy_rpc',
        physicallyDispatched: false,
        reason: 'direct_print_disabled',
        itemCount: items.length,
        traceId: traceId,
      );
      return GarsonKitchenImmediateResult(
        traceId: traceId,
        fastPathDecisionMs: fastPathDecisionMs,
        fallbackReason: 'direct_print_disabled',
        dispatchPath: 'legacy',
      );
    }

    final printSystemEnabled = canUseLocalPrintFastPath
        ? true
        : await _fetchPrintSystemEnabled(restaurantId);
    if (!printSystemEnabled) {
      final fastPathDecisionMs = decisionWatch.elapsedMilliseconds;
      _logGarsonKitchenFastPathDecision(
        tableNumber: tableNumber,
        canUseLocalPrintFastPath: canUseLocalPrintFastPath,
        bridgeAvailable: false,
        cachedKitchenPrinterId: cachedId,
        cachedKitchenPrinterName: cachedName,
        selectedPrinterId: '',
        fallbackReason: 'print_system_disabled',
      );
      logKitchenDispatchPath(
        path: 'unknown',
        physicallyDispatched: false,
        reason: 'print_system_disabled',
        itemCount: items.length,
        traceId: traceId,
      );
      return GarsonKitchenImmediateResult(
        traceId: traceId,
        fastPathDecisionMs: fastPathDecisionMs,
        fallbackReason: 'print_system_disabled',
        dispatchPath: 'skipped',
      );
    }

    final cachedStationNames =
        KitchenTicketHeaderResolver.sanitizeStationNameMap(
          _readCachedStationNames(restaurantId),
        );
    final productMappings = mergedKitchenProductMappingsForRestaurant(
      restaurantId,
      extra: productStationByProductId,
    );
    final enrichedItems =
        KitchenTicketHeaderResolver.enrichItemsWithProductionStations(
          items: items,
          stationNamesById: cachedStationNames,
          stationCodesById: cachedStationCodesForRestaurant(restaurantId),
          productStationIdByProductId: productStationIdByProductId,
          productStationByProductId: productMappings,
          tableAreaName: tableAreaName,
          restaurantId: restaurantId,
        );
    final normalized = _routingService
        .normalizeItems(enrichedItems)
        .map((item) => item.toPayloadMap())
        .toList(growable: false);
    if (normalized.isEmpty) {
      final fastPathDecisionMs = decisionWatch.elapsedMilliseconds;
      _logGarsonKitchenFastPathDecision(
        tableNumber: tableNumber,
        canUseLocalPrintFastPath: canUseLocalPrintFastPath,
        bridgeAvailable: false,
        cachedKitchenPrinterId: cachedId,
        cachedKitchenPrinterName: cachedName,
        selectedPrinterId: '',
        fallbackReason: 'payload_build_failed',
      );
      logKitchenDispatchPath(
        path: 'legacy_rpc',
        physicallyDispatched: false,
        reason: 'payload_build_failed',
        itemCount: 0,
        traceId: traceId,
      );
      return GarsonKitchenImmediateResult(
        traceId: traceId,
        fastPathDecisionMs: fastPathDecisionMs,
        fallbackReason: 'payload_build_failed',
        error: 'Mutfak fişi için sipariş kalemi bulunamadı.',
        dispatchPath: 'legacy',
      );
    }

    final bridgeReachable = await _printOrchestrator.isLocalBridgeReachable(
      useCache: true,
    );
    if (!bridgeReachable) {
      final fastPathDecisionMs = decisionWatch.elapsedMilliseconds;
      _logGarsonKitchenFastPathDecision(
        tableNumber: tableNumber,
        canUseLocalPrintFastPath: canUseLocalPrintFastPath,
        bridgeAvailable: false,
        cachedKitchenPrinterId: cachedId,
        cachedKitchenPrinterName: cachedName,
        selectedPrinterId: '',
        fallbackReason: 'bridge_unavailable',
      );
      _logKitchen(
        'Dispatch',
        'trace=$traceId restaurantId=$restaurantId tableNo=$tableNumber '
            'phase=garson_immediate_fallback bridge_unavailable',
      );
      logKitchenDispatchPath(
        path: 'legacy_rpc',
        physicallyDispatched: false,
        reason: 'bridge_unavailable',
        itemCount: normalized.length,
        traceId: traceId,
      );
      return GarsonKitchenImmediateResult(
        traceId: traceId,
        fastPathDecisionMs: fastPathDecisionMs,
        totalToBridgeMs: pipelineWatch.elapsedMilliseconds,
        fallbackReason: 'bridge_unavailable',
        dispatchPath: 'legacy',
      );
    }

    final stationWatch = Stopwatch()..start();
    final stationResolve = await _resolveStationNamesForKitchenPrint(
      restaurantId: restaurantId,
      items: enrichedItems,
      fastPath: canUseLocalPrintFastPath,
    );
    final stationResolveMs = stationWatch.elapsedMilliseconds;
    final stationNamesById = KitchenTicketHeaderResolver.sanitizeStationNameMap(
      stationResolve.namesById,
    );
    final stationCodesById = cachedStationCodesForRestaurant(restaurantId);
    var stationFallbackReason = stationResolve.fallbackReason;

    final payloadWatch = Stopwatch()..start();
    final localOrderTrace = 'garson-local-$traceId';
    final syntheticJob = <String, dynamic>{
      'order_id': localOrderTrace,
      'job_type': 'new_order',
    };
    final stationGroups = _groupItemsByProductionStation(
      normalized,
      stationNamesById: stationNamesById,
      stationCodesById: stationCodesById,
      productStationByProductId: productMappings,
    );
    for (final group in stationGroups) {
      final groupKey = group.stationId.isEmpty
          ? '__general__'
          : group.stationId;
      final groupCode = group.stationId.isEmpty
          ? ''
          : (stationCodesById[group.stationId] ?? '');
      logKitchenRoutingGroupCreated(
        groupKey: groupKey,
        stationId: group.stationId,
        stationName: group.stationName,
        stationCode: groupCode,
        itemCount: group.items.length,
      );
      kitchenPrintPayloadLog(
        'grouped_station',
        extra: {
          'stationId': group.stationId.isEmpty ? '-' : group.stationId,
          'stationName': group.stationName,
          'itemCount': group.items.length,
        },
      );
    }
    final payloadBuildMs = payloadWatch.elapsedMilliseconds;
    final directPrintStartedMs = pipelineWatch.elapsedMilliseconds;
    final fastPathDecisionMs = decisionWatch.elapsedMilliseconds;
    final dailyOrderNo = await KitchenDailyOrderNoStore.nextForRestaurant(
      restaurantId,
    );

    final bridgeWatch = Stopwatch()..start();
    try {
      var physicalOk = true;
      String? physicalError;
      var totalPrinterResolveMs = 0;
      var totalEncodingLoadMs = 0;
      String? selectedPrinterId;
      String? selectedPrinterName;
      final encodingProfilesByPrinterId = <String, PrinterEncodingProfile?>{};
      for (final group in stationGroups) {
        debugPrint('[KitchenPrintJob][create_start]');
        debugPrint('documentType=kitchen');
        debugPrint('role=mutfak');
        debugPrint('stationName=${group.stationName}');
        debugPrint(
          'stationId=${group.stationId.isEmpty ? '-' : group.stationId}',
        );
        kitchenRoutingLog(
          'station_group_created',
          extra: {
            'stationId': group.stationId,
            'stationName': group.stationName,
            'itemCount': group.items.length,
          },
        );
        final printerResolveWatch = Stopwatch()..start();
        final kitchenPrinter = await _printOrchestrator
            .resolveKitchenPrinterForStationOrRole(
              restaurantId: restaurantId,
              stationId: group.stationId,
              stationName: group.stationName,
              tableId: tableNumber.toString(),
              orderId: localOrderTrace,
              flowName: 'kitchen_order',
              source: 'order_print_job_service_garson_immediate',
              minimalSnapshot: true,
            );
        totalPrinterResolveMs += printerResolveWatch.elapsedMilliseconds;
        if (kitchenPrinter == null) {
          physicalOk = false;
          physicalError =
              'Mutfak yazıcısı atanmadı veya Ethernet yazıcıya ulaşılamadı.';
          break;
        }
        _logOrderPrintJobCreate(
          stationName: group.stationName,
          stationId: group.stationId,
          printer: kitchenPrinter,
        );
        selectedPrinterId ??= kitchenPrinter.id;
        selectedPrinterName ??= kitchenPrinter.displayName;
        PrinterEncodingProfile? encodingProfile;
        if (!canUseLocalPrintFastPath) {
          if (encodingProfilesByPrinterId.containsKey(kitchenPrinter.id)) {
            encodingProfile = encodingProfilesByPrinterId[kitchenPrinter.id];
          } else {
            final encodingWatch = Stopwatch()..start();
            encodingProfile = await _printOrchestrator.loadEncodingProfile(
              restaurantId: restaurantId,
              printerId: kitchenPrinter.id,
            );
            totalEncodingLoadMs += encodingWatch.elapsedMilliseconds;
            encodingProfilesByPrinterId[kitchenPrinter.id] = encodingProfile;
          }
        }
        final kitchenPayload = _buildKitchenPayload(
          job: <String, dynamic>{
            ...syntheticJob,
            if (group.stationId.isNotEmpty) 'station_id': group.stationId,
          },
          payload: <String, dynamic>{
            'table_number': tableNumber,
            if (tableAreaName != null &&
                tableAreaName.trim().isNotEmpty) ...<String, dynamic>{
              'display_table_label': tableAreaName.trim(),
              'table_name': tableAreaName.trim(),
              'table_display_name': tableAreaName.trim(),
            },
            'table_area_name':
                KitchenTicketHeaderResolver.diningAreaFromTableLabel(
                  tableAreaName,
                ) ??
                '',
            'station_id': group.stationId.isEmpty ? null : group.stationId,
            if (group.stationId.isNotEmpty) ...<String, dynamic>{
              'station_code': stationCodesById[group.stationId] ?? '',
              'station_name': group.stationName,
              'kitchen_ticket_header': group.stationName,
            },
            if (waiterName != null && waiterName.trim().isNotEmpty)
              'waiter_name': waiterName.trim(),
            'daily_order_no': dailyOrderNo,
            'kitchen_order_no': dailyOrderNo,
          },
          fallbackTableNumber: tableNumber,
          sourceItems: group.items,
          stationNamesById: stationNamesById,
          productStationByProductId: productMappings,
          stationCodesById: stationCodesById,
          tableAreaName: tableAreaName,
          kitchenTicketHeaderOverride: group.stationName,
        );
        stampKitchenOrderNumberFields(kitchenPayload);
        if (encodingProfile != null) {
          _printOrchestrator.stampEncodingProfileOnPayload(
            kitchenPayload,
            encodingProfile,
          );
        } else {
          _printOrchestrator.stampDefaultTurkishGuaranteeOnPayload(
            kitchenPayload,
          );
        }
        kitchenPayload['printer_id'] = kitchenPrinter.id;
        kitchenPayload['printer_name'] = kitchenPrinter.displayName;
        kitchenPayload['printer_queue'] = kitchenPrinter.queueName;
        kitchenPayload['printer_backend'] = kitchenPrinter.backend.value;
        kitchenPayload['document_type'] = 'kitchen';
        kitchenPayload['flow_type'] = 'kitchen_order';
        kitchenPayload['garson_immediate_trace'] = traceId;
        _stampResolvedKitchenPrinterPayload(
          kitchenPayload,
          printer: kitchenPrinter,
          stationName: group.stationName,
        );
        _printOrchestrator.stampDispatchProfileOnPayload(
          kitchenPayload,
          printer: kitchenPrinter,
          documentType: 'kitchen',
          role: 'mutfak',
        );
        _logOrderPrintJobPersistedPayload(kitchenPayload);
        logKitchenFinalBeforeBridge(
          path: 'direct_garson',
          payload: kitchenPayload,
        );
        final physicalResult = await _printOrchestrator.printPhysicalToPrinter(
          kitchenPrinter,
          PrintPayload.fromQueuedJob(kitchenPayload),
          restaurantId: restaurantId,
          flowName: 'kitchen_order',
          flowType: 'kitchen_order',
          source: 'order_print_job_service_garson_immediate',
          tableId: tableNumber.toString(),
        );
        if (!physicalResult.ok) {
          physicalOk = false;
          physicalError =
              physicalResult.technicalMessage ?? physicalResult.message;
          break;
        }
      }
      final physicalResult = PrinterActionResult(
        ok: physicalOk,
        status: physicalOk ? 'ready' : 'print_failed',
        message: physicalError ?? '',
      );
      final bridgeRequestMs = bridgeWatch.elapsedMilliseconds;
      final directPrintDoneMs = pipelineWatch.elapsedMilliseconds;
      final totalToBridgeMs = directPrintStartedMs + bridgeRequestMs;
      final ok = physicalResult.ok;
      final combinedFallback = ok
          ? (stationFallbackReason.isEmpty ? 'none' : stationFallbackReason)
          : 'direct_bridge_error';
      _logGarsonKitchenFastPathDecision(
        tableNumber: tableNumber,
        canUseLocalPrintFastPath: canUseLocalPrintFastPath,
        bridgeAvailable: true,
        cachedKitchenPrinterId: cachedId,
        cachedKitchenPrinterName: cachedName,
        selectedPrinterId: selectedPrinterId ?? '',
        fallbackReason: combinedFallback,
      );
      _logKitchen(
        'Dispatch',
        'trace=$traceId restaurantId=$restaurantId tableNo=$tableNumber '
            'phase=garson_immediate_${ok ? 'success' : 'failed'} '
            'printerId=${selectedPrinterId ?? '-'} printerName=${selectedPrinterName ?? '-'} '
            'bridgeRequestMs=$bridgeRequestMs totalToBridgeMs=$totalToBridgeMs '
            'printerCacheResolveMs=${totalPrinterResolveMs + totalEncodingLoadMs} '
            'stationResolveMs=$stationResolveMs payloadBuildMs=$payloadBuildMs',
      );
      logKitchenDispatchPath(
        path: ok ? 'direct_garson' : 'direct_garson_failed',
        physicallyDispatched: ok,
        reason: combinedFallback,
        itemCount: normalized.length,
        traceId: traceId,
      );
      logPrintPerf('kitchen_order', <String, Object?>{
        'tap_at': DateTime.now().toIso8601String(),
        'fast_path_decision_ms': fastPathDecisionMs,
        'printer_resolve_ms': totalPrinterResolveMs,
        'printer_cache_resolve_ms': totalPrinterResolveMs + totalEncodingLoadMs,
        'station_resolve_ms': stationResolveMs,
        'payload_build_ms': payloadBuildMs,
        'bridge_request_ms': bridgeRequestMs,
        'total_to_bridge_ms': totalToBridgeMs,
        'physicallyDispatched': ok,
        'path': ok ? 'direct_garson' : 'direct_garson_failed',
        'printerId': selectedPrinterId,
        'printerName': selectedPrinterName,
        'layer': 'order_print_job_service_immediate',
        'ok': ok,
        'fallback_reason': combinedFallback,
        if (!ok)
          'error': physicalResult.technicalMessage ?? physicalResult.message,
      });
      return GarsonKitchenImmediateResult(
        physicallyDispatched: ok,
        bridgeRequestMs: bridgeRequestMs,
        payloadBuildMs: payloadBuildMs,
        printerResolveMs: totalPrinterResolveMs,
        printerCacheResolveMs: totalPrinterResolveMs + totalEncodingLoadMs,
        stationResolveMs: stationResolveMs,
        fastPathDecisionMs: fastPathDecisionMs,
        directPrintStartedMs: directPrintStartedMs,
        directPrintDoneMs: directPrintDoneMs,
        totalToBridgeMs: totalToBridgeMs,
        selectedPrinterId: selectedPrinterId ?? '',
        dispatchPath: ok ? 'direct_garson' : 'direct_garson_failed',
        fallbackReason: ok ? stationFallbackReason : 'direct_bridge_error',
        error: ok
            ? null
            : (physicalResult.technicalMessage ?? physicalResult.message),
        traceId: traceId,
      );
    } catch (error, stackTrace) {
      _logGarsonKitchenFastPathDecision(
        tableNumber: tableNumber,
        canUseLocalPrintFastPath: canUseLocalPrintFastPath,
        bridgeAvailable: true,
        cachedKitchenPrinterId: cachedId,
        cachedKitchenPrinterName: cachedName,
        selectedPrinterId: '-',
        fallbackReason: 'direct_bridge_error',
      );
      _logKitchen(
        'Error',
        'trace=$traceId restaurantId=$restaurantId tableNo=$tableNumber '
            'phase=garson_immediate_error durationMs=${pipelineWatch.elapsedMilliseconds}',
        error: error,
        stackTrace: stackTrace,
      );
      logKitchenDispatchPath(
        path: 'legacy_rpc',
        physicallyDispatched: false,
        reason: 'direct_bridge_error',
        itemCount: normalized.length,
        traceId: traceId,
      );
      return GarsonKitchenImmediateResult(
        bridgeRequestMs: bridgeWatch.elapsedMilliseconds,
        payloadBuildMs: payloadBuildMs,
        printerResolveMs: 0,
        printerCacheResolveMs: 0,
        fastPathDecisionMs: fastPathDecisionMs,
        directPrintStartedMs: directPrintStartedMs,
        directPrintDoneMs: pipelineWatch.elapsedMilliseconds,
        totalToBridgeMs: pipelineWatch.elapsedMilliseconds,
        selectedPrinterId: '',
        dispatchPath: 'legacy',
        fallbackReason: 'direct_bridge_error',
        error: _compactError(error),
        traceId: traceId,
      );
    }
  }

  Future<OrderPrintJobDispatchResult> dispatchNewOrder({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
    String jobType = 'new_order',
    bool garsonDesktopFastKitchen = false,
  }) async {
    final traceId = _generateTraceId();
    final pipelineStartedAt = DateTime.now().toIso8601String();
    final pipelineWatch = Stopwatch()..start();
    final productMappings = mergedKitchenProductMappingsForRestaurant(
      restaurantId,
    );
    final stationNamesById = KitchenTicketHeaderResolver.sanitizeStationNameMap(
      _readCachedStationNames(restaurantId),
    );
    final stationCodesById = cachedStationCodesForRestaurant(restaurantId);
    final enrichedItems =
        KitchenTicketHeaderResolver.enrichItemsWithProductionStations(
          items: items,
          stationNamesById: stationNamesById,
          stationCodesById: stationCodesById,
          productStationByProductId: productMappings,
          restaurantId: restaurantId,
        );
    final normalized = _routingService
        .normalizeItems(enrichedItems)
        .map((item) => item.toPayloadMap())
        .toList(growable: false);

    if (normalized.isEmpty) {
      throw Exception('Print job oluşturmak için sipariş kalemi bulunamadı.');
    }

    debugPrint('[GarsonPrint][send_order_start]');
    debugPrint('table=$tableNumber');
    debugPrint('orderId=-');
    debugPrint('items=${normalized.length}');
    await _debugGarsonPrintConfigSnapshot(
      restaurantId: restaurantId,
      normalizedItems: normalized,
    );

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
    final jobsForEventLog = printJobIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _fetchPrintJobsByIds(printJobIds);
    final jobsById = <String, Map<String, dynamic>>{
      for (final job in jobsForEventLog)
        _textValue(job['id'], fallback: ''): Map<String, dynamic>.from(job),
    };
    final filteredPrintJobIds = await _suppressDuplicateKitchenJobs(
      restaurantId: restaurantId,
      traceId: traceId,
      tableNumber: tableNumber,
      jobType: jobType,
      printJobIds: printJobIds,
      jobsById: jobsById,
    );
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
      final job = jobsById[printJobId] ?? const <String, dynamic>{};
      final payload = job['payload'] is Map
          ? Map<String, dynamic>.from(job['payload'] as Map)
          : const <String, dynamic>{};
      final stationId = _textValue(job['station_id'], fallback: '');
      final stationName = _textValue(
        payload['station_name'] ?? payload['kitchen_ticket_header'],
        fallback: '',
      );
      final idempotencyKey = kitchenPrintIdempotencyKeyFromJob(
        restaurantId: restaurantId,
        job: job,
        payload: payload,
      );
      debugPrint(
        '[KITCHEN_JOB_CREATE_ATTEMPT] '
        'order_id=${_textValue(job['order_id'], fallback: _textValue(data['order_id']))} '
        'table_label=${_textValue(payload['display_table_label'] ?? payload['table_name'])} '
        'station=${stationName.isEmpty ? '-' : stationName} '
        'revision=${payload['revision'] ?? payload['order_revision'] ?? 1} '
        'items_hash=${buildKitchenItemsHash(_payloadItems(payload))} '
        'idempotency_key=$idempotencyKey '
        'source=$jobType '
        'existing_job_id=- will_create=true',
      );
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
              'print_job_id': printJobId,
              'station_id': stationId,
              'station_name': stationName,
              'idempotency_key': idempotencyKey,
            },
          )
          .ignore();
      _printerEventLogService
          .append(
            restaurantId: restaurantId,
            event: 'kitchen_print_job_created',
            message: 'Mutfak print job oluşturuldu.',
            jobId: printJobId,
            role: 'mutfak',
            details: <String, dynamic>{
              'traceId': traceId,
              'tableNumber': tableNumber,
              'jobType': jobType,
              'print_job_id': printJobId,
              'station_id': stationId,
              'station_name': stationName,
              'status': 'created',
              'idempotency_key': idempotencyKey,
            },
          )
          .ignore();
      debugPrint(
        '[KITCHEN_JOB_CREATED] '
        'job_id=$printJobId '
        'idempotency_key=$idempotencyKey '
        'station=${stationName.isEmpty ? '-' : stationName} '
        'items_count=${_payloadItems(payload).length}',
      );
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
              'print_job_id': printJobId,
              'station_id': stationId,
              'station_name': stationName,
              'resolution_source': _textValue(
                payload['printer_resolution_source'],
                fallback: '',
              ),
              'printer_source': _textValue(
                payload['printer_resolution_source'],
                fallback: '',
              ),
              'selected_printer_id': _textValue(
                payload['selected_printer_id'] ??
                    payload['printer_record_id'] ??
                    payload['printer_id'],
                fallback: '',
              ),
              'selected_printer_name': _textValue(
                payload['selected_printer_name'] ?? payload['printer_name'],
                fallback: '',
              ),
              'selected_printer_backend': _textValue(
                payload['selected_printer_backend'] ??
                    payload['printer_backend'] ??
                    payload['backend'],
                fallback: '',
              ),
              'selected_printer_host': _textValue(
                payload['selected_printer_host'] ??
                    payload['host'] ??
                    payload['ip_address'] ??
                    payload['ipAddress'],
                fallback: '',
              ),
              'selected_printer_port': _textValue(
                payload['selected_printer_port'] ?? payload['port'],
                fallback: '',
              ),
              'status': 'queued',
            },
          )
          .ignore();
    }

    final missingKitchenJobMessage =
        normalized.isNotEmpty && printJobIds.isEmpty
        ? 'Sipariş kaydoldu ama mutfak print job oluşturulmadı.'
        : null;
    if (missingKitchenJobMessage != null) {
      _printerEventLogService
          .append(
            restaurantId: restaurantId,
            event: 'kitchen_print_job_creation_failed',
            message: missingKitchenJobMessage,
            level: 'error',
            role: 'mutfak',
            details: <String, dynamic>{
              'traceId': traceId,
              'tableNumber': tableNumber,
              'jobType': jobType,
              'order_id': _textValue(data['order_id'], fallback: ''),
              'order_number': _textValue(data['order_number'], fallback: ''),
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

    final useGarsonFastKitchen =
        garsonDesktopFastKitchen &&
        _canDirectDispatch &&
        printSystemEnabled &&
        filteredPrintJobIds.isNotEmpty;
    final dispatchOutcome = useGarsonFastKitchen
        ? await _dispatchCreatedPrintJobsGarsonFast(
            restaurantId: restaurantId,
            tableNumber: tableNumber,
            orderId: data['order_id']?.toString(),
            printJobIds: filteredPrintJobIds,
            sourceItems: items,
          )
        : await _dispatchCreatedPrintJobs(
            restaurantId: restaurantId,
            tableNumber: tableNumber,
            orderId: data['order_id']?.toString(),
            printJobIds: filteredPrintJobIds,
            sourceItems: items,
          );

    logKitchenDispatchPath(
      path: useGarsonFastKitchen
          ? 'print_jobs_garson_fast'
          : (_canDirectDispatch ? 'print_jobs_legacy_rpc' : 'hub'),
      physicallyDispatched: dispatchOutcome.physicallyDispatched,
      reason: dispatchOutcome.dispatchPath,
      itemCount: normalized.length,
      traceId: traceId,
    );
    if (dispatchOutcome.handoffToHub) {
      _logKitchen(
        'Dispatch',
        'trace=$traceId restaurantId=$restaurantId tableNo=$tableNumber '
            'handoff_to_hub=true printer_not_printed_yet=true '
            'reason=${dispatchOutcome.pendingReason ?? '-'} '
            'pendingJobIds=${dispatchOutcome.pendingForHubJobIds.join(",")}',
      );
    }

    final printFailureMessage =
        missingKitchenJobMessage ??
        (dispatchOutcome.hasFailures
            ? dispatchOutcome.failureMessages.join(' | ')
            : null);

    final resultRaw = <String, dynamic>{
      ...data,
      'handoff_to_hub': dispatchOutcome.handoffToHub,
      'printer_not_printed_yet': dispatchOutcome.printerNotPrintedYet,
      'print_pending_reason': dispatchOutcome.pendingReason,
      'pending_for_hub_job_ids': dispatchOutcome.pendingForHubJobIds,
      if (printFailureMessage != null)
        'print_failure_message': printFailureMessage,
    };

    return OrderPrintJobDispatchResult(
      orderId: data['order_id']?.toString(),
      orderNumber: data['order_number']?.toString(),
      printJobCount: (data['print_job_count'] as num?)?.toInt() ?? 0,
      printJobIds: printJobIds,
      raw: resultRaw,
      orderSavedAt: orderSavedAt,
      printJobCreatedAt: printJobCreatedAt,
      dispatchedJobCount: dispatchOutcome.dispatchedJobCount,
      failedJobCount: dispatchOutcome.failedJobCount,
      traceId: traceId,
      pipelineStartedAt: pipelineStartedAt,
      printSystemEnabled: printSystemEnabled,
      printSuppressedReason: printSystemEnabled
          ? null
          : 'print_system_disabled',
      physicallyDispatched: dispatchOutcome.physicallyDispatched,
      bridgeRequestMs: dispatchOutcome.bridgeRequestMs,
      dispatchPath: dispatchOutcome.dispatchPath,
      handoffToHub: dispatchOutcome.handoffToHub,
      printerNotPrintedYet: dispatchOutcome.printerNotPrintedYet,
      printPendingReason: dispatchOutcome.pendingReason,
      pendingForHubJobIds: dispatchOutcome.pendingForHubJobIds,
      printFailureMessage: printFailureMessage,
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
          .update({'status': 'paused_by_operator', 'last_error': reason})
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

    debugPrint('[GarsonPrint][send_order_start]');
    debugPrint('table=$tableNumber');
    debugPrint('orderId=$tableOrderId');
    debugPrint('items=${rawItems.length}');

    if (sellerId.isEmpty || tableNumber <= 0) {
      throw Exception('table_orders kaydı print routing için uygun değil.');
    }

    return dispatchNewOrder(
      restaurantId: sellerId,
      tableNumber: tableNumber,
      items: rawItems,
      waiterName: waiterName,
      garsonDesktopFastKitchen: true,
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
          'p_waiter_id': (waiterId == null || waiterId.isEmpty)
              ? null
              : waiterId,
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
    if (details.contains(
          'column "table_number" of relation "orders" does not exist',
        ) ||
        details.contains('orders') &&
            details.contains('table_number') &&
            details.contains('does not exist')) {
      return 'Mutfak fişi oluşturulamadı. Supabase orders tablosunda table_number kolonu yok '
          'ama mutfak print RPC onu yazmaya çalışıyor. SQL patch uygulanmalı '
          '(create_table_order_with_print_jobs_impl).';
    }
    if (details.contains('missing from-clause entry for table "v_item"') ||
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

  Future<_KitchenPrintDispatchOutcome> _dispatchCreatedPrintJobsGarsonFast({
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
        dispatchPath: 'direct_garson_skipped_no_jobs',
      );
    }

    final bridgeReachable = await _printOrchestrator.isLocalBridgeReachable(
      useCache: true,
    );
    if (!bridgeReachable) {
      _logKitchen(
        'Dispatch',
        'restaurantId=$restaurantId tableNo=$tableNumber '
            'orderId=${_logValue(orderId)} phase=garson_fast_fallback_bridge_offline',
      );
      return _dispatchCreatedPrintJobs(
        restaurantId: restaurantId,
        tableNumber: tableNumber,
        orderId: orderId,
        printJobIds: printJobIds,
        sourceItems: sourceItems,
      );
    }

    final jobs = await _fetchPrintJobsByIds(printJobIds);
    final productMappings = mergedKitchenProductMappingsForRestaurant(
      restaurantId,
    );
    final stationNamesById = KitchenTicketHeaderResolver.sanitizeStationNameMap(
      _readCachedStationNames(restaurantId),
    );
    final stationCodesById = cachedStationCodesForRestaurant(restaurantId);
    final enrichedSource = sourceItems != null && sourceItems.isNotEmpty
        ? KitchenTicketHeaderResolver.enrichItemsWithProductionStations(
            items: sourceItems,
            stationNamesById: stationNamesById,
            stationCodesById: stationCodesById,
            productStationByProductId: productMappings,
            restaurantId: restaurantId,
          )
        : sourceItems;
    var dispatchedJobCount = 0;
    var failedJobCount = 0;
    final failureMessages = <String>[];
    var maxBridgeRequestMs = 0;
    var physicallyDispatched = false;
    var totalPrinterResolveMs = 0;
    final encodingProfilesByPrinterId = <String, PrinterEncodingProfile?>{};

    for (final job in jobs) {
      final printJobId = job['id']?.toString() ?? '';
      if (printJobId.isEmpty) continue;

      final payload = await _payloadWithPrinterConfig(job);
      final safePayload = Map<String, dynamic>.from(payload);
      if (KitchenTicketHeaderResolver.isDiningAreaStationLabel(
        _textValue(safePayload['area_name']),
      )) {
        safePayload.remove('area_name');
      }
      final jobStationId = _textValue(
        job['station_id'] ?? safePayload['station_id'],
      );
      final headerOverride = jobStationId.isNotEmpty
          ? KitchenTicketHeaderResolver.productionHeaderLabel(
              stationName:
                  stationNamesById[jobStationId] ??
                  _textValue(safePayload['station_name']),
              stationCode:
                  stationCodesById[jobStationId] ??
                  _textValue(safePayload['station_code']),
            )
          : null;
      final printerResolveWatch = Stopwatch()..start();
      debugPrint('[KitchenPrintJob][create_start]');
      debugPrint('documentType=kitchen');
      debugPrint('role=mutfak');
      debugPrint(
        'stationName=${stationNamesById[jobStationId] ?? _textValue(safePayload['station_name'])}',
      );
      debugPrint('stationId=${jobStationId.isEmpty ? '-' : jobStationId}');
      final kitchenPrinter = await _printOrchestrator
          .resolveKitchenPrinterForStationOrRole(
            restaurantId: restaurantId,
            stationId: jobStationId,
            stationName:
                stationNamesById[jobStationId] ??
                _textValue(safePayload['station_name']),
            tableId: tableNumber.toString(),
            orderId: _logValue(job['order_id']),
            printJobId: printJobId,
            flowName: 'kitchen_order',
            source: 'order_print_job_service_garson_fast',
            minimalSnapshot: true,
          );
      totalPrinterResolveMs += printerResolveWatch.elapsedMilliseconds;
      if (kitchenPrinter == null) {
        failedJobCount += 1;
        failureMessages.add(
          'Mutfak yazıcısı atanmadı veya Ethernet yazıcıya ulaşılamadı.',
        );
        await _markPrintJobFailed(
          printJobId,
          requestUrl: 'http://127.0.0.1:3001/print/kitchen',
          error: 'Mutfak yazıcısı atanmadı veya Ethernet yazıcıya ulaşılamadı.',
        );
        continue;
      }
      _logOrderPrintJobCreate(
        stationName: headerOverride ?? '',
        stationId: jobStationId,
        printer: kitchenPrinter,
      );
      final kitchenPayload = _buildKitchenPayload(
        job: job,
        payload: safePayload,
        fallbackTableNumber: tableNumber,
        sourceItems: enrichedSource,
        stationNamesById: stationNamesById,
        stationCodesById: stationCodesById,
        productStationByProductId: productMappings,
        kitchenTicketHeaderOverride: headerOverride,
      );
      PrinterEncodingProfile? encodingProfile;
      if (encodingProfilesByPrinterId.containsKey(kitchenPrinter.id)) {
        encodingProfile = encodingProfilesByPrinterId[kitchenPrinter.id];
      } else {
        encodingProfile = await _printOrchestrator.loadEncodingProfile(
          restaurantId: restaurantId,
          printerId: kitchenPrinter.id,
        );
        encodingProfilesByPrinterId[kitchenPrinter.id] = encodingProfile;
      }
      if (encodingProfile != null) {
        _printOrchestrator.stampEncodingProfileOnPayload(
          kitchenPayload,
          encodingProfile,
        );
      } else {
        _printOrchestrator.stampDefaultTurkishGuaranteeOnPayload(
          kitchenPayload,
        );
      }
      kitchenPayload['printer_id'] = kitchenPrinter.id;
      kitchenPayload['printer_name'] = kitchenPrinter.displayName;
      kitchenPayload['printer_queue'] = kitchenPrinter.queueName;
      kitchenPayload['printer_backend'] = kitchenPrinter.backend.value;
      kitchenPayload['document_type'] = 'kitchen';
      kitchenPayload['flow_type'] = 'kitchen_order';
      _stampResolvedKitchenPrinterPayload(
        kitchenPayload,
        printer: kitchenPrinter,
        stationName: headerOverride ?? '',
      );
      _printOrchestrator.stampDispatchProfileOnPayload(
        kitchenPayload,
        printer: kitchenPrinter,
        documentType: 'kitchen',
        role: 'mutfak',
      );
      _logOrderPrintJobPersistedPayload(kitchenPayload);

      final tapAt = DateTime.now().toIso8601String();
      final watch = Stopwatch()..start();
      final idempotencyKey = kitchenPrintIdempotencyKeyFromJob(
        restaurantId: restaurantId,
        job: job,
        payload: kitchenPayload,
      );
      try {
        debugPrint(
          '[KITCHEN_PHYSICAL_DISPATCH_ATTEMPT] '
          'job_id=$printJobId '
          'order_id=${_logValue(job['order_id'])} '
          'station=${headerOverride ?? '-'} '
          'idempotency_key=$idempotencyKey '
          'dispatch_source=immediate '
          'printer=${kitchenPrinter.displayName} '
          'backend=${kitchenPrinter.backend.value} '
          'host=${kitchenPrinter.raw['host'] ?? kitchenPrinter.raw['ip_address'] ?? '-'} '
          'port=${kitchenPrinter.raw['port'] ?? '-'}',
        );
        await _markPrintJobPrinting(
          printJobId,
          dispatchStartedAt: DateTime.now(),
          payload: kitchenPayload,
        );
        final bridgeWatch = Stopwatch()..start();
        logKitchenFinalBeforeBridge(
          path: 'print_jobs_garson_fast',
          payload: kitchenPayload,
        );
        final physicalResult = await _printOrchestrator.printPhysicalToPrinter(
          kitchenPrinter,
          PrintPayload.fromQueuedJob(kitchenPayload),
          restaurantId: restaurantId,
          flowName: 'kitchen_order',
          flowType: 'kitchen_order',
          source: 'order_print_job_service_garson_fast',
          printJobId: printJobId,
          tableId: tableNumber.toString(),
        );
        final bridgeRequestMs = bridgeWatch.elapsedMilliseconds;
        if (bridgeRequestMs > maxBridgeRequestMs) {
          maxBridgeRequestMs = bridgeRequestMs;
        }
        final jobPayloadBuildMs = watch.elapsedMilliseconds - bridgeRequestMs;
        logPrintPerf('kitchen_order', <String, Object?>{
          'tap_at': tapAt,
          'printer_cache_resolve_ms': totalPrinterResolveMs,
          'payload_build_ms': jobPayloadBuildMs < 0 ? 0 : jobPayloadBuildMs,
          'bridge_request_ms': bridgeRequestMs,
          'total_to_bridge_ms': watch.elapsedMilliseconds,
          'total_submit_to_print_ms': watch.elapsedMilliseconds,
          'physicallyDispatched': physicalResult.ok,
          'path': 'direct_garson',
          'printerId': kitchenPrinter.id,
          'printerName': kitchenPrinter.displayName,
          'print_job_id': printJobId,
          'layer': 'order_print_job_service_garson_fast',
          'ok': physicalResult.ok,
          if (!physicalResult.ok)
            'error': physicalResult.technicalMessage ?? physicalResult.message,
        });
        if (!physicalResult.ok) {
          failedJobCount += 1;
          failureMessages.add(physicalResult.message);
          await _markPrintJobFailed(
            printJobId,
            requestUrl: 'http://127.0.0.1:3001/print/kitchen',
            error: physicalResult.message,
          );
          continue;
        }
        await _markPrintJobCompleted(
          printJobId,
          completedAt: DateTime.now(),
          bridgeResult: physicalResult.raw,
          payload: kitchenPayload,
        );
        debugPrint(
          '[KITCHEN_PHYSICAL_DISPATCH_COMPLETED] '
          'job_id=$printJobId '
          'idempotency_key=$idempotencyKey '
          'completed_at=${DateTime.now().toIso8601String()}',
        );
        dispatchedJobCount += 1;
        physicallyDispatched = true;
        _logKitchen(
          'Dispatch',
          'orderId=${_logValue(job['order_id'])} tableNo=$tableNumber '
              'printerId=${kitchenPrinter.id} phase=garson_fast_success '
              'durationMs=${watch.elapsedMilliseconds} bridgeRequestMs=$bridgeRequestMs',
        );
      } catch (error, stackTrace) {
        failedJobCount += 1;
        failureMessages.add(_compactError(error));
        await _markPrintJobFailed(
          printJobId,
          requestUrl: 'http://127.0.0.1:3001/print/kitchen',
          error: _compactError(error),
        );
        _logKitchen(
          'Error',
          'orderId=${_logValue(job['order_id'])} tableNo=$tableNumber '
              'phase=garson_fast_error durationMs=${watch.elapsedMilliseconds}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return _KitchenPrintDispatchOutcome(
      dispatchedJobCount: dispatchedJobCount,
      failedJobCount: failedJobCount,
      failureMessages: failureMessages,
      physicallyDispatched: physicallyDispatched,
      bridgeRequestMs: maxBridgeRequestMs,
      dispatchPath: physicallyDispatched
          ? 'direct_garson'
          : 'direct_garson_failed',
    );
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
        handoffToHub: true,
        printerNotPrintedYet: true,
        pendingReason: 'bridge_unavailable',
        dispatchPath: 'pending_for_hub',
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
    final pendingForHubJobIds = <String>[];

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
      final safePayload = Map<String, dynamic>.from(payload);
      if (KitchenTicketHeaderResolver.isDiningAreaStationLabel(
        _textValue(safePayload['area_name']),
      )) {
        safePayload.remove('area_name');
      }
      final productMappings = Map<String, ProductStationMapping>.from(
        _productStationMappingsByRestaurant[restaurantId] ??
            const <String, ProductStationMapping>{},
      );
      final stationNamesById =
          KitchenTicketHeaderResolver.sanitizeStationNameMap(
            _readCachedStationNames(restaurantId),
          );
      final stationCodesById = cachedStationCodesForRestaurant(restaurantId);
      final jobStationId = _textValue(
        job['station_id'] ?? safePayload['station_id'],
      );
      final headerOverride = jobStationId.isNotEmpty
          ? KitchenTicketHeaderResolver.productionHeaderLabel(
              stationName:
                  stationNamesById[jobStationId] ??
                  _textValue(safePayload['station_name']),
              stationCode:
                  stationCodesById[jobStationId] ??
                  _textValue(safePayload['station_code']),
            )
          : KitchenTicketHeaderResolver.productionHeaderLabel(
              stationName: _textValue(safePayload['station_name']),
              stationCode: _textValue(safePayload['station_code']),
            );
      final area = headerOverride == kKitchenGeneralStationLabel
          ? kKitchenGeneralStationLabel
          : headerOverride;
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
      _warnPayloadConfig(safePayload, printJobId: printJobId);

      final itemCount = _payloadItems(safePayload).length;
      final tableNo = _resolveTableNo(
        safePayload,
        fallbackTableNumber: tableNumber,
      );
      final itemAreaMap = _itemAreaMapping(area, safePayload);

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
      final tapAt = DateTime.now().toIso8601String();
      var kitchenPayloadBuildMs = 0;
      var printDispatchMs = 0;
      var bridgeRequestMs = 0;
      var requestUrl = 'http://127.0.0.1:3001/print/kitchen';
      UnifiedPrinterModel? resolvedPrinterForAttempt;
      Map<String, dynamic>? resolvedPayloadForAttempt;
      var resolutionSourceForAttempt = '';
      try {
        final kitchenPayload = _buildKitchenPayload(
          job: job,
          payload: safePayload,
          fallbackTableNumber: tableNumber,
          sourceItems: sourceItems,
          stationNamesById: stationNamesById,
          stationCodesById: stationCodesById,
          productStationByProductId: productMappings,
          kitchenTicketHeaderOverride: headerOverride,
        );
        final preparedPayload = await _printOrchestrator
            .prepareQueuedPrintPayload(
              restaurantId: restaurantId,
              jobRecord: job,
              payload: kitchenPayload,
            );
        kitchenPayloadBuildMs = watch.elapsedMilliseconds;
        final resolvedPrinterCandidate = preparedPayload.printer;
        var resolvedPayload = Map<String, dynamic>.from(
          preparedPayload.payload,
        );
        resolvedPrinterForAttempt = resolvedPrinterCandidate;
        resolvedPayloadForAttempt = resolvedPayload;
        resolutionSourceForAttempt = preparedPayload.resolutionSource;
        _logOrderPrintJobDispatchLoaded(resolvedPayload);
        final builtItemCount = (kitchenPayload['items'] as List?)?.length ?? 0;
        _logKitchen(
          'Dispatch',
          'route=${_resolvePrinterRoute(resolvedPayload)} orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'payloadItemCount=$builtItemCount '
              'sourceItemCount=${sourceItems?.length ?? 0} '
              'payloadJobItemCount=${_payloadItems(payload).length} '
              '${builtItemCount == 0 ? 'WARN=EMPTY_ITEMS_PAYLOAD' : 'items_ok'} '
              'phase=payload_built '
              'resolutionSource=${preparedPayload.resolutionSource} '
              'resolvedPrinter=${resolvedPrinterCandidate?.id ?? '-'} '
              'resolvedRecordId=${resolvedPrinterCandidate?.printerRecordId ?? '-'}',
        );
        var resolvedPrinterForDispatch = resolvedPrinterCandidate;
        var resolutionSourceForDispatch = preparedPayload.resolutionSource;
        final canonicalStationName = _textValue(
          resolvedPayload['station_name'] ?? area,
          fallback: area,
        );
        final expectedKitchenPrinter = await _printerRepository
            .resolveExpectedKitchenPrinter(
              restaurantId: restaurantId,
              stationId: jobStationId,
              stationName: canonicalStationName,
            );

        if (expectedKitchenPrinter != null &&
            expectedKitchenPrinter.isTcp &&
            (resolvedPrinterForDispatch == null ||
                !_matchesExpectedKitchenResolution(
                  resolvedPrinterForDispatch,
                  expectedKitchenPrinter,
                ))) {
          final wrongPrinter = resolvedPrinterForDispatch;
          if (wrongPrinter != null) {
            _printerEventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'kitchen_wrong_printer_selected',
                  message:
                      'Mutfak işi için yanlış yazıcı son güvenlik kilidinde yakalandı.',
                  level: 'warning',
                  jobId: printJobId,
                  role: 'mutfak',
                  details: <String, dynamic>{
                    'actual_printer': wrongPrinter.displayName,
                    'actual_backend': wrongPrinter.backend.value,
                    'expected_printer': expectedKitchenPrinter.printer.name,
                    'expected_backend': expectedKitchenPrinter.backend,
                    'expected_host': expectedKitchenPrinter.host,
                    'expected_port': expectedKitchenPrinter.port,
                    'reason': _isBlockedKitchenDispatchPrinter(wrongPrinter)
                        ? 'stale_local_config_or_persisted_payload'
                        : 'resolved_printer_mismatch',
                  },
                )
                .ignore();
          }
          final correctedPrinter = await _printOrchestrator
              .resolveKitchenPrinterForStationOrRole(
                restaurantId: restaurantId,
                stationId: jobStationId,
                stationName: canonicalStationName,
                tableId: tableNo,
                orderId: _textValue(job['order_id'], fallback: printJobId),
                printJobId: printJobId,
                flowName: 'kitchen_order',
                source: 'order_print_job_service_final_guard',
                minimalSnapshot: true,
              );
          if (correctedPrinter != null &&
              _matchesExpectedKitchenResolution(
                correctedPrinter,
                expectedKitchenPrinter,
              )) {
            resolvedPrinterForDispatch = correctedPrinter;
            resolutionSourceForDispatch = 'kitchen_wrong_printer_corrected';
            resolvedPayload = Map<String, dynamic>.from(resolvedPayload);
            _stampResolvedKitchenPrinterPayload(
              resolvedPayload,
              printer: correctedPrinter,
              stationName: canonicalStationName,
            );
            resolvedPayload['selected_printer_id'] =
                correctedPrinter.printerRecordId ?? correctedPrinter.id;
            resolvedPayload['selected_printer_name'] =
                correctedPrinter.displayName;
            resolvedPayload['selected_printer_host'] =
                expectedKitchenPrinter.host;
            resolvedPayload['selected_printer_port'] =
                expectedKitchenPrinter.port;
            resolvedPayload['selected_printer_backend'] =
                correctedPrinter.backend.value;
            _printerEventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'kitchen_wrong_printer_corrected',
                  message:
                      'Mutfak işi DB Ethernet yazıcısına son güvenlik kilidinde düzeltildi.',
                  level: 'warning',
                  jobId: printJobId,
                  role: 'mutfak',
                  details: <String, dynamic>{
                    'new_printer': correctedPrinter.displayName,
                    'backend': correctedPrinter.backend.value,
                    'host': expectedKitchenPrinter.host,
                    'port': expectedKitchenPrinter.port,
                  },
                )
                .ignore();
          } else {
            resolvedPrinterForDispatch = null;
            resolutionSourceForDispatch = 'kitchen_runtime_guard_failed';
          }
        }
        resolvedPrinterForAttempt = resolvedPrinterForDispatch;
        resolvedPayloadForAttempt = resolvedPayload;
        resolutionSourceForAttempt = resolutionSourceForDispatch;

        final requestPath = _resolvePrinterRoute(resolvedPayload);
        final baseUri = _resolvePrinterBaseUri(resolvedPayload);
        requestUrl = baseUri.replace(path: requestPath).toString();

        if (resolvedPrinterForDispatch == null) {
          _printerEventLogService
              .append(
                restaurantId: restaurantId,
                event: 'printer_resolution_failed',
                message: expectedKitchenPrinter?.isTcp == true
                    ? 'Mutfak fişi yazdırılamadı: mutfak yazıcısı Ethernet olarak atanmış ama runtime çözümleme başarısız.'
                    : 'Mutfak fişi yazdırılamadı: yazıcı çözümlenemedi.',
                level: 'error',
                jobId: printJobId,
                role: 'mutfak',
                details: <String, dynamic>{
                  'printer_resolution_failed': true,
                  'print_job_id': printJobId,
                  'job_type': _textValue(
                    job['job_type'] ?? payload['job_type'],
                    fallback: '',
                  ),
                  'station_id': jobStationId,
                  'station_name': canonicalStationName,
                  'requested_printer_id': printerId,
                  'resolution_source': resolutionSourceForDispatch,
                  'expected_printer': expectedKitchenPrinter?.printer.name,
                  'expected_backend': expectedKitchenPrinter?.backend,
                  'expected_host': expectedKitchenPrinter?.host,
                  'expected_port': expectedKitchenPrinter?.port,
                  'status': 'failed',
                },
              )
              .ignore();
          failedJobCount += 1;
          failureMessages.add('$area/$printerName: printer_not_found');
          await _markPrintJobFailed(
            printJobId,
            requestUrl: requestUrl,
            error: expectedKitchenPrinter?.isTcp == true
                ? 'kitchen_runtime_guard_failed'
                : 'printer_not_found',
          );
          logPrintPerf('kitchen_order', <String, Object?>{
            'tap_at': tapAt,
            'kitchen_payload_build_ms': kitchenPayloadBuildMs,
            'print_dispatch_ms': watch.elapsedMilliseconds,
            'bridge_request_ms': bridgeRequestMs,
            'total_ms': watch.elapsedMilliseconds,
            'total_submit_to_print_ms': watch.elapsedMilliseconds,
            'print_job_id': printJobId,
            'layer': 'order_print_job_service',
            'ok': false,
            'error': 'printer_not_found',
          });
          continue;
        }
        final printer = resolvedPrinterForDispatch;
        final dispatchStartedAt = DateTime.now();
        final idempotencyKey = kitchenPrintIdempotencyKeyFromJob(
          restaurantId: restaurantId,
          job: job,
          payload: resolvedPayload,
        );
        await _markPrintJobPrinting(
          printJobId,
          dispatchStartedAt: dispatchStartedAt,
          payload: resolvedPayload,
        );
        debugPrint(
          '[KITCHEN_PHYSICAL_DISPATCH_ATTEMPT] '
          'job_id=$printJobId '
          'order_id=${_logValue(job['order_id'])} '
          'station=$canonicalStationName '
          'idempotency_key=$idempotencyKey '
          'dispatch_source=immediate '
          'printer=${printer.displayName} '
          'backend=${printer.backend.value} '
          'host=${resolvedPayload['selected_printer_host'] ?? resolvedPayload['host'] ?? resolvedPayload['ip_address'] ?? '-'} '
          'port=${resolvedPayload['selected_printer_port'] ?? resolvedPayload['port'] ?? '-'}',
        );
        final bridgeWatch = Stopwatch()..start();
        logKitchenFinalBeforeBridge(
          path: 'print_jobs_legacy_rpc',
          payload: resolvedPayload,
        );
        final physicalResult = await _printOrchestrator.printPhysicalToPrinter(
          printer,
          PrintPayload.fromQueuedJob(resolvedPayload),
          restaurantId: restaurantId,
          flowName: 'kitchen_order',
          flowType: _textValue(
            job['job_type'] ?? resolvedPayload['job_type'],
            fallback: 'kitchen_order',
          ),
          source: 'order_print_job_service',
          printJobId: printJobId,
        );
        bridgeRequestMs = bridgeWatch.elapsedMilliseconds;
        printDispatchMs = watch.elapsedMilliseconds;
        logPrintPerf('kitchen_order', <String, Object?>{
          'tap_at': tapAt,
          'kitchen_payload_build_ms': kitchenPayloadBuildMs,
          'print_dispatch_ms': printDispatchMs,
          'bridge_request_ms': bridgeRequestMs,
          'total_ms': watch.elapsedMilliseconds,
          'total_submit_to_print_ms': watch.elapsedMilliseconds,
          'print_job_id': printJobId,
          'layer': 'order_print_job_service',
          'ok': physicalResult.ok,
          if (!physicalResult.ok)
            'error': physicalResult.technicalMessage ?? physicalResult.message,
        });
        _logKitchen(
          'Dispatch',
          'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'printerId=${printer.id} durationMs=${watch.elapsedMilliseconds} '
              'encoding=${resolvedPayload['encoding'] ?? '-'} '
              'esc_t=${resolvedPayload['esc_t_value'] ?? resolvedPayload['codepage'] ?? '-'} '
              'esc_r=${resolvedPayload['esc_r_value'] ?? '-'} '
              'profileMissing=${resolvedPayload['encoding_profile_missing'] == true}',
        );
        if (!physicalResult.ok) {
          final failureMessage =
              physicalResult.technicalMessage ?? physicalResult.message;
          _printerEventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_physical_print_failed',
                message: 'Ethernet mutfak fişi yazdırılamadı.',
                level: 'error',
                jobId: printJobId,
                role: 'mutfak',
                printerId: printer.printerRecordId ?? printer.id,
                queueName: printer.queueName,
                backend: printer.backend.value,
                details: <String, dynamic>{
                  'print_job_id': printJobId,
                  'station_id': jobStationId,
                  'station_name': canonicalStationName,
                  'selected_printer_id': printer.printerRecordId ?? printer.id,
                  'selected_printer_name': printer.displayName,
                  'backend': printer.backend.value,
                  'host': _textValue(
                    resolvedPayload['host'] ??
                        resolvedPayload['ip_address'] ??
                        resolvedPayload['ipAddress'],
                  ),
                  'port': _textValue(resolvedPayload['port']),
                  'error': failureMessage,
                  'bridge_status': physicalResult.status,
                  'bridge_response': physicalResult.raw,
                  'reason': 'printPhysicalToPrinter_returned_not_ok',
                },
              )
              .ignore();
          if (_isConnectionError(
            Exception(
              physicalResult.technicalMessage ?? physicalResult.message,
            ),
          )) {
            if (_shouldFailTcpKitchenAfterDirectRetry(job, printer)) {
              failedJobCount += 1;
              failureMessages.add(
                '$area/$printerName: Ethernet mutfak fişi yazdırılamadı. /print/kitchen bridge hatası.',
              );
              await _markPrintJobFailed(
                printJobId,
                requestUrl: requestUrl,
                error:
                    'Ethernet mutfak fişi yazdırılamadı. /print/kitchen bridge hatası. $failureMessage',
              );
              continue;
            }
            pendingForHubJobIds.add(printJobId);
            _printerEventLogService
                .append(
                  restaurantId: restaurantId,
                  event: 'kitchen_job_pending_for_hub',
                  message:
                      'Mutfak fişi hub\'a devredildi; fiziksel baskı henüz tamamlanmadı.',
                  jobId: printJobId,
                  role: 'mutfak',
                  printerId: printer.printerRecordId ?? printer.id,
                  queueName: printer.queueName,
                  backend: printer.backend.value,
                  details: <String, dynamic>{
                    'handoff_to_hub': true,
                    'printer_not_printed_yet': true,
                    'print_pending_reason': failureMessage,
                    'print_job_id': printJobId,
                    'station_id': jobStationId,
                    'station_name': _textValue(
                      resolvedPayload['station_name'] ?? area,
                      fallback: area,
                    ),
                    'resolution_source': preparedPayload.resolutionSource,
                    'selected_printer_id':
                        printer.printerRecordId ?? printer.id,
                    'selected_printer_name': printer.displayName,
                    'backend': printer.backend.value,
                    'host': _textValue(
                      resolvedPayload['host'] ??
                          resolvedPayload['ip_address'] ??
                          resolvedPayload['ipAddress'],
                    ),
                    'port': _textValue(resolvedPayload['port']),
                    'status': 'pending_for_hub',
                    'reason': failureMessage,
                  },
                )
                .ignore();
            await _resetPrintJobToPending(
              printJobId,
              requestUrl: requestUrl,
              error: failureMessage,
            );
            dispatchedJobCount += 1;
            _logKitchen(
              'Dispatch',
              'orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
                  'printerId=${printer.id} printerName=${printer.displayName} '
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
                'printerId=${printer.id} printerName=${printer.displayName} itemCount=$itemCount '
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
          payload: resolvedPayload,
        );
        debugPrint(
          '[KITCHEN_PHYSICAL_DISPATCH_COMPLETED] '
          'job_id=$printJobId '
          'idempotency_key=$idempotencyKey '
          'completed_at=${DateTime.now().toIso8601String()}',
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
          _printerEventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_physical_print_failed',
                message: 'Ethernet mutfak fişi yazdırılamadı.',
                level: 'error',
                jobId: printJobId,
                role: 'mutfak',
                details: <String, dynamic>{
                  'print_job_id': printJobId,
                  'station_id': jobStationId,
                  'station_name': area,
                  'selected_printer_id': printerId,
                  'selected_printer_name': printerName,
                  'error': failureMessage,
                  'reason': 'printPhysicalToPrinter_exception',
                },
              )
              .ignore();
          final retryPrinter = resolvedPrinterForAttempt;
          if (retryPrinter == null) {
            failedJobCount += 1;
            failureMessages.add(
              '$area/$printerName: Ethernet mutfak fişi yazdırılamadı. /print/kitchen bridge hatası.',
            );
            await _markPrintJobFailed(
              printJobId,
              requestUrl: requestUrl,
              error:
                  'Ethernet mutfak fişi yazdırılamadı. /print/kitchen bridge hatası. $failureMessage',
            );
            continue;
          }
          if (_shouldFailTcpKitchenAfterDirectRetry(job, retryPrinter)) {
            failedJobCount += 1;
            failureMessages.add(
              '$area/$printerName: Ethernet mutfak fişi yazdırılamadı. /print/kitchen bridge hatası.',
            );
            await _markPrintJobFailed(
              printJobId,
              requestUrl: requestUrl,
              error:
                  'Ethernet mutfak fişi yazdırılamadı. /print/kitchen bridge hatası. $failureMessage',
            );
            logPrintPerf('kitchen_order', <String, Object?>{
              'tap_at': tapAt,
              'kitchen_payload_build_ms': kitchenPayloadBuildMs,
              'print_dispatch_ms': watch.elapsedMilliseconds,
              'bridge_request_ms': bridgeRequestMs,
              'total_ms': watch.elapsedMilliseconds,
              'total_submit_to_print_ms': watch.elapsedMilliseconds,
              'print_job_id': printJobId,
              'layer': 'order_print_job_service',
              'ok': false,
              'error': failureMessage,
            });
            continue;
          }
          pendingForHubJobIds.add(printJobId);
          _printerEventLogService
              .append(
                restaurantId: restaurantId,
                event: 'kitchen_job_pending_for_hub',
                message:
                    'Mutfak fişi hub\'a devredildi; fiziksel baskı henüz tamamlanmadı.',
                jobId: printJobId,
                role: 'mutfak',
                details: <String, dynamic>{
                  'handoff_to_hub': true,
                  'printer_not_printed_yet': true,
                  'print_pending_reason': failureMessage,
                  'print_job_id': printJobId,
                  'station_id': jobStationId,
                  'station_name': area,
                  'resolution_source': resolutionSourceForAttempt,
                  'backend': retryPrinter.backend.value,
                  'host': _textValue(
                    resolvedPayloadForAttempt?['host'] ??
                        resolvedPayloadForAttempt?['ip_address'] ??
                        resolvedPayloadForAttempt?['ipAddress'],
                  ),
                  'port': _textValue(resolvedPayloadForAttempt?['port']),
                  'status': 'pending_for_hub',
                  'reason': failureMessage,
                },
              )
              .ignore();
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
        logPrintPerf('kitchen_order', <String, Object?>{
          'tap_at': tapAt,
          'kitchen_payload_build_ms': kitchenPayloadBuildMs,
          'print_dispatch_ms': watch.elapsedMilliseconds,
          'bridge_request_ms': bridgeRequestMs,
          'total_ms': watch.elapsedMilliseconds,
          'total_submit_to_print_ms': watch.elapsedMilliseconds,
          'print_job_id': printJobId,
          'layer': 'order_print_job_service',
          'ok': false,
          'error': failureMessage,
        });
      }
    }

    return _KitchenPrintDispatchOutcome(
      dispatchedJobCount: dispatchedJobCount,
      failedJobCount: failedJobCount,
      failureMessages: failureMessages,
      handoffToHub: pendingForHubJobIds.isNotEmpty,
      printerNotPrintedYet: pendingForHubJobIds.isNotEmpty,
      pendingReason: pendingForHubJobIds.isNotEmpty
          ? 'reset_pending_for_hub'
          : null,
      pendingForHubJobIds: pendingForHubJobIds,
      dispatchPath: pendingForHubJobIds.isNotEmpty ? 'pending_for_hub' : '',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPrintJobsByIds(
    List<String> printJobIds,
  ) async {
    if (printJobIds.isEmpty) return const <Map<String, dynamic>>[];
    final rows = await _client
        .from('print_jobs')
        .select(
          'id, restaurant_id, order_id, station_id, printer_id, job_type, payload, status, last_error',
        )
        .inFilter('id', printJobIds);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Future<void> _markPrintJobPrinting(
    String printJobId, {
    required DateTime dispatchStartedAt,
    Map<String, dynamic>? payload,
  }) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'printing',
          'last_error': null,
          'dispatch_started_at': dispatchStartedAt.toIso8601String(),
          if (payload?['printer_record_id'] != null)
            'printer_id': payload!['printer_record_id'],
          ...?payload == null ? null : <String, dynamic>{'payload': payload},
        })
        .eq('id', printJobId)
        .inFilter('status', ['claimed', 'pending']);
  }

  Future<void> _markPrintJobCompleted(
    String printJobId, {
    required DateTime completedAt,
    Map<String, dynamic>? bridgeResult,
    Map<String, dynamic>? payload,
  }) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'completed',
          'last_error': null,
          'printed_at': completedAt.toIso8601String(),
          'completed_at': completedAt.toIso8601String(),
          if (payload?['printer_record_id'] != null)
            'printer_id': payload!['printer_record_id'],
          ...?payload == null ? null : <String, dynamic>{'payload': payload},
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

  Future<void> _markPrintJobDedupSkipped(
    String printJobId, {
    required String existingJobId,
    required String idempotencyKey,
  }) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'completed',
          'last_error':
              'duplicate_same_order_station_revision existing_job_id=$existingJobId '
              'idempotency_key=$idempotencyKey',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', printJobId);
  }

  Future<List<String>> _suppressDuplicateKitchenJobs({
    required String restaurantId,
    required String traceId,
    required int tableNumber,
    required String jobType,
    required List<String> printJobIds,
    required Map<String, Map<String, dynamic>> jobsById,
  }) async {
    if (printJobIds.length <= 1) return printJobIds;
    final keysByJobId = <String, String>{};
    for (final printJobId in printJobIds) {
      final job = jobsById[printJobId];
      if (job == null) continue;
      final payload = job['payload'] is Map
          ? Map<String, dynamic>.from(job['payload'] as Map)
          : const <String, dynamic>{};
      keysByJobId[printJobId] = kitchenPrintIdempotencyKeyFromJob(
        restaurantId: restaurantId,
        job: job,
        payload: payload,
      );
    }
    final deduped = dedupeKitchenJobIdsByKey(keysByJobId);
    if (deduped.duplicateOfByJobId.isEmpty) return printJobIds;
    for (final entry in deduped.duplicateOfByJobId.entries) {
      final duplicateJobId = entry.key;
      final existingJobId = entry.value;
      final idempotencyKey = keysByJobId[duplicateJobId] ?? '';
      debugPrint(
        '[KITCHEN_JOB_DEDUP_SKIPPED] '
        'existing_job_id=$existingJobId '
        'idempotency_key=$idempotencyKey '
        'reason=duplicate_same_order_station_revision',
      );
      _printerEventLogService
          .append(
            restaurantId: restaurantId,
            event: 'kitchen_job_dedup_skipped',
            message:
                'Aynı mutfak fişi tekrar gönderilmek üzereydi, sistem engelledi.',
            jobId: duplicateJobId,
            role: 'mutfak',
            details: <String, dynamic>{
              'traceId': traceId,
              'tableNumber': tableNumber,
              'jobType': jobType,
              'existing_job_id': existingJobId,
              'idempotency_key': idempotencyKey,
              'reason': 'duplicate_same_order_station_revision',
            },
          )
          .ignore();
      await _markPrintJobDedupSkipped(
        duplicateJobId,
        existingJobId: existingJobId,
        idempotencyKey: idempotencyKey,
      );
    }
    return deduped.primaryJobIds;
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

  /// Desktop/web on Windows/macOS/Linux can reach the local bridge directly.
  bool get _canDirectDispatch {
    if (kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;
    }
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

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

  bool _shouldFailTcpKitchenAfterDirectRetry(
    Map<String, dynamic> job,
    UnifiedPrinterModel resolvedPrinter,
  ) {
    if (resolvedPrinter.backend != DesktopPrinterBackend.tcp) return false;
    final lastError = _textValue(job['last_error'], fallback: '').toLowerCase();
    return lastError.contains('direct_dispatch_failed');
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
    Map<String, String>? stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
    String? tableAreaName,
    String? kitchenTicketHeaderOverride,
  }) {
    final orderId = _textValue(job['order_id'] ?? payload['order_id']);
    final tableNo = _resolveTableNo(
      payload,
      fallbackTableNumber: fallbackTableNumber,
    );
    final stationId = _textValue(job['station_id'] ?? payload['station_id']);
    final tableAreaOnly = _textValue(payload['table_area_name'], fallback: '');
    final legacyAreaName = _textValue(payload['area_name'], fallback: '');
    final diningArea = tableAreaOnly.isNotEmpty
        ? tableAreaOnly
        : (KitchenTicketHeaderResolver.isDiningAreaStationLabel(legacyAreaName)
              ? legacyAreaName
              : '');
    if (diningArea.isNotEmpty &&
        KitchenTicketHeaderResolver.isDiningAreaStationLabel(diningArea)) {
      kitchenPrintPayloadLog(
        'reject_table_area_header',
        extra: {
          'area': diningArea,
          'reason': 'table_area_is_not_kitchen_station',
        },
      );
    }

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
    final stationHeader =
        KitchenTicketHeaderResolver.finalizeKitchenTicketHeader(
          overrideHeader: kitchenTicketHeaderOverride,
          rawItems: rawItems,
          payload: payload,
          stationId: stationId,
          stationNamesById: stationNamesById,
          stationCodesById: stationCodesById,
          productStationByProductId: productStationByProductId,
          tableAreaName: tableAreaName ?? diningArea,
        );
    var fallbackReason = 'resolved';
    if (stationHeader == kKitchenGeneralStationLabel) {
      fallbackReason = stationId.isEmpty
          ? 'no_station_mapping'
          : 'station_cache_missing_or_dining_label';
    }
    kitchenPrintPayloadLog(
      'ticket_header',
      extra: {
        'header': stationHeader,
        'stationName': stationHeader,
        'tableAreaName': diningArea.isEmpty ? '-' : diningArea,
        'fallbackReason': fallbackReason,
      },
    );

    _logKitchen(
      'Payload',
      'buildStart orderId=$orderId tableNo=$tableNo area=$stationHeader '
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
            'missingItems orderId=$orderId tableNo=$tableNo area=$stationHeader '
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
        area: stationHeader,
        targetStationId: skipStationFilter ? '' : stationId,
      );
      if (kitchenItem == null) {
        droppedItemCount += 1;
        _logKitchen(
          'Payload',
          'missingItems orderId=$orderId tableNo=$tableNo area=$stationHeader '
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
        'emptyItemsFallback orderId=$orderId tableNo=$tableNo area=$stationHeader '
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
          area: stationHeader,
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
        'WARN_EMPTY_ITEMS orderId=$orderId tableNo=$tableNo area=$stationHeader '
            'originalItemCount=$originalItemCount droppedItemCount=$droppedItemCount '
            'itemSource=$itemSourceLabel stationId=${stationId.isEmpty ? '<null>' : stationId} '
            'payloadItemCount=${payloadItems.length} '
            'sourceItemCount=${sourceItems?.length ?? 0} '
            'ACTION=kitchen_ticket_will_print_with_no_items',
      );
    }

    _logKitchen(
      'Payload',
      'buildSuccess orderId=$orderId tableNo=$tableNo area=$stationHeader '
          'originalItemCount=$originalItemCount printedItemCount=${items.length} '
          'droppedItemCount=$droppedItemCount serviceItemIds=${serviceItemIds.isEmpty ? '-' : serviceItemIds.join(",")} '
          'plateCount=$plateCount itemSource=$itemSourceLabel',
    );

    final built = <String, dynamic>{
      'title': 'MUTFAK SIPARISI',
      'store_name': _textValue(
        payload['restaurant_name'] ?? payload['store_name'],
        fallback: 'Restoran',
      ),
      'order_id': orderId,
      'order_no': resolveKitchenPrintedOrderNo(payload),
      'daily_order_no': payload['daily_order_no'] ?? '',
      'kitchen_order_no': payload['kitchen_order_no'] ?? '',
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
      'table_area_name': diningArea,
      'kitchen_ticket_header': stationHeader,
      'station_name': stationHeader,
      'area_name': stationHeader,
      if (stationId.isNotEmpty)
        'station_code':
            stationCodesById?[stationId] ?? _textValue(payload['station_code']),
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
      'render_mode': 'text',
      'items': items,
    };
    stampKitchenOrderNumberFields(built);
    detectTableAreaUsedAsHeader(built, where: '_buildKitchenPayload');
    return built;
  }

  Map<String, dynamic> _normalizeKitchenSourceItem(Map<String, dynamic> item) {
    final normalized = MixedServiceOrder.normalizeOrderItem(<String, dynamic>{
      'product_id':
          item['product_id'] ?? item['order_item_id'] ?? item['productId'],
      'name': item['name'] ?? item['product_name'] ?? item['item_name'],
      'item_name': item['item_name'] ?? item['name'] ?? item['product_name'],
      'product_name': item['product_name'],
      'display_label': item['display_label'],
      'label': item['label'],
      'print_label': item['print_label'],
      'pricing_mode': item['pricing_mode'],
      'selected_grams': item['selected_grams'] ?? item['selectedGrams'],
      'selected_weight_grams':
          item['selected_weight_grams'] ?? item['selectedWeightGrams'],
      'selected_size_name':
          item['selected_size_name'] ?? item['selectedSizeName'],
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
    final baseName = GarsonProductSelection.printItemBaseName(item);
    final printLabel = GarsonProductSelection.resolvePrintItemLabel(item);
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
              'itemId=$itemId itemName=$printLabel reason=child_station_mismatch '
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
      'name': printLabel,
      'display_label': printLabel,
      'quantity': _intValue(item['quantity'], fallback: 1),
    };
    if (baseName.isNotEmpty && baseName != printLabel) {
      kitchenItem['product_name'] = baseName;
    }
    final amountLabel = GarsonProductSelection.resolvePrintItemAmountLabel(
      item,
    );
    final pricingMode = item['pricing_mode']?.toString().trim() ?? '';
    if (pricingMode.isNotEmpty) {
      kitchenItem['pricing_mode'] = pricingMode;
    }
    final selectedGrams = item['selected_grams'] ?? item['selectedGrams'];
    if (selectedGrams != null) {
      kitchenItem['selected_grams'] = selectedGrams;
    }
    final selectedWeightGrams =
        item['selected_weight_grams'] ?? item['selectedWeightGrams'];
    if (selectedWeightGrams != null) {
      kitchenItem['selected_weight_grams'] = selectedWeightGrams;
    }
    final selectedSizeName =
        item['selected_size_name'] ?? item['selectedSizeName'];
    if (selectedSizeName != null &&
        selectedSizeName.toString().trim().isNotEmpty) {
      kitchenItem['selected_size_name'] = selectedSizeName;
    }
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
    GarsonProductSelection.logGarsonPrintItemLabel(
      path: 'kitchen',
      item: item,
      finalPrintName: printLabel,
    );

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
    final printLabel = GarsonProductSelection.resolvePrintItemLabel(child);
    final baseName = GarsonProductSelection.printItemBaseName(child);
    final payload = <String, dynamic>{
      'id': _kitchenItemId(child),
      'name': printLabel,
      'display_label': printLabel,
      'quantity': _intValue(child['quantity'], fallback: 1),
    };
    if (baseName.isNotEmpty && baseName != printLabel) {
      payload['product_name'] = baseName;
    }
    final amountLabel = GarsonProductSelection.resolvePrintItemAmountLabel(
      child,
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

  void _stampResolvedKitchenPrinterPayload(
    Map<String, dynamic> payload, {
    required UnifiedPrinterModel printer,
    required String stationName,
  }) {
    final printerPayload = _printOrchestrator.buildDispatchPrinterPayload(
      printer,
    );
    payload['printer'] = printerPayload;
    payload['printer_role'] = 'mutfak';
    payload['printer_id'] = printer.id;
    payload['printer_name'] = printer.displayName;
    payload['printer_queue'] = printer.queueName;
    payload['printer_backend'] = printer.backend.value;
    payload['backend'] = printer.backend.value;
    payload['transportType'] =
        printerPayload['transportType'] ?? printer.backend.value;
    payload['transport_type'] =
        printerPayload['transport_type'] ??
        payload['transportType'] ??
        printer.backend.value;
    payload['printer_record_id'] =
        printer.printerRecordId ??
        printerPayload['printer_record_id'] ??
        payload['printer_record_id'];
    payload['station_name'] = stationName;
    if (printer.backend == DesktopPrinterBackend.tcp) {
      final host =
          (printerPayload['host'] ??
                  printerPayload['ip_address'] ??
                  printerPayload['ipAddress'])
              ?.toString() ??
          '';
      final port = printerPayload['port'];
      if (host.isNotEmpty) {
        payload['host'] = host;
        payload['ip_address'] = host;
        payload['ipAddress'] = host;
      }
      payload['port'] = port;
      payload['paper_width_mm'] =
          printerPayload['paper_width_mm'] ?? payload['paper_width_mm'] ?? 80;
      payload['auto_cut'] =
          printerPayload['auto_cut'] ?? payload['auto_cut'] ?? true;
    }
  }

  String? _printerHostForPayload(UnifiedPrinterModel printer) {
    final raw = printer.raw;
    return (raw['host'] ?? raw['ip_address'] ?? raw['ipAddress'])?.toString();
  }

  int? _printerPortForPayload(UnifiedPrinterModel printer) {
    final rawPort = printer.raw['port'] ?? printer.raw['tcp_port'];
    if (rawPort is int) return rawPort;
    return int.tryParse(rawPort?.toString() ?? '');
  }

  void _logOrderPrintJobCreate({
    required String stationName,
    required String stationId,
    required UnifiedPrinterModel printer,
  }) {
    debugPrint('[PrinterMapping][current_before_order]');
    debugPrint('receipt=-');
    debugPrint(
      'kitchen=${printer.displayName} backend=${printer.backend.value}',
    );
    debugPrint('[OrderPrintJob][create]');
    debugPrint('documentType=kitchen');
    debugPrint('printerRole=mutfak');
    debugPrint('stationName=${stationName.isEmpty ? '-' : stationName}');
    debugPrint('stationId=${stationId.isEmpty ? '-' : stationId}');
    debugPrint('resolvedPrinterId=${printer.id}');
    debugPrint('backend=${printer.backend.value}');
    debugPrint('host=${_printerHostForPayload(printer) ?? '-'}');
    debugPrint('port=${_printerPortForPayload(printer)?.toString() ?? '-'}');
  }

  void _logOrderPrintJobPersistedPayload(Map<String, dynamic> payload) {
    debugPrint('[KitchenPrintJob][persisted_payload]');
    debugPrint('documentType=${payload['document_type'] ?? 'kitchen'}');
    debugPrint('printerRole=${payload['printer_role'] ?? 'mutfak'}');
    debugPrint('printer_id=${payload['printer_id'] ?? '-'}');
    debugPrint(
      'backend=${payload['backend'] ?? payload['printer_backend'] ?? '-'}',
    );
    debugPrint(
      'host=${payload['host'] ?? payload['ip_address'] ?? payload['ipAddress'] ?? '-'}',
    );
    debugPrint('port=${payload['port'] ?? '-'}');
    debugPrint('paperWidthMm=${payload['paper_width_mm'] ?? '-'}');
    debugPrint(
      'printerProfile=${payload['printer_profile'] ?? payload['printer_profile_id'] ?? '-'}',
    );
    debugPrint('renderMode=${payload['render_mode'] ?? '-'}');
  }

  void _logOrderPrintJobDispatchLoaded(Map<String, dynamic> payload) {
    debugPrint('[DesktopPrintHub][loaded_job]');
    debugPrint('documentType=${payload['document_type'] ?? '-'}');
    debugPrint('printer_id=${payload['printer_id'] ?? '-'}');
    debugPrint(
      'backend=${payload['backend'] ?? payload['printer_backend'] ?? '-'}',
    );
    debugPrint(
      'host=${payload['host'] ?? payload['ip_address'] ?? payload['ipAddress'] ?? payload['target_host'] ?? '-'}',
    );
    debugPrint('port=${payload['port'] ?? payload['target_port'] ?? '-'}');
  }

  bool _isBlockedKitchenDispatchPrinter(UnifiedPrinterModel printer) {
    if (printer.backend == DesktopPrinterBackend.cups ||
        printer.backend == DesktopPrinterBackend.usbDirect) {
      return true;
    }
    final text = '${printer.id} ${printer.queueName} ${printer.displayName}'
        .toLowerCase();
    return text.contains('pos58') || text.contains('stmicroelectronics');
  }

  bool _matchesExpectedKitchenResolution(
    UnifiedPrinterModel? printer,
    ExpectedKitchenPrinterResolution expected,
  ) {
    if (printer == null) {
      return false;
    }
    final recordId = printer.printerRecordId?.trim() ?? '';
    if (recordId.isNotEmpty && recordId == expected.printer.id) {
      return true;
    }
    if (expected.isTcp) {
      return _printerHostForPayload(printer) == expected.host &&
          _printerPortForPayload(printer) == expected.port;
    }
    return printer.queueName.trim().toLowerCase() ==
        expected.queue.trim().toLowerCase();
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
    _synthesizeTcpPayloadMetadata(payload);
    final printerId = _textValue(
      payload['printer_record_id'] ??
          row['printer_id'] ??
          payload['printer_id'],
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

  Future<void> _debugGarsonPrintConfigSnapshot({
    required String restaurantId,
    required List<Map<String, dynamic>> normalizedItems,
  }) async {
    try {
      final snapshot = await _printOrchestrator.loadSetupSnapshot(
        restaurantId: restaurantId,
        minimal: true,
        flowName: 'garson_submit_snapshot',
        source: 'order_print_job_service',
      );
      final receiptPrinter = snapshot.localConfig?.receiptSelection?.printer;
      final kitchenPrinter = snapshot.localConfig?.kitchenSelection?.printer;
      debugPrint('[GarsonPrint][role_config_snapshot]');
      debugPrint('receiptPrinterId=${receiptPrinter?.id ?? '-'}');
      debugPrint('receiptName=${receiptPrinter?.displayName ?? '-'}');
      debugPrint('receiptBackend=${receiptPrinter?.backend.value ?? '-'}');
      debugPrint(
        'receiptHost=${receiptPrinter == null ? '-' : _printerHostForPayload(receiptPrinter) ?? '-'}',
      );
      debugPrint(
        'receiptPort=${receiptPrinter == null ? '-' : _printerPortForPayload(receiptPrinter)?.toString() ?? '-'}',
      );
      debugPrint('kitchenPrinterId=${kitchenPrinter?.id ?? '-'}');
      debugPrint('kitchenName=${kitchenPrinter?.displayName ?? '-'}');
      debugPrint('kitchenBackend=${kitchenPrinter?.backend.value ?? '-'}');
      debugPrint(
        'kitchenHost=${kitchenPrinter == null ? '-' : _printerHostForPayload(kitchenPrinter) ?? '-'}',
      );
      debugPrint(
        'kitchenPort=${kitchenPrinter == null ? '-' : _printerPortForPayload(kitchenPrinter)?.toString() ?? '-'}',
      );

      final stationNames = _readCachedStationNames(restaurantId);
      final stationCodes = _readCachedStationCodes(restaurantId);
      final mappings = (await _printerRepository.fetchStationPrinterMappings(
        restaurantId,
      )).whereType<StationPrinterModel>().toList(growable: false);
      final stationsById = <String>{};
      for (final item in normalizedItems) {
        final stationId = _textValue(item['station_id']);
        if (stationId.isNotEmpty) {
          stationsById.add(stationId);
        }
      }
      debugPrint('[GarsonPrint][station_config_snapshot]');
      for (final stationId in stationsById) {
        final stationMappings =
            mappings
                .where((entry) => entry.stationId == stationId)
                .toList(growable: false)
              ..sort((a, b) {
                if (a.isPrimary != b.isPrimary) {
                  return a.isPrimary ? -1 : 1;
                }
                return a.createdAt.compareTo(b.createdAt);
              });
        final mapping = stationMappings.isEmpty ? null : stationMappings.first;
        final legacyPrinter = mapping == null
            ? null
            : await _printerRepository.getPrinterByRecordId(mapping.printerId);
        final stationName =
            stationNames[stationId] ??
            mapping?.stationName ??
            stationCodes[stationId] ??
            stationId;
        debugPrint(
          'station=$stationName printerId=${legacyPrinter?.code ?? legacyPrinter?.id ?? '-'} backend=${legacyPrinter?.connectionType ?? '-'} host=${legacyPrinter?.ipAddress ?? '-'} port=${legacyPrinter?.port?.toString() ?? '-'}',
        );
      }
    } catch (error, stackTrace) {
      _logKitchen(
        'ConfigSnapshot',
        'restaurantId=$restaurantId phase=failed error=$error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _synthesizeTcpPayloadMetadata(Map<String, dynamic> payload) {
    final printerId = _textValue(payload['printer_id']);
    final host = _textValue(
      payload['host'] ??
          payload['ip_address'] ??
          payload['ipAddress'] ??
          payload['target_host'],
    );
    final portRaw = payload['port'] ?? payload['target_port'];
    var port = portRaw is int
        ? portRaw
        : int.tryParse(portRaw?.toString() ?? '');
    if (printerId.toLowerCase().startsWith('tcp:')) {
      final parts = printerId.split(':');
      if (parts.length >= 3) {
        if (host.isEmpty) {
          payload['host'] = parts[1].trim();
          payload['ip_address'] = parts[1].trim();
          payload['ipAddress'] = parts[1].trim();
        }
        port ??= int.tryParse(parts[2].trim());
      }
    }
    final effectiveHost = _textValue(
      payload['host'] ?? payload['ip_address'] ?? payload['ipAddress'],
    );
    if (!printerId.toLowerCase().startsWith('tcp:') ||
        effectiveHost.isEmpty ||
        (port ?? 0) <= 0) {
      return;
    }
    payload['printer_backend'] = 'tcp';
    payload['backend'] = 'tcp';
    payload['transportType'] = 'ethernet';
    payload['transport_type'] = 'ethernet';
    payload['port'] = port;
    payload['paper_width_mm'] = payload['paper_width_mm'] ?? 80;
    payload['auto_cut'] = payload['auto_cut'] ?? true;
  }

  Map<String, String> _stationNamesFromItems(List<Map<String, dynamic>> items) {
    final map = <String, String>{};
    for (final item in items) {
      final stationId = item['station_id']?.toString().trim() ?? '';
      final stationName =
          KitchenTicketHeaderResolver.sanitizeProductionStationName(
            item['station_name']?.toString() ?? '',
          );
      if (stationId.isNotEmpty &&
          stationName.isNotEmpty &&
          stationName != kKitchenGeneralStationLabel) {
        map[stationId] = stationName;
      }
    }
    return map;
  }

  Map<String, String> _readCachedStationNames(String restaurantId) {
    final cachedAt = _stationNamesMemoryCachedAt[restaurantId];
    final cached = _stationNamesMemoryCache[restaurantId];
    if (cachedAt == null || cached == null) return const <String, String>{};
    if (DateTime.now().difference(cachedAt) > _stationNamesCacheTtl) {
      return const <String, String>{};
    }
    return Map<String, String>.from(cached);
  }

  Map<String, String> _readCachedStationCodes(String restaurantId) {
    final cachedAt = _stationNamesMemoryCachedAt[restaurantId];
    final cached = _stationCodesMemoryCache[restaurantId];
    if (cachedAt == null || cached == null) return const <String, String>{};
    if (DateTime.now().difference(cachedAt) > _stationNamesCacheTtl) {
      return const <String, String>{};
    }
    return Map<String, String>.from(cached);
  }

  Future<_KitchenStationNamesResolveResult>
  _resolveStationNamesForKitchenPrint({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required bool fastPath,
  }) async {
    final fromItems = _stationNamesFromItems(items);
    final merged = <String, String>{
      ..._readCachedStationNames(restaurantId),
      ...fromItems,
    };
    var fallbackReason = '';

    final missingIds = <String>{};
    for (final item in items) {
      final stationId = item['station_id']?.toString().trim() ?? '';
      if (stationId.isEmpty) continue;
      final hasName = merged[stationId]?.trim().isNotEmpty == true;
      final itemName =
          KitchenTicketHeaderResolver.sanitizeProductionStationName(
            item['station_name']?.toString() ?? '',
          );
      if (!hasName &&
          (itemName.isEmpty || itemName == kKitchenGeneralStationLabel)) {
        missingIds.add(stationId);
      }
    }

    if (fastPath) {
      if (missingIds.isNotEmpty) {
        fallbackReason = 'station_cache_missing';
        kitchenRoutingLog(
          'station_cache_missing',
          extra: {
            'restaurantId': restaurantId,
            'missingStationIds': missingIds.join(','),
          },
        );
      }
      return _KitchenStationNamesResolveResult(
        namesById: merged,
        fallbackReason: fallbackReason,
      );
    }

    if (missingIds.isNotEmpty) {
      final fetched = await _fetchStationNamesById(restaurantId);
      merged.addAll(fetched);
      _stationNamesMemoryCache[restaurantId] = Map<String, String>.from(merged);
      _stationNamesMemoryCachedAt[restaurantId] = DateTime.now();
    }

    return _KitchenStationNamesResolveResult(
      namesById: merged,
      fallbackReason: fallbackReason,
    );
  }

  Future<Map<String, String>> _fetchStationNamesById(
    String restaurantId,
  ) async {
    try {
      final rows = await _client
          .from('stations')
          .select('id,name,code')
          .eq('restaurant_id', restaurantId);
      final map = <String, String>{};
      final codes = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final id = row['id']?.toString().trim() ?? '';
        final name = row['name']?.toString().trim() ?? '';
        final code = row['code']?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          map[id] = KitchenTicketHeaderResolver.sanitizeProductionStationName(
            name,
          );
        }
        if (id.isNotEmpty && code.isNotEmpty) {
          codes[id] = code.toUpperCase();
        }
      }
      _stationNamesMemoryCache[restaurantId] = Map<String, String>.from(map);
      _stationCodesMemoryCache[restaurantId] = Map<String, String>.from(codes);
      _stationNamesMemoryCachedAt[restaurantId] = DateTime.now();
      KitchenTicketHeaderResolver.registerRestaurantStationCaches(
        restaurantId: restaurantId,
        stationNamesById: map,
        stationCodesById: codes,
      );
      return map;
    } catch (error, stackTrace) {
      _logKitchen(
        'StationLookup',
        'fetchFailed restaurantId=$restaurantId',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, String>{};
    }
  }

  List<_KitchenStationPrintGroup> _groupItemsByProductionStation(
    List<Map<String, dynamic>> items, {
    required Map<String, String> stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
  }) {
    final grouped = <String, _KitchenStationPrintGroup>{};
    for (final item in items) {
      logKitchenRoutingGroupInput(item);
      var stationId = item['station_id']?.toString().trim() ?? '';
      final productId = item['product_id']?.toString().trim() ?? '';
      final mapping = productId.isEmpty
          ? null
          : productStationByProductId?[productId];
      if (stationId.isEmpty &&
          mapping != null &&
          mapping.stationId.isNotEmpty) {
        stationId = mapping.stationId;
        item['station_id'] = stationId;
      }
      if (mapping != null && mapping.stationCode.isNotEmpty) {
        item['station_code'] = mapping.stationCode;
      } else if (stationId.isNotEmpty &&
          (stationCodesById?[stationId] ?? '').isNotEmpty) {
        item['station_code'] = stationCodesById![stationId]!;
      }
      final key = stationId.isEmpty ? '__general__' : stationId;
      final stationName =
          KitchenTicketHeaderResolver.resolveProductionHeaderForItem(
            item: item,
            stationNamesById: stationNamesById,
            stationCodesById: stationCodesById,
            productStationByProductId: productStationByProductId,
          );
      grouped
          .putIfAbsent(
            key,
            () => _KitchenStationPrintGroup(
              stationId: stationId,
              stationName: stationName,
              items: <Map<String, dynamic>>[],
            ),
          )
          .items
          .add(item);
      logKitchenRoutingGroupCreated(
        groupKey: key,
        stationId: stationId,
        stationName: stationName,
        stationCode: item['station_code']?.toString() ?? '',
        itemCount: grouped[key]!.items.length,
      );
    }
    if (grouped.isEmpty) {
      return <_KitchenStationPrintGroup>[
        _KitchenStationPrintGroup(
          stationId: '',
          stationName: kKitchenGeneralStationLabel,
          items: items,
        ),
      ];
    }
    return grouped.values.toList(growable: false);
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
