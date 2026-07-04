import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/admin_finance_payout_helper.dart';
import '../helpers/admin_panel_density.dart';

typedef PayoutRowAction = Future<void> Function(AdminFinancePayoutSellerRow row);
typedef PayoutMarkPaidAction = Future<void> Function(
  AdminFinancePayoutSellerRow row,
  AdminPayoutPaymentDraft draft,
);

class AdminPayoutPaymentDraft {
  const AdminPayoutPaymentDraft({
    required this.paymentMethod,
    this.paymentReference,
    required this.paidAt,
    this.note,
  });

  final String paymentMethod;
  final String? paymentReference;
  final DateTime paidAt;
  final String? note;
}

class AdminFinancePayoutPanel extends StatelessWidget {
  const AdminFinancePayoutPanel({
    super.key,
    required this.density,
    required this.snapshot,
    required this.isLoading,
    required this.error,
    required this.periodLabel,
    required this.statusFilter,
    required this.searchQuery,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.onApprove,
    required this.onMarkPaid,
    required this.onDispute,
    required this.onCancel,
    required this.formatCurrency,
    required this.formatCompactCurrency,
    required this.onRetry,
    this.compactHeader = false,
  });

  final AdminPanelDensity density;
  final AdminFinancePayoutPeriodSnapshot snapshot;
  final bool isLoading;
  final String? error;
  final String periodLabel;
  final String? statusFilter;
  final String searchQuery;
  final ValueChanged<String?> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final PayoutRowAction onApprove;
  final PayoutMarkPaidAction onMarkPaid;
  final PayoutRowAction onDispute;
  final PayoutRowAction onCancel;
  final String Function(double) formatCurrency;
  final String Function(double) formatCompactCurrency;
  final VoidCallback onRetry;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Yeniden dene')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compactHeader) ...[
          _buildKpiRow(),
          SizedBox(height: density.sectionGap),
        ],
        _buildFilters(),
        SizedBox(height: density.gridSpacing),
        Text(
          'Dönem: $periodLabel · Hakediş tutarları teslim/iade item tarihine göre hesaplanır.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: density.financeKpiSubtitleFontSize,
          ),
        ),
        SizedBox(height: density.gridSpacing),
        _buildList(context),
      ],
    );
  }

  Widget _buildKpiRow() {
    final cards = [
      _MiniKpi('Bekleyen Hakediş', formatCompactCurrency(snapshot.pendingPayout), const Color(0xFFF97316)),
      _MiniKpi('Ödenen Hakediş', formatCompactCurrency(snapshot.paidPayout), const Color(0xFF16A34A)),
      _MiniKpi('Onay Bekleyen', '${snapshot.awaitingApprovalCount}', const Color(0xFF7C3AED)),
      _MiniKpi('Geciken Hakediş', formatCompactCurrency(snapshot.overduePayout), const Color(0xFFDC2626)),
      _MiniKpi('Dönem GMV', formatCompactCurrency(snapshot.periodGmv), const Color(0xFF2563EB)),
      _MiniKpi('Platform Komisyonu', formatCompactCurrency(snapshot.platformCommission), const Color(0xFF0F766E)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1080 ? 3 : constraints.maxWidth >= 640 ? 2 : 1;
        final itemWidth = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - density.gridSpacing * (cols - 1)) / cols;
        return Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: cards
              .map((c) => SizedBox(width: itemWidth, child: _miniCard(c)))
              .toList(),
        );
      },
    );
  }

  Widget _miniCard(_MiniKpi card) {
    return Container(
      padding: EdgeInsets.all(density.financeKpiCardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: card.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: density.financeKpiSubtitleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            card.value,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: density.financeKpiValueFontSize - 2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final activeCount =
        snapshot.rows.where((row) => row.hasPeriodActivity).length;
    final totalStores = snapshot.rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$totalStores mağaza listeleniyor · $activeCount tanesinde dönem satışı var',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Mağaza adı yazın…',
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Mağaza ara',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: onSearchChanged,
              ),
            ),
            SizedBox(
              width: 150,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Durum',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: statusFilter == null || statusFilter!.isEmpty ? '' : statusFilter,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Tümü')),
                      DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                      DropdownMenuItem(value: 'approved', child: Text('Onaylı')),
                      DropdownMenuItem(value: 'paid', child: Text('Ödendi')),
                      DropdownMenuItem(value: 'disputed', child: Text('İtirazlı')),
                      DropdownMenuItem(value: 'cancelled', child: Text('İptal')),
                    ],
                    onChanged: (v) => onStatusFilterChanged(v == null || v.isEmpty ? null : v),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final rows = snapshot.rows;
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          'Mağaza bulunamadı.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: density.gridSpacing,
            mainAxisSpacing: density.gridSpacing,
            childAspectRatio: cols == 1 ? 2.8 : 1.55,
          ),
          itemBuilder: (context, index) => _storeCard(context, rows[index]),
        );
      },
    );
  }

  Widget _storeCard(BuildContext context, AdminFinancePayoutSellerRow row) {
    final inactive = !row.hasPeriodActivity;
    final initial = row.storeName.trim().isNotEmpty
        ? row.storeName.trim()[0].toUpperCase()
        : '?';

    return Opacity(
      opacity: inactive ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inactive ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inactive ? const Color(0xFFE5E7EB) : const Color(0xFFDDD6FE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: inactive
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: inactive
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF7C3AED),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        inactive
                            ? 'Bu dönem satış yok'
                            : '${row.orderCount} sipariş · ${row.itemCount} kalem',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(row.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metricChip('GMV', formatCurrency(row.grossAmount)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _metricChip('Komisyon', formatCurrency(row.commissionAmount)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _metricChip(
                    'Net',
                    formatCurrency(row.netPayoutAmount),
                    bold: true,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _actions(context, row),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'paid' => const Color(0xFF16A34A),
      'approved' => const Color(0xFF2563EB),
      'disputed' => const Color(0xFFDC2626),
      'cancelled' => const Color(0xFF9CA3AF),
      _ => const Color(0xFFF97316),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AdminFinancePayoutHelper.statusLabel(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _actions(BuildContext context, AdminFinancePayoutSellerRow row) {
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => _openDetail(context, row),
          child: const Text('Detay', style: TextStyle(fontSize: 11)),
        ),
        if (row.status != 'paid' && row.status != 'cancelled') ...[
          TextButton(
            onPressed: () => onApprove(row),
            child: const Text('Onayla', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: () => _openMarkPaid(context, row),
            child: const Text('Ödendi', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: () => onDispute(row),
            child: const Text('İtiraz', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: () => onCancel(row),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('İptal', style: TextStyle(fontSize: 11)),
          ),
        ],
      ],
    );
  }

  Future<void> _openDetail(BuildContext context, AdminFinancePayoutSellerRow row) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PayoutDetailDialog(
        row: row,
        periodLabel: periodLabel,
        formatCurrency: formatCurrency,
        onApprove: onApprove,
        onMarkPaid: onMarkPaid,
        onDispute: onDispute,
        onCancel: onCancel,
      ),
    );
  }

  Future<void> _openMarkPaid(BuildContext context, AdminFinancePayoutSellerRow row) async {
    if (row.status == 'pending') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Onay gerekli'),
          content: const Text(
            'Hakediş henüz onaylanmadı. Ödeme kaydı oluşturmadan önce onaylamak ister misiniz?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla ve devam')),
          ],
        ),
      );
      if (proceed == true) await onApprove(row);
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MarkPaidDialog(
        row: row,
        onSubmit: (draft) => onMarkPaid(row, draft),
      ),
    );
  }
}

