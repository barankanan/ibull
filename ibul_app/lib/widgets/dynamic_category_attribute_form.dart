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

  @override
  void dispose() {
    for (final controller in _controllers.values) {
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
              'Hazir ozellikler yuklenemedi. Manuel alanlara gecebilirsiniz.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          );
        }

        if (!provider.hasDefinitions) {
          return _buildShell(
            context,
            child: Text(
              'Bu alt kategori icin hazir attribute bulunamadi.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          );
        }

        return _buildShell(
          context,
          child: Column(
            children: provider.definitions.map((definition) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildField(context, provider, definition),
              );
            }).toList(),
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
                'Alt kategoriye gore hazirlanan alanlar otomatik gelir. Satici sadece deger girer.',
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
    if (definition.isSelect) {
      final dropdownValue = (provider.valuesByAttributeId[definition.id] ?? '')
          .trim();
      return DropdownButtonFormField<String>(
        initialValue: definition.options.contains(dropdownValue)
            ? dropdownValue
            : null,
        decoration: _inputDecoration(
          label: definition.name,
          filterable: definition.filterable,
        ),
        items: definition.options
            .map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) =>
            provider.setValue(definition.id, value ?? '', notify: true),
      );
    }

    final controller = _controllerFor(
      definition.id,
      provider.valuesByAttributeId[definition.id] ?? '',
    );
    return TextFormField(
      controller: controller,
      keyboardType: definition.isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _inputDecoration(
        label: definition.name,
        filterable: definition.filterable,
        hint: definition.isNumber ? 'Sayisal deger girin' : null,
      ),
      onChanged: (value) => provider.setValue(definition.id, value),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required bool filterable,
    String? hint,
  }) {
    return InputDecoration(
      labelText: filterable ? '$label • Filtrelenebilir' : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
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
}
