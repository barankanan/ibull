import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mixed_service_order.dart';
import 'kitchen_routing_service.dart';
import 'local_print_service.dart';

class OrderPrintJobDispatchResult {
  const OrderPrintJobDispatchResult({
    required this.orderId,
    required this.orderNumber,
    required this.printJobCount,
    required this.raw,
    this.dispatchedJobCount = 0,
    this.failedJobCount = 0,
  });

  final String? orderId;
  final String? orderNumber;
  final int printJobCount;
  final Map<String, dynamic> raw;
  final int dispatchedJobCount;
  final int failedJobCount;
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
  }) : _client = client ?? Supabase.instance.client,
       _routingService = routingService ?? const KitchenRoutingService();

  final SupabaseClient _client;
  final KitchenRoutingService _routingService;

  Future<OrderPrintJobDispatchResult> dispatchNewOrder({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
    String jobType = 'new_order',
  }) async {
    final normalized = _routingService
        .normalizeItems(items)
        .map((item) => item.toPayloadMap())
        .toList(growable: false);

    if (normalized.isEmpty) {
      throw Exception('Print job oluşturmak için sipariş kalemi bulunamadı.');
    }

    _logKitchen(
      'Init',
      'restaurantId=$restaurantId tableNo=$tableNumber jobType=$jobType '
          'itemCount=${normalized.length} waiterId=${_logValue(waiterId)} '
          'waiterName=${_logValue(waiterName)}',
    );

    final response = await _client.rpc(
      'create_table_order_with_print_jobs',
      params: {
        'p_restaurant_id': restaurantId,
        'p_table_number': tableNumber,
        'p_items': normalized,
        'p_waiter_id': (waiterId == null || waiterId.isEmpty) ? null : waiterId,
        'p_waiter_name': waiterName,
        'p_notes': notes,
        'p_job_type': jobType,
        'p_order_type': 'table',
      },
    );

    final data = response is Map<String, dynamic>
        ? response
        : (response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{});
    final printJobIds = _extractPrintJobIds(data['print_job_ids']);

    _logKitchen(
      'Fetch',
      'restaurantId=$restaurantId tableNo=$tableNumber '
          'orderId=${_logValue(data['order_id'])} orderNo=${_logValue(data['order_number'])} '
          'printJobCount=${(data['print_job_count'] as num?)?.toInt() ?? 0} '
          'printJobIds=${printJobIds.isEmpty ? '-' : printJobIds.join(",")}',
    );

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
      raw: data,
      dispatchedJobCount: dispatchOutcome.dispatchedJobCount,
      failedJobCount: dispatchOutcome.failedJobCount,
    );
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
      'printJobs=${result.printJobCount} '
      'printed=${result.dispatchedJobCount} '
      'failed=${result.failedJobCount}',
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
      );
    }

    if (!kIsWeb) {
      _logKitchen(
        'Dispatch',
        'restaurantId=$restaurantId tableNo=$tableNumber '
            'orderId=${_logValue(orderId)} platform=non_web action=skip_local_dispatch '
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

      final payload = _jobPayload(job);
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
      final requestPath = _resolvePrinterRoute(payload);
      final baseUri = _resolvePrinterBaseUri(payload);
      final requestUrl = baseUri.replace(path: requestPath).toString();
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
            'requestUrl=$requestUrl itemAreaMap=$itemAreaMap',
      );

      await _markPrintJobPrinting(printJobId);
      final watch = Stopwatch()..start();
      final printService = LocalPrintService(baseUri: baseUri);
      try {
        _logKitchen(
          'Dispatch',
          'route=$requestPath orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'printerId=$printerId printerName=$printerName itemCount=$itemCount '
              'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl phase=start',
        );
        await printService.printKitchen(
          _buildKitchenPayload(
            job: job,
            payload: payload,
            fallbackTableNumber: tableNumber,
            sourceItems: sourceItems,
          ),
          path: requestPath,
        );
        await _markPrintJobPrinted(printJobId);
        dispatchedJobCount += 1;
        _logKitchen(
          'Dispatch',
          'route=$requestPath orderId=${_logValue(job['order_id'])} tableNo=$tableNo area=$area '
              'printerId=$printerId printerName=$printerName itemCount=$itemCount '
              'durationMs=${watch.elapsedMilliseconds} requestUrl=$requestUrl phase=success',
        );
      } catch (error, stackTrace) {
        failedJobCount += 1;
        final failureMessage = _compactError(error);
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
      } finally {
        printService.dispose();
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

  Future<void> _markPrintJobPrinting(String printJobId) async {
    await _client
        .from('print_jobs')
        .update({'status': 'printing', 'last_error': null})
        .eq('id', printJobId);
  }

  Future<void> _markPrintJobPrinted(String printJobId) async {
    await _client
        .from('print_jobs')
        .update({
          'status': 'printed',
          'last_error': null,
          'printed_at': DateTime.now().toIso8601String(),
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
    final rawItems = (sourceItems != null && sourceItems.isNotEmpty)
        ? sourceItems
        : _payloadItems(payload);
    final originalItemCount = rawItems.length;

    _logKitchen(
      'Payload',
      'buildStart orderId=$orderId tableNo=$tableNo area=$area '
          'originalItemCount=$originalItemCount source=${sourceItems != null && sourceItems.isNotEmpty ? 'source_items' : 'print_job_payload'}',
    );

    final items = <Map<String, dynamic>>[];
    final serviceItemIds = <String>{};
    var droppedItemCount = 0;
    var plateCount = 0;

    for (final rawItem in rawItems) {
      final normalized = _normalizeKitchenSourceItem(rawItem);
      final itemId = _kitchenItemId(normalized);
      final itemName = _kitchenItemName(normalized);
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

      if (stationId.isNotEmpty && !parentMatches && !hasMatchingChild) {
        droppedItemCount += 1;
        _logKitchen(
          'Payload',
          'missingItems orderId=$orderId tableNo=$tableNo area=$area '
              'itemId=$itemId itemName=$itemName reason=station_mismatch '
              'targetStationId=$stationId itemStationId=${_textValue(normalized['station_id'], fallback: '-')}',
        );
        continue;
      }

      final kitchenItem = _buildKitchenItemPayload(
        normalized,
        orderId: orderId,
        tableNo: tableNo,
        area: area,
        targetStationId: stationId,
      );
      if (kitchenItem == null) {
        droppedItemCount += 1;
        _logKitchen(
          'Payload',
          'missingItems orderId=$orderId tableNo=$tableNo area=$area '
              'itemId=$itemId itemName=$itemName reason=empty_after_filter',
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

    _logKitchen(
      'Payload',
      'buildSuccess orderId=$orderId tableNo=$tableNo area=$area '
          'originalItemCount=$originalItemCount printedItemCount=${items.length} '
          'droppedItemCount=$droppedItemCount serviceItemIds=${serviceItemIds.isEmpty ? '-' : serviceItemIds.join(",")} '
          'plateCount=$plateCount',
    );

    return <String, dynamic>{
      'title': 'MUTFAK SIPARISI',
      'order_id': orderId,
      'order_no': _textValue(
        payload['order_no'] ?? payload['order_number'],
        fallback: '-',
      ),
      'table_no': tableNo,
      'table_name': _textValue(
        payload['table_name'],
        fallback: 'Masa $fallbackTableNumber',
      ),
      'area_name': area,
      'waiter_name': _textValue(payload['waiter_name'], fallback: '-'),
      'job_type': _textValue(job['job_type'] ?? payload['job_type']),
      'datetime': _textValue(
        payload['created_at'],
        fallback: DateTime.now().toIso8601String(),
      ),
      'items': items,
    };
  }

  Map<String, dynamic> _normalizeKitchenSourceItem(Map<String, dynamic> item) {
    return MixedServiceOrder.normalizeOrderItem(<String, dynamic>{
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
    });
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
    final note = _textValue(
      item['general_note'] ?? item['note'] ?? item['notes'],
      fallback: '',
    );
    if (amountLabel.isNotEmpty) {
      kitchenItem['amount_label'] = amountLabel;
    }
    if (note.isNotEmpty) {
      kitchenItem['note'] = note;
    }

    if (filteredChildren.isEmpty) {
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
    final route = _textValue(
      payload['printer_target_route'] ??
          payload['target_route'] ??
          payload['printer_device_identifier'],
      fallback: '',
    );
    if (route.startsWith('/')) {
      return route;
    }
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
}
