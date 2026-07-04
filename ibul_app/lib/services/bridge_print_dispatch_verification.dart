import '../models/desktop_printer_setup_models.dart';
import 'restaurant_printer_dispatch_resolver.dart';

/// Shared bridge dispatch verification for tests and production print_jobs.
class BridgePrintDispatchVerification {
  const BridgePrintDispatchVerification({
    required this.ok,
    required this.countsAsJobCompleted,
    required this.status,
    required this.message,
    this.errorCode,
    this.usedFallback = false,
    this.backendMismatch = false,
    this.cupsUnverified = false,
    this.logSnapshot = const <String, dynamic>{},
  });

  final bool ok;
  final bool countsAsJobCompleted;
  final String status;
  final String message;
  final String? errorCode;
  final bool usedFallback;
  final bool backendMismatch;
  final bool cupsUnverified;
  final Map<String, dynamic> logSnapshot;

  static const String dispatchNotDeliveredMessage =
      'Fiş oluşturuldu ama yazıcıya gönderilemedi.';

  static const String cupsUnverifiedMessage =
      'CUPS yazdırma fiziksel olarak doğrulanamadı. Lütfen çıktı alındığını kontrol edin.';

  static const String stationMissingPrinterMessage =
      'Bu alan için yazıcı seçilmemiş. Yazıcı eşleştirme ekranından atayın.';

  static String kitchenGeneralFallbackWarning(String stationName) =>
      '$stationName için özel yazıcı yok. Mutfak genel yazıcısı kullanılacak.';

  /// Merges bridge verification output with print_job context for logging/DB payload.
  static Map<String, dynamic> buildJobObservabilitySnapshot({
    required BridgePrintDispatchVerification verification,
    String? jobId,
    String? orderId,
    String? tableId,
    String? role,
    String? stationId,
    String? stationName,
    String? documentType,
    String? printerId,
    String? printerName,
    String? deviceId,
    String? ip,
    String? port,
    String? queueName,
    String? printerProfileId,
    String? bridgeEndpoint,
    int? attempts,
    int? retryCount,
    DateTime? createdAt,
    DateTime? printedAt,
    DateTime? failedAt,
  }) {
    final snapshot = Map<String, dynamic>.from(verification.logSnapshot);
    void put(String key, Object? value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      snapshot[key] = value;
    }

    put('job_id', jobId);
    put('order_id', orderId);
    put('table_id', tableId);
    put('role', role);
    put('station_id', stationId);
    put('station', stationName);
    put('document_type', documentType);
    put('printer_id', printerId);
    put('printer_name', printerName);
    put('device_id', deviceId);
    put('ip', ip);
    put('port', port);
    put('queue_name', queueName);
    put('printer_profile_id', printerProfileId);
    put('bridge_endpoint', bridgeEndpoint);
    snapshot['ok'] = verification.ok;
    snapshot['used_fallback'] = verification.usedFallback;
    snapshot['ready_unverified'] = verification.cupsUnverified;
    snapshot['backend_mismatch'] = verification.backendMismatch;
    snapshot['countsAsJobCompleted'] = verification.countsAsJobCompleted;
    snapshot['error_code'] = verification.errorCode;
    snapshot['error_message'] = verification.message;
    snapshot['verification_status'] = verification.status;
    if (attempts != null) snapshot['attempts'] = attempts;
    if (retryCount != null) snapshot['retry_count'] = retryCount;
    if (createdAt != null) {
      snapshot['created_at'] = createdAt.toIso8601String();
    }
    if (printedAt != null) {
      snapshot['printed_at'] = printedAt.toIso8601String();
    }
    if (failedAt != null) {
      snapshot['failed_at'] = failedAt.toIso8601String();
    }
    return snapshot;
  }

  static BridgePrintDispatchVerification verify({
    Map<String, dynamic>? response,
    UnifiedPrinterModel? printer,
    bool dispatchUsedFallback = false,
    bool isTestFlow = false,
  }) {
    final bridgeOk = response?['ok'] == true;
    final queueStatus = _readText(response?['queue_status']).toLowerCase();
    final errorCode = _readText(
      response?['error_code'] ?? response?['errorCode'],
    );
    final usedFallback = response?['used_fallback'] == true || dispatchUsedFallback;
    final warningMessage = _readText(response?['warning']);
    final requestedBackend = _normalizeBackend(
      printer?.backend.value ??
          _readText(
            response?['requested_backend'] ??
                response?['selected_backend'] ??
                response?['backend'],
          ),
    );
    final actualBackend = _normalizeBackend(
      _readText(
        response?['actual_backend'] ??
            response?['selected_backend'] ??
            response?['transport_type'] ??
            response?['transport'] ??
            response?['backend'],
      ),
    );
    final physicalConfirmation = response?['physical_confirmation'];
    final bytesSentRaw = response?['bytes_sent'];
    final bytesSentParsed = int.tryParse(_readText(bytesSentRaw));
    final host = _readText(
      response?['host'] ??
          response?['target_host'] ??
          response?['ip_address'] ??
          response?['ipAddress'],
    );
    final port = _readText(response?['port'] ?? response?['target_port']);
    final queueName = _readText(
      response?['queue_name'] ??
          response?['printer_name'] ??
          response?['printer_queue'] ??
          printer?.queueName,
    );
    final logSnapshot = <String, dynamic>{
      'ok': bridgeOk,
      'backend': actualBackend.isEmpty ? null : actualBackend,
      'requested_backend': requestedBackend.isEmpty ? null : requestedBackend,
      'used_fallback': usedFallback,
      if ((bytesSentParsed ?? bytesSentRaw) != null)
        'bytes_sent': bytesSentParsed ?? bytesSentRaw,
      'physical_confirmation': physicalConfirmation,
      if (errorCode.isNotEmpty) 'error_code': errorCode,
      if (queueStatus.isNotEmpty) 'queue_status': queueStatus,
      if (host.isNotEmpty) 'host': host,
      if (port.isNotEmpty) 'port': port,
      if (queueName.isNotEmpty) 'queue_name': queueName,
      if (printer?.printerRecordId?.trim().isNotEmpty == true)
        'printer_id': printer!.printerRecordId,
      'bridge_endpoint': _readText(response?['endpoint']),
      'is_test_flow': isTestFlow,
    };

    if (!bridgeOk || queueStatus == 'failed' || queueStatus == 'error') {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'failed',
        message: _friendlyBridgeFailure(response),
        errorCode: errorCode.isEmpty ? 'bridge_error' : errorCode,
        logSnapshot: logSnapshot,
      );
    }

