import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/admin_panel_density.dart';

class AdminFinanceCalculatorPanel extends StatefulWidget {
  const AdminFinanceCalculatorPanel({
    super.key,
    required this.density,
    required this.defaultCommissionPercent,
    required this.defaultKdvPercent,
    required this.formatCurrency,
  });

  final AdminPanelDensity density;
  final double defaultCommissionPercent;
  final double defaultKdvPercent;
  final String Function(double) formatCurrency;

  @override
  State<AdminFinanceCalculatorPanel> createState() =>
      _AdminFinanceCalculatorPanelState();
}

class _AdminFinanceCalculatorPanelState extends State<AdminFinanceCalculatorPanel> {
  final _saleAmountController = TextEditingController(text: '1000');
  final _costController = TextEditingController(text: '600');
  final _commissionController = TextEditingController(text: '15');
  final _cargoController = TextEditingController(text: '49');
  final _kdvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commissionController.text = widget.defaultCommissionPercent
        .toStringAsFixed(
          widget.defaultCommissionPercent ==
                  widget.defaultCommissionPercent.roundToDouble()
              ? 0
              : 1,
        );
    _kdvController.text = widget.defaultKdvPercent.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _saleAmountController.dispose();
    _costController.dispose();
    _commissionController.dispose();
    _cargoController.dispose();
    _kdvController.dispose();
    super.dispose();
  }

  double _read(TextEditingController c, [double fallback = 0]) {
    return double.tryParse(c.text.replaceAll(',', '.')) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final density = widget.density;
    final sale = _read(_saleAmountController);
    final cost = _read(_costController);
    final commissionRate = _read(_commissionController, 15) / 100;
    final cargo = _read(_cargoController);
    final kdvRate = _read(_kdvController, 20) / 100;

    final commission = sale * commissionRate;
    final grossMargin = sale - cost;
    final marginPercent = sale <= 0 ? 0.0 : (grossMargin / sale) * 100;
    final platformNet = commission + cargo;
    final kdvEstimate = platformNet * kdvRate;
    final netAfterTax = platformNet - kdvEstimate;
    final breakEvenSales = commissionRate <= 0 ? 0.0 : cost / commissionRate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(density.financeSectionPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_outlined, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hesaplama Araçları',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      'Komisyon, kâr marjı, KDV ve başabaş simülasyonu',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: density.gridSpacing),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final inputs = _inputs();
              final results = _results(
                commission: commission,
                grossMargin: grossMargin,
                marginPercent: marginPercent,
                platformNet: platformNet,
                kdvEstimate: kdvEstimate,
                netAfterTax: netAfterTax,
                breakEvenSales: breakEvenSales,
              );
              if (!wide) {
                return Column(
                  children: [inputs, SizedBox(height: density.gridSpacing), results],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: inputs),
                  SizedBox(width: density.gridSpacing),
                  Expanded(child: results),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _inputs() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _field('Satış tutarı (₺)', _saleAmountController),
        _field('Maliyet (₺)', _costController),
        _field('Komisyon (%)', _commissionController),
        _field('Kargo geliri (₺)', _cargoController),
        _field('KDV (%)', _kdvController),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _results({
    required double commission,
    required double grossMargin,
    required double marginPercent,
    required double platformNet,
    required double kdvEstimate,
    required double netAfterTax,
    required double breakEvenSales,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _resultRow('Platform komisyonu', widget.formatCurrency(commission)),
          _resultRow('Brüt marj', widget.formatCurrency(grossMargin)),
          _resultRow('Marj %', '${marginPercent.toStringAsFixed(1)}%'),
          _resultRow('Toplam platform geliri', widget.formatCurrency(platformNet)),
          _resultRow('Tahmini KDV', widget.formatCurrency(kdvEstimate)),
          _resultRow('Vergi sonrası net', widget.formatCurrency(netAfterTax)),
          _resultRow('Başabaş satış', widget.formatCurrency(breakEvenSales)),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
