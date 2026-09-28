import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../domain/coupon_campaign.dart';
import '../domain/coupon_enums.dart';
import '../domain/coupon_status_labels.dart';
import '../domain/reward_wheel_probability.dart';
import 'coupon_status_chip.dart';
import 'reward_wheel_admin_widgets.dart';

class WheelDraftItem {
  WheelDraftItem({
    required this.label,
    required this.percent,
    this.campaignId,
    this.isNoPrize = false,
    this.isActive = true,
    this.campaign,
  });

  final String? campaignId;
  final String label;
  final bool isNoPrize;
  bool isActive;
  int percent;
  final CouponCampaign? campaign;

  WheelDraftItem copy() => WheelDraftItem(
    campaignId: campaignId,
    label: label,
    isNoPrize: isNoPrize,
    isActive: isActive,
    percent: percent,
    campaign: campaign,
  );

  bool sameAs(WheelDraftItem other) =>
      campaignId == other.campaignId &&
      label == other.label &&
      isNoPrize == other.isNoPrize &&
      isActive == other.isActive &&
      percent == other.percent;

  String get sourceLabel {
    if (isNoPrize) return 'Sistem';
    if (campaign == null) return 'Kupon';
    return CouponStatusLabels.source(campaign!.sourceType);
  }
}

class RewardWheelPendingOffers extends StatelessWidget {
  const RewardWheelPendingOffers({
    required this.offers,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
    super.key,
  });

  final List<CouponCampaign> offers;
  final ValueChanged<CouponCampaign> onApprove;
  final ValueChanged<CouponCampaign> onEdit;
  final ValueChanged<CouponCampaign> onReject;

  @override
  Widget build(BuildContext context) {
    return RewardWheelSettingsCard(
      title: 'Bekleyen Teklifler',
      child: Column(
        children: [
          for (final offer in offers)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDE9FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: (offer.storeLogoUrl ?? '').isNotEmpty
                            ? NetworkImage(offer.storeLogoUrl!)
                            : null,
                        child: (offer.storeLogoUrl ?? '').isEmpty
                            ? Text(_initial(offer))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.storeName ?? 'Mağaza',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              offer.name,
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      const CouponStatusChip(
                        status: CouponEffectiveStatus.pendingReview,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      'Ödül: ${offer.discountLabel}',
                      'Min. sepet: ${offer.minOrderAmount.toStringAsFixed(0)} TL',
                      'Kota: ${offer.totalUsageLimit ?? '-'}',
                      'Bütçe: ${offer.adBudget?.toStringAsFixed(0) ?? '-'} TL',
                      'Süre: ${offer.adDurationDays ?? '-'} gün',
                    ].join('  •  '),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => onApprove(offer),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Onayla'),
                      ),
                      OutlinedButton(
                        onPressed: () => onEdit(offer),
                        child: const Text('Düzenle'),
                      ),
                      TextButton(
                        onPressed: () => onReject(offer),
                        child: const Text('Reddet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _initial(CouponCampaign offer) {
    final raw = (offer.storeName ?? offer.name).trim();
    return raw.isEmpty ? 'M' : raw.substring(0, 1).toUpperCase();
  }
}

class RewardWheelRewardsTable extends StatelessWidget {
  const RewardWheelRewardsTable({
    required this.items,
    required this.onAdd,
    required this.onPercentChanged,
    required this.onActiveChanged,
    required this.onDetail,
    required this.onRemove,
    super.key,
  });

  final List<WheelDraftItem> items;
  final VoidCallback onAdd;
  final void Function(int index, int percent) onPercentChanged;
  final void Function(int index, bool active) onActiveChanged;
  final ValueChanged<int> onDetail;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return RewardWheelSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Çarktaki Ödüller',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Ödül Ekle'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              dataTextStyle: const TextStyle(fontSize: 13),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('Ödül')),
                DataColumn(label: Text('Kaynak')),
                DataColumn(label: Text('Mağaza')),
                DataColumn(label: Text('İndirim')),
                DataColumn(label: Text('Min. Sepet')),
                DataColumn(label: Text('Olasılık')),
                DataColumn(label: Text('Kota')),
                DataColumn(label: Text('Durum')),
                DataColumn(label: Text('İşlem')),
              ],
              rows: [
                for (var i = 0; i < items.length; i++)
                  DataRow(
                    cells: [
                      DataCell(Text(items[i].label)),
                      DataCell(Text(items[i].sourceLabel)),
                      DataCell(Text(items[i].campaign?.storeName ?? '-')),
                      DataCell(Text(items[i].campaign?.discountLabel ?? '-')),
                      DataCell(
                        Text(
                          items[i].campaign == null
                              ? '-'
                              : '${items[i].campaign!.minOrderAmount.toStringAsFixed(0)} TL',
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            key: ValueKey('pct-$i-${items[i].percent}'),
                            initialValue: '${items[i].percent}',
                            decoration: const InputDecoration(
                              suffixText: '%',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => onPercentChanged(
                              i,
                              RewardWheelProbability.parsePercent(value),
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text('${items[i].campaign?.totalUsageLimit ?? '-'}')),
                      DataCell(
                        CouponStatusChip(
                          status: items[i].isNoPrize
                              ? CouponEffectiveStatus.active
                              : items[i].campaign?.effectiveStatus ??
                                    CouponEffectiveStatus.draft,
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Switch.adaptive(
                              value: items[i].isActive,
                              onChanged: (value) => onActiveChanged(i, value),
                            ),
                            IconButton(
                              tooltip: 'Detay',
                              onPressed: items[i].campaign == null
                                  ? null
                                  : () => onDetail(i),
                              icon: const Icon(Icons.info_outline, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Kaldır',
                              onPressed: items[i].isNoPrize
                                  ? null
                                  : () => onRemove(i),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