    if (usedFallback) {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'failed',
        message: warningMessage.isNotEmpty
            ? warningMessage
            : RestaurantPrinterDispatchResolution.backendMismatchMessage,
        errorCode: errorCode.isEmpty ? 'used_fallback' : errorCode,
        usedFallback: true,
        logSnapshot: logSnapshot,
      );
    }

    if (requestedBackend.isNotEmpty &&
        actualBackend.isNotEmpty &&
        requestedBackend != actualBackend) {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'failed',
        message: warningMessage.isNotEmpty
            ? warningMessage
            : RestaurantPrinterDispatchResolution.backendMismatchMessage,
        errorCode: errorCode.isEmpty ? 'backend_mismatch' : errorCode,
        backendMismatch: true,
        logSnapshot: logSnapshot,
      );
    }

    final isCupsBackend =
        actualBackend == 'cups' ||
        requestedBackend == 'cups' ||
        printer?.backend == DesktopPrinterBackend.cups;
    if (physicalConfirmation == false && isCupsBackend) {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'ready_unverified',
        message: cupsUnverifiedMessage,
        cupsUnverified: true,
        logSnapshot: logSnapshot,
      );
    }

    if (bytesSentParsed != null && bytesSentParsed <= 0) {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'failed',
        message: dispatchNotDeliveredMessage,
        errorCode: errorCode.isEmpty ? 'bytes_not_sent' : errorCode,
        logSnapshot: logSnapshot,
      );
    }

    if (physicalConfirmation == false && bytesSentParsed == null) {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'ready_unverified',
        message: _readText(response?['physical_confirmation_message']).isNotEmpty
            ? _readText(response?['physical_confirmation_message'])
            : dispatchNotDeliveredMessage,
        logSnapshot: logSnapshot,
      );
    }

    if (errorCode.isNotEmpty &&
        errorCode != 'success' &&
        errorCode != 'ok' &&
        errorCode != 'completed') {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'failed',
        message: warningMessage.isNotEmpty
            ? warningMessage
            : dispatchNotDeliveredMessage,
        errorCode: errorCode,
        logSnapshot: logSnapshot,
      );
    }

    if (warningMessage.isNotEmpty && !isTestFlow) {
      return BridgePrintDispatchVerification(
        ok: false,
        countsAsJobCompleted: false,
        status: 'failed',
        message: warningMessage,
        errorCode: errorCode.isEmpty ? 'bridge_warning' : errorCode,
        logSnapshot: logSnapshot,
      );
    }

    return BridgePrintDispatchVerification(
      ok: true,
      countsAsJobCompleted: true,
      status: 'ready',
      message: warningMessage.isNotEmpty ? warningMessage : 'Hazir',
      logSnapshot: logSnapshot,
    );
  }

  static String _normalizeBackend(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    if (normalized == 'ethernet_tcp' ||
        normalized == 'ethernet' ||
        normalized == 'network' ||
        normalized == 'tcp/ip') {
      return 'tcp';
    }
    if (normalized == 'usb_direct' || normalized == 'usb-direct') {
      return 'usb-direct';
    }
    if (normalized == 'windows_spooler' ||
        normalized == 'windows-spool' ||
        normalized == 'windows_spool') {
      return 'windows-spool';
    }
    return normalized;
  }

  static String _readText(Object? value) => value?.toString().trim() ?? '';

  static String _friendlyBridgeFailure(Map<String, dynamic>? response) {
    final message = _readText(response?['message'] ?? response?['error']);
    if (message.isNotEmpty) return message;
    final errorCode = _readText(response?['error_code'] ?? response?['errorCode']);
    if (errorCode == 'bridge_offline' || errorCode == 'bridge_not_running') {
      return RestaurantPrinterDispatchResolution.bridgeOfflineMessage;
    }
    return BridgePrintDispatchVerification.dispatchNotDeliveredMessage;
  }
}
