import 'package:flutter/material.dart';

import '../../../../models/print_job_model.dart';
import '../../../../models/printer_model.dart';
import '../../../../models/station_model.dart';
import '../../../../models/station_printer_model.dart';
import 'printer_station_test_guard.dart';
import 'widgets/printer_center_sections.dart';

/// Counts taken from the same job list the panel renders.
class PrinterQueueSummary {
  const PrinterQueueSummary._();

  static const buckets = <String>[
    'pending',
    'processing',
    'failed',
    'uncertain',
    'quarantine',
    'paused_closed',
    'sent',
  ];

  static Map<String, int> counts(List<PrintJobModel> jobs) {
    final result = <String, int>{for (final bucket in buckets) bucket: 0};
    for (final job in jobs) {
      final bucket = job.operatorQueueBucket;
      result[bucket] = (result[bucket] ?? 0) + 1;
    }
    return result;
  }

  /// A completed TCP or CUPS handoff is not a confirmed paper ticket.
  static bool isPhysicalPrint(PrintJobModel job) {
    final raw = job.dispatchVerification['physical_confirmation'];
    return raw == true || raw == 'true';
  }
}

class PrinterCenterStationView {
  const PrinterCenterStationView({
    required this.stationName,
    required this.printerName,
    required this.connectionLabel,
    required this.address,
    required this.lastHandoff,
    required this.pendingCount,
    required this.failedCount,
    required this.lastError,
    required this.testBlockedReason,
  });

  final String stationName;
  final String printerName;
  final String connectionLabel;
  final String address;
  final String lastHandoff;
  final int pendingCount;
  final int failedCount;
  final String lastError;
  final String? testBlockedReason;
}

List<PrinterCenterStationView> printerCenterStationViews({
  required List<StationModel> stations,
  required List<StationPrinterModel> mappings,
  required List<PrinterModel> printers,
  required List<PrintJobModel> jobs,
  required bool printSystemEnabledLoaded,
  required bool printSystemEnabled,
  required bool queueRuntimeDisabled,
  required bool bridgeReachable,
  required bool testInFlight,
}) {
  final printerById = <String, PrinterModel>{
    for (final printer in printers) printer.id: printer,
  };
  return [
    for (final station in stations)
      _stationView(
        station: station,
        mappings: mappings,
        printerById: printerById,
        jobs: jobs,
        printSystemEnabledLoaded: printSystemEnabledLoaded,
        printSystemEnabled: printSystemEnabled,
        queueRuntimeDisabled: queueRuntimeDisabled,
        bridgeReachable: bridgeReachable,
        testInFlight: testInFlight,
      ),
  ];
}

PrinterCenterStationView _stationView({
  required StationModel station,
  required List<StationPrinterModel> mappings,
  required Map<String, PrinterModel> printerById,
  required List<PrintJobModel> jobs,
  required bool printSystemEnabledLoaded,
  required bool printSystemEnabled,
  required bool queueRuntimeDisabled,
  required bool bridgeReachable,
  required bool testInFlight,
}) {
  StationPrinterModel? mapping;
  for (final row in mappings) {
    if (row.stationId != station.id) continue;
    if (mapping == null || row.isPrimary) mapping = row;
  }
  final printer = mapping == null ? null : printerById[mapping.printerId];
  final stationJobs = jobs.where((job) {
    final stationId = job.payload['station_id']?.toString() ?? '';
    final stationName = job.payload['station']?.toString().toLowerCase() ??
        job.payload['station_name']?.toString().toLowerCase() ??
        '';
    return stationId == station.id ||
        stationName == station.name.toLowerCase() ||
        stationName == station.code.toLowerCase();
  }).toList(growable: false);
  PrintJobModel? lastHandoff;
  for (final job in stationJobs) {
    if (job.operatorQueueBucket != 'sent') continue;
    if (lastHandoff == null) {
      lastHandoff = job;
      continue;
    }
    final current = lastHandoff.completedAt ?? lastHandoff.createdAt;
    final candidate = job.completedAt ?? job.createdAt;
    if (candidate.isAfter(current)) lastHandoff = job;
  }
  final handoffText = lastHandoff == null
      ? 'Kayıt yok'
      : PrinterQueueSummary.isPhysicalPrint(lastHandoff)
          ? 'Fiziksel baskı doğrulandı'
          : 'Yazıcıya iletildi. Fiziksel çıktı doğrulanmadı.';
  String? lastError;
  for (final job in stationJobs) {
    final error = job.lastError?.trim() ?? '';
    if (error.isEmpty) continue;
    lastError = error;
    break;
  }
  final address = printer == null
      ? '-'
      : (printer.resolvedPort == null
            ? printer.resolvedHost
            : '${printer.resolvedHost}:${printer.resolvedPort}');
  return PrinterCenterStationView(
    stationName: station.name,
    printerName: printer?.name ?? 'Eşleşme yok',
    connectionLabel: printer == null
        ? '-'
        : PrinterStationTestGuard.backendLabel(printer),
    address: address.isEmpty ? '-' : address,
    lastHandoff: handoffText,
    pendingCount: stationJobs
        .where((job) => job.operatorQueueBucket == 'pending')
        .length,
    failedCount: stationJobs
        .where((job) => job.operatorQueueBucket == 'failed')
        .length,
    lastError: lastError ?? '',
    testBlockedReason: PrinterStationTestGuard.validate(
      station: station,
      primaryMapping: mapping,
      mappedPrinter: printer,
      printSystemEnabledLoaded: printSystemEnabledLoaded,
      printSystemEnabled: printSystemEnabled,
      queueRuntimeDisabled: queueRuntimeDisabled,
      bridgeReachable: bridgeReachable,
      testInFlight: testInFlight,
    ),
  );
}

