import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/admin_finance_commission_helper.dart';
import '../helpers/admin_panel_density.dart';

class AdminFinanceCommissionSettingsDialog extends StatefulWidget {
  const AdminFinanceCommissionSettingsDialog({
    super.key,
    required this.density,
    required this.initialConfig,
    required this.categoryOptions,
    required this.onSave,
  });

  final AdminPanelDensity density;
  final AdminFinanceCommissionConfig initialConfig;
  final List<Map<String, dynamic>> categoryOptions;
  final Future<void> Function(AdminFinanceCommissionConfig config) onSave;

  static Future<void> show(
    BuildContext context, {
    required AdminPanelDensity density,
    required AdminFinanceCommissionConfig initialConfig,
    required List<Map<String, dynamic>> categoryOptions,
    required Future<void> Function(AdminFinanceCommissionConfig config) onSave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminFinanceCommissionSettingsDialog(
        density: density,
        initialConfig: initialConfig,
        categoryOptions: categoryOptions,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AdminFinanceCommissionSettingsDialog> createState() =>
      _AdminFinanceCommissionSettingsDialogState();
}

class _AdminFinanceCommissionSettingsDialogState
    extends State<AdminFinanceCommissionSettingsDialog> {
  late AdminFinanceCommissionConfig _config;
  late final TextEditingController _defaultPercentController;
  late final TextEditingController _cargoPercentController;
  late final TextEditingController _cargoFixedController;
  late final TextEditingController _kdvController;
  late final TextEditingController _stopajController;
  late final TextEditingController _corporateTaxController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _defaultPercentController = TextEditingController(
      text: _formatNum(_config.defaultPercent),
    );
    _cargoPercentController = TextEditingController(
      text: _formatNum(_config.cargoPercent),
    );
    _cargoFixedController = TextEditingController(
      text: _formatNum(_config.cargoFixed),
    );
    _kdvController = TextEditingController(text: _formatNum(_config.kdvPercent));
    _stopajController = TextEditingController(
      text: _formatNum(_config.stopajPercent),
    );
    _corporateTaxController = TextEditingController(
      text: _formatNum(_config.corporateTaxPercent),
    );
  }

  @override
  void dispose() {
    _defaultPercentController.dispose();
    _cargoPercentController.dispose();
    _cargoFixedController.dispose();
    _kdvController.dispose();
    _stopajController.dispose();
    _corporateTaxController.dispose();
    super.dispose();
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  double _readPercent(TextEditingController controller, double fallback) {
    return double.tryParse(controller.text.replaceAll(',', '.')) ?? fallback;
  }

  Future<void> _handleSave() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final resolved = _config.copyWith(
        defaultPercent: _readPercent(_defaultPercentController, 15),
        cargoMode: _config.cargoMode,
        cargoPercent: _readPercent(_cargoPercentController, 10),
        cargoFixed: _readPercent(_cargoFixedController, 0),
        kdvPercent: _readPercent(_kdvController, 20),
        stopajPercent: _readPercent(_stopajController, 0),
        corporateTaxPercent: _readPercent(_corporateTaxController, 25),
      );
      await widget.onSave(resolved);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addCategoryRule() {
    if (widget.categoryOptions.isEmpty) return;
    final first = widget.categoryOptions.first;
    setState(() {
      _config = _config.copyWith(
        categoryRules: [
          ..._config.categoryRules,
          AdminFinanceCategoryCommissionRule(
            categoryId: (first['id'] as num?)?.toInt(),
            categoryName: (first['name'] ?? 'Kategori').toString(),
            percent: _config.defaultPercent,
          ),
        ],
      );
    });
  }

  void _updateRule(int index, AdminFinanceCategoryCommissionRule rule) {
    final rules = [..._config.categoryRules];
    rules[index] = rule;
    setState(() => _config = _config.copyWith(categoryRules: rules));
  }

  void _removeRule(int index) {
    final rules = [..._config.categoryRules]..removeAt(index);
    setState(() => _config = _config.copyWith(categoryRules: rules));
  }

  @override
  Widget build(BuildContext context) {
    final density = widget.density;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(density.financeSectionPadding),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.percent,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Komisyon & Kargo Ayarları',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Kategori komisyonları, kargo payı ve vergi tahmin oranları',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(density.financeSectionPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _sectionTitle('Genel komisyon'),
                    _percentField(
                      label: 'Varsayılan komisyon (%)',
                      controller: _defaultPercentController,
                      hint: 'Kategori kuralı olmayan ürünler',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _sectionTitle('Kategori kuralları')),
                        TextButton.icon(
                          onPressed: _addCategoryRule,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Kategori ekle'),
                        ),
                      ],
                    ),
                    if (_config.categoryRules.isEmpty)
                      const Text(
                        'Henüz kategori kuralı yok. Varsayılan oran uygulanır.',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      )
                    else
                      ...List.generate(_config.categoryRules.length, (index) {
                        final rule = _config.categoryRules[index];
                        return _CategoryRuleRow(
                          rule: rule,
                          categoryOptions: widget.categoryOptions,
                          onChanged: (updated) => _updateRule(index, updated),
                          onRemove: () => _removeRule(index),
                        );
                      }),
                    const SizedBox(height: 20),
                    _sectionTitle('Kargo komisyonu'),
                    SegmentedButton<AdminFinanceCargoCommissionMode>(
                      segments: const [
                        ButtonSegment(
                          value: AdminFinanceCargoCommissionMode.percent,
                          label: Text('Yüzde (%)'),
                        ),
                        ButtonSegment(
                          value: AdminFinanceCargoCommissionMode.fixed,
                          label: Text('Sabit (₺)'),
                        ),
                      ],
                      selected: {_config.cargoMode},
                      onSelectionChanged: (values) {
                        setState(() {
                          _config = _config.copyWith(cargoMode: values.first);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_config.cargoMode == AdminFinanceCargoCommissionMode.percent)
                      _percentField(
                        label: 'Kargo komisyon oranı (%)',
                        controller: _cargoPercentController,
                        hint: 'Teslim edilen kargo tutarı üzerinden',
                      )
                    else
                      _percentField(
                        label: 'Sabit kargo komisyonu (₺)',
                        controller: _cargoFixedController,
                        hint: 'Paket başına sabit gelir',
                      ),
                    const SizedBox(height: 20),
                    _sectionTitle('Vergi tahmin oranları'),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 200,
                          child: _percentField(
                            label: 'KDV (%)',
                            controller: _kdvController,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: _percentField(
                            label: 'Stopaj (%)',
                            controller: _stopajController,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: _percentField(
                            label: 'Kurumlar vergisi (%)',
                            controller: _corporateTaxController,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(density.financeSectionPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _handleSave,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kaydet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }

  Widget _percentField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _CategoryRuleRow extends StatelessWidget {
  const _CategoryRuleRow({
    required this.rule,
    required this.categoryOptions,
    required this.onChanged,
    required this.onRemove,
  });

  final AdminFinanceCategoryCommissionRule rule;
  final List<Map<String, dynamic>> categoryOptions;
  final ValueChanged<AdminFinanceCategoryCommissionRule> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedId = rule.categoryId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int?>(
              initialValue: selectedId,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: categoryOptions
                  .map(
                    (row) => DropdownMenuItem<int?>(
                      value: (row['id'] as num?)?.toInt(),
                      child: Text((row['name'] ?? '').toString()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final match = categoryOptions.firstWhere(
                  (row) => (row['id'] as num?)?.toInt() == value,
                  orElse: () => const {},
                );
                onChanged(
                  rule.copyWith(
                    categoryId: value,
                    categoryName: (match['name'] ?? rule.categoryName).toString(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: rule.percent.toStringAsFixed(
                rule.percent == rule.percent.roundToDouble() ? 0 : 1,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Komisyon %',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final percent = double.tryParse(value.replaceAll(',', '.'));
                if (percent == null) return;
                onChanged(rule.copyWith(percent: percent, fixedAmount: null));
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }
}
