import 'package:flutter/material.dart';

import '../management/models/mall_store_link.dart';
import '../management/services/mall_management_repository.dart';
import '../management/widgets/mall_management_dialogs.dart';
import '../management/widgets/mall_panel_kit.dart';
import 'seller_mall_apply_dialog.dart';
import 'seller_mall_code_card.dart';
import 'seller_mall_link_repository.dart';

/// Seller panel "AVM Talepleri": AVM invitations to answer, the store's own
/// applications and the resulting AVM links. The server decides who may answer.
class SellerMallRequestsView extends StatefulWidget {
  const SellerMallRequestsView({super.key, this.repository, this.pickFile});

  final SellerMallLinkRepository? repository;
  final SellerMallFilePicker? pickFile;

  @override
  State<SellerMallRequestsView> createState() => _SellerMallRequestsViewState();
}

class _SellerMallRequestsViewState extends State<SellerMallRequestsView> {
  late final SellerMallLinkRepository _repository = widget.repository ?? SellerMallLinkRepository();
  late Future<List<SellerMallRequest>> _requests = _repository.requests();
  final _busy = <String>{};
  String? _error;

  void _reload() {
    setState(() {
      _requests = _repository.requests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SellerMallRequest>>(
      future: _requests,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <SellerMallRequest>[];
        final invites = items.where((item) => item.awaitsMyAnswer).toList();
        final applications = items.where((item) => item.isPending && item.isOwnApplication).toList();
        final links = items.where((item) => !item.isPending).toList();
        return MallPage(children: [
          MallPageTitle(
            title: 'AVM Talepleri',
            subtitle: 'AVM davetleri, AVM\'lere yaptığınız başvurular ve aktif AVM bağlantılarınız.',
            actions: [
              IconButton(tooltip: 'Yenile', onPressed: _reload, icon: const Icon(Icons.refresh)),
              MallPrimaryButton(
                key: const ValueKey('seller-requests-apply'),
                label: 'AVM\'ye Başvur',
                icon: Icons.storefront_outlined,
                onPressed: () async {
                  final sent = await openSellerMallApplication(context,
                      repository: _repository, pickFile: widget.pickFile);
                  if (sent && mounted) _reload();
                },
              ),
            ],
          ),
          if (_error != null) MallInlineError(_error!, onClose: () => setState(() => _error = null)),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            MallLoadError(friendlyMallError(snapshot.error!), onRetry: _reload)
          else if (items.isEmpty)
            const MallEmptyState(
              icon: Icons.apartment_outlined,
              title: 'AVM bağlantısı yok',
              message: 'Fiziksel mağazanız bir AVM\'deyse "AVM\'ye Başvur" ile başvurun. '
                  'Bir AVM sizi davet ettiğinde de burada görünür.',
            )
          else ...[
            if (invites.isNotEmpty) ..._section('Yanıt bekleyen AVM davetleri', invites),
            if (applications.isNotEmpty) ..._section('Başvurularım', applications),
            if (links.isNotEmpty) ..._section('AVM Bağlantıları', links),
          ],
        ]);
      },
    );
  }

  List<Widget> _section(String title, List<SellerMallRequest> items) => [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        MallGrid(minTileWidth: 340, children: [for (final item in items) _card(item)]),
      ];

  Widget _card(SellerMallRequest item) {
    final busy = _busy.contains(item.id);
    return MallCard(
      key: ValueKey('seller-mall-request-${item.id}'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            mallLogo(item.logoUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.mallName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (item.locationLabel.isNotEmpty) Text(item.locationLabel, style: const TextStyle(color: MallTokens.muted)),
                const SizedBox(height: 6),
                MallBadge(
                  item.statusLabel,
                  key: ValueKey('seller-mall-status-${item.id}'),
                  dense: true,
                  tone: switch (item.status) {
                    'approved' => MallTone.success,
                    'rejected' => MallTone.danger,
                    _ => MallTone.warning,
                  },
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (item.awaitsMyAnswer) Text('${item.mallName} mağazanızı şu konuma eklemek istiyor:'),
          const SizedBox(height: 6),
          Text(
            [item.placeLabel, if (item.areaM2 != null) '${item.areaM2!.toStringAsFixed(0)} m²'].join(' • '),
            key: ValueKey('seller-mall-request-place-${item.id}'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (item.note != null) ...[
            const SizedBox(height: 6),
            Text('Not: ${item.note}', style: const TextStyle(color: MallTokens.muted)),
          ],
          if (item.reviewNote != null) ...[
            const SizedBox(height: 6),
            Text('AVM notu: ${item.reviewNote}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (item.isOwnApplication && item.documents.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Belgeler: ${item.documents.map((doc) => doc.label).toSet().join(', ')}',
                style: const TextStyle(color: MallTokens.muted, fontSize: 12)),
          ],
          if (item.isPending || item.status == 'approved') ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
              if (item.awaitsMyAnswer) ...[
                OutlinedButton(onPressed: busy ? null : () => _respond(item, false), child: const Text('Reddet')),
                MallPrimaryButton(label: 'Onayla', onPressed: busy ? null : () => _respond(item, true)),
              ] else if (item.isPending)
                TextButton(onPressed: busy ? null : () => _remove(item), child: const Text('Başvuruyu Geri Çek'))
              else
                TextButton(onPressed: busy ? null : () => _remove(item), child: const Text('Bağlantıyı Kaldır')),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _respond(SellerMallRequest item, bool approve) async {
    await _run(item.id, () => _repository.respond(item.id, approve: approve),
        approve ? 'Talep onaylandı. Mağazanız AVM\'de görünecek.' : 'Talep reddedildi.');
  }

  Future<void> _remove(SellerMallRequest item) async {
    final pending = item.isPending;
    final ok = await confirmMallAction(
      context,
      title: pending ? 'Başvuruyu geri çek' : 'Bağlantıyı kaldır',
      message: pending
          ? '${item.mallName} başvurunuz iptal edilecek.'
          : 'Mağazanız ${item.mallName} içindeki ${item.placeLabel} konumundan ayrılacak.',
      confirmLabel: pending ? 'Geri Çek' : 'Kaldır',
    );
    if (ok) await _run(item.id, () => _repository.remove(item.id), pending ? 'Başvuru geri çekildi.' : 'Bağlantı kaldırıldı.');
  }

  Future<void> _run(String id, Future<void> Function() action, String success) async {
    setState(() {
      _busy.add(id);
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      showMallSnack(context, success);
      _reload();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }
}