class PrinterCenterQueuePanel extends StatelessWidget {
  const PrinterCenterQueuePanel({
    super.key,
    required this.jobs,
    required this.bridgeReachable,
    required this.serviceEnabled,
    required this.serviceKnown,
    required this.autoPrintEnabled,
  });

  final List<PrintJobModel> jobs;
  final bool bridgeReachable;
  final bool serviceEnabled;
  final bool serviceKnown;
  final bool autoPrintEnabled;

  @override
  Widget build(BuildContext context) {
    final counts = PrinterQueueSummary.counts(jobs);
    final errors = jobs
        .map((job) => job.lastError?.trim() ?? '')
        .where((error) => error.isNotEmpty)
        .take(3)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Baskı kuyruğu',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            serviceKnown
                ? (serviceEnabled
                      ? 'Merkezi yazıcı servisi açık. Sayaçlar bu listedeki ${jobs.length} kayıttan hesaplanır.'
                      : 'Merkezi yazıcı servisi kapalı. Fiziksel fiş gönderilmez.')
                : 'Yazıcı servisi durumu bilinmiyor. Baskı gönderilmez.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            'Köprü: ${bridgeReachable ? 'bağlı' : 'ulaşılamıyor'} · '
            'Otomatik baskı: ${autoPrintEnabled ? 'açık' : 'kapalı'}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Bekleyen', counts['pending'] ?? 0),
              _chip('Başarısız', counts['failed'] ?? 0),
              _chip('Belirsiz', counts['uncertain'] ?? 0),
              _chip('Karantina', counts['quarantine'] ?? 0),
              _chip('Servis kapalı', counts['paused_closed'] ?? 0),
              _chip('İletilen', counts['sent'] ?? 0),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'İletilen kayıt TCP veya kuyruk yazımıdır. Fiziksel baskı başarısı sayılmaz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final error in errors)
              Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7E5EE)),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

class PrinterCenterStationCards extends StatelessWidget {
  const PrinterCenterStationCards({
    super.key,
    required this.views,
    this.onTest,
  });

  final List<PrinterCenterStationView> views;
  final void Function(PrinterCenterStationView view)? onTest;

  @override
  Widget build(BuildContext context) {
    final kitchen = views.where((view) {
      final name = view.stationName.toLowerCase();
      return name.contains('ocak') ||
          name.contains('fırın') ||
          name.contains('firin');
    }).toList(growable: false);
    final shown = kitchen.isEmpty ? views : kitchen;
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kitchen.isEmpty ? 'İstasyon yazıcıları' : 'Ocak / Fırın',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          for (final view in shown) ...[
            Text(
              view.stationName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${view.printerName} · ${view.connectionLabel} · ${view.address}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
            ),
            Text(
              'Son iletim: ${view.lastHandoff}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
            Text(
              'Bekleyen ${view.pendingCount} · Başarısız ${view.failedCount}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
            ),
            if (view.lastError.isNotEmpty)
              Text(
                view.lastError,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            if (view.testBlockedReason != null)
              Text(
                view.testBlockedReason!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              )
            else if (onTest != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onTest!(view),
                  child: const Text('Yetkili test baskısı'),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
