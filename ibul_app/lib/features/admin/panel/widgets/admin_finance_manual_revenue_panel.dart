import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/admin_service.dart';
import '../helpers/admin_finance_manual_revenue_helper.dart';
import '../helpers/admin_panel_density.dart';

typedef AdminRevenueSaveCallback = Future<void> Function(AdminRevenueDraft draft);
typedef AdminRevenueCancelCallback = Future<void> Function(AdminRevenue revenue);

class AdminRevenueDraft {
  const AdminRevenueDraft({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.revenueDate,
    required this.type,
    this.recurrence,
    required this.status,
    this.source,
    this.paymentMethod,
    this.referenceNo,
    this.note,
  });

  final String? id;
  final String title;
  final String category;
  final double amount;
  final DateTime revenueDate;
  final String type;
  final String? recurrence;
  final String status;
  final String? source;
  final String? paymentMethod;
  final String? referenceNo;
  final String? note;
}

class AdminFinanceManualRevenuePanel extends StatelessWidget {
  const AdminFinanceManualRevenuePanel({
    super.key,
    required this.density,
    required this.summary,
    required this.revenues,
    required this.isLoading,
    required this.error,
    required this.periodLabel,
    required this.categoryFilter,
    required this.statusFilter,
    required this.typeFilter,
    required this.onCategoryFilterChanged,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onSaveRevenue,
    required this.onCancelRevenue,
    required this.formatCurrency,
    required this.formatCompactCurrency,
    required this.onRetry,
  });

