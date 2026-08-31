import 'package:flutter/material.dart';

import '../delivery/ihiz_delivery_status.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizBusinessOpsPanel extends StatelessWidget {
  const IhizBusinessOpsPanel({
    super.key,
    required this.store,
    required this.stores,
    required this.selectedStoreId,
    required this.onOpenCouriers,
    required this.onRefresh,
    this.onSelectStore,
  });

  final Map<String, dynamic> store;
  final List<Map<String, dynamic>> stores;
  final String? selectedStoreId;
  final ValueChanged<String>? onSelectStore;
  final VoidCallback onOpenCouriers;
  final VoidCallback onRefresh;

  List<Map<String, dynamic>> _rows(String key) {
    final raw = store[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatChip(label: 'Gelen', value: store['incoming_count']),
            _StatChip(label: 'Çıkan', value: store['outgoing_count']),
            _StatChip(label: 'Gönderilen', value: store['sent_count']),
            _StatChip(label: 'Aktif', value: store['active_count']),
            _StatChip(label: 'Kurye', value: store['courier_count']),
          ],
        ),
        const SizedBox(height: 12),
        if (onSelectStore != null && stores.length > 1)
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: selectedStoreId,
            items: [
              for (final row in stores)
                DropdownMenuItem(
                  value: row['store_id']?.toString(),
                  child: Text((row['business_name'] ?? 'Mağaza').toString()),
                ),
            ],
            onChanged: (value) {
              if (value != null) onSelectStore!(value);
            },
            decoration: const InputDecoration(
              labelText: 'İşletme',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          [
            store['business_name'] ?? 'İşletme',
            if ((store['serial'] ?? '').toString().isNotEmpty) store['serial'],
            if ((store['status'] ?? '').toString().isNotEmpty)
              'Durum: ${store['status']}',
          ].join(' · '),
          style: const TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IhizSecondaryButton(
              label: 'Kurye yönetimi',
              icon: Icons.groups_rounded,
              onPressed: onOpenCouriers,
            ),
            const SizedBox(width: 10),
            IhizSecondaryButton(
              label: 'Yenile',
              icon: Icons.refresh_rounded,
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TaskSection(title: 'Gelen paketler', rows: _rows('incoming')),
        _TaskSection(title: 'Çıkan paketler', rows: _rows('outgoing')),
        _TaskSection(title: 'Gönderilen paketler', rows: _rows('sent')),
        _TaskSection(title: 'Aktif teslimatlar', rows: _rows('active')),
        _CourierSection(rows: _rows('couriers')),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: IhizBrand.navy,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: IhizBrand.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: IhizBrand.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Text(
                  'Kayıt yok.',
                  style: TextStyle(
                    color: IhizBrand.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (row['tracking_code'] ?? '-').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: IhizBrand.navy,
                          ),
                        ),
                        Text(
                          '${IhizDeliveryStatus.label(row['status']?.toString())}'
                          ' · ${(row['pickup_name'] ?? '-')} → ${(row['dropoff_name'] ?? '-')}',
                          style: const TextStyle(
                            color: IhizBrand.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourierSection extends StatelessWidget {
  const _CourierSection({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kurye işlemleri',
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text(
                'Seçili kurye yok.',
                style: TextStyle(
                  color: IhizBrand.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    [
                      row['full_name'] ?? 'Kurye',
                      if ((row['city'] ?? '').toString().isNotEmpty) row['city'],
                      if (row['is_active'] == true) 'aktif',
                    ].join(' · '),
                    style: const TextStyle(
                      color: IhizBrand.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
