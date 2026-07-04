import 'dart:math';

const restaurantOfflineCacheVersion = 1;
const restaurantOfflineOrderQueueVersion = 1;
const restaurantOfflinePrintQueueVersion = 1;

enum RestaurantConnectivityMode {
  online,
  supabaseUnreachable,
  bridgeUnreachable,
  offlineLocalMode,
  syncing,
}

enum RestaurantLocalOrderSyncStatus {
  localOnly,
  pendingSync,
  syncing,
  synced,
  syncFailed,
  conflict,
}

enum RestaurantLocalPrintJobStatus {
  created,
  queued,
  dispatching,
  printed,
  failed,
  retrying,
  cancelled,
}

class RestaurantLocalOrderRecord {
  const RestaurantLocalOrderRecord({
    required this.localOrderId,
    required this.restaurantId,
    required this.tableId,
    required this.tableName,
    required this.tableNumber,
    required this.waiterId,
    required this.waiterName,
    required this.items,
    required this.notes,
    required this.total,
    required this.stationGroups,
    required this.printStatus,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.remoteOrderId,
    this.syncError,
  });

  final String localOrderId;
  final String restaurantId;
  final String tableId;
  final String tableName;
  final int tableNumber;
  final String waiterId;
  final String waiterName;
  final List<Map<String, dynamic>> items;
  final String notes;
  final double total;
  final List<Map<String, dynamic>> stationGroups;
  final String printStatus;
  final RestaurantLocalOrderSyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? remoteOrderId;
  final String? syncError;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'local_order_id': localOrderId,
    'restaurant_id': restaurantId,
    'table_id': tableId,
    'table_name': tableName,
    'table_number': tableNumber,
    'waiter_id': waiterId,
    'waiter_name': waiterName,
    'items': items,
    'notes': notes,
    'total': total,
    'station_groups': stationGroups,
    'print_status': printStatus,
    'sync_status': syncStatus.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (remoteOrderId != null) 'remote_order_id': remoteOrderId,
    if (syncError != null) 'sync_error': syncError,
  };

  factory RestaurantLocalOrderRecord.fromJson(Map<String, dynamic> json) {
    return RestaurantLocalOrderRecord(
      localOrderId: json['local_order_id']?.toString() ?? '',
      restaurantId: json['restaurant_id']?.toString() ?? '',
      tableId: json['table_id']?.toString() ?? '',
      tableName: json['table_name']?.toString() ?? '',
      tableNumber: (json['table_number'] as num?)?.toInt() ?? 0,
      waiterId: json['waiter_id']?.toString() ?? '',
      waiterName: json['waiter_name']?.toString() ?? '',
      items: _readMapList(json['items']),
      notes: json['notes']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      stationGroups: _readMapList(json['station_groups']),
      printStatus: json['print_status']?.toString() ?? 'pending',
      syncStatus: RestaurantLocalOrderSyncStatus.values.firstWhere(
        (value) => value.name == json['sync_status']?.toString(),
        orElse: () => RestaurantLocalOrderSyncStatus.localOnly,
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      remoteOrderId: json['remote_order_id']?.toString(),
      syncError: json['sync_error']?.toString(),
    );
  }

  RestaurantLocalOrderRecord copyWith({
    RestaurantLocalOrderSyncStatus? syncStatus,
    String? printStatus,
    String? remoteOrderId,
    String? syncError,
    DateTime? updatedAt,
  }) {
    return RestaurantLocalOrderRecord(
      localOrderId: localOrderId,
      restaurantId: restaurantId,
      tableId: tableId,
      tableName: tableName,
      tableNumber: tableNumber,
      waiterId: waiterId,
      waiterName: waiterName,
      items: items,
      notes: notes,
      total: total,
      stationGroups: stationGroups,
      printStatus: printStatus ?? this.printStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteOrderId: remoteOrderId ?? this.remoteOrderId,
      syncError: syncError ?? this.syncError,
    );
  }
}

class RestaurantLocalPrintJobRecord {
  const RestaurantLocalPrintJobRecord({
    required this.localJobId,
    required this.restaurantId,
    required this.localOrderId,
    required this.tableId,
    required this.tableName,
    required this.documentType,
    required this.role,
    required this.station,
    required this.printerSnapshot,
    required this.payloadSnapshot,
    required this.status,
    required this.attempts,
    required this.createdAt,
    this.lastError,
    this.printedAt,
  });