  final AdminPanelDensity density;
  final AdminFinanceManualRevenueSummary summary;
  final List<AdminRevenue> revenues;
  final bool isLoading;
  final String? error;
  final String periodLabel;
  final String? categoryFilter;
  final String? statusFilter;
  final String? typeFilter;
  final ValueChanged<String?> onCategoryFilterChanged;
  final ValueChanged<String?> onStatusFilterChanged;
  final ValueChanged<String?> onTypeFilterChanged;
  final AdminRevenueSaveCallback onSaveRevenue;
  final AdminRevenueCancelCallback onCancelRevenue;
  final String Function(double) formatCurrency;
  final String Function(double) formatCompactCurrency;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
              ],
            ),
          ),
          SizedBox(height: density.gridSpacing),
        ],
        _buildKpiRow(),
        SizedBox(height: density.sectionGap),
        _buildToolbar(context),
        SizedBox(height: density.gridSpacing),
        Text(
          'Dönem: $periodLabel · Otomatik gelirler sistemden hesaplanır; aşağıdaki kayıtlar manuel girilir.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: density.financeKpiSubtitleFontSize,
          ),
        ),
        SizedBox(height: density.gridSpacing),
        _buildRevenueList(context),
      ],
    );
  }

  Widget _buildKpiRow() {
    final largestLabel = summary.largestCategoryKey.isEmpty
        ? '—'
        : AdminFinanceRevenueCategories.labelFor(summary.largestCategoryKey);
    final cards = [
      _MiniKpi(
        label: 'Manuel Gelir',
        value: formatCompactCurrency(summary.totalReceived),
        accent: const Color(0xFF0F766E),
      ),
      _MiniKpi(
        label: 'Bekleyen Gelir',
        value: formatCompactCurrency(summary.totalPending),
        accent: const Color(0xFFF97316),
      ),
      _MiniKpi(
        label: 'Tekrarlayan Aylık',
        value: formatCompactCurrency(summary.recurringMonthlyTotal),
        accent: const Color(0xFF7C3AED),
      ),
      _MiniKpi(
        label: 'En Büyük Kaynak',
        value: largestLabel,
        subtitle: summary.largestCategoryAmount > 0
            ? formatCompactCurrency(summary.largestCategoryAmount)
            : null,
        accent: const Color(0xFF2563EB),
      ),
      _MiniKpi(
        label: 'Emlak / Kira',
        value: formatCompactCurrency(summary.propertyRentTotal),
        accent: const Color(0xFF6B7280),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 640
            ? 3
            : constraints.maxWidth >= 360
            ? 2
            : 1;
        final itemWidth = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - density.gridSpacing * (cols - 1)) / cols;
        return Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: _buildMiniKpiCard(card)))
              .toList(),
        );
      },
    );
  }

  Widget _buildMiniKpiCard(_MiniKpi card) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: density.financeKpiValueFontSize - 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (card.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              card.subtitle!,
              style: TextStyle(
                color: const Color(0xFF6B7280),
                fontSize: density.financeKpiSubtitleFontSize,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Gelir Ekle'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        _filterDropdown(
          hint: 'Kategori',
          value: categoryFilter,
          items: [
            const MapEntry('', 'Tümü'),
            ...AdminFinanceRevenueCategories.keys.map(
              (key) => MapEntry(key, AdminFinanceRevenueCategories.labelFor(key)),
            ),
          ],
          onChanged: onCategoryFilterChanged,
        ),
        _filterDropdown(
          hint: 'Durum',
          value: statusFilter,
          items: const [
            MapEntry('', 'Tümü'),
            MapEntry('received', 'Alındı'),
            MapEntry('pending', 'Bekliyor'),
            MapEntry('cancelled', 'İptal'),
          ],
          onChanged: onStatusFilterChanged,
        ),
        _filterDropdown(
          hint: 'Tür',
          value: typeFilter,
          items: const [
            MapEntry('', 'Tümü'),
            MapEntry('one_time', 'Tek seferlik'),
            MapEntry('recurring', 'Tekrarlayan'),
          ],
          onChanged: onTypeFilterChanged,
        ),
      ],
    );
  }

  Widget _filterDropdown({
    required String hint,
    required String? value,
    required List<MapEntry<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 140,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          labelText: hint,
          labelStyle: const TextStyle(fontSize: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value == null || value.isEmpty ? '' : value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: items
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (selected) =>
                onChanged(selected == null || selected.isEmpty ? null : selected),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueList(BuildContext context) {
    if (revenues.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          error == null ? 'Bu dönem manuel gelir kaydı yok.' : 'Liste yüklenemedi.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columnSpacing: 16,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Text('Tarih', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Gelir adı', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Kategori', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Tutar', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Durum', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Tür', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Kaynak', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Aksiyon', style: TextStyle(fontSize: 11))),
                ],
                rows: revenues.map((r) => _tableRow(context, r)).toList(),
              ),
            ),
          );
        }
        return Column(
          children: revenues.map((r) => _revenueCard(context, r)).toList(),
        );
      },
    );
  }

  DataRow _tableRow(BuildContext context, AdminRevenue revenue) {
    final typeText = revenue.type == 'recurring'
        ? '${AdminFinanceManualRevenueHelper.typeLabel(revenue.type)} · '
            '${AdminFinanceManualRevenueHelper.recurrenceLabel(revenue.recurrence)}'
        : AdminFinanceManualRevenueHelper.typeLabel(revenue.type);
    return DataRow(
      cells: [
        DataCell(Text(
          DateFormat('d MMM yy', 'tr_TR').format(revenue.revenueDate),
          style: const TextStyle(fontSize: 11),
        )),
        DataCell(Text(revenue.title, style: const TextStyle(fontSize: 11))),
        DataCell(Text(
          AdminFinanceRevenueCategories.labelFor(revenue.category),
          style: const TextStyle(fontSize: 11),
        )),
        DataCell(Text(
          formatCurrency(revenue.amount),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        )),
        DataCell(Text(
          AdminFinanceManualRevenueHelper.statusLabel(revenue.status),
          style: TextStyle(
            fontSize: 11,
            color: revenue.status == 'pending'
                ? const Color(0xFFF97316)
                : revenue.status == 'cancelled'
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF16A34A),
          ),
        )),
        DataCell(Text(typeText, style: const TextStyle(fontSize: 11))),
        DataCell(Text(
          (revenue.source ?? '').trim().isEmpty ? '—' : revenue.source!.trim(),
          style: const TextStyle(fontSize: 11),
        )),
        DataCell(_actionButtons(context, revenue)),
      ],
    );
  }

  Widget _revenueCard(BuildContext context, AdminRevenue revenue) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  revenue.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Text(
                formatCurrency(revenue.amount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('d MMM yyyy', 'tr_TR').format(revenue.revenueDate)} · '
            '${AdminFinanceRevenueCategories.labelFor(revenue.category)} · '
            '${AdminFinanceManualRevenueHelper.statusLabel(revenue.status)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _actionButtons(context, revenue),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context, AdminRevenue revenue) {
    if (revenue.status == 'cancelled') {
      return const Text('İptal edildi', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)));
    }
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => _openForm(context, revenue: revenue),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Düzenle', style: TextStyle(fontSize: 11)),
        ),
        TextButton(
          onPressed: () => onCancelRevenue(revenue),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: const Color(0xFFDC2626),
          ),
          child: const Text('İptal', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, {AdminRevenue? revenue}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AdminRevenueFormDialog(
        initial: revenue,
        onSave: onSaveRevenue,
      ),
    );
  }
}

