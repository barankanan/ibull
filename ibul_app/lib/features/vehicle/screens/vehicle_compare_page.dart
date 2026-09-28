import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/ibul_page_state.dart';
import '../domain/vehicle_compare_fields.dart';
import '../domain/vehicle_compare_store.dart';
import '../models/vehicle_listing.dart';
import '../navigation/vehicle_routes.dart';
import '../widgets/vehicle_card.dart';

class VehicleComparePage extends StatelessWidget {
  const VehicleComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Araç Karşılaştırma'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        actions: [
          TextButton(
            onPressed: VehicleCompareStore.instance.clear,
            child: const Text('Temizle'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: VehicleCompareStore.instance,
        builder: (context, _) {
          final items = VehicleCompareStore.instance.items;
          if (items.length < VehicleCompareStore.minItems) {
            return IbulPageState.empty(
              icon: Icons.compare_arrows,
              title: 'Karşılaştırma için 2–4 araç seçin',
              message:
                  'Ana sayfadaki araç kartından karşılaştır ikonuna dokunun.',
            );
          }
          return _CompareTable(listings: items);
        },
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.listings});

  final List<VehicleListing> listings;

  @override
  Widget build(BuildContext context) {
    final rows = VehicleCompareFields.rowsFor(listings);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 132),
                  for (final listing in listings)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 180,
                        height: 280,
                        child: Column(
                          children: [
                            Text(
                              VehicleCompareFields.listingKind(listing),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: VehicleCard(
                                listing: listing,
                                width: 180,
                                storefront: true,
                                tight: true,
                                margin: EdgeInsets.zero,
                                showActions: false,
                                onTap: () => VehicleRoutes.openDetail(
                                  context,
                                  listing.id,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Table(
                defaultColumnWidth: const FixedColumnWidth(180),
                columnWidths: const {0: FixedColumnWidth(132)},
                border: TableBorder.all(color: AppColors.border),
                children: [
                  for (final row in rows)
                    TableRow(
                      children: [
                        _cell(row.label, header: true),
                        for (final listing in listings)
                          _cell(
                            row.value(listing).trim().isEmpty
                                ? '—'
                                : row.value(listing),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
