import 'package:flutter/material.dart';

import '../../models/restaurant_ops_models.dart';

/// Full-featured payment bottom sheet.
///
/// Shows:
///   - Live grand total + remaining balance
///   - Payment timeline (partial payments already recorded)
///   - Add partial payment action
///   - Split bill calculator
///   - Close table action (full payment)
///
/// Returns a [PaymentSheetResult] via Navigator.pop.

class PaymentSheetResult {
  const PaymentSheetResult({
    required this.method,
    required this.amount,
    required this.isClosing,
    this.note,
  });

  final TablePaymentMethod method;
  final double amount;
  final bool isClosing;
  final String? note;
}

class TablePaymentBottomSheet extends StatefulWidget {
  const TablePaymentBottomSheet._({
    required this.tableNumber,
    required this.grandTotal,
    required this.existingPayments,
  });

  final int tableNumber;
  final double grandTotal;
  final List<TablePayment> existingPayments;

  /// Shows the payment sheet and returns the user's chosen action.
  static Future<PaymentSheetResult?> show(
    BuildContext context, {
    required int tableNumber,
    required double grandTotal,
    List<TablePayment> existingPayments = const [],
  }) {
    return showModalBottomSheet<PaymentSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TablePaymentBottomSheet._(
        tableNumber: tableNumber,
        grandTotal: grandTotal,
        existingPayments: existingPayments,
      ),
    );
  }

  @override
  State<TablePaymentBottomSheet> createState() =>
      _TablePaymentBottomSheetState();
}

class _TablePaymentBottomSheetState extends State<TablePaymentBottomSheet> {
  final TablePaymentMethod _selectedMethod = TablePaymentMethod.cash;
  bool _submitting = false;
  final TextEditingController _partialAmountController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  static const _green = Color(0xFF16A34A);

  @override
  void dispose() {
    _partialAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _paidTotal =>
      widget.existingPayments.fold(0.0, (s, p) => s + p.amount);

  double get _remainingTotal {
    final r = widget.grandTotal - _paidTotal;
    return r < 0 ? 0 : r;
  }

  String _formatMoney(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';

  bool get _canConfirmPartial {
    if (_submitting) return false;
    final v = double.tryParse(
        _partialAmountController.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return false;
    final cents = (v * 100).round();
    final remainingCents = (_remainingTotal * 100).round();
    return cents > 0 && cents <= remainingCents;
  }

  String _paymentMethodLabel(TablePaymentMethod m) => m.label;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalCard(),
                  const SizedBox(height: 16),
                  if (widget.existingPayments.isNotEmpty) ...[
                    _buildPaymentTimeline(),
                    const SizedBox(height: 16),
                  ],
                  _buildMethodSelector(),
                  const SizedBox(height: 12),
                  _buildPartialAmountField(),
                  const SizedBox(height: 12),
                  _buildNoteField(),
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: _green,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masa ${widget.tableNumber} — Hesap',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'Toplam: ${_formatMoney(widget.grandTotal)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.grey.shade500,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toplam',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  _formatMoney(widget.grandTotal),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          _TotalColumn(label: 'Ödenen', value: _paidTotal, color: _green),
          const SizedBox(width: 16),
          _TotalColumn(
            label: 'Kalan',
            value: _remainingTotal,
            color: _remainingTotal > 0 ? Colors.orange.shade700 : _green,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ödeme Geçmişi',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: widget.existingPayments.asMap().entries.map((entry) {
              final idx = entry.key;
              final payment = entry.value;
              final time =
                  '${payment.createdAt.hour.toString().padLeft(2, '0')}:${payment.createdAt.minute.toString().padLeft(2, '0')}';
              return Column(
                children: [
                  if (idx > 0) const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        payment.isClosing
                            ? Icons.lock_rounded
                            : Icons.payments_rounded,
                        size: 14,
                        color: _green,
                      ),
                    ),
                    title: Text(
                      payment.method.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '$time${payment.paidBy != null ? ' • ${payment.paidBy}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    trailing: Text(
                      _formatMoney(payment.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _green,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    const methods = [
      (TablePaymentMethod.cash, Icons.payments_rounded, _green),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ödeme Yöntemi',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: methods.map((m) {
            final method = m.$1;
            final icon = m.$2;
            final color = m.$3;
            final selected = _selectedMethod == method;
            return GestureDetector(
              onTap: () {},
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? color : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? color : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 16,
                        color: selected ? Colors.white : color),
                    const SizedBox(width: 6),
                    Text(
                      _paymentMethodLabel(method),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nakit kasa kaydı. Banka veya ödeme kuruluşu onayı yoktur.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildPartialAmountField() {
    return TextField(
      controller: _partialAmountController,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Ara Ödeme Tutarı',
        hintText: 'Maks. ${_formatMoney(_remainingTotal)}',
        prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
        suffixText: '₺',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'Not (opsiyonel)',
        prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: 1,
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle partial mode
        FilledButton.icon(
          onPressed: _canConfirmPartial
              ? () {
                  final raw = double.parse(
                    _partialAmountController.text
                        .trim()
                        .replaceAll(',', '.'),
                  );
                  final amount = ((raw * 100).round()) / 100;
                  setState(() => _submitting = true);
                  Navigator.of(context).pop(PaymentSheetResult(
                    method: _selectedMethod,
                    amount: amount,
                    isClosing: false,
                    note: _noteController.text.trim().isNotEmpty
                        ? _noteController.text.trim()
                        : null,
                  ));
                }
              : null,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('İşlemi onayla'),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            minimumSize: const Size(0, 48),
          ),
        ),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _TotalColumn extends StatelessWidget {
  const _TotalColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  String _fmt(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          _fmt(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

