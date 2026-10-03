import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_floor.dart';
import '../models/mall_profile.dart';
import '../models/mall_store_link.dart';
import 'mall_panel_kit.dart';

/// Customer-facing summary built only from the saved profile, floors and
/// approved store links.
Future<void> showMallPreviewDialog(
  BuildContext context, {
  required MallProfile data,
  required List<MallFloor> floors,
  required List<MallStoreLink> links,
}) {
  final stores = links.where((link) => link.isApproved).toList();
  return showDialog<void>(
    context: context,
    builder: (context) => MallFormDialog(
      title: 'AVM Önizleme',
      width: 640,
      actions: [MallPrimaryButton(label: 'Kapat', onPressed: () => Navigator.pop(context))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.status != 'active')
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: MallBadge('Henüz yayında değil — müşteriler bu sayfayı görmez', tone: MallTone.warning),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1200 / 400,
              child: data.coverUrl == null
                  ? Container(color: MallTokens.soft, child: const Icon(Icons.image_outlined, color: AppColors.primary))
                  : Image.network(data.coverUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            mallLogo(data.logoUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(data.locationLabel, style: const TextStyle(color: MallTokens.muted)),
                ],
              ),
            ),
            if (data.isVerified) const MallBadge('Doğrulandı', tone: MallTone.success, icon: Icons.verified),
          ]),
          const SizedBox(height: 16),
          if (data.addressText.isNotEmpty) _line(Icons.place_outlined, data.addressText),
          if (data.openingHours != null) _line(Icons.schedule, data.openingHours!),
          if (data.phone != null) _line(Icons.phone_outlined, data.phone!),
          if (data.website != null) _line(Icons.language, data.website!),
          const SizedBox(height: 12),
          Text('${floors.length} kat • ${stores.length} mağaza', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (stores.isEmpty)
            const Text('Henüz onaylı mağaza yok.', style: TextStyle(color: MallTokens.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final store in stores.take(12))
                Chip(avatar: mallLogo(store.logoUrl, size: 22), label: Text('${store.storeName} • ${store.unitCode}')),
            ]),
        ],
      ),
    ),
  );
}

Widget _line(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: MallTokens.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ]),
  );
}
