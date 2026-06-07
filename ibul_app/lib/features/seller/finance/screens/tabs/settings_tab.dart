import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _formKey = GlobalKey<FormState>();
  CompanySettings? _settings;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  // Controllers
  final _companyNameCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _taxOfficeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'TRY');
  final _commissionCtrl = TextEditingController(text: '0');
  String? _defaultCashAccountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settings == null && !_loading) _load();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _taxNumberCtrl.dispose();
    _taxOfficeCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _currencyCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fp = context.read<FinanceProvider>();
      if (fp.cashAccounts.isEmpty) {
        await fp.loadSharedResources();
      }
      final s = await fp.repo.getCompanySettings();
      if (s != null) {
        _settings = s;
        _companyNameCtrl.text = s.companyName ?? '';
        _taxNumberCtrl.text = s.taxNumber ?? '';
        _taxOfficeCtrl.text = s.taxOffice ?? '';
        _addressCtrl.text = s.address ?? '';
        _phoneCtrl.text = s.phone ?? '';
        _emailCtrl.text = s.email ?? '';
        _currencyCtrl.text = s.defaultCurrency;
        _commissionCtrl.text = s.platformCommissionRate.toStringAsFixed(2);
        _defaultCashAccountId = s.defaultCashAccountId;
      }
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final fp = context.read<FinanceProvider>();
      final settings = CompanySettings(
        id: _settings?.id ?? '',
        sellerId: fp.sellerId,
        companyName: _companyNameCtrl.text.trim().isNotEmpty
            ? _companyNameCtrl.text.trim()
            : null,
        taxNumber: _taxNumberCtrl.text.trim().isNotEmpty
            ? _taxNumberCtrl.text.trim()
            : null,
        taxOffice: _taxOfficeCtrl.text.trim().isNotEmpty
            ? _taxOfficeCtrl.text.trim()
            : null,
        address: _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : null,
        phone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
        email: _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
        defaultCurrency: _currencyCtrl.text.trim().isNotEmpty
            ? _currencyCtrl.text.trim()
            : 'TRY',
        platformCommissionRate:
            double.tryParse(_commissionCtrl.text.replaceAll(',', '.')) ?? 0,
        defaultCashAccountId: _defaultCashAccountId,
      );
      await fp.repo.upsertCompanySettings(settings);
      setState(() => _settings = settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayarlar kaydedildi'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const FinLoadingOverlay();
    if (_error != null) return FinErrorCard(message: _error!, onRetry: _load);

    final fp = context.watch<FinanceProvider>();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionHeader('Şirket Bilgileri', Icons.business_outlined),
          const SizedBox(height: 10),
          FinTextField(
              controller: _companyNameCtrl,
              label: 'Şirket / İşletme Adı'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FinTextField(
                    controller: _taxNumberCtrl,
                    label: 'Vergi Numarası',
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FinTextField(
                    controller: _taxOfficeCtrl, label: 'Vergi Dairesi'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FinTextField(
              controller: _addressCtrl, label: 'Adres', maxLines: 2),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FinTextField(
                    controller: _phoneCtrl,
                    label: 'Telefon',
                    keyboardType: TextInputType.phone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FinTextField(
                    controller: _emailCtrl,
                    label: 'E-posta',
                    keyboardType: TextInputType.emailAddress),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionHeader('Finans Ayarları', Icons.tune_outlined),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FinTextField(
                  controller: _currencyCtrl,
                  label: 'Para Birimi',
                  hint: 'TRY',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FinTextField(
                  controller: _commissionCtrl,
                  label: 'Platform Komisyon (%)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  hint: '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (fp.cashAccounts.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              initialValue: _defaultCashAccountId,
              decoration: InputDecoration(
                labelText: 'Varsayılan Kasa/Hesap',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Seçilmedi', style: TextStyle(fontSize: 13))),
                ...fp.cashAccounts.map((a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(
                        a.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _defaultCashAccountId = v),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'Kaydediliyor...' : 'Ayarları Kaydet'),
              style: FilledButton.styleFrom(
                  backgroundColor: kFinancePrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kFinancePrimary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kFinancePrimary,
          ),
        ),
      ],
    );
  }
}
