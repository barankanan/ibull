import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../../seller/panel/widgets/store_location_change_dialog.dart';
import '../management/services/mall_management_repository.dart';
import '../management/widgets/mall_management_dialogs.dart';
import 'seller_mall_apply_dialog.dart';
import 'seller_mall_code_card.dart';
import 'seller_mall_link_repository.dart';

/// Mağaza Profili konum kartı: standalone / AVM / konum onayı bekleniyor.
class SellerStoreLocationCard extends StatefulWidget {
  const SellerStoreLocationCard({super.key, this.repository, this.pickFile, this.gap = 0});

  final SellerMallLinkRepository? repository;
  final SellerMallFilePicker? pickFile;
  final double gap;

  @override
  State<SellerStoreLocationCard> createState() => _SellerStoreLocationCardState();
}

class _SellerStoreLocationCardState extends State<SellerStoreLocationCard> {
  late final _repository = widget.repository ?? SellerMallLinkRepository();
  late Future<Map<String, dynamic>?> _row = _repository.myLocation();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _row,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(padding: EdgeInsets.only(bottom: widget.gap), child: const SizedBox(height: 8));
        }
        if (data == null) return SizedBox(height: widget.gap == 0 ? 0 : widget.gap);
        final type = data['location_type']?.toString() ?? 'standalone';
        final link = data['link'] is Map ? Map<String, dynamic>.from(data['link'] as Map) : null;
        final pending = data['pending_change'] is Map ? Map<String, dynamic>.from(data['pending_change'] as Map) : null;
        return Padding(
          padding: EdgeInsets.only(bottom: widget.gap),
          child: Container(
            key: const ValueKey('seller-location-card'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E6EF)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('KONUM TİPİ', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              Text(_title(type, link), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_subtitle(type, data, link), style: const TextStyle(color: Color(0xFF6B7280))),
              if (type == 'pending_location_change') ...[
                const SizedBox(height: 10),
                const Text(
                  'Bu mağazanın AVM bağlantısı sona erdi. Mağazayı İBUL\'da yayınlamaya devam etmek için yeni konum bilgisi girin.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (pending != null) ...[
                const SizedBox(height: 8),
                Text('Yeni konum onayı bekleniyor: ${[pending['city'], pending['district']].whereType<Object>().join(' / ')}'),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (link != null && (link['mall_id']?.toString().isNotEmpty ?? false))
                  OutlinedButton(
                    key: const ValueKey('seller-location-mall-detail'),
                    onPressed: () => IbulRouter.push(context, MarketplacePaths.mallProfile(link['mall_id'].toString())),
                    child: const Text('AVM Detayı'),
                  ),
                if (type == 'mall' && link?['status'] == 'approved')
                  TextButton(
                    key: const ValueKey('seller-location-leave'),
                    onPressed: () => _leave(link!['id'].toString(), link['mall_name']?.toString() ?? 'AVM'),
                    child: const Text('AVM\'den Ayrılma Talebi'),
                  ),
                if (type != 'mall')
                  FilledButton(
                    key: const ValueKey('seller-location-change'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _changeStandalone,
                    child: Text(type == 'pending_location_change' ? 'Yeni Konum Gir' : 'Konumu Değiştir'),
                  ),
                if (type == 'pending_location_change')
                  OutlinedButton(
                    onPressed: () => openSellerMallApplication(context, repository: _repository, pickFile: widget.pickFile)
                        .then((sent) { if (sent && mounted) setState(() => _row = _repository.myLocation()); }),
                    child: const Text('Başka AVM'),
                  ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  String _title(String type, Map<String, dynamic>? link) {
    if (type == 'mall' || link?['status'] == 'pending') return 'AVM içerisinde';
    if (type == 'pending_location_change') return 'Konum onayı bekleniyor';
    return 'Bağımsız Mağaza';
  }

  String _subtitle(String type, Map<String, dynamic> data, Map<String, dynamic>? link) {
    if (link != null) {
      final place = [link['mall_name'], link['floor_name'], link['unit_code']].whereType<Object>().join(' • ');
      final status = link['status'] == 'pending' ? 'AVM onayı bekleniyor' : place;
      return status;
    }
    return [data['city'], data['district'], data['address']].whereType<Object>().where((part) => '$part'.isNotEmpty).join(' / ');
  }

  Future<void> _leave(String linkId, String mallName) async {
    final ok = await confirmMallAction(
      context,
      title: 'AVM\'den ayrıl',
      message: '$mallName bağlantısı sona erecek. Yeni konum onayı yapılana kadar mağazanız haritada görünmeyecek.',
      confirmLabel: 'Ayrıl',
    );
    if (!ok) return;
    try {
      await _repository.remove(linkId);
      if (mounted) setState(() => _row = _repository.myLocation());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMallError(error))));
      }
    }
  }

  Future<void> _changeStandalone() async {
    final point = await showDialog<Map<String, double>>(
      context: context,
      builder: (_) => const StoreLocationChangeDialog(),
    );
    if (point == null || !mounted) return;
    final data = await _repository.myLocation();
    try {
      await _repository.submitStandaloneLocation(
        city: data?['city']?.toString() ?? '',
        district: data?['district']?.toString() ?? '',
        address: data?['address']?.toString() ?? 'Yeni konum',
        latitude: point['lat']!,
        longitude: point['lng']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni konum admin onayına gönderildi.')),
      );
      setState(() => _row = _repository.myLocation());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMallError(error))));
      }
    }
  }
}
