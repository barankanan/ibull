import 'package:flutter/material.dart';

import '../models/mall_ops.dart';
import '../models/mall_store_link.dart';
import '../services/mall_management_repository.dart';
import '../services/mall_operations_repository.dart';
import 'mall_campaign_dialog.dart';
import 'mall_management_dialogs.dart';
import 'mall_panel_kit.dart';

class MallCampaignsView extends StatefulWidget {
  const MallCampaignsView({
    super.key,
    required this.mallId,
    required this.campaigns,
    required this.links,
    required this.canManage,
    required this.operations,
    required this.repository,
    required this.onChanged,
  });

  final String mallId;
  final List<MallCampaign> campaigns;
  final List<MallStoreLink> links;
  final bool canManage;
  final MallOperationsRepository operations;
  final MallManagementRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<MallCampaignsView> createState() => _MallCampaignsViewState();
}

class _MallCampaignsViewState extends State<MallCampaignsView> {
  var _filter = 'all';
  String? _error;

  static MallTone _tone(String display) => switch (display) {
        'active' => MallTone.success,
        'scheduled' => MallTone.primary,
        'ended' => MallTone.neutral,
        _ => MallTone.warning,
      };

  @override
  Widget build(BuildContext context) {
    final items = widget.campaigns
        .where((campaign) => _filter == 'all' || campaign.displayStatus() == _filter)
        .toList();
    int count(String status) => widget.campaigns.where((item) => item.displayStatus() == status).length;
    return MallPage(children: [
      MallPageTitle(
        title: 'Kampanyalar',
        subtitle: 'AVM geneli veya seçili mağazalar için kampanya duyurun.',
        actions: [
          if (widget.canManage)
            MallPrimaryButton(label: 'Kampanya Oluştur', icon: Icons.add, onPressed: () => _edit()),
        ],
      ),
      if (_error != null) MallInlineError(_error!, onClose: () => setState(() => _error = null)),
      MallSegmented(
        items: {
          'all': 'Tümü (${widget.campaigns.length})',
          'draft': 'Taslak (${count('draft')})',
          'scheduled': 'Planlandı (${count('scheduled')})',
          'active': 'Aktif (${count('active')})',
          'ended': 'Bitti (${count('ended')})',
        },
        selected: _filter,
        onChanged: (value) => setState(() => _filter = value),
      ),
      if (items.isEmpty)
        MallEmptyState(
          icon: Icons.local_offer_outlined,
          title: widget.campaigns.isEmpty ? 'Henüz kampanya yok' : 'Bu durumda kampanya yok',
          message: 'Kampanyalar yayınlandığında AVM sayfanızda müşterilere gösterilir.',
          actionLabel: widget.canManage && widget.campaigns.isEmpty ? 'Kampanya Oluştur' : null,
          onAction: widget.canManage ? () => _edit() : null,
        )
      else
        MallGrid(minTileWidth: 320, children: [for (final item in items) _card(item)]),
    ]);
  }

  Widget _card(MallCampaign campaign) {
    final display = campaign.displayStatus();
    return MallCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(MallTokens.radius)),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: campaign.imageUrl == null
                  ? Container(color: MallTokens.soft, child: const Icon(Icons.local_offer_outlined, size: 36))
                  : Image.network(campaign.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(campaign.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  MallBadge(MallCampaign.statusLabel(display), tone: _tone(display)),
                ]),
                if (campaign.description != null) ...[
                  const SizedBox(height: 6),
                  Text(campaign.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Text(
                  '${mallDateLabel(campaign.startsAt)} – ${mallDateLabel(campaign.endsAt)} • ${campaign.targetLabel}',
                  style: const TextStyle(color: MallTokens.muted, fontSize: 13),
                ),
                if (widget.canManage)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(children: [
                      TextButton(onPressed: () => _edit(campaign), child: const Text('Düzenle')),
                      TextButton(onPressed: () => _delete(campaign), child: const Text('Sil')),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit([MallCampaign? existing]) async {
    final draft = await showMallCampaignDialog(
      context,
      mallId: widget.mallId,
      stores: widget.links.where((link) => link.isApproved).toList(),
      repository: widget.repository,
      existing: existing,
    );
    if (draft == null) return;
    await _run(() => widget.operations.saveCampaign(widget.mallId, draft),
        success: draft.publish ? 'Kampanya yayınlandı.' : 'Taslak kaydedildi.');
  }

  Future<void> _delete(MallCampaign campaign) async {
    final ok = await confirmMallAction(
      context,
      title: 'Kampanyayı sil',
      message: '"${campaign.title}" silinecek.',
      confirmLabel: 'Sil',
    );
    if (ok) await _run(() => widget.operations.deleteCampaign(widget.mallId, campaign.id), success: 'Kampanya silindi.');
  }

  Future<void> _run(Future<void> Function() action, {required String success}) async {
    try {
      await action();
      await widget.onChanged();
      if (mounted) showMallSnack(context, success);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    }
  }
}
