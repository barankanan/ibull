import 'package:flutter/material.dart';

import '../../data/coupon_repository.dart';
import '../../domain/coupon_campaign.dart';
import '../../domain/coupon_enums.dart';
import '../../domain/coupon_models.dart';
import '../../domain/reward_wheel_probability.dart';
import '../../widgets/reward_wheel_add_reward_sheet.dart';
import '../../widgets/reward_wheel_admin_sections.dart';
import '../../widgets/reward_wheel_admin_widgets.dart';
import '../../widgets/reward_wheel_preview.dart';
import 'coupon_admin_editor_page.dart';

class RewardWheelSettingsPage extends StatefulWidget {
  const RewardWheelSettingsPage({super.key});

  @override
  State<RewardWheelSettingsPage> createState() =>
      _RewardWheelSettingsPageState();
}

class _RewardWheelSettingsPageState extends State<RewardWheelSettingsPage> {
  final _repo = CouponRepository();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _configId;
  bool _active = false;
  bool _useGlobalPool = true;
  int _dailySpins = 1;
  int _perUserDailyLimit = 1;
  int _cooldownHours = 24;
  List<CouponCampaign> _coupons = const [];
  List<CouponCampaign> _pendingOffers = const [];
  List<WheelDraftItem> _items = [];
  List<WheelDraftItem> _savedItems = [];
  RewardWheelAdminStats _stats = const RewardWheelAdminStats();
  bool _savedActive = false;
  bool _savedUseGlobalPool = true;
  int _savedDailySpins = 1;
  int _savedPerUserDailyLimit = 1;
  int _savedCooldownHours = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _repo.loadWheelConfig();
      final coupons = await _repo.listForAdmin();
      final pending = coupons
          .where(
            (item) =>
                item.wheelRequested &&
                item.approvalStatus == CouponApprovalStatus.pendingReview,
          )
          .toList();
      RewardWheelAdminStats stats = RewardWheelAdminStats(
        activeRewards: config?.items.where((item) => item.isActive).length ?? 1,
        pendingSellerOffers: pending.length,
      );
      try {
        stats = await _repo.loadWheelAdminStats();
      } catch (error, stack) {
        debugPrint('RewardWheelSettingsPage stats: $error\n$stack');
      }
      if (!mounted) return;
      final items = (config?.items.isNotEmpty == true)
          ? config!.items
                .map(
                  (item) => WheelDraftItem(
                    campaignId: item.campaignId,
                    label: item.label,
                    isNoPrize: item.isNoPrize,
                    isActive: item.isActive,
                    percent: RewardWheelProbability.bpsToPercent(
                      item.probabilityBps,
                    ),
                    campaign: coupons
                        .where((coupon) => coupon.id == item.campaignId)
                        .firstOrNull,
                  ),
                )
                .toList()
          : [WheelDraftItem(label: 'Şansını tekrar dene', isNoPrize: true, percent: 40)];
      setState(() {
        _coupons = coupons;
        _pendingOffers = pending;
        _configId = config?.id;
        _active = config?.isActive ?? false;
        _useGlobalPool = config?.useGlobalPool ?? true;
        _dailySpins = config?.dailyFreeSpins ?? 1;
        _perUserDailyLimit = config?.perUserDailyLimit ?? 1;
        _cooldownHours = (config?.cooldownHours ?? 24).round();
        _items = items;
        _stats = stats;
        _captureSaved();
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('RewardWheelSettingsPage.load failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _captureSaved() {
    _savedActive = _active;
    _savedUseGlobalPool = _useGlobalPool;
    _savedDailySpins = _dailySpins;
    _savedPerUserDailyLimit = _perUserDailyLimit;
    _savedCooldownHours = _cooldownHours;
    _savedItems = [for (final item in _items) item.copy()];
  }

  bool get _dirty {
    if (_active != _savedActive ||
        _useGlobalPool != _savedUseGlobalPool ||
        _dailySpins != _savedDailySpins ||
        _perUserDailyLimit != _savedPerUserDailyLimit ||
        _cooldownHours != _savedCooldownHours ||
        _items.length != _savedItems.length) {
      return true;
    }
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].sameAs(_savedItems[i])) return true;
    }
    return false;
  }

  List<WheelDraftItem> get _activeItems =>
      _items.where((item) => item.isActive).toList();

  int get _totalPercent => RewardWheelProbability.totalPercent(
    _activeItems.map((item) => item.percent),
  );

  bool get _canSave =>
      _activeItems.isNotEmpty && RewardWheelProbability.isComplete(
        _activeItems.map((item) => item.percent),
      );

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await _repo.saveWheelConfig(
        RewardWheelConfig(
          id: _configId,
          isActive: _active,
          dailyFreeSpins: _dailySpins,
          perUserDailyLimit: _perUserDailyLimit,
          useGlobalPool: _useGlobalPool,
          cooldownHours: _cooldownHours.toDouble(),
          items: [
            for (var i = 0; i < _items.length; i++)
              RewardWheelItem(
                campaignId: _items[i].campaignId,
                label: _items[i].label,
                isNoPrize: _items[i].isNoPrize,
                isActive: _items[i].isActive,
                probabilityBps: RewardWheelProbability.percentToBps(
                  _items[i].percent,
                ),
                sortOrder: i,
              ),
          ],
        ),
      );
      if (!mounted) return;
      _captureSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hediye çarkı başarıyla güncellendi.')),
      );
      await _load();
    } catch (error, stack) {
      debugPrint('RewardWheelSettingsPage.save failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _active = _savedActive;
      _useGlobalPool = _savedUseGlobalPool;
      _dailySpins = _savedDailySpins;
      _perUserDailyLimit = _savedPerUserDailyLimit;
      _cooldownHours = _savedCooldownHours;
      _items = [for (final item in _savedItems) item.copy()];
    });
  }

  void _equalDistribute() {
    final targets = _activeItems;
    final values = RewardWheelProbability.equalDistribute(targets.length);
    setState(() {
      for (var i = 0; i < targets.length; i++) {
        targets[i].percent = values[i];
      }
    });
  }

  void _distributeRemainder() {
    final couponIndexes = [
      for (var i = 0; i < _items.length; i++)
        if (_items[i].isActive && !_items[i].isNoPrize) i,
    ];
    final allActive = [
      for (var i = 0; i < _items.length; i++)
        if (_items[i].isActive) i,
    ];
    final current = [for (final item in _items) item.percent];
    final next = RewardWheelProbability.distributeRemainder(
      current,
      targetIndexes: couponIndexes.isEmpty ? allActive : couponIndexes,
    );
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i].percent = next[i];
      }
    });
  }

  Future<void> _addReward() async {
    final selected = await showModalBottomSheet<CouponCampaign>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => RewardWheelAddRewardSheet(
        coupons: _coupons,
        selectedIds: {
          for (final item in _items)
            if (item.campaignId != null) item.campaignId!,
        },
      ),
    );
    if (selected == null) return;
    setState(() {
      _items.add(
        WheelDraftItem(
          campaignId: selected.id,
          label: selected.name,
          percent: 0,
          campaign: selected,
        ),
      );
    });
  }

  Future<void> _moderateOffer(CouponCampaign offer, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Teklifi reddet'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Red sebebi'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Reddet'),
              ),
            ],
          );
        },
      );
      if (reason == null || reason.isEmpty) return;
    }
    try {
      await _repo.moderate(campaignId: offer.id, action: action, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Teklif onaylandı. Ödül havuzuna eklenebilir.'
                : 'Teklif reddedildi.',
          ),
        ),
      );
      await _load();
    } catch (error, stack) {
      debugPrint('RewardWheelSettingsPage.moderate failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openEditor(CouponCampaign campaign) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CouponAdminEditorPage(existing: campaign)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }

    final previewItems = [
      for (var i = 0; i < _items.length; i++)
        if (_items[i].isActive)
          RewardWheelItem(
            label: _items[i].label,
            isNoPrize: _items[i].isNoPrize,
            probabilityBps: RewardWheelProbability.percentToBps(_items[i].percent),
            sortOrder: i,
          ),
    ];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kaydedilmemiş değişiklikler'),
            content: const Text('Sayfadan çıkarsanız değişiklikler kaybolur.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Kal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Çık'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                RewardWheelAdminHeader(
                  active: _active,
                  onActiveChanged: (value) => setState(() => _active = value),
                ),
                const SizedBox(height: 14),
                RewardWheelStatCards(stats: _stats),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final preview = RewardWheelSettingsCard(
                      title: 'Canlı Hediye Çarkı önizlemesi',
                      child: Center(child: RewardWheelPreview(items: previewItems)),
                    );
                    final settings = RewardWheelSettingsCard(
                      title: 'Genel ayarlar',
                      child: RewardWheelGeneralSettings(
                        active: _active,
                        useGlobalPool: _useGlobalPool,
                        dailySpins: _dailySpins,
                        cooldownHours: _cooldownHours,
                        perUserDailyLimit: _perUserDailyLimit,
                        onActiveChanged: (value) =>
                            setState(() => _active = value),
                        onGlobalPoolChanged: (value) =>
                            setState(() => _useGlobalPool = value),
                        onDailySpinsChanged: (value) => _dailySpins = value,
                        onCooldownChanged: (value) => _cooldownHours = value,
                        onPerUserLimitChanged: (value) =>
                            _perUserDailyLimit = value,
                      ),
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          preview,
                          const SizedBox(height: 12),
                          settings,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: preview),
                        const SizedBox(width: 12),
                        Expanded(child: settings),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                RewardWheelSettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RewardWheelProbabilityBar(totalPercent: _totalPercent),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _equalDistribute,
                            child: const Text('Eşit dağıt'),
                          ),
                          FilledButton.tonal(
                            onPressed: _totalPercent >= 100
                                ? null
                                : _distributeRemainder,
                            child: const Text('Kalan oranı dağıt'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_pendingOffers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  RewardWheelPendingOffers(
                    offers: _pendingOffers,
                    onApprove: (offer) => _moderateOffer(offer, 'approve'),
                    onEdit: _openEditor,
                    onReject: (offer) => _moderateOffer(offer, 'reject'),
                  ),
                ],
                const SizedBox(height: 14),
                RewardWheelRewardsTable(
                  items: _items,
                  onAdd: _addReward,
                  onPercentChanged: (index, percent) =>
                      setState(() => _items[index].percent = percent),
                  onActiveChanged: (index, active) =>
                      setState(() => _items[index].isActive = active),
                  onDetail: (index) {
                    final campaign = _items[index].campaign;
                    if (campaign != null) _openEditor(campaign);
                  },
                  onRemove: (index) => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
          ),
          RewardWheelStickyBar(
            canSave: _canSave,
            saving: _saving,
            onReset: _reset,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}