Future<void> showAdminPayoutMarkPaidDialog(
  BuildContext context, {
  required AdminFinancePayoutSellerRow row,
  required PayoutRowAction onApprove,
  required PayoutMarkPaidAction onMarkPaid,
}) async {
  if (row.status == 'pending') {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Onay gerekli'),
        content: const Text(
          'Hakediş henüz onaylanmadı. Ödeme kaydı oluşturmadan önce onaylamak ister misiniz?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla ve devam')),
        ],
      ),
    );
    if (proceed == true) await onApprove(row);
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _MarkPaidDialog(
      row: row,
      onSubmit: (draft) => onMarkPaid(row, draft),
    ),
  );
}

class _MiniKpi {
  const _MiniKpi(this.label, this.value, this.accent);
  final String label;
  final String value;
  final Color accent;
}

class _PayoutDetailDialog extends StatelessWidget {
  const _PayoutDetailDialog({
    required this.row,
    required this.periodLabel,
    required this.formatCurrency,
    required this.onApprove,
    required this.onMarkPaid,
    required this.onDispute,
    required this.onCancel,
  });

  final AdminFinancePayoutSellerRow row;
  final String periodLabel;
  final String Function(double) formatCurrency;
  final PayoutRowAction onApprove;
  final PayoutMarkPaidAction onMarkPaid;
  final PayoutRowAction onDispute;
  final PayoutRowAction onCancel;

