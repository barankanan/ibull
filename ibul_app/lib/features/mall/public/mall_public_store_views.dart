import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'mall_public_chrome.dart';
import 'mall_public_format.dart';
import 'mall_public_repository.dart';

class MallPublicFloorChips extends StatelessWidget {
  const MallPublicFloorChips({
    super.key,
    required this.floors,
    required this.selectedId,
    required this.storeCount,
    required this.onSelect,
    this.showAll = false,
  });

  final List<MallPublicFloor> floors;
  final String? selectedId;
  final int Function(String floorId) storeCount;
  final ValueChanged<String> onSelect;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (showAll) ...[
            _SelectChip(
              key: const ValueKey('mall-public-floor-all'),
              label: 'Tümü',
              selected: selectedId == null,
              onTap: () => onSelect(''),
            ),
            const SizedBox(width: 8),
          ],
          for (final floor in floors) ...[
            _SelectChip(
              key: ValueKey('mall-public-floor-${floor.id}'),
              label: mallFloorChipLabel(floor),
              count: storeCount(floor.id),
              selected: floor.id == selectedId,
              onTap: () => onSelect(floor.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class MallPublicFloorDirectory extends StatelessWidget {
  const MallPublicFloorDirectory({
    super.key,
    required this.floors,
    required this.storeCount,
    required this.onOpen,
  });

  final List<MallPublicFloor> floors;
  final int Function(String floorId) storeCount;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (floors.isEmpty) {
      return const Text('Kat bilgisi yakında eklenecek.', style: TextStyle(color: mallPublicMuted, fontWeight: FontWeight.w600));
    }
    return Column(children: [
      for (var i = 0; i < floors.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _FloorRow(floor: floors[i], count: storeCount(floors[i].id), onTap: () => onOpen(floors[i].id)),
      ],
    ]);
  }
}

class _FloorRow extends StatelessWidget {
  const _FloorRow({required this.floor, required this.count, required this.onTap});

  final MallPublicFloor floor;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stores = count == 0 ? 'Mağaza yok' : '$count mağaza';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('mall-public-floor-row-${floor.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: mallPublicLine),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  mallFloorPresentationLabel(floor),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: mallPublicNavy),
                ),
                const SizedBox(height: 2),
                Text(stores, style: const TextStyle(fontSize: 12.5, color: mallPublicMuted, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
          ]),
        ),
      ),
    );
  }
}

class MallPublicStoreList extends StatelessWidget {
  const MallPublicStoreList({
    super.key,
    required this.stores,
    required this.onOpen,
    required this.emptyText,
    this.highlightedStoreId,
    this.floorLabel,
  });

  final List<MallPublicStore> stores;
  final ValueChanged<MallPublicStore> onOpen;
  final String emptyText;
  final String? highlightedStoreId;
  final String? Function(MallPublicStore store)? floorLabel;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: mallPublicMuted, fontWeight: FontWeight.w600));
    }
    return Column(children: [
      for (var i = 0; i < stores.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        MallPublicStoreCard(
          store: stores[i],
          floorLabel: floorLabel?.call(stores[i]),
          highlighted: stores[i].storeId != null && stores[i].storeId == highlightedStoreId,
          onTap: stores[i].storeId == null ? null : () => onOpen(stores[i]),
        ),
      ],
    ]);
  }
}

class MallPublicStoreCard extends StatelessWidget {
  const MallPublicStoreCard({
    super.key,
    required this.store,
    this.floorLabel,
    this.highlighted = false,
    this.onTap,
  });

  final MallPublicStore store;
  final String? floorLabel;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if ((store.category ?? '').trim().isNotEmpty) store.category!.trim(),
      if ((floorLabel ?? '').trim().isNotEmpty) floorLabel!.trim(),
      'Mağaza No: ${store.unitCode}',
    ].join(' • ');
    return Material(
      color: highlighted ? const Color(0xFFF5F3FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('mall-public-store-${store.unitCode}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: highlighted ? AppColors.primary.withValues(alpha: 0.35) : mallPublicLine),
          ),
          child: Row(children: [
            MallPublicLogo(name: store.storeName, url: store.logoUrl, size: 42, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  store.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: mallPublicNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: mallPublicMuted, fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
          ]),
        ),
      ),
    );
  }
}

class MallPublicAboutCard extends StatelessWidget {
  const MallPublicAboutCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('mall-public-about'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mallPublicLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('İletişim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: mallPublicNavy)),
        const SizedBox(height: 4),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: mallPublicLine),
          rows[i],
        ],
      ]),
    );
  }
}

class MallPublicCampaignRail extends StatelessWidget {
  const MallPublicCampaignRail({super.key, required this.campaigns});

  final List<MallPublicCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Kampanyalar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: mallPublicNavy)),
      const SizedBox(height: 8),
      SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: campaigns.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            return Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: mallPublicLine),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  campaign.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: mallPublicNavy),
                ),
                if (campaign.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    campaign.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: mallPublicMuted),
                  ),
                ],
                if (campaign.endsAt != null) ...[
                  const Spacer(),
                  Text(
                    'Son gün: ${campaign.endsAt!.day}.${campaign.endsAt!.month}.${campaign.endsAt!.year}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

class MallPublicStoreSearch extends StatelessWidget {
  const MallPublicStoreSearch({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('mall-public-store-search'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Mağaza ara',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mallPublicLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mallPublicLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}

class MallPublicCategoryChips extends StatelessWidget {
  const MallPublicCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SelectChip(label: 'Tümü', selected: selected == null, onTap: () => onSelect(null)),
          const SizedBox(width: 8),
          for (final category in categories) ...[
            _SelectChip(label: category, selected: selected == category, onTap: () => onSelect(category)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = count != null && count! > 0 ? '$label · $count' : label;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: selected ? AppColors.primary : mallPublicLine),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : mallPublicNavy,
            ),
          ),
        ),
      ),
    );
  }
}