class _MiniKpi {
  const _MiniKpi({
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color accent;
  final String? subtitle;
}

class _AdminRevenueFormDialog extends StatefulWidget {
  const _AdminRevenueFormDialog({
    required this.initial,
    required this.onSave,
  });

  final AdminRevenue? initial;
  final AdminRevenueSaveCallback onSave;

  @override
  State<_AdminRevenueFormDialog> createState() => _AdminRevenueFormDialogState();
}

class _AdminRevenueFormDialogState extends State<_AdminRevenueFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _sourceController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _referenceController;
  late final TextEditingController _noteController;
  late String _category;
  late String _status;
  late String _type;
  String? _recurrence;
  late DateTime _revenueDate;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(0),
    );
    _sourceController = TextEditingController(text: initial?.source ?? '');
    _paymentMethodController =
        TextEditingController(text: initial?.paymentMethod ?? '');
    _referenceController = TextEditingController(text: initial?.referenceNo ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _category = initial?.category ?? AdminFinanceRevenueCategories.keys.first;
    _status = initial?.status ?? 'received';
    _type = initial?.type ?? 'one_time';
    _recurrence = initial?.recurrence ?? 'monthly';
    _revenueDate = initial?.revenueDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _sourceController.dispose();
    _paymentMethodController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _parseAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _revenueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _revenueDate = picked);
  }

  Widget _labeledDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == 'recurring' && (_recurrence == null || _recurrence!.isEmpty)) {
      setState(() => _errorMessage = 'Tekrarlayan gelir için periyot seçin.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSave(
        AdminRevenueDraft(
          id: widget.initial?.id,
          title: _titleController.text.trim(),
          category: _category,
          amount: _parseAmount(_amountController.text),
          revenueDate: _revenueDate,
          type: _type,
          recurrence: _type == 'recurring' ? _recurrence : null,
          status: _status,
          source: _sourceController.text.trim().isEmpty
              ? null
              : _sourceController.text.trim(),
          paymentMethod: _paymentMethodController.text.trim().isEmpty
              ? null
              : _paymentMethodController.text.trim(),
          referenceNo: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = '$error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Gelir Ekle' : 'Geliri Düzenle'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Gelir adı *', isDense: true),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Gelir adı zorunlu' : null,
                ),
                const SizedBox(height: 10),
                _labeledDropdown(
                  label: 'Kategori *',
                  value: _category,
                  items: AdminFinanceRevenueCategories.keys
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(AdminFinanceRevenueCategories.labelFor(key)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar *', isDense: true),
                  validator: (v) {
                    final amount = _parseAmount(v ?? '');
                    if (amount <= 0) return 'Tutar 0\'dan büyük olmalı';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tarih *', style: TextStyle(fontSize: 13)),
                  subtitle: Text(DateFormat('d MMMM yyyy', 'tr_TR').format(_revenueDate)),
                  trailing: TextButton(onPressed: _pickDate, child: const Text('Seç')),
                ),
                const SizedBox(height: 10),
                _labeledDropdown(
                  label: 'Durum',
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'received', child: Text('Alındı')),
                    DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 10),
                _labeledDropdown(
                  label: 'Tür',
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 'one_time', child: Text('Tek seferlik')),
                    DropdownMenuItem(value: 'recurring', child: Text('Tekrarlayan')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                if (_type == 'recurring') ...[
                  const SizedBox(height: 10),
                  _labeledDropdown(
                    label: 'Tekrar periyodu *',
                    value: _recurrence ?? 'monthly',
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Haftalık')),
                      DropdownMenuItem(value: 'monthly', child: Text('Aylık')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yıllık')),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sourceController,
                  decoration: const InputDecoration(labelText: 'Kaynak', isDense: true),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _paymentMethodController,
                  decoration: const InputDecoration(labelText: 'Ödeme yöntemi', isDense: true),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(labelText: 'Referans no', isDense: true),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Not', isDense: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}
