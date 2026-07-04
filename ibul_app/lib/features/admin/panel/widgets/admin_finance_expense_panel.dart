import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/admin_service.dart';
import '../helpers/admin_finance_expense_helper.dart';
import '../helpers/admin_panel_density.dart';

typedef AdminExpenseSaveCallback = Future<void> Function(AdminExpenseDraft draft);
typedef AdminExpenseCancelCallback = Future<void> Function(AdminExpense expense);

class AdminExpenseDraft {
  const AdminExpenseDraft({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.type,
    this.recurrence,
    required this.status,
    this.paymentMethod,
    this.vendor,
    this.invoiceUrl,
    this.note,
  });

  final String? id;
  final String title;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String type;
  final String? recurrence;
  final String status;
  final String? paymentMethod;
  final String? vendor;
  final String? invoiceUrl;
  final String? note;
}

class AdminFinanceExpensePanel extends StatelessWidget {
  const AdminFinanceExpensePanel({
    super.key,
    required this.density,
    required this.summary,
    required this.expenses,
    required this.isLoading,
    required this.error,
    required this.periodLabel,
    required this.categoryFilter,
    required this.statusFilter,
    required this.typeFilter,
    required this.onCategoryFilterChanged,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onSaveExpense,
    required this.onCancelExpense,
    required this.formatCurrency,
    required this.formatCompactCurrency,
    required this.onRetry,
  });

