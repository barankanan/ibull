import 'package:flutter/material.dart';

import '../../../../../models/print_job_model.dart';
import '../../../../../models/printer_model.dart';

BoxDecoration printerCenterCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x060F172A),
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
  );
}

class PrinterCenterQuickSetupCard extends StatelessWidget {
  const PrinterCenterQuickSetupCard({
    super.key,
    required this.onAddPrinter,
    required this.onBridgeSetup,
    required this.onConnectionTest,
    required this.onCopyDiagnostics,
    this.copyingDiagnostics = false,
    this.bridgeHealthy = false,
  });

  final VoidCallback onAddPrinter;
  final VoidCallback onBridgeSetup;
  final VoidCallback onConnectionTest;
  final VoidCallback onCopyDiagnostics;
  final bool copyingDiagnostics;
  final bool bridgeHealthy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hızlı Kurulum',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Yazıcı ekleme, bridge kurulumu ve bağlantı testi için hızlı erişim.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAddPrinter,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yazıcı ekle'),
              ),
              OutlinedButton.icon(
                onPressed: onBridgeSetup,
                icon: Icon(
                  bridgeHealthy
                      ? Icons.check_circle_outline
                      : Icons.power_settings_new,
                  size: 18,
                ),
                label: Text(
                  bridgeHealthy ? 'Bridge çalışıyor' : 'Bridge kurulumu',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onConnectionTest,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: const Text('Bağlantı testi'),
              ),
              OutlinedButton.icon(
                onPressed: copyingDiagnostics ? null : onCopyDiagnostics,
                icon: copyingDiagnostics
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('Tanı raporu kopyala'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PrinterAssignmentSummaryItem {
  const PrinterAssignmentSummaryItem({
    required this.label,
    required this.isMapped,
    this.printerName,
  });

  final String label;
  final bool isMapped;
  final String? printerName;
}

class PrinterAssignmentSummaryCard extends StatelessWidget {
  const PrinterAssignmentSummaryCard({
    super.key,
    required this.items,
    this.onGoToMapping,
  });

  final List<PrinterAssignmentSummaryItem> items;
  final VoidCallback? onGoToMapping;

  @override
  Widget build(BuildContext context) {
    final missingCount = items.where((item) => !item.isMapped).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Eşleştirme Özeti',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (missingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$missingCount eksik',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(_buildRow),
          if (onGoToMapping != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onGoToMapping,
                icon: const Icon(Icons.alt_route_rounded, size: 18),
                label: const Text('Eşleştirme sekmesine git'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(PrinterAssignmentSummaryItem item) {
    final tone = item.isMapped ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    final status = item.isMapped
        ? (item.printerName?.trim().isNotEmpty == true
              ? item.printerName!.trim()
              : 'Seçildi')
        : 'Seçilmedi';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            item.isMapped ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: tone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF374151),
                ),
                children: [
                  TextSpan(
                    text: '${item.label}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: status,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrinterRegisteredListCard extends StatelessWidget {
  const PrinterRegisteredListCard({
    super.key,
    required this.printers,
    this.onTest,
    this.onEdit,
    this.onDelete,
    this.repairingIds = const <String>{},
  });

  final List<PrinterModel> printers;
  final void Function(PrinterModel printer)? onTest;
  final void Function(PrinterModel printer)? onEdit;
  final void Function(PrinterModel printer)? onDelete;
  final Set<String> repairingIds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kayıtlı Yazıcılar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '${printers.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (printers.isEmpty)
            const Text(
              'Kayıtlı yazıcı yok. Hızlı kurulumdan yazıcı ekleyin.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            )
          else
            ...printers.map((printer) => _PrinterRegisteredRow(
              printer: printer,
              onTest: onTest,
              onEdit: onEdit,
              onDelete: onDelete,
              repairing: repairingIds.contains(printer.id),
            )),
        ],
      ),
    );
  }
}

class _PrinterRegisteredRow extends StatelessWidget {
  const _PrinterRegisteredRow({
    required this.printer,
    this.onTest,
    this.onEdit,
    this.onDelete,
    this.repairing = false,
  });

  final PrinterModel printer;
  final void Function(PrinterModel printer)? onTest;
  final void Function(PrinterModel printer)? onEdit;
  final void Function(PrinterModel printer)? onDelete;
  final bool repairing;

  String get _backendBadge {
    final conn = printer.formConnectionType;
    if (conn == PrinterModel.networkConnectionType) return 'Ethernet';
    if (conn == PrinterModel.usbConnectionType) return 'USB';
    if (conn == PrinterModel.localConnectionType) {
      final id = printer.deviceIdentifier?.toLowerCase() ?? '';
      if (id.contains('cups')) return 'CUPS';
      if (id.contains('windows')) return 'Windows';
      return 'Local';
    }
    return printer.connectionTypeLabel;
  }

  String get _connectionLine {
    if (printer.isLocalConnection) {
      final device = printer.deviceIdentifier?.trim() ?? '';
      if (device.isNotEmpty) return device;
      return printer.deviceIdentifier?.trim() ?? printer.code;
    }
    final host = printer.resolvedHost;
    final port = printer.resolvedPort;
    if (host.isNotEmpty && port != null) return '$host:$port';
    final device = printer.deviceIdentifier?.trim() ?? '';
    return device.isNotEmpty ? device : '-';
  }

  @override
  Widget build(BuildContext context) {
    final healthColor = printer.isActive
        ? const Color(0xFF15803D)
        : const Color(0xFF9CA3AF);
    final healthLabel = printer.isActive ? 'Aktif' : 'Pasif';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  printer.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _Badge(text: _backendBadge),
              const SizedBox(width: 6),
              _Badge(
                text: healthLabel,
                color: healthColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bağlantı: $_connectionLine',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
          ),
          Text(
            'Profil: ${printer.printerProfileId ?? '${printer.paperWidthMm}mm'}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
          ),
          if (repairing) ...[
            const SizedBox(height: 6),
            const Text(
              'Profil onarımı çalışıyor…',
              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (onTest != null)
                TextButton(
                  onPressed: () => onTest!(printer),
                  child: const Text('Test'),
                ),
              if (onEdit != null)
                TextButton(
                  onPressed: () => onEdit!(printer),
                  child: const Text('Düzenle'),
                ),
              if (onDelete != null)
                TextButton(
                  onPressed: () => onDelete!(printer),
                  child: const Text('Sil'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color = const Color(0xFF4B5563)});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class PrinterRecentJobsCard extends StatelessWidget {
  const PrinterRecentJobsCard({
    super.key,
    required this.jobs,
    this.loading = false,
  });

  final List<PrintJobModel> jobs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son Baskılar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (jobs.isEmpty)
            const Text(
              'Henüz baskı kaydı yok.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            )
          else
            ...jobs.take(5).map(_buildJobRow),
        ],
      ),
    );
  }

  Widget _buildJobRow(PrintJobModel job) {
    final status = job.normalizedStatus;
    final color = switch (status) {
      'failed' => const Color(0xFFDC2626),
      'completed' => const Color(0xFF16A34A),
      'printing' => const Color(0xFFEA580C),
      _ => const Color(0xFF6B7280),
    };
    final error = job.lastError?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status == 'failed' ? Icons.error_outline : Icons.print_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${job.displayStatusLabel()} • ${job.jobType}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (error.isNotEmpty)
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
