bool hasConfiguredAdisyonPrinter(Map<String, dynamic>? stationConfig) {
  if (stationConfig == null) return false;
  final roleMappings = stationConfig['role_mappings'];
  if (roleMappings is Map) {
    final adisyon = roleMappings['adisyon'];
    if (adisyon is Map) {
      final bridgeId =
          adisyon['id']?.toString().trim() ??
          adisyon['bridgePrinterId']?.toString().trim() ??
          '';
      if (bridgeId.isNotEmpty) return true;
    }
  }
  final printerId =
      stationConfig['adisyon_printer_id']?.toString().trim() ?? '';
  return printerId.isNotEmpty;
}

Map<String, dynamic> enrichQueuedReceiptPayloadWithPrinterRouting(
  Map<String, dynamic> payload, {
  required Map<String, dynamic>? stationConfig,
}) {
  final nextPayload = Map<String, dynamic>.from(payload)
    ..['printer_role'] = 'adisyon'
    ..['document_type'] = 'receipt'
    ..['job_type'] = 'receipt';

  final roleMappings = stationConfig?['role_mappings'];
  if (roleMappings is Map) {
    final receiptRole = roleMappings['adisyon'];
    if (receiptRole is Map) {
      final printer = Map<String, dynamic>.from(receiptRole);
      final bridgePrinterId =
          printer['id']?.toString().trim() ??
          printer['bridgePrinterId']?.toString().trim() ??
          '';
      final printerRecordId =
          printer['printerRecordId']?.toString().trim() ??
          printer['printer_record_id']?.toString().trim() ??
          '';
      final printerName =
          printer['displayName']?.toString().trim() ??
          printer['name']?.toString().trim() ??
          '';
      final printerQueue =
          printer['queueName']?.toString().trim() ??
          printer['queue']?.toString().trim() ??
          '';
      final printerBackend =
          printer['backend']?.toString().trim() ??
          printer['transportType']?.toString().trim() ??
          '';
      final deviceIdentifier =
          printer['deviceIdentifier']?.toString().trim() ??
          printer['device_identifier']?.toString().trim() ??
          '';
      nextPayload['printer'] = printer;
      if (bridgePrinterId.isNotEmpty) {
        nextPayload['printer_id'] = bridgePrinterId;
      }
      if (printerRecordId.isNotEmpty) {
        nextPayload['printer_record_id'] = printerRecordId;
      }
      if (printerName.isNotEmpty) {
        nextPayload['printer_name'] = printerName;
      }
      if (printerQueue.isNotEmpty) {
        nextPayload['printer_queue'] = printerQueue;
      }
      if (printerBackend.isNotEmpty) {
        nextPayload['printer_backend'] = printerBackend;
      }
      if (deviceIdentifier.isNotEmpty) {
        nextPayload['printer_device_identifier'] = deviceIdentifier;
      }
      return nextPayload;
    }
  }

  final printerId =
      stationConfig?['adisyon_printer_id']?.toString().trim() ?? '';
  final printerName =
      stationConfig?['adisyon_printer_name']?.toString().trim() ?? '';
  if (printerId.isNotEmpty) {
    nextPayload['printer_id'] = printerId;
    nextPayload['printer_record_id'] = printerId;
  }
  if (printerName.isNotEmpty) {
    nextPayload['printer_name'] = printerName;
  }

  return nextPayload;
}
