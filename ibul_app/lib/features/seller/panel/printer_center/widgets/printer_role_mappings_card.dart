import 'package:flutter/material.dart';

import '../../../../../models/desktop_printer_setup_models.dart';
import '../../../../../models/printer_model.dart';
import '../printer_assignment_state.dart';

class PrinterRoleMappingsCard extends StatelessWidget {
  const PrinterRoleMappingsCard({
    super.key,
    required this.printers,
    required this.selectedReceiptPrinterId,
    required this.selectedKitchenPrinterId,
    required this.roleMappingsDirty,
    required this.saving,
    required this.onReceiptChanged,
    required this.onKitchenChanged,
    required this.onSave,
    required this.onReceiptTest,
    required this.onKitchenTest,
    required this.testing,
    required this.bridgePrinters,
  });

  final List<PrinterModel> printers;
  final String? selectedReceiptPrinterId;
  final String? selectedKitchenPrinterId;
  final bool roleMappingsDirty;
  final bool saving;
  final bool testing;
  final ValueChanged<String?> onReceiptChanged;
  final ValueChanged<String?> onKitchenChanged;
  final VoidCallback onSave;
  final VoidCallback onReceiptTest;
  final VoidCallback onKitchenTest;
  final List<Map<String, dynamic>> bridgePrinters;

  @override
  Widget build(BuildContext context) {
    final receiptId = PrinterAssignmentState.normalizeSelectedPrinterId(
      printers: printers,
      selectedPrinterId: selectedReceiptPrinterId,
      bridgePrinters: bridgePrinters,
    );
    final kitchenId = PrinterAssignmentState.normalizeSelectedPrinterId(
      printers: printers,
      selectedPrinterId: selectedKitchenPrinterId,
      bridgePrinters: bridgePrinters,
    );
    final receiptError = PrinterAssignmentState.roleSelectionError(
      role: PrinterSetupRole.adisyon,
      selectedPrinterId: receiptId,
      printers: printers,
    );
    final kitchenError = PrinterAssignmentState.roleSelectionError(
      role: PrinterSetupRole.mutfak,
      selectedPrinterId: kitchenId,
      printers: printers,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Rol Eşleştirmeleri',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (roleMappingsDirty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: const Text(
                    'Kaydedilmemiş',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Adisyon ve mutfak yazıcıları burada kalıcı olarak kaydedilir. Canlı taramada görünmese bile kayıtlı yazıcı seçili kalır.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 14),
          _roleDropdown(
            label: 'Adisyon yazıcısı',
            value: receiptId,
            hintError: receiptError,
            keySuffix: receiptId ?? 'none',
            onChanged: onReceiptChanged,
          ),
          const SizedBox(height: 12),
          _roleDropdown(
            label: 'Mutfak yazıcısı',
            value: kitchenId,
            hintError: kitchenError,
            keySuffix: kitchenId ?? 'none',
            onChanged: onKitchenChanged,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: printers.isEmpty || saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Rol eşleştirmelerini kaydet'),
              ),
              OutlinedButton.icon(
                onPressed: receiptId == null || testing ? null : onReceiptTest,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Adisyon Test Fişi'),
              ),
              OutlinedButton.icon(
                onPressed: kitchenId == null || testing ? null : onKitchenTest,
                icon: const Icon(Icons.restaurant_menu_outlined, size: 16),
                label: const Text('Mutfak Genel Test Fişi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleDropdown({
    required String label,
    required String? value,
    required String? hintError,
    required String keySuffix,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey<String>('role-${label == 'Adisyon yazıcısı' ? 'receipt' : 'kitchen'}-$keySuffix'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: hintError,
          ),
          items: printers
              .map(
                (printer) => DropdownMenuItem<String>(
                  value: printer.id,
                  child: Text(printer.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
