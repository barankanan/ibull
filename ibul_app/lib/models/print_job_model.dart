class PrintJobModel {
  const PrintJobModel({
    required this.id,
    required this.restaurantId,
    required this.orderId,
    this.stationId,
    this.printerId,
    required this.jobType,
    required this.status,
    required this.payload,
    required this.retryCount,
    this.lastError,
    this.printedAt,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String orderId;
  final String? stationId;
  final String? printerId;
  final String jobType;
  final String status;
  final Map<String, dynamic> payload;
  final int retryCount;
  final String? lastError;
  final DateTime? printedAt;
  final DateTime createdAt;

  factory PrintJobModel.fromMap(Map<String, dynamic> map) {
    final rawPayload = map['payload'];
    return PrintJobModel(
      id: map['id']?.toString() ?? '',
      restaurantId: map['restaurant_id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      stationId: map['station_id']?.toString(),
      printerId: map['printer_id']?.toString(),
      jobType: map['job_type']?.toString() ?? 'new_order',
      status: map['status']?.toString() ?? 'pending',
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : (rawPayload is Map
                ? Map<String, dynamic>.from(rawPayload)
                : <String, dynamic>{}),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
      printedAt: DateTime.tryParse(map['printed_at']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get tableName => payload['table_name']?.toString() ?? '-';
  String get stationName {
    final value = payload['station_name']?.toString().trim() ?? '';
    return value.isEmpty ? 'Genel' : value;
  }

  String get printerName {
    final value = payload['printer_name']?.toString().trim() ?? '';
    return value.isEmpty ? 'Yerel Yazici' : value;
  }

  String get orderNo =>
      payload['order_no']?.toString() ??
      payload['order_number']?.toString() ??
      '-';
  int get itemCount =>
      payload['items'] is List ? (payload['items'] as List).length : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'order_id': orderId,
      'station_id': stationId,
      'printer_id': printerId,
      'job_type': jobType,
      'status': status,
      'payload': payload,
      'retry_count': retryCount,
      'last_error': lastError,
      'printed_at': printedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