  final AdminPanelDensity density;
  final AdminFinanceExpenseSummary summary;
  final List<AdminExpense> expenses;
  final bool isLoading;
  final String? error;
  final String periodLabel;
  final String? categoryFilter;
  final String? statusFilter;
  final String? typeFilter;
  final ValueChanged<String?> onCategoryFilterChanged;
  final ValueChanged<String?> onStatusFilterChanged;
  final ValueChanged<String?> onTypeFilterChanged;
  final AdminExpenseSaveCallback onSaveExpense;
  final AdminExpenseCancelCallback onCancelExpense;
  final String Function(double) formatCurrency;
  final String Function(double) formatCompactCurrency;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(context),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiRow(),
        SizedBox(height: density.sectionGap),
        _buildToolbar(context),
        SizedBox(height: density.gridSpacing),
        Text(
          'Dönem: $periodLabel · Yatırım kayıtları giderden ayrı tutulur.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: density.financeKpiSubtitleFontSize,
          ),
        ),
        SizedBox(height: density.gridSpacing),
        _buildExpenseList(context),
      ],
    );
  }

  Widget _buildKpiRow() {
    final largestLabel = summary.largestCategoryKey.isEmpty
        ? '—'
        : AdminFinanceExpenseCategories.labelFor(summary.largestCategoryKey);
    final cards = [
      _MiniKpi(
        label: 'Toplam Gider',
        value: formatCompactCurrency(summary.totalPaid),
        accent: const Color(0xFFEA580C),
      ),
      _MiniKpi(
        label: 'Bekleyen Gider',
        value: formatCompactCurrency(summary.totalPending),
        accent: const Color(0xFFF97316),
      ),
      _MiniKpi(
        label: 'Tekrarlayan Aylık',
        value: formatCompactCurrency(summary.recurringMonthlyTotal),
        accent: const Color(0xFF7C3AED),
      ),
      _MiniKpi(
        label: 'En Büyük Kategori',
        value: largestLabel,
        subtitle: summary.largestCategoryAmount > 0
            ? formatCompactCurrency(summary.largestCategoryAmount)
            : null,
        accent: const Color(0xFF2563EB),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final itemWidth = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - density.gridSpacing * (cols - 1)) / cols;
        return Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _buildMiniKpiCard(card),
                ),
              )
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
          label: const Text('Gider Ekle'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
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
            ...AdminFinanceExpenseCategories.keys.map(
              (key) => MapEntry(key, AdminFinanceExpenseCategories.labelFor(key)),
            ),
          ],
          onChanged: onCategoryFilterChanged,
        ),
        _filterDropdown(
          hint: 'Durum',
          value: statusFilter,
          items: const [
            MapEntry('', 'Tümü'),
            MapEntry('paid', 'Ödendi'),
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

  Widget _buildExpenseList(BuildContext context) {
    if (expenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          'Bu dönem gider kaydı yok.',
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
                  DataColumn(label: Text('Gider adı', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Kategori', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Tutar', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Durum', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Tür', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Açıklama', style: TextStyle(fontSize: 11))),
                  DataColumn(label: Text('Aksiyon', style: TextStyle(fontSize: 11))),
                ],
                rows: expenses.map((expense) => _tableRow(context, expense)).toList(),
              ),
            ),
          );
        }
        return Column(
          children: expenses
              .map((expense) => _expenseCard(context, expense))
              .toList(),
        );
      },
    );
  }

  DataRow _tableRow(BuildContext context, AdminExpense expense) {
    final note = expense.note?.trim() ?? '';
    final typeText = expense.type == 'recurring'
        ? '${AdminFinanceExpenseHelper.typeLabel(expense.type)} · '
            '${AdminFinanceExpenseHelper.recurrenceLabel(expense.recurrence)}'
        : AdminFinanceExpenseHelper.typeLabel(expense.type);
    return DataRow(
      cells: [
        DataCell(Text(
          DateFormat('d MMM yy', 'tr_TR').format(expense.expenseDate),
          style: const TextStyle(fontSize: 11),
        )),
        DataCell(Text(expense.title, style: const TextStyle(fontSize: 11))),
        DataCell(Text(
          AdminFinanceExpenseCategories.labelFor(expense.category),
          style: const TextStyle(fontSize: 11),
        )),
        DataCell(Text(
          formatCurrency(expense.amount),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        )),
        DataCell(Text(
          AdminFinanceExpenseHelper.statusLabel(expense.status),
          style: TextStyle(
            fontSize: 11,
            color: expense.status == 'pending'
                ? const Color(0xFFF97316)
                : expense.status == 'cancelled'
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF16A34A),
          ),
        )),
        DataCell(Text(typeText, style: const TextStyle(fontSize: 11))),
        DataCell(Text(
          note.isEmpty ? '—' : note,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        )),
        DataCell(_actionButtons(context, expense)),
      ],
    );
  }

  Widget _expenseCard(BuildContext context, AdminExpense expense) {
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
                  expense.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                formatCurrency(expense.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('d MMM yyyy', 'tr_TR').format(expense.expenseDate)} · '
            '${AdminFinanceExpenseCategories.labelFor(expense.category)} · '
            '${AdminFinanceExpenseHelper.statusLabel(expense.status)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          if ((expense.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(expense.note!.trim(), style: const TextStyle(fontSize: 11)),
          ],
          const SizedBox(height: 8),
          _actionButtons(context, expense),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context, AdminExpense expense) {
    if (expense.status == 'cancelled') {
      return const Text('İptal edildi', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)));
    }
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => _openForm(context, expense: expense),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Düzenle', style: TextStyle(fontSize: 11)),
        ),
        TextButton(
          onPressed: () => onCancelExpense(expense),
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

  Future<void> _openForm(BuildContext context, {AdminExpense? expense}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AdminExpenseFormDialog(
        initial: expense,
        onSave: onSaveExpense,
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

class _AdminExpenseFormDialog extends StatefulWidget {
  const _AdminExpenseFormDialog({
    required this.initial,
    required this.onSave,
  });

  final AdminExpense? initial;
  final AdminExpenseSaveCallback onSave;

  @override
  State<_AdminExpenseFormDialog> createState() => _AdminExpenseFormDialogState();
}

class _AdminExpenseFormDialogState extends State<_AdminExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _vendorController;
  late final TextEditingController _invoiceUrlController;
  late final TextEditingController _noteController;
  late String _category;
  late String _status;
  late String _type;
  String? _recurrence;
  late DateTime _expenseDate;
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
    _paymentMethodController =
        TextEditingController(text: initial?.paymentMethod ?? '');
    _vendorController = TextEditingController(text: initial?.vendor ?? '');
    _invoiceUrlController = TextEditingController(text: initial?.invoiceUrl ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _category = initial?.category ?? AdminFinanceExpenseCategories.keys.first;
    _status = initial?.status ?? 'paid';
    _type = initial?.type ?? 'one_time';
    _recurrence = initial?.recurrence ?? 'monthly';
    _expenseDate = initial?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _vendorController.dispose();
    _invoiceUrlController.dispose();
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
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tekrarlayan gider için periyot seçin.')),
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSave(
        AdminExpenseDraft(
          id: widget.initial?.id,
          title: _titleController.text.trim(),
          category: _category,
          amount: _parseAmount(_amountController.text),
          expenseDate: _expenseDate,
          type: _type,
          recurrence: _type == 'recurring' ? _recurrence : null,
          status: _status,
          paymentMethod: _paymentMethodController.text.trim().isEmpty
              ? null
              : _paymentMethodController.text.trim(),
          vendor: _vendorController.text.trim().isEmpty
              ? null
              : _vendorController.text.trim(),
          invoiceUrl: _invoiceUrlController.text.trim().isEmpty
              ? null
              : _invoiceUrlController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = '$error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Gider Ekle' : 'Gideri Düzenle'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Gider adı *',
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Gider adı zorunlu' : null,
                ),
                const SizedBox(height: 10),
                _labeledDropdown(
                  label: 'Kategori *',
                  value: _category,
                  items: AdminFinanceExpenseCategories.keys
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(AdminFinanceExpenseCategories.labelFor(key)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tutar *',
                    isDense: true,
                  ),
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
                  subtitle: Text(DateFormat('d MMMM yyyy', 'tr_TR').format(_expenseDate)),
                  trailing: TextButton(onPressed: _pickDate, child: const Text('Seç')),
                ),
                const SizedBox(height: 10),
                _labeledDropdown(
                  label: 'Durum',
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'paid', child: Text('Ödendi')),
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
                  controller: _paymentMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Ödeme yöntemi',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _vendorController,
                  decoration: const InputDecoration(
                    labelText: 'Firma / Tedarikçi',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _invoiceUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Fatura URL',
                    isDense: true,
                  ),
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
