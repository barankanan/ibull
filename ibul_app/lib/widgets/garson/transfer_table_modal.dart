import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/restaurant_ops_models.dart';

/// Transfer table modal.
///
/// Supports three transfer modes:
///   - [TableTransferType.full]          — moves every order/item
///   - [TableTransferType.partial]       — checkbox-based item selection
///   - [TableTransferType.customerBased] — groups items by "customer" label
///
/// Target tables are described by [TransferTargetTable] so the picker can show
/// each table's real label (e.g. "Bahçe 3"), group them by area (Salon, Bahçe,
/// Teras …) and highlight occupied tables in red.
///
/// Usage:
/// ```dart
/// final result = await TransferTableModal.show(
///   context,
///   tableNumber: 3,
///   availableTables: targets,
///   allItems: flatItemList,  // flattened from all table_orders
/// );
/// if (result != null) { /* perform transfer */ }
/// ```

/// Describes a single table the order can be transferred to.
class TransferTargetTable {
  const TransferTargetTable({
    required this.tableNumber,
    required this.label,
    this.areaName = '',
    this.isOccupied = false,
  });

  /// Canonical seller-wide table number (matches `store_tables.table_number`).
  final int tableNumber;

  /// Human label to render on the chip (e.g. "Bahçe 3", "Salon 1").
  final String label;

  /// Area this table belongs to (e.g. "Salon", "Bahçe", "Teras").
  /// Empty string → grouped under a generic "Diğer" bucket.
  final String areaName;

  /// True when the table currently has at least one active (non-closed) order.
  final bool isOccupied;
}

class TransferTableResult {
  const TransferTableResult({
    required this.toTable,
    required this.transferType,
    required this.selectedItemIds,
    this.note,
  });

  final int toTable;
  final TableTransferType transferType;
  final List<String> selectedItemIds; // empty → full transfer
  final String? note;
}

class TransferTableModal extends StatefulWidget {
  const TransferTableModal._({
    required this.tableNumber,
    required this.availableTables,
    required this.allItems,
    this.sourceLabel,
  });

  final int tableNumber;

  /// Source table label shown in the header (e.g. "Bahçe 3").
  final String? sourceLabel;

  /// Tables the current order can be transferred to.
  final List<TransferTargetTable> availableTables;

  /// Flat list of all order items currently on this table.
  /// Each map must have at minimum: 'id', 'name', 'quantity', 'price'.
  final List<Map<String, dynamic>> allItems;

  static Future<TransferTableResult?> show(
    BuildContext context, {
    required int tableNumber,
    required List<TransferTargetTable> availableTables,
    required List<Map<String, dynamic>> allItems,
    String? sourceLabel,
  }) {
    return showModalBottomSheet<TransferTableResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferTableModal._(
        tableNumber: tableNumber,
        availableTables: availableTables,
        allItems: allItems,
        sourceLabel: sourceLabel,
      ),
    );
  }

  @override
  State<TransferTableModal> createState() => _TransferTableModalState();
}

class _TransferTableModalState extends State<TransferTableModal> {
  TableTransferType _transferType = TableTransferType.full;
  int? _targetTable;
  final Set<String> _selectedItemIds = {};
  final TextEditingController _noteController = TextEditingController();

  static const _primaryColor = Color(0xFF2563EB);
  static const _occupiedColor = Color(0xFFDC2626);

  /// Tables grouped by area, preserving the incoming order of areas and tables.
  List<MapEntry<String, List<TransferTargetTable>>> get _tablesByArea {
    final grouped = <String, List<TransferTargetTable>>{};
    final order = <String>[];
    for (final table in widget.availableTables) {
      final area = table.areaName.trim().isEmpty ? 'Diğer' : table.areaName.trim();
      if (!grouped.containsKey(area)) {
        grouped[area] = <TransferTargetTable>[];
        order.add(area);
      }
      grouped[area]!.add(table);
    }
    return order.map((area) => MapEntry(area, grouped[area]!)).toList();
  }

  TransferTargetTable? get _selectedTable {
    for (final table in widget.availableTables) {
      if (table.tableNumber == _targetTable) return table;
    }
    return null;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_targetTable == null) return false;
    if (_transferType == TableTransferType.partial &&
        _selectedItemIds.isEmpty) {
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> get _groupedByCustomer {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in widget.allItems) {
      final customer =
          item['customer']?.toString().trim().isNotEmpty == true
          ? item['customer'].toString().trim()
          : 'Müşteri 1';
      grouped.putIfAbsent(customer, () => []).add(item);
    }
    return grouped.entries
        .map((e) => {'customer': e.key, 'items': e.value})
        .toList();
  }

  void _toggleCustomerItems(List<Map<String, dynamic>> items, bool select) {
    setState(() {
      for (final item in items) {
        final id = _itemId(item);
        if (select) {
          _selectedItemIds.add(id);
        } else {
          _selectedItemIds.remove(id);
        }
      }
    });
  }

  String _itemId(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    if (id.isNotEmpty) return id;
    // Fallback: use name + index to differentiate duplicates
    return '${item['name']}_${item['quantity']}';
  }

  double _itemTotal(Map<String, dynamic> item) {
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
    return price * qty;
  }