  @override
  Widget build(BuildContext context) {
    final orders = row.orderRows;
    return AlertDialog(
      title: Text('${row.storeName} · $periodLabel'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('GMV', formatCurrency(row.grossAmount)),
              _summaryRow('Komisyon', formatCurrency(row.commissionAmount)),
              _summaryRow('İade', formatCurrency(row.refundAmount)),
              _summaryRow('Net hakediş', formatCurrency(row.netPayoutAmount)),
              _summaryRow('Sipariş', '${row.orderCount}'),
              _summaryRow('Ürün adedi', '${row.itemCount}'),
              _summaryRow('Durum', AdminFinancePayoutHelper.statusLabel(row.status)),
              if ((row.note ?? '').trim().isNotEmpty)
                _summaryRow('Not', row.note!.trim()),
              const SizedBox(height: 12),
              const Text('Sipariş kırılımı', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              if (orders.isEmpty)
                Text('Sipariş kalemi yok.', style: TextStyle(color: Colors.grey.shade600, fontSize: 11))
              else
                ...orders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${order.orderId.length > 8 ? '${order.orderId.substring(0, 8)}…' : order.orderId} · '
                            '${DateFormat('d MMM yy', 'tr_TR').format(order.eventDate)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Text(
                          formatCurrency(order.payout),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: order.isRefund ? const Color(0xFFDC2626) : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        if (row.status != 'paid' && row.status != 'cancelled') ...[
          TextButton(
            onPressed: () async {
              await onApprove(row);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Onayla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await showAdminPayoutMarkPaidDialog(
                context,
                row: row,
                onApprove: onApprove,
                onMarkPaid: onMarkPaid,
              );
            },
            child: const Text('Ödendi İşaretle'),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog({required this.row, required this.onSubmit});
  final AdminFinancePayoutSellerRow row;
  final Future<void> Function(AdminPayoutPaymentDraft draft) onSubmit;

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  final _methodController = TextEditingController(text: 'Banka transferi');
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _methodController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_methodController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        AdminPayoutPaymentDraft(
          paymentMethod: _methodController.text.trim(),
          paymentReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          paidAt: _paidAt,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ödendi işaretle · ${widget.row.storeName}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _methodController,
              decoration: const InputDecoration(labelText: 'Ödeme yöntemi *', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(labelText: 'Ödeme referansı / dekont no', isDense: true),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ödeme tarihi', style: TextStyle(fontSize: 13)),
              subtitle: Text(DateFormat('d MMMM yyyy', 'tr_TR').format(_paidAt)),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paidAt,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _paidAt = picked);
                },
                child: const Text('Seç'),
              ),
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Not', isDense: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet')),
      ],
    );
  }
}
