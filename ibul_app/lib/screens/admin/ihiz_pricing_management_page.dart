import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IhizPricingManagementPage extends StatefulWidget {
  const IhizPricingManagementPage({super.key});

  @override
  State<IhizPricingManagementPage> createState() =>
      _IhizPricingManagementPageState();
}

class _IhizPricingManagementPageState extends State<IhizPricingManagementPage> {
  _IhizPricingConfig _config = _IhizPricingConfig.defaults;
  final TextEditingController _versionNoteController = TextEditingController();
  final Map<String, TextEditingController> _valueControllers = {};
  final Map<String, FocusNode> _valueFocusNodes = {};

  bool _loadingVersions = false;
  bool _savingVersion = false;
  String? _storageWarning;
  List<_IhizPricingVersion> _versions = const [];

  String _simOrderType = 'ibul_internal';
  double _simDistanceKm = 2.2;
  bool _simNight = false;
  bool _simRain = false;
  bool _simSurge = false;
  bool _simMultiOrder = false;
  bool _simFreeDelivery = false;
  String _simCancelStage = 'before_assign';

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  @override
  void dispose() {
    _versionNoteController.dispose();
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    for (final node in _valueFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _loadingVersions = true;
      _storageWarning = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('ihiz_pricing_rule_versions')
          .select('version, config, active_from, is_active, created_at, note')
          .order('version', ascending: false)
          .limit(40);
      final mapped = List<Map<String, dynamic>>.from(rows as List)
          .map((row) {
            final configMap = Map<String, dynamic>.from(
              (row['config'] as Map?) ?? const <String, dynamic>{},
            );
            return _IhizPricingVersion(
              version: _toInt(row['version'], 0),
              config: _IhizPricingConfig.fromJson(configMap),
              activeFrom:
                  DateTime.tryParse(row['active_from']?.toString() ?? '') ??
                  DateTime.now(),
              createdAt:
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
              isActive: row['is_active'] == true,
              note: row['note']?.toString() ?? '',
            );
          })
          .toList(growable: false);
      if (mapped.isNotEmpty) {
        _config = mapped.first.config;
      }
      setState(() {
        _versions = mapped;
      });
    } catch (error) {
      setState(() {
        _storageWarning =
            'Versiyon verileri okunamadı. SUPABASE_IHIZ_PRICING_ADMIN.sql çalıştırılmalı. Hata: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingVersions = false;
        });
      }
    }
  }

  Future<void> _saveNewVersion() async {
    if (_savingVersion) return;
    setState(() {
      _savingVersion = true;
      _storageWarning = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final nowIso = DateTime.now().toIso8601String();
      final rows = await client
          .from('ihiz_pricing_rule_versions')
          .select('version')
          .order('version', ascending: false)
          .limit(1);
      final currentVersion = rows.isNotEmpty
          ? _toInt((rows.first as Map)['version'], 0)
          : 0;
      final nextVersion = currentVersion + 1;

      await client
          .from('ihiz_pricing_rule_versions')
          .update({'is_active': false, 'active_to': nowIso})
          .eq('is_active', true);

      await client.from('ihiz_pricing_rule_versions').insert({
        'version': nextVersion,
        'config': _config.toJson(),
        'active_from': nowIso,
        'active_to': null,
        'is_active': true,
        'created_by': userId,
        'created_at': nowIso,
        'note': _versionNoteController.text.trim(),
      });

      _versionNoteController.clear();
      await _loadVersions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yeni fiyat kuralı v$nextVersion olarak kaydedildi.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storageWarning =
            'Versiyon kaydı yazılamadı. SUPABASE_IHIZ_PRICING_ADMIN.sql çalıştırılmalı. Hata: $error';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayıt başarısız: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _savingVersion = false;
        });
      }
    }
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _round2(double value) => (value * 100).round() / 100;

  String _try(double value, {bool decimal = false}) {
    final normalized = decimal
        ? _round2(value).toStringAsFixed(2)
        : value.round().toString();
    final parts = normalized.split('.');
    final integerPart = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    if (decimal && parts.length > 1) return '₺$integerPart,${parts[1]}';
    return '₺$integerPart';
  }

  double _internalCustomerContribution(double distanceKm) {
    if (_config.freeDeliveryCampaignEnabled || _simFreeDelivery) return 0;
    if (distanceKm <= 3) return _config.customerFee0To3Km;
    if (distanceKm <= 6) return _config.customerFee3To6Km;
    return _config.customerFee6PlusKm;
  }

  void _applyPromptPresetV1() {
    setState(() {
      _config = _config.copyWith(
        baseFee: 28,
        perKmFee: 7,
        platformFee: 10,
        nearbyThresholdKm: 8,
        mediumDistanceThresholdKm: 20,
        ihizDirectMaxDistanceKm: 20,
        branchBaseFee: 20,
        branchKmFee: 6,
        ihizActiveCities: 'Eskişehir,İstanbul,Ankara',
        enabledCargoCompanies: 'aras,mng,ptt',
        minDeliveryFee: 35,
        maxDeliveryFee: 350,
        customerFee0To3Km: 35,
        customerFee3To6Km: 45,
        customerFee6PlusKm: 55,
        courierBaseEarning: 28,
        courierPerKmEarning: 7,
        courierMinutePrice: 4,
        courierNightBonus: 12,
        courierRainBonus: 15,
        courierSurgeBonus: 20,
        courierMultiOrderBonus: 25,
        etaPerKmMinute: 5,
        etaBaseMinute: 6,
      );
    });
  }

  _IhizSimResult _simulate() {
    final etaMinutes = (_config.etaBaseMinute +
            (_simDistanceKm.clamp(0, 60).toDouble() * _config.etaPerKmMinute))
        .clamp(1, 240)
        .toDouble();
    final distanceBased =
        _config.courierBaseEarning +
        (_simDistanceKm * _config.courierPerKmEarning);
    final etaBased = etaMinutes * _config.courierMinutePrice;
    final coreCourierFee = distanceBased >= etaBased ? distanceBased : etaBased;

    final surgeMultiplier = _simSurge ? 1.2 : 1.0;
    final nightBonus = _simNight ? _config.courierNightBonus : 0.0;
    final weatherBonus = _simRain ? _config.courierRainBonus : 0.0;
    final multiBonus = (_simMultiOrder && _config.multiOrderEnabled)
        ? _config.courierMultiOrderBonus
        : 0.0;
    final branchDropFee =
        _config.branchBaseFee + (_simDistanceKm * _config.branchKmFee);

    final String recommendedType = _simDistanceKm <= _config.nearbyThresholdKm
        ? 'ihiz_direct'
        : _simDistanceKm <= _config.mediumDistanceThresholdKm
        ? 'ihiz_direct / standard_cargo'
        : 'standard_cargo (ihiz_to_branch aktif)';

    final courierEarning =
        (coreCourierFee * surgeMultiplier) +
        nightBonus +
        weatherBonus +
        multiBonus;

    final total = (courierEarning + _config.platformFee)
        .clamp(_config.minDeliveryFee, _config.maxDeliveryFee)
        .toDouble();

    double customerFee = 0;
    double sellerFee = 0;
    if (_simOrderType == 'external') {
      sellerFee = total;
      customerFee = 0;
    } else {
      customerFee = _internalCustomerContribution(_simDistanceKm);
      sellerFee = (total - customerFee).clamp(0, 999999).toDouble();
      customerFee = (total - sellerFee).clamp(0, 999999).toDouble();
    }

    final revenue = customerFee + sellerFee;
    final platformMargin = (revenue - courierEarning)
        .clamp(-999999, 999999)
        .toDouble();
    final marginRate = revenue <= 0
        ? 0.0
        : ((platformMargin / revenue) * 100).clamp(-999, 999).toDouble();
    final reserveAmount = sellerFee;
    final courierHourlyEstimate = etaMinutes <= 0
        ? 0.0
        : courierEarning * (60 / etaMinutes);
    final refundRate = switch (_simCancelStage) {
      'before_assign' => _config.cancelBeforeAssignRefundPct,
      'after_assign' => _config.cancelAfterAssignRefundPct,
      'after_pickup' => _config.cancelAfterPickupRefundPct,
      _ => _config.cancelBeforeAssignRefundPct,
    };
    final refundAmount = reserveAmount * (refundRate / 100);

    return _IhizSimResult(
      etaMinutes: _round2(etaMinutes),
      surgeMultiplier: _round2(surgeMultiplier),
      weatherBonus: _round2(weatherBonus),
      recommendedType: recommendedType,
      branchDropFee: _round2(branchDropFee),
      totalDeliveryFee: _round2(total),
      customerFee: _round2(customerFee),
      sellerFee: _round2(sellerFee),
      courierEarning: _round2(courierEarning),
      platformFee: _round2(_config.platformFee),
      platformMargin: _round2(platformMargin),
      courierHourlyEstimate: _round2(courierHourlyEstimate),
      marginRate: _round2(marginRate),
      reserveAmount: _round2(reserveAmount),
      refundAmount: _round2(refundAmount),
      refundRate: _round2(refundRate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = _simulate();
    final isMobile = MediaQuery.sizeOf(context).width < 1050;
    final activeVersion = _versions.cast<_IhizPricingVersion?>().firstWhere(
      (item) => item?.isActive == true,
      orElse: () => null,
    );

    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                Icons.new_releases_outlined,
                activeVersion == null
                    ? 'Aktif sürüm yok'
                    : 'Aktif sürüm: v${activeVersion.version}',
              ),
              _pill(
                Icons.calendar_today_outlined,
                'Toplam sürüm: ${_versions.length}',
              ),
              _pill(
                Icons.account_balance_wallet_outlined,
                'Min wallet: ${_try(_config.minWalletBalance)}',
              ),
            ],
          ),
        ),
        if ((_storageWarning ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _warning(_storageWarning!),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _applyPromptPresetV1,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Prompt V1 varsayilanini yukle'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isMobile) ...[
          _buildEditor(sim),
          const SizedBox(height: 12),
          _buildVersionPanel(),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: _buildEditor(sim)),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: _buildVersionPanel()),
            ],
          ),
        ],
      ],
    );

    return Stack(
      children: [
        Positioned.fill(child: Container(color: const Color(0xFFF8FAFC))),
        SingleChildScrollView(padding: const EdgeInsets.all(20), child: page),
      ],
    );
  }

  Widget _buildEditor(_IhizSimResult sim) {
    return Column(
      children: [
        _section(
          '1. Genel fiyat motoru ayarları',
          'Taban, km, min/max teslimat ve dinamik fiyat kontrolü',
          Column(
            children: [
              _slider(
                'Taban ücret',
                _config.baseFee,
                0,
                150,
                150,
                _try(_config.baseFee),
                (value) {
                  final normalized = _round2(value);
                  setState(
                    () => _config = _config.copyWith(
                      baseFee: normalized,
                      courierBaseEarning: normalized,
                    ),
                  );
                },
              ),
              _slider(
                'Km başı ücret',
                _config.perKmFee,
                0,
                40,
                400,
                _try(_config.perKmFee, decimal: true),
                (value) {
                  final normalized = _round2(value);
                  setState(
                    () => _config = _config.copyWith(
                      perKmFee: normalized,
                      courierPerKmEarning: normalized,
                    ),
                  );
                },
              ),
              _slider(
                'Platform fee',
                _config.platformFee,
                0,
                40,
                400,
                _try(_config.platformFee, decimal: true),
                (value) => setState(
                  () => _config = _config.copyWith(platformFee: _round2(value)),
                ),
              ),
              _slider(
                'Yakın mesafe eşiği',
                _config.nearbyThresholdKm,
                1,
                20,
                190,
                '${_config.nearbyThresholdKm.toStringAsFixed(1)} km',
                (value) => setState(
                  () => _config = _config.copyWith(
                    nearbyThresholdKm: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Orta mesafe eşiği',
                _config.mediumDistanceThresholdKm,
                5,
                40,
                350,
                '${_config.mediumDistanceThresholdKm.toStringAsFixed(1)} km',
                (value) => setState(
                  () => _config = _config.copyWith(
                    mediumDistanceThresholdKm: _round2(value),
                  ),
                ),
              ),
              _slider(
                'İHIZ direct max mesafe',
                _config.ihizDirectMaxDistanceKm,
                5,
                60,
                550,
                '${_config.ihizDirectMaxDistanceKm.toStringAsFixed(1)} km',
                (value) => setState(
                  () => _config = _config.copyWith(
                    ihizDirectMaxDistanceKm: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Şubeye bırakma taban ücreti',
                _config.branchBaseFee,
                0,
                80,
                800,
                _try(_config.branchBaseFee, decimal: true),
                (value) => setState(
                  () => _config = _config.copyWith(branchBaseFee: _round2(value)),
                ),
              ),
              _slider(
                'Şubeye bırakma km ücreti',
                _config.branchKmFee,
                0,
                20,
                200,
                _try(_config.branchKmFee, decimal: true),
                (value) => setState(
                  () => _config = _config.copyWith(branchKmFee: _round2(value)),
                ),
              ),
              _textInput(
                'İHIZ aktif şehirler',
                _config.ihizActiveCities,
                'Örn: Eskişehir,İstanbul,Ankara',
                (value) => setState(
                  () => _config = _config.copyWith(ihizActiveCities: value),
                ),
              ),
              _textInput(
                'Aktif kargo firmaları',
                _config.enabledCargoCompanies,
                'Örn: aras,mng,ptt',
                (value) => setState(
                  () =>
                      _config = _config.copyWith(enabledCargoCompanies: value),
                ),
              ),
              _slider(
                'Minimum teslimat ücreti',
                _config.minDeliveryFee,
                0,
                300,
                300,
                _try(_config.minDeliveryFee),
                (value) => setState(
                  () => _config = _config.copyWith(
                    minDeliveryFee: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Maksimum teslimat ücreti',
                _config.maxDeliveryFee,
                50,
                900,
                850,
                _try(_config.maxDeliveryFee),
                (value) => setState(
                  () => _config = _config.copyWith(
                    maxDeliveryFee: _round2(value),
                  ),
                ),
              ),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Dinamik fiyat aktif/pasif'),
                value: _config.dynamicPricingEnabled,
                onChanged: (value) => setState(
                  () =>
                      _config = _config.copyWith(dynamicPricingEnabled: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '2. İBUL içi sipariş fiyat yönetimi',
          'Müşteri katkı kademeleri, satıcı katkısı ve ücretsiz teslimat',
          Column(
            children: [
              _slider(
                '0-3 km müşteri katkısı',
                _config.customerFee0To3Km,
                0,
                200,
                200,
                _try(_config.customerFee0To3Km),
                (value) => setState(
                  () => _config = _config.copyWith(
                    customerFee0To3Km: _round2(value),
                  ),
                ),
              ),
              _slider(
                '3-6 km müşteri katkısı',
                _config.customerFee3To6Km,
                0,
                250,
                250,
                _try(_config.customerFee3To6Km),
                (value) => setState(
                  () => _config = _config.copyWith(
                    customerFee3To6Km: _round2(value),
                  ),
                ),
              ),
              _slider(
                '6+ km müşteri katkısı',
                _config.customerFee6PlusKm,
                0,
                350,
                350,
                _try(_config.customerFee6PlusKm),
                (value) => setState(
                  () => _config = _config.copyWith(
                    customerFee6PlusKm: _round2(value),
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _config.sellerContributionMode,
                decoration: const InputDecoration(
                  labelText: 'Satıcı katkısı hesaplama',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'remaining_after_customer',
                    child: Text('Müşteri sonrası kalan tutar'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed_percent',
                    child: Text('Sabit yüzde'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(
                    () => _config = _config.copyWith(
                      sellerContributionMode: value,
                    ),
                  );
                },
              ),
              if (_config.sellerContributionMode == 'fixed_percent')
                _slider(
                  'Satıcı katkısı yüzdesi',
                  _config.sellerContributionPercent,
                  0,
                  100,
                  100,
                  '%${_config.sellerContributionPercent.round()}',
                  (value) => setState(
                    () => _config = _config.copyWith(
                      sellerContributionPercent: _round2(value),
                    ),
                  ),
                ),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ücretsiz teslimat kampanya kontrolü'),
                value: _config.freeDeliveryCampaignEnabled,
                onChanged: (value) => setState(
                  () => _config = _config.copyWith(
                    freeDeliveryCampaignEnabled: value,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '3. Dış sipariş fiyat yönetimi',
          'Dış siparişte satıcıya yazım, servis bedeli ve minimum tutar',
          Column(
            children: [
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Dış siparişte tüm ücret satıcıya yazılsın'),
                value: _config.externalSellerPaysAll,
                onChanged: (value) => setState(
                  () =>
                      _config = _config.copyWith(externalSellerPaysAll: value),
                ),
              ),
              _slider(
                'Servis bedeli',
                _config.externalServiceFee,
                0,
                120,
                120,
                _try(_config.externalServiceFee),
                (value) => setState(
                  () => _config = _config.copyWith(
                    externalServiceFee: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Minimum dış sipariş ücreti',
                _config.externalMinFee,
                0,
                400,
                400,
                _try(_config.externalMinFee),
                (value) => setState(
                  () => _config = _config.copyWith(
                    externalMinFee: _round2(value),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '4. Bonus yönetimi',
          'Gece, yağmur, yoğunluk ve yol üstü bonusları',
          Column(
            children: [
              _slider(
                'Gece bonusu',
                _config.nightBonus,
                0,
                90,
                90,
                _try(_config.nightBonus),
                (value) => setState(
                  () => _config = _config.copyWith(nightBonus: _round2(value)),
                ),
              ),
              _slider(
                'Yağmur bonusu',
                _config.rainBonus,
                0,
                90,
                90,
                _try(_config.rainBonus),
                (value) => setState(
                  () => _config = _config.copyWith(rainBonus: _round2(value)),
                ),
              ),
              _slider(
                'Yoğunluk bonusu',
                _config.surgeBonus,
                0,
                120,
                120,
                _try(_config.surgeBonus),
                (value) => setState(
                  () => _config = _config.copyWith(surgeBonus: _round2(value)),
                ),
              ),
              _slider(
                'Yol üstü sipariş ek ücreti',
                _config.multiOrderExtraFee,
                0,
                140,
                140,
                _try(_config.multiOrderExtraFee),
                (value) => setState(
                  () => _config = _config.copyWith(
                    multiOrderExtraFee: _round2(value),
                  ),
                ),
              ),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Multi-order aktif/pasif'),
                value: _config.multiOrderEnabled,
                onChanged: (value) => setState(
                  () => _config = _config.copyWith(multiOrderEnabled: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '5. Wallet kuralları',
          'Minimum bakiye, reserve/capture/release akışı ve uyarı seviyesi',
          Column(
            children: [
              _slider(
                'Minimum wallet bakiyesi',
                _config.minWalletBalance,
                0,
                10000,
                1000,
                _try(_config.minWalletBalance),
                (value) => setState(
                  () => _config = _config.copyWith(
                    minWalletBalance: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Düşük bakiye uyarı seviyesi',
                _config.lowBalanceWarningLevel,
                0,
                10000,
                1000,
                _try(_config.lowBalanceWarningLevel),
                (value) => setState(
                  () => _config = _config.copyWith(
                    lowBalanceWarningLevel: _round2(value),
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _config.walletFlowMode,
                decoration: const InputDecoration(
                  labelText: 'Reserve / Capture / Release mantığı',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'reserve_capture_release',
                    child: Text('reserve → capture/release'),
                  ),
                  DropdownMenuItem(
                    value: 'direct_capture',
                    child: Text('doğrudan capture'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(
                    () => _config = _config.copyWith(walletFlowMode: value),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '6. İptal / iade kuralları',
          'İptal aşamasına göre iade ve kesinti oranları',
          Column(
            children: [
              _slider(
                'Kurye atanmadan iptal iade oranı',
                _config.cancelBeforeAssignRefundPct,
                0,
                100,
                100,
                '%${_config.cancelBeforeAssignRefundPct.round()}',
                (value) => setState(
                  () => _config = _config.copyWith(
                    cancelBeforeAssignRefundPct: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kurye atandıktan sonra iade oranı',
                _config.cancelAfterAssignRefundPct,
                0,
                100,
                100,
                '%${_config.cancelAfterAssignRefundPct.round()}',
                (value) => setState(
                  () => _config = _config.copyWith(
                    cancelAfterAssignRefundPct: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Pickup sonrası iade oranı',
                _config.cancelAfterPickupRefundPct,
                0,
                100,
                100,
                '%${_config.cancelAfterPickupRefundPct.round()}',
                (value) => setState(
                  () => _config = _config.copyWith(
                    cancelAfterPickupRefundPct: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kesinti oranı',
                _config.cancelPenaltyPct,
                0,
                100,
                100,
                '%${_config.cancelPenaltyPct.round()}',
                (value) => setState(
                  () => _config = _config.copyWith(
                    cancelPenaltyPct: _round2(value),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '7. Kurye hakediş ayarları',
          'ETA bazlı kurye ücreti: max(taban+km, ETA*dakika) + bonuslar',
          Column(
            children: [
              _slider(
                'Kurye taban kazanç',
                _config.courierBaseEarning,
                0,
                150,
                150,
                _try(_config.courierBaseEarning),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierBaseEarning: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kurye km başı kazanç',
                _config.courierPerKmEarning,
                0,
                40,
                400,
                _try(_config.courierPerKmEarning, decimal: true),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierPerKmEarning: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kurye dakika kazancı (ETA)',
                _config.courierMinutePrice,
                0,
                20,
                200,
                _try(_config.courierMinutePrice, decimal: true),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierMinutePrice: _round2(value),
                  ),
                ),
              ),
              _slider(
                'ETA km başına dakika',
                _config.etaPerKmMinute,
                1,
                12,
                110,
                _config.etaPerKmMinute.toStringAsFixed(1),
                (value) => setState(
                  () =>
                      _config = _config.copyWith(etaPerKmMinute: _round2(value)),
                ),
              ),
              _slider(
                'ETA sabit dakika',
                _config.etaBaseMinute,
                0,
                30,
                300,
                _config.etaBaseMinute.toStringAsFixed(1),
                (value) => setState(
                  () =>
                      _config = _config.copyWith(etaBaseMinute: _round2(value)),
                ),
              ),
              _slider(
                'Kurye gece bonusu',
                _config.courierNightBonus,
                0,
                80,
                80,
                _try(_config.courierNightBonus),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierNightBonus: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kurye yağmur bonusu',
                _config.courierRainBonus,
                0,
                80,
                80,
                _try(_config.courierRainBonus),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierRainBonus: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kurye yoğunluk bonusu',
                _config.courierSurgeBonus,
                0,
                120,
                120,
                _try(_config.courierSurgeBonus),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierSurgeBonus: _round2(value),
                  ),
                ),
              ),
              _slider(
                'Kurye multi-order bonusu',
                _config.courierMultiOrderBonus,
                0,
                120,
                120,
                _try(_config.courierMultiOrderBonus),
                (value) => setState(
                  () => _config = _config.copyWith(
                    courierMultiOrderBonus: _round2(value),
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _config.weeklyPayoutDay,
                decoration: const InputDecoration(
                  labelText: 'Haftalık ödeme günü',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Pazartesi',
                    child: Text('Pazartesi'),
                  ),
                  DropdownMenuItem(value: 'Salı', child: Text('Salı')),
                  DropdownMenuItem(value: 'Çarşamba', child: Text('Çarşamba')),
                  DropdownMenuItem(value: 'Perşembe', child: Text('Perşembe')),
                  DropdownMenuItem(value: 'Cuma', child: Text('Cuma')),
                  DropdownMenuItem(
                    value: 'Cumartesi',
                    child: Text('Cumartesi'),
                  ),
                  DropdownMenuItem(value: 'Pazar', child: Text('Pazar')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(
                    () => _config = _config.copyWith(weeklyPayoutDay: value),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          '8. Hesaplama simülatörü',
          'Sipariş tipi/mesafe/bonus senaryolarına göre anlık tutar analizi',
          Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _simOrderType,
                decoration: const InputDecoration(labelText: 'Sipariş tipi'),
                items: const [
                  DropdownMenuItem(
                    value: 'ibul_internal',
                    child: Text('İBUL iç sipariş'),
                  ),
                  DropdownMenuItem(
                    value: 'external',
                    child: Text('Dış sipariş'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _simOrderType = value);
                },
              ),
              _slider(
                'Mesafe',
                _simDistanceKm,
                0.3,
                25,
                247,
                '${_simDistanceKm.toStringAsFixed(1)} km',
                (value) => setState(() => _simDistanceKm = _round2(value)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    'Gece',
                    _simNight,
                    () => setState(() => _simNight = !_simNight),
                  ),
                  _chip(
                    'Yağmur',
                    _simRain,
                    () => setState(() => _simRain = !_simRain),
                  ),
                  _chip(
                    'Yoğunluk',
                    _simSurge,
                    () => setState(() => _simSurge = !_simSurge),
                  ),
                  _chip(
                    'Multi-order',
                    _simMultiOrder,
                    () => setState(() => _simMultiOrder = !_simMultiOrder),
                  ),
                  _chip(
                    'Ücretsiz teslimat',
                    _simFreeDelivery,
                    () => setState(() => _simFreeDelivery = !_simFreeDelivery),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _simCancelStage,
                decoration: const InputDecoration(labelText: 'İptal senaryosu'),
                items: const [
                  DropdownMenuItem(
                    value: 'before_assign',
                    child: Text('Kurye atanmadan iptal'),
                  ),
                  DropdownMenuItem(
                    value: 'after_assign',
                    child: Text('Kurye atandıktan sonra iptal'),
                  ),
                  DropdownMenuItem(
                    value: 'after_pickup',
                    child: Text('Pickup sonrası iptal'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _simCancelStage = value);
                },
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _simRow(
                      'ETA (dk)',
                      sim.etaMinutes.toStringAsFixed(1),
                    ),
                    _simRow(
                      'Surge çarpanı',
                      sim.surgeMultiplier.toStringAsFixed(2),
                    ),
                    _simRow(
                      'Hava bonusu',
                      _try(sim.weatherBonus),
                    ),
                    _simRow('Önerilen teslimat', sim.recommendedType),
                    _simRow('İHIZ şubeye bırakma', _try(sim.branchDropFee)),
                    _simRow(
                      'Toplam teslimat ücreti',
                      _try(sim.totalDeliveryFee),
                    ),
                    _simRow('Müşteriden alınacak tutar', _try(sim.customerFee)),
                    _simRow('Satıcıdan alınacak tutar', _try(sim.sellerFee)),
                    _simRow('Kurye hakedişi', _try(sim.courierEarning)),
                    _simRow('Platform fee', _try(sim.platformFee)),
                    _simRow('Platform net kazancı', _try(sim.platformMargin)),
                    _simRow(
                      'Kurye saatlik tahmin',
                      '${_try(sim.courierHourlyEstimate)} / saat',
                    ),
                    _simRow(
                      'Platform marj oranı',
                      '%${sim.marginRate.toStringAsFixed(1)}',
                    ),
                    _simRow('Reserve wallet tutarı', _try(sim.reserveAmount)),
                    _simRow(
                      'İade tutarı (${sim.refundRate.toStringAsFixed(0)}%)',
                      _try(sim.refundAmount),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Formül: max(taban + km*birim, ETA*dakika) * surge + bonuslar + platform fee',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionPanel() {
    return _section(
      'Kural sürümü ve log',
      'Aktif kural setini sürümleyip hangi tarihte devreye alındığını takip edin',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _versionNoteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Sürüm notu',
              hintText: 'Örn: Gece bonusu güncellendi',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingVersion ? null : _saveNewVersion,
              icon: _savingVersion
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _savingVersion ? 'Kaydediliyor...' : 'Yeni sürüm olarak kaydet',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingVersions)
            const LinearProgressIndicator(minHeight: 2)
          else if (_versions.isEmpty)
            const Text(
              'Henüz sürüm kaydı yok.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            )
          else
            ..._versions.take(14).map((item) {
              final date =
                  '${item.activeFrom.day.toString().padLeft(2, '0')}.${item.activeFrom.month.toString().padLeft(2, '0')}.${item.activeFrom.year}';
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isActive
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item.isActive
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'v${item.version} • $date',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (item.note.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.note,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (item.isActive)
                      const Chip(
                        label: Text('Aktif'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _section(String title, String subtitle, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _slider(
    String title,
    double value,
    double min,
    double max,
    int _,
    String label,
    ValueChanged<double> onChanged,
  ) {
    final fieldKey = 'value_$title';
    final controller = _valueControllers.putIfAbsent(
      fieldKey,
      () => TextEditingController(text: _editableNumber(value)),
    );
    final focusNode = _valueFocusNodes.putIfAbsent(fieldKey, FocusNode.new);
    if (!focusNode.hasFocus) {
      final expected = _editableNumber(value);
      if (controller.text != expected) {
        controller.text = expected;
      }
    }
    final suffixText = label.contains('%')
        ? '%'
        : (title.toLowerCase().contains('mesafe') ? 'km' : 'TL');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              hintText: _editableNumber(value),
              suffixText: suffixText,
              helperText:
                  'Aralık: ${_editableNumber(min)} - ${_editableNumber(max)}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onFieldSubmitted: (_) => _commitNumberValue(
              fieldKey: fieldKey,
              min: min,
              max: max,
              currentValue: value,
              onChanged: onChanged,
            ),
            onTapOutside: (_) {
              _commitNumberValue(
                fieldKey: fieldKey,
                min: min,
                max: max,
                currentValue: value,
                onChanged: onChanged,
              );
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _textInput(
    String title,
    String value,
    String hint,
    ValueChanged<String> onChanged,
  ) {
    final fieldKey = 'text_$title';
    final controller = _valueControllers.putIfAbsent(
      fieldKey,
      () => TextEditingController(text: value),
    );
    final focusNode = _valueFocusNodes.putIfAbsent(fieldKey, FocusNode.new);
    if (!focusNode.hasFocus && controller.text != value) {
      controller.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  String _editableNumber(double value) {
    final rounded = _round2(value);
    if ((rounded - rounded.roundToDouble()).abs() < 0.0001) {
      return rounded.round().toString();
    }
    return rounded
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double? _parseNumberInput(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text
        .replaceAll('₺', '')
        .replaceAll('%', '')
        .replaceAll('TL', '')
        .replaceAll('tl', '')
        .replaceAll(' ', '');

    if (text.contains(',') && text.contains('.')) {
      if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
        text = text.replaceAll('.', '').replaceAll(',', '.');
      } else {
        text = text.replaceAll(',', '');
      }
    } else if (text.contains(',')) {
      text = text.replaceAll(',', '.');
    }

    text = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (text.isEmpty || text == '.' || text == '-') return null;
    return double.tryParse(text);
  }

  void _commitNumberValue({
    required String fieldKey,
    required double min,
    required double max,
    required double currentValue,
    required ValueChanged<double> onChanged,
  }) {
    final controller = _valueControllers[fieldKey];
    if (controller == null) return;
    final parsed = _parseNumberInput(controller.text);
    final next = ((parsed ?? currentValue).clamp(min, max)).toDouble();
    controller.text = _editableNumber(next);
    if ((next - currentValue).abs() > 0.0001) {
      onChanged(next);
    }
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _simRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1F2937)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF991B1B),
        ),
      ),
    );
  }
}

class _IhizPricingVersion {
  const _IhizPricingVersion({
    required this.version,
    required this.config,
    required this.activeFrom,
    required this.createdAt,
    required this.isActive,
    required this.note,
  });

  final int version;
  final _IhizPricingConfig config;
  final DateTime activeFrom;
  final DateTime createdAt;
  final bool isActive;
  final String note;
}

class _IhizSimResult {
  const _IhizSimResult({
    required this.etaMinutes,
    required this.surgeMultiplier,
    required this.weatherBonus,
    required this.recommendedType,
    required this.branchDropFee,
    required this.totalDeliveryFee,
    required this.customerFee,
    required this.sellerFee,
    required this.courierEarning,
    required this.platformFee,
    required this.platformMargin,
    required this.courierHourlyEstimate,
    required this.marginRate,
    required this.reserveAmount,
    required this.refundAmount,
    required this.refundRate,
  });

  final double etaMinutes;
  final double surgeMultiplier;
  final double weatherBonus;
  final String recommendedType;
  final double branchDropFee;
  final double totalDeliveryFee;
  final double customerFee;
  final double sellerFee;
  final double courierEarning;
  final double platformFee;
  final double platformMargin;
  final double courierHourlyEstimate;
  final double marginRate;
  final double reserveAmount;
  final double refundAmount;
  final double refundRate;
}

class _IhizPricingConfig {
  const _IhizPricingConfig({
    required this.baseFee,
    required this.perKmFee,
    required this.platformFee,
    required this.nearbyThresholdKm,
    required this.mediumDistanceThresholdKm,
    required this.ihizDirectMaxDistanceKm,
    required this.branchBaseFee,
    required this.branchKmFee,
    required this.ihizActiveCities,
    required this.enabledCargoCompanies,
    required this.minDeliveryFee,
    required this.maxDeliveryFee,
    required this.dynamicPricingEnabled,
    required this.customerFee0To3Km,
    required this.customerFee3To6Km,
    required this.customerFee6PlusKm,
    required this.sellerContributionMode,
    required this.sellerContributionPercent,
    required this.freeDeliveryCampaignEnabled,
    required this.externalSellerPaysAll,
    required this.externalServiceFee,
    required this.externalMinFee,
    required this.nightBonus,
    required this.rainBonus,
    required this.surgeBonus,
    required this.multiOrderExtraFee,
    required this.multiOrderEnabled,
    required this.minWalletBalance,
    required this.walletFlowMode,
    required this.lowBalanceWarningLevel,
    required this.cancelBeforeAssignRefundPct,
    required this.cancelAfterAssignRefundPct,
    required this.cancelAfterPickupRefundPct,
    required this.cancelPenaltyPct,
    required this.courierBaseEarning,
    required this.courierPerKmEarning,
    required this.courierMinutePrice,
    required this.courierNightBonus,
    required this.courierRainBonus,
    required this.courierSurgeBonus,
    required this.courierMultiOrderBonus,
    required this.etaPerKmMinute,
    required this.etaBaseMinute,
    required this.weeklyPayoutDay,
  });

  final double baseFee;
  final double perKmFee;
  final double platformFee;
  final double nearbyThresholdKm;
  final double mediumDistanceThresholdKm;
  final double ihizDirectMaxDistanceKm;
  final double branchBaseFee;
  final double branchKmFee;
  final String ihizActiveCities;
  final String enabledCargoCompanies;
  final double minDeliveryFee;
  final double maxDeliveryFee;
  final bool dynamicPricingEnabled;

  final double customerFee0To3Km;
  final double customerFee3To6Km;
  final double customerFee6PlusKm;
  final String sellerContributionMode;
  final double sellerContributionPercent;
  final bool freeDeliveryCampaignEnabled;

  final bool externalSellerPaysAll;
  final double externalServiceFee;
  final double externalMinFee;

  final double nightBonus;
  final double rainBonus;
  final double surgeBonus;
  final double multiOrderExtraFee;
  final bool multiOrderEnabled;

  final double minWalletBalance;
  final String walletFlowMode;
  final double lowBalanceWarningLevel;

  final double cancelBeforeAssignRefundPct;
  final double cancelAfterAssignRefundPct;
  final double cancelAfterPickupRefundPct;
  final double cancelPenaltyPct;

  final double courierBaseEarning;
  final double courierPerKmEarning;
  final double courierMinutePrice;
  final double courierNightBonus;
  final double courierRainBonus;
  final double courierSurgeBonus;
  final double courierMultiOrderBonus;
  final double etaPerKmMinute;
  final double etaBaseMinute;
  final String weeklyPayoutDay;

  static const defaults = _IhizPricingConfig(
    baseFee: 28,
    perKmFee: 7,
    platformFee: 10,
    nearbyThresholdKm: 8,
    mediumDistanceThresholdKm: 20,
    ihizDirectMaxDistanceKm: 20,
    branchBaseFee: 20,
    branchKmFee: 6,
    ihizActiveCities: 'Eskişehir,İstanbul,Ankara',
    enabledCargoCompanies: 'aras,mng,ptt',
    minDeliveryFee: 35,
    maxDeliveryFee: 350,
    dynamicPricingEnabled: true,
    customerFee0To3Km: 35,
    customerFee3To6Km: 45,
    customerFee6PlusKm: 55,
    sellerContributionMode: 'remaining_after_customer',
    sellerContributionPercent: 50,
    freeDeliveryCampaignEnabled: false,
    externalSellerPaysAll: true,
    externalServiceFee: 0,
    externalMinFee: 45,
    nightBonus: 12,
    rainBonus: 15,
    surgeBonus: 10,
    multiOrderExtraFee: 25,
    multiOrderEnabled: true,
    minWalletBalance: 100,
    walletFlowMode: 'reserve_capture_release',
    lowBalanceWarningLevel: 200,
    cancelBeforeAssignRefundPct: 100,
    cancelAfterAssignRefundPct: 70,
    cancelAfterPickupRefundPct: 10,
    cancelPenaltyPct: 15,
    courierBaseEarning: 28,
    courierPerKmEarning: 7,
    courierMinutePrice: 4,
    courierNightBonus: 12,
    courierRainBonus: 15,
    courierSurgeBonus: 10,
    courierMultiOrderBonus: 25,
    etaPerKmMinute: 5,
    etaBaseMinute: 6,
    weeklyPayoutDay: 'Cuma',
  );

  _IhizPricingConfig copyWith({
    double? baseFee,
    double? perKmFee,
    double? platformFee,
    double? nearbyThresholdKm,
    double? mediumDistanceThresholdKm,
    double? ihizDirectMaxDistanceKm,
    double? branchBaseFee,
    double? branchKmFee,
    String? ihizActiveCities,
    String? enabledCargoCompanies,
    double? minDeliveryFee,
    double? maxDeliveryFee,
    bool? dynamicPricingEnabled,
    double? customerFee0To3Km,
    double? customerFee3To6Km,
    double? customerFee6PlusKm,
    String? sellerContributionMode,
    double? sellerContributionPercent,
    bool? freeDeliveryCampaignEnabled,
    bool? externalSellerPaysAll,
    double? externalServiceFee,
    double? externalMinFee,
    double? nightBonus,
    double? rainBonus,
    double? surgeBonus,
    double? multiOrderExtraFee,
    bool? multiOrderEnabled,
    double? minWalletBalance,
    String? walletFlowMode,
    double? lowBalanceWarningLevel,
    double? cancelBeforeAssignRefundPct,
    double? cancelAfterAssignRefundPct,
    double? cancelAfterPickupRefundPct,
    double? cancelPenaltyPct,
    double? courierBaseEarning,
    double? courierPerKmEarning,
    double? courierMinutePrice,
    double? courierNightBonus,
    double? courierRainBonus,
    double? courierSurgeBonus,
    double? courierMultiOrderBonus,
    double? etaPerKmMinute,
    double? etaBaseMinute,
    String? weeklyPayoutDay,
  }) {
    return _IhizPricingConfig(
      baseFee: baseFee ?? this.baseFee,
      perKmFee: perKmFee ?? this.perKmFee,
      platformFee: platformFee ?? this.platformFee,
      nearbyThresholdKm: nearbyThresholdKm ?? this.nearbyThresholdKm,
      mediumDistanceThresholdKm:
          mediumDistanceThresholdKm ?? this.mediumDistanceThresholdKm,
      ihizDirectMaxDistanceKm:
          ihizDirectMaxDistanceKm ?? this.ihizDirectMaxDistanceKm,
      branchBaseFee: branchBaseFee ?? this.branchBaseFee,
      branchKmFee: branchKmFee ?? this.branchKmFee,
      ihizActiveCities: ihizActiveCities ?? this.ihizActiveCities,
      enabledCargoCompanies:
          enabledCargoCompanies ?? this.enabledCargoCompanies,
      minDeliveryFee: minDeliveryFee ?? this.minDeliveryFee,
      maxDeliveryFee: maxDeliveryFee ?? this.maxDeliveryFee,
      dynamicPricingEnabled:
          dynamicPricingEnabled ?? this.dynamicPricingEnabled,
      customerFee0To3Km: customerFee0To3Km ?? this.customerFee0To3Km,
      customerFee3To6Km: customerFee3To6Km ?? this.customerFee3To6Km,
      customerFee6PlusKm: customerFee6PlusKm ?? this.customerFee6PlusKm,
      sellerContributionMode:
          sellerContributionMode ?? this.sellerContributionMode,
      sellerContributionPercent:
          sellerContributionPercent ?? this.sellerContributionPercent,
      freeDeliveryCampaignEnabled:
          freeDeliveryCampaignEnabled ?? this.freeDeliveryCampaignEnabled,
      externalSellerPaysAll:
          externalSellerPaysAll ?? this.externalSellerPaysAll,
      externalServiceFee: externalServiceFee ?? this.externalServiceFee,
      externalMinFee: externalMinFee ?? this.externalMinFee,
      nightBonus: nightBonus ?? this.nightBonus,
      rainBonus: rainBonus ?? this.rainBonus,
      surgeBonus: surgeBonus ?? this.surgeBonus,
      multiOrderExtraFee: multiOrderExtraFee ?? this.multiOrderExtraFee,
      multiOrderEnabled: multiOrderEnabled ?? this.multiOrderEnabled,
      minWalletBalance: minWalletBalance ?? this.minWalletBalance,
      walletFlowMode: walletFlowMode ?? this.walletFlowMode,
      lowBalanceWarningLevel:
          lowBalanceWarningLevel ?? this.lowBalanceWarningLevel,
      cancelBeforeAssignRefundPct:
          cancelBeforeAssignRefundPct ?? this.cancelBeforeAssignRefundPct,
      cancelAfterAssignRefundPct:
          cancelAfterAssignRefundPct ?? this.cancelAfterAssignRefundPct,
      cancelAfterPickupRefundPct:
          cancelAfterPickupRefundPct ?? this.cancelAfterPickupRefundPct,
      cancelPenaltyPct: cancelPenaltyPct ?? this.cancelPenaltyPct,
      courierBaseEarning: courierBaseEarning ?? this.courierBaseEarning,
      courierPerKmEarning: courierPerKmEarning ?? this.courierPerKmEarning,
      courierMinutePrice: courierMinutePrice ?? this.courierMinutePrice,
      courierNightBonus: courierNightBonus ?? this.courierNightBonus,
      courierRainBonus: courierRainBonus ?? this.courierRainBonus,
      courierSurgeBonus: courierSurgeBonus ?? this.courierSurgeBonus,
      courierMultiOrderBonus:
          courierMultiOrderBonus ?? this.courierMultiOrderBonus,
      etaPerKmMinute: etaPerKmMinute ?? this.etaPerKmMinute,
      etaBaseMinute: etaBaseMinute ?? this.etaBaseMinute,
      weeklyPayoutDay: weeklyPayoutDay ?? this.weeklyPayoutDay,
    );
  }

  Map<String, dynamic> toJson() => {
    'base_fee': baseFee,
    'per_km_fee': perKmFee,
    'platform_fee': platformFee,
    'nearby_threshold_km': nearbyThresholdKm,
    'medium_distance_threshold_km': mediumDistanceThresholdKm,
    'ihiz_direct_max_distance_km': ihizDirectMaxDistanceKm,
    'branch_base_fee': branchBaseFee,
    'branch_km_fee': branchKmFee,
    'ihiz_active_cities': ihizActiveCities,
    'enabled_cargo_companies': enabledCargoCompanies,
    'min_delivery_fee': minDeliveryFee,
    'max_delivery_fee': maxDeliveryFee,
    'dynamic_pricing_enabled': dynamicPricingEnabled,
    'customer_fee_0_3_km': customerFee0To3Km,
    'customer_fee_3_6_km': customerFee3To6Km,
    'customer_fee_6_plus_km': customerFee6PlusKm,
    'seller_contribution_mode': sellerContributionMode,
    'seller_contribution_percent': sellerContributionPercent,
    'free_delivery_campaign_enabled': freeDeliveryCampaignEnabled,
    'external_seller_pays_all': externalSellerPaysAll,
    'external_service_fee': externalServiceFee,
    'external_min_fee': externalMinFee,
    'night_bonus': nightBonus,
    'rain_bonus': rainBonus,
    'surge_bonus': surgeBonus,
    'multi_order_extra_fee': multiOrderExtraFee,
    'multi_order_enabled': multiOrderEnabled,
    'min_wallet_balance': minWalletBalance,
    'wallet_flow_mode': walletFlowMode,
    'low_balance_warning_level': lowBalanceWarningLevel,
    'cancel_before_assign_refund_pct': cancelBeforeAssignRefundPct,
    'cancel_after_assign_refund_pct': cancelAfterAssignRefundPct,
    'cancel_after_pickup_refund_pct': cancelAfterPickupRefundPct,
    'cancel_penalty_pct': cancelPenaltyPct,
    'courier_base_earning': courierBaseEarning,
    'courier_per_km_earning': courierPerKmEarning,
    'courier_minute_price': courierMinutePrice,
    'courier_night_bonus': courierNightBonus,
    'courier_rain_bonus': courierRainBonus,
    'courier_surge_bonus': courierSurgeBonus,
    'courier_multi_order_bonus': courierMultiOrderBonus,
    'eta_per_km_minute': etaPerKmMinute,
    'eta_base_minute': etaBaseMinute,
    'weekly_payout_day': weeklyPayoutDay,
  };

  static _IhizPricingConfig fromJson(Map<String, dynamic> raw) {
    double toDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool toBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
      return fallback;
    }

    final d = _IhizPricingConfig.defaults;
    return _IhizPricingConfig(
      baseFee: toDouble(raw['base_fee'], d.baseFee),
      perKmFee: toDouble(raw['per_km_fee'], d.perKmFee),
      platformFee: toDouble(raw['platform_fee'], d.platformFee),
      nearbyThresholdKm: toDouble(
        raw['nearby_threshold_km'],
        d.nearbyThresholdKm,
      ),
      mediumDistanceThresholdKm: toDouble(
        raw['medium_distance_threshold_km'],
        d.mediumDistanceThresholdKm,
      ),
      ihizDirectMaxDistanceKm: toDouble(
        raw['ihiz_direct_max_distance_km'],
        d.ihizDirectMaxDistanceKm,
      ),
      branchBaseFee: toDouble(raw['branch_base_fee'], d.branchBaseFee),
      branchKmFee: toDouble(raw['branch_km_fee'], d.branchKmFee),
      ihizActiveCities:
          raw['ihiz_active_cities']?.toString() ?? d.ihizActiveCities,
      enabledCargoCompanies:
          raw['enabled_cargo_companies']?.toString() ?? d.enabledCargoCompanies,
      minDeliveryFee: toDouble(raw['min_delivery_fee'], d.minDeliveryFee),
      maxDeliveryFee: toDouble(raw['max_delivery_fee'], d.maxDeliveryFee),
      dynamicPricingEnabled: toBool(
        raw['dynamic_pricing_enabled'],
        d.dynamicPricingEnabled,
      ),
      customerFee0To3Km: toDouble(
        raw['customer_fee_0_3_km'],
        d.customerFee0To3Km,
      ),
      customerFee3To6Km: toDouble(
        raw['customer_fee_3_6_km'],
        d.customerFee3To6Km,
      ),
      customerFee6PlusKm: toDouble(
        raw['customer_fee_6_plus_km'],
        d.customerFee6PlusKm,
      ),
      sellerContributionMode:
          raw['seller_contribution_mode']?.toString() ??
          d.sellerContributionMode,
      sellerContributionPercent: toDouble(
        raw['seller_contribution_percent'],
        d.sellerContributionPercent,
      ),
      freeDeliveryCampaignEnabled: toBool(
        raw['free_delivery_campaign_enabled'],
        d.freeDeliveryCampaignEnabled,
      ),
      externalSellerPaysAll: toBool(
        raw['external_seller_pays_all'],
        d.externalSellerPaysAll,
      ),
      externalServiceFee: toDouble(
        raw['external_service_fee'],
        d.externalServiceFee,
      ),
      externalMinFee: toDouble(raw['external_min_fee'], d.externalMinFee),
      nightBonus: toDouble(raw['night_bonus'], d.nightBonus),
      rainBonus: toDouble(raw['rain_bonus'], d.rainBonus),
      surgeBonus: toDouble(raw['surge_bonus'], d.surgeBonus),
      multiOrderExtraFee: toDouble(
        raw['multi_order_extra_fee'],
        d.multiOrderExtraFee,
      ),
      multiOrderEnabled: toBool(
        raw['multi_order_enabled'],
        d.multiOrderEnabled,
      ),
      minWalletBalance: toDouble(raw['min_wallet_balance'], d.minWalletBalance),
      walletFlowMode: raw['wallet_flow_mode']?.toString() ?? d.walletFlowMode,
      lowBalanceWarningLevel: toDouble(
        raw['low_balance_warning_level'],
        d.lowBalanceWarningLevel,
      ),
      cancelBeforeAssignRefundPct: toDouble(
        raw['cancel_before_assign_refund_pct'],
        d.cancelBeforeAssignRefundPct,
      ),
      cancelAfterAssignRefundPct: toDouble(
        raw['cancel_after_assign_refund_pct'],
        d.cancelAfterAssignRefundPct,
      ),
      cancelAfterPickupRefundPct: toDouble(
        raw['cancel_after_pickup_refund_pct'],
        d.cancelAfterPickupRefundPct,
      ),
      cancelPenaltyPct: toDouble(raw['cancel_penalty_pct'], d.cancelPenaltyPct),
      courierBaseEarning: toDouble(
        raw['courier_base_earning'],
        d.courierBaseEarning,
      ),
      courierPerKmEarning: toDouble(
        raw['courier_per_km_earning'],
        d.courierPerKmEarning,
      ),
      courierMinutePrice: toDouble(
        raw['courier_minute_price'],
        d.courierMinutePrice,
      ),
      courierNightBonus: toDouble(
        raw['courier_night_bonus'],
        d.courierNightBonus,
      ),
      courierRainBonus: toDouble(raw['courier_rain_bonus'], d.courierRainBonus),
      courierSurgeBonus: toDouble(
        raw['courier_surge_bonus'],
        d.courierSurgeBonus,
      ),
      courierMultiOrderBonus: toDouble(
        raw['courier_multi_order_bonus'],
        d.courierMultiOrderBonus,
      ),
      etaPerKmMinute: toDouble(
        raw['eta_per_km_minute'],
        d.etaPerKmMinute,
      ),
      etaBaseMinute: toDouble(raw['eta_base_minute'], d.etaBaseMinute),
      weeklyPayoutDay:
          raw['weekly_payout_day']?.toString() ?? d.weeklyPayoutDay,
    );
  }
}