  final String localJobId;
  final String restaurantId;
  final String localOrderId;
  final String tableId;
  final String tableName;
  final String documentType;
  final String role;
  final String station;
  final Map<String, dynamic> printerSnapshot;
  final Map<String, dynamic> payloadSnapshot;
  final RestaurantLocalPrintJobStatus status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? printedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'local_job_id': localJobId,
    'restaurant_id': restaurantId,
    'local_order_id': localOrderId,
    'table_id': tableId,
    'table_name': tableName,
    'document_type': documentType,
    'role': role,
    'station': station,
    'printer_snapshot': printerSnapshot,
    'payload_snapshot': payloadSnapshot,
    'status': status.name,
    'attempts': attempts,
    if (lastError != null) 'last_error': lastError,
    'created_at': createdAt.toIso8601String(),
    if (printedAt != null) 'printed_at': printedAt!.toIso8601String(),
  };

  factory RestaurantLocalPrintJobRecord.fromJson(Map<String, dynamic> json) {
    return RestaurantLocalPrintJobRecord(
      localJobId: json['local_job_id']?.toString() ?? '',
      restaurantId: json['restaurant_id']?.toString() ?? '',
      localOrderId: json['local_order_id']?.toString() ?? '',
      tableId: json['table_id']?.toString() ?? '',
      tableName: json['table_name']?.toString() ?? '',
      documentType: json['document_type']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      station: json['station']?.toString() ?? '',
      printerSnapshot: Map<String, dynamic>.from(
        json['printer_snapshot'] as Map? ?? const <String, dynamic>{},
      ),
      payloadSnapshot: Map<String, dynamic>.from(
        json['payload_snapshot'] as Map? ?? const <String, dynamic>{},
      ),
      status: RestaurantLocalPrintJobStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => RestaurantLocalPrintJobStatus.created,
      ),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      printedAt: DateTime.tryParse(json['printed_at']?.toString() ?? ''),
    );
  }

  RestaurantLocalPrintJobRecord copyWith({
    RestaurantLocalPrintJobStatus? status,
    int? attempts,
    String? lastError,
    DateTime? printedAt,
  }) {
    return RestaurantLocalPrintJobRecord(
      localJobId: localJobId,
      restaurantId: restaurantId,
      localOrderId: localOrderId,
      tableId: tableId,
      tableName: tableName,
      documentType: documentType,
      role: role,
      station: station,
      printerSnapshot: printerSnapshot,
      payloadSnapshot: payloadSnapshot,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      printedAt: printedAt ?? this.printedAt,
    );
  }
}

class RestaurantLocalCacheSnapshot {
  const RestaurantLocalCacheSnapshot({
    required this.restaurantId,
    required this.restaurantName,
    required this.sellerId,
    required this.storeCategory,
    required this.tables,
    required this.tableOrderSnapshots,
    required this.products,
    required this.stations,
    required this.printers,
    required this.stationPrinters,
    required this.printerRoles,
    required this.printerProfiles,
    required this.productStationMappings,
    required this.discoveredPrinters,
    required this.lastSetupSnapshot,
    required this.cachedAt,
  });

  final String restaurantId;
  final String restaurantName;
  final String sellerId;
  final String storeCategory;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> tableOrderSnapshots;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> stations;
  final List<Map<String, dynamic>> printers;
  final List<Map<String, dynamic>> stationPrinters;
  final Map<String, dynamic> printerRoles;
  final Map<String, dynamic> printerProfiles;
  final Map<String, dynamic> productStationMappings;
  final List<Map<String, dynamic>> discoveredPrinters;
  final Map<String, dynamic> lastSetupSnapshot;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': restaurantOfflineCacheVersion,
    'restaurant_id': restaurantId,
    'restaurant_name': restaurantName,
    'seller_id': sellerId,
    'store_category': storeCategory,
    'tables': tables,
    'table_order_snapshots': tableOrderSnapshots,
    'products': products,
    'stations': stations,
    'printers': printers,
    'station_printers': stationPrinters,
    'printer_roles': printerRoles,
    'printer_profiles': printerProfiles,
    'product_station_mappings': productStationMappings,
    'discovered_printers': discoveredPrinters,
    'last_setup_snapshot': lastSetupSnapshot,
    'cached_at': cachedAt.toIso8601String(),
  };

  factory RestaurantLocalCacheSnapshot.fromJson(Map<String, dynamic> json) {
    return RestaurantLocalCacheSnapshot(
      restaurantId: json['restaurant_id']?.toString() ?? '',
      restaurantName: json['restaurant_name']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      storeCategory: json['store_category']?.toString() ?? '',
      tables: _readMapList(json['tables']),
      tableOrderSnapshots: _readMapList(json['table_order_snapshots']),
      products: _readMapList(json['products']),
      stations: _readMapList(json['stations']),
      printers: _readMapList(json['printers']),
      stationPrinters: _readMapList(json['station_printers']),
      printerRoles: Map<String, dynamic>.from(
        json['printer_roles'] as Map? ?? const <String, dynamic>{},
      ),
      printerProfiles: Map<String, dynamic>.from(
        json['printer_profiles'] as Map? ?? const <String, dynamic>{},
      ),
      productStationMappings: Map<String, dynamic>.from(
        json['product_station_mappings'] as Map? ?? const <String, dynamic>{},
      ),
      discoveredPrinters: _readMapList(json['discovered_printers']),
      lastSetupSnapshot: Map<String, dynamic>.from(
        json['last_setup_snapshot'] as Map? ?? const <String, dynamic>{},
      ),
      cachedAt: DateTime.tryParse(json['cached_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

String newRestaurantLocalOrderId() =>
    'local-order-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

String newRestaurantLocalPrintJobId() =>
    'local-print-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

List<Map<String, dynamic>> _readMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
