import 'package:flutter/material.dart';

import '../../../../../models/print_job_model.dart';
import '../../../../../models/printer_model.dart';

BoxDecoration printerCenterCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE7E5EE)),
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
      padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onGoToMapping,
                icon: const Icon(Icons.alt_route_rounded, size: 18),
                label: const Text('Eşleştirmeyi Yönet'),
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

  static const double _tableBreakpoint = 720;
  static const double _actionsWidth = 220;

  @override
  Widget build(BuildContext context) {
    final activeCount = printers.where((printer) => printer.isActive).length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                printers.isEmpty
                    ? '0 kayıt'
                    : '${printers.length} kayıt • $activeCount aktif',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktif/pasif kayıt durumunu gösterir; yazıcının şu an açık ve bağlı olduğunu göstermez.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (printers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Henüz kayıtlı yazıcı yok. Üstteki “Yazıcı Ekle” ile ilk yazıcınızı ekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final table = constraints.maxWidth >= _tableBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (table) const _PrinterTableHeader(),
                    for (final printer in printers)
                      _PrinterRegisteredRow(
                        printer: printer,
                        table: table,
                        onTest: onTest,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        repairing: repairingIds.contains(printer.id),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PrinterTableHeader extends StatelessWidget {
  const _PrinterTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Ad', style: style)),
          Expanded(flex: 3, child: Text('Bağlantı', style: style)),
          Expanded(flex: 2, child: Text('Profil', style: style)),
          Expanded(flex: 2, child: Text('Etkinlik', style: style)),
          SizedBox(
            width: PrinterRegisteredListCard._actionsWidth,
            child: Text('İşlemler', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _PrinterRegisteredRow extends StatelessWidget {
  const _PrinterRegisteredRow({
    required this.printer,
    required this.table,
    this.onTest,
    this.onEdit,
    this.onDelete,
    this.repairing = false,
  });

  final PrinterModel printer;
  final bool table;
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

  String get _profileLabel =>
      printer.printerProfileId ?? '${printer.paperWidthMm}mm';

  @override
  Widget build(BuildContext context) {
    final activityColor = printer.isActive
        ? const Color(0xFF15803D)
        : const Color(0xFF9CA3AF);
    final activityLabel = printer.isActive ? 'Kayıt aktif' : 'Kayıt pasif';
    const cellStyle = TextStyle(fontSize: 12, color: Color(0xFF4B5563));

    final name = Text(
      printer.name,
      maxLines: table ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
    final connection = Tooltip(
      message: _connectionLine,
      child: Text(
        '$_backendBadge • $_connectionLine',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle,
      ),
    );
    final profile = Text(
      _profileLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: cellStyle,
    );
    final activity = Align(
      alignment: Alignment.centerLeft,
      child: _Badge(text: activityLabel, color: activityColor),
    );
    final actions = Wrap(
      alignment: table ? WrapAlignment.end : WrapAlignment.start,
      spacing: 2,
      children: [
        if (onTest != null)
          TextButton(
            onPressed: () => onTest!(printer),
            style: _compactButton,
            child: const Text('Test'),
          ),
        if (onEdit != null)
          TextButton(
            onPressed: () => onEdit!(printer),
            style: _compactButton,
            child: const Text('Düzenle'),
          ),
        if (onDelete != null)
          TextButton(
            onPressed: () => onDelete!(printer),
            style: _compactButton.copyWith(
              foregroundColor: const WidgetStatePropertyAll(Color(0xFFB91C1C)),
            ),
            child: const Text('Sil'),
          ),
      ],
    );
    const repairNote = Text(
      'Profil onarımı çalışıyor…',
      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
    );

    if (table) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEFEDF3))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, if (repairing) repairNote],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: connection),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: profile),
            Expanded(flex: 2, child: activity),
            SizedBox(
              width: PrinterRegisteredListCard._actionsWidth,
              child: actions,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: name),
              const SizedBox(width: 8),
              _Badge(text: activityLabel, color: activityColor),
            ],
          ),
          const SizedBox(height: 4),
          connection,
          Text(
            'Profil: $_profileLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: cellStyle,
          ),
          if (repairing) repairNote,
          actions,
        ],
      ),
    );
  }
}

final ButtonStyle _compactButton = TextButton.styleFrom(
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 10),
);

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
    this.onShowAll,
  });

  final List<PrintJobModel> jobs;
  final bool loading;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: printerCenterCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Henüz baskı kaydı yok.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
              ),
            )
          else
            ...jobs.take(5).map(_buildJobRow),
          if (onShowAll != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onShowAll,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('Tüm Kayıtlar'),
              ),
            ),
          ],
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
