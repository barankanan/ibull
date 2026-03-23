import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ad_credit_code.dart';
import '../../services/ad_credit_code_service.dart';

class AdminAdCreditCodesPanel extends StatefulWidget {
  const AdminAdCreditCodesPanel({super.key});

  @override
  State<AdminAdCreditCodesPanel> createState() =>
      _AdminAdCreditCodesPanelState();
}

class _AdminAdCreditCodesPanelState extends State<AdminAdCreditCodesPanel> {
  final AdCreditCodeService _adCreditCodeService = AdCreditCodeService();
  final TextEditingController _creditAmountController = TextEditingController(
    text: '250',
  );
  final TextEditingController _creditCountController = TextEditingController(
    text: '10',
  );
  final TextEditingController _usageLimitController = TextEditingController(
    text: '1',
  );
  final TextEditingController _creditTargetSellerController =
      TextEditingController();
  final TextEditingController _creditNoteController = TextEditingController();

  bool _isLoadingCreditData = false;
  bool _isGeneratingCreditCodes = false;
  bool _isSellerRestricted = false;
  bool _isCodeActive = true;
  String? _creditCodesError;
  DateTime? _selectedExpiryDate;
  List<AdCreditCode> _recentCreditCodes = const <AdCreditCode>[];
  List<AdCreditRedemption> _recentRedemptions = const <AdCreditRedemption>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[AdCredit][Admin] credit screen rendered');
      _loadRecentCreditData();
    });
  }

  @override
  void dispose() {
    _creditAmountController.dispose();
    _creditCountController.dispose();
    _usageLimitController.dispose();
    _creditTargetSellerController.dispose();
    _creditNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentCreditData() async {
    if (!mounted) return;
    debugPrint('[AdCredit][Admin] loading codes started');
    setState(() {
      _isLoadingCreditData = true;
      _creditCodesError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _adCreditCodeService.getRecentCodes(),
        _adCreditCodeService.getRecentRedemptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _recentCreditCodes = results[0] as List<AdCreditCode>;
        _recentRedemptions = results[1] as List<AdCreditRedemption>;
      });
      debugPrint(
        '[AdCredit][Admin] loading codes completed codes=${_recentCreditCodes.length} redemptions=${_recentRedemptions.length}',
      );
    } catch (error) {
      debugPrint('[AdCredit][Admin] loading codes failed: $error');
      if (!mounted) return;
      setState(() {
        _creditCodesError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCreditData = false;
        });
      }
    }
  }

  Future<void> _generateCreditCodes() async {
    final amount =
        double.tryParse(
          _creditAmountController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final count = int.tryParse(_creditCountController.text.trim()) ?? 0;
    final usageLimit = int.tryParse(_usageLimitController.text.trim()) ?? 0;
    final targetSellerId = _isSellerRestricted
        ? _creditTargetSellerController.text.trim()
        : '';
    if (amount <= 0 || count <= 0 || usageLimit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tutar, batch adedi ve kullanim limiti alanlarini gecerli doldurun.',
          ),
        ),
      );
      return;
    }
    if (_isSellerRestricted && targetSellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saticiya ozel kod icin hedef satici ID girin.'),
        ),
      );
      return;
    }
    debugPrint(
      '[AdCredit][Admin] batch generation started amount=$amount count=$count usageLimit=$usageLimit seller=$targetSellerId',
    );
    setState(() => _isGeneratingCreditCodes = true);
    try {
      final codes = await _adCreditCodeService.generateCodes(
        amount: amount,
        count: count,
        usageLimit: usageLimit,
        isActive: _isCodeActive,
        expiresAt: _selectedExpiryDate,
        note: _creditNoteController.text.trim(),
        targetSellerId: targetSellerId,
        metadata: <String, dynamic>{
          'seller_restricted': _isSellerRestricted,
          'created_from': 'admin_ad_credit_codes_panel',
        },
      );
      if (!mounted) return;
      setState(() {
        _recentCreditCodes = <AdCreditCode>[
          ...codes,
          ..._recentCreditCodes.where(
            (existing) => !codes.any((created) => created.id == existing.id),
          ),
        ];
      });
      debugPrint(
        '[AdCredit][Admin] batch generation success created=${codes.length}',
      );
      await _loadRecentCreditData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${codes.length} adet reklam kredisi kodu olusturuldu.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('[AdCredit][Admin] batch generation failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kodlar olusturulamadi: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCreditCodes = false);
      }
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedExpiryDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
        59,
      );
    });
  }

  Future<void> _copyCreditCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kredi kodu kopyalandi.')));
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Sinirsiz';
    }
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _codeStateLabel(AdCreditCode code) {
    if (code.expiresAt != null && code.expiresAt!.isBefore(DateTime.now())) {
      return 'Suresi doldu';
    }
    if (!code.isActive) {
      return code.isExhausted ? 'Hak bitti' : 'Pasif';
    }
    if (code.isExhausted) {
      return 'Hak bitti';
    }
    return 'Aktif';
  }

  Color _codeStateColor(AdCreditCode code) {
    if (code.expiresAt != null && code.expiresAt!.isBefore(DateTime.now())) {
      return const Color(0xFFDC2626);
    }
    if (!code.isActive && !code.isExhausted) {
      return const Color(0xFFEA580C);
    }
    if (code.isExhausted) {
      return const Color(0xFF2563EB);
    }
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reklam kredisi yonetimi',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Batch bazli kredi kodu uretin, kullanim limitini belirleyin ve son kullanimi takip edin. Kod kullanimi ad wallet tarafina islenir.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _isGeneratingCreditCodes
                    ? null
                    : _generateCreditCodes,
                icon: _isGeneratingCreditCodes
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  _isGeneratingCreditCodes ? 'Olusturuluyor' : 'Batch olustur',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _creditAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Kredi tutari',
                    hintText: 'Orn. 250',
                    suffixText: 'TRY',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _creditCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Batch adedi',
                    hintText: 'Orn. 10',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _usageLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kullanim limiti',
                    hintText: '1 = tek kullanim',
                    prefixIcon: Icon(Icons.all_inclusive_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 230,
                child: OutlinedButton.icon(
                  onPressed: _pickExpiryDate,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(
                    _selectedExpiryDate == null
                        ? 'Son kullanim sec'
                        : _formatDateTime(_selectedExpiryDate),
                  ),
                ),
              ),
              if (_selectedExpiryDate != null)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedExpiryDate = null),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Tarihi temizle'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isSellerRestricted,
            onChanged: (value) {
              setState(() {
                _isSellerRestricted = value;
                if (!value) {
                  _creditTargetSellerController.clear();
                }
              });
            },
            title: const Text('Saticiya ozel kod'),
            subtitle: const Text(
              'Acik ise sadece girilen satici ID bu kodu kullanabilir.',
            ),
          ),
          if (_isSellerRestricted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _creditTargetSellerController,
                decoration: const InputDecoration(
                  labelText: 'Hedef satici ID',
                  hintText: 'UUID veya auth seller id',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isCodeActive,
            onChanged: (value) => setState(() => _isCodeActive = value),
            title: const Text('Kod aktif olusturulsun'),
            subtitle: const Text(
              'Kapali olusturulan kodlar daha sonra aktif edilene kadar kullanilamaz.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _creditNoteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Not / aciklama',
              hintText: 'Kampanya, batch adi veya aciklama',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),
          if (_creditCodesError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                'Kredi verisi yuklenemedi: $_creditCodesError',
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_isLoadingCreditData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Olusturulan reklam kodlari',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadRecentCreditData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recentCreditCodes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Henuz reklam kredisi kodu uretilmedi. Yukaridan ilk batchi olusturabilirsiniz.',
                      style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                    ),
                  )
                else
                  ..._recentCreditCodes.map(_buildCreditCodeRow),
                const SizedBox(height: 18),
                const Text(
                  'Kullanim gecmisi',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (_recentRedemptions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Henuz kullanilan reklam kredi kodu yok.',
                      style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                    ),
                  )
                else
                  ..._recentRedemptions.map(_buildRedemptionRow),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCreditCodeRow(AdCreditCode code) {
    final stateColor = _codeStateColor(code);
    final stateLabel = _codeStateLabel(code);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      code.code,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${code.amount.toStringAsFixed(0)} TRY kredi • ${code.usedCount}/${code.usageLimit} kullanim',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Kopyala',
                onPressed: () => _copyCreditCode(code.code),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(
                Icons.storefront_outlined,
                code.targetSellerId?.trim().isNotEmpty == true
                    ? 'Satici: ${code.targetSellerId}'
                    : 'Genel kullanim',
              ),
              _metaChip(
                Icons.calendar_today_outlined,
                'Son kullanim: ${_formatDateTime(code.expiresAt)}',
              ),
              _metaChip(Icons.layers_outlined, 'Batch: ${code.batchId}'),
              if ((code.note ?? '').trim().isNotEmpty)
                _metaChip(Icons.notes_rounded, code.note!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionRow(AdCreditRedemption redemption) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            redemption.code,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          _metaChip(
            Icons.storefront_outlined,
            'Satici: ${redemption.sellerId}',
          ),
          _metaChip(
            Icons.account_balance_wallet_outlined,
            '${redemption.creditedAmount.toStringAsFixed(0)} TRY',
          ),
          _metaChip(
            Icons.schedule_rounded,
            _formatDateTime(redemption.redeemedAt),
          ),
          _metaChip(Icons.verified_outlined, redemption.status),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
