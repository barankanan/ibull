import 'dart:convert';
import 'dart:io';

import '../models/print_job_model.dart';

/// Builds a copy-friendly diagnostics report for restaurant printer support.
class RestaurantPrinterDiagnosticsReportBuilder {
  const RestaurantPrinterDiagnosticsReportBuilder._();

  static String build({
    required String restaurantId,
    required Map<String, dynamic> bridgeHealth,
    Map<String, dynamic>? bridgeDiagnostics,
    Map<String, dynamic>? queueStatus,
    List<Map<String, dynamic>> discoveredPrinters = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> savedPrinters = const <Map<String, dynamic>>[],
    List<String> ipDriftWarnings = const <String>[],
    List<String> duplicateWarnings = const <String>[],
    Map<String, dynamic>? roleMappings,
    List<PrintJobModel> recentFailedJobs = const <PrintJobModel>[],
    List<PrintJobModel> recentCompletedJobs = const <PrintJobModel>[],
    String? lastError,
    String bridgeEndpoint = 'http://127.0.0.1:3001',
  }) {
    final report = <String, dynamic>{
      'generated_at': DateTime.now().toIso8601String(),
      'restaurant_id': restaurantId,
      'platform': Platform.operatingSystem,
      'bridge_endpoint': bridgeEndpoint,
      'bridge_health': bridgeHealth,
      if (bridgeDiagnostics != null && bridgeDiagnostics.isNotEmpty)
        'bridge_diagnostics': bridgeDiagnostics,
      if (queueStatus != null && queueStatus.isNotEmpty)
        'queue_status': queueStatus,
      'discovered_printers': discoveredPrinters,
      'saved_printers': savedPrinters,
      if (ipDriftWarnings.isNotEmpty) 'ip_drift_warnings': ipDriftWarnings,
      if (duplicateWarnings.isNotEmpty) 'duplicate_warnings': duplicateWarnings,
      if (roleMappings != null && roleMappings.isNotEmpty)
        'role_mappings': roleMappings,
      'recent_failed_jobs': recentFailedJobs
          .take(10)
          .map(_jobSummary)
          .toList(growable: false),
      'recent_completed_jobs': recentCompletedJobs
          .take(10)
          .map(_jobSummary)
          .toList(growable: false),
      if (lastError != null && lastError.trim().isNotEmpty)
        'last_error': lastError.trim(),
    };
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  static Map<String, dynamic> _jobSummary(PrintJobModel job) {
    return <String, dynamic>{
      'job_id': job.id,
      'status': job.status,
      'role': job.roleLabel,
      'station': job.stationName,
      'printer': job.printerName,
      'backend': job.backendLabel,
      'connection': job.connectionSummary,
      'retry_count': job.retryCount,
      'last_error': job.lastError,
      'created_at': job.createdAt.toIso8601String(),
      if (job.dispatchVerification.isNotEmpty)
        'dispatch_verification': job.dispatchVerification,
    };
  }
}
