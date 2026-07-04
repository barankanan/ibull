class PrintJobModel {
  static const int maxManualRetries = 8;

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
    this.orderSavedAt,
    this.printJobCreatedAt,
    this.hubJobReceivedAt,
    this.claimedAt,
    this.dispatchStartedAt,
    this.printerWriteStartedAt,
    this.completedAt,
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
  final DateTime? orderSavedAt;
  final DateTime? printJobCreatedAt;
  final DateTime? hubJobReceivedAt;
  final DateTime? claimedAt;
  final DateTime? dispatchStartedAt;
  final DateTime? printerWriteStartedAt;
  final DateTime? completedAt;
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
      orderSavedAt: DateTime.tryParse(map['order_saved_at']?.toString() ?? ''),
      printJobCreatedAt: DateTime.tryParse(
        map['print_job_created_at']?.toString() ?? '',
      ),
      hubJobReceivedAt: DateTime.tryParse(
        map['hub_job_received_at']?.toString() ?? '',
      ),
      claimedAt: DateTime.tryParse(map['claimed_at']?.toString() ?? ''),
      dispatchStartedAt: DateTime.tryParse(
        map['dispatch_started_at']?.toString() ?? '',
      ),
      printerWriteStartedAt: DateTime.tryParse(
        map['printer_write_started_at']?.toString() ?? '',
      ),
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get tableName => payload['table_name']?.toString() ?? '-';
  String get normalizedStatus {
    final value = status.trim().toLowerCase();
    if (value == 'printed') {
      return 'completed';
    }
    return value;
  }

  bool get isCompleted => normalizedStatus == 'completed';
  bool get isFailed => normalizedStatus == 'failed';
  bool get isTerminal => isCompleted || isFailed;

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

  Map<String, dynamic> get dispatchVerification {
    final raw = payload['dispatch_verification'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String get dispatchVerificationStatus =>
      payload['dispatch_verification_status']?.toString().trim() ??
      dispatchVerification['verification_status']?.toString().trim() ??
      '';

  bool get isUnverifiedCompleted =>
      isCompleted &&
      (dispatchVerificationStatus == 'ready_unverified' ||
          dispatchVerification['ready_unverified'] == true);

  String get roleLabel {
    final role = payload['printer_role']?.toString().trim().toLowerCase() ??
        payload['role']?.toString().trim().toLowerCase() ??
        '';
    return switch (role) {
      'adisyon' => 'Adisyon',
      'mutfak' => 'Mutfak',
      'ocak' => 'Ocak',
      'firin' || 'fırın' => 'Fırın',
      'bar' => 'Bar',
      _ => stationName == 'Genel' ? 'Mutfak' : stationName,
    };
  }

  String get backendLabel {
    final backend = (dispatchVerification['backend'] ??
            dispatchVerification['requested_backend'] ??
            payload['selected_printer_backend'] ??
            payload['printer_backend'] ??
            payload['backend'])
        ?.toString()
        .trim()
        .toLowerCase();
    return switch (backend) {
      'tcp' || 'ethernet' || 'ethernet_tcp' => 'Ethernet',
      'usb-direct' || 'usb_direct' => 'USB',
      'cups' => 'CUPS',
      'windows-spool' || 'windows_spooler' => 'Windows',
      _ => backend == null || backend.isEmpty ? '-' : backend,
    };
  }

  String get connectionSummary {
    final backend = backendLabel;
    if (backend == 'Ethernet') {
      final host = dispatchVerification['ip']?.toString().trim().isNotEmpty == true
          ? dispatchVerification['ip']?.toString()
          : payload['selected_printer_host']?.toString() ??
              payload['host']?.toString() ??
              payload['ip_address']?.toString();
      final port = dispatchVerification['port']?.toString().trim().isNotEmpty == true
          ? dispatchVerification['port']?.toString()
          : payload['selected_printer_port']?.toString() ??
              payload['port']?.toString();
      if (host != null && host.isNotEmpty) {
        return port != null && port.isNotEmpty ? '$host:$port' : host;
      }
    }
    if (backend == 'CUPS' || backend == 'Windows') {
      final queue = dispatchVerification['queue_name']?.toString().trim().isNotEmpty == true
          ? dispatchVerification['queue_name']?.toString()
          : payload['printer_queue']?.toString() ??
              payload['selected_printer_queue']?.toString();
      if (queue != null && queue.isNotEmpty) return queue;
    }
    if (backend == 'USB') {
      final device = dispatchVerification['device_id']?.toString().trim().isNotEmpty == true
          ? dispatchVerification['device_id']?.toString()
          : payload['printer_device_identifier']?.toString();
      if (device != null && device.isNotEmpty) {
        return device.length > 24 ? '${device.substring(0, 24)}…' : device;
      }
    }
    return '-';
  }

  String displayStatusLabel({bool retrying = false}) {
    if (retrying) return 'Tekrar deneniyor';
    if (isUnverifiedCompleted) return 'Doğrulanamadı';
    return switch (normalizedStatus) {
      'completed' => 'Basıldı',
      'failed' => 'Başarısız',
      'printing' => 'Yazdırılıyor',
      'claimed' => 'İşleniyor',
      'pending' => 'Kuyrukta',
      _ => status,
    };
  }

  bool get canManualRetry =>
      isFailed && retryCount < maxManualRetries;

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
      'order_saved_at': orderSavedAt?.toIso8601String(),
      'print_job_created_at': printJobCreatedAt?.toIso8601String(),
      'hub_job_received_at': hubJobReceivedAt?.toIso8601String(),
      'claimed_at': claimedAt?.toIso8601String(),
      'dispatch_started_at': dispatchStartedAt?.toIso8601String(),
      'printer_write_started_at': printerWriteStartedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
