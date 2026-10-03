import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_ops.dart';
import '../models/mall_profile.dart';
import '../models/mall_setup_summary.dart';
import '../services/mall_management_repository.dart';
import 'mall_panel_kit.dart';

class MallDashboardView extends StatefulWidget {
  const MallDashboardView({
    super.key,
    required this.mall,
    required this.summary,
    required this.activeCampaigns,
    required this.loadActivity,
    required this.onOpen,
    this.revision = 0,
    this.canPublish = false,
    this.onPublish,
    this.onCancelPublish,
  });

  final MallProfile mall;
  final MallSetupSummary summary;
  final int activeCampaigns;
  final Future<List<MallActivity>> Function() loadActivity;
  final ValueChanged<String> onOpen;

  /// Bumped by the shell after every reload; recent activity follows it.
  final int revision;
  final bool canPublish;
  final VoidCallback? onPublish;
  final VoidCallback? onCancelPublish;

  @override
  State<MallDashboardView> createState() => _MallDashboardViewState();
}

class _MallDashboardViewState extends State<MallDashboardView> {
  late Future<List<MallActivity>> _activity = widget.loadActivity();

  @override
  void didUpdateWidget(MallDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _activity = widget.loadActivity();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Checklist(summary: summary, onOpen: widget.onOpen),
        const SizedBox(height: 24),
        _publicationCard(summary),
      ],
    );
    final activity = _activityCard();
    return MallPage(children: [
      const MallPageTitle(title: 'Genel Bakış', subtitle: 'AVM\'nizin kurulum ve operasyon özeti.'),
      MallGrid(minTileWidth: 220, maxColumns: 3, children: [
        MallKpiCard(
            key: const ValueKey('mall-kpi-floors'),
            label: 'Kat',
            value: '${summary.floorCount}',
            icon: Icons.layers_outlined),
        MallKpiCard(label: 'Mağaza Alanı', value: '${summary.unitCount}', icon: Icons.grid_view_outlined),
        MallKpiCard(
            label: 'Aktif Mağaza', value: '${summary.activeStoreCount}', icon: Icons.storefront, tone: MallTone.success),
        MallKpiCard(
            label: 'Boş Alan', value: '${summary.vacantUnitCount}', icon: Icons.crop_square, tone: MallTone.neutral),
        MallKpiCard(
          label: 'Bekleyen Talep',
          value: '${summary.pendingRequestCount}',
          icon: Icons.hourglass_top,
          tone: MallTone.warning,
        ),
        MallKpiCard(label: 'Aktif Kampanya', value: '${widget.activeCampaigns}', icon: Icons.local_offer_outlined),
      ]),
      if (wide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 24),
            Expanded(child: activity),
          ],
        )
      else ...[
        left,
        activity,
      ],
    ]);
  }

  Widget _publicationCard(MallSetupSummary summary) {
    final rejected = summary.status == 'draft' && (summary.publication?.isRejected ?? false);
    final Widget? action;
    if (!widget.canPublish || summary.isActive) {
      action = null;
    } else if (summary.isPendingReview) {
      action = OutlinedButton(onPressed: widget.onCancelPublish, child: const Text('Talebi Geri Çek'));
    } else {
      action = MallPrimaryButton(
        key: const ValueKey('mall-publish-button'),
        label: 'Yayına Gönder',
        icon: Icons.rocket_launch_outlined,
        onPressed: summary.canRequestPublish ? widget.onPublish : null,
      );
    }
    return MallCard(
      key: const ValueKey('mall-publication-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MallCardTitle('Yayın ve Harita',
              trailing: MallBadge(summary.statusLabel,
                  tone: summary.isActive ? MallTone.success : MallTone.warning, dense: true)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(summary.isActive ? Icons.location_on : Icons.location_off_outlined,
                color: summary.isActive ? AppColors.primary : MallTokens.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(summary.mapVisibilityText(widget.mall.name),
                  key: const ValueKey('mall-map-visibility'), style: const TextStyle(height: 1.4)),
            ),
          ]),
          if (rejected) ...[
            const SizedBox(height: 12),
            MallInlineError('Son yayın talebi reddedildi: ${summary.publication!.adminNote ?? '-'}'),
          ],
          if (!summary.fromServer) ...[
            const SizedBox(height: 12),
            const Text(
              'Yayın durumu şu an doğrulanamıyor. Yayına gönderme geçici olarak kapalı.',
              key: ValueKey('mall-publication-unavailable'),
              style: TextStyle(color: MallTokens.muted),
            ),
          ],
          if (!summary.isActive && summary.missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Yayına göndermek için: ${summary.missing.map(MallSetupSummary.missingLabel).join(', ')}.',
              style: const TextStyle(color: MallTokens.muted),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }

  Widget _activityCard() {
    return MallCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MallCardTitle(
            'Son İşlemler',
            trailing: IconButton(
              tooltip: 'Yenile',
              onPressed: () => setState(() {
                _activity = widget.loadActivity();
              }),
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ),
          FutureBuilder<List<MallActivity>>(
            future: _activity,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) return MallInlineError(friendlyMallError(snapshot.error!));
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Henüz işlem yok. Kat veya mağaza eklediğinizde burada görünür.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MallTokens.muted),
                  ),
                );
              }
              return Column(children: [for (final item in items) _activityRow(item)]);
            },
          ),
        ],
      ),
    );
  }

  Widget _activityRow(MallActivity item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.text)),
          Text(_ago(item.at), style: const TextStyle(color: MallTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }

  String _ago(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays < 1) return '${diff.inHours} sa önce';
    if (diff.inDays < 30) return '${diff.inDays} gün önce';
    return '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}.${at.year}';
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.summary, required this.onOpen});

  final MallSetupSummary summary;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <(String, bool, String)>[
      ('AVM bilgileri', summary.profileReady, 'bilgiler'),
      ('Logo ve kapak', summary.mediaReady, 'bilgiler'),
      ('Çalışma saatleri', summary.hoursReady, 'bilgiler'),
      ('Harita konumu', summary.locationReady, 'bilgiler'),
      ('En az 1 kat', summary.hasFloor, 'katlar'),
      ('En az 1 mağaza', summary.hasActiveStore, 'magazalar'),
      ('İç mekan planı (isteğe bağlı)', summary.hasFloorPlan, 'harita'),
    ];
    final done = items.where((item) => item.$2).length;
    return MallCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MallCardTitle('Kurulum Durumu', trailing: Text('$done / ${items.length}')),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: done / items.length,
              minHeight: 8,
              backgroundColor: MallTokens.soft,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            ListTile(
              key: ValueKey('mall-check-${item.$1}-${item.$2 ? 'done' : 'todo'}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item.$2 ? const Color(0xFF15803D) : MallTokens.muted,
              ),
              title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: item.$2 ? null : TextButton(onPressed: () => onOpen(item.$3), child: const Text('Tamamla')),
            ),
        ],
      ),
    );
  }
}
