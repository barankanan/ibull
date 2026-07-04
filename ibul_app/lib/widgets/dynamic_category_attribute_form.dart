import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/category_attribute_form_provider.dart';
import '../models/category_attribute_definition.dart';

class DynamicCategoryAttributeForm extends StatefulWidget {
  const DynamicCategoryAttributeForm({
    super.key,
    this.title = 'Ürün Özellikleri',
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  State<DynamicCategoryAttributeForm> createState() =>
      _DynamicCategoryAttributeFormState();
}

class _DynamicCategoryAttributeFormState
    extends State<DynamicCategoryAttributeForm> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _customKeyControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _customValueControllers =
      <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _customKeyControllers.values) {
      controller.dispose();
    }
    for (final controller in _customValueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryAttributeFormProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return _buildShell(
            context,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (provider.errorMessage != null && !provider.hasDefinitions) {
          return _buildShell(
            context,
            child: Text(
              'Hazır özellikler yüklenemedi. Manuel alanlara geçebilirsiniz.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          );
        }

        if (!provider.hasDefinitions) {
          return _buildShell(
            context,
            child: Text(
              'Bu alt kategori için hazır attribute bulunamadı.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          );
        }

        return _buildShell(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...provider.definitions.map((definition) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildField(context, provider, definition),
                );
              }),
              const SizedBox(height: 8),
              _buildCustomAttributeRows(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle ??
                'Alt kategoriye göre hazırlanan alanlar otomatik gelir. Değerleri seçebilir veya elle yazabilirsiniz.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    CategoryAttributeFormProvider provider,
    CategoryAttributeDefinition definition,
  ) {
    final rawValue = provider.valuesByAttributeId[definition.id] ?? '';
    final displayValue =
        CategoryAttributeFormProvider.isPlaceholderValue(rawValue)
        ? ''
        : rawValue;
    final controller = _controllerFor(definition.id, displayValue);

    return TextFormField(
      controller: controller,
      keyboardType: definition.isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _inputDecoration(
        label: definition.name,
        filterable: definition.filterable,
        hint: _hintForDefinition(definition),
        suffixIcon: definition.isSelect && definition.options.isNotEmpty
            ? IconButton(
                tooltip: 'Önerilen değerler',
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: () => _showOptionPicker(
                  context,
                  definition,
                  controller,
                  provider,
                ),
              )
            : null,
      ),
      onChanged: (value) => provider.setValue(definition.id, value),
    );
  }

  Widget _buildCustomAttributeRows(
    BuildContext context,
    CategoryAttributeFormProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.customAttributeRows.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Özellik Başlığı',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Açıklama / Değer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 8),
          ...provider.customAttributeRows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final rowId = row['id'] ?? 'custom-$index';
            final keyController = _customControllerFor(
              _customKeyControllers,
              '$rowId-key',
              row['key'] ?? '',
            );
            final valueController = _customControllerFor(
              _customValueControllers,
              '$rowId-value',
              row['value'] ?? '',
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: keyController,
                      decoration: InputDecoration(
                        hintText: 'Örn: Kasa Durumu',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          provider.setCustomAttributeKey(index, value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: valueController,
                      decoration: InputDecoration(
                        hintText: 'Örn: Çiziksiz',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          provider.setCustomAttributeValue(index, value),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final id = row['id'] ?? 'custom-$index';
                      _customKeyControllers.remove('$id-key')?.dispose();
                      _customValueControllers.remove('$id-value')?.dispose();
                      provider.removeCustomAttributeRow(index);
                    },
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade400,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: provider.addCustomAttributeRow,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ Ek Özellik Ekle'),
          ),
        ),
      ],
    );
  }

  Future<void> _showOptionPicker(
    BuildContext context,
    CategoryAttributeDefinition definition,
    TextEditingController controller,
    CategoryAttributeFormProvider provider,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: definition.options
                .map(
                  (option) => ListTile(
                    title: Text(option),
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) return;
    controller.text = selected;
    provider.setValue(definition.id, selected, notify: true);
  }

  String? _hintForDefinition(CategoryAttributeDefinition definition) {
    final nameLower = definition.name.trim().toLowerCase();
    if (nameLower == 'marka') return 'Marka seçin veya yazın';
    if (nameLower == 'model') return 'Model giriniz';
    if (definition.isNumber) return 'Sayısal değer girin';
    if (definition.isSelect && definition.options.isNotEmpty) {
      return 'Değer seçin veya yazın';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required bool filterable,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: filterable ? '$label • Filtrelenebilir' : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  TextEditingController _controllerFor(
    String attributeId,
    String initialValue,
  ) {
    final existing = _controllers[attributeId];
    if (existing != null) {
      if (existing.text != initialValue) {
        existing.text = initialValue;
        existing.selection = TextSelection.fromPosition(
          TextPosition(offset: existing.text.length),
        );
      }
      return existing;
    }
    final controller = TextEditingController(text: initialValue);
    _controllers[attributeId] = controller;
    return controller;
  }

  TextEditingController _customControllerFor(
    Map<String, TextEditingController> store,
    String key,
    String initialValue,
  ) {
    final existing = store[key];
    if (existing != null) {
      if (existing.text != initialValue) {
        existing.text = initialValue;
        existing.selection = TextSelection.fromPosition(
          TextPosition(offset: existing.text.length),
        );
      }
      return existing;
    }
    final controller = TextEditingController(text: initialValue);
    store[key] = controller;
    return controller;
  }
}
