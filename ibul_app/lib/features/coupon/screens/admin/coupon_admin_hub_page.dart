import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_campaign.dart';
import '../../domain/coupon_enums.dart';
import '../../domain/coupon_models.dart';
import '../../domain/coupon_status_labels.dart';
import '../../widgets/coupon_status_chip.dart';
import '../../widgets/coupon_summary_cards.dart';
import 'coupon_admin_editor_page.dart';

class CouponAdminHubPage extends StatefulWidget {
  const CouponAdminHubPage({super.key});

  @override
  State<CouponAdminHubPage> createState() => _CouponAdminHubPageState();
}

class _CouponAdminHubPageState extends State<CouponAdminHubPage> {
  final _repo = CouponRepository();
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<CouponCampaign> _all = const [];
  CouponAdminSummary _summary = const CouponAdminSummary();
  CouponEffectiveStatus? _status;
  CouponSourceType? _source;
  CouponDiscountType? _discount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.listForAdmin(
        search: _search.text,
        status: _status,
        source: _source,
        discountType: _discount,
      );
      final summary = await _repo.adminSummary(
        await _repo.listForAdmin(),
      );
      if (!mounted) return;
      setState(() {
        _all = rows;
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([CouponCampaign? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CouponAdminEditorPage(existing: existing),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _moderate(CouponCampaign campaign, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Kuponu reddet'),
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
      await _repo.moderate(
        campaignId: campaign.id,
        action: action,
        reason: reason,
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _all.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      );
    }
    if (_error != null && _all.isEmpty) {
      return _state(
        'Kuponlar yüklenemedi',
        _error!,
        actionLabel: 'Tekrar dene',
        onAction: _load,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Kuponlar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1035),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('+ Yeni Kupon'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CouponSummaryCards(summary: _summary),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _dropdown<CouponEffectiveStatus?>(
                label: 'Durum',
                value: _status,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tümü')),
                  for (final status in CouponEffectiveStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(CouponStatusLabels.effective(status)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _status = value);
                  _load();
                },
              ),
              _dropdown<CouponSourceType?>(
                label: 'Kaynak',
                value: _source,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tümü')),
                  for (final source in CouponSourceType.values)
                    DropdownMenuItem(
                      value: source,
                      child: Text(CouponStatusLabels.source(source)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _source = value);
                  _load();
                },
              ),
              _dropdown<CouponDiscountType?>(
                label: 'Kupon türü',
                value: _discount,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tümü')),
                  for (final type in CouponDiscountType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(CouponStatusLabels.discount(type)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _discount = value);
                  _load();
                },
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Kod, kampanya veya mağaza',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _all.isEmpty
              ? _state(
                  _status == CouponEffectiveStatus.pendingReview
                      ? 'İncelenmeyi bekleyen kupon yok.'
                      : 'Henüz aktif kupon bulunmuyor.',
                  'Filtreleri değiştirerek tekrar deneyebilirsiniz.',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 48,
                    ),
                    child: DataTable(
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      columns: const [
                        DataColumn(label: Text('Kupon adı')),
                        DataColumn(label: Text('Kod')),
                        DataColumn(label: Text('Kaynak')),
                        DataColumn(label: Text('Mağaza')),
                        DataColumn(label: Text('İndirim')),
                        DataColumn(label: Text('Min. sepet')),
                        DataColumn(label: Text('Kota')),
                        DataColumn(label: Text('Kullanılan')),
                        DataColumn(label: Text('Başlangıç')),
                        DataColumn(label: Text('Bitiş')),
                        DataColumn(label: Text('Durum')),
                        DataColumn(label: Text('Çark')),
                        DataColumn(label: Text('İşlemler')),
                      ],
                      rows: [
                        for (final campaign in _all)
                          DataRow(
                            cells: [
                              DataCell(Text(campaign.name)),
                              DataCell(Text(campaign.code)),
                              DataCell(
                                Text(CouponStatusLabels.source(campaign.sourceType)),
                              ),
                              DataCell(Text(campaign.storeName ?? '-')),
                              DataCell(Text(campaign.discountLabel)),
                              DataCell(
                                Text(
                                  campaign.minOrderAmount > 0
                                      ? '${campaign.minOrderAmount.toStringAsFixed(0)} TL'
                                      : '-',
                                ),
                              ),
                              DataCell(Text('${campaign.totalUsageLimit ?? '-'}')),
                              DataCell(Text('${campaign.usedCount}')),
                              DataCell(Text(_fmt(campaign.startsAt))),
                              DataCell(Text(_fmt(campaign.endsAt))),
                              DataCell(
                                CouponStatusChip(status: campaign.effectiveStatus),
                              ),
                              DataCell(Text(campaign.wheelEnabled ? 'Evet' : 'Hayır')),
                              DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _openEditor(campaign);
                                      case 'approve':
                                        _moderate(campaign, 'approve');
                                      case 'reject':
                                        _moderate(campaign, 'reject');
                                      case 'detail':
                                        _showDetail(campaign);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'detail',
                                      child: Text('Detayı Aç'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Düzenle'),
                                    ),
                                    if (campaign.approvalStatus ==
                                        CouponApprovalStatus.pendingReview) ...[
                                      const PopupMenuItem(
                                        value: 'approve',
                                        child: Text('Onayla'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'reject',
                                        child: Text('Reddet'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showDetail(CouponCampaign campaign) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(campaign.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mağaza: ${campaign.storeName ?? '-'}'),
              Text('Kaynak: ${CouponStatusLabels.source(campaign.sourceType)}'),
              Text('Tür: ${campaign.discountLabel}'),
              Text('Minimum sepet: ${campaign.minOrderAmount.toStringAsFixed(0)} TL'),
              Text('Kota: ${campaign.totalUsageLimit ?? '-'} / ${campaign.usedCount}'),
              Text('Kapsam: ${CouponStatusLabels.scope(campaign.scopeType)}'),
              Text('${_fmt(campaign.startsAt)} → ${_fmt(campaign.endsAt)}'),
              if ((campaign.rejectionReason ?? '').isNotEmpty)
                Text('Red sebebi: ${campaign.rejectionReason}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          if (campaign.approvalStatus == CouponApprovalStatus.pendingReview)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _moderate(campaign, 'approve');
              },
              child: const Text('Onayla'),
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _state(
    String title,
    String subtitle, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
