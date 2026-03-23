import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/seller_product.dart';
import '../../services/campaign_service.dart';
import '../../services/store_service.dart';

/// Satıcı panelinden kampanya/kupon oluşturma veya düzenleme formu.
class CampaignFormDialog extends StatefulWidget {
  final String campaignType;
  final List<SellerProduct> products;
  final StoreCampaign? existingCampaign;

  const CampaignFormDialog({
    super.key,
    required this.campaignType,
    required this.products,
    this.existingCampaign,
  });

  @override
  State<CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<CampaignFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _couponCodeController = TextEditingController();
  final _discountController = TextEditingController();
  final _minCartController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _usageLimitController = TextEditingController();
  final _perUserLimitController = TextEditingController();
  final _descController = TextEditingController();
  final _productSearchController = TextEditingController();

  bool _autoGenerateCode = false;
  bool _singleUse = false;
  bool _freeShipping = false;
  String _scope = 'all';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  final Set<String> _selectedProductIds = {};
  bool _isSubmitting = false;

  bool get _isEditMode => widget.existingCampaign != null;
  bool get _isCoupon => widget.campaignType.toLowerCase().contains('kupon');
  bool get _isPercent => widget.campaignType.toLowerCase().contains('yüzde');

  @override
  void initState() {
    super.initState();
    final c = widget.existingCampaign;
    if (c != null) {
      _nameController.text = c.name;
      _descController.text = c.description ?? '';
      _discountController.text = c.discountValue.toStringAsFixed(0);
      _minCartController.text = c.minCartAmount > 0 ? c.minCartAmount.toStringAsFixed(0) : '';
      _maxDiscountController.text = c.maxDiscount?.toStringAsFixed(0) ?? '';
      _usageLimitController.text = c.usageLimit?.toString() ?? '';
      _perUserLimitController.text = c.perUserLimit?.toString() ?? '';
      _couponCodeController.text = c.couponCode ?? '';
      _autoGenerateCode = c.autoGenerateCode;
      _singleUse = c.singleUse;
      _freeShipping = c.freeShipping;
      _startDate = c.startDate;
      _endDate = c.endDate;
      _scope = c.scope == 'products' ? 'products' : 'all';
      _selectedProductIds.addAll(c.productIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _couponCodeController.dispose();
    _discountController.dispose();
    _minCartController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    _perUserLimitController.dispose();
    _descController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _endDate = d);
  }

  String _typeToDb() {
    if (widget.existingCampaign != null) return widget.existingCampaign!.type;
    final t = widget.campaignType.toLowerCase();
    if (t.contains('yüzde')) return 'yuzde_indirim';
    if (t.contains('sabit')) return 'sabit_tutar';
    if (t.contains('kupon')) return 'kupon';
    if (t.contains('al-get') || t.contains('al get')) return 'al_get';
    if (t.contains('2. ürün') || t.contains('ikinci')) return 'ikinci_urun';
    if (t.contains('kargo')) return 'ucretsiz_kargo';
    return 'kupon';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kampanya adı zorunludur')),
      );
      return;
    }
    final discountVal = double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0;
    if (discountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir indirim değeri giriniz')),
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş tarihi başlangıçtan sonra olmalıdır')),
      );
      return;
    }
    if (_isCoupon && !_autoGenerateCode && _couponCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kupon kodu giriniz veya otomatik oluşturmayı işaretleyin')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final existing = widget.existingCampaign;
      final userId = StoreService().currentUserId ?? '';
      final campaign = StoreCampaign(
        id: existing?.id ?? '',
        sellerId: userId,
        type: _typeToDb(),
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        couponCode: _isCoupon ? (_autoGenerateCode ? existing?.couponCode : (_couponCodeController.text.trim().isEmpty ? null : _couponCodeController.text.trim())) : null,
        autoGenerateCode: _autoGenerateCode,
        singleUse: _singleUse,
        discountType: _isPercent ? 'percent' : 'fixed',
        discountValue: discountVal,
        minCartAmount: double.tryParse(_minCartController.text.replaceAll(',', '.')) ?? 0,
        maxDiscount: double.tryParse(_maxDiscountController.text.replaceAll(',', '.')),
        freeShipping: _freeShipping,
        startDate: _startDate,
        endDate: _endDate,
        usageLimit: int.tryParse(_usageLimitController.text),
        perUserLimit: int.tryParse(_perUserLimitController.text),
        productIds: _scope == 'products' ? _selectedProductIds.toList() : [],
        scope: _scope == 'products' ? 'products' : 'all',
        status: existing?.status ?? 'active',
      );
      if (existing != null) {
        await CampaignService().updateCampaign(campaign);
      } else {
        await CampaignService().createCampaign(campaign);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing != null ? 'Kampanya güncellendi!' : (_isCoupon ? 'Kupon kodu oluşturuldu!' : 'Kampanya oluşturuldu!')), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _stopCampaign() async {
    final c = widget.existingCampaign;
    if (c == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kampanyayı Durdur'),
        content: const Text('Bu kampanya durdurulacak ve satıcı sayfasından kaldırılacak. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Durdur'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isSubmitting = true);
    try {
      await CampaignService().stopCampaign(c.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kampanya durduruldu.'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = widget.products.where((p) {
      final q = _productSearchController.text.toLowerCase();
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || p.brand.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Color(0xFF6C63FF), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    _isEditMode ? 'Kampanya Düzenle' : (_isCoupon ? 'Kupon Kodu Oluştur' : '${widget.campaignType} - Kampanya Detayları'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('Temel Bilgiler', Icons.info_outline, [
                        _textField(_nameController, 'Kampanya Adı *', 'Örn: Bahar İndirimi'),
                        if (_isCoupon) ...[
                          const SizedBox(height: 12),
                          _textField(_couponCodeController, 'Kupon Kodu *', 'Örn: HOSGELDIN100', enabled: !_autoGenerateCode),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(value: _autoGenerateCode, onChanged: (v) => setState(() => _autoGenerateCode = v ?? false), activeColor: AppColors.primary),
                              const Text('Otomatik kod oluştur', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 16),
                              Checkbox(value: _singleUse, onChanged: (v) => setState(() => _singleUse = v ?? false), activeColor: AppColors.primary),
                              const Text('Tek seferlik kullanım', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ]),
                      const SizedBox(height: 20),
                      _section('İndirim Ayarları', Icons.discount, [
                        Row(
                          children: [
                            Expanded(child: _textField(_discountController, _isPercent ? 'İndirim Oranı (%) *' : 'İndirim Tutarı (₺) *', _isPercent ? '20' : '100', keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _textField(_minCartController, 'Minimum Sepet Tutarı (₺)', '0', keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _textField(_maxDiscountController, 'Maksimum İndirim (₺)', 'Boş = sınırsız', keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _freeShipping ? 'Evet' : 'Hayır',
                                decoration: const InputDecoration(labelText: 'Ücretsiz Kargo?'),
                                items: const [DropdownMenuItem(value: 'Hayır', child: Text('Hayır')), DropdownMenuItem(value: 'Evet', child: Text('Evet'))],
                                onChanged: (v) => setState(() => _freeShipping = v == 'Evet'),
                              ),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _section('Tarih ve Kullanım Limiti', Icons.calendar_today, [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickStartDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Başlangıç Tarihi *'),
                                  child: Text(_formatDate(_startDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _pickEndDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Bitiş Tarihi *'),
                                  child: Text(_formatDate(_endDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _textField(_usageLimitController, 'Toplam Kullanım Limiti', 'Boş = sınırsız', keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _textField(_perUserLimitController, 'Kişi Başı Limit', 'Boş = sınırsız', keyboardType: TextInputType.number)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _section('Hangi Ürünler İçin Geçerli?', Icons.shopping_bag, [
                        DropdownButtonFormField<String>(
                          value: _scope,
                          decoration: const InputDecoration(labelText: 'Uygulama Kapsamı'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tüm Ürünler')),
                            DropdownMenuItem(value: 'products', child: Text('Seçili Ürünler')),
                          ],
                          onChanged: (v) => setState(() => _scope = v ?? 'all'),
                        ),
                        if (_scope == 'products') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _productSearchController,
                            decoration: const InputDecoration(hintText: 'Ürün ara...', prefixIcon: Icon(Icons.search, size: 18)),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredProducts.length,
                              itemBuilder: (_, i) {
                                final p = filteredProducts[i];
                                final selected = _selectedProductIds.contains(p.id);
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (v) => setState(() {
                                    if (v == true) _selectedProductIds.add(p.id);
                                    else _selectedProductIds.remove(p.id);
                                  }),
                                  title: Text(p.name, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text('₺${p.price}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                );
                              },
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 20),
                      _textField(_descController, 'Kampanya Açıklaması', 'Müşterilere gösterilecek açıklama', maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isEditMode && widget.existingCampaign?.status == 'active')
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _stopCampaign,
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Kampanyayı Durdur'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check, size: 18),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        label: Text(_isEditMode ? 'Kaydet' : (_isCoupon ? 'Kupon Oluştur' : 'Kampanyayı Oluştur')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _textField(TextEditingController c, String label, String hint, {int maxLines = 1, bool enabled = true, TextInputType? keyboardType}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label, hintText: hint),
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
    );
  }
}