  String _formatMoney(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTargetTableSelector(),
                  const SizedBox(height: 16),
                  _buildTransferTypeSelector(),
                  const SizedBox(height: 16),
                  if (_transferType == TableTransferType.partial)
                    _buildItemSelector(),
                  if (_transferType == TableTransferType.customerBased)
                    _buildCustomerSelector(),
                  const SizedBox(height: 12),
                  _buildNoteField(),
                  const SizedBox(height: 20),
                  _buildConfirmButton(),
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
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.compare_arrows_rounded,
              color: _primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masa Aktar — ${widget.sourceLabel?.trim().isNotEmpty == true ? widget.sourceLabel!.trim() : 'Masa ${widget.tableNumber}'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  '${widget.allItems.length} ürün aktarılabilir',
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

  Widget _buildTargetTableSelector() {
    final groups = _tablesByArea;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Hedef Masa',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            if (widget.availableTables.any((t) => t.isOccupied))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: _occupiedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Dolu',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _occupiedColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Aktarılabilecek başka masa bulunamadı.',
              style: TextStyle(fontSize: 12),
            ),
          )
        else
          ...groups.map((entry) {
            final area = entry.key;
            final tables = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tables.map(_buildTargetTableChip).toList(),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTargetTableChip(TransferTargetTable table) {
    final selected = _targetTable == table.tableNumber;
    final occupied = table.isOccupied;

    final Color background;
    final Color borderColor;
    final Color textColor;
    if (selected) {
      background = occupied ? _occupiedColor : _primaryColor;
      borderColor = background;
      textColor = Colors.white;
    } else if (occupied) {
      background = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      textColor = _occupiedColor;
    } else {
      background = const Color(0xFFF1F5F9);
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF374151);
    }

    return GestureDetector(
      onTap: () => setState(() => _targetTable = table.tableNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (occupied) ...[
              Icon(
                Icons.circle,
                size: 8,
                color: selected ? Colors.white : _occupiedColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              table.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktarım Türü',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: TableTransferType.values.map((type) {
            final selected = _transferType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _transferType = type;
                  _selectedItemIds.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(
                    right: type != TableTransferType.customerBased ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? _primaryColor
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? _primaryColor
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    type.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildItemSelector() {
    if (widget.allItems.isEmpty) {
      return const _EmptyStateBox(message: 'Bu masada seçilebilecek ürün yok.');
    }
    final allSelected = widget.allItems
        .every((item) => _selectedItemIds.contains(_itemId(item)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Aktarılacak Ürünler',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selectedItemIds.clear();
                } else {
                  for (final item in widget.allItems) {
                    _selectedItemIds.add(_itemId(item));
                  }
                }
              }),
              child: Text(
                allSelected ? 'Tümünü Kaldır' : 'Tümünü Seç',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: widget.allItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final id = _itemId(item);
              final isChecked = _selectedItemIds.contains(id);
              final total = _itemTotal(item);
              return Column(
                children: [
                  if (idx > 0)
                    const Divider(height: 1, indent: 48),
                  CheckboxListTile(
                    value: isChecked,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedItemIds.add(id);
                      } else {
                        _selectedItemIds.remove(id);
                      }
                    }),
                    title: Text(
                      item['name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${(item['quantity'] as num?)?.toInt() ?? 1} adet',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    secondary: Text(
                      _formatMoney(total),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _primaryColor,
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        if (_selectedItemIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedItemIds.length} / ${widget.allItems.length} ürün seçildi',
              style: TextStyle(
                fontSize: 12,
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerSelector() {
    final groups = _groupedByCustomer;
    if (groups.isEmpty) {
      return const _EmptyStateBox(
          message: 'Müşteri bazlı gruplama için sipariş kalemi gerekli.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Müşteri Seç',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        ...groups.map((group) {
          final customer = group['customer'].toString();
          final items = group['items'] as List<Map<String, dynamic>>;
          final customerItemIds =
              items.map(_itemId).toSet();
          final allSelected =
              customerItemIds.every(_selectedItemIds.contains);
          final total =
              items.fold(0.0, (sum, item) => sum + _itemTotal(item));
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: allSelected
                  ? _primaryColor.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: allSelected
                    ? _primaryColor.withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: CheckboxListTile(
              value: allSelected,
              tristate: customerItemIds
                      .any(_selectedItemIds.contains) &&
                  !allSelected,
              onChanged: (v) =>
                  _toggleCustomerItems(items, v ?? !allSelected),
              title: Text(
                customer,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${items.length} ürün — ${_formatMoney(total)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              activeColor: _primaryColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'Not (opsiyonel)',
        hintText: 'Aktarım notu...',
        prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: 1,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _canConfirm
            ? () {
                final result = TransferTableResult(
                  toTable: _targetTable!,
                  transferType: _transferType,
                  selectedItemIds: _transferType == TableTransferType.full
                      ? const <String>[]
                      : _selectedItemIds.toList(),
                  note: _noteController.text.trim().isNotEmpty
                      ? _noteController.text.trim()
                      : null,
                );
                Navigator.of(context).pop(result);
              }
            : null,
        icon: const Icon(Icons.compare_arrows_rounded, size: 18),
        label: Text(
          _targetTable == null
              ? 'Hedef masa seçin'
              : '${_selectedTable?.label ?? 'Masa $_targetTable'}\'e Aktar',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          minimumSize: const Size(0, 48),
        ),
      ),
    );
  }
}

class _EmptyStateBox extends StatelessWidget {
  const _EmptyStateBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }
}
